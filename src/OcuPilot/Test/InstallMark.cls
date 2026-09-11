/// <p><b>DW-72, the gate half</b> (AD-38 as amended 2026-09-11): pins
/// <method>OcuPilot.Install.Installer.MarkInstalling</method>, the mark the container start
/// hook makes before it recompiles OcuPilot. On a restart at the same schema version the
/// previous start's <code>installed</code> row used to answer the gate for the whole recompile
/// and re-install; from the mark on it must not, until this start's own install records its
/// outcome.</p>
/// <p>What the mark may and may not touch is pinned here too, because each wrong answer breaks
/// something already fixed: it flips only an <code>installed</code> row, keeps its schema
/// version (which <method>OcuPilot.Install.Installer.PlanMigration</method> reads), never
/// touches a <code>failed</code> row (a failed row at schema version 0 is what keeps the
/// <code>_SYSTEM</code> unexpire retrying after a failed first install), and never creates a
/// row.</p>
/// <p>Everything runs on the <code>"probe"</code> profile; the gate is read through
/// <class>OcuPilot.Test.ProbeGateRow</class>, so the shared production row is never written.
/// Every method leaves the probe installed; nothing here uninstalls.</p>
Class OcuPilot.Test.InstallMark Extends %UnitTest.TestCase
{

/// <p>The probe profile's version rows, read by SQL: <var>pRow</var> carries
/// <code>count</code> and, for the newest row, <code>id</code>, <code>phase</code>,
/// <code>schema</code>, <code>failingStep</code> and <code>updatedAt</code>. A failed query is an
/// assertion failure, never a count of 0: several tests here assert that no row exists.</p>
Method ReadProbeRow(Output pRow)
{
    Kill pRow
    Set pRow("count") = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Phase, SchemaVersion, FailingStep, UpdatedAt FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the probe version row query succeeds (SQLCODE " _ tRS.%SQLCODE _ ")")
    While tRS.%Next() {
        Set pRow("count") = pRow("count") + 1
        If pRow("count") = 1 {
            Set pRow("id") = tRS.ID
            Set pRow("phase") = tRS.Phase
            Set pRow("schema") = tRS.SchemaVersion
            Set pRow("failingStep") = tRS.FailingStep
            Set pRow("updatedAt") = tRS.UpdatedAt
        }
    }
}

/// <p>Leave the probe profile with one row that failed its first install (schema version 0),
/// through the <class>OcuPilot.Test.MigrateFault</class> seam every failure test already uses.</p>
Method FailProbeFirstInstall()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row")
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tSC = ##class(OcuPilot.Test.MigrateFault).Install("probe")
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Do $$$AssertStatusNotOK(tSC, "the forced first install fails")
}

/// <p>Put the probe back to one <code>installed</code> row with a real install.</p>
Method RestoreProbe()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a real probe install restores an installed row")
}

