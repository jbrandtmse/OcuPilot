/// <p>Pins Story 18.34's Save, <code>POST /rest-service</code> (AD-10, AD-34, AD-53, AD-54, AD-55, AD-58), over the wire in
/// <code>USER</code> and <code>%SYS</code>: a document text builds the three classes, lists the service and reads back
/// matching, and the explorer's Delete then removes the specification and dispatch classes and keeps the implementation
/// class; the person builds where the agent is refused (<code>%SYS</code>, a document wider than one card) while the
/// agent's mint stays refused; and every refusal the port states -- the rules, the body, a taken name, a document the
/// management API cannot build, OcuPilot's own code -- answers its code on its field and leaves the probe state as it
/// was.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, <code>USER</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it builds and deletes REST services named <code>OcuProbe1832*</code> in <code>USER</code> and
/// <code>%SYS</code>. Every probe object is removed before and after each test and read back gone in both namespaces.</p>
Class OcuPilot.Test.RestServiceSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RestServiceProbe";

Parameter NAMESPACE = "USER";

/// <p>The namespace the agent is refused and the person is not.</p>
Parameter SYSTEMSCOPE = "%SYS";

/// <p>The Save route, relative to the API base.</p>
Parameter SAVEPATH = "/rest-service";

/// <p>The agent's create tool: its class for the mint, its name for the proposals it stores.</p>
Parameter CREATECLASS = "OcuPilot.Screen.Tool.RestServiceCreate";

Parameter CREATENAME = "webapp.restapis.create";

/// <p>The probe state of <parameter>NAMESPACE</parameter> and <parameter>SYSTEMSCOPE</parameter> before the test.</p>
Property PreparedFacts As %String(MAXLEN = "");

