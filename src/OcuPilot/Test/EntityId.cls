/// <p>AD-13's named corpus for <class>OcuPilot.Kernel.EntityId</class>, covering a leading
/// underscore, a slash, a space, a percent sign, a non-ASCII character, a question mark and
/// a hash — both directions, since an encode-only assertion is not evidence.</p>
/// <p><b>The round trip is over the wire contract, not over the two functions.</b>
/// <method>OcuPilot.Kernel.EntityId.Encode</method> encodes twice and
/// <method>OcuPilot.Kernel.EntityId.Decode</method> decodes once, because the web server
/// consumes exactly one decoding in transit (DW-31). So the trip these tests assert is
/// <code>Encode</code> -&gt; <method>ServerDecode</method> -&gt; <code>Decode</code>, and
/// <code>Decode(Encode(x))</code> is deliberately <b>not</b> the identity — asserting that
/// instead is what a single-encode codec would pass and the wire would then break.
/// <class>OcuPilot.Test.Wire</class> replays this same corpus through a real web
/// application, which is what proves <method>ServerDecode</method> models the server
/// correctly.</p>
Class OcuPilot.Test.EntityId Extends %UnitTest.TestCase
{

/// <p>The corpus, shared with <class>OcuPilot.Test.Wire</class> so the two cannot drift.
/// The non-ASCII row is built with <code>$Char</code> rather than a literal byte, per this
/// repository's own source convention.</p>
/// <p>Rows 9-11 are DW-97's. Neither this corpus nor <file>ui/tools/entity-id.test.mjs</file>'s
/// held a dot before, so a change to one codec's dot handling alone would have left both parity
/// suites green while the deep link it broke answered 400.</p>
/// <p>Rows 12-17 are DW-130's. <code>encodeURIComponent</code> escapes everything except
/// <code>A-Za-z0-9</code> and eleven punctuation characters: the RFC 3986 unreserved
/// <code>-</code>, <code>_</code>, <code>.</code>, <code>~</code> and the sub-delimiters
/// <code>!</code>, <code>*</code>, <code>'</code>, <code>(</code>, <code>)</code>. Each of the
/// eleven is a place the two codecs could diverge one-sidedly, and every one now has a row:
/// <code>_</code> through <code>_SYSTEM</code> (row 1), <code>.</code> through DW-97's three,
/// and the remaining seven here. Verified live 2026-09-12: this codec agrees with
/// <code>encodeURIComponent</code> on ten of the eleven and diverges on <code>~</code> alone
/// (<code>$ZConvert("~","O","URL")</code> yields <code>%7E</code>).
/// <method>TestBrowserEncodedInputMatchesTheServerCodec</method> pins the ten that agree;
/// <method>TestTildeDivergesFromTheClientCodecButStillRoundTrips</method> pins the one that
/// does not, since folding it into that method would assert a parity that does not hold.</p>
ClassMethod Corpus() As %List
{
    Quit $ListBuild("_SYSTEM", "a/b", "a b", "100%", "caf" _ $Char(233), "x?y", "#frag", "/csp/myapp", "a..b", "..leading", "trailing.", "a!b", "a~b", "a*b", "a'b", "a(b)", "a-b")
}

/// <p>What the front web server and <class>%CSP.REST</class> do to a path segment before a
/// route target ever sees it: percent-decode exactly once, then UTF-8-decode. Verified
/// against the pinned image on a throwaway container (Story 1.5) and re-verified over a real
/// web application by <class>OcuPilot.Test.Wire</class>.</p>
ClassMethod ServerDecode(pSegment As %String) As %String
{
    Quit $ZConvert($ZConvert(pSegment, "I", "URL"), "I", "UTF8")
}

/// <p>Every corpus value survives the wire trip byte for byte, and its encoded form carries
/// neither a raw <code>/</code> (which would make it two path segments) nor a literal
/// <code>%2F</code> (which the front web server refuses outright, so a value encoded only
/// once would never arrive at all).</p>
/// <p>Mutation: drop the second <method>PercentEncode</method> call from
/// <method>OcuPilot.Kernel.EntityId.Encode</method> — demonstrated red, and worth naming
/// exactly which rows carry it: the <code>%2F</code> assertion goes red for the two rows
/// holding a slash (<code>a/b</code>, <code>/csp/myapp</code>) and the round trip goes red
/// for the non-ASCII row (<code>café</code>). The four ASCII slash-free rows still pass, so
/// those two assertions — not the round trip alone — are what pin the second encode.</p>
Method TestCorpusSurvivesTheWireTrip()
{
    Set tCorpus = ##class(OcuPilot.Test.EntityId).Corpus()
    For i=1:1:$ListLength(tCorpus) {
        Set tOriginal = $List(tCorpus, i)
        Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode(tOriginal)
        Do $$$AssertTrue((tEncoded '[ "/"), "encoded form of row " _ i _ " carries no raw / -- one path segment")
        Do $$$AssertTrue(($ZConvert(tEncoded, "U") '[ "%2F"), "encoded form of row " _ i _ " carries no literal %2F, which the web server refuses")
        Do $$$AssertTrue((tEncoded '[ ".."), "encoded form of row " _ i _ " carries no literal .., which the static handler refuses outright (DW-97)")
        Set tDelivered = ##class(OcuPilot.Test.EntityId).ServerDecode(tEncoded)
        Do $$$AssertTrue((tDelivered '[ ".."), "row " _ i _ " does not reach the handler carrying a literal .. either -- the hop decodes exactly once")
        Set tDecoded = ##class(OcuPilot.Kernel.EntityId).Decode(tDelivered)
        Do $$$AssertEquals(tDecoded, tOriginal, "row " _ i _ " survives Encode -> the server's own single decode -> Decode")
    }
}

/// <p>A browser-encoded input: what <file>ui/src/app/core/entity-id.ts</file> produces --
/// <code>encodeURIComponent</code> twice, with a literal <code>.</code> escaped to
/// <code>%2E</code> on each pass (DW-97) -- is byte-identical to what
/// <method>OcuPilot.Kernel.EntityId.Encode</method> produces, so the client mirror and the
/// server codec are one contract rather than two. The expected strings below are the
/// browser's own output, not this codec's, which is the point.</p>
/// <p>The last five rows are DW-130's: <code>!</code>, <code>*</code>, <code>'</code>,
/// <code>(</code>, <code>)</code> and <code>-</code> survive both codecs unescaped, verified
/// live 2026-09-12. <code>~</code> is deliberately not among them -- it is the one character
/// of the eleven <code>encodeURIComponent</code> leaves literal that this codec does not agree
/// with the browser on, pinned separately in
/// <method>TestTildeDivergesFromTheClientCodecButStillRoundTrips</method> rather than folded
/// in here, where it would assert a parity that does not hold.</p>
Method TestBrowserEncodedInputMatchesTheServerCodec()
{
    Set tCases = $ListBuild($ListBuild("a b", "a%2520b"), $ListBuild("a/b", "a%252Fb"), $ListBuild("100%", "100%2525"), $ListBuild("caf" _ $Char(233), "caf%25C3%25A9"), $ListBuild("_SYSTEM", "_SYSTEM"), $ListBuild("a..b", "a%252E%252Eb"), $ListBuild("..leading", "%252E%252Eleading"), $ListBuild("trailing.", "trailing%252E"), $ListBuild("a!b", "a!b"), $ListBuild("a*b", "a*b"), $ListBuild("a'b", "a'b"), $ListBuild("a(b)", "a(b)"), $ListBuild("a-b", "a-b"))
    For i=1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, i)
        Set tOriginal = $List(tCase, 1)
        Set tBrowser = $List(tCase, 2)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityId).Encode(tOriginal), tBrowser, "the server codec produces the browser's own double-encoded form for row " _ i)
        Set tDecoded = ##class(OcuPilot.Kernel.EntityId).Decode(##class(OcuPilot.Test.EntityId).ServerDecode(tBrowser))
        Do $$$AssertEquals(tDecoded, tOriginal, "a browser-encoded segment decodes back to the original for row " _ i)
    }
}

/// <p>DW-130. Of the eleven punctuation characters <code>encodeURIComponent</code> leaves
/// literal (the RFC 3986 unreserved <code>-</code>, <code>_</code>, <code>.</code>,
/// <code>~</code> and the sub-delimiters <code>!</code>, <code>*</code>, <code>'</code>,
/// <code>(</code>, <code>)</code>), <code>~</code> alone diverges from this
/// codec: verified live, <code>$ZConvert("~","O","URL")</code> yields <code>%7E</code> where
/// <code>encodeURIComponent</code> leaves it literal. Pinned here rather than folded into
/// <method>TestBrowserEncodedInputMatchesTheServerCodec</method>, which asserts byte parity
/// with the browser and would misstate this one row. Documented, not a defect
/// (<file>ui/src/app/core/entity-id.ts</file>'s header): the wire bytes differ but each side
/// decodes its own output back to the original, and nothing compares two encoded segments for
/// equality.</p>
Method TestTildeDivergesFromTheClientCodecButStillRoundTrips()
{
    Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode("a~b")
    Do $$$AssertEquals(tEncoded, "a%257Eb", "the server codec escapes ~ to %7E on the first pass and %25 on the second")
    Set tDelivered = ##class(OcuPilot.Test.EntityId).ServerDecode(tEncoded)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityId).Decode(tDelivered), "a~b", "and still round-trips to the original")
}

/// <p>A segment that already reads <code>%2520</code> decodes, once, to the literal
/// three-character string <code>%20</code> — not to a space, which is what a second
/// decode would produce. This is the specific defect a slice that decodes twice
/// introduces.</p>
Method TestDoubleEncodedSegmentDecodesOnce()
{
    Set tDecodedOnce = ##class(OcuPilot.Kernel.EntityId).Decode("%2520")
    Do $$$AssertEquals(tDecodedOnce, "%20", "a single Decode() of %2520 yields the literal string %20")
    Do $$$AssertNotEquals(tDecodedOnce, " ", "not a space, which is what a second decode would (wrongly) produce")
}

/// <p>Encoding an already-safe value (no reserved or non-ASCII characters) is a no-op —
/// pins the identity case alongside the escaping cases above.</p>
Method TestSafeValueEncodesUnchanged()
{
    Set tOriginal = "widget42"
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityId).Encode(tOriginal), tOriginal, "a value with no reserved characters encodes unchanged")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityId).Decode(tOriginal), tOriginal, "and decodes unchanged")
}

}
