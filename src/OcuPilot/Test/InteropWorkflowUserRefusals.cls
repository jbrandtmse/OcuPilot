/// <p>Pins Story 24.17 Batch 3a's refusals and failures (AD-6, AD-14, AD-29, AD-36, AD-39, AD-54, AD-55, AD-58, AD-62): a name the instance does not offer, a name held in any letter case, a user
/// the namespace does not hold, a full name the vendor would refuse and a field of the wrong type are each refused by name, before the vendor is called and with nothing stored, from the person's Save and
/// row actions, the agent's mint and the port; a namespace under source control refuses every write on every shipped path; a vendor error status or a fault is 500 <code>INTERNAL</code>, never 200,
/// and its audit row reads not completed; and no line the port logs carries a full name or a vendor's text, or is written while the namespace is switched.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; <class>OcuPilot.Test.SourceControlProbe</class> puts <code>USER</code> under source control
/// for one test, which it takes away again.</p>
Class OcuPilot.Test.InteropWorkflowUserRefusals Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter NAMEA = "OcuP2417wFa";

Parameter NAMEB = "OcuP2417wFb";

Parameter ROLE = "OcuP2417wFr";

/// <p>A full name no log line may carry.</p>
Parameter SECRETFULLNAME = "OcuSecretFullName2417";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SC, "Disable", ..#SOURCE)
    Quit ##super()
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The code of the agent's mint of <var>pTool</var> for <var>pName</var> with <var>pArgs</var>, the sentence in <var>pReason</var>; its turn is cleaned up.</p>
ClassMethod MintCode(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set tCode = ..Mint(pTool, pName, pArgs, .pReason, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Quit tCode
}

/// <p>The workflow user <var>pName</var>'s facts in <code>USER</code>: <code>memberships|worklist items|tasks assigned</code>.</p>
ClassMethod Facts(pName As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "Facts", ..#SOURCE, pName)
}

/// <p>The audit text and completed flag of the last <code>ConfigChange</code> row naming <var>pName</var> since <var>pSince</var>, as <code>count|completed</code>; with <var>pSettle</var> the count is
/// read until it has stopped moving, which is how an absence is asserted.</p>
ClassMethod Audit(pSince As %String, pName As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0) As %String
{
    Set tRows = ..OwnRows(pSince, pName, .tData, pExpect, pSettle)
    Quit tRows _ "|" _ $Select(tData [ """completed"":false": "false", tData [ """completed"":true": "true", 1: "?")
}

/// <p>AC4: an add of a name the instance's user choices do not answer exactly -- a stranger, <code>_SYSTEM</code>, a user spelled in another letter case, the empty name -- is
/// <code>INTEROP.WORKFLOW.USERNAME</code> (422) from the Save and the port, and is refused at the agent's mint; an add of a name the namespace holds, in the exact spelling or another letter case, is
/// <code>INTEROP.WORKFLOW.USERTAKEN</code> (409); nothing is stored and no line is logged.</p>
/// <p>Mutation (Rule 19): make the add's taken test in <method>OcuPilot.Port.InteropPort.WorkflowFactsHere</method> count exactly -- the other-case leg goes red; make
/// <method>OcuPilot.Port.InteropPort.WorkflowWriteToken</method> skip the choices test -- the stranger and <code>_SYSTEM</code> legs go red.</p>
Method TestANameTheInstanceDoesNotOfferIsRefusedAndAHeldNameIsTakenInAnyCase()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEA), "an instance user the namespace does not hold is created")
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEB), "and a second")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", $ZConvert(..#NAMEB, "L"), "held", 1, ..#SOURCE, 0), "which the namespace holds under its lower-case spelling")
    Set tUsername = "INTEROP.WORKFLOW.USERNAME"
    For tCase = $ListBuild("a stranger", "OcuP2417wNobody"), $ListBuild("_SYSTEM", "_SYSTEM"), $ListBuild("another letter case", $ZConvert(..#NAMEA, "U")), $ListBuild("the empty name", "") {
        Set tName = $List(tCase, 2)
        Set tLabel = $List(tCase, 1)
        Do ..Save({"Name": (tName), "FullName": "x"}, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), tUsername, tLabel _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("WORKFLOWUSERNAME")), tLabel _ ": with the published sentence")
        If tName = "" Continue
        Do $$$AssertEquals(..Put("ADDWORKFLOWUSER", tName, {"FullName": "x"}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tUsername, tLabel _ ": the port refuses the add")
        Do $$$AssertEquals(..Read(tName, "ADDWORKFLOWUSER", .tRow, .tFault, ..#SOURCE, tSeam), "422 " _ tUsername, tLabel _ ": and the read composed for an add")
        Do $$$AssertEquals(..MintCode("Add", tName, {"FullName": "x"}, .tReason), tUsername, tLabel _ ": the agent's add is refused at the mint")
        Do $$$AssertEquals(tReason, ..Reason("WORKFLOWUSERNAME"), tLabel _ ": with the published sentence")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "UserCount", ..#SOURCE, 1), 1, "nothing was stored: only the held user is there")
    Set tTaken = "INTEROP.WORKFLOW.USERTAKEN"
    Do ..Save({"Name": (..#NAMEB)}, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), tTaken _ " " _ ..Reason("WORKFLOWUSERTAKEN"), "the Save of a name held in another letter case is refused with the published sentence")
    Do $$$AssertEquals(..Put("ADDWORKFLOWUSER", ..#NAMEB, {}, .tResult, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, "the port refuses it")
    Do $$$AssertEquals(..MintCode("Add", ..#NAMEB, {}, .tReason), tTaken, "and the agent's mint")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "exact", 1, ..#SOURCE, 0), "a user is held under the exact spelling too")
    Do ..Save({"Name": (..#NAMEA)}, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), tTaken, "the Save of the exact name is refused")
    Do $$$AssertEquals(..Put("ADDWORKFLOWUSER", ..#NAMEA, {}, .tResult, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, "and the port's add")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA) _ "|" _ $ClassMethod(tFx, "UserText", ..#SOURCE, $ZConvert(..#NAMEB, "L")), "exact|1|held|1", "the held users are untouched")
    Do $$$AssertEquals($ClassMethod(tFx, "UserCount", ..#SOURCE, 1), 2, "and nothing else was stored")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "no refusal logged a line")
}

/// <p>AC4: an edit or a remove of a name the namespace does not hold exactly is 404 from the person's row actions, the mint and the port, a name in another letter case included, and refused
/// nothing; a full name of 129 characters or holding a control character is <code>INTEROP.WORKFLOW.FULLNAME</code> (422) and one of 128 is accepted; a field of the wrong type is
/// <code>PORT.FIELD.SHAPE</code>; each is refused before the vendor, with nothing stored and no line carrying the full name.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowFullNameOK</method> allow 129 characters -- the long full name rows go red; drop the control character test -- the tab row goes red.</p>
Method TestAMissingUserIsNotFoundAndAFullNameTheVendorWouldRefuseIsRefused()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "held", 1), "a workflow user is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEB), "and an instance user that is not")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLE), "a role is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#NAMEA), "the held user is its member")
    Do $$$AssertTrue($ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#NAMEA, ..#NAMEA) > 0, "and owns a task with a worklist item")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tMissing ="OcuP2417wMissing", $ZConvert(..#NAMEA, "L") {
        Do $$$AssertEquals(..Put("SETWORKFLOWUSER", tMissing, {"FullName": "x"}, .tResult, .tFault), "404 PORT.NOTFOUND", "a set of '" _ tMissing _ "' is 404")
        Do $$$AssertEquals(..Put("REMOVEWORKFLOWUSER", tMissing, "", .tResult, .tFault), "404 PORT.NOTFOUND", "and a remove")
        Do $$$AssertEquals(..Act("edit", tMissing, {"FullName": "x"}, .tAnswer), "404 PORT.NOTFOUND", "the person's Edit is 404 too")
        Do $$$AssertEquals(..Act("remove", tMissing, "", .tAnswer), "404 PORT.NOTFOUND", "and so is the person's Remove")
        Do $$$AssertEquals(..MintCode("Update", tMissing, {"FullName": "x"}, .tReason), "TOOL.ARGUMENTS", "the agent's update is refused at the mint: " _ tReason)
        Do $$$AssertEquals(..MintCode("Remove", tMissing, {}, .tReason), "TOOL.ARGUMENTS", "and its remove: " _ tReason)
    }
    Set tLong = $Translate($Justify("", 129), " ", "n")
    Set tEdge = $Extract(tLong, 1, 128)
    For tCase = $ListBuild("129 characters", tLong), $ListBuild("a tab", "a" _ $Char(9) _ "b"), $ListBuild("a bell", "a" _ $Char(7)) {
        Set tFull = $List(tCase, 2)
        Set tLabel = $List(tCase, 1)
        Do ..Save({"Name": (..#NAMEB), "FullName": (tFull)}, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "INTEROP.WORKFLOW.FULLNAME", tLabel _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("WORKFLOWFULLNAME")), tLabel _ ": with the published sentence")
        Do $$$AssertEquals(..Put("ADDWORKFLOWUSER", ..#NAMEB, {"FullName": (tFull)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.FULLNAME", tLabel _ ": the port refuses the add")
        Do $$$AssertEquals(..Put("SETWORKFLOWUSER", ..#NAMEA, {"FullName": (tFull)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.FULLNAME", tLabel _ ": and the edit")
        Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"FullName": (tFull)}, .tAnswer), "422 INTEROP.WORKFLOW.FULLNAME", tLabel _ ": and the person's Edit")
        Do $$$AssertEquals(..MintCode("Update", ..#NAMEA, {"FullName": (tFull)}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": and the agent's update is refused at the mint")
        Do $$$AssertTrue(tReason [ ..Reason("WORKFLOWFULLNAME"), tLabel _ ": naming the published sentence: " _ tReason)
        Do $$$AssertEquals(..MintCode("Add", ..#NAMEB, {"FullName": (tFull)}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": and its add")
    }
    For tCase = $ListBuild("an active state that is text", "{""IsActive"":""yes""}"), $ListBuild("a full name that is a number", "{""FullName"":5}"), $ListBuild("a null full name", "{""FullName"":null}") {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2))
        Do $$$AssertEquals(..Put("SETWORKFLOWUSER", ..#NAMEA, tBody, .tResult, .tFault, ..#SOURCE, tSeam), "422 PORT.FIELD.SHAPE", $List(tCase, 1) _ ": the port refuses the edit by shape")
    }
    Do ..Save({"Name": (..#NAMEB), "IsActive": "yes"}, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "PORT.FIELD.SHAPE", "the Save of a state that is text is refused by shape")
    Set tText = ..Act("edit", ..#NAMEA, {"IsActive": "yes"}, .tAnswer)
    Do $$$AssertEquals(tText, "400 TOOL.ARGUMENTS", "the person's Edit of a state that is text is refused as the tool's arguments: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA) _ "|" _ $ClassMethod(tFx, "UserCount", ..#SOURCE, 1), "held|1|1", "the held user is as it was and nothing was stored")
    Do $$$AssertEquals(..Facts(..#NAMEA), "1|1|1", "its membership, worklist item and task are untouched")
    Do $$$AssertEquals(..Audit(tSince, ..#NAMEA, 0, 1), "0|?", "and no audit row names it")
    Do $$$AssertEquals(..Put("ADDWORKFLOWUSER", ..#NAMEB, {"FullName": (tEdge)}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "a full name of 128 characters is accepted")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEB), tEdge _ "|1", "and stored as sent")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "no refusal logged a line")
}

/// <p>AC4: a namespace under source control refuses every workflow user write by <code>SOURCECONTROL</code> before the vendor is called, the composed reads of a write included, while the list stays
/// readable. Driven through the port both callers reach, through a seam that answers the namespace's source control state.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.WorkflowWriteRefusal</method> -- the write rows go red.</p>
Method TestASourceControlledNamespaceRefusesEveryWriteThroughTheSeam()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "held", 1), "a workflow user is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEB), "and an instance user that is not")
    Set ^IRIS.Temp.OcuProbe2417wMode("source") = 1
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery, "", ..#SOURCE, tSeam), "200 ", "the list is readable under source control")
    For tWrite = $ListBuild("ADDWORKFLOWUSER", ..#NAMEB, "{}"), $ListBuild("SETWORKFLOWUSER", ..#NAMEA, "{""FullName"":""x""}"), $ListBuild("REMOVEWORKFLOWUSER", ..#NAMEA, "") {
        Set tBody = $Select($List(tWrite, 3) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tWrite, 3)))
        Set tVerdict = ..Put($List(tWrite, 1), $List(tWrite, 2), tBody, .tResult, .tFault, ..#SOURCE, tSeam)
        Do $$$AssertEquals(tVerdict, "409 INTEROP.WORKFLOW.SOURCECONTROL", $List(tWrite, 1) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("WORKFLOWSOURCECONTROL"), "with the published sentence")
        Do $$$AssertEquals(..Read($List(tWrite, 2), $List(tWrite, 1), .tRow, .tFault, ..#SOURCE, tSeam), "409 INTEROP.WORKFLOW.SOURCECONTROL", "the read composed for " _ $List(tWrite, 1) _ " is refused too")
    }
    Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 0, "no vendor call was made")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA) _ "|" _ $ClassMethod(tFx, "UserCount", ..#SOURCE, 1), "held|1|1", "the held user is unchanged and nothing was added")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>AC4: with <code>USER</code> really under source control, every write a person or the agent makes is refused on the shipped path before anything is stored: the person's Save, Edit and Remove over
/// HTTP and the agent's mint of each of the three tools by <code>SOURCECONTROL</code>; of an update and a remove minted while the namespace was not under source control, the update's re-read, which
/// asks for the edit, refuses and closes the proposal target-changed, and the remove is refused by the write. The held user is unchanged throughout.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.InteropWorkflowUserUpdate.READASKSACTION</parameter> to 0 -- the confirmed update's leg goes red; drop the
/// <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.WorkflowWriteRefusal</method> -- every leg goes red.</p>
Method TestEveryShippedWritePathIsRefusedUnderSourceControl()
{
    Set tFx = ..#FIXTURE
    Set tReason = ..Reason("WORKFLOWSOURCECONTROL")
    Set tRefusal = "INTEROP.WORKFLOW.SOURCECONTROL"
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "held", 1), "a workflow user is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", ..#NAMEB), "and an instance user that is not")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
    Kill tSettings
    Set tSettings("interop.workflowusers.remove") = "enabled"
    Try {
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove tool's key is turned on")
    Set tCode = ..Mint("Update", ..#NAMEA, {"FullName": "changed"}, .tUpdateReason, .tUpdate, .tUpdateTurn)
    Do $$$AssertEquals(tCode, "minted", "an update mints while the namespace is not under source control")
    Set tCode = ..Mint("Remove", ..#NAMEA, {}, .tRemoveReason, .tRemove, .tRemoveTurn)
    Do $$$AssertEquals(tCode, "minted", "and so does a remove")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#SOURCE), ..#SOURCE _ " is put under source control")
    Do ..Save({"Name": (..#NAMEB)}, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ "|" _ tAnswer.reason, 1: ""), tRefusal _ "|" _ tReason, "the person's Save is refused with the published sentence")
    Do $$$AssertEquals(..Act("edit", ..#NAMEA, {"FullName": "changed"}, .tAnswer), "409 " _ tRefusal, "and the person's Edit")
    Do $$$AssertEquals(..Act("remove", ..#NAMEA, "", .tAnswer), "409 " _ tRefusal, "and the person's Remove")
    For tCase = $ListBuild("Add", ..#NAMEB, "{}"), $ListBuild("Update", ..#NAMEA, "{""FullName"":""changed""}"), $ListBuild("Remove", ..#NAMEA, "{}") {
        Set tVerdict = ..MintCode($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), .tMintReason)
        Do $$$AssertEquals(tVerdict _ "|" _ tMintReason, tRefusal _ "|" _ tReason, $List(tCase, 1) _ ": the agent's mint is refused, and no card is made")
    }
    Set tWant("update") = "PROPOSAL.TARGETCHANGED"
    Set tWant("remove") = tRefusal
    For tKind = "update", "remove" {
        Set tProposal = $Select(tKind = "update": $Get(tUpdate), 1: $Get(tRemove))
        Do $$$AssertTrue($IsObject(tProposal), "the " _ tKind _ " minted before is there to confirm")
        If '$IsObject(tProposal) Continue
        Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), tWant(tKind), "the " _ tKind _ " minted before is refused at the confirm: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#SOURCE), "the probe's source control is taken out of " _ ..#SOURCE)
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA) _ "|" _ $ClassMethod(tFx, "UserCount", ..#SOURCE, 1), "held|1|1", "the held user is unchanged and nothing was added")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the source control leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC5: a vendor error status or a fault the vendor raises on an add, an edit and a remove is 500 <code>INTERNAL</code>, never 200, and the audit row reads not completed, naming the namespace and
/// the user and never a value; the user is as it was; and no line the port logged carries the vendor's text, the user's name or its full name, the vendor's refusal reaching the log by its
/// code alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowUser</method> ignore the vendor's status -- the status rows go red; make it log the vendor's text -- the log legs go
/// red; record the audit row only on success -- the not-completed legs go red.</p>
Method TestAVendorErrorIsNeverA200AndItsAuditRowReadsNotCompleted()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    ; Each mode takes names of its own, so the audit rows of one mode cannot be counted in the other's.
    Set tSuffix("status") = "s"
    Set tSuffix("fault") = "f"
    For tMode = "status", "fault" {
        Set tHeld = ..#NAMEA _ tSuffix(tMode)
        Set tFree = ..#NAMEB _ tSuffix(tMode)
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", tHeld, ..#SECRETFULLNAME, 1), tMode _ ": a workflow user is held")
        Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", tFree), tMode _ ": and an instance user that is not")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $ClassMethod(tSeam, "ClearLog")
        Kill ^IRIS.Temp.OcuProbe2417wMode
        Set ^IRIS.Temp.OcuProbe2417wMode = tMode
        Kill tRows
        For tCase = $ListBuild("ADDWORKFLOWUSER", tFree, "{""FullName"":""OcuSecretFullName2417""}"), $ListBuild("SETWORKFLOWUSER", tHeld, "{""FullName"":""OcuSecretOther2417""}"), $ListBuild("REMOVEWORKFLOWUSER", tHeld, "") {
            Set tBody = $Select($List(tCase, 3) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)))
            Set tVerdict = ..Put($List(tCase, 1), $List(tCase, 2), tBody, .tResult, .tFault, ..#SOURCE, tSeam)
            Do $$$AssertEquals(tVerdict, "500 INTERNAL", tMode _ ": " _ $List(tCase, 1) _ " answers 500 INTERNAL, never 200")
            Set tRows($List(tCase, 2)) = $Get(tRows($List(tCase, 2))) + 1
            Do $$$AssertEquals(..Audit(tSince, $List(tCase, 2), tRows($List(tCase, 2))), tRows($List(tCase, 2)) _ "|false", tMode _ ": " _ $List(tCase, 1) _ ": its audit row reads not completed")
        }
        Set tLogged = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue($ClassMethod(tSeam, "Logged") > 0, tMode _ ": the failure was logged: " _ tLogged)
        Do $$$AssertTrue((tLogged '[ $Parameter(tSeam, "MARKER")) && (tLogged '[ ..#NAMEA) && (tLogged '[ ..#NAMEB) && (tLogged '[ "OcuSecret"), tMode _ ": no line carries the vendor's text, a name or a full name: " _ tLogged)
        Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, tHeld) _ "|" _ $ClassMethod(tFx, "UserCount", ..#SOURCE, 1), ..#SECRETFULLNAME _ "|1|" _ $Select(tMode = "status": 1, 1: 2), tMode _ ": the held user is as it was and nothing was added")
        Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 3, tMode _ ": the vendor was called once for each write")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("ranIn")), ..#SOURCE, tMode _ ": in the namespace the write is for")
    }
    Kill ^IRIS.Temp.OcuProbe2417wMode
    Set tVerdict = ..Put("SETWORKFLOWUSER", ..#NAMEA _ "f", {"FullName": "Fine"}, .tResult, .tFault, ..#SOURCE, tSeam)
    Do $$$AssertEquals(tVerdict, "200 ", "with no mode the seam answers the vendor's own: the edit is made")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA _ "f"), "Fine|1", "and stored")
}

/// <p>AC5, AC7: nothing is logged while the namespace is switched: a fault raised inside the switched block of a write, a one-user read or the user choices is logged once the namespace is restored, in
/// the namespace the call was made in, and answers 500; the vendor's own call runs in the namespace the write is for and the process's namespace is the caller's after each call.</p>
/// <p>Mutation (Rule 19): log inside <method>OcuPilot.Port.InteropPort.WorkflowFacts</method> before its namespace is restored -- the namespace leg goes red.</p>
Method TestNothingIsLoggedWhileTheNamespaceIsSwitched()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "held", 1), "a workflow user is held")
    Set tHome = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode = "here"
    Do $ClassMethod(tSeam, "ClearLog")
    Do $$$AssertEquals(..Put("SETWORKFLOWUSER", ..#NAMEA, {"FullName": "x"}, .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault in a write's switched block is 500")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("hereIn")), ..#SOURCE, "it was raised in the namespace the write is for")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace")
    Do $$$AssertEquals(..Read(..#NAMEA, "", .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault in the one-user read is 500")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("WORKFLOWUSERCHOICES", .tRows, .tFault, .tQuery, "", ..#SOURCE, tSeam), "500 INTERNAL", "and in the user choices")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace after each")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 3, "each fault was logged once")
    Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), tHome _ "," _ tHome _ "," _ tHome, "every line was written in the caller's namespace, never the switched one")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA), "held|1", "the held user is unchanged")
}

/// <p>AC2: an edit that moves no field calls no vendor and records no audit row, and a user another process holds locked is 503 <code>PORT.UNAVAILABLE</code> for an edit, with nothing changed and no
/// audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowUser</method> call the vendor for an edit that changes nothing -- the unchanged leg goes red; open the user without a
/// concurrency -- the locked leg goes red.</p>
Method TestAnUnchangedEditCallsNothingAndALockedUserIsUnavailable()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAMEA, "held", 1), "a workflow user is held")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set ^IRIS.Temp.OcuProbe2417wMode = ""
    Do $$$AssertEquals(..Put("SETWORKFLOWUSER", ..#NAMEA, {"FullName": "held", "IsActive": true}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "an edit that sends what the user holds is accepted")
    Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 0, "and calls no vendor")
    Do $$$AssertEquals(..Audit(tSince, ..#NAMEA, 0, 1), "0|?", "and records no audit row")
    ; The request that answers the person's Edit runs in another process, so the lock this process takes is one the Edit meets.
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        Lock +^EnsLib.W.UserDefinitionD(..#NAMEA):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the user's lock")
        If tLocked {
            Set tText = ..Act("edit", ..#NAMEA, {"FullName": "changed"}, .tAnswer)
            Do $$$AssertEquals($Piece(tText, " ", 1), 503, "the Edit of the locked user is refused unavailable: " _ tText)
            Do $$$AssertEquals(..Audit(tSince, ..#NAMEA, 0, 1), "0|?", "no audit row was recorded")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tLocked {
        Set $NAMESPACE = ..#SOURCE
        Lock -^EnsLib.W.UserDefinitionD(..#NAMEA)
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAMEA), "held|1", "the user is unchanged")
}

}
