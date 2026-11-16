/// <p>Pins Story 24.9's promote over the real route and the real tool dispatch, as least-privileged principals (AD-8, AD-29, AD-53,
/// AD-61 rule 1): <code>POST /screens/explorer.namespacediff/dryrun</code> and <code>/action</code> and a turn that calls
/// <code>explorer.namespacediff.promote</code> and whose proposal is confirmed over HTTP, each signed in as a principal that holds
/// <code>%Development:USE</code> and the database pairs it is given, with WRITE on a routines database only where the test says so.
/// No test seam stands in for the gate, the port or the route's handler.</p>
/// <p>What it pins: a principal missing WRITE on the other namespace's routines database, or either namespace's read pair, is
/// refused 403 naming that pair and writes nothing, and a principal holding them promotes; a change in either namespace after the
/// review refuses the action as stale; each refusal of the matrix (a name outside the plan, a name beginning with
/// <code>%</code>, <code>%SYS</code>, too many names, a class that would lose its storage, a document of OcuPilot's own) is answered
/// with its status and code and writes nothing; and the agent's call is refused without its key and without the write pair, is
/// confirmed over HTTP with both, and is refused at the confirm after a change in the first namespace.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed, and the namespaces
/// <code>USER</code> and <code>HSCUSTOM</code>. Each test saves and removes the probe documents in both and puts the stored
/// governance policy back; the principals, their roles and the probe definition are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.NamespacePromoteRoute Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FLOOR = "OcuPilot.Test.DeveloperFloorFixture";

Parameter GOVERNANCE = "OcuPilot.Test.GovernanceFixture";

Parameter PORT = "OcuPilot.Port.DevToolPort";

Parameter TAG = "namespacepromoteroute-probe";

Parameter TOOLNAME = "explorer.namespacediff.promote";

Parameter SCREEN = "/screens/explorer.namespacediff";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter STEPS = "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248Mac.mac";

Parameter OWN = "OcuPilot.Port.DevToolPort.cls";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

/// <p>The governance policy found before each test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespacePromoteRoute creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespacePromoteRoute teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = $ClassMethod(..#GOVERNANCE, "Snapshot", .tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = $ClassMethod(..#GOVERNANCE, "Clear")
    If $$$ISERR(tSC) Quit tSC
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "no probe document is left from before")
    Quit $ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE)
}

