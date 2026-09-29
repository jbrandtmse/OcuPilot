/// <p>Test-only <class>OcuPilot.Test.DatabaseRecordPort</class> that sends no write: every mutating
/// call is recorded and answered 200, and every read reaches the instance (Story 18.3). The protected
/// database legs write through it, so a removed predicate shows as a recorded write and never as a
/// deleted or changed database.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseAcceptPort Extends OcuPilot.Test.DatabaseRecordPort
{

ClassMethod Accepts() As %Boolean
{
    Quit 1
}

}
