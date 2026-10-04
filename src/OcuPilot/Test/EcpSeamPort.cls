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
/// <p>Story 18.21 adds two armed modes, <code>ecpserver</code> and <code>pending</code>, and a guard
/// that never lets a <code>MaxServerConn</code> change reach the vendor (<method>Answered</method>).</p>
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
    ; Story 18.21's modes and guard, before anything reaches the vendor.
    Set tSC = ..Answered(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tAnswered)
    If tAnswered Quit tSC
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

/// <p>Story 18.21's two modes and its guard, asked for every call after it is recorded, with
/// <var>pAnswered</var> 1 when the call is answered here and never reaches the vendor.</p>
/// <p>Armed <code>ecpserver</code>: <code>Security.SSLConfig</code> <code>GET</code> of
/// <code>%ECPServer</code> answers a server configuration, enabled unless
/// <method>ArmServerSsl</method> armed it disabled, and an <code>ECP.Settings</code>
/// <code>PUT</code> answers 200 with its own body. Armed <code>pending</code>: the
/// <code>ECP.AppServerSSLConnection</code> <code>LIST</code> answers the instance's rows and
/// <parameter>PENDINGNAME</parameter> reading <code>Pending</code>, and its <code>AUTHORIZE</code>,
/// <code>REJECT</code> and <code>DELETE</code> answer 200 with no result.</p>
/// <p><b>The guard</b>: in any other mode, an <code>ECP.Settings</code> <code>PUT</code> whose
/// <code>DataServerSettings.MaxServerConn</code> differs from the stored value is refused 409
/// <parameter>GUARDCODE</parameter>, which no handler logs, and marked
/// in <code>^||OcuPilotEcpSeam("maxserverconn")</code>, because a real change leaves the instance pending
/// a restart that no restore clears (measured at Story 18.21's Task 0).</p>
ClassMethod Answered(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pAnswered As %Boolean) As %Status
{
    Set pAnswered = 0
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tMode = $Get(^||OcuPilotEcpSeam("mode"))
    If (pEndpoint = ..#SETTINGSENDPOINT) && (pType = "PUT") {
        If tMode = ..#SERVERMODE {
            Set pAnswered = 1
            Set pHttpStatus = 200
            If $IsObject(pBody) Set pResult = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
            Quit $$$OK
        }
        If ..ChangesMaxServerConn(pBody) {
            Set pAnswered = 1
            Set ^||OcuPilotEcpSeam("maxserverconn") = 1
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#GUARDCODE, "The test seam sends no MaxServerConn change to the vendor.")
            Quit $$$ERROR($$$GeneralError, ..#GUARDCODE)
        }
        Quit $$$OK
    }
    If (tMode = ..#SERVERMODE) && (pEndpoint = ..#SSLCONFIGENDPOINT) && (pType = "GET") && ($Get(pQuery(..#NAMEPARAM)) = ..#SERVERSSL) {
        Set pAnswered = 1
        Set pHttpStatus = 200
        Set pResult = {"Type": "1", "Description": "OcuPilot ECP seam (never stored)"}
        Do pResult.%Set("Name", ..#SERVERSSL, "string")
        Do pResult.%Set(..#SSLENABLEDFIELD, '$Get(^||OcuPilotEcpSeam("serverdisabled")), "boolean")
        Quit $$$OK
    }
    If (tMode = ..#PENDINGMODE) && (pEndpoint = ..#SSLCONNECTIONENDPOINT) {
        If pType = "LIST" {
            Set pAnswered = 1
            Kill tQuery
            Set tSC = ##class(OcuPilot.Port.EcpPort).Call(pEndpoint, pType, .tQuery, "", .tRows, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit tSC
            Set pResult = $Select($IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray"): tRows, 1: [])
            Set tRow = {"ClientIP": "192.0.2.20", "Status": "Pending"}
            Do tRow.%Set("SSLComputerName", ..#PENDINGNAME, "string")
            Do pResult.%Push(tRow)
            Set pHttpStatus = 200
            Quit $$$OK
        }
        If (pType = "AUTHORIZE") || (pType = "REJECT") || (pType = "DELETE") {
            Set pAnswered = 1
            Set pHttpStatus = 200
            Quit $$$OK
        }
    }
    Quit $$$OK
}

/// <p>Whether <var>pBody</var> carries a <code>DataServerSettings.MaxServerConn</code> other than the
/// one the instance stores (<method>OcuPilot.Test.EcpProbe.Settings</method>).</p>
ClassMethod ChangesMaxServerConn(pBody As %DynamicAbstractObject) As %Boolean
{
    If '$IsObject(pBody) || (pBody.%GetTypeOf("DataServerSettings") '= "object") Quit 0
    If pBody.%Get("DataServerSettings").%GetTypeOf("MaxServerConn") = "unassigned" Quit 0
    Set tStored = ##class(OcuPilot.Test.EcpProbe).Settings()
    If tStored.%GetTypeOf("error") '= "unassigned" Quit 1
    Quit (pBody.%Get("DataServerSettings").%Get("MaxServerConn") _ "") '= (tStored.%Get("MaxServerConn") _ "")
}

/// <p>Whether the guard refused a <code>MaxServerConn</code> change since the last
/// <method>Clear</method>.</p>
ClassMethod RefusedMaxServerConn() As %Boolean
{
    Quit ''$Get(^||OcuPilotEcpSeam("maxserverconn"))
}

/// <p>Story 18.21's two modes, the endpoint each answers, and the pending name the second lists.</p>
Parameter SERVERMODE = "ecpserver";

Parameter PENDINGMODE = "pending";

Parameter SSLCONNECTIONENDPOINT = "ECP.AppServerSSLConnection";

Parameter PENDINGNAME = "CN=OCUPROBEECPP";

/// <p>The code the guard refuses with.</p>
Parameter GUARDCODE = "TEST.MAXSERVERCONN";

/// <p>Arm <code>ecpserver</code> with <code>%ECPServer</code> answered enabled when <var>pEnabled</var>
/// is 1 and disabled when it is 0.</p>
ClassMethod ArmServerSsl(pEnabled As %Boolean = 1)
{
    Set ^||OcuPilotEcpSeam("mode") = ..#SERVERMODE
    Set ^||OcuPilotEcpSeam("serverdisabled") = ('pEnabled)
}

}
