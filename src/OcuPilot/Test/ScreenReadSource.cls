/// <p>The single-object and per-parent read shapes and member fields (AD-36):
/// <method>OcuPilot.Screen.Read.Execute</method> over <class>OcuPilot.Test.ReadSource.Object</class>
/// answers one row, projects a member of an object field and reads a 404 as no rows; and over
/// <class>OcuPilot.Test.ReadSource.Children</class> lists the parents at the cap plus one, issues one
/// child list per parent in order with the parent's fields copied in, skips a child 404, fails with
/// any other child or parent-list fault, and reports truncation from the rows held and from the
/// parent list. Both carry their declared <code>source.query</code> where the read's own endpoint is
/// called.</p>
/// <p>Over <class>OcuPilot.Test.ReadSource.Fixed</class> a declared <code>source.query</code> reaches
/// the port whatever the caller supplies, and over <class>OcuPilot.Test.ReadSource.Upcoming</class> an
/// <code>UPCOMING</code> source is issued as that type under the cap. Over
/// <class>OcuPilot.Test.ReadSource.History</class> a <code>HISTORY</code> source is issued the same
/// way, and its <code>search</code> criterion's declared <code>vendorParam</code> reaches the port
/// as <code>filter</code> (Story 6.6).</p>
/// <p>Answers come from <class>OcuPilot.Test.ReadSource.Endpoint</class> through
/// <class>OcuPilot.Test.PortFixture</class> and <class>OcuPilot.Test.Read.ReadFixture</class>, so
/// nothing on the instance is read or changed. Needs <code>%Admin_Operate:U</code> or
/// <code>%Admin_Manage:U</code> for the fixture endpoint.</p>
Class OcuPilot.Test.ScreenReadSource Extends %UnitTest.TestCase
{

/// <p>The fixture descriptor whose read is a single-object <code>GET</code>.</p>
Parameter OBJECT = "OcuPilot.Test.ReadSource.Object";

/// <p>The fixture descriptor whose read lists children per parent.</p>
Parameter CHILDREN = "OcuPilot.Test.ReadSource.Children";

/// <p>The fixture descriptor whose LIST fixes <code>onDemand=1</code>.</p>
Parameter FIXED = "OcuPilot.Test.ReadSource.Fixed";

/// <p>The fixture descriptor whose read issues <code>UPCOMING</code>.</p>
Parameter UPCOMING = "OcuPilot.Test.ReadSource.Upcoming";

/// <p>The fixture descriptor whose read issues <code>HISTORY</code> with a <code>vendorParam</code>
/// criterion (Story 6.6).</p>
Parameter HISTORY = "OcuPilot.Test.ReadSource.History";

/// <p>The fixture endpoint.</p>
Parameter ENDPOINT = "OcuPilot.Test.ReadSource.Endpoint";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
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
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>The <var>pKey</var> of every row in <var>pRows</var>, comma-separated.</p>
ClassMethod Values(pRows As %DynamicArray, pKey As %String) As %String
{
    Set tValues = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tValues = tValues _ $Select(tIndex = 0: "", 1: ",") _ tRow.%Get(pKey)
    }
    Quit tValues
}

/// <p>Matrix row "Unconfigured": a single-object read whose GET answers 404 answers 200 with no rows,
/// not truncated, and the declared fields.</p>
/// <p>Mutation: fail the read on a <code>GET</code> 404 in <method>OcuPilot.Screen.Read.Execute</method>
/// -&gt; the status, 200 and row assertions go red.</p>
Method TestAnUnconfiguredObjectReadsAsNoRows()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("objectFault", "notfound")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#OBJECT, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200, never 404")
    Do $$$AssertEquals(tFault, "", "with no fault")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%ToJSON(), "[]", "and no rows")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Name"",""Metadata.scopes_supported"",""Missing.member""]", "under the declared fields")
}

