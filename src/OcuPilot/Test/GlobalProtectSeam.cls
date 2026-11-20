/// <p><class>OcuPilot.Port.GlobalPort</class> whose writes fail as the instance fails a caller without WRITE on the database: a
/// <code>&lt;PROTECT&gt;</code>. <class>OcuPilot.Test.GlobalWrite</class> reads the port's answer to it without writing a protected global. Nothing else
/// differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalProtectSeam Extends OcuPilot.Port.GlobalPort
{

ClassMethod VendorSet(pNamespace As %String, pReference As %String, pValue As %String, Output pCaught)
{
    Set pCaught = ##class(%Exception.General).%New("<PROTECT>", 202, "", pReference)
}

ClassMethod VendorKillNode(pNamespace As %String, pReference As %String, Output pCaught)
{
    Set pCaught = ##class(%Exception.General).%New("<PROTECT>", 202, "", pReference)
}

ClassMethod VendorKillGlobal(pNamespace As %String, pName As %String, Output pCaught)
{
    Set pCaught = ##class(%Exception.General).%New("<PROTECT>", 202, "", pName)
}

}
