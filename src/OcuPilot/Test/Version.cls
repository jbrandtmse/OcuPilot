/// <p>Version row, phase resolver, migration ordering, populated-table survival,
/// downgrade refusal, install-namespace guard, unexpire scope and call site (AC2-AC8,
/// AC13, AC14).</p>
/// <p><b>Cycling discipline (this story's own hazard note):</b> manipulates version rows
/// and calls the migration, phase and guard methods directly wherever a direct call
/// suffices (<method>OcuPilot.Install.Installer.RunMigrations</method>,
/// <method>PlanMigration</method>, <method>EnsureUnexpired</method> and
/// <method>GatewayResponseTimeout</method> are all public for exactly this reason,
/// matching <method>EnsureGrant</method>'s own documented precedent) rather than paying
/// for a full <method>Install</method> pipeline. No method in this class calls
/// <code>Uninstall</code> at all.</p>
Class OcuPilot.Test.Version Extends %UnitTest.TestCase
{

/// <p>Creates a throwaway, expired (<code>ChangePassword = 1</code>), roleless account
/// -- never <code>_SYSTEM</code>, never a real named account.</p>
ClassMethod CreateThrowawayExpiredAccount(pName As %String) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(pName, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(pName)
            If $$$ISERR(tSC) Quit
        }
        Set tPassword = "OcuPilotTestVersion#" _ $Random(1000000000) _ "!Aa9"
        Set tSC = ##class(Security.Users).Create(pName, "", tPassword, "OcuPilot.Test.Version throwaway (deleted in OnAfterOneTest)", "", "", "", 1, 1, "Created by OcuPilot.Test.Version")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether <var>pName</var> currently reads <code>ChangePassword = 1</code>
/// (expired).</p>
ClassMethod IsExpired(pName As %String) As %Boolean [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Set tResult = -1
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            Set tGetSC = ##class(Security.Users).Get(pName, .tProps)
            If $$$ISOK(tGetSC) Set tResult = +$Get(tProps("ChangePassword"))
        }
    } Catch {
        Set tResult = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tResult
}

