/// <p>A test port: <class>OcuPilot.Port.TaskPort</class> with a task create's
/// <code>DailyIncrement</code> set to <code>0</code> before it is sent, so the vendor refuses a body
/// the rules accepted (7404). Every other call is the task port's own. Used by
/// <class>OcuPilot.Test.TaskSaveSkew</class> only.</p>
Class OcuPilot.Test.TaskPortSkew Extends OcuPilot.Port.TaskPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#TASKENDPOINT) && (pType = ..#CREATETYPE) && $IsObject(pBody) Do pBody.%Set("DailyIncrement", "0", "string")
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

}
