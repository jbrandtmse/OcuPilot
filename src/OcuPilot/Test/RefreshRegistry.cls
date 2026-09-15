/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at the one fixture
/// descriptor declaring rates on a screen that does not refresh. Kept apart from
/// <class>OcuPilot.Test.ScreenRegistry</class> so the sound roster stays sound, and apart from
/// the other refusal registries so each is demonstrated on a roster carrying exactly the one
/// fault it names.</p>
Class OcuPilot.Test.RefreshRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.Refresh."
}

}
