/// <p>Test-only <class>OcuPilot.Port.EcpPort</class> subclass: Story 18.20's seam. Every vendor call the
/// port makes is recorded, in order, in <code>^||OcuPilotEcpSeam("calls")</code> with its name query and
/// its body before it is answered.</p>
/// <p><b>A <code>SERVERACTION</code> with <code>Action</code> 3 never reaches the vendor</b>: armed
/// <code>finished</code> it answers 200 with no result, as a finished task does, and unarmed it is
/// refused 500. Armed <code>started</code>, every <code>SERVERACTION</code> answers 503
/// <code>PORT.TIMEOUT</code>, as the admin port's poll answers one still running at its bound; armed
/// <code>failed</code>, 500 <code>INTERNAL</code>, as the poll answers a task the vendor failed; neither
/// reaches the vendor. Every other call is the shipped port's.</p>
/// <p><method>NetworkEnabled</method> answers 1 under <code>^||OcuPilotRemoteLicensed</code>, the
/// licensed instance no instance here is, and the instance's own license otherwise.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EcpSeamPort Extends OcuPilot.Port.EcpPort
{

ClassMethod NetworkEnabled() As %Boolean
{
    If $Get(^||OcuPilotRemoteLicensed) Quit 1
    Quit ##super()
}

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotEcpSeam("calls"))
    Set ^||OcuPilotEcpSeam("calls", tIndex) = tPair
    Set ^||OcuPilotEcpSeam("name", tIndex) = $Get(pQuery(..#NAMEPARAM))
    If $IsObject(pBody) {
        Set ^||OcuPilotEcpSeam("body", tIndex) = pBody.%ToJSON()
        Set ^||OcuPilotEcpSeam("body", tPair) = pBody.%ToJSON()
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = ..#ACTIONTYPE) {
        Set tAction = ""
        If $IsObject(pBody) Set tAction = pBody.%Get(..#ACTIONFIELD)
        Set tMode = $Get(^||OcuPilotEcpSeam("mode"))
        If tMode = "started" {
            Set pHttpStatus = 503
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTTIMEOUT, "The instance did not finish that operation in time")
            Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTTIMEOUT)
        }
        If tMode = "failed" {
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the seam's task failed")
        }
        If +tAction = 3 {
            If tMode = "finished" {
                Set pHttpStatus = 200
                Quit $$$OK
            }
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the seam sends no Action 3 to the vendor")
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Arm <var>pMode</var>: <code>finished</code>, <code>started</code> or <code>failed</code>, as this
/// class's header gives each; <code>""</code> disarms.</p>
ClassMethod Arm(pMode As %String = "finished")
{
    Set ^||OcuPilotEcpSeam("mode") = pMode
}

/// <p>Forget every recorded call and the armed mode.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEcpSeam
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEcpSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotEcpSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded calls other than reads (<code>GET</code> and <code>LIST</code>), comma-joined.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEcpSeam("calls")) {
        Set tPair = $Get(^||OcuPilotEcpSeam("calls", tI))
        If ($Piece(tPair, "/", 2) = "GET") || ($Piece(tPair, "/", 2) = "LIST") Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPair
    }
    Quit tOut
}

/// <p>The <code>Action</code> of each recorded <code>SERVERACTION</code>, comma-joined in order.</p>
ClassMethod Actions() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEcpSeam("calls")) {
        If $Get(^||OcuPilotEcpSeam("calls", tI)) '= (..#ENDPOINT _ "/" _ ..#ACTIONTYPE) Continue
        Set tAction = ""
        Try { Set tAction = ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotEcpSeam("body", tI))).%Get(..#ACTIONFIELD) } Catch { Set tAction = "?" }
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tAction
    }
    Quit tOut
}

/// <p>The name query of the last recorded <var>pPair</var> call, or <code>""</code>.</p>
ClassMethod NameOf(pPair As %String) As %String
{
    Set tName = ""
    For tI = 1:1:+$Get(^||OcuPilotEcpSeam("calls")) {
        If $Get(^||OcuPilotEcpSeam("calls", tI)) = pPair Set tName = $Get(^||OcuPilotEcpSeam("name", tI))
    }
    Quit tName
}

/// <p>The JSON body the last <var>pPair</var> call carried.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotEcpSeam("body", pPair))
}

}
