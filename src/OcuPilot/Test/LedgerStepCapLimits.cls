/// <p>Narrowed step cap, so the turn is at <parameter>MAXSTEPS</parameter> by the time a
/// client-fulfilled call tries to announce itself -- which is the only way to reach
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>'s drop branch without writing a
/// hundred steps first. One, because the tool step the caller appends before the call is the turn's
/// first and the announce step would be its second. Every other bound keeps its shipped value.</p>
Class OcuPilot.Test.LedgerStepCapLimits Extends OcuPilot.Kernel.Agent.Limits
{

Parameter MAXSTEPS As %Integer = 1;

}
