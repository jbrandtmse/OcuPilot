/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the two fixture
/// descriptors whose parent is declared and built at the named route but carries no id (Story
/// 6.6, DW-1020).</p>
Class OcuPilot.Test.ParentScopeNoIdRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ParentScope.NoId."
}

}
