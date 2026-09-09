/// <p>AD-13's named corpus: round-trips <class>OcuPilot.Kernel.EntityId</class>'s
/// <method>Encode</method> / <method>Decode</method> pair over a fixed corpus covering a
/// leading underscore, a slash, a space, a percent sign, a non-ASCII character, a question
/// mark and a hash — both directions, since an encode-only assertion is not evidence.</p>
Class OcuPilot.Test.EntityId Extends %UnitTest.TestCase
{

/// <p>Every corpus value round-trips byte-for-byte, and its encoded form never contains
/// a raw <code>/</code> — the property that guarantees it occupies exactly one path
/// segment.</p>
Method TestCorpusRoundTrips()
{
    Set tCorpus = $ListBuild("_SYSTEM", "a/b", "a b", "100%", "café", "x?y", "#frag")
    For i=1:1:$ListLength(tCorpus) {
        Set tOriginal = $List(tCorpus, i)
        Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode(tOriginal)
        Do $$$AssertTrue((tEncoded '[ "/"), "encoded form of '" _ tOriginal _ "' carries no raw / — one path segment")
        Set tDecoded = ##class(OcuPilot.Kernel.EntityId).Decode(tEncoded)
        Do $$$AssertEquals(tDecoded, tOriginal, "round trip recovers '" _ tOriginal _ "' byte-for-byte")
    }
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
