/// <p>Pins Story 24.1's two System Explorer screens, Code metrics and Document hashes, read through
/// <class>OcuPilot.Port.DevToolPort</class>: every row of the story's matrix over the probe documents
/// <class>OcuPilot.Test.DevToolProbe</class> saves in <code>USER</code>, the refusals that must leave
/// <class>OcuPilot.Test.DevToolHarvestRecorder</class> with no recorded call, the query the port builds, and the
/// two read tools answering the rows the screens' read answered.</p>
/// <p>The screen's read is <method>OcuPilot.Screen.Read.Execute</method> over
/// <class>OcuPilot.Test.DevToolReadFixture</class>, which reaches the port through
/// <class>OcuPilot.Test.DevToolPortFixture</class>. The expected counts are made here from the text the instance
/// holds, by a small classifier of its own that covers the probes' lines.</p>
/// <p>Needs the install namespace and a <code>USER</code> namespace; it saves and removes the probe documents in
/// <code>USER</code> around every test, and its tool leg seeds one completed turn as the running principal and
/// removes it.</p>
Class OcuPilot.Test.DevToolRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolHarvestRecorder";

Parameter READ = "OcuPilot.Test.DevToolReadFixture";

Parameter METRICS = "OcuPilot.Screen.Descriptor.ExplorerCodeMetrics";

Parameter HASHES = "OcuPilot.Screen.Descriptor.ExplorerDocumentHashes";

Parameter NAMESPACE = "USER";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ..Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Forget the fixtures and remove the probe documents, so each test starts with none; a test makes them itself.</p>
Method Reset()
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "the probe documents are removed")
}

/// <p>Save the probe documents.</p>
Method MakeProbe()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE), "the probe documents are saved")
}

