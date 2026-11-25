/// <p>Pins Story 24.17 Batch 3a's three writes end to end against probe workflow users in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62): a person's New
/// workflow user Save adds a user, their Edit and Remove change and remove one, and the agent's three tools mint and confirm over HTTP. Each answers a read-back verdict and the change event's triple, and
/// what it stored reads back from <code>EnsLib.Workflow.UserDefinition</code> exactly as sent; the vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is the record, naming the
/// namespace, the user and the field names, never a value. A deactivation and a remove delete the user's worklist and leave each task they held unassigned, and a remove takes the user's
/// memberships with it. The script form of each write names the user and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, the HTTP test account, and an interoperability-enabled <code>USER</code> namespace. It starts
/// no production and removes every probe it creates.</p>
Class OcuPilot.Test.InteropWorkflowUserControl Extends OcuPilot.Test.InteropWorkflowCase
{

/// <p>The probe instance users the tests take as workflow users, and two probe roles.</p>
Parameter NAMEA = "OcuP2417wCa";

Parameter NAMEB = "OcuP2417wCb";

Parameter ROLEA = "OcuP2417wRa";

Parameter ROLEB = "OcuP2417wRb";

/// <p>Store a workflow user in two roles that owns a task and holds a worklist item for it, in <code>USER</code>: <var>pName</var>, active, with the full name <var>pFullName</var>.</p>
ClassMethod Busy(pName As %String, pFullName As %String = "Busy User") As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", pName, pFullName, 1)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEA))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEB))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEA, pName))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEB, pName))
    If $$$ISOK(tSC) && '$ClassMethod(tFx, "ProbeTask", ..#ROLEA, pName, pName) Set tSC = $$$ERROR($$$GeneralError, "the probe task was not stored")
    Quit tSC
}

/// <p>The workflow user <var>pName</var>'s facts in <code>USER</code>: <code>memberships|worklist items|tasks assigned</code>.</p>
ClassMethod Facts(pName As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "Facts", ..#SOURCE, pName)
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod("OcuPilot.Test.InteropItemControl", "LedgerCount", pTurn, pTool)
}

