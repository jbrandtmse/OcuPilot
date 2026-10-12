/// <p>Pins the one state row each of Story 20.23's five tools draws on its card (AD-51, AD-62), from a fresh read handed to
/// <code>StateDiff</code> directly: the queue abort's <code>Count</code> falling by the entries its read enumerated (which is
/// fewer than the queue holds once the queue exceeds <parameter>OcuPilot.Port.InteropPort.ABORTMAX</parameter>), the message
/// abort's <code>Status</code> moving to Aborted, and each job tool's field moving to its word. A read the action does not fit
/// answers the published sentence of the code <code>RowRefusal</code> names, and a read that left out the field it judges
/// answers that the instance did not report it.</p>
/// <p><b>What it needs from the environment:</b> the compiled tool classes. It starts nothing, writes nothing and arms nothing.</p>
Class OcuPilot.Test.InteropRuntimeCard Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter TOOLPACKAGE = "OcuPilot.Screen.Tool.";

/// <p>The card's rows of <class>OcuPilot.Screen.Tool.<var>pTool</var></class> for the read <var>pFresh</var> (JSON text), as
/// <code>&lt;rows JSON&gt;|&lt;problem&gt;</code>; <code>unread</code> when <code>StateDiff</code> itself failed.</p>
ClassMethod Diff(pTool As %String, pFresh As %String) As %String
{
    Set tFresh = $Select(pFresh = "": "", 1: ##class(%DynamicObject).%FromJSON(pFresh))
    Set tSC = $ClassMethod(..#TOOLPACKAGE _ pTool, "StateDiff", tFresh, .tRows, .tProblem)
    If $$$ISERR(tSC) Quit "unread"
    Quit tRows.%ToJSON() _ "|" _ tProblem
}

/// <p>AC2: the queue abort's card takes the entries its read enumerated off the queue's count: a queue holding more than the read
/// enumerated keeps the rest (<code>Count</code> 5, <code>Entries</code> 2 reads 5 to 3), one holding exactly the entries reads to 0,
/// and a count below the entries never reads below 0. A queue with no entry is refused by the published sentence of
/// <code>INTEROP.QUEUE.EMPTY</code>, and a read without a number for either field, or no read, is not reported.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropQueueAbort.StateDiff</method> set its after value to 0 -- the first
/// leg goes red.</p>
Method TestTheQueueAbortCardTakesOnlyTheEntriesItEnumeratedOffTheCount()
{
    Set tNone = "this instance did not report the queue's messages"
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":5,""Entries"":2}"), "[{""field"":""Count"",""before"":""5"",""after"":""3""}]|", "a queue holding more than the read enumerated keeps the rest")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":2,""Entries"":2}"), "[{""field"":""Count"",""before"":""2"",""after"":""0""}]|", "a queue holding exactly the entries reads to 0")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":1,""Entries"":3}"), "[{""field"":""Count"",""before"":""1"",""after"":""0""}]|", "and never below 0")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":4,""Entries"":0}"), "[]|" _ $Parameter(..#ERROR, "REASONQUEUEEMPTY"), "a queue with no entry is refused by the sentence of INTEROP.QUEUE.EMPTY")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":4}"), "[]|" _ tNone, "a read with no entry count is not reported")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", "{""Name"":""q"",""Count"":""4"",""Entries"":2}"), "[]|" _ tNone, "and neither is a count that is no number")
    Do $$$AssertEquals(..Diff("InteropQueueAbort", ""), "[]|" _ tNone, "nor no read at all")
}

/// <p>AC1: the message abort's card moves the message's <code>Status</code> from the word the read gave to Aborted, and a read that
/// answered no status is not reported.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropQueueMessageAbort.StateDiff</method> draw Suspended -- this goes
/// red.</p>
Method TestTheMessageAbortCardMovesTheStatusToAborted()
{
    Do $$$AssertEquals(..Diff("InteropQueueMessageAbort", "{""MessageId"":""17"",""Status"":""Queued""}"), "[{""field"":""Status"",""before"":""Queued"",""after"":""Aborted""}]|", "a queued message reads Queued to Aborted")
    Do $$$AssertEquals(..Diff("InteropQueueMessageAbort", "{""MessageId"":""17""}"), "[]|this instance did not report the message's state", "a read with no status is not reported")
    Do $$$AssertEquals(..Diff("InteropQueueMessageAbort", ""), "[]|this instance did not report the message's state", "nor no read at all")
}

