/// <p><b>DW-65</b> (the owner's decision, rework iteration 6):
/// <method>OcuPilot.Install.Installer.Uninstall</method> must not drop the protected
/// database while any demo fixture inventory row remains. Before the fix it called
/// <method>OcuPilot.Install.Fixture.Remove</method>, logged its warns, and then deleted the
/// <code>OcuPilot*</code> mapping and the database regardless. That destroyed the inventory
/// <method>OcuPilot.Install.Fixture.Remove</method> had just kept for a retry, and orphaned
/// the object it recorded.</p>
/// <p>Runs against the disposable <code>"probe"</code> profile, never production:
/// <method>OnBeforeOneTest</method> installs it and <method>OnAfterOneTest</method> removes
/// it, as in <class>OcuPilot.Test.Installer</class>. A separate class from that one only to
/// keep each test class near the ~500-line bound
/// (<file>.claude/rules/objectscript-testing.md</file>). For this profile the inventory
/// rows live in the production protected database, which is never touched here -- so the
/// test can watch the probe's own database survive the refusal and the probe's own
/// inventory rows survive with it. The production case, where the rows live in the very
/// database the refusal protects, was observed on a throwaway container (this story's
/// spec, <code>## Verification</code>).</p>
/// <p>It also pins which roles uninstall keeps: the read of the roles web applications carry names
/// a role in every form <code>MatchRoles</code> stores it, and a roster role no present application
/// carries is removed. Those tests create web applications of their own under
/// <parameter>ROLEAPPPREFIX</parameter> and remove them in every exit path.</p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.UninstallGuard Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the install this class
/// runs happens on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The path prefix of the web applications the role tests create, one letter of
/// <parameter>ROLEAPPSUFFIXES</parameter> each.</p>
Parameter ROLEAPPPREFIX As %String = "/csp/ocuprobe1843";

/// <p>The path suffixes <parameter>ROLEAPPPREFIX</parameter> takes.</p>
Parameter ROLEAPPSUFFIXES As %String = "abcd";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
/// <p><b>A doc comment does not keep a class that installs from installing.</b> Test classes are
/// selected by package, so pointing the runner at a container someone cares about would run
/// OcuPilot's production install on it. Failing here is the honest outcome: nothing is installed
/// and the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallGuard runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
}

/// <p>Production first, then the probe -- the same priming order, and for the same reason,
/// as <method>OcuPilot.Test.Installer.OnBeforeOneTest</method>: every install records a
/// stamp through the production privileged routine application.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

