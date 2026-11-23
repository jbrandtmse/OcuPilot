/// <p><class>OcuPilot.Port.SqlPort</class> with its seams in a test's hands (Stories 21.6 and 21.25): the gate is
/// <class>OcuPilot.Test.SqlTuningGateSeam</class>, which records the pair sets it is asked and refuses the permission a test armed, and
/// <method>StatementCall</method> and <method>TableCall</method> count each call and, where armed, answer an error status with its message instead of
/// calling the instance.
/// Without either armed, the call is the production port's. Everything else is the production port's.</p>
Class OcuPilot.Test.SqlTuningPortFixture Extends OcuPilot.Port.SqlPort
{

Parameter GATE = "OcuPilot.Test.SqlTuningGateSeam";

ClassMethod GateClass() As %String
{
    Quit ..#GATE
}

ClassMethod StatementCall(pType As %String, pHash As %String, pNamespace As %String) As %Status
{
    Set ^||OcuPilotSqlTuningCalls = $Get(^||OcuPilotSqlTuningCalls) + 1
    If $Get(^||OcuPilotSqlTuningRefuse) '= "" Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningRefuse)
    Quit ##super(pType, pHash, pNamespace)
}

/// <p>The table writes' seam (Story 21.25), counted and refused as <method>StatementCall</method> is.</p>
ClassMethod TableCall(pType As %String, pTarget As %String, pValues As %String, pNamespace As %String) As %Status
{
    Set ^||OcuPilotSqlTuningCalls = $Get(^||OcuPilotSqlTuningCalls) + 1
    If $Get(^||OcuPilotSqlTuningRefuse) '= "" Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningRefuse)
    Quit ##super(pType, pTarget, pValues, pNamespace)
}

}
