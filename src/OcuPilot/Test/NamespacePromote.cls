/// <p>Pins Story 24.9's promote between two namespaces of this instance, over the <code>OcuProbe248</code> documents
/// <class>OcuPilot.Test.DevToolProbe</class> saves in <code>USER</code> and <code>HSCUSTOM</code> (<code>USER</code> the
/// route's namespace, <code>HSCUSTOM</code> the other one): the plan and its hash, the person's reviewed action through
/// <class>OcuPilot.Api.ScreenAction</class>, and every refusal of the story's matrix, each leaving the other namespace's
/// documents as they were.</p>
/// <p>The port's own seams are driven through <class>OcuPilot.Test.DevToolPortFixture</class>; the route's pass is
/// <class>OcuPilot.Test.NamespaceActionFixture</class> over the shipped tool and port. The agent's pass is
/// <class>OcuPilot.Test.NamespacePromoteAgent</class>.</p>
/// <p>Needs the install namespace and the namespaces <code>USER</code> and <code>HSCUSTOM</code>, and auditing enabled for
/// <code>ConfigChange</code>; it saves and removes the probe documents in both around every test.</p>
Class OcuPilot.Test.NamespacePromote Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolAtelierRecorder";

Parameter ACTION = "OcuPilot.Test.NamespaceActionFixture";

Parameter DIFF = "OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff";

Parameter SCREEN = "explorer.namespacediff";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter CHANGED = "OcuProbe248.Changed.cls";

Parameter ONLYHERE = "OcuProbe248.OnlyHere.cls";

Parameter ONLYTHERE = "OcuProbe248.OnlyThere.cls";

Parameter SAME = "OcuProbe248.Same.cls";

Parameter MAC = "OcuProbe248Mac.mac";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#HERE)
    Do ..Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Forget the fixtures and remove the probe documents from both namespaces.</p>
Method Reset()
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe documents are removed from both namespaces")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveStoragePair", ..#HERE, ..#THERE), "the storage probe is removed from both namespaces")
}

/// <p>The three steps' names, as the checked rows name them.</p>
ClassMethod Steps() As %String
{
    Quit ..#CHANGED _ "," _ ..#ONLYHERE _ "," _ ..#MAC
}

/// <p>The port's <var>pType</var> over the fixture, from <var>pFrom</var> into <var>pTarget</var>, for the documents
/// <var>pDocuments</var>, <var>pSpec</var> and, when it is not <code>""</code>, <var>pReviewed</var>; the answer is in
/// <var>pResult</var> and the refusal in <var>pHttp</var> and <var>pFault</var>.</p>
Method Port(pType As %String, pFrom As %String, pTarget As %String, pDocuments As %String, pSpec As %String, pReviewed As %String = "", Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = pFrom
    Set tQuery("target") = pTarget
    Set tQuery("spec") = pSpec
    Set tQuery("documents") = pDocuments
    If pReviewed '= "" Set tQuery("reviewed") = pReviewed
    Quit $ClassMethod(..#FIXTURE, "Invoke", "NamespaceDiff", pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The plan hash of the three steps, from <code>USER</code> into <code>HSCUSTOM</code>.</p>
Method PlanHash() As %String
{
    Do $$$AssertStatusOK(..Port("PLAN", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, , .tPlan), "the plan is read")
    Quit $Select($IsObject($Get(tPlan)): tPlan.%Get("PlanHash"), 1: "")
}

/// <p>The hash of each probe document <var>pNamespace</var> holds, as <code>name=hash</code> entries, semicolon-joined, in
/// name order: the other namespace's state before and after a refusal.</p>
Method State(pNamespace As %String) As %String
{
    Kill tCriteria
    Set tCriteria("spec") = ..#SPEC
    Set tCriteria("namespace") = pNamespace
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "the hash read answers in " _ pNamespace)
    Set tState = ""
    If '$IsObject($Get(tRows)) Quit tState
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tState = tState _ tRow.%Get("Document") _ "=" _ tRow.%Get("Hash") _ ";"
    }
    Quit tState
}

