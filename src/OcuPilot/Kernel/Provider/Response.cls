/// <p>What one provider call answered, in the shape every adapter maps its own family's response
/// into. Anthropic's is canonical, so the Anthropic adapter's mapping is a passthrough and a later
/// family's adapter is what translates.</p>
/// <p><b><property>StopReason</property> <code>"error"</code> is the failure signal</b>, and it is
/// the only one: <method>OcuPilot.Kernel.Provider.Base.Invoke</method> returns <code>$$$OK</code>
/// on every path (AD-12, AD-39, AD-42), so a caller that read the <class>%Status</class> alone
/// would read every failure as a success. The fault the same call sets carries the
/// <code>PROVIDER.*</code> code.</p>
/// <p>No property here can hold a credential (AD-35): the key travels on the adapter instance and
/// onto the request's headers, and nothing on the way back carries it.</p>
/// <p>The two text-bearing properties are unbounded <class>%String</class>s rather than streams.
/// A reply is bounded by the definition's own <code>maxTokens</code>, whose ceiling is 32000, and
/// the text that many tokens render to is two orders of magnitude inside ObjectScript's long-string
/// limit. This class holds no storage, so nothing about that choice reaches a global.</p>
Class OcuPilot.Kernel.Provider.Response Extends %RegisteredObject
{

/// <p>Why the provider stopped -- the body's own <code>stop_reason</code> on a successful call,
/// and <code>"error"</code> on every failure.</p>
Property StopReason As %String(MAXLEN = 64) [ InitialExpression = "error" ];

/// <p>The reply's text content: its text blocks concatenated in order. <code>""</code> when the
/// reply carried none, which a tool-only reply does.</p>
Property Text As %String(MAXLEN = "");

/// <p>The reply's tool-use blocks as a JSON array, verbatim in the provider's own shape, or
/// <code>""</code> when there were none. Epic 4's turn is what reads them; nothing here
/// interprets one.</p>
Property ToolCallsJson As %String(MAXLEN = "");

/// <p>How many tokens the request consumed, from the body's own usage figures; <code>0</code> when
/// the provider reported none.</p>
Property RequestTokens As %Integer [ InitialExpression = 0 ];

/// <p>How many tokens the reply consumed.</p>
Property ResponseTokens As %Integer [ InitialExpression = 0 ];

/// <p>How long the call took, in milliseconds, measured across every attempt including the waits
/// between them -- what the caller actually spent, not what the last attempt did.</p>
Property LatencyMs As %Integer [ InitialExpression = 0 ];

/// <p>The HTTP status the last attempt read, or <code>0</code> when no call was made at all --
/// which is what an unresolved credential and a failed key-shape gate both answer.</p>
Property HttpStatus As %Integer [ InitialExpression = 0 ];

}
