/// <p>AC9-AC12: fixture creation, the DW-13 collision guard, the flag-absent path, and
/// inventory-scoped removal. Drives <class>OcuPilot.Install.Fixture</class> directly
/// under the disposable <code>"probe"</code> profile -- installs nothing itself and
/// calls neither <code>Install</code> nor <code>Uninstall</code> (this story's own
/// "Install/Uninstall cycling hazard" note), except for
/// <method>TestNoFixtureExistsWithoutTheFlag</method>, which drives the real, idempotent
/// <method>OcuPilot.Install.Installer.StartPath</method> with the flag off.</p>
/// <p><b>One shared, expensive setup for the whole class</b>
/// (<method>OnBeforeAllTests</method>, not <code>OnBeforeOneTest</code>): pre-creates the
/// DW-13 collision web application, then calls
/// <method>OcuPilot.Install.Fixture.Create</method> exactly once. That single call is
/// what waits for the real Task Manager daemon to run the demo task fixture for real,
/// up to <parameter>OcuPilot.Install.Fixture.TASKWAITSECONDS</parameter> (widened
/// 90 -> 300 during this story's own review, after this class's own review-time runs
/// observed the daemon on this specific long-lived container taking well past 90
/// seconds -- see that parameter's own header and this story's ledgered flake); every
/// test method below only asserts against the state it left, and
/// <method>OnAfterAllTests</method> tears all of it down once.</p>
Class OcuPilot.Test.Demo Extends %UnitTest.TestCase
{

/// <p>The fixed collision path (DW-13) -- see
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>.</p>
Parameter COLLISIONPATH = "/csp/myapp";

/// <p>Pre-creates the DW-13 collision application (enabled, carrying a resource, so any
/// modification by the fixture step is detectable), then drives
/// <method>OcuPilot.Install.Fixture.Create</method> once for the whole class.</p>
Method OnBeforeAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If '##class(Security.Applications).Exists(..#COLLISIONPATH, .tE, .tS) {
            Set tProps("Type") = 2
            Set tProps("Enabled") = 1
            Set tProps("Resource") = "%Development"
            Set tProps("Description") = "OcuPilot.Test.Demo's own collision fixture -- not created by install (DW-13)"
            Set tSC = ##class(Security.Applications).Create(..#COLLISIONPATH, .tProps)
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC

    Kill tReports
    Quit ##class(OcuPilot.Install.Fixture).Create("probe", .tReports)
}

