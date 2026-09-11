/// <p>Fault-injection tests for <class>OcuPilot.Install.Fixture</class> (rework iteration
/// 5), driven through <class>OcuPilot.Test.FixtureFault</class>: <b>DW-57</b> (the three
/// status-checked <code>Delete</code> branches in
/// <method>OcuPilot.Install.Fixture.RemoveOne</method>) and <b>DW-52</b> (a task deleted
/// between <method>OcuPilot.Install.Fixture.CreateTask</method>'s query and its open).</p>
/// <p>A separate class from <class>OcuPilot.Test.Demo</class> deliberately: that class's
/// shared <method>OcuPilot.Test.Demo.OnBeforeAllTests</method> runs the whole fixture
/// cascade, including the demo task's <code>RunNow</code> and its up-to-300-second wait.
/// Neither test here needs any of it, so neither pays for it -- and each uses its own
/// disposable names and profile, never the shared <code>"probe"</code> inventory.</p>
Class OcuPilot.Test.DemoFaults Extends %UnitTest.TestCase
{

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
        Set tN = $Order(tReports(""))
        While tN '= "" {
            If tReports(tN, "level") = "warn" {
                Set tMsg = tReports(tN, "message")
                If tMsg [ "Could not delete the demo web application fixture" Set tApps = 1
                If tMsg [ "Could not delete the demo SSL/TLS configuration fixture" Set tSsls = 1
                If tMsg [ "Could not delete the demo X.509 credential fixture" Set tCerts = 1
            }
            Set tN = $Order(tReports(tN))
        }
        Do $$$AssertTrue(tApps, "the failed web application delete is reported as a warn naming the object")
        Do $$$AssertTrue(tSsls, "the failed SSL/TLS configuration delete is reported as a warn naming the object")
        Do $$$AssertTrue(tCerts, "the failed X.509 credential delete is reported as a warn naming the object")

        Set tExistsSC = ##class(OcuPilot.Test.FixtureFault).SeededObjectsExist(tApp, tSsl, tCert, .tAppLeft, .tSslLeft, .tCertLeft)
        Do $$$AssertStatusOK(tExistsSC, "the three objects can be re-checked")
        Do $$$AssertTrue(tAppLeft, "the web application is still there -- the delete genuinely failed rather than the fault being ignored")
        Do $$$AssertTrue(tSslLeft, "the SSL/TLS configuration is still there")
        Do $$$AssertTrue(tCertLeft, "the X.509 credential is still there")
    } Catch ex {
        Do ##class(OcuPilot.Test.FixtureFault).Disarm()
        Do ##class(OcuPilot.Test.FixtureFault).RemoveSeededObjects(tApp, tSsl, tCert)
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
        Throw ex
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Test.FixtureFault).RemoveSeededObjects(tApp, tSsl, tCert), "cleanup removed the three disposable objects for real")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", tProfile)
}

/// <p><b>DW-52.</b> <method>OcuPilot.Install.Fixture.CreateTask</method> reads an id from
/// <method>TaskIds</method> and then opens it; another process can delete the task between
/// the two reads. Before this branch existed, a failed open fell through into the
/// <code>RunNow</code>/wait section and was ultimately reported as "did not reach the
/// suspended state within the wait window -- it remains scheduled", which names the wrong
/// cause: the task is not late, it is gone (and it is not scheduled either).</p>
/// <p><class>OcuPilot.Test.FixtureFault</class> reproduces the race deterministically --
/// an id that cannot resolve, and an open that refuses it -- so no real task is created,
/// no <code>%SYS.Task.RunNow</code> is issued and nothing is waited for.</p>
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
    Set tMisreported = 0
    Set tN = $Order(tReports(""))
    While tN '= "" {
        Set tMsg = tReports(tN, "message")
        If (tReports(tN, "level") = "warn") && (tMsg [ "vanished between the task query and the open") Set tVanished = 1
        If tMsg [ "did not reach the suspended state within the wait window" Set tMisreported = 1
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue(tVanished, "a task id deleted between the query and the open is reported as vanished, in its own warn")
    Do $$$AssertTrue('tMisreported, "and is never reported as 'not yet suspended, still scheduled', which would be false on both halves")
    Do $$$AssertTrue('$Data(tRows), "nothing is noted into the inventory for a task that no longer exists")
}

/// <p>Insert one <class>OcuPilot.Kernel.State.Demo</class> inventory row through the
/// escalated frame, for <method>TestRemoveReportsEveryFailedDelete</method>'s own
/// disposable profile. Scope is the literal <code>instance</code> for all three kinds it
/// seeds -- none of them is namespace-scoped.</p>
Method SeedInventoryRow(pProfile As %String, pKind As %String, pName As %String)
{
    Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tRow.Profile = pProfile
    Set tRow.Kind = pKind
    Set tRow.Name = pName
    Set tRow.Scope = "instance"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow), "seeded one disposable inventory row")
}

}
