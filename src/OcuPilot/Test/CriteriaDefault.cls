/// <p>Pins a declared criterion's default and its instance-side comparison (AD-36, Story 11.11):
/// an absent audit <code>beginDateTime</code> is sent as the instance's local now less 24 hours and
/// echoed in the answer's <code>criteria</code>, a defined empty one sends no key, Task history's
/// <code>since</code> is never sent and drops earlier rows before <code>truncated</code> is judged,
/// the read tool and the route answer the same, and an HTTP <code>?beginDateTime=</code> is not an
/// absent key.</p>
/// <p>Needs nothing from the instance: every read reaches <class>OcuPilot.Test.CriteriaDefault.Endpoint</class>
/// through <class>OcuPilot.Test.PortFixture</class>, which records the query each read seeds.</p>
Class OcuPilot.Test.CriteriaDefault Extends %UnitTest.TestCase
{

Parameter AUDIT = "OcuPilot.Screen.Descriptor.AuditList";

Parameter HISTORY = "OcuPilot.Screen.Descriptor.TaskHistoryList";

/// <p>How far, in seconds, a default may sit from the instance time this class computes itself.</p>
Parameter TOLERANCE As INTEGER = 5;

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.CriteriaDefault.Endpoint")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
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
}

/// <p>The query the last read seeded, as <var>pParams</var> subscripted by parameter name.</p>
ClassMethod SentParams(Output pParams)
{
    Kill pParams
    Set tText = ##class(OcuPilot.Test.EndpointFixture).Recorded("params")
    For tI = 1:1:$Length(tText, "&") {
        Set tPair = $Piece(tText, "&", tI)
        If tPair = "" Continue
        Set pParams($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2, *)
    }
}

/// <p>How many seconds <var>pValue</var>, a <code>YYYY-MM-DD HH:MM:SS</code>, is from the instance's
/// local now less <var>pHours</var> hours.</p>
ClassMethod SecondsOff(pValue As %String, pHours As %Integer) As %Integer
{
    Set tSent = $ZDateTimeH(pValue, 3, , , , , , , -1)
    If tSent = -1 Quit 999999
    Set tNow = $Horolog
    Set tWanted = ((+tNow * 86400) + $Piece(tNow, ",", 2)) - (pHours * 3600)
    Quit $ZAbs(((+tSent * 86400) + $Piece(tSent, ",", 2)) - tWanted)
}

