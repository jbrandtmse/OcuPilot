/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the read fixtures:
/// two read-declaring descriptors and one that declares no read.</p>
Class OcuPilot.Test.Read.Registry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Read."
}

}
