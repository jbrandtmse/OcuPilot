/// <p><class>OcuPilot.Test.SmokeWriteProbe</class> with the ownership answer AD-25 gives a fixture
/// this install did not create: the one state in which the shipped check must <code>skip</code>
/// rather than write (Story 5.8). It names the same application and never reaches it.</p>
Class OcuPilot.Test.SmokeUnownedProbe Extends OcuPilot.Test.SmokeWriteProbe
{

ClassMethod WriteTargetOwned() As %Boolean
{
    Quit 0
}

}
