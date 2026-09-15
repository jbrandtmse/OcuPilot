/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose declared privilege pair is missing a half. Kept apart from
/// <class>OcuPilot.Test.BadRegistry</class> so each refusal is demonstrated on a roster that
/// carries exactly the one fault it names.</p>
Class OcuPilot.Test.PairRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Pair."
}

}