/// <p>A single-object read's fault other than 404 fails the read with that fault and no rows: a 400
/// answers 400 <code>PORT.VALIDATION</code>, never an internal 500.</p>
/// <p>Mutation: answer a non-404 <code>GET</code> fault with <method>OcuPilot.Screen.Read.Internal</method>
/// in <method>OcuPilot.Screen.Read.Execute</method> -&gt; the 400 assertions go red.</p>
Method TestAnObjectFaultOtherThanNotFoundFailsTheRead()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("objectFault", "errorstatus")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#OBJECT, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code '= ""), "with a named fault")
    Do $$$AssertEquals(tResult, "", "and no result")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("objectFault", "badrequest")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#OBJECT, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusNotOK(tSC, "a 400 fails the read")
    Do $$$AssertEquals(tHttp2, 400, "with the endpoint's own status")
    Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTVALIDATION, "and its own fault code")
    Do $$$AssertEquals(tResult2, "", "and no result")
}

/// <p>Member fields: the object reads as one row carrying exactly the declared fields,
/// <code>Metadata.scopes_supported</code> read from the <code>Metadata</code> object with its JSON
/// type, an absent member <code>null</code>, and nothing else of the object; a literal dotted key the
/// object carries is read as itself. The GET carries the declared <code>source.query</code>.</p>
/// <p>Mutation: drop the member resolution from <method>OcuPilot.Screen.Read.CopyAs</method> -&gt; the
/// row's scopes read <code>null</code> and the row assertion goes red. Skip
/// <method>OcuPilot.Screen.Read.SeedSourceQuery</method> on the GET branch -&gt; the query assertion
/// goes red.</p>
Method TestAnObjectReadsAsOneRowProjectingMemberFields()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("object", {"Name": "srv", "Metadata": {"scopes_supported": ["openid", "profile"], "client_secret": "never"}, "ServerPassword": "never"}.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#OBJECT, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""srv"",""Metadata.scopes_supported"":[""openid"",""profile""],""Missing.member"":null}]", "one row of exactly the declared fields, the member read from its object")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "fixed=1", "the GET carries the fixed query")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("object", {"Name": "srv", "Metadata.scopes_supported": "literal", "Metadata": {"scopes_supported": ["openid"]}}.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#OBJECT, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the second read succeeds")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.rows.%Get(0).%Get("Metadata.scopes_supported"), "literal", "a literal dotted key the row carries is read as itself")
}

