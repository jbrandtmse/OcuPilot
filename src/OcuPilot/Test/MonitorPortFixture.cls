/// <p>Subclass of <class>OcuPilot.Port.MonitorPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.MonitorPort</class> runs the port's real gate order, namespace switch and
/// parse against text the test supplies.</p>
/// <p><method>Source</method> answers the armed text and counts its calls; unarmed, it answers the
/// real collection. <method>GateClass</method> answers the real gate unless a test arms another
/// (<class>OcuPilot.Test.ScreenGate</class>). <method>LogFault</method> counts its calls and routes
/// through <class>OcuPilot.Test.FaultProbe</class>, so nothing reaches <file>messages.log</file>.
/// State lives in <code>^||OcuPilotMonitorPortFixture</code>.</p>
Class OcuPilot.Test.MonitorPortFixture Extends OcuPilot.Port.MonitorPort
{

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real
/// gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotMonitorPortFixture("gate") = pClass
}

/// <p>Answer <method>Source</method> with <var>pText</var> instead of the real collection.</p>
ClassMethod SetText(pText As %String)
{
    Set ^||OcuPilotMonitorPortFixture("text") = pText
}

/// <p>Make <method>Source</method> raise, as a refused <code>%SYS</code> read would.</p>
ClassMethod SetRaise(pRaise As %Boolean)
{
    Set ^||OcuPilotMonitorPortFixture("raise") = pRaise
}

/// <p>How many times <method>Source</method> was called since the last <method>Clear</method>.</p>
ClassMethod SourceCalls() As %Integer
{
    Quit +$Get(^||OcuPilotMonitorPortFixture("sourceCalls"))
}

/// <p>The namespace <method>Source</method> last ran in.</p>
ClassMethod SourceNamespace() As %String
{
    Quit $Get(^||OcuPilotMonitorPortFixture("sourceNamespace"))
}

/// <p>How many lines <method>LogFault</method> wrote since the last <method>Clear</method>.</p>
ClassMethod LogCalls() As %Integer
{
    Quit +$Get(^||OcuPilotMonitorPortFixture("logCalls"))
}

/// <p>Forget every override and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMonitorPortFixture
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotMonitorPortFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod Source() As %String
{
    Set ^||OcuPilotMonitorPortFixture("sourceCalls") = $Get(^||OcuPilotMonitorPortFixture("sourceCalls")) + 1
    Set ^||OcuPilotMonitorPortFixture("sourceNamespace") = $NAMESPACE
    If $Get(^||OcuPilotMonitorPortFixture("raise")) {
        Throw ##class(%Exception.General).%New("OcuPilot.Test.MonitorPortFixture", 1, , "the fixture refused the collection")
    }
    If $Data(^||OcuPilotMonitorPortFixture("text"), tText) Quit tText
    Quit ##super()
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotMonitorPortFixture("logCalls") = $Get(^||OcuPilotMonitorPortFixture("logCalls")) + 1
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("monitorport", pMessage, pStatus, pCode)
}

}
