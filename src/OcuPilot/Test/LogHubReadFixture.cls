/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>timeline</code> reads compose
/// through <class>OcuPilot.Test.LogHubFixture</class>, so <class>OcuPilot.Test.LogHub</class> can
/// observe what the executor does before and after the composition.</p>
Class OcuPilot.Test.LogHubReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod TimelineClass() As %String
{
    Quit "OcuPilot.Test.LogHubFixture"
}

}
