/// <p>The governance policy's keys and its cascade (AD-22). A key is a write tool's canonical name,
/// or <code>tool:action</code> for a tool declaring
/// <parameter>OcuPilot.Screen.Tool.Base.GOVERNANCEACTION</parameter>. A key resolves through three
/// layers, the first that holds a value deciding and an explicit <code>false</code> being a value:
/// the stored setting (<class>OcuPilot.Kernel.State.Policy</class>), then the preset
/// (<code>read-only</code> disables, <code>full</code> enables), then the baseline
/// (<class>OcuPilot.Kernel.Governance.Baseline</class>, where an unlisted key is disabled).</p>
/// <p>A read is always allowed, and a kind that is neither <code>read</code> nor
/// <code>write</code> is denied under every layer. The store is read on every call; nothing
/// caches.</p>
Class OcuPilot.Kernel.Governance.Policy Extends %RegisteredObject
{

/// <p>The source word for a key the stored setting decides.</p>
Parameter SOURCESETTING = "setting";

/// <p>The source word for a key the preset decides.</p>
Parameter SOURCEPRESET = "preset";

/// <p>The source word for a key the baseline decides.</p>
Parameter SOURCEBASELINE = "baseline";

/// <p>A baseline that lists the key enabled.</p>
Parameter BASELINEENABLED = "enabled";

/// <p>A baseline that lists the key disabled.</p>
Parameter BASELINEDISABLED = "disabled";

/// <p>A baseline that does not list the key.</p>
Parameter BASELINEABSENT = "absent";

/// <p>The one kind every call is allowed for.</p>
Parameter READKIND = "read";

/// <p>The one kind the cascade decides.</p>
Parameter WRITEKIND = "write";

/// <p>The key a call to the tool <var>pName</var>, answered by <var>pToolClass</var>, with
/// arguments <var>pArgs</var> is governed by: <var>pName</var>, or
/// <code>&lt;pName&gt;:&lt;value&gt;</code> when the class declares
/// <parameter>OcuPilot.Screen.Tool.Base.GOVERNANCEACTION</parameter>, the value being that argument
/// as sent. A call that omits the argument yields <code>&lt;pName&gt;:</code>, which no baseline
/// lists, so the baseline layer reads it disabled.</p>
ClassMethod KeyFor(pToolClass As %String, pName As %String, pArgs As %DynamicAbstractObject = "") As %String
{
    Set tAction = ..ActionOf(pToolClass)
    If tAction = "" Quit pName
    Set tValue = ""
    If $IsObject(pArgs) && pArgs.%IsA("%Library.DynamicObject") && (pArgs.%GetTypeOf(tAction) = "string") Set tValue = pArgs.%Get(tAction)
    Quit pName _ ":" _ tValue
}

/// <p>Every key the <method>OcuPilot.Screen.Tool.Registry.ListTools</method> entry
/// <var>pToolEntry</var> yields, as a <class>%List</class>: its name, or one
/// <code>tool:value</code> per member of its action argument's <code>enum</code>. A tool whose
/// action argument declares no <code>enum</code> yields no key, which the baseline test reports.</p>
ClassMethod KeysOf(pToolEntry As %DynamicObject) As %List
{
    If '$IsObject(pToolEntry) Quit ""
    Set tName = pToolEntry.%Get("name")
    Set tClass = pToolEntry.%Get("class")
    Set tAction = ..ActionOf(tClass)
    If tAction = "" Quit $ListBuild(tName)
    Set tKeys = ""
    Try {
        Set tSchema = $ClassMethod(tClass, "InputSchema", pToolEntry.%Get("descriptor"))
        If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit
        Set tProperty = tSchema.%Get("properties").%Get(tAction)
        If '$IsObject(tProperty) || (tProperty.%GetTypeOf("enum") '= "array") Quit
        Set tIterator = tProperty.%Get("enum").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tValue) {
            Set tKeys = tKeys _ $ListBuild(tName _ ":" _ tValue)
        }
    } Catch {
        Set tKeys = ""
    }
    Quit tKeys
}

/// <p>Resolve <var>pKey</var> for a call of kind <var>pKind</var>: <var>pEnabled</var> 1 or 0, and
/// <var>pSource</var> the layer that decided (<code>""</code> for a read or an unclassifiable
/// kind). The stored policy is read here, on every call. A store that cannot be read is an error
/// with <var>pEnabled</var> 0.</p>
ClassMethod Resolve(pKey As %String, pKind As %String, Output pEnabled As %Boolean, Output pSource As %String) As %Status
{
    Set pEnabled = 0
    Set pSource = ""
    If pKind = ..#READKIND {
        Set pEnabled = 1
        Quit $$$OK
    }
    If pKind '= ..#WRITEKIND Quit $$$OK
    Set tSC = ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tValues, .tVersion)
    If $$$ISERR(tSC) Quit tSC
    Do ..Cascade(.tValues, pKey, pKind, .pEnabled, .pSource)
    Quit $$$OK
}

