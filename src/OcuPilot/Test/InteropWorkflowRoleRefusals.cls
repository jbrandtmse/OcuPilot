/// <p>Pins Story 24.17 Batch 3b's refusals and failures (AD-6, AD-14, AD-29, AD-36, AD-39, AD-54, AD-55, AD-58, AD-62), for the workflow roles and their members: a name the namespace holds in any letter
/// case, a role or user it does not hold, a value the vendor would refuse or store as something else (a capacity, a rank, a description, a title) and a field of the wrong type are each refused by name,
/// before the vendor is called and with nothing stored, from the person's Save and row actions, the agent's mint and the port; a namespace under source control refuses every write on every shipped path;
/// a vendor error status or fault, and a remove that deletes nothing, is 500 <code>INTERNAL</code>, never 200, with an audit row that reads not completed; and no line the port logs carries a
/// description, a title or a vendor's text, or is written while the namespace is switched.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; <class>OcuPilot.Test.SourceControlProbe</class> puts <code>USER</code> under source control
/// for one test, which it takes away again.</p>
Class OcuPilot.Test.InteropWorkflowRoleRefusals Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

Parameter MEMBERSCREEN = "/screens/interop.workflowmembers";

Parameter MEMBERSAVE = "/interop/workflow-members";

Parameter MEMBERTOOL = "OcuPilot.Screen.Tool.InteropWorkflowMember";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter ROLEA = "OcuP2417wFra";

Parameter ROLEB = "OcuP2417wFrb";

Parameter USERA = "OcuP2417wFua";

Parameter USERB = "OcuP2417wFub";

/// <p>A description and a title no log line may carry.</p>
Parameter SECRETTEXT = "OcuSecretText2417";

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