/// <p>An absent begin is sent as the instance's local now less 24 hours, and the answer echoes
/// exactly what was sent. The agent marker is not part of the default (AD-46).</p>
/// <p>Mutation: drop <code>defaultHoursAgo</code> from <class>OcuPilot.Screen.Descriptor.AuditList</class>
/// -&gt; no <code>beginDateTime</code> is sent and every assertion on it goes red.</p>
Method TestAnAbsentBeginIsTheInstanceTimeLessADay()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows([{"TimeStamp": "2026-09-26 10:00:00", "Event": "Login"}].%ToJSON())
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#AUDIT, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If '$IsObject(tResult) Quit
    Do ..SentParams(.tParams)
    Set tSent = $Get(tParams("beginDateTime"))
    Do $$$AssertTrue(tSent '= "", "a begin is sent although none was supplied")
    Do $$$AssertTrue(..SecondsOff(tSent, 24) '> ..#TOLERANCE, "within " _ ..#TOLERANCE _ " s of the instance's now less 24 hours: " _ tSent)
    Do $$$AssertTrue($Match(tSent, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "in the one form the instance reads")
    Do $$$AssertEquals($Data(tParams("eventSources")), 0, "the marker is never part of the default")
    Do $$$AssertEquals($Data(tParams("endDateTime")), 0, "and an end bound declares no default")
    Do $$$AssertTrue($IsObject(tResult.criteria), "the answer reports its criteria")
    If '$IsObject(tResult.criteria) Quit
    Do $$$AssertEquals(tResult.criteria.beginDateTime, tSent, "echoing the begin that was sent")
    Do $$$AssertEquals(tResult.criteria.endDateTime, "", "and an unset end as empty")
    Do $$$AssertEquals(tResult.criteria.%Size(), 9, "every declared criterion is reported")
}

/// <p>A begin defined as empty is an unset bound: no key reaches the vendor, and the echo is
/// empty.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.SeedCriteria</method> read the value with
/// <code>$Get</code> alone, so empty and absent collapse -&gt; the default is sent and this goes
/// red.</p>
Method TestADefinedEmptyBeginSendsNoKey()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Kill tCriteria
    Set tCriteria("beginDateTime") = ""
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#AUDIT, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do ..SentParams(.tParams)
    Do $$$AssertEquals($Get(tParams("maxRows")), 6, "a query was recorded")
    Do $$$AssertEquals($Data(tParams("beginDateTime")), 0, "no begin is sent")
    Do $$$AssertEquals($Select($IsObject(tResult) && $IsObject(tResult.criteria): tResult.criteria.beginDateTime, 1: "(no criteria)"), "", "and the echo reads the bound unset")
}

/// <p>Task history's <code>since</code> is never sent to the vendor, whether defaulted or supplied,
/// and its default is the instance's now less 168 hours.</p>
Method TestSinceIsNeverSent()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the defaulted read succeeds")
    Do ..SentParams(.tParams)
    Do $$$AssertEquals($Get(tParams("maxRows")), 6, "a query was recorded")
    Do $$$AssertEquals($Data(tParams("since")), 0, "a defaulted since is not sent")
    Set tSince = $Select($IsObject(tResult) && $IsObject(tResult.criteria): tResult.criteria.since, 1: "")
    Do $$$AssertTrue(..SecondsOff(tSince, 168) '> ..#TOLERANCE, "and its echo is the instance's now less 168 hours: " _ tSince)

    Kill tCriteria
    Set tCriteria("since") = "2026-09-20 00:00:00"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the supplied read succeeds")
    Do ..SentParams(.tParams)
    Do $$$AssertEquals($Data(tParams("since")), 0, "nor is a supplied one")
    Do $$$AssertEquals($Get(tParams("maxRows")), 6, "and the vendor is asked for the cap plus one")
}

/// <p>Rows earlier than <code>since</code>, and rows with no <code>LogDatetime</code>, are dropped
/// on the instance; a row at the cutoff stays.</p>
/// <p>Mutation: skip <method>OcuPilot.Screen.Read.AtOrAfter</method> in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; four rows answer and this goes red.</p>
Method TestTheSinceCutoffDropsEarlierRows()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows([{"Name": "newer", "LogDatetime": "2026-09-21 08:00:00"}, {"Name": "at", "LogDatetime": "2026-09-20 00:00:00"}, {"Name": "older", "LogDatetime": "2026-09-19 23:59:59"}, {"Name": "unlogged", "LogDatetime": ""}].%ToJSON())
    Kill tCriteria
    Set tCriteria("since") = "2026-09-20 00:00:00"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 10, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If '$IsObject(tResult) Quit
    Set tNames = ""
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name }
    Do $$$AssertEquals(tNames, "newer,at", "the earlier and the unlogged rows are dropped, the row at the cutoff stays")
    Do $$$AssertEquals(tResult.truncated, 0, "and nothing is truncated")

    Kill tCriteria
    Set tCriteria("since") = ""
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 10, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "an explicit empty since reads")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.rows.%Size(), 4, "the whole history")
}

