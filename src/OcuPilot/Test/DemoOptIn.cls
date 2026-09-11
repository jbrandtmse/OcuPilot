/// <p>AC9's opt-in half (AD-25): the demo flag is honoured at
/// <method>OcuPilot.Install.Installer.StartPath</method>'s own call site in <b>both</b>
/// directions, and a non-production profile's fixture names can never collide with
/// production's.</p>
/// <p><b>Moved out of <class>OcuPilot.Test.Demo</class> and strengthened in rework
/// iteration 5 (DW-56).</b> The flag-absent pin used to observe the flag only through the
/// production inventory's row count across a real <code>StartPath(0)</code>. On an
/// instance that already carries the production fixtures -- this repository's own
/// configuration, <code>OCUPILOT_DEMO: "1"</code> -- a <code>StartPath</code> that ignored
/// the flag and ran the fixtures anyway finds every object already present, notes nothing
/// new, and leaves the count unchanged: that gate could not fail on the one instance it
/// ran against. The pins below read the call site itself through
/// <class>OcuPilot.Test.InstallerProbe</class>'s
/// <method>OcuPilot.Test.InstallerProbe.CreateDemoFixtures</method> override, which
/// records the call and never makes it, so neither direction touches a real production
/// fixture. The inventory count is kept as a second, weaker assertion.</p>
/// <p>Each flag test drives one real production <code>Install("")</code> (idempotent, the
/// same one every other suite in this tree already runs), and
/// <method>TestStartPathRefusesWhileTheLockIsHeld</method> drives one that is refused before it
/// installs anything; nothing here uninstalls, so no
/// <code>DeleteDatabase</code> cycle is added. None of these tests needs
/// <class>OcuPilot.Test.Demo</class>'s shared fixture or the Task Manager daemon.</p>
Class OcuPilot.Test.DemoOptIn Extends %UnitTest.TestCase
{

/// <p>AC9 -- with the flag absent (here: <method>StartPath</method> called with
/// <var>pDemo</var> = 0, which does the same work as IPM's <code>&lt;Invoke&gt;</code> of
/// <method>OcuPilot.Install.Installer.Install</method>), the fixture step is never reached and no
/// fixture object of any kind is created. Drives the real, unmodified
/// <method>OcuPilot.Install.Installer.StartPath</method> through
/// <class>OcuPilot.Test.InstallerProbe</class> (whose only relevant difference is that it
/// records the fixture call instead of making it), so the assertion is about the call site
/// rather than about what a production instance happens to hold already.</p>
Method TestNoFixtureExistsWithoutTheFlag()
{
    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS0.%Next(), "the count query returns a row")
    Set tBefore = tRS0.N

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).StartPath(0)
    Set tCalls = ##class(OcuPilot.Test.InstallerProbe).CapturedDemoFixtureCalls()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(tSC, "StartPath with the demo flag off completes install")
    Do $$$AssertEquals(tCalls, 0, "StartPath with the demo flag off never reaches the demo-fixture call site")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS1.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS1.N, tBefore, "and no new production-scoped inventory row appears")
}

/// <p>AC9's positive twin -- with the flag set, <method>StartPath</method> reaches the
/// demo-fixture call site exactly once. That it comes only after install itself succeeded
/// is <method>StartPath</method>'s own <code>If $$$ISERR(tSC) Quit tSC</code>. This test
/// does not pin the ordering (corrected, rework iteration 5 review). Without
/// this, a regression that disconnected the fixtures from <code>StartPath</code>
/// altogether would pass <method>TestNoFixtureExistsWithoutTheFlag</method> trivially:
/// "never reached with the flag off" is also true of "never reached at all".</p>
/// <p>It also pins that <method>StartPath</method> creates the fixtures while it holds the
/// production profile's install lock (step-04 review of rework iteration 8):
/// <method>OcuPilot.Install.Installer.Install</method> has released its own hold by then, so
/// without <method>StartPath</method>'s an uninstall in another process could remove the
/// protected database under the fixtures being created. Mutation (Rule 19):
/// <method>StartPath</method> stops taking the lock -- the fixture call site runs without it,
/// red.</p>
Method TestDemoFlagReachesTheFixtureCallSite()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).StartPath(1)
    Set tCalls = ##class(OcuPilot.Test.InstallerProbe).CapturedDemoFixtureCalls()
    Set tLockHeld = ##class(OcuPilot.Test.InstallerProbe).CapturedDemoFixtureLockHeld()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(tSC, "StartPath with the demo flag on completes install")
    Do $$$AssertEquals(tCalls, 1, "StartPath with the demo flag on reaches the demo-fixture call site exactly once")
    Do $$$AssertEquals(tLockHeld, 1, "StartPath holds the production profile's install lock while it creates the demo fixtures")
    Do $$$AssertTrue('##class(OcuPilot.Test.InstallerProbe).HoldsProductionInstallLock(), "and has released it once it returns")
}