ClassMethod DeleteThrowawayAccount(pName As %String) [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            If ##class(Security.Users).Exists(pName, .tU, .tUS) {
                Do ##class(Security.Users).Delete(pName)
            }
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC4/AC14 -- pure-function half: <method>EnsureUnexpired</method> called directly
/// with <code>pFirstInstall = 0</code> against a deliberately expired throwaway account
/// leaves it expired; the unexpire step is genuinely skipped, not merely reported as
/// skipped.</p>
Method TestSecondStartDoesNotUnexpireAgain()
{
    Set tAccount = "OcuPilotTestVersionUnexp1"
    Set tSC = ##class(OcuPilot.Test.Version).CreateThrowawayExpiredAccount(tAccount)
    Do $$$AssertStatusOK(tSC, "create the throwaway expired account")
    Do $$$AssertEquals(##class(OcuPilot.Test.Version).IsExpired(tAccount), 1, "the throwaway account starts expired")

    Kill tReports
    Set tSC2 = ##class(OcuPilot.Install.Installer).EnsureUnexpired(tAccount, 0, .tReports)
    Do $$$AssertStatusOK(tSC2, "EnsureUnexpired(<account>, 0) does not error")
    Do $$$AssertEquals(##class(OcuPilot.Test.Version).IsExpired(tAccount), 1, "pFirstInstall=0 leaves the account expired -- the unexpire step is skipped")

    Do ##class(OcuPilot.Test.Version).DeleteThrowawayAccount(tAccount)
}

/// <p>AC4/AC14 -- call-site half: <method>Install</method> computes
/// <var>pFirstInstall</var> from the version row's absence, not a constant, verified
/// through <class>OcuPilot.Test.InstallerProbe</class>'s argument capture. A version row
/// already exists for the <code>"probe"</code> profile from earlier runs in this suite,
/// so the "first" half is exercised by deleting it first; the "not first" half needs no
/// setup at all.</p>
Method TestFirstInstallFlagComesFromTheVersionRow()
{
    Set tDelSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe")
    Do $$$AssertStatusOK(tDelSC, "clear any existing probe version row")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC1 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC1, "first install (no prior version row) succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "the call site passed pFirstInstall=1 when no version row existed yet")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC2 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC2, "second install succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 0, "the call site passed pFirstInstall=0 once a version row existed")

    ; Review finding (AC4): "exactly one version row exists per profile" was asserted
    ; nowhere -- every reader is a TOP-1-ORDER-BY-ID-DESC, so a duplicate row is
    ; invisible to them, and StateFingerprint would still read byte-identical across
    ; duplicates. This method already installs the probe profile twice above, which is
    ; exactly the scenario a missing unique constraint (the separately-tracked,
    ; deferred DW-47 finding) could leave two rows behind for.
    Set tCountRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
    Do $$$AssertTrue(tCountRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tCountRS.N, 1, "exactly one version row exists for the probe profile after two installs, never one per run")

    ; Review finding (build-auto review, 2026-09-10): the assertion above only ever
    ; covered the "probe" profile -- the production profile (Profile IS NULL) has its
    ; own, separately-populated row, and this file's own `## Auto Run Result` records a
    ; real, live duplicate found there during this same iteration's verification
    ; (id 1075 vs 1299). Checked here too so a recurrence of that duplicate on
    ; production is no longer invisible to this suite.
    Set tProdCountRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile IS NULL")
    Do $$$AssertTrue(tProdCountRS.%Next(), "the production count query returns a row")
    Do $$$AssertEquals(tProdCountRS.N, 1, "exactly one version row exists for the production profile")
}

/// <p>AC5 -- migration steps run in ascending order, driven directly through
/// <method>OcuPilot.Install.Installer.RunMigrations</method> against
/// <class>OcuPilot.Test.MigrateFault</class> (schema version 3, both steps succeeding).
/// No full <method>Install</method> pipeline is paid for.</p>
Method TestMigrationStepsRunInAscendingOrder()
{
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)

    ; RunMigrations is driven directly, bypassing Install/FlushReports entirely, so its
    ; reports land only in this LOCAL tReports array -- InstallerProbe's captured global
    ; (CapturedAll) is populated only by FlushReports, which this call never reaches.
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.MigrateFault).RunMigrations("probe", 0, .tReports)
    Do $$$AssertStatusOK(tSC, "all three registered steps (1, 2, 3) succeed in order")

    Set tPos2 = 0
    Set tPos3 = 0
    Set tN = $Order(tReports(""))
    While tN '= "" {
        If tReports(tN, "message") [ "Migrated to schema version 2" Set tPos2 = tN
        If tReports(tN, "message") [ "Migrated to schema version 3" Set tPos3 = tN
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue((tPos2 > 0) && (tPos3 > 0), "both migrations were reported")
    Do $$$AssertTrue(tPos2 < tPos3, "version 2 was migrated before version 3 -- ascending order")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
}

/// <p>AC5 -- an already-populated protected row survives a migration run untouched.
/// Seeds its own <class>OcuPilot.Kernel.State.Stamp</class> row with a real
/// <method>OcuPilot.Install.Installer.Install</method> call (review finding: the
/// previous version instead depended on "this instance already carries hundreds from
/// earlier install runs" -- true on this long-lived development container, but not on
/// the exact "one command on a clean clone" path this story ships, where that table
/// starts empty and the old version's environment-dependent assumption would fail for
/// non-defect reasons). The registered migration steps touch only a probe global, never
/// Stamp.</p>
Method TestPopulatedRowsSurviveMigration()
{
    Set tSeedSC = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSeedSC, "seed a probe-profile Stamp row for this test to observe")

    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID, Timestamp, GrantedUsername FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS0.%Next(), "the seeded Stamp row exists to observe")
    Set tId = tRS0.ID
    Set tBeforeTimestamp = tRS0.Timestamp
    Set tBeforeUser = tRS0.GrantedUsername

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.MigrateFault).RunMigrations("probe", 0, .tReports)
    Do $$$AssertStatusOK(tSC, "migration run succeeds")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT Timestamp, GrantedUsername FROM OcuPilot_Kernel_State.Stamp WHERE ID = ?", tId)
    Do $$$AssertTrue(tRS1.%Next(), "the same row is still there")
    Do $$$AssertEquals(tRS1.Timestamp, tBeforeTimestamp, "the row's Timestamp is byte-identical after migration")
    Do $$$AssertEquals(tRS1.GrantedUsername, tBeforeUser, "the row's GrantedUsername is byte-identical after migration")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
}

