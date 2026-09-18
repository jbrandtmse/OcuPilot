/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the two fixture
/// descriptors whose parent is declared at the named route but not built (Story 6.6,
/// DW-1020).</p>
Class OcuPilot.Test.ParentScopeNotBuiltRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ParentScope.NotBuilt."
}

}
