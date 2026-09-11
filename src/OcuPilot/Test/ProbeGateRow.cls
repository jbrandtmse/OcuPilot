/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> whose version-row read
/// (<method>OcuPilot.Install.Installer.CurrentVersionRow</method>) always reads the
/// <code>"probe"</code> profile's real, saved row, whatever profile is asked for. So
/// <code>##class(OcuPilot.Test.ProbeGateRow).GateStatus()</code> runs the real, unmodified
/// <method>OcuPilot.Install.Installer.GateStatus</method> ladder -- which always asks for the
/// production row -- against the probe's row instead, and
/// <class>OcuPilot.Test.InstallMark</class> can watch the gate across a real mark and a real
/// install without writing to the shared production row (DW-72, rework iteration 8).</p>
/// <p>Where <class>OcuPilot.Test.GateLadderRow</class> serves synthetic, never-saved rows to
/// pin each rung of the ladder, this one serves the row <method>OcuPilot.Install.Installer.MarkInstalling</method>
/// and <method>OcuPilot.Install.Installer.Install</method> actually wrote.</p>
Class OcuPilot.Test.ProbeGateRow Extends OcuPilot.Install.Installer
{

/// <p>The <code>"probe"</code> profile's real row, for every profile asked.</p>
ClassMethod CurrentVersionRow(pProfile As %String, Output pRow) As %Status
{
    Quit ##super("probe", .pRow)
}

}
