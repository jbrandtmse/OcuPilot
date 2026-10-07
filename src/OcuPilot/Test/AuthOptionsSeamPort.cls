/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass: Story 18.8's seam. Every call made through
/// <method>Invoke</method> is recorded, in order, in <code>^||OcuPilotAuthSeam("calls")</code> as
/// <code>endpoint/type</code>, with its query's <code>name</code> and its body's JSON, <b>never</b> a
/// <code>SMTPPassword</code> value, and then sent to the vendor unless a mode below answers it.</p>
/// <p><b>The guard</b>: unless armed <code>answer</code>, a <code>Security.WebAuth</code> <code>PUT</code>
/// that would change <code>JWTIssuer</code> or <code>JWTSigAlg</code>, turn off <code>AutheOS</code>,
/// <code>AutheCache</code> or <code>AutheUnauthenticated</code>, is answered 409 <parameter>GUARDCODE</parameter>
/// and never sent, because a real one ends every token session, fails the next start or cuts off OcuPilot's own
/// sign-in (measured at Story 18.8's plan). It is marked in <code>^||OcuPilotAuthSeam("guard")</code>.</p>
/// <p>Armed <code>answer</code>, every <code>Security.WebAuth</code> <code>PUT</code> is answered 200 with its
/// own body and every <code>CHANGESMTPPWD</code> with an empty one, and neither is sent; the instance keeps its value. <method>ArmMask</method> answers one application's
/// or service's read with a mask of the test's choosing, and <method>ArmFail</method> fails the read of one
/// endpoint (<code>WebApp.App</code>, <code>Security.Service</code> or <code>Security.WebAuth</code>) with a
/// 500 that is not the vendor's, without the vendor.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuthOptionsSeamPort Extends OcuPilot.Port.AdminPort
{

/// <p>The code the guard refuses with.</p>
Parameter GUARDCODE = "TEST.AUTHOPTIONS";

Parameter ENDPOINT = "Security.WebAuth";

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotAuthSeam("calls"))
    Set ^||OcuPilotAuthSeam("calls", tIndex) = tPair
    Set ^||OcuPilotAuthSeam("name", tIndex) = $Get(pQuery("name"))
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
        If tCopy.%GetTypeOf("SMTPPassword") '= "unassigned" Do tCopy.%Set("SMTPPassword", "<recorded as present>", "string")
        Set ^||OcuPilotAuthSeam("body", tIndex) = tCopy.%ToJSON()
        Set ^||OcuPilotAuthSeam("body", tPair) = tCopy.%ToJSON()
    }
    ; A read a test armed to fail or to answer a chosen mask.
    If pType = "GET" {
        If $Get(^||OcuPilotAuthSeam("fail", pEndpoint)) {
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the seam failed this read")
        }
        Set tName = $ZConvert($Get(pQuery("name")), "L")
        If $Data(^||OcuPilotAuthSeam("mask", pEndpoint, tName)) {
            Set pHttpStatus = 200
            Set pResult = {}
            Do pResult.%Set("AutheEnabled", +^||OcuPilotAuthSeam("mask", pEndpoint, tName), "number")
            Quit $$$OK
        }
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = "CHANGESMTPPWD") && ($Get(^||OcuPilotAuthSeam("mode")) = "answer") {
        Set pHttpStatus = 200
        Set pResult = {}
        Quit $$$OK
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = "PUT") {
        If $Get(^||OcuPilotAuthSeam("mode")) = "answer" {
            Set pHttpStatus = 200
            If $IsObject(pBody) Set pResult = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
            Quit $$$OK
        }
        If ..Guarded(pBody) {
            Set ^||OcuPilotAuthSeam("guard") = 1
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#GUARDCODE, "The test seam sends no sign-in, start or token change to the vendor.")
            Quit $$$ERROR($$$GeneralError, ..#GUARDCODE)
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Whether <var>pBody</var> would change <code>JWTIssuer</code> or <code>JWTSigAlg</code>, or turn off
/// <code>AutheOS</code>, <code>AutheCache</code> or <code>AutheUnauthenticated</code>, from what the instance
/// stores now.</p>
ClassMethod Guarded(pBody As %DynamicAbstractObject) As %Boolean
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tStored, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tStored)) Quit 1
    Set tGuarded = 0
    For tName = "JWTIssuer", "JWTSigAlg" {
        If (pBody.%GetTypeOf(tName) '= "unassigned") && ((pBody.%Get(tName) _ "") '= (tStored.%Get(tName) _ "")) Set tGuarded = 1
    }
    For tName = "AutheOS", "AutheCache", "AutheUnauthenticated" {
        If (pBody.%GetTypeOf(tName) '= "unassigned") && ('pBody.%Get(tName)) && tStored.%Get(tName) Set tGuarded = 1
    }
    Quit tGuarded
}

/// <p>Arm <code>answer</code>: every settings <code>PUT</code> is answered, recorded and never sent.</p>
ClassMethod Arm(pMode As %String = "answer")
{
    Set ^||OcuPilotAuthSeam("mode") = pMode
}

/// <p>Answer <var>pEndpoint</var>'s <code>GET</code> for <var>pName</var> with <code>AutheEnabled</code>
/// <var>pMask</var>.</p>
ClassMethod ArmMask(pEndpoint As %String, pName As %String, pMask As %Integer)
{
    Set ^||OcuPilotAuthSeam("mask", pEndpoint, $ZConvert(pName, "L")) = pMask
}

/// <p>Fail every <code>GET</code> of <var>pEndpoint</var>.</p>
ClassMethod ArmFail(pEndpoint As %String)
{
    Set ^||OcuPilotAuthSeam("fail", pEndpoint) = 1
}

/// <p>Forget every recorded call, the armed modes, masks and failures, and the guard's mark.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotAuthSeam
}

/// <p>Forget the recorded calls alone, keeping the armed modes, masks and failures.</p>
ClassMethod ClearCalls()
{
    Kill ^||OcuPilotAuthSeam("calls")
    Kill ^||OcuPilotAuthSeam("name")
    Kill ^||OcuPilotAuthSeam("body")
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotAuthSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotAuthSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded calls other than reads (<code>GET</code> and <code>LIST</code>), comma-joined.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotAuthSeam("calls")) {
        Set tPair = $Get(^||OcuPilotAuthSeam("calls", tI))
        If ($Piece(tPair, "/", 2) = "GET") || ($Piece(tPair, "/", 2) = "LIST") Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPair
    }
    Quit tOut
}

/// <p>The JSON body the last <var>pPair</var> call carried, its password recorded as present.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotAuthSeam("body", pPair))
}

/// <p>Whether the guard refused a change since the last <method>Clear</method>.</p>
ClassMethod Refused() As %Boolean
{
    Quit ''$Get(^||OcuPilotAuthSeam("guard"))
}

}