/// <p>The cascade over stored values <var>pValues</var> (as
/// <method>OcuPilot.Kernel.State.Policy.GuardedAll</method> answers them), for
/// <var>pKey</var> of kind <var>pKind</var>. Pure: it reads nothing but the baseline.</p>
ClassMethod Cascade(ByRef pValues, pKey As %String, pKind As %String, Output pEnabled As %Boolean, Output pSource As %String)
{
    Set pEnabled = 0
    Set pSource = ""
    If pKind = ..#READKIND {
        Set pEnabled = 1
        Quit
    }
    If pKind '= ..#WRITEKIND Quit
    Set tStore = "OcuPilot.Kernel.State.Policy"
    Set tSetting = $Get(pValues(pKey))
    If (pKey '= $Parameter(tStore, "PRESETNAME")) && ((tSetting = $Parameter(tStore, "VALUEENABLED")) || (tSetting = $Parameter(tStore, "VALUEDISABLED"))) {
        Set pEnabled = (tSetting = $Parameter(tStore, "VALUEENABLED"))
        Set pSource = ..#SOURCESETTING
        Quit
    }
    Set tPreset = $Get(pValues($Parameter(tStore, "PRESETNAME")))
    If (tPreset = $Parameter(tStore, "PRESETREADONLY")) || (tPreset = $Parameter(tStore, "PRESETFULL")) {
        Set pEnabled = (tPreset = $Parameter(tStore, "PRESETFULL"))
        Set pSource = ..#SOURCEPRESET
        Quit
    }
    Set pEnabled = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(pKey, .tListed)
    Set pSource = ..#SOURCEBASELINE
}

/// <p>Every registered write key, in name order, as <var>pRows</var>: a <class>%DynamicArray</class>
/// of <code>{key, baseline, setting, enabled, source}</code>, where <code>baseline</code> is
/// <parameter>BASELINEENABLED</parameter>, <parameter>BASELINEDISABLED</parameter> or
/// <parameter>BASELINEABSENT</parameter> and <code>setting</code> is <code>inherit</code>,
/// <code>enabled</code> or <code>disabled</code>. <var>pPreset</var> and <var>pVersion</var> are
/// the stored preset and the policy's version, read in the same pass.</p>
ClassMethod Effective(Output pRows As %DynamicArray, Output pPreset As %String, Output pVersion As %Integer) As %Status
{
    Set pRows = ""
    Set pPreset = ""
    Set pVersion = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..WriteKeys(.tKeys)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tValues, .pVersion)
        If $$$ISERR(tSC) Quit
        Set tStore = "OcuPilot.Kernel.State.Policy"
        Set pPreset = $Get(tValues($Parameter(tStore, "PRESETNAME")))
        Set pRows = []
        Set tKey = ""
        For {
            Set tKey = $Order(tKeys(tKey))
            If tKey = "" Quit
            Set tSeed = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
            Set tStored = $Get(tValues(tKey))
            If (tStored '= $Parameter(tStore, "VALUEENABLED")) && (tStored '= $Parameter(tStore, "VALUEDISABLED")) Set tStored = $Parameter(tStore, "VALUEINHERIT")
            Do ..Cascade(.tValues, tKey, ..#WRITEKIND, .tEnabled, .tSource)
            Set tRow = {}
            Do tRow.%Set("key", tKey, "string")
            Do tRow.%Set("baseline", $Select('tListed: ..#BASELINEABSENT, tSeed: ..#BASELINEENABLED, 1: ..#BASELINEDISABLED), "string")
            Do tRow.%Set("setting", tStored, "string")
            Do tRow.%Set("enabled", ''tEnabled, "boolean")
            Do tRow.%Set("source", tSource, "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>Every key a registered write tool yields (<method>KeysOf</method>), as <var>pKeys</var>
/// subscripted by key. The ledger, the agent marker and a read tool yield none.</p>
ClassMethod WriteKeys(Output pKeys) As %Status
{
    Kill pKeys
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= ..#WRITEKIND Continue
        Set tList = ..KeysOf(tEntry)
        For tI = 1:1:$ListLength(tList) Set pKeys($List(tList, tI)) = ""
    }
    Quit $$$OK
}

/// <p>The action argument <var>pToolClass</var> declares, or <code>""</code>.</p>
ClassMethod ActionOf(pToolClass As %String) As %String
{
    If pToolClass = "" Quit ""
    Set tAction = ""
    Try {
        Set tAction = $Parameter(pToolClass, "GOVERNANCEACTION")
    } Catch {
        Set tAction = ""
    }
    Quit tAction
}

}
