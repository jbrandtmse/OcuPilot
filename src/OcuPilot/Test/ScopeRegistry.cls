/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor whose declared <code>scope</code> is outside the two values. Kept apart from
/// <class>OcuPilot.Test.BadRegistry</class> and <class>OcuPilot.Test.PairRegistry</class> so each
/// refusal is demonstrated on a roster that carries exactly the one fault it names.</p>
Class OcuPilot.Test.ScopeRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Scope."
}

}
