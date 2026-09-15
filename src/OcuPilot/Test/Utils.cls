/// <p>The first executed test host for <class>OcuPilot.Kernel.Utils</class>' four harvested
/// methods (DW-23) and the pin on DW-24's fix.</p>
/// <p>Every method here runs in process and needs nothing from the environment: no web
/// application, no HTTP, no principal, no install state. <method>ReadRequestBody</method>'s
/// two branches are driven by putting <class>OcuPilot.Test.BodyRequest</class> in
/// <code>%request</code> inside a <code>New</code> frame, so no live CSP request is needed
/// and nothing outside the frame sees the substitution.</p>
/// <p>What is <b>not</b> closed here: none of these four methods has a production call site
/// yet. Story 1.6's token endpoints are handled by the CSP server before OcuPilot
/// dispatches, so no OcuPilot route reads a request body; the first route with a body is
/// Story 1.8's.</p>
Class OcuPilot.Test.Utils Extends %UnitTest.TestCase
{

/// <p>Build a string of <var>pCount</var> copies of <var>pChar</var> without a per-character
/// loop, so a million-byte fixture costs one <code>$Justify</code> and one
/// <code>$Translate</code>.</p>
ClassMethod Repeat(pChar As %String, pCount As %Integer) As %String
{
    If pCount <= 0 Quit ""
    Quit $Translate($Justify("", pCount), " ", pChar)
}

/// <p>DW-23 — the UTF-8 chunk-boundary carryover in
/// <method>OcuPilot.Kernel.Utils.DecodeUtf8Stream</method>, over a stream larger than
/// <parameter>OcuPilot.Kernel.Utils.UTF8CHUNKSIZE</parameter> whose three-byte sequence
/// straddles the boundary: two of its bytes fall in the first read, one in the second.</p>
/// <p>The straddle is <b>asserted, not assumed</b>. <code>Read(n)</code> is documented to be
/// allowed to return fewer than <var>n</var> bytes, so the fixture's first read and the tail
/// length the decoder computes from it are both checked before the decode is believed.</p>
/// <p>Mutation: delete the carry-back branch in <method>DecodeUtf8Stream</method> (decode
/// every chunk whole) -> the straddling sequence decodes to two replacement characters and
/// both the length and the code-point assertions go red.</p>
Method TestDecodeUtf8StreamCarriesASequenceAcrossTheChunkBoundary()
{
    Set tChunk = ##class(OcuPilot.Kernel.Utils).#UTF8CHUNKSIZE
    Set tFillerLen = tChunk - 2
    Set tRaw = ##class(%Stream.TmpBinary).%New()
    Set tRemaining = tFillerLen
    While tRemaining > 0 {
        Set tBlock = $Select(tRemaining > 20000: 20000, 1: tRemaining)
        Do tRaw.Write(..Repeat("a", tBlock))
        Set tRemaining = tRemaining - tBlock
    }
    ; U+20AC EURO SIGN, UTF-8 E2 82 AC. Its first two bytes are the last two of the
    ; first chunk; its third byte opens the second.
    Do tRaw.Write($Char(226) _ $Char(130) _ $Char(172))
    Do tRaw.Write("tail")
    Do $$$AssertEquals(tRaw.Size, tFillerLen + 7, "the fixture stream is larger than one chunk")

    Do tRaw.Rewind()
    Set tFirstRead = tRaw.Read(tChunk)
    Do $$$AssertEquals($Length(tFirstRead), tChunk, "one Read(UTF8CHUNKSIZE) consumes exactly the chunk, so the boundary falls inside the sequence")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Utils).IncompleteUtf8TailLength(tFirstRead), 2, "and two of the sequence's three bytes are held back as the carry")

    Do tRaw.Rewind()
    Set tOut = ##class(OcuPilot.Kernel.Utils).DecodeUtf8Stream(tRaw)
    Do tOut.Rewind()
    Set tText = ""
    While 'tOut.AtEnd {
        Set tText = tText _ tOut.Read(100000)
    }
    Do $$$AssertEquals($Length(tText), tFillerLen + 5, "the decoded text is the filler, one euro sign and the four-character tail")
    Do $$$AssertEquals($Ascii(tText, tFillerLen + 1), 8364, "the straddling sequence decoded to one U+20AC, not to replacement characters")
    Do $$$AssertEquals($Extract(tText, tFillerLen + 2, *), "tail", "and the bytes after the boundary are intact")
}

