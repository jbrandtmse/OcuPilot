/// <p>Test-only <class>OcuPilot.Port.LicensePort</class> subclass: Story 18.6's seam. Every vendor call
/// the port makes is recorded, in order, in <code>^||OcuPilotLicenseSeam</code> before it is answered,
/// with the body of a <code>License.Server</code> call; nothing of a <code>License.Key</code> body is
/// kept.</p>
/// <p><b><code>License.Key</code> <code>VALIDATE</code></b> answers the canned valid verdict
/// (<method>ValidAnswer</method>: a restart required, cores from 20 to 8, and the feature
/// <parameter>FEATURE</parameter>) when <method>Arm</method> armed it, and is the vendor's own call
/// otherwise. <b>A <code>License.Key</code> <code>PUT</code> never reaches the vendor</b>: armed it
/// answers <code>{}</code> at 200, and unarmed it is refused 500, so no test can activate a key.
/// Every other call is the vendor's own.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LicenseSeamPort Extends OcuPilot.Port.LicensePort
{

/// <p>The feature the canned verdict reduces.</p>
Parameter FEATURE = "Vector Search";

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotLicenseSeam("calls"))
    Set ^||OcuPilotLicenseSeam("calls", tIndex) = tPair
    If (pEndpoint = "License.Server") && $IsObject(pBody) Set ^||OcuPilotLicenseSeam("body", tPair) = pBody.%ToJSON()
    If pEndpoint = ..#KEYENDPOINT {
        If (pType = ..#VALIDATETYPE) && $Get(^||OcuPilotLicenseSeam("valid")) {
            Set pResult = ..ValidAnswer()
            Set pHttpStatus = 200
            Quit $$$OK
        }
        If pType = "PUT" {
            If $Get(^||OcuPilotLicenseSeam("valid")) {
                Set pResult = {}
                Set pHttpStatus = 200
                Quit $$$OK
            }
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the seam sends no license key PUT")
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The vendor-shaped answer of a valid check that requires a restart and reduces two things.</p>
ClassMethod ValidAnswer() As %DynamicObject
{
    Set tAnswer = {"IsValid": true, "InvalidReason": "", "RequiresRestart": true, "RestartReason": "a probe restart reason", "HasReductions": true}
    Set tReductions = {"Cores": {"From": 20, "To": 8}}
    Do tReductions.%Set("Features", [(..#FEATURE)])
    Do tAnswer.%Set("Reductions", tReductions)
    Quit tAnswer
}

/// <p>Arm the valid verdict (<var>pValid</var> 1) or the vendor's own check (0).</p>
ClassMethod Arm(pValid As %Boolean = 1)
{
    Set ^||OcuPilotLicenseSeam("valid") = ''pValid
}

/// <p>Forget every recorded call and the armed verdict.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLicenseSeam
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotLicenseSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotLicenseSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded calls other than reads (<code>GET</code> and <code>LIST</code>), comma-joined.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotLicenseSeam("calls")) {
        Set tPair = $Get(^||OcuPilotLicenseSeam("calls", tI))
        If ($Piece(tPair, "/", 2) = "GET") || ($Piece(tPair, "/", 2) = "LIST") Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPair
    }
    Quit tOut
}

/// <p>The JSON body the last <var>pPair</var> call carried, for a <code>License.Server</code> call.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotLicenseSeam("body", pPair))
}

}
