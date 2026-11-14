/// <p>Pins, over HTTP, what a person's client receives when a request body holds a value the instance
/// cannot hold (DW-2417, AD-39): a number past the largest it reads. Area routes that read the body through
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> answer 400 <code>PORT.FIELD.SHAPE</code> naming the
/// top-level key; a malformed body keeps its <code>AGENT.BADBODY</code> answer; the three routes that
/// answer every unusable body with their own input refusal (<code>EXPLORER.SQL.INPUT</code>,
/// <code>EXPLORER.DATA.INPUT</code>, <code>ANALYTICS.MDX.INPUT</code>) answer that 400.</p>
/// <p><b>What it needs from the environment:</b> the REST application and the suite's own credentials.
/// Nothing is written or run: every body is refused before it is used.</p>
Class OcuPilot.Test.BodyOversizedWire Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>One <code>POST</code> of the text <var>pBody</var> to <var>pPath</var> as the suite's own credentials:
/// the status and the parsed answer.</p>
ClassMethod Post(pPath As %String, pBody As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ pPath _ "?ns=HSCUSTOM", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, pBody, "application/json")
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>The answer as <code>status|code</code>.</p>
ClassMethod Line(pStatus As %Integer, pAnswer) As %String
{
    Quit pStatus _ "|" _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The first violation of a field-shape answer as <code>field|code|reason</code>, or <code>""</code>.</p>
ClassMethod Violation(pAnswer) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("detail")) || '$IsObject(pAnswer.%Get("detail").%Get("violations")) Quit ""
    Set tViolation = pAnswer.%Get("detail").%Get("violations").%Get(0)
    If '$IsObject(tViolation) Quit ""
    Quit tViolation.%Get("field") _ "|" _ tViolation.%Get("code") _ "|" _ tViolation.%Get("reason")
}

/// <p>A body holding a number past the largest the instance reads is refused 400
/// <code>PORT.FIELD.SHAPE</code> on the key that carries it, with the code's published sentence, on a route
/// that calls the reader directly (<code>POST /license/key/validate</code>) and on one that wraps it
/// (<code>POST /database/check</code>); a key holding the number inside an array is named by the top-level key.</p>
/// <p>Mutation (Rule 19): remove the oversized-value guard from
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> -- neither route answers the field refusal, and the legs go red.</p>
Method TestAnOversizedNumberIsRefusedOnItsFieldOverHttp()
{
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tExpected = "Extra|" _ tShape _ "|" _ ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE
    Set tSC = ..Post("/license/key/validate", "{""Key"": ""x"", ""Extra"": 1e400}", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the licence key check completes")
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "400|" _ tShape, "the licence key check refuses it as a field shape, not a 500")
    Do $$$AssertEquals(..Violation(tAnswer), tExpected, "naming the key with the published sentence")

    Set tSC = ..Post("/database/check", "{""step"": ""size"", ""values"": {}, ""Extra"": -1e400}", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the database step check completes")
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "400|" _ tShape, "the database step check refuses it as a field shape")
    Do $$$AssertEquals(..Violation(tAnswer), tExpected, "naming the key with the published sentence")

    Set tSC = ..Post("/database/check", "{""step"": ""size"", ""values"": {}, ""list"": [1, -1e400]}", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "a request with the number nested in an array completes")
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "400|" _ tShape, "a number nested in an array is refused too")
    Do $$$AssertEquals($Piece(..Violation(tAnswer), "|", 1), "list", "naming the top-level key")
}

/// <p>Values the instance can hold, and malformed JSON, are not answered as a field shape: the largest
/// double the instance reads is read on to the route's own answer, and an unterminated object keeps
/// 400 <code>AGENT.BADBODY</code> with no violations.</p>
/// <p>Mutation (Rule 19): judge numbers by <code>$IsValidNum</code> in
/// <method>OcuPilot.Kernel.Utils.HoldsOversized</method> -- the <code>1e308</code> leg goes red.</p>
Method TestAHoldableValueAndMalformedJsonKeepTheirOwnAnswers()
{
    Set tSC = ..Post("/database/check", "{""step"": ""size"", ""values"": {}, ""n"": 1e308}", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "a body holding 1e308 completes")
    Do $$$AssertNotEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "1e308 is held, so it is not refused as a field shape")
    Do $$$AssertTrue(tStatus < 500, "and it does not answer a server fault: " _ tStatus)

    Set tSC = ..Post("/license/key/validate", "{""a"":", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "a malformed body completes")
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "400|" _ ##class(OcuPilot.Api.Error).#AGENTBADBODY, "it stays the bad-body answer")
    Do $$$AssertEquals(..Violation(tAnswer), "", "with no violations")
}

/// <p>The three routes that answer every unusable body with their own input refusal answer it for an
/// oversized value, with no field named:
/// <code>POST /explorer/sql/run</code> and <code>/explorer/sql/plan</code>
/// (<code>EXPLORER.SQL.INPUT</code>), <code>POST /explorer/sql/data</code> (<code>EXPLORER.DATA.INPUT</code>)
/// and <code>POST /analytics/mdx/background</code> (<code>ANALYTICS.MDX.INPUT</code>).</p>
/// <p>Mutation (Rule 19): remove the oversized-value guard from
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> -- each leg answers 500 and goes red.</p>
Method TestTheRoutesWithTheirOwnInputRefusalAnswerItForAnOversizedValue()
{
    Set tOver = ", ""Extra"": 1e400}"
    Set tCases = ""
    Set tCases = tCases _ $ListBuild($ListBuild("/explorer/sql/run", "{""statement"": ""SELECT 1""" _ tOver, ##class(OcuPilot.Api.AtelierError).#SQLINPUT))
    Set tCases = tCases _ $ListBuild($ListBuild("/explorer/sql/plan", "{""statement"": ""SELECT 1""" _ tOver, ##class(OcuPilot.Api.AtelierError).#SQLINPUT))
    Set tCases = tCases _ $ListBuild($ListBuild("/explorer/sql/data", "{""schema"": ""SQLUser"", ""table"": ""T""" _ tOver, ##class(OcuPilot.Api.AtelierError).#DATAINPUT))
    Set tCases = tCases _ $ListBuild($ListBuild("/analytics/mdx/background", "{""statement"": ""SELECT FROM X""" _ tOver, ##class(OcuPilot.Api.AnalyticsError).#MDXINPUT))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..Post($List(tCase, 1), $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the request completes")
        Do $$$AssertEquals(..Line(tStatus, tAnswer), "400|" _ $List(tCase, 3), $List(tCase, 1) _ ": answers its own input refusal, not a 500")
        Do $$$AssertEquals(..Violation(tAnswer), "", $List(tCase, 1) _ ": and names no field")
    }
}

}
