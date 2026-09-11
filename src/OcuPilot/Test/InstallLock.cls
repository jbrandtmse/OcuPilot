/// <p><b>DW-47</b>: overlapping installs of one profile. <method>OcuPilot.Install.Installer.EnsureVersion</method>
/// reads the version row and then inserts or updates it, so two overlapping installs of one
/// profile could both read "no row" and both insert -- a real duplicate production row was
/// found and removed by hand in rework iteration 4. <method>OcuPilot.Install.Installer.Install</method>
/// and <method>OcuPilot.Install.Installer.MarkInstalling</method> now hold the profile's install
/// lock (<method>OcuPilot.Install.Installer.InstallLockName</method>) across that read and write,
/// and a caller still blocked after <parameter>OcuPilot.Install.Installer.INSTALLLOCKSECONDS</parameter>
/// refuses, naming the profile, and writes nothing.</p>
/// <p><b>DW-84</b>: an install and an uninstall of one profile overlapping. On 2026-09-11 a probe
/// <method>OcuPilot.Install.Installer.Uninstall</method> and a probe
/// <method>OcuPilot.Install.Installer.Install</method> in two processes interleaved their database
/// delete and create and left the probe database's directory mounted with no <code>IRIS.DAT</code>
/// on the live instance (DW-83). <method>OcuPilot.Install.Installer.Uninstall</method> now takes
/// the same lock, so it refuses the same way and removes nothing.</p>
/// <p><b>Held through the run, released on every exit</b> (step-04 review of rework iteration 8).
/// A refusal only shows that a caller <i>takes</i> the lock. So a second process also runs a real
/// install and a real uninstall through <class>OcuPilot.Test.LockPause</class>, paused part-way,
/// and the lock table must show it holding the lock there while this process's install and mark
/// refuse; and a second process whose install failed must have let the lock go.</p>
/// <p>The pins need a second process: a process that holds a lock takes it again at once, so
/// the suite's own process could never be refused by a lock it held itself.
/// <method>HoldInstallLock</method> is that process, started with <code>JOB</code>; it holds the
/// probe profile's install lock until this class releases a second, "go" lock it holds for as
/// long as it wants the first one held, and gives up on its own after a bounded wait either
/// way. Runs on the <code>"probe"</code> profile, which installs it; it installs and uninstalls
/// in this one process only, never alongside another process doing either. Its last method
/// (by name, the order <code>%UnitTest</code> runs them in) ends with the probe uninstalled.</p>
Class OcuPilot.Test.InstallLock Extends %UnitTest.TestCase
{

/// <p>The lock this class holds for as long as it wants <method>HoldInstallLock</method>'s
/// process to keep the install lock.</p>
Parameter GOLOCK As %String = "OcuPilotTestInstallLockGo";

/// <p>How long <method>HoldInstallLock</method> waits for the go lock before letting go on its
/// own, so an interrupted test run cannot leave the install lock held for long.</p>
Parameter HOLDMAXSECONDS As %Integer = 120;

/// <p>The second process, started by <code>JOB</code>: take <var>pProfile</var>'s install lock,
/// then wait for the go lock the test holds; once it gets it, or once
/// <parameter>HOLDMAXSECONDS</parameter> run out, release both and end. Its locks end with the
/// process in any case.</p>
ClassMethod HoldInstallLock(pProfile As %String)
{
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(pProfile)
    Set tGo = ..#GOLOCK
    Lock +@tName:10
    If '$Test Quit
    Lock +@tGo:..#HOLDMAXSECONDS
    If $Test Lock -@tGo
    Lock -@tName
}

/// <p>How the lock table records the probe profile's install lock: <code>^["^^&lt;manager
/// directory&gt;"]OcuPilotInstallLock("probe")</code>, the <code>IRISSYS</code> database's
/// directory, whichever namespace took it (<method>OcuPilot.Install.Installer.InstallLockName</method>).</p>
ClassMethod ExpectedProbeLockReference() As %String
{
    Quit "^[""^^" _ $System.Util.ManagerDirectory() _ """]OcuPilotInstallLock(""probe"")"
}

/// <p>The full references of every lock process <var>pPid</var> holds, as the lock table
/// (<code>%SYS.LockQuery</code>) records them, joined with <code>;</code>. A query that fails
/// (it needs <code>%Admin_Operate:U</code>) raises its error rather than reading as "holds
/// nothing", which a caller would report as a lock that was not held.</p>
ClassMethod LocksHeldBy(pPid As %String) As %String
{
    Set tHeld = ""
    Set tRS = ##class(%ResultSet).%New("%SYS.LockQuery:List")
    Set tSC = tRS.Execute("P" _ pPid)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    While tRS.Next() {
        Set tHeld = tHeld _ tRS.Get("FullReference") _ ";"
    }
    Do tRS.Close()
    Quit tHeld
}

/// <p>Whether process <var>pPid</var> holds the lock the table records as
/// <var>pReference</var>, polling for up to <var>pSeconds</var>.</p>
Method WaitUntilHeldBy(pPid As %String, pReference As %String, pSeconds As %Integer) As %Boolean
{
    Set tHeld = 0
    Set tDeadline = $ZHorolog + pSeconds
    While 'tHeld && ($ZHorolog < tDeadline) {
        Set tHeld = (";" _ ..LocksHeldBy(pPid)) [ (";" _ pReference _ ";")
        If 'tHeld Hang 0.2
    }
    Quit tHeld
}

/// <p>What a second process started by this class last recorded in
/// <code>^IRIS.Temp.OcuPilotLockPause(&lt;its job&gt;)</code>, once that begins with
/// <var>pPrefix</var>, polling for up to <var>pSeconds</var>; <code>""</code> if it never did.
/// <code>IRIS.Temp</code> is mapped from every namespace, so both processes see the same node.</p>
Method WaitForSignal(pPid As %String, pPrefix As %String, pSeconds As %Integer) As %String
{
    Set tDeadline = $ZHorolog + pSeconds
    Set tState = $Get(^IRIS.Temp.OcuPilotLockPause(pPid))
    While ($Extract(tState, 1, $Length(pPrefix)) '= pPrefix) && ($ZHorolog < tDeadline) {
        Hang 0.2
        Set tState = $Get(^IRIS.Temp.OcuPilotLockPause(pPid))
    }
    Quit $Select($Extract(tState, 1, $Length(pPrefix)) = pPrefix: tState, 1: "")
}

/// <p>A second process, started by <code>JOB</code>: install <var>pProfile</var> through
/// <class>OcuPilot.Test.LockPause</class>, which pauses after the ensure steps and before the
/// install stamp and the version row until the go lock frees, then record how the install
/// ended.</p>
ClassMethod PausedInstall(pProfile As %String)
{
    Do ##class(OcuPilot.Test.LockPause).SetPauseAt("install")
    Set tSC = ##class(OcuPilot.Test.LockPause).Install(pProfile)
    Set ^IRIS.Temp.OcuPilotLockPause($Job) = "done:" _ $System.Status.IsOK(tSC)
}

/// <p>A second process, started by <code>JOB</code>: uninstall <var>pProfile</var> through
/// <class>OcuPilot.Test.LockPause</class>, which pauses after the inventory read and before
/// anything is removed until the go lock frees, then record how the uninstall ended.</p>
ClassMethod PausedUninstall(pProfile As %String)
{
    Do ##class(OcuPilot.Test.LockPause).SetPauseAt("uninstall")
    Set tSC = ##class(OcuPilot.Test.LockPause).Uninstall(pProfile, 1)
    Set ^IRIS.Temp.OcuPilotLockPause($Job) = "done:" _ $System.Status.IsOK(tSC)
}

/// <p>A second process, started by <code>JOB</code>: run an install of <var>pProfile</var> that
/// fails (<class>OcuPilot.Test.MigrateFault</class>, armed in this process only), record how it
/// ended, and stay alive until the go lock frees -- so a lock that failed install left behind
/// would still be held while the test looks.</p>
ClassMethod FailedInstallThenWait(pProfile As %String)
{
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(1)
    Set tSC = ##class(OcuPilot.Test.MigrateFault).Install(pProfile)
    Do ##class(OcuPilot.Test.MigrateFault).SetShouldFail(0)
    Set ^IRIS.Temp.OcuPilotLockPause($Job) = "done:" _ $System.Status.IsOK(tSC)
    Set tGo = ..#GOLOCK
    Lock +@tGo:..#HOLDMAXSECONDS
    If $Test Lock -@tGo
}

/// <p>The probe profile's version row and its install-stamp count, as one string. A successful
/// install adds a stamp row, and a mark or a failed install changes the row's phase, so each of
/// the writes these tests guard against changes it. The row's timestamp has one-second
/// resolution: a rewrite in the same second that changed nothing else would not show. A failed
/// query is an assertion failure, never an empty snapshot that compares equal to another.</p>
Method ProbeWriteSnapshot() As %String
{
    Set tSnap = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Phase, SchemaVersion, FailingStep, UpdatedAt FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the probe version row query succeeds (SQLCODE " _ tRS.%SQLCODE _ ")")
    While tRS.%Next() {
        Set tSnap = tSnap _ tRS.ID _ "|" _ tRS.Phase _ "|" _ tRS.SchemaVersion _ "|" _ tRS.FailingStep _ "|" _ tRS.UpdatedAt _ ";"
    }
    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS2.%SQLCODE >= 0, "the probe stamp count query succeeds (SQLCODE " _ tRS2.%SQLCODE _ ")")
    If tRS2.%Next() Set tSnap = tSnap _ "stamps=" _ tRS2.N
    Quit tSnap
}

/// <p>Which of the probe profile's installer objects exist, as one string, each
/// <code>name=0|1</code>: its database's configuration entry and <code>IRIS.DAT</code>, its global
/// mapping, privileged routine application, administrative role and resource, its database's
/// guarding resource, and its audit event -- every object
/// <method>OcuPilot.Install.Installer.Uninstall</method> removes. The names are the probe's own,
/// as <class>OcuPilot.Test.Installer</class> spells them. Reads in <code>%SYS</code>, where those
/// classes live; the install namespace is resolved before the switch, since no
/// <code>##class(OcuPilot.*)</code> call can be made from <code>%SYS</code>.</p>
Method ProbeObjectsPresent() As %String
{
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tDir = ##class(%File).NormalizeDirectory("ocupilotprobe", $System.Util.ManagerDirectory())
    Set tOrigNS = $NAMESPACE
    Set tState = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tState = "database=" _ ''##class(Config.Databases).Exists("OCUPILOTPROBE", .tE1, .tS1)
        Set tState = tState _ ";iris.dat=" _ ''##class(%File).Exists(tDir _ "IRIS.DAT")
        Set tState = tState _ ";mapping=" _ ''##class(Config.MapGlobals).Exists(tInstallNs, "ProbeOcuPilotState*", .tE2, .tS2)
        Set tState = tState _ ";application=" _ ''##class(Security.Applications).Exists("OcuPilotStateProbe", .tE3, .tS3)
        Set tState = tState _ ";role=" _ ''##class(Security.Roles).Exists("OcuPilotAdminProbe", .tE4, .tS4)
        Set tState = tState _ ";adminresource=" _ ''##class(Security.Resources).Exists("OcuPilotAdminProbe", .tE5, .tS5)
        Set tState = tState _ ";dbresource=" _ ''##class(Security.Resources).Exists("%DB_OCUPILOTPROBE", .tE6, .tS6)
        Set tState = tState _ ";event=" _ ''##class(Security.Events).Exists("OcuPilot", "Security", "RoleGrantedProbe", .tE7, .tS7)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tState
}

/// <p>A failed install lets the lock go: a second process runs a probe install that fails and
/// then stays alive, and this process takes the probe profile's install lock at once. An
/// <method>OcuPilot.Install.Installer.Install</method> that kept the lock after a failure would
/// stall every later install, mark and uninstall of the profile for as long as the failing
/// process lived -- an operator's terminal, or the process an MCP call runs in.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.Install</method> releases the lock
/// only when it succeeds -- the failed install's process still holds it, red.</p>
Method TestFailedInstallReleasesTheLock()
{
    Set tProfile = "probe"
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(tProfile)
    Set tRef = ..ExpectedProbeLockReference()
    Set tGo = ..#GOLOCK
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a clean probe install for the second process to fail over")
    Do $$$AssertTrue('((";" _ ..LocksHeldBy($Job)) [ (";" _ tRef _ ";")), "this process holds no probe install lock of its own before it looks")

    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Set tChild = ""
    Try {
        Job ##class(OcuPilot.Test.InstallLock).FailedInstallThenWait(tProfile)::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Set tState = ..WaitForSignal(tChild, "done:", 60)
        Do $$$AssertEquals(tState, "done:0", "the second process's install failed, and that process is still alive")
        Lock +@tName:2
        Set tFree = $Test
        If tFree Lock -@tName
        Do $$$AssertTrue(tFree, "the failed install let the profile's install lock go: this process takes it at once (the other process holds " _ ..LocksHeldBy(tChild) _ ")")
    } Catch ex {
        Lock -@tGo
        If tChild '= "" Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
        Throw ex
    }
    Lock -@tGo
    If tChild '= "" Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a real install puts the probe back")
}

/// <p>DW-84, the other direction, with a real uninstall: a second process runs a probe
/// uninstall that pauses after its inventory read and before it removes anything
/// (<class>OcuPilot.Test.LockPause</class>). While it is paused, the lock table shows it holding
/// the probe profile's install lock, and an install and a mark of the profile each wait the
/// bounded time and refuse, changing nothing. Released, the uninstall completes.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.Uninstall</method> lets the lock go
/// right after taking it -- the paused uninstall no longer holds it, red.</p>
Method TestInstallAndMarkRefuseWhileAnUninstallRuns()
{
    Set tProfile = "probe"
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(tProfile)
    Set tGo = ..#GOLOCK
    Set tWait = ##class(OcuPilot.Install.Installer).#INSTALLLOCKSECONDS
    Set tAll = "database=1;iris.dat=1;mapping=1;application=1;role=1;adminresource=1;dbresource=1;event=1"
    Set tNone = "database=0;iris.dat=0;mapping=0;application=0;role=0;adminresource=0;dbresource=0;event=0"
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a clean probe install for the second process to uninstall")
    Do $$$AssertEquals(..ProbeObjectsPresent(), tAll, "every probe installer object exists before the uninstall starts")

    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Set tChild = ""
    Try {
        Job ##class(OcuPilot.Test.InstallLock).PausedUninstall(tProfile)::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Do $$$AssertEquals(..WaitForSignal(tChild, "paused", 60), "paused", "the second process's uninstall paused before it removed anything")
        Set tHeld = ..WaitUntilHeldBy(tChild, ..ExpectedProbeLockReference(), 5)
        Do $$$AssertTrue(tHeld, "paused part-way through, the uninstall holds the probe profile's install lock")
        ; Only while it holds the lock: without it, this install would run alongside the
        ; uninstall -- the overlap behind DW-83.
        If 'tHeld Quit

        Set tStart = $ZHorolog
        Set tSC = ##class(OcuPilot.Install.Installer).Install(tProfile)
        Set tWaited = $ZHorolog - tStart
        Do $$$AssertStatusNotOK(tSC, "an install of the profile refuses while its uninstall runs")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue((tText [ "Install refused") && (tText [ "'probe'"), "the install's refusal names itself and the profile: " _ tText)
        Do $$$AssertTrue(tWaited >= (tWait - 1), "after the bounded wait (" _ $FNumber(tWaited, "", 1) _ "s of " _ tWait _ "s)")
        Set tMarkSC = ##class(OcuPilot.Install.Installer).MarkInstalling(tProfile, .tOutcome)
        Do $$$AssertStatusNotOK(tMarkSC, "a mark of the profile refuses while its uninstall runs")
        Do $$$AssertTrue($System.Status.GetErrorText(tMarkSC) [ "MarkInstalling refused", "the mark's refusal names itself")
        Do $$$AssertEquals(..ProbeObjectsPresent(), tAll, "the paused uninstall has removed nothing, and the refused install and mark changed nothing")
    } Catch ex {
        Lock -@tGo
        If tChild '= "" Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
        Throw ex
    }
    Lock -@tGo
    If tChild '= "" {
        Do $$$AssertEquals(..WaitForSignal(tChild, "done:", 60), "done:1", "released, the uninstall completes")
        Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
    }
    Do $$$AssertEquals(..ProbeObjectsPresent(), tNone, "and has removed every installer object of the profile")
    Lock +@tName:5
    Set tFreed = $Test
    If tFreed Lock -@tName
    Do $$$AssertTrue(tFreed, "and has let the install lock go")
}

/// <p>The install lock is one lock per profile, and one lock for the whole instance: taken
/// from the install namespace and taken from <code>%SYS</code>, the lock table records it
/// against the same place, the <code>IRISSYS</code> database's directory -- never the protected
/// database's, whose <code>OcuPilot*</code> mapping a first install creates and an uninstall
/// deletes.</p>
/// <p>Mutations (Rule 19): make the name a plain global under the protected prefix
/// (<code>^OcuPilotInstallLock(...)</code>) -- from the install namespace the table records it
/// against the <code>OCUPILOT</code> database's directory, red; make it a plain local lock name
/// (no caret) -- the table records it as a local lock, red (and
/// <method>OcuPilot.Test.State.TestDeniedUserCannotHoldTheInstallLock</method> goes red too,
/// since an unprivileged account can take that one).</p>
Method TestInstallLockIsOneLockOutsideTheMappings()
{
    Set tProd = ##class(OcuPilot.Install.Installer).InstallLockName("")
    Set tProbe = ##class(OcuPilot.Install.Installer).InstallLockName("probe")
    Do $$$AssertNotEquals(tProd, tProbe, "each profile has its own install lock")
    Set tWant = ..ExpectedProbeLockReference()

    Lock +@tProbe:5
    Set tTook = $Test
    Set tFromInstallNs = $Select(tTook: ..LocksHeldBy($Job), 1: "")
    If tTook Lock -@tProbe
    Do $$$AssertTrue(tTook, "took the probe profile's install lock from the install namespace")
    ; Contained, not equal: the process running this test can hold locks of its own.
    Do $$$AssertTrue((";" _ tFromInstallNs) [ (";" _ tWant _ ";"), "taken from the install namespace, the lock table records it against the IRISSYS directory: " _ tFromInstallNs)

    Set tOrigNS = $NAMESPACE
    Set tFromSys = ""
    Set tTookSys = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Lock +@tProbe:5
        Set tTookSys = $Test
        Set tFromSys = $Select(tTookSys: ..LocksHeldBy($Job), 1: "")
        If tTookSys Lock -@tProbe
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Do $$$AssertTrue(tTookSys, "took the same lock from %SYS")
    Do $$$AssertTrue((";" _ tFromSys) [ (";" _ tWant _ ";"), "taken from %SYS, it is the same lock: " _ tFromSys)
}

/// <p>DW-47, held through the run: a second process runs a real probe install that pauses
/// after its ensure steps and before its install stamp and version row
/// (<class>OcuPilot.Test.LockPause</class>). While it is paused, the lock table shows it holding
/// the probe profile's install lock, and an install of the profile in this process waits the
/// bounded time and refuses -- two installs of one profile never run at once. Released, the
/// paused install completes and lets the lock go.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.Install</method> lets the lock go
/// right after taking it -- the paused install no longer holds it, red.</p>
Method TestLockIsHeldUntilTheInstallFinishes()
{
    Set tProfile = "probe"
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(tProfile)
    Set tGo = ..#GOLOCK
    Set tWait = ##class(OcuPilot.Install.Installer).#INSTALLLOCKSECONDS
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a clean probe install for the second process to repeat")

    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Set tChild = ""
    Try {
        Job ##class(OcuPilot.Test.InstallLock).PausedInstall(tProfile)::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Do $$$AssertEquals(..WaitForSignal(tChild, "paused", 60), "paused", "the second process's install paused after its ensure steps, before its version row")
        Set tHeld = ..WaitUntilHeldBy(tChild, ..ExpectedProbeLockReference(), 5)
        Do $$$AssertTrue(tHeld, "paused part-way through, the install holds the probe profile's install lock")
        ; Only while it holds the lock: without it, this install would run alongside the other.
        If 'tHeld Quit

        Set tStart = $ZHorolog
        Set tSC = ##class(OcuPilot.Install.Installer).Install(tProfile)
        Set tWaited = $ZHorolog - tStart
        Do $$$AssertStatusNotOK(tSC, "an install of the profile refuses while another install of it runs")
        Do $$$AssertTrue(tWaited >= (tWait - 1), "after the bounded wait (" _ $FNumber(tWaited, "", 1) _ "s of " _ tWait _ "s)")
    } Catch ex {
        Lock -@tGo
        If tChild '= "" Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
        Throw ex
    }
    Lock -@tGo
    If tChild '= "" {
        Do $$$AssertEquals(..WaitForSignal(tChild, "done:", 60), "done:1", "released, the paused install completes")
        Kill ^IRIS.Temp.OcuPilotLockPause(tChild)
    }
    Lock +@tName:5
    Set tFreed = $Test
    If tFreed Lock -@tName
    Do $$$AssertTrue(tFreed, "and has let the install lock go")
}

/// <p>While a second process holds the probe profile's install lock, an install of that
/// profile waits the bounded time and refuses, naming the profile, and a mark of it does the
/// same; neither writes anything. Once the lock is free, the same install runs.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Install.Installer.Install</method> stops taking the
/// lock -- the install runs over the held lock and adds a stamp row, red; so does
/// <method>OcuPilot.Install.Installer.MarkInstalling</method>, which then marks the row, red.</p>
Method TestSecondInstallAndMarkRefuseWhileTheLockIsHeld()
{
    Set tProfile = "probe"
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(tProfile)
    Set tGo = ..#GOLOCK
    Set tWait = ##class(OcuPilot.Install.Installer).#INSTALLLOCKSECONDS
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a clean probe install leaves an installed row to watch")
    Set tBefore = ..ProbeWriteSnapshot()

    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Try {
        Job ##class(OcuPilot.Test.InstallLock).HoldInstallLock(tProfile)::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Set tHeld = ..WaitUntilHeldBy(tChild, ..ExpectedProbeLockReference(), 15)
        Do $$$AssertTrue(tHeld, "the second process holds the probe profile's install lock")
        If 'tHeld Quit

        Set tStart = $ZHorolog
        Set tSC = ##class(OcuPilot.Install.Installer).Install(tProfile)
        Set tWaited = $ZHorolog - tStart
        Do $$$AssertStatusNotOK(tSC, "a second install of the profile refuses while another process holds its lock")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue((tText [ "'probe'") && (tText [ "install lock"), "the refusal names the profile and the lock: " _ tText)
        Do $$$AssertTrue(tWaited >= (tWait - 1), "it waited the bounded time before refusing (" _ $FNumber(tWaited, "", 1) _ "s of " _ tWait _ "s)")
        Do $$$AssertEquals(..ProbeWriteSnapshot(), tBefore, "the refused install wrote nothing: no version-row write and no install stamp")

        Set tMarkSC = ##class(OcuPilot.Install.Installer).MarkInstalling(tProfile, .tOutcome)
        Do $$$AssertStatusNotOK(tMarkSC, "a mark of the profile refuses while another process holds its lock")
        Do $$$AssertTrue($System.Status.GetErrorText(tMarkSC) [ "'probe'", "the mark's refusal names the profile")
        Do $$$AssertEquals(..ProbeWriteSnapshot(), tBefore, "the refused mark wrote nothing")
    } Catch ex {
        Lock -@tGo
        Throw ex
    }
    Lock -@tGo

    ; The second process gets the go lock, lets both go and ends.
    Lock +@tName:15
    Set tFreed = $Test
    If tFreed Lock -@tName
    Do $$$AssertTrue(tFreed, "the second process let the install lock go")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "with the lock free, the same install runs")
}

/// <p>DW-84: while a second process holds the probe profile's install lock, an uninstall of that
/// profile waits the bounded time and refuses, naming the profile, and removes nothing: every
/// installer object of the profile, its version row and its install stamps are as they were.
/// Once the lock is free, the same uninstall runs and removes them -- so the refusal came from the
/// lock and nothing else. The other direction, an install and a mark refused by a running
/// uninstall, is <method>TestInstallAndMarkRefuseWhileAnUninstallRuns</method>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.Uninstall</method> stops taking the
/// lock -- the uninstall runs over the held lock, returns OK and removes the probe's database,
/// mapping, application, role, resources and audit event, and purges its version row and stamps,
/// red.</p>
Method TestUninstallRefusesWhileTheLockIsHeld()
{
    Set tProfile = "probe"
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName(tProfile)
    Set tGo = ..#GOLOCK
    Set tWait = ##class(OcuPilot.Install.Installer).#INSTALLLOCKSECONDS
    Set tAll = "database=1;iris.dat=1;mapping=1;application=1;role=1;adminresource=1;dbresource=1;event=1"
    Set tNone = "database=0;iris.dat=0;mapping=0;application=0;role=0;adminresource=0;dbresource=0;event=0"
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(tProfile), "a clean probe install leaves every probe object in place to watch")
    Set tObjects = ..ProbeObjectsPresent()
    Do $$$AssertEquals(tObjects, tAll, "every probe installer object exists before the uninstall is tried")
    Set tFingerprint = ##class(OcuPilot.Install.Installer).StateFingerprint(tProfile)
    Set tBefore = ..ProbeWriteSnapshot()

    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Try {
        Job ##class(OcuPilot.Test.InstallLock).HoldInstallLock(tProfile)::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Set tHeld = ..WaitUntilHeldBy(tChild, ..ExpectedProbeLockReference(), 15)
        Do $$$AssertTrue(tHeld, "the second process holds the probe profile's install lock")
        If 'tHeld Quit

        Set tStart = $ZHorolog
        Set tSC = ##class(OcuPilot.Install.Installer).Uninstall(tProfile, 1)
        Set tWaited = $ZHorolog - tStart
        Do $$$AssertStatusNotOK(tSC, "an uninstall of the profile refuses while another process holds its install lock")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue((tText [ "Uninstall refused") && (tText [ "'probe'") && (tText [ "install lock"), "the refusal names the uninstall, the profile and the lock: " _ tText)
        Do $$$AssertTrue(tWaited >= (tWait - 1), "it waited the bounded time before refusing (" _ $FNumber(tWaited, "", 1) _ "s of " _ tWait _ "s)")
        Do $$$AssertEquals(..ProbeObjectsPresent(), tObjects, "the refused uninstall removed no installer object of the profile")
        Do $$$AssertEquals(##class(OcuPilot.Install.Installer).StateFingerprint(tProfile), tFingerprint, "the profile's installed state is unchanged, property for property")
        Do $$$AssertEquals(..ProbeWriteSnapshot(), tBefore, "the refused uninstall purged no version row and no install stamp")
    } Catch ex {
        Lock -@tGo
        Throw ex
    }
    Lock -@tGo

    ; The second process gets the go lock, lets both go and ends.
    Lock +@tName:15
    Set tFreed = $Test
    If tFreed Lock -@tName
    Do $$$AssertTrue(tFreed, "the second process let the install lock go")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Uninstall(tProfile, 1), "with the lock free, the same uninstall runs")
    Do $$$AssertEquals(..ProbeObjectsPresent(), tNone, "and removes every installer object of the profile")
}

}
