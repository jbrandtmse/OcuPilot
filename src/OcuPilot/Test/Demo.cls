/// <p>AC9-AC12: fixture creation, the DW-13 collision guard, and inventory-scoped
/// removal. Drives <class>OcuPilot.Install.Fixture</class> directly under the disposable
/// <code>"probe"</code> profile -- installs nothing itself and calls neither
/// <code>Install</code> nor <code>Uninstall</code> (this story's own "Install/Uninstall
/// cycling hazard" note). AC9's opt-in half -- the flag honoured at
/// <method>OcuPilot.Install.Installer.StartPath</method>'s call site, and the probe
/// profile's names never colliding with production's -- moved to
/// <class>OcuPilot.Test.DemoOptIn</class> in rework iteration 5, so those pins no longer
/// pay this class's shared setup; the fault-injection tests for
/// <method>OcuPilot.Install.Fixture.RemoveOne</method> and
/// <method>OcuPilot.Install.Fixture.CreateTask</method> live in
/// <class>OcuPilot.Test.DemoFaults</class> for the same reason.</p>
/// <p><b>One shared setup for the whole class</b> (<method>OnBeforeAllTests</method>, not
/// <code>OnBeforeOneTest</code>): calls <method>OcuPilot.Install.Fixture.Create</method>
/// exactly once. That call does <b>not</b> wait for the Task Manager -- it asks for one run
/// of the demo task and returns (the owner's decision, rework iteration 5; see
/// <method>OcuPilot.Install.Fixture.CreateTask</method>'s header).
/// <method>TestDemoTaskIsSuspendedAfterAnError</method> owns the wait instead, up to
/// <parameter>SUSPENDWAITSECONDS</parameter>, re-reading the task freshly on every poll, and
/// it fails when the task has not suspended inside that budget: there is no skip branch.
/// <method>OnAfterAllTests</method> tears the shared state down once. Not every other method
/// only reads that state (corrected in code review round 3): the three web-application tests
/// create and delete their own objects at <class>OcuPilot.Test.DemoAppProbe</class>'s private
/// path, and <method>TestDeleteByProfileRemovesProductionNullRows</method> deletes and restores
/// the production profile's inventory rows.</p>
/// <p><b>Corrected at its origin (rework iteration 5).</b> This header used to explain a
/// 90-to-300-second widening of the fixture's own wait by "the daemon on this specific
/// long-lived container taking well past 90 seconds", and described a DW-46 skip that
/// passed the task test whenever the daemon had not yet started the run. Both rested on a
/// misreading. The task test's grace loop re-opened the task with <code>%OpenId</code>
/// while still holding the previous OREF, and <code>%Open</code> hands back the in-memory
/// object without reloading it, so the loop could never observe the daemon's write; and
/// the fixture's own OREF, held across <code>RunNow</code> and its wait, kept the daemon
/// from running the task until that wait ended. The test never once observed a suspended
/// task -- every "pass" before this rework was the skip.</p>
Class OcuPilot.Test.Demo Extends %UnitTest.TestCase
{

/// <p>The fixture's own report stream from <method>OnBeforeAllTests</method>'
/// <code>Fixture.Create("probe", ...)</code> call, kept as instance state (review
/// finding, MED, round 2) so <method>TestDemoTaskIsSuspendedAfterAnError</method> can
/// assert that this run's fixture actually asked the Task Manager to run the task, and on
/// a timeout can tell "nothing ever asked it to run" apart from "asked, but the daemon
/// never ran it" -- see <method>FixtureRequestedTaskRun</method>. Prefix deliberately not
/// "Test" -- see .claude/rules/objectscript-testing.md.</p>
Property PreparedFixtureReports [ MultiDimensional ];

/// <p>The exact identity (<code>"&lt;$H day&gt;,&lt;entry number&gt;"</code>) of the
/// application-error entry <method>OnBeforeAllTests</method>' own
/// <code>Fixture.Create</code> call seeded, so
/// <method>TestDemoSeedsAnApplicationError</method> asserts against the entry <b>this
/// run</b> produced rather than against "some entry from today".</p>
/// <p>Replaces the <code>$H</code> boundary this property used to hold (rework iteration
/// 5): that boundary existed only because the fixture harvested the demo task's daemon
/// failure and could not tell which entry was its own -- see
/// <method>OcuPilot.Install.Fixture.CreateErrorEntry</method>'s own header. Prefix
/// deliberately not "Test" -- see .claude/rules/objectscript-testing.md.</p>
Property PreparedErrorEntryId As %String;

/// <p>How long <method>OnBeforeAllTests</method>' own <code>Fixture.Create("probe", ...)</code>
/// call took, in seconds (rework iteration 5 review). <method>TestDemoTaskIsSuspendedAfterAnError</method>
/// asserts it against <parameter>CREATEMAXSECONDS</parameter>, which pins the owner's
/// decision that the fixture never waits for the Task Manager. Prefix deliberately not
/// "Test" -- see .claude/rules/objectscript-testing.md.</p>
Property PreparedCreateSeconds As %Numeric;

/// <p>How long, in seconds, <method>TestDemoTaskIsSuspendedAfterAnError</method> waits for
/// the demo task to reach <code>Suspended &gt; 0</code> before it fails. The test owns this
/// budget because the fixture no longer waits at all (the owner's decision, rework
/// iteration 5). 180 seconds is about three times what the task needs once nothing in
/// the fixture's process holds it -- see <method>OcuPilot.Install.Fixture.CreateTask</method>'s
/// header for the evidence. Do not widen it to make a red go away: a task that has not
/// suspended in three minutes is a defect, and the failure message names which kind.</p>
Parameter SUSPENDWAITSECONDS As %Integer = 180;

/// <p>Seconds between the fresh re-reads <method>TestDemoTaskIsSuspendedAfterAnError</method>
/// makes while it waits.</p>
Parameter SUSPENDPOLLSECONDS As %Integer = 5;

/// <p>The longest <code>Fixture.Create("probe", ...)</code> may take before
/// <method>TestDemoTaskIsSuspendedAfterAnError</method> calls it a reintroduced wait. Create
/// normally returns in well under a second, and a wait that bought anything would have to
/// last at least one Task Manager pass (a minute), so 30 seconds separates the two with
/// room to spare.</p>
Parameter CREATEMAXSECONDS As %Integer = 30;

/// <p>Drives <method>OcuPilot.Install.Fixture.Create</method> once for the whole class,
/// under the <code>"probe"</code> profile.</p>
/// <p><b>No longer pre-creates a collision application at the real
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter></b> (review finding, HIGH,
/// round 2). Since <code>Fixture.Create</code>/<code>Remove</code> never touch that path
/// unless it is genuinely absent when THIS call runs (and, when they do, only remove
/// what they themselves recorded), this class no longer needs -- or performs -- any
/// out-of-band setup or teardown at the literal production path at all;
/// <method>TestExistingApplicationIsNeverModified</method> now exercises the DW-13
/// collision branch entirely on its own, private, disposable path instead (see that
/// method's own header) so this shared fixture can never collide with, or destroy, a
/// real production demo fixture at <code>/csp/myapp</code>.</p>
/// <p>Captures the fixture's own report stream and the exact identity of the
/// application-error entry it seeded into instance properties, so
/// <method>TestDemoTaskIsSuspendedAfterAnError</method> and
/// <method>TestDemoSeedsAnApplicationError</method> can each make their own,
/// independently-verifiable assertion about what THIS run actually did, rather than
/// re-deriving it from scratch.</p>
Method OnBeforeAllTests() As %Status
{
    Kill tReports
    Set tStart = $ZHorolog
    Set tSC = ##class(OcuPilot.Install.Fixture).Create("probe", .tReports, .tErrorEntryId)
    Set tElapsed = $ZHorolog - tStart
    Set ..PreparedCreateSeconds = tElapsed
    Kill ..PreparedFixtureReports
    Set tN = $Order(tReports(""))
    While tN '= "" {
        Set ..PreparedFixtureReports(tN, "level") = tReports(tN, "level")
        Set ..PreparedFixtureReports(tN, "message") = tReports(tN, "message")
        Set tN = $Order(tReports(tN))
    }
    Set ..PreparedErrorEntryId = tErrorEntryId
    Quit tSC
}

/// <p>Tears down everything <method>OnBeforeAllTests</method> created: the fixture
/// objects and inventory rows through <method>OcuPilot.Install.Fixture.Remove</method>.
/// No longer touches <parameter>COLLISIONPATH</parameter> -- see
/// <method>OnBeforeAllTests</method>'s own header (review finding, HIGH, round 2).</p>
Method OnAfterAllTests() As %Status
{
    Kill tReports
    Quit ##class(OcuPilot.Install.Fixture).Remove("probe", .tReports)
}

/// <p>Whether <method>OnBeforeAllTests</method>' own fixture run actually asked the Task
/// Manager daemon to run the demo task (<code>%SYS.Task.RunNow</code>), read from the
/// fixture's own captured report stream (review finding, MED, round 2). Distinguishes
/// "the daemon has not picked up the run" (a real request is pending) from "nothing ever
/// asked it to run" (a regression removing the <code>RunNow</code> call itself) -- both
/// leave <property>%SYS.Task.LastStarted</property> at <code>0</code> identically.
/// <method>TestDemoTaskIsSuspendedAfterAnError</method> asserts it outright and also uses
/// it to name the cause when the task never started.</p>
Method FixtureRequestedTaskRun() As %Boolean
{
    Set tFound = 0
    Set tN = $Order(..PreparedFixtureReports(""))
    While tN '= "" {
        If $Get(..PreparedFixtureReports(tN, "message")) [ "requested a real run via %SYS.Task.RunNow" {
            Set tFound = 1
        }
        Set tN = $Order(..PreparedFixtureReports(tN))
    }
    Quit tFound
}

/// <p>AC10 (DW-13) -- a pre-existing collision application is never modified, never
/// enabled/disabled, and never given a resource; no inventory row is written for it.</p>
/// <p><b>Rewritten to a private, disposable path this method owns outright</b> (review
/// finding, HIGH, round 2): this used to pre-create the collision object at the REAL
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter> ("/csp/myapp") for the whole
/// class's life, and <method>OnAfterAllTests</method> deleted it unconditionally --
/// which, on the exact configuration this story ships
/// (<code>docker-compose.yml</code>'s <code>OCUPILOT_DEMO: "1"</code>), meant a single
/// <code>OcuPilot.Test.Demo</code> run could destroy a REAL, already-installed
/// production demo web application, and this method's own hardcoded
/// <code>Enabled=1</code>/<code>Resource=%Development</code> assertions would go red
/// for the unrelated reason that production's own fixture is disabled with no resource.</p>
/// <p><b>DW-62 (rework iteration 5): the collision branch is now driven directly.</b> The
/// previous shape reached it through <method>OcuPilot.Test.DemoAppProbe.Create</method>,
/// i.e. the whole four-creator cascade including <method>CreateTask</method>'s
/// <code>%SYS.Task.RunNow</code> and (until rework iteration 5) its up-to-300-second wait
/// -- which made this test slow, coupled to the Task Manager, and able to check "no inventory row"
/// only as a SQL count taken afterwards (a count that a row written and then removed by
/// something else would satisfy just as well). It now calls
/// <method>OcuPilot.Test.DemoAppProbe.DriveCreateWebApp</method>, which opens the
/// <code>%SYS</code> window and dispatches the real, unmodified
/// <method>OcuPilot.Install.Fixture.CreateWebApp</method> -- so the invariant that
/// actually matters is asserted at the source: <b>nothing was noted into
/// <var>pRows</var></b>.</p>
/// <p><b>And through the real <method>OcuPilot.Install.Fixture.Create</method> as well</b>
/// (rework iteration 5 review). <method>OcuPilot.Test.DemoAppProbe.DriveCreateWebApp</method>
/// repeats Create's ownership read on the test side, so on its own it could not see a
/// regression in Create's wiring. The method therefore also runs Create against the same
/// application and asserts the DW-13 warn in Create's own reports. That run is also why
/// the closing SQL count can fail: Create's recording loop, the only writer of inventory
/// rows, runs in it.</p>
Method TestExistingApplicationIsNeverModified()
{
    Set tPath = ##class(OcuPilot.Test.DemoAppProbe).#APPPATH
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    ; A probe webapp row left behind by an earlier aborted run would make the application
    ; below read as this profile's own and turn this test red for an unrelated reason
    ; (rework iteration 5 review). Start from none.
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        If ##class(Security.Applications).Exists(tPath, .tE0, .tS0) {
            Set tDelSC0 = ##class(Security.Applications).Delete(tPath)
            Do $$$AssertStatusOK(tDelSC0, "cleanup removed any stale leftover application at the probe path")
        }
        Set tProps0("Type") = 2
        Set tProps0("Enabled") = 1
        Set tProps0("Resource") = "%Development"
        Set tProps0("Description") = "OcuPilot.Test.Demo's own collision fixture (DW-13) -- not created by install"
        Set tCreateSC0 = ##class(Security.Applications).Create(tPath, .tProps0)
        Do $$$AssertStatusOK(tCreateSC0, "hand-created the collision application at the probe's own private path")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Kill tProbeReports, tProbeRows
    Set tDriveSC = ##class(OcuPilot.Test.DemoAppProbe).DriveCreateWebApp("probe", tInstallNs, .tProbeReports, .tProbeRows)
    Do $$$AssertStatusOK(tDriveSC, "the real CreateWebApp branch runs against the pre-existing collision")

    ; The invariant DW-13 is actually about, read where the decision is made: the
    ; collision branch must note NOTHING, so a later Remove() can never delete an
    ; object this run did not create (AD-25). A count taken afterwards cannot
    ; distinguish "never noted" from "noted and then removed".
    Do $$$AssertTrue('$Data(tProbeRows), "the collision branch noted no inventory row at all -- nothing for a later Remove() to act on")

    Set tWarned = 0
    Set tRN = $Order(tProbeReports(""))
    While tRN '= "" {
        If (tProbeReports(tRN, "level") = "warn") && (tProbeReports(tRN, "message") [ "already carries a web application this run did not create") {
            Set tWarned = 1
        }
        Set tRN = $Order(tProbeReports(tRN))
    }
    Do $$$AssertTrue(tWarned, "the collision is reported as a warn naming DW-13, and install continues")

    ; The real call site too (rework iteration 5 review). Fixture.Create reads ownership
    ; itself, in the install namespace before its own %SYS switch, and passes the answer
    ; down; DriveCreateWebApp above repeats that read on the test side, so it cannot see a
    ; regression in Create's own wiring. Create no longer waits on the Task Manager, so
    ; the whole cascade costs well under a second. Its recording loop runs here too, which
    ; is what makes the inventory count at the end of this method able to fail.
    Kill tCreateReports
    Set tCreateSC = ##class(OcuPilot.Test.DemoAppProbe).Create("probe", .tCreateReports)
    Do $$$AssertStatusOK(tCreateSC, "the real Fixture.Create runs against the same pre-existing collision")
    Set tCreateWarned = 0
    Set tRN = $Order(tCreateReports(""))
    While tRN '= "" {
        If (tCreateReports(tRN, "level") = "warn") && (tCreateReports(tRN, "message") [ "already carries a web application this run did not create") Set tCreateWarned = 1
        Set tRN = $Order(tCreateReports(tRN))
    }
    Do $$$AssertTrue(tCreateWarned, "Fixture.Create itself reports the foreign application as a DW-13 warn")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Applications).Exists(tPath, .tE1, .tS1), "the pre-existing collision application is still there")
        Set tGetSC = ##class(Security.Applications).Get(tPath, .tProps)
        Do $$$AssertStatusOK(tGetSC, "read back the collision application")
        If $$$ISOK(tGetSC) {
            Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the pre-existing application's Enabled flag was never touched")
            Do $$$AssertEquals($Get(tProps("Resource")), "%Development", "the pre-existing application's Resource was never touched")
        }
        Set tDelSC1 = ##class(Security.Applications).Delete(tPath)
        Do $$$AssertStatusOK(tDelSC1, "cleanup removed the probe's own collision application")
        Set $NAMESPACE = tOrigNS2
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS2
        Throw ex2
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS.N, 0, "no inventory row was written for a web application this run did not create")
}

