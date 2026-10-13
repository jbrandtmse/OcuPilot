/// <p>Pins Story 20.27's data transformation test end to end against the probe transformations of
/// <class>OcuPilot.Test.InteropTransformFixture</class> in <code>USER</code> (AD-6, AD-15, AD-35, AD-39, AD-51, AD-53, AD-62): a
/// person's Test on a Data transformations row and the agent's proposal, confirmed over HTTP, each run <code>Transform</code> once on
/// the pasted message and answer the target as text in one JSON envelope; an HL7 and an X12 target are shown as their raw segments, one
/// to a line, and every stored object the run made is deleted before the answer; an existing target starts from <code>%New()</code>; the
/// card shows the transformation, its classes and the input and states that the code runs; the output reaches no stored proposal, step,
/// turn, ledger row or audit row; and a <code>TRANSFORM</code> read runs and stores nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs transformations in
/// <code>USER</code></b>. No probe production is used. The fixture and every proposal are removed after the last test. It borrows the
/// transport helpers of <class>OcuPilot.Test.InteropItemControl</class> and the stored-text reader of
/// <class>OcuPilot.Test.InteropHostTest</class>. One class per run.</p>
Class OcuPilot.Test.InteropTransformTest Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropTransformFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter HOST = "OcuPilot.Test.InteropHostTest";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropTransformTest";

Parameter SCREEN = "/screens/interop.transforms";

Parameter NAMESPACE = "USER";

/// <p>The target the XML transformation answers for the message <code>x</code>, as the dialog shows it.</p>
Parameter XMLLINES = "[""<StringResponse>"",""  <StringValue>out:x</StringValue>"",""</StringResponse>""]";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTransformTest compiles and runs probe data transformations in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

ClassMethod Clear()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p>A person's Test action on <var>pName</var> with the message <var>pContent</var>, as <code>status code</code>, the answer in
/// <var>pAnswer</var>.</p>
ClassMethod Act(pName As %String, pContent As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "test", "values": {}}
    Do tBody.%Set("id", pName, "string")
    Do tBody.values.%Set("content", pContent, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The arguments of the agent's call.</p>
ClassMethod ArgsFor(pName As %String, pContent As %String) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Do tArgs.%Set("content", pContent, "string")
    Quit tArgs
}

/// <p>The output member of <var>pAnswer</var> as <code>status|sourceClass|targetClass|errors|console|lines</code>, or <code>""</code>.</p>
ClassMethod Shape(pAnswer) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("output")) Quit ""
    Set tOutput = pAnswer.output
    Quit tOutput.status _ "|" _ tOutput.sourceClass _ "|" _ tOutput.targetClass _ "|" _ tOutput.errors _ "|" _ tOutput.console.%ToJSON() _ "|" _ tOutput.lines.%ToJSON()
}

