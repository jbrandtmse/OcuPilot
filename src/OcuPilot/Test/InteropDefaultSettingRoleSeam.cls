/// <p><class>OcuPilot.Test.InteropGateSeam</class> (the pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>) with
/// <method>OcuPilot.Port.InteropPort.HoldsAllRole</method> answered by a test, so <class>OcuPilot.Test.InteropDefaultSettingRefusals</class>
/// drives the per-setting rules for a caller who holds the <code>%All</code> role and one who does not, in a process that holds it either
/// way (Story 24.15). <method>Arm</method> declares the answer and <method>Disarm</method> restores the shipped one; nothing else differs
/// from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropDefaultSettingRoleSeam Extends OcuPilot.Test.InteropGateSeam
{

/// <p>Answer <var>pHoldsAll</var> from <method>HoldsAllRole</method> until <method>Disarm</method>.</p>
ClassMethod Arm(pHoldsAll As %Boolean)
{
    Set ^||OcuPilotDefaultSettingHoldsAll = ''pHoldsAll
}

/// <p>The shipped answer again.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotDefaultSettingHoldsAll
}

ClassMethod HoldsAllRole() As %Boolean
{
    Quit $Get(^||OcuPilotDefaultSettingHoldsAll, ##super())
}

}
