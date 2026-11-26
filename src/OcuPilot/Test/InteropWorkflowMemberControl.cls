/// <p>Pins Story 24.17 Batch 3b's two workflow member writes end to end against probe memberships in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62): a person's
/// Add member Save adds a user to a role and their Remove takes the user out, and the agent's two tools mint and confirm over HTTP. An added member reads back from
/// <code>EnsLib.Workflow.RoleMembership</code> with the rank and title sent, 3 and none when they are absent; an active member is sent the role's unassigned task and an inactive one is sent none; a
/// removed member's worklist for the role is deleted and the task they held is left unassigned. The vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is the record, naming the
/// namespace, the role, the user and the field names, never a title. The script form of each write names the membership and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, the HTTP test account, and an interoperability-enabled <code>USER</code> namespace. It
/// starts no production and removes every probe it creates.</p>
Class OcuPilot.Test.InteropWorkflowMemberControl Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowmembers";

Parameter SAVE = "/interop/workflow-members";

Parameter ENDPOINT = "WorkflowMembers";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowMember";

Parameter ENTITY = "interop-workflow-member";

Parameter READTYPE = "WORKFLOWMEMBER";

/// <p>The probe role, an active user and an inactive one.</p>
Parameter ROLE = "OcuP2417wMr";

Parameter ACTIVE = "OcuP2417wMua";

Parameter INACTIVE = "OcuP2417wMub";

/// <p>Store the role with an unassigned task and the two users, one active and one not, in <var>pNamespace</var>.</p>
ClassMethod Arrange(pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#ACTIVE, "Ann", 1, pNamespace)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#INACTIVE, "Bob", 0, pNamespace))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLE, pNamespace, "members", 10))
    If $$$ISOK(tSC) && '$ClassMethod(tFx, "ProbeTask", ..#ROLE, "", "", pNamespace) Set tSC = $$$ERROR($$$GeneralError, "the unassigned probe task was not stored")
    Quit tSC
}

