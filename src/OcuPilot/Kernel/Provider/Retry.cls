/// <p>AD-42's retry arithmetic, as pure functions: which statuses are worth trying again, how long
/// to wait, and how to read the provider's own hint.</p>
/// <p>Split out from <class>OcuPilot.Kernel.Provider.Base</class> so the decision can be driven
/// directly over its whole input range. A backoff exercised only through a real call is a backoff
/// nothing pins: the delays are measured in seconds and a test that waited them out would be a
/// suite nobody runs.</p>
/// <p><b>Nothing here decides whether a call may be retried at all.</b> A call that raised, and a
/// call that timed out, are never retried whatever these answer (AD-42: the request may already
/// have been processed); the base's loop is what enforces that, and these three answer only the
/// question "the provider replied with this status -- again?".</p>
Class OcuPilot.Kernel.Provider.Retry Extends %RegisteredObject
{

/// <p>The non-5xx statuses worth another attempt, comma-separated: request timeout, conflict and
/// too-many-requests. The provider SDKs' own default retries these three alongside the server
/// errors, and each means "the same request may succeed unchanged".</p>
Parameter RETRYABLESTATUSES = "408,409,429";

/// <p>The lowest server-error status; every status from here up is retryable.</p>
Parameter SERVERERRORFLOOR As %Integer = 500;

/// <p>The highest status that is a status at all. Above it is not an HTTP answer.</p>
Parameter STATUSCEILING As %Integer = 599;

/// <p>The base of the exponential backoff, in seconds.</p>
Parameter BACKOFFBASESECONDS As %Numeric = 1;

/// <p>The longest backoff window, in seconds, however many attempts have been made. Without a
/// ceiling the doubling reaches minutes on the fourth attempt, which is longer than any turn is
/// willing to wait.</p>
Parameter BACKOFFCAPSECONDS As %Integer = 8;

/// <p>The longest <code>Retry-After</code> hint that is honoured, in seconds. A hint above it is
/// clamped to it and the attempt is still made, so a provider cannot choose how long OcuPilot
/// blocks: the caller is a turn with a person in front of it.</p>
Parameter MAXRETRYAFTERSECONDS As %Integer = 30;

/// <p>Whether <var>pStatus</var> is a status the same request may be sent again on: one of
/// <parameter>RETRYABLESTATUSES</parameter>, or any server error.</p>
/// <p>A 401, a 403 and a 400 are deliberately absent: each means the request as written will be
/// refused again, so retrying one spends the budget and the operator's time to reach the same
/// answer.</p>
ClassMethod IsRetryable(pStatus As %String) As %Boolean
{
    If '$Match(pStatus, "^[0-9]+$") Quit 0
    If $ListFind($ListFromString(..#RETRYABLESTATUSES), +pStatus) Quit 1
    Quit (+pStatus >= ..#SERVERERRORFLOOR) && (+pStatus <= ..#STATUSCEILING)
}

/// <p>The provider's <code>Retry-After</code> hint in seconds, or <code>0</code> when there is
/// none to honour.</p>
/// <p><b>Delta-seconds only.</b> RFC 9110 lets the header carry an HTTP date as well, and
/// <code>Wed, 21 Oct 2026 07:28:00 GMT</code> read as a number is <code>0</code> in ObjectScript
/// -- which is harmless -- while a partially-parsed one would be a delay of some arbitrary size.
/// So the value is matched as digits or it is discarded, and the exponential backoff alone is
/// used. Bounded above by <parameter>MAXRETRYAFTERSECONDS</parameter>, so a provider cannot
/// choose how long OcuPilot blocks.</p>
ClassMethod ParseRetryAfter(pHeaderValue As %String = "") As %Integer
{
    If '$Match(pHeaderValue, "^[0-9]+$") Quit 0
    If +pHeaderValue > ..#MAXRETRYAFTERSECONDS Quit ..#MAXRETRYAFTERSECONDS
    Quit +pHeaderValue
}

/// <p>The exponential backoff for <var>pAttempt</var> -- the attempt that has just failed,
/// counting from 1 -- in seconds, with full jitter.</p>
/// <p><b>Full jitter, not a fixed doubling</b>: the window doubles per attempt to
/// <parameter>BACKOFFCAPSECONDS</parameter> and the delay is drawn uniformly from it, so several
/// callers that met the same outage do not return together and cause the next one.</p>
ClassMethod ExpBackoffSec(pAttempt As %Integer) As %Numeric
{
    If +pAttempt < 1 Quit 0
    Set tWindow = ..#BACKOFFBASESECONDS
    For tI = 2:1:+pAttempt {
        Set tWindow = tWindow * 2
        If tWindow >= ..#BACKOFFCAPSECONDS {
            Set tWindow = ..#BACKOFFCAPSECONDS
            Quit
        }
    }
    ; $Random(n) answers 0..n-1, so the draw is over tenths of a second and the window's own
    ; top value is reachable.
    Quit $Random((tWindow * 10) + 1) / 10
}

/// <p>How long to wait after attempt <var>pAttempt</var> failed with the header value
/// <var>pRetryAfter</var>: <b>the greater</b> of the provider's honoured hint and the exponential
/// backoff (AD-42).</p>
/// <p>The greater rather than the hint, because a provider that asks for one second while its own
/// error rate is rising gets a client that retries every second; and the greater rather than the
/// backoff, because a provider that asks for seven has told you something the backoff does not
/// know.</p>
ClassMethod DelaySec(pAttempt As %Integer, pRetryAfter As %String = "") As %Numeric
{
    Set tHint = ..ParseRetryAfter(pRetryAfter)
    Set tBackoff = ..ExpBackoffSec(pAttempt)
    If tHint > tBackoff Quit tHint
    Quit tBackoff
}

}
