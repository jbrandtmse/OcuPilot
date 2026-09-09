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
