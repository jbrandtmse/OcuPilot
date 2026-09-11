/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> that captures what
/// an ensure step reports through the <method>OcuPilot.Install.Installer.LogInfo</method>
/// / <method>LogWarn</method> seam, instead of writing to the console log -- the same
/// shape as <class>OcuPilot.Test.LogProbe</class> and <class>OcuPilot.Test.ErrorProbe</class>.</p>
/// <p>Every ensure step reaches the seam through <code>..</code> dispatch, so calling any
/// public entry point (<method>OcuPilot.Install.Installer.EnsureGrant</method> included)
/// on this subclass routes the real production code path into the capture below without
/// touching the production class or the real console log.</p>
Class OcuPilot.Test.InstallerProbe Extends OcuPilot.Install.Installer
{

/// <p>Captures into the process-private global <code>^||OcuPilotInstallerProbe</code>.
/// Subscripts follow ObjectScript identifier rules (no hyphens) per
/// <file>.claude/rules/objectscript-basics.md</file>.</p>
ClassMethod LogInfo(pMessage As %String, pData As %DynamicObject = "")
{
    Set ^||OcuPilotInstallerProbe("info", $Increment(^||OcuPilotInstallerProbe("info"))) = pMessage
    Set ^||OcuPilotInstallerProbe("lastInfo") = pMessage
    Set ^||OcuPilotInstallerProbe("lastInfoData") = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
}

/// <p>See <method>LogInfo</method>.</p>
ClassMethod LogWarn(pMessage As %String, pData As %DynamicObject = "")
{
    Set ^||OcuPilotInstallerProbe("warn", $Increment(^||OcuPilotInstallerProbe("warn"))) = pMessage
    Set ^||OcuPilotInstallerProbe("lastWarn") = pMessage
    Set ^||OcuPilotInstallerProbe("lastWarnData") = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
}

/// <p>Discard anything a previous capture left behind.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotInstallerProbe
}

/// <p>Read one captured field back. Returns <code>""</code> when nothing was captured.</p>
/// @param pField One of "lastInfo", "lastInfoData", "lastWarn", "lastWarnData"
ClassMethod Captured(pField As %String) As %String
{
    Quit $Get(^||OcuPilotInstallerProbe(pField), "")
}

/// <p>(Story 1.4) Records the <var>pAccount</var> and <var>pFirstInstall</var>
/// arguments <method>OcuPilot.Install.Installer.Install</method>'s call site actually
/// passed, then delegates to the real behavior via <code>##super()</code> -- so
/// <class>OcuPilot.Test.Version</class> can assert what the <b>call site</b> computed
/// (AC4, AC14), not only what <method>EnsureUnexpired</method> does when driven
/// directly with an explicit argument.</p>
ClassMethod EnsureUnexpired(pAccount As %String, pFirstInstall As %Boolean, ByRef pReports) As %Status
{
    Set ^||OcuPilotInstallerProbe("unexpireAccountArg") = pAccount
    Set ^||OcuPilotInstallerProbe("firstInstallArg") = pFirstInstall
    Quit ##super(pAccount, pFirstInstall, .pReports)
}

/// <p>See <method>EnsureUnexpired</method>. Returns <code>""</code> when no call was
/// captured.</p>
ClassMethod CapturedUnexpireAccountArg() As %String
{
    Quit $Get(^||OcuPilotInstallerProbe("unexpireAccountArg"), "")
}

/// <p>See <method>EnsureUnexpired</method>. Returns <code>""</code> when no call was
/// captured.</p>
ClassMethod CapturedFirstInstallArg() As %String
{
    Quit $Get(^||OcuPilotInstallerProbe("firstInstallArg"), "")
}

/// <p>(Story 1.4, DW-56) Records that <method>OcuPilot.Install.Installer.StartPath</method>
/// reached its demo-fixture call site, and deliberately does <b>not</b> delegate to the
/// real <method>OcuPilot.Install.Installer.CreateDemoFixtures</method>: a test driving
/// <code>StartPath(1)</code> on this probe must never create, adopt or re-run a real
/// production-profile fixture on the shared instance. Only <class>OcuPilot.Test.DemoOptIn</class>
/// drives <code>StartPath</code> through this class with the flag set; every other caller
/// passes <code>0</code>, so nothing else depends on the real call happening here.</p>
ClassMethod CreateDemoFixtures(ByRef pFixtureReports) As %Status
{
    Set ^||OcuPilotInstallerProbe("demoFixtureCalls") = $Get(^||OcuPilotInstallerProbe("demoFixtureCalls"), 0) + 1
    Quit $$$OK
}

/// <p>How many times <method>CreateDemoFixtures</method> was reached since the last
/// <method>Clear</method>. Returns <code>0</code> when it was never reached.</p>
ClassMethod CapturedDemoFixtureCalls() As %Integer
{
    Quit +$Get(^||OcuPilotInstallerProbe("demoFixtureCalls"), 0)
}

/// <p>Every message captured at <var>pLevel</var> during the run, joined with
/// <code>$Char(10)</code> -- unlike <method>Captured</method>'s "last" fields, this
/// survives a later report at the same level overwriting the one a test actually cares
/// about (e.g. <method>OcuPilot.Install.Installer.EnsureGrant</method>'s own "info"
/// report running after <method>OcuPilot.Install.Installer.EnsureAuditingEnabled</method>'s).
/// Returns <code>""</code> when nothing was captured at that level.</p>
/// @param pLevel "info" or "warn"
ClassMethod CapturedAll(pLevel As %String) As %String
{
    Set tResult = ""
    Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, ""))
    While tN '= "" {
        Set tResult = tResult _ $Select(tResult = "": "", 1: $Char(10)) _ ^||OcuPilotInstallerProbe(pLevel, tN)
        Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, tN))
    }
    Quit tResult
}

}
