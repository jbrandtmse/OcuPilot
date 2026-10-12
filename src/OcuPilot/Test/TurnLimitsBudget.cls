/// <p>Narrowed limits for the turn's tool-result budget (Story 18.39): everything
/// <class>OcuPilot.Test.TurnLimitsNav</class> restores, a reply budget of 6,000 characters inside a
/// turn budget of 9,000, four provider calls and a token limit no scripted turn reaches -- so three
/// replies of about 5,500 characters each are answered in full, cut to what the turn has left, and
/// refused <code>TOOL.RESULTTOOLARGE</code>.</p>
Class OcuPilot.Test.TurnLimitsBudget Extends OcuPilot.Test.TurnLimitsNav
{

Parameter MAXITERATIONS As %Integer = 4;

Parameter MAXTOKENS As %Integer = 500000;

Parameter TOOLRESULTMAXLENGTH As %Integer = 6000;

Parameter TURNRESULTMAXLENGTH As %Integer = 9000;

}
