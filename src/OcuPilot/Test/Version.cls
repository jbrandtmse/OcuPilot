/// <p>Version row, phase resolver, migration ordering, populated-table survival,
/// downgrade refusal, install-namespace guard, unexpire scope and call site (AC2-AC8,
/// AC13, AC14).</p>
/// <p><b>Cycling discipline (this story's own hazard note):</b> manipulates version rows
/// and calls the migration, phase and guard methods directly wherever a direct call
/// suffices (<method>OcuPilot.Install.Installer.RunMigrations</method>,
/// <method>PlanMigration</method>, <method>EnsureUnexpired</method> and
/// <method>GatewayResponseTimeout</method> are all public for exactly this reason,
/// matching <method>EnsureGrant</method>'s own documented precedent) rather than paying
/// for a full <method>Install</method> pipeline. No test method calls <code>Uninstall</code>;
/// <method>OnAfterAllTests</method> removes the probe profile once.</p>
Class OcuPilot.Test.Version Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the principals this class
/// creates exist on the container that script builds and nowhere else. Anything else -- absent,
/// empty, or a value that reads like a refusal such as <code>0</code> -- refuses (DW-289).</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Refuse to run at all unless <parameter>ARMINGVARIABLE</parameter> arms this class (DW-289).</p>
/// <p><class>%UnitTest.Manager</class> raises this status <b>before</b> it enumerates the class's
/// <code>Test*</code> methods, so an unarmed instance runs none of them and nothing is created.
/// The doc comment that used to stand here instead was a barrier only a reader could enforce, and
/// <code>ci-runner.mjs --container &lt;name&gt;</code> takes any container's name.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Version creates and deletes IRIS users on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron("OCUPILOT_ALLOW_PRODUCTION_INSTALL") '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Version runs OcuPilot's production install on this instance and runs on a throwaway container only. OCUPILOT_ALLOW_PRODUCTION_INSTALL does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Removes the probe profile the tests leave installed, so no probe web application survives
/// the class (DW-242).</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>Creates a throwaway, expired (<code>ChangePassword = 1</code>), roleless account
/// -- never <code>_SYSTEM</code>, never a real named account. Public, with
/// <method>IsExpired</method> and <method>DeleteThrowawayAccount</method>, so
/// <class>OcuPilot.Test.UnexpireScope</class> reuses them (code review round 4).</p>
ClassMethod CreateThrowawayExpiredAccount(pName As %String) As %Status
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
        ; Review finding (code review round 2, mechanical): this description used to
        ; read "deleted in OnAfterOneTest", but this class defines no OnAfterOneTest --
        ; every throwaway account is deleted inline at the end of the method that made
        ; it. Corrected at its origin rather than left to be mined as evidence that a
        ; teardown hook exists (CLAUDE.md's "correct a wrong claim at its origin").
        Set tSC = ##class(Security.Users).Create(pName, "", tPassword, "OcuPilot.Test.Version throwaway (deleted inline by the test that created it)", "", "", "", 1, 1, "Created by OcuPilot.Test.Version")
    } Catch ex {
        ; AD-16: restore first in every Catch (code review round 3).
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether <var>pName</var> currently reads <code>ChangePassword = 1</code>
/// (expired).</p>
ClassMethod IsExpired(pName As %String) As %Boolean
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
        Set $NAMESPACE = tOrigNS
        Set tResult = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tResult
}

ClassMethod DeleteThrowawayAccount(pName As %String)
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
        Set $NAMESPACE = tOrigNS
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
/// <p>Both installs are driven in <method>OcuPilot.Install.Installer.StartPath</method>'s
/// form (<var>pUnexpire</var> = 1): since DW-73 that is the only form that reaches the
/// unexpire step at all, so an IPM-form install here would record nothing and prove
/// nothing (<class>OcuPilot.Test.UnexpireScope</class> pins the IPM form separately).</p>
Method TestFirstInstallFlagComesFromTheVersionRow()
{
    Set tDelSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe")
    Do $$$AssertStatusOK(tDelSC, "clear any existing probe version row")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC1 = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do $$$AssertStatusOK(tSC1, "first install (no prior version row) succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "the call site passed pFirstInstall=1 when no version row existed yet")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC2 = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
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

    Set tBeforeDigest = ..ProtectedRowsDigest()
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.MigrateFault).RunMigrations("probe", 0, .tReports)
    Do $$$AssertStatusOK(tSC, "migration run succeeds")
    ; AC5 says every row and every property value survives, and the two columns of one row
    ; checked below cannot see a step that rewrites anything else (code review round 3).
    Do $$$AssertEquals(..ProtectedRowsDigest(), tBeforeDigest, "every column of every row of the protected tables (Stamp, Demo, Version) is byte-identical after the migration run")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT Timestamp, GrantedUsername FROM OcuPilot_Kernel_State.Stamp WHERE ID = ?", tId)
    Do $$$AssertTrue(tRS1.%Next(), "the same row is still there")
    Do $$$AssertEquals(tRS1.Timestamp, tBeforeTimestamp, "the row's Timestamp is byte-identical after migration")
    Do $$$AssertEquals(tRS1.GrantedUsername, tBeforeUser, "the row's GrantedUsername is byte-identical after migration")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
}

