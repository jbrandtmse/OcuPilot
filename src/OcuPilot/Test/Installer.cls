/// <p>Create / repair / idempotency / uninstall suite for
/// <class>OcuPilot.Install.Installer</class>, run against the disposable
/// <code>"probe"</code> profile except where an acceptance criterion names production
/// (the idempotency pair below, which calls <code>Install("")</code> twice -- safe by
/// definition, since a second install is a no-op). <method>OnAfterOneTest</method> calls
/// <code>Uninstall("probe", 1)</code> unconditionally; <method>OnBeforeOneTest</method>
/// installs the probe fresh before every test method so each one starts from a known,
/// correct state.</p>
/// <p><b>No test calls <code>Uninstall("")</code>, and no test writes
/// <code>AuditEnabled</code>.</b></p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.Installer Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the install this class
/// runs happens on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
/// <p><b>A doc comment does not keep a class that installs from installing.</b> Test classes are
/// selected by package, so pointing the runner at a container someone cares about would run
/// OcuPilot's production install on it. Failing here is the honest outcome: nothing is installed
/// and the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Installer runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>This process's UTC clock (<code>$ZTimeStamp</code>, in ODBC format to the millisecond, the
/// form <class>%SYS.Audit</class> records <property>UTCTimeStamp</property> in) read just before
/// <method>OnBeforeOneTest</method>'s probe install, which runs in this same process and so
/// stamps its audit row from the same host clock (corrected in code review round 4: this used to
/// call it the audit database's own clock), so
/// <method>TestGrantForRealAccountGrantsAndAudits</method> can count only the audit rows this
/// method's own install wrote (DW-85). The prefix must not begin with "Test"
/// (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedProbeInstallSince As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedProbeInstallSince = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; Every Install() call -- whatever the profile -- ends by recording a
    ; OcuPilot.Kernel.State.Stamp row, which always escalates through the
    ; *production* privileged routine application (OcuPilot.Kernel.State.Base names
    ; exactly one). On an instance where production has never been installed, even
    ; Install("probe") would fail at that last step -- so production is primed first,
    ; matching the real deployment order (Story 1.4 installs production before anything
    ; else ever runs).
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    ; DW-85: the probe install below grants the probe's administrative role and writes its
    ; audit marker; TestGrantForRealAccountGrantsAndAudits counts only rows from here on.
    Set ..PreparedProbeInstallSince = $ZDateTime($ZTimeStamp, 3, , 3)
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