Property PreparedSystemFacts As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFacts = ""
    Set ..PreparedSystemFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, $ClassName() _ " builds and deletes REST services on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was built. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", ..#SYSTEMSCOPE))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", ..#SYSTEMSCOPE))
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE)
    Set ..PreparedSystemFacts = $ClassMethod(..#PROBE, "Facts", ..#SYSTEMSCOPE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe service, class and web application is removed from " _ ..#NAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#SYSTEMSCOPE), "and from " _ ..#SYSTEMSCOPE)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining", ..#NAMESPACE) _ " " _ $ClassMethod(..#PROBE, "Remaining", ..#SYSTEMSCOPE), "0 0", "and none is left in either")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The body a Save sends: the package and the document <var>pText</var>, as the dialog sends them.</p>
ClassMethod Body(pName As %String, pText As %String) As %DynamicObject
{
    Quit {"Name": (pName), "Document": (pText)}
}

/// <p>The Save of <var>pBody</var> (an object, or the raw text of one) in <var>pNamespace</var>, answered as
/// <code>status code field</code>, the field being the first violation's. <var>pAnswer</var> is the parsed envelope and
/// <var>pHeaders</var> the response headers.</p>
ClassMethod Save(pBody, pNamespace As %String = {..#NAMESPACE}, Output pAnswer, Output pHeaders) As %String
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#SAVEPATH _ "?ns=" _ $ZConvert(pNamespace, "O", "URL")
    Kill tExtra
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .pHeaders, tText, "application/json", .tExtra, 120)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Set tCode = $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
    Set tField = ""
    If $IsObject(pAnswer) && $IsObject(pAnswer.%Get("detail")) && $IsObject(pAnswer.detail.%Get("violations")) && (pAnswer.detail.violations.%Size() > 0) Set tField = pAnswer.detail.violations.%Get(0).field
    Quit tStatus _ " " _ tCode _ " " _ tField
}

/// <p>Whether the probe state of both namespaces reads as the test found it.</p>
Method Unchanged() As %Boolean
{
    Quit ($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE) = ..PreparedFacts) && ($ClassMethod(..#PROBE, "Facts", ..#SYSTEMSCOPE) = ..PreparedSystemFacts)
}

/// <p>The text of the probe document, formatted over several lines as a person pastes it.</p>
ClassMethod Text(pTitle As %String = "probe") As %String
{
    Quit ##class(OcuPilot.Screen.Tool.RestServiceCreateMint).FormattedDocument($ClassMethod(..#PROBE, "Document", pTitle))
}

/// <p>C1, the matrix's Create row: the Save of <code>OcuProbe1832P</code> from a formatted 2.0 text answers 201 as JSON
/// naming the package with a read-back that matches, builds the three classes in the request's namespace and not in the
/// install namespace, and lists the service; the explorer's Delete then removes the specification and dispatch classes
/// and keeps the implementation class.</p>
/// <p>Mutation (Rule 19): hand the port <code>{}</code> as the document in
/// <method>OcuPilot.Area.WebApp.RestServiceSave.Create</method> -- the port refuses the document, the Save answers 422 and
/// this goes red.</p>
Method TestTheSaveBuildsTheServiceAndTheExplorersDeleteRemovesIt()
{
    Set tStatus = ..Save(..Body("OcuProbe1832P", ..Text()), ..#NAMESPACE, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, "201  ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.name _ "|" _ tAnswer.readBack.verdict, "OcuProbe1832P|matches", "naming the package, with a read-back that matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832P") _ " " _ $ClassMethod(..#PROBE, "HasClass", "HSCUSTOM", "OcuProbe1832P.spec"), "111 0", "the three classes exist in the request's namespace, and not in the install namespace")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Listed", ..#NAMESPACE, "OcuProbe1832P") && $ListFind($ClassMethod(..#PROBE, "Services", ..#NAMESPACE), "OcuProbe1832P"), "and the explorer lists the service")
    Do ##class(OcuPilot.Test.RestServiceWrite).Act("delete", "OcuProbe1832P", .tDeleteStatus, .tDeleted)
    Do $$$AssertEquals(tDeleteStatus, 200, "the explorer's Delete is accepted: " _ $Select($IsObject(tDeleted): tDeleted.%ToJSON(), 1: tDeleted))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832P"), "001", "it removes the specification and dispatch classes and keeps the implementation class")
}

/// <p>C2: the person builds where the agent may not. The agent's create of <code>OcuProbe1832Sys</code> in
/// <code>%SYS</code> is refused at the mint with the code saves' sentence and nothing is stored or built; the person's Save
/// of it there answers 201, and <code>%SYS</code> holds the three classes and lists the service. A document wider than the
/// agent's card is refused to the agent and accepted by the person's Save.</p>
/// <p>Mutation (Rule 19): refuse in <method>OcuPilot.Area.WebApp.RestServiceSave.Create</method> with
/// <method>OcuPilot.Screen.Tool.RestServiceCreate.AgentProblems</method> -- the person's <code>%SYS</code> leg answers
/// 400 instead of 201 and this goes red.</p>
Method TestThePersonBuildsWhereTheAgentIsRefused()
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATENAME)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SYSTEMSCOPE)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATECLASS, "OcuProbe1832Sys", {"Name": "OcuProbe1832Sys", "Document": ($ClassMethod(..#PROBE, "Document"))}, .tProposal, .tHttp, .tProblem)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject($Get(tProposal)), "the agent's create in %SYS is refused at the mint")
    Do $$$AssertEquals($Get(tProblem), $ClassMethod(..#CREATECLASS, "AgentProblems", ..#SYSTEMSCOPE, "OcuProbe1832Sys"), "with the code saves' sentence")
    Do $$$AssertTrue($Get(tProblem) [ "%SYS", "which names %SYS: " _ $Get(tProblem))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CREATENAME), tBefore, "nothing is stored")
    Do $$$AssertTrue(..Unchanged(), "and nothing is built")

    Set tStatus = ..Save(..Body("OcuProbe1832Sys", ..Text()), ..#SYSTEMSCOPE, .tAnswer)
    Do $$$AssertEquals(tStatus, "201  ", "the person's Save of it in %SYS answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#SYSTEMSCOPE, "OcuProbe1832Sys"), "111", "%SYS holds the three classes")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Listed", ..#SYSTEMSCOPE, "OcuProbe1832Sys") && $ListFind($ClassMethod(..#PROBE, "Services", ..#SYSTEMSCOPE), "OcuProbe1832Sys"), "and lists the service")

    Set tWide = $ClassMethod(..#PROBE, "Document")
    Do tWide.info.%Set("description", $Translate($Justify("", 40000), " ", "x"))
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATECLASS, "OcuProbe1832W", {"Name": "OcuProbe1832W", "Document": (tWide)}, .tProposal, .tHttp, .tProblem)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tProblem) [ "wider than one card"), "a document wider than one card is refused to the agent: " _ $Get(tProblem))
    Set tStatus = ..Save(..Body("OcuProbe1832W", tWide.%ToJSON()), ..#NAMESPACE, .tAnswer)
    Do $$$AssertEquals(tStatus, "201  ", "and built by the person's Save: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832W"), "111", "which holds the three classes")
}

/// <p>C3, the matrix's Rules row: a package that is no package, holds a percent sign or is over 215 characters is refused
/// 422 <code>RESTSERVICE.NAME</code> on <code>Name</code>; a document that is not a string, not JSON, a JSON string (a
/// quoted URL), not 2.0 or over 1,000,000 characters is refused 422 <code>RESTSERVICE.DOCUMENT</code> on
/// <code>Document</code>; the package is judged first; and nothing is built.</p>
/// <p>Mutation (Rule 19): drop the <code>DocumentProblem</code> check from
/// <method>OcuPilot.Area.WebApp.RestServiceSave.Create</method> -- the document is no longer judged before the name is
/// read as taken, the listed service's leg answers 422 <code>RESTSERVICE.TAKEN</code> and this goes red; drop the
/// <code>NameProblem</code> check -- the package legs reach the state read, answer 400 and this goes red.</p>
Method TestTheRulesAreTheMgmntPortsAndNothingIsBuilt()
{
    Set tText = ..Text()
    Set tName = "RESTSERVICE.NAME"
    Set tDocument = "RESTSERVICE.DOCUMENT"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832T"), "a probe service is built")
    Set tSeeded = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE)
    Do $$$AssertEquals(..Save(..Body("Bad Name", tText)), "422 " _ tName _ " Name", "a package that is no package")
    Do $$$AssertEquals(..Save(..Body("%OcuProbe1832X", tText)), "422 " _ tName _ " Name", "a package holding a percent sign")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832" _ $Translate($Justify("", 204), " ", "b"), tText)), "422 " _ tName _ " Name", "a package of 216 characters")
    Do $$$AssertEquals(..Save({"Name": 7, "Document": (tText)}), "422 " _ tName _ " Name", "a package that is not a string")
    Do $$$AssertEquals(..Save(..Body("Bad Name", "not json")), "422 " _ tName _ " Name", "the package is judged before the document")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", "not json"), , .tAnswer), "422 " _ tDocument _ " Document", "a document that is no JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.detail.violations.%Get(0).reason, 1: ""), ##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT, "with the published sentence")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1832X", "Document": ($ClassMethod(..#PROBE, "Document"))}), "422 " _ tDocument _ " Document", "a document sent as an object, not as text")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1832X"}), "422 " _ tDocument _ " Document", "a document that is absent")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", "http://example.org/spec.json")), "422 " _ tDocument _ " Document", "a document that is a URL, not text")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", """http://example.org/spec.json""")), "422 " _ tDocument _ " Document", "and a JSON string that is a quoted URL")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", "[]")), "422 " _ tDocument _ " Document", "and a JSON array")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", {"swagger": "3.0", "paths": {}}.%ToJSON())), "422 " _ tDocument _ " Document", "a document whose swagger is not 2.0")
    Set tLong = $ClassMethod(..#PROBE, "Document")
    Do tLong.info.%Set("description", $Translate($Justify("", 1000001), " ", "x"))
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832X", tLong.%ToJSON())), "422 " _ tDocument _ " Document", "and a document over 1,000,000 characters")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832T", "not json")), "422 " _ tDocument _ " Document", "the document is judged before the name is read as taken")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832T"), "111", "and the listed service stands")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE), tSeeded, "no refusal built anything beyond the service the test built")
}

