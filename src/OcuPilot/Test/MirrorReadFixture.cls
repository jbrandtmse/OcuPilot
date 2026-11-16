/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>mirror</code> reads and banner go through
/// <class>OcuPilot.Test.MirrorPortFixture</class>, so the screen's read of an armed member, with its cap and its banner, is read
/// without a mirror on the instance.</p>
Class OcuPilot.Test.MirrorReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod MirrorPortClass() As %String
{
    Quit "OcuPilot.Test.MirrorPortFixture"
}

}
