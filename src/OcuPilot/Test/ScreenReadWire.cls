/// <p>The screen-read route over the wire: <code>GET /api/ocupilot/screens/:screen/read</code>
/// through the real <code>/api/ocupilot</code> application, as the configured test principal
/// (<class>OcuPilot.Test.Http</class>): the web applications and users lists' reads, the two not-found rows and
/// the wrong verb. The denied row over the wire is <class>OcuPilot.Test.Wire</class>'s, which owns a
/// principal that lacks the pair; the bad-cap row runs through <class>OcuPilot.Test.Dispatch</class>
/// in <class>OcuPilot.Test.ScreenRead</class>.</p>
/// <p>Needs the API application installed, the test principal's password, that principal holding
/// <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>, at least three web applications
/// and three users. Reads only.</p>
Class OcuPilot.Test.ScreenReadWire Extends %UnitTest.TestCase
{

/// <p>AC2 -- <code>GET /screens/webapp.list/read</code> answers one JSON envelope whose
/// <code>fields</code> are the six the descriptor declares and whose every row carries exactly those
/// keys, with <code>Name</code> and <code>Namespace</code> non-empty strings, <code>Enabled</code> a
/// boolean, and <code>Type</code>, <code>DispatchClass</code> and <code>Resource</code> strings. At <code>maxRows=1000</code> nothing is cut; at <code>maxRows=2</code> two rows come back
/// truncated.</p>
/// <p>Mutation: declare <code>NameSpace</code> in <class>OcuPilot.Screen.Descriptor.WebAppList</class>'s
/// read -> the field list and the non-empty <code>Namespace</code> assertions go red.</p>
Method TestTheWebApplicationsListReadsOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/webapp.list/read?maxRows=1000", tUser, tPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Set tExpected = "[""Name"",""Namespace"",""Type"",""Enabled"",""DispatchClass"",""Resource""]"
    Do $$$AssertEquals(tObj.fields.%ToJSON(), tExpected, "fields are the six declared fields, in order")
    Do $$$AssertEquals(tObj.%GetTypeOf("truncated"), "boolean", "truncated is a boolean")
    Do $$$AssertEquals(tObj.truncated, 0, "and nothing is cut at 1,000")
    Do $$$AssertTrue(tObj.rows.%Size() >= 3, "the instance's web applications are listed: " _ tObj.rows.%Size())

    Set tBad = ""
    Set tIterator = tObj.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tExpected {
            Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        } ElseIf (tRow.%GetTypeOf("Name") '= "string") || (tRow.Name = "") {
            Set tBad = "row " _ tIndex _ " has no Name string"
        } ElseIf (tRow.%GetTypeOf("Namespace") '= "string") || (tRow.Namespace = "") {
            Set tBad = "row " _ tIndex _ " has no Namespace string"
        } ElseIf tRow.%GetTypeOf("Enabled") '= "boolean" {
            Set tBad = "row " _ tIndex _ " has an Enabled that is " _ tRow.%GetTypeOf("Enabled")
        } ElseIf (tRow.%GetTypeOf("Type") '= "string") || (tRow.%GetTypeOf("DispatchClass") '= "string") || (tRow.%GetTypeOf("Resource") '= "string") {
            Set tBad = "row " _ tIndex _ " has a Type, DispatchClass or Resource that is not a string"
        }
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the declared keys, a non-empty Name and Namespace, and a boolean Enabled")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/webapp.list/read?maxRows=2", tUser, tPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the capped request completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tCapped = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tCapped.rows.%Size(), 2, "two rows at maxRows=2")
    Do $$$AssertEquals(tCapped.truncated, 1, "reported truncated")
}

