/// <p>Narrowed limits for the navigation wait (Story 4.7, AC8): everything
/// <class>OcuPilot.Test.TurnLimits</class> narrows, plus <parameter>NAVWAITSECONDS</parameter> cut
/// to a couple of seconds so a lapse test does not wait out the shipped 60-second bound.</p>
Class OcuPilot.Test.TurnLimitsNav Extends OcuPilot.Test.TurnLimits
{

Parameter NAVWAITSECONDS As %Integer = 2;

/// <p>Wide enough for a scripted navigation call's model step, tool step and announce step to
/// all land -- <parameter>OcuPilot.Test.TurnLimits.MAXSTEPS</parameter>'s narrowed 2 is enough
/// for an ordinary two-call turn but drops the third (announce) step of a navigating one.</p>
Parameter MAXSTEPS As %Integer = 20;

/// <p>The shipped default, restored: <parameter>OcuPilot.Test.TurnLimits.SUMMARYMAXLENGTH</parameter>'s
/// narrowed 8 characters truncates a tool step's own canonical name ("shell.screen.open" to
/// "shell.sc"), which a navigation test needs to read back whole.</p>
Parameter SUMMARYMAXLENGTH As %Integer = 1000;

}
