/// <p>Pins Story 24.17 Batch 3b's reads (AD-5, AD-29, AD-36, AD-62): the Workflow roles list and its one-role read, and the Role members list of one role, through the port, the screens' read
/// route and the agent's read tools, which answer the same rows; the lists' caps and one over; and the refusals of a members read that names no role. The
/// probes are <code>EnsLib.Workflow.RoleDefinition</code>, <code>UserDefinition</code> and <code>RoleMembership</code> rows in <code>USER</code>, saved through the vendor's own calls.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs.</p>
Class OcuPilot.Test.InteropWorkflowRoleList Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

Parameter MEMBERENDPOINT = "WorkflowMembers";

/// <p>The probe users and roles.</p>
Parameter USERA = "OcuP2417wLa";

Parameter USERB = "OcuP2417wLb";

Parameter ROLEA = "OcuP2417wLra";

Parameter ROLEB = "OcuP2417wLrb";

/// <p>Store two probe users, one inactive, and two probe roles in <code>USER</code>: the first holds both users, with the ranks 2 and 4 and a title for the first; the second holds none.</p>
ClassMethod Arrange() As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#USERA, "Ada Lovelace", 1)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERB, "", 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "Alpha role", 40))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEB))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERA, ..#SOURCE, 2, "Lead"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERB, ..#SOURCE, 4, ""))
    Quit tSC
}

