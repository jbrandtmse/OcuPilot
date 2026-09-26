/// <p>Test-only <class>OcuPilot.Port.OAuthServerPort</class> subclass with one added seam: every
/// mutating call's request type, <code>issuer</code> query parameter and body are recorded in a
/// process-private global before the shipped port sends it, and every call of any request type is
/// counted. A <code>TOKEN</code> body is recorded as its key names alone, never its value. Every
/// call still reaches the instance through the shipped port. A second seam, <method>Deny</method>,
/// answers a named resource as not held; a third, <method>FailType</method>, refuses one request type
/// before it is sent.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthServerRecordPort Extends OcuPilot.Port.OAuthServerPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotOAuthCalls($Increment(^||OcuPilotOAuthCalls)) = pType
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotOAuthRecord)
        Set ^||OcuPilotOAuthRecord(tIndex, "type") = pType
        Set ^||OcuPilotOAuthRecord(tIndex, "issuer") = $Get(pQuery("issuer"))
        Set tRecorded = ""
        If $IsObject(pBody) {
            If pType = "TOKEN" {
                Set tIterator = pBody.%GetIterator()
                While tIterator.%GetNext(.tKey, .tValue) {
                    Set tRecorded = tRecorded _ $Select(tRecorded = "": "", 1: ",") _ tKey
                }
            } Else {
                Set tRecorded = pBody.%ToJSON()
            }
        }
        Set ^||OcuPilotOAuthRecord(tIndex, "body") = tRecorded
    }
    If (pType '= "") && (pType = $Get(^||OcuPilotOAuthRecord("fail"))) {
        Quit ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, .pHttpStatus, .pFault)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Refuse every call of request type <var>pType</var> with the port's not-applied fault, sending
/// nothing, until <method>Clear</method>.</p>
ClassMethod FailType(pType As %String)
{
    Set ^||OcuPilotOAuthRecord("fail") = pType
}

/// <p>Answer that the caller does not hold the resource <method>Deny</method> named; otherwise the
/// shipped port's own check.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    If (pResource '= "") && (pResource = $Get(^||OcuPilotOAuthRecord("deny"))) Quit 0
    Quit ##super(pResource)
}

/// <p>Refuse <var>pResource</var> until <method>Clear</method>.</p>
ClassMethod Deny(pResource As %String)
{
    Set ^||OcuPilotOAuthRecord("deny") = pResource
}

/// <p>Forget every recorded call, the denied resource and the failed request type.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotOAuthRecord, ^||OcuPilotOAuthCalls
}

/// <p>The request types of every call since <method>Clear</method>, in order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotOAuthCalls(tI))
    }
    Quit tTypes
}

/// <p>How many mutating calls were recorded since <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotOAuthRecord)
}

/// <p>The last recorded body: JSON text, a <code>TOKEN</code> body's key names, or
/// <code>""</code>.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotOAuthRecord(+$Get(^||OcuPilotOAuthRecord), "body"))
}

/// <p>The last recorded request type, or <code>""</code>.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotOAuthRecord(+$Get(^||OcuPilotOAuthRecord), "type"))
}

/// <p>The last recorded <code>issuer</code> query parameter, or <code>""</code>.</p>
ClassMethod LastIssuer() As %String
{
    Quit $Get(^||OcuPilotOAuthRecord(+$Get(^||OcuPilotOAuthRecord), "issuer"))
}

}