/// <p>AC6 -- pure-function half: <method>PlanMigration</method> refuses a stored version
/// ahead of the deployed code and allows anything at or below it.</p>
Method TestPlanRefusesAStoredVersionAheadOfTheCode()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Set tSC1 = ##class(OcuPilot.Install.Installer).PlanMigration(tDeployed + 1)
    Do $$$AssertStatusNotOK(tSC1, "a stored version one ahead of the deployed code is refused")
    Set tText = $System.Status.GetErrorText(tSC1)
    Do $$$AssertTrue((tText [ (tDeployed + 1)) && (tText [ tDeployed), "the refusal names both versions")

    Set tSC2 = ##class(OcuPilot.Install.Installer).PlanMigration(tDeployed)
    Do $$$AssertStatusOK(tSC2, "a stored version equal to the deployed code is allowed")
    Set tSC3 = ##class(OcuPilot.Install.Installer).PlanMigration(0)
    Do $$$AssertStatusOK(tSC3, "a stored version of 0 (never installed) is allowed")
}

/// <p>AC6 -- call-site half: with the probe profile's stored version pushed ahead of
/// the deployed code, <method>Install</method> refuses, naming both versions, and
/// changes nothing (the version row's <property>SchemaVersion</property> is still the
/// inflated value afterward -- proof nothing overwrote it).</p>
Method TestInstallRefusesWhenStoredVersionIsNewer()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Set tInflated = tDeployed + 98

    Set tRowSC = ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile("probe", .tRow)
    Do $$$AssertStatusOK(tRowSC, "read (or confirm absent) the probe version row")
    If '$IsObject(tRow) {
        Set tRow = ##class(OcuPilot.Kernel.State.Version).%New()
        Set tRow.Profile = "probe"
    }
    Set tRow.SchemaVersion = tInflated
    Set tRow.Phase = "installed"
    Set tSaveSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
    Do $$$AssertStatusOK(tSaveSC, "inflate the probe version row's SchemaVersion")

    Set tSC = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusNotOK(tSC, "install refuses a stored version ahead of the deployed code")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText [ tInflated) && (tText [ tDeployed), "the refusal names both versions")

    Set tRowSC2 = ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile("probe", .tRow2)
    Do $$$AssertStatusOK(tRowSC2, "re-read the probe version row")
    Do $$$AssertTrue($IsObject(tRow2), "the version row still exists")
    Do $$$AssertEquals(tRow2.SchemaVersion, tInflated, "the version row's SchemaVersion is untouched -- nothing was changed")

    ; Targeted teardown: restore the probe version row to a sane state rather than
    ; leaving the inflated value for any later run in this suite (or this class re-run)
    ; to trip over.
    Set tRow2.SchemaVersion = 0
    Do ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow2)
}

/// <p>AC3, AC5 -- a failing migration step leaves the version row's phase
/// <code>failed</code>, names the failing step, and leaves the stored schema version at
/// its prior value (here 0) rather than the deployed one. Drives the full
/// <class>OcuPilot.Test.MigrateFault</class> <method>Install</method> once (this
/// class's one full-pipeline call, alongside the downgrade-refusal test) -- the version
/// row is only written by <method>Install</method> itself, never by
/// <method>RunMigrations</method> alone.</p>
Method TestFailingStepLeavesPhaseFailed()
{
    Set tDelSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe")
    Do $$$AssertStatusOK(tDelSC, "clear any existing probe version row")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tSC = ##class(OcuPilot.Test.MigrateFault).Install("probe")
    Do $$$AssertStatusNotOK(tSC, "install fails when a migration step fails")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 SchemaVersion, Phase, FailingStep FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS.%Next(), "a version row exists for the probe profile")
    Do $$$AssertEquals(tRS.Phase, "failed", "the phase is failed")
    Do $$$AssertEquals(tRS.FailingStep, "RunMigrations", "the failing step is named")
    Do $$$AssertEquals(tRS.SchemaVersion, 0, "the stored schema version is left at its prior value (0), not advanced")
}

