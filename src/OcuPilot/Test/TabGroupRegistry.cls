/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the two fixture
/// descriptors whose tab group leaves a gap in its positions (AD-5).</p>
Class OcuPilot.Test.TabGroupRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.TabGroup."
}

}
