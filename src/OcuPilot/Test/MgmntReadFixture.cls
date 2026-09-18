/// <p>Subclass of <class>OcuPilot.Screen.Read</class> whose <code>mgmnt</code> reads go through
/// <class>OcuPilot.Test.MgmntPortFixture</class>, so the executor's mgmnt branch -- the scope it
/// hands the port, the criteria it seeds and the document it carries -- is read off
/// <class>OcuPilot.Test.MgmntImplFixture</class>'s recorded calls.</p>
Class OcuPilot.Test.MgmntReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod MgmntPortClass() As %String
{
    Quit "OcuPilot.Test.MgmntPortFixture"
}

}
