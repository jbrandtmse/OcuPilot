/// <p><class>OcuPilot.Test.TurnLimitsNav</class> with the step cap back down to 2, so a navigating
/// turn's model and tool steps are stored and its <code>announce</code> step is dropped past the
/// cap -- the one state in which no reader can ever see the announcement, and the directive must
/// therefore lapse rather than be requested.</p>
Class OcuPilot.Test.TurnLimitsNavCapped Extends OcuPilot.Test.TurnLimitsNav
{

Parameter MAXSTEPS As %Integer = 2;

}
