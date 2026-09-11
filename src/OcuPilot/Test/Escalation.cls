/// <p><b>DW-63</b> (rework iteration 5): pins
/// <method>OcuPilot.Install.Installer.IsEscalationInfrastructureAbsent</method> -- the fix
/// for a real, live-discovered first-install failure (<code>ERROR #868: Application
/// OcuPilotState not found</code>) that shipped with no test of its own, because every
/// instance this suite runs against has carried the privileged routine application since
/// an early story. Pins the predicate <b>and</b> both of its call sites
/// (<method>OcuPilot.Install.Installer.Install</method>'s pre-read guard and
/// <method>OcuPilot.Install.Installer.EnsureVersion</method>'s), through
/// <class>OcuPilot.Test.EscalationGap</class>, which forces the "genuinely absent" state
/// in-process.</p>
/// <p>A separate class from <class>OcuPilot.Test.Version</class> only to keep each test
/// class near the ~500-line bound (<file>.claude/rules/objectscript-testing.md</file>).
/// One method drives a full <code>Install("probe")</code> and repairs it with a second;
/// nothing here uninstalls, so it adds no <code>DeleteDatabase</code> cycle (the
/// spec's cycling hazard).</p>
Class OcuPilot.Test.Escalation Extends %UnitTest.TestCase
{

/// <p><b>DW-63, the predicate.</b> <method>OcuPilot.Install.Installer.IsEscalationInfrastructureAbsent</method>
/// fixed a real, live-discovered first-install failure (<code>ERROR #868: Application
/// OcuPilotState not found</code>) and had no test of its own. Drives the real,
/// unmodified <code>[ Private ]</code> predicate (through
/// <class>OcuPilot.Test.EscalationGap</class>'s passthrough, fault disarmed) against the
/// real <code>Security.Applications</code> check twice: once for the privileged routine
/// application this instance genuinely carries, once for a name that cannot exist.</p>
Method TestEscalationPredicateReadsTheApplicationExistence()
{
    Do ##class(OcuPilot.Test.EscalationGap).Disarm()
    Set tRealApp = ##class(OcuPilot.Kernel.State.Base).#APPLICATION

    Kill tReportsPresent
    Set tAbsentForReal = ##class(OcuPilot.Test.EscalationGap).ProbeEscalationAbsent(tRealApp, .tReportsPresent)
    Do $$$AssertEquals(tAbsentForReal, 0, "the privileged routine application this instance really carries is read as present")
    Do $$$AssertTrue('$Data(tReportsPresent), "the routine, already-present case stays silent")

    Kill tReportsAbsent
    Set tAbsentForMissing = ##class(OcuPilot.Test.EscalationGap).ProbeEscalationAbsent("OcuPilotZZNoSuchAppC1A2B3", .tReportsAbsent)
    Do $$$AssertEquals(tAbsentForMissing, 1, "an application that does not exist is read as absent -- the genuinely-first-install state")
    Set tInfo = ""
    Set tN = $Order(tReportsAbsent(""))
    While tN '= "" {
        If tReportsAbsent(tN, "level") = "info" Set tInfo = tInfo _ tReportsAbsent(tN, "message")
        Set tN = $Order(tReportsAbsent(tN))
    }
    Do $$$AssertTrue(tInfo [ "Escalation infrastructure not found yet", "the absent case is reported once, at info level")
}

/// <p><b>DW-63, the <method>Install</method> call site</b> -- the one the live
/// <code>ERROR #868</code> actually came from. With the escalation infrastructure forced
/// absent, <method>OcuPilot.Install.Installer.Install</method> must skip its escalated
/// version-row read entirely (nothing could be recorded yet on a genuinely first install)
/// and treat the run as a first install, rather than failing closed on a read that
/// cannot succeed. <class>OcuPilot.Test.EscalationGap</class> counts every
/// <method>CurrentVersionRow</method> call, so this asserts the read was skipped, not
/// merely survived.</p>
/// <p>Forcing the predicate leaves the real application in place, so the forced run's own
/// closing <method>EnsureVersion</method> write (which also skips its read) inserts a
/// fresh probe row beside the existing one; <method>RepairProbeVersionRow</method> puts
/// the probe profile back to exactly one row with a real, unforced install, on every exit
/// path.</p>
Method TestInstallSkipsTheEscalatedReadWhenAbsent()
{
    Do ##class(OcuPilot.Test.EscalationGap).Disarm()
    Do ##class(OcuPilot.Test.EscalationGap).Clear()
    Do ##class(OcuPilot.Test.EscalationGap).SetEscalationAbsent(1)
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Test.EscalationGap).Install("probe")
        Set tReads = ##class(OcuPilot.Test.EscalationGap).VersionReadCount()
        Set tFirst = ##class(OcuPilot.Test.EscalationGap).CapturedFirstInstallArg()
        Set tInfo = ##class(OcuPilot.Test.EscalationGap).CapturedAll("info")
    } Catch ex {
        Do ##class(OcuPilot.Test.EscalationGap).Disarm()
        Do ..RepairProbeVersionRow()
        Throw ex
    }
    Do ##class(OcuPilot.Test.EscalationGap).Disarm()

    Do $$$AssertStatusOK(tSC, "a first install whose escalation infrastructure is absent completes instead of failing on ERROR #868")
    Do $$$AssertEquals(tReads, 0, "Install never attempted the escalated version-row read while the escalation infrastructure was absent")
    Do $$$AssertEquals(tFirst, 1, "an absent escalation infrastructure is read as a first install")
    Do $$$AssertTrue(tInfo [ "Escalation infrastructure not found yet", "the genuinely-first-install branch is reported")

    Do ..RepairProbeVersionRow()
}

/// <p><b>DW-63, the <method>EnsureVersion</method> call site.</b> The same guard sits in
/// front of <method>OcuPilot.Install.Installer.EnsureVersion</method>'s own read. Drives
/// the real, unmodified <code>[ Private ]</code> method through
/// <class>OcuPilot.Test.EscalationGap</class>'s passthrough, on a disposable profile of its
/// own, and asserts the read was skipped and the row written.</p>
/// <p>Recorded honestly (<method>EnsureVersion</method>'s own header carries the full
/// correction): on a <i>genuinely</i> absent application the <code>GuardedSave</code> that
/// follows fails with the same <code>ERROR #868</code>, so this guard is outcome-neutral on
/// a real first install that fails before <method>EnsureApplication</method>. The row is
/// written here only because the fault forces the predicate while the real application
/// still exists. What this pins is the guard itself, which is what DW-63 asks for.</p>
Method TestEnsureVersionSkipsTheEscalatedReadWhenAbsent()
{
    Set tProfile = "escgap"
    Do ##class(OcuPilot.Kernel.State.Version).DeleteByProfile(tProfile)
    Do ##class(OcuPilot.Test.EscalationGap).Disarm()
    Do ##class(OcuPilot.Test.EscalationGap).SetEscalationAbsent(1)
    Set tSC = $$$OK
    Try {
        Kill tReports
        Set tSC = ##class(OcuPilot.Test.EscalationGap).ProbeEnsureVersion(tProfile, "failed", "EnsureDatabase", 0, ##class(OcuPilot.Kernel.State.Base).#APPLICATION, .tReports)
        Set tReads = ##class(OcuPilot.Test.EscalationGap).VersionReadCount()
    } Catch ex {
        Do ##class(OcuPilot.Test.EscalationGap).Disarm()
        Do ##class(OcuPilot.Kernel.State.Version).DeleteByProfile(tProfile)
        Throw ex
    }
    Do ##class(OcuPilot.Test.EscalationGap).Disarm()

    Do $$$AssertStatusOK(tSC, "the failure-path version write completes")
    Do $$$AssertEquals(tReads, 0, "EnsureVersion never attempted the escalated version-row read while the escalation infrastructure was absent")

    Set tRowSC = ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile(tProfile, .tRow)
    Do $$$AssertStatusOK(tRowSC, "read the disposable profile's row back")
    Do $$$AssertTrue($IsObject(tRow), "the row was written")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.Phase, "failed", "the row records the failed phase")
        Do $$$AssertEquals(tRow.FailingStep, "EnsureDatabase", "the row names the failing step")
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile(tProfile), "cleanup removed the disposable profile's row")
}

/// <p>Put the probe profile back to exactly one version row with a real, unforced
/// <code>Install("probe")</code> -- called from both
/// <method>TestInstallSkipsTheEscalatedReadWhenAbsent</method>'s straight-line path and
/// its <code>Catch</code>, the same one-repair-path shape
/// <method>RepairProductionInstall</method> uses.</p>
Method RepairProbeVersionRow()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "cleared the probe version rows the forced run left behind")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a real, unforced probe install restores the probe version row")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS.N, 1, "the probe profile is back to exactly one version row")
}

}
