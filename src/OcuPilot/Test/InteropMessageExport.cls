/// <p>Pins Story 24.16 Batch 3's message export end to end against probe messages stored in <code>USER</code> (AD-6, AD-13, AD-15, AD-21, AD-22, AD-39, AD-51, AD-53, AD-62): the person's
/// export, reviewed and sent for each of the six separators and for <code>UTF8</code>, <code>CP1252</code> and <code>UnicodeLittle</code>, answers a file whose bytes equal the classic Export dialog's for an HL7 message
/// and an XML-adaptor body; a character stream is its text as Contents shows it and a binary stream is left out with its verdict line; the agent's export, confirmed over HTTP at its shipped
/// key, answers the same bytes with no body text in OcuPilot's stored state; a message whose render fails is recorded and the rest are exported, and a set every render of which fails sends
/// no file; each body exported records the vendor's one view row and no file is left on the instance.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled
/// <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it stores probe messages in <code>USER</code> and <code>HSCUSTOM</code>
/// (<class>OcuPilot.Test.InteropMessageExportCase</class>). No production is started. One class per run.</p>
Class OcuPilot.Test.InteropMessageExport Extends OcuPilot.Test.InteropMessageExportCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Store a probe message of <var>pKind</var> in <code>USER</code> and answer its id; <var>pSuffix</var> tells probes apart.</p>
Method Store(pKind As %String, pSuffix As %String, pText As %String = "") As %Integer
{
    Set tId = $ClassMethod(..#EXPORTFIXTURE, "Store", ..#NAMESPACE, pKind, pSuffix, pText)
    Do $$$AssertTrue(tId > 0, "the probe " _ pKind _ " message " _ pSuffix _ " is stored")
    Quit tId
}

/// <p>The line a probe message of suffix <var>pSuffix</var> reads in the review: its id, source and target, then the sentence of <var>pVerdict</var>.</p>
ClassMethod LineOf(pId As %String, pVerdict As %String, pSuffix As %String) As %String
{
    Quit ..Line(pId, pVerdict, $Parameter(..#EXPORTFIXTURE, "MARKER") _ "Src" _ pSuffix, $Parameter(..#EXPORTFIXTURE, "MARKER") _ "Op" _ pSuffix)
}

/// <p>The text of the probe message <var>pId</var> as Contents shows it, lines joined by a line feed: the Messages contents read.</p>
ClassMethod ContentsText(pId As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("message") = pId
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "MessageContents", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If (+$Get(tHttp) '= 200) || '$IsObject(tRows) Quit "<unread>"
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tRow.Text
    }
    Quit tText
}

/// <p>AC1: the person reviews and exports an HL7 message and an XML-adaptor body with each of the six separators and with <code>UTF8</code>, <code>CP1252</code> and <code>UnicodeLittle</code>, and each file's bytes
/// equal the classic export's for the same two messages; the answer's lines name both messages exported, each export leaves one view row for each body, and the instance's temporary directory
/// holds nothing more than before.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ExportSeparatorChars</method> answers <code>LF</code> for <code>MLLP</code> -- the MLLP legs go red, alone; <method>OcuPilot.Port.InteropPort.ExportByteOrderMark</method> answers
/// <code>""</code> -- the <code>UnicodeLittle</code> legs go red, alone.</p>
Method TestThePersonsExportEqualsTheClassicBytesForEachSeparatorAndCharacterSet()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tXml = ..Store("xml", "b")
    Set tSet = tHl7 _ "," _ tXml
    Set tBefore = ..TempListing()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tExports = 0
    For tSeparator = "CRLF", "CR", "LF", "MLLP", "Tab", "None" {
        For tCharset = "UTF8", "CP1252", "UnicodeLittle" {
            Set tCode = ..ExportThrough(tSet, .tAnswer, tSeparator, tCharset, .tDry)
            Do $$$AssertEquals(tCode, "200 ", tSeparator _ "/" _ tCharset _ ": the review and the action are admitted: " _ $Select($IsObject($Get(tAnswer)): $Extract(tAnswer.%ToJSON(), 1, 200), 1: $Get(tAnswer)))
            Set tExports = tExports + 1
            Set tSaved(tExports) = ..BytesOf($Get(tAnswer))
            Set tSaved(tExports, "name") = tSeparator _ "/" _ tCharset
            Set tSaved(tExports, "separator") = tSeparator
            Set tSaved(tExports, "charset") = tCharset
        }
    }
    Do $$$AssertEquals(..OutcomeText($Get(tAnswer)), ..OutcomeLine("export", tHl7) _ $Char(10) _ ..OutcomeLine("export", tXml), "the answer names both messages exported")
    Do $$$AssertEquals(..Views(tSince, tHl7, .tDescription) _ "|" _ ..Views(tSince, tXml), tExports _ "|" _ tExports, "one view row for each body for each export")
    Do $$$AssertEquals(tDescription, "OcuPilot", "recorded as OcuPilot's own view")
    ; The classic export is called after the views are counted: it records views of its own.
    For tI = 1:1:tExports {
        Set tExpected = ..Oracle(tSet, tSaved(tI, "charset"), tSaved(tI, "separator"))
        Do $$$AssertTrue((tExpected '= "<unread>") && (tSaved(tI) = tExpected), tSaved(tI, "name") _ ": the saved bytes equal the classic export's (" _ $Length(tSaved(tI)) _ " and " _ $Length(tExpected) _ " bytes)")
    }
    Do $$$AssertEquals(..TempListing(), tBefore, "no file or directory is left in the temporary directory")
}

/// <p>AC1: of an HL7 message, a character stream and a binary stream the review reads <code>will be exported</code> for the first two and <code>its body cannot be exported as text</code>
/// for the third, in id order; the export is the classic's bytes for the HL7 message, then the stream's text as Contents shows it, each followed by the separator, and the binary stream
/// is left out with its line and no view row.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.TextBodyHere</method> answers 1 for a binary stream -- the binary leg goes red, alone.</p>
Method TestACharacterStreamIsItsTextAsContentsShowsItAndABinaryStreamIsLeftOut()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tChars = ..Store("chars", "b")
    Set tBinary = ..Store("binary", "c")
    Set tSet = tHl7 _ "," _ tChars _ "," _ tBinary
    Set tContents = ..ContentsText(tChars)
    ; Reading the contents records a view of its own, which the count below must not take.
    Hang 0.1
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..ExportDry(tSet, .tDry, "LF", "UTF8")
    Do $$$AssertEquals(tCode, "200 ", "the review answers")
    Do $$$AssertEquals(..Lines(tDry), ..LineOf(tHl7, "export", "a") _ $Char(10) _ ..LineOf(tChars, "export", "b") _ $Char(10) _ ..LineOf(tBinary, "notext", "c"), "each message reads its own verdict, in id order")
    Set tCode = ..ExportSend(tSet, ..Digest(tDry), .tAnswer, "LF", "UTF8")
    Do $$$AssertEquals(tCode, "200 ", "the export is admitted")
    Do $$$AssertEquals(..OutcomeText($Get(tAnswer)), ..OutcomeLine("export", tHl7) _ $Char(10) _ ..OutcomeLine("export", tChars), "the lines name the two exported and not the binary stream")
    Do $$$AssertEquals(..Views(tSince, tHl7) _ "|" _ ..Views(tSince, tChars) _ "|" _ ..Views(tSince, tBinary), "1|1|0", "one view row for each body exported and none for the one left out")
    Set tExpected = ..Oracle(tHl7, "UTF8", "LF") _ $ZConvert(tContents, "O", "UTF8") _ $Char(10)
    Do $$$AssertTrue(..BytesOf($Get(tAnswer)) = tExpected, "the file is the HL7 message as the classic writes it, then the stream's text, each followed by a line feed (" _ $Length(..BytesOf($Get(tAnswer))) _ " and " _ $Length(tExpected) _ " bytes)")
}

/// <p>AC2: the agent's export mints a proposal whose card lists each message's verdict, confirms over HTTP at the key it ships, and the confirming browser's answer carries the same bytes
/// the classic export writes with the chosen separator and character set; OcuPilot's own audit holds no row for it, the ledger holds one row, and no body text is in any global of its stored
/// state.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropMessageExport.PortQuery</method> leaves the character set out -- the bytes leg goes red; the confirm also
/// keeps its <code>output</code> in a global of OcuPilot's stored state -- the file leg goes red.</p>
Method TestTheAgentsExportConfirmsOverHttpAndKeepsNoBodyTextInItsState()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tXml = ..Store("xml", "b")
    Set tSet = tHl7 _ "," _ tXml
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tSet), "Separator": "LF", "Charset": "CP1252"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the export mints at its shipped key: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.MESSAGE.EXPORT|0", "its consequence is the export's, and it is not destructive")
    Set tCard = tProposal.changed.%ToJSON()
    Do $$$AssertTrue((tCard [ tHl7) && (tCard [ tXml) && (tCard [ ##class(OcuPilot.Api.InteropError).VerdictSentence("export")), "its card lists each message and its verdict: " _ tCard)
    Do $$$AssertEquals(..StateHolding($Parameter(..#EXPORTFIXTURE, "SENTINEL")), "none", "no body text is in the proposal after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the export confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..OutcomeText($Get(tAnswer)), ..OutcomeLine("export", tHl7) _ $Char(10) _ ..OutcomeLine("export", tXml), "its card output names each message")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#EXPORTKEY), 1, "the confirmed write is in the ledger once")
    Do $$$AssertEquals(..Views(tSince, tHl7) _ "|" _ ..Views(tSince, tXml), "1|1", "one view row for each body")
    Do $$$AssertEquals(..OwnRows(tSince, "export", .tOwn), 0, "OcuPilot's own audit holds no row for an export: an export changes nothing")
    Do $$$AssertTrue(..BytesOf($Get(tAnswer)) = ..Oracle(tSet, "CP1252", "LF"), "the confirming browser's file equals the classic export's bytes")
    Do $$$AssertEquals(..StateHolding($Parameter(..#EXPORTFIXTURE, "SENTINEL")), "none", "no body text is in OcuPilot's stored state after the confirm")
    Set tFile = $Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("output")): tAnswer.output.%Get("file"), 1: "")
    Do $$$AssertTrue($Length(tFile) > 100, "the answer carries the file: " _ $Length(tFile) _ " characters")
    Do $$$AssertEquals(..StateHolding($Extract(tFile, 1, 100)), "none", "nor is the file, as the answer carries it, in OcuPilot's stored state")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC4: a message whose render fails is recorded not exported with the vendor's text and the rest are exported, in id order; the file holds the two exported, the status line's counts say
/// so, the failure reaches the log as one line carrying no vendor text and written in the install namespace, and a view row is recorded for the two exported alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.PerformExport</method> counts a failed render as exported -- the counts leg goes red.</p>
Method TestAMessageWhoseRenderFailsIsRecordedAndTheRestAreExported()
{
    Set tA = ..Store("hl7", "a")
    Set tB = ..Store("xml", "b")
    Set tC = ..Store("chars", "c")
    Set tSet = tA _ "," _ tB _ "," _ tC
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailRenderOf", tB)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..XPort("EXPORTMESSAGES", tSet, .tResult, , "LF", "UTF8", , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode, "200 ", "the write answers 200: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.Exported _ "|" _ tResult.Failed _ "|" _ tResult.Messages.%Size(), "2|1|3", "two exported, one failed, an entry for each")
    Do $$$AssertEquals(tResult.Messages.%Get(1).ID _ "|" _ (tResult.Messages.%Get(1).Error [ $Parameter(..#SEAM, "MARKER")), tB _ "|1", "the second carries the vendor's text in the answer")
    Set tOutput = $ClassMethod(..#EXPORTTOOL, "WriteOutput", tResult)
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.lines.%Get(0) _ $Char(10) _ tOutput.lines.%Get(1) _ $Char(10) _ tOutput.lines.%Get(2), 1: ""), ..OutcomeLine("export", tA) _ $Char(10) _ ..OutcomeLine("export", tB, 0) _ ": " _ tResult.Messages.%Get(1).Error _ $Char(10) _ ..OutcomeLine("export", tC), "the outcome names the two exported and the one not exported with its text")
    Do $$$AssertEquals(..Views(tSince, tA) _ "|" _ ..Views(tSince, tB) _ "|" _ ..Views(tSince, tC), "1|0|1", "a view row for each exported body and none for the one that failed")
    Set tExpected = ..Oracle(tA, "UTF8", "LF") _ $ZConvert($ClassMethod(..#EXPORTFIXTURE, "CharText"), "O", "UTF8") _ $Char(10)
    Do $$$AssertTrue(..BytesOf(tResult) = tExpected, "the file holds the two exported, in id order")
    Do $$$AssertTrue($IsObject(tOutput) && (tOutput.%GetTypeOf("file") = "string"), "and the output carries it")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 1, "the failure was logged once")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#SEAM, "MARKER"), "the line carries no text of the vendor's: " _ $ClassMethod(..#SEAM, "LoggedText"))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "LoggedIn"), "HSCUSTOM", "and it was written in the install namespace, not the message's")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "RenderedIn"), "USER,USER,USER", "the three renders ran in the messages' namespace")
}

/// <p>AC4: when every render fails the answer is 200 with none exported, each id named with the vendor's text, no file in the answer or the output, and no view row.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.PerformExport</method> answers the empty bytes as a file -- the no-file leg goes red.</p>
Method TestASetEveryRenderOfWhichFailsSendsNoFile()
{
    Set tA = ..Store("hl7", "a")
    Set tB = ..Store("xml", "b")
    Set tSet = tA _ "," _ tB
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailRenderOf", tSet)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..XPort("EXPORTMESSAGES", tSet, .tResult, , "LF", "UTF8", , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode, "200 ", "the write answers 200")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.Exported _ "|" _ tResult.Failed _ "|" _ tResult.Messages.%Size() _ "|" _ tResult.File, "0|2|2|", "none exported, both failed, no file")
    Do $$$AssertEquals(tResult.Messages.%Get(0).ID _ "," _ tResult.Messages.%Get(1).ID, tSet, "both ids are named")
    Set tOutput = $ClassMethod(..#EXPORTTOOL, "WriteOutput", tResult)
    Do $$$AssertTrue($IsObject(tOutput) && (tOutput.%GetTypeOf("file") = "unassigned") && (tOutput.lines.%Size() = 2), "the output has a line for each and no file")
    Do $$$AssertEquals(..Views(tSince, tA) _ "|" _ ..Views(tSince, tB), "0|0", "no body was recorded as viewed")
}

/// <p>AC1: the two lists the dialog offers are the classic's: the six separators, and the character sets the instance lists with <code>UTF8</code> preselected, answered by the port's own read
/// and by the review's <code>review</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ExportCharsets</method> answers a fixed list -- the instance leg goes red.</p>
Method TestTheListsAreTheInstancesOwnAndTheReviewCarriesThem()
{
    Set tCode = ..XPort("EXPORTCHOICES", "", .tChoices, , , , , .tFault)
    Do $$$AssertEquals(tCode, "200 ", "the choices read answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tChoices)) Quit
    Set tNames = $$GetIONames^%SYS.NLS(.tDefaults, 1)
    Set tCharsets = ""
    Set tIterator = tChoices.Charsets.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tCharsets = tCharsets _ $Select(tCharsets = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tCharsets, tNames, "the character sets are the ones the instance lists")
    Do $$$AssertEquals(tChoices.Separators.%Size() _ "|" _ tChoices.Separators.%Get(0) _ "|" _ tChoices.DefaultSeparator _ "|" _ tChoices.DefaultCharset, "6|CRLF|CRLF|UTF8", "the six separators, CRLF and UTF8 preselected")
    Do $$$AssertTrue($ListFind($ListFromString(tNames), "CP1252") > 0, "CP1252 is among them")
    Set tHl7 = ..Store("hl7", "a")
    Set tCode = ..ExportDry(tHl7, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "a review with no choices answers")
    If $IsObject($Get(tDry)) && $IsObject(tDry.%Get("review")) {
        Do $$$AssertEquals(tDry.review.Separator _ "|" _ tDry.review.Charset _ "|" _ tDry.review.Separators.%Size() _ "|" _ (tDry.review.Charsets.%Size() = $Length(tNames, ",")), "CRLF|UTF8|6|1", "and carries the defaults and both lists")
    }
}

}