/// <p>The port's members list in <var>pNamespace</var> for the criterion <var>pRole</var>, with <var>pUser</var> sent under the name <code>user</code>, which the list does not take (each named only
/// when not empty), as <code>status code</code>, with the rows in <var>pRows</var>.</p>
ClassMethod Members(pRole As %String, pUser As %String, Output pRows, Output pFault, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}, pMax As %Integer = 0) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pRole '= "" Set tQuery("role") = pRole
    If pUser '= "" Set tQuery("user") = pUser
    If pMax > 0 Set tQuery("maxRows") = pMax
    Set tSC = $ClassMethod(pClass, "Invoke", ..#MEMBERENDPOINT, "LIST", .tQuery, "", .pRows, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The screens are declared as the plan places them: Workflow roles in the Interoperability area at side bar 26 with the role's name as its key, New workflow role as its primary action and Edit and
/// Remove as its row actions; Role members unlisted, a sub-resource of the roles with the one criterion <code>role</code>, keyed by <code>[Role, User]</code>, with Add member and Remove; each over
/// <code>%Ens_WorkflowConfig:READ</code>, naming the classic page it replaces and declaring no secret.</p>
/// <p>Mutation (Rule 19): change the roles screen's <code>sideBarPosition</code> to 25 -- this goes red.</p>
Method TestTheDeclarationsRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowRoleList).DeclarationJson(.tRole)
    Do $$$AssertStatusOK(tSC, "the roles screen declares JSON")
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowMemberList).DeclarationJson(.tMember)
    Do $$$AssertStatusOK(tSC, "and so does the members screen")
    If '$IsObject($Get(tRole)) || '$IsObject($Get(tMember)) Quit
    Do $$$AssertEquals(tRole.route _ "|" _ tRole.sideBarPosition _ "|" _ tRole.archetype _ "|" _ tRole.area, "interoperability/workflow-roles|26|list|interoperability", "the roles' route, place, archetype and area")
    Do $$$AssertEquals(tRole.entityType _ "|" _ tRole.id.kind _ "|" _ tRole.id.parts.%ToJSON() _ "|" _ tRole.toolIdentifier, "interop-workflow-role|composite|[""Name""]|interop.workflowroles", "their entity type, key and tool identifier")
    Do $$$AssertEquals(tRole.primaryAction.id _ "|" _ tRole.rowActions.%Get(0).id _ "," _ tRole.rowActions.%Get(1).id, "add|edit,remove", "their actions")
    Do $$$AssertEquals(tMember.route _ "|" _ tMember.sideBarPosition _ "|" _ tMember.parentScope _ "|" _ tMember.area, "interoperability/workflow-roles/members|0|interoperability/workflow-roles|interoperability", "the members' route, place and parent")
    Do $$$AssertEquals(tMember.entityType _ "|" _ tMember.id.kind _ "|" _ tMember.id.parts.%ToJSON() _ "|" _ tMember.toolIdentifier, "interop-workflow-member|composite|[""Role"",""User""]|interop.workflowmembers", "their entity type, key and tool identifier")
    Do $$$AssertEquals(tMember.primaryAction.id _ "|" _ tMember.rowActions.%Get(0).id _ "|" _ tMember.rowActions.%Size(), "add|remove|1", "their actions: add and remove, no edit")
    Do $$$AssertEquals(tMember.read.criteria.fields.%Size() _ "|" _ tMember.read.criteria.fields.%Get(0).param, "1|role", "and the one criterion the route id fills")
    Do $$$AssertEquals(tRole.classicPage _ "|" _ tMember.classicPage _ "|" _ tRole.context.secretFields.%ToJSON() _ "|" _ tMember.context.secretFields.%ToJSON(), "EnsPortal.WFRoles|EnsPortal.WFRoles|[]|[]", "the classic page and no secret field")
    Do $$$AssertEquals(tRole.privileges.%ToJSON() _ tMember.privileges.%ToJSON(), tRole.privileges.%ToJSON() _ "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_WorkflowConfig"",""permission"":""READ""}]", "their pairs are the classic page's")
    Do $$$AssertTrue(($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#ENDPOINT) > 0) && ($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#MEMBERENDPOINT) > 0), "the port serves both endpoints")
}

/// <p>AC1: the roles list answers every probe of the namespace by name, with its description, capacity, member count and namespace; another namespace's roles are not listed; and the one-role read
/// answers the same fields for the exact name and 404 for any other spelling.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowRoles</method> read <code>Members</code> as 0 -- this goes red.</p>
Method TestTheRolesListAnswersEveryProbeByNameWithItsFacts()
{
    Do $$$AssertStatusOK(..Arrange(), "two users and two roles are stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeRole", "OcuP2417wLrz", ..#OTHER, "elsewhere", 7), "and a role in HSCUSTOM alone")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery), "200 ", "the list answers 200")
    Do $$$AssertEquals(..Names(tRows), ..#ROLEA _ "," _ ..#ROLEB, "exactly the probes of USER, by name")
    If '$IsObject($Get(tRows)) Quit
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ tRow.Description _ "|" _ tRow.Capacity _ "|" _ tRow.Members _ "|" _ tRow.Namespace _ ";"
    }
    Do $$$AssertEquals(tText, "Alpha role|40|2|USER;|100|0|USER;", "each row carries its description, capacity, member count and namespace")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tOther, .tFault, .tQuery, "", ..#OTHER), "200 ", "HSCUSTOM's list answers 200")
    Do $$$AssertEquals(..Names(tOther), "OcuP2417wLrz", "and holds its own probe alone")
    Set tOne = ..Read(..#ROLEA, "", .tRow, .tFault)
    Do $$$AssertEquals(tOne _ "|" _ tRow.Name _ "|" _ tRow.Description _ "|" _ tRow.Capacity _ "|" _ tRow.Members _ "|" _ tRow.Namespace, "200 |" _ ..#ROLEA _ "|Alpha role|40|2|USER", "the one-role read answers the same fields")
    Do $$$AssertEquals(..Read($ZConvert(..#ROLEA, "L"), "", .tRow, .tFault), "404 PORT.NOTFOUND", "a name in another letter case is not held")
    Do $$$AssertEquals(..Read("OcuP2417wNobody", "", .tRow, .tFault), "404 PORT.NOTFOUND", "and a name no one holds")
}

/// <p>AC1: the members list answers one role's members by user name, each row with the role, user, the user's full name, rank, title, active state and namespace, and none of another role's
/// members; a call that names no role, or a role name this port does not read, is 400 <code>PORT.VALIDATION</code>, and the list takes no <code>user</code> criterion; and a role with no members answers an empty list.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowMembers</method> read the members of every role whose name sorts at or after the one named -- the third-role leg goes
/// red.</p>
Method TestTheMembersListAnswersOneRolesMembersAndRefusesTheOtherCalls()
{
    Do $$$AssertStatusOK(..Arrange(), "two users and two roles are stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeRole", ..#ROLEB _ "x"), "and a third role")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLEB _ "x", ..#USERA, ..#SOURCE, 5, "Boss"), "which the first user also joins")
    Do $$$AssertEquals(..Members(..#ROLEA, "", .tRows, .tFault), "200 ", "the members of the first role answer 200")
    Do $$$AssertEquals(..Names(tRows, "User"), ..#USERA _ "," _ ..#USERB, "its two members, by user name")
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ tRow.Role _ "|" _ tRow.FullName _ "|" _ tRow.Ranking _ "|" _ tRow.Title _ "|" _ tRow.IsActive _ "|" _ tRow.Namespace _ ";"
    }
    Do $$$AssertEquals(tText, ..#ROLEA _ "|Ada Lovelace|2|Lead|1|USER;" _ ..#ROLEA _ "||4||0|USER;", "each row carries its role, full name, rank, title, active state and namespace")
    Do $$$AssertEquals(..Members(..#ROLEB _ "x", "", .tRows, .tFault) _ "|" _ ..Names(tRows, "User"), "200 |" _ ..#USERA, "the third role's one member, and not the first role's")
    Do $$$AssertEquals(..Members(..#ROLEB, "", .tRows, .tFault) _ "|" _ tRows.%Size(), "200 |0", "a role with no members answers an empty list")
    Do $$$AssertEquals(..Members("", "", .tRows, .tFault), "400 PORT.VALIDATION", "a call that names no role is refused")
    Do $$$AssertEquals(..Members("", ..#USERA, .tRows, .tFault), "400 PORT.VALIDATION", "and so is one that names a user alone: the list takes no user criterion")
    Do $$$AssertEquals(..Members($Translate($Justify("", 129), " ", "x"), "", .tRows, .tFault), "400 PORT.VALIDATION", "and a role name of 129 characters")
    Do $$$AssertEquals(..Members("a" _ $Char(9) _ "b", "", .tRows, .tFault), "400 PORT.VALIDATION", "and a role name holding a control character")
    Do $$$AssertEquals(..Members($ZConvert(..#ROLEA, "L"), "", .tRows, .tFault) _ "|" _ tRows.%Size(), "200 |0", "a role name in another letter case holds no members")
    Kill tQuery
    Set tQuery("maxRows") = "0"
    Do $$$AssertEquals(..Verdict("LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "a cap that is not a whole number above zero is refused by name")
}

/// <p>AC1: the screens' read route and the agent's read tools answer the rows the port answers: the roles list through the roles screen's route and <code>interop.workflowroles.read</code>, and one
/// role's members through the members screen's route with its <code>role</code> criterion and <code>interop.workflowmembers.read</code>.</p>
/// <p>Mutation (Rule 19): rename the <code>Members</code> field in <class>OcuPilot.Screen.Descriptor.InteropWorkflowRoleList</class>'s read -- the route and the tool answer no count and this goes red.</p>
Method TestTheReadRoutesAndTheReadToolsAnswerTheSameRows()
{
    Do $$$AssertStatusOK(..Arrange(), "two users and two roles are stored")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    Kill tQuery
    Do ..Verdict("LIST", .tPortRoles, .tPortFault, .tQuery)
    Do ..Members(..#ROLEA, "", .tPortMembers, .tPortFault)
    Set tRoleClass = "OcuPilot.Screen.Descriptor.InteropWorkflowRoleList"
    Set tMemberClass = "OcuPilot.Screen.Descriptor.InteropWorkflowMemberList"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tRoleClass, 1000, .tRoleAnswer, .tRoleHttp, .tRoleFault, .tNone)
    Set tCriteria("role") = ..#ROLEA
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tMemberClass, 1000, .tMemberAnswer, .tMemberHttp, .tMemberFault, .tCriteria)
    Do $$$AssertEquals(tRoleHttp _ "|" _ tMemberHttp, "200|200", "both routes answer")
    Set tToolHttp = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tRoleClass, "ToolIdentifier") _ ".read", .tRoleTool)
    Do $$$AssertTrue($IsObject($Get(tRoleTool)), "interop.workflowroles.read is a registered read tool")
    If $IsObject($Get(tRoleTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tRoleTool, {}, 1000, .tRoleResult, .tToolHttp, .tToolFault)
    Set tMemberHttp = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tMemberClass, "ToolIdentifier") _ ".read", .tMemberTool)
    Do $$$AssertTrue($IsObject($Get(tMemberTool)), "interop.workflowmembers.read is a registered read tool")
    If $IsObject($Get(tMemberTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tMemberTool, {"role": (..#ROLEA)}, 1000, .tMemberResult, .tMemberHttp, .tMemberToolFault)
    Do $$$AssertEquals(tToolHttp _ "|" _ tMemberHttp, "200|200", "and both tools")
    If '$IsObject($Get(tRoleAnswer)) || '$IsObject($Get(tRoleResult)) || '$IsObject($Get(tMemberAnswer)) || '$IsObject($Get(tMemberResult)) Quit
    Do $$$AssertEquals(tPortRoles.%Size() _ "|" _ tPortMembers.%Size(), "2|2", "the port answers the two roles and the first role's two members")
    Do $$$AssertEquals(..Canon(tRoleAnswer.rows, "Name,Description,Capacity,Members"), ..Canon(tPortRoles, "Name,Description,Capacity,Members"), "the roles route's rows are the port's")
    Do $$$AssertEquals(..Canon(tRoleResult.rows, "Name,Description,Capacity,Members"), ..Canon(tPortRoles, "Name,Description,Capacity,Members"), "and so are the roles tool's")
    Do $$$AssertEquals(..Canon(tMemberAnswer.rows, "Role,User,FullName,Ranking,Title,IsActive"), ..Canon(tPortMembers, "Role,User,FullName,Ranking,Title,IsActive"), "the members route's rows are the port's")
    Do $$$AssertEquals(..Canon(tMemberResult.rows, "Role,User,FullName,Ranking,Title,IsActive"), ..Canon(tPortMembers, "Role,User,FullName,Ranking,Title,IsActive"), "and so are the members tool's")
}

/// <p><var>pRows</var> reduced to the named fields, one line for each row, in order.</p>
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

/// <p>AC1: both lists are cut at a named limit when the caller names no cap, and truncation is the caller's to read from the row it asks for beyond its own cap: three roles at the limit of three
/// are all listed and a fourth one over answers the limit; three members of one role the same; a caller that asks for one row beyond a cap is answered it, and one that asks for fewer gets fewer.
/// The shipped limits are 10,000 each, measured.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowCap</method> answer no more than <var>pLimit</var> -- the row asked for beyond the cap is lost and this goes red.</p>
Method TestBothListsStopAtTheirNamedLimit()
{
    Set tCap = ..#CAPSEAM
    Do $$$AssertEquals($Parameter(..#PORT, "WORKFLOWROLESMAX") _ "|" _ $Parameter(..#PORT, "WORKFLOWMEMBERSMAX"), "10000|10000", "the shipped limits are 10,000 roles and 10,000 members")
    Do $$$AssertEquals($Parameter(tCap, "WORKFLOWROLESMAX") _ "|" _ $Parameter(tCap, "WORKFLOWMEMBERSMAX"), "3|3", "the seam lowers both to three")
    Set tFx = ..#FIXTURE
    For tI = 1:1:3 {
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", "OcuP2417wLc" _ tI), "probe role " _ tI _ " is stored")
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", "OcuP2417wLu" _ tI, "user " _ tI), "probe user " _ tI _ " is stored")
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", "OcuP2417wLc1", "OcuP2417wLu" _ tI), "and joins the first role")
    }
    Kill tQuery
    Do ..Verdict("LIST", .tAt, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tAt), "OcuP2417wLc1,OcuP2417wLc2,OcuP2417wLc3", "three roles at the limit: all three")
    Do $$$AssertEquals(..Members("OcuP2417wLc1", "", .tMembersAt, .tFault, ..#SOURCE, tCap), "200 ", "three members at the limit answer 200")
    Do $$$AssertEquals(..Names(tMembersAt, "User"), "OcuP2417wLu1,OcuP2417wLu2,OcuP2417wLu3", "all three")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", "OcuP2417wLc4"), "a fourth role is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", "OcuP2417wLu4", "user 4"), "and a fourth user")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", "OcuP2417wLc1", "OcuP2417wLu4"), "who joins the first role")
    Kill tQuery
    Do ..Verdict("LIST", .tOver, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tOver), "OcuP2417wLc1,OcuP2417wLc2,OcuP2417wLc3", "four roles, one over: the limit, the first three by name")
    Do ..Members("OcuP2417wLc1", "", .tMembersOver, .tFault, ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tMembersOver, "User"), "OcuP2417wLu1,OcuP2417wLu2,OcuP2417wLu3", "four members, one over: the limit, the first three by user name")
    Kill tQuery
    Set tQuery("maxRows") = 4
    Do ..Verdict("LIST", .tAsked, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAsked)): tAsked.%Size(), 1: -1), 4, "a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
    Do ..Members("OcuP2417wLc1", "", .tMembersAsked, .tFault, ..#SOURCE, tCap, 4)
    Do $$$AssertEquals($Select($IsObject($Get(tMembersAsked)): tMembersAsked.%Size(), 1: -1), 4, "and so does a members reader")
    Kill tQuery
    Set tQuery("maxRows") = 2
    Do ..Verdict("LIST", .tFewer, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tFewer)): tFewer.%Size(), 1: -1), 2, "one that asks for fewer roles gets fewer")
    Do ..Members("OcuP2417wLc1", "", .tMembersFewer, .tFault, ..#SOURCE, tCap, 2)
    Do $$$AssertEquals($Select($IsObject($Get(tMembersFewer)): tMembersFewer.%Size(), 1: -1), 2, "and fewer members")
}

}
