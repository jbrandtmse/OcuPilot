/// <p>Pins Story 24.8's System Explorer screen Compare namespaces, read through
/// <class>OcuPilot.Port.DevToolPort</class>'s <code>NamespaceDiff</code> endpoint: every row of the story's matrix
/// over the <code>OcuProbe248</code> documents <class>OcuPilot.Test.DevToolProbe</class> saves in <code>USER</code>
/// and <code>HSCUSTOM</code>, each refusal leaving <class>OcuPilot.Test.DevToolHarvestRecorder</class> with no
/// recorded call, the two body calls a diff makes, and the read tool answering the rows the screen's read answered.</p>
/// <p>The screen's read is <method>OcuPilot.Screen.Read.Execute</method> over
/// <class>OcuPilot.Test.DevToolReadFixture</class>, which reaches the port through
/// <class>OcuPilot.Test.DevToolPortFixture</class>. The route's own pass is in <file>ui/browser/namespace-diff.browser-spec.mjs</file>.</p>
/// <p>Needs the install namespace and the namespaces <code>USER</code> and <code>HSCUSTOM</code>; it saves and removes the
/// probe documents in both around every test, and its tool leg seeds one completed turn as the running principal and
/// removes it.</p>
Class OcuPilot.Test.NamespaceDiffRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolHarvestRecorder";

Parameter READ = "OcuPilot.Test.DevToolReadFixture";

Parameter DIFF = "OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Property Http As %Integer;

Property Fault As %DynamicObject;

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

/// <p>Forget the fixtures and remove the probe documents from both namespaces, so each test starts with none.</p>
Method Reset()
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe documents are removed from both namespaces")
}

/// <p>Save the probe documents.</p>
Method MakeProbe()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe documents are saved")
}

/// <p>Read the screen over the fixtures with <var>pTarget</var>, <var>pSpec</var>, <code>generated</code>
/// <var>pGenerated</var> (omitted when <code>""</code>) and cap <var>pMaxRows</var>; the refusal is kept in
/// <property>Http</property> and <property>Fault</property>.</p>
Method Run(pTarget As %String, pSpec As %String, pGenerated As %String = "", pMaxRows As %String = "", Output pResult) As %Status
{
    Kill tCriteria
    Set tCriteria("target") = pTarget
    Set tCriteria("spec") = pSpec
    If pGenerated '= "" Set tCriteria("generated") = pGenerated
    Set tSC = $ClassMethod(..#READ, "Execute", ..#DIFF, pMaxRows, .pResult, .tHttp, .tFault, .tCriteria)
    Set i%Http = tHttp
    Set i%Fault = tFault
    Quit tSC
}

/// <p>The rows' <code>pField</code> values, comma-separated, in row order.</p>
ClassMethod Column(pRows As %DynamicArray, pField As %String) As %String
{
    Set tList = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tList = tList _ $Select(tList = "": "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tList
}

/// <p>Assert the last answer was refused <var>pHttp</var> with <var>pCode</var>, no body was asked for and nothing was
/// logged.</p>
Method AssertRefused(pHttp As %Integer, pCode As %String, pLabel As %String)
{
    Do $$$AssertEquals(+i%Http, pHttp, pLabel _ ": HTTP status")
    Do $$$AssertEquals($Select($IsObject(i%Fault): i%Fault.%Get("code"), 1: ""), pCode, pLabel _ ": fault code")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 0, pLabel _ ": no body was asked for")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "LogCount"), 0, pLabel _ ": nothing is logged")
}

/// <p>The <code>name</code>-keyed hashes and times the hash read answers for <var>pSpec</var> in <var>pNamespace</var>, as
/// <code>pHash(name)</code> and <code>pModified(name)</code>.</p>
Method HashesIn(pNamespace As %String, pSpec As %String, Output pHash, Output pModified)
{
    Kill pHash, pModified
    Kill tCriteria
    Set tCriteria("spec") = pSpec
    Set tCriteria("namespace") = pNamespace
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "the hash read answers in " _ pNamespace)
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pHash(tRow.%Get("Document")) = tRow.%Get("Hash")
        Set pModified(tRow.%Get("Document")) = tRow.%Get("Modified")
    }
}

