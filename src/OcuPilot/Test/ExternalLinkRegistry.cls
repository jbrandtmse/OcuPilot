/// <p>Test-only <class>OcuPilot.Screen.Registry</class> subclass pointed at <class>OcuPilot.Test.ExternalLink.Doctored</class>, the one
/// fixture descriptor whose declaration a test arms, so each refusal of an <code>external</code> screen (AD-44, Story 20.32) is
/// demonstrated on a roster carrying exactly the one fault it names.</p>
Class OcuPilot.Test.ExternalLinkRegistry Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.ExternalLink."
}

}
