/// <p>Story 13.1, AC1 and AC2 -- what <method>OcuPilot.Install.Installer.Uninstall</method>
/// removes when the instance is <b>not</b> in the state install left it in. Four legs: a real
/// <class>%SYS.Task</class> demo fixture and its inventory row; one target removed by hand
/// before the uninstall, once per target; a roster-declared matching role whose application
/// another hand had already removed; and, on a plain cycle, the shell bundle directory and
/// this profile's own provenance and version bookkeeping.</p>
/// <p>Every assertion runs against the disposable <code>"probe"</code> profile, whose object
/// names are derived here from the same declarations the installer reads rather than
/// transcribed. Three literals are not derived and are named at their declarations: the global
/// mapping pattern (<parameter>PROBEMAPPING</parameter>), which
/// <method>OcuPilot.Install.Installer.Names</method> makes a wholesale distinct literal that
/// production's own does not yield; the fixture task class
/// (<parameter>TASKCLASS</parameter>); and the shell roster key
/// (<parameter>SHELLKEY</parameter>).
/// It also runs OcuPilot's <b>production</b> install -- the probe's protected database is
/// created through production's own privileged routine application -- so it runs on a
/// throwaway container only (<file>scripts/ci-throwaway.sh</file>) and refuses wherever
/// <parameter>ARMINGVARIABLE</parameter> does not arm it, in <method>OnBeforeAllTests</method>
/// and again in <method>OnAfterAllTests</method>, which <class>%UnitTest.Manager</class> calls
/// even after <method>OnBeforeAllTests</method> returned an error.</p>
Class OcuPilot.Test.UninstallResidue Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The profile suffix <method>OcuPilot.Install.Installer.Names</method> applies to the
/// disposable profile's object names.</p>
Parameter PROBESUFFIX As %String = "Probe";

/// <p>The task class <method>OcuPilot.Install.Fixture.RemoveOne</method> queries by, so the
/// hand-created task in <method>TestUninstallRemovesARealScheduledTaskFixture</method> is one
/// the real removal path can find.</p>
Parameter TASKCLASS As %String = "OcuPilot.Install.DemoTask";

/// <p>The suffix on this class's own disposable task name, kept distinct from the demo
/// fixture's own so a run never removes a fixture another profile owns.</p>
Parameter TASKNAME As %String = "Residue purge";

/// <p>The roster key of the shell application, whose bundle directory
/// <method>ShellDirectory</method> derives. The key itself is named here rather than read
/// from the roster's <code>bundle.destinationApplication</code>;
/// <class>OcuPilot.Test.Manifest</class> pins the roster's keys, so a key that moved fails
/// there rather than silently here.</p>
Parameter SHELLKEY As %String = "shell";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallResidue runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Production first, then the probe: every install records its stamp through production's
/// privileged routine application.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

Method OnAfterOneTest() As %Status
{
    Quit ..CleanProbe()
}

/// <p>Armed exactly as <method>OnBeforeAllTests</method> is: the manager calls this on the
/// error path too, and without the guard an unarmed instance would still run a probe
/// uninstall under <var>pConfirmDataLoss</var>.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$OK
    }
    Quit ..CleanProbe()
}

/// <p>Return the instance to "the probe profile is not installed". Uninstall removes only
/// what a provenance row records, so an application a leg deleted by hand -- and any
/// matching role a regressed uninstall left behind -- are removed by name afterwards, along
/// with this class's own task and inventory rows.</p>
Method CleanProbe() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProbeApps).Remove()
    Do ..RemoveTaskAndRows()
    Do ..RemoveProbeRoles()
    Quit tSC
}

