/// <p>The three web-application routes over the wire (Story 8.1, AD-12, AD-39, AD-54, AD-55): the
/// form's bootstrap read, the name look-up and the create, each asserted on status, content type
/// and body shape.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account
/// holding the screen's own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>
/// -- because the create leg creates a real web application. <method>OnBeforeAllTests</method>
/// refuses anywhere it does not, and <method>OnAfterOneTest</method> deletes the one name this
/// class ever creates, by name and never by prefix sweep.</p>
/// <p><b>It refuses to adopt an application it did not make.</b> A name the instance already holds
/// when the suite starts is a refusal rather than a silent adoption, on the pairing
/// <method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method> keeps: the teardown deletes
/// that name, and deleting somebody else's application is the one thing a test must not do.</p>
Class OcuPilot.Test.WebAppWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The three routes, relative to the API application: <method>OcuPilot.Test.Http.MakeRequest</method>
/// prefixes <parameter>OcuPilot.Test.Http.BASEPATH</parameter> itself, and
/// <method>OcuPilot.Test.Http.AbsoluteRequest</method> takes the whole path, which
/// <method>Absolute</method> builds.</p>
Parameter FORMPATH = "/web-applications/form";

Parameter NAMEPATH = "/web-applications/name";

Parameter CREATEPATH = "/web-applications";

/// <p>The one application this class creates and deletes.</p>
Parameter PROBEAPP = "/csp/ocupilotprobewire";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppWire creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If ..Exists(..#PROBEAPP) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppWire's probe application " _ ..#PROBEAPP _ " already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove(..#PROBEAPP)
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 0, "the probe application is gone")
    Quit $$$OK
}

/// <p><code>GET /web-applications/form</code>: the rules the create applies, the methods this
/// instance offers and the sentence each rule refuses with (DW-376).</p>
/// <p>Mutation: return <code>[]</code> from
/// <method>OcuPilot.Area.WebApp.FormRules.Rules</method> -> the sentence assertion goes red, and
/// the client would have no server-authored copy to render on blur.</p>
Method TestTheFormReadPublishesTheRulesAndTheInstancesOwnMethods()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the form read answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    If '$IsObject($Get(tBody)) Quit

    Do $$$AssertTrue(tBody.%Get("authenticationMethods").%Size() > 0, "it offers at least one authentication method")
    Do $$$AssertTrue(+tBody.%Get("defaultMethod") > 0, "and names the one a create starts on")
    Do $$$AssertNotEquals(+tBody.%Get("defaultMethod"), 64, "which is never the unauthenticated option")
    Do $$$AssertTrue(tBody.%Get("requiredFields").%Size() > 0, "it names the fields a create must carry")
    Do $$$AssertTrue(tBody.%Get("wsgiTypes").%Size() = 2, "and the two protocol values the instance publishes")
    Do $$$AssertTrue(+tBody.%Get("maxLengths").%Get("Name") > 0, "with the length each field stores")

    Set tRules = tBody.%Get("rules")
    Do $$$AssertTrue(tRules.%Size() > 0, "and one rule per refusal the create can make")
    Set tIterator = tRules.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRule) {
        Do $$$AssertNotEquals(tRule.%Get("field"), "", "every rule names a field")
        Do $$$AssertNotEquals(tRule.%Get("code"), "", "and a machine code")
        Do $$$AssertEquals(tRule.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(tRule.%Get("code")), "and the sentence the server authored for that code")
    }
}

/// <p><code>GET /web-applications/name</code>: whether a name is free, which is a read of the
/// instance rather than a validation of the value (AD-54).</p>
/// <p>Mutation: answer <code>available</code> 1 from the error path of
/// <method>OcuPilot.Area.WebApp.FormRules.Taken</method> -> the taken leg goes red, and a create
/// could overwrite somebody's application on a look-up that failed.</p>
Method TestTheNameReadAnswersFreeAndTakenAndRefusesAnEmptyName()
{
    Set tFree = "/csp/ocupilotprobewirenothinghere"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ $ZConvert(tFree, "O", "URL"), .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "a free name answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(''tBody.%Get("available"), 1, "and reports it available")
        Do $$$AssertEquals(tBody.%Get("reason"), "", "with no sentence")
    }

    ; OcuPilot's own API application, which every installed instance holds.
    Set tTaken = ..ApiPath()
    Do $$$AssertNotEquals(tTaken, "", "the install roster names OcuPilot's own API path")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ $ZConvert(tTaken, "O", "URL"), .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "a taken name answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(''tBody.%Get("available"), 0, "and reports it taken")
        Do $$$AssertEquals(tBody.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#WEBAPPNAMETAKEN), "with the server's own sentence")
    }

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "a look-up with no name answers")
    Do $$$AssertEquals(tStatus, 422, "at 422")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("code"), ##class(OcuPilot.Api.Error).#WEBAPPVALIDATION, "with the validation code")
        Do $$$AssertEquals(tBody.%Get("detail").%Get("violations").%Get(0).%Get("field"), "Name", "on the field that names it")
    }
}

