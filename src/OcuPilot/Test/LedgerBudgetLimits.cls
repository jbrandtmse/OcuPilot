/// <p>Narrowed reply budget, so <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> refuses a
/// call before dispatch in one write rather than after a full turn's worth of results. Every other
/// bound keeps its shipped value -- in particular <parameter>LEDGERROWMAXLENGTH</parameter>, so a
/// declared secret's absence from the stored row is redaction's work and not the argument cut's.</p>
Class OcuPilot.Test.LedgerBudgetLimits Extends OcuPilot.Kernel.Agent.Limits
{

Parameter TOOLRESULTMAXLENGTH As %Integer = 100;

}
