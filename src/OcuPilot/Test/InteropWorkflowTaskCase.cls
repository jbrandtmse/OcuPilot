/// <p>What Story 24.17 Batch 4's workflow task suites share beyond <class>OcuPilot.Test.InteropWorkflowCase</class>: the Workflow tasks screen, tools and endpoint as the case's parameters, one probe role
/// with two active members and one inactive, the port's task write and read calls, the screen's row actions, the agent's mint of the two task tools, and the audit rows a task write leaves, all through
/// <class>OcuPilot.Test.InteropWorkflowTaskFixture</class>. The probes live in <code>USER</code>, which holds no production unless a test starts the probe production, which it stops and removes.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropWorkflowTaskCase Extends OcuPilot.Test.InteropWorkflowCase [ Abstract ]
{

Parameter FIXTURE = "OcuPilot.Test.InteropWorkflowTaskFixture";

Parameter SCREEN = "/screens/interop.workflowtasks";

Parameter ENDPOINT = "WorkflowTasks";

Parameter WORKLISTENDPOINT = "WorkflowWorklist";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowTask";

Parameter ENTITY = "interop-workflow-task";

Parameter READTYPE = "WORKFLOWTASK";

/// <p>The probe role, its two active members and its inactive one.</p>
Parameter ROLE = "OcuP2417wTr";

Parameter USERA = "OcuP2417wTa";

Parameter USERB = "OcuP2417wTb";

Parameter USERC = "OcuP2417wTc";

/// <p>Store the probe role in <var>pNamespace</var> with the active members <parameter>USERA</parameter> and <parameter>USERB</parameter> and the inactive <parameter>USERC</parameter>.</p>
ClassMethod Arrange(pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 1, pNamespace, 0)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERB, "Bob", 1, pNamespace, 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERC, "Cy", 0, pNamespace, 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLE, pNamespace, "tasks", 30))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#USERA, pNamespace))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#USERB, pNamespace))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#USERC, pNamespace))
    Quit tSC
}

/// <p>The task <var>pId</var> of <var>pNamespace</var> and its worklist as <code>role|assignedTo|priority|status|complete#users</code>.</p>
ClassMethod Facts(pId As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit $ClassMethod(..#FIXTURE, "TaskText", pNamespace, pId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", pNamespace, pId)
}

/// <p>The port's assign of the task <var>pId</var> in <var>pNamespace</var>: the user <var>pUser</var> (<code>$Char(0)</code> for none sent, <code>""</code> for Unassigned) and the priority
/// <var>pPriority</var> (<code>""</code> for none sent), as <code>status code</code>, the row in <var>pResult</var> and the envelope in <var>pFault</var>.</p>
ClassMethod Assign(pId As %String, pUser As %String, pPriority As %String, Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    If pUser '= $Char(0) Set tQuery("taskuser") = pUser
    If pPriority '= "" Set tQuery("taskpriority") = pPriority
    Quit ..Verdict("ASSIGNWORKFLOWTASK", .pResult, .pFault, .tQuery, "", pNamespace, pClass)
}

/// <p>The port's cancel of the task <var>pId</var> in <var>pNamespace</var>, as <code>status code</code>.</p>
ClassMethod Cancel(pId As %String, Output pResult, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    Quit ..Verdict("CANCELWORKFLOWTASK", .pResult, .pFault, .tQuery, "", pNamespace, pClass)
}

/// <p>The port's worklist list in <var>pNamespace</var> with the cap <var>pMax</var> when above zero, as <code>status code</code>, the rows in <var>pRows</var>.</p>
ClassMethod Worklist(Output pRows, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}, pMax As %Integer = 0) As %String
{
    Kill tQuery
    If pMax > 0 Set tQuery("maxRows") = pMax
    Quit ..Verdict("LIST", .pRows, .pFault, .tQuery, "", pNamespace, pClass, ..#WORKLISTENDPOINT)
}

/// <p>One person's Assign of the task <var>pId</var> on the Workflow tasks screen with the values <var>pValues</var>, as <code>status code</code>.</p>
ClassMethod ScreenAssign(pId As %String, pValues As %DynamicObject, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit ..Act("assign", pId, pValues, .pAnswer, pNamespace)
}

/// <p>The agent's mint of the assign or cancel tool for the task <var>pId</var> with the arguments <var>pArgs</var>, as <method>Mint</method> answers it.</p>
ClassMethod MintTask(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit ..Mint(pTool, pId, pArgs, .pReason, .pProposal, .pTurn, pNamespace)
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod("OcuPilot.Test.InteropItemControl", "LedgerCount", pTurn, pTool)
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the task <var>pId</var>, with the last row's data in <var>pData</var>; see
/// <method>OwnRows</method> of the case for the waiting.</p>
ClassMethod TaskRows(pSince As %String, pId As %String, Output pData As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0) As %Integer
{
    Quit ..OwnRows(pSince, pId, .pData, pExpect, pSettle, """task"":""" _ pId _ """")
}

/// <p>The rows <var>pRows</var> reduced to the named fields, one line for each row, in order.</p>
ClassMethod Canon(pRows As %DynamicArray, pFields As %String) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        For tI = 1:1:$Length(pFields, ",") {
            Set tText = tText _ tRow.%Get($Piece(pFields, ",", tI)) _ "="
        }
        Set tText = tText _ $Char(10)
    }
    Quit tText
}

}
