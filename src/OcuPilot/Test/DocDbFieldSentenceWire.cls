/// <p>Pins that a document database name refusal carries, over HTTP, the sentence the router answers for its
/// code (AD-12, AD-39): <code>POST /explorer/docdb</code> refuses an invalid name 422
/// <code>DOCDB.NAME.INVALID</code> and a name whose package this namespace keeps in another database 422
/// <code>DOCDB.NAME.MAPPED</code>, and the envelope's reason and the one violation's reason are both
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s answer for that code and the document-database
/// family's own. A caller that resolves a violation's code through the router therefore reads the sentence the
/// wire carried.</p>
/// <p><b>What it needs from the environment:</b> the REST application, the suite's own credentials and a
/// <code>USER</code> namespace. Both names are refused before the document database service is asked, and
/// nothing is created.</p>
Class OcuPilot.Test.DocDbFieldSentenceWire Extends %UnitTest.TestCase
{

/// <p>The create route, relative to the API base.</p>
Parameter SAVEPATH = "/explorer/docdb";

/// <p>The namespace the request runs in: it resolves <code>Ens</code> to a database other than its own.</p>
Parameter NAMESPACE = "USER";

/// <p>An invalid name and a mapped one, carrying the probe prefix the document database suites clean up.</p>
Parameter INVALIDNAME = "OcuProbe1917_wire";

Parameter MAPPEDNAME = "Ens.OcuProbe1917wire";

/// <p>One create over the wire as the suite's own credentials, scoped to <parameter>NAMESPACE</parameter>.</p>
ClassMethod Create(pName As %String, Output pStatus As %Integer, Output pAnswer, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#SAVEPATH _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .pHeaders, {"Name": (pName)}.%ToJSON(), "application/json")
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>Asserts that creating <var>pName</var> is refused 422 on <var>pCode</var>, and that the envelope and its
/// one violation carry the sentence the router and the family each answer for the code.</p>
Method AssertRefusal(pName As %String, pCode As %String, pWhat As %String)
{
    Set tSC = ..Create(pName, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the request completes")
    Do $$$AssertEquals(tStatus, 422, pWhat _ ": is refused as a validation failure")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", pWhat _ ": is answered as JSON")
    Set tRouter = ##class(OcuPilot.Api.Error).ReasonForViolation(pCode)
    Set tFamily = ##class(OcuPilot.Api.DocDbError).ReasonFor(pCode)
    Do $$$AssertTrue(tRouter '= "", pWhat _ ": the router answers " _ pCode _ " a sentence")
    Do $$$AssertEquals(tRouter, tFamily, pWhat _ ": and it is the family's own")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), pCode, pWhat _ ": carries " _ pCode)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), tRouter, pWhat _ ": the envelope carries the router's sentence")
    Set tViolation = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.detail.%Get("violations")) Set tViolation = tAnswer.detail.violations.%Get(0)
    Do $$$AssertTrue($IsObject(tViolation), pWhat _ ": names one violation")
    If '$IsObject(tViolation) Quit
    Do $$$AssertEquals(tViolation.%Get("field") _ "|" _ tViolation.%Get("code"), "Name|" _ pCode, pWhat _ ": on the Name field, under the same code")
    Do $$$AssertEquals(tViolation.%Get("reason"), tRouter, pWhat _ ": the violation carries the router's sentence")
}

/// <p>An invalid name is refused on <code>DOCDB.NAME.INVALID</code> with the sentence the router answers.</p>
/// <p>Mutation (Rule 19): delete the <code>DOCDB.</code> arm from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- the router answers <code>""</code>, the wire
/// still carries the family's sentence, and this goes red on the router's sentence and on the equality with
/// the wire.</p>
Method TestAnInvalidNameIsRefusedWithTheSentenceTheRouterAnswers()
{
    Do ..AssertRefusal(..#INVALIDNAME, ##class(OcuPilot.Api.DocDbError).#NAMEINVALID, "an invalid name")
}

/// <p>A name in a package this namespace keeps in another database is refused on
/// <code>DOCDB.NAME.MAPPED</code> with the sentence the router answers.</p>
/// <p>Mutation (Rule 19): as <method>TestAnInvalidNameIsRefusedWithTheSentenceTheRouterAnswers</method>.</p>
Method TestAMappedNameIsRefusedWithTheSentenceTheRouterAnswers()
{
    Do ..AssertRefusal(..#MAPPEDNAME, ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, "a mapped name")
}

}
