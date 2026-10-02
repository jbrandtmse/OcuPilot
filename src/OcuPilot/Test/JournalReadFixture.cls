/// <p>The declared-read executor over <class>OcuPilot.Test.JournalCountPort</class>, so a test can
/// count the vendor calls a journal screen's read makes (Story 18.5). Every other seam is the
/// executor's own.</p>
Class OcuPilot.Test.JournalReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.JournalCountPort"
}

}
