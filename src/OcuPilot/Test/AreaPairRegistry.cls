/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose privilege set names a pair its area does not declare. Kept apart from
/// <class>OcuPilot.Test.PairRegistry</class> so each refusal is demonstrated on a roster that
/// carries exactly the one fault it names.</p>
Class OcuPilot.Test.AreaPairRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.AreaPair."
}

}