/// <p>AC2/AC14 regression pin (review finding, HIGH -- Rule 19: shipped with no
/// committed test at all). <method>OcuPilot.Install.Installer.Install</method> used to
/// treat a version row's mere PRESENCE as "not first install", so a first install that
/// failed after <method>Names</method> (almost every failure path writes a
/// <code>"failed"</code> row) permanently disabled <method>EnsureUnexpired</method> for
/// that profile -- a clean <code>docker compose up -d --wait</code> would then need a
/// manual unexpire forever, contradicting AC2's own promise. The fix treats a
/// <code>"failed"</code> row as still-first-install; only an <code>"installed"</code>
/// row (the only other value <method>EnsureVersion</method> ever writes) counts as
/// not-first. Forces a failed first attempt through the same
/// <class>OcuPilot.Test.MigrateFault</class> seam
/// <method>TestFailingStepLeavesPhaseFailed</method> already uses, then drives a real
/// (non-faulty) install through <class>OcuPilot.Test.InstallerProbe</class> and reads
/// the argument it actually passed to <method>EnsureUnexpired</method>.</p>
Method TestFailedFirstInstallStillCountsAsFirstInstall()
{
    Set tDelSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe")
    Do $$$AssertStatusOK(tDelSC, "clear any existing probe version row")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tFailSC = ##class(OcuPilot.Test.MigrateFault).Install("probe")
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Do $$$AssertStatusNotOK(tFailSC, "the forced first install fails")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Phase FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS.%Next(), "a version row exists for the probe profile after the forced failure")
    Do $$$AssertEquals(tRS.Phase, "failed", "the failed first attempt left a failed row, not no row at all")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tRealSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tRealSC, "the real, non-faulty install that follows succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "a prior FAILED row still counts as first-install for the unexpire gate -- a failed attempt is not an install (AC2/AC14)")
}

/// <p>AC3's own mutation line ("in <method>OcuPilot.Install.Installer.StartPath</method>,
/// discard the failing step's <code>%Status</code> and fall through") names
/// <method>StartPath</method> specifically, but the pinning test named alongside it
/// (<method>TestFailingStepLeavesPhaseFailed</method>, above) drives
/// <method>Install</method> directly and never calls <method>StartPath</method> at all
/// -- review finding: that mutation could ship and every existing test would stay
/// green. <method>StartPath</method>'s own <code>Install("")</code> call is hardcoded
/// to the production profile (no parameter redirects it -- see <method>StartPath</method>'s
/// own header), so this test induces the failure through the existing
/// <class>OcuPilot.Test.MigrateFault</class> seam against the SHARED production version
/// row on this instance, exactly as
/// <method>OcuPilot.Test.Version.TestRealProductionGateResolvesToInstalledAfterInstall</method>
/// already accepts touching production for real -- and repairs it with a real,
/// unmocked <code>Install("")</code> before returning, leaving production no worse than
/// a normal successful install run already leaves it.</p>
Method TestStartPathPropagatesAFailingStep()
{
    ; Review finding (build-auto review, 2026-09-10): wrapped so an uncaught exception
    ; from StartPath (rather than an ordinary returned %Status) cannot skip
    ; SetShouldFail(0) and leave MigrateFault's shared fault-injection flag stuck on
    ; for every later test in this class run.
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Test.MigrateFault).StartPath(0)
    } Catch ex {
        Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
        Throw ex
    }
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)

    Do $$$AssertStatusNotOK(tSC, "StartPath propagates Install's own failure instead of swallowing it")

    ; Repair: a real, unmocked Install("") against the real deployed schema restores
    ; the production version row to a genuinely installed state.
    Set tRepairSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRepairSC, "production install is repaired back to a real installed state")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).GateStatus(), "installed", "production gate resolves to installed again after the repair")
}

