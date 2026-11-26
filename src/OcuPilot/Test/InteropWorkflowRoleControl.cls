/// <p>Pins Story 24.17 Batch 3b's three workflow role writes end to end against probe roles in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62): a person's New
/// workflow role Save adds a role, their Edit and Remove change and remove one, and the agent's three tools mint and confirm over HTTP. Each answers a read-back verdict and the change event's triple,
/// and what it stored reads back from <code>EnsLib.Workflow.RoleDefinition</code> exactly as sent; the vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is the record,
/// naming the namespace, the role and the field names, never a description. A remove takes the role's memberships and leaves the tasks sent through the role and their worklist items as they were,
/// where the vendor's delete takes the memberships and where it leaves them. The script form of each write names the role and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, the HTTP test account, and an interoperability-enabled <code>USER</code> namespace. It
/// starts no production and removes every probe it creates.</p>
Class OcuPilot.Test.InteropWorkflowRoleControl Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

/// <p>The probe roles and users the tests take.</p>
Parameter ROLEA = "OcuP2417wCra";

Parameter ROLEB = "OcuP2417wCrb";

Parameter USERA = "OcuP2417wCua";

Parameter USERB = "OcuP2417wCub";

/// <p>Store the role <var>pRole</var> in <var>pNamespace</var> with two active members, an unassigned task, a task owned by the first member with a worklist item and a task with a worklist item for the
/// second; the facts are <code>2|2|3|1</code> (<code>memberships|worklist items|tasks|tasks assigned</code>).</p>
ClassMethod Busy(pRole As %String, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 1, pNamespace)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERB, "Bob", 1, pNamespace, 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", pRole, pNamespace, "busy", 30))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", pRole, ..#USERA, pNamespace))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", pRole, ..#USERB, pNamespace))
    If $$$ISERR(tSC) Quit tSC
    If '$ClassMethod(tFx, "ProbeTask", pRole, "", "", pNamespace) || '$ClassMethod(tFx, "ProbeTask", pRole, ..#USERA, ..#USERA, pNamespace) || '$ClassMethod(tFx, "ProbeTask", pRole, "", ..#USERB, pNamespace) Set tSC = $$$ERROR($$$GeneralError, "a probe task was not stored")
    Quit tSC
}

