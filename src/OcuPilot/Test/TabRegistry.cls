/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>tab</code> is outside the grammar (AD-5).</p>
Class OcuPilot.Test.TabRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Tab."
}

}
