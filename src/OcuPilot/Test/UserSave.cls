/// <p>Pins the user editor's Save (Story 9.1, AD-4, AD-10, AD-12, AD-39, AD-55, AD-56):
/// <code>PUT /users/:id</code> and the form read's <code>user</code> over a real HTTP request, a
/// two-field Save that sends all sixteen properties and leaves every other one as it was, the four
/// keys the Save never carries refused with nothing sent, the two-factor rules on both callers, and
/// a disable of <code>_SYSTEM</code> and a sign-in change to <code>CSPSystem</code> refused before
/// the port. The refused legs run through <class>OcuPilot.Test.UserSaveHeldFixture</class>, whose
/// port never sends a <code>PUT</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes one account, <parameter>PROBEUSER</parameter>, by exact name.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.UserSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The edit route; <method>Path</method> fills its one segment.</p>
Parameter EDITPATH = "/users/:id";

Parameter FORMPATH = "/users/form";

Parameter SAVE = "OcuPilot.Test.UserSaveFixture";

/// <p>The Save whose port records a <code>PUT</code> and never sends it.</p>
Parameter HELDSAVE = "OcuPilot.Test.UserSaveHeldFixture";

Parameter PORT = "OcuPilot.Test.DeviceRecordPort";

Parameter RULES = "OcuPilot.Area.Permissions.UserCreateRules";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The probe account every leg edits, created with every one of its settings set.</p>
Parameter PROBEUSER = "OcuPilotProbeUserSave";

/// <p>The comment the probe account is created with, which is how it is recognised as this class's
/// own before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot user save probe";

Parameter PROBEPASSWORD = "OcuPilotAc5ProbePassword9Aa";

/// <p>How many top-level properties the vendor's <code>Security.User</code> <code>GET</code> answers
/// on this build, measured.</p>
Parameter PROPERTYCOUNT As %Integer = 16;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserSave creates and deletes a user account on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbe()
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Quit ..EnsureProbe()
}