/// <p>DW-13's sibling branch (rework iteration 5): an application already at the path
/// that this profile's <b>own</b> inventory records -- the ordinary state of every
/// container start after the first, with <code>OCUPILOT_DEMO: "1"</code> -- is this
/// profile's earlier fixture, not a collision. It is reported at <code>info</code>,
/// never as a DW-13 <code>warn</code>, and is still left untouched and not re-noted.</p>
/// <p>This branch was a round-2 fix (F-6) that never ran: its inventory read was made
/// while <code>$NAMESPACE</code> was <code>%SYS</code>, where the inventory class cannot
/// resolve, so every collision -- foreign or owned -- fell into the method's
/// <code>Catch</code> instead (see
/// <method>OcuPilot.Install.Fixture.WebAppOwnedByProfile</method>). Nothing pinned it,
/// because the object was left untouched either way. Driven directly through
/// <method>OcuPilot.Test.DemoAppProbe.DriveCreateWebApp</method> on the probe's own
/// private path, with a hand-seeded inventory row standing in for the earlier run.</p>
Method TestOwnEarlierWebAppIsNotACollision()
{
    Set tPath = ##class(OcuPilot.Test.DemoAppProbe).#APPPATH
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        If ##class(Security.Applications).Exists(tPath, .tE0, .tS0) {
            Do $$$AssertStatusOK(##class(Security.Applications).Delete(tPath), "cleanup removed any stale leftover application at the probe path")
        }
        Set tProps0("Type") = 2
        Set tProps0("Enabled") = 0
        Set tProps0("Description") = "OcuPilot.Test.Demo's stand-in for this profile's own earlier fixture run"
        Do $$$AssertStatusOK(##class(Security.Applications).Create(tPath, .tProps0), "created the stand-in for this profile's earlier fixture at the probe's own private path")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = "probe"
    Set tRow.Kind = "webapp"
    Set tRow.Name = tPath
    Set tRow.Scope = "instance"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow), "seeded this profile's own inventory row for the application, as its earlier run would have")

    Kill tReports, tRows
    Set tDriveSC = ##class(OcuPilot.Test.DemoAppProbe).DriveCreateWebApp("probe", tInstallNs, .tReports, .tRows)
    Do $$$AssertStatusOK(tDriveSC, "the real CreateWebApp branch runs against this profile's own earlier fixture")
    Do $$$AssertTrue('$Data(tRows), "nothing is re-noted for an object this profile already recorded")

    Set tInfo = 0
    Set tWarn = 0
    Set tN = $Order(tReports(""))
    While tN '= "" {
        If (tReports(tN, "level") = "info") && (tReports(tN, "message") [ "already exists from an earlier run") Set tInfo = 1
        If tReports(tN, "level") = "warn" Set tWarn = 1
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue(tInfo, "this profile's own earlier fixture is reported at info, as its own")
    Do $$$AssertTrue('tWarn, "and never as a DW-13 collision warn, or as a failure")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Applications).Exists(tPath, .tE1, .tS1), "the application is still there, untouched")
        Do $$$AssertStatusOK(##class(Security.Applications).Delete(tPath), "cleanup removed the stand-in application")
        Set $NAMESPACE = tOrigNS2
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS2
        Throw ex2
    }
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
}

/// <p>AC11 (DW-14) -- the demo task is suspended after a real run's real, deliberate
/// error, with readable error text.</p>
/// <p><b>Not pinned here: AC11's literal "Status below zero".</b> Verified live,
/// repeatedly, against this build (<class>OcuPilot.Install.DemoTask</class>'s own
/// header carries the full record) that this build's <code>%SYS.Task</code> framework
/// leaves <code>Status</code> at <code>1</code> -- the same value a successful run
/// leaves it at -- after a real run whose <code>OnTask</code> throws, for both a thrown
/// <code>%Exception.StatusException</code> and a genuine uncaught
/// <code>&lt;DIVIDE&gt;</code> error. <code>Suspended</code> and <code>Error</code> are
/// what this build actually uses to signal "ran and failed", so this test pins those two
/// -- both independently verified and both directly useful to Stories 2.8 and 5.11 --
/// rather than fabricating a passing assertion against a value this build never
/// produces. Recorded here at its origin, per this project's own convention, rather than
/// left to be rediscovered.</p>
/// <p><b>This test owns the wait, and it fails rather than skips</b> (the owner's decision,
/// rework iteration 5). <method>OcuPilot.Install.Fixture.CreateTask</method> asks for one
/// run and returns without waiting, so this method polls for up to
/// <parameter>SUSPENDWAITSECONDS</parameter>. Every poll drops the previous OREF before it
/// re-opens the task, and the OREF is dropped again as soon as the fields are read:
/// <code>%OpenId</code> on an object this process still holds returns the in-memory copy
/// without reloading it, which is exactly why the loop this replaces never once saw the
/// daemon's write (see <file>.claude/rules/objectscript-basics.md</file>, "Collections
/// and object identity"). On a timeout the failure message separates the two causes: the
/// Task Manager never started the task (<code>LastStarted = 0</code>, and whether this
/// run's fixture had asked it to), or it ran the task and the task did not suspend -- the
/// state the AC11 mutation (<code>DemoTask.OnTask</code> returning <code>$$$OK</code>)
/// produces.</p>
/// <p><b>Corrected at its origin:</b> this header used to describe a DW-46 "deterministic
/// pass" for a task the daemon had not started, and a daemon latency "observed growing 50s
/// -&gt; 150s -&gt; 240s+". That growth was the fixture's own wait plus one poll, seen from
/// different starting points, and the skip was the only way this test ever passed.</p>
Method TestDemoTaskIsSuspendedAfterAnError()
{
    ; Resolved BEFORE switching to %SYS: a fresh ##class(OcuPilot.*) dispatch issued while
    ; $NAMESPACE is %SYS cannot resolve the class at all (see
    ; OcuPilot.Install.Installer.TestOnlyInstallFromSys's own header) -- verified live.
    ; TaskIds itself is safe to call from any namespace; it only touches %SYS.TaskSuper.
    ; "probe" is the profile this class's shared fixture was created under
    ; (OnBeforeAllTests), so the name is resolved through ResolvedPrefix, never typed as
    ; production's literal (review finding, HIGH, round 2).
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Kill tIds
    Set tTaskName = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ " nightly purge"
    Set tQSC = ##class(OcuPilot.Install.Fixture).TaskIds("OcuPilot.Install.DemoTask", tTaskName, tInstallNs, .tIds)
    Do $$$AssertStatusOK(tQSC, "querying for the demo task succeeds")
    Set tId = $Select($Data(tIds): $Get(tIds(1)), 1: "")
    Do $$$AssertTrue(tId '= "", "the demo task fixture exists")

    ; The positive marker CreateTask reports right after a successful RunNow. Asserted
    ; outright: a task left suspended by an earlier run proves nothing about THIS run's
    ; fixture, and a regression that deletes the RunNow call leaves LastStarted at 0
    ; exactly as a daemon that never ran the task would.
    Set tRequested = ..FixtureRequestedTaskRun()
    Do $$$AssertTrue(tRequested, "this run's own fixture asked the Task Manager to run the demo task (RunNow)")

    ; The owner's decision, pinned (rework iteration 5 review): Fixture.Create must not
    ; wait for the Task Manager. A reintroduced wait of the kind this rework removed would
    ; still let the task suspend inside this test's own budget -- it runs at the first pass
    ; after the wait lets go of it -- so the budget alone cannot see one. Create's own
    ; elapsed time can.
    Do $$$AssertTrue(..PreparedCreateSeconds < ..#CREATEMAXSECONDS, "Fixture.Create returned in " _ $FNumber(..PreparedCreateSeconds, "", 1) _ "s, under " _ ..#CREATEMAXSECONDS _ "s -- it asks the Task Manager for a run and does not wait for it (the owner's decision)")

    Set tBudget = ..#SUSPENDWAITSECONDS
    Set tPoll = ..#SUSPENDPOLLSECONDS
    Set tOpened = 0
    Set tSuspendOnError = ""
    Set tTimePeriod = ""
    Set tSuspended = 0
    Set tLastStarted = ""
    Set tError = ""
    Set tWaited = 0
    If tId '= "" {
        Set tOrigNS = $NAMESPACE
        Try {
            Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
            Do $$$AssertStatusOK(tSC, "switch to %SYS")
            Set tTask = ""
            While 1 {
                ; Drop the previous OREF BEFORE the re-open (Defect 1): while this process
                ; still holds the task, %OpenId returns that same in-memory object and never
                ; reloads the row the Task Manager has since written.
                Set tTask = ""
                Set tTask = ##class(%SYS.Task).%OpenId(tId)
                If '$IsObject(tTask) Quit
                Set tOpened = 1
                Set tSuspendOnError = +tTask.SuspendOnError
                Set tTimePeriod = tTask.TimePeriod
                Set tSuspended = +tTask.Suspended
                Set tLastStarted = tTask.LastStarted
                Set tError = tTask.Error
                ; Released again before the wait, so this test never holds the task while
                ; the daemon is trying to take it.
                Set tTask = ""
                If tSuspended > 0 Quit
                If tWaited >= tBudget Quit
                Hang tPoll
                Set tWaited = tWaited + tPoll
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Throw ex
        }
    }

    Do $$$AssertTrue(tOpened, "the demo task opens")
    Do $$$AssertEquals(tSuspendOnError, 1, "the fixture scheduled the task to suspend on error (DW-14)")
    ; AC11: "scheduled so a resume can report a next run" (code review round 3 -- unpinned
    ; until then). TimePeriod 0 is %SYS.Task's daily schedule; 5 (on demand) would leave a
    ; resumed task with no next run at all. Mutation: create the task with TimePeriod 5, and
    ; this goes red while the suspension assertions stay green.
    Do $$$AssertEquals(tTimePeriod, 0, "the demo task is on a daily schedule, so a resume can report a next run")
    If tSuspended > 0 {
        Do $$$AssertTrue(tError '= "", "the demo task suspended after its run (this test waited " _ tWaited _ "s) and its Error property carries readable text")
        Do $$$AssertTrue(tError [ "OcuPilot demo task", "the error text is the task's own deliberate message, not a generic placeholder")
    } ElseIf tOpened && (+tLastStarted = 0) {
        Do $$$AssertTrue(0, "the demo task did not suspend within " _ tBudget _ "s because the Task Manager never started it (LastStarted=0)" _ $Select(tRequested: " although this run's fixture had asked for a run (RunNow)", 1: " -- and this run's fixture never asked for one (no RunNow)"))
    } ElseIf tOpened {
        Do $$$AssertTrue(0, "the demo task did not suspend within " _ tBudget _ "s although the Task Manager did run it (LastStarted=" _ tLastStarted _ ") -- the run did not fail and suspend the task, which DW-14 requires (DemoTask.OnTask's deliberate error, or SuspendOnError, is broken)")
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'task' AND Profile = 'probe'")
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS.N > 0, "the task fixture has an inventory row")
}

/// <p>AC12 (DW-15) -- the install namespace's own application error log carries at least
/// one entry with readable error text and a time, seeded by this run's own fixture.</p>
/// <p><b>Rewritten for the deterministic seed (rework iteration 5).</b> This used to scan
/// <code>SYS.ApplicationError:ErrorList</code> across a date window for an entry naming
/// the demo <i>task</i>, bounded by a <code>$H</code> "since" value and a minute-floored
/// time comparison -- a construction that could only ever narrow, never close, the
/// question "is this entry one THIS run produced?", and that failed outright on any run
/// where the Task Manager daemon had not yet serviced the task (the ordering defect the
/// rework item diagnosed: in <code>%UnitTest_Result</code> run 304 this method failed in
/// 17 ms because the fixture's confirmation ran before the Task Manager had run the task
/// at all). <b>Corrected (rework iteration 5 review):</b> this used to add "while the daemon
/// delivered the entry 180 s later". It did not. The task ran only after the fixture's
/// own 300-second wait let go of it (see <method>OcuPilot.Install.Fixture.CreateTask</method>'s
/// header), and the "180 s" came from a test that could not observe the task at all. The
/// fixture now seeds its own
/// entry synchronously and hands back its exact identity, so this asserts against that one
/// row: its <code>Error #</code>, on its own date, in the install namespace.</p>
/// <p>Independent of the fixture's own confirmation by construction: the fixture reports
/// what it found, this test re-reads the entry itself from the supported query and checks
/// the two things AC12 actually names (readable text, and a time), plus that the text
/// carries this class's own routine marker -- something nothing else on the instance can
/// produce.</p>
Method TestDemoSeedsAnApplicationError()
{
    Do $$$AssertTrue(..PreparedErrorEntryId '= "", "this run's own fixture seeded an application-error log entry and reported its exact identity")
    If ..PreparedErrorEntryId = "" {
        Quit
    }

    Set tDay = $Piece(..PreparedErrorEntryId, ",", 1)
    Set tNumber = $Piece(..PreparedErrorEntryId, ",", 2)
    Do $$$AssertTrue((tDay > 0) && (tNumber > 0), "the seeded entry's identity is a real ($H day, entry number) pair")

    ; SYS.ApplicationError exists only in %SYS (AD-48's own note, confirmed live: a
    ; %ResultSet built against it from HSCUSTOM comes back not-an-object, and the
    ; classmethod triad fails outright with <CLASS DOES NOT EXIST>) -- the target
    ; namespace travels as the query's own first parameter, never via $NAMESPACE.
    ; Resolved BEFORE the switch: a fresh ##class(OcuPilot.*) dispatch issued while
    ; $NAMESPACE is %SYS cannot resolve at all (this story's Boundaries).
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tOrigNS = $NAMESPACE
    Set tFound = 0
    Set tMessage = ""
    Set tTime = ""
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSwitchSC, "switch to %SYS")
        Set tRS = ##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
        Do $$$AssertTrue($IsObject(tRS), "the ErrorList result set is constructed")
        Set tSC = tRS.Execute(tInstallNs, $ZDate(tDay, 1))
        Do $$$AssertStatusOK(tSC, "the supported SYS.ApplicationError.ErrorList query executes")
        While tRS.Next() {
            If tRS.Get("Error #") = tNumber {
                Set tFound = 1
                Set tMessage = tRS.Get("Error message")
                Set tTime = tRS.Get("Time")
            }
        }
        Do tRS.Close()
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do $$$AssertTrue(tFound, "the entry this run's fixture seeded is readable back from the install namespace's own application error log")
    Do $$$AssertTrue(tMessage '= "", "the entry carries readable error text")
    Do $$$AssertTrue(tTime '= "", "the entry carries a time")
    ; The marker, not bare presence: the seed raises its error inside
    ; OcuPilot.Install.Fixture's own routine, so the logged text names that routine and
    ; nothing else on this instance can produce it. A mutation that swallows the
    ; deliberate error without letting the trap log it leaves PreparedErrorEntryId empty
    ; and fails the first assertion above; a mutation that logs something else fails here.
    Do $$$AssertTrue(tMessage [ "OcuPilot.Install.Fixture", "the entry's text names the fixture's own routine, so it is this fixture's entry and not an unrelated one")

    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'errorentry' AND Profile = 'probe'")
    Do $$$AssertTrue(tRS2.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS2.N > 0, "the error-log fixture has an inventory row")
}

/// <p>AC9 -- positive assertion for the demo SSL/TLS configuration fixture: it exists,
/// carries the <parameter>OcuPilot.Install.Fixture.DEMOPREFIX</parameter> name, and has
/// an inventory row. Review finding (HIGH): no test previously asserted any of this --
/// deleting <method>OcuPilot.Install.Fixture.CreateSslConfig</method>'s body entirely
/// would have left every existing test green.</p>
Method TestDemoSslConfigFixtureExists()
{
    ; Review finding (HIGH, round 2): a hardcoded literal here resolved to the
    ; PRODUCTION fixture's own name -- see ResolvedPrefix's own header.
    Set tName = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ "TLS"
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.SSLConfigs).Exists(tName, .tE, .tS), "the demo SSL/TLS configuration fixture exists")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'sslconfig' AND Name = ? AND Profile = 'probe'", tName)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS.N > 0, "the SSL/TLS configuration fixture has an inventory row")
}

/// <p>AC9 -- positive assertion for the demo self-signed X.509 credential fixture: it
/// exists, carries the <parameter>OcuPilot.Install.Fixture.DEMOPREFIX</parameter> name,
/// and has an inventory row. Same gap as <method>TestDemoSslConfigFixtureExists</method>
/// (review finding, HIGH).</p>
Method TestDemoX509CredentialFixtureExists()
{
    ; Review finding (HIGH, round 2): a hardcoded literal here resolved to the
    ; PRODUCTION fixture's own name -- see ResolvedPrefix's own header.
    Set tAlias = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ "Cert"
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Do $$$AssertTrue(##class(%SYS.X509Credentials).Exists(tAlias, .tE, .tS), "the demo X.509 credential fixture exists")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'x509credential' AND Name = ? AND Profile = 'probe'", tAlias)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS.N > 0, "the X.509 credential fixture has an inventory row")
}

/// <p>AC9 -- positive assertion for the demo web application fixture's CREATE branch:
/// disabled, carrying no resource, with an inventory row; and AC8's gap line for it.
/// Review finding (HIGH): when this test was written, <class>OcuPilot.Test.Demo</class>'s
/// shared fixture kept a collision in place at the real
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>, so
/// <method>OcuPilot.Install.Fixture.CreateWebApp</method>'s create branch was unreachable
/// here (round 2 removed that collision; see <method>OnBeforeAllTests</method>). Drives the real, unmodified
/// <method>CreateWebApp</method>/<method>RemoveOne</method> against
/// <class>OcuPilot.Test.DemoAppProbe</class>'s own private, disposable path instead
/// (that class's own header explains the isolation) -- order-independent of every other
/// method in this class, since it never touches the real
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>.</p>
Method TestDemoWebAppFixtureCreatedWhenAbsent()
{
    Set tPath = ##class(OcuPilot.Test.DemoAppProbe).#APPPATH
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        If ##class(Security.Applications).Exists(tPath, .tE0, .tS0) {
            Set tDelSC0 = ##class(Security.Applications).Delete(tPath)
            Do $$$AssertStatusOK(tDelSC0, "cleanup removed any stale leftover application at the probe path")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Kill tProbeReports
    Set tCreateSC = ##class(OcuPilot.Test.DemoAppProbe).Create("probe", .tProbeReports)
    Do $$$AssertStatusOK(tCreateSC, "the probe fixture's own Create call succeeds")
    ; AC8: the install report names the CSP Gateway registration gap for every web
    ; application this run created (code review round 3 -- unpinned until then: deleting the
    ; gap line in CreateWebApp left every test green).
    Do $$$AssertTrue(..ReportsGatewayGapFor(.tProbeReports, tPath), "the run that created the web application names the CSP Gateway registration gap for it")

    ; This profile's own earlier fixture, seen by the real call site (rework iteration 5
    ; review). A second Create finds the application the first one just created and
    ; recorded, and must report it at info as its own, never as a DW-13 collision warn.
    ; Every container restart with OCUPILOT_DEMO="1" depends on that (F-6), and here it is
    ; read through Create's own ownership lookup, not a test-side copy of it.
    Kill tSecondReports
    Set tSecondSC = ##class(OcuPilot.Test.DemoAppProbe).Create("probe", .tSecondReports)
    Do $$$AssertStatusOK(tSecondSC, "a second Create on the same profile succeeds")
    Set tOwnInfo = 0
    Set tDw13Warn = 0
    Set tRN = $Order(tSecondReports(""))
    While tRN '= "" {
        If (tSecondReports(tRN, "level") = "info") && (tSecondReports(tRN, "message") [ "already exists from an earlier run") Set tOwnInfo = 1
        If (tSecondReports(tRN, "level") = "warn") && (tSecondReports(tRN, "message") [ "already carries a web application this run did not create") Set tDw13Warn = 1
        Set tRN = $Order(tSecondReports(tRN))
    }
    Do $$$AssertTrue(tOwnInfo, "Create reports this profile's own earlier web application at info, as its own")
    Do $$$AssertTrue('tDw13Warn, "and never as a DW-13 collision warn")
    Do $$$AssertTrue('..ReportsGatewayGapFor(.tSecondReports, tPath), "a run that created no web application names no gap for one")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Applications).Exists(tPath, .tE1, .tS1), "the disabled web application fixture was created at the genuinely-absent probe path")
        Set tGetSC = ##class(Security.Applications).Get(tPath, .tProps)
        Do $$$AssertStatusOK(tGetSC, "read back the created fixture application")
        ; Review finding (build-auto review, 2026-09-10, Rule 19): $$$AssertStatusOK does
        ; not abort the method on failure -- without this guard, a Get() failure would
        ; leave tProps undefined, and $Get(tProps(...))'s own default values (0, "")
        ; happen to match the disabled/no-resource assertions below, turning a real read
        ; failure into a vacuous pass instead of a red test.
        ; Fix Pack F-3 (round 2): the ISERR guard used to be a bare `Quit`, which exits
        ; this whole Try block -- skipping the Delete cleanup below it too, and leaving
        ; the probe application behind on a Get failure. An If/Else now gates only the
        ; two property assertions, so cleanup always runs regardless of which branch
        ; this takes.
        If $$$ISERR(tGetSC) {
            Do $$$AssertTrue(0, "could not read back the created fixture application, so its Enabled/Resource properties could not be checked: " _ $System.Status.GetErrorText(tGetSC))
        } Else {
            Do $$$AssertEquals(+$Get(tProps("Enabled")), 0, "the created fixture application is disabled")
            Do $$$AssertEquals($Get(tProps("Resource")), "", "the created fixture application carries no resource")
        }
        Set tDelSC1 = ##class(Security.Applications).Delete(tPath)
        Do $$$AssertStatusOK(tDelSC1, "cleanup removed the probe application")
        Set $NAMESPACE = tOrigNS2
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS2
        Throw ex2
    }

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS.N > 0, "the created web application fixture has an inventory row")

    ; Scoped cleanup: only this probe path's own row, never the whole profile's
    ; inventory (which TestDemoTaskIsSuspendedAfterAnError/TestDemoSeedsAnApplicationError
    ; still depend on for the rest of this class's run).
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ? AND Profile = 'probe'", tPath)
}

/// <p>Whether <var>pReports</var> carries the CSP Gateway registration-gap line
/// <method>OcuPilot.Install.Fixture.CreateWebApp</method> reports for the application at
/// <var>pPath</var> it has just created.</p>
Method ReportsGatewayGapFor(ByRef pReports, pPath As %String) As %Boolean
{
    Set tFound = 0
    Set tN = $Order(pReports(""))
    While tN '= "" {
        Set tData = $Get(pReports(tN, "data"))
        If ($Get(pReports(tN, "message")) [ "does not notify the CSP Gateway") && $IsObject(tData) && (tData.%Get("path") = pPath) Set tFound = 1
        Set tN = $Order(pReports(tN))
    }
    Quit tFound
}

/// <p>Regression pin for this rework pass's own discovery (DW-53 correction, this story's
/// spec): <code>$Data(tIds(""))</code> -- dereferencing the literal empty string as an
/// explicit subscript, never <code>$Order</code>'s own seed argument -- throws
/// <code>&lt;SUBSCRIPT&gt;</code> unconditionally on this build whenever
/// <code>%SYS.TaskSuper.QueryTasks</code> legitimately matches nothing (confirmed live).
/// That is exactly the state <method>OcuPilot.Install.Fixture.CreateTask</method> starts
/// from on a genuinely first install, and the shape this class's own
/// <method>TestDemoTaskIsSuspendedAfterAnError</method> depends on getting right every run.
/// Drives the real, read-only <code>QueryTasks</code> against a name that cannot exist --
/// no fixture, no namespace switch, no side effect -- so a regression back to the literal
/// (and equally broken) <code>$Data(tIds(tFirst))</code> form fails loudly and
/// deterministically here, instead of only intermittently on whichever run happens to find
/// nothing.</p>
/// <p>Review finding (HIGH): the previous version of this regression pin re-implemented
/// the guard inline and asserted that COPY never throws -- it never referenced
/// <class>OcuPilot.Install.Fixture</class> at all, so reverting the real
/// <method>OcuPilot.Install.Fixture.CreateTask</method> guard to the broken, literal
/// <code>$Data(tIds(tFirst))</code> form left this test green (Rule 19: a gate that
/// cannot fail). Now drives the real, Public, read-only
/// <method>OcuPilot.Install.Fixture.TaskIds</method> helper both
/// <method>CreateTask</method> and <method>RemoveOne</method> call, against a name
/// guaranteed not to exist -- no fixture, no namespace switch, no side effect -- so a
/// regression to the broken form fails loudly and deterministically here.</p>
Method TestNoMatchGuardResolvesEmptyWithoutThrowing()
{
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Kill tIds
    Set tThrew = 0
    Set tQSC = $$$OK
    Try {
        Set tQSC = ##class(OcuPilot.Install.Fixture).TaskIds("OcuPilot.Install.DemoTask", "ZZ-guaranteed-no-such-task-name-c1a2b3", tInstallNs, .tIds)
    } Catch ex {
        Set tThrew = 1
    }
    Do $$$AssertTrue('tThrew, "TaskIds never throws when QueryTasks matches nothing")
    Do $$$AssertStatusOK(tQSC, "querying for a name that cannot exist still succeeds")
    Do $$$AssertTrue('$Data(tIds), "and resolves to no ids, not a false match")
}

/// <p>Regression pin (review finding, MED): <method>OcuPilot.Kernel.State.Demo.DeleteByProfile</method>'s
/// production-profile (<code>""</code>) branch used to bind <code>Profile = ?</code>
/// with the literal <code>''</code>, which never matches the SQL <code>NULL</code> a
/// production row's <property>Profile</property> actually reads back as -- so a
/// confirmed uninstall would silently leave every production fixture's inventory row
/// behind. Verified only by a manual, one-off SQL probe during this same iteration's
/// review (this file's <code>## Auto Run Result</code>), never a committed test.
/// Backs up and restores any pre-existing production rows around the destructive call
/// so a real deployed instance's own demo-fixture inventory (from
/// <code>OCUPILOT_DEMO=1</code>) is never actually lost by running this test.</p>
Method TestDeleteByProfileRemovesProductionNullRows()
{
    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Kind, Name, Scope FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS0.%SQLCODE >= 0, "reading existing production rows succeeds")
    Kill tBackup
    Set tBackupN = 0
    While tRS0.%Next() {
        Set tBackupN = tBackupN + 1
        Set tBackup(tBackupN, "kind") = tRS0.Kind
        Set tBackup(tBackupN, "name") = tRS0.Name
        Set tBackup(tBackupN, "scope") = tRS0.Scope
    }

    ; Review finding (MED, round 2): everything from here on used to have NO Try/Catch
    ; at all -- an exception anywhere between the destructive DeleteByProfile('') call
    ; and the restore loop finishing left production's demo-fixture inventory
    ; PERMANENTLY EMPTIED, with no repair. RestoreProductionDemoRows below is now the
    ; one restore path both the normal return and the Catch call, so no exit from this
    ; method can skip it.
    ;
    ; Review finding (build-auto step-04 review pass, 2026-09-11): the Catch used to
    ; call RestoreProductionDemoRows UNCONDITIONALLY -- but if the exception happened
    ; BEFORE DeleteByProfile('') ever actually ran (e.g. GuardedSave or
    ; GuardedRowExists above throwing), the original rows were never removed, and
    ; restoring anyway would INSERT DUPLICATE copies on top of the still-present
    ; originals, corrupting production's own inventory rather than protecting it.
    ; tDeleteRan tracks whether the delete itself actually completed, so the Catch
    ; only restores when there is genuinely something to restore.
    Set tThrowawayName = "ZZ-DeleteByProfile-NULL-probe-c1a2b3"
    Set tDeleteRan = 0
    Try {
        Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
        Set tRow.Profile = ""
        Set tRow.Kind = "sslconfig"
        Set tRow.Name = tThrowawayName
        Set tRow.Scope = "instance"
        Set tSaveSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
        Do $$$AssertStatusOK(tSaveSC, "hand-created a throwaway production-profile row")

        Set tExistsSC = ##class(OcuPilot.Kernel.State.Demo).GuardedRowExists("", "sslconfig", tThrowawayName, .tExistsBefore)
        Do $$$AssertStatusOK(tExistsSC, "GuardedRowExists succeeds before the delete")
        Do $$$AssertTrue(tExistsBefore, "the throwaway row reads back as a production ('' -> NULL) row through the class's own sibling reader")

        Set tDelSC = ##class(OcuPilot.Kernel.State.Demo).DeleteByProfile("")
        Set tDeleteRan = 1
        Do $$$AssertStatusOK(tDelSC, "DeleteByProfile('') succeeds")

        Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
        Do $$$AssertTrue(tRS1.%Next(), "the post-delete count query returns a row")
        Do $$$AssertEquals(tRS1.N, 0, "every production-profile row, including the throwaway one, is actually deleted -- not left behind by a Profile = '' bind that never matches NULL")
    } Catch ex {
        If tDeleteRan Do ..RestoreProductionDemoRows(.tBackup, tBackupN)
        Throw ex
    }

    Do ..RestoreProductionDemoRows(.tBackup, tBackupN)
}

/// <p>Restores every backed-up production (<code>Profile IS NULL</code>) row
/// <method>TestDeleteByProfileRemovesProductionNullRows</method>' own destructive
/// <code>DeleteByProfile("")</code> call removed -- called from both that method's
/// straight-line path and its <code>Catch</code> block (review finding, MED, round 2),
/// so an exception partway through cannot leave the shared instance's demo fixture
/// inventory permanently emptied.</p>
Method RestoreProductionDemoRows(ByRef pBackup, pBackupN As %Integer)
{
    For tI = 1:1:pBackupN {
        Set tRestoreRow = ##class(OcuPilot.Kernel.State.Demo).%New()
        Set tRestoreRow.Profile = ""
        Set tRestoreRow.Kind = pBackup(tI, "kind")
        Set tRestoreRow.Name = pBackup(tI, "name")
        Set tRestoreRow.Scope = pBackup(tI, "scope")
        Set tRestoreSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRestoreRow)
        Do $$$AssertStatusOK(tRestoreSC, "restored a pre-existing production row this test's own destructive call removed")
    }
}

}
