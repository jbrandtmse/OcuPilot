/// <p>Pins the role editor's Save and its actions (Story 9.3, AD-4, AD-10, AD-12, AD-39, AD-55,
/// AD-56): <code>PUT /roles/:id</code> and the form read's <code>role</code>, <code>members</code>
/// and <code>holders</code> over a real HTTP request; a two-field Save that sends the complete set and
/// leaves the grants as they were; the grant lists refused on the Save; the edit's field rules; one of
/// OcuPilot's own roles refused a grant change; the role census on a Save, a change and a delete; and
/// the Roles list's four value actions applied as deltas over a real request.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes three roles, a resource and three accounts by exact name.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.RoleSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter EDITPATH = "/roles/:id";

Parameter FORMPATH = "/roles/form";

Parameter ACTIONPATH = "/screens/permissions.roles/action";

Parameter SAVE = "OcuPilot.Test.RoleSaveFixture";

/// <p>The Save whose port records a <code>PUT</code> and never sends it, and whose prohibited set's
/// census input is armed in this process.</p>
Parameter HELDSAVE = "OcuPilot.Test.RoleSaveHeldFixture";

Parameter PORT = "OcuPilot.Test.DeviceRecordPort";

Parameter RULES = "OcuPilot.Area.Permissions.RoleCreateRules";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter UPDATETOOL = "permissions.roles.update";

Parameter DELETETOOL = "permissions.roles.delete";

/// <p>The role every edit leg changes, granting <code>%Development:U</code> and
/// <code>%Developer</code>.</p>
Parameter PROBEROLE = "OcuPilotProbeRoleSave";

/// <p>A role that holds <parameter>PROBEROLE</parameter>, and an account that does.</p>
Parameter MEMBERROLE = "OcuPilotProbeRoleSaveMember";

Parameter MEMBERUSER = "OcuPilotProbeRoleSaveUser";

/// <p>An account holding <parameter>PROBEROLE</parameter> only as an escalation role;
/// <parameter>MEMBERUSER</parameter> holds it both ways.</p>
Parameter ESCALATIONUSER = "OcuPilotProbeRoleSaveEscalation";

/// <p>The census leg's role, granting <code>%All</code>, and the one account holding it.</p>
Parameter PATHROLE = "OcuPilotProbeRoleSavePath";

Parameter HOLDERUSER = "OcuPilotProbeRoleSaveHolder";

/// <p>The resource the screen's resource Delete removes over the wire.</p>
Parameter PROBERESOURCE = "OcuPilotProbeRoleSaveResource";

Parameter RESOURCEACTIONPATH = "/screens/permissions.resources/action";

/// <p>The description every probe role and the comment every probe account is created with, which
/// is how each is recognised as this class's own before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot role save probe";

Parameter PROBEPASSWORD = "OcuPilotRoleSaveProbe9Aa";

/// <p>How many top-level properties the vendor's <code>Security.Role</code> <code>GET</code> answers
/// on this build, measured.</p>
Parameter PROPERTYCOUNT As %Integer = 4;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoleSave creates and deletes roles and accounts on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbes()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbes()
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Quit ..EnsureProbes()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder("")
    Do $ClassMethod(..#SETFIXTURE, "ArmDirectRoles", "")
    Do ..StripProbeFromOwnRoles()
    Quit $$$OK
}

