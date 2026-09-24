/// <p>Pins the web application editor's Save and its role actions (Story 9.2, AD-4, AD-10, AD-12,
/// AD-27, AD-39, AD-53, AD-55, AD-56): <code>PUT /web-applications/:id</code> and the form read's
/// <code>application</code> over a real HTTP request, a two-field Save that sends the complete set
/// and leaves every other field as it was, the keys the Save never carries refused with nothing
/// sent, the edit's field rules, a system application keeping its type, the four role actions as a
/// delta over the fresh read, and OcuPilot's own applications refused on both callers. The refused
/// legs run through <class>OcuPilot.Test.WebAppSaveHeldFixture</class>, whose port never sends a
/// <code>PUT</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes one web application, <parameter>PROBEAPP</parameter>, by exact
/// name. <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.WebAppSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The edit route; <method>Path</method> fills its one segment.</p>
Parameter EDITPATH = "/web-applications/:id";

Parameter FORMPATH = "/web-applications/form";

Parameter ACTIONPATH = "/screens/webapp.list/action";

Parameter SAVE = "OcuPilot.Test.WebAppSaveFixture";

/// <p>The Save whose port records a <code>PUT</code> and never sends it.</p>
Parameter HELDSAVE = "OcuPilot.Test.WebAppSaveHeldFixture";

Parameter PORT = "OcuPilot.Test.DeviceRecordPort";

Parameter RULES = "OcuPilot.Area.WebApp.Create";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The probe application every leg edits, created with CORS, JWT and file serving set.</p>
Parameter PROBEAPP = "/csp/ocupilotprobewebappsave";

/// <p>The description the probe is created with, which is how it is recognised as this class's own
/// before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot web application save probe";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppSave creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveApp(..#PROBEAPP, ..#PROBEMARKER)
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Quit ..EnsureProbe()
}

