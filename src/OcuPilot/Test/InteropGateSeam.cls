/// <p><class>OcuPilot.Port.InteropPort</class> with its pair sets evaluated through
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares, so
/// <class>OcuPilot.Test.PortGate</class> and <class>OcuPilot.Test.InteropGate</class> drive the port's
/// refusal in a process holding <code>%All</code>. <method>StopSeconds</method> is shortened by
/// <method>Shorten</method> so a test observes a busy production refused without waiting the full cap.
/// Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropGateSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>Wait <var>pSeconds</var> in a stop, restart or update until <method>Restore</method>; a value of
/// zero or less restores the shipped cap.</p>
ClassMethod Shorten(pSeconds As %Integer)
{
    If +pSeconds > 0 {
        Set ^||OcuPilotInteropStopSeconds = +pSeconds
    } Else {
        Kill ^||OcuPilotInteropStopSeconds
    }
}

/// <p>The shipped cap again.</p>
ClassMethod Restore()
{
    Kill ^||OcuPilotInteropStopSeconds
}

ClassMethod StopSeconds() As %Integer
{
    Quit $Get(^||OcuPilotInteropStopSeconds, ##super())
}

}
