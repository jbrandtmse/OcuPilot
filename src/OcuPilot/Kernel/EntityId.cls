/// <p>The one shared entity-id codec (AD-13). A route is
/// <code>/ocupilot/&lt;area&gt;/&lt;screen&gt;[/&lt;id&gt;]?ns=&lt;NAMESPACE&gt;</code> — the id
/// occupies exactly one path segment, percent-encoded on write and decoded on read by this
/// pair of functions and no other. A slice that writes its own codec, or that calls
/// <method>Decode</method> more than once on the same value, is the failure this class
/// exists to prevent.</p>
/// <p><code>$ZConvert(str,"O","URL")</code> percent-encodes the reserved and non-ASCII
/// characters a URL path segment cannot carry literally, but — verified against the
/// running instance — leaves a literal <code>/</code> untouched, since it is written for
/// encoding a whole URL rather than one path component. <method>Encode</method> escapes
/// it explicitly afterward so an id containing a slash still round-trips as exactly one
/// path segment; <method>Decode</method> needs no matching special case, since
/// <code>$ZConvert(str,"I","URL")</code> already turns <code>%2F</code> back into
/// <code>/</code> on its own.</p>
Class OcuPilot.Kernel.EntityId Extends %RegisteredObject
{

/// <p>Percent-encode <var>pId</var> into exactly one URL path segment.</p>
ClassMethod Encode(pId As %String) As %String
{
    Quit $Replace($ZConvert(pId, "O", "URL"), "/", "%2F")
}

/// <p>Decode a single URL path segment back into the original entity id. This is the
/// <b>only</b> decode point in the tree — call it exactly once per id. A caller that
/// decodes a value already decoded (double-decoding) is the specific defect the
/// percent-encoded-double-encoded corpus row in <class>OcuPilot.Test.EntityId</class>
/// exists to catch.</p>
ClassMethod Decode(pSegment As %String) As %String
{
    Quit $ZConvert(pSegment, "I", "URL")
}

}
