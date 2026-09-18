/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at three fixture
/// descriptors whose <code>parentScope</code> declarations are all sound (Story 6.6, DW-1020):
/// one resolving, one empty and not checked, and the parent itself.</p>
Class OcuPilot.Test.ParentScopeSoundRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ParentScope.Sound."
}

}
