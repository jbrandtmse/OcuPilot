/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> whose poll of a finished task answers the
/// console lines and the terminal state a test arms (Story 18.5): <method>PollTask</method> reads the
/// vendor's own answer and, once that answer is finished, replaces its <code>Console</code> with
/// <method>Arm</method>'s lines and its <code>State</code> with the armed state, so
/// <method>OcuPilot.Port.AdminPort.AwaitTask</method>'s
/// <parameter>OcuPilot.Port.AdminPort.CONSOLEDTYPES</parameter> branches run over a real queued journal
/// integrity check. A poll answer that is not finished is passed through. Faults go to
/// <class>OcuPilot.Test.FaultProbe</class>, never <code>messages.log</code>. State lives in
/// <code>^||OcuPilotJournalConsolePort</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalConsolePort Extends OcuPilot.Port.AdminPort
{

/// <p>Answer the next finished poll in the vendor's state <var>pState</var> with <var>pCount</var>
/// console lines, <code>line 1</code> to <code>line &lt;pCount&gt;</code>.</p>
ClassMethod Arm(pState As %String, pCount As %Integer)
{
    Set ^||OcuPilotJournalConsolePort("state") = pState
    Set ^||OcuPilotJournalConsolePort("count") = +pCount
}

/// <p>Forget what was armed.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotJournalConsolePort
}

/// <p>The admin port's poll, with a finished answer's console and state replaced by the armed
/// ones.</p>
ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set tSC = ##super(pGuid, .pAnswer, .pHttpStatus)
    If $$$ISERR(tSC) || '$IsObject($Get(pAnswer)) Quit tSC
    If '$Data(^||OcuPilotJournalConsolePort("state")) Quit tSC
    If pAnswer.%Get("State") '= $Parameter(..#ASYNCTASKCLASS, "STATEFINISHED") Quit tSC
    Set tLines = []
    For tI = 1:1:^||OcuPilotJournalConsolePort("count") Do tLines.%Push("line " _ tI, "string")
    Do pAnswer.%Set("Console", tLines)
    Do pAnswer.%Set("State", ^||OcuPilotJournalConsolePort("state"), "string")
    Quit tSC
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

}
