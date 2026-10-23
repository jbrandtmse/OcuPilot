/// <p>Test-only <class>OcuPilot.Port.DatabasePort</class> subclass that finds no default database encryption key
/// whatever the instance holds, so the create's refusal of an encrypted database (Story 18.48) is driven without
/// depending on the instance's keys. Every other call is the database port's own.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseNoKeyPort Extends OcuPilot.Port.DatabasePort
{

ClassMethod DefaultKey(Output pKeyID As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKeyID = ""
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
