/// <p>Test-only <class>OcuPilot.Area.Security.SslSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class>: the fresh read
/// reaches the instance and the Save's <code>PUT</code> is recorded and never sent, so a leg over
/// OcuPilot's own provider configuration can reach the port without changing it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SslSaveHeldFixture Extends OcuPilot.Area.Security.SslSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
