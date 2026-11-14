/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor that declares as its own a pair its area already declares. Kept apart from
/// <class>OcuPilot.Test.OwnPairRegistry</class> so each refusal is demonstrated on a roster that
/// carries exactly the one fault it names.</p>
Class OcuPilot.Test.OwnPairAreaRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.OwnPairArea."
}

}
