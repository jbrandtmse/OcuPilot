/// <p>Test-only <class>OcuPilot.Port.AuditPort</class> subclass whose vendor task is never terminal
/// at the bound: <method>AsyncTimeout</method> is 0 and <method>PollTask</method> reports every
/// polled task <parameter>RUNNING</parameter>, whatever the vendor answered, and records its id. The
/// task itself is queued and run by the vendor's worker as shipped.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuditStartedPort Extends OcuPilot.Port.AuditPort
{

/// <p>The state every poll reports, and the two terminal states <method>Settle</method> waits for.</p>
Parameter RUNNING = "Running";

Parameter FINISHED = "Finished";

Parameter FAILED = "Failed";

ClassMethod AsyncTimeout() As %Numeric
{
    Quit 0
}

ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set ^||OcuPilotAuditStarted = pGuid
    Set tSC = ##super(pGuid, .pAnswer, .pHttpStatus)
    If $IsObject($Get(pAnswer)) Do pAnswer.%Set("State", ..#RUNNING, "string")
    Quit tSC
}

/// <p>The id of the task polled last in this process, or <code>""</code>.</p>
ClassMethod LastTask() As %String
{
    Quit $Get(^||OcuPilotAuditStarted)
}

/// <p>Wait up to <var>pSeconds</var> for task <var>pGuid</var> to reach a terminal state through the
/// shipped poll, remove its row once it has, and answer the last state read (<code>""</code> when
/// none could be read).</p>
ClassMethod Settle(pGuid As %String, pSeconds As %Integer = 60) As %String
{
    Set tState = ""
    If pGuid = "" Quit tState
    Set tEnd = $ZHorolog + pSeconds
    For {
        Set tAnswer = ""
        Set tSC = ##class(OcuPilot.Port.AdminPort).PollTask(pGuid, .tAnswer, .tHttp)
        If $$$ISOK(tSC) && $IsObject(tAnswer) Set tState = tAnswer.%Get("State")
        If (tState = ..#FINISHED) || (tState = ..#FAILED) || ($ZHorolog >= tEnd) Quit
        Hang 0.5
    }
    If (tState = ..#FINISHED) || (tState = ..#FAILED) Do ##class(OcuPilot.Port.AdminPort).ForgetTask(pGuid)
    Quit tState
}

ClassMethod Clear()
{
    Kill ^||OcuPilotAuditStarted
}

}