/// <p>The must-hold, end to end on real rows: an <code>installed</code> row serves; from the
/// mark on it does not, while its schema version stays what it was; and once this start's
/// install has recorded its outcome it serves again. The row is marked in place -- still one
/// row, the same id.</p>
/// <p>A second mark then meets the row <code>installing</code>, as the next start's mark does
/// after a start that failed before its install recorded an outcome, and leaves it as it is (code
/// review round 4).</p>
/// <p>Mutations (Rule 19): the mark skips its write -- the gate still reads
/// <code>installed</code> after the mark, red; the mark writes schema version 0 -- red on
/// "keeps its schema version"; drop the mark's "only an installed row" guard -- the second mark
/// reports <code>marked</code>, red.</p>
Method TestMarkFlipsAnInstalledRowAndKeepsItsVersion()
{
    Do ..RestoreProbe()
    Do ..ReadProbeRow(.tBefore)
    Do $$$AssertEquals(tBefore("count"), 1, "one probe row before the mark")
    Do $$$AssertEquals($Get(tBefore("phase")), "installed", "the probe row reads installed before the mark")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeGateRow).GateStatus(), "installed", "before the mark, the installed row serves")

    Set tSC = ##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcome)
    Do $$$AssertStatusOK(tSC, "the mark succeeds")
    Do $$$AssertEquals(tOutcome, "marked", "the mark reports that it marked the row")

    Do ..ReadProbeRow(.tAfter)
    Do $$$AssertEquals(tAfter("count"), 1, "still exactly one probe row: the mark writes in place, never a second row")
    Do $$$AssertEquals($Get(tAfter("id")), $Get(tBefore("id")), "the same row was marked")
    Do $$$AssertEquals($Get(tAfter("phase")), "installing", "the marked row reads installing")
    Do $$$AssertEquals($Get(tAfter("schema")), $Get(tBefore("schema")), "the mark keeps the row's schema version")
    Do $$$AssertEquals($Get(tAfter("failingStep")), "", "the marked row names no failing step")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeGateRow).GateStatus(), "installing", "from the mark on, the gate does not answer installed")

    Set tSC2 = ##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcome2)
    Do $$$AssertStatusOK(tSC2, "a second mark succeeds")
    Do $$$AssertEquals(tOutcome2, "left-installing", "and leaves an installing row as it is")
    Do ..ReadProbeRow(.tAgain)
    Do $$$AssertEquals($Get(tAgain("phase")) _ "|" _ $Get(tAgain("schema")) _ "|" _ $Get(tAgain("updatedAt")), $Get(tAfter("phase")) _ "|" _ $Get(tAfter("schema")) _ "|" _ $Get(tAfter("updatedAt")), "the installing row is untouched: phase, schema version and timestamp")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "this start's install runs over the marked row")
    Do ..ReadProbeRow(.tDone)
    Do $$$AssertEquals($Get(tDone("phase")), "installed", "the install recorded its own outcome over the mark")
    Do $$$AssertEquals($Get(tDone("id")), $Get(tBefore("id")), "on the same row")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeGateRow).GateStatus(), "installed", "once this start's install has recorded success, the gate serves again")
}

/// <p>A <code>failed</code> row is left exactly as it is -- phase, schema version, failing step
/// and timestamp -- whether it failed a first install (schema version 0) or a later one.</p>
/// <p>Mutation (Rule 19): drop the mark's "only an installed row" guard -- both failed rows
/// come back <code>installing</code>, red.</p>
Method TestMarkLeavesAFailedRowFailed()
{
    Do ..FailProbeFirstInstall()
    Do ..ReadProbeRow(.tBefore0)
    Do $$$AssertEquals($Get(tBefore0("phase")), "failed", "the probe row failed its first install")
    Do $$$AssertEquals($Get(tBefore0("schema")), 0, "at schema version 0")
    Set tSC0 = ##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcome0)
    Do $$$AssertStatusOK(tSC0, "the mark succeeds")
    Do $$$AssertEquals(tOutcome0, "left-failed", "the mark reports that it left the failed row alone")
    Do ..ReadProbeRow(.tAfter0)
    Do $$$AssertEquals($Get(tAfter0("phase")) _ "|" _ $Get(tAfter0("schema")) _ "|" _ $Get(tAfter0("failingStep")) _ "|" _ $Get(tAfter0("updatedAt")), $Get(tBefore0("phase")) _ "|" _ $Get(tBefore0("schema")) _ "|" _ $Get(tBefore0("failingStep")) _ "|" _ $Get(tBefore0("updatedAt")), "a row that failed its first install is untouched: phase, schema version 0, failing step and timestamp")

    Do ..RestoreProbe()
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tFailSC = ##class(OcuPilot.Test.MigrateFault).Install("probe")
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Do $$$AssertStatusNotOK(tFailSC, "a later install of the probe fails")
    Do ..ReadProbeRow(.tBefore1)
    Do $$$AssertEquals($Get(tBefore1("phase")), "failed", "the probe row failed a later install")
    Do $$$AssertTrue($Get(tBefore1("schema")) > 0, "above schema version 0")
    Set tSC1 = ##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcome1)
    Do $$$AssertStatusOK(tSC1, "the mark succeeds")
    Do $$$AssertEquals(tOutcome1, "left-failed", "the mark reports that it left the failed row alone")
    Do ..ReadProbeRow(.tAfter1)
    Do $$$AssertEquals($Get(tAfter1("phase")) _ "|" _ $Get(tAfter1("schema")) _ "|" _ $Get(tAfter1("failingStep")) _ "|" _ $Get(tAfter1("updatedAt")), $Get(tBefore1("phase")) _ "|" _ $Get(tBefore1("schema")) _ "|" _ $Get(tBefore1("failingStep")) _ "|" _ $Get(tBefore1("updatedAt")), "a row that failed a later install is untouched")

    Do ..RestoreProbe()
}

