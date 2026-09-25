/// <p>Fault-injection tests for <class>OcuPilot.Install.Fixture</class> (rework iteration
/// 5), driven through <class>OcuPilot.Test.FixtureFault</class>: <b>DW-57</b> (the four
/// status-checked <code>Delete</code> branches in
/// <method>OcuPilot.Install.Fixture.RemoveOne</method>) and <b>DW-52</b> (a task deleted
/// between <method>OcuPilot.Install.Fixture.CreateTask</method>'s query and its open).</p>
/// <p>A separate class from <class>OcuPilot.Test.Demo</class> deliberately: that class's
/// shared <method>OcuPilot.Test.Demo.OnBeforeAllTests</method> runs the whole fixture
/// cascade, including a real <code>RunNow</code> of the demo task, and its task test then
/// waits for the Task Manager. No test here needs any of it, so none pays for it. None of
/// them reads or writes the shared <code>"probe"</code> inventory. The
/// <code>Remove</code> tests use their own disposable profiles and names.
/// <method>TestCreateTaskReportsAVanishedTaskId</method> passes <code>"probe"</code>, but
/// its armed <code>TaskIds</code>/<code>OpenTask</code> seams never reach a real task, and
/// it notes nothing (corrected, rework iteration 5 review).</p>
/// <p>It runs only where <parameter>ARMINGVARIABLE</parameter> reads <code>1</code>.</p>
Class OcuPilot.Test.DemoFaults Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone: it creates and removes a web application, a TLS configuration, an X.509 credential
/// and a wallet collection on this instance.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DemoFaults creates and removes a web application, a TLS configuration, an X.509 credential and a wallet collection on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p><b>DW-57.</b> <method>OcuPilot.Install.Fixture.RemoveOne</method>'s three
/// status-checked <code>Delete</code> branches (webapp / sslconfig / x509credential) were
/// exercised only on their success paths: a regression back to the bare
/// <code>Do ##class(...).Delete(pName)</code> form that discards the <code>%Status</code>
/// -- the exact defect a HIGH review finding fixed -- left the whole suite green, because
/// nothing in the suite could make a real delete fail.</p>
/// <p>Drives the real, public <method>OcuPilot.Install.Fixture.Remove</method> against
/// three genuinely-existing disposable objects and three seeded inventory rows, with
/// <class>OcuPilot.Test.FixtureFault</class>'s delete overrides armed, so the real,
/// unmodified <method>RemoveOne</method> runs and each branch's failure path is taken for
/// real. Uses its own disposable profile, never <code>"probe"</code>, so it cannot disturb
/// the shared class fixture's own inventory.</p>
/// <p>Also pins the consequence the warns alone did not cover (rework iteration 5): with
/// the objects still on the instance, <method>OcuPilot.Install.Fixture.Remove</method> must
/// keep their inventory rows for a retry rather than purge the only record of them.</p>
Method TestRemoveReportsEveryFailedDelete()
{
    Set tProfile = "removefault"
    Set tApp = "/csp/ocupilottestremovefault"
    Set tSsl = "OcuPilotRemoveFaultTLS"
    Set tCert = "OcuPilotRemoveFaultCert"

    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).SeedRemovableObjects(tApp, tSsl, tCert), "the three disposable objects exist before the removal attempt")

    Try {
        Do ..SeedInventoryRow(tProfile, "webapp", tApp)
        Do ..SeedInventoryRow(tProfile, "sslconfig", tSsl)
        Do ..SeedInventoryRow(tProfile, "x509credential", tCert)

        Do ##class(OcuPilot.Test.FixtureFault).SetDeletesShouldFail(1)
        Kill tReports
        Set tSC = ##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tReports)
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do $$$AssertStatusOK(tSC, "Remove still returns OK -- a removal failure is a warn, never a propagated error (AD-25)")

        Set tApps = 0
        Set tSsls = 0
        Set tCerts = 0
        Set tKept = 0
        Set tN = $Order(tReports(""))
        While tN '= "" {
            If tReports(tN, "level") = "warn" {
                Set tMsg = tReports(tN, "message")
                If tMsg [ "Could not delete the demo web application fixture" Set tApps = 1
                If tMsg [ "Could not delete the demo SSL/TLS configuration fixture" Set tSsls = 1
                If tMsg [ "Could not delete the demo X.509 credential fixture" Set tCerts = 1
                If tMsg [ "could not be removed -- inventory left in place" Set tKept = 1
            }
            Set tN = $Order(tReports(tN))
        }
        Do $$$AssertTrue(tApps, "the failed web application delete is reported as a warn naming the object")
        Do $$$AssertTrue(tSsls, "the failed SSL/TLS configuration delete is reported as a warn naming the object")
        Do $$$AssertTrue(tCerts, "the failed X.509 credential delete is reported as a warn naming the object")
        Do $$$AssertTrue(tKept, "Remove reports that it kept the inventory because an object could not be removed")

        Set tRowsRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Do $$$AssertTrue(tRowsRS.%Next(), "the inventory count query returns a row")
        Do $$$AssertEquals(tRowsRS.N, 3, "all three inventory rows are kept for a retry -- the objects are still on the instance, so their only record is not purged")

        Set tExistsSC = ##class(OcuPilot.Test.FixtureFault).SeededObjectsExist(tApp, tSsl, tCert, .tAppLeft, .tSslLeft, .tCertLeft)
        Do $$$AssertStatusOK(tExistsSC, "the three objects can be re-checked")
        Do $$$AssertTrue(tAppLeft, "the web application is still there -- the delete genuinely failed rather than the fault being ignored")
        Do $$$AssertTrue(tSslLeft, "the SSL/TLS configuration is still there")
        Do $$$AssertTrue(tCertLeft, "the X.509 credential is still there")

        ; The retry the kept inventory exists for (rework iteration 5 review): with the
        ; fault gone, a second Remove deletes what the first could not, then purges.
        Kill tRetryReports
        Set tRetrySC = ##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tRetryReports)
        Do $$$AssertStatusOK(tRetrySC, "the retry Remove returns OK")
        Set tRetryExistsSC = ##class(OcuPilot.Test.FixtureFault).SeededObjectsExist(tApp, tSsl, tCert, .tAppAfter, .tSslAfter, .tCertAfter)
        Do $$$AssertStatusOK(tRetryExistsSC, "the three objects can be re-checked after the retry")
        Do $$$AssertTrue('tAppAfter && 'tSslAfter && 'tCertAfter, "the retry removed all three objects the failed attempt left behind")
        Set tAfterRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Do $$$AssertTrue(tAfterRS.%Next(), "the post-retry count query returns a row")
        Do $$$AssertEquals(tAfterRS.N, 0, "and, with every object gone, the retry purged the kept inventory")
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do ##class(OcuPilot.Test.FixtureFault).RemoveSeededObjects(tApp, tSsl, tCert)
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Throw ex
    }

    ; Belt and braces: both are no-ops when the retry above did its job.
    Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).RemoveSeededObjects(tApp, tSsl, tCert), "cleanup found nothing left to remove, or removed it for real")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
}

/// <p><b>DW-57, the task branch</b> (rework iteration 5 review). <method>OcuPilot.Install.Fixture.RemoveOne</method>
/// now reports whether its object is gone. <method>OcuPilot.Install.Fixture.Remove</method>
/// keeps the whole inventory when any object could not be removed. The three
/// <code>Delete</code> branches are pinned above. This pins the task branch: a failed
/// <code>%SYS.Task.%DeleteId</code> must keep the row too. Without it, the task stays on
/// the instance with no record left to find it by.</p>
/// <p>No real task is involved. With <class>OcuPilot.Test.FixtureFault</class>'s
/// vanished-task fault armed, <code>TaskIds</code> hands back an id that cannot resolve, and
/// <code>%DeleteId</code> refuses it with <code>ERROR #7415</code>, the same failure a task
/// deleted by someone else produces. Disarmed, the retry finds no task and purges.</p>
Method TestRemoveKeepsInventoryWhenATaskDeleteFails()
{
    Set tProfile = "removetask"
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
    Try {
        Do ..SeedInventoryRow(tProfile, "task", "OcuPilotRemoveTask nightly purge", tInstallNs)

        Do ##class(OcuPilot.Test.FixtureFault).SetTaskShouldVanish(1)
        Kill tReports
        Set tSC = ##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tReports)
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do $$$AssertStatusOK(tSC, "Remove still returns OK -- a removal failure is a warn (AD-25)")

        Set tTaskWarn = 0
        Set tN = $Order(tReports(""))
        While tN '= "" {
            If (tReports(tN, "level") = "warn") && (tReports(tN, "message") [ "Could not delete a demo task fixture") Set tTaskWarn = 1
            Set tN = $Order(tReports(tN))
        }
        Do $$$AssertTrue(tTaskWarn, "the failed task delete is reported as a warn")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Do $$$AssertTrue(tRS.%Next(), "the inventory count query returns a row")
        Do $$$AssertEquals(tRS.N, 1, "the task's inventory row is kept for a retry, not purged with the task still unaccounted for")

        Kill tRetryReports
        Set tRetrySC = ##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tRetryReports)
        Do $$$AssertStatusOK(tRetrySC, "the retry Remove returns OK")
        Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Do $$$AssertTrue(tRS2.%Next(), "the post-retry count query returns a row")
        Do $$$AssertEquals(tRS2.N, 0, "the retry finds no such task and purges the row")
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Throw ex
    }
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
}

/// <p><b>DW-52.</b> <method>OcuPilot.Install.Fixture.CreateTask</method> reads an id from
/// <method>TaskIds</method> and then opens it; another process can delete the task between
/// the two reads. Before this branch existed, a failed open fell through into
/// <code>RunNow</code> and, while the fixture still waited afterwards, was reported as
/// "did not reach the suspended state within the wait window -- it remains scheduled",
/// which names the wrong cause: the task is not late, it is gone (and it is not scheduled
/// either).</p>
/// <p>Since rework iteration 5 the fixture no longer waits, so that misreport can no longer
/// be produced; what the branch must still guarantee is that a vanished task is reported
/// as vanished and that <b>no run is attempted for it</b>. The second assertion therefore
/// looks for any sign of <code>RunNow</code> -- its success marker or its failure warn --
/// which is what the fall-through produces when the branch is removed.</p>
/// <p><class>OcuPilot.Test.FixtureFault</class> reproduces the race deterministically --
/// an id that cannot resolve, and an open that refuses it -- so no real task is created
/// and, with the branch in place, no <code>%SYS.Task.RunNow</code> is issued.</p>
Method TestCreateTaskReportsAVanishedTaskId()
{
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do ##class(OcuPilot.Test.FixtureFault).SetTaskShouldVanish(1)
    Kill tReports, tRows
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Test.FixtureFault).DriveCreateTask("probe", tInstallNs, .tReports, .tRows)
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Throw ex
    }
    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do $$$AssertStatusOK(tSC, "the fixture's own task step never propagates an error to its caller")

    Set tVanished = 0
    Set tRunAttempted = 0
    Set tN = $Order(tReports(""))
    While tN '= "" {
        Set tMsg = tReports(tN, "message")
        If (tReports(tN, "level") = "warn") && (tMsg [ "vanished between the task query and the open") Set tVanished = 1
        If (tMsg [ "requested a real run via %SYS.Task.RunNow") || (tMsg [ "Could not schedule the demo task fixture to run now") Set tRunAttempted = 1
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue(tVanished, "a task id deleted between the query and the open is reported as vanished, in its own warn")
    Do $$$AssertTrue('tRunAttempted, "and no run is attempted for a task that no longer exists -- RunNow is never called with its id")
    Do $$$AssertTrue('$Data(tRows), "nothing is noted into the inventory for a task that no longer exists")
}

/// <p><b>DW-57, the wallet collection branch</b> (Story 6.3), pinned the way
/// <method>TestRemoveReportsEveryFailedDelete</method> pins the other three: with
/// <class>OcuPilot.Test.FixtureFault</class>'s delete fault armed, a failed collection delete is a
/// warn naming the object, its inventory row is kept and the collection is still there; with the
/// fault gone, a retry removes the collection and purges the row. Uses its own disposable profile
/// and collection, never <code>"probe"</code>.</p>
/// <p>Mutation: delete the <code>walletcollection</code> arm of
/// <method>OcuPilot.Install.Fixture.RemoveOne</method> -&gt; the row falls to an unrecognized kind and
/// is purged with the collection left behind, so the warn, kept-row and retry assertions go red.</p>
Method TestRemoveReportsAFailedWalletCollectionDelete()
{
    Set tProfile = "removewallet"
    Set tName = "OcuPilotRemoveFaultWallet"
    Set tCountSql = "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?"

    Do ##class(OcuPilot.Test.FixtureFault).Disarm()
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).WalletCollection(tName, "create", .tExisted), "the disposable wallet collection exists before the removal attempt")

    Try {
        Do ..SeedInventoryRow(tProfile, "walletcollection", tName)

        Do ##class(OcuPilot.Test.FixtureFault).SetDeletesShouldFail(1)
        Kill tReports
        Set tSC = ##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tReports)
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do $$$AssertStatusOK(tSC, "Remove still returns OK -- a removal failure is a warn, never a propagated error (AD-25)")

        Set tWarned = 0
        Set tN = $Order(tReports(""))
        While tN '= "" {
            If (tReports(tN, "level") = "warn") && (tReports(tN, "message") [ "Could not delete the demo wallet collection fixture") Set tWarned = 1
            Set tN = $Order(tReports(tN))
        }
        Do $$$AssertTrue(tWarned, "the failed wallet collection delete is reported as a warn naming the object")
        Set tRowsRS = ##class(%SQL.Statement).%ExecDirect(, tCountSql, tProfile)
        Do $$$AssertTrue(tRowsRS.%Next(), "the inventory count query returns a row")
        Do $$$AssertEquals(tRowsRS.N, 1, "the inventory row is kept for a retry")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).WalletCollection(tName, "exists", .tLeft), "the collection can be re-checked")
        Do $$$AssertTrue(tLeft, "the collection is still there -- the delete genuinely failed")

        Kill tRetryReports
        Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).Remove(tProfile, .tRetryReports), "the retry Remove returns OK")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).WalletCollection(tName, "exists", .tAfter), "the collection can be re-checked after the retry")
        Do $$$AssertTrue('tAfter, "the retry removed the collection the failed attempt left behind")
        Set tAfterRS = ##class(%SQL.Statement).%ExecDirect(, tCountSql, tProfile)
        Do $$$AssertTrue(tAfterRS.%Next(), "the post-retry count query returns a row")
        Do $$$AssertEquals(tAfterRS.N, 0, "and purged the kept row")
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do ##class(OcuPilot.Test.FixtureFault).WalletCollection(tName, "delete", .tIgnored)
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Throw ex
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).WalletCollection(tName, "delete", .tIgnored), "cleanup found nothing left to remove, or removed it for real")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
}

/// <p>Insert one <class>OcuPilot.Kernel.State.Demo</class> inventory row through the
/// escalated frame, for the <code>Remove</code> tests' own disposable profiles.
/// <var>pScope</var> defaults to the literal <code>instance</code>, which is right for
/// the web application, SSL/TLS, X.509 and wallet collection kinds. A task row passes the install namespace,
/// exactly as <method>OcuPilot.Install.Fixture.CreateTask</method> records one.</p>
Method SeedInventoryRow(pProfile As %String, pKind As %String, pName As %String, pScope As %String = "instance")
{
    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = pProfile
    Set tRow.Kind = pKind
    Set tRow.Name = pName
    Set tRow.Scope = pScope
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow), "seeded one disposable inventory row")
}

}
