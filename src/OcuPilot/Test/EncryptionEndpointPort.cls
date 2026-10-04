/// <p>Test-only <class>OcuPilot.Port.EncryptionPort</class> subclass for Story 18.7's raw-file legs: every
/// endpoint resolves to <class>OcuPilot.Test.EndpointFixture</class>, so a call that passes the port's own
/// guards builds that fixture and never a vendor endpoint.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionEndpointPort Extends OcuPilot.Port.EncryptionPort
{

ClassMethod EndpointClass(pEndpoint As %String) As %String
{
    Quit "OcuPilot.Test.EndpointFixture"
}

}
