/// <p>AD-42's retry arithmetic: which statuses are worth trying again, how long to wait, how to
/// read the provider's own hint, the two budgets that bound what one call may spend, and the clamp
/// that holds a stored timeout and attempt count inside them
/// (<method>EffectiveTimeoutSec</method>, <method>EffectiveAttempts</method>). Pure but
/// for one clock read -- <method>HttpDateDeltaSec</method>, because a <code>Retry-After</code> date
/// names a moment and only the clock turns that into a delay.</p>
/// <p>Split out from <class>OcuPilot.Kernel.Provider.Base</class> so the decision can be driven
/// directly over its whole input range. A backoff exercised only through a real call is a backoff
/// nothing pins: the delays are measured in seconds and a test that waited them out would be a
/// suite nobody runs.</p>
/// <p><b>Nothing here decides whether a call may be retried at all.</b> A call that raised, and a
/// call that timed out, are never retried whatever these answer (AD-42: the request may already
/// have been processed); the base's loop is what enforces that, and these three answer only the
/// question "the provider replied with this status -- again?". A transport failure before any
/// status line is the one failure the base's loop retries, once, waiting
/// <method>DelaySec</method> (AD-42).</p>
Class OcuPilot.Kernel.Provider.Retry Extends %RegisteredObject
{

/// <p>The non-5xx statuses worth another attempt, comma-separated: request timeout, conflict and
/// too-many-requests. The provider SDKs' own default retries these three alongside the server
/// errors, and each means "the same request may succeed unchanged".</p>
Parameter RETRYABLESTATUSES = "408,409,429";

/// <p>The server-error statuses that are <b>not</b> worth another attempt, comma-separated. 501
/// Not Implemented and 505 HTTP Version Not Supported are determinate refusals of the request as
/// written -- the same request meets the same answer -- so retrying one spends the budget and the
/// operator's time to reach it again. Every other status in the server-error band stays
/// retryable.</p>
Parameter NONRETRYABLESERVERSTATUSES = "501,505";

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

/// <p>The total seconds one provider call may spend <b>sleeping</b> between its attempts. It is one
/// honoured <code>Retry-After</code> at its own ceiling (<parameter>MAXRETRYAFTERSECONDS</parameter>),
/// so a provider that asks for the maximum gets it once and not twice: the next wait is cut to
/// whatever is left, and a call with nothing left stops rather than sleeping.</p>
Parameter RETRYBUDGETSECONDS As %Integer = 30;

/// <p><b>The seconds one provider call may spend in total</b> -- its attempts and the sleeps
/// between them. It is both the deadline <method>OcuPilot.Kernel.Provider.Base.Attempts</method>
/// reads between attempts, which refuses a further attempt once it has passed, and the ceiling
/// <method>EffectiveTimeoutSec</method> and <method>EffectiveAttempts</method> clamp a stored
/// per-call timeout and attempt count to, so <code>(attempts x timeout) +
/// <parameter>RETRYBUDGETSECONDS</parameter></code> is at most this whatever is stored (AD-42).
/// The deadline alone bounded only when a further attempt may <i>start</i>, which left the last
/// attempt free to run out an unbounded stored <code>timeoutSeconds</code>.</p>
/// <p>It is <parameter>OcuPilot.Kernel.State.Egress.DEFAULTMAXATTEMPTS</parameter> x
/// <parameter>OcuPilot.Kernel.State.Egress.DEFAULTTIMEOUT</parameter> plus
/// <parameter>RETRYBUDGETSECONDS</parameter> exactly, so the shipped defaults clamp to themselves
/// and three 90-second attempts are what they were.
/// <parameter>OcuPilot.Kernel.Agent.Limits.PROVIDERCALLSECONDS</parameter> is the turn-side
/// declaration of this same ceiling, and a test pins the two equal.</p>
Parameter ATTEMPTBUDGETSECONDS As %Integer = 300;

/// <p>The seconds one call's <b>attempts</b> may spend between them:
/// <parameter>ATTEMPTBUDGETSECONDS</parameter> less the sleeps
/// <parameter>RETRYBUDGETSECONDS</parameter> already reserves. Computed rather than spelled a
/// third time, so moving either budget moves the clamp with it.</p>
ClassMethod WorkBudgetSec() As %Integer
{
    Quit ..#ATTEMPTBUDGETSECONDS - ..#RETRYBUDGETSECONDS
}

/// <p>The per-call timeout one attempt may actually be given: <var>pTimeoutSeconds</var> cut to
/// <method>WorkBudgetSec</method>.</p>
/// <p><b>It only ever lowers.</b> A caller resolves its own default first -- a non-positive value
/// is the caller's to interpret, and is handed back unchanged -- so this composes with the
/// lowering <method>OcuPilot.Port.ProviderPort.Dispatch</method> already does rather than
/// fighting it.</p>
ClassMethod EffectiveTimeoutSec(pTimeoutSeconds As %Numeric) As %Numeric
{
    If +pTimeoutSeconds > ..WorkBudgetSec() Quit ..WorkBudgetSec()
    Quit +pTimeoutSeconds
}

/// <p>How many attempts of <var>pTimeoutSeconds</var> one call may make:
/// <var>pMaxAttempts</var> cut to as many whole <method>EffectiveTimeoutSec</method> timeouts as
/// <method>WorkBudgetSec</method> holds, and <b>never fewer than one</b> -- a timeout so long that
/// no whole attempt fits still buys the one attempt, clamped, rather than a refusal.</p>
/// <p>A timeout of zero or less bounds nothing, because such an attempt spends no time the budget
/// measures (<class>%Net.HttpRequest</class> reads <code>Timeout</code> 0 as no wait at all), so
/// the count is handed back as given; the attempt deadline is what bounds that call.</p>
ClassMethod EffectiveAttempts(pMaxAttempts As %Integer, pTimeoutSeconds As %Numeric) As %Integer
{
    Set tAttempts = +pMaxAttempts
    If tAttempts < 1 Set tAttempts = 1
    Set tTimeout = ..EffectiveTimeoutSec(pTimeoutSeconds)
    If tTimeout <= 0 Quit tAttempts
    Set tAllowed = ..WorkBudgetSec() \ tTimeout
    If tAllowed < 1 Set tAllowed = 1
    If tAttempts > tAllowed Quit tAllowed
    Quit tAttempts
}

/// <p>Whether <var>pStatus</var> is a status the same request may be sent again on: one of
/// <parameter>RETRYABLESTATUSES</parameter>, or any server error other than the two
/// <parameter>NONRETRYABLESERVERSTATUSES</parameter> carves out.</p>
/// <p>A 401, a 403 and a 400 are deliberately absent: each means the request as written will be
/// refused again, so retrying one spends the budget and the operator's time to reach the same
/// answer.</p>
ClassMethod IsRetryable(pStatus As %String) As %Boolean
{
    If '$Match(pStatus, "^[0-9]+$") Quit 0
    If $ListFind($ListFromString(..#RETRYABLESTATUSES), +pStatus) Quit 1
    If $ListFind($ListFromString(..#NONRETRYABLESERVERSTATUSES), +pStatus) Quit 0
    Quit (+pStatus >= ..#SERVERERRORFLOOR) && (+pStatus <= ..#STATUSCEILING)
}

/// <p>The provider's <code>Retry-After</code> hint in seconds, or <code>0</code> when there is
/// none to honour.</p>
/// <p><b>Both forms RFC 9110 gives the header.</b> Delta-seconds is taken as written. An
/// IMF-fixdate -- <code>Wed, 21 Oct 2026 07:28:00 GMT</code>, the preferred form -- is resolved
/// against <code>$ZTimeStamp</code> and rounded <b>up</b> to whole seconds, so the wait is never
/// shorter than the moment the provider named. A date already past, a date this instance cannot
/// read, and the two obsolete date forms RFC 9110 still admits each answer <code>0</code>, which
/// leaves the exponential backoff alone in charge: a partially-read date would be a delay of some
/// arbitrary size, and no delay at all is the safe answer.</p>
/// <p>Bounded above by <parameter>MAXRETRYAFTERSECONDS</parameter> whichever form it arrived in,
/// so a provider cannot choose how long OcuPilot blocks.</p>
ClassMethod ParseRetryAfter(pHeaderValue As %String = "") As %Integer
{
    Set tSeconds = $Select($Match(pHeaderValue, "^[0-9]+$"): +pHeaderValue, 1: ..HttpDateDeltaSec(pHeaderValue))
    If tSeconds > ..#MAXRETRYAFTERSECONDS Quit ..#MAXRETRYAFTERSECONDS
    Quit tSeconds
}

/// <p>Whole seconds from now until the IMF-fixdate <var>pHeaderValue</var>, rounded up;
/// <code>0</code> for a moment already past, and for anything that is not that form.</p>
/// <p><b>The one reading of the clock in this class</b>, and the reason the form is matched before
/// it is parsed: <method>$ZDateH</method> and <method>$ZTimeH</method> raise on a value they cannot
/// read, and a shape test settles that before either runs. The trailing locale argument is the one
/// <class>%Net.HttpRequest</class>'s own cookie-expiry parser passes, so an English month name is
/// read on an instance whose locale names months otherwise.</p>
/// <p>Rounded up rather than truncated because the header names a moment, not a duration: the
/// fraction of a second already elapsed when this runs must not shorten the wait below it.</p>
ClassMethod HttpDateDeltaSec(pHeaderValue As %String) As %Integer [ Private ]
{
    Set tDelta = 0
    Try {
        If '$Match(pHeaderValue, "^[A-Za-z]{3}, [0-9]{2} [A-Za-z]{3} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$") Quit
        Set tTarget = ($ZDateH($Piece(pHeaderValue, " ", 2, 4), 7, , , , , , , , 1) * 86400) + $ZTimeH($Piece(pHeaderValue, " ", 5), , , 1)
        Set tDelta = tTarget - (($Piece($ZTimeStamp, ",", 1) * 86400) + $Piece($ZTimeStamp, ",", 2))
        If tDelta <= 0 {
            Set tDelta = 0
            Quit
        }
        If tDelta > (tDelta \ 1) Set tDelta = (tDelta \ 1) + 1
    } Catch ex {
        Set tDelta = 0
    }
    Quit tDelta
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
/// backoff (AD-42), cut to <var>pRemainingBudget</var>.</p>
/// <p>The greater rather than the hint, because a provider that asks for one second while its own
/// error rate is rising gets a client that retries every second; and the greater rather than the
/// backoff, because a provider that asks for seven has told you something the backoff does not
/// know.</p>
/// <p><var>pRemainingBudget</var> is what is left of <parameter>RETRYBUDGETSECONDS</parameter>
/// after the waits this call has already taken; the answer is truncated to it rather than honoured
/// whole, so a provider cannot lengthen a turn past the bound by asking twice. <code>""</code>
/// means no budget bound at all, which is how the arithmetic is driven directly; the transport loop
/// always supplies one.</p>
ClassMethod DelaySec(pAttempt As %Integer, pRetryAfter As %String = "", pRemainingBudget As %String = "") As %Numeric
{
    Set tHint = ..ParseRetryAfter(pRetryAfter)
    Set tBackoff = ..ExpBackoffSec(pAttempt)
    Set tDelay = $Select(tHint > tBackoff: tHint, 1: tBackoff)
    If pRemainingBudget = "" Quit tDelay
    If tDelay > +pRemainingBudget Quit +pRemainingBudget
    Quit tDelay
}

}
