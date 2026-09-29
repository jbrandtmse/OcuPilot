/// <p>Test-only <class>OcuPilot.Port.NamespacePort</class> subclass that accepts every mutating call
/// and changes nothing, answering an empty result at 200, and sends every read through the shipped
/// port, which splits a mapping's composite id. The request types it was asked for are recorded in
/// <code>^||OcuPilotMappingAcceptCalls</code>. A removed prohibited predicate therefore shows as a
/// recorded write here and never as a changed mapping (Story 18.14).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingAcceptPort Extends OcuPilot.Port.NamespacePort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotMappingAcceptCalls($Increment(^||OcuPilotMappingAcceptCalls)) = pType
    If '..IsMutating(pEndpoint, pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = {}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The mutating request types asked for since <method>Clear</method>, comma-separated.</p>
ClassMethod Writes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotMappingAcceptCalls) {
        Set tType = $Get(^||OcuPilotMappingAcceptCalls(tI))
        If '$ListFind($ListBuild("PUT", "DELETE", "MAPPINGS"), tType) Continue
        Set tTypes = tTypes _ $Select(tTypes = "": "", 1: ",") _ tType
    }
    Quit tTypes
}

ClassMethod Clear()
{
    Kill ^||OcuPilotMappingAcceptCalls
}

}
