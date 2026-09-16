/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor that names an entity type the kernel enum does not hold. Kept in a package of
/// its own so <class>OcuPilot.Test.ScreenRegistry</class>'s roster stays valid and the two
/// halves -- "a sound roster validates" and "an unsound one is refused" -- cannot pass for each
/// other.</p>
Class OcuPilot.Test.BadRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Bad."
}

}