/// <p>Delete every probe matching role the roster declares that is still on the instance --
/// the leftover a regressed role loop produces, which
/// <method>OcuPilot.Test.ProbeApps.Existing</method> cannot see because it reads applications
/// only.</p>
Method RemoveProbeRoles()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tPaths = ##class(OcuPilot.Test.ProbeApps).Paths(.tRoles)
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            For tI = 1:1:$ListLength(tPaths) {
                Set tRole = $Get(tRoles($ListGet(tPaths, tI)))
                If tRole = "" Continue
                If ##class(Security.Roles).Exists(tRole, .tE, .tS) Do ##class(Security.Roles).Delete(tRole)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Delete this class's own disposable task, wherever a leg left it, and its inventory
/// rows. No <code>%SYS</code> switch: <class>OcuPilot.Install.Fixture</class> is compiled
/// only into the install namespace, so a fresh dispatch to it from <code>%SYS</code> raises
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code>, and both calls below answer from here.</p>
Method RemoveTaskAndRows()
{
    Try {
        Set tName = ..TaskName()
        Set tScope = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Kill tIds
        Set tQSC = ##class(OcuPilot.Install.Fixture).TaskIds(..#TASKCLASS, tName, tScope, .tIds)
        If $$$ISOK(tQSC) {
            For tI = 1:1:$Get(tIds) {
                Do ##class(%SYS.Task).%DeleteId(tIds(tI))
            }
        }
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = 'probe' AND Kind = 'task' AND Name = ?", tName)
    } Catch ex {
        Set tName = ""
    }
}

/// <p>The disposable task's full name, as <method>OcuPilot.Install.Fixture.ResolvedPrefix</method>
/// builds a probe fixture name.</p>
Method TaskName() As %String
{
    Quit ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ ..#TASKNAME
}

/// <p>Every probe-profile object install creates that is still on the instance, comma
/// separated, or <code>""</code>. A failed <code>%SYS</code> switch, or anything that throws,
/// answers with its own text rather than with <code>""</code>. <b>An individual
/// <code>Exists</code> that fails to read is not distinguished from one that answers
/// "absent"</b> (the statuses the ten calls below take by reference are not inspected), so
/// this method's <code>""</code> means "no residue was found", not "no residue is there" --
/// the same unsafe direction DW-1271 records for the caller-side guard.</p>
Method Residue() As %String
{
    Set tOut = ""
    Set tFail = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tDatabase = ##class(OcuPilot.Kernel.State.Base).#DATABASENAME _ $ZConvert(..#PROBESUFFIX, "U")
        Set tDir = ##class(%File).NormalizeDirectory($ZConvert(tDatabase, "L"), $System.Util.ManagerDirectory())
        Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
        Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
        Set tEvents = ##class(OcuPilot.Kernel.Audit.Event).Names(..#PROBESUFFIX)
        Set tPaths = ##class(OcuPilot.Test.ProbeApps).Paths(.tRoles)
        Set tMapping = ..MappingPattern()
        Set tStateApp = ##class(OcuPilot.Kernel.State.Base).#APPLICATION _ ..#PROBESUFFIX
        Set tAdmin = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ..#PROBESUFFIX
        Set tSsl = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG _ ..#PROBESUFFIX
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set tFail = "could not switch to %SYS: " _ $System.Status.GetErrorText(tSC)
            Quit
        }
        If ##class(Config.MapGlobals).Exists(tInstallNs, tMapping, .tE1, .tS1) Set tOut = tOut _ ",mapping " _ tMapping
        If ##class(Security.Applications).Exists(tStateApp, .tE2, .tS2) Set tOut = tOut _ ",application " _ tStateApp
        If ##class(Security.Roles).Exists(tAdmin, .tE3, .tS3) Set tOut = tOut _ ",role " _ tAdmin
        If ##class(Security.Resources).Exists(tAdmin, .tE4, .tS4) Set tOut = tOut _ ",resource " _ tAdmin
        If ##class(Security.Resources).Exists("%DB_" _ tDatabase, .tE5, .tS5) Set tOut = tOut _ ",resource %DB_" _ tDatabase
        If ##class(Config.Databases).Exists(tDatabase, .tE6, .tS6) Set tOut = tOut _ ",database " _ tDatabase
        If ##class(%File).DirectoryExists(tDir) Set tOut = tOut _ ",directory " _ tDir
        If ##class(Security.SSLConfigs).Exists(tSsl, .tE7, .tS7) Set tOut = tOut _ ",sslconfig " _ tSsl
        For tI = 1:1:$ListLength(tEvents) {
            Set tEvName = $ListGet(tEvents, tI)
            If ##class(Security.Events).Exists(tSource, tType, tEvName, .tE8, .tS8) Set tOut = tOut _ ",auditevent " _ tEvName
        }
        For tI = 1:1:$ListLength(tPaths) {
            Set tPath = $ListGet(tPaths, tI)
            If ##class(Security.Applications).Exists(tPath, .tE9, .tS9) Set tOut = tOut _ ",application " _ tPath
            Set tRole = $Get(tRoles(tPath))
            If tRole = "" Continue
            If ##class(Security.Roles).Exists(tRole, .tE10, .tS10) Set tOut = tOut _ ",role " _ tRole
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFail = "the residue check failed: " _ ex.DisplayString()
    }
    If tFail '= "" Quit tFail
    Quit $Extract(tOut, 2, *)
}

