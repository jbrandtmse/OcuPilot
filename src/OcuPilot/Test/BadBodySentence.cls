/// <p>Pins the one sentence a refused request body carries on <code>AGENT.BADBODY</code> (AD-12,
/// AD-39), asserted over HTTP on both kinds of route: one that refuses an absent body
/// (<code>POST /license/key/validate</code>) and one that refuses an unreadable body
/// (<code>POST /agent/definitions</code>). The sentence is
/// <parameter>OcuPilot.Api.Error.REASONAGENTBADBODY</parameter>, and it is true on both: it
/// names a body that is missing or is not the JSON object the request expects, and it never tells
/// a caller that no body is acceptable.</p>
/// <p><b>What it needs from the environment:</b> the REST application and the suite's own
/// credentials. Both requests are refused before anything is read or written.</p>
Class OcuPilot.Test.BadBodySentence Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>One request as the suite's own credentials, with <var>pBody</var> sent verbatim, or no
/// body at all when it is <code>""</code>.</p>
ClassMethod Call(pPath As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>Asserts that <var>pBodyText</var> is the 400 envelope on <code>AGENT.BADBODY</code> with the
/// written sentence, as JSON, and that the sentence does not say no body is acceptable.</p>
Method AssertBadBody(pStatus As %Integer, pBodyText As %String, ByRef pHeaders, pWhat As %String)
{
    Do $$$AssertEquals(pStatus, 400, pWhat _ " is refused as a bad request: " _ pBodyText)
    Do $$$AssertEquals($ZConvert($Get(pHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, pWhat _ " is answered as JSON: " _ $Get(pHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pBodyText)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTBADBODY, pWhat _ " carries the bad-body code")
    Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, pWhat _ " carries the written sentence: " _ tAnswer.reason)
    Do $$$AssertEquals(tAnswer.reason, "The request body is missing or is not the JSON object this request expects.", pWhat _ " carries the ruled wording")
    Do $$$AssertTrue(tAnswer.reason '[ "no body", pWhat _ "'s sentence does not tell the caller that no body is acceptable: " _ tAnswer.reason)
}

/// <p>A route that requires a body refuses an absent one with the same sentence, and the sentence
/// does not tell the caller to send no body.</p>
/// <p>Mutation (Rule 19): put <code>, or no body at all</code> back at the end of
/// <parameter>OcuPilot.Api.Error.REASONAGENTBADBODY</parameter> -- this goes red on the "no body"
/// and ruled-wording assertions of both methods.</p>
Method TestAnAbsentBodyWhereOneIsRequiredIsNamedAsMissing()
{
    Set tSC = ..Call("/license/key/validate", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do ..AssertBadBody(tStatus, tBody, .tHeaders, "an absent body on the license key check")
}

/// <p>A route that accepts no body at all still refuses an unreadable one with the same sentence.</p>
Method TestAnUnreadableBodyWhereNoneIsRequiredIsRefusedWithTheSameSentence()
{
    Set tSC = ..Call("/agent/definitions", "{not json", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do ..AssertBadBody(tStatus, tBody, .tHeaders, "an unreadable body on the definitions create")
}

}