/// <p>AD-12, AD-39: the Save and the form read each answer exactly one JSON envelope over a real
/// HTTP request. A Save that changes nothing is 200 <code>{name}</code>; the form read with a name
/// carries the role's four properties and its name, its members -- accounts, escalation holders and
/// a role -- and <code>holders</code>, the distinct accounts among them, 2; both answer 404 <code>ROLE.NAME.ABSENT</code> for a role the instance does
/// not hold.</p>
/// <p>Mutation (Rule 19): drop the distinct-name check from
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.Members</method> -- the holders leg reads 3 and
/// goes red.</p>
Method TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEROLE), .tStatus, .tBody, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the Save completes")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""), "{""name"":""" _ ..#PROBEROLE _ """}", "answering the role's name")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#PROBEROLE), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "{}", "application/json")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tRaw [ "}{"), 0, "and exactly one envelope")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..#PROBEROLE, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read of the role answers 200")
    Set tRole = $Select($IsObject($Get(tBody)): tBody.%Get("role"), 1: "")
    Do $$$AssertTrue($IsObject(tRole), "carrying the role")
    If $IsObject(tRole) {
        Do $$$AssertEquals(tRole.%Get("Name"), ..#PROBEROLE, "by its name")
        Do $$$AssertEquals(..Count(tRole), ..#PROPERTYCOUNT + 1, "with every property the vendor's read answers")
        Do $$$AssertEquals(tRole.%Get("Description"), ..#PROBEMARKER, "as the instance holds them")
        Do $$$AssertEquals(tRole.%GetTypeOf("EscalationOnly"), "boolean", "the escalation flag a boolean")
    }
    Set tMembers = $Select($IsObject($Get(tBody)): tBody.%Get("members"), 1: "")
    Do $$$AssertTrue($IsObject(tMembers) && tMembers.%IsA("%Library.DynamicArray"), "the members are a list")
    Set tSeen = ""
    If $IsObject(tMembers) {
        Set tIterator = tMembers.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tSeen = tSeen _ $ListBuild(tRow.%Get("Name") _ "/" _ tRow.%Get("Type"))
        }
    }
    Do $$$AssertTrue($ListFind(tSeen, ..#MEMBERUSER _ "/User") > 0, "naming the account member: " _ $ListToString(tSeen))
    Do $$$AssertTrue($ListFind(tSeen, ..#MEMBERROLE _ "/Role") > 0, "and the role member")
    Do $$$AssertTrue($ListFind(tSeen, ..#MEMBERUSER _ "/User (escalation)") > 0, "the account holding it both ways is listed both ways")
    Do $$$AssertTrue($ListFind(tSeen, ..#ESCALATIONUSER _ "/User (escalation)") > 0, "and the escalation-only holder once")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("holders"), 1: ""), 2, "and holders counts the two distinct accounts, an escalation holder among them")

    For tPath = ..Path("OcuPilotNoSuchRoleSave"), ..#FORMPATH _ "?name=OcuPilotNoSuchRoleSave" {
        Set tMethod = $Select(tPath [ "form": "GET", 1: "PUT")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest(tMethod, tPath, .tStatus, .tBody, $Select(tMethod = "PUT": "{""Description"":""x""}", 1: ""), $Select(tMethod = "PUT": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#ROLENAMEABSENT, tMethod _ " of an absent role is 404 on its own code")
    }
}

/// <p>AD-4: a Save of <code>Description</code> and <code>EscalationOnly</code> sends the complete
/// four-property set, the grants and granted roles exactly as the fresh read answered them, and
/// afterwards both lists read back unchanged while the two read back as saved.</p>
/// <p>Mutation (Rule 19): merge over <code>{Name}</code> instead of the fresh read in
/// <method>OcuPilot.Area.Permissions.RoleSave.Update</method> -- the four-key and survival legs go
/// red.</p>
Method TestATwoFieldSaveSendsTheCompleteSetAndTheGrantsSurvive()
{
    Set tName = ..#PROBEROLE
    Do $$$AssertStatusOK(..Fresh(tName, .tBefore), "the role reads fresh")
    If '$IsObject($Get(tBefore)) Quit
    Do $$$AssertEquals(..Count(tBefore), ..#PROPERTYCOUNT, "the vendor's read answers four properties")
    Set tSC = $ClassMethod(..#SAVE, "Update", tName, {"Description": (..#PROBEMARKER _ " saved"), "EscalationOnly": true}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the two-field Save succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 1, "one write was sent")
    Do $$$AssertEquals($ClassMethod(..#PORT, "LastType"), "PUT", "the vendor's PUT")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#PORT, "LastWriteBody"))
    Do $$$AssertEquals(..Count(tSent), ..#PROPERTYCOUNT, "carrying all four properties")
    Do $$$AssertStatusOK(..Fresh(tName, .tAfter), "the role reads back")
    If '$IsObject($Get(tAfter)) Quit
    For tKey = "GrantedRoles", "Resources" {
        Set tWas = ..Rendered(tBefore, tKey)
        Do $$$AssertEquals(..Rendered(tSent, tKey), tWas, tKey _ " was sent as the fresh read held it")
        Do $$$AssertEquals(..Rendered(tAfter, tKey), tWas, tKey _ " survives the Save")
    }
    Do $$$AssertEquals(tAfter.%Get("Description"), ..#PROBEMARKER _ " saved", "and the description reads back as saved")
    Do $$$AssertEquals(..Rendered(tAfter, "EscalationOnly"), "true", "as does the escalation flag")
}

/// <p>AD-56 (ii): a Save carrying <code>GrantedRoles</code>, <code>Resources</code> or
/// <code>Name</code> -- a <code>%All</code> grant among them -- is 400
/// <code>PORT.FIELD.UNEXPECTED</code> naming the key, and nothing is sent. Over the wire the
/// same.</p>
/// <p>Mutation (Rule 19): admit <code>SettableFields</code> rather than <code>PermittedFields</code>
/// in <method>OcuPilot.Area.Permissions.RoleSave.Update</method> -- the grant legs go red.</p>
Method TestTheUndeclaredKeysAreRefusedAndNothingIsSent()
{
    For tCase = $ListBuild("GrantedRoles", "[""%All""]"), $ListBuild("Resources", "[{""Name"":""%DB_USER"",""Permissions"":""RW""}]"), $ListBuild("Name", """OcuPilotProbeRenamed""") {
        Set tKey = $List(tCase, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON("{""Description"":""probe"",""" _ tKey _ """:" _ $List(tCase, 2) _ "}")
        Do $ClassMethod(..#PORT, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEROLE, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusNotOK(tSC, tKey _ " is refused")
        Do $$$AssertEquals(tHttp, 400, tKey _ ": at 400")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tKey _ ": as an unexpected field")
        Set tRows = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.violations, 1: "")
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 1) && (tRows.%Get(0).field = tKey), tKey _ ": named in detail.violations")
        Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, tKey _ ": and nothing is sent")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEROLE), .tStatus, .tBody, "{""GrantedRoles"":[""%All""]}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "over the wire a granted-role change is 400 too")
    Do $$$AssertStatusOK(..Fresh(..#PROBEROLE, .tAfter), "the role reads back")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): ..Rendered(tAfter, "GrantedRoles"), 1: ""), "[""%Developer""]", "granting only what it was created with")
}

/// <p>AD-39: a non-boolean <code>EscalationOnly</code> is 422 on its own code, and an over-long
/// description on its own; a refused Save sends nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>EscalationOnly</code> rule from
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.Validate</method> -- the flag legs go red.</p>
Method TestTheEditsFieldRulesRefuseEachFieldWithItsCode()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEROLE, .tFresh), "the role reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tLong = $Translate($Justify("", $Parameter(..#RULES, "DESCRIPTIONMAXLENGTH") + 1), " ", "x")
    For tCase = $ListBuild("{""EscalationOnly"":""yes""}", "EscalationOnly", "ROLEESCALATIONONLYSHAPE"), $ListBuild("{""EscalationOnly"":2}", "EscalationOnly", "ROLEESCALATIONONLYSHAPE"), $ListBuild("{""Description"":""" _ tLong _ """}", "Description", "ROLEDESCRIPTIONLENGTH") {
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 1))
        Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBEROLE, $ClassMethod(..#RULES, "Changed", tArgs, tFresh), .tViolations, 0, 0, "update", tFresh)
        Do $$$AssertStatusOK(tSC, "the rules answer for " _ $Extract($List(tCase, 1), 1, 40))
        Set tGot = $Select(+$Get(tViolations) > 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: "")
        Do $$$AssertEquals(tGot, $List(tCase, 2) _ " " _ $Parameter("OcuPilot.Api.Error", $List(tCase, 3)), $Extract($List(tCase, 1), 1, 40) _ " is refused on its field")
    }
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEROLE, {"EscalationOnly": "yes"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 1, "a Save with a non-boolean flag carries one violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and sends nothing")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEROLE), .tStatus, .tBody, "{""EscalationOnly"":""yes""}", "application/json")
    Set tRow = $Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("detail") = "object"): tBody.detail.violations.%Get(0), 1: "")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRow): tRow.field _ " " _ tRow.code, 1: ""), "422 EscalationOnly " _ ##class(OcuPilot.Api.Error).#ROLEESCALATIONONLYSHAPE, "over the wire at 422 on the flag")
}

/// <p>AD-10 as amended 2026-09-24: a change to what one of OcuPilot's own roles grants -- its
/// escalation flag on a Save, its resource grants or granted roles on a change -- is 403
/// <code>PROHIBITED.OCUPILOTROLE</code> before the port, while its description passes the set.
/// Over the wire, a granted-role action on it is refused the same, with the published
/// sentence.</p>
/// <p>Mutation (Rule 19): delete the own-role arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Role</method> for a change -- the Save, change and
/// action legs go red.</p>
Method TestOcuPilotsOwnRoleIsRefusedAGrantChangeButNotItsDescription()
{
    Set tSC = $ClassMethod(..#SET, "OcuPilotRoles", .tOwn)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own roles are read")
    Do $$$AssertTrue($ListLength($Get(tOwn)) > 0, "and there is at least one")
    If '$ListLength($Get(tOwn)) Quit
    Set tRole = $List(tOwn, $ListLength(tOwn))
    Do $$$AssertStatusOK(..Fresh(tRole, .tFresh), tRole _ " reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", tRole, {"EscalationOnly": true}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "OCUPILOTROLE"), "the Save of its escalation flag is refused as OcuPilot's own")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "OCUPILOTROLEREASON"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and nothing is sent")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", tRole, {"Description": "probe"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter("OcuPilot.Test.HeldPutPort", "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, "its description passes the set and reaches the held port")
    For tField = "Resources", "GrantedRoles" {
        Set tPayload = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
        Do tPayload.%Set(tField, $Select(tField = "Resources": [{"Name": "%DB_USER", "Permissions": "R"}], 1: ["%Developer"]))
        Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff(tField), tRole, "role", .tProhibits, .tCode, ..#UPDATETOOL)
        Do $$$AssertEquals(tCode, $Parameter(..#SET, "OCUPILOTROLE"), "a change to its " _ tField _ " is refused as OcuPilot's own")
    }
    Set tSC = ..Act("add-granted-role", tRole, {"Role": (..#MEMBERROLE)}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "403 " _ $Parameter(..#SET, "OCUPILOTROLE"), "over the wire the granted-role action is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("reason"), 1: ""), $Parameter(..#SET, "OCUPILOTROLEREASON"), "with the same sentence")
}

/// <p>AD-10 as amended 2026-09-24, the census: the one account holding <code>%All</code> holds it
/// only through <parameter>PATHROLE</parameter>, so setting that role escalation-only on a Save,
/// taking <code>%All</code> from its granted roles, and deleting it are each 403
/// <code>PROHIBITED.LASTALLHOLDER</code>; the same change stripping <code>_SYSTEM</code>'s
/// <code>%All</code> through the role is 403 <code>PROHIBITED.SYSTEMACCOUNT</code>; and a change
/// that keeps <code>%All</code> is not refused. Only the census's inputs are armed.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Kernel.Proposal.Prohibited.ChangeStripsAll</method>
/// answer <code>""</code> for a change -- the Save, change and <code>_SYSTEM</code> legs go red.</p>
Method TestTheCensusRefusesAChangeOrDeleteThatStripsAll()
{
    Do $$$AssertStatusOK(..Fresh(..#PATHROLE, .tFresh), "the path role reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders(..#HOLDERUSER)
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", ..#PATHROLE, {"EscalationOnly": true}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "LASTALLHOLDER"), "setting the role escalation-only on a Save is refused")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and nothing is sent")

    Set tStrip = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
    Do tStrip.%Set("GrantedRoles", [])
    Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tStrip.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("GrantedRoles"), ..#PATHROLE, "role", .tProhibits, .tCode, ..#UPDATETOOL)
    Do $$$AssertStatusOK(tSC, "the set answers the change")
    Do $$$AssertEquals(tCode, $Parameter(..#SET, "LASTALLHOLDER"), "taking %All from its granted roles is refused")
    Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tFresh.%ToJSON(), "[]", ..#PATHROLE, "role", .tProhibits, .tCode, ..#DELETETOOL)
    Do $$$AssertEquals(tCode, $Parameter(..#SET, "LASTALLHOLDER"), "and so is deleting the role")

    Set tKeep = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
    Do tKeep.%Set("GrantedRoles", ["%All", "%Developer"])
    Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tKeep.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("GrantedRoles"), ..#PATHROLE, "role", .tProhibits, .tCode, ..#UPDATETOOL)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "a change that keeps %All is not refused")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders(..#HOLDERUSER _ ",_SYSTEM")
    Do $ClassMethod(..#SETFIXTURE, "ArmDirectRoles", "_SYSTEM", ..#PATHROLE)
    Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tStrip.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("GrantedRoles"), ..#PATHROLE, "role", .tProhibits, .tCode, ..#UPDATETOOL)
    Do $$$AssertEquals(tCode, $Parameter(..#SET, "SYSTEMACCOUNT"), "the same change through _SYSTEM's role is refused as _SYSTEM's")
    Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tFresh.%ToJSON(), "[]", ..#PATHROLE, "role", .tProhibits, .tCode, ..#DELETETOOL)
    Do $$$AssertEquals(tCode, $Parameter(..#SET, "SYSTEMACCOUNT"), "and so is the delete, _SYSTEM checked first")
}

/// <p>AD-56 (ii): each of the Roles list's value actions is applied over a real request as a delta
/// over the fresh read -- a grant added, its letters replaced, removed; a granted role added and
/// removed -- and the role's other grants and granted roles survive each. An unknown resource, a
/// grant its resource does not admit, a grant not held, a grant restated, a role already granted
/// and an unknown role are 400
/// <code>TOOL.ARGUMENTS</code> with nothing changed.</p>
/// <p>Mutation (Rule 19): build the <code>set-resource-grant</code> list from an empty array
/// instead of the fresh read in <method>OcuPilot.Screen.Tool.RoleUpdate.ScreenActionDelta</method>
/// -- the survival legs go red.</p>
Method TestTheValueActionsAreDeltasOverTheFreshRead()
{
    Set tName = ..#PROBEROLE
    Set tSC = ..Act("set-resource-grant", tName, {"Resource": "%DB_USER", "Permissions": "RW"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a grant is added")
    Do $$$AssertEquals(..Grants(tName), "%DB_USER:RW,%Development:U", "beside the grant the role held")
    Set tSC = ..Act("set-resource-grant", tName, {"Resource": "%db_user", "Permissions": "R"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its letters are replaced, the name matched in any case")
    Do $$$AssertEquals(..Grants(tName), "%DB_USER:R,%Development:U", "RW becoming R")
    Set tSC = ..Act("remove-resource-grant", tName, {"Resource": "%DB_USER"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and it is removed")
    Do $$$AssertEquals(..Grants(tName), "%Development:U", "leaving the other grant")

    Set tSC = ..Act("add-granted-role", tName, {"Role": "%SQL"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a granted role is added")
    Do $$$AssertStatusOK(..Fresh(tName, .tFresh), "the role reads back")
    Do $$$AssertEquals(..Rendered(tFresh, "GrantedRoles"), "[""%Developer"",""%SQL""]", "beside the one it granted")
    Set tSC = ..Act("remove-granted-role", tName, {"Role": "%Developer"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and one is removed")
    Do $$$AssertStatusOK(..Fresh(tName, .tFresh), "the role reads back")
    Do $$$AssertEquals(..Rendered(tFresh, "GrantedRoles"), "[""%SQL""]", "leaving the other")

    ; Each case's values are JSON text: a $List would lose the object (objectscript-basics.md).
    For tCase = $ListBuild("set-resource-grant", "{""Resource"":""OcuPilotNoSuchResource"",""Permissions"":""U""}", "no resource"), $ListBuild("set-resource-grant", "{""Resource"":""%DB_USER"",""Permissions"":""U""}", ##class(OcuPilot.Api.Error).#REASONROLERESOURCESPERMISSIONS), $ListBuild("remove-resource-grant", "{""Resource"":""%DB_USER""}", "does not grant"), $ListBuild("add-granted-role", "{""Role"":""%SQL""}", "already grants"), $ListBuild("add-granted-role", "{""Role"":""OcuPilotNoSuchRoleSave""}", "no role by that name"), $ListBuild("set-resource-grant", "{""Resource"":""%Development"",""Permissions"":""U""}", "with those permissions") {
        Set tSC = ..Act($List(tCase, 1), tName, ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tStatus, .tBody)
        Set tProblem = $Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("detail") = "object"): tBody.detail.%Get("problem"), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused")
        Do $$$AssertTrue(tProblem [ $List(tCase, 3), "naming why: " _ tProblem)
    }
    Do $$$AssertEquals(..Grants(tName), "%Development:U", "and nothing changed")
}

/// <p>AD-53 (DW-1513, DW-1528): the Roles and Resources lists' Delete over a real request removes a
/// probe role and a probe resource, answering the <code>deleted</code> action; a forced Delete of a
/// system resource is 400 <code>TOOL.ARGUMENTS</code> whose problem is the bare published sentence
/// the row draws before a click. A predefined role's forced Delete is pinned by
/// <class>OcuPilot.Test.RoleDelete</class> without a request, because the vendor would drop the role
/// if the refusal were ever missing.</p>
/// <p>Mutation (Rule 19): drop the delete refusal from
/// <method>OcuPilot.Screen.Tool.ResourceDelete.ScreenActionDelta</method> -- the
/// <code>%DB_IRISSYS</code> leg goes red on the vendor's own 409.</p>
Method TestTheScreenDeletesApplyAndRefuseOverTheWire()
{
    Set tSC = ..Act("delete", ..#MEMBERROLE, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("action"), 1: ""), "200 deleted", "a probe role is deleted from the Roles list")
    Do $$$AssertStatusNotOK(..Fresh(..#MEMBERROLE, .tGone), "and the instance no longer holds it")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Resources).Create(..#PROBERESOURCE, ..#PROBEMARKER, "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "a probe resource is created")
    Set tSC = ..Act("delete", ..#PROBERESOURCE, "", .tStatus, .tBody, ..#RESOURCEACTIONPATH)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("action"), 1: ""), "200 deleted", "and deleted from the Resources list")
    Set tSC = ..Act("delete", "%DB_IRISSYS", "", .tStatus, .tBody, ..#RESOURCEACTIONPATH)
    Set tProblem = $Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("detail") = "object"): tBody.detail.%Get("problem"), 1: "")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "a forced Delete of %DB_IRISSYS is refused")
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Api.Error).#REASONRESOURCENAMESYSTEM, "with the sentence the row draws")
}

/// <p>Send screen action <var>pAction</var> for <var>pId</var> to <var>pPath</var>, the Roles list's
/// route by default.</p>
Method Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pStatus As %Integer, Output pBody, pPath As %String = {..#ACTIONPATH}) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Quit ##class(OcuPilot.Test.Http).MakeRequest("POST", pPath, .pStatus, .pBody, tRequest.%ToJSON())
}

/// <p>The edit route for <var>pName</var>, one encoded segment (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Piece(..#EDITPATH, ":id", 1) _ ##class(OcuPilot.Kernel.EntityId).Encode(pName)
}

/// <p>The role <var>pName</var> as the vendor's own <code>GET</code> answers it now.</p>
ClassMethod Fresh(pName As %String, Output pFresh As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
}

/// <p>The role <var>pName</var>'s grants as <code>Name:Permissions</code>, sorted by name and
/// comma-separated.</p>
ClassMethod Grants(pName As %String) As %String
{
    If $$$ISERR(..Fresh(pName, .tFresh)) || '$IsObject($Get(tFresh)) Quit ""
    Kill tSorted
    Set tIterator = tFresh.Resources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGrant) {
        Set tSorted($ZConvert(tGrant.Name, "U")) = tGrant.Name _ ":" _ tGrant.Permissions
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tSorted(tKey)
    }
    Quit tOut
}

/// <p>How many top-level members <var>pObject</var> carries.</p>
ClassMethod Count(pObject As %DynamicObject) As %Integer
{
    Set tCount = 0
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p><var>pObject</var>'s member <var>pKey</var> as the diff renders it.</p>
ClassMethod Rendered(pObject As %DynamicObject, pKey As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pKey), pObject.%GetTypeOf(pKey))
}

/// <p>Create the probe roles and accounts afresh: each removed first when it is this class's own, and
/// refused when a principal of that name is anybody else's.</p>
Method EnsureProbes() As %Status
{
    Set tSC = ..RemoveProbes()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, ..#PROBEMARKER, "%Development:U", "%Developer")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#MEMBERROLE, ..#PROBEMARKER, "", ..#PROBEROLE)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#PATHROLE, ..#PROBEMARKER, "", "%All")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#MEMBERUSER, ..#PROBEROLE, ..#PROBEPASSWORD, ..#PROBEMARKER, "", "", "", 0, 1, ..#PROBEMARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#HOLDERUSER, ..#PATHROLE, ..#PROBEPASSWORD, ..#PROBEMARKER, "", "", "", 0, 1, ..#PROBEMARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#ESCALATIONUSER, "", ..#PROBEPASSWORD, ..#PROBEMARKER, "", "", "", 0, 1, ..#PROBEMARKER)
        For tUser = ..#MEMBERUSER, ..#ESCALATIONUSER {
            If $$$ISERR(tSC) Quit
            Kill tEscalation
            Set tEscalation("EscalationRoles") = ..#PROBEROLE
            Set tSC = ##class(Security.Users).Modify(tUser, .tEscalation)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe accounts and roles whose comment or description says they are this class's
/// own; a principal of one of those names that is anybody else's is an error and is left alone.</p>
Method RemoveProbes() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#MEMBERUSER, ..#HOLDERUSER, ..#ESCALATIONUSER {
            If '##class(Security.Users).Exists(tUser) Continue
            Kill tProps
            Set tSC = ##class(Security.Users).Get(tUser, .tProps)
            If $$$ISERR(tSC) Quit
            If $Extract($Get(tProps("Comment")), 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the account " _ tUser _ " is not this class's own, so it was left alone")
                Quit
            }
            Set tSC = ##class(Security.Users).Delete(tUser)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) {
            For tRole = ..#MEMBERROLE, ..#PATHROLE, ..#PROBEROLE {
                If '##class(Security.Roles).Exists(tRole) Continue
                Kill tProps
                Set tSC = ##class(Security.Roles).Get(tRole, .tProps)
                If $$$ISERR(tSC) Quit
                If $Extract($Get(tProps("Description")), 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                    Set tSC = $$$ERROR($$$GeneralError, "the role " _ tRole _ " is not this class's own, so it was left alone")
                    Quit
                }
                Set tSC = ##class(Security.Roles).Delete(tRole)
                If $$$ISERR(tSC) Quit
            }
        }
        If $$$ISOK(tSC) && ##class(Security.Resources).Exists(..#PROBERESOURCE) {
            Kill tProps
            Set tSC = ##class(Security.Resources).Get(..#PROBERESOURCE, .tProps)
            If $$$ISOK(tSC) {
                If $Extract($Get(tProps("Description")), 1, $Length(..#PROBEMARKER)) = ..#PROBEMARKER {
                    Set tSC = ##class(Security.Resources).Delete(..#PROBERESOURCE)
                } Else {
                    Set tSC = $$$ERROR($$$GeneralError, "the resource " _ ..#PROBERESOURCE _ " is not this class's own, so it was left alone")
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Take <parameter>MEMBERROLE</parameter> off every one of OcuPilot's own roles that grants it,
/// in case a refused action leg found the refusal missing and applied the change.</p>
Method StripProbeFromOwnRoles()
{
    If $$$ISERR($ClassMethod(..#SET, "OcuPilotRoles", .tOwn)) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tOwn) {
            Kill tProps
            If $$$ISERR(##class(Security.Roles).Get($List(tOwn, tI), .tProps)) Continue
            Set tGranted = $Get(tProps("GrantedRoles"))
            Set tKept = ""
            Set tFound = 0
            For tJ = 1:1:$Length(tGranted, ",") {
                Set tOne = $Piece(tGranted, ",", tJ)
                If tOne = "" Continue
                If $ZConvert(tOne, "U") = $ZConvert(..#MEMBERROLE, "U") {
                    Set tFound = 1
                    Continue
                }
                Set tKept = tKept _ $Select(tKept = "": "", 1: ",") _ tOne
            }
            If 'tFound Continue
            Kill tChange
            Set tChange("GrantedRoles") = tKept
            Do ##class(Security.Roles).Modify($List(tOwn, tI), .tChange)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
