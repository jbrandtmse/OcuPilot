/// <p>Every number a turn obeys (AD-31, AD-33, AD-41), as named constants in one place. Nothing
/// else in the tree spells these values: the handler, the job, the loop and the two turn stores
/// read them from here, through the class name <method>OcuPilot.Kernel.Agent.Loop.LimitsClass</method>
/// answers.</p>
/// <p>A subclass that narrows a parameter is how a test drives a bound without waiting it out.
/// Story 14.6 replaces these constants with per-user settings.</p>
Class OcuPilot.Kernel.Agent.Limits Extends %RegisteredObject
{

/// <p>Wall-clock seconds a turn may run, counted from the moment its job begins.</p>
Parameter WALLCLOCKSECONDS As %Integer = 600;

/// <p>The ceiling on provider calls per turn. The cap a turn runs under is the lower of this and
/// its definition's own <property>OcuPilot.Kernel.State.Agent.MaxIterationsPerTurn</property>.</p>
Parameter MAXITERATIONS As %Integer = 100;

/// <p>Provider tokens, input plus output, one turn may spend.</p>
Parameter MAXTOKENS As %Integer = 500000;

/// <p>Seconds a running turn survives without an authenticated poll by its owner.</p>
Parameter LEASESECONDS As %Integer = 120;

/// <p>Seconds a terminal turn and its progress are kept after it ends.</p>
Parameter RETENTIONSECONDS As %Integer = 900;

/// <p>Seconds a minted proposal stays confirmable (AD-6), counted from the moment it is minted.</p>
/// <p>It is at or below <parameter>RETENTIONSECONDS</parameter> by rule: a proposal is confirmable
/// only while its turn ended normally, which <method>OcuPilot.Kernel.Proposal.Write.Claim</method>
/// reads off the turn row, so the turn record has to outlive the proposal's own window.
/// <class>OcuPilot.Test.ProposalWrite</class> asserts that relation rather than leaving it to be
/// noticed when a claim starts answering <code>PROPOSAL.TURNENDED</code> for a turn that merely
/// aged out.</p>
Parameter PROPOSALEXPIRYSECONDS As %Integer = 600;

/// <p>Characters a posted message may carry.</p>
Parameter MESSAGEMAXLENGTH As %Integer = 16000;

/// <p>Progress steps stored per turn; later steps are counted, not stored.</p>
Parameter MAXSTEPS As %Integer = 100;

/// <p>Characters a step's name or summary is cut at.</p>
Parameter SUMMARYMAXLENGTH As %Integer = 1000;

/// <p>Characters a step's text, or a turn's reply, is cut at.</p>
Parameter TEXTMAXLENGTH As %Integer = 131072;

/// <p>Seconds a turn may stay queued before a reserve or a poll with the slot free reads its job as
/// lost; also how long a starting job waits for the slot.</p>
Parameter QUEUEDSECONDS As %Integer = 10;

/// <p>Rows one tool result carries at most (AD-24, AD-36). A tool is asked for no more, and a result
/// that still holds more is cut and marked <code>truncated</code>.</p>
Parameter TOOLROWS As %Integer = 200;

/// <p>Characters one serialized tool result carries at most (AD-24). Trailing rows are dropped until
/// it fits; a result that cannot fit is refused <code>TOOL.RESULTTOOLARGE</code>.</p>
Parameter TOOLRESULTMAXLENGTH As %Integer = 65536;

/// <p>Characters one field's string value carries at most, when the descriptor declares no
/// <code>context.maxLength</code> for that field (AD-24, DW-281). A value cut to this bound loses
/// one character to the trailing U+2026 mark, so the kept text is this many characters minus
/// one.</p>
Parameter FIELDMAXLENGTH As %Integer = 1000;

/// <p>Characters the next turn's model request replays from prior turns of the same conversation
/// (Story 4.5, AD-24): each turn with a reply contributes its user message then its reply, oldest
/// first, and whole turns are dropped from the oldest end until the total fits. A turn with no
/// reply is skipped; tool results and screen context are never replayed.</p>
Parameter HISTORYMAXLENGTH As %Integer = 65536;

/// <p>Seconds a client-fulfilled tool call (Story 4.7, AD-11 rule 3) waits for the browser to
/// answer its directive, in 250 ms passes each re-running <method>OcuPilot.Kernel.Agent.Loop.Boundary</method>.
/// Long enough for a person to answer "Leave without saving?"; cut short by the turn's own stop,
/// kill-switch, lease, wall-clock and token bounds on every pass, whichever elapses first. A
/// browser that never answers within it lapses the call to <code>NAV.UNAVAILABLE</code>.</p>
Parameter NAVWAITSECONDS As %Integer = 60;

/// <p>Ledger rows stored per turn (AD-41); later calls are counted on that turn's one
/// <code>overflow</code> row, not stored. A turn is capped at <parameter>MAXITERATIONS</parameter>
/// provider calls and the common shape is one tool answer per iteration, so this is one row per
/// call at the turn's own ceiling: an ordinary turn never overflows, and a turn returning several
/// <code>tool_use</code> blocks per iteration can.</p>
Parameter LEDGERMAXROWS As %Integer = 200;

/// <p>Characters a ledger row's redacted argument string is cut at, the cut value ending in
/// U+2026. Four times <parameter>SUMMARYMAXLENGTH</parameter>, the bound the tool step's own
/// argument string already obeys, so a ledger row can never be narrower than the step it
/// reconciles with; the worst-case per-turn footprint is about 800 KB.</p>
Parameter LEDGERROWMAXLENGTH As %Integer = 4096;

/// <p>Rows one ledger read answers at most (AD-24's row cap, applied to a bounded read like any
/// other). The read asks its source for this many plus one and reports the truncation.</p>
Parameter LEDGERVIEWMAXROWS As %Integer = 200;

/// <p>Seconds one provider call may add to a turn, its retries and the sleeps between them
/// included (Story 4.8, AD-42). The turn's <b>declared</b> ceiling; the one actually enforced is
/// <parameter>OcuPilot.Kernel.Provider.Retry.ATTEMPTBUDGETSECONDS</parameter>, because
/// <package>OcuPilot.Kernel.Provider</package> is reached from Test connection as well as from a
/// turn and must not depend on a turn's limits. A test pins the two equal.</p>
/// <p>Its consequence, stated rather than left to be discovered: a turn may be observed for up to
/// <parameter>WALLCLOCKSECONDS</parameter> plus this, because the wall clock is checked
/// <i>before</i> a provider call and not during one -- and a lease that lapses during a call is
/// noticed at most this late, which is AD-31's "next step boundary" unchanged. That holds while the
/// stored <property>OcuPilot.Kernel.State.Egress.MaxAttempts</property> times the stored
/// <property>OcuPilot.Kernel.State.Egress.TimeoutSeconds</property> plus
/// <parameter>OcuPilot.Kernel.Provider.Retry.RETRYBUDGETSECONDS</parameter> is at or below this,
/// which the shipped defaults satisfy exactly. Neither stored value is bounded by anything else,
/// and the deadline gates when an attempt may <i>start</i>, so an attempt already in flight when it
/// passes still runs to its own timeout: <b>one call's true worst case is this plus the stored
/// <property>TimeoutSeconds</property></b>, whatever the attempt bound is.</p>
Parameter PROVIDERCALLSECONDS As %Integer = 300;

}
