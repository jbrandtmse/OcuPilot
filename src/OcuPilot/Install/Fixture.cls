/// <p>The five opt-in walkthrough fixtures (AD-25, AC9-AC12): a disabled web application
/// at <parameter>APPPATH</parameter> carrying no resource, a demo SSL/TLS configuration,
/// a self-signed X.509 credential, a task suspended after a real, controlled error
/// (DW-14), and at least one application-error-log entry (DW-15). Every one of them
/// except the web-application path carries the <parameter>DEMOPREFIX</parameter> name
/// prefix; the web application is namespaced by <i>behavior</i> instead, per this
/// story's Design Notes ("DW-13 -- addressed, with the branch taken and why").</p>
/// <p>A separate class from <class>OcuPilot.Install.Installer</class> deliberately (this
/// story's Design Notes, "Reading of AD-17's 'one installer class'"): the demo fixture is
/// a distinct, opt-in concern absent from the IPM path entirely, so folding it into the
/// one installer class would be the drift risk AD-17 guards against.</p>
/// <p><b>Guard-then-act, and every failure a warn that never fails the caller</b> --
/// <method>Create</method> and <method>Remove</method> always return
/// <code>$$$OK</code>; any internal problem is reported through <var>pReports</var>
/// (the same <code>{level, message, data}</code> shape
/// <class>OcuPilot.Install.Installer</class> uses) instead of propagating. Callers that
/// want the underlying detail read <var>pReports</var> directly -- there is no probe
/// subclass here, unlike <class>OcuPilot.Test.InstallerProbe</class>, because the report
/// array is already a public output parameter.</p>
/// <p>Switches to <code>%SYS</code> for the four <code>%SYS</code>-scoped fixtures
/// (Security.Applications/SSLConfigs/X509Credentials, %SYS.Task) and restores before the
/// error-log fixture, which must write into the <b>install namespace's own</b>
/// <code>^ERRORS</code> (DW-15, AC12) -- and before recording
/// <class>OcuPilot.Kernel.State.Demo</class> inventory rows, an OcuPilot class compiled
/// only into the install namespace (same ordering constraint as
/// <method>OcuPilot.Install.Installer.RecordStamp</method>).</p>
Class OcuPilot.Install.Fixture Extends %RegisteredObject
{

/// <p>The fixed web-application path Stories 2.5 and 5.8 name literally in their own
/// acceptance criteria -- this story's Design Notes explain why the path itself cannot be
/// namespaced (renaming it would be a cross-story AC change, a Rule 5 "ask first"
/// amendment, not a slice decision).</p>
Parameter APPPATH = "/csp/myapp";

/// <p>Name prefix every fixture object except <parameter>APPPATH</parameter> carries
/// (AC9).</p>
Parameter DEMOPREFIX = "OcuPilotDemo";

/// <p>How long, in seconds, <method>CreateTask</method> will wait for the real Task
/// Manager daemon to pick up and run the demo task after
/// <code>%SYS.Task.RunNow</code> -- a timeout here is reported as a warn, never a
/// failure (the task is left scheduled and will still run on its own; AD-25's fixture
/// failures never fail install).</p>
/// <p><b>Widened from 90 to 300 during this story's own review</b>: 90 seconds matches
/// the daemon's documented ~60-second poll cycle on a freshly-started instance (verified
/// live against a throwaway container), but this repository's long-lived, heavily
/// reused <code>ocupilot</code> development container -- the one every later story
/// depends on, after four stories' worth of repeated install/task-fixture cycling --
/// was observed, live, taking as long as ~150 seconds for the same daemon to service a
/// single <code>RunNow</code>, causing <class>OcuPilot.Test.Demo</class>'s
/// <code>TestDemoTaskIsSuspendedAfterAnError</code> to fail on that specific instance
/// even though the fixture itself worked correctly, just slower than the old budget
/// allowed. The same category of hazard as this project's own documented
/// <code>SYS.Database.DeleteDatabase</code> slowdown after repeated cycling -- a
/// long-lived, heavily churned instance is slower than a fresh one at some background
/// operations, and the margin must cover the slow case, not the common one.</p>
Parameter TASKWAITSECONDS As %Integer = 300;

/// <p>Append one report line, matching
/// <method>OcuPilot.Install.Installer.Report</method>'s shape exactly so a caller can
/// merge the two arrays with the identical drain loop
/// <method>OcuPilot.Install.Installer.FlushReports</method> already uses. A private
/// duplicate rather than a shared call: <method>OcuPilot.Install.Installer.Report</method>
/// is <code>[ Private ]</code>, reachable only from <class>Installer</class> and its own
/// subclasses, and this class is neither.</p>
ClassMethod Report(ByRef pReports, pLevel As %String, pMessage As %String, pData As %DynamicObject = "") [ Private ]
{
    Set tN = $Increment(pReports)
    Set pReports(tN, "level") = pLevel
    Set pReports(tN, "message") = pMessage
    Set pReports(tN, "data") = pData
}

/// <p>Create every fixture the opt-in flag governs, guard-then-act, for
/// <var>pProfile</var> (<code>""</code> production, <code>"probe"</code> the test
/// seam). Always returns <code>$$$OK</code> -- see this class's header.</p>
ClassMethod Create(pProfile As %String = "", ByRef pReports) As %Status
{
    Set tOrigNS = $NAMESPACE
    Kill tRows
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Demo fixtures could not switch to %SYS -- none were created this run", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }

        Do ..CreateWebApp(pProfile, tInstallNs, .pReports, .tRows)
        Do ..CreateSslConfig(pProfile, .pReports, .tRows)
        Do ..CreateX509Credential(pProfile, .pReports, .tRows)
        Do ..CreateTask(pProfile, tInstallNs, .pReports, .tRows)

        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..Report(.pReports, "warn", "Demo fixture creation hit an unexpected error and stopped early", {"error": (ex.DisplayString())})
    }

    ; The error-log fixture runs in the INSTALL namespace deliberately (DW-15, AC12):
    ; ^ERRORS is per-namespace, and the entry must land in this namespace's own log,
    ; never %SYS's.
    Try {
        Do ..CreateErrorEntry(pProfile, tInstallNs, .pReports, .tRows)
    } Catch ex2 {
        Do ..Report(.pReports, "warn", "Demo error-log fixture failed", {"error": (ex2.DisplayString())})
    }

    ; Record inventory rows now that we're back in the install namespace
    ; (Kernel.State.Demo is an OcuPilot class, compiled only there).
    Set tN = $Order(tRows(""))
    While tN '= "" {
        Set tKind = tRows(tN, "kind")
        Set tName = tRows(tN, "name")
        Set tScope = tRows(tN, "scope")
        Try {
            Set tExistsSC = ##class(OcuPilot.Kernel.State.Demo).GuardedRowExists(pProfile, tKind, tName, .tExists)
            If $$$ISOK(tExistsSC) && ('tExists) {
                Set tRow = ##class(OcuPilot.Kernel.State.Demo).%New()
                Set tRow.Profile = pProfile
                Set tRow.Kind = tKind
                Set tRow.Name = tName
                Set tRow.Scope = tScope
                Set tSaveSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
                If $$$ISERR(tSaveSC) {
                    Do ..Report(.pReports, "warn", "Fixture created but its inventory row could not be saved", {"kind": (tKind), "name": (tName)})
                }
            }
        } Catch ex3 {
            Do ..Report(.pReports, "warn", "Fixture inventory recording failed", {"kind": (tKind), "name": (tName), "error": (ex3.DisplayString())})
        }
        Set tN = $Order(tRows(tN))
    }
    Quit $$$OK
}

