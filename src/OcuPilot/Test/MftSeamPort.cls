/// <p>Test-only <class>OcuPilot.Port.MftPort</class> subclass: Story 18.26's seam. Every vendor call made through
/// <method>Call</method> is recorded, in order, in <code>^||OcuPilotMftSeam("calls")</code> as
/// <code>endpoint/type</code>, with its query's <code>connection</code> and its body's JSON, and then sent to the
/// vendor unless a rule below answers it.</p>
/// <p><b>The guard</b>: a <code>Security.MFT</code> <code>PUT</code>, <code>DELETE</code> or <code>REVOKE</code> is
/// sent only for a connection whose name begins <code>OcuMftProbe</code>. Any other is answered 409
/// <parameter>GUARDCODE</parameter> and never sent.</p>
/// <p>Armed <method>ArmAuthorized</method>, the <code>LIST</code> row of a named connection reads "Authorized", so
/// a revoke of a connection that holds no real token reaches the vendor's <code>REVOKE</code>, which changes
/// nothing for it (measured at Story 18.26's plan); a <code>REVOKE</code> the vendor answers disarms the row, as a
/// real revoke leaves the connection not authorized. No call reaches a file service. <method>ArmFail</method> fails
/// every call of one <code>endpoint/type</code> pair with a 500 that is not the vendor's, and
/// <method>ArmFailAfter</method> every call of it after the first few.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MftSeamPort Extends OcuPilot.Port.MftPort
{

/// <p>The code the guard refuses with.</p>
Parameter GUARDCODE = "TEST.MFT";

Parameter PROBEPREFIX = "OcuMftProbe";

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotMftSeam("calls"))
    Set ^||OcuPilotMftSeam("calls", tIndex) = tPair
    Set ^||OcuPilotMftSeam("name", tIndex) = $Get(pQuery("connection"))
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set ^||OcuPilotMftSeam("body", tIndex) = pBody.%ToJSON()
        Set ^||OcuPilotMftSeam("body", tPair) = pBody.%ToJSON()
    }
    Set tCount = $Increment(^||OcuPilotMftSeam("count", tPair))
    If $Get(^||OcuPilotMftSeam("fail", tPair)) || ($Data(^||OcuPilotMftSeam("failafter", tPair)) && (tCount > ^||OcuPilotMftSeam("failafter", tPair))) {
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the seam failed this call")
    }
    If (pEndpoint = "Security.SSLConfig") && (pType = "GET") && $Data(^||OcuPilotMftSeam("ssl", $Get(pQuery("name")))) {
        Set pResult = {"Name": ($Get(pQuery("name"))), "Type": (^||OcuPilotMftSeam("ssl", $Get(pQuery("name"))))}
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If (pEndpoint = ..#ENDPOINT) && ((pType = "PUT") || (pType = "DELETE") || (pType = "REVOKE")) {
        Set ^||OcuPilotMftSeam("writes", $Increment(^||OcuPilotMftSeam("writes"))) = pType _ ":" _ $Get(pQuery("connection"))
        If $Extract($Get(pQuery("connection")), 1, $Length(..#PROBEPREFIX)) '= ..#PROBEPREFIX {
            Set ^||OcuPilotMftSeam("guard") = 1
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#GUARDCODE, "The test seam sends no write to a connection outside OcuMftProbe.")
            Quit $$$ERROR($$$GeneralError, ..#GUARDCODE)
        }
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    ; A revoke the vendor answered removes the token, so the connection's row reads "Not Authorized" after it.
    If $$$ISOK(tSC) && (pEndpoint = ..#ENDPOINT) && (pType = "REVOKE") Kill ^||OcuPilotMftSeam("authorized", $Get(pQuery("connection")))
    If $$$ISOK(tSC) && (pEndpoint = ..#ENDPOINT) && (pType = "LIST") && $IsObject($Get(pResult)) && pResult.%IsA("%Library.DynamicArray") {
        Set tIterator = pResult.%GetIterator()
        While tIterator.%GetNext(.tRowIndex, .tRow) {
            If $IsObject(tRow) && $Data(^||OcuPilotMftSeam("authorized", tRow.%Get("Name"))) Do tRow.%Set("IsAuthorized", "Authorized", "string")
        }
    }
    Quit tSC
}

/// <p>Make the <code>LIST</code> row of the connection <var>pName</var> read "Authorized".</p>
ClassMethod ArmAuthorized(pName As %String)
{
    Set ^||OcuPilotMftSeam("authorized", pName) = 1
}

/// <p>Answer the <code>Security.SSLConfig</code> <code>GET</code> of <var>pName</var> without the vendor, as a
/// configuration of <var>pType</var> (0 a client configuration, 1 a server one), which a stock throwaway cannot
/// create a server one of.</p>
ClassMethod ArmSslType(pName As %String, pType As %Integer)
{
    Set ^||OcuPilotMftSeam("ssl", pName) = pType
}

/// <p>Fail every call of the <code>endpoint/type</code> pair <var>pPair</var> without the vendor.</p>
ClassMethod ArmFail(pPair As %String)
{
    Set ^||OcuPilotMftSeam("fail", pPair) = 1
}

/// <p>Fail every call of the pair <var>pPair</var> after the first <var>pAfter</var> of them.</p>
ClassMethod ArmFailAfter(pPair As %String, pAfter As %Integer)
{
    Set ^||OcuPilotMftSeam("failafter", pPair) = pAfter
}

/// <p>Forget every recorded call, the armed rows and failures, and the guard's mark.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMftSeam
}

/// <p>Forget the recorded calls alone, keeping what is armed.</p>
ClassMethod ClearCalls()
{
    Kill ^||OcuPilotMftSeam("calls"), ^||OcuPilotMftSeam("name"), ^||OcuPilotMftSeam("body"), ^||OcuPilotMftSeam("writes"), ^||OcuPilotMftSeam("count")
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotMftSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotMftSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded writes since the last <method>ClearCalls</method>, as <code>type:name</code>, comma-joined,
/// whether the seam sent them or not.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotMftSeam("writes", tIndex))
        If tIndex = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotMftSeam("writes", tIndex)
    }
    Quit tOut
}

/// <p>The JSON body the last <var>pPair</var> call carried.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotMftSeam("body", pPair))
}

/// <p>Whether the guard refused a write since the last <method>Clear</method>.</p>
ClassMethod Refused() As %Boolean
{
    Quit ''$Get(^||OcuPilotMftSeam("guard"))
}

}
