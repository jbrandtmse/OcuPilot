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
/// <p><code>$ZConvert(str,"O","URL")</code> leaves a literal <code>/</code> untouched — it
/// is written for encoding a whole URL rather than one path component — so each pass
/// escapes it explicitly afterwards.</p>
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

/// <p>One percent-encoding pass over <var>pValue</var>, with a literal <code>/</code>
/// escaped explicitly so the result stays one path segment.</p>
ClassMethod PercentEncode(pValue As %String) As %String [ Private ]
{
    Quit $Replace($ZConvert(pValue, "O", "URL"), "/", "%2F")
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
