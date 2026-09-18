/// <p>Subclass of <class>OcuPilot.Port.MonitorPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.MonitorPort</class> and <class>OcuPilot.Test.MonitorPortDenial</class> run
/// the port's real gate order, argument checks, status mapping and row building against
/// <class>OcuPilot.Test.MonitorSensorFixture</class>.</p>
/// <p><method>SensorClass</method> always answers the fixture and <method>SensorNamespace</method>
/// the current namespace, because an <code>OcuPilot.*</code> class is invisible from
/// <code>%SYS</code>. <method>GateClass</method> answers the real gate unless a test arms another
/// (<class>OcuPilot.Test.ScreenGate</class>), and <method>LogFault</method> always routes through
/// <class>OcuPilot.Test.FaultProbe</class>, so vendor text lands in the capture rather than
/// <file>messages.log</file>. State lives in <code>^||OcuPilotMonitorPortFixture</code>.</p>
Class OcuPilot.Test.MonitorPortFixture Extends OcuPilot.Port.MonitorPort
{

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real
/// gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotMonitorPortFixture("gate") = pClass
}

/// <p>Forget every override.</p>
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

ClassMethod SensorClass() As %String
{
    Quit "OcuPilot.Test.MonitorSensorFixture"
}

ClassMethod SensorNamespace() As %String
{
    Quit $Namespace
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("monitorport", pMessage, pStatus, pCode)
}

}
