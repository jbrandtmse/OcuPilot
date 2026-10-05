/// <p><class>OcuPilot.Port.DocDbPort</class> with its pair sets evaluated through
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares, so
/// <class>OcuPilot.Test.PortGate</class> drives the port's refusal in a process holding
/// <code>%All</code>. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DocDbGateSeam Extends OcuPilot.Port.DocDbPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

}
