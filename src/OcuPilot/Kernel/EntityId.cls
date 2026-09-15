/// <p>The one shared entity-id codec (AD-13). A route is
/// <code>/ocupilot/&lt;area&gt;/&lt;screen&gt;[/&lt;id&gt;]?ns=&lt;NAMESPACE&gt;</code> — the id
/// occupies exactly one path segment, encoded on write and decoded on read by this pair of
/// functions and no other. A slice that writes its own codec, or that calls
/// <method>Decode</method> more than once on the same value, is the failure this class
/// exists to prevent.</p>
/// <p><b>The wire contract is encode-twice, decode-once</b> (DW-31, settled in Story 1.5
/// against the pinned image and written into the spine at AD-13). A path segment reaches a
/// <class>%CSP.REST</class> class <b>already percent-decoded exactly once and UTF-8
/// decoded</b>, so one encode on the client would be consumed by the server's own decode
/// and <method>Decode</method> would receive a value it must not decode again. Encoding
/// twice leaves exactly one encoding for <method>Decode</method> to undo.</p>
/// <p>Two properties of the trip make the second encode load-bearing rather than
/// decorative:</p>
/// <ul>
/// <li><b><code>%2F</code> never arrives.</b> The container's own front web server refuses
/// an encoded slash (and an encoded null) before IRIS sees the request. Encoding twice
/// sends <code>%252F</code>, which it does forward, and the server's decode turns it back
/// into the <code>%2F</code> <method>Decode</method> expects — so an id containing a slash,
/// a web application name such as <code>/csp/myapp</code> among them, survives. This is a
/// stack limitation recorded, not worked around.</li>
/// <li><b>A non-ASCII byte does not survive singly encoded.</b> The UTF-8 conversion
/// happens here, before the first percent-encoding, and the second encoding carries the
/// resulting <code>%XX</code> triples through the server's decode intact.</li>
/// </ul>
/// <p><code>$ZConvert(str,"O","URL")</code> leaves a literal <code>/</code> and a literal
/// <code>.</code> untouched — it is written for encoding a whole URL rather than one path
/// component — so each pass escapes both explicitly afterwards.</p>
/// <p><b>The dot is escaped so an id can carry <code>..</code></b> (DW-97). An entity id such
/// as <code>a..b</code> would otherwise reach the wire with a literal <code>..</code> in it,
/// which <class>OcuPilot.Api.StaticHandler</class> refuses outright before it resolves a path
/// (AD-21) — so a deep link to that entity would answer 400 rather than the shell document.
/// Escaping the dot in <b>both</b> passes means the encoded segment carries
/// <code>%252E%252E</code>, the one decode the server performs in transit turns that into the
/// text <code>%2E%2E</code>, and no layer ever sees a literal <code>..</code>. AD-21's refusal
/// is untouched: a hand-typed <code>..</code> path still answers 400, which is the whole point
/// of fixing this in the codec rather than by teaching a containment check to carry data.</p>
/// <p><method>Decode</method> needs no change — <code>$ZConvert(...,"I","URL")</code> already
/// reads <code>%2E</code> back as a dot.</p>
Class OcuPilot.Kernel.EntityId Extends %RegisteredObject
{

/// <p>Encode <var>pId</var> into exactly one URL path segment: UTF-8 first, then
/// percent-encoded twice. The result is what a client puts in the URL; what the route
/// target receives is one decode less than this, which is exactly what
/// <method>Decode</method> consumes.</p>
ClassMethod Encode(pId As %String) As %String
{
    Quit ..PercentEncode(..PercentEncode($ZConvert(pId, "O", "UTF8")))
}

/// <p>One percent-encoding pass over <var>pValue</var>, with a literal <code>/</code> escaped
/// explicitly so the result stays one path segment, and a literal <code>.</code> escaped so the
/// result never carries a <code>..</code> the static handler refuses (DW-97).</p>
/// <p>The order of the two replacements does not matter: neither introduces the other's
/// character. Both run after <code>$ZConvert</code>, which is what turns the <code>%</code>
/// each escape introduces into <code>%25</code> on the second pass.</p>
ClassMethod PercentEncode(pValue As %String) As %String [ Private ]
{
    Quit $Replace($Replace($ZConvert(pValue, "O", "URL"), "/", "%2F"), ".", "%2E")
}

/// <p>The character that separates the parts of a composite id, as its code point. A composite
/// id is still <b>one</b> path segment (AD-13): where a natural key has parts, the descriptor
/// names them and this codec joins them, so a slice never invents a second composite
/// grammar.</p>
/// <p><code>$Char(1)</code> because the parts of the composite keys Release 1 administers are
/// IRIS identifiers, namespace names and web-application paths, none of which can hold a
/// control character (inference). The codec percent-encodes it like any other byte, so nothing
/// about the wire trip changes.</p>
Parameter COMPOSITESEPARATOR = 1;

/// <p>Join the parts of a composite id into the single value <method>Encode</method> takes.</p>
ClassMethod JoinComposite(pParts As %List) As %String
{
    Quit $ListToString(pParts, $Char(..#COMPOSITESEPARATOR))
}

/// <p>Split a composite id back into its parts, in declaration order. The inverse of
/// <method>JoinComposite</method>, and the only place that inverse is spelled.</p>
ClassMethod SplitComposite(pValue As %String) As %List
{
    Quit $ListFromString(pValue, $Char(..#COMPOSITESEPARATOR))
}

/// <p>Decode a single URL path segment back into the original entity id: percent-decode
/// once, then UTF-8-decode. This is the <b>only</b> decode point in the tree — call it
/// exactly once per id, on the value the framework handed the route target, never on
/// <method>Encode</method>'s own output (that value still carries the encoding the web
/// server consumes in transit).</p>
ClassMethod Decode(pSegment As %String) As %String
{
    Quit $ZConvert($ZConvert(pSegment, "I", "URL"), "I", "UTF8")
}

}
