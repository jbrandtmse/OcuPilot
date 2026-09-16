/// <p>A read's per-row detail call (AD-36): <method>OcuPilot.Screen.Read.Execute</method> over
/// <class>OcuPilot.Test.ReadRowGet.Users</class> merges each surviving row's detail fields, derives
/// <code>Expired</code> on the instance clock, issues no detail call beyond the cap, drops a row whose
/// detail answers 404, and fails the whole read on any other detail fault or on a value it cannot
/// read.</p>
/// <p>Rows and details come from <class>OcuPilot.Test.EndpointFixture</class> through
/// <class>OcuPilot.Test.PortFixture</class>, so nothing on the instance is read or changed; the dates
/// are computed from <code>+$Horolog</code> when the test runs. Needs <code>%Admin_Operate:U</code>
/// or <code>%Admin_Manage:U</code> for the fixture endpoint.</p>
Class OcuPilot.Test.ScreenReadRowGet Extends %UnitTest.TestCase
{

/// <p>The fixture descriptor whose read declares the detail call.</p>
Parameter USERS = "OcuPilot.Test.ReadRowGet.Users";

/// <p>The fixture descriptor whose detail call names a secret context field.</p>
Parameter SECRETDETAIL = "OcuPilot.Test.ReadRowGet.SecretDetail";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Arm the list rows <var>pRows</var> and the details <var>pDetails</var>, keyed by name.</p>
ClassMethod Arm(pRows As %DynamicArray, pDetails As %DynamicObject)
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows(pRows.%ToJSON())
    Do ##class(OcuPilot.Test.EndpointFixture).SetDetails(pDetails.%ToJSON())
}

/// <p>A list row named <var>pName</var>.</p>
ClassMethod Row(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "FullName": ("Full " _ pName), "Enabled": true, "Type": "Password user"}
}

/// <p>The instance date <var>pOffset</var> days from today, as <code>YYYY-MM-DD</code>.</p>
ClassMethod Day(pOffset As %Integer) As %String
{
    Quit $ZDate(+$Horolog + pOffset, 3)
}

/// <p>The <code>Name</code> of every row in <var>pRows</var>, comma-separated.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    Set tNames = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name
    }
    Quit tNames
}