/// <p>AC7's "changes nothing" (AC6) and "the health check never reports healthy"
/// (AC3) together imply <method>OcuPilot.Install.Installer.GateStatus</method> must not
/// resolve to <code>installed</code> when the stored schema version is AHEAD of the
/// deployed code -- the one case <method>PlanMigration</method> refuses outright.
/// Review finding: the ladder previously had no branch for that direction, so it fell
/// through to <code>installed</code> after a refused downgrade, meaning the compose
/// health check (which reads <method>GateStatus</method> directly, not the hook's exit
/// code) would report the container healthy while old code served traffic against a
/// newer schema.</p>
/// <p><method>GateStatus</method> always resolves the <b>production</b> profile
/// (<class>OcuPilot.Api.Router</class>'s own consumer, with no profile parameter to
/// redirect), so this test mutates the SHARED production version row directly -- the
/// same acceptance
/// <method>TestStartPathPropagatesAFailingStep</method> and
/// <method>TestRealProductionGateResolvesToInstalledAfterInstall</method> already make
/// -- and restores it, then repairs with a real <code>Install("")</code>, before
/// returning.</p>
Method TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Set tRowSC = ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile("", .tRow)
    Do $$$AssertStatusOK(tRowSC, "read the production version row")
    Do $$$AssertTrue($IsObject(tRow), "a production version row already exists (this suite installs production elsewhere)")
    ; Review finding (build-auto review, 2026-09-10, Rule 19): $$$AssertTrue does not
    ; abort the method on failure -- without this guard, a genuinely row-less instance
    ; (e.g. a fresh container never installed) would dereference tRow.SchemaVersion on
    ; a non-object next and throw <INVALID OREF>/similar instead of failing cleanly.
    If '$IsObject(tRow) Quit

    Set tPriorSchemaVersion = tRow.SchemaVersion
    Set tPriorPhase = tRow.Phase
    ; Review finding (build-auto review, 2026-09-10): the mutate-assert-restore
    ; sequence below had no Try/Catch -- an exception anywhere between the inflate and
    ; the restore (including a genuine bug in GateStatus() itself, the thing under
    ; test) would leave the SHARED production version row permanently ahead of the
    ; deployed schema, which PlanMigration then actively refuses -- unlike a "failed"
    ; phase, that state does not self-heal on the next ordinary Install and would need
    ; manual SQL repair on this shared development instance.
    Try {
        Set tRow.SchemaVersion = tDeployed + 1
        Set tRow.Phase = "installed"
        Set tSaveSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
        Do $$$AssertStatusOK(tSaveSC, "inflate the production version row's SchemaVersion, phase installed")

        Do $$$AssertNotEquals(##class(OcuPilot.Install.Installer).GateStatus(), "installed", "the gate never resolves to installed when the stored schema version is ahead of the deployed code")
    } Catch ex {
        Set tRow.SchemaVersion = tPriorSchemaVersion
        Set tRow.Phase = tPriorPhase
        Do ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
        Do ##class(OcuPilot.Install.Installer).Install("")
        Throw ex
    }

    Set tRow.SchemaVersion = tPriorSchemaVersion
    Set tRow.Phase = tPriorPhase
    Do ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
    Set tRepairSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRepairSC, "production install still succeeds after the restore")
}

/// <p>Version row unreadable -- a forced read failure resolves
/// <method>OcuPilot.Install.Installer.Phase</method> to <code>installing</code>, never
/// <code>installed</code>.</p>
Method TestUnreadableVersionRowResolvesToInstalling()
{
    Do ##class(OcuPilot.Test.MigrateFault).SetVersionReadShouldFail(1)
    Set tPhase = ##class(OcuPilot.Test.MigrateFault).Phase()
    Do ##class(OcuPilot.Test.MigrateFault).SetVersionReadShouldFail(0)
    Do $$$AssertEquals(tPhase, "installing", "a read failure resolves to installing, never installed")
}

