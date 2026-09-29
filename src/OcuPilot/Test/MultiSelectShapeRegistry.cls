/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>multiSelect</code> is outside the grammar (AD-5, Story 16.6).</p>
Class OcuPilot.Test.MultiSelectShapeRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.MultiSelectShape."
}

}
