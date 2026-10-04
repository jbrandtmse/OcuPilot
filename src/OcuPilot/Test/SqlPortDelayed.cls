/// <p><class>OcuPilot.Port.SqlPort</class> whose run waits half a second before it prepares, so a test
/// can cancel a background run whose job has begun but runs no statement yet. Its bound and everything
/// else are the production port's.</p>
Class OcuPilot.Test.SqlPortDelayed Extends OcuPilot.Port.SqlPort
{

/// <p>The seconds a run waits before the production run.</p>
Parameter DELAYSECONDS = 0.5;

ClassMethod Run(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, pMode As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Hang ..#DELAYSECONDS
    Quit ##super(pNamespace, pText, pValues, pMaxRows, pMode, .pAnswer, .pHttpStatus, .pFault)
}

}
