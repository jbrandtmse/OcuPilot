/// <p>What Story 24.17 Batch 3a's armed workflow user suites share, and Batch 3b's extend: the arming check, the refusal to start beside workflow rows that are not probes, the probe rows
/// <class>OcuPilot.Test.InteropWorkflowFixture</class> stores in <code>USER</code> and <code>HSCUSTOM</code> and removes before and after every test and asserts gone (the probe instance users and
/// principals with them), the HTTP calls of the Workflow users screen and its Save route, the agent's mint and confirm, the port's calls through the shipped class or a seam, and the audit rows a
/// write leaves. The probes live in <code>USER</code>, which holds no production; <code>HSCUSTOM</code> holds the install, so the two namespaces tell a confirm's namespace apart.
/// <b>No production is started.</b></p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropWorkflowCase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropWorkflowFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropWorkflowSeam";

Parameter CAPSEAM = "OcuPilot.Test.InteropWorkflowCapSeam";

Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

Parameter SCREEN = "/screens/interop.workflowusers";

Parameter SAVE = "/interop/workflow-users";

Parameter ENDPOINT = "WorkflowUsers";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowUser";

Parameter MODE = "^IRIS.Temp.OcuProbe2417wMode";

/// <p>The entity type the audit rows a test reads name, and the port type of the one-object read: a subclass for the workflow roles or their members overrides them with
/// <code>SCREEN</code>, <code>SAVE</code>, <code>ENDPOINT</code> and <code>TOOLPREFIX</code> (Story 24.17 Batch 3b).</p>
Parameter ENTITY = "interop-workflow-user";

Parameter READTYPE = "WORKFLOWUSER";

/// <p>The seconds an exact-count read of the audit rows waits for the count to stop moving.</p>
Parameter SETTLE = 1.5;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " stores probe workflow users, roles, memberships and tasks in USER and HSCUSTOM, removes them and creates instance users and principals on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do $ClassMethod(..#FIXTURE, "KeepStamps")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Set tForeign = 0
    For tNamespace = ..#SOURCE, ..#OTHER {
        Set tForeign = $ClassMethod(..#FIXTURE, "Foreign", tNamespace)
        If tForeign '= 0 Quit
    }
    If tForeign '= 0 Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " lists and counts every workflow user, role, membership, worklist item and task a namespace holds, and " _ tNamespace _ " holds " _ tForeign _ " that are not its probes, so nothing was run. A class that ran before it left them.")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do $ClassMethod(..#FIXTURE, "RestoreStamps")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417wMode
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RestoreCascade")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417wMode
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe workflow rows, instance users and principals are removed from both namespaces, and none survives")
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