/// <p>No row -- a genuinely first start, or one after the version row was purged -- stays no
/// row.</p>
/// <p>Mutation (Rule 19): the mark creates an <code>installing</code> row when it finds none --
/// red.</p>
Method TestMarkNeverCreatesARow()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row")
    Do ..ReadProbeRow(.tBefore)
    Do $$$AssertEquals(tBefore("count"), 0, "no probe row before the mark")
    Set tSC = ##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcome)
    Do $$$AssertStatusOK(tSC, "the mark succeeds")
    Do $$$AssertEquals(tOutcome, "norow", "the mark reports that there was no row")
    Do ..ReadProbeRow(.tAfter)
    Do $$$AssertEquals(tAfter("count"), 0, "the mark created no row")

    Do ..RestoreProbe()
}

/// <p>A first install after a mark still unexpires when it should and not when it should not:
/// the mark leaves <method>OcuPilot.Install.Installer.Install</method>'s first-install answer
/// exactly as it was. Driven in <method>OcuPilot.Install.Installer.StartPath</method>'s form
/// (<var>pUnexpire</var> = 1, the only form that reaches the step), through
/// <class>OcuPilot.Test.InstallerProbe</class>, which records the step's arguments and never
/// runs the real unexpire.</p>
/// <ul>
/// <li>no row, marked: a genuinely first start -- unexpires;</li>
/// <li>a failed first install (schema version 0), marked: the retry -- unexpires;</li>
/// <li>an installed row, marked: an ordinary restart -- does not.</li>
/// </ul>
/// <p>Mutations (Rule 19): drop the mark's "only an installed row" guard -- the failed-at-0 row
/// comes back <code>installing</code> at 0 and the retry no longer unexpires, red; mark an
/// installed row by deleting it instead of flipping it -- the restart reads as a first install
/// and unexpires again, red.</p>
Method TestFirstInstallAfterAMarkUnexpiresOnlyWhenItShould()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcomeA), "mark with no row")
    Do $$$AssertEquals(tOutcomeA, "norow", "the mark found no row to mark")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).Install("probe", 1), "the first install after the mark succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "no row, marked: the first install still unexpires")

    Do ..FailProbeFirstInstall()
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcomeB), "mark the failed-at-0 row")
    Do $$$AssertEquals(tOutcomeB, "left-failed", "the mark left the failed-at-0 row as it was")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).Install("probe", 1), "the retry after the mark succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "a failed first install, marked: the retry still unexpires")

    Do ..ReadProbeRow(.tInstalled)
    Do $$$AssertEquals($Get(tInstalled("phase")), "installed", "the retry left an installed row")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).MarkInstalling("probe", .tOutcomeC), "mark the installed row")
    Do $$$AssertEquals(tOutcomeC, "marked", "the installed row was marked")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).Install("probe", 1), "the restart's install after the mark succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 0, "an installed row, marked: an ordinary restart does not unexpire")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
}