/// <p>Regression pin (review finding, build-auto step-04 review pass, 2026-09-11; moved
/// here from <class>OcuPilot.Test.Demo</class> in rework iteration 5 so it no longer pays
/// that class's daemon-dependent shared setup): every one of the
/// <code>ResolvedPrefix</code>-based fixture tests --
/// <method>OcuPilot.Test.Demo.TestDemoSslConfigFixtureExists</method>,
/// <method>OcuPilot.Test.Demo.TestDemoX509CredentialFixtureExists</method>,
/// <method>OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError</method>, and
/// <class>OcuPilot.Test.Installer</class>'s <method>TestUninstallRemovesDemoFixtures</method>
/// -- compute their own expected name by calling
/// <method>OcuPilot.Install.Fixture.ResolvedPrefix</method> itself, then assert
/// against that computed value. None of them pins <method>ResolvedPrefix</method>'s
/// own output to an independent literal, so a regression reverting it to its pre-HIGH-fix
/// form (<code>Quit ..#DEMOPREFIX</code>, dropping the profile suffix entirely) would
/// leave all four green -- exactly the "test whose green depends on the defect it
/// guards against" shape Rule 19 exists to catch, on the single most significant fix
/// this story has made (stopping a probe-profile test run from destroying production's
/// own demo fixtures). This test is that independent pin.</p>
Method TestResolvedPrefixQualifiesNonProductionProfiles()
{
    Do $$$AssertEquals(##class(OcuPilot.Install.Fixture).ResolvedPrefix(""), "OcuPilotDemo", "the production profile's prefix carries no suffix")
    Do $$$AssertEquals(##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe"), "OcuPilotDemoProbe", "the probe profile's prefix is qualified so its fixture names can never collide with production's own")
    Do $$$AssertNotEquals(##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe"), ##class(OcuPilot.Install.Fixture).ResolvedPrefix(""), "the two profiles never resolve to the same prefix")
}

/// <p>While another process holds the production profile's install lock,
/// <method>OcuPilot.Install.Installer.StartPath</method> waits the bounded time and refuses,
/// naming itself and the profile. It never reaches its install or the demo-fixture call site,
/// and it keeps no lock of its own afterwards (code review round 4, which moved its lock into
/// its <code>Try</code>). Driven through <class>OcuPilot.Test.InstallerProbe</class>, so nothing
/// unexpires and no fixture is made; the second process is
/// <method>OcuPilot.Test.InstallLock.HoldInstallLock</method>, holding production's lock for
/// about ten seconds, which writes nothing and installs nothing.</p>
/// <p>Mutation (Rule 19): <method>StartPath</method> takes no lock of its own -- its install is
/// the call refused, so the error names <code>Install</code>, not <code>StartPath</code>, red.</p>
Method TestStartPathRefusesWhileTheLockIsHeld()
{
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName("")
    Set tGo = ##class(OcuPilot.Test.InstallLock).#GOLOCK
    Set tWait = ##class(OcuPilot.Install.Installer).#INSTALLLOCKSECONDS
    Set tRef = "^[""^^" _ $System.Util.ManagerDirectory() _ """]OcuPilotInstallLock(""production"")"
    Lock +@tGo:5
    If '$Test {
        Do $$$AssertTrue(0, "took the go lock the second process waits on")
        Quit
    }
    Try {
        Job ##class(OcuPilot.Test.InstallLock).HoldInstallLock("")::10
        Set tStarted = $Test
        Do $$$AssertTrue(tStarted, "started the second process")
        If 'tStarted Quit
        Set tChild = $ZChild
        Set tHeld = 0
        Set tDeadline = $ZHorolog + 15
        While 'tHeld && ($ZHorolog < tDeadline) {
            Set tHeld = (";" _ ##class(OcuPilot.Test.InstallLock).LocksHeldBy(tChild)) [ (";" _ tRef _ ";")
            If 'tHeld Hang 0.2
        }
        Do $$$AssertTrue(tHeld, "the second process holds the production profile's install lock")
        If 'tHeld Quit

        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Set tStart = $ZHorolog
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).StartPath(1)
        Set tWaited = $ZHorolog - tStart
        Set tUnexpire = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
        Set tCalls = ##class(OcuPilot.Test.InstallerProbe).CapturedDemoFixtureCalls()
        Set tStillHeld = ##class(OcuPilot.Test.InstallerProbe).HoldsProductionInstallLock()
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusNotOK(tSC, "StartPath refuses while another process holds the production profile's install lock")
        Set tText = $System.Status.GetErrorText(tSC)
        Do $$$AssertTrue((tText [ "StartPath refused") && (tText [ "(production)"), "the refusal names StartPath and the production profile: " _ tText)
        Do $$$AssertTrue(tWaited >= (tWait - 1), "after the bounded wait (" _ $FNumber(tWaited, "", 1) _ "s of " _ tWait _ "s)")
        Do $$$AssertEquals(tUnexpire, "", "it never reached its install")
        Do $$$AssertEquals(tCalls, 0, "nor the demo-fixture call site")
        Do $$$AssertTrue('tStillHeld, "and it keeps no production install lock of its own afterwards")
    } Catch ex {
        Lock -@tGo
        Throw ex
    }
    Lock -@tGo
    ; The second process gets the go lock, lets both go and ends.
    Lock +@tName:15
    Set tFreed = $Test
    If tFreed Lock -@tName
    Do $$$AssertTrue(tFreed, "the second process let the production install lock go")
}

}
