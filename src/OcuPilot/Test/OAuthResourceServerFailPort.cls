/// <p>Test-only <class>OcuPilot.Test.OAuthResourceServerRecordPort</class> subclass, so every mutating
/// call is recorded, with one replaced seam: the
/// private <method>Vendor</method> answers an <code>&lt;endpoint&gt;/&lt;type&gt;</code> armed with
/// <method>Arm</method> the way the admin port answers a vendor refusal at that status, without calling
/// the vendor, and counts each such answer; every other call goes to the shipped port's own. The arming
/// is process-private and lasts until <method>Disarm</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthResourceServerFailPort Extends OcuPilot.Test.OAuthResourceServerRecordPort
{

/// <p>Answer every later call of <var>pEndpoint</var>'s <var>pType</var> as a vendor refusal at HTTP
/// <var>pHttp</var>.</p>
ClassMethod Arm(pEndpoint As %String, pType As %String, pHttp As %Integer)
{
    Set ^||OcuPilotOAuthResourceFail(pEndpoint _ "/" _ pType) = pHttp
}

/// <p>Forget every armed type and every count.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotOAuthResourceFail, ^||OcuPilotOAuthResourceFailCount
}

/// <p>How many calls of <var>pEndpoint</var>'s <var>pType</var> were answered as a refusal since
/// <method>Disarm</method>.</p>
ClassMethod Reached(pEndpoint As %String, pType As %String) As %Integer
{
    Quit +$Get(^||OcuPilotOAuthResourceFailCount(pEndpoint _ "/" _ pType))
}

ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tKey = pEndpoint _ "/" _ pType
    Set tHttp = $Get(^||OcuPilotOAuthResourceFail(tKey))
    If tHttp = "" Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotOAuthResourceFailCount(tKey) = $Get(^||OcuPilotOAuthResourceFailCount(tKey)) + 1
    Set pResult = ""
    Quit ..Fail(pEndpoint, tHttp, $$$ERROR($$$GeneralError, "OcuPilot test: a canned vendor refusal"), .pHttpStatus, .pFault)
}

}
