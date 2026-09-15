/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose server-search criteria are outside the grammar. Kept apart from the other
/// fixture registries so each refusal is demonstrated on a roster that carries exactly the one
/// fault it names.</p>
Class OcuPilot.Test.CriteriaRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Criteria."
}

}
