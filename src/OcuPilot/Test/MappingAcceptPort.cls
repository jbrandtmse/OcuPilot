/// <p>Test-only <class>OcuPilot.Port.NamespacePort</class> subclass that accepts every mutating call
/// and changes nothing, answering an empty result at 200, and sends every read through the shipped
/// port, which splits a mapping's composite id. The request types it was asked for are recorded in
/// <code>^||OcuPilotMappingAcceptCalls</code>. A removed prohibited predicate therefore shows as a
/// recorded write here and never as a changed mapping (Story 18.14).</p>
/// <p>A <code>Namespace.Namespace</code> <code>GET</code> of <code>%ALL</code> the instance answers 404
/// is answered with a present namespace over <code>USER</code>, so a refusal that follows the fresh
/// read is asked about <code>%ALL</code> without that namespace on the instance (Story 18.15, the
/// <class>OcuPilot.Test.MappingAllTargetFixture</class> precedent).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingAcceptPort Extends OcuPilot.Port.NamespacePort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotMappingAcceptCalls($Increment(^||OcuPilotMappingAcceptCalls)) = pType
    If '..IsMutating(pEndpoint, pType) {
        Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) && (+$Get(pHttpStatus) = 404) && (pEndpoint = ..#NAMESPACEENDPOINT) && (pType = ..#READTYPE) && ($ZConvert($Get(pQuery(..#IDQUERY)), "U") = "%ALL") {
            Set pResult = {"Globals": "USER", "Routines": "USER", "TempGlobals": "IRISTEMP", "SourceNamespace": ""}
            Set pHttpStatus = 200
            Set pFault = ""
            Quit $$$OK
        }
        Quit tSC
    }
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
        If '$ListFind($ListBuild("PUT", "DELETE", "MAPPINGS", "INTEROP"), tType) Continue
        Set tTypes = tTypes _ $Select(tTypes = "": "", 1: ",") _ tType
    }
    Quit tTypes
}

ClassMethod Clear()
{
    Kill ^||OcuPilotMappingAcceptCalls
}

/// <p>How many calls of any request type, reads included, were made since <method>Clear</method>, so
/// this port can stand in for <class>OcuPilot.Test.MappingRecordPort</class> in
/// <class>OcuPilot.Test.MappingWriteGateProbe</class>'s steps.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotMappingAcceptCalls)
}

/// <p>The request types of every call since <method>Clear</method>, in order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotMappingAcceptCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotMappingAcceptCalls(tI))
    }
    Quit tTypes
}

}
