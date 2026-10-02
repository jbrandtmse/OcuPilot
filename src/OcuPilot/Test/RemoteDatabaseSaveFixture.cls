/// <p>Test-only <class>OcuPilot.Area.OsMgmt.RemoteDatabaseSave</class> subclass with two replaced
/// seams: <method>PortClass</method> answers the port a test names in
/// <code>^||OcuPilotDatabaseWritePort</code>, and <class>OcuPilot.Test.RemoteDatabaseListingPort</class>
/// when none is named, so a Save's fresh read and write are recorded and its listing is the seam's; and
/// <method>ProhibitedClass</method> answers the class a test names in
/// <code>^||OcuPilotDatabaseProhibited</code>, and the shipped set otherwise. Its rules are
/// <class>OcuPilot.Test.RemoteDatabaseRulesFixture</class>, whose reads go to the same port, so a rule's
/// vendor read is recorded as the write's are.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseSaveFixture Extends OcuPilot.Area.OsMgmt.RemoteDatabaseSave
{

Parameter RULES = "OcuPilot.Test.RemoteDatabaseRulesFixture";

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.RemoteDatabaseListingPort")
}

ClassMethod ProhibitedClass() As %String
{
    Set tArmed = $Get(^||OcuPilotDatabaseProhibited)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

}
