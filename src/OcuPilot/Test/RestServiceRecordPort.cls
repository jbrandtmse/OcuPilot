/// <p>Test-only <class>OcuPilot.Port.MgmntPort</class> subclass with one added seam: every call's endpoint, request type and
/// body is recorded in a process-private global before the shipped port sends it, so a test can see which reads and
/// writes a Save made, in which order, and what the vendor was handed. Every call still reaches the instance through the
/// shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RestServiceRecordPort Extends OcuPilot.Port.MgmntPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pDocument As %DynamicObject) As %Status
{
    Set tIndex = $Increment(^||OcuPilotRestServiceCalls)
    Set ^||OcuPilotRestServiceCalls(tIndex) = pEndpoint _ "." _ pType
    Set ^||OcuPilotRestServiceCalls(tIndex, "body") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pDocument)
}

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotRestServiceCalls
}

/// <p>The endpoint and request type of every call since <method>Clear</method>, in order, as
/// <code>Endpoint.TYPE</code> comma-separated.</p>
ClassMethod Calls() As %String
{
    Set tCalls = ""
    For tI = 1:1:+$Get(^||OcuPilotRestServiceCalls) {
        Set tCalls = tCalls _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotRestServiceCalls(tI))
    }
    Quit tCalls
}

/// <p>How many calls since <method>Clear</method> were of request type <var>pType</var>.</p>
ClassMethod CountOf(pType As %String) As %Integer
{
    Set tCount = 0
    For tI = 1:1:+$Get(^||OcuPilotRestServiceCalls) {
        If $Piece($Get(^||OcuPilotRestServiceCalls(tI)), ".", 2) = pType Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The body of the first call of request type <var>pType</var> since <method>Clear</method>, parsed, or
/// <code>""</code> when there was none or it sent no body.</p>
ClassMethod BodyOf(pType As %String) As %DynamicObject
{
    Set tBody = ""
    For tI = 1:1:+$Get(^||OcuPilotRestServiceCalls) {
        If $Piece($Get(^||OcuPilotRestServiceCalls(tI)), ".", 2) '= pType Continue
        Set tBody = $Get(^||OcuPilotRestServiceCalls(tI, "body"))
        Quit
    }
    If tBody = "" Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody)
}

}
