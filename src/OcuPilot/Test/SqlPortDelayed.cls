/// <p><class>OcuPilot.Port.SqlPort</class> whose run waits a second before it prepares, so a test can
/// cancel a background run whose job has begun but runs no statement yet. Its bound and everything
/// else are the production port's.</p>
Class OcuPilot.Test.SqlPortDelayed Extends OcuPilot.Port.SqlPort
{

/// <p>The seconds a run waits before the production run: long enough that a cancel sent once the run
/// has begun lands in the wait, and short of <parameter>OcuPilot.Area.Explorer.SqlBackground.CANCELTRIES</parameter>
/// times <parameter>OcuPilot.Area.Explorer.SqlBackground.CANCELPAUSE</parameter>.</p>
Parameter DELAYSECONDS = 1;

ClassMethod Run(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, pMode As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Hang ..#DELAYSECONDS
    Quit ##super(pNamespace, pText, pValues, pMaxRows, pMode, .pAnswer, .pHttpStatus, .pFault)
}

}