/// <p>The screen is declared as the story says: a validating, listed System Explorer list at position 16 gated on
/// <code>%Development:USE</code> alone, read through the devtool port's <code>NamespaceDiff</code>, with the other
/// namespace, the pattern and the generated choice as its criteria, three prompts and no classic page.</p>
Method TestTheScreenIsDeclaredAsTheStorySays()
{
    Set tSC = $ClassMethod(..#DIFF, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "the declaration, its read and its criteria validate")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.area _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind, "system-explorer/namespace-diff|16|system-explorer|namespace|none", "route, position, area, scope and id")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Development"",""permission"":""USE""}]", "gated on %Development:USE alone")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint, "devtool|NamespaceDiff", "read through the devtool port's NamespaceDiff")
    Do $$$AssertEquals($ClassMethod(..#DIFF, "ClassicPage"), "", "no classic page")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).CriteriaParams(..#DIFF), $ListBuild("target", "spec", "generated"), "the other namespace, the pattern and the generated choice")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("explorer.namespacediff"), ..#DIFF, "its tool identifier resolves to it")
}

/// <p>Matrix, Diff: four rows in <code>Document</code> order, each change as the story reads it, the unchanged
/// document absent, every hash and time the one the hash read answers in its own namespace, and the answer not
/// truncated. The port asked for exactly two bodies, one for each namespace with that namespace's pairs and only the
/// keys it builds.</p>
/// <p>Mutation: make <method>OcuPilot.Port.DevToolPort.DiffRows</method> drop the rows only in the other namespace -&gt;
/// the row list, and the tool leg, go red; compare the time with the hash -&gt; the row list gains <code>Same</code>.</p>
Method TestTheDiffListsEachDifferenceAndNotTheSameDocument()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#THERE, ..#SPEC, , , .tResult)
    Do $$$AssertStatusOK(tSC, "the read answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Column(tResult.rows, "Document"), "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248.OnlyThere.cls,OcuProbe248Mac.mac", "four rows in Document order, and Same is not one")
    Do $$$AssertEquals(..Column(tResult.rows, "Change"), "Content differs,Only in this namespace,Only in the other namespace,Only in this namespace", "each change reads as the story says")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    Set tChanged = tResult.rows.%Get(0)
    Do $$$AssertTrue((tChanged.%Get("Hash") '= "") && (tChanged.%Get("OtherHash") '= "") && (tChanged.%Get("Hash") '= tChanged.%Get("OtherHash")), "Changed carries two non-empty, unequal hashes")
    For tI = 1, 3 {
        Set tRow = tResult.rows.%Get(tI)
        Do $$$AssertEquals(tRow.%Get("OtherHash") _ "|" _ tRow.%Get("OtherModified"), "|", tRow.%Get("Document") _ ": nothing of the other namespace")
        Do $$$AssertTrue((tRow.%Get("Hash") '= "") && (tRow.%Get("Modified") '= ""), tRow.%Get("Document") _ ": this namespace's hash and time")
    }
    Set tThere = tResult.rows.%Get(2)
    Do $$$AssertEquals(tThere.%Get("Hash") _ "|" _ tThere.%Get("Modified"), "|", "OnlyThere: nothing of this namespace")
    Do $$$AssertTrue((tThere.%Get("OtherHash") '= "") && (tThere.%Get("OtherModified") '= ""), "OnlyThere: the other namespace's hash and time")

    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 2, "one body for each namespace")
    Set tCommon = ##class(OcuPilot.Port.AtelierPort).Pairs()
    For tSide = 1, 2 {
        Set tNamespace = $Select(tSide = 1: ..#HERE, 1: ..#THERE)
        Set tCall = $ClassMethod(..#RECORDER, "CallAt", tSide)
        Set tPairs = tCommon _ ##class(OcuPilot.Port.AtelierPort).NamespacePairs(tNamespace)
        Set tExpected = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tExpected = tExpected _ $Select(tI = 1: "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        }
        Do $$$AssertEquals(tCall.handler _ "." _ tCall.method, "OcuPilot.Port.Harvest.EnvSync.DocHashes", tNamespace _ ": the hash body")
        Do $$$AssertEquals(tCall.pairs, tExpected, tNamespace _ ": Pairs and that namespace's own pairs")
        Do $$$AssertEquals(tCall.query.%ToJSON(), "{""includeGenerated"":""0"",""namespace"":""" _ tNamespace _ """,""spec"":""" _ ..#SPEC _ """}", tNamespace _ ": spec, namespace and includeGenerated only")
    }
    Do $$$AssertNotEquals($ClassMethod(..#RECORDER, "CallAt", 1).pairs, $ClassMethod(..#RECORDER, "CallAt", 2).pairs, "the two calls carry different pair sets")

    Do ..HashesIn(..#HERE, ..#SPEC, .tHereHash, .tHereModified)
    Do ..HashesIn(..#THERE, ..#SPEC, .tThereHash, .tThereModified)
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tName = tRow.%Get("Document")
        Do $$$AssertEquals(tRow.%Get("Hash"), $Get(tHereHash(tName)), tName _ ": Hash is the hash read's in " _ ..#HERE)
        Do $$$AssertEquals(tRow.%Get("Modified"), $Get(tHereModified(tName)), tName _ ": Modified is the hash read's in " _ ..#HERE)
        Do $$$AssertEquals(tRow.%Get("OtherHash"), $Get(tThereHash(tName)), tName _ ": OtherHash is the hash read's in " _ ..#THERE)
        Do $$$AssertEquals(tRow.%Get("OtherModified"), $Get(tThereModified(tName)), tName _ ": OtherModified is the hash read's in " _ ..#THERE)
    }
    Do $$$AssertTrue($Get(tHereHash("OcuProbe248.Same.cls")) '= "", "Same is held in " _ ..#HERE)
    Do $$$AssertEquals($Get(tThereHash("OcuProbe248.Same.cls")), $Get(tHereHash("OcuProbe248.Same.cls")), "Same holds one hash in both namespaces, so it is no row")
    Do $$$AssertNotEquals($Get(tThereModified("OcuProbe248.Same.cls")), $Get(tHereModified("OcuProbe248.Same.cls")), "Same was saved at different times, and a time alone is no difference")
}

/// <p>Matrix, Identical: a pattern that names only the document both namespaces hold alike answers no rows, not
/// truncated.</p>
Method TestAnIdenticalDocumentAnswersNoRows()
{
    Do ..MakeProbe()
    Do ..HashesIn(..#HERE, "OcuProbe248.Same.cls", .tHereHash)
    Do ..HashesIn(..#THERE, "OcuProbe248.Same.cls", .tThereHash)
    Do $$$AssertTrue(($Get(tHereHash("OcuProbe248.Same.cls")) '= "") && ($Get(tThereHash("OcuProbe248.Same.cls")) '= ""), "the document is held in both namespaces")
    Set tSC = ..Run(..#THERE, "OcuProbe248.Same.cls", , , .tResult)
    Do $$$AssertStatusOK(tSC, "the read answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 0, "no rows")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
}

/// <p>Matrix, Generated: the port sent each of the two bodies <code>includeGenerated</code> 1 for <code>yes</code> and 0
/// for <code>no</code>.</p>
/// <p>Mutation: send <code>includeGenerated</code> 1 always in <method>OcuPilot.Port.DevToolPort.RunBody</method> -&gt; the
/// <code>no</code> legs go red.</p>
Method TestTheGeneratedChoiceReachesBothBodies()
{
    Do ..MakeProbe()
    Do $$$AssertStatusOK(..Run(..#THERE, ..#SPEC, "yes", , .tYes), "the read with generated yes answers")
    Do $$$AssertStatusOK(..Run(..#THERE, ..#SPEC, "no", , .tNo), "the read with generated no answers")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 4, "two bodies for each read")
    For tI = 1:1:4 {
        Do $$$AssertEquals($ClassMethod(..#RECORDER, "CallAt", tI).query.includeGenerated, $Select(tI < 3: "1", 1: "0"), "call " _ tI _ ": includeGenerated")
    }
}

/// <p>Matrix, Cut: a cap of two answers the first two rows and <code>truncated</code>.</p>
Method TestACapBelowTheRowCountTruncates()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#THERE, ..#SPEC, , 2, .tResult)
    Do $$$AssertStatusOK(tSC, "the read answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Column(tResult.rows, "Document"), "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls", "the first two rows in Document order")
    Do $$$AssertEquals(tResult.truncated, 1, "truncated")
    Do $$$AssertStatusOK(..Run(..#THERE, ..#SPEC, , 4, .tExact), "a cap equal to the row count answers")
    Do $$$AssertEquals(tExact.rows.%Size(), 4, "all four rows")
    Do $$$AssertEquals(tExact.truncated, 0, "a cap equal to the row count is not truncated")
}

/// <p>Matrix, Same namespace: <code>user</code> or <code>USER</code> as the other namespace, in the namespace the route
/// is scoped to, is 400 <code>PORT.VALIDATION</code> with the written reason, before any body runs.</p>
/// <p>Mutation: move the same-namespace check after the <code>RunBody</code> calls in
/// <method>OcuPilot.Port.DevToolPort.Invoke</method> -&gt; the no-call assertion goes red.</p>
Method TestTheSameNamespaceIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    For tTarget = "user", "USER" {
        Do $$$AssertStatusNotOK(..Run(tTarget, ..#SPEC), tTarget _ ": the read is refused")
        Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "target " _ tTarget)
        Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Port.DevToolPort).#REASONTARGETSAME, tTarget _ ": the written reason")
    }
}

/// <p>Matrix, Bad target: an empty target, or one with a space or a slash, is 400 <code>PORT.VALIDATION</code> with the
/// written reason, before any body runs.</p>
Method TestABadTargetIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    For tTarget = "", "A B", "A/B", "A.B", "..", "A" _ $Char(7) {
        Do $$$AssertStatusNotOK(..Run(tTarget, ..#SPEC), "target " _ $ZConvert(tTarget, "O", "JSON") _ ": the read is refused")
        Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "target " _ $ZConvert(tTarget, "O", "JSON"))
        Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Port.DevToolPort).#REASONTARGETSHAPE, "target " _ $ZConvert(tTarget, "O", "JSON") _ ": the written reason")
    }
}

/// <p>Matrix, Unknown target: a namespace the instance does not hold is 400 <code>PORT.VALIDATION</code> with the
/// namespace-unknown reason, before any body runs.</p>
Method TestAnUnknownTargetIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $$$AssertStatusNotOK(..Run("NOSUCHNS248", ..#SPEC), "the read is refused")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "an unknown target")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, "with the namespace-unknown reason")
}

/// <p>Matrix, Target gate, and AC3: a caller who holds <code>%Development:USE</code> and READ on this namespace's code
/// databases but not READ on the other namespace's is 403 <code>AUTH.NOPRIVILEGE</code> naming the other namespace's
/// pair, before any body runs.</p>
/// <p>Mutation: skip evaluating <code>NamespacePairs(tTarget)</code> in <method>OcuPilot.Port.DevToolPort.Invoke</method>
/// -&gt; this goes red.</p>
Method TestACallerWhoMayNotReadTheOtherNamespaceIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tHere = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#HERE)
    For tI = 1:1:$ListLength(tHere) {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tHere, tI), 1), $List($List(tHere, tI), 2))
    }
    Do $$$AssertStatusNotOK(..Run(..#THERE, ..#SPEC), "the read is refused")
    Do ..AssertRefused(403, ##class(OcuPilot.Kernel.Denial).Code(), "this namespace's pairs held, the other's not")
    Do $$$AssertEquals(i%Fault.detail.failedPair, "%DB_HSCUSTOM:READ", "naming READ on the other namespace's code database")
}

/// <p>Matrix, Wide or bad spec: a bare <code>*</code> is 400 <code>EXPLORER.SPEC.WIDE</code> and a spec of the wrong
/// shape 400 <code>PORT.VALIDATION</code>, before any body runs.</p>
Method TestAWideOrBadSpecIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 100000000)
    Do $ClassMethod(..#RECORDER, "SetDry")
    Do $$$AssertStatusNotOK(..Run(..#THERE, "*"), "a wide spec is refused")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.AtelierError).#SPECWIDE, "a wide spec")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Api.AtelierError).#REASONSPECWIDE, "with the written reason")
    Do $$$AssertStatusNotOK(..Run(..#THERE, "OcuProbe248..x"), "a spec of the wrong shape is refused")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "a bad spec")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Port.DevToolPort).#REASONSPECSHAPE, "with the shape reason")
}

/// <p>Matrix, Too many: with a cap of three and <code>USER</code> matching four documents, the read is 400
/// <code>EXPLORER.SPEC.TOOMANY</code> with <code>detail</code> <code>{count: 4, max: 3, namespace: "USER"}</code>; scoped to
/// <code>HSCUSTOM</code> (three) with <code>USER</code> as the other namespace, the other namespace is the one named. No
/// body runs.</p>
Method TestTooManyDocumentsInEitherNamespaceAreRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 3)
    Do $$$AssertStatusNotOK(..Run(..#THERE, ..#SPEC), "the first namespace over the cap is refused")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.AtelierError).#SPECTOOMANY, "the first namespace")
    Do $$$AssertEquals(i%Fault.detail.%ToJSON(), "{""count"":4,""max"":3,""namespace"":""USER""}", "naming the count, the cap and the namespace")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Api.AtelierError).#REASONSPECTOOMANY, "with the written reason")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#THERE)
    Do $$$AssertStatusNotOK(..Run(..#HERE, ..#SPEC), "the other namespace over the cap is refused")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.AtelierError).#SPECTOOMANY, "the other namespace")
    Do $$$AssertEquals(i%Fault.detail.%ToJSON(), "{""count"":4,""max"":3,""namespace"":""USER""}", "naming the other namespace")
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 4)
    Do $$$AssertStatusOK(..Run(..#HERE, ..#SPEC), "at a cap equal to the count the read answers")
}

/// <p>Integration (AC4): <code>explorer.namespacediff.read</code>, dispatched as the agent does with the Diff row's
/// arguments, answers the rows the screen's read answered, and refuses the same namespace with the screen's code.</p>
/// <p>Mutation: point the descriptor's source endpoint at <code>DocumentHashes</code> -&gt; the rows differ and this goes red.</p>
Method TestTheReadToolAnswersTheScreenRows()
{
    Do ..MakeProbe()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Set tScreenSC = ..Run(..#THERE, ..#SPEC, , , .tScreen)
        Do $$$AssertStatusOK(tScreenSC, "the screen's read answers")
        For tTarget = ..#THERE, ..#HERE {
            Set tUse = {"type": "tool_use", "id": "toolu_namespacediff", "input": {}}
            Do tUse.input.%Set("target", tTarget, "string")
            Do tUse.input.%Set("spec", ..#SPEC, "string")
            Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.namespacediff.read"), "string")
            Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
            Do $$$AssertStatusOK(tSC, tTarget _ ": the dispatch answers")
            If $$$ISERR(tSC) Continue
            Set tContent = tResults.%Get(0).%Get("content")
            If tTarget = ..#THERE {
                Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "the diff is answered without error: " _ $Extract(tContent, 1, 300))
                Set tRows = ##class(%DynamicObject).%FromJSON(tContent).rows
                Do $$$AssertEquals(tRows.%ToJSON(), tScreen.rows.%ToJSON(), "the screen's rows")
                Do $$$AssertEquals(tRows.%Size(), 4, "and there are four")
            } Else {
                Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 1, "the same namespace is an error")
                Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tContent).code, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "carrying the screen's refusal code")
            }
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tRemaining, 0, "the seeded turn is removed")
}

}