/// <p>Read <var>pDescriptor</var> over the fixtures with spec <var>pSpec</var>, <code>generated</code>
/// <var>pGenerated</var> (omitted when <code>""</code>) and cap <var>pMaxRows</var>.</p>
Method Run(pDescriptor As %String, pSpec As %String, pGenerated As %String = "", pMaxRows As %String = "", Output pResult, Output pHttp, Output pFault) As %Status
{
    Kill tCriteria
    Set tCriteria("spec") = pSpec
    If pGenerated '= "" Set tCriteria("generated") = pGenerated
    Quit $ClassMethod(..#READ, "Execute", pDescriptor, pMaxRows, .pResult, .pHttp, .pFault, .tCriteria)
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

/// <p>Count <var>pLines</var> (the array <code>pLines(0)</code> counts) into <var>pTotals</var>: <code>blank</code>,
/// <code>code</code> and <code>comment</code>, a line being blank when it holds only spaces and tabs and a comment when
/// its first character past them is <code>;</code> or <code>//</code>. Adds to what <var>pTotals</var> holds, under
/// <code>test</code> when <var>pTest</var>, else under <code>source</code>.</p>
ClassMethod Classify(ByRef pLines, pTest As %Boolean, ByRef pTotals)
{
    Set tScope = $Select(pTest: "test", 1: "source")
    For tI = 1:1:pLines(0) {
        Set tText = $ZStrip(pLines(tI), "<>W")
        Set tKind = $Select(tText = "": "blank", ($Extract(tText) = ";") || ($Extract(tText, 1, 2) = "//"): "comment", 1: "code")
        Set pTotals(tKind, tScope) = $Get(pTotals(tKind, tScope)) + 1
        Set pTotals("lines") = $Get(pTotals("lines")) + 1
    }
}

/// <p>The totals the probe classes hold, from their stored text: Alpha and Beta are source, Gamma a test class.</p>
Method ClassTotals(Output pTotals)
{
    Kill pTotals
    For tClass = "Alpha", "Beta", "Gamma" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ClassLines", ..#NAMESPACE, $Parameter(..#PROBE, "PACKAGE") _ "." _ tClass, .tLines), tClass _ " is read")
        Do ..Classify(.tLines, tClass = "Gamma", .pTotals)
    }
    Set pTotals("documents") = 3
}

/// <p>Assert row <var>pRow</var> of Code metrics is the one <var>pTotals</var> makes.</p>
Method AssertMetricsRow(pRow As %DynamicObject, ByRef pTotals, pLabel As %String)
{
    Set tCode = $Get(pTotals("code", "source")) + $Get(pTotals("code", "test"))
    Set tComments = $Get(pTotals("comment", "source")) + $Get(pTotals("comment", "test"))
    Set tBlank = $Get(pTotals("blank", "source")) + $Get(pTotals("blank", "test"))
    Set tLines = pTotals("lines")
    Do $$$AssertEquals(pRow.%Get("Documents"), pTotals("documents"), pLabel _ ": Documents")
    Do $$$AssertEquals(pRow.%Get("Lines"), tLines, pLabel _ ": Lines")
    Do $$$AssertEquals(pRow.%Get("Code"), tCode, pLabel _ ": Code")
    Do $$$AssertEquals(pRow.%Get("SourceCode"), +$Get(pTotals("code", "source")), pLabel _ ": SourceCode")
    Do $$$AssertEquals(pRow.%Get("TestCode"), +$Get(pTotals("code", "test")), pLabel _ ": TestCode")
    Do $$$AssertEquals(pRow.%Get("Comments"), tComments, pLabel _ ": Comments")
    Do $$$AssertEquals(pRow.%Get("Blank"), tBlank, pLabel _ ": Blank")
    Do $$$AssertEquals(pRow.%Get("CodePercent"), $Select(tLines = 0: 0, 1: +$Justify(100 * tCode / tLines, 0, 1)), pLabel _ ": CodePercent")
    Do $$$AssertEquals(pRow.%Get("CommentPercent"), $Select(tLines = 0: 0, 1: +$Justify(100 * tComments / tLines, 0, 1)), pLabel _ ": CommentPercent")
    Do $$$AssertEquals(pRow.%Get("BlankPercent"), $Select(tLines = 0: 0, 1: +$Justify(100 * tBlank / tLines, 0, 1)), pLabel _ ": BlankPercent")
}

/// <p>The text of generated routine <var>pName</var> in <var>..#NAMESPACE</var>, a header line the stored routine type
/// makes and then its lines, one to a node with the count at <code>pLines(0)</code>. Only system classes run while the
/// namespace is switched.</p>
ClassMethod GeneratedLines(pName As %String, Output pLines)
{
    Kill pLines
    Set pLines(0) = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRoutine = ##class(%Routine).%OpenId(pName)
        If $IsObject(tRoutine) {
            Set pLines(1) = "ROUTINE " _ $Piece(pName, ".", 1, 3) _ " [Type=INT" _ $Select(tRoutine.Generated: ",Generated", 1: "") _ "]"
            Set pLines(0) = 1
            Do tRoutine.Rewind()
            While 'tRoutine.AtEnd {
                Set tLength = 3641144
                Set pLines(0) = pLines(0) + 1
                Set pLines(pLines(0)) = tRoutine.ReadLine(.tLength)
            }
        }
        Set tRoutine = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pLines(0) = 0
    }
}

/// <p>The SHA-256 of <var>pLines</var>' text, each line followed by a line feed, in hex, as <code>$System.Encryption.ToHex</code> writes it: the hash the story pins.</p>
ClassMethod HashOf(ByRef pLines) As %String
{
    Set tText = ""
    For tI = 1:1:pLines(0) {
        Set tText = tText _ pLines(tI) _ $Char(10)
    }
    Quit $System.Encryption.ToHex($System.Encryption.SHAHash(256, tText))
}

/// <p>The two declarations: each validates, sits at its side-bar position in System Explorer, is gated on
/// <code>%Development:USE</code> alone, reads through the devtool source's own endpoint, keys no classic page, declares
/// the story's two criteria, carries three prompts in the Code group and resolves from its tool identifier.</p>
Method TestTheScreensAreDeclaredAsTheStorySays()
{
    For tCase = $ListBuild(..#METRICS, "system-explorer/code-metrics", 13, "CodeMetrics", "explorer.codemetrics"), $ListBuild(..#HASHES, "system-explorer/document-hashes", 14, "DocumentHashes", "explorer.documenthashes") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": the declaration, its read and its criteria validate")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.area _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind, $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|system-explorer|namespace|none", tClass _ ": route, position, area, scope and id")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Development"",""permission"":""USE""}]", tClass _ ": gated on %Development:USE alone")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint, "devtool|" _ $List(tCase, 4), tClass _ ": read through the devtool port")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "", tClass _ ": no classic page")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Read).CriteriaParams(tClass), $ListBuild("spec", "generated"), tClass _ ": the spec and generated criteria")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three prompts")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 5)), tClass, tClass _ ": its tool identifier resolves to it")
    }
}

