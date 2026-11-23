/// <p>Pins what Story 24.16 Batch 3's message export refuses, and what it leaves alone while it does (AD-8, AD-13, AD-21, AD-29, AD-51, AD-53, AD-62): the verdict each message reads, first
/// rule winning, so only a message with a body that can be written as text is exported, each line naming its verdict; a set none of which can be exported (409
/// <code>INTEROP.EXPORT.NONE</code>) and a review the messages moved past (409 <code>INTEROP.EXPORT.CHANGED</code>), each with nothing rendered and no view recorded; a file exactly at the
/// size cap, which is exported, and one byte over it and a set whose bodies pass it, which are refused whole (409 <code>INTEROP.EXPORT.TOOLARGE</code>) before any view is recorded; a render
/// that throws, which is 500 and logs nothing while the message's namespace is switched; a set of 101 ids, a separator and a character set outside their lists; each missing pair, refused 403
/// naming it before any render, and READ alone on the database admitting an export; and the script form, which shape-checks every value and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropMessageExportCase</class> needs: OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. The gate legs run through the fake gate
/// (<class>OcuPilot.Test.ScreenGate</class>). No production is started. One class per run.</p>
Class OcuPilot.Test.InteropMessageExportRefusals Extends OcuPilot.Test.InteropMessageExportCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The file's cap in bytes, and the most characters a body of one byte each may hold at it.</p>
Parameter CAP = 2250000;