/// <p>DW-13. Creates the disabled, no-resource web application fixture only when
/// <parameter>APPPATH</parameter> is genuinely absent -- an application already there,
/// created by anyone else, is never modified, never enabled and never given a resource;
/// the collision is reported as a <code>warn</code> and no inventory row is written for
/// it, so a later <method>Remove</method> leaves it alone.</p>
ClassMethod CreateWebApp(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        If ##class(Security.Applications).Exists(..#APPPATH, .tE, .tS) {
            Do ..Report(.pReports, "warn", "Demo fixture path already carries a web application this run did not create -- left untouched (DW-13)", {"path": (..#APPPATH)})
            Quit
        }
        Set tProps("Type") = 2
        Set tProps("Enabled") = 0
        Set tProps("NameSpace") = pInstallNs
        Set tProps("Description") = "OcuPilot demo fixture (disabled, no resource) -- created by the opt-in walkthrough install"
        Set tSC = ##class(Security.Applications).Create(..#APPPATH, .tProps)
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Could not create the demo web application fixture", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }
        Do ..NoteRow(.pRows, "webapp", ..#APPPATH, "instance")
        Do ..Report(.pReports, "info", "Created the demo web application fixture (disabled, no resource)", {"path": (..#APPPATH)})
        ; AC8 (AD-17/AD-27): name the CSP Gateway registration gap for THIS web
        ; application, the same gap OcuPilot.Install.Installer.ReportGatewayGap reports
        ; for the applications Install() itself creates -- Install()'s own report always
        ; says "no web application was created by this run" because Install() never
        ; creates one; the fixture is the one thing in this story that does, so it must
        ; name the gap for itself rather than leaving it unreported.
        Do ..Report(.pReports, "info", "Security.Applications.Create does not notify the CSP Gateway -- this demo web application may 404 until an SMP Save or a Gateway restart", {"path": (..#APPPATH)})
    } Catch ex {
        Do ..Report(.pReports, "warn", "Demo web application fixture failed", {"error": (ex.DisplayString())})
    }
}

/// <p>The demo SSL/TLS configuration (AC9) -- deliberately not AD-32's
/// <b>ProviderPort</b> configuration, which the installer creates unconditionally and is
/// not a fixture. A plain, unused client-type configuration whose only purpose is to
/// appear in Story 2.7's list.</p>
ClassMethod CreateSslConfig(pProfile As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        Set tName = ..#DEMOPREFIX _ "TLS"
        If ##class(Security.SSLConfigs).Exists(tName, .tE, .tS) {
            Do ..NoteRow(.pRows, "sslconfig", tName, "instance")
            Do ..Report(.pReports, "info", "Demo SSL/TLS configuration fixture already exists", {"name": (tName)})
            Quit
        }
        Set tProps("Description") = "OcuPilot demo fixture -- not used for any outbound call"
        Set tSC = ##class(Security.SSLConfigs).Create(tName, .tProps)
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Could not create the demo SSL/TLS configuration fixture", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }
        Do ..NoteRow(.pRows, "sslconfig", tName, "instance")
        Do ..Report(.pReports, "info", "Created the demo SSL/TLS configuration fixture", {"name": (tName)})
    } Catch ex {
        Do ..Report(.pReports, "warn", "Demo SSL/TLS configuration fixture failed", {"error": (ex.DisplayString())})
    }
}

/// <p>The self-signed X.509 credential (AC9). Certificate and private key are a fixed,
/// checked-in 10-year self-signed pair generated for this fixture alone -- there is no
/// supported ObjectScript API to generate an X.509 certificate at install time
/// (<code>%SYSTEM.Encryption</code> reads and verifies certificates but does not create
/// them), and shelling out to an external tool from an install path was rejected as
/// exactly the undocumented-internals risk AD-27 exists to confine.</p>
ClassMethod CreateX509Credential(pProfile As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        Set tAlias = ..#DEMOPREFIX _ "Cert"
        If ##class(%SYS.X509Credentials).Exists(tAlias, .tE, .tS) {
            Do ..NoteRow(.pRows, "x509credential", tAlias, "instance")
            Do ..Report(.pReports, "info", "Demo X.509 credential fixture already exists", {"alias": (tAlias)})
            Quit
        }
        Set tCertPem = ..DemoCertificatePem()
        Set tKeyPem = ..DemoPrivateKeyPem()
        ; Same PEM-to-DER extraction %SYS.X509Credentials.LoadCertificate itself performs
        ; (irissys/%SYS/X509Credentials.cls) -- CertificateSet expects raw DER bytes, not
        ; the PEM text; the private key property, unlike the certificate, is stored as
        ; PEM text as-is.
        Set tBegin = "-----BEGIN CERTIFICATE-----" _ $Char(10)
        Set tEnd = $Char(10) _ "-----END CERTIFICATE-----"
        Set tBody = $Piece($Piece(tCertPem, tBegin, 2), tEnd, 1)
        Set tX509 = ##class(%SYS.X509Credentials).%New()
        Set tX509.Alias = tAlias
        Set tX509.Certificate = $System.Encryption.Base64Decode(tBody)
        Set tX509.PrivateKeyType = "RSA"
        Set tX509.PrivateKey = tKeyPem
        Set tSC = tX509.Save()
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Could not create the demo X.509 credential fixture", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }
        Do ..NoteRow(.pRows, "x509credential", tAlias, "instance")
        Do ..Report(.pReports, "info", "Created the demo self-signed X.509 credential fixture", {"alias": (tAlias)})
    } Catch ex {
        Do ..Report(.pReports, "warn", "Demo X.509 credential fixture failed", {"error": (ex.DisplayString())})
    }
}

/// <p>DW-14. The demo task, suspended after a real run's real failure --
/// <class>OcuPilot.Install.DemoTask</class>'s own header records exactly why a real run
/// is the only supported route to a populated <code>Suspended</code>/<code>Error</code>
/// pair, and what this build's <code>Status</code> value actually does (not what its own
/// doc comment claims). Idempotent: a task already <code>Suspended &gt; 0</code> from an
/// earlier run is left alone rather than re-triggered.</p>
ClassMethod CreateTask(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        Set tName = ..#DEMOPREFIX _ " nightly purge"
        Set tId = ""
        Kill tIds
        Set tQSC = ##class(%SYS.TaskSuper).QueryTasks("OcuPilot.Install.DemoTask", tName, pInstallNs, .tIds)
        ; QueryTasks populates tIds starting at subscript 0. DW-53 attributed a prior
        ; failure here to "0 '= "" is FALSE" (the empty string numifying to 0) making a
        ; plain tFirst '= "" guard silently drop that id -- re-verified live this rework
        ; pass, repeatedly, against this exact API with a real single-match task: it does
        ; NOT reproduce. ObjectScript's '=/= operators fall back to string comparison
        ; whenever either side is not a canonical number, and "" never is, so 0 '= "" is
        ; actually TRUE here (confirmed both with a plain local array and with a real
        ; QueryTasks-populated one). The real, confirmed hazard runs the other way:
        ; $Data(tIds("")) -- dereferencing the literal empty string as an explicit
        ; subscript, never $Order's own seed argument -- throws <SUBSCRIPT>
        ; ("Subscript 1 is \"\"") unconditionally on this build, defined array or not
        ; (confirmed live). That makes the seemingly obvious repair, $Data(tIds(tFirst)),
        ; itself broken whenever QueryTasks matches nothing and tFirst is genuinely ""
        ; (confirmed live: it throws where the original tFirst '= "" guard did not).
        ; Checking bare $Data(tIds) -- no subscript at all -- first sidesteps that real
        ; trap without leaning on DW-53's own, unconfirmed one.
        If $$$ISOK(tQSC) && $Data(tIds) {
            Set tFirst = $Order(tIds(""))
            Set tId = tIds(tFirst)
        }

        If tId = "" {
            Set tTask = ##class(%SYS.Task).%New()
            Set tTask.Name = tName
            Set tTask.Description = "OcuPilot demo fixture (DW-14): deliberately fails to demonstrate the suspended-after-error state read by Stories 2.8 and 5.11"
            Set tTask.NameSpace = pInstallNs
            Set tTask.TaskClass = "OcuPilot.Install.DemoTask"
            Set tTask.TimePeriod = 0
            Set tTask.TimePeriodEvery = 1
            Set tTask.DailyFrequency = 0
            Set tTask.DailyStartTime = 10800
            Set tTask.SuspendOnError = 1
            Set tTask.Expires = 0
            Set tSC = tTask.%Save()
            If $$$ISERR(tSC) {
                Do ..Report(.pReports, "warn", "Could not create the demo task fixture", {"error": ($System.Status.GetErrorText(tSC))})
                Quit
            }
            Set tId = tTask.%Id()
            Do ..Report(.pReports, "info", "Created the demo task fixture", {"name": (tName), "id": (tId)})
        } Else {
            Set tTask = ##class(%SYS.Task).%OpenId(tId)
        }

        Do ..NoteRow(.pRows, "task", tName, pInstallNs)

        If $IsObject(tTask) && (+tTask.Suspended > 0) {
            Do ..Report(.pReports, "info", "Demo task fixture already suspended after an earlier run", {"name": (tName)})
            Quit
        }

        Set tRunSC = ##class(%SYS.Task).RunNow(tId)
        If $$$ISERR(tRunSC) {
            Do ..Report(.pReports, "warn", "Could not schedule the demo task fixture to run now", {"error": ($System.Status.GetErrorText(tRunSC))})
            Quit
        }

        ; Wait for the real Task Manager daemon (verified live: its own poll cycle, not
        ; a fixed short delay) to run the task and populate Suspended/Error for real --
        ; see this class's TASKWAITSECONDS and DemoTask's own header.
        Set tWaited = 0
        Set tPollSeconds = 5
        While tWaited < ..#TASKWAITSECONDS {
            Hang tPollSeconds
            Set tWaited = tWaited + tPollSeconds
            Set tTask = ##class(%SYS.Task).%OpenId(tId)
            Quit:($IsObject(tTask) && (+tTask.Suspended > 0))
        }

        If $IsObject(tTask) && (+tTask.Suspended > 0) {
            Do ..Report(.pReports, "info", "Demo task fixture ran for real and is now suspended after its (deliberate) error", {"name": (tName), "error": (tTask.Error)})
        } Else {
            Do ..Report(.pReports, "warn", "Demo task fixture did not reach the suspended state within the wait window -- it remains scheduled and will still run on its own", {"name": (tName)})
        }
    } Catch ex {
        Do ..Report(.pReports, "warn", "Demo task fixture failed", {"error": (ex.DisplayString())})
    }
}

/// <p>DW-15. Confirms at least one readable entry landed in the install namespace's own
/// <code>^ERRORS</code> (AD-48's underlying store) -- <b>as a side effect of the demo
/// task fixture's own run</b>, not a second, independent error-seeding step.</p>
/// <p>Verified live, repeatedly, against this build: when
/// <class>OcuPilot.Install.DemoTask</class>'s deliberate exception reaches the real Task
/// Manager daemon (<method>CreateTask</method>'s own wait already blocks until that run
/// has happened), the daemon's own error handling writes a fully descriptive entry --
/// <code>&lt;THROW&gt;OnTask+1^OcuPilot.Install.DemoTask.1 *%Exception.StatusException
/// ERROR #5001: ...</code>, with a real time -- into this namespace's <code>^ERRORS</code>
/// automatically. <code>%ETN</code>'s own entry points
/// (<code>Do BACK^%ETN</code>, <code>$$LOG^%ETN()</code>) accept no error payload, so
/// there is nothing this class could call directly even if it wanted to; letting the
/// task's own real, controlled failure reach the trap is the only route, and it already
/// happened during <method>CreateTask</method>. This method only confirms the
/// observable and records its own inventory row.</p>
ClassMethod CreateErrorEntry(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        If '$Data(^ERRORS) {
            Do ..Report(.pReports, "warn", "This namespace's application error log is still empty after the demo task ran -- the DW-15 fixture could not be confirmed this run", "")
            Quit
        }
        ; Review finding: this used to pass pProfile ("" / "probe") as Scope, where
        ; every other fixture kind passes "instance" or the install namespace --
        ; inconsistent with Scope's own documented meaning ("where the object lives").
        ; ^ERRORS is namespace-scoped, so the install namespace is the correct value,
        ; matching CreateTask's own NoteRow call two methods above.
        Do ..NoteRow(.pRows, "errorentry", ..#DEMOPREFIX _ " nightly purge", pInstallNs)
        Do ..Report(.pReports, "info", "Confirmed this namespace's application error log carries at least one entry, from the demo task fixture's own deliberate failure", "")
    } Catch ex {
        Do ..Report(.pReports, "warn", "Could not confirm the demo error-log fixture", {"error": (ex.DisplayString())})
    }
}

/// <p>Record one <code>{kind, name, scope}</code> row to be saved as a
/// <class>OcuPilot.Kernel.State.Demo</class> inventory row once back in the install
/// namespace. Never called for the DW-13 collision branch -- that path notes nothing,
/// so <method>Remove</method> never touches an object this run did not create.</p>
ClassMethod NoteRow(ByRef pRows, pKind As %String, pName As %String, pScope As %String) [ Private ]
{
    Set tN = $Increment(pRows)
    Set pRows(tN, "kind") = pKind
    Set pRows(tN, "name") = pName
    Set pRows(tN, "scope") = pScope
}

/// <p>Remove every fixture <var>pProfile</var>'s inventory names, reading
/// <class>OcuPilot.Kernel.State.Demo</class> first (in the install namespace), removing
/// each named object (in <code>%SYS</code>), then purging the inventory rows themselves
/// -- the same three-phase, namespace-ordered shape
/// <method>OcuPilot.Install.Installer.Uninstall</method> already uses for
/// <class>OcuPilot.Kernel.State.Stamp</class>. Always returns <code>$$$OK</code>; a
/// removal failure is a warn (this class's header).</p>
ClassMethod Remove(pProfile As %String = "", ByRef pReports) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tInventoryReadable = 1
    Kill tKinds, tNames
    Try {
        Set tIdsSC = ##class(OcuPilot.Kernel.State.Demo).GuardedIdsForProfile(pProfile, .tIds)
        If $$$ISERR(tIdsSC) {
            ; Review finding: a returned error status (not a thrown exception) left
            ; tInventoryReadable at its initial 1, so the code below still purged the
            ; inventory rows via DeleteByProfile even though nothing was identified or
            ; removed from %SYS -- orphaning any fixture objects that existed. Set the
            ; same flag the Catch block below sets, so this path skips removal AND the
            ; purge identically.
            Set tInventoryReadable = 0
            Do ..Report(.pReports, "warn", "Could not read the demo fixture inventory -- nothing removed", {"error": ($System.Status.GetErrorText(tIdsSC))})
            Quit
        }
        Set tN = $Order(tIds(""))
        While tN '= "" {
            Set tRowSC = ##class(OcuPilot.Kernel.State.Demo).GuardedOpenId(tIds(tN), .tRow)
            If $$$ISOK(tRowSC) && $IsObject(tRow) {
                Set tI = $Increment(tKinds)
                Set tKinds(tI) = tRow.Kind
                Set tNames(tI) = tRow.Name
            }
            Set tN = $Order(tIds(tN))
        }
    } Catch ex {
        ; Argumented Quit is not allowed inside Try/Catch (ERROR #1043) -- a flag
        ; checked after this block, not a Quit here, is what skips the removal phase
        ; below (.claude/rules/objectscript-basics.md).
        Set tInventoryReadable = 0
        Do ..Report(.pReports, "warn", "Reading the demo fixture inventory failed", {"error": (ex.DisplayString())})
    }
    If 'tInventoryReadable {
        Quit $$$OK
    }

    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Demo fixture removal could not switch to %SYS -- nothing removed", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }
        For tI = 1:1:$Get(tKinds) {
            Do ..RemoveOne($Get(tKinds(tI)), $Get(tNames(tI)), .pReports)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS
        Do ..Report(.pReports, "warn", "Demo fixture removal hit an unexpected error", {"error": (ex2.DisplayString())})
    }

    Set tPurgeSC = ##class(OcuPilot.Kernel.State.Demo).DeleteByProfile(pProfile)
    If $$$ISERR(tPurgeSC) {
        Do ..Report(.pReports, "warn", "Demo fixture objects were removed but the inventory rows could not be purged", {"error": ($System.Status.GetErrorText(tPurgeSC))})
    }
    Quit $$$OK
}

