/// <p>Test-only <class>OcuPilot.Port.SuperserverPort</class> subclass: Story 18.25's seam. Every vendor call
/// made through <method>Call</method> is recorded, in order, in <code>^||OcuPilotSuperserverSeam("calls")</code>
/// as <code>endpoint/type</code>, with its query's <code>port</code> and its body's JSON, and then sent to the
/// vendor unless a rule below answers it.</p>
/// <p><b>The guard</b>: a <code>Security.Superserver</code> <code>PUT</code> or <code>DELETE</code> is sent only
/// when its port is one of <parameter>PROBEPORTS</parameter> (21825 to 21829). Any other, the system default's
/// 1972 among them, is answered 409 <parameter>GUARDCODE</parameter>, marked in
/// <code>^||OcuPilotSuperserverSeam("guard")</code> and never sent, because a real one could cut off the
/// throwaway's own gateway connection.</p>
/// <p>Armed <code>inuse</code>, a <code>PUT</code> to a probe port is answered with the vendor's measured
/// <code>#5001</code> fault, through the admin port's own fault mapping, and is not sent. Armed
/// <code>answer</code>, a probe-port write is answered 200 and not sent. <method>ArmFail</method> fails every
/// call of one <code>endpoint/type</code> pair with a 500 that is not the vendor's, and <method>ArmFailAfter</method>
/// every call of it after the first few.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverSeamPort Extends OcuPilot.Port.SuperserverPort
{

/// <p>The code the guard refuses with.</p>
Parameter GUARDCODE = "TEST.SUPERSERVER";

/// <p>The ports a probe superserver may take, and so the only ports a write is forwarded for.</p>
Parameter PROBEPORTS = "21825,21826,21827,21828,21829";

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotSuperserverSeam("calls"))
    Set ^||OcuPilotSuperserverSeam("calls", tIndex) = tPair
    Set ^||OcuPilotSuperserverSeam("port", tIndex) = $Get(pQuery("port"))
    Set ^||OcuPilotSuperserverSeam("bind", tIndex) = $Get(pQuery("bindAddress"))
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set ^||OcuPilotSuperserverSeam("body", tIndex) = pBody.%ToJSON()
        Set ^||OcuPilotSuperserverSeam("body", tPair) = pBody.%ToJSON()
    }
    Set tCount = $Increment(^||OcuPilotSuperserverSeam("count", tPair))
    If $Get(^||OcuPilotSuperserverSeam("fail", tPair)) || ($Data(^||OcuPilotSuperserverSeam("failafter", tPair)) && (tCount > ^||OcuPilotSuperserverSeam("failafter", tPair))) {
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the seam failed this call")
    }
    If (pEndpoint = ..#ENDPOINT) && ((pType = "PUT") || (pType = "DELETE")) {
        Set ^||OcuPilotSuperserverSeam("writes", $Increment(^||OcuPilotSuperserverSeam("writes"))) = pType _ ":" _ $Get(pQuery("port"))
        If '$ListFind($ListFromString(..#PROBEPORTS), $Get(pQuery("port"))) {
            Set ^||OcuPilotSuperserverSeam("guard") = 1
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#GUARDCODE, "The test seam sends no write to a port outside 21825 to 21829.")
            Quit $$$ERROR($$$GeneralError, ..#GUARDCODE)
        }
        Set tMode = $Get(^||OcuPilotSuperserverSeam("mode"))
        If (tMode = "inuse") && (pType = "PUT") {
            Quit ..TakenFault(pEndpoint, $Get(pQuery("port")), .pHttpStatus, .pFault)
        }
        If tMode = "answer" {
            Set pHttpStatus = 200
            If $IsObject(pBody) Set pResult = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
            Quit $$$OK
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The fault the admin port answers the vendor's measured <code>#5001</code> refusal of a taken port with --
/// its fault mapping and the mapped violation row -- built without the admin port's log line, which would raise
/// the instance's alert state.</p>
ClassMethod TakenFault(pEndpoint As %String, pPort As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tVendor = $$$ERROR($$$GeneralError, "Could not start superserver " _ pPort _ ", may be in use by another instance")
    Set pHttpStatus = 500
    Do ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, tVendor, .pFault, .tDetail)
    Set tViolations = ##class(OcuPilot.Api.Error).ViolationsFromVendor(tVendor)
    If '$IsObject(tViolations) Set tViolations = []
    Do ..PropertyViolations(pEndpoint, tVendor, tViolations)
    If tViolations.%Size() > 0 Do pFault.%Set("detail", {"violations": (tViolations)})
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>Arm <code>inuse</code> or <code>answer</code>.</p>
ClassMethod Arm(pMode As %String)
{
    Set ^||OcuPilotSuperserverSeam("mode") = pMode
}

/// <p>Fail every call of the <code>endpoint/type</code> pair <var>pPair</var> without the vendor.</p>
ClassMethod ArmFail(pPair As %String)
{
    Set ^||OcuPilotSuperserverSeam("fail", pPair) = 1
}

/// <p>Fail every call of the <code>endpoint/type</code> pair <var>pPair</var> after the first <var>pAfter</var>
/// of them, without the vendor.</p>
ClassMethod ArmFailAfter(pPair As %String, pAfter As %Integer)
{
    Set ^||OcuPilotSuperserverSeam("failafter", pPair) = pAfter
}

/// <p>Forget every recorded call, the armed modes and failures, and the guard's mark.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSuperserverSeam
}

/// <p>Forget the recorded calls alone, keeping the armed modes and failures.</p>
ClassMethod ClearCalls()
{
    Kill ^||OcuPilotSuperserverSeam("calls"), ^||OcuPilotSuperserverSeam("port"), ^||OcuPilotSuperserverSeam("bind"), ^||OcuPilotSuperserverSeam("body"), ^||OcuPilotSuperserverSeam("writes")
}

/// <p>The <code>port</code> and <code>bindAddress</code> the call at <var>pIndex</var> carried, as
/// <code>port|bindAddress</code>.</p>
ClassMethod QueryOf(pIndex As %Integer) As %String
{
    Quit $Get(^||OcuPilotSuperserverSeam("port", pIndex)) _ "|" _ $Get(^||OcuPilotSuperserverSeam("bind", pIndex))
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotSuperserverSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotSuperserverSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded writes since the last <method>ClearCalls</method>, as <code>type:port</code>,
/// comma-joined, whether the seam sent them or not.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotSuperserverSeam("writes", tIndex))
        If tIndex = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotSuperserverSeam("writes", tIndex)
    }
    Quit tOut
}

/// <p>The JSON body the last <var>pPair</var> call carried.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotSuperserverSeam("body", pPair))
}

/// <p>Whether the guard refused a write since the last <method>Clear</method>.</p>
ClassMethod Refused() As %Boolean
{
    Quit ''$Get(^||OcuPilotSuperserverSeam("guard"))
}

}
