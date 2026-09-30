/// <p>Test-only <class>OcuPilot.Area.OsMgmt.DatabaseSave</class> subclass with two replaced seams:
/// <method>PortClass</method> answers the port a test names in <code>^||OcuPilotDatabaseWritePort</code>,
/// and <class>OcuPilot.Test.DatabaseAcceptPort</class>, which writes nothing, when none is named; and
/// <method>ProhibitedClass</method> answers the class a test names in
/// <code>^||OcuPilotDatabaseProhibited</code>, and the shipped set otherwise. The rules are
/// <class>OcuPilot.Test.DatabaseRulesFixture</class>, whose reads go through the tools' own port unless
/// <code>^||OcuPilotDatabaseRulesPort</code> names another; the prohibited set's target read is not a
/// seam.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseSaveFixture Extends OcuPilot.Area.OsMgmt.DatabaseSave
{

Parameter RULES = "OcuPilot.Test.DatabaseRulesFixture";

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.DatabaseAcceptPort")
}

ClassMethod ProhibitedClass() As %String
{
    Set tArmed = $Get(^||OcuPilotDatabaseProhibited)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

}