/// <p>Remove one named object by its recorded <var>pKind</var>, inside the
/// <code>%SYS</code> window <method>Remove</method> has already opened. The
/// <code>errorentry</code> kind has nothing to remove -- <code>^ERRORS</code> is left
/// alone, matching AD-48's "deletes are ordinary writes" scoping (they belong to the Logs
/// area's own confirmed delete tool, not to uninstall).</p>
ClassMethod RemoveOne(pKind As %String, pName As %String, ByRef pReports) [ Private ]
{
    Try {
        If pKind = "webapp" {
            If ##class(Security.Applications).Exists(pName, .tE1, .tS1) {
                Do ##class(Security.Applications).Delete(pName)
            }
        } ElseIf pKind = "sslconfig" {
            If ##class(Security.SSLConfigs).Exists(pName, .tE2, .tS2) {
                Do ##class(Security.SSLConfigs).Delete(pName)
            }
        } ElseIf pKind = "x509credential" {
            If ##class(%SYS.X509Credentials).Exists(pName, .tE3, .tS3) {
                Do ##class(%SYS.X509Credentials).Delete(pName)
            }
        } ElseIf pKind = "task" {
            Kill tIds
            Set tQSC = ##class(%SYS.TaskSuper).QueryTasks("OcuPilot.Install.DemoTask", pName, "", .tIds)
            ; See CreateTask's own header two methods above: DW-53's claimed
            ; "0 '= "" is FALSE" mechanism does not reproduce against this build
            ; (re-verified live this pass, including against this exact loop's own
            ; single-entry case). Unlike CreateTask, this loop never dereferences
            ; $Data with an explicit "" subscript either -- it only ever tests
            ; tI '= "" against a real $Order-returned value -- so it was never exposed
            ; to either the disproven hazard or the $Data(tIds("")) one; the bare
            ; $Data(tIds) check below is a harmless, consistency-only addition
            ; (Blind Hunter, this pass, correctly noting it changes nothing here). The
            ; real defect this loop had is the one fixed just below: %DeleteId's own
            ; %Status was silently discarded.
            If $$$ISOK(tQSC) && $Data(tIds) {
                Set tI = $Order(tIds(""))
                While tI '= "" {
                    ; Review finding (Edge Case Hunter, this rework pass): %DeleteId's
                    ; own %Status was discarded here (a bare "Do"). Confirmed live that
                    ; %DeleteId genuinely fails -- ERROR #7415 "Could not find task to
                    ; delete" -- when the id no longer exists (e.g. a duplicate-name
                    ; match already removed by an earlier cycle), which is exactly the
                    ; class of silent, swallowed failure that could leave a same-named
                    ; task behind while Remove still reports $$$OK. Checking and
                    ; reporting it is the same guard-then-act discipline every other
                    ; fixture removal in this method already follows.
                    Set tDelSC = ##class(%SYS.Task).%DeleteId(tIds(tI))
                    If $$$ISERR(tDelSC) {
                        Do ..Report(.pReports, "warn", "Could not delete a demo task fixture", {"name": (pName), "id": (tIds(tI)), "error": ($System.Status.GetErrorText(tDelSC))})
                    }
                    Set tI = $Order(tIds(tI))
                }
            }
        }
    } Catch ex {
        Do ..Report(.pReports, "warn", "Could not remove a demo fixture object", {"kind": (pKind), "name": (pName), "error": (ex.DisplayString())})
    }
}

