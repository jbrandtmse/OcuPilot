/// <p>Test-only <class>OcuPilot.Port.DatabasePort</class> whose queued writes run the admin port's own
/// sequence with this class's seams (Story 18.4): <method>AsyncTimeout</method> is 0, so a queued disk
/// operation is answered started after one poll while the vendor's worker runs it for real, and
/// <method>PollTask</method> records the task it polled and counts its polls (<method>Polls</method>),
/// so a test can settle it (<method>Settle</method>) and read its finished result once. Every other
/// call, the state read's among them, is the shipped port's. Faults go to
/// <class>OcuPilot.Test.FaultProbe</class>, never <code>messages.log</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseQueuedPort Extends OcuPilot.Port.DatabasePort
{

/// <p>A queued write: the admin port's own sequence, reached through <code>InvokeLocated</code>, which
/// this port does not override, so its seams below apply. Any other call: the shipped port's.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If '..IsQueuedWrite(pEndpoint, pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Quit ..InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tLocation)
}

ClassMethod AsyncTimeout() As %Numeric
{
    Quit 0
}

/// <p>The admin port's poll, with the task's GUID recorded as the last one polled and the poll
/// counted.</p>
ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set ^||OcuPilotDatabaseQueued = pGuid
    Do $Increment(^||OcuPilotDatabaseQueued("polls"))
    Quit ##super(pGuid, .pAnswer, .pHttpStatus)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

/// <p>The GUID of the task this port last polled, or <code>""</code>.</p>
ClassMethod LastTask() As %String
{
    Quit $Get(^||OcuPilotDatabaseQueued)
}

/// <p>How many polls this port made since <method>Clear</method>.</p>
ClassMethod Polls() As %Integer
{
    Quit +$Get(^||OcuPilotDatabaseQueued("polls"))
}

/// <p>Poll task <var>pGuid</var> through the admin port until it is terminal or <var>pSeconds</var>
/// pass, then delete its row once terminal, answering its last state. A task that has not ended is read
/// as often as it takes; an ended one is read once.</p>
ClassMethod Settle(pGuid As %String, pSeconds As %Integer = 60) As %String
{
    Set tState = ""
    If pGuid = "" Quit tState
    Set tEnd = $ZHorolog + pSeconds
    For {
        Set tAnswer = ""
        Set tSC = ##class(OcuPilot.Port.AdminPort).PollTask(pGuid, .tAnswer, .tHttp)
        If $$$ISOK(tSC) && $IsObject(tAnswer) Set tState = tAnswer.%Get("State")
        If $$$ISERR(tSC) || (tState = "Finished") || (tState = "Failed") || (tState = "Canceled") || ($ZHorolog >= tEnd) Quit
        Hang 0.2
    }
    If (tState = "Finished") || (tState = "Failed") || (tState = "Canceled") Do ##class(OcuPilot.Port.AdminPort).ForgetTask(pGuid)
    Quit tState
}

/// <p>Forget the task this port last polled, and its poll count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDatabaseQueued
}

}
