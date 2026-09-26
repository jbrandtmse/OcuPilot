/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose <code>parentScope</code> names its own route (Story 6.6, review pass 1,
/// DW-1020).</p>
Class OcuPilot.Test.ParentScopeSelfRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ParentScope.Self."
}

}
