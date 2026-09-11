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
/// <p><b>Correction (build-auto review, 2026-09-10):</b> the "no probe subclass here"
/// sentence below is now false in the narrow sense it stated -- <class>OcuPilot.Test.DemoAppProbe</class>
/// exists as a subclass of this class, but for path isolation (overriding
/// <parameter>APPPATH</parameter>), not for report capture. The original reasoning (the
/// report array is already a public output parameter) is still the correct answer to
/// "why no <class>OcuPilot.Test.InstallerProbe</class>-shaped capture subclass" and is
/// unchanged by <class>DemoAppProbe</class>'s existence.
/// <class>OcuPilot.Test.FixtureFault</class> (rework iteration 5) is a second such
/// subclass, for fault injection into the three <code>Delete</code> calls
/// <method>RemoveOne</method> makes and into <method>OpenTask</method>.</p>
/// <p><b>Correction at its origin (rework iteration 5, 2026-09-11) -- the error-log
/// fixture no longer depends on the Task Manager daemon.</b> An earlier version of
/// <method>CreateErrorEntry</method>'s own header concluded that "<code>%ETN</code>'s own
/// entry points accept no error payload, so there is nothing this class could call
/// directly even if it wanted to". The premise is true and the conclusion was wrong: this
/// class does not need to hand <code>%ETN</code> a payload, it can <b>raise its own real,
/// controlled runtime error and log that</b>. Verified live this pass:
/// <code>$$LOG^%ETN()</code> called from inside a <code>Catch</code> writes one entry into
/// the current namespace's <code>^ERRORS</code> synchronously and returns
/// <code>$ListBuild(&lt;$H day&gt;, &lt;entry number&gt;)</code> -- the entry's exact
/// identity -- with no daemon, no scheduled task and no wait. The seed must be a genuine
/// runtime error (one that sets <code>$ZError</code>), never a <code>Throw</code> of a
/// <class>%Exception.StatusException</class>, which leaves <code>$ZError</code> empty and
/// logs the useless placeholder <code>&lt;LOG ENTRY&gt;</code>. The separate observation
/// recorded beside the old conclusion -- that a bare <code>JOB</code> of a throwing
/// classmethod does not reach <code>^ERRORS</code> -- was re-read and remains correct; it
/// simply is not the route this class now takes. This is a return to the design this
/// story's own Design Notes already specify for DW-15 ("the fixture raises a real,
/// controlled error inside its own routine and lets the trap log it"), not an AC
/// amendment.</p>
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

/// <p>The <parameter>DEMOPREFIX</parameter>, suffixed for a non-production profile so a
/// probe run's fixture objects can never collide with -- or silently adopt -- production's
/// own unqualified names (review finding, HIGH, round 2: the <code>"probe"</code> test
/// profile's own SSL/TLS, X.509 and task fixtures used to share literal production names
/// outright, so <class>OcuPilot.Test.Demo</class>'s own class-level fixture run could
/// destroy a real, already-installed production fixture on the exact configuration this
/// story ships, <code>OCUPILOT_DEMO: "1"</code>). Matches
/// <method>OcuPilot.Install.Installer.Names</method>'s own <code>"Probe"</code> suffix
/// convention. Deliberately <b>not</b> applied to <parameter>APPPATH</parameter> -- that
/// path cannot be renamed at all (this class's header, DW-13) -- callers that need a
/// private, disposable web-application path use <class>OcuPilot.Test.DemoAppProbe</class>
/// instead. Public (not Private) so a test computes the exact resolved name directly
/// rather than hand-typing a copy that can drift from the production algorithm (Rule 19).</p>
ClassMethod ResolvedPrefix(pProfile As %String) As %String
{
    Quit ..#DEMOPREFIX _ $Select(pProfile = "probe": "Probe", 1: "")
}

/// <p>Create every fixture the opt-in flag governs, guard-then-act, for
/// <var>pProfile</var> (<code>""</code> production, <code>"probe"</code> the test
/// seam). Always returns <code>$$$OK</code> -- see this class's header.</p>
/// <p><var>pErrorEntryId</var> is the exact identity of the application-error entry
/// <method>CreateErrorEntry</method> seeded <b>and confirmed</b> on THIS call --
/// <code>"&lt;$H day&gt;,&lt;entry number&gt;"</code>, or <code>""</code> when no entry was
/// both seeded and read back. A seed whose read-back failed also leaves it <code>""</code>,
/// and the reports then carry the warn that says which step failed. Output so a caller
/// (<class>OcuPilot.Test.Demo</class>) can make its own independent assertion against the
/// entry this run actually produced rather than against "some entry from today", which is
/// the DW-61 false-green this replaced: the previous shape output a <code>$H</code>
/// boundary instead, because the fixture could not tell which entry it had produced.
/// <code>$$LOG^%ETN()</code>'s return value <b>is</b> that identity, so the ~59-second
/// same-minute false positive and the midnight-rollover false negative the boundary
/// apparatus was narrowing are both closed by construction rather than narrowed again.</p>
ClassMethod Create(pProfile As %String = "", ByRef pReports, Output pErrorEntryId As %String) As %Status
{
    Set pErrorEntryId = ""
    Set tOrigNS = $NAMESPACE
    Kill tRows
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        ; Read BEFORE the %SYS switch: Kernel.State.Demo is an OcuPilot class compiled
        ; only into the install namespace, and a fresh ##class(OcuPilot.*) dispatch from
        ; %SYS cannot resolve it at all -- see WebAppOwnedByProfile's own header.
        Set tWebAppOwned = ..WebAppOwnedByProfile(pProfile)

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Do ..Report(.pReports, "warn", "Demo fixtures could not switch to %SYS -- none were created this run", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }

        Do ..CreateWebApp(pProfile, tInstallNs, tWebAppOwned, .pReports, .tRows)
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
        Do ..CreateErrorEntry(pProfile, tInstallNs, .pReports, .tRows, .pErrorEntryId)
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
            If $$$ISERR(tExistsSC) {
                ; Review finding: an error status here (as opposed to a thrown
                ; exception, already caught below) fell through with no report at all --
                ; the fixture object was created but silently gained no inventory row,
                ; and no later Remove() could ever find it (AD-25). Every other failure
                ; in this class is reported; this one now is too.
                Do ..Report(.pReports, "warn", "Could not check whether an inventory row already exists -- the fixture object may have been created but was not recorded", {"kind": (tKind), "name": (tName), "error": ($System.Status.GetErrorText(tExistsSC))})
            } ElseIf 'tExists {
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

/// <p>Whether <var>pProfile</var>'s own inventory already records the web-application
/// fixture at <parameter>APPPATH</parameter> -- i.e. whether an application found there is
/// this profile's own earlier run's (reported as <code>info</code>) rather than a genuine
/// DW-13 collision (reported as <code>warn</code>). Returns <code>0</code> when the
/// inventory cannot be read, so an unreadable inventory is treated as a foreign collision:
/// the safe direction, since that branch touches nothing either way.</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> must be the install namespace</b>, never
/// <code>%SYS</code>. <class>OcuPilot.Kernel.State.Demo</class> is compiled only into the
/// install namespace, and a fresh <code>##class(OcuPilot.*)</code> dispatch from
/// <code>%SYS</code> fails with <code>&lt;CLASS DOES NOT EXIST&gt;</code> (verified live,
/// rework iteration 5) -- which is exactly how this check, when it lived inside
/// <method>CreateWebApp</method>, threw on every collision without anyone noticing.
/// <method>Create</method> and <method>OcuPilot.Test.DemoAppProbe.DriveCreateWebApp</method>
/// both call this before opening their <code>%SYS</code> window.</p>
ClassMethod WebAppOwnedByProfile(pProfile As %String) As %Boolean
{
    Set tOwned = 0
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Demo).GuardedRowExists(pProfile, "webapp", ..#APPPATH, .tExists)
        If $$$ISOK(tSC) Set tOwned = ''tExists
    } Catch ex {
        Set tOwned = 0
    }
    Quit tOwned
}

