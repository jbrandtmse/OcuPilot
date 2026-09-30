/// <p>Test-only <class>OcuPilot.Port.LockPort</class> subclass whose one replaced seam is
/// <method>Call</method>: nothing reaches the vendor. A <code>Lock</code> <code>LIST</code> answers the
/// rows a test armed for its ordinal with <method>ArmListing</method>, else those armed with
/// <method>Arm</method>, at most its <code>maxRows</code>, and a <code>Lock</code> <code>DELETE</code> answers 200,
/// or the status <method>ArmStatus</method> names for its id; each call's query is recorded
/// (<method>Calls</method>), so a test reads what the port would have sent (Story 16.12).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LockRecordPort Extends OcuPilot.Port.LockPort
{

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pFault = ""
    Set tIndex = $Increment(^||OcuPilotLockCalls)
    Set ^||OcuPilotLockCalls(tIndex) = $ListBuild(pEndpoint _ "/" _ pType, $Get(pQuery("id")), $Get(pQuery("checkTxn")), $Get(pQuery("filter")), $Get(pQuery("maxRows")))
    If pType = "LIST" {
        ; As the vendor does, answer at most maxRows rows where the query names it.
        Set tList = $Increment(^||OcuPilotLockLists)
        Set tRows = ##class(%DynamicArray).%FromJSON($Get(^||OcuPilotLockRows(tList), $Get(^||OcuPilotLockRows, "[]")))
        Set tMax = +$Get(pQuery("maxRows"))
        Set pResult = []
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tMax && (pResult.%Size() >= tMax) Quit
            Do pResult.%Push(tRow)
        }
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set pHttpStatus = +$Get(^||OcuPilotLockStatus($Get(pQuery("id"))), 200)
    If pHttpStatus = 200 {
        Set pResult = {}
        Quit $$$OK
    }
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#PORTCONFLICT, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, "refused by the test port")
}

/// <p>Forget every armed row, status and recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotLockCalls, ^||OcuPilotLockRows, ^||OcuPilotLockStatus, ^||OcuPilotLockLists
}

/// <p>Answer every <code>Lock</code> <code>LIST</code> with the rows in <var>pRows</var>.</p>
ClassMethod Arm(pRows As %DynamicArray)
{
    Set ^||OcuPilotLockRows = pRows.%ToJSON()
}

/// <p>Answer the <var>pNumber</var>th <code>Lock</code> <code>LIST</code> since <method>Reset</method>
/// with the rows in <var>pRows</var>, in place of those <method>Arm</method> armed.</p>
ClassMethod ArmListing(pNumber As %Integer, pRows As %DynamicArray)
{
    Set ^||OcuPilotLockRows(pNumber) = pRows.%ToJSON()
}

/// <p>Answer a <code>Lock</code> <code>DELETE</code> of <var>pId</var> with HTTP <var>pStatus</var>.</p>
ClassMethod ArmStatus(pId As %String, pStatus As %Integer)
{
    Set ^||OcuPilotLockStatus(pId) = pStatus
}

/// <p>The recorded calls of request type <var>pType</var>, in order, each as
/// <code>id|checkTxn|filter|maxRows</code>, as a <class>%List</class>.</p>
ClassMethod Calls(pType As %String) As %List
{
    Set tCalls = ""
    For tI = 1:1:$Get(^||OcuPilotLockCalls) {
        Set tCall = ^||OcuPilotLockCalls(tI)
        If $List(tCall, 1) '= ("Lock/" _ pType) Continue
        Set tCalls = tCalls _ $ListBuild($List(tCall, 2) _ "|" _ $List(tCall, 3) _ "|" _ $List(tCall, 4) _ "|" _ $List(tCall, 5))
    }
    Quit tCalls
}

}