/// <p>A digest of every column of every row of the three protected tables, read in ID
/// order -- what <method>TestPopulatedRowsSurviveMigration</method> compares before and
/// after a migration run (AC5: "every row ... with every property value byte-identical").
/// The query texts are call-site literals. A query that fails contributes its SQLCODE, so
/// a failure on both sides still reads as equal only if it is the same failure.</p>
Method ProtectedRowsDigest() As %String
{
    Set tAll = ""
    For tQuery = "SELECT * FROM OcuPilot_Kernel_State.Stamp ORDER BY ID", "SELECT * FROM OcuPilot_Kernel_State.Demo ORDER BY ID", "SELECT * FROM OcuPilot_Kernel_State.Version ORDER BY ID" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tQuery)
        If tRS.%SQLCODE < 0 {
            Set tAll = tAll _ "|SQLCODE " _ tRS.%SQLCODE
            Continue
        }
        Set tCols = tRS.%GetMetadata().columnCount
        While tRS.%Next() {
            For tC = 1:1:tCols {
                Set tAll = tAll _ $ListBuild(tRS.%GetData(tC))
            }
        }
        Set tAll = tAll _ "|"
    }
    Quit $System.Encryption.Base64Encode($System.Encryption.SHA1Hash(tAll))
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

    ; Driven through InstallerProbe (code review round 3) so the test can see which steps
    ; ran: AC6's "changes nothing" means the refusal comes before the first ensure step,
    ; which the version row alone cannot show -- moving PlanMigration below the ensure
    ; steps left every assertion here green while they repaired and unexpired first.
    ; StartPath's form (pUnexpire = 1, DW-73): the IPM form never reaches the unexpire step,
    ; so "it was never reached" below would pass whatever the refusal's position.
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do $$$AssertStatusNotOK(tSC, "install refuses a stored version ahead of the deployed code")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText [ tInflated) && (tText [ tDeployed), "the refusal names both versions")
    Set tReported = $ZConvert(##class(OcuPilot.Test.InstallerProbe).CapturedAll("info") _ ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn"), "L")
    Do $$$AssertTrue('(tReported [ "database resource"), "the refusal came before the first ensure step -- none of them reported")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), "", "the refusal came before the unexpire step -- it was never reached")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

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
    ; AC3 (amended): the returned status names the failing step, so the start hook's
    ; STARTPATH-FAILED line does too -- including on a first install that fails before any
    ; version row can be written (code review round 3). Mutation: drop the step name from
    ; Install's failure path, and this goes red.
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "Install failed at step 'RunMigrations'", "the returned status names the failing step: " _ $System.Status.GetErrorText(tSC))

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
    Set tRealSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do $$$AssertStatusOK(tRealSC, "the real, non-faulty install that follows succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 1, "a prior FAILED row still counts as first-install for the unexpire gate -- a failed attempt is not an install (AC2/AC14)")
}

/// <p>Regression pin (review finding, MED, round 2): the fix above reads the version
/// row's *current* phase alone, which re-arms the unexpire on ANY mature instance whose
/// latest start happens to fail -- not only a profile's genuinely first attempt.
/// <method>TestFailedFirstInstallStillCountsAsFirstInstall</method> cannot see this: it
/// deletes the row first, so its own forced failure IS a genuinely first attempt either
/// way. This test installs to a real "installed" row first, THEN forces the failure
/// through the same <class>OcuPilot.Test.MigrateFault</class> seam, so the resulting
/// "failed" row carries a non-zero `SchemaVersion` inherited from the prior successful
/// install -- exactly the case `(tVerRow.Phase = "failed") && (tVerRow.SchemaVersion = 0)`
/// exists to tell apart from a genuinely first, still-eligible failure.</p>
Method TestFailedNonFirstInstallDoesNotReArmUnexpire()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tCleanSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tCleanSC, "a clean install establishes a real installed row first")

    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Phase, SchemaVersion FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS0.%Next(), "a version row exists for the probe profile after the clean install")
    Do $$$AssertEquals(tRS0.Phase, "installed", "the clean install left the row installed")
    Do $$$AssertTrue(tRS0.SchemaVersion > 0, "the clean install advanced SchemaVersion past 0")

    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tFailSC = ##class(OcuPilot.Test.MigrateFault).Install("probe")
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Do $$$AssertStatusNotOK(tFailSC, "the forced later failure fails")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Phase, SchemaVersion FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS1.%Next(), "a version row still exists after the forced failure")
    Do $$$AssertEquals(tRS1.Phase, "failed", "the forced failure left the row failed")
    Do $$$AssertTrue(tRS1.SchemaVersion > 0, "the failed row inherited the prior install's non-zero SchemaVersion -- this is not a genuinely first attempt")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tRealSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do $$$AssertStatusOK(tRealSC, "the real, non-faulty install that follows succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg(), 0, "a failed row on an instance that has already reached installed once does NOT re-arm the unexpire (Boundaries: never unexpire on a start that is not the first install)")
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
/// <p>It also pins that a failed <method>StartPath</method> lets the production profile's
/// install lock go (code review round 4): the process an MCP call runs in lives on, and a lock
/// it kept would stall every later install, mark and uninstall of production in any other
/// process. Mutation (Rule 19): <method>StartPath</method> releases the lock only when it
/// succeeds -- this process still holds it, red.</p>
Method TestStartPathPropagatesAFailingStep()
{
    ; Review finding (build-auto review, 2026-09-10): wrapped so an uncaught exception
    ; from StartPath (rather than an ordinary returned %Status) cannot skip
    ; SetShouldFail(0) and leave MigrateFault's shared fault-injection flag stuck on
    ; for every later test in this class run.
    ;
    ; Review finding (MED, round 2): the repair below used to run only AFTER this
    ; Try/Catch, on the straight-line path -- the Catch reset SetShouldFail(0) and
    ; re-threw without ever repairing. An exception (or an abandoned run -- DW-54
    ; records the MCP test-runner tool sometimes timing out while the server-side run
    ; continues) left the SHARED PRODUCTION version row at "failed": GateStatus()
    ; reads "failed", Api.Router answers every request with a 503, and the compose
    ; health check reports the container unhealthy, until a human notices.
    ; RepairProductionInstall below is now the one repair path both this Catch and the
    ; straight line call, so no exit from this method can skip it.
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Test.MigrateFault).StartPath(0)
    } Catch ex {
        Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
        Do ..RepairProductionInstall()
        Throw ex
    }
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Set tStillHeld = ##class(OcuPilot.Test.InstallerProbe).HoldsProductionInstallLock()

    Do $$$AssertStatusNotOK(tSC, "StartPath propagates Install's own failure instead of swallowing it")
    Do $$$AssertTrue('tStillHeld, "the failed StartPath let the production profile's install lock go")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "Install failed at step 'RunMigrations'", "the status StartPath hands the start hook names the failing step (AC3): " _ $System.Status.GetErrorText(tSC))

    Do ..RepairProductionInstall()
}

