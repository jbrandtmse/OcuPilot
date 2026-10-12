/// <p>Test-only <class>OcuPilot.Port.SqlPrivilegePort</class> subclass: Stories 18.9's and 18.28's seam. Every vendor call made
/// through <method>Call</method> is recorded, in order, in <code>^||OcuPilotSqlPrivSeam("calls")</code> as
/// <code>endpoint/type</code>, with its grantee and, on a revoke, its grantor, and then sent to the vendor unless a
/// rule below answers it. A <code>LIST</code>'s <code>includeSystem</code> is kept as the last one asked.</p>
/// <p><b>The guard</b>: a <code>GRANT</code> or <code>REVOKE</code> of any of the three families is sent only for a
/// grantee, and an object (an admin privilege has none), whose names begin <code>OcuSqlPrivProbe</code>. Any other
/// is answered 409 <parameter>GUARDCODE</parameter> and never sent.</p>
/// <p>Armed <method>ArmRows</method>, a <code>LIST</code> answers those rows for the grantee whatever the
/// instance holds, and a <code>REVOKE</code> removes the armed rows its <code>asGrantor</code> granted, without
/// being sent: the way a privilege held directly from several grantors is read, which the instance stores once
/// for each privilege.</p>
/// <p>Armed <method>ArmNoop</method>, a <code>GRANT</code> or <code>REVOKE</code> is recorded and answered 200
/// <code>{}</code> without being sent, which is the vendor's silent no-op: the re-read then finds the state
/// unmoved.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlPrivilegeSeamPort Extends OcuPilot.Port.SqlPrivilegePort
{

/// <p>The code the guard refuses with.</p>
Parameter GUARDCODE = "TEST.SQLPRIV";

Parameter PROBEPREFIX = "OcuSqlPrivProbe";

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tIndex = $Increment(^||OcuPilotSqlPrivSeam("calls"))
    Set ^||OcuPilotSqlPrivSeam("calls", tIndex) = pEndpoint _ "/" _ pType
    If ((pEndpoint = ..#ENDPOINT) || (pEndpoint = ..#COLUMNENDPOINT) || (pEndpoint = ..#ADMINENDPOINT)) && ((pType = ..#GRANT) || (pType = ..#REVOKE)) {
        Set ^||OcuPilotSqlPrivSeam("writes", $Increment(^||OcuPilotSqlPrivSeam("writes"))) = pType _ ":" _ $Get(pQuery("grantee")) _ ":" _ $Get(pQuery("asGrantor"))
        If ($ZConvert($Extract($Get(pQuery("grantee")), 1, $Length(..#PROBEPREFIX)), "U") '= $ZConvert(..#PROBEPREFIX, "U")) || ((pEndpoint '= ..#ADMINENDPOINT) && ($ZConvert($Extract($Get(pQuery("object")), 1, $Length(..#PROBEPREFIX)), "U") '= $ZConvert(..#PROBEPREFIX, "U"))) {
            Set ^||OcuPilotSqlPrivSeam("guard") = 1
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..#GUARDCODE, "The test seam sends no write outside OcuSqlPrivProbe.")
            Quit $$$ERROR($$$GeneralError, ..#GUARDCODE)
        }
        If $Data(^||OcuPilotSqlPrivSeam("rows")) && (pType = ..#REVOKE) {
            Set tKept = []
            Set tIterator = ##class(%DynamicAbstractObject).%FromJSON(^||OcuPilotSqlPrivSeam("rows")).%GetIterator()
            While tIterator.%GetNext(.tRowIndex, .tRow) {
                If tRow.%Get("GrantedBy") '= $Get(pQuery("asGrantor")) Do tKept.%Push(tRow)
            }
            Set ^||OcuPilotSqlPrivSeam("rows") = tKept.%ToJSON()
            Set pResult = {}
            Set pHttpStatus = 200
            Quit $$$OK
        }
        If $Get(^||OcuPilotSqlPrivSeam("noop", pType)) {
            Set pResult = {}
            Set pHttpStatus = 200
            Quit $$$OK
        }
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = ..#LISTTYPE) Set ^||OcuPilotSqlPrivSeam("includeSystem") = $Get(pQuery("includeSystem"))
    If $Data(^||OcuPilotSqlPrivSeam("rows")) && (pEndpoint = ..#ENDPOINT) && (pType = ..#LISTTYPE) {
        Set pResult = ##class(%DynamicAbstractObject).%FromJSON(^||OcuPilotSqlPrivSeam("rows"))
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Answer every <code>LIST</code> with the rows <var>pRows</var>, a <class>%DynamicArray</class>.</p>
ClassMethod ArmRows(pRows As %DynamicArray)
{
    Set ^||OcuPilotSqlPrivSeam("rows") = pRows.%ToJSON()
}

/// <p>Answer the vendor's <code>GRANT</code> or <code>REVOKE</code> (<var>pType</var>) 200 without sending it.</p>
ClassMethod ArmNoop(pType As %String)
{
    Set ^||OcuPilotSqlPrivSeam("noop", pType) = 1
}

/// <p>Forget every recorded call, the armed no-ops and the guard's mark.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSqlPrivSeam
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotSqlPrivSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotSqlPrivSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded writes, as <code>type:grantee:asGrantor</code>, comma-joined in order, whether the seam sent
/// them or not.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotSqlPrivSeam("writes", tIndex))
        If tIndex = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotSqlPrivSeam("writes", tIndex)
    }
    Quit tOut
}

/// <p>Forget the recorded calls and writes, keeping what is armed.</p>
ClassMethod ClearCalls()
{
    Kill ^||OcuPilotSqlPrivSeam("calls"), ^||OcuPilotSqlPrivSeam("writes")
}

/// <p>Whether the guard refused a write since the last <method>Clear</method>.</p>
ClassMethod Refused() As %Boolean
{
    Quit ''$Get(^||OcuPilotSqlPrivSeam("guard"))
}

}