/// <p>DW-23 — the same carryover at every tail length
/// <method>OcuPilot.Kernel.Utils.IncompleteUtf8TailLength</method> can return, driven through
/// the method's own <var>pChunkSize</var> argument so the boundary lands where this test
/// says it does rather than where a stream implementation happens to put it.</p>
/// <p>Row 1 splits a two-byte sequence after its lead byte, row 2 a three-byte sequence
/// after two bytes, row 3 a four-byte astral sequence after one byte.</p>
Method TestDecodeUtf8StreamHandlesEveryTailLength()
{
    ; pChunkSize, raw bytes after the "ab" prefix, the character the sequence decodes to.
    Set tRows = $ListBuild($ListBuild(3, $Char(195) _ $Char(169), 233), $ListBuild(4, $Char(226) _ $Char(130) _ $Char(172), 8364), $ListBuild(3, $Char(240) _ $Char(159) _ $Char(152) _ $Char(138), 55357))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tSize = $List(tRow, 1)
        Set tBytes = $List(tRow, 2)
        Set tExpected = $List(tRow, 3)
        Set tRaw = ##class(%Stream.TmpBinary).%New()
        Do tRaw.Write("ab" _ tBytes _ "cd")
        Set tOut = ##class(OcuPilot.Kernel.Utils).DecodeUtf8Stream(tRaw, tSize)
        Do tOut.Rewind()
        Set tText = tOut.Read(1000)
        Do $$$AssertEquals($Extract(tText, 1, 2), "ab", "row " _ tI _ ": the prefix survives")
        Do $$$AssertEquals($Ascii(tText, 3), tExpected, "row " _ tI _ ": the sequence split across the boundary decoded to its own character")
        Do $$$AssertEquals($Extract(tText, *-1, *), "cd", "row " _ tI _ ": the suffix survives")
        ; Length is what catches a dropped code unit. Row 3's astral character occupies two
        ; of them, so asserting only the first would stay green with the low half lost.
        Set tUnits = $Select(tI = 3: 6, 1: 5)
        Do $$$AssertEquals($Length(tText), tUnits, "row " _ tI _ ": nothing was dropped or duplicated")
        If tI = 3 {
            Do $$$AssertEquals($Ascii(tText, 4), 56842, "row 3: the low surrogate survives alongside the high one")
        }
    }
}

/// <p>DW-23 — <method>OcuPilot.Kernel.Utils.ApplyOutputCeiling</method> cutting exactly
/// where a surrogate pair would otherwise be split.</p>
/// <p>The arithmetic is fixed, which is what makes the assertion exact: at a ceiling of 100
/// the elision marker is 39 characters, so the cut length is 61 — and code unit 61 of the
/// fixture is the high half of a surrogate pair.
/// <method>OcuPilot.Kernel.Utils.SurrogateSafeCutLength</method> must back that off to 60,
/// leaving a 99-character result whose retained text ends on the ASCII character before the
/// pair.</p>
/// <p>Mutation: drop the <method>SurrogateSafeCutLength</method> call from
/// <method>ApplyOutputCeiling</method>'s marker branch -> the result is 100 characters and
/// its 61st code unit is a stranded high surrogate, so both assertions go red.</p>
Method TestApplyOutputCeilingNeverCutsASurrogatePair()
{
    Set tStr = ..Repeat("a", 60) _ $Char(55357) _ $Char(56842) _ ..Repeat("b", 60)
    Do $$$AssertEquals($Ascii(tStr, 61), 55357, "the fixture puts a high surrogate exactly at the cut length")

    Set tTruncated = 0
    Set tResult = ##class(OcuPilot.Kernel.Utils).ApplyOutputCeiling(tStr, .tTruncated, 100)

    Do $$$AssertTrue(tTruncated, "the ceiling truncated")
    Do $$$AssertEquals($Length(tResult), 99, "the cut backed off one code unit rather than landing between the surrogate halves")
    Do $$$AssertEquals($Extract(tResult, 60), "a", "the last retained character is the ASCII one before the pair")
    Do $$$AssertEquals($Ascii(tResult, 61), 10, "and the elision marker begins immediately after it")
    ; Nowhere in the result, not merely at the cut: a lone high (D800-DBFF) or low
    ; (DC00-DFFF) surrogate anywhere would mean the truncation split a pair.
    Set tStranded = 0
    For tI = 1:1:$Length(tResult) {
        Set tCode = $Ascii(tResult, tI)
        If (tCode >= 55296) && (tCode <= 57343) Set tStranded = tStranded + 1
    }
    Do $$$AssertEquals(tStranded, 0, "no surrogate half survives anywhere in the truncated result")
}