/// <p>AD-12, AD-39: the Save and the form read each answer exactly one JSON envelope over a real
/// HTTP request. A Save that changes nothing is 200 <code>{name}</code>; the form read with a name
/// carries the account's sixteen properties less <code>EscalationRoles</code>; and both answer 404
/// <code>USER.NAME.ABSENT</code> for an account the instance does not hold.</p>
/// <p>Mutation (Rule 19): drop the <code>user</code> member from
/// <method>OcuPilot.Area.Permissions.UserCreateRules.HandleForm</method> -- the form-read legs go
/// red.</p>
Method TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEUSER), .tStatus, .tBody, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the Save completes")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("readBack") = "object"): tBody.%Get("readBack").%Get("verdict") _ " " _ tBody.%Get("readBack").%Get("written").%ToJSON(), 1: ""), "matches []", "carrying the Save's read-back, which holds what was sent (AD-58): " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    If $IsObject($Get(tBody)) Do tBody.%Remove("readBack")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""), "{""name"":""" _ ..#PROBEUSER _ """}", "answering the account's name beside it")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#PROBEUSER), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "{}", "application/json")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tRaw [ "}{"), 0, "and exactly one envelope")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..#PROBEUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read of the account answers 200")
    Set tUser = $Select($IsObject($Get(tBody)): tBody.%Get("user"), 1: "")
    Do $$$AssertTrue($IsObject(tUser), "carrying the account")
    If $IsObject(tUser) {
        Do $$$AssertEquals(tUser.%GetTypeOf("EscalationRoles"), "unassigned", "without its escalation roles")
        Do $$$AssertEquals(..Count(tUser), ..#PROPERTYCOUNT - 1, "and with every other property the vendor's read answers")
        Do $$$AssertEquals(tUser.%Get("Comment"), ..#PROBEMARKER, "as the instance holds them")
    }
    Do $$$AssertTrue($IsObject($Get(tBody)) && (tBody.%Get("roles").%Size() > 0), "beside the roles the instance holds")

    For tPath = ..Path("OcuPilotNoSuchUserSave"), ..#FORMPATH _ "?name=OcuPilotNoSuchUserSave" {
        Set tMethod = $Select(tPath [ "form": "GET", 1: "PUT")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest(tMethod, tPath, .tStatus, .tBody, $Select(tMethod = "PUT": "{""FullName"":""x""}", 1: ""), $Select(tMethod = "PUT": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#USERNAMEABSENT, tMethod _ " of an absent account is 404 on its own code")
    }
}

/// <p>AD-4 (AC2): a Save of two fields sends the complete sixteen-property set, the other fourteen
/// exactly as the fresh read answered them, and afterwards every one of those fourteen reads back
/// unchanged while the two read back as saved.</p>
/// <p>Mutation (Rule 19): merge over an empty object instead of the fresh read in
/// <method>OcuPilot.Area.Permissions.UserSave.Update</method> -- the sixteen-key and survival legs go
/// red.</p>
Method TestATwoFieldSaveSendsEverySixteenAndTheOthersSurvive()
{
    Set tName = ..#PROBEUSER
    Do $$$AssertStatusOK(..Fresh(tName, .tBefore), "the account reads fresh")
    If '$IsObject($Get(tBefore)) Quit
    Do $$$AssertEquals(..Count(tBefore), ..#PROPERTYCOUNT, "the vendor's read answers sixteen properties")
    Set tArgs = {"FullName": "Probe saved name", "Comment": (..#PROBEMARKER _ " saved")}
    Set tSC = $ClassMethod(..#SAVE, "Update", tName, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the two-field Save succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 1, "one write was sent")
    Do $$$AssertEquals($ClassMethod(..#PORT, "LastType"), "PUT", "the vendor's PUT")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#PORT, "LastWriteBody"))
    Do $$$AssertEquals(..Count(tSent), ..#PROPERTYCOUNT, "carrying all sixteen properties")
    Do $$$AssertStatusOK(..Fresh(tName, .tAfter), "the account reads back")
    If '$IsObject($Get(tAfter)) Quit
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = "FullName") || (tKey = "Comment") Continue
        Set tWas = ..Rendered(tBefore, tKey)
        Do $$$AssertEquals(..Rendered(tSent, tKey), tWas, tKey _ " was sent as the fresh read held it")
        Do $$$AssertEquals(..Rendered(tAfter, tKey), tWas, tKey _ " survives the Save")
    }
    Do $$$AssertEquals(tAfter.%Get("FullName"), "Probe saved name", "and the full name reads back as saved")
    Do $$$AssertEquals(tAfter.%Get("Comment"), ..#PROBEMARKER _ " saved", "as does the comment")
}

/// <p>AD-56 (AC3): a Save carrying <code>Roles</code>, <code>EscalationRoles</code>,
/// <code>Password</code> or <code>NewPassword</code> -- a privileged role grant among them -- is 400
/// <code>PORT.FIELD.UNEXPECTED</code> naming the key in <code>detail.violations</code>, and nothing
/// is sent. Over the wire the same.</p>
/// <p>Mutation (Rule 19): admit <code>SettableFields</code> rather than <code>PermittedFields</code>
/// in <method>OcuPilot.Area.Permissions.UserSave.Update</method> -- the <code>Roles</code> legs go
/// red.</p>
Method TestTheFourUndeclaredKeysAreRefusedAndNothingIsSent()
{
    For tCase = $ListBuild("Roles", "[""%All""]"), $ListBuild("EscalationRoles", "[""%SQL""]"), $ListBuild("Password", """Ocu8Probe-Secret"""), $ListBuild("NewPassword", """Ocu8Probe-Secret""") {
        Set tKey = $List(tCase, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON("{""FullName"":""probe"",""" _ tKey _ """:" _ $List(tCase, 2) _ "}")
        Do $ClassMethod(..#PORT, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEUSER, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusNotOK(tSC, tKey _ " is refused")
        Do $$$AssertEquals(tHttp, 400, tKey _ ": at 400")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tKey _ ": as an unexpected field")
        Set tRows = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.violations, 1: "")
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 1) && (tRows.%Get(0).field = tKey), tKey _ ": named in detail.violations")
        Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, tKey _ ": and nothing is sent")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEUSER), .tStatus, .tBody, "{""Roles"":[""%All""]}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "over the wire a Roles grant is 400 too")
    Set tRoles = ..Roles(..#PROBEUSER)
    Do $$$AssertTrue($ListFind(tRoles, "%Developer") > 0, "the account reads back with the role it was created with: " _ $ListToString(tRoles))
    Do $$$AssertTrue($ListFind(tRoles, "%All") = 0, "and holds no %All")
}

/// <p>AD-39: <code>AutheEnabled</code> may move only its two two-factor bits, and not both on. Both
/// on is 422 <code>USER.TWOFACTOR.BOTH</code>; another bit moved is
/// <code>USER.AUTHEENABLED.SCOPE</code>; each on alone is permitted. A refused Save sends
/// nothing.</p>
/// <p>Mutation (Rule 19): drop the both-on leg from
/// <method>OcuPilot.Area.Permissions.UserCreateRules.AutheViolation</method> -- the both-on legs go
/// red.</p>
Method TestTheTwoFactorRules()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEUSER, .tFresh), "the account reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tStored = +tFresh.AutheEnabled
    Set tSms = $Parameter(..#RULES, "TWOFACTORSMSBIT")
    Set tTotp = $Parameter(..#RULES, "TWOFACTORTOTPBIT")
    Set tBase = $ZBoolean(tStored, tSms + tTotp, 2)
    ; The rules compare against a stored mask with neither bit on, so each bit turned on alone is a change.
    Set tStoredOff = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
    Do tStoredOff.%Set("AutheEnabled", tBase, "number")
    For tCase = $ListBuild(tBase + tSms + tTotp, "USERTWOFACTORBOTH"), $ListBuild($ZBoolean(tBase, 64, 6), "USERAUTHEENABLEDSCOPE"), $ListBuild("fast", "USERAUTHEENABLEDSCOPE"), $ListBuild("99999999999999999999", "USERAUTHEENABLEDSCOPE"), $ListBuild(tBase + tSms, ""), $ListBuild(tBase + tTotp, ""), $ListBuild(tBase, "") {
        Set tArgs = {}
        Do tArgs.%Set("AutheEnabled", $List(tCase, 1), $Select($IsValidNum($List(tCase, 1)): "number", 1: "string"))
        Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBEUSER, $ClassMethod(..#RULES, "Changed", tArgs, tStoredOff), .tViolations, 0, 0, "update", tStoredOff)
        Do $$$AssertStatusOK(tSC, "the rules answer for " _ $List(tCase, 1))
        Set tCode = $Select(+$Get(tViolations) > 0: $List(tViolations(1), 2), 1: "")
        Set tExpected = $Select($List(tCase, 2) = "": "", 1: $Parameter("OcuPilot.Api.Error", $List(tCase, 2)))
        Do $$$AssertEquals(tCode, tExpected, $List(tCase, 1) _ " answers '" _ tExpected _ "'")
    }
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEUSER, {"AutheEnabled": (tBase + tSms + tTotp)}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 1, "a Save with both on carries one violation")
    Do $$$AssertEquals($Select(+$Get(tViolations): $List(tViolations(1), 1), 1: ""), "AutheEnabled", "on AutheEnabled")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and sends nothing")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEUSER), .tStatus, .tBody, "{""AutheEnabled"":" _ (tBase + tSms + tTotp) _ "}", "application/json")
    Do $$$AssertEquals(tStatus, 422, "over the wire at 422")
    Set tRow = $Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("detail") = "object"): tBody.detail.violations.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.field _ " " _ tRow.code, 1: ""), "AutheEnabled " _ ##class(OcuPilot.Api.Error).#USERTWOFACTORBOTH, "with the violation on AutheEnabled")
}

/// <p>AD-39: the edit's own field rules -- each text setting held to the length the instance
/// stores, a flag to true/false/0/1, the expiry to a real date, a routine to a namespace the edit
/// leaves, and no setting an object -- each refuse on the field with its own code, and a refused
/// Save sends nothing.</p>
/// <p>Mutation (Rule 19): delete the length loop from
/// <method>OcuPilot.Area.Permissions.UserCreateRules.UpdateViolations</method> -- the length legs
/// and the Save leg go red.</p>
Method TestTheEditsFieldRulesRefuseEachFieldWithItsCode()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEUSER, .tFresh), "the account reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tMax = $ClassMethod(..#RULES, "Lengths")
    Set tCases = []
    For tPair = $ListBuild("FullName", "USERFULLNAMELENGTH"), $ListBuild("Comment", "USERCOMMENTLENGTH"), $ListBuild("EmailAddress", "USEREMAILADDRESSLENGTH"), $ListBuild("PhoneNumber", "USERPHONENUMBERLENGTH"), $ListBuild("PhoneProvider", "USERPHONEPROVIDERLENGTH") {
        Set tBound = +tMax.%Get($List(tPair, 1))
        Do $$$AssertTrue(tBound > 0, $List(tPair, 1) _ " has a stored length")
        Set tArgs = {}
        Do tArgs.%Set($List(tPair, 1), $Translate($Justify("", tBound + 1), " ", "x"), "string")
        Do tCases.%Push({"args": (tArgs), "field": ($List(tPair, 1)), "code": ($Parameter("OcuPilot.Api.Error", $List(tPair, 2)))})
    }
    Do tCases.%Push({"args": {"Enabled": "yes"}, "field": "Enabled", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"Comment": {"a": 1}}, "field": "Comment", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"ExpirationDate": "2027-02-30"}, "field": "ExpirationDate", "code": (##class(OcuPilot.Api.Error).#USEREXPIRATIONDATESHAPE)})
    Do tCases.%Push({"args": {"NameSpace": ""}, "field": "Routine", "code": (##class(OcuPilot.Api.Error).#USERROUTINENAMESPACE)})
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBEUSER, $ClassMethod(..#RULES, "Changed", tCase.args, tFresh), .tViolations, 0, 0, "update", tFresh)
        Do $$$AssertStatusOK(tSC, "the rules answer for " _ tCase.args.%ToJSON())
        Set tGot = $Select(+$Get(tViolations) > 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: "")
        Do $$$AssertEquals(tGot, tCase.field _ " " _ tCase.code, tCase.args.%ToJSON() _ " is refused on its field")
    }
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEUSER, {"Comment": ($Translate($Justify("", +tMax.%Get("Comment") + 1), " ", "x"))}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 1, "a Save with an over-long comment carries one violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and sends nothing")
}

/// <p>AD-39 on the agent's caller: a <code>permissions.users.update</code> proposal turning both
/// two-factor bits on, or moving another bit of <code>AutheEnabled</code>, is refused at the mint
/// with a problem naming <code>'AutheEnabled'</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.UserUpdate.ArgumentProblem</method>
/// answer no problem -- both legs go red.</p>
Method TestTheAgentsUpdateKeepsTheTwoFactorRules()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEUSER, .tFresh), "the account reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tSms = $Parameter(..#RULES, "TWOFACTORSMSBIT")
    Set tTotp = $Parameter(..#RULES, "TWOFACTORTOTPBIT")
    Set tBase = $ZBoolean(+tFresh.AutheEnabled, tSms + tTotp, 2)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    For tValue = tBase + tSms + tTotp, $ZBoolean(tBase, 64, 6) {
        Set tArgs = {"Name": (..#PROBEUSER)}
        Do tArgs.%Set("AutheEnabled", tValue, "number")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
        Set tSC = ##class(OcuPilot.Screen.Tool.UserUpdate).View("", tArgs, 0, .tProposal, .tHttp, .tFault)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Do $$$AssertStatusNotOK(tSC, tValue _ " is not proposed")
        Set tProblem = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.%Get("problem"), 1: "")
        Do $$$AssertTrue(tProblem [ "'AutheEnabled'", tValue _ " is refused naming 'AutheEnabled': " _ tProblem)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe turn is removed")
}

/// <p>AD-10 (the matrix's protected-account and DW-1520 rows): a Save that disables
/// <code>_SYSTEM</code>, or sets it to expire on a past date, is refused 403
/// <code>PROHIBITED.SYSTEMACCOUNT</code>, and one that turns <code>ChangePassword</code> on for
/// <code>CSPSystem</code> 403 <code>PROHIBITED.SERVICEACCOUNTSIGNIN</code>, each before the port,
/// and nothing is sent. A future expiration date passes the set and reaches the held port.</p>
/// <p>Mutation (Rule 19): remove the <method>Prohibited</method> call from
/// <method>OcuPilot.Area.Permissions.UserSave.Update</method> -- every refused leg goes red, and the
/// held port keeps each account as it was. Drop the expiration term from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Disables</method> -- the past-date leg goes red.</p>
Method TestDisablingTheSystemAccountIsRefusedBeforeThePort()
{
    Do $$$AssertStatusOK(..Fresh("CSPSystem", .tService), "CSPSystem reads fresh")
    Do $$$AssertTrue($IsObject($Get(tService)) && (tService.%Get("ChangePassword") = 0), "and is not required to change its password")
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", "_SYSTEM", {"AccountNeverExpires": false, "ExpirationDate": "2099-12-31"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter("OcuPilot.Test.HeldPutPort", "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, "_SYSTEM: a future expiration date is not refused and reaches the held port")
    For tCase = $ListBuild("_SYSTEM", "{""Enabled"":false}", "SYSTEMACCOUNT"), $ListBuild("_SYSTEM", "{""AccountNeverExpires"":false,""ExpirationDate"":""2020-01-01""}", "SYSTEMACCOUNT"), $ListBuild("CSPSystem", "{""ChangePassword"":true}", "SERVICEACCOUNTSIGNIN") {
        Set tName = $List(tCase, 1)
        Set tCode = $List(tCase, 3)
        Do $ClassMethod(..#PORT, "Clear")
        Set tSC = $ClassMethod(..#HELDSAVE, "Update", tName, ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusNotOK(tSC, tName _ ": the change is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, tCode), tName _ ": 403 on " _ tCode)
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, tCode _ "REASON"), tName _ ": with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, tName _ ": and nothing is sent")
    }
}

/// <p>The edit route for <var>pName</var>, one encoded segment (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Piece(..#EDITPATH, ":id", 1) _ ##class(OcuPilot.Kernel.EntityId).Encode(pName)
}

/// <p>The account <var>pName</var> as the vendor's own <code>GET</code> answers it now.</p>
ClassMethod Fresh(pName As %String, Output pFresh As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
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

/// <p>The roles <var>pName</var> holds, as a <class>%List</class>.</p>
ClassMethod Roles(pName As %String) As %List
{
    Set tRoles = ""
    If $$$ISERR(..Fresh(pName, .tFresh)) || '$IsObject(tFresh) Quit ""
    Set tIterator = tFresh.Roles.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        Set tRoles = tRoles _ $ListBuild(tRole)
    }
    Quit tRoles
}

/// <p>Create <parameter>PROBEUSER</parameter> afresh with every setting set: removed first when it
/// is this class's own, refused when an account of that name is anybody else's.</p>
Method EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(..#PROBEUSER, "%Developer", ..#PROBEPASSWORD, "Probe Full", "", "", "", 0, 1, ..#PROBEMARKER)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tProps("EmailAddress") = "probe@example.invalid"
        Set tProps("PhoneNumber") = "5550100"
        Set tProps("PhoneProvider") = "ProbeProvider"
        Set tProps("NameSpace") = tOrigNS
        Set tProps("Routine") = "probe^OcuPilotProbe"
        Set tProps("ExpirationDate") = "2099-12-31"
        Set tProps("AccountNeverExpires") = 0
        Set tProps("PasswordNeverExpires") = 1
        Set tProps("ChangePassword") = 1
        Set tProps("AutheEnabled") = 32 + 1048576
        Set tProps("HOTPKeyDisplay") = 0
        Set tProps("EscalationRoles") = "%SQL"
        Set tSC = ##class(Security.Users).Modify(..#PROBEUSER, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>PROBEUSER</parameter> when its comment says it is this class's own; an
/// account of that name that is anybody else's is an error and is left alone.</p>
Method RemoveProbe() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PROBEUSER) {
            Kill tProps
            Set tSC = ##class(Security.Users).Get(..#PROBEUSER, .tProps)
            If $$$ISOK(tSC) {
                If $Extract($Get(tProps("Comment")), 1, $Length(..#PROBEMARKER)) = ..#PROBEMARKER {
                    Set tSC = ##class(Security.Users).Delete(..#PROBEUSER)
                } Else {
                    Set tSC = $$$ERROR($$$GeneralError, "the account " _ ..#PROBEUSER _ " is not this class's own, so it was left alone")
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

}