/// <p>The demo X.509 credential's certificate, as PEM text (<method>CreateX509Credential</method>
/// decodes it to DER before setting <property>%SYS.X509Credentials.Certificate</property>).
/// Self-signed, RSA 2048, SHA-256, 10-year validity, generated once for this fixture
/// (<code>CN=OcuPilotDemo</code>) -- see this class's header for why it is a fixed,
/// checked-in pair rather than generated at install time.</p>
ClassMethod DemoCertificatePem() As %String [ Private ]
{
    Set tCert = ""
    Set tCert = tCert _ "-----BEGIN CERTIFICATE-----" _ $Char(10)
    Set tCert = tCert _ "MIIDYzCCAkugAwIBAgIUfCaES2gLfiNCx6wO8r0Si54vP48wDQYJKoZIhvcNAQEL" _ $Char(10)
    Set tCert = tCert _ "BQAwQTEVMBMGA1UEAwwMT2N1UGlsb3REZW1vMREwDwYDVQQKDAhPY3VQaWxvdDEV" _ $Char(10)
    Set tCert = tCert _ "MBMGA1UECwwMRGVtbyBGaXh0dXJlMB4XDTI2MDkxMDEyMjcyMVoXDTM2MDkwNzEy" _ $Char(10)
    Set tCert = tCert _ "MjcyMVowQTEVMBMGA1UEAwwMT2N1UGlsb3REZW1vMREwDwYDVQQKDAhPY3VQaWxv" _ $Char(10)
    Set tCert = tCert _ "dDEVMBMGA1UECwwMRGVtbyBGaXh0dXJlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A" _ $Char(10)
    Set tCert = tCert _ "MIIBCgKCAQEApH2gaJbgE3p+Fi+S1WaYQrVB+3LPKEdOO7V8uwJdYssu46gqLq5H" _ $Char(10)
    Set tCert = tCert _ "gGbbDGtH9kbG+hPl0czBOf09t0rwM1drz2lxi85SS2PKwhtYQpwOtlX+yafsx/lA" _ $Char(10)
    Set tCert = tCert _ "2dd6J7SRkJiXJ0dRFqJwOuTXIoLOx1Ex75i90RCxpL5+ZX3U9EIcIVoMdXOXP8F+" _ $Char(10)
    Set tCert = tCert _ "/C+3tLfeHKM9K1aGzxK7+NqBrZGyDhRHJWRBRD/JWA95ixIJHXviVIOcTRYiyLG8" _ $Char(10)
    Set tCert = tCert _ "2LZKriAq7wJHM13d8S/K7f9W4RA+ldRmgin7C6BZXw3+Wf3H+ZOASWOShczBdvIg" _ $Char(10)
    Set tCert = tCert _ "8AguF1vufbbaILy1T3ESFUZ2ewiPIhPJCQIDAQABo1MwUTAdBgNVHQ4EFgQUuNet" _ $Char(10)
    Set tCert = tCert _ "G8UFD3D8bs/c5R5bk4QO0fAwHwYDVR0jBBgwFoAUuNetG8UFD3D8bs/c5R5bk4QO" _ $Char(10)
    Set tCert = tCert _ "0fAwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAnJlxW1pb/0DW" _ $Char(10)
    Set tCert = tCert _ "Glzzl++StICdk8AHVwoQe9bkMa6vALlsNbSkC5DSIO1KvlHJF1v1fdSjPiDch7l+" _ $Char(10)
    Set tCert = tCert _ "8Kzxejnum4nFr5EODAIMBM77T8dtAMfpNC9JyoDgWqrqx9+isVVSdwA1UQ+vjq3Z" _ $Char(10)
    Set tCert = tCert _ "5o9LIghNopjOEqQjPFGQ7mPt/qhZ+AfHXYpCEcQ4lSIbPGFFRkSesNyjEd060KyO" _ $Char(10)
    Set tCert = tCert _ "1poKESQj2V8zH7IFKuYbJXvi+MXVwbNfcqvJVBWj24TVUKimPgyw9Fy3+uyMFR0f" _ $Char(10)
    Set tCert = tCert _ "YQIWxhLoEzPjByEhlFfWpEG3p69RHglB08XCT2QbuzaiYpR75g6IYhH/RKqC1pYa" _ $Char(10)
    Set tCert = tCert _ "yGOZK7kyNg==" _ $Char(10)
    Set tCert = tCert _ "-----END CERTIFICATE-----" _ $Char(10)
    Quit tCert
}

