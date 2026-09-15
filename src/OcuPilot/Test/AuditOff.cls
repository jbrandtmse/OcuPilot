/// <p>DW-45 (rework iteration 6 review). Test-only subclass of
/// <class>OcuPilot.Install.Installer</class> that reports instance auditing as off, on,
/// or unreadable, and records a request to turn it on <b>without ever making it</b> -- so
/// <class>OcuPilot.Test.AuditEnable</class> can drive the real
/// <method>OcuPilot.Install.Installer.EnsureAuditingEnabled</method> down its enable
/// branch in-process. This image starts with <code>AuditEnabled = 1</code>, so no
/// instance the suite runs against reaches that branch, and the Never list forbids
/// turning auditing off on the shared instance to get there.</p>
/// <p>The mode and the call count live in process-private globals, as in
/// <class>OcuPilot.Test.MigrateFault</class>, because the real code path makes
/// class-method dispatches that never carry an instance.</p>
Class OcuPilot.Test.AuditOff Extends OcuPilot.Install.Installer
{

/// <p>Mode 1: the setting reads 0 (auditing off).</p>
Parameter OFFMODE = 1;

/// <p>Mode 2: the setting reads 1 (auditing already on).</p>
Parameter ONMODE = 2;

/// <p>Mode 3: the read fails with an error status.</p>
Parameter READFAILSMODE = 3;

/// <p>Select what <method>AuditEnabledSetting</method> reports and clear the call count.</p>
ClassMethod Arm(pMode As %Integer)
{
    Set ^||OcuPilotAuditOffMode = pMode
    Kill ^||OcuPilotAuditOffEnables
}

/// <p>Back to no mode, count cleared. Called from every driving test's cleanup path.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotAuditOffMode, ^||OcuPilotAuditOffEnables
}

/// <p>How many times <method>EnableInstanceAuditing</method> was reached since the last
/// <method>Arm</method> or <method>Disarm</method>.</p>
ClassMethod EnableCalls() As %Integer
{
    Quit +$Get(^||OcuPilotAuditOffEnables, 0)
}

/// <p>Drive the real, unmodified <code>[ Private ]</code>
/// <method>OcuPilot.Install.Installer.EnsureAuditingEnabled</method> through inherited
/// <code>..</code> dispatch. With both seams below overridden nothing it calls touches
/// <code>Security.System</code>, so no <code>%SYS</code> window is needed. Refuses to run
/// unarmed, so it can never reach the real read or write.</p>
ClassMethod DriveEnsureAuditing(ByRef pReports) As %Status
{
    If '$Data(^||OcuPilotAuditOffMode) Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditOff: arm a mode before driving EnsureAuditingEnabled")
    Quit ..EnsureAuditingEnabled(.pReports)
}

/// <p>The setting, as the armed mode says.</p>
ClassMethod AuditEnabledSetting(Output pEnabled As %Boolean) As %Status [ Private ]
{
    Set pEnabled = ""
    Set tMode = +$Get(^||OcuPilotAuditOffMode, 0)
    If tMode = ..#READFAILSMODE Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditOff: induced AuditEnabled read failure")
    Set pEnabled = $Select(tMode = ..#ONMODE: 1, 1: 0)
    Quit $$$OK
}

/// <p>Records the request and returns OK. Never delegates to the real write, armed or
/// not: this class must not be able to change the shared instance's auditing.</p>
ClassMethod EnableInstanceAuditing() As %Status [ Private ]
{
    Set ^||OcuPilotAuditOffEnables = +$Get(^||OcuPilotAuditOffEnables, 0) + 1
    Quit $$$OK
}

}
