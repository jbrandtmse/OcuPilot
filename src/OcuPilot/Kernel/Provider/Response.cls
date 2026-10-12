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
/// <p>The text-bearing properties are unbounded <class>%String</class>s rather than streams.
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

/// <p>The reply's <code>content</code> array verbatim, as JSON, when it carries reasoning blocks
/// that must go back to the provider unchanged and in order, and <code>""</code> otherwise.
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> echoes it whole as the assistant turn in
/// place of the text and tool-use blocks it would otherwise rebuild.</p>
Property ContentJson As %String(MAXLEN = "");

/// <p>How many tokens the request consumed, from the body's own usage figures, the prompt's whole
/// size with any cached part included (AD-31); <code>0</code> when the provider reported none.</p>
Property RequestTokens As %Integer [ InitialExpression = 0 ];

/// <p>How many tokens the request counts against a turn's token limit (AD-31): the prompt's size with
/// its cached part at the weight the provider bills it, rounded up to a whole token, as
/// <method>WeightedTokens</method> computes it. <code>""</code> when the adapter set none, which a
/// reader takes as <property>RequestTokens</property>. Never what the turn row or the ledger
/// records: they keep <property>RequestTokens</property>.</p>
Property BoundTokens As %Integer;

/// <p>How many tokens the reply consumed.</p>
Property ResponseTokens As %Integer [ InitialExpression = 0 ];

/// <p>How long the call took, in milliseconds, measured across every attempt including the waits
/// between them -- what the caller actually spent, not what the last attempt did.</p>
Property LatencyMs As %Integer [ InitialExpression = 0 ];

/// <p>The HTTP status the last attempt read, or <code>0</code> when no call was made at all --
/// which is what an unresolved credential and a failed key-shape gate both answer.</p>
Property HttpStatus As %Integer [ InitialExpression = 0 ];

/// <p>A prompt of <var>pWhole</var> tokens, <var>pCached</var> of them cached, with the cached part
/// counted at <var>pWeight</var> of a token each: the whole count less the cached part plus
/// <var>pWeight</var> times it, rounded up to a whole token. A cached part outside 0 to
/// <var>pWhole</var> is clamped into it, so a malformed usage block never counts below 0 or above the
/// whole count, and a weight of 1 answers the whole count.</p>
ClassMethod WeightedTokens(pWhole As %Integer, pCached As %Integer, pWeight As %Numeric) As %Integer
{
    Set tWhole = $Select(+pWhole > 0: +pWhole, 1: 0)
    Set tCached = $Select(+pCached > tWhole: tWhole, +pCached > 0: +pCached, 1: 0)
    Set tCount = tWhole - tCached + (+pWeight * tCached)
    Quit $Select(tCount = (tCount \ 1): tCount, 1: (tCount \ 1) + 1)
}

}