/// <p>The role <var>pRole</var>'s facts in <var>pNamespace</var>: <code>memberships|worklist items|tasks|tasks assigned</code>.</p>
ClassMethod Facts(pRole As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit $ClassMethod(..#FIXTURE, "RoleFacts", pNamespace, pRole)
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod("OcuPilot.Test.InteropItemControl", "LedgerCount", pTurn, pTool)
}

/// <p>AC2: a person's New workflow role Save adds a role: it answers 201 with the name as its id, its target in the change event's triple and a read-back that matches, stores exactly what was sent
/// (an absent capacity is the vendor's 100) and records one <code>ConfigChange</code> naming the namespace, the role and the field names, and no value. An Edit changes only the fields it carries, an
/// Edit that sends what the role holds calls nothing, an empty description clears it, and a Remove takes the role.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowRole</method> store the capacity on an edit that carries only the description -- the kept-capacity leg goes red.</p>
Method TestThePersonsNewEditAndRemoveReadBackAsSent()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Save({"Name": (..#ROLEA), "Description": "Order approvals", "Capacity": 40}, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#ROLEA _ "|interop-workflow-role|" _ ..#ROLEA _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name as its id, its target and a matching read-back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "Order approvals|40", "the class holds exactly what was sent")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData), 1, "OcuPilot records one ConfigChange row")
    Do $$$AssertTrue((tData [ "USER") && (tData [ "Description,Capacity") && (tData '[ "Order approvals"), "naming the namespace and the field names, never a value: " _ tData)
    Do $$$AssertEquals(..Save({"Name": (..#ROLEB)}, .tSecond), "201 ", "a Save with a name alone answers 201")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEB), "|100", "and the vendor's capacity of 100 is stored")
    Set tText = ..Act("edit", ..#ROLEA, {"Description": "Changed"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-workflow-role|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "Changed|40", "the description changed and the capacity is kept")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 2), 2, "the Edit records its own row")
    Do $$$AssertTrue((tData [ "Description") && (tData '[ "Capacity") && (tData '[ "Changed"), "naming the one field it changed and no value: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Capacity": "55"}, .tAnswer), "200 ", "an Edit of the capacity alone answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "Changed|55", "and keeps the description")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 3), 3, "it records a third row")
    Do $$$AssertTrue((tData [ "Capacity") && (tData '[ "Description"), "naming the capacity alone: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Capacity": "55", "Description": "Changed"}, .tAnswer), "200 ", "an Edit that sends what the role holds is accepted and calls nothing")
    Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Description": ""}, .tAnswer), "200 ", "an Edit that sends an empty description answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "|55", "and the description is cleared")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 4), 4, "the unchanged Edit recorded none and the cleared description records one")
    Set tText = ..Act("remove", ..#ROLEA, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|interop-workflow-role", "as a deletion")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "<absent>", "the role is gone from the class")
    Do $$$AssertEquals(..Act("remove", ..#ROLEA, "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 5, 1), 5, "the Remove records its own row and the refused second Remove records none")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#ROLEA), 0, "and the vendor recorded no row throughout")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#OTHER, ..#ROLEA), "<absent>", "HSCUSTOM was never written")
}

/// <p>AC2: the Save route answers JSON over the wire: 201 with the name as its id, its target and a read-back that matches, and a name the namespace holds, in another letter case too, 409 with
/// <code>INTEROP.WORKFLOW.ROLETAKEN</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.IdOf</method> answer an empty id for a workflow role -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/workflow-roles?ns=USER"
    Set tBody = {"Name": (..#ROLEA), "Description": "Wire role", "Capacity": 20}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#ROLEA _ "|interop-workflow-role|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name's id, its target and a matching read-back")
    For tName = ..#ROLEA, $ZConvert(..#ROLEA, "L") {
        Set tBody = {"Name": (tName)}
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus _ "|" _ ##class(%DynamicObject).%FromJSON(tRaw).code, "409|INTEROP.WORKFLOW.ROLETAKEN", tName _ ": a held name is refused 409 with the envelope's code: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "Wire role|20", "the held role is untouched")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleCount", ..#SOURCE), 1, "and only its row exists")
}

/// <p>AC3: a remove takes the role's memberships and leaves a task sent through the role and its worklist items as they were, both where the vendor's delete leaves the memberships behind
/// (<code>USER</code> with the vendor's foreign-key registry for them taken out for the test and put back after it, shown by a positive control: the vendor's own delete of another role leaves its
/// membership) and where the vendor's delete has already taken them (<code>HSCUSTOM</code>); each audit row counts the members the role held.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowRole</method> skip <method>OcuPilot.Port.InteropPort.WorkflowMembersGone</method> -- the <code>USER</code> leg
/// goes red; make it delete the role's worklist items -- both legs go red.</p>
Method TestTheRemoveTakesTheMembershipsWithOrWithoutTheVendorsRegistry()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertEquals($ClassMethod(tFx, "RoleCascadeHeld", ..#OTHER), 1, "HSCUSTOM holds the registry the vendor's delete takes memberships by")
    Set tFound = $ClassMethod(tFx, "RoleCascadeHeld", ..#SOURCE)
    Do $$$AssertStatusOK(..Busy(..#ROLEA), "a role with two members and three tasks is stored in USER")
    Do $$$AssertEquals(..Facts(..#ROLEA), "2|2|3|1", "two memberships, two worklist items, three tasks, one assigned")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEB), "and a control role")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLEB, ..#USERA), "with a member")
    Do $$$AssertTrue($ClassMethod(tFx, "HideRoleCascade", ..#SOURCE), "USER holds no registry for the test, which puts back what it held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "VendorRoleDelete", ..#SOURCE, ..#ROLEB), "the vendor's own delete of the control role succeeds")
    Do $$$AssertEquals($Piece(..Facts(..#ROLEB), "|", 1), 1, "and leaves its membership behind, so USER is in the state the remove must handle")
    Do $$$AssertStatusOK(..Busy(..#ROLEA _ "h", ..#OTHER), "a role is stored in HSCUSTOM with two members and three tasks")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Put("REMOVEWORKFLOWROLE", ..#ROLEA, {}, .tResult, .tFault), "200 ", "the remove answers 200 in USER")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ ..Facts(..#ROLEA), "<absent>|0|2|3|1", "the role and its two memberships are gone, and its worklist items and tasks are as they were")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#USERA) _ "|" _ $ClassMethod(tFx, "UserText", ..#SOURCE, ..#USERB), "Ann|1|Bob|1", "and its two users stay")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 1, 1), 1, "the remove records one ConfigChange")
    Do $$$AssertTrue((tData [ """members"":2") && (tData [ "USER") && (tData [ """completed"":true"), "naming the namespace and the two members the role held: " _ tData)
    Do $ClassMethod(tFx, "RestoreCascade")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleCascadeHeld", ..#SOURCE), tFound, "USER holds the registry as the test found it")
    Do $$$AssertEquals(..Put("REMOVEWORKFLOWROLE", ..#ROLEA _ "h", {}, .tResult, .tFault, ..#OTHER), "200 ", "the remove answers 200 in HSCUSTOM, where the vendor's delete took the memberships")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#OTHER, ..#ROLEA _ "h") _ "|" _ ..Facts(..#ROLEA _ "h", ..#OTHER), "<absent>|0|2|3|1", "the role and its memberships are gone and its tasks and worklist are as they were")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA _ "h", .tData, 1, 1), 1, "the remove records one ConfigChange")
    Do $$$AssertTrue((tData [ """members"":2") && (tData [ "HSCUSTOM"), "naming HSCUSTOM and the two members: " _ tData)
}

/// <p>AC2: the agent's add of a workflow role, minted for the HTTP account and confirmed over HTTP, creates a role that did not exist with the capacity it proposed, answers one envelope with a
/// read-back that matches, is ledgered once and marked (AD-15), and records one <code>ConfigChange</code> carrying no description; a name taken after the mint, in another letter case, closes the
/// confirm target-changed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowRoleWriteToken</method> answer no token for a held name -- the taken leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..Mint("Add", ..#ROLEA, {"Description": "Agent role", "Capacity": 70}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the add mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-workflow-role|USER|" _ ..#ROLEA, "the target is the role, by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.workflowroles.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "Agent role|70", "the class holds what the proposal reviewed")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#ROLEA), 0, "the vendor records no row")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 1, 1), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "Description,Capacity") && (tData '[ "Agent role"), "naming the fields and carrying no description: " _ tData)
    Set tCode = ..Mint("Add", ..#ROLEB, {"Description": "Second"}, .tReason, .tSecond, .tSecondTurn)
    Do $$$AssertEquals(tCode, "minted", "a second add mints: " _ tReason)
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeRole", $ZConvert(..#ROLEB, "L")), "the name is taken after the mint, in another letter case")
    Set tStatus = ..Confirm(tSecond.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEB), "<absent>", "and nothing was written under the name the agent proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

/// <p>AC2, AC3: the agent's update changes the description or the capacity and keeps the other, and the agent's remove is destructive and ships off: it is refused while the tool's key is off, closes
/// target-changed when a member was added after the mint, and removes the role and its memberships once it is on. The update states no consequence; the remove's says what becomes of the members and
/// the tasks.</p>
/// <p>Mutation (Rule 19): turn the remove tool's baseline key on -- the refusal leg goes red; remove <code>Members</code> from
/// <parameter>OcuPilot.Screen.Tool.InteropWorkflowRoleRemove.FINGERPRINTSUBJECT</parameter> -- the moved leg goes red.</p>
Method TestTheAgentsUpdateAndRemoveConfirmOverHttp()
{
    Do $$$AssertStatusOK(..Busy(..#ROLEA), "a role with two members and three tasks is stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tCode = ..Mint("Update", ..#ROLEA, {"Capacity": 60}, .tReason, .tUpdate, .tUpdateTurn)
        Do $$$AssertEquals(tCode, "minted", "a capacity change mints: " _ tReason)
        If '$IsObject($Get(tUpdate)) Quit
        Do $$$AssertEquals(tUpdate.changed.%ToJSON(), "[{""field"":""Capacity"",""before"":""30"",""after"":""60""}]", "its card shows the one field it moves")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tUpdate.proposalId, "Consequence"), "", "an update states no consequence")
        Set tStatus = ..Confirm(tUpdate.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals(tHttp, 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "busy|60", "the capacity changed and the description is kept")
        Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 1, 1), 1, "the update records one ConfigChange")
        Do $$$AssertTrue((tData [ "Capacity") && (tData '[ "Description") && (tData '[ "busy"), "naming the one field it changed and no value: " _ tData)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tUpdateTurn)
        Set tCode = ..Mint("Remove", ..#ROLEA, {}, .tReason, .tRemove, .tRemoveTurn)
        Do $$$AssertEquals(tCode, "minted", "the remove mints: " _ tReason)
        If '$IsObject($Get(tRemove)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.WORKFLOW.ROLEREMOVE|1", "its consequence says what becomes of the members and the tasks, and it is destructive")
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA), "busy|60", "and the role is still there")
        Kill tSettings
        Set tSettings("interop.workflowroles.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeUser", "OcuP2417wCuc", "Cy", 0), "a third, inactive workflow user is stored, to whom the engine sends no task")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLEA, "OcuP2417wCuc"), "and joins the role after the mint")
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "a member added after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..Facts(..#ROLEA), "3|2|3|1", "and the role is still there with its three members")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRemoveTurn))
        Set tCode = ..Mint("Remove", ..#ROLEA, {}, .tReason, .tRemove, .tRemoveTurn)
        Do $$$AssertEquals(tCode, "minted", "a fresh remove mints: " _ tReason)
        If '$IsObject($Get(tRemove)) Quit
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals(tHttp, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the role gone")
        Do $$$AssertEquals(..LedgerCount(tRemoveTurn, "interop.workflowroles.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ ..Facts(..#ROLEA), "<absent>|0|2|3|1", "the role and its memberships are gone and its tasks and worklist are as they were")
        Do $$$AssertEquals(..OwnRows(tSince, ..#ROLEA, .tData, 2, 1), 2, "the remove records its own ConfigChange and the refused confirms record none")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC8: the script form of each write renders the switch to the namespace, each refusal as one guard and the vendor call, with the role's name and values as string literals, runs nothing, and
/// renders no draft for a name or a value the port would refuse by shape. Run line by line, an add's script stores a free name and only sets the refusal for a name held in another letter case; an
/// edit's and a remove's scripts act on a held role and refuse a missing one, and the remove's takes the memberships the vendor's delete leaves where <code>USER</code>'s registry is taken
/// out for the run and put back after it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowRoleSnippet</method> drop the held-name guard from an add -- the held-in-another-case run goes red; drop the remove's
/// <code>IDDelete</code> loop -- the membership leg goes red.</p>
Method TestTheScriptFormsRenderTheGuardsAndRunNothingForABadValue()
{
    Set tFx = ..#FIXTURE
    For tType = "ADDWORKFLOWROLE", "SETWORKFLOWROLE", "REMOVEWORKFLOWROLE" {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = ..#ROLEA
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery, {"Description": "Script role", "Capacity": 25})
        Set tText = ..StepText(tSteps)
        Do $$$AssertEquals(tSteps.%Size(), 1, tType _ ": the script is one step")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "EnsLib.Workflow.RoleDefinition") && (tText [ ..#ROLEA) && (tText [ "IsEnabled($Namespace)"), tType _ ": it switches the namespace, guards source control and names the role and the vendor's class: " _ tText)
        If tType '= "REMOVEWORKFLOWROLE" Do $$$AssertTrue((tText [ "Script role") && (tText [ "Capacity = 25"), tType _ ": and carries the values as the body had them")
        If tType = "ADDWORKFLOWROLE" Do $$$AssertTrue(tText [ "LOWER(Name)", "the add guards a name held in any letter case")
        If tType = "REMOVEWORKFLOWROLE" Do $$$AssertTrue(tText [ "IDDelete", "the remove takes each membership left after the delete: " _ tText)
    }
    Set tLong = $Translate($Justify("", 129), " ", "x")
    For tBad = $ListBuild("ADDWORKFLOWROLE", "", "{}"), $ListBuild("ADDWORKFLOWROLE", tLong, "{}"), $ListBuild("ADDWORKFLOWROLE", "a" _ $Char(9) _ "b", "{}"), $ListBuild("ADDWORKFLOWROLE", ..#ROLEA, "{""Capacity"":0}"), $ListBuild("ADDWORKFLOWROLE", ..#ROLEA, "{""Capacity"":101}"), $ListBuild("ADDWORKFLOWROLE", ..#ROLEA, "{""Capacity"":1.5}"), $ListBuild("SETWORKFLOWROLE", ..#ROLEA, "{""Capacity"":""x""}"), $ListBuild("SETWORKFLOWROLE", ..#ROLEA, "{""Description"":5}"), $ListBuild("SETWORKFLOWROLE", ..#ROLEA, "{""Description"":""" _ $Translate($Justify("", 2001), " ", "d") _ """}"), $ListBuild("REMOVEWORKFLOWROLE", tLong, "{}") {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tBad, 2)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, ##class(%DynamicAbstractObject).%FromJSON($List(tBad, 3)))
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " of '" _ $Extract($List(tBad, 2), 1, 20) _ "' with " _ $Extract($List(tBad, 3), 1, 24) _ " renders no draft")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "RoleCount", ..#SOURCE), 0, "rendering ran nothing and stored nothing")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", $ZConvert(..#ROLEB, "L")), "a role is held under the lower-case spelling of a second name")
    For tCase = $ListBuild(..#ROLEA, 1), $ListBuild(..#ROLEB, 0) {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tCase, 1)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDWORKFLOWROLE", .tQuery, {"Description": "Script", "Capacity": 12})
        Do $$$AssertEquals(..RunScript(tSteps), $List(tCase, 2), $List(tCase, 1) _ ": the add's script " _ $Select($List(tCase, 2): "adds the free name", 1: "only sets the refusal for a name held in another letter case"))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA), "Script|12", "the free name was added as the script had it")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEB), "<absent>", "and the other spelling was not")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = ..#ROLEA
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "SETWORKFLOWROLE", .tQuery, {"Description": "Edited", "Capacity": 33})), 1, "an edit's script changes the held role")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA), "Edited|33", "as it had the values")
    Set tQuery("id") = "OcuP2417wNobody"
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWROLE", .tQuery, "")), 0, "a remove's script refuses a role that is not held")
    Set tQuery("id") = ..#ROLEA
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann"), "a user is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERA), "and joins the held role")
    Set tFound = $ClassMethod(tFx, "RoleCascadeHeld", ..#SOURCE)
    Do $$$AssertTrue($ClassMethod(tFx, "HideRoleCascade", ..#SOURCE), "USER holds no registry for the run, so the vendor's delete leaves the membership to the script")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWROLE", .tQuery, "")), 1, "and removes one that is")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $Piece(..Facts(..#ROLEA), "|", 1), "<absent>|0", "which is gone, with its membership")
    Do $ClassMethod(tFx, "RestoreCascade")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleCascadeHeld", ..#SOURCE), tFound, "USER holds the registry as the test found it")
}

}