/// <p>C3, the matrix's Body row: a body that is no JSON object is 400 <code>AGENT.BADBODY</code>; a key besides
/// <code>Name</code> and <code>Document</code>, a namespace among them, is 400 <code>PORT.FIELD.UNEXPECTED</code> naming
/// the key, though the package and the document are valid; and nothing is built.</p>
/// <p>Mutation (Rule 19): drop the unexpected-key refusal from <method>OcuPilot.Area.WebApp.RestServiceSave.HandleCreate</method>
/// -- the <code>Namespace</code> leg builds the service and goes red.</p>
Method TestABodyThatIsNotNameAndDocumentAloneIsRefused()
{
    Set tText = ..Text()
    Do $$$AssertEquals(..Save("[]"), "400 " _ ##class(OcuPilot.Api.Error).#AGENTBADBODY _ " ", "an array is not a body")
    Do $$$AssertEquals(..Save("{not json"), "400 " _ ##class(OcuPilot.Api.Error).#AGENTBADBODY _ " ", "and neither is text that is no JSON")
    Do $$$AssertEquals(..Save(""), "400 " _ ##class(OcuPilot.Api.Error).#AGENTBADBODY _ " ", "and neither is no body at all")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1832X", "Document": (tText), "Namespace": "HSCUSTOM"}), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " Namespace", "a namespace in the body is refused")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1832X", "Document": (tText), "Url": "http://example.org"}), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " Url", "and so is a URL")
    Do $$$AssertTrue(..Unchanged() && '$ClassMethod(..#PROBE, "HasClass", "HSCUSTOM", "OcuProbe1832X.spec"), "no refusal built anything, in this namespace or the install namespace")
}

/// <p>C3, the matrix's Taken row: a name the namespace lists in another case, or in the case it is listed, and a name whose
/// dispatch class or specification class the namespace holds although no service lists it, are each refused 422
/// <code>RESTSERVICE.TAKEN</code> on <code>Name</code> with the published sentence; the held classes and the listed
/// service stand.</p>
/// <p>Mutation (Rule 19): make the taken check answer free in <method>OcuPilot.Area.WebApp.RestServiceSave.Create</method>
/// -- the held-class legs build over the held classes and go red.</p>
Method TestATakenNameIsRefusedInAnyLetterCase()
{
    Set tText = ..Text()
    Set tTaken = ##class(OcuPilot.Api.RestServiceError).#TAKEN
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, "OcuProbe1832T"), "a probe service is built")
    Do $$$AssertEquals(..Save(..Body("ocuprobe1832t", tText), , .tAnswer), "422 " _ tTaken _ " Name", "a name listed in another case is taken")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.detail.violations.%Get(0).reason, 1: ""), ##class(OcuPilot.Api.RestServiceError).#REASONTAKEN, "with the published sentence")
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832T", tText)), "422 " _ tTaken _ " Name", "and so is the name as listed")
    For tCase = $ListBuild("OcuProbe1832Q.disp", "OcuProbe1832Q"), $ListBuild("OcuProbe1832R.spec", "OCUPROBE1832R") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClass", ..#NAMESPACE, tClass), tClass _ " is held, and no service lists it")
        Do $$$AssertEquals(..Save(..Body($List(tCase, 2), tText)), "422 " _ tTaken _ " Name", $List(tCase, 2) _ " is taken by the held class")
        Do $$$AssertTrue($ClassMethod(..#PROBE, "HasClass", ..#NAMESPACE, tClass), tClass _ " stands")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832T") _ " " _ $ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832Q") _ " " _ $ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832R"), "111 010 100", "the listed service stands and the held classes stand alone, with no sibling built beside them")
}

/// <p>C3, the matrix's Build failure and Own code rows: a 2.0 document the management API cannot build is refused 422
/// <code>RESTSERVICE.BUILD</code> on <code>Document</code> and leaves no class; a package beginning <code>OcuPilot</code>, in
/// any letter case, is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> with the published sentence before anything is
/// sent. The own-code legs carry the unbuildable document, so a Save that wrongly sent them would build nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>Prohibited</code> call from
/// <method>OcuPilot.Area.WebApp.RestServiceSave.Create</method> -- the own-code legs reach the port, answer 422
/// <code>RESTSERVICE.BUILD</code>, leave nothing, and go red.</p>
Method TestABuildFailureLeavesNothingAndOcuPilotsOwnCodeIsNeverSent()
{
    Set tBroken = ##class(OcuPilot.Screen.Tool.RestServiceCreateMint).FormattedDocument($ClassMethod(..#PROBE, "Unbuildable"))
    Do $$$AssertEquals(..Save(..Body("OcuProbe1832B", tBroken)), "422 " _ ##class(OcuPilot.Api.RestServiceError).#BUILD _ " Document", "an unbuildable document is refused on Document")
    Do $$$AssertTrue(..Unchanged(), "and no class is left")
    Set tOwn = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE
    For tName = "OcuPilotProbe1834", "OCUPILOTPROBE1834" {
        Do $$$AssertEquals(..Save(..Body(tName, tBroken), , .tAnswer), "403 " _ tOwn _ " ", tName _ " is refused as OcuPilot's own code")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tOwn), "with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HasClass", ..#NAMESPACE, tName _ ".spec") + $ClassMethod(..#PROBE, "HasClass", ..#NAMESPACE, tName _ ".disp"), 0, "and no class of that package exists")
    }
    Do $$$AssertTrue(..Unchanged(), "nothing was left by any refusal")
}

}