/// <p>The code of the agent's mint of the role tool <var>pTool</var> for <var>pName</var> with <var>pArgs</var>, the sentence in <var>pReason</var>; its turn is cleaned up.</p>
ClassMethod MintCode(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set tCode = ..Mint(pTool, pName, pArgs, .pReason, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Quit tCode
}

/// <p>The code of the agent's mint of the member tool <var>pTool</var> for <var>pUser</var> in <var>pRole</var>, as <method>MintCode</method> answers it.</p>
ClassMethod MemberMintCode(pTool As %String, pRole As %String, pUser As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set tCode = ..MintMember(pTool, pRole, pUser, pArgs, .pReason, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Quit tCode
}

/// <p>The person's member row action <var>pAction</var> on the Role members screen for the membership of <var>pUser</var> in <var>pRole</var>, as <code>status code</code>.</p>
ClassMethod ActMember(pAction As %String, pRole As %String, pUser As %String, Output pAnswer) As %String
{
    Do ..Call("POST", ..#MEMBERSCREEN _ "/action", {"action": (pAction), "id": (..MemberId(pRole, pUser))}, .tStatus, .pAnswer, ..#SOURCE)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Add member Save of <var>pBody</var> as <code>status code</code>.</p>
ClassMethod SaveMember(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do ..Call("POST", ..#MEMBERSAVE, pBody, .tStatus, .pAnswer, ..#SOURCE)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The code of an answer <var>pAnswer</var>, and its reason.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>How many <code>ConfigChange</code> rows of the entity <var>pEntity</var> naming <var>pNeedle</var> exist since <var>pSince</var>, read until the count has stopped moving when
/// <var>pSettle</var>, with the last row's data in <var>pData</var>, and whether the last one reads completed: <code>count|completed</code>.</p>
ClassMethod Audit(pSince As %String, pEntity As %String, pNeedle As %String, Output pData As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0) As %String
{
    Set tRows = 0
    For tTry = 1:1:20 {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pEntity, .pData, pNeedle)
        If tRows '< pExpect Quit
        Hang 0.25
    }
    If pSettle {
        Set tStable = $ZHorolog
        While ($ZHorolog - tStable) < ..#SETTLE {
            Hang 0.25
            Set tNow = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pEntity, .pData, pNeedle)
            If tNow '= tRows {
                Set tRows = tNow
                Set tStable = $ZHorolog
            }
        }
    }
    Quit tRows _ "|" _ $Select(pData [ """completed"":false": "false", pData [ """completed"":true": "true", 1: "?")
}

/// <p>AC5: a role name that is empty, over 128 characters or holds a control character is <code>INTEROP.WORKFLOW.ROLENAME</code> (422), and one the namespace holds, in the exact spelling or another
/// letter case, <code>INTEROP.WORKFLOW.ROLETAKEN</code> (409), from the Save and the port and at the agent's mint; an edit or remove of a name not held exactly is 404 from the person's row actions and
/// the port and refused at the mint; nothing is stored and no line is logged.</p>
/// <p>Mutation (Rule 19): make the add's taken test in <method>OcuPilot.Port.InteropPort.WorkflowRoleFactsHere</method> count exactly -- the other-case leg goes red; make
/// <method>OcuPilot.Port.InteropPort.WorkflowNameOK</method> allow 129 characters -- the long name leg goes red.</p>
Method TestARoleNameTheNamespaceHoldsInAnyCaseOrCannotTakeIsRefused()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Set tName = "INTEROP.WORKFLOW.ROLENAME"
    Set tLong = $Translate($Justify("", 129), " ", "n")
    For tCase = $ListBuild("the empty name", ""), $ListBuild("129 characters", tLong), $ListBuild("a tab", "a" _ $Char(9) _ "b"), $ListBuild("a bell", "a" _ $Char(7)) {
        Set tRole = $List(tCase, 2)
        Set tLabel = $List(tCase, 1)
        Do ..Save({"Name": (tRole)}, .tAnswer)
        Do $$$AssertEquals(..CodeOf(tAnswer), tName, tLabel _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("WORKFLOWROLENAME")), tLabel _ ": with the published sentence")
        If tRole = "" Continue
        Do $$$AssertEquals(..Put("ADDWORKFLOWROLE", tRole, {}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tName, tLabel _ ": the port refuses the add")
        Do $$$AssertEquals(..MintCode("Add", tRole, {}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": and the agent's mint, as the tool's arguments")
        Do $$$AssertTrue(tReason [ ..Reason("WORKFLOWROLENAME"), tLabel _ ": naming the published sentence: " _ $Extract(tReason, 1, 200))
    }
    Set tTaken = "INTEROP.WORKFLOW.ROLETAKEN"
    For tHeld = ..#ROLEA, $ZConvert(..#ROLEA, "U") {
        Do ..Save({"Name": (tHeld)}, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), tTaken _ " " _ ..Reason("WORKFLOWROLETAKEN"), tHeld _ ": the Save is refused with the published sentence")
        Do $$$AssertEquals(..Put("ADDWORKFLOWROLE", tHeld, {}, .tResult, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, tHeld _ ": the port refuses the add")
        Do $$$AssertEquals(..Read(tHeld, "ADDWORKFLOWROLE", .tRow, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, tHeld _ ": and the read composed for an add")
        Do $$$AssertEquals(..MintCode("Add", tHeld, {}, .tReason), tTaken, tHeld _ ": and the agent's mint")
    }
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tMissing = "OcuP2417wMissing", $ZConvert(..#ROLEA, "L") {
        Do $$$AssertEquals(..Put("SETWORKFLOWROLE", tMissing, {"Description": "x"}, .tResult, .tFault), "404 PORT.NOTFOUND", "a set of '" _ tMissing _ "' is 404")
        Do $$$AssertEquals(..Put("REMOVEWORKFLOWROLE", tMissing, "", .tResult, .tFault), "404 PORT.NOTFOUND", "and a remove")
        Do $$$AssertEquals(..Act("edit", tMissing, {"Description": "x"}, .tAnswer), "404 PORT.NOTFOUND", "the person's Edit is 404 too")
        Do $$$AssertEquals(..Act("remove", tMissing, "", .tAnswer), "404 PORT.NOTFOUND", "and so is the person's Remove")
        Do $$$AssertEquals(..MintCode("Update", tMissing, {"Description": "x"}, .tReason), "TOOL.ARGUMENTS", "the agent's update is refused at the mint: " _ tReason)
        Do $$$AssertEquals(..MintCode("Remove", tMissing, {}, .tReason), "TOOL.ARGUMENTS", "and its remove: " _ tReason)
    }
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $ClassMethod(tFx, "RoleCount", ..#SOURCE), "held|20|1", "the held role is unchanged and nothing was stored")
    Do $$$AssertEquals(..Audit(tSince, ..#ENTITY, """" _ ..#ROLEA _ """", .tData, 0, 1), "0|?", "and no audit row names it")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "no refusal logged a line")
}

/// <p>AC5: a description of 2,001 characters is <code>INTEROP.WORKFLOW.ROLEDESCRIPTION</code> and one of 2,000 is accepted; a capacity that is not a whole number from 1 to 100 (0, 101, 1.5) is
/// <code>INTEROP.WORKFLOW.ROLECAPACITY</code> and 1 and 100 are accepted; a field of the wrong type is <code>PORT.FIELD.SHAPE</code>; each is refused before the vendor, from the Save, the person's Edit,
/// the agent's mint and the port, with nothing stored and no line carrying the description.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowCapacityOK</method> allow 101 -- the capacity row goes red; allow a fraction -- the 1.5 row goes red.</p>
Method TestADescriptionOrACapacityTheVendorWouldRefuseOrStoreOtherwiseIsRefused()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Set tLong = $Translate($Justify("", 2001), " ", "d")
    Do $$$AssertEquals(..Put("ADDWORKFLOWROLE", ..#ROLEB, {"Description": (tLong)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.ROLEDESCRIPTION", "a description of 2,001 characters is refused by the port's add")
    Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, {"Description": (tLong)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.ROLEDESCRIPTION", "and by its edit")
    Do ..Save({"Name": (..#ROLEB), "Description": (tLong)}, .tAnswer)
    Do $$$AssertTrue(..CodeOf(tAnswer) = "INTEROP.WORKFLOW.ROLEDESCRIPTION" && (tAnswer.%ToJSON() [ ..Reason("WORKFLOWROLEDESCRIPTION")), "and by the Save, with the published sentence")
    Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Description": (tLong)}, .tAnswer), "422 INTEROP.WORKFLOW.ROLEDESCRIPTION", "and by the person's Edit")
    Do $$$AssertEquals(..MintCode("Update", ..#ROLEA, {"Description": (tLong)}, .tReason), "TOOL.ARGUMENTS", "and the agent's update is refused at the mint")
    Do $$$AssertTrue(tReason [ ..Reason("WORKFLOWROLEDESCRIPTION"), "naming the published sentence: " _ $Extract(tReason, 1, 200))
    For tCapacity = 0, 101, 1.5 {
        Set tLabel = "capacity " _ tCapacity
        Do $$$AssertEquals(..Put("ADDWORKFLOWROLE", ..#ROLEB, {"Capacity": (tCapacity)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.ROLECAPACITY", tLabel _ ": the port refuses the add")
        Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, {"Capacity": (tCapacity)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.ROLECAPACITY", tLabel _ ": and the edit")
        Do ..Save({"Name": (..#ROLEB), "Capacity": (tCapacity)}, .tAnswer)
        Do $$$AssertEquals(..CodeOf(tAnswer), "INTEROP.WORKFLOW.ROLECAPACITY", tLabel _ ": and the Save")
        Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Capacity": (tCapacity _ "")}, .tAnswer), "422 INTEROP.WORKFLOW.ROLECAPACITY", tLabel _ ": and the person's Edit")
        Do $$$AssertEquals(..MintCode("Update", ..#ROLEA, {"Capacity": (tCapacity)}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": and the agent's update at the mint")
    }
    Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Capacity": "x"}, .tAnswer), "400 TOOL.ARGUMENTS", "a capacity that is no number in the Edit is refused as the tool's arguments")
    For tCase = $ListBuild("a description that is a number", "{""Description"":5}"), $ListBuild("a capacity that is text", "{""Capacity"":""x""}"), $ListBuild("a null description", "{""Description"":null}") {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2))
        Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, tBody, .tResult, .tFault, ..#SOURCE, tSeam), "422 PORT.FIELD.SHAPE", $List(tCase, 1) _ ": the port refuses the edit by shape")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $ClassMethod(tFx, "RoleCount", ..#SOURCE), "held|20|1", "the held role is as it was and nothing was stored")
    Do $$$AssertEquals(..Put("ADDWORKFLOWROLE", ..#ROLEB, {"Description": ($Extract(tLong, 1, 2000)), "Capacity": 1}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "a description of 2,000 characters and a capacity of 1 are accepted")
    Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, {"Capacity": 100}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "and a capacity of 100")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA), "held|100", "which is stored as sent")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "no refusal logged a line")
}

/// <p>AC5: an add of a member to a role the namespace does not hold is 404; of a user who is no workflow user of it, held exactly, <code>INTEROP.WORKFLOW.MEMBERUSER</code> (422); of a user who is already
/// a member <code>INTEROP.WORKFLOW.MEMBERTAKEN</code> (409); a rank that is not a whole number from 1 to 5 is <code>MEMBERRANK</code> and a title over 128 characters or holding a control character
/// <code>MEMBERTITLE</code>; a remove of a user who is not a member is 404 though the vendor answers it as a success; each from the person's Save and row action, the agent's mint and the port, with nothing
/// stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowRankOK</method> allow 6 -- the rank row goes red; make <method>OcuPilot.Port.InteropPort.WorkflowMemberWriteToken</method> answer
/// no token for a non-member's remove -- the 404 rows go red.</p>
Method TestAMemberWriteTheNamespaceCannotMakeIsRefusedByName()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA), "a role is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 0), "a workflow user is stored, inactive so the engine sends it no task")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERB, "Bob", 0), "and a second")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERB, ..#SOURCE, 2, "held"), "which is a member")
    Set tAbsent = ..#ROLEB
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", tAbsent, ..#USERA, {}, .tResult, .tFault, ..#SOURCE, tSeam), "404 PORT.NOTFOUND", "an add to a role the namespace does not hold is 404")
    Do $$$AssertEquals(..SaveMember({"Role": (tAbsent), "User": (..#USERA)}, .tAnswer), "404 PORT.NOTFOUND", "from the Save too")
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", $ZConvert(..#ROLEA, "L"), ..#USERA, {}, .tResult, .tFault, ..#SOURCE, tSeam), "404 PORT.NOTFOUND", "and to a role named in another letter case")
    For tUser = "OcuP2417wNobody", $ZConvert(..#USERA, "L") {
        Set tCode = "INTEROP.WORKFLOW.MEMBERUSER"
        Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, tUser, {}, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tCode, "an add of '" _ tUser _ "' is refused by the port")
        Do $$$AssertEquals(..ReadMember(..#ROLEA, tUser, "ADDWORKFLOWMEMBER", .tRow, .tFault, ..#SOURCE, tSeam), "422 " _ tCode, "and by the read composed for an add")
        Do $$$AssertEquals(..SaveMember({"Role": (..#ROLEA), "User": (tUser)}, .tAnswer), "422 " _ tCode, "and by the Save")
        Do $$$AssertEquals(..MemberMintCode("Add", ..#ROLEA, tUser, {}, .tReason), tCode, "and at the agent's mint")
        Do $$$AssertEquals(tReason, ..Reason("WORKFLOWMEMBERUSER"), "with the published sentence")
    }
    Set tTaken = "INTEROP.WORKFLOW.MEMBERTAKEN"
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERB, {}, .tResult, .tFault, ..#SOURCE, tSeam), "409 " _ tTaken, "an add of a user who is already a member is refused by the port")
    Do $$$AssertEquals(..SaveMember({"Role": (..#ROLEA), "User": (..#USERB)}, .tAnswer), "409 " _ tTaken, "by the Save")
    Do $$$AssertEquals(..MemberMintCode("Add", ..#ROLEA, ..#USERB, {}, .tReason), tTaken, "and at the agent's mint")
    Set tRank = "INTEROP.WORKFLOW.MEMBERRANK"
    For tRankValue = 0, 6, 1.5, "x" {
        Set tBody = {"Ranking": (tRankValue)}
        If tRankValue = "x" Set tBody = {"Ranking": "x"}
        Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, tBody, .tResult, .tFault, ..#SOURCE, tSeam), "422 " _ tRank, "rank '" _ tRankValue _ "' is refused by the port")
        Do $$$AssertEquals(..SaveMember({"Role": (..#ROLEA), "User": (..#USERA), "Ranking": (tRankValue)}, .tAnswer), "422 " _ tRank, "and by the Save")
        Do $$$AssertEquals(..MemberMintCode("Add", ..#ROLEA, ..#USERA, tBody, .tReason), "TOOL.ARGUMENTS", "and at the agent's mint: " _ $Extract(tReason, 1, 120))
    }
    Set tLong = $Translate($Justify("", 129), " ", "t")
    For tTitle = tLong, "a" _ $Char(9) _ "b" {
        Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, {"Title": (tTitle)}, .tResult, .tFault, ..#SOURCE, tSeam), "422 INTEROP.WORKFLOW.MEMBERTITLE", "a title of " _ $Length(tTitle) _ " characters is refused by the port")
        Do $$$AssertEquals(..SaveMember({"Role": (..#ROLEA), "User": (..#USERA), "Title": (tTitle)}, .tAnswer), "422 INTEROP.WORKFLOW.MEMBERTITLE", "and by the Save")
    }
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, {"Title": 5}, .tResult, .tFault, ..#SOURCE, tSeam), "422 PORT.FIELD.SHAPE", "a title that is a number is refused by shape")
    Do $$$AssertEquals(..Facts(), "1|0", "nothing was stored: only the held member is there")
    For tMissing = $ListBuild(..#ROLEA, ..#USERA), $ListBuild(..#ROLEA, $ZConvert(..#USERB, "L")), $ListBuild(..#ROLEB, ..#USERB) {
        Do $$$AssertEquals(..PutMember("REMOVEWORKFLOWMEMBER", $List(tMissing, 1), $List(tMissing, 2), "", .tResult, .tFault, ..#SOURCE, tSeam), "404 PORT.NOTFOUND", "a remove of " _ $List(tMissing, 2) _ " from " _ $List(tMissing, 1) _ ", who is no member, is 404")
        Do $$$AssertEquals(..ActMember("remove", $List(tMissing, 1), $List(tMissing, 2), .tAnswer), "404 PORT.NOTFOUND", "the person's Remove is 404 too")
        Do $$$AssertEquals(..MemberMintCode("Remove", $List(tMissing, 1), $List(tMissing, 2), {}, .tReason), "TOOL.ARGUMENTS", "and the agent's remove is refused at the mint")
    }
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, {"Ranking": 5, "Title": ($Extract(tLong, 1, 128))}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "a rank of 5 and a title of 128 characters are accepted")
    Do $$$AssertEquals(..Text(..#USERA), "5|" _ $Extract(tLong, 1, 128), "and stored as sent")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "no refusal logged a line")
}

/// <p>The membership of <var>pUser</var> in the first probe role as <code>Ranking|Title</code> or <code>&lt;absent&gt;</code>.</p>
ClassMethod Text(pUser As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "MemberText", ..#SOURCE, ..#ROLEA, pUser)
}

/// <p>The first probe role's facts: <code>memberships|worklist items</code>.</p>
ClassMethod Facts() As %String
{
    Quit $Piece($ClassMethod(..#FIXTURE, "RoleFacts", ..#SOURCE, ..#ROLEA), "|", 1, 2)
}

/// <p>AC5: a namespace under source control refuses every workflow role and member write by <code>SOURCECONTROL</code> before the vendor is called, the composed reads of a write included, while the lists
/// stay readable. Driven through the port both callers reach, through a seam that answers the namespace's source control state.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.WorkflowWriteRefusal</method> -- every row goes red.</p>
Method TestASourceControlledNamespaceRefusesEveryWriteThroughTheSeam()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 0), "and a workflow user")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERA), "who is its member")
    Set ^IRIS.Temp.OcuProbe2417wMode("source") = 1
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery, "", ..#SOURCE, tSeam), "200 ", "the roles list is readable under source control")
    Set tRefusal = "409 INTEROP.WORKFLOW.SOURCECONTROL"
    For tWrite = $ListBuild("ADDWORKFLOWROLE", ..#ROLEB, "{}"), $ListBuild("SETWORKFLOWROLE", ..#ROLEA, "{""Description"":""x""}"), $ListBuild("REMOVEWORKFLOWROLE", ..#ROLEA, "") {
        Set tBody = $Select($List(tWrite, 3) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tWrite, 3)))
        Do $$$AssertEquals(..Put($List(tWrite, 1), $List(tWrite, 2), tBody, .tResult, .tFault, ..#SOURCE, tSeam), tRefusal, $List(tWrite, 1) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("WORKFLOWSOURCECONTROL"), "with the published sentence")
        Do $$$AssertEquals(..Read($List(tWrite, 2), $List(tWrite, 1), .tRow, .tFault, ..#SOURCE, tSeam), tRefusal, "the read composed for " _ $List(tWrite, 1) _ " is refused too")
    }
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, {}, .tResult, .tFault, ..#SOURCE, tSeam), tRefusal, "ADDWORKFLOWMEMBER is refused for source control")
    Do $$$AssertEquals(..PutMember("REMOVEWORKFLOWMEMBER", ..#ROLEA, ..#USERA, "", .tResult, .tFault, ..#SOURCE, tSeam), tRefusal, "and so is REMOVEWORKFLOWMEMBER")
    Do $$$AssertEquals(..ReadMember(..#ROLEA, ..#USERA, "REMOVEWORKFLOWMEMBER", .tRow, .tFault, ..#SOURCE, tSeam), tRefusal, "and the read composed for it")
    Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 0, "no vendor call was made")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $ClassMethod(tFx, "RoleCount", ..#SOURCE) _ "|" _ ..Text(..#USERA), "held|20|1|1|", "the held role and member are unchanged and nothing was added")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>AC5: with <code>USER</code> really under source control, every write a person or the agent makes is refused on the shipped path before anything is stored: the person's Save, Edit and Remove of a role
/// and Add member and Remove of a member over HTTP, and the agent's mint of each of the five tools by <code>SOURCECONTROL</code>; of an update and two removes minted while the namespace was not under
/// source control, the update's re-read, which asks for the edit, refuses and closes the proposal target-changed, and each remove is refused by the write.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.InteropWorkflowRoleUpdate.READASKSACTION</parameter> to 0 -- the confirmed update's leg goes red; drop the
/// <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.WorkflowWriteRefusal</method> -- every leg goes red.</p>
Method TestEveryShippedWritePathIsRefusedUnderSourceControl()
{
    Set tFx = ..#FIXTURE
    Set tReason = ..Reason("WORKFLOWSOURCECONTROL")
    Set tRefusal = "INTEROP.WORKFLOW.SOURCECONTROL"
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 0), "and a workflow user")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERB, "Bob", 0), "and a second")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERA), "who is a member of the role")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
    Kill tSettings
    Set tSettings("interop.workflowroles.remove") = "enabled"
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the role remove tool's key is turned on")
        Set tCode = ..Mint("Update", ..#ROLEA, {"Description": "changed"}, .tUpdateReason, .tUpdate, .tUpdateTurn)
        Do $$$AssertEquals(tCode, "minted", "a role update mints while the namespace is not under source control")
        Set tCode = ..Mint("Remove", ..#ROLEA, {}, .tRemoveReason, .tRemove, .tRemoveTurn)
        Do $$$AssertEquals(tCode, "minted", "and so does a role remove")
        Set tCode = ..MintMember("Remove", ..#ROLEA, ..#USERA, {}, .tMemberReason, .tMember, .tMemberTurn)
        Do $$$AssertEquals(tCode, "minted", "and a member remove")
        Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#SOURCE), ..#SOURCE _ " is put under source control")
        Do ..Save({"Name": (..#ROLEB)}, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ "|" _ tAnswer.reason, 1: ""), tRefusal _ "|" _ tReason, "the person's Save is refused with the published sentence")
        Do $$$AssertEquals(..Act("edit", ..#ROLEA, {"Description": "changed"}, .tAnswer), "409 " _ tRefusal, "and the person's Edit")
        Do $$$AssertEquals(..Act("remove", ..#ROLEA, "", .tAnswer), "409 " _ tRefusal, "and the person's Remove")
        Do $$$AssertEquals(..SaveMember({"Role": (..#ROLEA), "User": (..#USERB)}, .tAnswer), "409 " _ tRefusal, "the person's Add member")
        Do $$$AssertEquals(..ActMember("remove", ..#ROLEA, ..#USERA, .tAnswer), "409 " _ tRefusal, "and the person's member Remove")
        For tCase = $ListBuild("Add", ..#ROLEB, "{}"), $ListBuild("Update", ..#ROLEA, "{""Description"":""changed""}"), $ListBuild("Remove", ..#ROLEA, "{}") {
            Set tVerdict = ..MintCode($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), .tMintReason)
            Do $$$AssertEquals(tVerdict _ "|" _ tMintReason, tRefusal _ "|" _ tReason, "the agent's role " _ $List(tCase, 1) _ " is refused at the mint, and no card is made")
        }
        Set tVerdict = ..MemberMintCode("Add", ..#ROLEA, ..#USERB, {}, .tMintReason)
        Do $$$AssertEquals(tVerdict _ "|" _ tMintReason, tRefusal _ "|" _ tReason, "the agent's member add is refused at the mint")
        Set tWant("update") = "PROPOSAL.TARGETCHANGED"
        Set tWant("remove") = tRefusal
        Set tWant("member") = tRefusal
        For tKind = "update", "remove", "member" {
            Set tProposal = $Select(tKind = "update": $Get(tUpdate), tKind = "remove": $Get(tRemove), 1: $Get(tMember))
            Do $$$AssertTrue($IsObject(tProposal), "the " _ tKind _ " minted before is there to confirm")
            If '$IsObject(tProposal) Continue
            Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
            Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), tWant(tKind), "the " _ tKind _ " minted before is refused at the confirm: " _ $Extract($Get(tRaw), 1, 300))
        }
        Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#SOURCE), "the probe's source control is taken out of " _ ..#SOURCE)
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $ClassMethod(tFx, "RoleCount", ..#SOURCE) _ "|" _ ..Facts(), "held|20|1|1|0", "the held role and member are unchanged and nothing was added")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the source control leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn), $Get(tMemberTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

}