/// <p>With no privileged routine application to escalate through -- the first container start
/// after a production uninstall, whose classes are still compiled -- the mark reports
/// <code>norow</code> without reading the version row, and without an error: that read would
/// fail with <code>ERROR #868</code> and the hook would log a failed mark on a start where
/// nothing is wrong. Driven through <class>OcuPilot.Test.EscalationGap</class>, which reports
/// the application absent and counts version-row reads (step-04 review of rework iteration
/// 8).</p>
/// <p>Mutation (Rule 19): drop the mark's "no escalation application yet" guard -- the mark
/// reads the row and marks it, red.</p>
Method TestMarkSkipsTheReadWhenTheEscalationIsAbsent()
{
    Do ..RestoreProbe()
    Do ..ReadProbeRow(.tBefore)
    Do $$$AssertEquals($Get(tBefore("phase")), "installed", "the probe row reads installed before the mark")
    Try {
        Do ##class(OcuPilot.Test.EscalationGap).Disarm()
        Do ##class(OcuPilot.Test.EscalationGap).SetEscalationAbsent(1)
        Set tSC = ##class(OcuPilot.Test.EscalationGap).MarkInstalling("probe", .tOutcome)
        Set tReads = ##class(OcuPilot.Test.EscalationGap).VersionReadCount()
        Do ##class(OcuPilot.Test.EscalationGap).Disarm()
    } Catch ex {
        Do ##class(OcuPilot.Test.EscalationGap).Disarm()
        Throw ex
    }
    Do $$$AssertStatusOK(tSC, "with no escalation application, the mark still succeeds")
    Do $$$AssertEquals(tOutcome, "norow", "and reports that there is no row to mark")
    Do $$$AssertEquals(tReads, 0, "without trying to read the version row")
    Do ..ReadProbeRow(.tAfter)
    Do $$$AssertEquals($Get(tAfter("phase")) _ "|" _ $Get(tAfter("id")), $Get(tBefore("phase")) _ "|" _ $Get(tBefore("id")), "the probe row is left as it was")
}

/// <p>A mark that fails lets the lock go (code review round 4). A version-row read that fails --
/// served by <class>OcuPilot.Test.GateLadderRow</class>, which writes nothing -- makes
/// <method>OcuPilot.Install.Installer.MarkInstalling</method> return an error with no outcome
/// after it has taken the probe profile's install lock, and this process must not hold that lock
/// afterwards: the process a mark runs in can live on, and a lock it kept would stall every later
/// install, mark and uninstall of the profile in any other process. The real row is never
/// read or written.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.MarkInstalling</method> releases
/// the lock only when it succeeds -- this process still holds it, red.</p>
Method TestFailedMarkReleasesTheLock()
{
    Do ..RestoreProbe()
    Do ..ReadProbeRow(.tBefore)
    Set tSC = $$$OK
    Set tOutcome = "unset"
    Try {
        Do ##class(OcuPilot.Test.GateLadderRow).ArmReadError()
        Set tSC = ##class(OcuPilot.Test.GateLadderRow).MarkInstalling("probe", .tOutcome)
        Do ##class(OcuPilot.Test.GateLadderRow).Disarm()
    } Catch ex {
        Do ##class(OcuPilot.Test.GateLadderRow).Disarm()
        Throw ex
    }
    Set tHeld = (";" _ ##class(OcuPilot.Test.InstallLock).LocksHeldBy($Job)) [ (";" _ ##class(OcuPilot.Test.InstallLock).ExpectedProbeLockReference() _ ";")
    Do $$$AssertStatusNotOK(tSC, "a mark whose version-row read fails returns an error")
    Do $$$AssertEquals(tOutcome, "", "and reports no outcome")
    Do $$$AssertTrue('tHeld, "and has let the probe profile's install lock go")
    Do ..ReadProbeRow(.tAfter)
    Do $$$AssertEquals($Get(tAfter("phase")) _ "|" _ $Get(tAfter("id")), $Get(tBefore("phase")) _ "|" _ $Get(tBefore("id")), "the real probe row is left as it was")
}

}
