/// <p>What Story 24.17 Batch 1's armed managed alert suites share: the arming check, the probe alerts <class>OcuPilot.Test.InteropAlertFixture</class> stores in <code>USER</code> and
/// <code>HSCUSTOM</code> and removes before and after every test and asserts gone, the HTTP calls of the Managed alerts screen and the proposal route, the agent's mint, the port's calls
/// through the shipped class or a seam, and the audit rows an update leaves. The probes live in <code>USER</code>, which holds no production; <code>HSCUSTOM</code> holds the install, so the
/// two namespaces tell a confirm's namespace apart. <b>No production is started.</b></p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropAlertCase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropAlertFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropAlertSeam";

Parameter CAPSEAM = "OcuPilot.Test.InteropAlertCapSeam";

Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

Parameter SCREEN = "/screens/interop.managedalerts";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropManagedAlertUpdate";

Parameter KEY = "interop.managedalerts.update";

Parameter ENDPOINT = "ManagedAlerts";

Parameter MODE = "^IRIS.Temp.OcuProbe2417Mode";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " stores probe managed alerts in USER and HSCUSTOM, updates them and creates principals on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    For tNamespace = ..#SOURCE, ..#OTHER {
        Set tForeign = $ClassMethod(..#FIXTURE, "Foreign", tNamespace)
        If tForeign '= 0 Quit
    }
    If tForeign '= 0 Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " lists and counts every managed alert a namespace holds, and " _ tNamespace _ " holds " _ tForeign _ " that are not its probes, so nothing was run. A class that ran before it left them.")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417Mode
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417Mode
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe alerts are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One HTTP call as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var> and the parsed answer, or the raw text, in <var>pAnswer</var>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 300)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>One person's Update on the Managed alerts screen for alert <var>pId</var> with the values <var>pValues</var> (an object of strings), as <code>status code</code>, the answer in
/// <var>pAnswer</var>.</p>
ClassMethod Act(pId As %String, pValues As %DynamicObject, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tBody = {"action": "update", "id": (pId), "values": (pValues)}
    Do ..Call("POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer, pNamespace)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of the update of alert <var>pId</var> with the arguments <var>pArgs</var>, scoped to <var>pNamespace</var>: the code of its refusal, <code>minted</code> when it was not
/// refused; the sentence in <var>pReason</var>; the proposal in <var>pProposal</var> and its turn in <var>pTurn</var>.</p>
ClassMethod Mint(pId As %String, pArgs As %DynamicObject, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Set pReason = ""
    Set pProposal = ""
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit "refused"
    Do pArgs.%Set("ID", pId, "string")
    Do pArgs.%Set("rationale", "probe", "string")
    Do pArgs.%Set("expectedImpact", "probe", "string")
    Set tTool = ..#TOOL
    Set tSC = $ClassMethod($ClassMethod(tTool, "MintClass"), "Mint", $Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), tUser, "", pTurn, pArgs, $ClassMethod(tTool, "LimitsClass"), .pProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pId, "ID", $ClassMethod(tTool, "SettableFields"), $ClassMethod(tTool, "ToolClass"))
    If $IsObject($Get(pProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var>, the raw body and the parsed answer.</p>
ClassMethod Confirm(pProposalId As %String, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ pProposalId _ "/confirm?ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, "", "application/json", .tExtra, 300)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(pRaw) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>The port class <var>pClass</var>'s call of <var>pEndpoint</var> and <var>pType</var> in <var>pNamespace</var> as <code>status code</code>, the rows or the row in <var>pResult</var> and the
/// envelope in <var>pFault</var>. <var>pQuery</var> names the call's other keys.</p>
ClassMethod Verdict(pEndpoint As %String, pType As %String, Output pResult, Output pFault, ByRef pQuery, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Set pQuery("namespace") = pNamespace
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, pType, .pQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port's update of alert <var>pId</var> with the query keys <var>pValues</var> (<code>alertowner</code>, <code>alertopen</code>, <code>alertlevel</code>, <code>alertminutes</code>,
/// <code>alertreason</code>) in <var>pNamespace</var>, as <code>status code</code>.</p>
ClassMethod Update(pId As %String, ByRef pValues, Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Merge tQuery = pValues
    Set tQuery("id") = pId
    Quit ..Verdict(..#ENDPOINT, "UPDATEALERT", .pResult, .pFault, .tQuery, pNamespace, pClass)
}

/// <p>The ids of the rows <var>pRows</var> carries under <code>ID</code>, comma-separated in the order they come.</p>
ClassMethod Ids(pRows) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit tText
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("ID")
    }
    Quit tText
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the managed alert <var>pId</var>, with the last row's data in <var>pData</var>. The audit database
/// shows a row a moment after it is written, so the read is made again, for up to five seconds, until it finds <var>pExpect</var> rows.</p>
ClassMethod OwnRows(pSince As %String, pId As %String, Output pData As %String, pExpect As %Integer = 1) As %Integer
{
    For tTry = 1:1:20 {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", "interop-managed-alert", .pData, """" _ pId _ """")
        If tRows '< pExpect Quit
        Hang 0.25
    }
    Quit tRows
}

/// <p>The text of every step of <var>pSteps</var>, joined by line feeds.</p>
ClassMethod StepText(pSteps As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pSteps) Quit tText
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("text")
    }
    Quit tText
}

}