/// <p>Matrix row "forEach faults": parents P and Q, P's child list answering 404 and Q's one row,
/// answer that one row with Q's fields copied in; Q's answering an error or a 400 instead fails the
/// read with that fault, the 400 as 400 <code>PORT.VALIDATION</code>. Each child list carries the
/// declared <code>source.query</code> beside its parent key; the parent list does not.</p>
/// <p>Mutation: stop skipping a child 404 in <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt;
/// the read fails and the first half goes red. Skip <method>OcuPilot.Screen.Read.SeedSourceQuery</method>
/// in <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt; the child query assertion goes red. Answer a non-404 child fault with
/// <method>OcuPilot.Screen.Read.Internal</method> -&gt; the 400 assertions go red.</p>
Method TestAPerParentReadSkipsAChildNotFoundAndFailsOnAnyOtherFault()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "P", "IssuerEndpoint": "https://p"}, {"ID": "Q", "IssuerEndpoint": "https://q"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("childFault", "notfound", "P")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "q1", "Secret": "never"}].%ToJSON(), "Q")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""q1"",""ParentID"":""Q"",""Issuer"":""https://q""}]", "one row, from Q, with Q's fields copied in")
        Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "P,Q", "each parent's child list was read, in parent order")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "fixed=1,maxRows=1001,parentKey=P,fixed=1,maxRows=1001,parentKey=Q", "each child list carries the fixed query")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("parentQuery"), "maxRows=1001", "and the parent list does not")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "P", "IssuerEndpoint": "https://p"}, {"ID": "Q", "IssuerEndpoint": "https://q"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("childFault", "notfound", "P")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("childFault", "errorstatus", "Q")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusNotOK(tSC, "Q answering an error fails the read")
    Do $$$AssertEquals(tHttp2, 500, "with that fault's status")
    Do $$$AssertTrue($IsObject(tFault2) && (tFault2.code '= ""), "and a named fault")
    Do $$$AssertEquals(tResult2, "", "and no rows")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "P", "IssuerEndpoint": "https://p"}, {"ID": "Q", "IssuerEndpoint": "https://q"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("childFault", "badrequest", "Q")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusNotOK(tSC, "Q answering 400 fails the read")
    Do $$$AssertEquals(tHttp3, 400, "with the child's own status, never an internal 500")
    Do $$$AssertEquals($Select($IsObject(tFault3): tFault3.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTVALIDATION, "and its own fault code")
    Do $$$AssertEquals(tResult3, "", "and no rows")
}

/// <p>A parent list that fails fails the read with its own fault and no rows, never an empty list:
/// a 400 answers 400 <code>PORT.VALIDATION</code>, and no child list is read.</p>
/// <p>Mutation: read a failed parent list as no parents in
/// <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt; the read succeeds with no rows and the
/// status assertions go red.</p>
Method TestAParentListFaultFailsTheRead()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parentFault", "badrequest")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp, 400, "with the parent list's own status")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTVALIDATION, "and its own fault code")
    Do $$$AssertEquals(tResult, "", "and no rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "", "and no child list is read")
}

/// <p>The bounds (AD-36): at a cap of 1, one parent holding two children answers one row, truncated
/// by the rows held; at a cap of 2, five parents are listed at <code>maxRows</code> 3, so exactly
/// three child lists are issued, and the read is truncated by the parent list, also when the parent
/// list answers more parents than it was asked for; each child list asks for no more rows than
/// are still wanted; and once a parent's children fill the cap plus one, no later parent's
/// children are listed.</p>
/// <p>Mutation: compute <code>truncated</code> from the parent list alone in
/// <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt; the held-rows assertion goes red. List
/// the parents with the cap rather than the cap plus one -&gt; the parent-bound assertions go
/// red. Drop the parent-count stop -&gt; the uncapped parent list's child-list assertion goes
/// red. Drop the held-rows stop -&gt; the last arm's child-list assertion goes red.</p>
Method TestAPerParentReadIsBoundedByTheCapOnRowsAndParents()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "A", "IssuerEndpoint": "https://a"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "a1"}, {"Name": "a2"}].%ToJSON(), "A")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the capped read succeeds")
    If $IsObject(tResult) {
        Do $$$AssertEquals(..Values(tResult.rows, "Name"), "a1", "one row at a cap of one")
        Do $$$AssertEquals(tResult.truncated, 1, "truncated by the rows held, though one parent fit the cap")
    }

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "A"}, {"ID": "B"}, {"ID": "C"}, {"ID": "D"}, {"ID": "E"}].%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read over five childless parents succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("parentMaxRows"), 3, "the parents are listed at the cap plus one")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "A,B,C", "so at most the cap plus one child lists are issued")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.rows.%Size(), 0, "no rows")
        Do $$$AssertEquals(tResult.truncated, 1, "truncated by the parent list")
    }

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "A"}, {"ID": "B"}, {"ID": "C"}, {"ID": "D"}, {"ID": "E"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parentsUncapped", 1)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read over a parent list that ignores maxRows succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "A,B,C", "and still issues no more than the cap plus one child lists")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.truncated, 1, "truncated by the parent list")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "A"}, {"ID": "B"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "a1"}, {"Name": "a2"}].%ToJSON(), "A")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "b1"}, {"Name": "b2"}, {"Name": "b3"}, {"Name": "b4"}].%ToJSON(), "B")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, 3, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read over two parents succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childMaxRows"), "4,2", "each child list asks for the rows still wanted")
    If $IsObject(tResult) {
        Do $$$AssertEquals(..Values(tResult.rows, "Name"), "a1,a2,b1", "the cap's rows, in parent order")
        Do $$$AssertEquals(tResult.truncated, 1, "truncated, since a fourth row was held")
    }

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "A"}, {"ID": "B"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "a1"}, {"Name": "a2"}, {"Name": "a3"}].%ToJSON(), "A")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read whose first parent fills the cap succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "A", "and lists no child once the cap plus one rows are held")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.truncated, 1, "truncated by the rows held")
}

