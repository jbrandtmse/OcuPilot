/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>parentScope</code> names a route nothing in the package declares
/// (Story 6.6, DW-1020).</p>
Class OcuPilot.Test.ParentScopeNotFoundRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ParentScope.NotFound."
}

}
