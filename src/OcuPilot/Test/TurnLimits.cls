/// <p>Narrowed turn limits, so a test reaches the step cap, the field caps, the token limit and the
/// iteration ceiling in one or two provider calls. The wall clock, the lease, retention, the message
/// length and the queued limit keep the shipped values; tests reach those by ageing the stored
/// timestamps instead.</p>
Class OcuPilot.Test.TurnLimits Extends OcuPilot.Kernel.Agent.Limits
{

Parameter MAXITERATIONS As %Integer = 2;

Parameter MAXTOKENS As %Integer = 3;

Parameter MAXSTEPS As %Integer = 2;

Parameter SUMMARYMAXLENGTH As %Integer = 8;

Parameter TEXTMAXLENGTH As %Integer = 16;

}
