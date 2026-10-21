/// <p>Pins that a request body that is valid JSON but is not the object a route expects is refused with
/// the same code and the same sentence as a missing or unreadable one (AD-12, AD-39): 400
/// <code>AGENT.BADBODY</code> carrying <parameter>OcuPilot.Api.Error.REASONAGENTBADBODY</parameter>, asserted
/// over HTTP on the three routes that refuse a well-formed object of the wrong shape: the licence key check
/// (<code>POST /license/key/validate</code>), the database wizard's step check
/// (<code>POST /database/check</code>) and the percent-class access create
/// (<code>POST /web-app/pct-access</code>). The sentence is true on each, because it names a body that is
/// missing or is not the JSON object the request expects; a sentence that blamed the reader, or the lack of
/// a body, would be false there. Each route also answers a body of the right shape with something else, so a
/// route that refused every body would not pass.</p>
/// <p><b>What it needs from the environment:</b> the REST application and the suite's own credentials. Nothing
/// is written: each wrong-shape refusal is answered before the body is used, the right-shape legs reach only the
/// licence key check, the step check and the entry rules, and the entry the percent-class legs name is in a web
/// application that does not exist.</p>
Class OcuPilot.Test.BadBodyWrongShape Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The sentence the ruling fixed, spelled out so a reword of the parameter cannot move this test with it.</p>
Parameter RULEDSENTENCE = "The request body is missing or is not the JSON object this request expects.";

/// <p>One <code>POST</code> as the suite's own credentials, with <var>pBody</var> sent as JSON.</p>
ClassMethod Post(pPath As %String, pBody As %String, Output pStatus As %Integer, Output pAnswer, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .pHeaders, pBody, "application/json")
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>Asserts that <var>pBody</var>, valid JSON that is an object, is refused by <var>pPath</var> as
/// <code>AGENT.BADBODY</code> with the ruled sentence.</p>
Method AssertWrongShape(pPath As %String, pBody As %String, pWhat As %String)
{
    Set tSent = ""
    Try { Set tSent = ##class(%DynamicObject).%FromJSON(pBody) } Catch { Set tSent = "" }
    Do $$$AssertTrue($IsObject(tSent) && tSent.%IsA("%Library.DynamicObject"), pWhat _ ": the body sent is a well-formed JSON object, so the refusal is about its shape: " _ pBody)
    Set tSC = ..Post(pPath, pBody, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the request completes")
    Do $$$AssertEquals(tStatus, 400, pWhat _ ": is refused as a bad request")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", pWhat _ ": is answered as JSON")
    Set tCode = $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")
    Set tReason = $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: "")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#AGENTBADBODY, pWhat _ ": carries the bad-body code")
    Do $$$AssertEquals(tReason, ..#RULEDSENTENCE, pWhat _ ": carries the ruled sentence: " _ tReason)
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, pWhat _ ": and it is the one the router publishes")
}

/// <p>Asserts that <var>pBody</var>, a body of the right shape, is not refused as a bad body by
/// <var>pPath</var>, and answers <var>pStatus</var>.</p>
Method AssertRightShape(pPath As %String, pBody As %String, pStatus As %Integer, pWhat As %String)
{
    Set tSC = ..Post(pPath, pBody, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the request completes")
    Do $$$AssertEquals(tStatus, pStatus, pWhat _ ": answers its own status")
    Set tCode = $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")
    Do $$$AssertTrue(tCode '= ##class(OcuPilot.Api.Error).#AGENTBADBODY, pWhat _ ": is not refused as a bad body")
}

/// <p>The licence key check refuses a body that is an object with the key the wrong type, no key, or a member
/// besides the key, with the ruled sentence; a body of exactly one string <code>Key</code> is read.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Area.OsMgmt.LicenseRules.HandleValidate</method>'s wrong-shape
/// refusal another sentence -- the three wrong-shape legs go red on the ruled sentence.</p>
Method TestALicenseKeyBodyOfTheWrongShapeIsAnsweredWithTheRuledSentence()
{
    Do ..AssertWrongShape("/license/key/validate", {"Key": 5}.%ToJSON(), "a key that is a number")
    Do ..AssertWrongShape("/license/key/validate", "{}", "no key")
    Do ..AssertWrongShape("/license/key/validate", {"Key": "x", "Other": 1}.%ToJSON(), "a member besides the key")
    Do ..AssertRightShape("/license/key/validate", {"Key": "x"}.%ToJSON(), 422, "a key that is a string")
}

/// <p>The database wizard's step check refuses a body whose <code>values</code> is not an object, or is
/// absent, and one that names a step the form does not have, with the ruled sentence; a step with its values
/// object is checked.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Area.OsMgmt.DatabaseRules.HandleCheck</method>'s shape refusal
/// another sentence -- the two shape legs go red on the ruled sentence.</p>
Method TestADatabaseCheckBodyOfTheWrongShapeIsAnsweredWithTheRuledSentence()
{
    Do ..AssertWrongShape("/database/check", {"step": "size", "values": "x"}.%ToJSON(), "values that are text")
    Do ..AssertWrongShape("/database/check", {"step": "size"}.%ToJSON(), "no values")
    Do ..AssertWrongShape("/database/check", {"step": "nosuchstep", "values": {}}.%ToJSON(), "a step the form does not have")
    Do ..AssertRightShape("/database/check", {"step": "size", "values": {}}.%ToJSON(), 200, "a step with its values")
}

/// <p>The percent-class access create refuses a body whose <code>AllowAccess</code> is not a boolean, or is
/// absent, with the ruled sentence; a body of the right shape is read on to the entry's own rules.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Area.WebApp.PctAccessSave.Create</method>'s shape refusal
/// another sentence -- the two wrong-shape legs go red on the ruled sentence.</p>
Method TestAPctAccessBodyOfTheWrongShapeIsAnsweredWithTheRuledSentence()
{
    Set tPath = "/web-app/pct-access?ns=HSCUSTOM"
    Do ..AssertWrongShape(tPath, {"Name": "/csp/ocuprobe2377", "AllowType": "AllowClass", "Class": "%OcuProbe2377.Shape", "AllowAccess": "yes"}.%ToJSON(), "an access that is text")
    Do ..AssertWrongShape(tPath, {"Name": "/csp/ocuprobe2377", "AllowType": "AllowClass", "Class": "%OcuProbe2377.Shape"}.%ToJSON(), "no access")
    Do ..AssertRightShape(tPath, {"Name": "/csp/ocuprobe2377", "AllowType": "AllowClass", "Class": "Ocuprobe2377.NoPercent", "AllowAccess": true}.%ToJSON(), 422, "an access that is a boolean")
}

}
