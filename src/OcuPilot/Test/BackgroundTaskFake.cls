/// <p>A stand-in for the vendor's background task, <class>%SYS.BackgroundTask</class>, that does no
/// work: <method>%OpenId</method> answers an instance for the one task id armed by
/// <method>Arm</method>, and <method>Pause</method>, <method>Resume</method> and <method>Cancel</method>
/// record the call and answer OK, or the vendor error code armed by <method>ArmAnswer</method>. State
/// lives in <code>^||OcuPilotBackgroundTaskFake</code>; <method>Clear</method> forgets it.</p>
/// <p>It is the <parameter>OcuPilot.Port.BackgroundTaskPort.PORTALTASKCLASS</parameter> of
/// <class>OcuPilot.Test.BackgroundTaskPortOnFake</class>. The port opens that class in
/// <code>%SYS</code>, which sees this package only while
/// <class>OcuPilot.Test.BackgroundTaskPortSeam</class> maps it there.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundTaskFake Extends %RegisteredObject
{

/// <p>The task id this instance was opened for.</p>
Property TaskId As %String;

/// <p>Open the fake for <var>pId</var>: an instance when <var>pId</var> is the id <method>Arm</method>
/// armed, <code>""</code> otherwise, as <code>%OpenId</code> answers a task that is not there.</p>
ClassMethod %OpenId(pId As %String) As OcuPilot.Test.BackgroundTaskFake
{
    Set tFake = ""
    If (pId '= "") && (pId = $Get(^||OcuPilotBackgroundTaskFake("task"))) {
        Set tFake = ..%New()
        Set tFake.TaskId = pId
    }
    Quit tFake
}

/// <p>Record a pause request and answer the armed status.</p>
Method Pause() As %Status
{
    Quit ..Record("Pause")
}

/// <p>Record a resume request and answer the armed status.</p>
Method Resume() As %Status
{
    Quit ..Record("Resume")
}

/// <p>Record a cancel request and answer the armed status.</p>
Method Cancel() As %Status
{
    Quit ..Record("Cancel")
}

/// <p>Record <var>pMethod</var> against this task, then answer OK, or the vendor error code
/// <method>ArmAnswer</method> armed.</p>
Method Record(pMethod As %String) As %Status [ Private ]
{
    Set ^||OcuPilotBackgroundTaskFake("calls", $Increment(^||OcuPilotBackgroundTaskFake("calls"))) = pMethod _ " " _ ..TaskId
    Set tCode = +$Get(^||OcuPilotBackgroundTaskFake("answer"))
    If tCode = 0 Quit $$$OK
    Quit $System.Status.Error(tCode)
}

/// <p>Let <method>%OpenId</method> open the task <var>pId</var>, and no other.</p>
ClassMethod Arm(pId As %String)
{
    Set ^||OcuPilotBackgroundTaskFake("task") = pId
}

/// <p>Answer every control with the vendor error code <var>pCode</var>; <code>0</code> answers OK.</p>
ClassMethod ArmAnswer(pCode As %Integer)
{
    Set ^||OcuPilotBackgroundTaskFake("answer") = pCode
}

/// <p>Every control recorded, oldest first, each <code>&lt;method&gt; &lt;task id&gt;</code>, joined
/// by <code>|</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotBackgroundTaskFake("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tCall
    }
    Quit tOut
}

/// <p>Forget the armed task, the armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotBackgroundTaskFake
}

}