/// <p>Review finding (verification-gap): every other gate/phase test drives
/// <class>OcuPilot.Test.GateFixture</class> (a forced phase, never reaching the real
/// version-row read) or <class>OcuPilot.Test.MigrateFault</class> (fault injection).
/// Nothing exercised the real, unmocked chain --
/// <method>OcuPilot.Api.Router.GateStatus</method> →
/// <method>OcuPilot.Install.Installer.GateStatus</method>/<method>Phase</method> →
/// <method>OcuPilot.Kernel.State.Version.GuardedCurrentForProfile</method> (production
/// branch, <code>Profile IS NULL</code>) -- the exact NULL-vs-bound-parameter class of
/// bug this story already had to fix once for the production profile (this class's own
/// <method>GuardedOpenOneWhereNoParam</method> header). A regression reintroducing that
/// bug would permanently 503 all real traffic and never turn the container healthy,
/// while every other test in this suite stayed green. Drives the real
/// <method>OcuPilot.Install.Installer.Install</method> with the production profile
/// (already exercised elsewhere in this suite, e.g.
/// <class>OcuPilot.Test.Installer.TestProductionInstallIsIdempotent</class>) and asserts
/// the real <method>GateStatus</method> resolves to <code>installed</code> afterward,
/// with no override and no fault injection anywhere in the call chain.</p>
Method TestRealProductionGateResolvesToInstalledAfterInstall()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tSC, "the real production install succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).GateStatus(), "installed", "the real, unmocked gate resolves to installed after a real production install")
    Do $$$AssertEquals(##class(OcuPilot.Api.Router).GateStatus(), "installed", "Api.Router's own delegation reaches the identical result")
}

/// <p>AC13 -- reached while <code>$NAMESPACE</code> is <code>%SYS</code>, the guard
/// refuses immediately, naming both namespaces, and the caller's namespace is restored.
/// Driven through <method>OcuPilot.Install.Installer.TestOnlyInstallFromSys</method>
/// (test-only seam) rather than a fresh <code>##class()</code> call from <code>%SYS</code>
/// directly -- verified live that the latter cannot even resolve the class (see that
/// method's own header), which would test IRIS's class mapping, not this guard.</p>
Method TestInstallRefusesFromWrongNs()
{
    Set tStart = $NAMESPACE
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tSC = ##class(OcuPilot.Install.Installer).TestOnlyInstallFromSys("probe", .tNamespaceAfterInstall)

    Do $$$AssertStatusNotOK(tSC, "Install refuses when reached while $NAMESPACE is %SYS")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText [ tInstallNs) && (tText [ "%SYS"), "the refusal names both the expected and the actual namespace")
    ; Review finding: asserting only against $NAMESPACE AFTER this whole call returns
    ; cannot distinguish Install's own guard restoring correctly from
    ; TestOnlyInstallFromSys's own unconditional restore doing it regardless (Rule 19) --
    ; the seam now captures $NAMESPACE immediately after Install() returns, before its
    ; own restore runs, so this checks what the guard itself left behind.
    Do $$$AssertEquals(tNamespaceAfterInstall, "%SYS", "Install's own guard refuses before ever moving the namespace away from where the caller's %SYS switch left it")
    Do $$$AssertEquals($NAMESPACE, tStart, "the caller's namespace is restored")
}

/// <p>Gateway read fails -- neither the live registry nor a configuration file
/// answering is reported as one <code>info</code> line, and the caller
/// (<method>ReportGatewayGap</method>) still returns <code>$$$OK</code>.</p>
Method TestGatewayTimeoutUnavailableIsReportedNotFatal()
{
    Do ##class(OcuPilot.Test.MigrateFault).SetGatewayReadShouldFail(1)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.MigrateFault).ReportGatewayGap(.tReports)
    Do ##class(OcuPilot.Test.MigrateFault).SetGatewayReadShouldFail(0)

    Do $$$AssertStatusOK(tSC, "ReportGatewayGap never fails install (AD-27's fallback)")
    Set tN = $Order(tReports(""))
    Set tFoundUnavailable = 0
    While tN '= "" {
        If tReports(tN, "message") [ "not available" Set tFoundUnavailable = 1
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue(tFoundUnavailable, "one info report says the timeout is not available")
}

/// <p>AC8 -- the reported timeout matches an independent read of the same live source,
/// rather than a literal. Recorded honestly (this story's own Verification section): a
/// hardcoded 60 would currently pass a test that merely checked the constant 60, which
/// is exactly why this compares against a second, independent call instead.</p>
Method TestGatewayTimeoutIsReportedFromTheLiveSource()
{
    Kill tReports
    Set tSC = ##class(OcuPilot.Install.Installer).ReportGatewayGap(.tReports)
    Do $$$AssertStatusOK(tSC, "ReportGatewayGap succeeds")

    Set tIndependentSC = ##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tIndependentTimeout, .tIndependentSource)
    Do $$$AssertStatusOK(tIndependentSC, "the independent read succeeds")

    Set tN = $Order(tReports(""))
    Set tReportedTimeout = ""
    Set tReportedSource = ""
    While tN '= "" {
        Set tData = tReports(tN, "data")
        If $IsObject(tData) && (tData.%IsDefined("timeout")) {
            Set tReportedTimeout = tData.timeout
            Set tReportedSource = $Select(tData.%IsDefined("source"): tData.source, 1: "")
        }
        Set tN = $Order(tReports(tN))
    }

    ; Review finding: comparing ReportGatewayGap's own output against a second call to
    ; the SAME method it gets its value from (GatewayResponseTimeout) cannot tell a
    ; defect in that method apart from a correct report -- both sides move together.
    ; This instance's own live Gateway registry answers (verified this story:
    ; Server_Response_Timeout=60), so the meaningful branch below is the one this
    ; environment actually exercises; the empty/empty branch is now an explicit,
    ; documented no-evidence skip rather than a silent vacuous pass on "" = "".
    If tIndependentTimeout = "" {
        Do $$$AssertTrue(1, "SKIPPED: neither the live Gateway registry nor a configuration file answers on this instance, so this run offers no evidence either way")
    } Else {
        Do $$$AssertEquals(tReportedTimeout, tIndependentTimeout, "the reported timeout matches an independent read of the same live source")
        ; AC8 requires the report to NAME the source it read the timeout from -- the
        ; previous version of this test never read tData.source at all.
        Do $$$AssertTrue(tReportedSource '= "", "the report names the source it read the timeout from")
    }
}

