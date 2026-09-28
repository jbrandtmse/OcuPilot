/// <p>Test-only <class>OcuPilot.Port.NamespacePort</class> subclass whose queued copy of mappings is
/// never terminal at the bound: <method>AsyncTimeout</method> is 0 and <method>PollTask</method>
/// answers every polled task <parameter>RUNNING</parameter> without reading it, and records its id.
/// The copy itself is queued and run by the vendor's worker as shipped, and its finished result is
/// read once, by <method>Settle</method>, which then deletes the row.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceStartedPort Extends OcuPilot.Port.NamespacePort
{

/// <p>The state every poll reports, and the two terminal states <method>Settle</method> waits for.</p>
Parameter RUNNING = "Running";

Parameter FINISHED = "Finished";

Parameter FAILED = "Failed";

ClassMethod AsyncTimeout() As %Numeric
{
    Quit 0
}

/// <p>The task's id recorded and a running answer, without reading the task: the finished result is
/// <method>Settle</method>'s to read, once.</p>
ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set ^||OcuPilotNamespaceStarted = pGuid
    Set pAnswer = {}
    Do pAnswer.%Set("State", ..#RUNNING, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The id of the task polled last in this process, or <code>""</code>.</p>
ClassMethod LastTask() As %String
{
    Quit $Get(^||OcuPilotNamespaceStarted)
}

/// <p>Wait up to <var>pSeconds</var> for task <var>pGuid</var> to reach a terminal state through the
/// shipped poll, reading a finished task once and removing its row, and answer the last state read
/// (<code>""</code> when none could be read).</p>
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
        Hang 0.2
    }
    If (tState = ..#FINISHED) || (tState = ..#FAILED) Do ##class(OcuPilot.Port.AdminPort).ForgetTask(pGuid)
    Quit tState
}

ClassMethod Clear()
{
    Kill ^||OcuPilotNamespaceStarted
}

}
