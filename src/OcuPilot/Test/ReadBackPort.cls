/// <p>Test-only port for <class>OcuPilot.Test.ReadBack</class>: every call is answered from
/// <code>^||OcuPilotReadBackPort</code> without reaching the vendor -- <code>("status")</code> the
/// HTTP status (200 when unset) and <code>("body")</code> the JSON the read answers -- and its
/// request type is recorded under <code>("types", n)</code>.</p>
/// <p><b>Nothing this class receives changes the instance.</b> Not a
/// <class>%UnitTest.TestCase</class>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ReadBackPort Extends %RegisteredObject
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotReadBackPort("types", $Increment(^||OcuPilotReadBackPort("types"))) = pType
    Set pResult = ""
    Set pFault = ""
    Set pHttpStatus = +$Get(^||OcuPilotReadBackPort("status"), 200)
    If pHttpStatus >= 300 {
        Set tCode = $Select(pHttpStatus = 404: ##class(OcuPilot.Api.Error).#PORTNOTFOUND, 1: ##class(OcuPilot.Api.Error).#INTERNAL)
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, tCode, "OcuPilot.Test.ReadBackPort answers this status.")
        Quit $$$ERROR($$$GeneralError, tCode)
    }
    Set tBody = $Get(^||OcuPilotReadBackPort("body"))
    If tBody '= "" Set pResult = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Quit $$$OK
}

/// <p>Arm the next answers: <var>pStatus</var> and the JSON <var>pBody</var>.</p>
ClassMethod Arm(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotReadBackPort
    Set ^||OcuPilotReadBackPort("status") = pStatus
    Set ^||OcuPilotReadBackPort("body") = pBody
}

/// <p>Forget every armed answer and recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotReadBackPort
}

}