Method OnAfterOneTest() As %Status
{
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK($ClassMethod(..#GOVERNANCE, "Restore", .tRows), "the policy found before the test is put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe documents are removed from both namespaces")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveStoragePair", ..#HERE, ..#THERE), "the storage probe is removed from both namespaces")
    Quit $$$OK
}

/// <p>The role grant that reads the pairs of each namespace in <var>pRead</var> (comma-separated) and writes the routines
/// database of each in <var>pWrite</var>, with <code>%Development:USE</code>.</p>
ClassMethod Grants(pRead As %String, pWrite As %String) As %String
{
    Kill tHeld
    For tI = 1:1:$Length(pRead, ",") {
        Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs($Piece(pRead, ",", tI))
        For tJ = 1:1:$ListLength(tPairs) {
            Set tResource = $List($List(tPairs, tJ), 1)
            If '$Data(tHeld(tResource)) Set tHeld(tResource) = "R"
        }
    }
    For tI = 1:1:$Length(pWrite, ",") {
        If $Piece(pWrite, ",", tI) = "" Continue
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources($Piece(pWrite, ",", tI), .tCode, .tGlobal, .tMapped, .tResolved)
        If tResolved Set tHeld(tCode) = "RW"
    }
    Set tGrants = "%Development:U"
    Set tResource = ""
    For {
        Set tResource = $Order(tHeld(tResource))
        If tResource = "" Quit
        Set tGrants = tGrants _ "," _ tResource _ ":" _ tHeld(tResource)
    }
    Quit tGrants
}

/// <p>Create the principal that reads <var>pRead</var> and writes <var>pWrite</var>, and read back that it holds WRITE on the
/// routines database of each namespace in <var>pWrite</var> and of no other namespace this test touches, and no administrative
/// resource. Answers its name.</p>
Method Principal(pRead As %String, pWrite As %String) As %String
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tGrant = ..Grants(pRead, pWrite)
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0), tGrant)
    Do $$$AssertStatusOK(tSC, "the principal is created holding " _ tGrant)
    Set tSC = $ClassMethod(..#FLOOR, "Composed", tUser, .tComposed)
    Do $$$AssertStatusOK(tSC, "its composed privileges read back")
    If $$$ISERR(tSC) Quit tUser
    Set tHeld = ""
    For tNamespace = ..#HERE, ..#THERE {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tNamespace, .tCode, .tGlobal, .tMapped, .tResolved)
        Set tHeld = tHeld _ $ClassMethod(..#FLOOR, "Holds", tComposed, tCode, "WRITE") _ "|"
    }
    Set tExpected = ($ListFind($ListFromString(pWrite, ","), ..#HERE) > 0) _ "|" _ ($ListFind($ListFromString(pWrite, ","), ..#THERE) > 0) _ "|"
    Do $$$AssertEquals(tHeld, tExpected, "it holds WRITE on the routines database of " _ $Select(pWrite = "": "neither namespace", 1: pWrite) _ " and of no other")
    Do $$$AssertEquals($ClassMethod(..#FLOOR, "HoldsAdministrative", tComposed), 0, "and no administrative resource")
    Quit tUser
}

/// <p>One <code>POST</code> of <var>pBody</var> to <var>pRoute</var> (<code>action</code> or <code>dryrun</code>) of the screen,
/// scoped to <var>pScope</var>, as <var>pUser</var>; <var>pAnswer</var> is the parsed answer, or <code>""</code> when it is not
/// JSON.</p>
Method Post(pUser As %String, pScope As %String, pRoute As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", "POST", ..#SCREEN _ "/" _ pRoute _ "?ns=" _ pScope, pUser, ..PreparedPassword, pBody.%ToJSON(), .pStatus, .tText, .tHeaders)
    Try { Set pAnswer = ##class(%DynamicAbstractObject).%FromJSON(tText) } Catch {}
    Do $$$AssertTrue($IsObject(pAnswer), "the answer parses: " _ $Extract($Get(tText), 1, 200))
    Quit tSC
}

/// <p>The body of a promote of <var>pIds</var> into <var>pTarget</var> for <var>pSpec</var>, reviewed at <var>pReviewed</var>
/// when that is not <code>""</code>.</p>
ClassMethod Body(pIds As %String, pTarget As %String, pSpec As %String, pReviewed As %String = "") As %DynamicObject
{
    Set tBody = {"action": "promote"}
    Do tBody.%Set("id", pIds, "string")
    Set tValues = {}
    Do tValues.%Set("target", pTarget, "string")
    Do tValues.%Set("spec", pSpec, "string")
    Do tValues.%Set("generated", "no", "string")
    If pReviewed '= "" Do tValues.%Set("Reviewed", pReviewed, "string")
    Do tBody.%Set("values", tValues)
    Quit tBody
}

/// <p>The dry run's digest of <var>pIds</var> from <var>pScope</var> into <var>pTarget</var> as <var>pUser</var>, or
/// <code>""</code>.</p>
Method Digest(pUser As %String, pScope As %String, pIds As %String, pTarget As %String, pSpec As %String) As %String
{
    Do ..Post(pUser, pScope, "dryrun", ..Body(pIds, pTarget, pSpec), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the dry run answers for " _ pScope _ " into " _ pTarget _ ": " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 250), 1: ""))
    If '$IsObject(tAnswer) || (tStatus '= 200) Quit ""
    Quit tAnswer.review.%Get("Digest")
}

/// <p>The promote action as <var>pUser</var>.</p>
Method Act(pUser As %String, pScope As %String, pIds As %String, pTarget As %String, pSpec As %String, pReviewed As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject)
{
    Do ..Post(pUser, pScope, "action", ..Body(pIds, pTarget, pSpec, pReviewed), .pStatus, .pAnswer)
}

/// <p>The hash of each probe document <var>pNamespace</var> holds under <var>pSpec</var>, as <code>name=hash</code> entries,
/// semicolon-joined: a namespace's state before and after a refusal.</p>
ClassMethod State(pNamespace As %String, pSpec As %String = {..#SPEC}) As %String
{
    Kill tCriteria
    Set tCriteria("spec") = pSpec
    Set tCriteria("namespace") = pNamespace
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault)
    Set tState = ""
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unread"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tState = tState _ tRow.%Get("Document") _ "=" _ tRow.%Get("Hash") _ ";"
    }
    Quit tState
}

/// <p>One document's hash in <var>pNamespace</var>, or <code>""</code>.</p>
ClassMethod HashOf(pNamespace As %String, pDocument As %String) As %String
{
    Set tState = ..State(pNamespace, pDocument)
    Quit $Piece($Piece(tState, "=", 2), ";", 1)
}

/// <p>Save <code>OcuProbe248.Changed</code> in <var>pNamespace</var> again with a method named <var>pMethod</var>.</p>
Method ResaveChanged(pNamespace As %String, pMethod As %String)
{
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, "OcuProbe248.Changed", $ClassMethod(..#PROBE, "PairText", "Changed", pMethod)), "Changed is saved again in " _ pNamespace)
}

/// <p>Assert <var>pAnswer</var>, answered <var>pStatus</var>, is a refusal <var>pHttp</var> with <var>pCode</var>; when
/// <var>pPair</var> is not <code>""</code> it names that pair, and when <var>pDocument</var> is not <code>""</code> its detail
/// names that document.</p>
Method AssertRefused(pStatus As %Integer, pAnswer As %DynamicObject, pHttp As %Integer, pCode As %String, pLabel As %String, pPair As %String = "", pDocument As %String = "")
{
    Do $$$AssertEquals(+pStatus, pHttp, pLabel _ ": HTTP status")
    If '$IsObject(pAnswer) Quit
    Do $$$AssertEquals(pAnswer.%Get("code"), pCode, pLabel _ ": code")
    If pPair '= "" {
        Do $$$AssertEquals($Select($IsObject(pAnswer.%Get("detail")): pAnswer.detail.%Get("failedPair"), 1: ""), pPair, pLabel _ ": names the pair")
    }
    If pDocument '= "" {
        Do $$$AssertEquals($Select($IsObject(pAnswer.%Get("detail")): pAnswer.detail.%Get("document"), 1: ""), pDocument, pLabel _ ": names the document")
    }
}

/// <p><b>AC1 and AC2 at the real route.</b> A principal that reads both namespaces and cannot write <code>HSCUSTOM</code>'s routines
/// database is refused 403 naming <code>%DB_HSCUSTOM:WRITE</code>; one that holds <code>HSCUSTOM</code> and not <code>USER</code>
/// is refused 403 naming <code>%DB_USER:READ</code> when <code>USER</code> is the route's scope; one that holds <code>USER</code> and
/// not <code>HSCUSTOM</code> is refused naming a pair of <code>HSCUSTOM</code>; each leaves <code>HSCUSTOM</code> as it was. A principal
/// holding both reads and WRITE on <code>HSCUSTOM</code> reviews and promotes the three steps: each document's hash in
/// <code>HSCUSTOM</code> then equals <code>USER</code>'s, and the two documents the plan leaves alone are untouched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.ExplorerNamespacePromote.ArgumentPairs</method> answer no pair and skip
/// the evaluation of <code>WritePairs</code> in <method>OcuPilot.Port.DevToolPort.Promote</method> -- the first leg writes and
/// this goes red.</p>
Method TestEachNamespacePassesItsOwnGateAndOnlyAWriterPromotes()
{
    Set tBefore = ..State(..#THERE)
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    Set tReader = ..Principal(..#HERE _ "," _ ..#THERE, "")
    Do ..Post(tReader, ..#HERE, "dryrun", ..Body(..#STEPS, ..#THERE, ..#SPEC), .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 403, "AUTH.NOPRIVILEGE", "a reader of both, the dry run", "%DB_HSCUSTOM:WRITE")
    Do ..Act(tReader, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 403, "AUTH.NOPRIVILEGE", "a reader of both", "%DB_HSCUSTOM:WRITE")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "a reader of both wrote nothing")

    Set tUser = ..Principal(..#THERE, ..#THERE)
    Do ..Act(tUser, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 403, "NS.DENIED", "a writer of HSCUSTOM who cannot read USER, USER as the scope", "%DB_USER:READ")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "it wrote nothing")

    Set tUser = ..Principal(..#HERE, "")
    Do ..Act(tUser, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 403, "a reader of USER alone is refused: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertTrue($Extract(tAnswer.detail.%Get("failedPair"), 1, 13) = "%DB_HSCUSTOM:", "naming a pair of HSCUSTOM: " _ tAnswer.detail.%Get("failedPair"))
    Do $$$AssertEquals(..State(..#THERE), tBefore, "it wrote nothing")

    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tLeftAlone = ..HashOf(..#THERE, "OcuProbe248.OnlyThere.cls") _ "|" _ ..HashOf(..#THERE, "OcuProbe248.Same.cls")
    Do $$$AssertTrue($Length(tLeftAlone) = 129, "both documents left alone are held in HSCUSTOM before the promote")
    Do $$$AssertEquals($Length(tDigest), 64, "the dry run's digest is the 64-hex plan hash")
    Do ..Act(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the writer's promote answers: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If '$IsObject(tAnswer) Quit
    Set tOutcomes = ""
    Set tOutput = tAnswer.%Get("output")
    If $IsObject(tOutput) && $IsObject(tOutput.%Get("documents")) {
        Set tIterator = tOutput.documents.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDocument) {
            Set tOutcomes = tOutcomes _ $Select(tOutcomes = "": "", 1: ",") _ tDocument.%Get("Outcome")
        }
    }
    Do $$$AssertEquals(tOutcomes, "Replaced,Added,Added", "each document's outcome")
    For tDocument = "OcuProbe248.Changed.cls", "OcuProbe248.OnlyHere.cls", "OcuProbe248Mac.mac" {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": HSCUSTOM holds USER's text")
    }
    Do $$$AssertEquals(..HashOf(..#THERE, "OcuProbe248.OnlyThere.cls") _ "|" _ ..HashOf(..#THERE, "OcuProbe248.Same.cls"), tLeftAlone, "the document only in HSCUSTOM and the identical one are untouched")
    Do $$$AssertEquals(..HashOf(..#HERE, "OcuProbe248.OnlyThere.cls"), "", "and nothing was written to USER")
}

/// <p><b>AC2 at the real route.</b> A change after the review refuses the action 409 <code>EXPLORER.PROMOTE.STALE</code> and
/// writes nothing, whichever namespace changed: <code>Changed</code> saved again in <code>HSCUSTOM</code>, in <code>USER</code>, or a
/// new document the spec matches saved in <code>USER</code>. A review taken after the changes promotes.</p>
/// <p>Mutation (Rule 19): make the reviewed-hash comparison inert in <method>OcuPilot.Port.DevToolPort.Promote</method> -- the
/// first leg writes and this goes red.</p>
Method TestAChangeInEitherNamespaceAfterTheReviewRefusesTheAction()
{
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tBefore = ..State(..#THERE)
    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    Do ..ResaveChanged(..#THERE, "ResavedThere")
    Set tAfterThere = ..State(..#THERE)
    Do $$$AssertNotEquals(tAfterThere, tBefore, "the re-save moved HSCUSTOM's copy")
    Do ..Act(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 409, "EXPLORER.PROMOTE.STALE", "a change in the target")
    Do $$$AssertEquals(..State(..#THERE), tAfterThere, "nothing was written, and the re-saved text is kept")

    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    Do ..ResaveChanged(..#HERE, "ResavedHere")
    Do ..Act(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 409, "EXPLORER.PROMOTE.STALE", "a change in the source")
    Do $$$AssertEquals(..State(..#THERE), tAfterThere, "nothing was written")

    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#HERE, "OcuProbe248.Extra", $ClassMethod(..#PROBE, "PairText", "Same", "Extra")), "a document the spec matches is saved in USER")
    Do ..Act(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 409, "EXPLORER.PROMOTE.STALE", "a new document in the source")
    Do $$$AssertEquals(..State(..#THERE), tAfterThere, "nothing was written")

    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    Do ..Act(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a review taken after the changes promotes: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: ""))
    Do $$$AssertEquals(..HashOf(..#THERE, "OcuProbe248.Changed.cls"), ..HashOf(..#HERE, "OcuProbe248.Changed.cls"), "and HSCUSTOM then holds USER's Changed")
}

/// <p><b>AC2 at the real route.</b> A writer's request is refused with its status and code, and writes nothing: a name the plan does
/// not list as a step, even beside a real step (400 <code>EXPLORER.PROMOTE.NOTASTEP</code> naming it), a name beginning with
/// <code>%</code> (400 <code>EXPLORER.PROMOTE.SYSTEM</code>), <code>%SYS</code> as the target (refused by the gate or as the system
/// namespace, never written), and 101 names (400 <code>PORT.VALIDATION</code>).</p>
/// <p>Mutation (Rule 19): skip the step lookup in <method>OcuPilot.Port.DevToolPort.Compose</method> -- the name legs write and this
/// goes red.</p>
Method TestEveryPlanRefusalIsAnsweredAtTheRoute()
{
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tBefore = ..State(..#THERE)
    Set tDigest = ..Digest(tWriter, ..#HERE, ..#STEPS, ..#THERE, ..#SPEC)
    For tName = "OcuProbe248.Same.cls", "OcuProbe248.OnlyThere.cls", "OcuProbe248.Nothing.cls" {
        Do ..Act(tWriter, ..#HERE, "OcuProbe248.Changed.cls," _ tName, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
        Do ..AssertRefused(tStatus, tAnswer, 400, "EXPLORER.PROMOTE.NOTASTEP", tName, "", tName)
    }
    Do ..Act(tWriter, ..#HERE, "OcuProbe248.Changed.cls,%Library.Foo.cls", ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 400, "EXPLORER.PROMOTE.SYSTEM", "a name beginning with %")
    Do ..Act(tWriter, ..#HERE, ..#STEPS, "%SYS", ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do $$$AssertTrue($ListFind($ListBuild(400, 403), +tStatus) > 0, "%SYS as the target is refused: " _ tStatus _ " " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: ""))
    Set tMany = ""
    For tI = 1:1:101 Set tMany = tMany _ $Select(tI = 1: "", 1: ",") _ "OcuProbe248.Many" _ tI _ ".cls"
    Do ..Act(tWriter, ..#HERE, tMany, ..#THERE, ..#SPEC, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "101 names")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p><b>AC2 at the real route.</b> A class whose copy in <code>HSCUSTOM</code> holds a storage definition its copy in
/// <code>USER</code> lacks is refused 409 <code>EXPLORER.PROMOTE.STORAGE</code> naming it, a create sorted before it is not written
/// either, and <code>HSCUSTOM</code> is unchanged. A document of OcuPilot's own, promoted from <code>HSCUSTOM</code> into
/// <code>USER</code> by a principal that holds WRITE on <code>USER</code>, is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> and
/// <code>USER</code> gains nothing.</p>
/// <p>Mutation (Rule 19): drop the storage guard's comparison in <method>OcuPilot.Port.DevToolPort.Preflight</method> -- the first
/// leg writes and this goes red.</p>
Method TestAStorageLossAndAnOwnClassAreRefusedAtTheRoute()
{
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeStoragePair", ..#HERE, ..#THERE), "the storage probe is saved")
    Set tBeside = $Parameter(..#PROBE, "STORAGEPACKAGE") _ ".Before"
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#HERE, tBeside, "Class " _ tBeside _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)), "a class beside it is saved in USER only")
    Set tSpec = $Parameter(..#PROBE, "STORAGEPACKAGE") _ ".*.cls"
    Set tName = $Parameter(..#PROBE, "STORAGECLASS") _ ".cls"
    Set tNames = tBeside _ ".cls," _ tName
    Set tBefore = ..State(..#THERE, tSpec)
    Set tDigest = ..Digest(tWriter, ..#HERE, tNames, ..#THERE, tSpec)
    Do ..Act(tWriter, ..#HERE, tNames, ..#THERE, tSpec, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 409, "EXPLORER.PROMOTE.STORAGE", "a class that would lose its storage", "", tName)
    Do $$$AssertEquals(..State(..#THERE, tSpec), tBefore, "HSCUSTOM is unchanged, the class beside it included")

    Set tUserWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#HERE)
    Set tBefore = ..State(..#HERE, ..#OWN)
    Set tDigest = ..Digest(tUserWriter, ..#THERE, ..#OWN, ..#HERE, ..#OWN)
    Do ..Act(tUserWriter, ..#THERE, ..#OWN, ..#HERE, ..#OWN, tDigest, .tStatus, .tAnswer)
    Do ..AssertRefused(tStatus, tAnswer, 403, ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, "a document of OcuPilot's own")
    Do $$$AssertEquals(..State(..#HERE, ..#OWN) _ "|" _ tBefore, "|", "USER holds no such document")
}

/// <p>The call of the promote tool the provider names: id <var>pId</var>, the documents <var>pDocuments</var>, into
/// <code>HSCUSTOM</code>.</p>
ClassMethod Call(pId As %String, pDocuments As %String) As %DynamicObject
{
    Set tCall = {"input": {"rationale": "Move the reviewed documents.", "expectedImpact": "The other namespace holds them."}}
    Do tCall.%Set("id", pId, "string")
    Do tCall.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME), "string")
    Do tCall.input.%Set("target", ..#THERE, "string")
    Do tCall.input.%Set("spec", ..#SPEC, "string")
    Do tCall.input.%Set("Documents", pDocuments, "string")
    Quit tCall
}

/// <p>Run one turn over <code>USER</code> as <var>pUser</var> whose model calls the promote tool once with <var>pCall</var>, then
/// says it is done. <var>pView</var> is the finished turn, <var>pResult</var> the tool result the model read, unwrapped from its
/// data frame, and <var>pIsError</var> its error flag.</p>
Method RunTurn(pUser As %String, pCall As %DynamicObject, Output pView, Output pResult As %String, Output pIsError As %Boolean) As %String
{
    Set pView = ""
    Set pResult = ""
    Set pIsError = 0
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG), "the probe row is armed for this turn")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(pCall)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", pUser, ..PreparedPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    If tConvId = "" Quit ""
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#HERE, pUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "promote the reviewed documents", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit ""
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, pUser, ..PreparedPassword, 90, .pView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    If tState '= "completed" Quit tState
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") '= "tool_result" Continue
            Set pResult = $ClassMethod(..#FIXTURE, "Unwrapped", tBlock.%Get("content"), .tWrapped)
            Set pIsError = +tBlock.%Get("is_error")
            Do $$$AssertTrue(tWrapped, "the result reaches the model framed as data (AD-60)")
        }
    }
    Quit tState
}

/// <p>The code of the JSON object <var>pResult</var> holds, or <code>""</code>.</p>
ClassMethod CodeOf(pResult As %String) As %String
{
    Try {
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pResult)
        Quit
    } Catch {
        Set tParsed = ""
    }
    Quit $Select($IsObject(tParsed): tParsed.%Get("code"), 1: "")
}

/// <p>The proposals the finished turn <var>pView</var> holds.</p>
ClassMethod Proposals(pView As %DynamicObject) As %DynamicArray
{
    Quit $Select($IsObject(pView) && $IsObject(pView.%Get("proposals")): pView.proposals, 1: [])
}

/// <p>Enable the promote's key through its stored setting.</p>
Method EnableKey()
{
    Kill tSettings
    Set tSettings(..#TOOLNAME) = "enabled"
    Do $$$AssertStatusOK($ClassMethod(..#GOVERNANCE, "Apply", "", .tSettings), "the promote's key is enabled through its stored setting")
}

/// <p><b>AC5 at the real tool dispatch.</b> A turn run as a principal that holds WRITE on <code>HSCUSTOM</code> has the promote call
/// refused <code>GOVERNANCE.DISABLED</code> at the shipped key and mints no proposal; with the key enabled, a turn run as a
/// principal that cannot write <code>HSCUSTOM</code> has it refused <code>AUTH.NOPRIVILEGE</code> and mints none. Nothing is written
/// either time.</p>
/// <p>Mutation (Rule 19): set the key to <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</code> -- the first leg mints
/// a proposal and this goes red.</p>
Method TestTheAgentsCallIsRefusedWithoutItsKeyAndWithoutTheWritePair()
{
    Set tBefore = ..State(..#THERE)
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tState = ..RunTurn(tWriter, ..Call("toolu_key", ..#STEPS), .tView, .tResult, .tIsError)
    If tState = "completed" {
        Do $$$AssertEquals(tIsError _ "|" _ ..CodeOf(tResult), "1|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "at the shipped key governance refuses the call: " _ $Extract(tResult, 1, 200))
        Do $$$AssertEquals(..Proposals(tView).%Size(), 0, "and no proposal is minted")
    }
    Do ..EnableKey()
    Set tReader = ..Principal(..#HERE _ "," _ ..#THERE, "")
    Set tState = ..RunTurn(tReader, ..Call("toolu_pair", ..#STEPS), .tView, .tResult, .tIsError)
    If tState = "completed" {
        Do $$$AssertEquals(tIsError _ "|" _ ..CodeOf(tResult), "1|AUTH.NOPRIVILEGE", "a principal that cannot write HSCUSTOM is refused with the key enabled: " _ $Extract(tResult, 1, 200))
        Do $$$AssertEquals(..Proposals(tView).%Size(), 0, "and no proposal is minted")
    }
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p><b>AC5 at the real tool dispatch.</b> With the key enabled, a turn run as a writer of <code>HSCUSTOM</code> mints one proposal of
/// the three steps that writes nothing; the same principal confirms it over HTTP scoped to <code>USER</code>, and each document's
/// hash in <code>HSCUSTOM</code> then equals <code>USER</code>'s. A second proposal minted after the pair is saved again and then
/// followed by a re-save of <code>Changed</code> in <code>USER</code> is refused at its confirm 409
/// <code>PROPOSAL.TARGETCHANGED</code> and writes nothing.</p>
/// <p>Mutation (Rule 19): take <code>PlanHash</code> out of <parameter>OcuPilot.Screen.Tool.ExplorerNamespacePromote.FINGERPRINTSUBJECT</parameter>
/// -- the second leg writes and this goes red.</p>
Method TestTheAgentsPromoteIsConfirmedOverHTTPAndASourceChangeRefusesIt()
{
    Do ..EnableKey()
    Set tWriter = ..Principal(..#HERE _ "," _ ..#THERE, ..#THERE)
    Set tBefore = ..State(..#THERE)
    Set tState = ..RunTurn(tWriter, ..Call("toolu_one", ..#STEPS), .tView, .tResult, .tIsError)
    If tState '= "completed" Quit
    Do $$$AssertEquals(tIsError, 0, "the call is answered without error: " _ $Extract(tResult, 1, 300))
    Set tProposals = ..Proposals(tView)
    Do $$$AssertEquals(tProposals.%Size(), 1, "the turn holds one proposal: " _ tProposals.%ToJSON())
    If tProposals.%Size() '= 1 Quit
    Do $$$AssertEquals(..State(..#THERE), tBefore, "the mint wrote nothing")
    Set tKey = tProposals.%Get(0).%Get("proposalId")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ tKey _ "/confirm?ns=" _ ..#HERE, tWriter, ..PreparedPassword, .tStatus, .tText, .tHeaders, "", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tText), 1, 300))
    Try { Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tText) } Catch { Set tBody = "" }
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("output")) && (tBody.output.documents.%Size() = 3), "it answers the three documents' outcomes")
    For tDocument = "OcuProbe248.Changed.cls", "OcuProbe248.OnlyHere.cls", "OcuProbe248Mac.mac" {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": HSCUSTOM holds USER's text")
    }

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe pair is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "and saved again")
    Set tBefore = ..State(..#THERE)
    Set tState = ..RunTurn(tWriter, ..Call("toolu_two", ..#STEPS), .tView, .tResult, .tIsError)
    If tState '= "completed" Quit
    Set tProposals = ..Proposals(tView)
    Do $$$AssertEquals(tProposals.%Size(), 1, "the second turn holds one proposal: " _ $Extract(tResult, 1, 300))
    If tProposals.%Size() '= 1 Quit
    Do ..ResaveChanged(..#HERE, "ResavedHere")
    Set tKey = tProposals.%Get(0).%Get("proposalId")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ tKey _ "/confirm?ns=" _ ..#HERE, tWriter, ..PreparedPassword, .tStatus, .tText, .tHeaders, "", "application/json")
    Try { Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tText) } Catch { Set tBody = "" }
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "409|" _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a change in USER after the mint refuses the confirm: " _ $Extract($Get(tText), 1, 300))
    Do $$$AssertEquals(..State(..#THERE), tBefore, "and nothing was written")
}

}
