/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor declaring a classic link-out on a <code>list</code> archetype. Kept apart from
/// <class>OcuPilot.Test.ScreenRegistry</class> so the sound roster stays sound, and apart from
/// the other refusal registries so each is demonstrated on a roster carrying exactly the one
/// fault it names.</p>
Class OcuPilot.Test.ClassicLinkRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ClassicLink."
}

}