/// <p>AC2: a person's New workflow user Save adds a user the instance holds: it answers 201 with the name as its id, its target in the change event's triple and a read-back that matches, stores
/// exactly what was sent, and records one <code>ConfigChange</code> naming the namespace, the user and the field names, and no value. The vendor records none. An Edit changes only the
/// fields it carries, an Edit of the active state alone keeps the full name, and a Remove takes the user; each records its own row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowUser</method> store the full name on an edit that carries only the active state -- the kept-full-name leg goes red.</p>
Method TestThePersonsNewEditAndRemoveReadBackAsSent()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "InstanceUser", ..#NAMEA), "the probe instance user is created")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Save({"Name": (..#NAMEA), "FullName": "Ann Example", "IsActive": false}, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#NAMEA _ "|interop-workflow-user|" _ ..#NAMEA _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name as its id, its target and a matching read-back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Ann Example|0", "the class holds exactly what was sent")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData), 1, "OcuPilot records one ConfigChange row")
    Do $$$AssertTrue((tData [ "USER") && (tData [ "FullName,IsActive") && (tData '[ "Ann Example"), "naming the namespace and the field names, never a value: " _ tData)
    Set tText = ..Act("edit", ..#NAMEA, {"FullName": "Ann Changed"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-workflow-user|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Ann Changed|0", "the full name changed and the active state is kept")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 2), 2, "the Edit records its own row")
    Do $$$AssertTrue((tData [ "FullName") && (tData '[ "IsActive") && (tData '[ "Ann Changed"), "naming the one field it changed and no value: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"IsActive": "true"}, .tAnswer), "200 ", "an Edit of the active state alone answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Ann Changed|1", "and keeps the full name")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 3), 3, "it records a third row")
    Do $$$AssertTrue((tData [ "IsActive") && (tData '[ "FullName"), "naming the active state alone: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"IsActive": "true"}, .tAnswer), "200 ", "an Edit that changes nothing is accepted and calls nothing")
    Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"FullName": ""}, .tAnswer), "200 ", "an Edit that sends an empty full name answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "|1", "and the full name is cleared")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 4), 4, "the unchanged Edit recorded none and the cleared full name records one")
    Set tText = ..Act("remove", ..#NAMEA, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|interop-workflow-user", "as a deletion")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "<absent>", "the user is gone from the class")
    Do $$$AssertEquals(..Act("remove", ..#NAMEA, "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 5, 1), 5, "the Remove records its own row and the refused second Remove records none")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#NAMEA), 0, "and the vendor recorded no row throughout")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#OTHER, ..#NAMEA), "<absent>", "HSCUSTOM was never written")
}

/// <p>AC2: the Save route answers JSON over the wire: 201 with the name as its id, its target and a read-back that matches, and a name the namespace holds, in another letter case too, 409
/// with <code>INTEROP.WORKFLOW.USERTAKEN</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.IdOf</method> answer an empty id for a workflow user -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "InstanceUser", ..#NAMEA), "the probe instance user is created")
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/workflow-users?ns=USER"
    Set tBody = {"Name": (..#NAMEA), "FullName": "Wire Ann"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#NAMEA _ "|interop-workflow-user|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name's id, its target and a matching read-back")
    For tName = ..#NAMEA, $ZConvert(..#NAMEA, "L") {
        Set tBody = {"Name": (tName)}
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).code
        If tName = ..#NAMEA {
            Do $$$AssertEquals(tStatus, 409, "a held name is refused 409: " _ $Extract($Get(tRaw), 1, 300))
            Do $$$AssertEquals(tCode, "INTEROP.WORKFLOW.USERTAKEN", "with the envelope's code")
        } Else {
            Do $$$AssertEquals(tStatus, 422, "a name the instance does not offer in that letter case is refused 422: " _ $Extract($Get(tRaw), 1, 300))
            Do $$$AssertEquals(tCode, "INTEROP.WORKFLOW.USERNAME", "with the envelope's code")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Wire Ann|1", "the held user is untouched")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserCount", ..#SOURCE, 1), 1, "and only its row exists")
}

/// <p>AC2: the choices route answers JSON over the wire: 200 with <code>{rows}</code> of <code>{Name, Namespace}</code> naming a probe instance user and the request's namespace, and
/// no write is made.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.WorkflowUserSave.HandleChoices</method> answer an empty list -- this goes red.</p>
Method TestTheChoicesRouteAnswersTheInstancesUsersOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "InstanceUser", "OcuP2417wRouteA"), "a probe instance user is created")
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/workflow-users/choices?ns=USER"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the choices answer 200: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tFound = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = "OcuP2417wRouteA" Set tFound = tRow.Namespace
    }
    Do $$$AssertEquals(tFound, ..#SOURCE, "the probe instance user is offered, in the request's namespace")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserCount", ..#SOURCE, 1), 0, "and reading the choices stored no workflow user")
}

/// <p>AC3: a person's Edit that makes a user inactive deletes the user's worklist item and leaves the task they owned unassigned, the user's memberships stay; a person's Remove of another such user
/// takes the user, its two memberships and its worklist item and leaves its task unassigned, and the roles stay.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowVendor</method> remove the user by SQL <code>DELETE</code> of its row alone -- the memberships leg goes red.</p>
Method TestTheDeactivationAndTheRemoveDeleteTheWorklistAndUnassignTheTasks()
{
    Do $$$AssertStatusOK(..Busy(..#NAMEA), "an active user in two roles with a task and a worklist item is stored")
    Do $$$AssertStatusOK(..Busy(..#NAMEB, "Other User"), "and a second one")
    Do $$$AssertEquals(..Facts(..#NAMEA), "2|1|1", "each holds two memberships, a worklist item and an owned task")
    Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"IsActive": "false"}, .tAnswer), "200 ", "the person's Edit makes the first inactive")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Busy User|0", "it reads inactive")
    Do $$$AssertEquals(..Facts(..#NAMEA), "2|0|0", "its worklist item is gone and its task is unassigned, and its memberships stay")
    Do $$$AssertEquals($Piece(..Facts(..#NAMEB), "|", 1) _ "|" _ $Piece(..Facts(..#NAMEB), "|", 3), "2|1", "the other keeps its memberships and the task it owns (the engine may offer it the first one's freed task)")
    Do $$$AssertEquals(..Act("remove", ..#NAMEB, "", .tAnswer), "200 ", "the person's Remove takes the second")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEB), "<absent>", "the user is gone")
    Do $$$AssertEquals(..Facts(..#NAMEB), "0|0|0", "its memberships and its worklist item are gone and its task is unassigned")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleCount", ..#SOURCE), 2, "and the two roles stay")
}

/// <p>AC2, AC3: the agent's add of a workflow user, minted for the HTTP account and confirmed over HTTP, creates a user that did not exist with the active state it proposed, answers one envelope with a
/// read-back that matches, is ledgered once and marked (AD-15), and records one <code>ConfigChange</code> carrying no value; a name taken after the mint, in another letter case, closes the confirm
/// target-changed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowWriteToken</method> answer no token for a held name -- the taken leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "InstanceUser", ..#NAMEA), "the probe instance user is created")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "InstanceUser", ..#NAMEB), "and a second")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..Mint("Add", ..#NAMEA, {"FullName": "Agent Ann", "IsActive": false}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the add mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-workflow-user|USER|" _ ..#NAMEA, "the target is the user, by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.workflowusers.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Agent Ann|0", "the class holds what the proposal reviewed, the active state included")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, ..#NAMEA), 0, "the vendor records no row")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "FullName,IsActive") && (tData '[ "Agent Ann"), "naming the fields and carrying no value: " _ tData)
    Set tCode = ..Mint("Add", ..#NAMEB, {"FullName": "Agent Bea"}, .tReason, .tSecond, .tSecondTurn)
    Do $$$AssertEquals(tCode, "minted", "a second add mints: " _ tReason)
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeUser", $ZConvert(..#NAMEB, "L"), "other case", 1, ..#SOURCE, 0), "the name is taken after the mint, in another letter case")
    Set tStatus = ..Confirm(tSecond.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEB), "<absent>", "and nothing was written under the name the agent proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

/// <p>AC2, AC3: the agent's update changes the full name or the active state and keeps the other, and the agent's remove is destructive and ships off: it is refused while the tool's key is off, closes
/// target-changed when a membership was added after the mint, and removes the user, its memberships and its worklist item once it is on. The update's consequence is the deactivation's when the
/// state goes from active to inactive and none for a rename or an activation; the remove's says what becomes of the user's roles and tasks.</p>
/// <p>Mutation (Rule 19): turn the remove tool's baseline key on -- the refusal leg goes red; remove <code>Roles</code> from
/// <parameter>OcuPilot.Screen.Tool.InteropWorkflowUserRemove.FINGERPRINTSUBJECT</parameter> -- the moved leg goes red.</p>
Method TestTheAgentsUpdateAndRemoveConfirmOverHttp()
{
    Do $$$AssertStatusOK(..Busy(..#NAMEA), "an active user in two roles with a task and a worklist item is stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tCode = ..Mint("Update", ..#NAMEA, {"FullName": "Renamed"}, .tReason, .tRename, .tRenameTurn)
        Do $$$AssertEquals(tCode, "minted", "a rename mints: " _ tReason)
        Do $$$AssertTrue($IsObject($Get(tRename)) && (##class(OcuPilot.Test.ProposalFixture).Field(tRename.proposalId, "Consequence") = ""), "a rename carries no consequence")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRenameTurn))
        Set tCode = ..Mint("Update", ..#NAMEA, {"IsActive": false}, .tReason, .tUpdate, .tUpdateTurn)
        Do $$$AssertEquals(tCode, "minted", "a deactivation mints: " _ tReason)
        If '$IsObject($Get(tUpdate)) Quit
        Do $$$AssertEquals(tUpdate.changed.%ToJSON(), "[{""field"":""IsActive"",""before"":""true"",""after"":""false""}]", "its card shows the one field it moves")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tUpdate.proposalId, "Consequence"), "INTEROP.WORKFLOW.USERINACTIVE", "its consequence says what a deactivation does to the worklist and the tasks")
        Set tStatus = ..Confirm(tUpdate.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals(tHttp, 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Busy User|0", "the user is inactive and keeps its full name")
        Do $$$AssertEquals(..Facts(..#NAMEA), "2|0|0", "its worklist item is gone and its task is unassigned")
        Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData), 1, "the update records one ConfigChange")
        Do $$$AssertTrue((tData [ "IsActive") && (tData '[ "FullName"), "naming the one field it changed and no value: " _ tData)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tUpdateTurn)
        Set tCode = ..Mint("Update", ..#NAMEA, {"IsActive": true}, .tReason, .tActivate, .tActivateTurn)
        Do $$$AssertTrue((tCode = "minted") && (##class(OcuPilot.Test.ProposalFixture).Field(tActivate.proposalId, "Consequence") = ""), "an activation carries no consequence: " _ tCode _ " " _ tReason)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tActivateTurn))
        Set tCode = ..Mint("Remove", ..#NAMEA, {}, .tReason, .tRemove, .tRemoveTurn)
        Do $$$AssertEquals(tCode, "minted", "the remove mints: " _ tReason)
        If '$IsObject($Get(tRemove)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.WORKFLOW.USERREMOVE|1", "its consequence says what becomes of the roles, the worklist and the tasks, and it is destructive")
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA), "Busy User|0", "and the user is still there")
        Kill tSettings
        Set tSettings("interop.workflowusers.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeRole", "OcuP2417wRc"), "a third role is stored")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", "OcuP2417wRc", ..#NAMEA), "and the user joins it after the mint")
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "a membership added after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..Facts(..#NAMEA), "3|0|0", "and the user is still there with its three memberships")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRemoveTurn))
        Set tCode = ..Mint("Remove", ..#NAMEA, {}, .tReason, .tRemove, .tRemoveTurn)
        Do $$$AssertEquals(tCode, "minted", "a fresh remove mints: " _ tReason)
        If '$IsObject($Get(tRemove)) Quit
        Set tStatus = ..Confirm(tRemove.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals(tHttp, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the user gone")
        Do $$$AssertEquals(..LedgerCount(tRemoveTurn, "interop.workflowusers.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#NAMEA) _ "|" _ ..Facts(..#NAMEA), "<absent>|0|0|0", "the user and its memberships and worklist are gone")
        Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 2), 2, "the remove records its own ConfigChange and the refused confirms record none")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC7: the script form of each write renders the switch to the namespace, each refusal as one guard and the vendor call, with the user's name and values as string literals, runs nothing, and
/// renders no draft for a name or a value the port would refuse by shape. Run line by line, an add's script stores a free name the instance offers, and only sets the refusal for a name that is no
/// instance user and for one held in another letter case; an edit's and a remove's scripts act on a held user and refuse a missing one.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowSnippet</method> drop the name guard from an add -- the not-an-instance-user run goes red; drop the held-name guard -- the
/// held-in-another-case run goes red.</p>
Method TestTheScriptFormsRenderTheGuardsAndRunNothingForABadValue()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEA), "an instance user the script may add is created")
    For tType = "ADDWORKFLOWUSER", "SETWORKFLOWUSER", "REMOVEWORKFLOWUSER" {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = ..#NAMEA
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery, {"FullName": "Script Ann", "IsActive": false})
        Set tText = ..StepText(tSteps)
        Do $$$AssertEquals(tSteps.%Size(), 1, tType _ ": the script is one step")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "EnsLib.Workflow.UserDefinition") && (tText [ ..#NAMEA) && (tText [ "IsEnabled($Namespace)"), tType _ ": it switches the namespace, guards source control and names the user and the vendor's class: " _ tText)
        If tType '= "REMOVEWORKFLOWUSER" Do $$$AssertTrue((tText [ "Script Ann") && (tText [ "IsActive = 0"), tType _ ": and carries the values as the body had them")
        If tType = "ADDWORKFLOWUSER" Do $$$AssertTrue((tText [ "ListEnsembleUsers") && (tText [ "LOWER(Name)"), "the add guards the instance's user choices and a name held in any letter case")
    }
    Set tLong = $Translate($Justify("", 129), " ", "x")
    For tBad = $ListBuild("ADDWORKFLOWUSER", "", "{}"), $ListBuild("ADDWORKFLOWUSER", ..#NAMEA, "{""FullName"":5}"), $ListBuild("SETWORKFLOWUSER", ..#NAMEA, "{""IsActive"":""yes""}"), $ListBuild("SETWORKFLOWUSER", ..#NAMEA, "{""FullName"":""" _ tLong _ """}"), $ListBuild("ADDWORKFLOWUSER", ..#NAMEA, "{""FullName"":""a\tb""}"), $ListBuild("REMOVEWORKFLOWUSER", tLong, "{}") {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tBad, 2)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, ##class(%DynamicAbstractObject).%FromJSON($List(tBad, 3)))
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " of '" _ $Extract($List(tBad, 2), 1, 20) _ "' with a bad value renders no draft")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "UserCount", ..#SOURCE, 1), 0, "rendering ran nothing and stored nothing")
    ; An add of a free name the instance offers stores it; one that is no instance user, and one held in another letter case, only set the refusal.
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", $ZConvert(..#NAMEB, "L"), "held", 1, ..#SOURCE, 0), "a user is held under the lower-case spelling of a second instance user")
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEB), "which is an instance user in its own spelling")
    For tCase = $ListBuild(..#NAMEA, 1), $ListBuild("OcuP2417wNobody", 0), $ListBuild(..#NAMEB, 0) {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tCase, 1)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDWORKFLOWUSER", .tQuery, {"FullName": "Script"})
        Do $$$AssertEquals(..RunScript(tSteps), $List(tCase, 2), $List(tCase, 1) _ ": the add's script " _ $Select($List(tCase, 2): "adds the free name the instance offers", 1: "only sets the refusal"))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA), "Script|1", "the free name was added as the script had it")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, "OcuP2417wNobody") _ "|" _ $ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEB), "<absent>|<absent>", "and neither the stranger nor the other spelling was added")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = ..#NAMEA
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "SETWORKFLOWUSER", .tQuery, {"FullName": "Edited", "IsActive": false})), 1, "an edit's script changes the held user")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA), "Edited|0", "as it had the values")
    Set tQuery("id") = "OcuP2417wNobody"
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWUSER", .tQuery, "")), 0, "a remove's script refuses a user that is not held")
    Set tQuery("id") = ..#NAMEA
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "REMOVEWORKFLOWUSER", .tQuery, "")), 1, "and removes one that is")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA), "<absent>", "which is gone")
}

}
