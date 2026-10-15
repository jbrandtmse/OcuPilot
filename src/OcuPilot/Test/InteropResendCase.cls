/// <p>What Story 20.31's armed message-resend suites share: the arming check, the probe production in <code>USER</code> started before each
/// test and stopped after it (<class>OcuPilot.Test.InteropResendFixture</class>), the sweep of every message and log row the suite made
/// (<method>OcuPilot.Test.ProductionProbe.SweepSince</method>, asserted empty after the last test), the governance key a test turns
/// on, and the HTTP and port calls of the Messages and Header screens. A suite extends it for its tests and may override
/// <method>OnPrepare</method> and <method>OnRelease</method> to add and remove the classes its messages carry.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropResendCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The environment variable that arms a suite, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropResendFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropResendSeam";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NAMESPACE = "USER";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter SVCNAME = "OcuPilotProbeSvc";

Parameter TWONAME = "OcuPilotProbeTwo";

Parameter OFFNAME = "OcuPilotProbeOff";

/// <p>A message header id no header holds.</p>
Parameter GONE = 999999999;

/// <p><method>OcuPilot.Test.ProductionProbe.HighWater</method> before the suite made a message.</p>
Property PreparedMark As %String;

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMark = ""
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " compiles and runs a probe production in USER and sends messages to it on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedMark = $ClassMethod(..#PROBE, "HighWater")
    If ..PreparedMark = "" Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " could not read the message store's high-water mark in USER, so it could not tell what it made from what was there.")
    Set tSC = $ClassMethod(..#FIXTURE, "Prepare")
    If $$$ISOK(tSC) Set tSC = ..OnPrepare()
    Quit tSC
}

/// <p>What a suite adds to the probe before its first test (<method>OcuPilot.Test.InteropResendFixture.Prepare</method> has run).</p>
Method OnPrepare() As %Status
{
    Quit $$$OK
}

/// <p>What a suite removes before the probe is removed, after its messages were swept.</p>
Method OnRelease() As %Status
{
    Quit $$$OK
}

/// <p>Sweep the messages and logs above the mark, then remove what the suite added and the probe; a failing status when anything
/// survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Set tLeft = $ClassMethod(..#PROBE, "SweepSince", ..PreparedMark)
    Set tSC = $$$ADDSC(tSC, ..OnRelease())
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If tLeft '= "0|0" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, ..%ClassName(1) _ " left messages or log rows in USER: " _ tLeft))
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, ..%ClassName(1) _ " left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set ..PreparedPolicyTaken = 0
    Set tSC = $ClassMethod(..#FIXTURE, "Restore")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Start")
    Quit tSC
}

/// <p>The governance policy is put back, the proposals removed and the probe stopped, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>Store a string request <var>pText</var> addressed to <var>pTarget</var>; its header id.</p>
Method Make(pText As %String, pTarget As %String = {..#OPNAME}) As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "Request", pText, pTarget, .tId)
    Do $$$AssertStatusOK(tSC, "the request '" _ pText _ "' to " _ pTarget _ " is stored")
    Quit $Get(tId)
}

/// <p>Hold, for the fake gate, the pairs of a principal who reads messages and resends them (and, with <var>pEdit</var>, edits and
/// resends one), for a call through <class>OcuPilot.Test.InteropResendSeam</class>.</p>
ClassMethod HoldPairs(pEdit As %Boolean = 0)
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageHeader", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageResend", "USE")
    If pEdit {
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageContent", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageEditResend", "USE")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>Take the copy-out draft of the proposal <var>pProposalId</var> (AD-59) as the HTTP account: the draft in <var>pDraft</var>,
/// <code>""</code> when none was made, and the text of its first step in <var>pText</var>.</p>
ClassMethod TakeDraft(pProposalId As %String, Output pDraft, Output pText As %String) As %Status
{
    Set pDraft = ""
    Set pText = ""
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(pProposalId, ##class(OcuPilot.Test.Http).GetTestUsername(), "https://draft.example:52773", .pDraft, .tHttp, .tCode)
    If $$$ISOK(tSC) && $IsObject($Get(pDraft)) && $IsObject(pDraft.draft) Set pText = pDraft.draft.steps.%Get(0).text
    Quit tSC
}

/// <p>Run the ObjectScript text <var>pText</var> of a draft step as this process does, one line at a time in one frame, so the locals
/// a line sets reach the next; the namespace is put back. The status is the one the script left in <code>tSC</code>.</p>
ClassMethod RunScript(pText As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        For tI = 1:1:$Length(pText, $Char(10)) {
            Set tLine = $Piece(pText, $Char(10), tI)
            If $ZStrip(tLine, "<>W") '= "" XECUTE tLine
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit $Get(tSC, $$$OK)
}

/// <p><var>pBody</var> posted to <var>pPath</var> as the HTTP account: <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>A Messages call of the port as the running account, with the digest <var>pReviewed</var>, the fields <var>pFields</var> (JSON
/// object text) and the composing action <var>pAction</var> when they are not empty: <code>status code</code>, the answer in
/// <var>pResult</var> and the fault in <var>pFault</var>.</p>
ClassMethod Port(pType As %String, pId As %String, Output pResult, pReviewed As %String = "", pFields As %String = "", pAction As %String = "", Output pFault) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pReviewed '= "" Set tQuery("digest") = pReviewed
    If pFields '= "" Set tQuery("fields") = pFields
    If pAction '= "" Set tQuery("action") = pAction
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Messages", pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

}