/// <p>AC3, AC4: each job tool's card moves its field to its word -- the abort and the suspend the message the job is retrying to
/// Aborted or Suspended, the stop the job's status to Stopped. A job whose process has ended is refused by the sentence of
/// <code>INTEROP.JOB.DEAD</code> by all three; an abort or a suspend of a job not retrying a message by the sentence of
/// <code>INTEROP.JOB.NOTRETRYING</code>, which a stop does not need; and a read that left out the <code>Dead</code> flag is not
/// reported, since a job nobody established is not one to act on.</p>
/// <p>Mutation (Rule 19): drop the <code>RowRefusal</code> call from <method>OcuPilot.Screen.Tool.InteropJobAction.StateDiff</method>
/// -- the refusal legs go red.</p>
Method TestTheJobCardsMoveTheirFieldAndRefuseAJobTheActionDoesNotFit()
{
    Set tE = ..#ERROR
    Set tRetrying = "{""Host"":""h"",""Status"":""Retry"",""ActiveMessage"":""41"",""Dead"":false}"
    Set tIdle = "{""Host"":""h"",""Status"":""OK"",""ActiveMessage"":"""",""Dead"":false}"
    Set tDead = "{""Host"":""h"",""Status"":""OK"",""ActiveMessage"":"""",""Dead"":true}"
    Do $$$AssertEquals(..Diff("InteropJobAbort", tRetrying), "[{""field"":""ActiveMessage"",""before"":""41"",""after"":""Aborted""}]|", "an abort draws the retried message going to Aborted")
    Do $$$AssertEquals(..Diff("InteropJobSuspend", tRetrying), "[{""field"":""ActiveMessage"",""before"":""41"",""after"":""Suspended""}]|", "a suspend draws it going to Suspended")
    Do $$$AssertEquals(..Diff("InteropJobStop", tIdle), "[{""field"":""Status"",""before"":""OK"",""after"":""Stopped""}]|", "a stop of a job that is not retrying draws its status going to Stopped")
    Do $$$AssertEquals(..Diff("InteropJobStop", tRetrying), "[{""field"":""Status"",""before"":""Retry"",""after"":""Stopped""}]|", "and of one that is")
    For tTool = "InteropJobAbort", "InteropJobSuspend", "InteropJobStop" {
        Do $$$AssertEquals(..Diff(tTool, tDead), "[]|" _ $Parameter(tE, "REASONJOBDEAD"), tTool _ ": a job whose process has ended is refused by the sentence of INTEROP.JOB.DEAD")
        Do $$$AssertEquals(..Diff(tTool, "{""Host"":""h"",""Status"":""OK""}"), "[]|this instance did not report the job's state", tTool _ ": a read with no Dead flag is not reported")
        Do $$$AssertEquals(..Diff(tTool, ""), "[]|this instance did not report the job's state", tTool _ ": nor no read at all")
    }
    For tTool = "InteropJobAbort", "InteropJobSuspend" {
        Do $$$AssertEquals(..Diff(tTool, tIdle), "[]|" _ $Parameter(tE, "REASONJOBNOTRETRYING"), tTool _ ": a job not retrying a message is refused by the sentence of INTEROP.JOB.NOTRETRYING")
        Do $$$AssertEquals(..Diff(tTool, "{""Host"":""h"",""Status"":""Retry"",""ActiveMessage"":"""",""Dead"":false}"), "[]|" _ $Parameter(tE, "REASONJOBNOTRETRYING"), tTool _ ": and so is one reading Retry with no message")
    }
}

}
