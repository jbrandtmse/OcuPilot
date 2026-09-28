/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>logsource</code> reads go through
/// <class>OcuPilot.Test.LogSourceFixture</class>, so <class>OcuPilot.Test.LogSource</class> observes
/// the executor carry the port's own cut into <code>truncated</code> over a scratch file.</p>
Class OcuPilot.Test.LogSourceReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod LogSourcePortClass() As %String
{
    Quit "OcuPilot.Test.LogSourceFixture"
}

}