/// <p>Matrix, Metrics: the probe classes' totals are one row whose ten fields equal the stored text's composition, and
/// the answer is not truncated.</p>
/// <p>Mutation: make <method>OcuPilot.Port.DevToolPort.MetricsRows</method> add the source and test comment lines to Code
/// -&gt; the Code and CodePercent assertions go red.</p>
Method TestMetricsAreTheProbesComposition()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#METRICS, "OcuProbe241.*.cls", , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "one row")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    If tResult.rows.%Size() '= 1 Quit
    Do ..ClassTotals(.tTotals)
    Do ..AssertMetricsRow(tResult.rows.%Get(0), .tTotals, "classes")
    Do $$$AssertTrue(tTotals("code", "test") > 0 && (tTotals("code", "source") > 0) && (tTotals("comment", "source") > 0) && (tTotals("blank", "source") > 0), "the probes hold every kind of line, so each field is exercised")
}

/// <p>Matrix, Hashes: one row for each probe class, each <code>Hash</code> the SHA-256 in hex of the stored UDL text with
/// a line feed after every line, and <code>Modified</code> a time.</p>
/// <p>Mutation: join the lines with no line feed in <method>OcuPilot.Port.Harvest.EnvSync.HashDoc</method> -&gt; the
/// hash assertions go red (and the harvest comparison with it).</p>
Method TestHashesAreTheSha256OfTheStoredText()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls", , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals(..Column(tResult.rows, "Document"), "OcuProbe241.Alpha.cls,OcuProbe241.Beta.cls,OcuProbe241.Gamma.cls", "one row for each probe class")
    Do $$$AssertEquals(tResult.truncated, 0, "not truncated")
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ClassLines", ..#NAMESPACE, $Piece(tRow.%Get("Document"), ".", 1, 2), .tLines), tRow.%Get("Document") _ " is read")
        Do $$$AssertEquals(tRow.%Get("Hash"), ..HashOf(.tLines), tRow.%Get("Document") _ ": the SHA-256 of its text")
        Do $$$AssertTrue($Match(tRow.%Get("Hash"), "^[0-9A-F]{64}$"), tRow.%Get("Document") _ ": 64 hex characters")
        Do $$$AssertTrue($Match(tRow.%Get("Modified"), "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+$"), tRow.%Get("Document") _ ": a modified time")
    }
}