Method OnAfterOneTest() As %Status
{
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

/// <p>AC1 -- fresh create: the database exists at
/// <code>&lt;ManagerDirectory&gt;ocupilotprobe/</code> with an <code>IRIS.DAT</code>,
/// its <code>SYS.Database.ResourceName</code> is the profile's <code>%DB_</code>
/// resource, and that resource exists with <code>PublicPermission = ""</code> and
/// <code>Type = 2</code>.</p>
Method TestCreatesGuardedDatabase()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")

        Set tDir = ##class(%File).NormalizeDirectory("ocupilotprobe", $System.Util.ManagerDirectory())
        Do $$$AssertTrue(##class(%File).Exists(tDir _ "IRIS.DAT"), "the probe database's IRIS.DAT exists")

        Set tDbObj = ##class(SYS.Database).%OpenId(tDir)
        Do $$$AssertTrue($IsObject(tDbObj), "SYS.Database can open the probe database directory")
        Do $$$AssertEquals(tDbObj.ResourceName, "%DB_OCUPILOTPROBE", "the database's ResourceName is the profile's %DB_ resource")

        Do $$$AssertTrue(##class(Security.Resources).Exists("%DB_OCUPILOTPROBE", .tResObj, .tResSC), "the %DB_ resource exists")
        Set tSC2 = ##class(Security.Resources).Get("%DB_OCUPILOTPROBE", .tResProps)
        Do $$$AssertStatusOK(tSC2, "read back the %DB_ resource")
        Do $$$AssertEquals($Get(tResProps("PublicPermission")), "", "the %DB_ resource is not public")
        Do $$$AssertEquals(+$Get(tResProps("Type")), 2, "the %DB_ resource is a database resource (Type=2)")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC2 -- the administrative resource and a role of the same name exist, the role's
/// Resources grants only the administrative resource with U, and the role does not
/// grant the %DB_ resource -- no ordinary role holds the guarding resource (AD-9).</p>
Method TestAdminRoleGrantsOnlyTheAdminResource()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")

        Do $$$AssertTrue(##class(Security.Resources).Exists("OcuPilotAdminProbe", .tResObj, .tResSC), "the administrative resource exists")
        Do $$$AssertTrue(##class(Security.Roles).Exists("OcuPilotAdminProbe", .tRoleObj, .tRoleSC), "a role of the same name exists")

        Set tSC2 = ##class(Security.Roles).Get("OcuPilotAdminProbe", .tProps)
        Do $$$AssertStatusOK(tSC2, "read back the administrative role")
        Do $$$AssertEquals($Get(tProps("Resources")), "OcuPilotAdminProbe:U", "the role grants only the administrative resource, with U")
        Do $$$AssertTrue(($Get(tProps("Resources")) [ "%DB_OCUPILOTPROBE") = 0, "the role does not grant the %DB_ resource")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC3 -- exactly one global mapping exists whose name is the profile's global
/// prefix followed by <code>*</code> and whose Database is the profile's database.</p>
Method TestGlobalMappingTargetsTheGuardedDatabase()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")

        Do $$$AssertTrue(##class(Config.MapGlobals).Exists(tInstallNs, "ProbeOcuPilotState*", .tMapObj, .tMapSC), "the probe's global mapping exists")
        Set tSC2 = ##class(Config.MapGlobals).Get(tInstallNs, "ProbeOcuPilotState*", .tProps)
        Do $$$AssertStatusOK(tSC2, "read back the global mapping")
        Do $$$AssertEquals($Get(tProps("Database")), "OCUPILOTPROBE", "the mapping targets the probe's own database")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC3 -- no package mapping and no routine mapping was created, so OcuPilot's code
/// remains in the install namespace's normal databases.</p>
Method TestNoPackageOrRoutineMappingIsCreated()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")

        Do $$$AssertTrue('##class(Config.MapPackages).Exists(tInstallNs, "OcuPilot", .tPkgObj, .tPkgSC), "no package mapping named OcuPilot exists")
        Do $$$AssertTrue('##class(Config.MapRoutines).Exists(tInstallNs, "OcuPilot*", .tRtnObj, .tRtnSC), "no routine mapping named OcuPilot* exists")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC7 (basic idempotency smoke) -- installing the probe twice returns OK both times
/// and leaves the net state unchanged.</p>
Method TestInstallIsIdempotent()
{
    Set tSC1 = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC1, "install (already primed by OnBeforeOneTest, re-run here) returns OK")
    Set tFp1 = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")

    Set tSC2 = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC2, "a further install returns OK")
    Set tFp2 = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")

    Do $$$AssertEquals(tFp2, tFp1, "installing twice leaves the net state unchanged")
}

/// <p>AC7's real pinning test -- unlike <method>TestInstallIsIdempotent</method> (a
/// fingerprint compared against itself stays equal however wrong the fingerprint is),
/// this installs, disables the privileged routine application, takes the fingerprint,
/// re-installs (repairing it), takes it again, and asserts the two differ.</p>
Method TestFingerprintChangesWhenAnObjectChanges()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tModProps("Enabled") = 0
        Set tSC2 = ##class(Security.Applications).Modify("OcuPilotStateProbe", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually disable the probe's privileged routine application")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Set tFpDisabled = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")

    Set tSC3 = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC3, "re-install repairs the drift")

    Set tFpRepaired = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertNotEquals(tFpRepaired, tFpDisabled, "the fingerprint after repair differs from the fingerprint taken while drifted")
}

/// <p>AC8 -- a second run repairs a drifted, disabled privileged routine application
/// and the repair is reported; existence alone never counts as installed. This is the
/// sibling's exact defect, reproduced and pinned.</p>
Method TestSecondRunRepairsDriftedApplication()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tModProps("Enabled") = 0
        Set tSC2 = ##class(Security.Applications).Modify("OcuPilotStateProbe", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually disable the probe's privileged routine application")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "re-install (via the probe subclass, so the repair report is captured) succeeds")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).Captured("lastWarn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC4 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC4, "switch to %SYS")
        Set tSC5 = ##class(Security.Applications).Get("OcuPilotStateProbe", .tProps)
        Do $$$AssertStatusOK(tSC5, "read back the application")
        Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the second run repaired the disabled application back to Enabled")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2

    Do $$$AssertTrue(tWarnings '= "", "the repair was reported through the logger, not silently applied")
}

/// <p>AD-17 -- the audit event's existing-object path also verifies and repairs drift
/// (a manually disabled event), not only creates when absent. Same shape as
/// <method>TestSecondRunRepairsDriftedApplication</method>.</p>
Method TestSecondRunRepairsDriftedAuditEvent()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tModProps("Enabled") = 0
        Set tSC2 = ##class(Security.Events).Modify("OcuPilot", "Security", "RoleGrantedProbe", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually disable the probe's audit event")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "re-install (via the probe subclass, so the repair report is captured) succeeds")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC4 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC4, "switch to %SYS")
        Set tSC5 = ##class(Security.Events).Get("OcuPilot", "Security", "RoleGrantedProbe", .tProps)
        Do $$$AssertStatusOK(tSC5, "read back the audit event")
        Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the second run repaired the disabled audit event back to Enabled")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2

    Do $$$AssertTrue(tWarnings [ "audit event", "the repair was reported through the logger, not silently applied")
}

/// <p>AC10 -- when the instance's auditing was already on before this run (the actual
/// state on this instance, and never flipped off by any test -- see this class's own
/// header), a further install reports "already enabled", not "enabled now", as a
/// distinct outcome. Checks <method>CapturedAll</method> rather than the "last" fields,
/// since <method>EnsureGrant</method>'s own "info" report runs after this one and would
/// otherwise overwrite it.</p>
Method TestSecondRunReportsAuditingAlreadyEnabled()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC, "install succeeds")
    Set tInfoAll = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("info")
    Set tWarnAll = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue(tInfoAll [ "already enabled", "the auditing step reports 'already enabled' at info level, matching this instance's actual, untouched state")
    Do $$$AssertTrue((tWarnAll [ "Enabled instance auditing") = 0, "the auditing step never reports 'enabled now' when it was already on")
}

/// <p>AC12 -- an ordinary <code>%Status</code> failure deep inside the
/// <code>%SYS</code>-switched window (not a thrown exception) still leaves
/// <code>$NAMESPACE</code> restored to the caller's namespace when <method>Install</method>
/// returns. This is the pinning test the spec's own Verification section names for AC12's
/// second mutation -- a fingerprint-style self-comparison cannot catch this class of bug,
/// since nothing before this test forced a real ensure-step failure mid-flight.</p>
Method TestNamespaceIsRestoredFirstOnTheErrorPath()
{
    Set tStart = $NAMESPACE
    Set tSC = ##class(OcuPilot.Test.InstallerFault).Install("probe")
    Do $$$AssertStatusNotOK(tSC, "an ordinary %Status failure deep inside the %SYS-switched window is propagated as an error")
    Do $$$AssertEquals($NAMESPACE, tStart, "the namespace is restored to the caller's namespace even though nothing threw an exception -- only an ordinary bad %Status was returned from the last ensure step")
}

/// <p>AC12 -- the other half of the error path: a genuine <b>thrown exception</b> inside
/// the <code>%SYS</code>-switched window reaches
/// <method>OcuPilot.Install.Installer.Install</method>'s <code>Catch</code> block, whose
/// first line restores <code>$NAMESPACE</code>. <method>TestNamespaceIsRestoredFirstOnTheErrorPath</method>
/// above cannot cover this: its induced failure is an ordinary bad <code>%Status</code>,
/// which the inline <code>If $$$ISERR</code> guards absorb with an argumentless
/// <code>Quit</code> that never enters the <code>Catch</code> at all -- confirmed live by
/// this story's QA pass, which reordered that <code>Catch</code> and watched the test stay
/// green. Every ensure step converts its own exceptions to a <code>%Status</code>, so
/// nothing else in the suite reaches this block either; see
/// <class>OcuPilot.Test.InstallerThrow</class> for the falsifying mutation.</p>
Method TestNamespaceIsRestoredWhenTheSwitchedWindowThrows()
{
    Set tStart = $NAMESPACE
    Set tSC = ##class(OcuPilot.Test.InstallerThrow).Install("probe")
    Do $$$AssertStatusNotOK(tSC, "a thrown exception inside the %SYS-switched window is reported as an error status, not propagated to the caller")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "induced test exception", "the returned status carries the induced exception, so the Catch block really is the path that ran")
    Do $$$AssertEquals($NAMESPACE, tStart, "the namespace is restored to the caller's namespace on the exception path, as the first line of Install's Catch")
}

/// <p>AC9 -- an empty, UnknownUser or _PUBLIC candidate is never granted.</p>
/// <p>Called directly from the install namespace, <b>not</b> switched to
/// <code>%SYS</code> first: <method>EnsureGrant</method> is designed to be invoked
/// while already switched (its own <code>Security.Users.*</code> calls need it), which
/// works when <method>Install</method> reaches it through <code>..</code> self-dispatch
/// from inside its own already-switched frame, but a fresh
/// <code>##class(OcuPilot.Install.Installer)</code> dispatch -- exactly what calling it
/// from a test requires -- cannot itself be issued from <code>%SYS</code> (see
/// <method>TestSwitchAndRestoreNamespaceRoundTrip</method>'s note). Every username
/// here is one of the three placeholders, so <code>||</code>'s short-circuit means
/// <method>EnsureGrant</method> never actually reaches <code>Security.Users.Exists</code>
/// -- it is exercised correctly from here without a switch.</p>
Method TestPlaceholderUserIsNotGranted()
{
    Kill tNames, tReports
    Set tNames("adminRole") = "OcuPilotAdminProbe"

    Set tSC1 = ##class(OcuPilot.Install.Installer).EnsureGrant(.tNames, .tOutcome1, .tGranted1, .tCommand1, "", .tReports)
    Do $$$AssertStatusOK(tSC1, "EnsureGrant does not error on an empty username")
    Do $$$AssertEquals(tOutcome1, "skipped-placeholder", "an empty username is treated as a placeholder")
    Do $$$AssertEquals(tGranted1, "", "no username is recorded as granted")

    Set tSC2 = ##class(OcuPilot.Install.Installer).EnsureGrant(.tNames, .tOutcome2, .tGranted2, .tCommand2, "UnknownUser", .tReports)
    Do $$$AssertEquals(tOutcome2, "skipped-placeholder", "UnknownUser is treated as a placeholder, not granted")

    Set tSC3 = ##class(OcuPilot.Install.Installer).EnsureGrant(.tNames, .tOutcome3, .tGranted3, .tCommand3, "_PUBLIC", .tReports)
    Do $$$AssertEquals(tOutcome3, "skipped-placeholder", "_PUBLIC is treated as a placeholder, not granted")
}

/// <p>AC9 -- the exact grant command an operator must run is reported through
/// <var>pReports</var> (drained into the logger by <method>OcuPilot.Install.Installer.FlushReports</method>
/// on the real <code>Install</code> path), and never a silent skip.</p>
/// <p>Called directly, without switching to <code>%SYS</code> first -- see
/// <method>TestPlaceholderUserIsNotGranted</method>'s note.</p>
Method TestSkippedGrantReportsTheRequiredCommand()
{
    Kill tNames, tReports
    Set tNames("adminRole") = "OcuPilotAdminProbe"
    Set tSC2 = ##class(OcuPilot.Install.Installer).EnsureGrant(.tNames, .tOutcome, .tGranted, .tCommand, "_PUBLIC", .tReports)
    Do $$$AssertStatusOK(tSC2, "EnsureGrant does not error on the _PUBLIC placeholder")
    Do $$$AssertTrue(tCommand '= "", "the returned command hint is not empty")
    Do $$$AssertTrue((tCommand [ "AddRoles") && (tCommand [ "OcuPilotAdminProbe"), "the reported command names AddRoles and the role to grant")

    Set tN = $Order(tReports(""))
    Do $$$AssertTrue(tN '= "", "a report line was appended, not a silent skip")
    Do $$$AssertEquals(tReports(tN, "level"), "warn", "the skip is reported at warn level")
    Set tReportedData = tReports(tN, "data")
    Do $$$AssertTrue($IsObject(tReportedData), "the report carries a structured data object")
    Do $$$AssertTrue(tReportedData."command" [ "AddRoles", "the logged report itself carries the required command")
}

/// <p>AC9 (real-account half) and AC10 (round trip) -- the test connection's own
/// <code>$Username</code> is a real named account in this environment, so
/// <method>OnBeforeOneTest</method>'s <code>Install("probe")</code> already exercised
/// the "granted" branch; this reads the resulting stamp back and confirms that install
/// wrote its audit marker: exactly one <code>OcuPilot/Security/RoleGrantedProbe</code> row
/// since <property>PreparedProbeInstallSince</property>, written by this user and naming the
/// actor, the target and the role.</p>
/// <p><b>Why the audit read looks like this (DW-85).</b> This test used to count every
/// <code>RoleGrantedProbe</code> row the audit database had ever held, with
/// <code>WHERE EventSource = ? AND EventType = ? AND Event = ?</code>. It failed the first
/// class run on a fresh instance and passed the second, and on a long-lived instance earlier
/// runs' rows satisfied it whatever this run did, so there it could not fail. The cause is how
/// <class>%SYS.Audit</class> is indexed, not when a row becomes readable: the row is in the audit
/// data global (<code>^IRIS.AuditD</code>) as soon as <code>$System.Security.Audit</code>
/// returns, but the <code>Event</code>, <code>EventSource</code> and <code>EventType</code>
/// indexes are brought up to date by a background pass -- <method>%SYS.Audit.UpdateIndices</method>,
/// which its own documentation says the work-queue manager calls every 60 seconds in
/// <code>%SYS</code> -- and that query's plan reads the <code>Event</code> and
/// <code>EventSource</code> index maps. So a row younger than the last pass is invisible to it,
/// from any process. Here the three event predicates carry <code>%NOINDEX</code> and the rows are
/// bounded by <property>UTCTimeStamp</property>, the first subscript of the table's IDKEY, so the
/// plan reads the master map over that range and sees the row at once; and the count is scoped
/// to this method's own install, so an earlier run's rows cannot satisfy it. The count the
/// indexes serve at the same moment is logged, not asserted, as evidence of the lag.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.EnsureGrant</method> stops writing
/// the audit marker -- no row since this method's install, red, on a fresh instance and on a
/// long-lived one alike.</p>
Method TestGrantForRealAccountGrantsAndAudits()
{
    Set tUser = $Username
    Set tSince = ..PreparedProbeInstallSince
    Do $$$AssertTrue(tSince '= "", "OnBeforeOneTest recorded when its probe install began")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 GrantOutcome, GrantedUsername FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe' ORDER BY ID DESC")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "querying the stamp table succeeds")
    Do $$$AssertTrue(tRS.%Next(), "at least one probe stamp row exists")
    Do $$$AssertEquals(tRS.GrantOutcome, "granted", "the installing user, a real named account here, is granted -- not skipped")
    Do $$$AssertEquals(tRS.GrantedUsername, tUser, "the stamp records the granted username")

    Set tWantData = "actor=" _ tUser _ ";target=" _ tUser _ ";role=OcuPilotAdminProbe"
    Set tRows = 0
    Set tNamed = 0
    Set tIndexed = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT Username, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", tSince, "OcuPilot", "Security", "RoleGrantedProbe")
        Do $$$AssertTrue(tRS2.%SQLCODE >= 0, "querying the audit master map succeeds")
        While tRS2.%Next() {
            Set tRows = tRows + 1
            If (tRS2.Username = tUser) && (tRS2.EventData = tWantData) Set tNamed = tNamed + 1
        }
        ; Evidence, not an assertion: the same rows as the indexes serve them right now.
        Set tRS3 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND EventSource = ? AND EventType = ? AND Event = ?", tSince, "OcuPilot", "Security", "RoleGrantedProbe")
        If tRS3.%Next() Set tIndexed = tRS3.N
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tRows, 1, "this method's own probe install wrote exactly one granted-role audit marker since " _ tSince _ " UTC -- the round trip, not the registration alone")
    Do $$$AssertEquals(tNamed, 1, "the marker was written by " _ tUser _ " and names the actor, the target and the role (" _ tWantData _ ")")
    Do ..LogMessage("DW-85 evidence: since " _ tSince _ " UTC the audit master map holds " _ tRows _ " RoleGrantedProbe row(s); the Event/EventSource indexes serve " _ tIndexed _ " of them so far")
}

/// <p>AC7 (Story 3.8) -- <b>the grant marker records the grant, not the state</b> (DW-44). The run
/// that actually grants the administrative role writes exactly one
/// <code>OcuPilot/Security/RoleGrantedProbe</code> row and stamps <code>granted</code>; a second
/// install, finding the role already held, grants nothing, writes no second row and stamps
/// <code>alreadyheld</code>.</p>
/// <p>Without the already-held branch every container start wrote another row for a grant that did
/// not happen, and a reader counting them could not tell the run that granted the role from the
/// hundred that found it already there.</p>
/// <p>The audit read is <method>TestGrantForRealAccountGrantsAndAudits</method>'s, for the reason
/// its own comment gives (DW-85): the master map under <code>%NOINDEX</code>, bounded by
/// <code>UTCTimeStamp</code>.</p>
/// <p>Mutation (Rule 19): remove <method>OcuPilot.Install.Installer.EnsureGrant</method>'s
/// already-held branch -- the second install writes a second row and stamps <code>granted</code>,
/// and both assertions below go red.</p>
Method TestASecondInstallGrantsNothingAndWritesNoSecondMarker()
{
    Set tUser = $Username
    Set tFirst = ..PreparedProbeInstallSince
    Do $$$AssertTrue(tFirst '= "", "OnBeforeOneTest recorded when its probe install began")
    Do $$$AssertEquals(..GrantOutcomeOfLastProbeStamp(), "granted", "the install OnBeforeOneTest ran is the one that granted the role")
    Do $$$AssertEquals(..ProbeMarkersSince(tFirst), 1, "and it wrote exactly one grant marker")

    Set tSecond = $ZDateTime($ZTimeStamp, 3, , 3)
    Set tSC = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC, "a second install of the same profile succeeds")

    Do $$$AssertEquals(..GrantOutcomeOfLastProbeStamp(), "alreadyheld", "and records that the role was already held rather than granted again")
    Do $$$AssertEquals(..ProbeMarkersSince(tSecond), 0, "having written no second grant marker")
    Do $$$AssertEquals(..ProbeMarkersSince(tFirst), 1, "so the only marker in the audit database is still the one the granting run wrote")
}

/// <p>The <code>GrantOutcome</code> of the most recent probe-profile install stamp, or
/// <code>"unreadable"</code>.</p>
ClassMethod GrantOutcomeOfLastProbeStamp() As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 GrantOutcome FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe' ORDER BY ID DESC")
    If tRS.%SQLCODE < 0 Quit "unreadable"
    If 'tRS.%Next() Quit "unreadable"
    Quit tRS.%Get("GrantOutcome")
}

/// <p>How many <code>RoleGrantedProbe</code> rows the audit database's master map holds since
/// <var>pSince</var>, or <code>-1</code> when the read failed. <code>%NOINDEX</code> on the three
/// event predicates, bounded by <code>UTCTimeStamp</code> (DW-85).</p>
ClassMethod ProbeMarkersSince(pSince As %String) As %Integer
{
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, "OcuPilot", "Security", "RoleGrantedProbe")
        If (tRS.%SQLCODE >= 0) && tRS.%Next() Set tRows = tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>(QA) AC10 -- closes a Rule-19 falsifiability gap found while independently
/// verifying this story's own Verification section: the spec names
/// <code>TestAuditEventRoundTrips</code> as AC10's first mutation's pinning test, but no
/// method of that name exists anywhere in the tree, and the nearest existing test
/// (<method>TestGrantForRealAccountGrantsAndAudits</method>) cannot stand in for it --
/// production's audit event was registered by an earlier run and stays registered
/// regardless of what a later <code>Install()</code> does, so removing
/// <method>EnsureAuditEvents</method>'s <code>Security.Events.Create</code> call would
/// leave that test green (confirmed empirically: reverting the registration call left it
/// passing). This test instead deletes the probe's own registration first, so "not yet
/// registered" is a real, current fact rather than a frozen assumption, confirms the
/// round trip fails while it is absent, then re-installs (the real, unmutated
/// <method>EnsureAuditEvents</method>) and confirms the round trip is restored.</p>
Method TestAuditEventRegistrationRestoresTheRoundTrip()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")

        If ##class(Security.Events).Exists("OcuPilot", "Security", "RoleGrantedProbe", .tE, .tS) {
            Set tSC2 = ##class(Security.Events).Delete("OcuPilot", "Security", "RoleGrantedProbe")
            Do $$$AssertStatusOK(tSC2, "delete the probe's own audit event registration, so absence is a current fact")
        }

        Set tAuditSC1 = $System.Security.Audit("OcuPilot", "Security", "RoleGrantedProbe", "pre-registration probe", "should not produce a row")
        Do $$$AssertStatusNotOK(tAuditSC1, "an audit call against an unregistered triple fails")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Set tSC3 = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC3, "re-install (real, unmutated EnsureAuditEvents) re-registers the missing audit event")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC4 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC4, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Events).Exists("OcuPilot", "Security", "RoleGrantedProbe", .tE2, .tS2), "the audit event is registered again after re-install")

        ; %Status, not an indexed SQL row count. Story 1.3 saw a %SQL.Statement count issued
        ; right after $System.Security.Audit miss the just-written row, and read that as a
        ; same-process visibility artifact. Corrected in Story 1.4 (DW-85): the row is in the
        ; audit data global at once, but the Event/EventSource/EventType indexes that such a
        ; count reads are updated by a background pass about every 60 seconds
        ; (%SYS.Audit.UpdateIndices' own documentation), so a row younger than the last pass
        ; is invisible to an indexed query from any process until then.
        ; TestGrantForRealAccountGrantsAndAudits reads the master map instead. Here
        ; $System.Security.Audit's own returned %Status is the immediate signal, and is exactly
        ; what EnsureGrant itself branches on.
        Set tAuditSC2 = $System.Security.Audit("OcuPilot", "Security", "RoleGrantedProbe", "post-registration probe", "should produce a row")
        Do $$$AssertStatusOK(tAuditSC2, "an audit call against the now-registered triple succeeds -- the same call that failed above, now that Install() has re-registered it")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2
}

/// <p>AC11 -- when the profile's objects are present and pConfirmDataLoss=0, Uninstall
/// returns an error naming what would be destroyed and changes nothing.</p>
/// <p>It also pins that the refused uninstall lets the profile's install lock go (DW-84; code
/// review round 4): an operator's dry run in a long-lived process would otherwise stall every
/// install, mark and uninstall of the profile in any other process. Mutation (Rule 19):
/// <method>OcuPilot.Install.Installer.Uninstall</method> releases the lock only when it succeeds
/// -- this process still holds it, red.</p>
Method TestUninstallRefusesWithoutConfirmation()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 0)
    Set tHeldAfter = (";" _ ##class(OcuPilot.Test.InstallLock).LocksHeldBy($Job)) [ (";" _ ##class(OcuPilot.Test.InstallLock).ExpectedProbeLockReference() _ ";")
    Do $$$AssertStatusNotOK(tSC, "uninstall without confirmation returns an error")
    Do $$$AssertTrue('tHeldAfter, "the refused uninstall let the probe profile's install lock go")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "OCUPILOTPROBE", "the error names what would be destroyed")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue(##class(Config.Databases).Exists("OCUPILOTPROBE", .tE, .tS), "the probe database still exists after a refused uninstall -- nothing changed")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC11 -- uninstalling an already-absent profile returns OK, having changed
/// nothing, and never demands confirmation for work it does not need to do.</p>
Method TestUninstallAbsentIsNoop()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall of a present profile succeeds")

    Set tSC2 = ##class(OcuPilot.Install.Installer).Uninstall("probe", 0)
    Do $$$AssertStatusOK(tSC2, "uninstalling an already-absent profile returns OK without requiring confirmation")
}

/// <p>AC11 -- a confirmed uninstall removes the mapping, application, role, both
/// resources, config entry, IRIS.DAT and the directory, proved by a fresh listing and
/// by %File.DirectoryExists.</p>
Method TestUninstallLeavesNoResidue()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds")

    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    ; Resolved BEFORE the switch: a fresh ##class(OcuPilot.*) dispatch issued while $NAMESPACE is
    ; %SYS raises <CLASS DOES NOT EXIST>, because OcuPilot's code is mapped nowhere but the install
    ; namespace. Derived from the roster rather than spelled, so a triple added later is asserted
    ; gone by arriving there.
    Set tAuditSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tAuditType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tRoster = ##class(OcuPilot.Kernel.Audit.Event).Names("Probe")
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")

        Do $$$AssertTrue('##class(Config.MapGlobals).Exists(tInstallNs, "ProbeOcuPilotState*", .t1, .s1), "the mapping is gone")
        Do $$$AssertTrue('##class(Security.Applications).Exists("OcuPilotStateProbe", .t2, .s2), "the application is gone")
        Do $$$AssertTrue('##class(Security.Roles).Exists("OcuPilotAdminProbe", .t3, .s3), "the role is gone")
        Do $$$AssertTrue('##class(Security.Resources).Exists("OcuPilotAdminProbe", .t4, .s4), "the administrative resource is gone")
        Do $$$AssertTrue('##class(Security.Resources).Exists("%DB_OCUPILOTPROBE", .t5, .s5), "the database's guarding resource is gone")
        Do $$$AssertTrue('##class(Config.Databases).Exists("OCUPILOTPROBE", .t6, .s6), "the database config entry is gone")
        ; Every triple the roster declares, not only the baseline: before Story 3.8 the uninstall
        ; loop removed the grant marker alone, so two registrations survived every uninstall and
        ; this assertion -- which named that one triple -- passed anyway.
        Do $$$AssertTrue($ListLength(tRoster) > 1, "the probe roster carries more than the baseline triple, so this sweep asserts something: " _ $ListLength(tRoster))
        For tE = 1:1:$ListLength(tRoster) {
            Set tEvName = $List(tRoster, tE)
            Do $$$AssertTrue('##class(Security.Events).Exists(tAuditSource, tAuditType, tEvName, .t7, .s7), "the audit event " _ tEvName _ " is gone")
        }

        Set tDir = ##class(%File).NormalizeDirectory("ocupilotprobe", $System.Util.ManagerDirectory())
        Do $$$AssertTrue('##class(%File).DirectoryExists(tDir), "the database directory is gone")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AD-25 regression pin (review finding, HIGH -- Rule 19, "the gate that cannot
/// fail" applies just as much to a fix with no committed test at all): a confirmed
/// <code>Uninstall</code> removes an opt-in demo fixture object AND its
/// <class>OcuPilot.Kernel.State.Demo</class> inventory row for this profile, not only
/// the core objects <method>TestUninstallLeavesNoResidue</method> checks. Before this
/// story's own H1 fix, fixture removal ran AFTER the mapping/database were already
/// destroyed, silently orphaning every fixture on uninstall -- confirmed only by a
/// manual, one-off MCP session (this file's <code>## Auto Run Result</code>), never a
/// committed test. Hand-creates the SSL/TLS configuration fixture and its inventory
/// row directly, bypassing <method>OcuPilot.Install.Fixture.Create</method> entirely,
/// which also creates and runs the demo task and seeds an application-error entry. None
/// of that is needed for a test whose only subject is uninstall ordering. <b>Corrected
/// (rework iteration 5 review):</b> this used to cite Create's "real-Task-Manager-daemon
/// wait", which rework iteration 5 removed.</p>
Method TestUninstallRemovesDemoFixtures()
{
    ; Review finding (HIGH, round 2): this used to hardcode the PRODUCTION fixture's
    ; own name -- so on the configuration this story ships (OCUPILOT_DEMO="1"), this
    ; probe-profile test filed a "probe" inventory row naming production's real
    ; OcuPilotDemoTLS, then Uninstall("probe", 1) deleted it by that name, destroying
    ; the real production fixture while passing green. ResolvedPrefix("probe") is the
    ; production-safe, "probe"-suffixed name Fixture.CreateSslConfig itself now uses
    ; for this profile (see that method's own header) -- never the literal production
    ; string.
    Set tName = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ "TLS"
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        If '##class(Security.SSLConfigs).Exists(tName, .tE0, .tS0) {
            Set tProps("Description") = "OcuPilot demo fixture (test-created, AD-25 regression pin)"
            Set tCreateSC = ##class(Security.SSLConfigs).Create(tName, .tProps)
            Do $$$AssertStatusOK(tCreateSC, "hand-created the SSL/TLS configuration fixture")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = "probe"
    Set tRow.Kind = "sslconfig"
    Set tRow.Name = tName
    Set tRow.Scope = "instance"
    Set tRowSaveSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
    Do $$$AssertStatusOK(tRowSaveSC, "hand-created the fixture's inventory row")

    Set tUninstallSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tUninstallSC, "confirmed uninstall succeeds")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue('##class(Security.SSLConfigs).Exists(tName, .tE1, .tS1), "the demo fixture object is gone after uninstall -- H1's fixture-removal-before-destruction ordering, not the old orphaning behavior")
        Set $NAMESPACE = tOrigNS2
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS2
        Throw ex2
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'sslconfig' AND Name = ? AND Profile = 'probe'", tName)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS.N, 0, "the fixture's inventory row is gone after uninstall")
}

/// <p>Uninstall also purges every <class>OcuPilot.Kernel.State.Stamp</class> row
/// recorded for the profile, not only the named objects AC11 lists -- otherwise the
/// disposable <code>"probe"</code> profile's own bookkeeping would survive every
/// confirmed uninstall and grow without bound across repeated test runs, since Stamp's
/// storage lives in the same table for every profile. The profile's version row goes the
/// same way.</p>
/// <p>Mutation (Rule 19, rework iteration 8): skip both purges for every profile (Fix Pack
/// F-1 confines them to a non-production profile; this is the half that must still run) --
/// the stamp and version-row assertions go red.</p>
Method TestUninstallPurgesStampHistoryForTheProfile()
{
    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS0.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS0.N > 0, "at least one probe stamp exists before uninstall (OnBeforeOneTest just recorded one)")
    Set tRSV = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRSV.%Next(), "the version count query returns a row")
    Do $$$AssertEquals(tRSV.N, 1, "the probe profile carries its version row before uninstall (OnBeforeOneTest just recorded it)")

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS1.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS1.N, 0, "no probe-profile stamp rows survive a confirmed uninstall")

    ; The version row is purged the same way (Fix Pack F-1, rework iteration 8, confined both
    ; purges to a non-production profile; this is the half that must still run).
    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS2.%Next(), "the version count query returns a row")
    Do $$$AssertEquals(tRS2.N, 0, "no probe-profile version row survives a confirmed uninstall")
}

/// <p>AC12 -- direct test host for <class>OcuPilot.Kernel.Utils</class>'s
/// <method>SwitchNamespace</method> / <method>RestoreNamespace</method>; this story is
/// their first consumer and its header asked for exactly this.</p>
/// <p><b>Verified on the instance, and load-bearing for how this story's own installer
/// is written:</b> <code>##class(OcuPilot.Kernel.Utils).AnyMethod()</code> cannot be
/// dispatched once <code>$NAMESPACE</code> has moved away from the namespace
/// <class>OcuPilot.Kernel.Utils</class> itself lives in -- IRIS resolves a class
/// reference against the routine database mapped into the <b>current</b> namespace at
/// the moment of the call, every time, and OcuPilot's classes are deliberately mapped
/// nowhere but the install namespace (AD-9). So <method>SwitchNamespace</method> and
/// <method>RestoreNamespace</method> are each individually dispatched here from the
/// namespace they are compiled into, never chained back-to-back across the switch they
/// themselves perform -- which is also why
/// <method>OcuPilot.Install.Installer.Install</method> restores with a bare
/// <code>Set $NAMESPACE = ...</code> rather than a second call into
/// <class>OcuPilot.Kernel.Utils</class> after switching to <code>%SYS</code>.</p>
Method TestSwitchAndRestoreNamespaceRoundTrip()
{
    Set tStart = $NAMESPACE

    Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrig)
    Do $$$AssertStatusOK(tSC, "SwitchNamespace to %SYS succeeds")
    Do $$$AssertEquals($NAMESPACE, "%SYS", "the namespace is actually %SYS after the switch")
    Do $$$AssertEquals(tOrig, tStart, "the captured original namespace is the one in effect before the switch")

    ; Bare restore -- not under test here -- so the rest of this method (and
    ; RestoreNamespace itself, below) can keep calling OcuPilot classes.
    Set $NAMESPACE = tStart

    Set tSC2 = ##class(OcuPilot.Kernel.Utils).RestoreNamespace("%SYS")
    Do $$$AssertStatusOK(tSC2, "RestoreNamespace succeeds")
    Do $$$AssertEquals($NAMESPACE, "%SYS", "RestoreNamespace actually switches to the namespace it is given")

    Set $NAMESPACE = tStart
}

/// <p>AC12 -- an invalid profile is refused before any namespace switch happens, so the
/// namespace is never disturbed on that error path either.</p>
Method TestInvalidProfileLeavesNamespaceUntouched()
{
    Set tStart = $NAMESPACE
    Set tSC = ##class(OcuPilot.Install.Installer).Install("not-a-valid-profile")
    Do $$$AssertStatusNotOK(tSC, "an invalid profile is refused")
    Do $$$AssertEquals($NAMESPACE, tStart, "the namespace is unchanged after the refusal")

    ; A refused profile writes nothing (code review round 3). The long name above is too
    ; long for Version.Profile, so it could never show a stray row; a short one could, and
    ; did: Install named Names() as its failing step and recorded a "failed" version row for
    ; a profile that does not exist, which no Uninstall can ever remove. Mutation: name
    ; Names() as the failing step again, and the count below goes red.
    Set tBogus = "bogusprofile"
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Version WHERE %EXACT(Profile) = ?", tBogus)
    Set tSC2 = ##class(OcuPilot.Install.Installer).Install(tBogus)
    Do $$$AssertStatusNotOK(tSC2, "a short invalid profile is refused too")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Version WHERE %EXACT(Profile) = ?", tBogus)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS.N, 0, "no version row is recorded for a profile Install refused")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Version WHERE %EXACT(Profile) = ?", tBogus)
}

/// <p>Production idempotency pair (Design Notes: "only two of its methods touch
/// production"). Calling <code>Install("")</code> twice is safe by definition -- a
/// second install is a no-op -- and this is also what makes production's objects exist
/// for <class>OcuPilot.Test.State</class>'s AC4/AC5 tests, which necessarily run against
/// production (<class>OcuPilot.Kernel.State.Base</class> names exactly one application
/// and one guarding role). No test here calls <code>Uninstall("")</code>.</p>
/// <p><b>The pause between the two installs is what lets this pin fail</b> (Story 1.4,
/// rework iteration 5, DW-56). AC4's mutation for this test puts the version row's
/// <property>UpdatedAt</property> into <method>OcuPilot.Install.Installer.StateFingerprint</method>.
/// <property>UpdatedAt</property> has one-second resolution and a production install
/// takes a few milliseconds, so two back-to-back installs usually land in the same
/// second, stamp the same value, and leave that mutation green. Waiting past a second
/// boundary makes the two stamps differ on every run.</p>
Method TestProductionInstallIsIdempotent()
{
    Set tSC1 = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tSC1, "production install (first or repeat) returns OK")
    Set tFp1 = ##class(OcuPilot.Install.Installer).StateFingerprint("")

    Hang 1.1
    Set tSC2 = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tSC2, "a further production install returns OK")
    Set tFp2 = ##class(OcuPilot.Install.Installer).StateFingerprint("")

    Do $$$AssertEquals(tFp2, tFp1, "installing production twice leaves the net state unchanged")
}

/// <p><b>DW-12.</b> An instance carrying neither candidate namespace is refused, by name, and
/// nothing is created. Before this, <method>OcuPilot.Install.Installer.ResolveNamespace</method>
/// answered <code>USER</code> unconditionally when <code>HSCUSTOM</code> was absent -- it had no
/// failure branch at all -- so on such an instance every entry point either refused with a
/// message naming a namespace that does not exist, or tried to install into one.</p>
/// <p>Driven through <class>OcuPilot.Test.NamespaceProbe</class>, which arms which namespaces
/// exist rather than what the resolver answers: no namespace is created or removed to reach
/// this state, and the resolver's candidate order and empty answer stay the code under test.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Install.Installer.ResolveNamespace</method> answer <code>"USER"</code>
/// rather than <code>""</code> when neither candidate exists, or drop the empty-answer branch
/// from <method>OcuPilot.Install.Installer.GuardInstallNamespace</method> -- red either way.</p>
Method TestNeitherCandidateNamespaceIsRefusedByName()
{
    Set tHere = $NAMESPACE
    Set tBefore = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do ##class(OcuPilot.Test.NamespaceProbe).Arm("")
    Try {
        ; The resolver itself, not only the guards that read it: with neither candidate on the
        ; instance it must answer "", and a resolver that named a namespace nobody could find
        ; would still satisfy every refusal assertion below.
        Set tResolved = ##class(OcuPilot.Test.NamespaceProbe).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Test.NamespaceProbe).Install("probe")
        Set tStartSC = ##class(OcuPilot.Test.NamespaceProbe).StartPath(0)
        Set tMarkSC = ##class(OcuPilot.Test.NamespaceProbe).MarkInstalling("probe", .tOutcome)
    } Catch ex {
        Do ##class(OcuPilot.Test.NamespaceProbe).Reset()
        Throw ex
    }
    Do ##class(OcuPilot.Test.NamespaceProbe).Reset()

    Do $$$AssertEquals(tResolved, "", "ResolveNamespace answers nothing when neither candidate exists, rather than a name that is not there")

    ; All three entry points, because all three used to resolve the namespace themselves and a
    ; fix applied to one of them would leave the other two installing into nothing.
    For tName = "Install", "StartPath", "MarkInstalling" {
        Set tStatus = $Case(tName, "Install": tSC, "StartPath": tStartSC, : tMarkSC)
        Do $$$AssertStatusNotOK(tStatus, tName _ " refuses when neither candidate namespace exists")
        Set tText = $System.Status.GetErrorText(tStatus)
        Do $$$AssertTrue(tText [ "HSCUSTOM", tName _ "'s refusal names the first candidate: " _ tText)
        Do $$$AssertTrue(tText [ "USER", tName _ "'s refusal names the second candidate: " _ tText)
        Do $$$AssertTrue(tText [ "OCUPILOT_NAMESPACE", tName _ "'s refusal names the override: " _ tText)
    }

    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).StateFingerprint("probe"), tBefore, "and nothing was created, changed or removed")
    ; Compared with the namespace captured before the refusals, not with the resolver's answer:
    ; the latter is equal by coincidence wherever the suite happens to run in the default, and
    ; cannot observe a namespace the refusal path left switched.
    Do $$$AssertEquals($NAMESPACE, tHere, "the caller's namespace is untouched")
}

/// <p><b>DW-12, the other half.</b> The install target is the namespace the call was made
/// from, not <method>OcuPilot.Install.Installer.ResolveNamespace</method>'s default -- which is
/// what lets an IPM install land where <code>zpm install</code> was run. Demonstrated by arming
/// an instance on which only the <b>other</b> candidate exists, so the resolved default is
/// deliberately not the current namespace: under the old equality guard that call was refused
/// outright; now it installs, into the namespace it was called from.</p>
/// <p>Mutation (Rule 19): restore the equality test
/// (<code>If $NAMESPACE '= ..ResolveNamespace() Quit error</code>) in
/// <method>OcuPilot.Install.Installer.GuardInstallNamespace</method> -- red.</p>
Method TestTheInstallTargetIsTheNamespaceInstallWasCalledFrom()
{
    Set tHere = $NAMESPACE
    Set tOther = $Select(tHere = "USER": "HSCUSTOM", 1: "USER")
    Do $$$AssertNotEquals(tOther, tHere, "the armed default is a different namespace from this one")

    Do ##class(OcuPilot.Test.NamespaceProbe).Arm(tOther)
    Try {
        Set tResolved = ##class(OcuPilot.Test.NamespaceProbe).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Test.NamespaceProbe).Install("probe")
    } Catch ex {
        Do ##class(OcuPilot.Test.NamespaceProbe).Reset()
        Throw ex
    }
    Do ##class(OcuPilot.Test.NamespaceProbe).Reset()

    Do $$$AssertEquals(tResolved, tOther, "the armed instance really did resolve a default other than the current namespace")
    Do $$$AssertStatusOK(tSC, "install succeeds from a namespace that is not the resolved default")
    Do $$$AssertEquals($NAMESPACE, tHere, "and leaves the caller where it found it")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSwitchSC, "switch to %SYS")
        Set tGetSC = ##class(Security.Applications).Get("/probeocupilot", .tProps)
        Do $$$AssertStatusOK(tGetSC, "read back the probe shell application")
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS
        Throw ex2
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals($Get(tProps("NameSpace")), tHere, "the application it created runs in the namespace install was called from, not the armed default")
}

/// <p><b>DW-12, the refusal that remains.</b> A system namespace is never an install target,
/// whatever the caller is standing in. The closed list is
/// <parameter>OcuPilot.Install.Installer.SYSTEMNAMESPACES</parameter> plus every
/// <code>%</code>-prefixed name; everything else is an ordinary namespace OcuPilot may install
/// into.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Install.Installer.IsSystemNamespace</method> answer <code>0</code> for
/// <code>%SYS</code> -- red here, and red in
/// <method>OcuPilot.Test.Version.TestInstallRefusesFromWrongNs</method>.</p>
Method TestSystemNamespacesAreRefusedAsInstallTargets()
{
    For tRefused = "%SYS", "%ALL", "%sys", "HSLIB", "HSSYS", "ENSLIB", "IRISSYS", "irislib", "" {
        Do $$$AssertEquals(##class(OcuPilot.Install.Installer).IsSystemNamespace(tRefused), 1, "'" _ tRefused _ "' is never an install target")
    }
    For tAccepted = "HSCUSTOM", "USER", "MYAPP", "hscustom", "OCUPILOTDEMO" {
        Do $$$AssertEquals(##class(OcuPilot.Install.Installer).IsSystemNamespace(tAccepted), 0, "'" _ tAccepted _ "' is an ordinary namespace OcuPilot may install into")
    }
}

}