/// <p>Repairs the SHARED production version row back to a real installed state with a
/// genuine, unmocked <code>Install("")</code> -- called from both
/// <method>TestStartPathPropagatesAFailingStep</method>'s straight-line path and its
/// <code>Catch</code> block (review finding, MED, round 2: an exception used to skip
/// this entirely, leaving production's gate at <code>failed</code> until a human
/// noticed).</p>
Method RepairProductionInstall()
{
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
/// <method>OcuPilot.Install.Installer.Phase</method> and
/// <method>OcuPilot.Install.Installer.GateStatus</method> to <code>unreadable</code>, never
/// <code>installing</code> or <code>installed</code> (DW-96).</p>
Method TestUnreadableVersionRowResolvesToUnreadable()
{
    Do ##class(OcuPilot.Test.MigrateFault).SetVersionReadShouldFail(1)
    Set tPhase = ##class(OcuPilot.Test.MigrateFault).Phase()
    Set tGate = ##class(OcuPilot.Test.MigrateFault).GateStatus()
    Do ##class(OcuPilot.Test.MigrateFault).SetVersionReadShouldFail(0)
    Do $$$AssertEquals(tPhase, "unreadable", "a read failure resolves Phase to unreadable")
    Do $$$AssertEquals(tGate, "unreadable", "and the gate to unreadable")
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
    Set tSC = ##class(OcuPilot.Test.MigrateFault).ReportGatewayGap(.tReports, "probe")
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
    Set tSC = ##class(OcuPilot.Install.Installer).ReportGatewayGap(.tReports, "probe")
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
        ; Logged, not asserted (code review round 3): a pass counted from AssertTrue(1, ...)
        ; is a gate that cannot fail -- the same fix OcuPilot.Test.GatewayIni's cross-check
        ; already made.
        Do ..LogMessage("SKIPPED: neither the live Gateway registry nor a configuration file answers on this instance, so this run offers no evidence either way")
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
/// <parameter>UNEXPIREACCOUNT</parameter>'s own header. Driven in
/// <method>OcuPilot.Install.Installer.StartPath</method>'s form (<var>pUnexpire</var> = 1),
/// the only form that reaches the step since DW-73. It never reaches the real
/// <code>UnExpireUserPasswords</code>: <class>OcuPilot.Test.InstallerProbe</class> records
/// the step's arguments instead of running it (DW-79).</p>
Method TestProductionWiringNamesOnlyTheInstallAccount()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do $$$AssertStatusOK(tSC, "install succeeds")
    Set tArg = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
    Do $$$AssertEquals(tArg, "_SYSTEM", "the call site passes the fixed, documented install account")
    Do $$$AssertTrue(tArg '= "*", "the call site never passes the all-users wildcard")
}

/// <p>Regression pin (review finding, build-auto step-04 review pass, 2026-09-11):
/// <method>OcuPilot.Kernel.State.Version.DeleteByProfile("")</method> gained a
/// <code>Profile IS NULL</code> branch (Fix Pack F-5) so it actually purges the shared
/// production row instead of silently no-op-ing on a <code>Profile = ?</code> bind that
/// can never match SQL <code>NULL</code> -- mirroring
/// <class>OcuPilot.Kernel.State.Demo</class>'s own identical fix and its own committed
/// test (<method>OcuPilot.Test.Demo.TestDeleteByProfileRemovesProductionNullRows</method>),
/// which this test copies the backup/delete/restore shape from. No prior committed test
/// called <code>Version.DeleteByProfile("")</code> at all -- the only verification this
/// fix had was a single hand-run backup/delete/restore against the live production row
/// via MCP, not repeatable from the suite.</p>
Method TestVersionDeleteByProfileRemovesTheProductionRow()
{
    Set tReadSC = ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile("", .tRow0)
    Do $$$AssertStatusOK(tReadSC, "reading the existing production version row succeeds")
    Set tHadRow = $IsObject(tRow0)
    If tHadRow {
        Set tBackupSchemaVersion = tRow0.SchemaVersion
        Set tBackupPhase = tRow0.Phase
        Set tBackupFailingStep = tRow0.FailingStep
        Set tBackupUpdatedAt = tRow0.UpdatedAt
        Set tBackupBuildIdentity = tRow0.BuildIdentity
    }

    Set tDeleteRan = 0
    Try {
        Set tDelSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile("")
        Set tDeleteRan = 1
        Do $$$AssertStatusOK(tDelSC, "DeleteByProfile('') succeeds")

        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile IS NULL")
        Do $$$AssertTrue(tRS.%Next(), "the post-delete count query returns a row")
        Do $$$AssertEquals(tRS.N, 0, "the production version row is actually deleted -- not left behind by a Profile = '' bind that never matches NULL")
    } Catch ex {
        If tDeleteRan && tHadRow Do ..RestoreProductionVersionRow(tBackupSchemaVersion, tBackupPhase, tBackupFailingStep, tBackupUpdatedAt, tBackupBuildIdentity)
        Throw ex
    }

    If tHadRow Do ..RestoreProductionVersionRow(tBackupSchemaVersion, tBackupPhase, tBackupFailingStep, tBackupUpdatedAt, tBackupBuildIdentity)

    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT SchemaVersion, Phase FROM OcuPilot_Kernel_State.Version WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS2.%Next(), "the production row exists again after the restore")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).GateStatus(), "installed", "production's gate resolves to installed again after the restore")
}

/// <p>Restores the production (<code>Profile IS NULL</code>) <class>Version</class>
/// row <method>TestVersionDeleteByProfileRemovesTheProductionRow</method>'s own
/// destructive <code>DeleteByProfile("")</code> call removed -- called from both that
/// method's straight-line path and its <code>Catch</code> block, matching
/// <class>OcuPilot.Test.Demo</class>'s identical shape for the sibling table.</p>
Method RestoreProductionVersionRow(pSchemaVersion As %Integer, pPhase As %String, pFailingStep As %String, pUpdatedAt As %String, pBuildIdentity As %String)
{
    Set tRestoreRow = ##class(OcuPilot.Kernel.State.Version).%New()
    Set tRestoreRow.Profile = ""
    Set tRestoreRow.SchemaVersion = pSchemaVersion
    Set tRestoreRow.Phase = pPhase
    Set tRestoreRow.FailingStep = pFailingStep
    Set tRestoreRow.UpdatedAt = pUpdatedAt
    Set tRestoreRow.BuildIdentity = pBuildIdentity
    Set tRestoreSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRestoreRow)
    Do $$$AssertStatusOK(tRestoreSC, "restored the pre-existing production version row this test's own destructive call removed")
}

}
