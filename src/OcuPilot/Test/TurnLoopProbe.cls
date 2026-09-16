/// <p>Test-only <class>OcuPilot.Kernel.Agent.Loop</class> subclass whose seams are switches, so the
/// loop runs in process with no socket: the port is <class>OcuPilot.Test.ProviderPortProbe</class>,
/// the limits are <class>OcuPilot.Test.TurnLimits</class>, and the restraint verdict is the real one unless a test forces the kill switch on. No method of
/// the loop itself is replaced.</p>
Class OcuPilot.Test.TurnLoopProbe Extends OcuPilot.Kernel.Agent.Loop
{

/// <p>Forget every switch.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotTurnLoopProbe
}

/// <p>Answer the kill switch on, with <var>pCode</var> as its code, from now on.</p>
ClassMethod ForceKillSwitch(pCode As %String)
{
    Set ^||OcuPilotTurnLoopProbe("killSwitch") = pCode
}

ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Test.TurnLimits"
}

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProviderPortProbe"
}

/// <p>The real verdict, with the kill switch forced on when a test asked for it.</p>
ClassMethod Restraint(pUser As %String, Output pVerdict) As %Status
{
    Set tSC = ##super(pUser, .pVerdict)
    If $Get(^||OcuPilotTurnLoopProbe("killSwitch")) '= "" {
        Set pVerdict("killSwitch") = 1
        Set pVerdict("code") = ^||OcuPilotTurnLoopProbe("killSwitch")
    }
    Quit tSC
}

}
