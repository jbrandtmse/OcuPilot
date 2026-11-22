/// <p><class>OcuPilot.Port.SqlPort</class> with its two seams in a test's hands (Story 21.6): the gate is
/// <class>OcuPilot.Test.SqlTuningGateSeam</class>, which records the pair sets it is asked and refuses the permission a test armed, and
/// <method>StatementCall</method> counts each call and, where armed, answers an error status with its message instead of calling the instance.
/// Without either armed, the call is the production port's. Everything else is the production port's.</p>
Class OcuPilot.Test.SqlTuningPortFixture Extends OcuPilot.Port.SqlPort
{

Parameter GATE = "OcuPilot.Test.SqlTuningGateSeam";

ClassMethod GateClass() As %String
{
    Quit ..#GATE
}

ClassMethod StatementCall(pType As %String, pHash As %String) As %Status
{
    Set ^||OcuPilotSqlTuningCalls = $Get(^||OcuPilotSqlTuningCalls) + 1
    If $Get(^||OcuPilotSqlTuningRefuse) '= "" Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningRefuse)
    Quit ##super(pType, pHash)
}

}