/// <p><code>POST /web-applications</code>: the create, its field-level refusals and AD-10's
/// prohibited refusals, each over the wire (AD-12, AD-39, AD-55). Application roles are refused on
/// OcuPilot's own application and granted, <code>%All</code> included, on any other.</p>
/// <p>Mutation: render the fault's <code>error</code> where
/// <method>OcuPilot.Area.WebApp.Create.HandleCreate</method> renders its <code>code</code> -> the
/// prohibited legs lose their codes and go red.</p>
Method TestTheCreateAnswersOneEnvelopeForEachOutcome()
{
    ; Field rules: one response naming every broken rule, never one response per rule.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, "{""Name"":""" _ ..#PROBEAPP _ """}", "application/json")
    Do $$$AssertStatusOK(tSC, "a create missing two required fields answers")
    Do $$$AssertEquals(tStatus, 422, "at 422")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("error"), ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, "on the validation slug")
        Do $$$AssertEquals(tBody.%Get("code"), ##class(OcuPilot.Api.Error).#WEBAPPVALIDATION, "with the create's own code")
        Do $$$AssertEquals(tBody.%Get("detail").%Get("violations").%Size(), 2, "and one violation per broken rule")
    }
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 0, "and nothing was created")

    ; AD-10: application roles on OcuPilot's own application, refused whatever the caller.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, "{""Name"":""" _ ..ApiPath() _ """,""NameSpace"":""" _ $Namespace _ """,""AutheEnabled"":32,""MatchRoles"":[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]}", "application/json")
    Do $$$AssertStatusOK(tSC, "a create at OcuPilot's own path carrying application roles answers")
    Do $$$AssertEquals(tStatus, 403, "at 403")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("code"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PRIVILEGEGRANT"), "on the privilege-grant predicate")
    }
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 0, "and nothing was created")

    ; The create itself: 201, the application the instance then holds -- granting %All as an
    ; application role, which AD-10 permits on any application but OcuPilot's own -- and a second
    ; one refused.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, "{""Name"":""" _ ..#PROBEAPP _ """,""NameSpace"":""" _ $Namespace _ """,""AutheEnabled"":32,""Enabled"":true,""MatchRoles"":[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]}", "application/json")
    Do $$$AssertStatusOK(tSC, "a sound create answers")
    Do $$$AssertEquals(tStatus, 201, "at 201")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("name"), ..#PROBEAPP, "naming the application it created")
        Do $$$AssertEquals(tBody.%Get("application").%Get("NameSpace"), $Namespace, "and carrying the application the instance now holds")
        Do $$$AssertEquals(+tBody.%Get("application").%Get("AutheEnabled"), 32, "with the authentication method the body sent explicitly")
    }
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 1, "and the instance holds it")
    Do $$$AssertEquals(..MatchRoles(..#PROBEAPP), ":%All", "with %All as its application role")

    ; AD-54's load-bearing half over the screen path: the vendor's PUT is an upsert with no
    ; refusal of its own, so a second create of the same name is refused here rather than
    ; rewriting the first.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, "{""Name"":""" _ ..#PROBEAPP _ """,""NameSpace"":""" _ $Namespace _ """,""AutheEnabled"":32,""Description"":""overwritten""}", "application/json")
    Do $$$AssertStatusOK(tSC, "a second create of the same name answers")
    Do $$$AssertEquals(tStatus, 422, "at 422")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("detail").%Get("violations").%Get(0).%Get("code"), ##class(OcuPilot.Api.Error).#WEBAPPNAMETAKEN, "as a name this instance already holds")
    }
    Do $$$AssertEquals(..Description(..#PROBEAPP), "", "and the first application was not rewritten")
}

/// <p>AD-39 at the <b>port boundary</b>: a refusal the vendor raises about a body field crosses
/// as one <code>detail.violations[]</code> row naming that field, with OcuPilot's own code and
/// sentence, and the vendor's own text reaches neither consumer.</p>
/// <p><b>It drives the port rather than the create route, because the route cannot reach this.</b>
/// Every field the vendor would refuse by name is one OcuPilot refuses first -- a missing
/// namespace by its own rule, an unknown field by the prohibited set -- which is the point of
/// stating the rules before the port. The mapping is still what a refusal from any other request
/// on this endpoint depends on, so it is exercised where it lives. The call writes nothing: the
/// vendor's own <code>ValidateRequest</code> refuses before <code>Run</code>.</p>
/// <p>Mutation: drop the violations block from <method>OcuPilot.Port.AdminPort.Fail</method>, or
/// take the last dotted segment instead of <code>param 1</code> in
/// <method>OcuPilot.Api.Error.ViolationsFromVendor</method> -> this goes red.</p>
Method TestAVendorFieldRefusalCrossesThePortOnTheFieldItNames()
{
    Kill tQuery
    Set tQuery("name") = ..#PROBEAPP
    Set tBody = {}
    Do tBody.%Set("OcuPilotNotAField", "probe", "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses a body field its own template does not declare")
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 0, "and nothing was created")
    Do $$$AssertTrue($IsObject($Get(tFault)), "the port answers a fault")
    If '$IsObject($Get(tFault)) Quit
    Set tDetail = tFault.%Get("detail")
    Do $$$AssertTrue($IsObject(tDetail), "carrying a structured detail")
    If '$IsObject(tDetail) Quit
    Set tViolations = tDetail.%Get("violations")
    Do $$$AssertTrue($IsObject(tViolations) && (tViolations.%Size() > 0), "with at least one field-level violation")
    If '$IsObject(tViolations) || (tViolations.%Size() = 0) Quit
    Do $$$AssertEquals(tViolations.%Get(0).%Get("field"), "OcuPilotNotAField", "naming the field the vendor refused")
    Do $$$AssertEquals(tViolations.%Get(0).%Get("code"), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "with OcuPilot's own unexpected-field code")
    Do $$$AssertEquals(tViolations.%Get(0).%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "and OcuPilot's own sentence")
}

/// <p>AD-55 at the <b>screen's</b> own call site: a WSGI create made over the wire leaves the
/// instance holding a <code>Path</code> equal to the directory the caller's name resolves to under
/// the fixed WSGI root, derived by the tool rather than accepted from the body (AD-21).</p>
/// <p>Mutation: remove the <method>DerivedFields</method> call from
/// <method>OcuPilot.Area.WebApp.Create.Perform</method> -> this goes red, and the application
/// serves from whatever directory <method>Security.Applications.Create</method> defaults to.</p>
Method TestAWsgiCreateLeavesTheInstanceHoldingTheDerivedPath()
{
    Set tLocation = "ocupilot-probe-wire-wsgi"
    Set tBody = "{""Name"":""" _ ..#PROBEAPP _ """,""NameSpace"":""" _ $Namespace _ """,""AutheEnabled"":32,""WSGIAppName"":""probe.py"",""WSGICallable"":""app"",""WSGIAppLocation"":""" _ tLocation _ """,""WSGIType"":""WSGI""}"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody2, tBody, "application/json")
    Do $$$AssertStatusOK(tSC, "a WSGI create answers")
    Do $$$AssertEquals(tStatus, 201, "at 201")
    If tStatus '= 201 Quit
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 1, "and the instance holds it")
    Do $$$AssertEquals(..PathOf(..#PROBEAPP), ##class(OcuPilot.Area.WebApp.Location).Root() _ tLocation _ "/", "with the path the server resolved from the directory name the caller gave")
}

/// <p><var>pName</var>'s stored physical path, or <code>""</code>.</p>
ClassMethod PathOf(pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName, .tApp) Set tValue = tApp.Path
        Set tApp = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit $Select(tValue = $Char(0): "", 1: tValue)
}

/// <p>AD-12: each of the three routes answers exactly one JSON envelope, over a real HTTP request
/// with its own headers read back.</p>
/// <p>It is the leg that reads the <b>content type</b> and parses the body, which
/// <method>OcuPilot.Test.Http.MakeRequest</method> does for its callers and so hides: what is
/// asserted here is that the instance said <code>application/json</code> and that the bytes it
/// sent parse as one object rather than two concatenated ones.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Response.JSON</method> write the body twice -> the
/// one-envelope assertion goes red on every route below.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tPaths = $ListBuild(..Absolute(..#FORMPATH), ..Absolute(..#NAMEPATH) _ "?name=" _ $ZConvert(..ApiPath(), "O", "URL"))
    For tI = 1:1:$ListLength(tPaths) {
        Set tPath = $List(tPaths, tI)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
        Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertTrue($IsObject(tParsed), tPath _ ": whose body parses as one object")
    }

    ; The write route, refused on its own field rules so this leg creates nothing.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..Absolute(..#CREATEPATH), tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "a body naming nothing is refused at 422")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#WEBAPPVALIDATION, "with the create's own envelope code")
    Do $$$AssertEquals(..Exists(..#PROBEAPP), 0, "and nothing was created")
}

/// <p><var>pPath</var> prefixed with the API application's own path, for the one helper that
/// takes a whole path rather than a relative one.</p>
ClassMethod Absolute(pPath As %String) As %String
{
    Quit $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath
}

/// <p>Whether a web application called <var>pName</var> exists, read in <code>%SYS</code> by
/// AD-16's explicit save and restore.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Applications).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p><var>pName</var>'s stored description, or <code>""</code>.</p>
ClassMethod Description(pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName, .tApp) Set tValue = tApp.Description
        Set tApp = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit $Select(tValue = $Char(0): "", 1: tValue)
}

/// <p><var>pName</var>'s stored application roles, or <code>""</code>.</p>
ClassMethod MatchRoles(pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Applications).Get(pName, .tProps)) Set tValue = $Get(tProps("MatchRoles"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Delete <var>pName</var>. Called only for <parameter>PROBEAPP</parameter>, which this class
/// refuses to start if the instance already held.</p>
ClassMethod Remove(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName) Do ##class(Security.Applications).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>OcuPilot's own API application path, read from the install roster rather than typed here.</p>
ClassMethod ApiPath() As %String
{
    Set tSC = ##class(OcuPilot.Install.Roster).Application("api", .tApplication)
    If $$$ISERR(tSC) || '$IsObject(tApplication) Quit ""
    Quit tApplication.%Get("path")
}

}