/// <p>Matrix, Routines: a spec naming routines and include files lists one row each, hashed over the header line the
/// instance gives a routine and then its lines, and Code metrics counts both.</p>
Method TestRoutinesAndIncludeFilesAreListedAndCounted()
{
    Do ..MakeProbe()
    Set tSpec = "OcuProbe241*.mac,OcuProbe241*.inc"
    Set tSC = ..Run(..#HASHES, tSpec, , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the hash read answers")
    Do $$$AssertEquals(..Column(tResult.rows, "Document"), "OcuProbe241Inc.inc,OcuProbe241Mac.mac", "one row for each routine and include file")
    Kill tTotals
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $ClassMethod(..#PROBE, "RoutineLines", tRow.%Get("Document"), .tLines)
        Do $$$AssertEquals(tRow.%Get("Hash"), ..HashOf(.tLines), tRow.%Get("Document") _ ": the SHA-256 of its header and lines")
        Do ..Classify(.tLines, 0, .tTotals)
    }
    Set tTotals("documents") = 2
    Set tSC = ..Run(..#METRICS, tSpec, , , .tMetrics, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the metrics read answers")
    Do $$$AssertEquals(tMetrics.rows.%Size(), 1, "one metrics row")
    If tMetrics.rows.%Size() = 1 Do ..AssertMetricsRow(tMetrics.rows.%Get(0), .tTotals, "routines")
}

/// <p>Matrix, Generated: <code>yes</code> lists the compiled probes' generated routines and <code>no</code> lists none,
/// and the port sent the body <code>includeGenerated</code> 1 and 0.</p>
/// <p>Mutation: send <code>includeGenerated</code> 1 always in <method>OcuPilot.Port.DevToolPort.Invoke</method> -&gt;
/// the <code>no</code> legs go red.</p>
Method TestGeneratedRoutinesFollowTheChoice()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.int", "yes", , .tYes, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read with generated yes answers")
    Do $$$AssertEquals(..Column(tYes.rows, "Document"), "OcuProbe241.Beta.1.int,OcuProbe241.Gamma.1.int", "generated yes lists the generated routines")
    Set tIterator = tYes.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do ..GeneratedLines(tRow.%Get("Document"), .tLines)
        Do $$$AssertEquals(tRow.%Get("Hash"), ..HashOf(.tLines), tRow.%Get("Document") _ ": hashed over that header and its lines")
    }
    Set tCall = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tCall.query.includeGenerated, "1", "and the body was sent includeGenerated 1")
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.int", "no", , .tNo, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read with generated no answers")
    Do $$$AssertEquals(tNo.rows.%Size(), 0, "generated no lists none")
    Set tCall = $ClassMethod(..#RECORDER, "CallAt", 2)
    Do $$$AssertEquals(tCall.query.includeGenerated, "0", "and the body was sent includeGenerated 0")
    Set tSC = ..Run(..#METRICS, "OcuProbe241.*.int", "yes", , .tCounted, .tHttp, .tFault)
    Do $$$AssertEquals(tCounted.rows.%Get(0).Documents, 2, "Code metrics counts the generated routines when asked")
}

/// <p>Matrix, No match: a spec that matches nothing is no hash rows and one metrics row of zero documents, neither
/// truncated.</p>
Method TestAnAbsentPackageMatchesNothing()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#HASHES, "OcuProbe241Absent.*.cls", , , .tHashes, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the hash read answers")
    Do $$$AssertEquals(tHashes.rows.%Size(), 0, "no hash rows")
    Do $$$AssertEquals(tHashes.truncated, 0, "not truncated")
    Set tSC = ..Run(..#METRICS, "OcuProbe241Absent.*.cls", , , .tMetrics, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the metrics read answers")
    Do $$$AssertEquals(tMetrics.rows.%Size(), 1, "one metrics row")
    Do $$$AssertEquals(tMetrics.rows.%Get(0).Documents, 0, "of no documents")
    Do $$$AssertEquals(tMetrics.rows.%Get(0).Lines, 0, "and no lines")
}

/// <p>Matrix, Over the cap: a cap below the probe count answers the cap's rows and <code>truncated</code>, and a cap
/// at the count does not.</p>
Method TestACapBelowTheCountTruncates()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls", , 2, .tCut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals(tCut.rows.%Size(), 2, "the cap's rows")
    Do $$$AssertEquals(tCut.truncated, 1, "truncated")
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls", , 3, .tWhole, .tHttp, .tFault)
    Do $$$AssertEquals(tWhole.rows.%Size(), 3, "a cap at the count answers every row")
    Do $$$AssertEquals(tWhole.truncated, 0, "and does not truncate")
}

/// <p>Assert the last answer was refused <var>pHttp</var> with <var>pCode</var>, no body was asked for and nothing was
/// logged.</p>
Method AssertRefused(pHttp As %Integer, pCode As %String, pLabel As %String)
{
    Do $$$AssertEquals(+$Get(i%Http), pHttp, pLabel _ ": HTTP status")
    Do $$$AssertEquals($Select($IsObject($Get(i%Fault)): i%Fault.%Get("code"), 1: ""), pCode, pLabel _ ": fault code")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 0, pLabel _ ": no body was asked for")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "LogCount"), 0, pLabel _ ": nothing is logged")
}

Property Http As %Integer;

Property Fault As %DynamicObject;