/// <p>Matrix row "Detail merge": the <code>_SYSTEM</code> row carries its detail's
/// <code>Roles</code> array and <code>ExpirationDate</code>, <code>Expired</code> false, and nothing
/// else from the detail; the view rule reads its roles as <code>%All, OcuPilotAdmin</code>.</p>
Method TestADetailIsMergedIntoItsRow()
{
    Do ..Arm([(..Row("_SYSTEM"))], {"_SYSTEM": {"FullName": "from the detail", "Roles": ["%All", "OcuPilotAdmin"], "ExpirationDate": "", "Comment": "undeclared"}})
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(tFault, "", "with no fault")
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Name"",""FullName"",""Enabled"",""Roles"",""ExpirationDate"",""Expired""]", "the fields are the declared ones")
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "one row")
    If tResult.rows.%Size() '= 1 Quit
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertEquals(tRow.%ToJSON(), "{""Name"":""_SYSTEM"",""FullName"":""Full _SYSTEM"",""Enabled"":true,""Roles"":[""%All"",""OcuPilotAdmin""],""ExpirationDate"":"""",""Expired"":false}", "the row carries the list's fields, the declared detail fields and the derived one, with their JSON types")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).TextOf(tRow, "Roles"), "%All, OcuPilotAdmin", "and the view rule reads the roles joined")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("getNames"), "_SYSTEM", "the detail was read by the row's name")
}

/// <p>Matrix row "Cap first": three list rows under a cap of two issue exactly two detail calls and
/// answer two rows, truncated.</p>
/// <p>Mutation: issue the detail call for every list row before the cap is applied in
/// <method>OcuPilot.Screen.Read.Execute</method> -> the <code>getNames</code> assertion goes
/// red.</p>
Method TestTheDetailCallRunsOnlyForRowsThatSurviveTheCap()
{
    Set tDetail = {"Roles": ["%Developer"], "ExpirationDate": ""}
    Do ..Arm([(..Row("a")), (..Row("b")), (..Row("c"))], {"a": (tDetail), "b": (tDetail), "c": (tDetail)})
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("getNames"), "a,b", "exactly the two surviving rows had their detail read")
    Do $$$AssertEquals(..Names(tResult.rows), "a,b", "two rows are answered")
    Do $$$AssertEquals(tResult.truncated, 1, "truncated, because the list answered more than the cap")
}

/// <p>Matrix row "Deleted between calls": a row whose detail answers 404 is dropped, the others stay,
/// and <code>truncated</code> still follows the list.</p>
/// <p>Mutation: pass a 404 through as a fault in <method>OcuPilot.Screen.Read.DetailRow</method> ->
/// the read fails and every assertion here goes red.</p>
Method TestARowDeletedBetweenTheCallsIsDropped()
{
    Set tDetail = {"Roles": [], "ExpirationDate": ""}
    Do ..Arm([(..Row("a")), (..Row("b")), (..Row("c")), (..Row("d"))], {"a": (tDetail), "b": (tDetail), "c": (tDetail), "d": (tDetail)})
    Do ##class(OcuPilot.Test.EndpointFixture).SetDetailFault("b", "notfound")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 3, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(tFault, "", "with no fault left from the dropped row")
    Do $$$AssertEquals(..Names(tResult.rows), "a,c", "the deleted row is dropped and the others stay")
    Do $$$AssertEquals(tResult.truncated, 1, "and truncated follows the list, which answered four under a cap of three")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("getNames"), "a,b,c", "every surviving row's detail was read")
}

/// <p>Matrix row "Deleted between calls", under the cap: a dropped row does not make a list that fit
/// the cap read as truncated.</p>
/// <p>Mutation: compare the list's size with the answered rows rather than the cap in
/// <method>OcuPilot.Screen.Read.Execute</method> -> the <code>truncated</code> assertion goes red.</p>
Method TestADroppedRowUnderTheCapIsNotTruncated()
{
    Set tDetail = {"Roles": [], "ExpirationDate": ""}
    Do ..Arm([(..Row("a")), (..Row("b")), (..Row("c"))], {"a": (tDetail), "b": (tDetail), "c": (tDetail)})
    Do ##class(OcuPilot.Test.EndpointFixture).SetDetailFault("b", "notfound")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Names(tResult.rows), "a,c", "the deleted row is dropped")
    Do $$$AssertEquals(tResult.truncated, 0, "and the read is not truncated, because the list answered three under a cap of five")
}

/// <p>Matrix row "Row fault": a detail fault other than 404 fails the whole read with that status,
/// HTTP status and fault, and answers no rows. Run for an error status, which the port answers as
/// 500, and for a 403, whose status and fault differ from the executor's own internal fault.</p>
/// <p>Mutation: set <var>pHttpStatus</var> to 500 on the detail fault path in
/// <method>OcuPilot.Screen.Read.DetailRow</method> -> the <code>forbidden</code> HTTP status
/// assertion goes red.</p>
Method TestAnyOtherDetailFaultFailsTheWholeRead()
{
    Set tDetail = {"Roles": [], "ExpirationDate": ""}
    For tMode = "errorstatus", "forbidden" {
        Do ..ClearFixtures()
        Do ..Arm([(..Row("a")), (..Row("b")), (..Row("c"))], {"a": (tDetail), "b": (tDetail), "c": (tDetail)})
        Do ##class(OcuPilot.Test.EndpointFixture).SetDetailFault("b", tMode)
        Kill tQuery
        Set tQuery("name") = "b"
        Set tPortSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.User", "GET", .tQuery, "", .tPortResult, .tPortHttp, .tPortFault)
        Do $$$AssertStatusNotOK(tPortSC, tMode _ ": the fixture's detail call for b fails")
        Do ##class(OcuPilot.Test.EndpointFixture).Clear()
        Do ..Arm([(..Row("a")), (..Row("b")), (..Row("c"))], {"a": (tDetail), "b": (tDetail), "c": (tDetail)})
        Do ##class(OcuPilot.Test.EndpointFixture).SetDetailFault("b", tMode)

        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tMode _ ": the read fails")
        Do $$$AssertEquals($System.Status.GetErrorText(tSC), $System.Status.GetErrorText(tPortSC), tMode _ ": with the detail call's status")
        Do $$$AssertEquals(tHttp, tPortHttp, tMode _ ": its HTTP status " _ tPortHttp)
        Do $$$AssertTrue($IsObject(tFault) && $IsObject(tPortFault) && (tFault.%ToJSON() = tPortFault.%ToJSON()), tMode _ ": and its fault")
        Do $$$AssertEquals(tResult, "", tMode _ ": and no rows, never a partial list")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("getNames"), "a,b", tMode _ ": nothing is read after the fault")
    }
    Do $$$AssertEquals(tPortHttp, 403, "the forbidden detail call answers 403, not the internal fault's 500")
}

/// <p>A secret context field declared as a detail field is dropped from the merged row, as it is
/// from a list row: neither <code>fields</code> nor any row carries its name or value.</p>
/// <p>Mutation: pass the declared <code>read.fields</code> rather than the secret-free fields to
/// <method>OcuPilot.Screen.Read.DetailRow</method> -> the row assertion goes red.</p>
Method TestASecretDetailFieldIsNotMerged()
{
    Do ..Arm([(..Row("a"))], {"a": {"Roles": ["%Developer"], "Comment": "the secret value"}})
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#SECRETDETAIL, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Name"",""Roles""]", "the secret field is not among the answered fields")
    Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""a"",""Roles"":[""%Developer""]}]", "and the row carries neither its name nor its value")
}

/// <p>Matrix rows "Expired" and "Not expired": <code>Expired</code> is true exactly for a date
/// earlier than the instance date, and false for <code>""</code>, today, a later date, a
/// <code>null</code> and an absent key.</p>
/// <p>Mutation: compare with <code>'&gt;</code> instead of <code>&lt;</code> in
/// <method>OcuPilot.Screen.Read.Derive</method> -> the today row goes red.</p>
Method TestExpiredIsADateEarlierThanTheInstanceDate()
{
    Set tRows = []
    Set tDetails = {}
    Set tCases = $ListBuild($ListBuild("past", ..Day(-13), 1), $ListBuild("yesterday", ..Day(-1), 1), $ListBuild("today", ..Day(0), 0), $ListBuild("later", ..Day(30), 0), $ListBuild("never", "", 0))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do tRows.%Push(..Row($List(tCase, 1)))
        Do tDetails.%Set($List(tCase, 1), {"Roles": [], "ExpirationDate": ($List(tCase, 2))})
    }
    Do tRows.%Push(..Row("nulled"))
    Do tDetails.%Set("nulled", {"Roles": [], "ExpirationDate": null})
    Do tRows.%Push(..Row("absent"))
    Do tDetails.%Set("absent", {"Roles": []})
    Do ..Arm(tRows, tDetails)

    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tResult.rows.%Size(), 7, "every row is answered")
    Kill tExpired
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tExpired(tRow.Name) = $ListBuild(tRow.%GetTypeOf("Expired"), +tRow.Expired)
    }
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do $$$AssertEquals($Get(tExpired($List(tCase, 1))), $ListBuild("boolean", $List(tCase, 3)), $List(tCase, 1) _ " (" _ $List(tCase, 2) _ ") is " _ $Select($List(tCase, 3): "expired", 1: "not expired") _ " against " _ ..Day(0))
    }
    Do $$$AssertEquals($Get(tExpired("nulled")), $ListBuild("boolean", 0), "a null expiration date is not expired")
    Do $$$AssertEquals($Get(tExpired("absent")), $ListBuild("boolean", 0), "and neither is an absent one")
}

/// <p>Matrix row "Malformed date": an expiration date that is not <code>YYYY-MM-DD</code>, or is not a
/// date, fails the read with 500 <code>INTERNAL</code>.</p>
Method TestAMalformedExpiryFailsTheRead()
{
    For tValue = "09/01/2026", "2026-02-30" {
        Do ..ClearFixtures()
        Do ..Arm([(..Row("a"))], {"a": {"Roles": [], "ExpirationDate": (tValue)}})
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tValue _ ": the read fails")
        Do $$$AssertEquals(tHttp, 500, tValue _ ": at 500")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "INTERNAL"), tValue _ ": with the internal fault")
        Do $$$AssertEquals(tResult, "", tValue _ ": and no rows")
    }
}

/// <p>A surviving row whose key is not a non-empty string, or whose detail is not an object, fails
/// the read with 500 <code>INTERNAL</code>; a row with no key issues no detail call.</p>
Method TestARowOrDetailTheCallCannotReadFailsTheRead()
{
    For tName = "", 7 {
        Do ..ClearFixtures()
        Set tRow = ..Row("x")
        Do tRow.%Set("Name", tName, $Select(tName = "": "string", 1: "number"))
        Do ..Arm([(tRow)], {})
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "Name " _ tRow.%ToJSON() _ ": the read fails")
        Do $$$AssertEquals(tHttp, 500, "Name " _ tRow.%ToJSON() _ ": at 500")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "INTERNAL"), "Name " _ tRow.%ToJSON() _ ": with the internal fault")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("getCount"), "", "Name " _ tRow.%ToJSON() _ ": and no detail call")
    }

    Do ..ClearFixtures()
    Do ..Arm([(..Row("a"))], {"a": "not an object"})
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#USERS, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a detail that is not an object fails the read")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = "INTERNAL"), "with the internal fault")
    Do $$$AssertEquals(tResult, "", "and no rows")
}

}