/// <p>The probe profile's global mapping pattern. <method>OcuPilot.Install.Installer.Names</method>
/// makes it a wholesale distinct literal rather than a derivative of production's, so that the
/// two profiles' mappings can never overlap, and it is therefore spelled here too --
/// <parameter>MAPPINGPATTERN</parameter> is production's own and does not yield it.</p>
Parameter PROBEMAPPING As %String = "ProbeOcuPilotState*";

/// <p>See <parameter>PROBEMAPPING</parameter>.</p>
Method MappingPattern() As %String
{
    Quit ..#PROBEMAPPING
}

/// <p>The first probe application path whose roster entry declares a matching role, with
/// that role in <var>pRole</var> -- the application whose orphaned role this story is about.
/// Derived from the roster rather than named, so a roster reordering moves the target rather
/// than silently testing nothing. <code>""</code> when the roster declares no such
/// application.</p>
Method RoledApplication(Output pRole As %String) As %String
{
    Set pRole = ""
    Set tPaths = ##class(OcuPilot.Test.ProbeApps).Paths(.tRoles)
    For tI = 1:1:$ListLength(tPaths) {
        Set tPath = $ListGet(tPaths, tI)
        If $Get(tRoles(tPath)) = "" Continue
        Set pRole = tRoles(tPath)
        Quit
    }
    If pRole = "" Quit ""
    Quit tPath
}

/// <p>Whether the role <var>pRole</var> exists: <code>1</code> present, <code>0</code> absent,
/// <code>-1</code> when the read itself failed. Three-valued rather than Boolean because the
/// caller asserts the <b>negative</b> after uninstall -- that the orphaned role is gone, this
/// story's core claim -- and a failed lookup read as a negative result would pass that
/// assertion on no evidence. Switches to <code>%SYS</code> and restores (AD-16).</p>
Method RoleExists(pRole As %String) As %Integer
{
    Set tExists = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) Set tExists = ''##class(Security.Roles).Exists(pRole, .tE, .tS)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tExists = -1
    }
    Quit tExists
}

