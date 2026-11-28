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
    If (pType = ..#TYPESAVEQUERY) && ($Get(^||OcuPilotSqlTuningLeaveRow) '= "") {
        Set tSaved = ##super(pType, pHash, pNamespace, pValues)
        Set ^||OcuPilotSqlTuningLeaveRow("left") = $ListLength(##class(OcuPilot.Test.SqlTuningProbe).ReportIds(pNamespace))
        Quit $$$ERROR($$$GeneralError, ^||OcuPilotSqlTuningLeaveRow)
    }
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

/// <p>The index analysis vendor call (Story 21.27), recorded as <code>method(arguments)</code>, in order, in <code>^||OcuPilotSqlTuningVendor</code> while
/// <code>^||OcuPilotSqlTuningVendorArmed</code> is set, and then answered <code>$$$OK</code> without calling the instance, or an error status for the method
/// <code>^||OcuPilotSqlTuningVendorFail</code> names; the production call otherwise.</p>
ClassMethod AnalysisVendor(pNamespace As %String, pMethod As %String, pArgs...) As %Status [ Private ]
{
    If '$Get(^||OcuPilotSqlTuningVendorArmed) Quit ##super(pNamespace, pMethod, pArgs...)
    Set tText = ""
    For tIndex = 1:1:pArgs Set tText = tText _ $Select(tIndex > 1: ",", 1: "") _ pArgs(tIndex)
    Set ^||OcuPilotSqlTuningVendor($Increment(^||OcuPilotSqlTuningVendor)) = pMethod _ "(" _ tText _ ")"
    If $Get(^||OcuPilotSqlTuningVendorFail) = pMethod Quit $$$ERROR($$$GeneralError, "the vendor's " _ pMethod _ " failed")
    Quit $$$OK
}

/// <p>The advice's class: the one <code>^||OcuPilotSqlTuningAdvisor</code> names where a test set it, else the production port's.</p>
ClassMethod AdvisorClass() As %String
{
    Quit $Get(^||OcuPilotSqlTuningAdvisor, ##super())
}

/// <p>One checked read of the fixed text <var>pText</var> a test supplies, with the tables <var>pTables</var> a refusal would name: the port's
/// <method>CheckedRows</method> with no value bound and one row. Its status and fault are the port's.</p>
ClassMethod RowsOf(pNamespace As %String, pText As %String, pTables As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..CheckedRows(pNamespace, pText, [], 1, "a probe read", pTables, .tRows, .pHttpStatus, .pFault)
}

/// <p>The same for the port's <method>CheckedRow</method>.</p>
ClassMethod RowOf(pNamespace As %String, pText As %String, pTables As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..CheckedRow(pNamespace, pText, 0, "a probe read", pTables, .tRow, .pHttpStatus, .pFault)
}

/// <p>The privilege refusal the port answers for <var>pTables</var>.</p>
ClassMethod RefusalOf(pTables As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..SelectRefusal(pTables, .pHttpStatus, .pFault)
}

/// <p>A procedure whose call answers the SQLCODE <var>pCode</var> at execute, after a prepare that succeeds:
/// <code>CALL OcuPilot_Test.OcuProbe2127Code(-99)</code>.</p>
ClassMethod AnswerCode(pCode As %Integer) [ SqlName = OcuProbe2127Code, SqlProc ]
{
    Set %sqlcontext.%SQLCODE = pCode
    Set %sqlcontext.%Message = "probe " _ pCode
}

/// <p>The field's read, which raises while a table call runs where <method>OcuPilot.Test.SqlTuningGateSeam.Throw</method> armed it: the one read a
/// selectivity's setter makes inside its guarded block, after the collected statistics were saved.</p>
ClassMethod FieldRead(pSchema As %String, pTable As %String, pField As %String, Output pRow As %DynamicObject) As %Status [ Private ]
{
    If $Get(^||OcuPilotSqlTuningInCall) Throw ##class(%Exception.General).%New("SetterRaised", 5001, , "the setter raised")
    Quit ##super(pSchema, pTable, pField, .pRow)
}

}
