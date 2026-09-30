/// <p>Test-only <class>OcuPilot.Area.OsMgmt.DatabaseRules</class> subclass whose
/// <method>PortClass</method> answers the port a test names in <code>^||OcuPilotDatabaseRulesPort</code>,
/// and the tools' own port when none is named, so a Save's rules read the same armed state its write
/// does (<class>OcuPilot.Test.DatabaseSaveFixture</class> declares it as its rules).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseRulesFixture Extends OcuPilot.Area.OsMgmt.DatabaseRules
{

ClassMethod PortClass() As %String
{
    Set tArmed = $Get(^||OcuPilotDatabaseRulesPort)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

}