/// <p>AC14 -- pure-function half: <method>EnsureUnexpired</method> targets only the
/// account it is given. Two throwaway accounts, both expired; only the one named is
/// unexpired.</p>
Method TestUnexpireTargetsOnlyTheInstallAccount()
{
    Set tA = "OcuPilotTestVersionUnexpA"
    Set tB = "OcuPilotTestVersionUnexpB"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Version).CreateThrowawayExpiredAccount(tA), "create throwaway A")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Version).CreateThrowawayExpiredAccount(tB), "create throwaway B")

    ; EnsureUnexpired switches to %SYS itself (Security.Users is mapped into %SYS
    ; only), unlike EnsureGrant, so this is called directly with no switch of our own.
    Kill tReports
    Set tSC = ##class(OcuPilot.Install.Installer).EnsureUnexpired(tA, 1, .tReports)
    Do $$$AssertStatusOK(tSC, "EnsureUnexpired(A, 1) does not error")

    Do $$$AssertEquals(##class(OcuPilot.Test.Version).IsExpired(tA), 0, "A is unexpired")
    Do $$$AssertEquals(##class(OcuPilot.Test.Version).IsExpired(tB), 1, "B is untouched and still expired")

    Do ##class(OcuPilot.Test.Version).DeleteThrowawayAccount(tA)
    Do ##class(OcuPilot.Test.Version).DeleteThrowawayAccount(tB)
}

/// <p>AC14 -- call-site half: <method>Install</method> passes the single, fixed
/// <parameter>OcuPilot.Install.Installer.UNEXPIREACCOUNT</parameter> account
/// (<code>_SYSTEM</code>), never <code>$Username</code> and never <code>"*"</code>,
/// verified through <class>OcuPilot.Test.InstallerProbe</class>'s argument capture.
/// Deliberately not <code>$Username</code>: verified live in a throwaway container that
/// the container start hook's own <code>$Username</code> resolves to
/// <code>irisowner</code>, never <code>_SYSTEM</code> -- see
/// <parameter>UNEXPIREACCOUNT</parameter>'s own header. This call is expected to reach
/// <code>UnExpireUserPasswords</code> for real only when this is genuinely the first
/// install for the <code>"probe"</code> profile (unlikely by the time this method runs,
/// since an earlier method in this class already created a probe version row) -- and
/// even then it is harmless: <code>_SYSTEM</code> is already unexpired on this
/// instance, so the call is idempotent.</p>
Method TestProductionWiringNamesOnlyTheInstallAccount()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC, "install succeeds")
    Set tArg = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
    Do $$$AssertEquals(tArg, "_SYSTEM", "the call site passes the fixed, documented install account")
    Do $$$AssertTrue(tArg '= "*", "the call site never passes the all-users wildcard")
}

}