/// <p>Remove one of this profile's targets by hand, as another operator or another product
/// would: <var>pTarget</var> is <code>roledapplication</code>, <code>adminrole</code>,
/// <code>adminresource</code>, <code>sslconfig</code>, <code>mapping</code> or
/// <code>auditevent</code>. Returns the removal's own status; an unknown target is an error
/// rather than a silent no-op, so a mistyped row in the table below cannot pass as a leg that
/// removed something.</p>
Method DeleteTarget(pTarget As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tMapping = ..MappingPattern()
        Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
        Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
        Set tEvent = $ListGet(##class(OcuPilot.Kernel.Audit.Event).Names(..#PROBESUFFIX), 1)
        Set tRoled = ..RoledApplication(.tRoledRole)
        Set tAdmin = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ..#PROBESUFFIX
        Set tSsl = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG _ ..#PROBESUFFIX
        If (pTarget = "roledapplication") && (tRoled = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the roster declares no application with a matching role, so this leg would assert nothing")
            Quit
        }
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If pTarget = "roledapplication" {
            Set tSC = ##class(Security.Applications).Delete(tRoled)
        } ElseIf pTarget = "adminrole" {
            Set tSC = ##class(Security.Roles).Delete(tAdmin)
        } ElseIf pTarget = "adminresource" {
            Set tSC = ##class(Security.Resources).Delete(tAdmin)
        } ElseIf pTarget = "sslconfig" {
            Set tSC = ##class(Security.SSLConfigs).Delete(tSsl)
        } ElseIf pTarget = "mapping" {
            Set tSC = ##class(Config.MapGlobals).Delete(tInstallNs, tMapping)
        } ElseIf pTarget = "auditevent" {
            Set tSC = ##class(Security.Events).Delete(tSource, tType, tEvent)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "unknown hand-removal target '" _ pTarget _ "'")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>AC1 -- a real <class>%SYS.Task</class> recorded in the demo inventory is gone after a
/// confirmed uninstall, and its inventory row with it. The installer creates no task of its
/// own; the demo fixture's is the only one OcuPilot makes, so this is the clause's one
/// reachable target. The task is created here rather than through
/// <method>OcuPilot.Install.Fixture.Create</method>, which would also create four other
/// objects and run the task.</p>
Method TestUninstallRemovesARealScheduledTaskFixture()
{
    Set tName = ..TaskName()
    Set tScope = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do ..RemoveTaskAndRows()

    Do $$$AssertStatusOK(..CreateTask(tName, tScope), "hand-created a real %SYS.Task demo fixture")
    Do $$$AssertTrue(..TaskCount(tName, tScope) > 0, "the task is on the instance before uninstall")
    Do $$$AssertStatusOK(..SeedRow("task", tName, tScope), "hand-created the fixture's inventory row")

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds: " _ $System.Status.GetErrorText(tSC))

    Set tTasksLeft = ..TaskCount(tName, tScope)
    Do $$$AssertEquals(tTasksLeft, 0, "the scheduled task is gone from %SYS.Task after uninstall; found=" _ tTasksLeft)
    Set tRowsLeft = ..RowCount("task", tName)
    Do $$$AssertEquals(tRowsLeft, 0, "and its demo inventory row with it; found=" _ tRowsLeft)
    Set tLeft = ..Residue()
    Do $$$AssertEquals(tLeft, "", "and every other object install created is gone too; left=" _ tLeft)
}

/// <p>AC1 and AC2 -- with exactly one target removed by hand first, a confirmed uninstall
/// still returns OK and still removes every other object install created. One leg per
/// target: an already-absent object is never an error (AD-17), and a guard that stopped
/// guarding would fail its own row rather than the whole table.</p>
Method TestUninstallCompletesWithOneTargetAlreadyAbsent()
{
    Set tTargets = $ListBuild("roledapplication", "adminrole", "adminresource", "sslconfig", "mapping", "auditevent")
    For tI = 1:1:$ListLength(tTargets) {
        Set tTarget = $ListGet(tTargets, tI)
        Do $$$AssertStatusOK(..CleanProbe(), "the instance is clean before the '" _ tTarget _ "' leg")
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a probe install succeeds for the '" _ tTarget _ "' leg")
        Do $$$AssertStatusOK(..DeleteTarget(tTarget), "the '" _ tTarget _ "' target is removed by hand")

        Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
        Do $$$AssertStatusOK(tSC, "uninstall returns OK with '" _ tTarget _ "' already absent: " _ $System.Status.GetErrorText(tSC))
        Set tLeft = ..Residue()
        Do $$$AssertEquals(tLeft, "", "and every remaining target is removed with '" _ tTarget _ "' already absent; left=" _ tLeft)
    }
}

/// <p>AC1 and AC2 -- a roster-declared matching role whose application another hand removed
/// is itself removed. No application sits at that roster path any more, so there is no
/// AD-21 privilege floor to preserve; the role that buys it is residue. The opposite case,
/// an application uninstall deliberately leaves in place, keeps its role and is pinned by
/// <class>OcuPilot.Test.Provenance</class>.</p>
Method TestUninstallRemovesAMatchingRoleWhoseApplicationIsAlreadyGone()
{
    Set tPath = ..RoledApplication(.tRole)
    Do $$$AssertTrue(tPath '= "", "the roster declares an application with a matching role, so this leg asserts something")
    Do $$$AssertEquals(..RoleExists(tRole), 1, "that application's matching role " _ tRole _ " exists after install")

    Do $$$AssertStatusOK(..DeleteTarget("roledapplication"), "the application " _ tPath _ " is removed by hand, leaving its role")
    Do $$$AssertEquals(..RoleExists(tRole), 1, "the role outlives the application it was matched to")

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds: " _ $System.Status.GetErrorText(tSC))

    Set tRoleLeft = ..RoleExists(tRole)
    Do $$$AssertEquals(tRoleLeft, 0, "the orphaned matching role is removed -- no roster-declared role survives with no application at its roster path; read=" _ tRoleLeft)
    Set tLeft = ..Residue()
    Do $$$AssertEquals(tLeft, "", "and nothing else install created is left; left=" _ tLeft)
}

/// <p>AC1 -- three targets <method>Residue</method> does not check: the shell
/// application's bundle directory, this profile's
/// <class>OcuPilot.Kernel.State.WebApp</class> provenance rows, and its
/// <class>OcuPilot.Kernel.State.Version</class> row. None of the three is a demo-fixture
/// kind, so none is covered by the Design Notes' demo-inventory scope-out -- each is an
/// object a plain (not hand-mutilated) probe install always creates and a plain confirmed
/// uninstall is required to remove.</p>
Method TestUninstallRemovesTheShellDirectoryAndItsOwnProvenanceBookkeeping()
{
    Set tDir = ..ShellDirectory()
    Do $$$AssertTrue(tDir '= "", "the roster declares a shell application, so this leg asserts something")
    Do $$$AssertTrue(##class(%File).DirectoryExists(tDir), "the shell bundle directory exists after install: " _ tDir)
    Set tWebAppBefore = ..WebAppProvenanceRows()
    Do $$$AssertTrue(tWebAppBefore > 0, "at least one WebApp provenance row is recorded for this profile after install; found=" _ tWebAppBefore)
    Set tVersionBefore = ..VersionRows()
    Do $$$AssertEquals(tVersionBefore, 1, "exactly one Version row is recorded for the probe profile after install; found=" _ tVersionBefore)

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds: " _ $System.Status.GetErrorText(tSC))

    Do $$$AssertTrue('##class(%File).DirectoryExists(tDir), "the shell bundle directory is gone after uninstall: " _ tDir)
    Set tWebAppAfter = ..WebAppProvenanceRows()
    Do $$$AssertEquals(tWebAppAfter, 0, "and every WebApp provenance row for this profile is gone too; found=" _ tWebAppAfter)
    Set tVersionAfter = ..VersionRows()
    Do $$$AssertEquals(tVersionAfter, 0, "and the Version row is gone too; found=" _ tVersionAfter)
    Set tLeft = ..Residue()
    Do $$$AssertEquals(tLeft, "", "and every object the residue sweep covers is gone as well; left=" _ tLeft)
}

/// <p>The probe profile's shell-application bundle directory, computed the same way
/// <method>OcuPilot.Install.Installer.EnsureShellFiles</method> resolves it -- from the
/// roster's <parameter>SHELLKEY</parameter> application path through
/// <method>OcuPilot.Api.StaticHandler.RootDirectory</method> -- rather than transcribed.
/// <code>""</code> when the roster declares no such application.</p>
Method ShellDirectory() As %String
{
    Set tDir = ""
    Try {
        Set tSC = ##class(OcuPilot.Install.Roster).Application(..#SHELLKEY, .tApp)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tApp) Quit
        Set tPath = ##class(OcuPilot.Install.Installer).ProbeApplicationPath(tApp.path)
        If tPath = "" Quit
        Set tDir = ##class(OcuPilot.Api.StaticHandler).RootDirectory(tPath)
    } Catch ex {
        Set tDir = ""
    }
    Quit tDir
}

/// <p>How many <class>OcuPilot.Kernel.State.WebApp</class> provenance rows the
/// <code>"probe"</code> profile carries, across every application path -- not one hand-picked
/// path, so a row left behind for any of the profile's applications is visible.
/// <code>-1</code> when the read failed, so a failed read is never counted as zero rows.</p>
Method WebAppProvenanceRows() As %Integer
{
    Set tCount = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.WebApp WHERE Profile = 'probe'")
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tCount = tRS.N
    } Catch ex {
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many <class>OcuPilot.Kernel.State.Version</class> rows the <code>"probe"</code>
/// profile carries -- one while installed (that class's own header), zero after a clean
/// uninstall. <code>-1</code> when the read failed, so a failed read is never counted as
/// zero rows.</p>
Method VersionRows() As %Integer
{
    Set tCount = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tCount = tRS.N
    } Catch ex {
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Create one real <class>%SYS.Task</class> the fixture removal path can find: the class
/// and name it queries by, bound to <var>pScope</var>. Scheduled daily at 03:00 so the Task
/// Manager never runs it during a test run, and the object reference is released as soon as
/// the save returns rather than held across the rest of the method.</p>
Method CreateTask(pName As %String, pScope As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tTask = ##class(%SYS.Task).%New()
        Set tTask.Name = pName
        Set tTask.Description = "OcuPilot.Test.UninstallResidue disposable task fixture (AC1)"
        Set tTask.NameSpace = pScope
        Set tTask.TaskClass = ..#TASKCLASS
        Set tTask.TimePeriod = 0
        Set tTask.TimePeriodEvery = 1
        Set tTask.DailyFrequency = 0
        Set tTask.DailyStartTime = 10800
        Set tTask.SuspendOnError = 1
        Set tTask.Expires = 0
        Set tSC = tTask.%Save()
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many <class>%SYS.Task</class> rows carry <var>pName</var> for this class's task
/// class in <var>pScope</var>, read through the same helper the removal path queries by. A
/// failed query answers <code>-1</code>, never <code>0</code>. Runs in the install namespace
/// for the reason <method>RemoveTaskAndRows</method> records.</p>
Method TaskCount(pName As %String, pScope As %String) As %Integer
{
    Set tCount = -1
    Try {
        Kill tIds
        Set tQSC = ##class(OcuPilot.Install.Fixture).TaskIds(..#TASKCLASS, pName, pScope, .tIds)
        If $$$ISOK(tQSC) Set tCount = +$Get(tIds)
    } Catch ex {
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Save one <code>"probe"</code> demo inventory row through the guarded path.</p>
Method SeedRow(pKind As %String, pName As %String, pScope As %String) As %Status
{
    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = "probe"
    Set tRow.Kind = pKind
    Set tRow.Name = pName
    Set tRow.Scope = pScope
    Quit ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
}

/// <p>How many <code>"probe"</code> inventory rows name <var>pKind</var>/<var>pName</var>. A
/// failed read answers <code>-1</code>, never <code>0</code>, so "could not tell" is never
/// read as "the row is gone".</p>
Method RowCount(pKind As %String, pName As %String) As %Integer
{
    Set tCount = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = 'probe' AND Kind = ? AND Name = ?", pKind, pName)
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tCount = tRS.N
    } Catch ex {
        Set tCount = -1
    }
    Quit tCount
}

}