/// <p>Run <var>pDescriptor</var> over <var>pSpec</var> and keep the refusal in <property>Http</property> and
/// <property>Fault</property>.</p>
Method Refusal(pDescriptor As %String, pSpec As %String, Output pResult)
{
    Set tSC = ..Run(pDescriptor, pSpec, , , .pResult, .tHttp, .tFault)
    Set i%Http = tHttp
    Set i%Fault = tFault
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
}

/// <p>Matrix, Wide spec: a bare <code>*</code>, alone or as one part, is 400 <code>EXPLORER.SPEC.WIDE</code> on both
/// screens, before any body runs. The cap is lifted and the recorder answers without a scan, so a body asked for would
/// be recorded.</p>
/// <p>Mutation: move the wide-spec check after the <code>HarvestPortClass()</code> call in
/// <method>OcuPilot.Port.DevToolPort.Invoke</method> -&gt; the no-call assertion goes red.</p>
Method TestAWideSpecIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 100000000)
    Do $ClassMethod(..#RECORDER, "SetDry")
    For tDescriptor = ..#METRICS, ..#HASHES {
        For tSpec = "*", "OcuProbe241.*.cls, *" {
            Do ..Refusal(tDescriptor, tSpec)
            Do ..AssertRefused(400, ##class(OcuPilot.Api.AtelierError).#SPECWIDE, tDescriptor _ " " _ tSpec)
            Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Api.AtelierError).#REASONSPECWIDE, "with the written reason")
        }
    }
}

/// <p>Matrix, Bad shape: a spec with a slash, a backslash, a double dot, a space inside a name, a control character or an
/// empty part is 400 <code>PORT.VALIDATION</code> with the shape reason, and one longer than 256 characters with the
/// length reason, before any body runs.</p>
Method TestABadSpecShapeIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Set tShape = ##class(OcuPilot.Port.DevToolPort).#REASONSPECSHAPE
    Set tCases = $ListBuild("a/b", "a\b", "a..b", "a b.cls", "a" _ $Char(7) _ "b", "a,,b.cls", "a.cls,", ",a.cls", "a.cls," _ $Char(9) _ "b.cls", "OcuProbe241.*.cls;x")
    For tI = 1:1:$ListLength(tCases) {
        Do ..Refusal(..#HASHES, $List(tCases, tI))
        Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "spec " _ tI)
        Do $$$AssertEquals(i%Fault.%Get("reason"), tShape, "spec " _ tI _ ": the shape reason")
    }
    Kill tCriteria
    Set tCriteria("spec") = $Translate($Justify("", 257), " ", "a")
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "CodeMetrics", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code") _ " " _ tFault.%Get("reason"), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION _ " " _ ##class(OcuPilot.Port.DevToolPort).#REASONSPECLENGTH, "a spec of 257 characters is refused with the length reason")
    Kill tCriteria
    Set tCriteria("spec") = "OcuProbe241.*.cls"
    Set tCriteria("generated") = "maybe"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code") _ " " _ tFault.%Get("reason"), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION _ " " _ ##class(OcuPilot.Port.DevToolPort).#REASONGENERATED, "a generated value that is neither yes nor no, sent to the port, is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 0, "and no body was asked for")
}

/// <p>Matrix, Too many: a spec matching more documents than the port's cap is 400 <code>EXPLORER.SPEC.TOOMANY</code> with
/// <code>detail.count</code> and <code>detail.max</code>, before any body runs; at a cap equal to the count it reads.</p>
Method TestTooManyDocumentsAreRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 2)
    Do ..Refusal(..#HASHES, "OcuProbe241.*.cls")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.AtelierError).#SPECTOOMANY, "three documents over a cap of two")
    Do $$$AssertEquals(i%Fault.detail.%ToJSON(), "{""count"":3,""max"":2}", "naming the count and the cap, and no namespace")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Api.AtelierError).#REASONSPECTOOMANY, "with the written reason")
    Do $$$AssertTrue(i%Fault.%Get("reason") [ ("more than " _ $FNumber($Parameter("OcuPilot.Port.DevToolPort", "MAXDOCUMENTS"), ",") _ " documents"), "and the reason names the shipped cap")
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 3)
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls", , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "at a cap equal to the count the read answers")
    Do $$$AssertEquals(tResult.rows.%Size(), 3, "every row")
    Do $ClassMethod(..#FIXTURE, "SetMaxDocuments", 4)
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls,OcuProbe241.*.int", "yes", , .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.detail.count, 1: ""), "400 5", "generated yes counts the two generated routines against the cap")
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls,OcuProbe241.*.int", "no", , .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tResult.rows.%Size(), 3, "and generated no counts the classes alone")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Port.DevToolPort", "MaxDocuments"), $Parameter("OcuPilot.Port.DevToolPort", "MAXDOCUMENTS"), "the shipped port's cap is its MAXDOCUMENTS")
}

