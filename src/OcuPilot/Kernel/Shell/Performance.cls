/// <p>The five instance metrics Home's performance row reports (Story 16.18, AD-43, AD-29, AD-50's
/// shell-chrome precedent).</p>
/// <p><class>OcuPilot.Api.UiPerformance</class> answers it as
/// <code>GET /api/ocupilot/ui/performance</code>. It is not a screen, a declared read or a tool: the
/// row is shell chrome on Home, which never gates, and the agent receives the values through Home's
/// screen context (AD-24). Every value comes from one collection through
/// <class>OcuPilot.Port.MonitorPort</class>, whose gate this read inherits unchanged.</p>
Class OcuPilot.Kernel.Shell.Performance Extends %RegisteredObject
{

/// <p>The port the values are read through.</p>
Parameter PORTCLASS = "OcuPilot.Port.MonitorPort";

/// <p>The port seam: a class name, so a test can answer a substitute port.</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p>Read the five values once, writing nothing. The outputs are
/// <method>OcuPilot.Port.MonitorPort.Performance</method>'s, unchanged: <var>pValues</var> on
/// success, or an error status with <var>pHttpStatus</var> and the wire fault
/// <var>pFault</var>.</p>
ClassMethod Read(Output pValues As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod(..PortClass(), "Performance", .pValues, .pHttpStatus, .pFault)
}

}