/// <p>DW-23 — <method>OcuPilot.Kernel.Utils.SanitizeError</method>'s bracket-depth scan,
/// over a routine reference whose argument list carries a <b>nested</b> paren.</p>
/// <p>A scan that stopped at the first <code>)</code> would leave <code>,c)</code> behind;
/// the depth scan consumes the whole list, so the sanitized text reads exactly
/// <code>Boom &lt;UNDEFINED&gt;Run tail</code> — the <code>ERROR #nnnn:</code> prefix removed
/// by the same method's last step, the offset and the routine reference removed by the
/// scan.</p>
/// <p>Mutation: replace the depth loop with a scan to the first <code>)</code> ->
/// the result reads <code>Boom &lt;UNDEFINED&gt;Run,c) tail</code> and this goes red.</p>
Method TestSanitizeErrorRemovesANestedParenRoutineReference()
{
    Set tStatus = $$$ERROR($$$GeneralError, "Boom <UNDEFINED>Run+12^MyPkgCls1(a(b),c) tail")
    Set tSafe = ##class(OcuPilot.Kernel.Utils).SanitizeError(tStatus)

    Do $$$AssertStatusNotOK(tSafe, "a sanitized error is still an error")
    Set tText = $System.Status.GetErrorText(tSafe)
    Do $$$AssertTrue(tText [ "Boom <UNDEFINED>Run tail", "the whole nested argument list and the routine reference are gone: " _ tText)
    Do $$$AssertEquals((tText [ "^MyPkgCls1"), 0, "the routine reference itself is gone")
    Do $$$AssertEquals((tText [ ",c)"), 0, "and so is the tail a first-close-paren scan would have left behind")
}

/// <p>DW-23 — <method>SanitizeError</method> leaves a status that is already OK alone.</p>
Method TestSanitizeErrorPassesAnOkStatusThrough()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Utils).SanitizeError($$$OK), "an OK status is returned unchanged")
}

/// <p>DW-24 — a body read that <b>faults</b> returns an error status naming the read stage,
/// where it used to return <code>$$$OK</code> with an empty body.</p>
/// <p>The fixture makes <code>%request.GetMimeData("BODY")</code> yield nothing and
/// <code>%request.Content</code> throw, which is exactly the shape whose inner
/// <code>Catch</code> used to swallow the exception.</p>
/// <p>Mutation: wrap the <code>%request.Content</code> read in
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> in a <code>Catch</code> that sets
/// the stream empty (the pre-fix code) -> this goes red on the status assertion, and
/// <method>TestReadRequestBodyTreatsAnAbsentBodyAsOk</method> stays green, which is the pair
/// that shows the two cases are genuinely separated.</p>
Method TestReadRequestBodyReportsAReadFaultInsteadOfAnEmptyBody()
{
    New %request
    Set %request = ##class(OcuPilot.Test.BodyRequest).%New()
    Set %request.FaultOnContent = 1

    Set tSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)

    Do $$$AssertStatusNotOK(tSC, "a read fault is reported, not swallowed as an empty body")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "read stage", "and the status names the stage that faulted: " _ tText)
    Do $$$AssertEquals($IsObject($Get(tBody)), 0, "no body is handed back")
}

/// <p>DW-24's other half — a request that genuinely carries no body is <b>not</b> an error:
/// <code>$$$OK</code> with an empty <var>pBody</var>. Neither source yields a stream and
/// neither throws.</p>
Method TestReadRequestBodyTreatsAnAbsentBodyAsOk()
{
    New %request
    Set %request = ##class(OcuPilot.Test.BodyRequest).%New()

    Set tSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)

    Do $$$AssertStatusOK(tSC, "an absent body is a legitimate request shape")
    Do $$$AssertEquals($Get(tBody), "", "and yields an empty body")
}

/// <p>DW-24's positive control — a real UTF-8 JSON body arriving through the MIME branch is
/// decoded and parsed, so the two branches above are read against a method that does work
/// when there is something to read. The non-ASCII value also exercises
/// <method>DecodeUtf8Stream</method> on the ordinary single-chunk path.</p>
Method TestReadRequestBodyParsesAUtf8MimeBody()
{
    Set tRaw = ##class(%Stream.TmpBinary).%New()
    ; {"user":"café"} with the e-acute as its two UTF-8 bytes, C3 A9.
    Do tRaw.Write("{""user"":""caf" _ $Char(195) _ $Char(169) _ """}")

    New %request
    Set %request = ##class(OcuPilot.Test.BodyRequest).%New()
    Set %request.MimePayload = tRaw

    Set tSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)

    Do $$$AssertStatusOK(tSC, "a well-formed body parses")
    Do $$$AssertTrue($IsObject($Get(tBody)), "and yields a dynamic object")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("user"), "caf" _ $Char(233), "whose value is UTF-8-decoded rather than taken as raw bytes")
    }
}

/// <p>DW-24 — a body that is present but is not JSON reports the <b>parse</b> stage, so a
/// client's malformed document is never reported as a server-side fault.</p>
Method TestReadRequestBodyReportsAParseFaultSeparately()
{
    Set tRaw = ##class(%Stream.TmpBinary).%New()
    Do tRaw.Write("{not json at all")

    New %request
    Set %request = ##class(OcuPilot.Test.BodyRequest).%New()
    Set %request.MimePayload = tRaw

    Set tSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)

    Do $$$AssertStatusNotOK(tSC, "a malformed document is an error")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "Invalid JSON", "reported as the client's JSON, not as a read or decode fault: " _ tText)
}

}
