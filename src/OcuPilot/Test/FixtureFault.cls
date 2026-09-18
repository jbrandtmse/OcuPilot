/// <p>Fault-injection subclass of <class>OcuPilot.Install.Fixture</class> (rework
/// iteration 5), the same test-isolation-by-subclass shape
/// <class>OcuPilot.Test.MigrateFault</class>, <class>OcuPilot.Test.GateFixture</class> and
/// <class>OcuPilot.Test.DemoAppProbe</class> already use. Two independent faults, each
/// armed on demand and off by default:</p>
/// <ul>
/// <li><b>DW-57.</b> <method>OcuPilot.Install.Fixture.RemoveOne</method>'s status-checked
/// <code>Delete</code> branches (webapp / sslconfig / x509credential, and walletcollection through
/// <method>DeleteWalletCollection</method>) go
/// straight to <code>Security.Applications</code>, <code>Security.SSLConfigs</code>,
/// <code>%SYS.X509Credentials</code> and <code>%Wallet.Collection</code>, which no existing seam can make fail -- so those
/// branches, and the four <code>warn</code> reports they guard, ran only on their
/// success paths and a regression back to a bare <code>Do ...Delete(pName)</code> that
/// discarded the status left the whole suite green. Overriding the four
/// <code>Delete*</code> wrappers makes each one fail for real while the genuine,
/// unmodified <method>Remove</method>/<method>RemoveOne</method> pair still runs.</li>
/// <li><b>DW-52.</b> <method>OcuPilot.Install.Fixture.CreateTask</method> reads an id
/// from <method>TaskIds</method> and then opens it -- the task can be deleted between the
/// two reads. Overriding <method>TaskIds</method> (to hand back an id that cannot
/// resolve) and <method>OpenTask</method> (to return <code>$$$NULLOREF</code>) reproduces
/// that race deterministically, with no real task created, no
/// <code>%SYS.Task.RunNow</code> issued and no wait.</li>
/// </ul>
/// <p>Toggles live in process-private globals rather than properties, exactly as
/// <class>OcuPilot.Test.MigrateFault</class> does and for the identical reason: the real
/// code path makes fresh <code>##class(...)</code>/<code>..</code> class-method
/// dispatches that never carry an instance.</p>
Class OcuPilot.Test.FixtureFault Extends OcuPilot.Install.Fixture
{

/// <p>A disposable path this class owns outright, so that a caller who reaches
/// <method>OcuPilot.Install.Fixture.Create</method> on this subclass by mistake can never
/// touch the real <parameter>OcuPilot.Install.Fixture.APPPATH</parameter> that Stories 2.5
/// and 5.8 name literally.</p>
Parameter APPPATH = "/csp/ocupilottestfixturefault";

/// <p>The id <method>TaskIds</method> hands back while the DW-52 fault is armed -- high
/// enough that it cannot collide with a real <class>%SYS.Task</class> row, and never
/// actually opened (<method>OpenTask</method> refuses it while armed).</p>
Parameter VANISHEDTASKID = 999999999;

/// <p>Arm or disarm the DW-57 delete faults.</p>
ClassMethod SetDeletesShouldFail(pShouldFail As %Boolean)
{
    Set ^||OcuPilotFixtureFaultDeletes = pShouldFail
}

/// <p>Arm or disarm the DW-52 vanished-task fault.</p>
ClassMethod SetTaskShouldVanish(pShouldVanish As %Boolean)
{
    Set ^||OcuPilotFixtureFaultTaskGone = pShouldVanish
}

/// <p>Disarm both faults. Called from every driving test's own cleanup path, including
/// its <code>Catch</code>, so an exception can never leave a fault armed for a later test
/// in the same class run.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotFixtureFaultDeletes, ^||OcuPilotFixtureFaultTaskGone
}

/// <p>DW-57: fails on demand (default off), otherwise the real delete.</p>
ClassMethod DeleteWebApp(pName As %String) As %Status
{
    If +$Get(^||OcuPilotFixtureFaultDeletes, 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FixtureFault: induced web application delete failure")
    }
    Quit ##super(pName)
}