/// <p>Matrix, Gate: a caller without <code>%Development:USE</code>, and one with it but without READ on the namespace's code
/// databases, is 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair, before any body runs.</p>
Method TestAnUnprivilegedCallerIsRefusedBeforeAnyBody()
{
    Do ..MakeProbe()
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ..Refusal(..#METRICS, "OcuProbe241.*.cls")
    Do ..AssertRefused(403, ##class(OcuPilot.Kernel.Denial).Code(), "no pair held")
    Do $$$AssertEquals(i%Fault.detail.failedPair, "%Development:USE", "naming %Development:USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Do ..Refusal(..#HASHES, "OcuProbe241.*.cls")
    Do ..AssertRefused(403, ##class(OcuPilot.Kernel.Denial).Code(), "the code databases' READ not held")
    Do $$$AssertEquals(i%Fault.detail.failedPair, "%DB_USER:READ", "naming READ on the namespace's code database")
}

/// <p>Matrix, Unknown namespace: a scope the instance does not hold is 400 <code>PORT.VALIDATION</code>, before any body
/// runs.</p>
Method TestAnUnknownNamespaceIsRefusedBeforeAnyBody()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("NOSUCH241")
    Do ..Refusal(..#METRICS, "OcuProbe241.*.cls")
    Do ..AssertRefused(400, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "a namespace the instance does not hold")
    Do $$$AssertEquals(i%Fault.%Get("reason"), ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, "with the written reason")
}

/// <p>The port builds the body's query itself: <code>spec</code> without the spaces around its parts,
/// <code>namespace</code>, <code>includeGenerated</code> and, for Code metrics, <code>topN</code> 1, and never
/// <code>allowWide</code> or anything the caller supplied.</p>
Method TestTheBodyIsSentOnlyTheKeysThePortBuilds()
{
    Do ..MakeProbe()
    Set tSC = ..Run(..#METRICS, "OcuProbe241.*.cls , OcuProbe241*.mac", , , .tMetrics, .tHttp, .tFault)
    Set tSC = ..Run(..#HASHES, "OcuProbe241.*.cls", , , .tHashes, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 2, "each read asked for one body")
    Set tFirst = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tFirst.handler _ "." _ tFirst.method, "OcuPilot.Port.Harvest.Loc.LocCount", "Code metrics runs the line counter")
    Do $$$AssertEquals(tFirst.query.%ToJSON(), "{""includeGenerated"":""0"",""namespace"":""USER"",""spec"":""OcuProbe241.*.cls,OcuProbe241*.mac"",""topN"":""1""}", "with its four keys and the spec stripped")
    Set tSecond = $ClassMethod(..#RECORDER, "CallAt", 2)
    Do $$$AssertEquals(tSecond.handler _ "." _ tSecond.method, "OcuPilot.Port.Harvest.EnvSync.DocHashes", "Document hashes runs the hasher")
    Do $$$AssertEquals(tSecond.query.%ToJSON(), "{""includeGenerated"":""0"",""namespace"":""USER"",""spec"":""OcuProbe241.*.cls""}", "with three keys, and no allowWide")
    Kill tCriteria
    Set tCriteria("spec") = "OcuProbe241.*.cls", tCriteria("allowWide") = 1, tCriteria("topN") = 50
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "a direct call answers")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "CallAt", 3).query.%ToJSON(), tSecond.query.%ToJSON(), "and a key the caller adds is not sent")
}

/// <p>Integration (AC4): <code>explorer.codemetrics.read</code> and <code>explorer.documenthashes.read</code>, dispatched
/// as the agent does, answer the rows the screen's read answered for the same spec.</p>
/// <p>Mutation: point the Code metrics descriptor's source endpoint at <code>DocumentHashes</code> -&gt; the Code metrics
/// leg goes red.</p>
Method TestTheReadToolsAnswerTheScreenRows()
{
    Do ..MakeProbe()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        For tCase = $ListBuild("explorer.codemetrics.read", ..#METRICS, "Documents"), $ListBuild("explorer.documenthashes.read", ..#HASHES, "Hash") {
            Kill tCriteria
            Set tCriteria("spec") = "OcuProbe241.*.cls"
            Set tScreenSC = ##class(OcuPilot.Screen.Read).Execute($List(tCase, 2), "", .tScreen, .tHttp, .tFault, .tCriteria)
            Do $$$AssertStatusOK(tScreenSC, $List(tCase, 1) _ ": the screen's read answers")
            Set tUse = {"type": "tool_use", "id": "toolu_devtool", "input": {"spec": "OcuProbe241.*.cls"}}
            Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName($List(tCase, 1)), "string")
            Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
            Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the dispatch answers")
            If $$$ISERR(tSC) || $$$ISERR(tScreenSC) Continue
            Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, $List(tCase, 1) _ ": without error: " _ $Extract(tResults.%Get(0).%Get("content"), 1, 300))
            Set tContent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
            Do $$$AssertEquals(tContent.rows.%ToJSON(), tScreen.rows.%ToJSON(), $List(tCase, 1) _ ": the screen's rows")
            Do $$$AssertTrue(tContent.rows.%Size() > 0, $List(tCase, 1) _ ": and there are some")
            Do $$$AssertTrue(tContent.rows.%Size() > 0 && tContent.rows.%Get(0).%IsDefined($List(tCase, 3)), $List(tCase, 1) _ ": each row carries its own " _ $List(tCase, 3) _ " field")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tRemaining, 0, "the seeded turn is removed")
}

/// <p>The devtool source's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this block too: each case
/// replaces the Code metrics declaration's <code>read.source</code> and names the sentence the registry's read check
/// answers, or <code>null</code>.</p>
XData Cases
{
{
  "cases": [
    {"name": "a devtool LIST of CodeMetrics is sound", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST"}, "expected": null},
    {"name": "so is DocumentHashes", "source": {"port": "devtool", "endpoint": "DocumentHashes", "type": "LIST"}, "expected": null},
    {"name": "so is NamespaceDiff", "source": {"port": "devtool", "endpoint": "NamespaceDiff", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not serve", "source": {"port": "devtool", "endpoint": "Nothing", "type": "LIST"}, "expected": "read.source.endpoint 'Nothing' is not one of the devtool port's endpoints ('CodeMetrics', 'DocumentHashes', 'NamespaceDiff') (AD-29)"},
    {"name": "a type other than LIST", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a devtool source, which lists the developer tools' rows (AD-36)"},
    {"name": "rowGet", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST", "rowGet": {"key": "Documents", "param": "name", "fields": ["Lines"], "derived": []}}, "expected": "read.source.rowGet is declared on a devtool source, which answers its list whole (AD-36)"},
    {"name": "forEach", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST", "forEach": ["Lines"]}, "expected": "read.source.forEach is declared on a devtool source, which answers its list whole (AD-36)"},
    {"name": "query", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on a devtool source, which answers its list whole (AD-36)"},
    {"name": "parts", "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a devtool source, which answers its list whole (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry, and the corpus refuses at
/// least six shapes.</p>
/// <p>Mutation (Rule 19): drop the devtool arm from <method>OcuPilot.Screen.Registry.ReadProblem</method> -- the endpoint, type
/// and key cases go red.</p>
Method TestTheDevtoolSourceRefusals()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Kill tDeclaration
        Do $ClassMethod(..#METRICS, "DeclarationJson", .tDeclaration)
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 6, "the corpus refuses its shapes: " _ tRefusals)
}

}