/// <p>DW-13. Creates the disabled, no-resource web application fixture only when
/// <parameter>APPPATH</parameter> is genuinely absent -- an application already there,
/// created by anyone else, is never modified, never enabled and never given a resource;
/// the collision is reported as a <code>warn</code> and no inventory row is written for
/// it, so a later <method>Remove</method> leaves it alone.</p>
/// <p><var>pOwnedByProfile</var> is <method>WebAppOwnedByProfile</method>'s answer, read
/// by the caller in the install namespace before the <code>%SYS</code> switch: true
/// downgrades an application already at the path from a DW-13 <code>warn</code> to an
/// <code>info</code> line, because it is this profile's own earlier run's fixture. Either
/// way the application is left exactly as found and nothing is noted.</p>
/// <p><b>Public, not <code>[ Private ]</code></b> (DW-62, rework iteration 5), the same
/// documented deviation <method>OcuPilot.Install.Installer.EnsureGrant</method> already
/// carries: <method>OcuPilot.Test.Demo.TestExistingApplicationIsNeverModified</method>
/// drives this one branch directly instead of paying <method>Create</method>'s whole
/// four-creator cascade (including <method>CreateTask</method>'s <code>RunNow</code>,
/// which until rework iteration 5 was followed by a wait of up to 300 seconds) to reach
/// it -- and, driving it directly, can assert the invariant that actually matters on a
/// collision, that <b>no row was noted into <var>pRows</var></b>, rather than inferring
/// it from a SQL count taken afterwards. <b>Caller contract:</b> <code>$NAMESPACE</code>
/// must already be <code>%SYS</code> (this method calls <code>Security.Applications</code>
/// directly, and <method>Create</method> switches before calling it); a caller that is not a subclass
/// cannot open that window and then reach this method, because a fresh
/// <code>##class(OcuPilot.*)</code> dispatch from <code>%SYS</code> fails outright (this
/// story's Boundaries) -- which is why the test drives it through
/// <method>OcuPilot.Test.DemoAppProbe.DriveCreateWebApp</method>'s inherited
/// <code>..</code> dispatch.</p>
ClassMethod CreateWebApp(pProfile As %String, pInstallNs As %String, pOwnedByProfile As %Boolean, ByRef pReports, ByRef pRows)
{
    Try {
        If ##class(Security.Applications).Exists(..#APPPATH, .tE, .tS) {
            ; Review finding (Fix Pack F-6, round 2): this used to report a warn
            ; unconditionally, so an install restarted with the flag still set
            ; (OCUPILOT_DEMO="1" on every start) logged a DW-13 collision against its
            ; OWN earlier run's fixture, every time. The ssl/x509/task guards already
            ; distinguish "owned by this profile's own inventory" (info) from "a
            ; genuine foreign collision" (warn); this does the same, through the one
            ; inventory check every other guard already uses.
            ;
            ; Rework iteration 5 (found by DW-62's direct test): F-6 made that
            ; inventory check HERE, as ##class(OcuPilot.Kernel.State.Demo).GuardedRowExists
            ; -- while $NAMESPACE is %SYS, where that class cannot resolve (verified
            ; live: <CLASS DOES NOT EXIST>). So this branch ALWAYS threw into the Catch
            ; below: a genuine foreign collision was reported as the generic "Demo web
            ; application fixture failed" rather than as DW-13, and the owned case F-6
            ; existed for never reached its info line. The object was still left
            ; untouched and nothing was noted (the Catch skips the create), which is why
            ; the previous test -- asserting only those two -- stayed green. The read
            ; now happens in the install namespace before the switch
            ; (WebAppOwnedByProfile) and arrives here as pOwnedByProfile.
            If pOwnedByProfile {
                Do ..Report(.pReports, "info", "Demo web application fixture already exists from an earlier run -- left untouched, not re-recorded in this run's inventory", {"path": (..#APPPATH)})
            } Else {
                Do ..Report(.pReports, "warn", "Demo fixture path already carries a web application this run did not create -- left untouched (DW-13)", {"path": (..#APPPATH)})
            }
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
        Set tName = ..ResolvedPrefix(pProfile) _ "TLS"
        If ##class(Security.SSLConfigs).Exists(tName, .tE, .tS) {
            ; Review finding (HIGH): this name carries no profile qualifier, so a
            ; SEPARATE profile's earlier run (or an operator) could have created the
            ; object this run is now finding -- adopting it into THIS profile's
            ; inventory would let a later Remove(pProfile) delete an object this run
            ; did not create (AD-25). Matching CreateWebApp's own DW-13 handling: an
            ; already-existing object is left exactly as found and is never noted into
            ; the inventory here. A genuine repeat install for the SAME profile already
            ; has its row from the original creation and needs no second one.
            Do ..Report(.pReports, "info", "Demo SSL/TLS configuration fixture already exists -- left untouched, not re-recorded in this run's inventory", {"name": (tName)})
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
        Set tAlias = ..ResolvedPrefix(pProfile) _ "Cert"
        If ##class(%SYS.X509Credentials).Exists(tAlias, .tE, .tS) {
            ; Review finding (HIGH): same cross-profile adoption hazard as
            ; CreateSslConfig's identical guard, two methods above -- see its comment.
            Do ..Report(.pReports, "info", "Demo X.509 credential fixture already exists -- left untouched, not re-recorded in this run's inventory", {"alias": (tAlias)})
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

/// <p>The <code>$Data(tIds)\10</code> guard <method>CreateTask</method> and
/// <method>RemoveOne</method> both need against <code>%SYS.TaskSuper.QueryTasks</code>'s
/// own subscript-0-based, possibly-empty result -- extracted into one Public,
/// independently-callable helper (Fix Pack F-1, F-7) so there is exactly one
/// implementation of this guard in the tree instead of three near-identical copies, and
/// so a regression test can drive the real guard directly instead of a retyped copy of
/// it that can never fail when the real one regresses (review finding, HIGH: the
/// original <class>OcuPilot.Test.Demo</class> regression pin for this guard tested such
/// a copy, because <method>CreateTask</method> is <code>[ Private ]</code>).</p>
/// <p><b>History, so the next reader does not "fix" this guard back to something
/// broken.</b> DW-53 attributed an earlier failure here to <code>"0 '= \"\" is FALSE"</code>
/// (the empty string numifying to 0) making a plain <code>tFirst '= ""</code> guard
/// silently drop an id at subscript 0 -- re-verified live, repeatedly, against this exact
/// API with a real single-match task: it does <b>not</b> reproduce. ObjectScript's
/// <code>'=</code>/<code>=</code> operators fall back to string comparison whenever
/// either side is not a canonical number, and <code>""</code> never is, so
/// <code>0 '= ""</code> is actually TRUE here. The real, confirmed hazard runs the other
/// way: <code>$Data(tIds(""))</code> -- dereferencing the literal empty string as an
/// explicit subscript, never <code>$Order</code>'s own seed argument -- throws
/// <code>&lt;SUBSCRIPT&gt;</code> unconditionally on this build, defined array or not,
/// which makes the seemingly obvious repair, <code>$Data(tIds(tFirst))</code>, itself
/// broken whenever <code>QueryTasks</code> matches nothing and <var>tFirst</var> is
/// genuinely <code>""</code>. <code>$Data(tIds)\10</code> settles both hazards
/// unconditionally: it is truthy only when <var>tIds</var> has at least one descendant
/// subscript (<code>$Data</code> of 10 or 11, never the bare-scalar 1 that would make
/// <code>$Order(tIds(""))</code> return <code>""</code> and the next line throw), so it
/// never depends on the "<code>QueryTasks</code> was observed returning 0 or 10 and never
/// 1" observation the bare <code>$Data(tIds)</code> form the first fix shipped had to
/// lean on.</p>
ClassMethod TaskIds(pTaskClass As %String, pTaskName As %String, pNamespace As %String, Output pIds) As %Status
{
    Set tSC = $$$OK
    Kill pIds
    Try {
        Set tSC = ##class(%SYS.TaskSuper).QueryTasks(pTaskClass, pTaskName, pNamespace, .tRaw)
        If $$$ISERR(tSC) Quit
        If '($Data(tRaw) \ 10) Quit
        Set tSub = $Order(tRaw(""))
        While tSub '= "" {
            Set pIds($Increment(pIds)) = tRaw(tSub)
            Set tSub = $Order(tRaw(tSub))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Open one <class>%SYS.Task</class> row by id, returning <code>$$$NULLOREF</code>
/// when it no longer resolves. The one seam <method>CreateTask</method> reads a task
/// through, so <class>OcuPilot.Test.FixtureFault</class> can force the DW-52
/// "vanished between the query and the open" branch deterministically, without racing a
/// real deletion. Production never overrides this. <b>Caller contract:</b>
/// <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
ClassMethod OpenTask(pId As %String) As %SYS.Task
{
    Quit ##class(%SYS.Task).%OpenId(pId)
}

/// <p>DW-14. The demo task, scheduled so that it suspends after a real run's real failure
/// -- <class>OcuPilot.Install.DemoTask</class>'s own header records exactly why a real run
/// is the only supported route to a populated <code>Suspended</code>/<code>Error</code>
/// pair, and what this build's <code>Status</code> value actually does (not what its own
/// doc comment claims). Idempotent: a task already <code>Suspended &gt; 0</code> from an
/// earlier run is left alone rather than re-triggered.</p>
/// <p><b>Never waits for the Task Manager (the owner's decision, 2026-09-11).</b> This
/// method creates the task, asks for one run through <code>%SYS.Task.RunNow</code>,
/// releases its object reference, reports, and returns. The Task Manager runs the task at
/// its next once-a-minute pass (every run observed on this build landed at a whole minute)
/// and the task suspends itself on its deliberate error, so the container's health check
/// can go green up to a minute before the demo task has actually suspended -- the accepted
/// trade, recorded in this story's Design Notes under DW-14. The one place that waits for
/// the suspended state is the test that pins it,
/// <method>OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError</method>, which re-reads
/// the task freshly on every poll and fails rather than skips.</p>
/// <p><b>Corrected at its origin (rework iteration 5).</b> This method used to wait up to
/// 300 seconds after <code>RunNow</code>, re-opening the task every 5 seconds, and its
/// comments explained the timeouts as the daemon's "own poll cycle" on a slow, long-lived
/// container -- which is why the budget had been widened from 90 to 300. Both halves of
/// that explanation were wrong. The re-open never reloaded: <code>%OpenId</code> on an
/// object this process already holds returns the in-memory OREF and reloads it only when
/// its concurrency is raised past 2 (<code>%Library.Persistent</code>'s
/// <code>%Open</code>), so the loop could not see the daemon's write however long it
/// waited. And the OREF this method kept alive across <code>RunNow</code> and the whole
/// wait kept the daemon from running the task at all until the wait ended: on a
/// genuinely fresh throwaway container the task ran 314 seconds after it was created,
/// 14 seconds after the 300-second wait gave up, and on the long-lived container 13 of 13
/// fixture tasks ran at creation plus six minutes. The lock behind the second half was
/// observed directly with a throwaway probe (rework iteration 5): right after
/// <code>RunNow</code> the caller's OREF reads <code>%Concurrency = 4</code> and the caller
/// owns an exclusive lock on <code>^SYS("Task","TaskD",id)</code> until it releases the OREF,
/// and a task held across a minute boundary was skipped at that pass and run at the first
/// pass after release. Releasing the OREF right after <code>RunNow</code> is what lets the
/// Task Manager take the task, so do not reintroduce a wait here.</p>
ClassMethod CreateTask(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows) [ Private ]
{
    Try {
        Set tName = ..ResolvedPrefix(pProfile) _ " nightly purge"
        Set tId = ""
        Kill tIds
        Set tQSC = ..TaskIds("OcuPilot.Install.DemoTask", tName, pInstallNs, .tIds)
        If $$$ISOK(tQSC) && $Data(tIds) {
            Set tId = tIds(1)
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
            Do ..NoteRow(.pRows, "task", tName, pInstallNs)
            Do ..Report(.pReports, "info", "Created the demo task fixture", {"name": (tName), "id": (tId)})
        } Else {
            Set tTask = ..OpenTask(tId)
            ; DW-52 (rework iteration 5): the id came from QueryTasks a few lines above,
            ; and the open that follows is a SECOND read -- another process (an operator,
            ; a concurrent Remove, another profile's uninstall) can delete the task
            ; between the two. Before this branch existed, a failed open fell straight
            ; through into RunNow and, while this method still waited afterwards, was
            ; reported as "did not reach the suspended state within the wait window",
            ; which names the wrong cause entirely: the task is not late, it is gone.
            ; Reported as its own warn instead, and the run stops here -- RunNow on an id
            ; that no longer resolves has nothing to schedule.
            If '$IsObject(tTask) {
                Do ..Report(.pReports, "warn", "Demo task fixture vanished between the task query and the open -- another process deleted it; nothing was run or recorded this run", {"name": (tName), "id": (tId)})
                Quit
            }
            ; Review finding (HIGH): this task's name carries no profile suffix, so a
            ; task created by a DIFFERENT profile's own earlier run (or by an operator)
            ; resolves here identically -- adopting it into THIS profile's inventory
            ; would let a later Remove(pProfile) delete an object this run did not
            ; create (AD-25). Matching CreateWebApp's own DW-13 collision handling: an
            ; already-existing task is never (re-)noted into the inventory here; a
            ; genuine repeat install for the SAME profile already has its row from the
            ; original creation and needs no second one.
            ; Correction (build-auto review, 2026-09-10): "left untouched" below used to
            ; overclaim -- the Suspended check and RunNow a few lines down still run for
            ; this branch too, so a not-yet-suspended task (belonging to this profile's
            ; own earlier run, or to a different profile entirely -- the name carries no
            ; profile suffix, and this story's own Design Notes explicitly declined to
            ; add one) is still actively run now via %SYS.Task.RunNow. Harmless in
            ; practice: the task's OnTask() always fails the same deliberate way
            ; regardless of who or what triggers the run, so this cannot corrupt another
            ; profile's state -- but the report text must not claim inaction that is not
            ; actually happening.
            Do ..Report(.pReports, "info", "Demo task fixture already exists -- not re-recorded in this run's inventory (may still be run now if not yet suspended)", {"name": (tName)})
        }

        If $IsObject(tTask) && (+tTask.Suspended > 0) {
            Do ..Report(.pReports, "info", "Demo task fixture already suspended after an earlier run", {"name": (tName)})
            Quit
        }

        Set tRunSC = ##class(%SYS.Task).RunNow(tId)
        ; Owner's decision (rework iteration 5): release the task object immediately, on
        ; both outcomes, and never wait. Holding this OREF across RunNow is what kept the
        ; daemon from running the task until this method returned -- see this method's
        ; own header.
        Set tTask = ""
        If $$$ISERR(tRunSC) {
            Do ..Report(.pReports, "warn", "Could not schedule the demo task fixture to run now", {"error": ($System.Status.GetErrorText(tRunSC))})
            Quit
        }
        ; The one report for the task's run. Its "requested a real run via
        ; %SYS.Task.RunNow" wording is the positive marker
        ; OcuPilot.Test.Demo.FixtureRequestedTaskRun() reads back, so a regression that
        ; deletes the RunNow call above is caught by name rather than surfacing only as a
        ; task that never ran (review finding, MED, round 2). Keep the phrase verbatim.
        Do ..Report(.pReports, "info", "Demo task fixture: requested a real run via %SYS.Task.RunNow -- install does not wait for it; the Task Manager runs it at its next once-a-minute pass and it suspends itself on its deliberate error", {"name": (tName), "id": (tId)})
    } Catch ex {
        Do ..Report(.pReports, "warn", "Demo task fixture failed", {"error": (ex.DisplayString())})
    }
}

/// <p>DW-15, AC12. <b>Seeds</b> one readable application-error entry into the install
/// namespace's own <code>^ERRORS</code> (AD-48's underlying store) and then confirms
/// exactly that entry -- deterministically, in the caller's own process, with no Task
/// Manager, no scheduled task and no wait.</p>
/// <p><b>Rework iteration 5 (2026-09-11): this method no longer harvests the demo task's
/// failure.</b> It used to scan <code>SYS.ApplicationError:ErrorList</code> for an entry
/// the Task Manager daemon writes when <class>OcuPilot.Install.DemoTask</class>'s
/// deliberate exception reaches it -- which made the DW-15 fixture race the daemon by
/// construction: <method>Create</method> calls this method immediately after
/// <method>CreateTask</method>, so on any run where the daemon had not yet serviced the
/// <code>RunNow</code> request there was nothing to find. <b>Corrected at its origin
/// (rework iteration 5):</b> this used to attribute that to the long-lived container and
/// to cite run 304 as the daemon delivering the entry 180 seconds later. Neither holds.
/// Until <method>CreateTask</method> stopped waiting, it was <b>every</b> run, on any
/// container: <method>CreateTask</method>'s own held task OREF kept the daemon from running
/// the task until its 300-second wait had ended (see its header), and run 304's
/// "180 seconds" came from a test that could not observe the task at all. The whole
/// <code>$H</code>-boundary/date-window/minute-flooring apparatus that grew around it
/// existed only because the fixture could not tell which entry it had produced. It now produces one itself and knows its identity exactly.</p>
/// <p><b>Mechanism, verified live this pass.</b> <method>SeedApplicationError</method>
/// raises a genuine runtime error inside this class's own routine and calls
/// <code>$$LOG^%ETN()</code> from the <code>Catch</code>: the entry lands in the current
/// namespace's <code>^ERRORS</code> synchronously, and the call returns
/// <code>$ListBuild(&lt;$H day&gt;, &lt;entry number&gt;)</code>. Because the error is
/// raised here, the logged text names this class's own routine
/// (<code>&lt;DIVIDE&gt;...^OcuPilot.Install.Fixture.1</code>) -- a marker nothing else on
/// the instance can produce, so the confirmation stays specific rather than regressing to
/// a bare <code>$Data(^ERRORS)</code> presence check (the round-2 MED finding). The
/// confirmation reads the entry back through <code>SYS.ApplicationError:ErrorList</code>,
/// the same supported query the Logs area (Story 5.13) will read, matched on its
/// <code>Error #</code> -- one exact row, never a date bucket.</p>
/// <p><b>Deliberately not guarded on "already seeded"</b>, unlike the four object
/// fixtures above. Guard-then-act protects <i>named objects</i> from being modified or
/// duplicated; an application-error entry has no name and no identity to collide with, it
/// is append-only log data, and AD-48 makes <code>^ERRORS</code> the Logs area's own data
/// -- Story 5.13's walkthrough <i>deletes</i> the seeded entries, so a fixture that
/// refused to re-seed after that delete would leave the next container start's
/// walkthrough with an empty Logs area, which is precisely what AC12 exists to prevent.
/// One entry per start, bounded by the instance's own application-error retention.</p>
ClassMethod CreateErrorEntry(pProfile As %String, pInstallNs As %String, ByRef pReports, ByRef pRows, Output pErrorEntryId As %String) [ Private ]
{
    Set pErrorEntryId = ""
    Set tOrigNS = $NAMESPACE
    Set tRSOpen = 0
    Try {
        ; ^ERRORS is namespace-scoped, so the seed must be raised while $NAMESPACE is the
        ; install namespace -- never %SYS's own log. Create() restores before calling
        ; this, so the switch below is normally a no-op; it exists so a caller that
        ; reaches this method from somewhere else still seeds the right namespace.
        If $NAMESPACE '= pInstallNs {
            Set tToInstallSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace(pInstallNs, .tOrigNS)
            If $$$ISERR(tToInstallSC) {
                Do ..Report(.pReports, "warn", "Could not seed the demo error-log fixture -- switching to the install namespace failed", {"namespace": (pInstallNs), "error": ($System.Status.GetErrorText(tToInstallSC))})
                Quit
            }
        }

        Set tSeedSC = ..SeedApplicationError(.tDay, .tNumber)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSeedSC) {
            Do ..Report(.pReports, "warn", "Could not seed the demo application-error log entry", {"error": ($System.Status.GetErrorText(tSeedSC))})
            Quit
        }

        ; SYS.ApplicationError exists only in %SYS (confirmed live: a %ResultSet built
        ; against it from the install namespace comes back not-an-object), and the target
        ; namespace travels as the query's own first parameter, never via $NAMESPACE.
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSwitchSC) {
            Do ..Report(.pReports, "warn", "Seeded the demo error-log fixture but could not confirm it -- switching to %SYS to read SYS.ApplicationError failed", {"error": ($System.Status.GetErrorText(tSwitchSC))})
            Quit
        }
        Set tFound = 0
        Set tMessage = ""
        Set tTime = ""
        Set tQueryFailed = 0
        Set tRS = ##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
        If $IsObject(tRS) {
            Set tRSOpen = 1
            Set tListSC = tRS.Execute(pInstallNs, $ZDate(tDay, 1))
            If $$$ISOK(tListSC) {
                While tRS.Next() {
                    If tRS.Get("Error #") = tNumber {
                        Set tFound = 1
                        Set tMessage = tRS.Get("Error message")
                        Set tTime = tRS.Get("Time")
                    }
                }
            } Else {
                Set tQueryFailed = 1
            }
            Do tRS.Close()
            Set tRSOpen = 0
        } Else {
            Set tQueryFailed = 1
        }
        Set $NAMESPACE = tOrigNS

        If tQueryFailed {
            Do ..Report(.pReports, "warn", "Seeded the demo error-log fixture but could not confirm it -- the SYS.ApplicationError:ErrorList query could not be constructed or executed", {"error": ($Select($$$ISERR($Get(tListSC,$$$OK)): $System.Status.GetErrorText(tListSC), 1: "ResultSet not constructed"))})
            Quit
        }
        If 'tFound || (tMessage = "") || (tTime = "") {
            Do ..Report(.pReports, "warn", "Seeded an application-error log entry but it did not read back with both readable text and a time (AC12)", {"entry": (tDay _ "," _ tNumber), "message": (tMessage), "time": (tTime)})
            Quit
        }

        Set pErrorEntryId = tDay _ "," _ tNumber
        ; Scope matches CreateTask's own NoteRow call: ^ERRORS is namespace-scoped, so the
        ; install namespace -- never the install profile -- is the correct value here.
        ; The Name is the fixture's stable identity, not this run's entry number: the
        ; inventory is a removal roster (AD-25/AD-37), and RemoveOne deliberately removes
        ; nothing for this Kind (^ERRORS is the Logs area's own data, deleted by its own
        ; confirmed delete tool, never by uninstall).
        Do ..NoteRow(.pRows, "errorentry", ..ResolvedPrefix(pProfile) _ " application error", pInstallNs)
        Do ..Report(.pReports, "info", "Seeded and confirmed one readable application-error log entry in the install namespace (DW-15)", {"entry": (pErrorEntryId), "namespace": (pInstallNs), "message": (tMessage), "time": (tTime)})
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        ; Fix Pack F-4 (round 2): a throw inside tRS.Next()/tRS.Get() used to land here
        ; with the result set still open -- the identical shape F-4's original pass
        ; fixed for the file handle in GatewayResponseTimeout, at the one site that
        ; sweep missed.
        If tRSOpen Do tRS.Close()
        Do ..Report(.pReports, "warn", "Could not seed or confirm the demo error-log fixture", {"error": (ex.DisplayString())})
    }
}

/// <p>Raise one genuine, controlled runtime error inside this class's own routine and
/// log it to the current namespace's <code>^ERRORS</code> through the <code>%ETN</code>
/// trap, returning the entry's exact identity in <var>pDay</var> (a <code>$H</code> day
/// number) and <var>pNumber</var> (that day's entry number).</p>
/// <p><b>A genuine runtime error, never a <code>Throw</code>.</b> Verified live this
/// pass: a <code>Throw</code> of a <class>%Exception.StatusException</class> leaves
/// <code>$ZError</code> empty, and <code>$$LOG^%ETN()</code> then logs the useless
/// placeholder <code>&lt;LOG ENTRY&gt;</code> with no readable text -- failing AC12's
/// "readable error text" outright. A real <code>&lt;DIVIDE&gt;</code> raised here logs
/// <code>&lt;DIVIDE&gt;SeedApplicationError+N^OcuPilot.Install.Fixture.1</code> together
/// with the offending source line, which is both readable and specific to this fixture.
/// The divisor is read out of a variable, not written as a literal <code>1/0</code>,
/// because the compiler folds the literal form at compile time.</p>
/// <p>Not overridden anywhere, in production or in a test. <b>Corrected (rework
/// iteration 5 review):</b> this used to say <class>OcuPilot.Test.FixtureFault</class>
/// overrides it to force the "the trap logged nothing" branch. It does not, so that
/// branch and the other <method>CreateErrorEntry</method> warns have no test of their own.
/// They are warn-only, and a fixture failure never fails install (AD-25).</p>
ClassMethod SeedApplicationError(Output pDay As %Integer, Output pNumber As %Integer) As %Status
{
    Set pDay = ""
    Set pNumber = ""
    Set tSC = $$$OK
    Set tLogged = ""
    Try {
        Set tZero = 0
        Set tUnreachable = ..#DEMOPREFIX / tZero
        ; Not reached: the line above always raises <DIVIDE>. Kept assigned so the
        ; compiler cannot discard the expression as unused.
        Set tSC = $$$ERROR($$$GeneralError, "The demo error-log seed did not raise its own deliberate error")
    } Catch ex {
        Set tLogged = $$LOG^%ETN()
    }
    If tLogged = "" {
        If $$$ISOK(tSC) {
            Set tSC = $$$ERROR($$$GeneralError, "The demo error-log seed raised its deliberate error but the %ETN trap recorded no entry")
        }
        Quit tSC
    }
    Set pDay = $List(tLogged, 1)
    Set pNumber = $List(tLogged, 2)
    Quit $$$OK
}

/// <p>Delete one web application. The one seam <method>RemoveOne</method>'s
/// <code>webapp</code> branch deletes through, so <class>OcuPilot.Test.FixtureFault</class>
/// can make the delete fail and the branch's own <code>%Status</code> check and
/// <code>warn</code> report be exercised for real (DW-57) -- without it, those three
/// branches ran only on their success paths and a regression back to a bare
/// <code>Do ...Delete(pName)</code> that discarded the status left the whole suite green.
/// Production never overrides this. <b>Caller contract:</b> <code>$NAMESPACE</code> must
/// already be <code>%SYS</code>.</p>
ClassMethod DeleteWebApp(pName As %String) As %Status
{
    Quit ##class(Security.Applications).Delete(pName)
}

/// <p>Delete one SSL/TLS configuration -- see <method>DeleteWebApp</method>.</p>
ClassMethod DeleteSslConfig(pName As %String) As %Status
{
    Quit ##class(Security.SSLConfigs).Delete(pName)
}

/// <p>Delete one X.509 credential -- see <method>DeleteWebApp</method>.</p>
ClassMethod DeleteX509Credential(pName As %String) As %Status
{
    Quit ##class(%SYS.X509Credentials).Delete(pName)
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
/// <p>When this keeps the inventory for a retry, <method>OcuPilot.Install.Installer.Uninstall</method>
/// sees the rows through <method>Remaining</method> and stops before it drops the
/// protected database that holds them (DW-65, rework iteration 6), so the "inventory left
/// in place so a later run can retry" warns below hold on the uninstall path too.</p>
ClassMethod Remove(pProfile As %String = "", ByRef pReports) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tInventoryReadable = 1
    ; Review finding (MED, round 2): a row that failed to open (error status, or a
    ; NULLOREF with no error) used to be silently skipped by the If with no Else --
    ; its object was never queued for removal below, yet the purge that follows still
    ; deleted the only record that it needed retrying. tReadComplete forces that purge
    ; closed the same way tInventoryReadable already does for a wholesale read failure.
    Set tReadComplete = 1
    Kill tKinds, tNames, tScopes
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
                Set tScopes(tI) = tRow.Scope
            } Else {
                Set tReadComplete = 0
                Set tRowErrText = $Select($$$ISERR(tRowSC): $System.Status.GetErrorText(tRowSC), 1: "row did not open")
                Do ..Report(.pReports, "warn", "Could not open one demo fixture inventory row -- its object may not be removed this run, and its row is left in place for a later retry", {"id": (tIds(tN)), "error": (tRowErrText)})
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

    ; Review finding: the two failure branches below (SwitchNamespace failing, and the
    ; unexpected-error Catch) used to fall through to the unconditional purge just past
    ; this block regardless -- removing nothing from %SYS while still deleting the only
    ; record of what needed removing. tRemovalOk gates that purge the same way
    ; tInventoryReadable gates the read phase above, and starts from tReadComplete
    ; (round 2) rather than an unconditional 1, so an incompletely-read inventory never
    ; gets purged either.
    ; DW-57 (rework iteration 5): the same hole existed one level down. A Delete that
    ; RemoveOne reported as failed left its object on the instance, and the purge below
    ; still ran and deleted the only record that it needed removing. RemoveOne now says
    ; whether its object is gone, and a single failure keeps the whole inventory in place.
    ; A retry is safe because every branch guards its Delete with an Exists check, so the
    ; objects that were removed this time are simply skipped next time.
    Set tRemovalOk = tReadComplete
    Set tObjectFailed = 0
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set tRemovalOk = 0
            Do ..Report(.pReports, "warn", "Demo fixture removal could not switch to %SYS -- nothing removed; inventory left in place so a later run can retry", {"error": ($System.Status.GetErrorText(tSC))})
            Quit
        }
        For tI = 1:1:$Get(tKinds) {
            If '..RemoveOne($Get(tKinds(tI)), $Get(tNames(tI)), $Get(tScopes(tI)), .pReports) {
                Set tObjectFailed = 1
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS
        Set tRemovalOk = 0
        Do ..Report(.pReports, "warn", "Demo fixture removal hit an unexpected error -- inventory left in place so a later run can retry", {"error": (ex2.DisplayString())})
    }

    If tRemovalOk && tObjectFailed {
        Set tRemovalOk = 0
        Do ..Report(.pReports, "warn", "At least one demo fixture object could not be removed -- inventory left in place so a later run can retry", {"profile": (pProfile)})
    }
    If tRemovalOk {
        Set tPurgeSC = ##class(OcuPilot.Kernel.State.Demo).DeleteByProfile(pProfile)
        If $$$ISERR(tPurgeSC) {
            Do ..Report(.pReports, "warn", "Demo fixture objects were removed but the inventory rows could not be purged", {"error": ($System.Status.GetErrorText(tPurgeSC))})
        }
    }
    Quit $$$OK
}

/// <p>Remove one named object by its recorded <var>pKind</var>/<var>pScope</var>, inside
/// the <code>%SYS</code> window <method>Remove</method> has already opened. The
/// <code>errorentry</code> kind has nothing to remove -- <code>^ERRORS</code> is left
/// alone, matching AD-48's "deletes are ordinary writes" scoping (they belong to the Logs
/// area's own confirmed delete tool, not to uninstall).</p>
/// <p>Every branch now checks its own <code>Delete</code> call's <code>%Status</code>
/// (review finding, HIGH): three of the four were bare <code>Do</code>s discarding it
/// silently, the same class of defect confirmed live for <code>%SYS.Task.%DeleteId</code>
/// (<code>ERROR #7415</code> when an id no longer resolves) and, per
/// <file>.claude/rules/objectscript-basics.md</file> ("do not silently discard write
/// failures") and this project's own Status-handling convention, never acceptable here
/// either.</p>
/// <p>Returns <code>1</code> when the object is gone -- removed now, already absent, or of
/// a kind with nothing to remove -- and <code>0</code> when a failure was reported, so
/// <method>Remove</method> keeps the inventory for a retry instead of purging the only
/// record of an object still on the instance (DW-57, rework iteration 5). An
/// unrecognized <var>pKind</var> returns <code>1</code>: nothing in this class could ever
/// remove it, so keeping the row would only repeat the same warn on every run.</p>
ClassMethod RemoveOne(pKind As %String, pName As %String, pScope As %String, ByRef pReports) As %Boolean [ Private ]
{
    Set tOk = 1
    Try {
        If pKind = "webapp" {
            If ##class(Security.Applications).Exists(pName, .tE1, .tS1) {
                Set tDelSC1 = ..DeleteWebApp(pName)
                If $$$ISERR(tDelSC1) {
                    Set tOk = 0
                    Do ..Report(.pReports, "warn", "Could not delete the demo web application fixture", {"name": (pName), "error": ($System.Status.GetErrorText(tDelSC1))})
                }
            }
        } ElseIf pKind = "sslconfig" {
            If ##class(Security.SSLConfigs).Exists(pName, .tE2, .tS2) {
                Set tDelSC2 = ..DeleteSslConfig(pName)
                If $$$ISERR(tDelSC2) {
                    Set tOk = 0
                    Do ..Report(.pReports, "warn", "Could not delete the demo SSL/TLS configuration fixture", {"name": (pName), "error": ($System.Status.GetErrorText(tDelSC2))})
                }
            }
        } ElseIf pKind = "x509credential" {
            If ##class(%SYS.X509Credentials).Exists(pName, .tE3, .tS3) {
                Set tDelSC3 = ..DeleteX509Credential(pName)
                If $$$ISERR(tDelSC3) {
                    Set tOk = 0
                    Do ..Report(.pReports, "warn", "Could not delete the demo X.509 credential fixture", {"name": (pName), "error": ($System.Status.GetErrorText(tDelSC3))})
                }
            }
        } ElseIf pKind = "task" {
            ; Review finding (MED): this used to query with namespace "" (every
            ; namespace) regardless of the inventory row's own recorded Scope (the
            ; install namespace CreateTask passed to NoteRow) -- uninstalling one
            ; namespace's fixtures could delete another namespace's identically-named
            ; demo task. pScope is now threaded through from Remove's own read of the
            ; inventory row.
            Kill tIds
            Set tQSC = ..TaskIds("OcuPilot.Install.DemoTask", pName, pScope, .tIds)
            ; Review finding (MED, round 2): a TaskIds failure used to fall through
            ; silently -- nothing deleted, nothing reported. Reported now, matching
            ; every other guard-then-act step in this class; $Data(tIds) false with
            ; tQSC OK is not an error (the task is simply already gone), so that case
            ; stays silent by design.
            If $$$ISERR(tQSC) {
                Set tOk = 0
                Do ..Report(.pReports, "warn", "Could not query for the demo task fixture to remove it", {"name": (pName), "error": ($System.Status.GetErrorText(tQSC))})
            } ElseIf $Data(tIds) {
                For tI = 1:1:$Get(tIds) {
                    Set tDelSC = ##class(%SYS.Task).%DeleteId(tIds(tI))
                    If $$$ISERR(tDelSC) {
                        Set tOk = 0
                        Do ..Report(.pReports, "warn", "Could not delete a demo task fixture", {"name": (pName), "id": (tIds(tI)), "error": ($System.Status.GetErrorText(tDelSC))})
                    }
                }
            }
        } ElseIf pKind = "errorentry" {
            ; By design (this class's header): ^ERRORS is namespace-scoped log data,
            ; never an install-created object -- nothing to remove. Explicit, not a
            ; fallthrough (review finding, MED, round 2), so a genuinely unrecognized
            ; Kind is never mistaken for this intentional no-op.
        } Else {
            Do ..Report(.pReports, "warn", "Unrecognized demo fixture inventory Kind -- nothing removed for this row", {"kind": (pKind), "name": (pName)})
        }
    } Catch ex {
        Set tOk = 0
        Do ..Report(.pReports, "warn", "Could not remove a demo fixture object", {"kind": (pKind), "name": (pName), "error": (ex.DisplayString())})
    }
    Quit tOk
}

/// <p>Every inventory row <var>pProfile</var> still carries, each with whether its object
/// is still on the instance -- what <method>OcuPilot.Install.Installer.Uninstall</method>
/// reads after <method>Remove</method> to decide whether it may drop the protected database
/// that holds this inventory (DW-65, the owner's decision, rework iteration 6).
/// <var>pLeft</var> is the row count, and <code>pLeft(n, ...)</code> carries
/// <code>"id"</code>, <code>"kind"</code>, <code>"name"</code>, <code>"scope"</code> and
/// <code>"state"</code>. The state is one of:</p>
/// <ul>
/// <li><code>still on the instance</code> -- the object this row names exists, so removing
/// the database would orphan it;</li>
/// <li><code>already removed</code> -- the object is gone and the row is only waiting for a
/// retry to purge it (<method>Remove</method> keeps the <i>whole</i> inventory when any one
/// object could not be removed);</li>
/// <li><code>nothing to remove</code> -- an <code>errorentry</code> row, whose
/// <code>^ERRORS</code> entry uninstall leaves alone by design (<method>RemoveOne</method>);</li>
/// <li><code>unrecognized kind</code>, <code>not checked</code> (the presence check itself
/// failed), or <code>row could not be read</code>.</li>
/// </ul>
/// <p>Returns an error only when the inventory itself cannot be read; the caller must then
/// treat the inventory as possibly non-empty. Reads in the install namespace, where
/// <class>OcuPilot.Kernel.State.Demo</class> is compiled, then opens one <code>%SYS</code>
/// window for the presence checks -- the ordering <method>Remove</method> uses.</p>
ClassMethod Remaining(pProfile As %String = "", Output pLeft) As %Status
{
    Set tSC = $$$OK
    Kill pLeft
    Set pLeft = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Demo).GuardedIdsForProfile(pProfile, .tIds)
        If $$$ISERR(tSC) Quit
        Set tN = $Order(tIds(""))
        While tN '= "" {
            Set tI = $Increment(pLeft)
            Set pLeft(tI, "id") = tIds(tN)
            Set tRow = $$$NULLOREF
            Set tRowSC = ##class(OcuPilot.Kernel.State.Demo).GuardedOpenId(tIds(tN), .tRow)
            If $$$ISOK(tRowSC) && $IsObject(tRow) {
                Set pLeft(tI, "kind") = tRow.Kind
                Set pLeft(tI, "name") = tRow.Name
                Set pLeft(tI, "scope") = tRow.Scope
                Set pLeft(tI, "state") = "not checked"
            } Else {
                Set pLeft(tI, "kind") = ""
                Set pLeft(tI, "name") = ""
                Set pLeft(tI, "scope") = ""
                Set pLeft(tI, "state") = "row could not be read"
            }
            Set tRow = ""
            Set tN = $Order(tIds(tN))
        }
        If 'pLeft Quit

        ; A presence check that cannot run leaves every row "not checked" -- the rows are
        ; still known, so the caller still refuses; only the detail is lost.
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSwitchSC) Quit
        For tI = 1:1:pLeft {
            If pLeft(tI, "kind") '= "" {
                Set pLeft(tI, "state") = ..ObjectState(pLeft(tI, "kind"), pLeft(tI, "name"), pLeft(tI, "scope"))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The <method>Remaining</method> state of one inventory row's object, using the same
/// existence checks <method>RemoveOne</method> guards its deletes with. <b>Caller
/// contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
ClassMethod ObjectState(pKind As %String, pName As %String, pScope As %String) As %String [ Private ]
{
    Set tState = "not checked"
    Try {
        If pKind = "webapp" {
            Set tState = $Select(##class(Security.Applications).Exists(pName, .tE1, .tS1): "still on the instance", 1: "already removed")
        } ElseIf pKind = "sslconfig" {
            Set tState = $Select(##class(Security.SSLConfigs).Exists(pName, .tE2, .tS2): "still on the instance", 1: "already removed")
        } ElseIf pKind = "x509credential" {
            Set tState = $Select(##class(%SYS.X509Credentials).Exists(pName, .tE3, .tS3): "still on the instance", 1: "already removed")
        } ElseIf pKind = "task" {
            Kill tIds
            Set tQSC = ..TaskIds("OcuPilot.Install.DemoTask", pName, pScope, .tIds)
            If $$$ISOK(tQSC) Set tState = $Select($Data(tIds): "still on the instance", 1: "already removed")
        } ElseIf pKind = "errorentry" {
            Set tState = "nothing to remove"
        } Else {
            Set tState = "unrecognized kind"
        }
    } Catch ex {
        Set tState = "not checked"
    }
    Quit tState
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
