/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor that declares an own privilege pair its privileges do not carry. Kept apart from
/// <class>OcuPilot.Test.AreaPairRegistry</class> so each refusal is demonstrated on a roster that
/// carries exactly the one fault it names.</p>
Class OcuPilot.Test.OwnPairRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.OwnPair."
}

}