/// <p>Disarm both fault classes, then return the instance to "the probe profile is not installed",
/// applications and shell directory included: a refusal leaves them, and an uninstall whose
/// protected state is already gone removes none.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do ##class(OcuPilot.Test.UninstallFault).Disarm()
    Do ..RemoveRoleApps()
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>Hand-creates one fixture object -- a disposable SSL/TLS configuration -- and its
/// <code>"probe"</code> inventory row, plus five more rows whose objects are not on the
/// instance (a web application, an X.509 credential, a wallet collection and a task that do not
/// exist, and an
/// <code>errorentry</code>), which is the shape a real refusal has: one failed delete keeps
/// the <i>whole</i> inventory. It arms <class>OcuPilot.Test.FixtureFault</class>'s delete
/// fault and uninstalls through <class>OcuPilot.Test.UninstallFault</class>, so the real
/// <method>OcuPilot.Install.Fixture.Remove</method> fails that one delete for real and
/// keeps every row. <method>OcuPilot.Install.Installer.Uninstall</method> must then refuse,
/// name all six rows with the state of each object, and leave the probe's database,
/// mapping and inventory rows in place. With the fault cleared, the production
/// <method>OcuPilot.Install.Installer.Uninstall</method> must complete the same removal.</p>
/// <p>Mutation (Rule 19): delete the refusal block after the fixture removal in
/// <method>OcuPilot.Install.Installer.Uninstall</method>, restoring the unconditional drop.
/// The call then returns OK and the probe's database is gone, so the refusal and survival
/// assertions go red. The inventory-row assertion stays green under that mutation, because
/// the probe's rows live in production's database, which the probe uninstall never drops.
/// Second mutation: swap the two arms of <method>OcuPilot.Install.Fixture.ObjectState</method>'s
/// web application branch, and the "(already removed)" assertion for the web application
/// goes red.</p>
Method TestUninstallStopsWhileAFixtureCannotBeRemoved()
{
    Set tPrefix = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe")
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tName = tPrefix _ "UninstallTLS"
    Set tGoneApp = "/csp/ocupilotprobeuninstallgone"
    Set tGoneCert = tPrefix _ "UninstallGoneCert"
    Set tGoneTask = tPrefix _ "UninstallGone task"
    Set tGoneWallet = tPrefix _ "UninstallGoneWallet"
    Set tErrName = tPrefix _ "UninstallErr"
    Set tRows = $ListBuild($ListBuild("sslconfig", tName, "instance"), $ListBuild("webapp", tGoneApp, "instance"), $ListBuild("x509credential", tGoneCert, "instance"), $ListBuild("walletcollection", tGoneWallet, "instance"), $ListBuild("task", tGoneTask, tInstallNs), $ListBuild("errorentry", tErrName, tInstallNs))
    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do ..DeleteRows(tRows)

    Try {
        Do $$$AssertStatusOK(..SslConfig(tName, "create"), "hand-created the disposable SSL/TLS configuration fixture")
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            Do $$$AssertStatusOK(..SeedRow($List(tRow, 1), $List(tRow, 2), $List(tRow, 3)), "hand-created the probe inventory row for " _ $List(tRow, 1) _ " '" _ $List(tRow, 2) _ "'")
        }

        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.FixtureFault).SetDeletesShouldFail(1)
        Set tSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 1)
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()

        Do $$$AssertStatusNotOK(tSC, "Uninstall refuses while a fixture it could not remove is still recorded in the inventory")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue(tText [ "stopped before removing the protected database", "the refusal says Uninstall stopped before the database: " _ tText)
        Do $$$AssertTrue(tText [ "6 demo fixture inventory row(s) remain", "the refusal counts all six kept rows: " _ tText)
        Do $$$AssertTrue(tText [ ("sslconfig '" _ tName _ "' (still on the instance)"), "the refusal names the object that is left and says it is still on the instance: " _ tText)
        Do $$$AssertTrue(tText [ ("webapp '" _ tGoneApp _ "' (already removed)"), "the web application row reads 'already removed': " _ tText)
        Do $$$AssertTrue(tText [ ("x509credential '" _ tGoneCert _ "' (already removed)"), "the X.509 credential row reads 'already removed': " _ tText)
        Do $$$AssertTrue(tText [ ("walletcollection '" _ tGoneWallet _ "' (already removed)"), "the wallet collection row reads 'already removed': " _ tText)
        Do $$$AssertTrue(tText [ ("task '" _ tGoneTask _ "' (already removed)"), "the task row reads 'already removed': " _ tText)
        Do $$$AssertTrue(tText [ ("errorentry '" _ tErrName _ "' (nothing to remove)"), "the error-entry row reads 'nothing to remove': " _ tText)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue(tWarns [ "Could not delete the demo SSL/TLS configuration fixture", "the failed delete itself is logged as a warn")
        Do $$$AssertTrue(tWarns [ "Uninstall stopped before removing the protected database", "the refusal is logged as a warn too")
        Set tLeftCount = -1
        Try {
            Set tLeftCount = {}.%FromJSON(##class(OcuPilot.Test.InstallerProbe).Captured("lastWarnData")).left.%Size()
        } Catch exJson {
            Set tLeftCount = -1
        }
        Do $$$AssertEquals(tLeftCount, 6, "the refusal's logged data lists every remaining row")

        Do $$$AssertStatusOK(..ProbeState(tName, .tDbExists, .tDatExists, .tMapExists, .tSslExists), "re-read the probe's objects after the refusal")
        Do $$$AssertTrue(tDbExists, "the probe's database configuration survives the refusal")
        Do $$$AssertTrue(tDatExists, "the probe's IRIS.DAT survives the refusal")
        Do $$$AssertTrue(tMapExists, "the probe's global mapping survives the refusal -- nothing else was removed")
        Do $$$AssertTrue(tSslExists, "the SSL/TLS configuration is still there -- the delete genuinely failed")
        Do $$$AssertEquals(..CountRows(tRows), 6, "every inventory row survives, so a retry can still find the object")

        ; The fault cleared, the production class completes the same removal.
        Set tRetrySC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
        Do $$$AssertStatusOK(tRetrySC, "with the blocker cleared, a re-run of Uninstall completes")
        Do $$$AssertStatusOK(..ProbeState(tName, .tDbAfter, .tDatAfter, .tMapAfter, .tSslAfter), "re-read the probe's objects after the re-run")
        Do $$$AssertTrue('tSslAfter, "the re-run removed the SSL/TLS configuration the first attempt could not")
        Do $$$AssertTrue('tDbAfter && 'tDatAfter && 'tMapAfter, "and then removed the probe's database, IRIS.DAT and mapping")
        Do $$$AssertEquals(..CountRows(tRows), 0, "and purged every inventory row")
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do ..SslConfig(tName, "delete")
        Do ..DeleteRows(tRows)
        Throw ex
    }

    ; Belt and braces: both are no-ops when the re-run above did its job.
    Do $$$AssertStatusOK(..SslConfig(tName, "delete"), "cleanup found nothing left to remove, or removed it for real")
    Do ..DeleteRows(tRows)
}

/// <p>The inventory read after removal fails while its privileged routine application
/// still exists -- "could not tell" -- so <method>OcuPilot.Install.Installer.Uninstall</method>
/// must refuse and leave the probe's database and mapping in place, never read the failure
/// as "nothing left". Forced through <class>OcuPilot.Test.UninstallFault</class>'s
/// <method>OcuPilot.Test.UninstallFault.RemainingDemoFixtures</method> override.</p>
/// <p>Mutation (Rule 19): delete the branch that refuses on a failed read. The failed read
/// leaves the row count at 0, so <method>OcuPilot.Install.Installer.Uninstall</method>
/// carries on and drops the database, and every assertion below goes red.</p>
Method TestUninstallStopsWhenTheInventoryCannotBeRead()
{
    Do ##class(OcuPilot.Test.UninstallFault).Disarm()
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.UninstallFault).SetInventoryReadFails(1)
        Set tSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 1)
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()

        Do $$$AssertStatusNotOK(tSC, "Uninstall refuses when the inventory cannot be read after removal")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue(tText [ "the demo fixture inventory could not be read after fixture removal", "the refusal says why: " _ tText)
        Do $$$AssertTrue(tText [ "run Install with no profile", "the refusal names the remedy -- the production profile holds every profile's inventory: " _ tText)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue(tWarns [ "Uninstall stopped before removing the protected database: the demo fixture inventory could not be read", "the refusal is logged as a warn")
        Do $$$AssertStatusOK(..ProbeState("", .tDbExists, .tDatExists, .tMapExists, .tSsl), "re-read the probe's objects after the refusal")
        Do $$$AssertTrue(tDbExists, "the probe's database configuration survives a refusal on an unreadable inventory")
        Do $$$AssertTrue(tDatExists, "the probe's IRIS.DAT survives it")
        Do $$$AssertTrue(tMapExists, "the probe's global mapping survives it")
    } Catch ex {
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()
        Throw ex
    }
}

/// <p>The one exception to the refusal above: the inventory cannot be read because its
/// privileged routine application no longer exists -- the state a completed production
/// uninstall leaves, in which a repeat run must stay a no-op rather than become an error
/// whose only remedy is to reinstall. <method>OcuPilot.Install.Installer.Uninstall</method>
/// must warn and complete. Forced through <class>OcuPilot.Test.UninstallFault</class>'s
/// read and application-existence overrides; the real application is never touched.</p>
/// <p>Mutation (Rule 19): make the exception refuse as well, and the call returns an error
/// with the probe's database still in place, so every assertion below goes red.</p>
Method TestUninstallContinuesWhenTheInventoryIsGone()
{
    Do ##class(OcuPilot.Test.UninstallFault).Disarm()
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.UninstallFault).SetInventoryReadFails(1)
        Do ##class(OcuPilot.Test.UninstallFault).SetInventoryAppAbsent(1)
        Set tSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 1)
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()

        Do $$$AssertStatusOK(tSC, "Uninstall completes when the inventory's own application is already gone: " _ $System.Status.GetErrorText(tSC))
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue(tWarns [ "Could not check the demo fixture inventory after fixture removal", "the skipped check is reported as a warn, never silently")
        Do $$$AssertStatusOK(..ProbeState("", .tDbAfter, .tDatAfter, .tMapAfter, .tSsl), "re-read the probe's objects after the run")
        Do $$$AssertTrue('tDbAfter && 'tDatAfter && 'tMapAfter, "the probe's database, IRIS.DAT and mapping were removed")
    } Catch ex {
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()
        Throw ex
    }
}

/// <p>Uninstall cannot tell what install created without the web-application provenance record, so
/// when that record cannot be read while the profile's privileged routine application exists it
/// refuses, naming the record and the remedy, and removes nothing. Forced through
/// <class>OcuPilot.Test.UninstallFault</class>'s
/// <method>OcuPilot.Test.UninstallFault.ReadApplicationProvenance</method> override; the profile's
/// own application is left alone, so the read genuinely fails against an application that exists.</p>
/// <p>Mutation (Rule 19): restore the warn-and-continue read in
/// <method>OcuPilot.Install.Installer.Uninstall</method> -- the call completes and the database and
/// mapping are gone, so the refusal and database assertions go red (with an empty record the
/// applications and directory are left in place either way).</p>
Method TestUninstallRefusesWhenTheProvenanceRecordCannotBeRead()
{
    Set tApps = ##class(OcuPilot.Test.ProbeApps).Existing()
    Set tDir = ##class(OcuPilot.Test.ProbeApps).ShellDirectory()
    Do $$$AssertTrue((tApps '= "") && ($Extract(tApps, 1, 6) '= "error:"), "precondition: the probe applications exist: " _ tApps)
    Do $$$AssertTrue((tDir '= "") && ##class(%File).DirectoryExists(tDir), "and so does the shell bundle directory: " _ tDir)

    Do ##class(OcuPilot.Test.UninstallFault).Disarm()
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.UninstallFault).SetProvenanceReadFails(1)
        Set tSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 1)
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()

        Do $$$AssertStatusNotOK(tSC, "Uninstall refuses when the provenance record cannot be read")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue(tText [ "provenance record could not be read", "the refusal names the record: " _ tText)
        Do $$$AssertTrue(tText [ "Nothing was removed", "and says nothing was removed: " _ tText)
        Do $$$AssertTrue(tText [ "run Install with no profile", "and names the remedy: " _ tText)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue(tWarns [ "Uninstall refused: this profile's web-application provenance record could not be read", "the refusal is logged as a warn")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProbeApps).Existing(), tApps, "every probe application remains")
        Do $$$AssertTrue(##class(%File).DirectoryExists(tDir), "and so does the shell bundle directory")
        Do $$$AssertStatusOK(..ProbeState("", .tDb, .tDat, .tMap, .tSsl), "re-read the probe's objects after the refusal")
        Do $$$AssertTrue(tDb && tDat && tMap, "the probe's database, IRIS.DAT and mapping remain")

        ; The same refusal answers a call that asks only for the preview.
        Do ##class(OcuPilot.Test.UninstallFault).SetProvenanceReadFails(1)
        Set tPreviewSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 0)
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()
        Do $$$AssertTrue($System.Status.GetErrorText(tPreviewSC) [ "provenance record could not be read", "an unconfirmed call is refused the same way, not previewed")
    } Catch ex {
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()
        Throw ex
    }
}

/// <p>Uninstall cannot tell a role another application carries from one nothing carries without
/// reading the applications' roles, so when that read fails it refuses, naming the roles and
/// saying nothing was removed. Forced through <class>OcuPilot.Test.UninstallFault</class>'s
/// <method>OcuPilot.Test.UninstallFault.RolesInUse</method> override.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Install.Installer.Uninstall</method> carry on past a
/// failed roles read -- the call completes and the database, applications and directory are gone,
/// so every assertion below goes red.</p>
Method TestUninstallRefusesWhenTheApplicationRolesCannotBeRead()
{
    Set tApps = ##class(OcuPilot.Test.ProbeApps).Existing()
    Set tDir = ##class(OcuPilot.Test.ProbeApps).ShellDirectory()
    Do $$$AssertTrue((tApps '= "") && ($Extract(tApps, 1, 6) '= "error:"), "precondition: the probe applications exist: " _ tApps)
    Do $$$AssertTrue((tDir '= "") && ##class(%File).DirectoryExists(tDir), "and so does the shell bundle directory: " _ tDir)

    Do ##class(OcuPilot.Test.UninstallFault).Disarm()
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.UninstallFault).SetRolesReadFails(1)
        Set tSC = ##class(OcuPilot.Test.UninstallFault).Uninstall("probe", 1)
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()

        Do $$$AssertStatusNotOK(tSC, "Uninstall refuses when the applications' roles cannot be read")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue(tText [ "matching roles could not be read", "the refusal names the roles: " _ tText)
        Do $$$AssertTrue(tText [ "Nothing was removed", "and says nothing was removed: " _ tText)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue(tWarns [ "Uninstall refused: the web applications' roles could not be read", "the refusal is logged as a warn")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProbeApps).Existing(), tApps, "every probe application remains")
        Do $$$AssertTrue(##class(%File).DirectoryExists(tDir), "and so does the shell bundle directory")
        Do $$$AssertStatusOK(..ProbeState("", .tDb, .tDat, .tMap, .tSsl), "re-read the probe's objects after the refusal")
        Do $$$AssertTrue(tDb && tDat && tMap, "the probe's database, IRIS.DAT and mapping remain")
    } Catch ex {
        Do ##class(OcuPilot.Test.UninstallFault).Disarm()
        Throw ex
    }
}

/// <p>The read of which roles web applications carry names a role in every form
/// <code>MatchRoles</code> stores it -- an unconditional entry (<code>:Role</code>) and a conditional
/// one (<code>Held:Role</code>), on either side of the colon -- keyed by the upper-cased role and
/// listing every application that names it. It never lists an application that names only other roles
/// or none, and leaves out an application the caller excepts.</p>
/// <p>Mutations (Rule 19): read only each entry's target role in
/// <method>OcuPilot.Install.Installer.RoleNamesIn</method> -- the held-role legs go red. Drop the
/// <var>pExcept</var> skip from <method>OcuPilot.Install.Installer.RolesInUse</method> -- the excepted
/// leg goes red.</p>
Method TestRolesInUseNamesARoleInEveryFormAnApplicationCarriesIt()
{
    Set tA = ..#ROLEAPPPREFIX _ "a"
    Set tB = ..#ROLEAPPPREFIX _ "b"
    Set tC = ..#ROLEAPPPREFIX _ "c"
    Set tD = ..#ROLEAPPPREFIX _ "d"
    Do ..RemoveRoleApps()
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tA, ":%Operator"), "an application carries %Operator unconditionally")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tB, "%Manager:%Operator"), "one carries %Operator when its user holds %Manager")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tC, "%Developer:%Manager"), "one carries %Manager when its user holds %Developer")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tD), "and one carries no role")

        Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).DriveRolesInUse(.tNone, .tRoles), "the read succeeds")
        Set tOperator = $Get(tRoles("%OPERATOR"))
        Do $$$AssertTrue(..Names(tOperator, tA) && ..Names(tOperator, tB), "%Operator is named by the unconditional and the conditional entry: " _ tOperator)
        Do $$$AssertTrue('..Names(tOperator, tC) && '..Names(tOperator, tD), "and by no application that carries only other roles or none")
        Set tManager = $Get(tRoles("%MANAGER"))
        Do $$$AssertTrue(..Names(tManager, tB) && ..Names(tManager, tC), "%Manager is named where it is held and where it is carried: " _ tManager)
        Do $$$AssertTrue('..Names(tManager, tA) && '..Names(tManager, tD), "and not by an application that names neither")
        Set tDeveloper = $Get(tRoles("%DEVELOPER"))
        Do $$$AssertTrue(..Names(tDeveloper, tC) && '..Names(tDeveloper, tA) && '..Names(tDeveloper, tB) && '..Names(tDeveloper, tD), "%Developer is named by the one entry that holds it: " _ tDeveloper)

        Set tExcept(tA) = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).DriveRolesInUse(.tExcept, .tRoles), "the read succeeds with an application excepted")
        Do $$$AssertTrue('..Names($Get(tRoles("%OPERATOR")), tA) && ..Names($Get(tRoles("%OPERATOR")), tB), "an excepted application is left out and the others stay")
    } Catch ex {
        Do ..RemoveRoleApps()
        Throw ex
    }
    Do ..RemoveRoleApps()
}

/// <p>A roster matching role goes with uninstall when the web applications present on the instance
/// carry only other roles: the present application keeps its own roles and no role is reported kept.</p>
/// <p>Mutation (Rule 19): let the role loop of <method>OcuPilot.Install.Installer.Uninstall</method>
/// keep every roster role whenever any application carries any role (<code>$Data(tInUse)</code>) -- the
/// role survives and this goes red.</p>
Method TestUninstallRemovesAMatchingRoleThatAPresentApplicationDoesNotCarry()
{
    Set tRole = $Piece(##class(OcuPilot.Test.Provenance).MatchRolesOf(##class(OcuPilot.Test.Provenance).#PROBESHELL), ":", 2)
    Do $$$AssertTrue(tRole '= "", "the shell application carries a matching role: " _ tRole)
    Set tApp = ..#ROLEAPPPREFIX _ "a"
    Do ..RemoveRoleApps()
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tApp, ":%Operator"), "a present application carries another role")
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).Uninstall("probe", 1)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()

        Do $$$AssertStatusOK(tSC, "uninstall succeeds: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertTrue('##class(OcuPilot.Test.Provenance).RoleExists(tRole), "the matching role is removed")
        Do $$$AssertEquals(##class(OcuPilot.Test.Provenance).MatchRolesOf(tApp), ":%Operator", "the present application keeps its own role")
        Do $$$AssertTrue('(tWarns [ "left a matching role in place"), "and no role is reported kept: " _ tWarns)
    } Catch ex {
        Do ..RemoveRoleApps()
        Throw ex
    }
    Do ..RemoveRoleApps()
}

/// <p>Whether <var>pPath</var> is one of the comma-separated applications in <var>pList</var>.</p>
ClassMethod Names(pList As %String, pPath As %String) As %Boolean
{
    Quit ($ListFind($ListFromString(pList, ", "), pPath) > 0)
}

/// <p>Delete every web application the role tests create that still exists.</p>
ClassMethod RemoveRoleApps()
{
    For tI = 1:1:$Length(..#ROLEAPPSUFFIXES) {
        Set tPath = ..#ROLEAPPPREFIX _ $Extract(..#ROLEAPPSUFFIXES, tI)
        If ##class(OcuPilot.Test.Provenance).ApplicationDispatchClass(tPath) '= "" Do ##class(OcuPilot.Test.Provenance).DeleteApplication(tPath)
    }
}

/// <p>Save one <code>"probe"</code> inventory row through the guarded path.</p>
Method SeedRow(pKind As %String, pName As %String, pScope As %String) As %Status
{
    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = "probe"
    Set tRow.Kind = pKind
    Set tRow.Name = pName
    Set tRow.Scope = pScope
    Quit ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
}

/// <p>How many of the <code>"probe"</code> inventory rows named in <var>pRows</var> exist.</p>
Method CountRows(pRows As %List) As %Integer
{
    Set tCount = 0
    For tI = 1:1:$ListLength(pRows) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = 'probe' AND Kind = ? AND Name = ?", $List($List(pRows, tI), 1), $List($List(pRows, tI), 2))
        If tRS.%Next() Set tCount = tCount + tRS.N
    }
    Quit tCount
}

/// <p>Delete the <code>"probe"</code> inventory rows named in <var>pRows</var>, if any --
/// a pre-clean and a cleanup. A failure surfaces through the next assertion that counts
/// them.</p>
Method DeleteRows(pRows As %List)
{
    For tI = 1:1:$ListLength(pRows) {
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = 'probe' AND Kind = ? AND Name = ?", $List($List(pRows, tI), 1), $List($List(pRows, tI), 2))
    }
}

/// <p>Create (<var>pAction</var> <code>"create"</code>) or delete (<code>"delete"</code>) the
/// disposable SSL/TLS configuration <var>pName</var> in <code>%SYS</code>. Both are
/// no-ops when the object is already in the requested state.</p>
Method SslConfig(pName As %String, pAction As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tExists = ##class(Security.SSLConfigs).Exists(pName, .tE, .tS)
        If (pAction = "create") && 'tExists {
            Set tProps("Description") = "OcuPilot.Test.UninstallGuard disposable object (DW-65)"
            Set tSC = ##class(Security.SSLConfigs).Create(pName, .tProps)
        } ElseIf (pAction = "delete") && tExists {
            Set tSC = ##class(Security.SSLConfigs).Delete(pName)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the probe's database configuration, its <code>IRIS.DAT</code>, its global
/// mapping and the disposable SSL/TLS configuration <var>pSslName</var> currently exist.
/// An empty <var>pSslName</var> reports <var>pSsl</var> as <code>0</code>.</p>
Method ProbeState(pSslName As %String, Output pDb As %Boolean, Output pDat As %Boolean, Output pMap As %Boolean, Output pSsl As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pDb = 0
    Set pDat = 0
    Set pMap = 0
    Set pSsl = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tDir = ##class(%File).NormalizeDirectory("ocupilotprobe", $System.Util.ManagerDirectory())
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set pDb = ''##class(Config.Databases).Exists("OCUPILOTPROBE", .tE1, .tS1)
        Set pDat = ''##class(%File).Exists(tDir _ "IRIS.DAT")
        Set pMap = ''##class(Config.MapGlobals).Exists(tInstallNs, "ProbeOcuPilotState*", .tE2, .tS2)
        If pSslName '= "" Set pSsl = ''##class(Security.SSLConfigs).Exists(pSslName, .tE3, .tS3)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