/// <p>Story 2.6 AC3 -- <code>GET /screens/permissions.users/read</code> at <code>maxRows=1000</code>
/// answers one JSON envelope whose <code>fields</code> are the seven the descriptor declares and whose
/// every row carries exactly those keys, with <code>Roles</code> an array, <code>Expired</code> a
/// boolean and <code>ExpirationDate</code> a string; <code>_SYSTEM</code> holds <code>%All</code> and
/// is not expired. At <code>maxRows=2</code> two rows come back truncated.</p>
/// <p>Mutation: remove <code>rowGet</code> from <class>OcuPilot.Screen.Descriptor.UserList</class> ->
/// every <code>Roles</code> is <code>null</code> and the per-row assertion goes red.</p>
Method TestTheUsersListReadsOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.users/read?maxRows=1000", tUser, tPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Set tExpected = "[""Name"",""FullName"",""Enabled"",""Type"",""Roles"",""ExpirationDate"",""Expired""]"
    Do $$$AssertEquals(tObj.fields.%ToJSON(), tExpected, "fields are the seven declared fields, in order")
    Do $$$AssertTrue(tObj.rows.%Size() >= 3, "the instance's users are listed, enough to truncate at two: " _ tObj.rows.%Size())

    Set tBad = ""
    Set tSystem = ""
    Set tIterator = tObj.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tExpected {
            Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        } ElseIf tRow.%GetTypeOf("Roles") '= "array" {
            Set tBad = "row " _ tIndex _ " has a Roles that is " _ tRow.%GetTypeOf("Roles")
        } ElseIf tRow.%GetTypeOf("Expired") '= "boolean" {
            Set tBad = "row " _ tIndex _ " has an Expired that is " _ tRow.%GetTypeOf("Expired")
        } ElseIf tRow.%GetTypeOf("ExpirationDate") '= "string" {
            Set tBad = "row " _ tIndex _ " has an ExpirationDate that is " _ tRow.%GetTypeOf("ExpirationDate")
        }
        If tBad '= "" Quit
        If tRow.Name = "_SYSTEM" Set tSystem = tRow
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the declared keys, a Roles array, a boolean Expired and a string ExpirationDate")
    Do $$$AssertTrue($IsObject(tSystem), "_SYSTEM is listed")
    If $IsObject(tSystem) {
        Set tHasAll = 0
        Set tRoleIterator = tSystem.Roles.%GetIterator()
        While tRoleIterator.%GetNext(.tIndex, .tRole) {
            If tRole = "%All" Set tHasAll = 1
        }
        Do $$$AssertTrue(tHasAll, "_SYSTEM's Roles contain %All: " _ tSystem.Roles.%ToJSON())
        Do $$$AssertEquals(tSystem.Expired, 0, "and _SYSTEM is not expired")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.users/read?maxRows=2", tUser, tPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the capped request completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tCapped = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tCapped.rows.%Size(), 2, "two rows at maxRows=2")
    Do $$$AssertEquals(tCapped.truncated, 1, "reported truncated")
}

/// <p>An unknown screen and a screen with no read are each one 404 envelope with
/// <code>ROUTE.NOTFOUND</code>, as JSON.</p>
Method TestAnUnknownAndAReadlessScreenAreNotFoundOverTheWire()
{
    For tScreen = "nosuch.screen", "shell.home" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ tScreen _ "/read?maxRows=5", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tScreen _ ": the request completes")
        Do $$$AssertEquals(tStatus, 404, tScreen _ ": 404")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tScreen _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tScreen _ ": exactly one envelope")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.error, "not_found", tScreen _ ": on the not_found slug")
        Do $$$AssertEquals(tObj.code, "ROUTE.NOTFOUND", tScreen _ ": with ROUTE.NOTFOUND")
    }
}

/// <p>A <code>POST</code> to the screen-read path is the framework's 405 naming <code>GET</code>, an
/// answer only a mapped <code>GET /screens/:screen/read</code> route produces; without the route
/// the path matches nothing and is a 404.</p>
/// <p>Mutation: delete the screen-read route from <class>OcuPilot.Api.Router</class>'s
/// <code>UrlMap</code> -> the request answers 404 and every assertion here goes red.</p>
Method TestAPostToTheScreenReadPathIsRefusedNamingGet()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/nosuch.screen/read", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 405, "a POST to the screen-read route is refused")
    Do $$$AssertTrue($ListFind($ListFromString($Get(tHeaders("ALLOW"))), "GET"), "and Allow names GET: " _ $Get(tHeaders("ALLOW")))
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "ROUTE.METHODNOTALLOWED", "through the one error writer")
}

}