/// <p>One person's row action <var>pAction</var> on the Workflow users screen for the user <var>pId</var> with the values <var>pValues</var> (an object of strings, or empty), as
/// <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Do ..Call("POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer, pNamespace)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's New workflow user Save of <var>pBody</var> as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Do ..Call("POST", ..#SAVE, pBody, .tStatus, .pAnswer, pNamespace)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of the tool <var>pTool</var> (<code>Add</code>, <code>Update</code> or <code>Remove</code>) for the user <var>pName</var> with the other arguments <var>pArgs</var>, scoped to
/// <var>pNamespace</var>: the code of its refusal, <code>minted</code> when it was not refused; the sentence in <var>pReason</var>; the proposal in <var>pProposal</var> and its turn in
/// <var>pTurn</var>.</p>
ClassMethod Mint(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}, pPrefix As %String = {..#TOOLPREFIX}) As %String
{
    Set pReason = ""
    Set pProposal = ""
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit "refused"
    Set tTool = pPrefix _ pTool
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Set tIdArgument = $ClassMethod(tTool, "IdArgument")
    Do tArgs.%Set(tIdArgument, pName, "string")
    Do tArgs.%Set("rationale", "probe", "string")
    Do tArgs.%Set("expectedImpact", "probe", "string")
    Set tSC = $ClassMethod($ClassMethod(tTool, "MintClass"), "Mint", $Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), tUser, "", pTurn, tArgs, $ClassMethod(tTool, "LimitsClass"), .pProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pName, tIdArgument, $ClassMethod(tTool, "SettableFields"), $ClassMethod(tTool, "ToolClass"))
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

/// <p>The port class <var>pClass</var>'s call of <var>pType</var> in <var>pNamespace</var> with the query keys <var>pQuery</var> and the body <var>pBody</var> as <code>status code</code>, the rows
/// or the row in <var>pResult</var> and the envelope in <var>pFault</var>.</p>
ClassMethod Verdict(pType As %String, Output pResult, Output pFault, ByRef pQuery, pBody As %DynamicObject = "", pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}, pEndpoint As %String = {..#ENDPOINT}) As %String
{
    Set pQuery("namespace") = pNamespace
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, pType, .pQuery, pBody, .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port's write <var>pType</var> of the user <var>pName</var> with the body <var>pBody</var> in <var>pNamespace</var>, as <code>status code</code>.</p>
ClassMethod Put(pType As %String, pName As %String, pBody As %DynamicObject, Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = pName
    Quit ..Verdict(pType, .pResult, .pFault, .tQuery, pBody, pNamespace, pClass)
}

/// <p>The port's one-user read of <var>pName</var> in <var>pNamespace</var>, composed for the write <var>pAction</var> when it is not empty, as <code>status code</code>.</p>
ClassMethod Read(pName As %String, pAction As %String = "", Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = pName
    If pAction '= "" Set tQuery("action") = pAction
    Quit ..Verdict(..#READTYPE, .pResult, .pFault, .tQuery, "", pNamespace, pClass)
}

/// <p>The port's member write <var>pType</var> of <var>pUser</var> in <var>pRole</var> with the body <var>pBody</var> in <var>pNamespace</var>, as <code>status code</code> (Story 24.17 Batch 3b).</p>
ClassMethod PutMember(pType As %String, pRole As %String, pUser As %String, pBody As %DynamicObject, Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = ..MemberId(pRole, pUser)
    Quit ..Verdict(pType, .pResult, .pFault, .tQuery, pBody, pNamespace, pClass, "WorkflowMembers")
}

/// <p>The port's one-membership read of <var>pUser</var> in <var>pRole</var> in <var>pNamespace</var>, composed for the write <var>pAction</var> when it is not empty, as <code>status code</code>.</p>
ClassMethod ReadMember(pRole As %String, pUser As %String, pAction As %String = "", Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = ..MemberId(pRole, pUser)
    If pAction '= "" Set tQuery("action") = pAction
    Quit ..Verdict("WORKFLOWMEMBER", .pResult, .pFault, .tQuery, "", pNamespace, pClass, "WorkflowMembers")
}

/// <p>The composite id of the membership of <var>pUser</var> in <var>pRole</var>, as the members list's rows carry it (Story 24.17 Batch 3b).</p>
ClassMethod MemberId(pRole As %String, pUser As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pRole, pUser))
}

/// <p>The agent's mint of the member tool <var>pTool</var> (<code>Add</code> or <code>Remove</code>) for <var>pUser</var> in <var>pRole</var> with the other arguments <var>pArgs</var>, as
/// <method>Mint</method> answers it (Story 24.17 Batch 3b).</p>
ClassMethod MintMember(pTool As %String, pRole As %String, pUser As %String, pArgs As %DynamicObject, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set("Role", pRole, "string")
    Quit ..Mint(pTool, pUser, tArgs, .pReason, .pProposal, .pTurn, pNamespace, "OcuPilot.Screen.Tool.InteropWorkflowMember")
}

/// <p>The names of the rows <var>pRows</var> carries, comma-separated in the order they come.</p>
ClassMethod Names(pRows, pField As %String = "Name") As %String
{
    Quit $ClassMethod(..#FIXTURE, "Names", pRows, pField)
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the workflow user <var>pName</var>, with the last row's data in <var>pData</var>. The audit database
/// shows a row a moment after it is written, so the read is made again, for up to five seconds, until it finds <var>pExpect</var> rows. With <var>pSettle</var> the answer is an exact count: after
/// <var>pExpect</var> rows are seen the read goes on until the count has not moved for <parameter>SETTLE</parameter> seconds, so a row that lands later is counted and an absence is not read once.</p>
ClassMethod OwnRows(pSince As %String, pName As %String, Output pData As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0, pNeedle As %String = "") As %Integer
{
    If pNeedle = "" Set pNeedle = """" _ pName _ """"
    For tTry = 1:1:20 {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", ..#ENTITY, .pData, pNeedle)
        If tRows '< pExpect Quit
        Hang 0.25
    }
    If 'pSettle Quit tRows
    Set tStable = $ZHorolog
    While ($ZHorolog - tStable) < ..#SETTLE {
        Hang 0.25
        Set tNow = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", ..#ENTITY, .pData, pNeedle)
        If tNow '= tRows {
            Set tRows = tNow
            Set tStable = $ZHorolog
        }
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

/// <p>Run the first step of <var>pSteps</var>, a script, line by line in this process; 1 when it left <code>tSC</code> a success, 0 when it left it an error or a line threw.</p>
ClassMethod RunScript(pSteps As %DynamicArray) As %Boolean
{
    Quit $ClassMethod("OcuPilot.Test.AnalyticsListingGroupBase", "RunScript", pSteps)
}

}