/// <p>AC1: a person's Test on the XML transformation runs it once and answers, in one JSON envelope, <code>done</code> with the two
/// classes, the target as indented XML and no console line; the change event names the class; the run stored nothing; and one audit
/// row of OcuPilot's own records the test with the classes and the status and neither the message nor a line.</p>
/// <p>Mutation (Rule 19): call <code>Transform</code> twice in <method>OcuPilot.Port.InteropPort.RunTransformHere</method> -- the run
/// count goes red; skip the render -- the lines go red; drop the <code>AuditRuntime</code> call from
/// <method>OcuPilot.Port.InteropPort.PerformTransformTest</method> -- the audit leg goes red.</p>
Method TestThePersonsRunShowsTheTargetAsXml()
{
    Set tName = $Parameter(..#FIXTURE, "XML") _ ".cls"
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tAudited = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """id"":""" _ tName _ """")
    Set tText = ..Act(tName, $ClassMethod(..#FIXTURE, "Message", "x"), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Shape(tAnswer), "done|Ens.StringRequest|Ens.StringResponse|0|[]|" _ ..#XMLLINES, "the run is done and shows the target as indented XML")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 1, "the transformation ran once")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.target.id, 1: ""), "updated|class|USER|" _ tName, "publishing the change event for the class")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the run stored nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """id"":""" _ tName _ """") - tAudited, 1, "one audit row of OcuPilot's own records the test")
    Do $$$AssertTrue((tData [ """sourceClass"":""Ens.StringRequest""") && (tData [ """status"":""done""") && (tData '[ "out:") && (tData '[ "StringValue") && (tData '[ """lines"""), "which carries the classes and the status and no message and no line: " _ tData)
}

/// <p>AC1, AC3, AC6: the agent's call, minted for the HTTP account and confirmed over HTTP, shows a card with the transformation, its
/// two classes and the input as a changed-lines block, the running consequence, not destructive, under a governance key that reads
/// <code>true</code>; the mint runs nothing; the confirm answers one envelope whose output is the same answer a person's Test gets; and
/// the output is in no stored proposal, step, turn, ledger row or audit row, with the input in the proposal as the control that the
/// read can see what is stored.</p>
/// <p>Mutation (Rule 19): drop <code>Input</code> from <method>OcuPilot.Screen.Tool.InteropTransformTest.StateDiff</method> or clear its
/// consequence code -- the card leg goes red; have <method>OcuPilot.Kernel.Proposal.Confirm</method> record the confirmed output as the
/// proposal's read-back -- the stored-text leg goes red; add <code>outcome</code> to
/// <method>OcuPilot.Screen.Tool.InteropTransformTest.WriteOutput</method> -- the output leg goes red.</p>
Method TestTheAgentsRunConfirmsOverHttp()
{
    Set tName = $Parameter(..#FIXTURE, "XML") _ ".cls"
    Set tMessage = $ClassMethod(..#FIXTURE, "Message", "x")
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tAudited = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """id"":""" _ tName _ """")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..ArgsFor(tName, tMessage), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tMintHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the call mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    For tI = 0:1:tProposal.changed.%Size() - 1 Set tFields = tFields _ $Select(tFields = "": "", 1: "|") _ tProposal.changed.%Get(tI).field
    Do $$$AssertEquals(tFields, "Transform|Source|Target|Input", "its card shows the transformation, its classes and the input")
    Do $$$AssertEquals(tProposal.changed.%Get(0).after _ "|" _ tProposal.changed.%Get(1).after _ "|" _ tProposal.changed.%Get(2).after, tName _ "|Ens.StringRequest|Ens.StringResponse", "naming the class and the two classes")
    Set tInput = tProposal.changed.%Get(3)
    Do $$$AssertEquals(tInput.kind _ "|" _ tInput.before _ "|" _ tInput.after, "lines||" _ tMessage _ $Char(10), "and the input as a changed-lines block")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id, "class|" _ tName, "the target is the class, by its document name")
    Set tId = tProposal.proposalId
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tId, "Destructive") + 0), "INTEROP.TRANSFORM.RUNS|0", "it states the running consequence and is not destructive")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Governance.Baseline).Seed($Parameter(..#TOOL, "TOOLNAME"), .tListed) && tListed, "the governance key reads true")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "the mint ran nothing")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertTrue($Length(tRaw, "}{") = 1, "exactly one envelope")
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", "marked and updated")
    Do $$$AssertEquals(..Shape(tAnswer), "done|Ens.StringRequest|Ens.StringResponse|0|[]|" _ ..#XMLLINES, "the output is the answer a person's Test gets")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 1, "the confirm ran the transformation once")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and stored nothing")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, $Parameter(..#TOOL, "TOOLNAME")), 1, "the confirmed write is in the ledger once")
    Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT Arguments, Fields, Target, Code, Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurn)
    Set tLedger = ""
    While tRows.%Next() {
        Set tLedger = tLedger _ tRows.%GetData(1) _ "|" _ tRows.%GetData(2) _ "|" _ tRows.%GetData(3) _ "|" _ tRows.%GetData(4) _ "|" _ tRows.%GetData(5) _ ";"
    }
    Do $$$AssertTrue((tLedger '= "") && (tLedger '[ "out:") && (tLedger '[ "<StringResponse>"), "the ledger row carries no output: " _ tLedger)
    Set tStored = $ClassMethod(..#HOST, "StoredText", tId, tTurn)
    Do $$$AssertTrue((tStored [ "<StringValue>x</StringValue>") && (tStored '[ "out:") && (tStored '[ "<StringResponse>"), "the confirmed proposal and the turn's steps, read back, hold the input and no output")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """id"":""" _ tName _ """") - tAudited, 1, "one audit row records the test")
    Do $$$AssertTrue((tData '[ "out:") && (tData '[ "StringValue") && (tData '[ """lines"""), "which carries no input and no output: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC2: an HL7 ADT_A01 and an X12 interchange are shown as the raw text of the target, one segment to a line, as the classic raw
/// view writes it, from the person's Test and from the agent's confirmed call, and the HL7 and X12 extents hold their counts from
/// before.</p>
/// <p>Mutation (Rule 19): write the segmented target without the classic separators in
/// <method>OcuPilot.Port.InteropPort.RenderTargetHere</method> -- the line counts go red; delete only the target in
/// <method>OcuPilot.Port.InteropPort.RunTransformHere</method> -- the X12 extent goes red.</p>
Method TestDocumentsAreShownAsRawTextOneSegmentToALine()
{
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tText = ..Act($Parameter(..#FIXTURE, "HL7") _ ".cls", $ClassMethod(..#FIXTURE, "Hl7Text"), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the HL7 Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.lines.%Size() _ "|" _ tOutput.lines.%Get(0) _ "|" _ tOutput.lines.%Get(3), 1: ""), "done|4|MSH|^~\&|PROBEAPP|OCUFAC|OCURECV|OCUFAC|20260101000000||ADT^A01|MSG1|P|2.5|PV1|1|I|ICU^101^A", "the HL7 target is its four segments, the first with the sending application the transformation set")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the HL7 run stored nothing")
    Set tText = ..Act($Parameter(..#FIXTURE, "X12") _ ".cls", $Parameter(..#FIXTURE, "X12TEXT"), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the X12 Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.lines.%Size() _ "|" _ $Extract(tOutput.lines.%Get(0), 1, 7) _ "|" _ tOutput.lines.%Get(6), 1: ""), "done|7|ISA*00*|IEA*1*000000001~", "the X12 target is its seven segments")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the interchange the parse saved, and the copy, are deleted before the answer")
    For tCase = $ListBuild("HL7", "", "done|4|MSH|^~\&|PROBEAPP|"), $ListBuild("X12", "", "done|7|ISA*00*") {
        Set tMessage = $Select($List(tCase, 1) = "HL7": $ClassMethod(..#FIXTURE, "Hl7Text"), 1: $Parameter(..#FIXTURE, "X12TEXT"))
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..ArgsFor($Parameter(..#FIXTURE, $List(tCase, 1)) _ ".cls", tMessage), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tMintHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the agent's call mints")
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirm)
        Set tOutput = $Select($IsObject($Get(tConfirm)): tConfirm.%Get("output"), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tOutput): $Extract(tOutput.status _ "|" _ tOutput.lines.%Size() _ "|" _ tOutput.lines.%Get(0), 1, $Length($List(tCase, 3))), 1: ""), "200 " _ $List(tCase, 3), $List(tCase, 1) _ ": the agent's confirmed test answers the person's lines: " _ $Extract($Get(tRaw), 1, 300))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the confirmed tests stored nothing either")
}

/// <p>AC1: a transformation that creates <code>existing</code> gets a target from <code>%New()</code> with no argument: the classic
/// dialog's argument would put its own marker text into the response's first property, so the target here holds only what the
/// transformation wrote.</p>
/// <p>Mutation (Rule 19): create the target with an argument in <method>OcuPilot.Port.InteropPort.RunTransformHere</method> -- this goes
/// red.</p>
Method TestAnExistingTargetStartsFromNewWithNoArgument()
{
    Set tText = ..Act($Parameter(..#FIXTURE, "EXISTING") _ ".cls", $ClassMethod(..#FIXTURE, "Message", "x"), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Shape(tAnswer), "done|Ens.StringRequest|Ens.StringResponse|0|[]|[""<StringResponse>"",""  <StringValue>existing:x</StringValue>"",""</StringResponse>""]", "the target holds what the transformation wrote and nothing before it")
}

/// <p>AC2: an EDI XML document is a virtual document: a pasted <code>&lt;root&gt;</code>, with blanks or line ends before it or none
/// (the vendor opens text with no <code>&lt;</code> in its first four characters as a file), is parsed by its own <code>ImportFromString</code> and the target is shown as indented XML, one element to a line, with nothing stored; and an XML
/// message after a line end, with its declaration, is read from its first <code>&lt;</code>.</p>
/// <p>Mutation (Rule 19): render an EDI XML target without the <code>"wt"</code> option in
/// <method>OcuPilot.Port.InteropPort.RenderTargetHere</method> -- the lines go red; hand the vendor the pasted text with its leading
/// blanks in <method>OcuPilot.Port.InteropPort.ParseSourceHere</method> -- the blanks leg goes red; strip blanks alone, not line ends, in
/// <method>OcuPilot.Port.InteropPort.PastedXmlHere</method> -- the line-end legs go red.</p>
Method TestAnEdiXmlDocumentIsParsedAsADocumentAndShownAsIndentedXml()
{
    Set tName = $Parameter(..#FIXTURE, "EDIXML") _ ".cls"
    Set tText = $Parameter(..#FIXTURE, "EDIXMLTEXT")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    For tBlanks = "", "      ", $Char(9, 9, 9, 9, 9), $Char(13, 10), $Char(10, 32, 9) {
        Set tCode = ..Act(tName, tBlanks _ tText, .tAnswer)
        Do $$$AssertEquals(tCode, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
        Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
        If '$IsObject(tOutput) Continue
        Set tLines = tOutput.lines
        Do $$$AssertEquals(tOutput.status _ "|" _ tOutput.sourceClass _ "|" _ tOutput.targetClass _ "|" _ tOutput.errors _ "|" _ tOutput.console.%Size() _ "|" _ tLines.%Size(), "done|EnsLib.EDI.XML.Document|EnsLib.EDI.XML.Document|0|0|4", "blanks " _ $Length(tBlanks) _ ": the run is done with four lines")
        Do $$$AssertEquals(tLines.%Get(0) _ "|" _ $ZStrip(tLines.%Get(1), "<W") _ "|" _ $ZStrip(tLines.%Get(2), "<W") _ "|" _ tLines.%Get(3), "<root>|<a>1</a>|<b>two</b>|</root>", "blanks " _ $Length(tBlanks) _ ": the target is the document's elements, one to a line")
        Do $$$AssertTrue(($Length(tLines.%Get(1)) > $Length($ZStrip(tLines.%Get(1), "<W"))) && ($Length(tLines.%Get(2)) > $Length($ZStrip(tLines.%Get(2), "<W"))), "blanks " _ $Length(tBlanks) _ ": the children are indented")
    }
    Set tCode = ..Act($Parameter(..#FIXTURE, "XML") _ ".cls", $Char(13, 10) _ "<?xml version=""1.0""?>" _ $ClassMethod(..#FIXTURE, "Message", "x"), .tAnswer)
    Do $$$AssertEquals(tCode _ " " _ ..Shape(tAnswer), "200  done|Ens.StringRequest|Ens.StringResponse|0|[]|" _ ..#XMLLINES, "an XML message after a line end, with its declaration, is read from its first <")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the runs stored nothing")
}

/// <p>The extents the legs compare before and after a run each read a real count, so an equal pair is not two unreadable ones.</p>
/// <p>Mutation (Rule 19): name an extent that does not exist in <method>OcuPilot.Test.InteropTransformFixture.Counts</method> -- this
/// goes red.</p>
Method TestTheExtentsTheLegsCompareAreReadable()
{
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Do $$$AssertTrue(($Length(tCounts, ";") = 4) && (tCounts '[ "=-1") && (tCounts '= "unread"), "all four extents read a count: " _ tCounts)
}

/// <p>AC7: the <code>TRANSFORM</code> read, with and without the test's action, answers the transformation's classes, kinds and the
/// message as given, and runs no <code>Transform</code> and stores nothing, whatever the transformation.</p>
/// <p>Mutation (Rule 19): call <code>Transform</code> in <method>OcuPilot.Port.InteropPort.ReadTransform</method> -- the run count goes
/// red; judge an XML adaptor class before a virtual document in <method>OcuPilot.Port.InteropPort.FormatKindHere</method> -- the EDI XML
/// case, which is both, goes red.</p>
Method TestAReadRunsNothingAndStoresNothing()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tCases = $ListBuild($ListBuild("XML", "Ens.StringRequest||xml|Ens.StringResponse||xml|new"), $ListBuild("HL7", "EnsLib.HL7.Message|2.5:ADT_A01|document|EnsLib.HL7.Message|2.5:ADT_A01|document|copy"), $ListBuild("X12", "EnsLib.EDI.X12.Document||document|EnsLib.EDI.X12.Document||document|copy"), $ListBuild("EXISTING", "Ens.StringRequest||xml|Ens.StringResponse||xml|existing"), $ListBuild("EDIXML", "EnsLib.EDI.XML.Document||document|EnsLib.EDI.XML.Document||document|copy"))
    For tI = 1:1:$ListLength(tCases) {
        Set tClass = $Parameter(..#FIXTURE, $List($List(tCases, tI), 1))
        For tAction = "", "TRANSFORMTEST" {
            Kill tQuery
            Set tQuery("namespace") = ..#NAMESPACE
            Set tQuery("id") = tClass _ ".cls"
            Set tQuery("content") = $ClassMethod(..#FIXTURE, "Message", "x")
            If tAction '= "" Set tQuery("action") = tAction
            Set tSC = $ClassMethod(..#PORT, "Invoke", "Transforms", "TRANSFORM", .tQuery, "", .tRow, .tHttp, .tFault)
            Do $$$AssertEquals(+$Get(tHttp), 200, tClass _ " (" _ tAction _ "): the read answers 200")
            If '$IsObject($Get(tRow)) Continue
            Do $$$AssertEquals(tRow.SourceClass _ "|" _ tRow.SourceDocType _ "|" _ tRow.SourceKind _ "|" _ tRow.TargetClass _ "|" _ tRow.TargetDocType _ "|" _ tRow.TargetKind _ "|" _ tRow.Create, $List($List(tCases, tI), 2), tClass _ " (" _ tAction _ "): its classes, document types, kinds and create")
            Do $$$AssertEquals(tRow.Name _ "|" _ tRow.Namespace _ "|" _ tRow.content, tClass _ ".cls|" _ ..#NAMESPACE _ "|" _ tQuery("content"), tClass _ " (" _ tAction _ "): its name, namespace and the message as given")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "no read ran a transformation")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and none stored anything")
}

}