/// <p>The demo X.509 credential's matching private key, as PKCS#8 unencrypted PEM text --
/// see <method>DemoCertificatePem</method>.</p>
ClassMethod DemoPrivateKeyPem() As %String [ Private ]
{
    Set tKey = ""
    Set tKey = tKey _ "-----BEGIN PRIVATE KEY-----" _ $Char(10)
    Set tKey = tKey _ "MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCkfaBoluATen4W" _ $Char(10)
    Set tKey = tKey _ "L5LVZphCtUH7cs8oR047tXy7Al1iyy7jqCourkeAZtsMa0f2Rsb6E+XRzME5/T23" _ $Char(10)
    Set tKey = tKey _ "SvAzV2vPaXGLzlJLY8rCG1hCnA62Vf7Jp+zH+UDZ13ontJGQmJcnR1EWonA65Nci" _ $Char(10)
    Set tKey = tKey _ "gs7HUTHvmL3RELGkvn5lfdT0QhwhWgx1c5c/wX78L7e0t94coz0rVobPErv42oGt" _ $Char(10)
    Set tKey = tKey _ "kbIOFEclZEFEP8lYD3mLEgkde+JUg5xNFiLIsbzYtkquICrvAkczXd3xL8rt/1bh" _ $Char(10)
    Set tKey = tKey _ "ED6V1GaCKfsLoFlfDf5Z/cf5k4BJY5KFzMF28iDwCC4XW+59ttogvLVPcRIVRnZ7" _ $Char(10)
    Set tKey = tKey _ "CI8iE8kJAgMBAAECggEAC1NYhvcDbufnVE76fs3BdE9fX4kmRQ1S0Ebk04n8RNP9" _ $Char(10)
    Set tKey = tKey _ "UqC2pc/rXaaHVMWyttzk8J1L3LwKvlvGwu7qlrhhVI67qg7+yNDSSjbghvaQh0Ko" _ $Char(10)
    Set tKey = tKey _ "yDjzE0pAyjb9QsxanPB6sNJG3aZ50H5G50oHI39eTzNOt309I/0XPhTxw48lOXEJ" _ $Char(10)
    Set tKey = tKey _ "2qzpJlimdU1cjxQEy8f3ZdgwN2DY627hg73wCeaulHFA270br2Ic43ilOPPPVvS3" _ $Char(10)
    Set tKey = tKey _ "1G9KNry/WEdT3Xnx3/z9zrWe8aXsC8PETCSkxIvXq3lHjJWks13xhDUwhcuBVbO0" _ $Char(10)
    Set tKey = tKey _ "VaLMFHhVQR5w1IRWkGq6pKTA+3LeDtdyfkJr21nacQKBgQDbGCT9UMGoppdAm7IC" _ $Char(10)
    Set tKey = tKey _ "4Z5/+tF+WOMRSs2bbv5Q9Qf8fkIvnno9GRxrNEfvrTsiyT9gTkJZhj+Bof20tKyB" _ $Char(10)
    Set tKey = tKey _ "SNwd0H3Bk0kRRw8qwPEaKt+dCGIJ40+ZzgoJXY4M0iOinfTN+/BzAkeuYLr/VmoP" _ $Char(10)
    Set tKey = tKey _ "Wj4FJ+hVvYOnH6eMry1FCdzcmQKBgQDAMtlGAQX9Wuc5tYfA4BMz7ZAZf7/JacbP" _ $Char(10)
    Set tKey = tKey _ "E4Z2txJvHGGLBVjhXfGzRVlo6JpQF2S54ILORZNohUPXu1qxyXHKhHjykyq3M7XM" _ $Char(10)
    Set tKey = tKey _ "PON4rweGZHWdPjtUY/Cq1bC9r8dXM3Rh2LgI6hf29KwMy1wkUvKnv7oI+FFIDo/I" _ $Char(10)
    Set tKey = tKey _ "NLCKrTYl8QKBgDVIH+bC9vXO3cXGl3n/6I3zL3NspnwUFwCP86U4keKjyfDOt6eY" _ $Char(10)
    Set tKey = tKey _ "LcMcicoN9O22x4TiQ1yGO3eJL6v8rF8cmvtdMtgau5BKGbQqC/hzKMKFwWHqN/eN" _ $Char(10)
    Set tKey = tKey _ "lf9FE0Cm8iegBmL5vDYb/da4i4GBQHXPWnnihKwlVJkWJ6cdCwNZLK8xAoGAJVa7" _ $Char(10)
    Set tKey = tKey _ "lzoDq+DJIxD9Op9Nm7z/TbTf0YVXNkuYx99xGVzuJk/3oHDbz/QdFqB5ui2RR/sx" _ $Char(10)
    Set tKey = tKey _ "7ljd9mRNdc/UIs376VgrFxU4KzdEjlUV7BA06gsCPnYkmJSB4O56058envZEGe48" _ $Char(10)
    Set tKey = tKey _ "cp7n4PZPpnyrffMPaT96KNv1DoalsENsOMTFzEECgYAVI41hfAqWM0JRIU/an9oe" _ $Char(10)
    Set tKey = tKey _ "yS0Z6T38O8kAL8mtX2yywOlhS4StF6pGgt3Gh/3/PtUEt8vnlcExvXKJXpWFO0mf" _ $Char(10)
    Set tKey = tKey _ "h4sWInSebn+vFvYp53LdcCE9bLqplPn7lv4jmD3ICeSue3VjL513DBdQm73QAJ70" _ $Char(10)
    Set tKey = tKey _ "P19UUXYFQb2yWJrk1wzbRQ==" _ $Char(10)
    Set tKey = tKey _ "-----END PRIVATE KEY-----" _ $Char(10)
    Quit tKey
}

}
