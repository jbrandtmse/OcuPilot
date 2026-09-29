/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass that drives
/// <method>OcuPilot.Port.AdminPort.AwaitGone</method> with no session on the instance: its
/// <code>LIST</code> answers the rows <method>Arm</method> set, or fails when none are armed, and
/// counts each call; <method>LogFault</method> records each message and its status text instead of
/// logging them; and its
/// bound is <parameter>AWAITEDDELETEMS</parameter>, shortened so a still-listed row passes it
/// quickly. Every other request type is refused.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AwaitPort Extends OcuPilot.Port.AdminPort
{

Parameter AWAITEDDELETEMS As INTEGER = 600;

/// <p>Answer <var>pRowsJson</var>, a JSON array, to every <code>LIST</code> until the next call;
/// <code>""</code> makes every <code>LIST</code> fail. Clears the counts and the recorded log.</p>
ClassMethod Arm(pRowsJson As %String)
{
    Kill ^||OcuPilotAwaitPort
    Set ^||OcuPilotAwaitPort("rows") = pRowsJson
}

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pFault = ""
    Set ^||OcuPilotAwaitPort("lists") = $Get(^||OcuPilotAwaitPort("lists")) + (pType = "LIST")
    If (pType '= "LIST") || ($Get(^||OcuPilotAwaitPort("rows")) = "") {
        Set pHttpStatus = 500
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AwaitPort answers an armed LIST only")
    }
    Set pResult = ##class(%DynamicArray).%FromJSON(^||OcuPilotAwaitPort("rows"))
    Set pHttpStatus = 200
    Quit $$$OK
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotAwaitPort("logged") = $Get(^||OcuPilotAwaitPort("logged")) _ pMessage _ " | " _ $System.Status.GetErrorText(pStatus) _ $Char(10)
}

/// <p>Run the port's own wait for a <var>pEndpoint</var> <var>pSuffix</var> issued with
/// <var>pQuery</var>.</p>
ClassMethod Await(pEndpoint As %String, pSuffix As %String, ByRef pQuery)
{
    Do ..AwaitGone(pEndpoint, pSuffix, .pQuery)
}

/// <p>How many <code>LIST</code> calls were made since <method>Arm</method>.</p>
ClassMethod Lists() As %Integer
{
    Quit +$Get(^||OcuPilotAwaitPort("lists"))
}

/// <p>Every message <method>LogFault</method> recorded since <method>Arm</method>.</p>
ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotAwaitPort("logged"))
}

}
