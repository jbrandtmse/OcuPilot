/// <p>Narrowed ledger bounds, so a test reaches the per-turn row cap and the argument cut in a
/// handful of writes rather than in two hundred. Every other bound keeps its shipped value.</p>
Class OcuPilot.Test.LedgerLimits Extends OcuPilot.Kernel.Agent.Limits
{

Parameter LEDGERMAXROWS As %Integer = 2;

Parameter LEDGERROWMAXLENGTH As %Integer = 24;

Parameter LEDGERVIEWMAXROWS As %Integer = 3;

}
