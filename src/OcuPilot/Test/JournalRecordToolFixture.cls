/// <p>Test-only <class>OcuPilot.Screen.Tool.Read</class> subclass reading through
/// <class>OcuPilot.Test.JournalReadFixture</class>, so a test can count the vendor calls the read tool
/// makes for a journal screen (Story 18.19).</p>
Class OcuPilot.Test.JournalRecordToolFixture Extends OcuPilot.Screen.Tool.Read [ Abstract ]
{

ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Test.JournalReadFixture"
}

}
