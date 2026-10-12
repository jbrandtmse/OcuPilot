/// <p>Test-only <class>OcuPilot.Port.WalletPort</class> subclass with one added seam: every mutating
/// call's endpoint, request type, identifying query parameter and flat body are recorded in a
/// process-private global before the shipped port sends it, so a test can compare what two callers
/// sent. Every call still reaches the instance through the shipped port, and the recorded body --
/// value included -- lives only in the test process until <method>Clear</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletRecordPort Extends OcuPilot.Port.WalletPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    ; A key write is recorded by <method>Send</method>, once per vendor call it makes.
    If ..IsMutating(pEndpoint, pType) && (..KeyTypeOf(.pQuery, pBody) = "") Do ..Record(pType, .pQuery, pBody)
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Every vendor call a key write makes, recorded before it is sent.</p>
ClassMethod Send(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ..Record(pType, .pQuery, pBody)
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Record one mutating call.</p>
ClassMethod Record(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "") [ Private ]
{
    Set tIndex = $Increment(^||OcuPilotWalletRecord)
    Set ^||OcuPilotWalletRecord(tIndex, "type") = pType
    Set ^||OcuPilotWalletRecord(tIndex, "name") = $Get(pQuery("name"))
    Set ^||OcuPilotWalletRecord(tIndex, "body") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
}

/// <p>The body recorded as call number <var>pIndex</var> since <method>Clear</method>, as JSON text, or
/// <code>""</code>.</p>
ClassMethod WriteBodyAt(pIndex As %Integer) As %String
{
    Quit $Get(^||OcuPilotWalletRecord(pIndex, "body"))
}

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotWalletRecord
}

/// <p>How many mutating calls were recorded since <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotWalletRecord)
}

/// <p>The last recorded body as JSON text, or <code>""</code>.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotWalletRecord(+$Get(^||OcuPilotWalletRecord), "body"))
}

/// <p>The last recorded request type, or <code>""</code>.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotWalletRecord(+$Get(^||OcuPilotWalletRecord), "type"))
}

/// <p>The last recorded <code>name</code> query parameter, or <code>""</code>.</p>
ClassMethod LastName() As %String
{
    Quit $Get(^||OcuPilotWalletRecord(+$Get(^||OcuPilotWalletRecord), "name"))
}

}
