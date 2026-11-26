/// <p>Pins Story 24.17 Batch 4's refusals and failures (AD-6, AD-9, AD-15, AD-36, AD-58, AD-62): an assign or cancel the namespace's task cannot take is refused by name before any vendor call, in the
/// order the spec names them, leaving the task and its worklist as they were and recording no audit row; and a vendor error status or fault is 500 <code>INTERNAL</code>, never 200, even after part of the
/// write was saved, with its audit row <code>completed</code> false, no subject or vendor text in a log line, and nothing logged while the namespace is switched.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs. The cancel leg starts the probe production in <code>USER</code> and removes it.</p>
Class OcuPilot.Test.InteropWorkflowTaskRefusals Extends OcuPilot.Test.InteropWorkflowTaskCase
{

/// <p>How many times the vendor seam was reached since the test began.</p>
ClassMethod Ran() As %Integer
{
    Quit +$Get(^IRIS.Temp.OcuProbe2417wMode("ran"))
}

/// <p>The seam's calls of an assign of <var>pId</var> with the arguments, as <method>Assign</method> answers them.</p>
ClassMethod Via(pId As %String, pUser As %String, pPriority As %String, Output pFault) As %String
{
    Quit ..Assign(pId, pUser, pPriority, .tResult, .pFault, ..#SOURCE, ..#SEAM)
}

/// <p>AC4: each value the classic dialog would not take is refused by name before any vendor call, the user and the priority together when both are wrong: a name that is no workflow user, one in another letter
/// case, an inactive user, a priority of 0, 6 or text, an assign that changes nothing; the task and its worklist are unchanged and no row is recorded.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskJudge</method> accept an inactive user -- the inactive leg goes red.</p>
Method TestEachValueIsRefusedByNameBeforeAnyVendorCall()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, ..#USERA, ..#USERA)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "SetPriority", tId, 3), "the task is given priority 3")
    Set tBefore = ..Facts(tId)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Via(tId, "OcuP2417wNobody", "", .tFault), "422 INTEROP.WORKFLOW.TASKUSER", "a name that is no workflow user is refused")
    Do $$$AssertEquals(..Via(tId, $ZConvert(..#USERB, "L"), "", .tFault), "422 INTEROP.WORKFLOW.TASKUSER", "a name in another letter case is refused")
    Do $$$AssertEquals(..Via(tId, ..#USERC, "", .tFault), "422 INTEROP.WORKFLOW.TASKUSER", "an inactive user is refused")
    Do $$$AssertEquals(..Via(tId, "a" _ $Char(9) _ "b", "", .tFault), "422 INTEROP.WORKFLOW.TASKUSER", "a name holding a control character is refused")
    For tPriority = "0", "6", "x", "2.5", "-1", "03" {
        Do $$$AssertEquals(..Via(tId, $Char(0), tPriority, .tFault), "422 INTEROP.WORKFLOW.TASKPRIORITY", "a priority of '" _ tPriority _ "' is refused")
    }
    Do $$$AssertEquals(..Via(tId, "OcuP2417wNobody", "9", .tFault), "422 INTEROP.WORKFLOW.TASKUSER", "a bad user and a bad priority together are refused")
    Do $$$AssertEquals($Select($IsObject(tFault.detail.violations): tFault.detail.violations.%Size(), 1: 0), 2, "with both violations reported")
    Do $$$AssertEquals(..Via(tId, ..#USERA, "", .tFault), "409 INTEROP.WORKFLOW.TASKUNCHANGED", "the assignee it already has is refused as nothing to change")
    Do $$$AssertEquals(..Via(tId, ..#USERA, "3", .tFault), "409 INTEROP.WORKFLOW.TASKUNCHANGED", "and so is the same user with the priority it holds")
    Do $$$AssertEquals(..Ran(), 0, "no refusal reached the vendor")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "and none was logged")
    Do $$$AssertEquals(..Facts(tId), tBefore, "the task and its worklist are unchanged")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 0, "and no row was recorded")
    Do $$$AssertEquals(..Act("assign", tId, {"User": "OcuP2417wNobody"}, .tAnswer), "422 INTEROP.WORKFLOW.TASKUSER", "the screen's Assign of a bad user is refused by the same code")
    Do $$$AssertEquals(..Act("assign", tId, {"Priority": "6"}, .tAnswer), "400 TOOL.ARGUMENTS", "and of a bad priority by the tool's argument check")
    Do $$$AssertEquals(..Act("assign", tId, {"User": (..#USERA)}, .tAnswer), "409 INTEROP.WORKFLOW.TASKUNCHANGED", "and of what the task holds as unchanged")
    Do $$$AssertEquals(..Facts(tId), tBefore, "the screen's refusals changed nothing")
}

/// <p>AC4: a task that is complete is refused by both writes with <code>INTEROP.WORKFLOW.TASKCOMPLETE</code>, ahead of the values and of the production; an id no task holds, or the port does not read, is
/// 404; the refusals call no vendor and record no row; and the one-task read composed for the write refuses the same way.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskWriteToken</method> not refuse a complete task -- the complete legs go red.</p>
Method TestACompleteOrMissingTaskIsRefusedByBothWrites()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", "")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "CompleteProbe", tId, "Cancelled"), "a task is completed")
    Set tBefore = ..Facts(tId)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Via(tId, ..#USERA, "3", .tFault), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "an assign of it is refused as complete, ahead of its values")
    Do $$$AssertEquals(..Via(tId, "OcuP2417wNobody", "9", .tFault), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "even with values that are wrong")
    Do $$$AssertEquals(..Cancel(tId, .tResult, .tFault, ..#SOURCE, ..#SEAM), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "a cancel of it is refused as complete, ahead of the production")
    Do $$$AssertEquals(..Act("assign", tId, {"User": (..#USERA)}, .tAnswer), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "the screen's Assign of it is refused")
    Do $$$AssertEquals(..Act("cancel", tId, "", .tAnswer), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "and its Cancel task")
    For tMissing = "999999999", "0", "abc", "-5", "01" {
        Do $$$AssertEquals(..Via(tMissing, ..#USERA, "", .tFault), "404 PORT.NOTFOUND", "an assign of '" _ tMissing _ "' finds no task")
        Do $$$AssertEquals(..Cancel(tMissing, .tResult, .tFault, ..#SOURCE, ..#SEAM), "404 PORT.NOTFOUND", "and so does a cancel")
    }
    Do $$$AssertEquals(..Ran(), 0, "no refusal reached the vendor")
    Do $$$AssertEquals(..Facts(tId), tBefore, "the completed task is unchanged")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 0, "and no row was recorded")
    Do $$$AssertEquals(..Read(tId, "CANCELWORKFLOWTASK", .tRow, .tFault), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "the read composed for a cancel refuses the same way")
}

/// <p>AC4: a task another process holds locked is refused 503 before the vendor is called, leaves the task as it was and records no row, and the same assign is applied once the lock is released.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowTask</method> open the task at concurrency 0 -- the locked leg goes red.</p>
Method TestALockedTaskIsRefusedWithoutCallingTheVendor()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", ..#USERA)
    Set tBefore = ..Facts(tId)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "HoldLock", tId, 6), "another process holds the task's lock")
    Set tTimeout = $ZUtil(115, 4, 1)
    Set tText = ..Via(tId, ..#USERB, "", .tFault)
    Do $ZUtil(115, 4, tTimeout)
    Do $$$AssertEquals($Piece(tText, " ", 1), 503, "an assign of a locked task is 503: " _ tText)
    Do $$$AssertEquals(..Ran(), 0, "the vendor was not called")
    Do $$$AssertEquals(..Facts(tId), tBefore, "and the task is as it was")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 0, "and no row was recorded")
    Hang 7
    Do $$$AssertEquals($Piece(..Via(tId, ..#USERB, "", .tFault), " ", 1), 200, "once the lock is released the same assign is applied")
    Do $$$AssertEquals(..Ran(), 1, "and reaches the vendor")
}

/// <p>AC5: a vendor error status after the unassign saved, a status for a cancel, and a fault in either write are 500 <code>INTERNAL</code>, never 200; the audit row reads <code>completed</code> false and
/// still names the namespace and the task; the log lines carry the vendor's code and no subject or vendor text; and nothing is logged while the namespace is switched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowTask</method> ignore the vendor's status -- the status legs go red.</p>
Method TestAVendorErrorIsNeverA200AndLogsNothingItShouldNot()
{
    Set tMarker = $Parameter(..#SEAM, "MARKER")
    Set tSubject = $Parameter(..#FIXTURE, "TASKSUBJECT")
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, ..#USERA, ..#USERA)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "SetPriority", tId, 3), "the task is given priority 3")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set ^IRIS.Temp.OcuProbe2417wMode = "status"
    Do $$$AssertEquals(..Via(tId, "", "", .tFault), "500 INTERNAL", "an unassign whose vendor answers an error status after its save is 500")
    Do $$$AssertEquals(..Facts(tId), ..#ROLE _ "||3|Unassigned|0#" _ ..#USERA _ "," _ ..#USERB, "the vendor's own save is left: the task is unassigned and sent to the members")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 1, "one audit row was recorded")
    Do $$$AssertTrue((tData [ """completed"":false") && (tData [ "USER") && (tData '[ tMarker) && (tData '[ tSubject), "reading completed false, naming the namespace, and no vendor text or subject: " _ tData)
    Do $$$AssertTrue($ClassMethod(..#SEAM, "Logged") > 0, "the failure was logged")
    Do $$$AssertTrue(($ClassMethod(..#SEAM, "LoggedText") '[ tMarker) && ($ClassMethod(..#SEAM, "LoggedText") '[ tSubject), "without the vendor's text or the subject: " _ $ClassMethod(..#SEAM, "LoggedText"))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "LoggedIn") [ ..#SOURCE, 0, "and no line was logged while the task's namespace was switched to")
    Do $ClassMethod(..#SEAM, "ClearLog")
    Set ^IRIS.Temp.OcuProbe2417wMode = "fault"
    Do $$$AssertEquals(..Via(tId, ..#USERB, "", .tFault), "500 INTERNAL", "a fault in the assign is 500")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 2, 1), 2, "and records a second row")
    Do $$$AssertTrue((tData [ """completed"":false") && (tData '[ tMarker), "reading completed false and no fault text: " _ tData)
    Do $$$AssertTrue(($ClassMethod(..#SEAM, "LoggedText") '[ tMarker) && ($ClassMethod(..#SEAM, "LoggedText") '[ tSubject), "the fault's text and the subject are not in a log line")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "LoggedIn") [ ..#SOURCE, 0, "and no line was logged in the task's namespace")
    Do $ClassMethod(..#SEAM, "ClearLog")
    Set ^IRIS.Temp.OcuProbe2417wMode = "here"
    Do $$$AssertEquals(..Via(tId, ..#USERA, "", .tFault), "500 INTERNAL", "a fault raised inside the switched block is 500")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "LoggedIn") [ ..#SOURCE, 0, "and logged after the namespace was restored")
    Do $$$AssertEquals(..Facts(tId), ..#ROLE _ "||3|Unassigned|0#" _ ..#USERA _ "," _ ..#USERB, "and the task is as it was")
    Kill ^IRIS.Temp.OcuProbe2417wMode
    Do $ClassMethod(..#SEAM, "ClearLog")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "LiveStart", ..#ROLE), "the probe production runs")
    Set tLive = $ClassMethod(..#FIXTURE, "LiveTask")
    Do $$$AssertTrue(tLive > 0, "a live task is stored")
    If 'tLive Quit
    Set tOpen = ..State(tLive)
    Set ^IRIS.Temp.OcuProbe2417wMode = "status"
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault, ..#SOURCE, ..#SEAM), "500 INTERNAL", "a cancel whose vendor answers an error status is 500")
    Do $$$AssertEquals(..State(tLive), tOpen, "and the task is as it was")
    Do $$$AssertEquals(..TaskRows(tSince, tLive, .tData, 1, 1), 1, "its audit row was recorded")
    Do $$$AssertTrue((tData [ """completed"":false") && (tData '[ tMarker), "reading completed false: " _ tData)
    Set ^IRIS.Temp.OcuProbe2417wMode = "fault"
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault, ..#SOURCE, ..#SEAM), "500 INTERNAL", "a fault in the cancel is 500")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Received"), "-", "and the waiting process was given nothing")
    Do $$$AssertTrue(($ClassMethod(..#SEAM, "LoggedText") '[ tMarker) && ($ClassMethod(..#SEAM, "LoggedText") '[ tSubject), "no cancel log line carries the vendor's text or a subject")
}

/// <p>The task <var>pId</var> as <code>status|complete#users</code>.</p>
ClassMethod State(pId As %String) As %String
{
    Quit $Piece($ClassMethod(..#FIXTURE, "TaskText", ..#SOURCE, pId), "|", 4, 5) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, pId)
}

}
