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

ClassMethod StatementCall(pType As %String, pHash As %String, pNamespace As %String, pValues As %String = "") As %Status
{
    Set ^||OcuPilotSqlTuningCalls = $Get(^||OcuPilotSqlTuningCalls) + 1
    Set ^||OcuPilotSqlTuningStatement($Increment(^||OcuPilotSqlTuningStatement)) = pType _ "|" _ pValues
    If $Get(^||OcuPilotSqlTuningRefuse) '= "" Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningRefuse)
    If $Get(^||OcuPilotSqlTuningRaise) '= "" Throw ##class(%Exception.General).%New("StatementCallRaised", 5001, , "the statement call raised")
    Quit ##super(pType, pHash, pNamespace, pValues)
}

/// <p>The table writes' seam (Story 21.25), counted and refused as <method>StatementCall</method> is, and recording the type and values of each call
/// as <code>type|values</code> for <method>OcuPilot.Test.SqlTuningGateSeam.TableCalls</method>.</p>
ClassMethod TableCall(pType As %String, pTarget As %String, pValues As %String, pNamespace As %String, Output pFixed As %Boolean) As %Status
{
    Set pFixed = 0
    Set ^||OcuPilotSqlTuningTable($Increment(^||OcuPilotSqlTuningTable)) = pType _ "|" _ pValues
    Set ^||OcuPilotSqlTuningCalls = $Get(^||OcuPilotSqlTuningCalls) + 1
    If $Get(^||OcuPilotSqlTuningRefuse) '= "" Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningRefuse)
    If ($Get(^||OcuPilotSqlTuningBadMap) '= "") && (pType = ..#TYPESETMAPSIZE) {
        Set tValues = ##class(%DynamicObject).%FromJSON(pValues)
        Do tValues.%Set("Map", "NoSuchMap", "string")
        Set pValues = tValues.%ToJSON()
    }
    If $Get(^||OcuPilotSqlTuningThrow) '= "" Set ^||OcuPilotSqlTuningInCall = 1
    Set tStatus = ##super(pType, pTarget, pValues, pNamespace, .pFixed)
    Kill ^||OcuPilotSqlTuningInCall
    Quit tStatus
}

/// <p>The field's read, which raises while a table call runs where <method>OcuPilot.Test.SqlTuningGateSeam.Throw</method> armed it: the one read a
/// selectivity's setter makes inside its guarded block, after the collected statistics were saved.</p>
ClassMethod FieldRead(pSchema As %String, pTable As %String, pField As %String, Output pRow As %DynamicObject) As %Status [ Private ]
{
    If $Get(^||OcuPilotSqlTuningInCall) Throw ##class(%Exception.General).%New("SetterRaised", 5001, , "the setter raised")
    Quit ##super(pSchema, pTable, pField, .pRow)
}

}
