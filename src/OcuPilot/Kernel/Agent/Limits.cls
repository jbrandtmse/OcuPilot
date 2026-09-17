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

}