/// <p>Tears down everything <method>OnBeforeAllTests</method> created: the fixture
/// objects and inventory rows through <method>OcuPilot.Install.Fixture.Remove</method>,
/// then the collision application it pre-created (never touched by <code>Remove</code>,
/// by design -- DW-13).</p>
Method OnAfterAllTests() As %Status
{
    Kill tReports
    Do ##class(OcuPilot.Install.Fixture).Remove("probe", .tReports)

    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Applications).Exists(..#COLLISIONPATH, .tE, .tS) {
            Set tSC = ##class(Security.Applications).Delete(..#COLLISIONPATH)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>AC10 (DW-13) -- the pre-existing collision application is never modified, never
/// enabled/disabled, and never given a resource; no inventory row was written for it.</p>
Method TestExistingApplicationIsNeverModified()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Applications).Exists(..#COLLISIONPATH, .tE, .tS), "the pre-existing collision application is still there")
        Set tGetSC = ##class(Security.Applications).Get(..#COLLISIONPATH, .tProps)
        Do $$$AssertStatusOK(tGetSC, "read back the collision application")
        Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the pre-existing application's Enabled flag was never touched")
        Do $$$AssertEquals($Get(tProps("Resource")), "%Development", "the pre-existing application's Resource was never touched")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'webapp' AND Name = ?", ..#COLLISIONPATH)
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS.N, 0, "no inventory row was written for a web application this run did not create")
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
Method TestDemoTaskIsSuspendedAfterAnError()
{
    ; Resolved BEFORE switching to %SYS: a fresh ##class(OcuPilot.Install.Installer)
    ; dispatch issued while $NAMESPACE is %SYS cannot resolve the class at all (see
    ; OcuPilot.Install.Installer.TestOnlyInstallFromSys's own header) -- verified live
    ; while writing this test.
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Kill tIds
        Set tQSC = ##class(%SYS.TaskSuper).QueryTasks("OcuPilot.Install.DemoTask", "OcuPilotDemo nightly purge", tInstallNs, .tIds)
        Do $$$AssertStatusOK(tQSC, "querying for the demo task succeeds")
        ; QueryTasks populates tIds starting at subscript 0, not 1 (verified live,
        ; the root cause this test method's own earlier failure traced to).
        Set tId = ""
        Set tFirst = $Order(tIds(""))
        If tFirst '= "" Set tId = tIds(tFirst)
        Do $$$AssertTrue(tId '= "", "the demo task fixture exists")
        Set tTask = ##class(%SYS.Task).%OpenId(tId)
        Do $$$AssertTrue($IsObject(tTask), "the demo task opens")
        Do $$$AssertTrue(+tTask.Suspended > 0, "the demo task is suspended after its run (DW-14)")
        Do $$$AssertTrue(tTask.Error '= "", "the demo task's Error property carries readable text")
        Do $$$AssertTrue(tTask.Error [ "OcuPilot demo task", "the error text is the task's own deliberate message, not a generic placeholder")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'task' AND Profile = 'probe'")
    Do $$$AssertTrue(tRS.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS.N > 0, "the task fixture has an inventory row")
}

/// <p>AC12 (DW-15) -- the install namespace's own application error log carries at
/// least one readable entry with a time, produced as a side effect of the demo task
/// fixture's own real, deliberate failure (verified live: the Task Manager's own error
/// handling writes a fully descriptive <code>&lt;THROW&gt;...</code> entry).</p>
Method TestDemoSeedsAnApplicationError()
{
    Do $$$AssertTrue($Data(^ERRORS) > 0, "the install namespace's application error log carries at least one entry")

    ; SYS.ApplicationError exists only in %SYS (AD-48's own note, confirmed live: a
    ; %ResultSet built against it from HSCUSTOM comes back not-an-object, and the
    ; classmethod triad fails outright with <CLASS DOES NOT EXIST>) -- the target
    ; namespace travels as the query's own first parameter, never via $NAMESPACE.
    Set tOrigNS = $NAMESPACE
    Set tFound = 0
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSwitchSC, "switch to %SYS")

        Set tDate = $ZDate($Piece($H, ",", 1), 1)
        Set tRS = ##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
        Do $$$AssertTrue($IsObject(tRS), "the ErrorList result set is constructed")
        Set tSC = tRS.Execute("HSCUSTOM", tDate)
        Do $$$AssertStatusOK(tSC, "the supported SYS.ApplicationError.ErrorList query executes")
        While tRS.Next() {
            If tRS.Get("Error message") [ "OcuPilot demo task" {
                Set tFound = 1
                Do $$$AssertTrue(tRS.Get("Time") '= "", "the entry carries a time")
            }
        }
        Do tRS.Close()
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tFound, "the demo task's own deliberate failure produced a readable entry in today's application error log")

    Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Kind = 'errorentry' AND Profile = 'probe'")
    Do $$$AssertTrue(tRS2.%Next(), "the count query returns a row")
    Do $$$AssertTrue(tRS2.N > 0, "the error-log fixture has an inventory row")
}

/// <p>AC9 -- with the flag absent (here: <method>StartPath</method> called with
/// <var>pDemo</var> = 0, exactly IPM's own path), no fixture object of any kind is
/// created: no new production-profile (<code>Profile IS NULL</code>) inventory row
/// appears. Drives the real <method>OcuPilot.Install.Installer.StartPath</method>
/// (idempotent, safe -- the same production install every other test in this tree
/// already exercises repeatedly) rather than only asserting that
/// <method>OcuPilot.Install.Fixture.Create</method> was never called, which would be
/// true by construction and prove nothing about the call site.</p>
Method TestNoFixtureExistsWithoutTheFlag()
{
    Set tRS0 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS0.%Next(), "the count query returns a row")
    Set tBefore = tRS0.N

    Set tSC = ##class(OcuPilot.Install.Installer).StartPath(0)
    Do $$$AssertStatusOK(tSC, "StartPath with the demo flag off completes install")

    Set tRS1 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL")
    Do $$$AssertTrue(tRS1.%Next(), "the count query returns a row")
    Do $$$AssertEquals(tRS1.N, tBefore, "StartPath with the demo flag off creates no fixture object of any kind -- no new production-scoped inventory row appears")
}

}