/// <p>A parent whose key is a number is read for its JSON text; a parent with no key, or an empty
/// one, is an internal fault, never a child list read for an empty key.</p>
Method TestAParentKeyIsANonEmptyStringOrANumber()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": 7, "IssuerEndpoint": "https://seven"}].%ToJSON())
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("children", [{"Name": "s1"}].%ToJSON(), "7")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a numeric key reads")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "7", "for its text")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""s1"",""ParentID"":7,""Issuer"":""https://seven""}]", "and the copied key keeps its JSON type")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"IssuerEndpoint": "https://nokey"}].%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusNotOK(tSC, "a parent with no key fails the read")
    Do $$$AssertEquals(tHttp2, 500, "as an internal fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childKeys"), "", "and no child list is read")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("parents", [{"ID": "", "IssuerEndpoint": "https://blank"}].%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#CHILDREN, "", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusNotOK(tSC, "a parent with an empty key fails the read")
    Do $$$AssertEquals(tHttp3, 500, "as an internal fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("childMaxRows"), "", "and no child list is read for the empty key")
}

/// <p>Matrix row "Fixed param": a caller supplying <code>onDemand=0</code> beside the declared
/// criterion <code>name</code> still sends <code>onDemand=1</code>, with the criterion and the cap
/// plus one; and a read with no caller values sends it too.</p>
/// <p>Mutation: skip <method>OcuPilot.Screen.Read.SeedSourceQuery</method> in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; both query assertions go red.</p>
Method TestAFixedQueryParameterReachesThePortWhateverTheCallerSends()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("rows", [{"Name": "a"}].%ToJSON())
    Kill tCriteria
    Set tCriteria("onDemand") = "0"
    Set tCriteria("name") = "a"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#FIXED, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "maxRows=6,name=a,onDemand=1", "the port receives onDemand=1, the declared criterion and the cap plus one")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("type"), 0, "as a LIST")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""a""}]", "and its rows")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Kill tNone
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#FIXED, "", .tResult2, .tHttp2, .tFault2, .tNone)
    Do $$$AssertStatusOK(tSC, "a read with no caller values succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "maxRows=1001,onDemand=1", "and still sends onDemand=1")
}

/// <p>An <code>UPCOMING</code> source is issued as that request type with its criterion and the cap
/// plus one, answers its rows under the cap and reports truncation.</p>
/// <p>Mutation: issue <parameter>OcuPilot.Screen.Read.READTYPE</parameter> for every admin read in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the fixture still answers 200 and the type
/// assertion goes red.</p>
Method TestAnUpcomingSourceIsIssuedAsItsOwnType()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("rows", [{"Id": 3, "Datetime": "2026-09-17 01:00:00"}, {"Id": 3, "Datetime": "2026-09-17 02:00:00"}].%ToJSON())
    Kill tCriteria
    Set tCriteria("hoursOffset") = "24"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#UPCOMING, 1, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("type"), ##class(OcuPilot.Test.ReadSource.Endpoint).#TYPEUPCOMING, "issued as UPCOMING")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "hoursOffset=24,maxRows=2", "with its criterion and the cap plus one")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Id"":3,""Datetime"":""2026-09-17 01:00:00""}]", "the cap's one occurrence")
        Do $$$AssertEquals(tResult.truncated, 1, "truncated")
    }
}

/// <p>Story 6.6 -- a <code>HISTORY</code> source is issued as that request type, and a criterion
/// declaring <code>vendorParam</code> reaches the port under that name, never under its own
/// <code>param</code>.</p>
/// <p>Mutation: drop the <code>vendorParam</code> lookup in
/// <method>OcuPilot.Screen.Read.SeedCriteria</method> and seed under <var>tParam</var> always -&gt;
/// the query assertion below goes red, reading <code>search=OcuPilotDemo</code> instead of
/// <code>filter=OcuPilotDemo</code>.</p>
Method TestAHistorySourceIsIssuedAsItsOwnTypeAndVendorParamReachesThePort()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("rows", [{"Name": "OcuPilotDemoTask"}].%ToJSON())
    Kill tCriteria
    Set tCriteria("search") = "OcuPilotDemo"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("type"), ##class(OcuPilot.Test.ReadSource.Endpoint).#TYPEHISTORY, "issued as HISTORY")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("query"), "filter=OcuPilotDemo,maxRows=1001", "the vendorParam name reaches the port, not the criterion's own param")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""OcuPilotDemoTask""}]", "the armed row")
    }
}

}