/// <p>DW-57 -- see <method>DeleteWebApp</method>.</p>
ClassMethod DeleteSslConfig(pName As %String) As %Status
{
    If +$Get(^||OcuPilotFixtureFaultDeletes, 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FixtureFault: induced SSL/TLS configuration delete failure")
    }
    Quit ##super(pName)
}

/// <p>DW-57 -- see <method>DeleteWebApp</method>.</p>
ClassMethod DeleteX509Credential(pName As %String) As %Status
{
    If +$Get(^||OcuPilotFixtureFaultDeletes, 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FixtureFault: induced X.509 credential delete failure")
    }
    Quit ##super(pName)
}

/// <p>DW-57 -- see <method>DeleteWebApp</method>.</p>
ClassMethod DeleteWalletCollection(pName As %String) As %Status
{
    If +$Get(^||OcuPilotFixtureFaultDeletes, 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FixtureFault: induced wallet collection delete failure")
    }
    Quit ##super(pName)
}

/// <p>Create, delete or probe one disposable wallet collection in <code>%SYS</code>, for the wallet
/// branch of the DW-57 test. <var>pAction</var> is <code>create</code> (a no-op when it exists),
/// <code>delete</code> (a real delete, never the faulted seam; a no-op when it does not exist) or
/// <code>exists</code>. Every action sets <var>pExists</var> to whether it existed on entry.</p>
ClassMethod WalletCollection(pName As %String, pAction As %String, Output pExists As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set pExists = ''##class(%Wallet.Collection).Exists(pName)
        If (pAction = "create") && 'pExists Set tSC = ##class(%Wallet.Collection).Create(pName, {"Resource": "%Admin_Wallet:USE"})
        If (pAction = "delete") && pExists Set tSC = ##class(%Wallet.Collection).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>DW-52: hands back one id that cannot resolve while the fault is armed (default
/// off), so <method>OcuPilot.Install.Fixture.CreateTask</method> takes its
/// already-exists branch and then fails to open the row -- exactly the state a real
/// concurrent deletion between the two reads produces.</p>
ClassMethod TaskIds(pTaskClass As %String, pTaskName As %String, pNamespace As %String, Output pIds) As %Status
{
    If +$Get(^||OcuPilotFixtureFaultTaskGone, 0) {
        Kill pIds
        Set pIds(1) = ..#VANISHEDTASKID
        Set pIds = 1
        Quit $$$OK
    }
    Quit ##super(pTaskClass, pTaskName, pNamespace, .pIds)
}

/// <p>DW-52 -- refuses to open the vanished id while the fault is armed.</p>
ClassMethod OpenTask(pId As %String) As %SYS.Task
{
    If +$Get(^||OcuPilotFixtureFaultTaskGone, 0) {
        Quit $$$NULLOREF
    }
    Quit ##super(pId)
}

/// <p>Opens the <code>%SYS</code> window <method>OcuPilot.Install.Fixture.CreateTask</method>
/// expects its caller to have opened (<method>OcuPilot.Install.Fixture.Create</method>
/// does so in production) and drives the real, unmodified method through inherited
/// <code>..</code> dispatch -- the only way to reach a <code>[ Private ]</code> method
/// whose body must run while <code>$NAMESPACE</code> is <code>%SYS</code>, since a fresh
/// <code>##class(OcuPilot.*)</code> dispatch from <code>%SYS</code> cannot resolve at all
/// (this story's Boundaries).</p>
ClassMethod DriveCreateTask(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Do ..CreateTask(pProfile, pInstallNs, .pReports, .pRows)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the three disposable <code>%SYS</code>-scoped objects the DW-57 test needs
/// <method>OcuPilot.Install.Fixture.RemoveOne</method> to attempt (and fail) to delete.
/// The objects have to genuinely exist, because each branch guards its delete with an
/// <code>Exists</code> check first. The certificate and key come from the real fixture's
/// own <code>[ Private ]</code> PEM helpers through inherited <code>..</code> dispatch,
/// so the test never re-types them.</p>
ClassMethod SeedRemovableObjects(pAppPath As %String, pSslName As %String, pCertAlias As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCertPem = ..DemoCertificatePem()
        Set tKeyPem = ..DemoPrivateKeyPem()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        If '##class(Security.Applications).Exists(pAppPath, .tE1, .tS1) {
            Set tProps("Type") = 2
            Set tProps("Enabled") = 0
            Set tProps("NameSpace") = ##class(%SYS.Namespace).Exists("HSCUSTOM")
            Set tProps("NameSpace") = $Select(tProps("NameSpace"): "HSCUSTOM", 1: "USER")
            Set tProps("Description") = "OcuPilot.Test.FixtureFault disposable object (DW-57)"
            Set tSC = ##class(Security.Applications).Create(pAppPath, .tProps)
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If '##class(Security.SSLConfigs).Exists(pSslName, .tE2, .tS2) {
            Set tSslProps("Description") = "OcuPilot.Test.FixtureFault disposable object (DW-57)"
            Set tSC = ##class(Security.SSLConfigs).Create(pSslName, .tSslProps)
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If '##class(%SYS.X509Credentials).Exists(pCertAlias, .tE3, .tS3) {
            Set tBegin = "-----BEGIN CERTIFICATE-----" _ $Char(10)
            Set tEnd = $Char(10) _ "-----END CERTIFICATE-----"
            Set tBody = $Piece($Piece(tCertPem, tBegin, 2), tEnd, 1)
            Set tX509 = ##class(%SYS.X509Credentials).%New()
            Set tX509.Alias = pCertAlias
            Set tX509.Certificate = $System.Encryption.Base64Decode(tBody)
            Set tX509.PrivateKeyType = "RSA"
            Set tX509.PrivateKey = tKeyPem
            Set tSC = tX509.Save()
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Report whether each of the three disposable objects still exists, so the DW-57 test
/// can assert that a failed delete really did leave them in place.</p>
ClassMethod SeededObjectsExist(pAppPath As %String, pSslName As %String, pCertAlias As %String, Output pApp As %Boolean, Output pSsl As %Boolean, Output pCert As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pApp = 0
    Set pSsl = 0
    Set pCert = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set pApp = ''##class(Security.Applications).Exists(pAppPath, .tE1, .tS1)
        Set pSsl = ''##class(Security.SSLConfigs).Exists(pSslName, .tE2, .tS2)
        Set pCert = ''##class(%SYS.X509Credentials).Exists(pCertAlias, .tE3, .tS3)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the three disposable objects for real, with the fault disarmed -- the DW-57
/// test's own cleanup, called from both its straight-line path and its
/// <code>Catch</code>.</p>
ClassMethod RemoveSeededObjects(pAppPath As %String, pSslName As %String, pCertAlias As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Do ..SetDeletesShouldFail(0)
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        ; Rework iteration 5 review: these used to be bare Do calls, so this helper returned
        ; $$$OK whatever happened and its caller's "cleanup removed ... for real" assertion
        ; could not fail -- the same discarded-status shape DW-57 exists to forbid. Every
        ; delete is attempted; the first failure is what comes back.
        If ##class(Security.Applications).Exists(pAppPath, .tE1, .tS1) {
            Set tDel1 = ##class(Security.Applications).Delete(pAppPath)
            If $$$ISERR(tDel1) && $$$ISOK(tSC) Set tSC = tDel1
        }
        If ##class(Security.SSLConfigs).Exists(pSslName, .tE2, .tS2) {
            Set tDel2 = ##class(Security.SSLConfigs).Delete(pSslName)
            If $$$ISERR(tDel2) && $$$ISOK(tSC) Set tSC = tDel2
        }
        If ##class(%SYS.X509Credentials).Exists(pCertAlias, .tE3, .tS3) {
            Set tDel3 = ##class(%SYS.X509Credentials).Delete(pCertAlias)
            If $$$ISERR(tDel3) && $$$ISOK(tSC) Set tSC = tDel3
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
