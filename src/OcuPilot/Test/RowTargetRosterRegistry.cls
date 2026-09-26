/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>rowTarget.route</code> resolves to nothing (AD-5, Story 6.10).</p>
Class OcuPilot.Test.RowTargetRosterRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.RowTargetRoster."
}

}
