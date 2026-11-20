/// <p><class>OcuPilot.Port.GlobalPort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares, so
/// <class>OcuPilot.Test.GlobalRead</class> drives the port's refusal in a process holding <code>%All</code>. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalGateSeam Extends OcuPilot.Port.GlobalPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

}
