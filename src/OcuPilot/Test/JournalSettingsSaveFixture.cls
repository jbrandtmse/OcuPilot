/// <p>Test-only <class>OcuPilot.Area.OsMgmt.JournalSave</class> whose one replaced seam is
/// <method>PortClass</method>: <class>OcuPilot.Test.JournalSettingsPort</class>, so the Save's fresh
/// read and write are recorded and sent on. Its route handler runs in the calling process, so a test
/// reads the record.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalSettingsSaveFixture Extends OcuPilot.Area.OsMgmt.JournalSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.JournalSettingsPort"
}

}