/// <p>The cutoff runs before truncation is judged: the vendor's cap-plus-one row is truncation only
/// when it lies inside the window.</p>
Method TestTruncationIsJudgedAfterTheCutoff()
{
    Kill tCriteria
    Set tCriteria("since") = "2026-09-20 00:00:00"
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows([{"Name": "a", "LogDatetime": "2026-09-22 00:00:00"}, {"Name": "b", "LogDatetime": "2026-09-21 00:00:00"}, {"Name": "c", "LogDatetime": "2026-09-19 00:00:00"}].%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.rows.%Size(), 2, "the cap's two rows")
        Do $$$AssertEquals(tResult.truncated, 0, "and a cap-plus-one row outside the window is not truncation")
    }
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows([{"Name": "a", "LogDatetime": "2026-09-22 00:00:00"}, {"Name": "b", "LogDatetime": "2026-09-21 00:00:00"}, {"Name": "c", "LogDatetime": "2026-09-20 12:00:00"}].%ToJSON())
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#HISTORY, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the second read succeeds")
    If $IsObject(tResult) Do $$$AssertEquals(tResult.truncated, 1, "while one inside it is")
}

/// <p>The read tool and the route apply the one default: with no criteria, both send a begin at the
/// instance's now less 24 hours, answer the same rows and echo the same criteria.</p>
Method TestTheToolAndTheRouteApplyTheSameDefault()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows([{"TimeStamp": "2026-09-26 10:00:00", "Event": "Login"}, {"TimeStamp": "2026-09-26 09:00:00", "Event": "Logout"}].%ToJSON())
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#AUDIT, 1000, .tRoute, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the route's read succeeds")
    Do ..SentParams(.tRouteParams)
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#AUDIT, {}, 1000, .tTool, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool's read succeeds")
    Do ..SentParams(.tToolParams)
    If '$IsObject(tRoute) || '$IsObject(tTool) Quit
    Do $$$AssertTrue($IsObject(tTool.criteria), "the tool's result carries criteria")
    If '$IsObject(tTool.criteria) Quit
    Do $$$AssertTrue(..SecondsOff($Get(tToolParams("beginDateTime")), 24) '> ..#TOLERANCE, "the tool sent the default begin")
    Do $$$AssertTrue(..SecondsOff($Get(tRouteParams("beginDateTime")), 24) '> ..#TOLERANCE, "and so did the route")
    Do $$$AssertEquals(tTool.criteria.beginDateTime, $Get(tToolParams("beginDateTime")), "the tool echoes what it sent")
    Do $$$AssertEquals(tTool.criteria.%Size(), tRoute.criteria.%Size(), "both report every criterion")
    Do $$$AssertEquals(tTool.rows.%ToJSON(), tRoute.rows.%ToJSON(), "and both answer the same rows")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.Read).ResultSchema(..#AUDIT), tTool, .tProblem), "the tool's result conforms to its schema: " _ $Get(tProblem))
}

/// <p>Over the route itself: a request carrying <code>?beginDateTime=</code> sends no begin, and one
/// that does not carry the key sends the default.</p>
/// <p>Mutation: make <method>OcuPilot.Api.ScreenRead.Handle</method> set every declared criterion
/// from <code>%request.Get</code> unconditionally -&gt; the absent-key leg sends no begin and goes
/// red.</p>
Method TestAnHttpEmptyBeginDiffersFromAnAbsentKey()
{
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Test.CriteriaDefault.Route", "Audit", {"maxRows": "5"}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the absent-key request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do ..SentParams(.tParams)
    Do $$$AssertTrue(..SecondsOff($Get(tParams("beginDateTime")), 24) '> ..#TOLERANCE, "an absent key sends the default begin")
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tAnswer = ""
    }
    If $IsObject(tAnswer) && $IsObject(tAnswer.criteria) Do $$$AssertEquals(tAnswer.criteria.beginDateTime, $Get(tParams("beginDateTime")), "and echoes it")

    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Test.CriteriaDefault.Route", "Audit", {"maxRows": "5", "beginDateTime": ""}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the empty-value request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do ..SentParams(.tParams)
    Do $$$AssertEquals($Data(tParams("beginDateTime")), 0, "while ?beginDateTime= sends none")
    Do $$$AssertTrue(##class(OcuPilot.Test.EndpointFixture).Recorded("params") '= "", "a query was recorded, so the absence above is an observation")
}

}
