/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>atelier</code> reads go through
/// <class>OcuPilot.Test.AtelierPortFixture</class>, so the executor's atelier branch -- the scope it
/// hands the port, the criteria and defaults it seeds and the document it carries -- is read off the
/// fixture's recorded calls.</p>
Class OcuPilot.Test.AtelierReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod AtelierPortClass() As %String
{
    Quit "OcuPilot.Test.AtelierPortFixture"
}

}
