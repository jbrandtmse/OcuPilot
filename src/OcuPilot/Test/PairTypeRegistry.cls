/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose declared privilege pair carries a half that is not a string. Kept apart from
/// <class>OcuPilot.Test.PairRegistry</class> so each refusal is demonstrated on a roster that
/// carries exactly the one fault it names.</p>
Class OcuPilot.Test.PairTypeRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.PairType."
}

}
