/// <p>Test-only <class>OcuPilot.Port.OAuthClientPort</class> subclass with one replaced seam: the
/// private <method>Vendor</method> answers a request type armed with <method>Arm</method> the way the
/// admin port answers a vendor refusal at that status, without calling the vendor, and counts each
/// such answer; every other call goes to the shipped port's own. It lets a test drive the port's and
/// the Save's handling of a vendor refusal the instance cannot be made to give on demand. The arming
/// is process-private and lasts until <method>Disarm</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthClientFailPort Extends OcuPilot.Port.OAuthClientPort
{

/// <p>Answer every later <var>pType</var> call as a vendor refusal at HTTP <var>pHttp</var>.</p>
ClassMethod Arm(pType As %String, pHttp As %Integer)
{
    Set ^||OcuPilotOAuthClientFail(pType) = pHttp
}

/// <p>Forget every armed type and every count.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotOAuthClientFail, ^||OcuPilotOAuthClientFailCount
}

/// <p>How many <var>pType</var> calls were answered as a refusal since <method>Disarm</method>.</p>
ClassMethod Reached(pType As %String) As %Integer
{
    Quit +$Get(^||OcuPilotOAuthClientFailCount(pType))
}

ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tHttp = $Get(^||OcuPilotOAuthClientFail(pType))
    If tHttp = "" Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotOAuthClientFailCount(pType) = $Get(^||OcuPilotOAuthClientFailCount(pType)) + 1
    Set pResult = ""
    Quit ..Fail(pEndpoint, tHttp, $$$ERROR($$$GeneralError, "OcuPilot test: a canned vendor refusal"), .pHttpStatus, .pFault)
}

}
