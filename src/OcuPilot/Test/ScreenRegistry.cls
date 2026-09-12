/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the fixture
/// descriptor package. The production roster holds exactly one real screen -- Home, whose page
/// is Story 1.12's -- so it cannot demonstrate the three awkward declaration forms the
/// mechanism has to express; this registry enumerates the fixtures that do, and the production
/// roster stays what the shell actually serves.</p>
/// <p>The fixture package holds no base class of its own, so the inherited base-class
/// exclusion simply never matches there.</p>
Class OcuPilot.Test.ScreenRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Screen."
}

}
