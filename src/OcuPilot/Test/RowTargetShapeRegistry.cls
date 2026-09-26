/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>rowTarget</code> is outside the grammar (AD-5, Story 6.10).</p>
Class OcuPilot.Test.RowTargetShapeRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.RowTargetShape."
}

}