/// <p>One document's hash in <var>pNamespace</var>, or <code>""</code>.</p>
Method HashOf(pNamespace As %String, pDocument As %String) As %String
{
    Set tState = ..State(pNamespace)
    Set tFrom = $Find(tState, pDocument _ "=")
    If 'tFrom Quit ""
    Quit $Piece($Extract(tState, tFrom, *), ";", 1)
}

/// <p>Save <code>OcuProbe248.Changed</code> in <var>pNamespace</var> again with a method named <var>pMethod</var>.</p>
Method ResaveChanged(pNamespace As %String, pMethod As %String)
{
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, "OcuProbe248.Changed", $ClassMethod(..#PROBE, "PairText", "Changed", pMethod)), "Changed is saved again in " _ pNamespace)
}

/// <p>The dry run of the promote of <var>pIds</var> from the route's namespace into <var>pTarget</var>: the preview
/// <code>{tool, targetRef, fresh, payload, diff, review}</code>.</p>
Method Review(pIds As %String, pTarget As %String, pSpec As %String, Output pPreview) As %Status
{
    Set tBody = {"action": "promote"}
    Do tBody.%Set("id", pIds, "string")
    Set tValues = {}
    Do tValues.%Set("target", pTarget, "string")
    Do tValues.%Set("spec", pSpec, "string")
    Do tValues.%Set("generated", "no", "string")
    Do tBody.%Set("values", tValues)
    Quit ##class(OcuPilot.Api.ScreenAction).DryRun(..#DIFF, tBody, .pPreview)
}

/// <p>The person's promote action of <var>pIds</var>, reviewed at <var>pReviewed</var> when that is not <code>""</code>,
/// through the route's own handler: the status and the parsed envelope.</p>
Method Act(pIds As %String, pTarget As %String, pSpec As %String, pReviewed As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set tBody = {"action": "promote"}
    Do tBody.%Set("id", pIds, "string")
    Set tValues = {}
    Do tValues.%Set("target", pTarget, "string")
    Do tValues.%Set("spec", pSpec, "string")
    Do tValues.%Set("generated", "no", "string")
    If pReviewed '= "" Do tValues.%Set("Reviewed", pReviewed, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tRaw, .pStatus)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>The code of the refusal <var>pAnswer</var> answers, or <code>""</code>.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The pure plan (<method>OcuPilot.Port.DevToolPort.Plan</method>) over two answers: a document only in the first
/// namespace and one that differs are steps, one only in the second is a warning, and the hash covers all three rows
/// without a time, moves with a hash, and is 64 hex digits.</p>
/// <p>Mutation (Rule 19): hash the steps without the warnings in <method>OcuPilot.Port.DevToolPort.Plan</method> -- the
/// warning leg goes red.</p>
Method TestThePlanIsPureAndItsHashCoversEveryRow()
{
    Set tHere = {"documents": [{"name": "A.cls", "hash": "h1", "timestamp": "t1"}, {"name": "B.cls", "hash": "h2", "timestamp": "t2"}, {"name": "C.cls", "hash": "same", "timestamp": "t3"}]}
    Set tThere = {"documents": [{"name": "B.cls", "hash": "h3", "timestamp": "t4"}, {"name": "C.cls", "hash": "same", "timestamp": "t5"}, {"name": "D.cls", "hash": "h4", "timestamp": "t6"}]}
    Set tPlan = ##class(OcuPilot.Port.DevToolPort).Plan(tHere, tThere)
    Do $$$AssertEquals(tPlan.steps.%Size() _ "|" _ tPlan.steps.%Get(0).Document _ "|" _ tPlan.steps.%Get(0).Change _ "|" _ tPlan.steps.%Get(1).Document _ "|" _ tPlan.steps.%Get(1).Change, "2|A.cls|Only in this namespace|B.cls|Content differs", "A and B are the steps, in Document order, and C is the same")
    Do $$$AssertEquals(tPlan.warnings.%Size() _ "|" _ tPlan.warnings.%Get(0).Document, "1|D.cls", "D is the one warning, and is never a step")
    Do $$$AssertTrue($Match(tPlan.planHash, "^[0-9a-f]{64}$"), "the hash is 64 hex digits")
    Set tTimes = {"documents": [{"name": "A.cls", "hash": "h1", "timestamp": "later"}, {"name": "B.cls", "hash": "h2", "timestamp": "later"}, {"name": "C.cls", "hash": "same", "timestamp": "later"}]}
    Do $$$AssertEquals(##class(OcuPilot.Port.DevToolPort).Plan(tTimes, tThere).planHash, tPlan.planHash, "a time moves nothing")
    Set tWarned = {"documents": [{"name": "B.cls", "hash": "h3", "timestamp": "t4"}, {"name": "C.cls", "hash": "same", "timestamp": "t5"}, {"name": "D.cls", "hash": "h9", "timestamp": "t6"}]}
    Do $$$AssertNotEquals(##class(OcuPilot.Port.DevToolPort).Plan(tHere, tWarned).planHash, tPlan.planHash, "a warning's hash moves the plan")
    Set tMoved = {"documents": [{"name": "A.cls", "hash": "h1", "timestamp": "t1"}, {"name": "B.cls", "hash": "h8", "timestamp": "t2"}, {"name": "C.cls", "hash": "same", "timestamp": "t3"}]}
    Do $$$AssertNotEquals(##class(OcuPilot.Port.DevToolPort).Plan(tMoved, tThere).planHash, tPlan.planHash, "a step's hash moves the plan")
}

/// <p>Matrix, Plan: the three chosen steps, one warning, a 64-hex hash equal across two reads, moved by a re-save of
/// <code>Changed</code> in the other namespace and not by a re-save of <code>Same</code> with its own text.</p>
Method TestThePlanListsTheStepsTheWarningAndAStableHash()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Do $$$AssertStatusOK(..Port("PLAN", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, , .tPlan), "the plan is read")
    If '$IsObject($Get(tPlan)) Quit
    Do $$$AssertEquals(tPlan.Steps.%ToJSON(), "[{""Document"":""OcuProbe248.Changed.cls"",""Change"":""Content differs""},{""Document"":""OcuProbe248.OnlyHere.cls"",""Change"":""Only in this namespace""},{""Document"":""OcuProbe248Mac.mac"",""Change"":""Only in this namespace""}]", "the three steps")
    Do $$$AssertEquals(tPlan.Warnings _ "|" _ tPlan.Namespace _ "|" _ tPlan.Target _ "|" _ tPlan.Generated _ "|" _ tPlan.Reviewed, "1|USER|HSCUSTOM|no|", "one warning, both namespaces and no review")
    Do $$$AssertTrue($Match(tPlan.PlanHash, "^[0-9a-f]{64}$"), "a 64-hex hash")
    Do $$$AssertEquals(..PlanHash(), tPlan.PlanHash, "it is equal across two reads")
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#THERE, "OcuProbe248.Same", $ClassMethod(..#PROBE, "PairText", "Same", "One")), "Same is saved again with its own text")
    Do $$$AssertEquals(..PlanHash(), tPlan.PlanHash, "and a document saved again with the same text moves nothing")
    Do ..ResaveChanged(..#THERE, "Later")
    Do $$$AssertNotEquals(..PlanHash(), tPlan.PlanHash, "a re-save of Changed with other text moves it")
}

/// <p>In <var>pNamespace</var>: whether <code>OcuProbe248.OnlyHere</code> is compiled, whether <code>OcuProbe248.Changed</code>
/// holds the method <code>Here</code> and whether it holds the method <code>There</code>, as <code>a|b|c</code>.</p>
Method CompiledIn(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tAnswer = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tAnswer = +##class(%Dictionary.CompiledClass).%ExistsId("OcuProbe248.OnlyHere") _ "|" _ +##class(%Dictionary.CompiledMethod).%ExistsId("OcuProbe248.Changed||Here") _ "|" _ +##class(%Dictionary.CompiledMethod).%ExistsId("OcuProbe248.Changed||There")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tAnswer
}

/// <p>Save the probe pair, as a status.</p>
Method Save() As %Status
{
    Quit $ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE)
}

/// <p>Matrix, Promote, and AC1: the dry run lists the steps and the one document left alone and answers the plan hash; the
/// action with that hash writes the three documents into the other namespace, each hash then equal to its source's, and
/// the classes compiled; <code>OnlyThere</code> and <code>Same</code> are untouched, a fresh diff lists only
/// <code>OnlyThere</code>, the outcomes read Replaced, Added, Added, and one <code>ConfigChange</code> row names the other
/// namespace.</p>
/// <p>Mutation (Rule 19): skip the <code>CREATE</code> steps in <method>OcuPilot.Port.DevToolPort.Promote</method> -- the
/// outcome, the hash and the fresh-diff legs go red.</p>
Method TestAReviewedPromoteWritesCompilesAndLeavesTheRest()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tOnlyThere = ..HashOf(..#THERE, ..#ONLYTHERE)
    Set tSame = ..HashOf(..#THERE, ..#SAME)
    Do $$$AssertStatusOK(..Review(..Steps(), ..#THERE, ..#SPEC, .tPreview), "the dry run answers")
    If '$IsObject($Get(tPreview)) Quit
    Do $$$AssertEquals(tPreview.diff.%Get(0).after, "OcuProbe248.Changed.cls -- Content differs" _ $Char(10) _ "OcuProbe248.OnlyHere.cls -- Only in this namespace" _ $Char(10) _ "OcuProbe248Mac.mac -- Only in this namespace" _ $Char(10) _ "1 document only in the other namespace stays as it is.", "the review lists the steps and the one document left alone")
    Do $$$AssertEquals(tPreview.review.Digest, ..PlanHash(), "its digest is the plan hash")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK(..Act(..Steps(), ..#THERE, ..#SPEC, tPreview.review.Digest, .tStatus, .tAnswer), "the action runs")
    Do $$$AssertEquals(tStatus, 200, "it answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.output.errors _ "|" _ tAnswer.output.stopped, "updated|0|0", "updated, the compile reported no error and nothing stopped")
    Set tOutcomes = ""
    Set tIterator = tAnswer.output.documents.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tDocument) {
        Set tOutcomes = tOutcomes _ $Select(tOutcomes = "": "", 1: ",") _ tDocument.%Get("Outcome")
    }
    Do $$$AssertEquals(tOutcomes, "Replaced,Added,Added", "the outcomes read Replaced, Added, Added")
    For tDocument = ..#CHANGED, ..#ONLYHERE, ..#MAC {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": the other namespace holds the source's text")
    }
    Do $$$AssertEquals(..HashOf(..#THERE, ..#ONLYTHERE) _ "|" _ ..HashOf(..#THERE, ..#SAME), tOnlyThere _ "|" _ tSame, "OnlyThere and Same are untouched")
    Do $$$AssertEquals(..CompiledIn(..#THERE), "1|1|0", "the promoted classes are compiled in the other namespace")
    Kill tCriteria
    Set tCriteria("namespace") = ..#HERE
    Set tCriteria("target") = ..#THERE
    Set tCriteria("spec") = ..#SPEC
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "NamespaceDiff", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "a fresh diff is read")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Get(0).Document _ "|" _ tRows.%Size(), 1: ""), "OcuProbe248.OnlyThere.cls|1", "and lists only OnlyThere")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""namespace"",""scope"":""instance"",""id"":""HSCUSTOM""", .tData, """verb"":""promote"""), 1, "one ConfigChange row names the promote into the other namespace")
}

/// <p>Matrix, Allow-list subset: only the document named is written, and <code>OnlyHere</code> stays absent in the other
/// namespace.</p>
Method TestOnlyTheNamedDocumentsAreWritten()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tHash = ..PlanHash()
    Do $$$AssertStatusOK(..Port("PLAN", ..#HERE, ..#THERE, ..#CHANGED, ..#SPEC, , .tOne), "the plan for Changed alone is read")
    Do $$$AssertStatusOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..#CHANGED, ..#SPEC, tOne.PlanHash, .tResult, .tHttp, .tFault), "the promote of Changed alone is written")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.documents.%Size() _ "|" _ tResult.documents.%Get(0).Outcome, "1|Replaced", "one document, replaced")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#CHANGED), ..HashOf(..#HERE, ..#CHANGED), "Changed now holds the source's text")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#ONLYHERE) _ "|" _ ..HashOf(..#THERE, ..#MAC), "|", "OnlyHere and the routine stay absent")
    Do $$$AssertEquals(tOne.PlanHash, tHash, "the plan hash covers the whole plan, not the chosen documents")
}

/// <p>Matrix, Not a step, and AC2: a name the plan does not list as a step -- one both namespaces hold alike, one only the
/// other namespace holds, or one nothing holds -- refuses the whole request, even beside a real step, 400
/// <code>EXPLORER.PROMOTE.NOTASTEP</code> naming it, at the route and at the port, and nothing is written.</p>
/// <p>Mutation (Rule 19): skip the step lookup in <method>OcuPilot.Port.DevToolPort.Compose</method> -- every leg goes
/// red.</p>
Method TestANameThatIsNotAStepRefusesTheWholeRequest()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tBefore = ..State(..#THERE)
    Set tHash = ..PlanHash()
    For tName = ..#SAME, ..#ONLYTHERE, "OcuProbe248.Nothing.cls" {
        Do $$$AssertStatusNotOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..#CHANGED _ "," _ tName, ..#SPEC, tHash, , .tHttp, .tFault), tName _ ": the port refuses")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.detail.document, 1: ""), "400|EXPLORER.PROMOTE.NOTASTEP|" _ tName, tName _ ": 400 naming the document")
        Do $$$AssertEquals(tFault.%Get("reason"), ##class(OcuPilot.Port.DevToolPort).#REASONNOTASTEP, tName _ ": the written reason")
        Do $$$AssertStatusOK(..Act(..#CHANGED _ "," _ tName, ..#THERE, ..#SPEC, tHash, .tStatus, .tAnswer), tName _ ": the route's action runs")
        Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "400|EXPLORER.PROMOTE.NOTASTEP", tName _ ": the route refuses it")
    }
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p>Matrix, Stale, and AC2: a plan hash taken before <code>Changed</code> is saved again in the other namespace refuses the
/// action, 409 <code>EXPLORER.PROMOTE.STALE</code>; the other namespace keeps the text it was re-saved with, and a promote
/// with no reviewed hash is refused the same way.</p>
/// <p>Mutation (Rule 19): make the reviewed-hash comparison inert in <method>OcuPilot.Port.DevToolPort.Promote</method> --
/// both legs go red.</p>
Method TestAStaleReviewWritesNothing()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Do $$$AssertStatusOK(..Review(..Steps(), ..#THERE, ..#SPEC, .tPreview), "the dry run answers")
    If '$IsObject($Get(tPreview)) Quit
    Do ..ResaveChanged(..#THERE, "Resaved")
    Set tBefore = ..State(..#THERE)
    Do $$$AssertStatusOK(..Act(..Steps(), ..#THERE, ..#SPEC, tPreview.review.Digest, .tStatus, .tAnswer), "the action runs")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "409|EXPLORER.PROMOTE.STALE", "it is refused as stale")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Port.DevToolPort).#REASONSTALE, "with the written reason")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "the other namespace keeps what it was re-saved with")
    Do $$$AssertStatusNotOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, "", , .tHttp, .tFault), "a call with no reviewed hash is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "409|EXPLORER.PROMOTE.STALE", "as stale too")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "and writes nothing")
}

/// <p>Matrix, Own code, and AC2: a plan from <code>HSCUSTOM</code> into <code>USER</code> that holds a document of
/// OcuPilot's own is refused <code>PROHIBITED.OCUPILOTCODE</code> by the kernel at the person's action, and
/// <code>USER</code> gains nothing. The dry run shows the step.</p>
Method TestADocumentOfOcuPilotsOwnIsRefusedAtTheAction()
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#THERE)
    Set tOwn = "OcuPilot.Port.DevToolPort.cls"
    Do $$$AssertStatusOK(..Review(tOwn, ..#HERE, tOwn, .tPreview), "the dry run shows the step")
    If '$IsObject($Get(tPreview)) Quit
    Do $$$AssertEquals(tPreview.diff.%Get(0).after, tOwn _ " -- Only in this namespace", "the review lists it")
    Do $$$AssertStatusOK(..Act(tOwn, ..#HERE, tOwn, tPreview.review.Digest, .tStatus, .tAnswer), "the action runs")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "403|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, "the kernel refuses it")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE), "with the kernel's own reason")
    Kill tCriteria
    Set tCriteria("spec") = tOwn
    Set tCriteria("namespace") = ..#HERE
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "the hash read answers in USER")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 0, "USER holds no such document")
}

/// <p>Matrix, System, and AC2: <code>%SYS</code> as the other namespace or as the first, and a name beginning with
/// <code>%</code>, are 400 <code>EXPLORER.PROMOTE.SYSTEM</code> with the written reason, for the plan and the promote, and
/// nothing is written.</p>
Method TestTheSystemNamespaceAndAPercentNameAreRefused()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tBefore = ..State(..#THERE)
    For tCase = $ListBuild("PLAN", ..#HERE, "%SYS", ..#CHANGED), $ListBuild("PROMOTE", ..#HERE, "%SYS", ..#CHANGED), $ListBuild("PROMOTE", "%SYS", ..#HERE, ..#CHANGED), $ListBuild("PROMOTE", ..#HERE, ..#THERE, ..#CHANGED _ ",%Library.Foo.cls") {
        Do $$$AssertStatusNotOK(..Port($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), ..#SPEC, "x", , .tHttp, .tFault), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ">" _ $List(tCase, 3) _ ": refused")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "400|EXPLORER.PROMOTE.SYSTEM|" _ ##class(OcuPilot.Port.DevToolPort).#REASONSYSTEM, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ">" _ $List(tCase, 3) _ ": 400 with the written reason")
    }
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p>Matrix, Write gate, and AC2: a caller who holds every read pair and <code>%Development:USE</code> but not WRITE on the
/// other namespace's routines database is 403 <code>AUTH.NOPRIVILEGE</code> naming that pair, and nothing is written.</p>
/// <p>Mutation (Rule 19): skip evaluating <code>WritePairs</code> in <method>OcuPilot.Port.DevToolPort.Promote</method> --
/// the promote is written and this goes red.</p>
Method TestACallerWithoutWriteOnTheOtherNamespaceIsRefused()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tHash = ..PlanHash()
    Set tBefore = ..State(..#THERE)
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).Pairs() _ ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#HERE) _ ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#THERE)
    For tI = 1:1:$ListLength(tPairs) {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tPairs, tI), 1), $List($List(tPairs, tI), 2))
    }
    Do $$$AssertStatusNotOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, tHash, , .tHttp, .tFault), "the promote is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.detail.failedPair, "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|%DB_HSCUSTOM:WRITE", "403 naming WRITE on the other namespace's routines database")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p>Matrix, Storage, and AC2: a class that is saved without a storage definition in the first namespace and compiled, so
/// with its storage definition, in the other one is 409 <code>EXPLORER.PROMOTE.STORAGE</code> naming it, and nothing is
/// written, a document beside it included.</p>
/// <p>Mutation (Rule 19): drop the storage guard's comparison in <method>OcuPilot.Port.DevToolPort.Preflight</method> -- the
/// class is replaced and this goes red.</p>
Method TestAClassThatWouldLoseItsStorageIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeStoragePair", ..#HERE, ..#THERE), "the storage probe is saved")
    Set tBeside = $Parameter(..#PROBE, "STORAGEPACKAGE") _ ".Before"
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#HERE, tBeside, "Class " _ tBeside _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)), "a class beside it is saved in the first namespace only")
    Set tSpec = "OcuProbe249.*.cls"
    Set tName = $Parameter(..#PROBE, "STORAGECLASS") _ ".cls"
    Set tNames = tBeside _ ".cls," _ tName
    Do $$$AssertStatusOK(..Port("PLAN", ..#HERE, ..#THERE, tNames, tSpec, , .tPlan), "the plan is read")
    If '$IsObject($Get(tPlan)) Quit
    Do $$$AssertEquals(tPlan.Steps.%Get(0).Change _ "|" _ tPlan.Steps.%Get(1).Change, "Only in this namespace|Content differs", "the class beside it is a create, sorted first, and the class differs")
    Kill tCriteria
    Set tCriteria("spec") = tSpec
    Set tCriteria("namespace") = ..#THERE
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tBefore, .tHttp, .tFault), "the other namespace's hash is read")
    Do $$$AssertStatusNotOK(..Port("PROMOTE", ..#HERE, ..#THERE, tNames, tSpec, tPlan.PlanHash, , .tHttp, .tFault), "the promote is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.detail.document, "409|EXPLORER.PROMOTE.STORAGE|" _ tName, "409 naming the class")
    Do $$$AssertEquals(tFault.%Get("reason"), ##class(OcuPilot.Port.DevToolPort).#REASONSTORAGE, "with the written reason")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tAfter, .tHttp, .tFault), "the other namespace's hash is read again")
    Do $$$AssertEquals(tAfter.%ToJSON(), tBefore.%ToJSON(), "the class is unchanged and the class beside it was not written")
}

/// <p>Matrix, Stop, and AC3: with the second save failing, the first document is Replaced, the second Failed with the
/// port's reason, the third Not attempted; no compile ran; <code>stopped</code> is true; the answer is 200 and the first
/// write stays written.</p>
/// <p>Mutation (Rule 19): remove the stop in <method>OcuPilot.Port.DevToolPort.Promote</method> so the loop goes on after a
/// failure -- the third document is written and this goes red.</p>
Method TestAFailedSaveStopsThePromoteAndUndoesNothing()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tHash = ..PlanHash()
    Do $ClassMethod(..#FIXTURE, "SetAtelierClass", ..#RECORDER)
    Do $ClassMethod(..#RECORDER, "FailSave", ..#ONLYHERE)
    Do $$$AssertStatusOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, tHash, .tResult, .tHttp, .tFault), "the promote answers")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tHttp, 200, "200")
    Set tOutcomes = ""
    Set tIterator = tResult.documents.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tDocument) {
        Set tOutcomes = tOutcomes _ $Select(tOutcomes = "": "", 1: ",") _ tDocument.%Get("Document") _ ":" _ tDocument.%Get("Outcome") _ ":" _ tDocument.%Get("Reason")
    }
    Do $$$AssertEquals(tOutcomes, "OcuProbe248.Changed.cls:Replaced:,OcuProbe248.OnlyHere.cls:Failed:" _ $Parameter(..#RECORDER, "REFUSED") _ ",OcuProbe248Mac.mac:Not attempted:", "Replaced, Failed with its reason, Not attempted")
    Do $$$AssertEquals(tResult.stopped _ "|" _ tResult.errors _ "|" _ tResult.lines.%Size(), "1|0|0", "stopped, with no compile line")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Writes"), "SAVE:HSCUSTOM:OcuProbe248.Changed.cls,CREATE:HSCUSTOM:OcuProbe248.OnlyHere.cls", "no write after the failed one and no compile ran")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#CHANGED), ..HashOf(..#HERE, ..#CHANGED), "the first document stays written")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#ONLYHERE) _ "|" _ ..HashOf(..#THERE, ..#MAC), "|", "the others are absent")
}

/// <p>Matrix, Too many: 101 names, and none, are 400 <code>PORT.VALIDATION</code> with the written reason and nothing is
/// written; 100 names are not refused for their count.</p>
Method TestTheCountOfDocumentsIsBounded()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tBefore = ..State(..#THERE)
    Set tNames = ""
    For tI = 1:1:101 {
        Set tNames = tNames _ $Select(tI = 1: "", 1: ",") _ "OcuProbe248.N" _ tI _ ".cls"
    }
    For tCase = $ListBuild(tNames, "101 names"), $ListBuild("", "no name"), $ListBuild(",,", "only separators") {
        Do $$$AssertStatusNotOK(..Port("PROMOTE", ..#HERE, ..#THERE, $List(tCase, 1), ..#SPEC, "x", , .tHttp, .tFault), $List(tCase, 2) _ ": refused")
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.%Get("reason"), "400|" _ ##class(OcuPilot.Api.Error).#PORTVALIDATION _ "|" _ ##class(OcuPilot.Port.DevToolPort).#REASONDOCUMENTS, $List(tCase, 2) _ ": 400 with the written reason")
    }
    Set tHundred = $Piece(tNames, ",", 1, 100)
    Do $$$AssertStatusNotOK(..Port("PLAN", ..#HERE, ..#THERE, tHundred, ..#SPEC, , , .tHttp, .tFault), "100 names that are no steps are refused")
    Do $$$AssertEquals(tFault.%Get("code"), ##class(OcuPilot.Port.DevToolPort).#CODENOTASTEP, "for what they are, not for their count")
    Do $$$AssertEquals(..State(..#THERE), tBefore, "nothing was written")
}

/// <p>A passing promote writes every step, then sends one compile for the classes and one for the routines, each with the
/// flag set the import and the save send, <code>cuk</code>, and the routine is compiled in the other namespace.</p>
/// <p>Mutation (Rule 19): leave the routines' compile out of <method>OcuPilot.Port.DevToolPort.Promote</method>, or send
/// the dependents flag -- the recorded writes differ and this goes red.</p>
Method TestAPromoteCompilesEachKindWithTheImportsFlags()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Set tHash = ..PlanHash()
    Do $ClassMethod(..#FIXTURE, "SetAtelierClass", ..#RECORDER)
    Do $$$AssertStatusOK(..Port("PROMOTE", ..#HERE, ..#THERE, ..Steps(), ..#SPEC, tHash, .tResult, .tHttp, .tFault), "the promote answers")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Writes"), "SAVE:HSCUSTOM:OcuProbe248.Changed.cls,CREATE:HSCUSTOM:OcuProbe248.OnlyHere.cls,CREATE:HSCUSTOM:OcuProbe248Mac.mac,COMPILE:HSCUSTOM:OcuProbe248.Changed.cls+OcuProbe248.OnlyHere.cls:cuk,COMPILE:HSCUSTOM:OcuProbe248Mac.mac:cuk", "every step is written, then the classes and the routines are compiled once each with cuk")
}

/// <p>AD-59: the script of a promote is one step of one line to a document and one compile line to a kind, each closing every
/// block it opens, copying the documents the plan chose into the other namespace when it is run, with the compile flags
/// <code>cuk</code>; a read, and a plan, have no script form.</p>
/// <p>Mutation (Rule 19): drop the <code>Save</code> from the routine's line in <method>OcuPilot.Port.DevToolPort.Snippet</method>
/// -- the routine is not written and the hash leg goes red.</p>
Method TestTheScriptCopiesTheChosenDocumentsWhenRun()
{
    Do $$$AssertStatusOK(..Save(), "the probe pair is saved")
    Do $$$AssertEquals(##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "PROMOTE") _ "|" _ ##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "PLAN") _ "|" _ ##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "LIST"), "objectscript||", "only the promote has a script form")
    Kill tQuery
    Set tQuery("namespace") = ..#HERE
    Set tQuery("target") = ..#THERE
    Set tQuery("documents") = ..Steps()
    Set tSteps = ##class(OcuPilot.Port.DevToolPort).Snippet("NamespaceDiff", "PROMOTE", .tQuery)
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", "one ObjectScript step")
    Set tText = tSteps.%Get(0).text
    Set tLines = $Length(tText, $Char(10))
    Do $$$AssertEquals(tLines, 6, "one line for each document, the line that enters the other namespace and one compile line for each kind")
    For tI = 1:1:tLines {
        Set tLine = $Piece(tText, $Char(10), tI)
        Do $$$AssertEquals($Length(tLine, "{"), $Length(tLine, "}"), "line " _ tI _ " closes every block it opens")
    }
    Do $$$AssertTrue((tText [ "CompileList(""OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls"", ""cuk"")") && (tText [ "CompileList(""OcuProbe248Mac.mac"", ""cuk"")"), "the classes and the routines are compiled with cuk, each in one call")
    Set tOrigNS = $NAMESPACE
    Try {
        For tI = 1:1:tLines {
            Xecute $Piece(tText, $Char(10), tI)
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the script runs")
    }
    Set $NAMESPACE = tOrigNS
    For tDocument = ..#CHANGED, ..#ONLYHERE, ..#MAC {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": the script copied it")
    }
}

}
