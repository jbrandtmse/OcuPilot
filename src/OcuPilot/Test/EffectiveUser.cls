/// <p>Pins the user editor's Effective privileges read, <code>GET /users/effective</code> (Story
/// 16.3, AD-8): the chained account's sections in order, with its escalation role absent and public
/// letters naming no role; an <code>%All</code> account listing its roles only; the Databases section
/// unchecked for a caller without <code>%Admin_Manage:USE</code> while every other section is read;
/// the services and web applications rules; the 404, 403 and 400 refusals; and a cut read marking
/// every section.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes accounts, roles, resources and a web application
/// (<class>OcuPilot.Test.PermissionFixture</class>) and removes them in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.EffectiveUser Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.PermissionFixture";

Parameter ROUTE = "/api/ocupilot/users/effective";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EffectiveUser creates and deletes accounts, roles, resources and a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "CreateAll")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RemoveAll")
    Set tLeft = $ClassMethod(..#FIXTURE, "Left")
    Quit $Select(tLeft = "": $$$OK, 1: $$$ERROR($$$GeneralError, "probe objects survived: " _ tLeft))
}

/// <p>The route's answer for account <var>pName</var>, as the test account or, with
/// <var>pUser</var>, as that probe account; its status and headers in <var>pStatus</var> and
/// <var>pHeaders</var>.</p>
Method View(pName As %String, pUser As %String = "", Output pStatus As %Integer, Output pHeaders) As %DynamicAbstractObject
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: $Parameter(..#FIXTURE, "PASSWORD"))
    Set pStatus = 0
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#ROUTE _ "?name=" _ $ZConvert(pName, "O", "URL"), tUser, tPassword, .pStatus, .tRaw, .pHeaders)
    Set tBody = ""
    Try {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>The row of <var>pSection</var> whose <var>pField</var> is <var>pValue</var>, or
/// <code>""</code>.</p>
Method Row(pAnswer As %DynamicObject, pSection As %String, pField As %String, pValue As %String) As %DynamicObject
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get(pSection)) Quit ""
    Set tFound = ""
    Set tIterator = pAnswer.%Get(pSection).%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get(pField) = pValue) Set tFound = tRow Quit
    }
    Quit tFound
}

