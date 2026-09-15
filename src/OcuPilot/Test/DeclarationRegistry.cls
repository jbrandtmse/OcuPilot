/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor declaring an unknown top-level key. Kept apart from the other fixture registries so
/// the refusal is demonstrated on a roster that carries exactly the one fault it names (DW-306).</p>
Class OcuPilot.Test.DeclarationRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Declaration."
}

}
