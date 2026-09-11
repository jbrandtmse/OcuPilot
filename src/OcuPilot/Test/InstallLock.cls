/// <p><b>DW-47</b>: overlapping installs of one profile. <method>OcuPilot.Install.Installer.EnsureVersion</method>
/// reads the version row and then inserts or updates it, so two overlapping installs of one
/// profile could both read "no row" and both insert -- a real duplicate production row was
/// found and removed by hand in rework iteration 4. <method>OcuPilot.Install.Installer.Install</method>
/// and <method>OcuPilot.Install.Installer.MarkInstalling</method> now hold the profile's install
/// lock (<method>OcuPilot.Install.Installer.InstallLockName</method>) across that read and write,
/// and a caller still blocked after <parameter>OcuPilot.Install.Installer.INSTALLLOCKSECONDS</parameter>
/// refuses, naming the profile, and writes nothing.</p>
/// <p>The pin needs a second process: a process that holds a lock takes it again at once, so
/// the suite's own process could never be refused by a lock it held itself.
/// <method>HoldInstallLock</method> is that process, started with <code>JOB</code>; it holds the
/// probe profile's install lock until this class releases a second, "go" lock it holds for as
/// long as it wants the first one held, and gives up on its own after a bounded wait either
/// way. Runs on the <code>"probe"</code> profile; nothing here uninstalls.</p>
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
/// (<code>%SYS.LockQuery</code>) records them, joined with <code>;</code>.</p>
ClassMethod LocksHeldBy(pPid As %String) As %String
{
    Set tHeld = ""
    Set tRS = ##class(%ResultSet).%New("%SYS.LockQuery:List")
    Do tRS.Execute("P" _ pPid)
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

/// <p>The probe profile's version row and its install-stamp count, as one string: any write an
/// install makes changes it (every successful install adds a stamp row, and every version-row
/// write changes the row's timestamp).</p>
Method ProbeWriteSnapshot() As %String
{
    Set tSnap = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Phase, SchemaVersion, FailingStep, UpdatedAt FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe' ORDER BY ID")
    While tRS.%Next() {
        Set tSnap = tSnap _ tRS.ID _ "|" _ tRS.Phase _ "|" _ tRS.SchemaVersion _ "|" _ tRS.FailingStep _ "|" _ tRS.UpdatedAt _ ";"
    }
    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'")
    If tRS2.%Next() Set tSnap = tSnap _ "stamps=" _ tRS2.N
    Quit tSnap
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

}
