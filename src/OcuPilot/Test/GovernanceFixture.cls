/// <p>Test helper for the classes that write the governance policy
/// (<class>OcuPilot.Kernel.State.Policy</class>): a snapshot of the stored rows, taken before a test,
/// and its restore, so a policy one test left restrictive never refuses a later class's writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions.</p>
Class OcuPilot.Test.GovernanceFixture Extends %RegisteredObject
{

/// <p>Every stored row as <var>pRows</var>, subscripted by name. A read that fails is its error.</p>
ClassMethod Snapshot(Output pRows) As %Status
{
    Kill pRows
    Quit ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.pRows, .tVersion)
}

/// <p>Put the stored rows back to <var>pRows</var>, a <method>Snapshot</method>: every row removed,
/// then the snapshot's preset and settings stored again when it held any.</p>
ClassMethod Restore(ByRef pRows) As %Status
{
    Set tStore = "OcuPilot.Kernel.State.Policy"
    Set tSC = ##class(OcuPilot.Kernel.State.Policy).DeleteAllGuarded()
    If $$$ISERR(tSC) Quit tSC
    If '$Data(pRows) Quit $$$OK
    Kill tSettings
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName), 1, tValue)
        If tName = "" Quit
        If tName = $Parameter(tStore, "PRESETNAME") Continue
        Set tSettings(tName) = tValue
    }
    Quit ##class(OcuPilot.Kernel.State.Policy).GuardedApply($Get(pRows($Parameter(tStore, "PRESETNAME"))), .tSettings, 0)
}

/// <p>Whether the stored rows read exactly <var>pRows</var> again, name for name and value for
/// value.</p>
ClassMethod Matches(ByRef pRows) As %Boolean
{
    Set tSC = ..Snapshot(.tNow)
    If $$$ISERR(tSC) Quit 0
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName), 1, tValue)
        If tName = "" Quit
        If $Get(tNow(tName), $Char(1)) '= tValue Quit
    }
    If tName '= "" Quit 0
    Set tName = ""
    For {
        Set tName = $Order(tNow(tName))
        If tName = "" Quit
        If '$Data(pRows(tName)) Quit
    }
    Quit (tName = "")
}

/// <p>Store <var>pPreset</var> and <var>pSettings</var> over whatever the policy holds, at the
/// version it holds now.</p>
ClassMethod Apply(pPreset As %String, ByRef pSettings) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tValues, .tVersion)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Policy).GuardedApply(pPreset, .pSettings, tVersion)
}

/// <p>Whether <var>pRegistry</var>, a fixture registry, lists <var>pTool</var> while the production
/// registry does not: a fixture tool has no baseline line, so a dispatch probe allows it rather
/// than asking the shipped gate, and asks the shipped gate for every production tool.</p>
ClassMethod FixtureOnly(pRegistry As %String, pTool As %String) As %Boolean
{
    Set tProduction = "OcuPilot.Screen.Tool.Registry"
    If pRegistry = tProduction Quit 0
    Set tSC = $ClassMethod(pRegistry, "Resolve", pTool, .tFixture, 1)
    If $$$ISERR(tSC) || '$IsObject($Get(tFixture)) Quit 0
    Set tSC = $ClassMethod(tProduction, "Resolve", pTool, .tShipped, 1)
    If $$$ISERR(tSC) Quit 0
    Quit '$IsObject($Get(tShipped))
}

/// <p>Whether the stored rows <var>pRows</var> (a <method>Snapshot</method>) leave the baseline to
/// decide every key: no key row, and no preset or an empty one.</p>
ClassMethod IsDefault(ByRef pRows) As %Boolean
{
    Set tPresetName = $Parameter("OcuPilot.Kernel.State.Policy", "PRESETNAME")
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName))
        If tName = "" Quit
        If tName '= tPresetName Quit
    }
    If tName '= "" Quit 0
    Quit ($Get(pRows(tPresetName)) = "")
}

/// <p>Arm (<var>pOn</var> 1) or clear the failing gate
/// <class>OcuPilot.Test.ConfirmFixture</class> answers with, in this process.</p>
ClassMethod FailGate(pOn As %Boolean = 1)
{
    If 'pOn {
        Kill ^||OcuPilotGovernanceFixture("failgate")
        Quit
    }
    Set ^||OcuPilotGovernanceFixture("failgate") = 1
}

/// <p>Whether <method>FailGate</method> is armed.</p>
ClassMethod GateFails() As %Boolean
{
    Quit +$Get(^||OcuPilotGovernanceFixture("failgate"))
}

/// <p>A gate that cannot decide: the signature
/// <method>OcuPilot.Kernel.Governance.Gate.Decide</method> declares, answering an error with the
/// call denied, as an unreadable policy store makes the shipped gate answer.</p>
ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    Kill pDecision
    Set pDecision("allowed") = 0
    Set pDecision("code") = ""
    Quit $$$ERROR($$$GeneralError, "the governance fixture's gate could not decide")
}

/// <p>Remove every stored row, so the baseline alone decides.</p>
ClassMethod Clear() As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Policy).DeleteAllGuarded()
}

}