/// <p>AC1 -- the chained account: its roles in closure order with the escalation role absent, its
/// resources by name with the granting role on each held letter and public letters naming none, and
/// the web applications, databases and services those resources guard.</p>
/// <p>Mutation (Rule 19): pass the account's <code>EscalationRoles</code> to the composition in
/// <method>OcuPilot.Kernel.Shell.EffectiveUser.Of</method> -- the roles and escalation legs go
/// red.</p>
Method TestTheChainedAccountsSections()
{
    Set tBody = ..View($Parameter(..#FIXTURE, "USERCHAINED"), "", .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertTrue($IsObject(tBody), "with a body")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("user") _ "|" _ tBody.%Get("all") _ "|" _ tBody.%Get("allVia"), $Parameter(..#FIXTURE, "USERCHAINED") _ "|0|", "for the account, not holding everything")
    Do $$$AssertEquals(tBody.%Get("roles").%ToJSON(), "{""rows"":[{""name"":""" _ $Parameter(..#FIXTURE, "ROLEA") _ """,""through"":""""},{""name"":""" _ $Parameter(..#FIXTURE, "ROLEB") _ """,""through"":""" _ $Parameter(..#FIXTURE, "ROLEA") _ """}],""unchecked"":""""}", "roles: A, then B through A, and no escalation role")

    Set tRes = ..Row(tBody, "resources", "name", $Parameter(..#FIXTURE, "RESOURCE"))
    Do $$$AssertEquals($Select($IsObject(tRes): tRes.%ToJSON(), 1: "(absent)"), "{""name"":""" _ $Parameter(..#FIXTURE, "RESOURCE") _ """,""R"":""" _ $Parameter(..#FIXTURE, "ROLEB") _ """,""U"":""" _ $Parameter(..#FIXTURE, "ROLEB") _ """}", "the resource: Read and Use granted by B, and not the W the escalation role grants")
    Set tDb = ..Row(tBody, "resources", "name", "%DB_USER")
    Do $$$AssertEquals($Select($IsObject(tDb): tDb.%Get("R"), 1: "(absent)"), $Parameter(..#FIXTURE, "ROLEB"), "%DB_USER: Read granted by B")
    Set tPub = ..Row(tBody, "resources", "name", $Parameter(..#FIXTURE, "PUBLICRESOURCE"))
    Do $$$AssertEquals($Select($IsObject(tPub): tPub.%ToJSON(), 1: "(absent)"), "{""name"":""" _ $Parameter(..#FIXTURE, "PUBLICRESOURCE") _ """,""R"":""""}", "a public letter names no role")
    Do $$$AssertEquals(..Row(tBody, "resources", "name", "%Admin_Secure"), "", "the escalation role's %Admin_Secure is not held")
    Set tPrevious = ""
    Set tOrdered = 1
    Set tIterator = tBody.%Get("resources").%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert(tRow.%Get("name"), "U") ']] $ZConvert(tPrevious, "U") Set tOrdered = 0
        Set tPrevious = tRow.%Get("name")
    }
    Do $$$AssertTrue(tOrdered, "resources come by name")

    Set tApp = ..Row(tBody, "applications", "name", $Parameter(..#FIXTURE, "APP"))
    Do $$$AssertEquals($Select($IsObject(tApp): tApp.%Get("resource"), 1: "(absent)"), $Parameter(..#FIXTURE, "RESOURCE"), "the web application the resource guards at Use is listed")
    Set tUserDb = ""
    Set tIterator = tBody.%Get("databases").%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("resource") = "%DB_USER" Set tUserDb = tRow Quit
    }
    Do $$$AssertEquals($Select($IsObject(tUserDb): tUserDb.%Get("permissions"), 1: "(absent)"), "R", "the USER database is listed with Read")
    Set tTemp = ..Row(tBody, "databases", "resource", "%DB_IRISTEMP")
    Do $$$AssertEquals($Select($IsObject(tTemp): tTemp.%Get("permissions"), 1: "(absent)"), "RW", "IRISTEMP, publicly readable and writable, is listed RW")
    Do $$$AssertEquals(..Row(tBody, "databases", "resource", "%DB_IRISSYS"), "", "IRISSYS, whose resource the account does not hold, is not listed")
    Do $$$AssertEquals(..Row(tBody, "applications", "resource", "%Development"), "", "no web application guarded by %Development, which the account does not hold, is listed")
    Do $$$AssertEquals(tBody.%Get("databases").%Get("unchecked") _ tBody.%Get("applications").%Get("unchecked") _ tBody.%Get("services").%Get("unchecked"), "", "every section was read")
}

/// <p>The Services rule -- a service is listed when a resource of its own name is held at Use,
/// publicly included; a service with no resource of its own name, <code>%Service_Bindings</code>
/// among them, is never listed.</p>
Method TestAServiceIsListedByItsOwnResourceOnly()
{
    Set tBody = ..View($Parameter(..#FIXTURE, "USERCHAINED"), "", .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    If '$IsObject(tBody) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.resources/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tResStatus, .tResRaw, .tResHeaders)
    Do $$$AssertEquals(tResStatus, 200, "the resources read answers")
    Set tPublicUse = ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tResRaw).%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ($Extract(tRow.%Get("Name"), 1, 9) = "%Service_") && (tRow.%Get("PublicPermission") [ "U") Set tPublicUse(tRow.%Get("Name")) = ""
    }
    Set tServices = ""
    Set tIterator = tBody.%Get("services").%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tServices(tRow.%Get("name")) = ""
    }
    Set tChecked = 0
    Set tName = ""
    For {
        Set tName = $Order(tPublicUse(tName))
        If tName = "" Quit
        If '..IsService(tName) Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue($Data(tServices(tName)), tName _ ": a service whose own resource is public at Use is listed")
    }
    Do $$$AssertTrue(tChecked > 0, "at least one such service was checked: " _ tChecked)
    Do $$$AssertTrue('$Data(tServices("%Service_Bindings")), "%Service_Bindings, which has no resource of its own name, is not listed")
}

/// <p>Whether the instance holds a service named <var>pName</var>, read as the test account.</p>
Method IsService(pName As %String) As %Boolean
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.services/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    If tStatus '= 200 Quit 0
    Set tFound = 0
    Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>AC2 -- an account whose role grants <code>%All</code> holds everything through that role, and
/// only its roles are listed.</p>
/// <p>Mutation (Rule 19): ignore <code>all</code> in
/// <method>OcuPilot.Kernel.Shell.EffectiveUser.Of</method> -- this goes red.</p>
Method TestAnAllHolderListsItsRolesOnly()
{
    Set tBody = ..View($Parameter(..#FIXTURE, "USERALL"), "", .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("all") _ "|" _ tBody.%Get("allVia"), "1|" _ $Parameter(..#FIXTURE, "ROLEALL"), "it holds everything through R")
    Do $$$AssertEquals(tBody.%Get("roles").%Get("rows").%ToJSON(), "[{""name"":""" _ $Parameter(..#FIXTURE, "ROLEALL") _ """,""through"":""""},{""name"":""%All"",""through"":""" _ $Parameter(..#FIXTURE, "ROLEALL") _ """}]", "its roles: R, then %All through R")
    For tSection = "resources", "applications", "databases", "services" {
        Do $$$AssertEquals(tBody.%Get(tSection).%ToJSON(), "{""rows"":[],""unchecked"":""""}", tSection _ ": not read, and empty")
    }
}

/// <p>AC3 -- a caller holding <code>%Admin_Secure:USE</code>, <code>%DB_IRISSYS:READ</code> and the
/// code database but not <code>%Admin_Manage:USE</code> gets Databases unchecked naming the pair, and
/// every other section read.</p>
/// <p>Mutation (Rule 19): read the Databases screen without its pair gate in
/// <method>OcuPilot.Kernel.Shell.EffectiveUser.ListRows</method> -- this goes red.</p>
Method TestAPartTheCallerCannotReadIsUncheckedNamingThePair()
{
    Set tBody = ..View($Parameter(..#FIXTURE, "USERCHAINED"), $Parameter(..#FIXTURE, "USERSECURE"), .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers the caller 200")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("databases").%ToJSON(), "{""rows"":[],""unchecked"":""%Admin_Manage:USE""}", "Databases is not checked, naming the pair")
    For tSection = "roles", "resources", "applications", "services" {
        Do $$$AssertEquals(tBody.%Get(tSection).%Get("unchecked"), "", tSection _ ": read")
        Do $$$AssertTrue(tBody.%Get(tSection).%Get("rows").%Size() > 0, tSection _ ": and listed")
    }
}

/// <p>AC6 -- a missing account is 404 <code>USER.NAME.ABSENT</code>, a blank name 400
/// <code>TOOL.ARGUMENTS</code>, and a caller without <code>%Admin_Secure:USE</code> 403 naming it.</p>
Method TestRefusalsCarryTheirCodeAndStatus()
{
    Set tBody = ..View($Parameter(..#FIXTURE, "NOUSER"), "", .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "404|USER.NAME.ABSENT", "a missing account")
    Set tBody = ..View("", "", .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "400|TOOL.ARGUMENTS", "a blank name")
    Set tBody = ..View($Parameter(..#FIXTURE, "USERCHAINED"), $Parameter(..#FIXTURE, "USERLOW"), .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("detail").%Get("failedPair"), 1: ""), "403|AUTH.NOPRIVILEGE|%Admin_Secure:USE", "a caller without the user editor's pair")
}

/// <p>A composition read cut at its cap marks every section unchecked <code>truncated</code> rather
/// than listing any as empty.</p>
Method TestACutReadMarksEverySection()
{
    Set tSC = ##class(OcuPilot.Test.EffectiveUserCut).Of($Parameter(..#FIXTURE, "USERCHAINED"), .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view answers")
    If '$IsObject($Get(tAnswer)) Quit
    For tSection = "roles", "resources", "applications", "databases", "services" {
        Do $$$AssertEquals(tAnswer.%Get(tSection).%ToJSON(), "{""rows"":[],""unchecked"":""truncated""}", tSection _ ": not checked, too many")
    }
}

}