/// <p>Store a probe message of <var>pKind</var> in <code>USER</code> and answer its id; <var>pSuffix</var> tells probes apart.</p>
Method Store(pKind As %String, pSuffix As %String, pText As %String = "") As %Integer
{
    Set tId = $ClassMethod(..#EXPORTFIXTURE, "Store", ..#NAMESPACE, pKind, pSuffix, pText)
    Do $$$AssertTrue(tId > 0, "the probe " _ pKind _ " message " _ pSuffix _ " is stored")
    Quit tId
}

/// <p>The line a probe message of suffix <var>pSuffix</var> reads in the review.</p>
ClassMethod LineOf(pId As %String, pVerdict As %String, pSuffix As %String) As %String
{
    Quit ..Line(pId, pVerdict, $Parameter(..#EXPORTFIXTURE, "MARKER") _ "Src" _ pSuffix, $Parameter(..#EXPORTFIXTURE, "MARKER") _ "Op" _ pSuffix)
}

/// <p>A text of <var>pLength</var> characters, each one byte in <code>UTF8</code>.</p>
ClassMethod Filler(pLength As %Integer) As %String
{
    Quit $Translate($Justify("", pLength), " ", "x")
}

/// <p>AC3: of an HL7 message, one whose body was deleted, a binary stream and an id no header holds, the review reads <code>will be exported</code>, <code>its body no longer exists</code>,
/// <code>its body cannot be exported as text</code> and <code>no longer exists</code>, in id order, and the export sends the first alone and records its view alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.MessageVerdict</method> reads <code>notext</code> before <code>nobody</code> -- the second line goes red.</p>
Method TestEachMessageIsJudgedAndOnlyThoseWithATextBodyAreExported()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tNoBody = ..Store("xml", "b")
    Do $$$AssertTrue($ClassMethod(..#EXPORTFIXTURE, "DeleteBody", ..#NAMESPACE, tNoBody), "the second message's body is deleted")
    Set tBinary = ..Store("binary", "c")
    Set tSet = tHl7 _ "," _ tNoBody _ "," _ tBinary _ "," _ ..#GONE
    Set tCode = ..ExportDry(tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the review answers")
    Do $$$AssertEquals(..Lines(tDry), ..LineOf(tHl7, "export", "a") _ $Char(10) _ ..LineOf(tNoBody, "nobody", "b") _ $Char(10) _ ..LineOf(tBinary, "notext", "c") _ $Char(10) _ ..Line(..#GONE, "gone"), "each message reads its own verdict, in id order")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..ExportSend(tSet, ..Digest(tDry), .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the export is admitted: " _ $Select($IsObject($Get(tSent)): $Extract(tSent.%ToJSON(), 1, 200), 1: $Get(tSent)))
    Do $$$AssertEquals(..OutcomeText($Get(tSent)), ..OutcomeLine("export", tHl7), "one line, for the message that could go")
    Do $$$AssertEquals(..Views(tSince, tHl7) _ "|" _ ..Views(tSince, tNoBody) _ "|" _ ..Views(tSince, tBinary), "1|0|0", "one view row, for the message exported")
}

/// <p>AC3: a set none of whose messages can be exported is refused 409 <code>INTEROP.EXPORT.NONE</code> by the port, and by the person's review and the agent's mint as the sentence and the lines,
/// with nothing rendered, no view recorded and no file.</p>
/// <p>Mutation (Rule 19): drop the <code>Eligible</code> test in <method>OcuPilot.Port.InteropPort.PerformExport</method> -- the port leg answers 200 and goes red.</p>
Method TestASetNoneOfWhichCanBeExportedIsRefusedBeforeAnythingIsRendered()
{
    Set tBinary = ..Store("binary", "a")
    Set tSet = tBinary _ "," _ ..#GONE
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..XPort("EXPORTMESSAGES", tSet, , , "LF", "UTF8", , , ..#NAMESPACE, ..#SEAM), "409 INTEROP.EXPORT.NONE", "the port refuses the write")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "RenderedIn"), "", "nothing was rendered")
    Set tCode = ..ExportDry(tSet, .tDry)
    Do $$$AssertEquals(tCode, "400 TOOL.ARGUMENTS", "the review of a set that can export nothing is refused")
    Do $$$AssertTrue($IsObject(tDry) && $IsObject(tDry.%Get("detail")) && (tDry.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONEXPORTNONE) && (tDry.detail.%Get("problem") [ ..LineOf(tBinary, "notext", "a")), "with the sentence and the line")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tSet)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) >= 400) && '$IsObject($Get(tProposal)), "the agent's mint is refused and writes no proposal")
    Do $$$AssertEquals(..Views(tSince, tBinary), 0, "no view was recorded")
}

/// <p>AC3: a review the messages moved past -- a body deleted after the person reviewed -- is refused 409 <code>INTEROP.EXPORT.CHANGED</code> with nothing exported and no view recorded; the agent's
/// proposal is closed as a moved target on the confirm, 409 <code>PROPOSAL.TARGETCHANGED</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>pReviewed</code> comparison in <method>OcuPilot.Port.InteropPort.ReadResend</method> -- the first leg exports and goes red; leave <code>Verdicts</code> out of
/// <parameter>OcuPilot.Screen.Tool.InteropMessageExport.FINGERPRINTSUBJECT</parameter> -- the agent's leg goes red.</p>
Method TestAReviewThatMovedIsRefusedAndNothingIsExported()
{
    Set tA = ..Store("hl7", "a")
    Set tB = ..Store("xml", "b")
    Set tSet = tA _ "," _ tB
    Set tCode = ..ExportDry(tSet, .tDry)
    Set tDigest = ..Digest(tDry)
    Do $$$AssertTrue($ClassMethod(..#EXPORTFIXTURE, "DeleteBody", ..#NAMESPACE, tB), "the second message's body is deleted after the review")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..ExportSend(tSet, tDigest, .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.EXPORT.CHANGED", "the digest of the earlier review is refused: " _ $Select($IsObject($Get(tRefused)): tRefused.%ToJSON(), 1: $Get(tRefused)))
    Do $$$AssertEquals(..BytesOf($Get(tRefused)) _ "|" _ ..Views(tSince, tA), "<none>|0", "nothing was exported and no view was recorded")
    Set tC = ..Store("hl7", "c")
    Set tD = ..Store("xml", "d")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tC _ "," _ tD)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's export mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertTrue($ClassMethod(..#EXPORTFIXTURE, "DeleteBody", ..#NAMESPACE, tD), "the second message's body is deleted after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Views(tSince, tC), 0, "and nothing was recorded as viewed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: a file of exactly <parameter>CAP</parameter> bytes is exported, through the port and over HTTP as the person's, and one byte more is refused 409 <code>INTEROP.EXPORT.TOOLARGE</code> before
/// any view is recorded and with no bytes in the answer; so is a set whose bodies together pass it. The instance's temporary directory holds nothing more than before.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ExportMemberHere</method> compares the bytes with <code>&gt;=</code> the cap -- the at-the-cap leg goes red; the comparison is
/// <code>&gt;</code> the cap plus one in both <method>ExportMemberHere</method> and <method>PerformExport</method> (either alone is covered by the other) -- the one-over leg goes red.</p>
Method TestAFileAtTheCapIsExportedAndOneByteOverItIsRefusedBeforeAnyViewIsRecorded()
{
    Set tBefore = ..TempListing()
    Do $$$AssertEquals($Parameter(..#PORT, "EXPORTMAXBYTES") _ "|" _ ((##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS \ 4) * 3), ..#CAP _ "|" _ ..#CAP, "the cap is three quarters of the characters an answer carries, and this test's own")
    Set tAt = ..Store("chars", "a", ..Filler(..#CAP))
    Set tOver = ..Store("chars", "b", ..Filler(..#CAP + 1))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..XPort("EXPORTMESSAGES", tAt, .tResult, , "None", "UTF8", , .tFault)
    Do $$$AssertEquals(tCode, "200 ", "a file of exactly the cap is exported: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tResult)) Do $$$AssertEquals($Length(tResult.File) _ "|" _ $Length(..BytesOf(tResult)), "3000000|" _ ..#CAP, "its bytes travel as the largest string the answer carries")
    Do $$$AssertEquals(..Views(tSince, tAt), 1, "its view was recorded")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..XPort("EXPORTMESSAGES", tOver, .tResult, , "None", "UTF8", , .tFault)
    Do $$$AssertEquals(tCode, "409 INTEROP.EXPORT.TOOLARGE", "one byte more is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): "answered", 1: "nothing") _ "|" _ ..Views(tSince, tOver), "nothing|0", "no bytes leave and no view is recorded")
    Set tThree = ..Store("chars", "c", ..Filler(800000)) _ "," _ ..Store("chars", "d", ..Filler(800000)) _ "," _ ..Store("chars", "e", ..Filler(800000))
    Do $$$AssertEquals(..XPort("EXPORTMESSAGES", tThree, .tResult, , "LF", "UTF8"), "409 INTEROP.EXPORT.TOOLARGE", "a set whose bodies together pass the cap is refused")
    Set tCode = ..ExportThrough(tAt, .tAnswer, "None", "UTF8", .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the person's export of the file at the cap is admitted over HTTP")
    Do $$$AssertEquals($Length(..BytesOf($Get(tAnswer))), ..#CAP, "and the browser receives every byte")
    Set tCode = ..ExportDry(tOver, .tDryOver)
    Set tCode = ..ExportSend(tOver, ..Digest(tDryOver), .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.EXPORT.TOOLARGE", "the person's export of the file one byte over is refused")
    Do $$$AssertEquals(..TempListing(), tBefore, "no file or directory is left in the temporary directory")
}

/// <p>AC3: a render that throws is 500, with no bytes, no view recorded and no file or directory left; the fault is logged once, after the namespace is restored, in the install namespace.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.PerformExport</method> audits each body before the next is rendered -- the view leg goes red.</p>
Method TestARenderThatThrowsIsAnInternalFaultThatLeavesNothing()
{
    Set tA = ..Store("hl7", "a")
    Set tB = ..Store("xml", "b")
    Set tSet = tA _ "," _ tB
    Set tBefore = ..TempListing()
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "ThrowRenderOf", tB)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..XPort("EXPORTMESSAGES", tSet, .tResult, , "LF", "UTF8", , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals($Piece(tCode, " ", 1), "500", "the write is an internal fault: " _ tCode)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): "answered", 1: "nothing") _ "|" _ ..Views(tSince, tA) _ "|" _ ..Views(tSince, tB), "nothing|0|0", "no bytes leave and no view is recorded, not even for the message rendered before it")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 1, "the fault was logged once")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "LoggedIn"), "HSCUSTOM", "in the install namespace, after the message's was restored")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#EXPORTFIXTURE, "SENTINEL"), "and carries no body text")
    Do $$$AssertEquals(..TempListing(), tBefore, "no file or directory is left in the temporary directory")
}

/// <p>AC3: a set of 100 ids is read, 101 is refused whole 400 <code>PORT.VALIDATION</code> by the port, the review, the action and the agent's mint, and so are an empty set and a member that is not a message
/// id; nothing is rendered.</p>
/// <p>Mutation (Rule 19): raise <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> to 101 -- the cap legs go red.</p>
Method TestASetOverTheCapOrMalformedIsRefusedWhole()
{
    Set tHundred = ""
    Set tMore = ""
    For tI = 1:1:101 {
        Set tId = 900000000 + tI
        If tI <= 100 Set tHundred = tHundred _ $Select(tHundred = "": "", 1: ",") _ tId
        Set tMore = tMore _ $Select(tMore = "": "", 1: ",") _ tId
    }
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $$$AssertEquals(..XPort("EXPORT", tHundred, .tRead, , , , , , ..#NAMESPACE, ..#SEAM), "200 ", "a set of 100 ids is read")
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.Messages.%Size() _ "|" _ tRead.Eligible, 1: ""), "100|0", "each answers a verdict and none can go")
    For tType = "EXPORT", "EXPORTMESSAGES" {
        Do $$$AssertEquals(..XPort(tType, tMore, , , , , , .tFault, ..#NAMESPACE, ..#SEAM), "400 PORT.VALIDATION", tType _ ": 101 ids are refused whole")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() [ "Messages must name 1 to 100 message header IDs"), tType _ ": naming Messages and the cap")
    }
    Do $$$AssertEquals(..ExportDry(tMore) _ "|" _ ..ExportSend(tMore, "0"), "400 PORT.VALIDATION|400 PORT.VALIDATION", "the review and the action refuse it")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tMore)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) = 400) && '$IsObject($Get(tProposal)), "the agent's mint refuses it")
    For tBad = "", "0x1", "007", "12,,13", "abc", "1.5" {
        Do $$$AssertEquals(..XPort("EXPORTMESSAGES", tBad, , , , , , , ..#NAMESPACE, ..#SEAM), "400 PORT.VALIDATION", "'" _ tBad _ "' is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "RenderedIn"), "", "nothing was rendered")
}

/// <p>AC3: a separator or a character set outside its list is refused with nothing rendered: 400 <code>PORT.VALIDATION</code> naming it by the port, 400 <code>TOOL.ARGUMENTS</code> by the person's
/// review and action, and a refused mint for the agent.</p>
/// <p>Mutation (Rule 19): drop the character set test in <method>OcuPilot.Port.InteropPort.ReadExport</method> -- the <code>Klingon</code> legs go red.</p>
Method TestASeparatorOrCharacterSetOutsideItsListIsRefusedBeforeAnythingIsRendered()
{
    Set tHl7 = ..Store("hl7", "a")
    Do ..HoldForExport()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tCase = $ListBuild("separator", "FF", "UTF8"), $ListBuild("charset", "LF", "Klingon") {
        Set tName = $List(tCase, 1)
        Set tSeparator = $List(tCase, 2)
        Set tCharset = $List(tCase, 3)
        Do $$$AssertEquals(..XPort("EXPORTMESSAGES", tHl7, , , tSeparator, tCharset, , .tFault, ..#NAMESPACE, ..#SEAM), "400 PORT.VALIDATION", tName _ ": the port refuses the write")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() [ tName), tName _ ": naming it")
        Do $$$AssertEquals(..ExportDry(tHl7, .tDry, tSeparator, tCharset), "400 TOOL.ARGUMENTS", tName _ ": the review is refused")
        Do $$$AssertTrue($IsObject(tDry) && $IsObject(tDry.%Get("detail")) && (tDry.detail.%Get("problem") [ $Select(tName = "separator": "'Separator'", 1: "'Charset'")), tName _ ": naming the argument")
        Do $$$AssertEquals(..ExportSend(tHl7, "0", , tSeparator, tCharset), "400 TOOL.ARGUMENTS", tName _ ": and so is the action")
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tHl7), "Separator": (tSeparator), "Charset": (tCharset)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) >= 400) && '$IsObject($Get(tProposal)), tName _ ": the agent's mint is refused and writes no proposal")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "RenderedIn"), "", "nothing was rendered")
}

/// <p>AC3: each pair an export needs -- the Interoperability menu's, the message viewer's, the export dialog's, the Contents pane's and READ on <code>USER</code>'s database -- is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming it when it alone is missing, by the port, before any render and any view; a caller holding exactly them, and no WRITE on the database, is admitted.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageContent:USE</code> from the export branch of <method>OcuPilot.Port.InteropPort.Pairs</method> -- the Contents leg goes red.</p>
Method TestEachMissingPairIsRefusedByNameBeforeAnyRender()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tPairs = "%Ens_Portal:USE,%Ens_MessageHeader:USE,%Ens_MessageExport:USE,%Ens_MessageContent:USE,%DB_USER:READ"
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tType = "EXPORT", "EXPORTMESSAGES", "EXPORTCHOICES" {
        For tMissing = 1:1:$Length(tPairs, ",") {
            Do ##class(OcuPilot.Test.ScreenGate).Reset()
            For tHeld = 1:1:$Length(tPairs, ",") {
                If tHeld '= tMissing Do ##class(OcuPilot.Test.ScreenGate).Hold($Piece($Piece(tPairs, ",", tHeld), ":", 1), $Piece($Piece(tPairs, ",", tHeld), ":", 2))
            }
            Set tCode = ..XPort(tType, $Select(tType = "EXPORTCHOICES": "", 1: tHl7), , , , , , .tFault, ..#NAMESPACE, ..#SEAM)
            Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tFault): tFault.detail.failedPair, 1: ""), "403 AUTH.NOPRIVILEGE|" _ $Piece(tPairs, ",", tMissing), tType _ ": without " _ $Piece(tPairs, ",", tMissing))
        }
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "RenderedIn") _ "|" _ ..Views(tSince, tHl7), "|0", "no refused call rendered or recorded anything")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ..HoldForExport()
    Do $$$AssertEquals(..XPort("EXPORTMESSAGES", tHl7, .tResult, , "LF", "UTF8", , .tFault, ..#NAMESPACE, ..#SEAM), "200 ", "the caller holding exactly the five, with READ and no WRITE, is admitted")
    Do $$$AssertEquals(..Views(tSince, tHl7), 1, "and its export recorded its view")
}

/// <p>AC3: the script form (AD-59) of an export renders the switch to the namespace, each exported message's body written with the separator and its view recorded, and the MLLP framing, and runs none of
/// it: no view is recorded by rendering it. A set with a bad id, a separator outside its list or a character set outside its list renders no draft; ids the review read as another verdict are left out.</p>
/// <p>Mutation (Rule 19): drop the character set test in <method>OcuPilot.Port.InteropPort.ExportSnippet</method> -- the bad character set renders a draft and this goes red.</p>
Method TestTheScriptFormRendersTheExportAndRunsNothingAndABadValueRendersNoDraft()
{
    Set tHl7 = ..Store("hl7", "a")
    Set tBinary = ..Store("binary", "b")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tHl7 _ "," _ tBinary
    Set tQuery("separator") = "MLLP"
    Set tQuery("charset") = "UTF8"
    Set tContext = {"payload": {"Verdicts": (tHl7 _ "=export," _ tBinary _ "=notext")}}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "EXPORTMESSAGES", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size(), 1, "an objectscript step is rendered")
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue((tText [ ("Set $NAMESPACE = """ _ ..#NAMESPACE _ """")) && (tText [ ("%OpenId(""" _ tHl7 _ """)")) && (tText [ "AuditViewMessage") && (tText [ " W $Char(11)") && (tText [ "$Char(13)"), "it switches, opens the exported message, records its view and frames it as MLLP: " _ tText)
    Do $$$AssertTrue(tText '[ ("%OpenId(""" _ tBinary _ """)"), "and leaves the message that cannot be exported out")
    Do $$$AssertEquals(..Views(tSince, tHl7), 0, "rendering it recorded no view")
    For tBad = $ListBuild("id", tHl7 _ ",abc"), $ListBuild("separator", "FF"), $ListBuild("charset", "Klingon") {
        Kill tBadQuery
        Merge tBadQuery = tQuery
        Set tBadQuery($Select($List(tBad, 1) = "id": "id", 1: $List(tBad, 1))) = $List(tBad, 2)
        Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "EXPORTMESSAGES", .tBadQuery, "", tContext).%Size(), 0, "a bad " _ $List(tBad, 1) _ " renders no draft")
    }
}

}
