/// <p><class>OcuPilot.Port.DocDbPort</class> with each log line it would write recorded as its code in
/// <code>^||OcuPilotDocDbLog</code> instead, so <class>OcuPilot.Test.DocDbPort</class> can read which
/// refusals the port logs (AD-2). Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DocDbLogSeam Extends OcuPilot.Port.DocDbPort
{

/// <p>Record the line's code in place of writing it to the log.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotDocDbLog($Increment(^||OcuPilotDocDbLog)) = pCode
}

}
