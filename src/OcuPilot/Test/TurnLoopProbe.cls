/// <p>Test-only <class>OcuPilot.Kernel.Agent.Loop</class> subclass whose seams are switches, so the
/// loop runs in process with no socket: the port is <class>OcuPilot.Test.ProviderPortProbe</class>,
/// the limits are <class>OcuPilot.Test.TurnLimits</class> unless a test names others, the dispatcher
/// is the shipped one unless a test names another, and the restraint verdict is the real one unless
/// a test forces the kill switch on or the read to fail. No method of the loop itself is
/// replaced.</p>
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

/// <p>Answer the restraint read as failed from now on, with the verdict a failed read leaves:
/// neither the kill switch nor read-only on.</p>
ClassMethod ForceRestraintError()
{
    Set ^||OcuPilotTurnLoopProbe("restraintError") = 1
}

/// <p>Answer <var>pClass</var> as the dispatcher from now on; <code>""</code> restores the shipped
/// one.</p>
ClassMethod SetDispatchClass(pClass As %String)
{
    Set ^||OcuPilotTurnLoopProbe("dispatch") = pClass
}

/// <p>Answer <var>pClass</var> as the limits from now on; <code>""</code> restores
/// <class>OcuPilot.Test.TurnLimits</class>.</p>
ClassMethod SetLimitsClass(pClass As %String)
{
    Set ^||OcuPilotTurnLoopProbe("limits") = pClass
}

ClassMethod LimitsClass() As %String
{
    If $Get(^||OcuPilotTurnLoopProbe("limits")) '= "" Quit ^||OcuPilotTurnLoopProbe("limits")
    Quit "OcuPilot.Test.TurnLimits"
}

ClassMethod DispatchClass() As %String
{
    If $Get(^||OcuPilotTurnLoopProbe("dispatch")) '= "" Quit ^||OcuPilotTurnLoopProbe("dispatch")
    Quit ##super()
}

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProviderPortProbe"
}

/// <p>The real verdict, with the kill switch forced on or the read failed when a test asked for
/// it.</p>
ClassMethod Restraint(pUser As %String, Output pVerdict) As %Status
{
    If $Get(^||OcuPilotTurnLoopProbe("restraintError")) {
        Kill pVerdict
        Set pVerdict("blocked") = 1
        Set pVerdict("killSwitch") = 0
        Set pVerdict("enforcedReadOnly") = 0
        Quit $$$ERROR($$$GeneralError, "the probe answered the switches as unreadable")
    }
    Set tSC = ##super(pUser, .pVerdict)
    If $Get(^||OcuPilotTurnLoopProbe("killSwitch")) '= "" {
        Set pVerdict("killSwitch") = 1
        Set pVerdict("code") = ^||OcuPilotTurnLoopProbe("killSwitch")
    }
    Quit tSC
}

}
