/// <p>Pins the permission check (Story 16.3, AD-8, AD-1): <code>held</code> equal to
/// <code>$System.Security.CheckUserPermission</code> for every probe triple, the granting role and the
/// account's role it is reached through, the role check, <code>%All</code> answered before any
/// per-resource lookup while a missing resource is refused, each refusal's code and status, the route
/// and the tool answering the same object, the 403 through the route and the dispatch path as a
/// least-privileged principal, and a cut read refused 503.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes accounts, roles, resources and a web application
/// (<class>OcuPilot.Test.PermissionFixture</class>) and removes them in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.PermissionCheck Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.PermissionFixture";

Parameter CHECK = "OcuPilot.Kernel.Shell.PermissionCheck";

Parameter TOOLNAME = "permissions.privileges.check";

Parameter ROUTE = "/api/ocupilot/permissions/check";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PermissionCheck creates and deletes accounts, roles, resources and a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "CreateAll")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RemoveAll")
    Set tLeft = $ClassMethod(..#FIXTURE, "Left")
    Quit $Select(tLeft = "": $$$OK, 1: $$$ERROR($$$GeneralError, "probe objects survived: " _ tLeft))
}

/// <p>The route's answer for the four arguments, as the test account or, with <var>pUser</var>, as
/// that probe account; its status and headers in <var>pStatus</var> and <var>pHeaders</var>.</p>
Method Route(pKind As %String, pName As %String, pResource As %String, pPermission As %String, pUser As %String = "", Output pStatus As %Integer, Output pHeaders) As %DynamicAbstractObject
{
    Set tPath = ..#ROUTE _ "?kind=" _ $ZConvert(pKind, "O", "URL") _ "&name=" _ $ZConvert(pName, "O", "URL") _ "&resource=" _ $ZConvert(pResource, "O", "URL") _ "&permission=" _ $ZConvert(pPermission, "O", "URL")
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: $Parameter(..#FIXTURE, "PASSWORD"))
    Set pStatus = 0
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .pStatus, .tRaw, .pHeaders)
    Set tBody = ""
    Try {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>The operation's answer in process, or its fault, as <code>held|grantedBy|through</code> or
/// <code>status:code</code>.</p>
Method Said(pKind As %String, pName As %String, pResource As %String, pPermission As %String, pClass As %String = "") As %String
{
    Set tSC = $ClassMethod($Select(pClass = "": ..#CHECK, 1: pClass), "Check", pKind, pName, pResource, pPermission, .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tHttp _ ":" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "(no fault)")
    Quit tAnswer.%Get("held") _ "|" _ tAnswer.%Get("grantedBy") _ "|" _ tAnswer.%Get("through")
}

/// <p>AC4 -- for every probe triple, <code>held</code> equals the instance's own answer: a grant
/// reached through a granted role, a public permission, an escalation-only grant (not held), an
/// <code>%All</code> holder, and a permission nothing grants.</p>
/// <p>Mutation (Rule 19): pass the account's <code>EscalationRoles</code> into the composition in
/// <method>OcuPilot.Kernel.Shell.PermissionCheck.Check</method> -- the escalation triples go red.</p>
Method TestHeldAgreesWithTheInstanceForEveryProbeTriple()
{
    Set tU = $Parameter(..#FIXTURE, "USERCHAINED")
    Set tV = $Parameter(..#FIXTURE, "USERALL")
    Set tRes = $Parameter(..#FIXTURE, "RESOURCE")
    Set tPub = $Parameter(..#FIXTURE, "PUBLICRESOURCE")
    Set tTriples = $ListBuild($ListBuild(tU, tRes, "READ"), $ListBuild(tU, tRes, "USE"), $ListBuild(tU, tRes, "WRITE"), $ListBuild(tU, "%Admin_Secure", "USE"), $ListBuild(tU, tPub, "READ"), $ListBuild(tU, tPub, "WRITE"), $ListBuild(tU, "%DB_USER", "READ"), $ListBuild(tU, "%DB_IRISTEMP", "WRITE"), $ListBuild(tV, tRes, "WRITE"), $ListBuild(tV, "%Admin_Secure", "USE"), $ListBuild(tV, tPub, "WRITE"))
    Set tHeldCount = 0
    Set tNotHeld = 0
    For tI = 1:1:$ListLength(tTriples) {
        Set tTriple = $List(tTriples, tI)
        Set tLabel = $ListToString(tTriple, " ")
        Set tSC = $ClassMethod(..#CHECK, "Check", "user", $List(tTriple, 1), $List(tTriple, 2), $List(tTriple, 3), .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tLabel _ ": answered")
        If $$$ISERR(tSC) Continue
        Set tOracle = ($System.Security.CheckUserPermission($List(tTriple, 1), $List(tTriple, 2), $List(tTriple, 3)) = 1)
        Do $$$AssertEquals(+tAnswer.%Get("held"), tOracle, tLabel _ ": held equals CheckUserPermission")
        If tOracle Set tHeldCount = tHeldCount + 1
        If 'tOracle Set tNotHeld = tNotHeld + 1
    }
    Do $$$AssertTrue((tHeldCount >= 6) && (tNotHeld >= 3), "the triples cover both answers: " _ tHeldCount _ " held, " _ tNotHeld _ " not")
}

/// <p>AC4, AC5 -- a yes names the role whose own grant it is, and the account's own role in
/// <code>through</code> when that differs; a public permission says so; an <code>%All</code> holder
/// is granted by <code>%All</code> through its role; a role check names no through; an escalation
/// grant is a no.</p>
Method TestAYesNamesTheGrantingRoleAndTheRoleItIsReachedThrough()
{
    Set tU = $Parameter(..#FIXTURE, "USERCHAINED")
    Set tRes = $Parameter(..#FIXTURE, "RESOURCE")
    Do $$$AssertEquals(..Said("user", tU, tRes, "READ"), "1|" _ $Parameter(..#FIXTURE, "ROLEB") _ "|" _ $Parameter(..#FIXTURE, "ROLEA"), "the chained grant: granted by B, through A")
    Do $$$AssertEquals(..Said("user", tU, $Parameter(..#FIXTURE, "PUBLICRESOURCE"), "READ"), "1||", "a public permission names no role")
    Set tSC = $ClassMethod(..#CHECK, "Check", "user", tU, $Parameter(..#FIXTURE, "PUBLICRESOURCE"), "READ", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("public"), 1: ""), 1, "and says it is public")
    Do $$$AssertEquals(..Said("user", tU, "%Admin_Secure", "USE"), "0||", "the escalation role's grant is a no")
    Do $$$AssertEquals(..Said("user", $Parameter(..#FIXTURE, "USERALL"), tRes, "WRITE"), "1|%All|" _ $Parameter(..#FIXTURE, "ROLEALL"), "an %All holder: granted by %All, through R")
    Set tSC = $ClassMethod(..#CHECK, "Check", "user", $Parameter(..#FIXTURE, "USERALL"), tRes, "WRITE", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("all"), 1: ""), 1, "and says all")
    Do $$$AssertEquals(..Said("role", $Parameter(..#FIXTURE, "ROLEA"), tRes, "READ"), "1|" _ $Parameter(..#FIXTURE, "ROLEB") _ "|", "a role check names the granting role and no through")
    Do $$$AssertEquals(..Said("role", $Parameter(..#FIXTURE, "ROLEB"), tRes, "READ"), "1|" _ $Parameter(..#FIXTURE, "ROLEB") _ "|", "and a role granting it itself names itself")
    Do $$$AssertEquals(..Said("user", $ZConvert(tU, "L"), $ZConvert(tRes, "L"), "READ"), "1|" _ $Parameter(..#FIXTURE, "ROLEB") _ "|" _ $Parameter(..#FIXTURE, "ROLEA"), "names resolve without regard to case")
}

/// <p>AC5 -- a resource the instance does not hold is refused, even for an account holding
/// <code>%All</code>, whose composition would otherwise answer yes.</p>
/// <p>Mutation (Rule 19): skip the resource read in
/// <method>OcuPilot.Kernel.Shell.PermissionCheck.Check</method> -- this goes red.</p>
Method TestAMissingResourceIsRefusedEvenForAnAllHolder()
{
    Set tNo = $Parameter(..#FIXTURE, "NORESOURCE")
    Do $$$AssertEquals(..Said("user", $Parameter(..#FIXTURE, "USERALL"), tNo, "READ"), "404:RESOURCE.NAME.ABSENT", "the %All holder is refused a missing resource")
    Do $$$AssertEquals(..Said("user", $Parameter(..#FIXTURE, "USERCHAINED"), tNo, "READ"), "404:RESOURCE.NAME.ABSENT", "and so is any account")
}

/// <p>AC6 -- each refusal answers the matrix's code and status on the route: a missing user, role or
/// resource, a malformed argument, and a caller without <code>%Admin_Secure:USE</code>. The route
/// answers JSON envelopes.</p>
Method TestEachRefusalCarriesItsCodeAndStatus()
{
    Set tU = $Parameter(..#FIXTURE, "USERCHAINED")
    Set tRes = $Parameter(..#FIXTURE, "RESOURCE")
    For tCase = $ListBuild("user", $Parameter(..#FIXTURE, "NOUSER"), tRes, "READ", 404, "USER.NAME.ABSENT"), $ListBuild("role", $Parameter(..#FIXTURE, "NOROLE"), tRes, "READ", 404, "ROLE.NAME.ABSENT"), $ListBuild("user", tU, $Parameter(..#FIXTURE, "NORESOURCE"), "READ", 404, "RESOURCE.NAME.ABSENT"), $ListBuild("group", tU, tRes, "READ", 400, "TOOL.ARGUMENTS"), $ListBuild("user", tU, tRes, "ALL", 400, "TOOL.ARGUMENTS"), $ListBuild("user", "", tRes, "READ", 400, "TOOL.ARGUMENTS"), $ListBuild("user", tU, " ", "READ", 400, "TOOL.ARGUMENTS"), $ListBuild("role", $Translate($Justify("", 65), " ", "x"), tRes, "READ", 400, "TOOL.ARGUMENTS") {
        Set tLabel = $List(tCase, 1) _ " " _ $Extract($List(tCase, 2), 1, 20) _ " " _ $List(tCase, 3) _ " " _ $List(tCase, 4)
        Set tBody = ..Route($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), "", .tStatus, .tHeaders)
        Do $$$AssertEquals(tStatus, $List(tCase, 5), tLabel _ ": the route answers " _ $List(tCase, 5))
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", tLabel _ ": as JSON")
        Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: "(not JSON)"), $List(tCase, 6), tLabel _ ": with its code")
        Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("reason"), 1: "(not JSON)"), $Parameter("OcuPilot.Api.Error", "REASON" _ $Translate($List(tCase, 6), ".")), tLabel _ ": and its reason")
        Do $$$AssertEquals(..Said($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4)), $List(tCase, 5) _ ":" _ $List(tCase, 6), tLabel _ ": as the operation answers it")
    }
    Set tBody = ..Route("user", tU, tRes, "READ", $Parameter(..#FIXTURE, "USERLOW"), .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 403, "a caller without %Admin_Secure:USE is refused 403")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("detail").%Get("failedPair"), 1: "(not JSON)"), "AUTH.NOPRIVILEGE|%Admin_Secure:USE", "naming the pair")
    Set tBody = ..Route("group", tU, tRes, "ALL", $Parameter(..#FIXTURE, "USERLOW"), .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBody): tBody.%Get("code"), 1: "(not JSON)"), "403|AUTH.NOPRIVILEGE", "and is refused the pair before its arguments, as the dispatcher refuses the tool")
}

/// <p>AD-1, AD-53 -- the route and the tool answer the same object for the same arguments, a yes
/// and a refusal alike; the tool refuses arguments its schema does not admit before anything is
/// read.</p>
/// <p>Mutation (Rule 19): make the tool's <method>View</method> answer a constant -- this goes
/// red.</p>
Method TestTheRouteAndTheToolAnswerTheSameObject()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOLNAME, .tTool), "the tool resolves")
    Do $$$AssertTrue($IsObject(tTool) && (tTool.%Get("kind") = "read"), "to a read tool")
    If '$IsObject(tTool) Quit
    Set tU = $Parameter(..#FIXTURE, "USERCHAINED")
    For tArgs = {"kind": "user", "name": (tU), "resource": ($Parameter(..#FIXTURE, "RESOURCE")), "permission": "READ"}, {"kind": "role", "name": ($Parameter(..#FIXTURE, "ROLEA")), "resource": "%DB_USER", "permission": "READ"}, {"kind": "user", "name": ($Parameter(..#FIXTURE, "USERALL")), "resource": ($Parameter(..#FIXTURE, "PUBLICRESOURCE")), "permission": "WRITE"}, {"kind": "user", "name": (tU), "resource": ($Parameter(..#FIXTURE, "NORESOURCE")), "permission": "USE"} {
        Set tBody = ..Route(tArgs.kind, tArgs.name, tArgs.resource, tArgs.permission, "", .tStatus, .tHeaders)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tHttp, .tFault)
        Set tToolSaid = $Select($$$ISOK(tSC): tResult.%ToJSON(), 1: tHttp _ ":" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""))
        Set tRouteSaid = $Select(tStatus = 200: $Select($IsObject(tBody): tBody.%ToJSON(), 1: "(not JSON)"), 1: tStatus _ ":" _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""))
        Do $$$AssertEquals(tRouteSaid, tToolSaid, tArgs.%ToJSON() _ ": the route and the tool answer the same")
        If tArgs.kind = "user", tArgs.name = tU, tArgs.resource = $Parameter(..#FIXTURE, "RESOURCE") Do $$$AssertEquals($Select((tStatus = 200) && $IsObject(tBody): tBody.%Get("held") _ "|" _ tBody.%Get("grantedBy") _ "|" _ tBody.%Get("through"), 1: tRouteSaid), "1|" _ $Parameter(..#FIXTURE, "ROLEB") _ "|" _ $Parameter(..#FIXTURE, "ROLEA"), "and the chained account's answer is the grant through A")
        If $$$ISOK(tSC) Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.Registry).ResultSchemaOf(tTool), tResult, .tProblem), tArgs.%ToJSON() _ ": conforming to the result schema " _ $Get(tProblem))
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"kind": "user", "name": (tU), "resource": "%DB_USER"}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ ":" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "400:TOOL.ARGUMENTS", "the tool refuses a call missing its permission")
}

/// <p>AC6 through the agent's path -- a least-privileged principal (an administrative resource,
/// not <code>%Admin_Secure</code>) calling the tool in a turn is refused by the dispatcher naming
/// <code>%Admin_Secure:USE</code>, as the route refuses it.</p>
Method TestTheDispatchRefusesALeastPrivilegedPrincipal()
{
    Set tLow = $Parameter(..#FIXTURE, "USERLOW")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tLow, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded for the principal")
    If $$$ISERR(tSC) Quit
    Try {
        Do $System.Event.Clear($Job)
        Job ..DispatchAs($Job, tLow, tTurnKey)::10
        Do $$$AssertTrue($Test, "the principal's process starts")
        Set tMessage = $System.Event.WaitMsg("", 120)
        Do $$$AssertEquals($ListGet(tMessage, 1), 1, "and signals")
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2, "{}"))
        Do $$$AssertEquals(tOut.%Get("error"), "", "without failing: " _ tOut.%ToJSON())
        Do $$$AssertEquals(tOut.%Get("username"), tLow, "as the principal")
        Do $$$AssertEquals(tOut.%Get("isError"), 1, "the call is refused")
        Set tContent = ##class(%DynamicObject).%FromJSON($Select(tOut.%Get("content") = "": "{}", 1: tOut.%Get("content")))
        Do $$$AssertEquals(tContent.%Get("code") _ "|" _ $Select($IsObject(tContent.%Get("detail")): tContent.%Get("detail").%Get("failedPair"), 1: ""), "AUTH.NOPRIVILEGE|%Admin_Secure:USE", "naming the pair: " _ tOut.%Get("content"))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
}

/// <p>Log in as <var>pUser</var>, answer one <code>permissions.privileges.check</code> call through
/// the dispatcher under turn <var>pTurnKey</var>, and signal <code>{error, username, isError,
/// content}</code> to process <var>pParent</var>.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by
/// <method>TestTheDispatchRefusesALeastPrivilegedPrincipal</method> and by nothing else;
/// <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod DispatchAs(pParent As %Integer, pUser As %String, pTurnKey As %String)
{
    Set tOut = {"error": ""}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tUse = {"type": "tool_use", "id": "toolu_check"}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME), "string")
        Set tInput = {"kind": "user", "resource": "%DB_USER", "permission": "READ"}
        Do tInput.%Set("name", pUser, "string")
        Do tUse.%Set("input", tInput)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", $System.Status.GetErrorText(tSC))
            Quit
        }
        Do tOut.%Set("isError", ''tResults.%Get(0).%Get("is_error"), "boolean")
        Do tOut.%Set("content", tResults.%Get(0).%Get("content"), "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>AC6 -- a composition read cut at its cap is refused 503 <code>PERMISSION.UNCHECKED</code>,
/// never answered no.</p>
/// <p>Mutation (Rule 19): answer held false on a truncated read in
/// <method>OcuPilot.Kernel.Shell.PermissionCheck.Check</method> -- this goes red.</p>
Method TestACutReadIsRefusedRatherThanAnsweredNo()
{
    Set tSaid = ..Said("user", $Parameter(..#FIXTURE, "USERCHAINED"), $Parameter(..#FIXTURE, "RESOURCE"), "READ", "OcuPilot.Test.PermissionCheckCut")
    Do $$$AssertEquals(tSaid, "503:PERMISSION.UNCHECKED", "the cut read is refused 503")
    Set tSC = ##class(OcuPilot.Test.PermissionCheckCut).Check("user", $Parameter(..#FIXTURE, "USERCHAINED"), $Parameter(..#FIXTURE, "RESOURCE"), "READ", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("error") _ "|" _ tFault.%Get("reason"), 1: ""), "unavailable|" _ ##class(OcuPilot.Api.Error).#REASONPERMISSIONUNCHECKED, "on the unavailable slug, with its sentence")
    Set tArgs = {"kind": "user", "name": ($Parameter(..#FIXTURE, "USERCHAINED")), "resource": ($Parameter(..#FIXTURE, "RESOURCE")), "permission": "READ"}
    Set tSC = ##class(OcuPilot.Test.PermissionCheckCut).View("", tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ ":" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "503:PERMISSION.UNCHECKED", "the tool's view refuses it alike")
    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Test.PrivilegesCut", "HandleCheck", tArgs, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the route's handler answers")
    Set tEnvelope = ""
    Try {
        Set tEnvelope = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    } Catch {
        Set tEnvelope = ""
    }
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tEnvelope): tEnvelope.%Get("code") _ "|" _ tEnvelope.%Get("reason"), 1: tBody), "503|PERMISSION.UNCHECKED|" _ ##class(OcuPilot.Api.Error).#REASONPERMISSIONUNCHECKED, "and the route renders it 503 with its code and sentence")
}

}