/// <p>The facts of the role in <var>pNamespace</var>: <code>memberships|worklist items|tasks|tasks assigned</code>.</p>
ClassMethod Facts(pNamespace As %String = {..#SOURCE}) As %String
{
    Quit $ClassMethod(..#FIXTURE, "RoleFacts", pNamespace, ..#ROLE)
}

/// <p>The membership of <var>pUser</var> in the role as <code>Ranking|Title</code> or <code>&lt;absent&gt;</code>, in <var>pNamespace</var>.</p>
ClassMethod Text(pUser As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit $ClassMethod(..#FIXTURE, "MemberText", pNamespace, ..#ROLE, pUser)
}

/// <p>The audit rows naming the user <var>pUser</var> since <var>pSince</var>, as <method>OwnRows</method> counts them.</p>
ClassMethod Rows(pSince As %String, pUser As %String, Output pData As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0) As %Integer
{
    Quit ..OwnRows(pSince, pUser, .pData, pExpect, pSettle, """user"":""" _ pUser _ """")
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod("OcuPilot.Test.InteropItemControl", "LedgerCount", pTurn, pTool)
}

/// <p>AC4: a person's Add member Save adds a workflow user to a role: it answers 201 with its target and a read-back that matches, stores the rank and title sent (3 and none when they are absent), sends
/// an active member the role's unassigned task and an inactive one none, and records one <code>ConfigChange</code> naming the namespace, the role, the user and the field names, and no title. A
/// Remove takes the member out, deletes their worklist for the role and leaves the task they held through it unassigned; a second Remove finds none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowMemberVendor</method> pass an empty rank when none was sent -- the default-rank leg goes red.</p>
Method TestThePersonsAddMemberAndRemoveReadBackAsSent()
{
    Do $$$AssertStatusOK(..Arrange(), "a role with an unassigned task and two users are stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Save({"Role": (..#ROLE), "User": (..#ACTIVE), "Ranking": 2, "Title": "Lead"}, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), "interop-workflow-member|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with its target and a matching read-back")
    Do $$$AssertEquals(..Text(..#ACTIVE), "2|Lead", "the class holds the rank and the title sent")
    Do $$$AssertEquals(..Facts(), "1|1|1|0", "and the active member was sent the role's unassigned task")
    Do $$$AssertEquals(..Rows(tSince, ..#ACTIVE, .tData), 1, "OcuPilot records one ConfigChange row")
    Do $$$AssertTrue((tData [ "USER") && (tData [ ..#ROLE) && (tData [ "Ranking,Title") && (tData '[ "Lead"), "naming the namespace, the role, the user and the field names, never a title: " _ tData)
    Do $$$AssertEquals(..Save({"Role": (..#ROLE), "User": (..#INACTIVE)}, .tSecond), "201 ", "a Save with neither rank nor title answers 201")
    Do $$$AssertEquals(..Text(..#INACTIVE), "3|", "and stores the vendor's rank of 3 and no title")
    Do $$$AssertEquals(..Facts(), "2|1|1|0", "an inactive member is sent no task")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, ..#ACTIVE, ..#ACTIVE), "the active member holds a task through the role")
    Do $$$AssertEquals(..Facts(), "2|2|2|1", "with a worklist item")
    Set tText = ..Act("remove", ..MemberId(..#ROLE, ..#ACTIVE), "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|interop-workflow-member", "as a deletion")
    Do $$$AssertEquals(..Text(..#ACTIVE), "<absent>", "the member is gone from the class")
    Do $$$AssertEquals(..Facts(), "1|0|2|0", "their worklist for the role is deleted and the task they held is unassigned")
    Do $$$AssertEquals(..Act("remove", ..MemberId(..#ROLE, ..#ACTIVE), "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..Rows(tSince, ..#ACTIVE, .tData, 2, 1), 2, "the Remove records its own row and the refused second Remove records none")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#ACTIVE), 0, "and the vendor recorded no row throughout")
    Do $$$AssertEquals(..Text(..#ACTIVE, ..#OTHER) _ "|" _ $ClassMethod(..#FIXTURE, "RoleCount", ..#OTHER), "<absent>|0", "HSCUSTOM was never written")
}

/// <p>AC4: the Save route answers JSON over the wire: 201 with its target and a read-back that matches, a user already a member 409 <code>INTEROP.WORKFLOW.MEMBERTAKEN</code>, and a user who is no
/// workflow user of the namespace 422 <code>INTEROP.WORKFLOW.MEMBERUSER</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.IdOf</method> answer an empty id for a member -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Do $$$AssertStatusOK(..Arrange(), "a role and two users are stored")
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/workflow-members?ns=USER"
    Set tBody = {"Role": (..#ROLE), "User": (..#ACTIVE), "Ranking": 4, "Title": "Wire"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "interop-workflow-member|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with its target and a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ "|" _ ##class(%DynamicObject).%FromJSON(tRaw).code, "409|INTEROP.WORKFLOW.MEMBERTAKEN", "a user already a member is refused 409 with the envelope's code: " _ $Extract($Get(tRaw), 1, 300))
    Set tBody = {"Role": (..#ROLE), "User": "OcuP2417wMnobody"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ "|" _ ##class(%DynamicObject).%FromJSON(tRaw).code, "422|INTEROP.WORKFLOW.MEMBERUSER", "a user who is no workflow user is refused 422 with the envelope's code: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Text(..#ACTIVE) _ "|" _ ..Facts(), "4|Wire|1|1|1|0", "the member is as the first Save made it and nothing else was stored")
}

/// <p>AC4: the agent's add of a member, minted for the HTTP account and confirmed over HTTP, adds the user with the rank and title it proposed, states its consequence for an active user and none for an
/// inactive one, answers one envelope with a read-back that matches, is ledgered once and marked (AD-15), and records one <code>ConfigChange</code> carrying no title; a membership that exists
/// after the mint closes the confirm target-changed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowMemberWriteToken</method> answer no token for a held membership -- the moved leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Do $$$AssertStatusOK(..Arrange(), "a role with an unassigned task and two users are stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..MintMember("Add", ..#ROLE, ..#ACTIVE, {"Ranking": 2, "Title": "Boss"}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the add mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-workflow-member|USER|" _ ..MemberId(..#ROLE, ..#ACTIVE), "the target is the membership, by its role and user")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "INTEROP.WORKFLOW.MEMBERADD", "its consequence says an active member is sent the role's unassigned tasks")
    Do $$$AssertEquals(..Text(..#ACTIVE), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.workflowmembers.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Text(..#ACTIVE) _ "|" _ ..Facts(), "2|Boss|1|1|1|0", "the class holds what the proposal reviewed and the active member was sent the task")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#ACTIVE), 0, "the vendor records no row")
    Do $$$AssertEquals(..Rows(tSince, ..#ACTIVE, .tData, 1, 1), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "Ranking,Title") && (tData '[ "Boss"), "naming the fields and carrying no title: " _ tData)
    Set tCode = ..MintMember("Add", ..#ROLE, ..#INACTIVE, {}, .tReason, .tSecond, .tSecondTurn)
    Do $$$AssertEquals(tCode, "minted", "an add of the inactive user mints: " _ tReason)
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond.proposalId, "Consequence"), "", "and states no consequence, for the engine sends an inactive member no task")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLE, ..#INACTIVE, ..#SOURCE, 5, "Other"), "the user joins the role after the mint")
    Set tStatus = ..Confirm(tSecond.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Text(..#INACTIVE), "5|Other", "and the membership found at the confirm is untouched")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

/// <p>AC4: the agent's remove of a member is not destructive and ships on: its card states what becomes of the member's worklist and tasks, it confirms over HTTP, takes the member out, deletes their
/// worklist for the role and leaves the task they held through it unassigned, and is read back as gone, ledgered once and marked; a member who is taken out and added again with another rank after the
/// mint closes the confirm target-changed.</p>
/// <p>Mutation (Rule 19): remove <code>Ranking</code> from <parameter>OcuPilot.Screen.Tool.InteropWorkflowMemberRemove.FINGERPRINTSUBJECT</parameter> -- the moved leg goes red.</p>
Method TestTheAgentsRemoveConfirmsOverHttp()
{
    Do $$$AssertStatusOK(..Arrange(), "a role and two users are stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLE, ..#INACTIVE, ..#SOURCE, 2, "Lead"), "a member joins the role")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeUser", "OcuP2417wMuc", "Cy", 1), "and so does a second user")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLE, "OcuP2417wMuc", ..#SOURCE, 3, ""), "")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "OcuP2417wMuc", "OcuP2417wMuc"), "who holds a task through the role")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..MintMember("Remove", ..#ROLE, "OcuP2417wMuc", {}, .tReason, .tRemove, .tRemoveTurn)
    Do $$$AssertEquals(tCode, "minted", "the remove mints: " _ tReason)
    If '$IsObject($Get(tRemove)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.WORKFLOW.MEMBERREMOVE|0", "its consequence says what becomes of the worklist and the task, and it is not destructive")
    Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the remove confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the member gone")
    Do $$$AssertEquals(..LedgerCount(tRemoveTurn, "interop.workflowmembers.remove"), 1, "ledgered once")
    Do $$$AssertEquals(..Text("OcuP2417wMuc") _ "|" _ ..Facts(), "<absent>|1|0|2|0", "the member is gone, their worklist for the role is deleted and their task is unassigned")
    Do $$$AssertEquals(..Rows(tSince, "OcuP2417wMuc", .tData, 1, 1), 1, "OcuPilot records one ConfigChange")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tRemoveTurn)
    Set tCode = ..MintMember("Remove", ..#ROLE, ..#INACTIVE, {}, .tReason, .tMoved, .tMovedTurn)
    Do $$$AssertEquals(tCode, "minted", "a second remove mints: " _ tReason)
    If '$IsObject($Get(tMoved)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "VendorDeleteMember", ..#SOURCE, ..#ROLE, ..#INACTIVE), "the member is taken out after the mint")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLE, ..#INACTIVE, ..#SOURCE, 4, "Lead"), "and added again with another rank")
    Set tStatus = ..Confirm(tMoved.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Text(..#INACTIVE), "4|Lead", "and the member is still there with the new rank")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tMovedTurn))
}

/// <p>AC8: the script form of each write renders the switch to the namespace, each refusal as one guard and the vendor call, with the role, user and values as literals, runs nothing, and renders no
/// draft for a name or a value the port would refuse by shape. Run line by line, an add's script adds a workflow user who is not yet a member, refuses one already a member and one who is no
/// workflow user; a remove's script refuses a non-member and takes a member out.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowMemberSnippet</method> drop the already-a-member guard -- the held-member run goes red.</p>
Method TestTheScriptFormsRenderTheGuardsAndRunNothingForABadValue()
{
    Do $$$AssertStatusOK(..Arrange(), "a role and two users are stored")
    Set tId = ..MemberId(..#ROLE, ..#INACTIVE)
    For tType = "ADDWORKFLOWMEMBER", "REMOVEWORKFLOWMEMBER" {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = tId
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery, {"Ranking": 2, "Title": "Script"})
        Set tText = ..StepText(tSteps)
        Do $$$AssertEquals(tSteps.%Size(), 1, tType _ ": the script is one step")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "EnsLib.Workflow.RoleDefinition") && (tText [ ..#ROLE) && (tText [ ..#INACTIVE) && (tText [ "IsEnabled($Namespace)"), tType _ ": it switches the namespace, guards source control and names the role, the user and the vendor's class: " _ tText)
        If tType = "ADDWORKFLOWMEMBER" Do $$$AssertTrue((tText [ "AddUserToRole") && (tText [ "Script") && (tText [ "IDExists"), "the add carries the rank and title and guards a member already held: " _ tText)
        If tType = "REMOVEWORKFLOWMEMBER" Do $$$AssertTrue((tText [ "RemoveUserFromRole") && (tText [ "IDExists"), "the remove reads the membership again after the call, which drops the delete's status: " _ tText)
    }
    Set tLong = $Translate($Justify("", 129), " ", "x")
    For tBad = $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Ranking"":0}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Ranking"":6}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Ranking"":1.5}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Ranking"":""x""}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Title"":""" _ tLong _ """}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, ..#INACTIVE, "{""Title"":5}"), $ListBuild("ADDWORKFLOWMEMBER", "", ..#INACTIVE, "{}"), $ListBuild("ADDWORKFLOWMEMBER", ..#ROLE, "", "{}"), $ListBuild("ADDWORKFLOWMEMBER", tLong, ..#INACTIVE, "{}"), $ListBuild("REMOVEWORKFLOWMEMBER", ..#ROLE, tLong, "{}") {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = ..MemberId($List(tBad, 2), $List(tBad, 3))
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, ##class(%DynamicAbstractObject).%FromJSON($List(tBad, 4)))
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " with " _ $Extract($List(tBad, 4), 1, 24) _ " renders no draft")
    }
    Do $$$AssertEquals(..Facts(), "0|0|1|0", "rendering ran nothing and stored nothing")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = ..MemberId(..#ROLE, ..#ACTIVE)
    Set tAdd = {"Ranking": 2, "Title": "Script"}
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDWORKFLOWMEMBER", .tQuery, tAdd)), 1, "an add's script adds a workflow user who is not yet a member")
    Do $$$AssertEquals(..Text(..#ACTIVE), "2|Script", "as it had the rank and the title")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDWORKFLOWMEMBER", .tQuery, tAdd)), 0, "and only sets the refusal for one who already is")
    Set tQuery("id") = ..MemberId(..#ROLE, "OcuP2417wMnobody")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDWORKFLOWMEMBER", .tQuery, tAdd)), 0, "and for one who is no workflow user")
    Set tQuery("id") = ..MemberId(..#ROLE, ..#INACTIVE)
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWMEMBER", .tQuery, "")), 0, "a remove's script refuses a user who is not a member")
    Set tQuery("id") = ..MemberId(..#ROLE, ..#ACTIVE)
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWMEMBER", .tQuery, "")), 1, "and takes one who is out")
    Do $$$AssertEquals(..Text(..#ACTIVE), "<absent>", "who is gone")
}

}
