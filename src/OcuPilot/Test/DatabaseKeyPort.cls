/// <p>Test-only <class>OcuPilot.Port.DatabasePort</class> subclass that finds <parameter>KEYID</parameter> as the default
/// database encryption key whatever the instance holds, so the create's encrypted script (Story 18.48) is drawn without
/// depending on the instance's keys. Every other call is the database port's own.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseKeyPort Extends OcuPilot.Port.DatabasePort
{

Parameter KEYID = "DRAFTKEY1";

ClassMethod DefaultKey(Output pKeyID As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKeyID = ..#KEYID
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
