/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>devtool</code> reads go through
/// <class>OcuPilot.Test.DevToolPortFixture</class>, so the executor's devtool branch is driven over the fixture's
/// armed gate, document cap and recorded calls.</p>
Class OcuPilot.Test.DevToolReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod DevToolPortClass() As %String
{
    Quit "OcuPilot.Test.DevToolPortFixture"
}

}
