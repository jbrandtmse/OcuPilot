/// <p>The handler behind <code>GET</code> and <code>PUT /agent/governance</code> (Story 14.2, AD-22):
/// the governance policy an administrator views and edits on the Governance policy screen.</p>
/// <p><b>Both routes require OcuPilot's administrative resource</b>, checked at the moment of the
/// call through <method>OcuPilot.Api.Definitions.IsAdministrator</method> and refused through its
/// <method>OcuPilot.Api.Definitions.RenderForbidden</method> (AD-8, AD-39).</p>
/// <p><b>The read</b> answers <code>{preset, rowVersion, keys}</code>, one entry per registered write
/// key in name order, as <method>OcuPilot.Kernel.Governance.Policy.Effective</method> resolves it.
/// <b>The write</b> accepts exactly <code>{preset, settings, rowVersion}</code>; a key it omits is
/// left as it is, and it saves only while the policy still carries <code>rowVersion</code>
/// (Consistency Conventions: concurrent writes). Every accepted write is audited with the old and
/// new value of the preset and of each changed key (FR-29).</p>
/// <p><b>No gate lives here.</b> Whether a call is allowed is
/// <class>OcuPilot.Kernel.Governance.Gate</class>'s alone; this class stores and projects.</p>
Class OcuPilot.Api.Governance Extends %RegisteredObject
{

/// <p>The subsystem every policy change is logged under.</p>
Parameter LOGSUBSYSTEM = "agent-governance";

/// <p>The verb an accepted write records under.</p>
Parameter VERB = "governance";

/// <p>The <class>OcuPilot.Kernel.EntityType</class> value the audit row's target carries.</p>
Parameter ENTITYTYPE = "agent-policy";

/// <p>The id half of that target: the policy is instance state with no identity of its own.</p>
Parameter ENTITYID = "instance";

/// <p>The members a write body carries, and no others.</p>
Parameter BODYMEMBERS = "preset,settings,rowVersion";

/// <p>The presets a write may name.</p>
Parameter PRESETS = ",read-only,full";

/// <p>The settings a key may take.</p>
Parameter SETTINGS = "inherit,enabled,disabled";

/// <p>Answer <code>GET /agent/governance</code>.</p>
ClassMethod HandleRead() As %Status
{
    Set tSC = $$$OK
    Try {
        If '##class(OcuPilot.Api.Definitions).IsAdministrator() {
            Set tSC = ##class(OcuPilot.Api.Definitions).RenderForbidden()
            Quit
        }
        Set tBodySC = ..Projection(.tBody)
        If $$$ISERR(tBodySC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tBodySC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /agent/governance</code>: validate the whole body, then store it in one
/// conditional transaction, audit it, and answer the read's body.</p>
/// <p>A body of any other shape is refused 422 <parameter>OcuPilot.Api.Error.GOVERNANCEBODY</parameter>
/// and a key no registered write tool yields 422
/// <parameter>OcuPilot.Api.Error.GOVERNANCEKEY</parameter>, each with
/// <code>detail.violations</code> of <code>{field, code, reason}</code>; a stale
/// <code>rowVersion</code> is 409 <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter>. None of
/// them writes anything.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Try {
        If '##class(OcuPilot.Api.Definitions).IsAdministrator() {
            Set tSC = ##class(OcuPilot.Api.Definitions).RenderForbidden()
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) && (tStage '= "parse") {
            Set tSC = ##class(OcuPilot.Api.Definitions).RenderBadBody(tReadSC, tStage)
            Quit
        }
        If $$$ISERR(tReadSC) Set tBody = ""
        Set tKeysSC = ##class(OcuPilot.Kernel.Governance.Policy).WriteKeys(.tKnown)
        If $$$ISERR(tKeysSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tKeysSC))
            Quit
        }
        Kill tViolations, tSettings
        Do ..Validate(tBody, .tKnown, .tPreset, .tSettings, .tExpected, .tViolations, .tShapeFault)
        If +$Get(tViolations) {
            Set tCode = $Select(tShapeFault: ##class(OcuPilot.Api.Error).#GOVERNANCEBODY, 1: ##class(OcuPilot.Api.Error).#GOVERNANCEKEY)
            Set tReason = $Select(tShapeFault: ##class(OcuPilot.Api.Error).#REASONGOVERNANCEBODY, 1: ##class(OcuPilot.Api.Error).#REASONGOVERNANCEKEY)
            Set tSC = ##class(OcuPilot.Api.Definitions).RenderViolations(.tViolations, tReason, tCode)
            Quit
        }
        Set tBeforeSC = ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tBefore, .tBeforeVersion)
        If $$$ISERR(tBeforeSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tBeforeSC))
            Quit
        }
        Set tSaveSC = ##class(OcuPilot.Kernel.State.Policy).GuardedApply(tPreset, .tSettings, tExpected)
        If ##class(OcuPilot.Kernel.State.Base).IsStaleSave(tSaveSC) {
            Set tSC = ##class(OcuPilot.Api.Definitions).RenderConflict()
            Quit
        }
        If $$$ISERR(tSaveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The governance policy could not be saved", ##class(%Exception.StatusException).CreateFromStatus(tSaveSC))
            Quit
        }
        Do ..Applied(.tBefore, tPreset, .tSettings, .tAfter)
        Do ..LogChange(.tBefore, .tAfter, .tSettings)
        Set tBodySC = ..Projection(.tAnswer)
        If $$$ISERR(tBodySC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tBodySC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The body both routes answer: <code>{preset, rowVersion, keys}</code>.</p>
ClassMethod Projection(Output pBody As %DynamicObject) As %Status
{
    Set pBody = ""
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Effective(.tRows, .tPreset, .tVersion)
    If $$$ISERR(tSC) Quit tSC
    Set pBody = {}
    Do pBody.%Set("preset", tPreset, "string")
    Do pBody.%Set("rowVersion", +tVersion, "number")
    Do pBody.%Set("keys", tRows)
    Quit $$$OK
}

/// <p>Validate <var>pBody</var> against <var>pKnown</var> (the registered write keys, subscripted by
/// key). Every problem is appended to <var>pViolations</var> as
/// <code>$ListBuild(field, code, reason)</code>, and <var>pShapeFault</var> is 1 when any of them is
/// about the body's shape rather than a key. On no violation, <var>pPreset</var>,
/// <var>pSettings</var> (subscripted by key) and <var>pExpected</var> hold what to store.</p>
ClassMethod Validate(pBody, ByRef pKnown, Output pPreset As %String, Output pSettings, Output pExpected As %Integer, Output pViolations, Output pShapeFault As %Boolean) [ Private ]
{
    Kill pSettings, pViolations
    Set pPreset = ""
    Set pExpected = 0
    Set pShapeFault = 0
    Set tBodyCode = ##class(OcuPilot.Api.Error).#GOVERNANCEBODY
    Set tBodyReason = ##class(OcuPilot.Api.Error).#REASONGOVERNANCEBODY
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") {
        Set pViolations($Increment(pViolations)) = $ListBuild("body", tBodyCode, tBodyReason)
        Set pShapeFault = 1
        Quit
    }
    Set tMembers = $ListFromString(..#BODYMEMBERS)
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tMember, .tIgnored) {
        If '$ListFind(tMembers, tMember) {
            Set pViolations($Increment(pViolations)) = $ListBuild(tMember, tBodyCode, tBodyReason)
            Set pShapeFault = 1
        }
    }
    If (pBody.%GetTypeOf("preset") '= "string") || '$ListFind($ListFromString(..#PRESETS), pBody.%Get("preset")) {
        Set pViolations($Increment(pViolations)) = $ListBuild("preset", tBodyCode, tBodyReason)
        Set pShapeFault = 1
    } Else {
        Set pPreset = pBody.%Get("preset")
    }
    If (pBody.%GetTypeOf("rowVersion") '= "number") || '$Match(pBody.%Get("rowVersion"), "^(0|[1-9][0-9]{0,17})$") {
        Set pViolations($Increment(pViolations)) = $ListBuild("rowVersion", tBodyCode, tBodyReason)
        Set pShapeFault = 1
    } Else {
        Set pExpected = +pBody.%Get("rowVersion")
    }
    If pBody.%GetTypeOf("settings") '= "object" {
        Set pViolations($Increment(pViolations)) = $ListBuild("settings", tBodyCode, tBodyReason)
        Set pShapeFault = 1
        Quit
    }
    Set tSettingWords = $ListFromString(..#SETTINGS)
    Set tIterator = pBody.%Get("settings").%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tField = "settings." _ tKey
        If (pBody.%Get("settings").%GetTypeOf(tKey) '= "string") || '$ListFind(tSettingWords, tValue) {
            Set pViolations($Increment(pViolations)) = $ListBuild(tField, tBodyCode, tBodyReason)
            Set pShapeFault = 1
            Continue
        }
        If (tKey = "") || '$Data(pKnown(tKey)) {
            Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#GOVERNANCEKEY, ##class(OcuPilot.Api.Error).#REASONGOVERNANCEKEY)
            Continue
        }
        Set pSettings(tKey) = tValue
    }
}

/// <p>The stored values <var>pAfter</var> an accepted write leaves: <var>pBefore</var> (as
/// <method>OcuPilot.Kernel.State.Policy.GuardedAll</method> read it before the write) with the
/// preset <var>pPreset</var> and every setting in <var>pSettings</var> applied, an
/// <code>inherit</code> removing the key. Computed rather than read back, so the record names what
/// this request wrote.</p>
ClassMethod Applied(ByRef pBefore, pPreset As %String, ByRef pSettings, Output pAfter) [ Private ]
{
    Kill pAfter
    Merge pAfter = pBefore
    Set tStore = "OcuPilot.Kernel.State.Policy"
    Set pAfter($Parameter(tStore, "PRESETNAME")) = pPreset
    Set tKey = ""
    For {
        Set tKey = $Order(pSettings(tKey), 1, tSetting)
        If tKey = "" Quit
        If tSetting = $Parameter(tStore, "VALUEINHERIT") {
            Kill pAfter(tKey)
        } Else {
            Set pAfter(tKey) = tSetting
        }
    }
}

/// <p>Record one accepted write: the structured log line and the audit row, carrying the old and
/// new preset and, under <code>keys</code>, one <code>{tool, old, new}</code> entry for every key
/// <var>pSettings</var> named whose setting changed. The key is a member's value, never a member's
/// name, so a key ending in a credential word is not masked by the redaction backstop.
/// <var>pBefore</var> and <var>pAfter</var> are the stored values on either side of the write.
/// It swallows its own failure, and emission never fails the write it records (AD-15).</p>
ClassMethod LogChange(ByRef pBefore, ByRef pAfter, ByRef pSettings)
{
    Try {
        Set tStore = "OcuPilot.Kernel.State.Policy"
        Set tPresetName = $Parameter(tStore, "PRESETNAME")
        Set tChanges = {}
        Set tPreset = {}
        Do tPreset.%Set("old", $Get(pBefore(tPresetName)), "string")
        Do tPreset.%Set("new", $Get(pAfter(tPresetName)), "string")
        Do tChanges.%Set("preset", tPreset)
        Set tKeys = []
        Set tKey = ""
        For {
            Set tKey = $Order(pSettings(tKey))
            If tKey = "" Quit
            Set tOld = ..SettingOf(.pBefore, tKey)
            Set tNew = ..SettingOf(.pAfter, tKey)
            If tOld = tNew Continue
            Set tEntry = {}
            Do tEntry.%Set("tool", tKey, "string")
            Do tEntry.%Set("old", tOld, "string")
            Do tEntry.%Set("new", tNew, "string")
            Do tKeys.%Push(tEntry)
        }
        Do tChanges.%Set("keys", tKeys)
        Set tData = {}
        Do tData.%Set("changes", tChanges)
        Do tData.%Set("securityChange", 1, "boolean")
        Do ##class(OcuPilot.Api.Definitions).LogInfo(..#LOGSUBSYSTEM, ..#VERB, tData)
        Do ..RecordAudit(tChanges)
    } Catch ex {
    }
}

/// <p>The one call this class makes into <class>OcuPilot.Kernel.Audit.Event</class>: a security
/// change against the instance's policy (AD-13, AD-15).</p>
ClassMethod RecordAudit(pChanges As %DynamicObject)
{
    Do ##class(OcuPilot.Kernel.Audit.Event).Record(..#VERB, ..#ENTITYTYPE, ..#ENTITYID, pChanges, 1)
}

/// <p>The setting <var>pKey</var> reads as in the stored values <var>pValues</var>:
/// <code>enabled</code>, <code>disabled</code> or <code>inherit</code>.</p>
ClassMethod SettingOf(ByRef pValues, pKey As %String) As %String [ Private ]
{
    Set tStore = "OcuPilot.Kernel.State.Policy"
    Set tValue = $Get(pValues(pKey))
    If (tValue = $Parameter(tStore, "VALUEENABLED")) || (tValue = $Parameter(tStore, "VALUEDISABLED")) Quit tValue
    Quit $Parameter(tStore, "VALUEINHERIT")
}

}