/// <p>AD-12, AD-39: the Save and the form read each answer exactly one JSON envelope over a real
/// HTTP request. A Save that changes nothing is 200 <code>{name}</code>; the form read with a name
/// carries the application as the edit tool's read answers it; and both answer 404
/// <code>WEBAPP.NAME.ABSENT</code> for an application the instance does not hold.</p>
/// <p>Mutation (Rule 19): drop the <code>application</code> member from
/// <method>OcuPilot.Area.WebApp.FormRules.HandleForm</method> -- the form-read legs go red.</p>
Method TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEAPP), .tStatus, .tBody, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the Save completes")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("name"), 1: ""), ..#PROBEAPP, "answering the application's name")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#PROBEAPP), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "{}", "application/json")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tRaw [ "}{"), 0, "and exactly one envelope")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ $ZConvert(..#PROBEAPP, "O", "URL"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read of the application answers 200")
    Set tApp = $Select($IsObject($Get(tBody)): tBody.%Get("application"), 1: "")
    Do $$$AssertTrue($IsObject(tApp), "carrying the application")
    If $IsObject(tApp) {
        Do $$$AssertEquals(tApp.%Get("Description"), ..#PROBEMARKER, "as the instance holds it")
        Do $$$AssertEquals(tApp.%Get("ServeFiles"), "Always", "every setting the read answers among it")
    }
    Do $$$AssertTrue($IsObject($Get(tBody)) && (tBody.%Get("serveFilesChoices").%Size() = 4), "beside the four file-serving choices")

    For tPath = ..Path("/csp/ocupilotnosuchwebappsave"), ..#FORMPATH _ "?name=" _ $ZConvert("/csp/ocupilotnosuchwebappsave", "O", "URL") {
        Set tMethod = $Select(tPath [ "form": "GET", 1: "PUT")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest(tMethod, tPath, .tStatus, .tBody, $Select(tMethod = "PUT": "{""Description"":""x""}", 1: ""), $Select(tMethod = "PUT": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#WEBAPPNAMEABSENT, tMethod _ " of an absent application is 404 on its own code")
    }
}

/// <p>AD-4 (the matrix's two-field row): a Save of <code>Description</code> and <code>Timeout</code>
/// sends the complete set the fresh read answered, every other field exactly as it was read, and
/// afterwards every other field -- CORS, JWT and file serving among them -- reads back unchanged
/// while the two read back as saved.</p>
/// <p>Mutation (Rule 19): merge over an empty object instead of the fresh read in
/// <method>OcuPilot.Area.WebApp.WebAppSave.Update</method> -- the complete-set and survival legs go
/// red.</p>
Method TestATwoFieldSaveSendsTheCompleteSetAndTheOthersSurvive()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEAPP, .tBefore), "the application reads fresh")
    If '$IsObject($Get(tBefore)) Quit
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEAPP, {"Description": (..#PROBEMARKER _ " saved"), "Timeout": 1234}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the two-field Save succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 1, "one write was sent")
    Do $$$AssertEquals($ClassMethod(..#PORT, "LastType"), "PUT", "the vendor's PUT")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#PORT, "LastWriteBody"))
    Do $$$AssertEquals(..Count(tSent), ..Count(tBefore), "carrying every property the read answered")
    Do $$$AssertStatusOK(..Fresh(..#PROBEAPP, .tAfter), "the application reads back")
    If '$IsObject($Get(tAfter)) Quit
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = "Description") || (tKey = "Timeout") Continue
        Set tWas = ..Rendered(tBefore, tKey)
        Do $$$AssertEquals(..Rendered(tSent, tKey), tWas, tKey _ " was sent as the fresh read held it")
        Do $$$AssertEquals(..Rendered(tAfter, tKey), tWas, tKey _ " survives the Save")
    }
    Do $$$AssertEquals(tAfter.%Get("Description"), ..#PROBEMARKER _ " saved", "and the description reads back as saved")
    Do $$$AssertEquals(tAfter.%Get("Timeout"), 1234, "as does the timeout")
    Do $$$AssertEquals(tAfter.%Get("CorsAllowlist").%ToJSON(), "[""https://probe.example""]", "the CORS allow list among the survivors")
}

/// <p>AD-56, AD-21: a Save carrying <code>MatchRoles</code>, <code>Path</code> or
/// <code>WSGIAppLocation</code> is 400 <code>PORT.FIELD.UNEXPECTED</code> naming the key, and
/// nothing is sent. Over the wire the same.</p>
/// <p>Mutation (Rule 19): admit <code>SettableFields</code> rather than <code>PermittedFields</code>
/// in <method>OcuPilot.Area.WebApp.WebAppSave.Update</method> -- the <code>MatchRoles</code> legs go
/// red.</p>
Method TestTheUndeclaredKeysAreRefusedAndNothingIsSent()
{
    For tCase = $ListBuild("MatchRoles", "[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]"), $ListBuild("Path", """/tmp/elsewhere/"""), $ListBuild("WSGIAppLocation", """/tmp/elsewhere/""") {
        Set tKey = $List(tCase, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON("{""Description"":""probe"",""" _ tKey _ """:" _ $List(tCase, 2) _ "}")
        Do $ClassMethod(..#PORT, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEAPP, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusNotOK(tSC, tKey _ " is refused")
        Do $$$AssertEquals(tHttp, 400, tKey _ ": at 400")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tKey _ ": as an unexpected field")
        Set tRows = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.violations, 1: "")
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 1) && (tRows.%Get(0).field = tKey), tKey _ ": named in detail.violations")
        Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, tKey _ ": and nothing is sent")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBEAPP), .tStatus, .tBody, "{""MatchRoles"":[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "over the wire a role grant is 400 too")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).MatchRoles(..#PROBEAPP), "", "and the application still grants no role")
}

/// <p>AD-39, AD-55: the edit's field rules refuse each field with its own code on both callers --
/// the Save and the agent's mint (<method>OcuPilot.Screen.Tool.WebAppUpdate.ArgumentProblem</method>)
/// -- and a refused Save sends nothing.</p>
/// <p>Mutation (Rule 19): delete the timeout loop from
/// <method>OcuPilot.Area.WebApp.Create.UpdateViolations</method> -- the timeout legs go red.</p>
Method TestTheEditsRulesRefuseEachFieldWithItsCode()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBEAPP, .tFresh), "the application reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tCases = []
    Do tCases.%Push({"args": {"Timeout": -1}, "field": "Timeout", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"ServeFilesTimeout": 1.5}, "field": "ServeFilesTimeout", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"ServeFiles": "Sometimes"}, "field": "ServeFiles", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"NameSpace": ""}, "field": "NameSpace", "code": (##class(OcuPilot.Api.Error).#WEBAPPNAMESPACEREQUIRED)})
    Do tCases.%Push({"args": {"AutheEnabled": 0}, "field": "AutheEnabled", "code": (##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED)})
    Do tCases.%Push({"args": {"CorsAllowlist": [1]}, "field": "CorsAllowlist", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"LockCSPName": "yes"}, "field": "LockCSPName", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"GroupById": ($Translate($Justify("", 65), " ", "g"))}, "field": "GroupById", "code": (##class(OcuPilot.Api.Error).#WEBAPPFIELDLENGTH)})
    Do tCases.%Push({"args": {"WSGIAppName": "probe"}, "field": "WSGIAppLocation", "code": (##class(OcuPilot.Api.Error).#WEBAPPWSGILOCATION)})
    Do tCases.%Push({"args": {"WSGIType": "CGI"}, "field": "WSGIType", "code": (##class(OcuPilot.Api.Error).#WEBAPPWSGITYPE)})
    Do tCases.%Push({"args": {"AutheEnabled": (tFresh.%Get("AutheEnabled") + 1024)}, "field": "AutheEnabled", "code": (##class(OcuPilot.Api.Error).#WEBAPPAUTHEUNKNOWN)})
    Do tCases.%Push({"args": {"WSGIAppName": "probe", "DispatchClass": "OcuPilot.Api.Router"}, "field": "DispatchClass", "code": (##class(OcuPilot.Api.Error).#WEBAPPTYPECONFLICT)})
    Do tCases.%Push({"args": {"Description": {}}, "field": "Description", "code": (##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)})
    Do tCases.%Push({"args": {"MatchRoles": [{"MatchRole": 1, "TargetRoles": ["%SQL"]}]}, "field": "MatchRoles", "code": (##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESSHAPE)})
    Do tCases.%Push({"args": {"Package": ($Translate($Justify("", 65), " ", "p"))}, "field": "Package", "code": (##class(OcuPilot.Api.Error).#WEBAPPFIELDLENGTH)})
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBEAPP, $ClassMethod(..#RULES, "Changed", tCase.args, tFresh), .tViolations, 0, "update", tFresh)
        Do $$$AssertStatusOK(tSC, "the rules answer for " _ tCase.args.%ToJSON())
        Set tGot = ""
        For tI = 1:1:+$Get(tViolations) {
            If $List(tViolations(tI), 1) = tCase.field Set tGot = $List(tViolations(tI), 1) _ " " _ $List(tViolations(tI), 2)
        }
        Do $$$AssertEquals(tGot, tCase.field _ " " _ tCase.code, tCase.args.%ToJSON() _ " is refused on its field")
        Set tSC = ##class(OcuPilot.Screen.Tool.WebAppUpdate).ArgumentProblem(..#PROBEAPP, tCase.args, .tProblem)
        Do $$$AssertTrue(tProblem [ ("'" _ tCase.field _ "'"), "and the agent's mint refuses it naming '" _ tCase.field _ "': " _ tProblem)
    }
    Do $ClassMethod(..#PORT, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEAPP, {"Timeout": -1}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 1, "a Save with a negative timeout carries one violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and sends nothing")
}

/// <p>AD-27's fifth case (the matrix's system-application row): the vendor's PUT resets an
/// application's <code>Type</code>, so a Save on a system application -- <code>Type</code> 3 -- would
/// demote it; the port puts the type back, and it still reads 3 afterwards.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.TYPEKEPTTYPES</parameter> and
/// recompile the port and its subclasses -- the type reads 2 and this goes red.</p>
Method TestASystemApplicationKeepsItsType()
{
    Do $$$AssertStatusOK(..SetType(..#PROBEAPP, 3), "the probe is made a system application")
    Do $$$AssertEquals(..TypeOf(..#PROBEAPP), 3, "and reads Type 3")
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBEAPP, {"Description": (..#PROBEMARKER _ " system")}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the Save succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(..TypeOf(..#PROBEAPP), 3, "and the application still reads Type 3")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).Description(..#PROBEAPP), ..#PROBEMARKER _ " system", "with the saved description")
}

/// <p>AD-53, AD-56 (ii): the four role actions change <code>MatchRoles</code> by a delta over the
/// fresh read, over the screen's own action route. An application role and a matching role are
/// added and removed; adding one held, removing one not held, an unknown role and an empty value are
/// each 400 with nothing written.</p>
/// <p>Mutation (Rule 19): build the list from an empty array instead of the fresh read in
/// <method>OcuPilot.Screen.Tool.WebAppUpdate.ScreenActionDelta</method> -- the leg keeping the
/// application role across the matching-role add goes red.</p>
Method TestTheRoleActionsApplyADeltaOverTheWire()
{
    Do $$$AssertEquals(..Act("add-application-role", ..#PROBEAPP, {"Role": "%Developer"}), 200, "an application role is added")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).MatchRoles(..#PROBEAPP), ":%Developer", "and the application grants it to every request")
    Do $$$AssertEquals(..Act("add-matching-role", ..#PROBEAPP, {"MatchRole": "%Operator", "Role": "%SQL"}), 200, "a matching role is added")
    Set tRoles = ##class(OcuPilot.Test.WebAppWire).MatchRoles(..#PROBEAPP)
    Do $$$AssertTrue((tRoles [ ":%Developer") && (tRoles [ "%Operator:%SQL"), "and the application keeps the first beside it: " _ tRoles)
    Do $$$AssertEquals(..Act("add-application-role", ..#PROBEAPP, {"Role": "%developer"}), 400, "adding a role already granted there is refused")
    Do $$$AssertEquals(..Act("remove-matching-role", ..#PROBEAPP, {"MatchRole": "%Operator", "Role": "%Developer"}), 400, "removing one not granted there is refused")
    Do $$$AssertEquals(..Act("add-application-role", ..#PROBEAPP, {"Role": "OcuPilotNoSuchRole"}), 400, "an unknown role is refused")
    Do $$$AssertEquals(..Act("add-matching-role", ..#PROBEAPP, {"MatchRole": "", "Role": "%SQL"}), 400, "and so is an empty matching role")
    Do $$$AssertEquals(..Act("remove-matching-role", ..#PROBEAPP, {"MatchRole": "%Operator", "Role": "%SQL"}), 200, "the matching role is removed")
    Do $$$AssertEquals(..Act("remove-application-role", ..#PROBEAPP, {"Role": "%Developer"}), 200, "and the application role")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).MatchRoles(..#PROBEAPP), "", "leaving the application granting none")
}

/// <p>AD-10, AC3 (DW-1502): on one of OcuPilot's own applications a Save that disables it is
/// refused 403 <code>PROHIBITED.SERVINGPATH</code> before the port, and an application-role action
/// is refused 403 <code>PROHIBITED.PRIVILEGEGRANT</code>, each with its published sentence and with
/// nothing written.</p>
/// <p>Mutation (Rule 19): remove the <method>Prohibited</method> call from
/// <method>OcuPilot.Area.WebApp.WebAppSave.Update</method> -- the Save leg goes red.</p>
Method TestOcuPilotsOwnApplicationIsRefusedOnBothCallers()
{
    Set tApi = ##class(OcuPilot.Test.WebAppWire).ApiPath()
    Do $$$AssertNotEquals(tApi, "", "the install roster names OcuPilot's API path")
    Do $ClassMethod("OcuPilot.Test.HeldPutPort", "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", tApi, {"Enabled": false}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "disabling OcuPilot's own API is refused")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "SERVINGPATH"), "403 on the serving path")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "SERVINGPATHREASON"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.HeldPutPort", "WriteCount"), 0, "and nothing is sent")

    Set tShell = "/ocupilot"
    Set tBefore = ##class(OcuPilot.Test.WebAppWire).MatchRoles(tShell)
    Set tStatus = ..Act("add-application-role", tShell, {"Role": "%All"}, .tBody)
    Do $$$AssertEquals(tStatus, 403, "an application role on OcuPilot's own shell is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), $Parameter(..#SET, "PRIVILEGEGRANT"), "as a privilege grant")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("reason"), 1: ""), $Parameter(..#SET, "PRIVILEGEGRANTREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).MatchRoles(tShell), tBefore, "and the shell's roles are what they were")
}

/// <p>One role action <var>pAction</var> on <var>pId</var> with <var>pValues</var>, over the screen's
/// own action route; answers the HTTP status and, in <var>pBody</var>, the envelope.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject, Output pBody As %DynamicObject) As %Integer
{
    Set tRequest = {"action": (pAction), "id": (pId), "values": (pValues)}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .pBody, tRequest.%ToJSON(), "application/json")
    If $$$ISERR(tSC) Quit 0
    Quit tStatus
}

/// <p>The edit route for <var>pName</var>, one encoded segment (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Piece(..#EDITPATH, ":id", 1) _ ##class(OcuPilot.Kernel.EntityId).Encode(pName)
}

/// <p>The application <var>pName</var> as the vendor's own <code>GET</code> answers it now.</p>
ClassMethod Fresh(pName As %String, Output pFresh As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
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

/// <p><var>pName</var>'s <code>Type</code> as <class>Security.Applications</class> holds it, or
/// <code>""</code>.</p>
ClassMethod TypeOf(pName As %String) As %String
{
    Set tType = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Applications).Get(pName, .tProps)) Set tType = $Get(tProps("Type"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tType
}

/// <p>Set <var>pName</var>'s <code>Type</code> to <var>pType</var>. Only ever called for an
/// application a probe class created.</p>
ClassMethod SetType(pName As %String, pType As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Type") = pType
        Set tSC = ##class(Security.Applications).Modify(pName, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create <var>pName</var> afresh through the shipped port from <var>pBody</var>, whose
/// <code>Description</code> must start with <var>pMarker</var>: removed first when it is the
/// caller's own, refused when an application of that name is anybody else's.</p>
ClassMethod EnsureApp(pName As %String, pMarker As %String, pBody As %DynamicObject) As %Status
{
    Set tSC = ..RemoveApp(pName, pMarker)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tQuery, pBody, .tAnswer, .tHttp, .tFault)
    Quit tSC
}

/// <p>Delete <var>pName</var> when its description starts with <var>pMarker</var>; an application
/// of that name that is anybody else's is an error and is left alone.</p>
ClassMethod RemoveApp(pName As %String, pMarker As %String) As %Status
{
    Set tSC = $$$OK
    If '##class(OcuPilot.Test.WebAppWire).Exists(pName) Quit tSC
    If $Extract(##class(OcuPilot.Test.WebAppWire).Description(pName), 1, $Length(pMarker)) '= pMarker {
        Quit $$$ERROR($$$GeneralError, "the web application " _ pName _ " is not this suite's own, so it was left alone")
    }
    ; The instance refuses to delete a system application, which the type leg makes this probe.
    Set tType = ..TypeOf(pName)
    If (tType '= "") && (tType # 2) {
        Set tSC = ..SetType(pName, tType - 1)
        If $$$ISERR(tSC) Quit tSC
    }
    Do ##class(OcuPilot.Test.WebAppWire).Remove(pName)
    If ##class(OcuPilot.Test.WebAppWire).Exists(pName) Quit $$$ERROR($$$GeneralError, "the web application " _ pName _ " could not be removed")
    Quit tSC
}

/// <p>Create <parameter>PROBEAPP</parameter> afresh: password authentication, a resource, CORS,
/// JWT and file serving set.</p>
Method EnsureProbe() As %Status
{
    Set tBody = {"NameSpace": ($Namespace), "Description": (..#PROBEMARKER), "AutheEnabled": 32, "Resource": "%Development", "Enabled": true, "CorsAllowlist": ["https://probe.example"], "CorsCredentialsAllowed": true, "JWTAuthEnabled": true, "ServeFiles": "Always", "Timeout": 900}
    Quit ..EnsureApp(..#PROBEAPP, ..#PROBEMARKER, tBody)
}

}
