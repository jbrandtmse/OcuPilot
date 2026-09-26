/// <p>Narrowed navigation wait, so a client-fulfilled call no browser answers lapses on its first
/// pass rather than after a minute. Zero rather than one: the lapse check is
/// <code>elapsed &gt;= limit</code>, so zero makes the first pass the last one. Every other bound
/// keeps its shipped value.</p>
Class OcuPilot.Test.LedgerNavWaitLimits Extends OcuPilot.Kernel.Agent.Limits
{

Parameter NAVWAITSECONDS As %Integer = 0;

}
