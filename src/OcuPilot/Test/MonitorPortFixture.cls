/// <p>Subclass of <class>OcuPilot.Port.MonitorPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.MonitorPort</class> runs the port's real gate order, namespace switch and
/// parse against text the test supplies.</p>
/// <p><method>Source</method> answers the armed text and counts its calls; unarmed, it answers the
/// real collection. <method>UsageSource</method> likewise answers the rows armed for its endpoint
/// (<method>SetUsageRows</method>) and counts its calls and the namespace it ran in; unarmed, it
/// runs the real query. <method>GateClass</method> answers the real gate unless a test arms another
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

/// <p>The message of the last line <method>LogFault</method> wrote since the last <method>Clear</method>, or <code>""</code>.</p>
ClassMethod LastLog() As %String
{
    Quit $Get(^||OcuPilotMonitorPortFixture("lastLog"))
}

/// <p>Answer <method>UsageSource</method> for <var>pEndpoint</var> with the rows <var>pJson</var>
/// holds, a JSON array of objects whose values are the strings the vendor query answers, instead of
/// running the query. The fixture answers every armed row whatever the cap, so the port's own cut is
/// what a test observes.</p>
ClassMethod SetUsageRows(pEndpoint As %String, pJson As %String)
{
    Set ^||OcuPilotMonitorPortFixture("usage", pEndpoint) = pJson
}

/// <p>Make <method>UsageSource</method> fail: <code>1</code> raises, as a refused query would, and
/// <code>2</code> answers an error status; <code>0</code> restores it.</p>
ClassMethod SetUsageRaise(pMode As %Integer)
{
    Set ^||OcuPilotMonitorPortFixture("usageRaise") = pMode
}

/// <p>How many times <method>UsageSource</method> was called since the last <method>Clear</method>.</p>
ClassMethod UsageCalls() As %Integer
{
    Quit +$Get(^||OcuPilotMonitorPortFixture("usageCalls"))
}

/// <p>The namespace <method>UsageSource</method> last ran in.</p>
ClassMethod UsageNamespace() As %String
{
    Quit $Get(^||OcuPilotMonitorPortFixture("usageNamespace"))
}

/// <p>The columns <method>UsageSource</method> asks the vendor query behind <var>pEndpoint</var> for, as the
/// port's <method>UsageColumns</method> answers them.</p>
ClassMethod Columns(pEndpoint As %String) As %String
{
    Quit ..UsageColumns(pEndpoint)
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

ClassMethod UsageSource(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray) As %Status
{
    Set ^||OcuPilotMonitorPortFixture("usageCalls") = $Get(^||OcuPilotMonitorPortFixture("usageCalls")) + 1
    Set ^||OcuPilotMonitorPortFixture("usageNamespace") = $NAMESPACE
    Set tMode = +$Get(^||OcuPilotMonitorPortFixture("usageRaise"))
    If tMode = 1 {
        Throw ##class(%Exception.General).%New("OcuPilot.Test.MonitorPortFixture", 1, , "the fixture refused the usage query")
    }
    If tMode = 2 {
        Set pRows = []
        Quit $$$ERROR($$$GeneralError, "the fixture failed the usage query")
    }
    If $Data(^||OcuPilotMonitorPortFixture("usage", pEndpoint), tJson) {
        Set pRows = ##class(%DynamicArray).%FromJSON(tJson)
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pMax, .pRows)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotMonitorPortFixture("logCalls") = $Get(^||OcuPilotMonitorPortFixture("logCalls")) + 1
    Set ^||OcuPilotMonitorPortFixture("lastLog") = pMessage
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("monitorport", pMessage, pStatus, pCode)
}

}
