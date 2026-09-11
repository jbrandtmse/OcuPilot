/// <p>OcuPilot's one installer class (AD-17). Creates, guard-then-act and idempotently,
/// a dedicated database holding OcuPilot's <b>globals only</b> (AD-9), a <code>%DB_</code>
/// resource guarding it that no ordinary role holds, the OcuPilot administrative resource
/// and a role granting it, a privileged routine application, one global mapping, and
/// registers and emits OcuPilot's audit events -- leaving OcuPilot's <b>code</b> in the
/// install namespace's normal database. Also unexpires the instance's documented default
/// account's password on a genuinely first install (AC14), forward-migrates OcuPilot's own protected state
/// against a version stamp (<class>OcuPilot.Kernel.State.Version</class>, AD-38, AC5/AC6),
/// reports the CSP Gateway registration gap and its response timeout as information
/// (AC8), and, under an explicit opt-in flag, creates and removes the five demo
/// walkthrough fixtures through <class>OcuPilot.Install.Fixture</class> (AD-25, AC9).
/// <method>StartPath</method> is the container start hook's single entry point (Story
/// 1.4); no web application is created here (Story 1.5).</p>
/// <p>Every ensure step below is guard-then-act: it creates the object when absent and
/// verifies-and-repairs it when present but drifted (AD-17) -- existence alone is never
/// read as "installed".</p>
/// <p><b>Verified on the instance: a namespace-mapped class cannot be dispatched once
/// <code>$NAMESPACE</code> has moved away from it.</b> <code>##class(X).Method()</code>
/// re-resolves <code>X</code> against whichever namespace's routine database is current
/// at the moment of <b>that specific call</b> -- not the namespace the calling code was
/// compiled in, and not a cross-namespace cache from an earlier call in the same job.
/// Concretely: once <code>Install</code> below has switched to <code>%SYS</code> (AD-16),
/// any further <code>##class(OcuPilot.*)</code> call -- to
/// <class>OcuPilot.Kernel.Audit.Log</class>, or even a second call to
/// <class>OcuPilot.Kernel.Utils</class> itself to switch back -- fails with
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code>, since OcuPilot's code is deliberately mapped
/// nowhere but the install namespace (AD-9). Two consequences, both load-bearing:</p>
/// <ol>
/// <li><b>Reports are deferred until after the namespace restore.</b> Ensure steps call
/// <method>Report</method> to append to a <var>pReports</var> array instead of logging
/// directly, and <method>Install</method> drains it through <method>FlushReports</method>
/// only once back in the install namespace. <method>FlushReports</method> reaches
/// <class>OcuPilot.Kernel.Audit.Log</class> through the <method>LogInfo</method> /
/// <method>LogWarn</method> seam (same shape as
/// <method>OcuPilot.Api.Error.LogError</method>), so a probe subclass
/// (<class>OcuPilot.Test.InstallerProbe</class>) can capture what was reported instead of
/// writing to the console log.</li>
/// <li><b>The restore back out of <code>%SYS</code> is a bare
/// <code>Set $NAMESPACE = ...</code></b>, not a second call into
/// <class>OcuPilot.Kernel.Utils</class> -- <method>OcuPilot.Kernel.Utils.RestoreNamespace</method>
/// still exists, is still this story's consumption of it (used by
/// <method>Install</method>'s own <b>entry</b> into <code>%SYS</code> via
/// <method>OcuPilot.Kernel.Utils.SwitchNamespace</method>, and directly tested in
/// <class>OcuPilot.Test.Installer</class>), but calling it a second time from inside the
/// namespace it would be restoring <b>out of</b> is exactly the failure mode above.</li>
/// </ol>
/// <p>This class never <code>Write</code>s.</p>
/// <p>All internal calls use <code>..</code> self-dispatch rather than a hardcoded
/// <code>##class(OcuPilot.Install.Installer)</code>, so a probe subclass's overrides
/// reach every ensure step in the call chain.</p>
Class OcuPilot.Install.Installer Extends %RegisteredObject
{

/// <p>The deployed schema version (AD-38). Advancing this is what a future story's
/// migration step is <i>for</i> -- add the next <method>MigrationStep</method> branch
/// first, then raise this number, never the other way round.</p>
Parameter SCHEMAVERSION As %Integer = 1;

/// <p>The deployed build identity, recorded on the version row alongside the schema
/// version (Story 1.5's DW-3: a stale browser bundle can eventually be prompted to
/// reload). Opaque and unversioned by this story.</p>
Parameter BUILDIDENTITY As %String = "dev";

/// <p>The single account <method>EnsureUnexpired</method> targets (AC2, AC14) --
/// deliberately a fixed constant, <b>not</b> <code>$Username</code>. <method>EnsureGrant</method>
/// grants the administrative role to whoever is actually running install, which is the
/// right target for a privilege grant; unexpiring exists for a different reason
/// entirely -- making the instance's own documented default credentials
/// (<code>_SYSTEM</code>/<code>SYS</code>, README.md and CLAUDE.md) work with no manual
/// step. Verified live in a genuinely fresh throwaway container that the two identities
/// differ: the <code>--after</code> hook's own <code>$Username</code> resolves to
/// <code>irisowner</code> (the container's OS-mapped IRIS account), never
/// <code>_SYSTEM</code> -- so unexpiring "whoever is running install" would leave
/// <code>_SYSTEM</code> expired and AC2 unmet.</p>
Parameter UNEXPIREACCOUNT As %String = "_SYSTEM";

/// <p>Resolve and validate the full set of object names for <var>pProfile</var>
/// (<code>""</code> for production, <code>"probe"</code> for the disposable test seam --
/// any other value is refused). Production names come from
/// <class>OcuPilot.Kernel.State.Base</class>'s own parameters, so
/// <class>Base</class> and the installer never carry two copies of the same string
/// (AD-10). The probe's names are suffixed derivatives, except the mapping pattern,
/// which is a wholesale distinct literal that does not begin with <code>OcuPilot</code>
/// -- deliberately not nested inside the production prefix, so the two global mappings
/// can never overlap (see this story's Design Notes, resolved reading 5).</p>
ClassMethod Names(pProfile As %String, Output pNames) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pNames
    Try {
        If (pProfile '= "") && (pProfile '= "probe") {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid profile '" _ pProfile _ "': must be '' or 'probe'")
            Quit
        }
        Set tIsProbe = (pProfile = "probe")
        Set tSuffix = $Select(tIsProbe: "Probe", 1: "")

        Set pNames("profile") = pProfile
        Set pNames("database") = ##class(OcuPilot.Kernel.State.Base).#DATABASENAME _ $ZConvert(tSuffix, "U")
        Set pNames("dbResource") = $Select(tIsProbe: "%DB_" _ pNames("database"), 1: ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE)
        Set pNames("adminResource") = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ tSuffix
        Set pNames("adminRole") = pNames("adminResource")
        Set pNames("application") = ##class(OcuPilot.Kernel.State.Base).#APPLICATION _ tSuffix
        Set pNames("mappingPattern") = $Select(tIsProbe: "ProbeOcuPilotState*", 1: ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN)
        Set pNames("eventSource") = ##class(OcuPilot.Kernel.State.Base).#AUDITSOURCE
        Set pNames("eventType") = ##class(OcuPilot.Kernel.State.Base).#AUDITTYPE
        Set pNames("eventName") = ##class(OcuPilot.Kernel.State.Base).#AUDITNAME _ tSuffix

        Set tDirName = $ZConvert(pNames("database"), "L")
        Set pNames("directory") = ##class(%File).NormalizeDirectory(tDirName, $System.Util.ManagerDirectory())
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The install namespace: <code>HSCUSTOM</code> when it exists on this instance,
/// else <code>USER</code>. <code>%SYS.Namespace</code> is a percent-package class,
/// reachable from any namespace without a switch.</p>
ClassMethod ResolveNamespace() As %String
{
    Quit $Select(##class(%SYS.Namespace).Exists("HSCUSTOM"): "HSCUSTOM", 1: "USER")
}

/// <p><b>Test-only</b> (AC13). A fresh <code>##class(OcuPilot.Install.Installer)</code>
/// dispatch issued while <code>$NAMESPACE</code> is <code>%SYS</code> or
/// <code>USER</code> cannot even reach <method>Install</method>'s own guard -- verified
/// live: IRIS re-resolves the class reference against whichever namespace's routine
/// database is current <b>at the moment of that specific call</b> (this class's own
/// header), and OcuPilot's code is mapped nowhere but the install namespace, so the
/// dispatch itself fails with <code>&lt;CLASS DOES NOT EXIST&gt;</code> before
/// <method>Install</method>'s body ever starts. This method reaches the guard the way a
/// real bug would: dispatched normally (so class resolution succeeds), it switches to
/// <code>%SYS</code> and then calls <method>Install</method> via inherited (<code>..</code>)
/// dispatch, which -- unlike a fresh <code>##class()</code> call -- does not re-resolve
/// the class, because it is already executing inside this class's own loaded routine
/// (the same reason every ensure step above can call <code>..</code> siblings while
/// switched). Restores the namespace unconditionally. Production code never calls this.</p>
/// <p><var>pNamespaceAfterInstall</var> captures <code>$NAMESPACE</code> immediately
/// after <method>Install</method> returns, <b>before</b> this method's own unconditional
/// restore below runs (review finding, MED): without it, every caller only ever observed
/// this seam's own blanket <code>Set $NAMESPACE = tOrig</code>, so
/// <class>OcuPilot.Test.Version.TestInstallRefusesFromWrongNs</class>'s assertion that
/// "the caller's namespace is unchanged" passed regardless of what
/// <method>Install</method>'s own guard actually did -- this seam's restore, not the
/// guard's, was the only thing a caller could ever observe (Rule 19: an assertion that
/// cannot fail is a defect, not a test).</p>
ClassMethod TestOnlyInstallFromSys(pProfile As %String, Output pNamespaceAfterInstall As %String) As %Status
{
    Set tOrig = $NAMESPACE
    Set tSC = $$$OK
    Set pNamespaceAfterInstall = ""
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrig)
        If $$$ISERR(tSwitchSC) {
            Set tSC = tSwitchSC
            Quit
        }
        Set tSC = ..Install(pProfile)
        Set pNamespaceAfterInstall = $NAMESPACE
    } Catch ex {
        Set pNamespaceAfterInstall = $NAMESPACE
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrig
    Quit tSC
}

/// <p>Append one report line to <var>pReports</var>, to be emitted later by
/// <method>FlushReports</method> -- see this class's header for why ensure steps cannot
/// log directly while switched to <code>%SYS</code>. <var>pReports</var> is an ordinary
/// local array, so storing <var>pData</var>'s OREF in it (rather than its serialization)
/// preserves object identity across the call, unlike a global or a process-private
/// <code>^||</code> array (<file>.claude/rules/objectscript-basics.md</file>).</p>
ClassMethod Report(ByRef pReports, pLevel As %String, pMessage As %String, pData As %DynamicObject = "") [ Private ]
{
    Set tN = $Increment(pReports)
    Set pReports(tN, "level") = pLevel
    Set pReports(tN, "message") = pMessage
    Set pReports(tN, "data") = pData
}

/// <p>Emit every line <var>pReports</var> collected, in order, through the
/// <method>LogInfo</method> / <method>LogWarn</method> seam. Call only after
/// <code>$NAMESPACE</code> is back in the install namespace -- see this class's header.</p>
ClassMethod FlushReports(ByRef pReports) [ Private ]
{
    Set tN = $Order(pReports(""))
    While tN '= "" {
        Set tLevel = $Get(pReports(tN, "level"))
        Set tMsg = $Get(pReports(tN, "message"))
        Set tData = $Get(pReports(tN, "data"))
        If tLevel = "warn" {
            Do ..LogWarn(tMsg, tData)
        } Else {
            Do ..LogInfo(tMsg, tData)
        }
        Set tN = $Order(pReports(tN))
    }
}

/// <p>The logging seam <method>FlushReports</method> calls through instead of naming
/// <class>OcuPilot.Kernel.Audit.Log</class> directly -- the same shape as
/// <method>OcuPilot.Api.Error.LogError</method> and
/// <method>OcuPilot.Kernel.Audit.Log.WriteConsole</method>, so
/// <class>OcuPilot.Test.InstallerProbe</class> can capture what an ensure step reported.
/// Production never overrides this.</p>
ClassMethod LogInfo(pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Info("install", pMessage, pData)
}

/// <p>See <method>LogInfo</method>.</p>
ClassMethod LogWarn(pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Warn("install", pMessage, pData)
}

/// <p>Install (or re-install) <var>pProfile</var>. Guard-then-act throughout, safe to
/// repeat (AD-17): every ensure step re-runs and reports its outcome even when the
/// object it manages already exists and is correct.</p>
/// <p><b>AC13's namespace guard is the first act</b>, before any object is created and
/// before any <code>%SYS</code> switch -- refuses immediately when called from anywhere
/// but the resolved install namespace, closing the <code>reopen_if</code> Story 1.3 left
/// on this exact gap. <b>AC6's downgrade refusal runs second</b>, for the identical
/// reason: reading the stored schema version needs no escalation and must settle
/// "changes nothing" before anything is touched.</p>
/// <p>The version row is written <b>last</b> (AD-38), after the <code>Try</code>/
/// <code>Catch</code> below, because it must run from the install namespace -- guaranteed
/// restored at every exit above -- and because a step's failure must still be recorded
/// on it (phase <code>failed</code>, the failing step named, the stored schema version
/// left untouched) rather than only a successful run reaching it.</p>
ClassMethod Install(pProfile As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tFailingStep = ""
    Set tStoredVersion = 0
    Kill tReports
    Try {
        ; The namespace guard runs before ANYTHING else -- even before Names() --
        ; because Names() itself unconditionally references
        ; ##class(OcuPilot.Kernel.State.Base) for the production profile's object names,
        ; and that fresh ##class() dispatch re-resolves against whatever namespace is
        ; CURRENT (this class's own header); verified live that calling it while
        ; $NAMESPACE is %SYS or USER raises <CLASS DOES NOT EXIST> on Kernel.State.Base,
        ; not this guard's own message. ResolveNamespace() itself is always safe --
        ; %SYS.Namespace is a %-package class reachable from any namespace.
        Set tInstallNs = ..ResolveNamespace()
        If tOrigNS '= tInstallNs {
            Set tSC = $$$ERROR($$$GeneralError, "Install must be called from the install namespace ('" _ tInstallNs _ "'), not '" _ tOrigNS _ "'")
            Quit
        }

        Set tFailingStep = "Names"
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit
        Set tFailingStep = ""

        ; Read the stored version row BEFORE switching to %SYS -- Kernel.State.Version is
        ; an OcuPilot class, mapped only into the install namespace (this class's own
        ; header). An ABSENT row is schema version 0, a genuinely first install -- never
        ; mistaken for a downgrade or for already-installed. A READ FAILURE is different
        ; from an absent row (review finding) and must not be folded into "first
        ; install": treating a transient read error as version 0 would silently replay
        ; every migration step against an already-migrated system, and would repeat the
        ; unexpire step on a system that is not genuinely on its first install. Fail
        ; closed instead, matching Phase()'s own "a read failure is never installed"
        ; discipline -- refuse rather than guess.
        ;
        ; Real defect, found live (Rule 3 throwaway-container verification, round 2):
        ; on a genuinely fresh instance -- the very first `docker compose up -d --wait`
        ; this story is FOR -- this read itself failed outright with
        ; "ERROR #868: Application OcuPilotState not found", because
        ; CurrentVersionRow's own escalation (Kernel.State.Base's GuardedOpenOneWhere*)
        ; needs that privileged routine application, and EnsureApplication -- the step
        ; that CREATES it -- has not run yet at this point in the method. Invisible on
        ; every instance this story's own suite runs against (the long-lived `ocupilot`
        ; container, whose OcuPilotState has existed since an early story), so no test
        ; ever exercised a TRULY first attempt until the throwaway container did.
        ; IsEscalationInfrastructureAbsent breaks the cycle: when the escalation
        ; application genuinely does not exist, nothing could possibly be recorded yet
        ; -- Version, Demo and Stamp all share that identical escalation and the
        ; identical protected database, created together -- so this outcome IS "no row
        ; exists yet", the contract GuardedCurrentForProfile's own header already
        ; promises, not a read error to fail closed on.
        Set tFirstInstall = 1
        Set tVerRow = $$$NULLOREF
        If '..IsEscalationInfrastructureAbsent(.tNames, .tReports) {
            Set tVerReadSC = ..CurrentVersionRow(pProfile, .tVerRow)
            If $$$ISERR(tVerReadSC) {
                Set tSC = tVerReadSC
                Quit
            }
        }
        If $IsObject(tVerRow) {
            Set tStoredVersion = tVerRow.SchemaVersion
            ; Review finding (MED): a row's mere PRESENCE used to mean tFirstInstall=0,
            ; so a first install that failed after Names() (almost every failure path
            ; writes a "failed" row -- see the post-Try/Catch block below) left a row
            ; behind, and every later start then read tFirstInstall=0 and skipped
            ; EnsureUnexpired for good -- while a clean `docker compose up -d --wait`
            ; promises no manual step (AC2). AC14's own wording ("only when this profile
            ; carries no version row") is the mechanism, not the promise; a failed
            ; attempt is not an install (Boundaries: "never unexpire on a start that is
            ; not the first install on this durable volume"). A row that reached
            ; "installed" at least once is still first-install=0 -- only a still-failed
            ; row keeps this profile eligible.
            ;
            ; Review finding (MED, round 2): the fix above read only the row's CURRENT
            ; phase, so the unexpire re-armed on ANY mature instance whose LATEST start
            ; happened to fail -- a successful install leaves the row "installed"; a
            ; later start that fails after Names() rewrites that same row to "failed"
            ; (the ElseIf tFailingStep '= "" block below), and the next start would then
            ; read "failed" and compute tFirstInstall=1 again, unexpiring an account the
            ; operator may have deliberately expired. EnsureVersion's "failed" write
            ; carries tStoredVersion (see two lines above and the post-Try/Catch block),
            ; which is 0 only when this profile has never once reached "installed" --
            ; so requiring SchemaVersion=0 as well as Phase="failed" is what actually
            ; makes the comment above ("a row that reached installed at least once is
            ; still first-install=0") true, rather than merely asserted.
            Set tFirstInstall = (tVerRow.Phase = "failed") && (tVerRow.SchemaVersion = 0)
        }

        Set tSC = ..PlanMigration(tStoredVersion)
        If $$$ISERR(tSC) Quit

        Set tFailingStep = "SwitchNamespace"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tFailingStep = "EnsureDatabaseResource"
        Set tSC = ..EnsureDatabaseResource(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureDatabase"
        Set tSC = ..EnsureDatabase(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureAdminResource"
        Set tSC = ..EnsureAdminResource(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureAdminRole"
        Set tSC = ..EnsureAdminRole(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureApplication"
        Set tSC = ..EnsureApplication(.tNames, tInstallNs, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureMapping"
        Set tSC = ..EnsureMapping(.tNames, tInstallNs, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureAuditEvent"
        Set tSC = ..EnsureAuditEvent(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureAuditingEnabled"
        Set tSC = ..EnsureAuditingEnabled(.tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureGrant"
        Set tSC = ..EnsureGrant(.tNames, .tGrantOutcome, .tGrantedUser, .tGrantCommand, $Username, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureUnexpired"
        Set tSC = ..EnsureUnexpired(..#UNEXPIREACCOUNT, tFirstInstall, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }

        ; Never fails install (AD-27's fallback) -- ReportGatewayGap always returns OK.
        Do ..ReportGatewayGap(.tReports)

        Set $NAMESPACE = tOrigNS
        Set tFailingStep = ""

        Set tFailingStep = "RunMigrations"
        Set tSC = ..RunMigrations(pProfile, tStoredVersion, .tReports)
        If $$$ISERR(tSC) Quit
        Set tFailingStep = ""

        Set tFailingStep = "RecordStamp"
        Set tSC = ..RecordStamp(.tNames, tGrantOutcome, tGrantedUser, tGrantCommand)
        If $$$ISERR(tSC) {
            Do ..Report(.tReports, "warn", "Install ran every ensure step but could not record the install stamp -- the run is reported as failed", {"profile": (pProfile)})
            Quit
        }
        Set tFailingStep = ""
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }

    If $$$ISOK(tSC) {
        ; Review finding: a failure here was only reported as a warn, never folded back
        ; into tSC -- Install() would return $$$OK while the version row (the one signal
        ; Api.Router's gate and the compose health check both read, AD-38) was never
        ; actually advanced to "installed". Fold it in, the same way RecordStamp's own
        ; failure already does two blocks above.
        Set tVerWriteSC = ..EnsureVersion(pProfile, "installed", "", ..#SCHEMAVERSION, .tNames, .tReports)
        If $$$ISERR(tVerWriteSC) {
            Do ..Report(.tReports, "warn", "Install completed every step but could not record the version row -- the run is reported as failed", {"error": ($System.Status.GetErrorText(tVerWriteSC))})
            Set tSC = tVerWriteSC
        }
    } ElseIf tFailingStep '= "" {
        Set tVerFailWriteSC = ..EnsureVersion(pProfile, "failed", tFailingStep, tStoredVersion, .tNames, .tReports)
        If $$$ISERR(tVerFailWriteSC) {
            Do ..Report(.tReports, "warn", "Install failed and could not record the failure on the version row either", {"error": ($System.Status.GetErrorText(tVerFailWriteSC))})
        }
    }

    ; Flushed after the Try/Catch rather than on the success path alone, so the lines the
    ; ensure steps collected survive EVERY exit: the argumentless Quit in each
    ; If $$$ISERR guard above lands here too. Before this, a run that repaired three
    ; objects and then failed on the fourth discarded every report it had already
    ; collected -- including "Repaired the database's drifted guarding resource" -- which
    ; contradicts AC8's "the drift is repaired and the repair is reported". Safe at this
    ; point because $NAMESPACE is restored at every one of those guards and in the Catch,
    ; so FlushReports can always reach OcuPilot.Kernel.Audit.Log (see this class's header).
    Do ..FlushReports(.tReports)
    Quit tSC
}

/// <p>The container start hook's single entry point (Story 1.4;
/// <file>scripts/container-start.sh</file> is the hook's own shell side). Repeats
/// <method>Install</method>'s namespace guard as its own first act, before delegating to
/// it, so a caller that invokes <method>StartPath</method> from the wrong namespace is
/// refused identically (AC13) rather than reaching <method>Install</method> and being
/// refused a frame later. Always installs the production profile
/// (<code>""</code>); only when that succeeds, and only when <var>pDemo</var> is true,
/// creates the five opt-in demo fixtures through <class>OcuPilot.Install.Fixture</class>
/// (AD-25) -- there is no reason to seed a walkthrough on top of a failed install.</p>
ClassMethod StartPath(pDemo As %Boolean = 0) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tInstallNs = ..ResolveNamespace()
    If tOrigNS '= tInstallNs {
        Quit $$$ERROR($$$GeneralError, "StartPath must be called from the install namespace ('" _ tInstallNs _ "'), not '" _ tOrigNS _ "'")
    }

    Set tSC = ..Install("")
    If $$$ISERR(tSC) Quit tSC

    If pDemo {
        Kill tFixtureReports
        Do ##class(OcuPilot.Install.Fixture).Create("", .tFixtureReports)
        ; Merge the fixture's own report array into a fresh one and drain it through
        ; this class's seam -- Fixture.cls cannot reach OcuPilot.Kernel.Audit.Log itself
        ; while it is switched to %SYS (this class's own header explains why), and
        ; Installer.Report/FlushReports are [ Private ], so this is the one merge point.
        Kill tReports
        Set tN = $Order(tFixtureReports(""))
        While tN '= "" {
            Do ..Report(.tReports, tFixtureReports(tN, "level"), tFixtureReports(tN, "message"), tFixtureReports(tN, "data"))
            Set tN = $Order(tFixtureReports(tN))
        }
        Do ..FlushReports(.tReports)
    }

    Quit $$$OK
}

/// <p>Read <var>pProfile</var>'s current version row -- the one seam
/// <method>Phase</method>, <method>GateStatus</method>, <method>Install</method> and
/// <method>EnsureVersion</method> all read through, so a test subclass
/// (<class>OcuPilot.Test.Version</class>) can force the "read failed" branch without
/// needing a genuinely corrupted protected database. Production never overrides this.</p>
ClassMethod CurrentVersionRow(pProfile As %String, Output pRow) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Version).GuardedCurrentForProfile(pProfile, .pRow)
}

/// <p>Whether <var>pNames</var>'s privileged routine application (the one every
/// <class>OcuPilot.Kernel.State.Base</class>-derived escalation needs) does not exist
/// yet -- checked with its own brief, self-contained <code>%SYS</code> switch and
/// restore, entirely before <method>CurrentVersionRow</method> is ever called, because
/// that read needs the escalation this infrastructure provides and, on a genuinely
/// first install, nothing has created it yet (see <method>Install</method>'s own
/// comment at its call site for the live-verified defect this closes).</p>
/// <p>On any failure of its own (a switch that cannot complete, an unexpected
/// exception) this defaults to <code>0</code> ("assume present, take the normal read
/// path") -- exactly <method>Install</method>'s own pre-existing fail-closed behavior
/// for that read, so a failure here never makes anything less safe than before this
/// method existed.</p>
/// <p><var>pReports</var> (review finding, build-auto step-04 review pass, 2026-09-11):
/// reports once, at <code>info</code> level, only when the escalation infrastructure is
/// genuinely absent -- the notable, rare branch (a real, first-ever install on this
/// durable volume) -- matching this class's "guard-then-act... reports through
/// Kernel.Audit.Log" convention for every other decision point in this file. The
/// routine (already-present) branch stays silent, like the file's other steps that only
/// report when they take or skip a non-default action.</p>
ClassMethod IsEscalationInfrastructureAbsent(ByRef pNames, ByRef pReports) As %Boolean [ Private ]
{
    Set tAbsent = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tAbsent = '##class(Security.Applications).Exists(pNames("application"), .tE, .tS)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tAbsent = 0
    }
    If tAbsent {
        Do ..Report(.pReports, "info", "Escalation infrastructure not found yet -- this is a genuinely first install on this durable volume", {"application": ($Get(pNames("application")))})
    }
    Quit tAbsent
}

/// <p>Golden example -- the phase read must never fail open (this story's Design Notes).
/// A read failure or an absent row is <code>installing</code>, never
/// <code>installed</code>: the protected database may not exist yet on a genuinely
/// first start.</p>
ClassMethod Phase() As %String
{
    Set tPhase = "installing"
    Try {
        Set tSC = ..CurrentVersionRow("", .tRow)
        If $$$ISERR(tSC) Quit
        If $IsObject(tRow) Set tPhase = tRow.Phase
    } Catch {
        Set tPhase = "installing"
    }
    Quit tPhase
}

/// <p>The deployed schema version -- <parameter>SCHEMAVERSION</parameter>, exposed as a
/// method so <class>OcuPilot.Api.Router</class>'s gate and any later consumer never read
/// the class parameter directly.</p>
ClassMethod DeployedSchemaVersion() As %Integer
{
    Quit ..#SCHEMAVERSION
}

/// <p>The single decision <class>OcuPilot.Api.Router</class>'s traffic gate renders
/// (AD-38, AC7): <code>installed</code> only when the production version row's phase is
/// <code>installed</code> <b>and</b> its stored schema version is at least the deployed
/// one; otherwise <code>installing</code>, <code>failed</code>, or
/// <code>upgraderequired</code>. Built on <method>Phase</method>'s own fail-closed
/// discipline -- a read failure or an absent row is never <code>installed</code>.</p>
ClassMethod GateStatus() As %String
{
    ; Review finding: reading the version row twice (once via Phase(), once more
    ; here for SchemaVersion) let phase and schema version come from two different
    ; instants if the row changed in between. One read, deriving both from the same
    ; row object, removes that window.
    Set tPhase = "installing"
    Set tStoredVersion = 0
    Try {
        Set tSC = ..CurrentVersionRow("", .tRow)
        If $$$ISOK(tSC) && $IsObject(tRow) {
            Set tPhase = tRow.Phase
            Set tStoredVersion = tRow.SchemaVersion
        }
    } Catch {
        Set tPhase = "installing"
        Set tStoredVersion = 0
    }
    If tPhase = "failed" Quit "failed"
    If tPhase '= "installed" Quit "installing"
    If tStoredVersion < ..#SCHEMAVERSION Quit "upgraderequired"
    ; Review finding (MED): the ladder above had no branch for the one case
    ; PlanMigration refuses outright -- a stored version AHEAD of the deployed code
    ; (a downgrade). That left this method falling through to "installed", so after a
    ; refused downgrade (StartPath returns an error and the hook exits non-zero, but
    ; the compose health check reads this method, not the hook's exit code) the
    ; container would report healthy while old code served traffic against a newer
    ; schema -- AC3's "the health check never reports healthy" did not hold for this
    ; case. "installing" is reused rather than inventing a fourth code (Boundaries:
    ; never a second escalation/response-writer/envelope field) -- both states mean
    ; "not safe to serve yet", and AC6's own "changes nothing" is a guarantee about
    ; writes, never about what a read reports.
    If tStoredVersion > ..#SCHEMAVERSION Quit "installing"
    Quit "installed"
}

/// <p>Upsert <var>pProfile</var>'s <b>one</b> <class>OcuPilot.Kernel.State.Version</class>
/// row (AC2, AC4): updates the existing row in place when one exists, creates it
/// otherwise -- never a second row per profile. Called last in <method>Install</method>,
/// after every other step has already succeeded or failed (AD-38).</p>
/// <p><var>pNames</var> is <method>Install</method>'s own <var>tNames</var> array
/// (review finding, build-auto step-04 review pass): the escalation-infrastructure
/// check <method>Install</method>'s own version-row read already uses (see that
/// method's call site) was one-sided -- this method's IDENTICAL
/// <method>CurrentVersionRow</method> call had no equivalent guard, so a first
/// install that fails at or before <method>EnsureApplication</method> for any OTHER
/// reason (an <method>EnsureDatabaseResource</method>/<method>EnsureDatabase</method>
/// failure, say) would hit the same <code>ERROR #868</code> here, on the FAILURE-path
/// call this method also serves -- silently leaving the "failed" phase unrecorded
/// (only a warn logged) instead of written, so <method>Phase</method>'s own
/// "absent row resolves to installing" failsafe would report <code>installing</code>
/// forever rather than the <code>failed</code>-with-failing-step AC3 promises.</p>
ClassMethod EnsureVersion(pProfile As %String, pPhase As %String, pFailingStep As %String, pSchemaVersion As %Integer, ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tRow = $$$NULLOREF
        If '..IsEscalationInfrastructureAbsent(.pNames, .pReports) {
            Set tSC = ..CurrentVersionRow(pProfile, .tRow)
            If $$$ISERR(tSC) Quit
        }
        If '$IsObject(tRow) {
            Set tRow = ##class(OcuPilot.Kernel.State.Version).%New()
            Set tRow.Profile = pProfile
        }
        Set tRow.SchemaVersion = pSchemaVersion
        Set tRow.Phase = pPhase
        Set tRow.FailingStep = pFailingStep
        Set tRow.UpdatedAt = $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
        Set tRow.BuildIdentity = ..#BUILDIDENTITY
        Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
        If $$$ISERR(tSC) Quit
        Do ..Report(.pReports, $Select(pPhase = "failed": "warn", 1: "info"), "Recorded the version row", {"profile": (pProfile), "phase": (pPhase), "schemaVersion": (pSchemaVersion), "failingStep": (pFailingStep)})
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Unexpire <var>pAccount</var>'s password, on a genuinely first install only (AC14)
/// -- gated on <var>pFirstInstall</var>, which the caller derives from the version row's
/// absence and passes in, never recomputed here. The caller always passes
/// <parameter>UNEXPIREACCOUNT</parameter> (<code>_SYSTEM</code>), never
/// <code>$Username</code> -- see that parameter's own header for why. Never the
/// all-users form regardless: a single literal name is passed as <code>Names</code>,
/// which <code>Security.Users.UnExpireUserPasswords</code> documents as "Comma
/// separated list of user names, '*' = All" (<code>irissys/Security/Users.cls</code>) --
/// a single name targets only that one account.</p>
/// <p><b>Public, not <code>[ Private ]</code></b> -- the same documented deviation
/// <method>EnsureGrant</method> already carries, for the identical reason:
/// <class>OcuPilot.Test.Version</class> drives this directly with throwaway accounts, so
/// AC14's own test never needs to expire (or unexpire) <code>_SYSTEM</code> or route
/// through a full <method>Install</method> call.</p>
/// <p><b>Switches to <code>%SYS</code> itself, with a bare <code>Set $NAMESPACE</code>
/// -- never <code>##class(OcuPilot.Kernel.Utils).SwitchNamespace</code></b> (unlike
/// <method>EnsureGrant</method>, which relies on its caller already being switched):
/// <code>Security.Users</code> is mapped into <code>%SYS</code> only, and this is the
/// one Public ensure step whose direct-call test
/// (<class>OcuPilot.Test.Version</class>) drives it with a real, non-placeholder
/// account that genuinely reaches <code>Security.Users</code>. <b>Verified live that
/// the obvious fix -- calling <code>Kernel.Utils.SwitchNamespace</code> here -- breaks
/// the production call site</b>: <method>Install</method> calls this from
/// <i>already inside</i> its own <code>%SYS</code>-switched region, and a fresh
/// <code>##class(OcuPilot.Kernel.Utils)</code> dispatch issued while <code>$NAMESPACE</code>
/// is already <code>%SYS</code> is exactly the "further <code>##class(OcuPilot.*)</code>
/// call fails with <code>&lt;CLASS DOES NOT EXIST&gt;</code>" trap this class's own
/// header describes -- confirmed by reproducing it. A bare assignment needs no class
/// resolution at all, which is also why <method>Install</method>'s own restore uses one
/// instead of a second call into <code>Kernel.Utils</code>.</p>
ClassMethod EnsureUnexpired(pAccount As %String, pFirstInstall As %Boolean, ByRef pReports) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If 'pFirstInstall {
            Do ..Report(.pReports, "info", "Skipped the password-unexpire step -- a version row already exists for this profile, so this is not the first install", "")
            Quit
        }

        Set $NAMESPACE = "%SYS"

        If (pAccount = "") || (pAccount = "UnknownUser") || (pAccount = "_PUBLIC") || ('##class(Security.Users).Exists(pAccount, .tU, .tUS)) {
            Set $NAMESPACE = tOrigNS
            Do ..Report(.pReports, "info", "Skipped the password-unexpire step -- the named install account is not a usable account on this instance", {"user": (pAccount)})
            Quit
        }
        Set tSC = ##class(Security.Users).UnExpireUserPasswords(pAccount, .tCount)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        ; Wording: "the install account", never "the installing account/identity" --
        ; UNEXPIREACCOUNT's own header says in bold that the target is the fixed constant
        ; _SYSTEM and deliberately NOT $Username (verified live as irisowner in the
        ; container). The old text asserted the opposite of the parameter it is reporting.
        Do ..Report(.pReports, "info", "Unexpired the named install account's password", {"user": (pAccount), "count": (tCount)})
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Report the CSP Gateway registration gap for every web application this run
/// created (empty in this story -- Story 1.5 adds the two OcuPilot applications to this
/// same step without changing it, per this story's Design Notes on the 1.4/1.5 seam) and
/// the current Web Gateway response timeout as information only (AD-17, AD-27) -- never a
/// prerequisite, never modified. Never fails install: any problem reading the timeout is
/// reported as "not available" rather than propagated.</p>
ClassMethod ReportGatewayGap(ByRef pReports) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Fix Pack F-5: this used to say "No web application was created by this run" --
        ; true of Install() alone, which never creates one, but StartPath drains this
        ; report merged with Install.Fixture's own reports into ONE stream, and the
        ; demo fixture's CreateWebApp emits its OWN gap line for the application it DID
        ; just create in that same run whenever the opt-in flag is set -- two lines that
        ; read as contradicting each other. Reworded to a claim that stays true
        ; regardless of what ran alongside it.
        Do ..Report(.pReports, "info", "Security.Applications.Create does not notify the CSP Gateway -- a new web application may 404 until an SMP Save or a Gateway restart. This installer step did not create a web application; Story 1.5's own applications, or the opt-in demo fixture, may create one separately and report their own gap.", "")

        Set tTimeout = ""
        Set tSource = ""
        Set tReadSC = ..GatewayResponseTimeout(.tTimeout, .tSource)
        If $$$ISOK(tReadSC) && (tTimeout '= "") {
            Do ..Report(.pReports, "info", "Web Gateway response timeout (information only, never modified)", {"timeout": (tTimeout), "source": (tSource)})
        } Else {
            Do ..Report(.pReports, "info", "Web Gateway response timeout is not available from either the live registry or a configuration file this run could read", "")
        }
    } Catch ex {
        Do ..Report(.pReports, "info", "Web Gateway response timeout is not available", {"error": (ex.DisplayString())})
    }
    Quit tSC
}

/// <p>Read the Web Gateway's <code>Server_Response_Timeout</code>, preferring the live
/// registry -- <code>$SYSTEM.CSP.GetGatewayRegistry().GetGatewayMgrs("a")</code>'s first
/// entry's <code>GetDefaultParams</code>, verified live this story to return
/// <code>Server_Response_Timeout=60</code> on this instance -- and falling back to a
/// configuration file resolved from <code>$System.Util.InstallDirectory()</code> (AD-21:
/// never a caller-supplied path) when no Gateway is registered. Neither source answering
/// leaves both outputs <code>""</code>, never an error. Overridable so
/// <class>OcuPilot.Test.Version</class> can force the "neither answers" branch without
/// needing a genuinely Gateway-less instance; production never overrides this.</p>
ClassMethod GatewayResponseTimeout(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = ""
    Set pSource = ""
    Set tSC = $$$OK
    Try {
        Set tReg = $SYSTEM.CSP.GetGatewayRegistry()
        Set tMgrs = tReg.GetGatewayMgrs("a")
        If tMgrs.Count() {
            Set tMgr = tMgrs.GetAt(1)
            Set tParamSC = tMgr.GetDefaultParams(.tParams)
            If $$$ISOK(tParamSC) && ($Get(tParams("Server_Response_Timeout")) '= "") {
                Set pTimeout = tParams("Server_Response_Timeout")
                Set pSource = "live Gateway registry"
                Quit
            }
        }

        Set tCandidate = $System.Util.InstallDirectory() _ "CSP.ini"
        Set tFileOpen = 0
        If ##class(%File).Exists(tCandidate) {
            Set tFile = ##class(%File).%New(tCandidate)
            Set tOpenSC = tFile.Open("RSK\RAW\")
            If $$$ISERR(tOpenSC) Quit
            Set tFileOpen = 1
            While 'tFile.AtEnd {
                Set tLine = tFile.ReadLine()
                If tLine [ "Server_Response_Timeout" {
                    Set pTimeout = $ZStrip($Piece(tLine, "=", 2), "<>W")
                    Set pSource = "configuration file (" _ tCandidate _ ")"
                    Quit
                }
            }
            Do tFile.Close()
            Set tFileOpen = 0
        }
    } Catch ex {
        ; Fix Pack F-4: the normal-path Close() above runs only after the While loop
        ; completes without throwing -- an exception partway through ReadLine left the
        ; handle open on this path. tFileOpen tracks whether this Try block's own file
        ; is still open when an exception lands here.
        ; Review finding (build-auto review, 2026-09-10): Close() itself could throw on
        ; an already-broken handle -- a bare Do here would then escape uncaught, turning
        ; a graceful "timeout not available" fallback (AD-27) into a crash that could
        ; abort the whole Install() call instead of returning an ordinary %Status error.
        ; Isolated in its own Try/Catch so a Close() failure can never do that.
        Try {
            If $Get(tFileOpen) && $IsObject($Get(tFile)) {
                Do tFile.Close()
            }
        } Catch exClose { }
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Pure decision (AC6): refuses when <var>pStoredVersion</var> is ahead of the
/// deployed code, otherwise <code>$$$OK</code>. The one place this comparison lives --
/// <method>Install</method> calls this before touching anything (before the <code>%SYS</code>
/// switch and before any migration step), so a downgrade genuinely changes nothing.
/// Public so <class>OcuPilot.Test.Version</class> can pin it directly, independent of
/// any call site, per the Story 1.1 lesson that a pure-function test alone is not
/// enough -- see <method>Install</method>'s own call for the paired call-site test.</p>
ClassMethod PlanMigration(pStoredVersion As %Integer) As %Status
{
    If pStoredVersion > ..#SCHEMAVERSION {
        Quit $$$ERROR($$$GeneralError, "Install refuses: the stored schema version (" _ pStoredVersion _ ") is newer than the deployed code's version (" _ ..#SCHEMAVERSION _ "). Nothing was changed; downgrade is not supported.")
    }
    Quit $$$OK
}

/// <p>Run every registered migration step from <var>pFromVersion</var>+1 up to the
/// deployed <parameter>SCHEMAVERSION</parameter>, strictly in ascending order, stopping
/// at the first failure without running any step past it (AC5, AC6).</p>
/// <p><b>Public, not <code>[ Private ]</code></b>, the same documented deviation
/// <method>EnsureGrant</method> and <method>MigrationStep</method> already carry:
/// <class>OcuPilot.Test.Version</class> drives this directly against
/// <class>OcuPilot.Test.MigrateFault</class> to test ordering, survival and failure
/// propagation without paying for a full <method>Install</method> pipeline (no
/// database, resource or role touched) for tests that do not need one.</p>
ClassMethod RunMigrations(pProfile As %String, pFromVersion As %Integer, ByRef pReports) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tVersion = pFromVersion
        While tVersion < ..#SCHEMAVERSION {
            Set tNext = tVersion + 1
            Set tSC = ..MigrationStep(tNext, pProfile, .pReports)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Migrated to schema version " _ tNext, {"version": (tNext)})
            Set tVersion = tNext
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Dispatch one migration step by its target schema version -- the ordered migration
/// registry AD-38 requires, kept in this one class (AD-17) so a later story adds the next
/// version here, never in a second registry. <b>Public, not <code>[ Private ]</code></b>,
/// the same documented deviation <method>EnsureGrant</method> already carries and for the
/// identical reason: <class>OcuPilot.Test.MigrateFault</class> must be able to register
/// steps above the deployed version to test the runner itself.</p>
ClassMethod MigrationStep(pTargetVersion As %Integer, pProfile As %String, ByRef pReports) As %Status
{
    If pTargetVersion = 1 {
        Quit ..MigrateToVersion1(pProfile, .pReports)
    }
    Quit $$$ERROR($$$GeneralError, "No migration step registered for schema version " _ pTargetVersion)
}

/// <p>Schema version 0 to 1: introduces the version stamp itself
/// (<class>OcuPilot.Kernel.State.Version</class>), which needs no data migration of its
/// own -- every already-populated protected row (<class>OcuPilot.Kernel.State.Stamp</class>'s
/// 273+ production rows on this instance, at spec-writing time) survives untouched
/// (AC5).</p>
ClassMethod MigrateToVersion1(pProfile As %String, ByRef pReports) As %Status [ Private ]
{
    Do ..Report(.pReports, "info", "No data migration needed for schema version 1 -- it introduces the version stamp itself", "")
    Quit $$$OK
}

/// <p>Ensure the <code>%DB_</code> resource guarding the profile's database (AC1):
/// <code>Type = 2</code>, <code>PublicPermission = ""</code>. Must run before
/// <method>EnsureDatabase</method> -- <code>SYS.Database</code> does not validate that a
/// resource exists, so creating the database first yields a silently <code>%All</code>-
/// only database.</p>
ClassMethod EnsureDatabaseResource(ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("dbResource")
        If ##class(Security.Resources).Exists(tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Resources).Get(tName, .tProps)
            If $$$ISERR(tSC) Quit
            ; Only PublicPermission is compared. Type is deliberately NOT part of this
            ; guard: it is filer-assigned and Security.Resources' own header says user
            ; code must not modify it, so a Type mismatch could be detected but never
            ; repaired -- the branch would report "Repaired the database resource" on
            ; every run forever while changing nothing. Verified live on this build:
            ; %DB_OCUPILOT reads Type = 2, and the ordinary OcuPilotAdmin resource reads
            ; 2147483648 rather than the 0 it was created with, both filer-set.
            If $Get(tProps("PublicPermission")) '= "" {
                Set tModProps("PublicPermission") = ""
                Set tSC = ##class(Security.Resources).Modify(tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the database resource", {"resource": (tName)})
            } Else {
                Do ..Report(.pReports, "info", "Database resource already correct", {"resource": (tName)})
            }
        } Else {
            Set tSC = ##class(Security.Resources).Create(tName, "OcuPilot protected-state database", "", 2)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the database resource", {"resource": (tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the profile's database exists at
/// <code>&lt;ManagerDirectory&gt;&lt;name&gt;/</code> (AC1), guarding creation of an
/// existing <code>IRIS.DAT</code> with a re-initializing <code>CreateDatabase</code>
/// call. On the existing-object path, verifies and repairs
/// <code>SYS.Database.ResourceName</code> against drift -- the sibling's exact defect
/// (its own doc comment admits the early return "never verifies the existing object's
/// configuration"), reproduced correctly here.</p>
ClassMethod EnsureDatabase(ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tDir = pNames("directory")
        Set tIrisDat = tDir _ "IRIS.DAT"

        If '##class(%File).Exists(tIrisDat) {
            Do ##class(%File).CreateDirectoryChain(tDir, .tReturn)
            Set tSC = ##class(SYS.Database).CreateDatabase(tDir, 1, 8192, 0, pNames("dbResource"))
            If $$$ISERR(tSC) Quit
            If '##class(Config.Databases).Exists(pNames("database"), .tCfgObj, .tCfgSC) {
                Set tProps("Directory") = tDir
                Set tSC = ##class(Config.Databases).Create(pNames("database"), .tProps)
                If $$$ISERR(tSC) Quit
            }
            Do ..Report(.pReports, "info", "Created the OcuPilot database", {"database": (pNames("database")), "directory": (tDir)})
        } Else {
            Set tDbObj = ##class(SYS.Database).%OpenId(tDir)
            If '$IsObject(tDbObj) {
                Set tSC = $$$ERROR($$$GeneralError, "Database directory exists but SYS.Database could not open it: " _ tDir)
                Quit
            }
            If tDbObj.ResourceName '= pNames("dbResource") {
                Set tWas = tDbObj.ResourceName
                Set tSC = ##class(SYS.Database).ModifyDatabase(tDir, tDbObj.Size, pNames("dbResource"), tDbObj.GlobalJournalState)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the database's drifted guarding resource", {"database": (pNames("database")), "was": (tWas), "now": (pNames("dbResource"))})
            } Else {
                Do ..Report(.pReports, "info", "OcuPilot database already correct", {"database": (pNames("database"))})
            }
            If '##class(Config.Databases).Exists(pNames("database"), .tCfgObj2, .tCfgSC2) {
                Set tProps2("Directory") = tDir
                Set tSC = ##class(Config.Databases).Create(pNames("database"), .tProps2)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the database's missing config entry", {"database": (pNames("database"))})
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the OcuPilot administrative resource exists (AC2): non-public, and created
/// as an ordinary resource by passing <code>Type = 0</code>. The stored value is not 0 --
/// <class>Security.Resources</class> documents <code>Type</code> as filer-assigned and
/// not to be set by user code, and this instance reads it back as
/// <code>2147483648</code> ("user defined resource"). It is therefore not compared or
/// repaired here, for the same reason as in <method>EnsureDatabaseResource</method>.</p>
ClassMethod EnsureAdminResource(ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("adminResource")
        If ##class(Security.Resources).Exists(tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Resources).Get(tName, .tProps)
            If $$$ISERR(tSC) Quit
            If $Get(tProps("PublicPermission")) '= "" {
                Set tModProps("PublicPermission") = ""
                Set tSC = ##class(Security.Resources).Modify(tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the administrative resource", {"resource": (tName)})
            } Else {
                Do ..Report(.pReports, "info", "Administrative resource already correct", {"resource": (tName)})
            }
        } Else {
            Set tSC = ##class(Security.Resources).Create(tName, "OcuPilot administrative access", "", 0)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the administrative resource", {"resource": (tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the administrative role exists and grants <b>only</b> the administrative
/// resource with <code>U</code> (AC2) -- never the <code>%DB_</code> resource, which no
/// ordinary role holds (AD-9).</p>
ClassMethod EnsureAdminRole(ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("adminRole")
        Set tWantResources = pNames("adminResource") _ ":U"
        If ##class(Security.Roles).Exists(tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Roles).Get(tName, .tProps, .tRoleObj)
            If $$$ISERR(tSC) Quit
            ; GrantedRoles is compared as well as Resources: a role that has acquired a
            ; granted role -- %All, or any %Admin_* -- is precisely the "granting
            ; privilege through any path" effect AD-10's prohibited set names, and
            ; existence alone must never read as "installed" (AD-17). Verified live that
            ; a correctly created role reads GrantedRoles back as "", so this guard does
            ; not fire on a clean install.
            If ($Get(tProps("Resources")) '= tWantResources) || ($Get(tProps("GrantedRoles")) '= "") {
                Set tModProps("Resources") = tWantResources
                Set tModProps("GrantedRoles") = ""
                Set tModProps("ForceSave") = 2
                Set tSC = ##class(Security.Roles).Modify(tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the administrative role's resources", {"role": (tName)})
            } Else {
                Do ..Report(.pReports, "info", "Administrative role already correct", {"role": (tName)})
            }
        } Else {
            Set tSC = ##class(Security.Roles).Create(tName, "OcuPilot administrative role", tWantResources, "")
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the administrative role", {"role": (tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the privileged routine application exists, enabled, granting the
/// <code>%DB_</code> resource's implicit role unconditionally
/// (<code>MatchRoles = ":&lt;dbResource&gt;"</code>) to the one class allowed to call it
/// (<code>Routines = "OcuPilot.Kernel.State.Base:&lt;codeDatabase&gt;:1"</code>).
/// Carries no <code>Resource</code> of its own (this story's Design Notes, resolved
/// reading 4) -- containment comes from the <code>Routines</code> allow-list plus the
/// <code>New $ROLES</code> frame plus AC6's mechanical check, not from gating who may
/// call <code>AddRoles</code>.</p>
ClassMethod EnsureApplication(ByRef pNames, pInstallNs As %String, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("application")
        Set tNsObj = ##class(Config.Namespaces).Open(pInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ pInstallNs)
            Quit
        }
        Set tCodeDb = tNsObj.Routines
        If tCodeDb = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the routine database for namespace " _ pInstallNs)
            Quit
        }
        Set tWantRoutines = "OcuPilot.Kernel.State.Base:" _ tCodeDb _ ":1"
        Set tWantMatchRoles = ":" _ pNames("dbResource")

        If ##class(Security.Applications).Exists(tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Applications).Get(tName, .tProps)
            If $$$ISERR(tSC) Quit
            Set tNeedsRepair = 0
            If +$Get(tProps("Enabled")) '= 1 Set tNeedsRepair = 1
            If $Get(tProps("MatchRoles")) '= tWantMatchRoles Set tNeedsRepair = 1
            If $Get(tProps("Routines")) '= tWantRoutines Set tNeedsRepair = 1
            If tNeedsRepair {
                Set tModProps("Enabled") = 1
                Set tModProps("MatchRoles") = tWantMatchRoles
                Set tModProps("Routines") = tWantRoutines
                Set tSC = ##class(Security.Applications).Modify(tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the privileged routine application", {"application": (tName)})
            } Else {
                Do ..Report(.pReports, "info", "Privileged routine application already correct", {"application": (tName)})
            }
        } Else {
            Set tProps2("Type") = 4
            Set tProps2("Enabled") = 1
            Set tProps2("Description") = "OcuPilot protected-state escalation"
            Set tProps2("MatchRoles") = tWantMatchRoles
            Set tProps2("Routines") = tWantRoutines
            Set tSC = ##class(Security.Applications).Create(tName, .tProps2)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the privileged routine application", {"application": (tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure exactly one global mapping <code>&lt;prefix&gt;*</code> targeting the
/// profile's database (AC3). Never a package or routine mapping -- OcuPilot's code stays
/// in the install namespace's normal database (AD-9).</p>
ClassMethod EnsureMapping(ByRef pNames, pInstallNs As %String, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("mappingPattern")
        If ##class(Config.MapGlobals).Exists(pInstallNs, tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Config.MapGlobals).Get(pInstallNs, tName, .tProps)
            If $$$ISERR(tSC) Quit
            If $Get(tProps("Database")) '= pNames("database") {
                Set tModProps("Database") = pNames("database")
                Set tSC = ##class(Config.MapGlobals).Modify(pInstallNs, tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the global mapping's target database", {"mapping": (tName)})
            } Else {
                Do ..Report(.pReports, "info", "Global mapping already correct", {"mapping": (tName)})
            }
        } Else {
            Set tProps2("Database") = pNames("database")
            Set tSC = ##class(Config.MapGlobals).Create(pInstallNs, tName, .tProps2)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the global mapping", {"mapping": (tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the profile's audit event type is registered (AD-15) -- without
/// registration, <code>$System.Security.Audit</code> silently returns a bare failure
/// status and drops the event. Guard-then-act, and verify-and-repair (AD-17): the
/// existing-object path also compares the live <code>Enabled</code> flag against the
/// intended value and repairs it when a since-registered event was manually disabled --
/// existence of the registration alone is never read as "installed", the same rule
/// <method>EnsureApplication</method> applies to the privileged routine application's
/// own <code>Enabled</code> flag.</p>
ClassMethod EnsureAuditEvent(ByRef pNames, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tSource = pNames("eventSource")
        Set tType = pNames("eventType")
        Set tName = pNames("eventName")
        If ##class(Security.Events).Exists(tSource, tType, tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Events).Get(tSource, tType, tName, .tProps)
            If $$$ISERR(tSC) Quit
            If +$Get(tProps("Enabled")) '= 1 {
                Set tModProps("Enabled") = 1
                Set tSC = ##class(Security.Events).Modify(tSource, tType, tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the disabled audit event", {"event": (tSource _ "/" _ tType _ "/" _ tName)})
            } Else {
                Do ..Report(.pReports, "info", "Audit event already registered", {"event": (tSource _ "/" _ tType _ "/" _ tName)})
            }
        } Else {
            Set tSC = ##class(Security.Events).Create(tSource, tType, tName, "OcuPilot administrative role granted", 1, 0)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Registered the audit event", {"event": (tSource _ "/" _ tType _ "/" _ tName)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure instance-wide auditing is enabled (FR-66), reporting which of "already
/// enabled" and "enabled now" happened as a distinct outcome (AC10). Never touches
/// <code>AuditEncrypt</code> -- changing it deletes the audit database.</p>
ClassMethod EnsureAuditingEnabled(ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        ; Security.System.Get, not the [ Internal ] IsAuditingEnabled() helper -- see
        ; StateFingerprint's note. A failed read is an error, never a silent "it is off"
        ; that would then write the setting.
        Set tSC = ##class(Security.System).Get("SYSTEM", .tSysProps)
        If $$$ISERR(tSC) Quit
        If +$Get(tSysProps("AuditEnabled")) = 1 {
            Do ..Report(.pReports, "info", "Instance auditing already enabled", "")
        } Else {
            Set tProps("AuditEnabled") = 1
            Set tSC = ##class(Security.System).Modify("SYSTEM", .tProps)
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "warn", "Enabled instance auditing", "")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the administrative role is granted (AC9, DW-16), using the process's own
/// <code>$Username</code> as the candidate by default. Takes the candidate username as
/// an explicit parameter (rather than reading <code>$Username</code> only internally) so
/// <class>OcuPilot.Test.Installer</class> can drive the placeholder branch directly with
/// a literal placeholder value, without the test connection itself needing to
/// authenticate as one. Never a silent skip: when no grant is made,
/// <var>pCommand</var> always carries the exact <code>Security.Users.AddRoles(...)</code>
/// command an operator must run -- and it is reported through <var>pReports</var> too
/// (see this class's header for why ensure steps cannot log directly while switched to
/// <code>%SYS</code>). Called directly by tests with an explicit <var>pReports</var>, or
/// through <method>Install</method> with the array it threads through every step.</p>
ClassMethod EnsureGrant(ByRef pNames, Output pOutcome As %String, Output pGrantedUser As %String, Output pCommand As %String, pUsername As %String = {$Username}, ByRef pReports) As %Status
{
    Set tSC = $$$OK
    Set pOutcome = ""
    Set pGrantedUser = ""
    Set pCommand = ""
    Try {
        Set tRole = pNames("adminRole")

        If (pUsername = "") || (pUsername = "UnknownUser") || (pUsername = "_PUBLIC") || ('##class(Security.Users).Exists(pUsername, .tU, .tUS)) {
            Set pOutcome = "skipped-placeholder"
            ; The reported command never names the rejected identity as the grant target.
            ; Rendering "UnknownUser" or "_PUBLIC" back into a runnable AddRoles call --
            ; which an earlier version did for every case but the empty one -- instructs
            ; the operator to grant OcuPilot's administrative role to the anonymous CSP
            ; identity, exactly the outcome AD-21 ("anonymous does not mean
            ; unprivileged") and AD-10's prohibited set exist to prevent. The rejected
            ; value is still reported, as data on the report below.
            Set tTargetLabel = "<a named account that exists on this instance>"
            ; Prefixed with the namespace switch: Security.Users is mapped into %SYS
            ; only, so without it the command raises <CLASS DOES NOT EXIST> in the
            ; install namespace an operator is otherwise working in (verified live).
            Set pCommand = "Set $NAMESPACE=""%SYS"" Set tRoles=""" _ tRole _ """ Do ##class(Security.Users).AddRoles(""" _ tTargetLabel _ """, .tRoles)"
            Do ..Report(.pReports, "warn", "Administrative role not granted -- the installing identity is not a usable named account", {"user": (pUsername), "command": (pCommand)})
            Quit
        }

        Set tRolesArg = tRole
        Set tSC = ##class(Security.Users).AddRoles(pUsername, .tRolesArg)
        If $$$ISERR(tSC) Quit

        Set pOutcome = "granted"
        Set pGrantedUser = pUsername
        Do ..Report(.pReports, "info", "Granted the administrative role", {"user": (pUsername), "role": (tRole)})

        Set tAuditSC = $System.Security.Audit(pNames("eventSource"), pNames("eventType"), pNames("eventName"), "actor=" _ pUsername _ ";target=" _ pUsername _ ";role=" _ tRole, "OcuPilot administrative role granted")
        If $$$ISERR(tAuditSC) {
            Do ..Report(.pReports, "warn", "Administrative role granted, but the audit marker failed to write", {"user": (pUsername)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Append one <class>OcuPilot.Kernel.State.Stamp</class> row recording this run.
/// Runs after the namespace restore -- <class>OcuPilot.Kernel.State.Stamp</class> is an
/// OcuPilot class, compiled only into the install namespace, not <code>%SYS</code>.</p>
ClassMethod RecordStamp(ByRef pNames, pGrantOutcome As %String, pGrantedUser As %String, pGrantCommand As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
        Set tStamp.Timestamp = $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
        Set tStamp.Profile = pNames("profile")
        Set tStamp.DatabaseName = pNames("database")
        Set tStamp.DatabaseResourceName = pNames("dbResource")
        Set tStamp.AdminResourceName = pNames("adminResource")
        Set tStamp.AdminRoleName = pNames("adminRole")
        Set tStamp.ApplicationName = pNames("application")
        Set tStamp.MappingPattern = pNames("mappingPattern")
        Set tStamp.GrantOutcome = pGrantOutcome
        Set tStamp.GrantedUsername = pGrantedUser
        Set tStamp.GrantCommandHint = pGrantCommand
        Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tStamp)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A composite fingerprint of every live, ensure-managed property this story's
/// installer touches for <var>pProfile</var> -- sensitive to drift on any of them,
/// including <code>Enabled</code> on the privileged routine application (AC7, AC8) and,
/// as of this story, the version row's <property>SchemaVersion</property> and
/// <property>Phase</property> (AC4, AC5). <property>UpdatedAt</property> is deliberately
/// <b>excluded</b> (NFR-9's Design Notes) -- a record of when install last ran is not
/// drift. Excludes nothing else that a caller can observe changing between two correct
/// installs.</p>
ClassMethod StateFingerprint(pProfile As %String = "") As %String
{
    Set tResult = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) {
            Set tResult = "ERROR:" _ $System.Status.GetErrorText(tSC)
            Quit
        }
        Set tInstallNs = ..ResolveNamespace()

        ; Read while still in the install namespace -- Kernel.State.Version is an
        ; OcuPilot class, mapped only there (this class's own header).
        Set tVerSchemaVersion = "READFAILED"
        Set tVerPhase = "READFAILED"
        Set tVerReadSC = ..CurrentVersionRow(pProfile, .tVerRow)
        If $$$ISOK(tVerReadSC) {
            Set tVerSchemaVersion = $Select($IsObject(tVerRow): tVerRow.SchemaVersion, 1: "")
            Set tVerPhase = $Select($IsObject(tVerRow): tVerRow.Phase, 1: "")
        }

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set tResult = "ERROR:" _ $System.Status.GetErrorText(tSC)
            Quit
        }

        Set tDbResourceName = ""
        If ##class(%File).Exists(tNames("directory") _ "IRIS.DAT") {
            Set tDbObj = ##class(SYS.Database).%OpenId(tNames("directory"))
            If $IsObject(tDbObj) Set tDbResourceName = tDbObj.ResourceName
        }

        ; Every Get below has its %Status checked (Consistency Conventions: Status
        ; handling). Discarding them -- which the sibling installer does on three
        ; privileged calls, and this story's Code Map lists under "Do not copy" -- makes
        ; a failed read indistinguishable from an absent object: both leave the component
        ; "", so two consecutive failed reads compare byte-identical and AC7's
        ; idempotency oracle passes on no evidence at all.
        Set tRoleResources = ""
        If ##class(Security.Roles).Exists(tNames("adminRole"), .tRoleObj, .tRoleSC) {
            Set tGetSC = ##class(Security.Roles).Get(tNames("adminRole"), .tRoleProps, .tRoleObj2)
            Set tRoleResources = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tRoleProps("Resources")))
        }

        Set tAppEnabled = ""
        Set tAppMatchRoles = ""
        Set tAppRoutines = ""
        If ##class(Security.Applications).Exists(tNames("application"), .tAppObj, .tAppSC) {
            Set tGetSC = ##class(Security.Applications).Get(tNames("application"), .tAppProps)
            Set tAppEnabled = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tAppProps("Enabled")))
            Set tAppMatchRoles = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tAppProps("MatchRoles")))
            Set tAppRoutines = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tAppProps("Routines")))
        }

        Set tMapDatabase = ""
        If ##class(Config.MapGlobals).Exists(tInstallNs, tNames("mappingPattern"), .tMapObj, .tMapSC) {
            Set tGetSC = ##class(Config.MapGlobals).Get(tInstallNs, tNames("mappingPattern"), .tMapProps)
            Set tMapDatabase = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tMapProps("Database")))
        }

        Set tEventEnabled = ""
        If ##class(Security.Events).Exists(tNames("eventSource"), tNames("eventType"), tNames("eventName"), .tEvObj, .tEvSC) {
            Set tGetSC = ##class(Security.Events).Get(tNames("eventSource"), tNames("eventType"), tNames("eventName"), .tEvProps)
            Set tEventEnabled = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tEvProps("Enabled")))
        }

        ; Also fold in the two resources' own live properties (not merely the database's
        ; link to the %DB_ resource by name) and the instance-wide auditing flag
        ; EnsureAuditingEnabled manages, so a drift on any of them -- not only the four
        ; objects above -- also moves this fingerprint (AC7, AC8).
        Set tDbResourcePublic = ""
        Set tDbResourceType = ""
        If ##class(Security.Resources).Exists(tNames("dbResource"), .tDbResObj, .tDbResSC) {
            Set tGetSC = ##class(Security.Resources).Get(tNames("dbResource"), .tDbResProps)
            Set tDbResourcePublic = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tDbResProps("PublicPermission")))
            Set tDbResourceType = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tDbResProps("Type")))
        }

        Set tAdminResourcePublic = ""
        If ##class(Security.Resources).Exists(tNames("adminResource"), .tAdminResObj, .tAdminResSC) {
            Set tGetSC = ##class(Security.Resources).Get(tNames("adminResource"), .tAdminResProps)
            Set tAdminResourcePublic = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tAdminResProps("PublicPermission")))
        }

        ; Security.System.Get, not IsAuditingEnabled(): the latter is marked [ Internal ]
        ; in Security/System.cls and carries no stability contract, while AuditEnabled is
        ; an ordinary property of the same record this class already writes through
        ; Security.System.Modify.
        Set tAuditingEnabled = ""
        Set tSysSC = ##class(Security.System).Get("SYSTEM", .tSysProps)
        Set tAuditingEnabled = $Select($$$ISERR(tSysSC): "READFAILED", 1: +$Get(tSysProps("AuditEnabled")))

        Set tResult = tDbResourceName _ "|" _ tRoleResources _ "|" _ tAppEnabled _ "|" _ tAppMatchRoles _ "|" _ tAppRoutines _ "|" _ tMapDatabase _ "|" _ tEventEnabled _ "|" _ tDbResourcePublic _ "|" _ tDbResourceType _ "|" _ tAdminResourcePublic _ "|" _ tAuditingEnabled _ "|" _ tVerSchemaVersion _ "|" _ tVerPhase
    } Catch ex {
        Set tResult = "ERROR:" _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tResult
}

/// <p>Whether any object <var>pNames</var> names currently exists, so
/// <method>Uninstall</method> can tell "absent" from "present" before deciding whether
/// <var>pConfirmDataLoss</var> matters at all.</p>
ClassMethod AnyObjectExists(ByRef pNames, pInstallNs As %String) As %Boolean [ Private ]
{
    If ##class(Config.Databases).Exists(pNames("database"), .t1, .s1) Quit 1
    If ##class(Security.Resources).Exists(pNames("dbResource"), .t2, .s2) Quit 1
    If ##class(Security.Resources).Exists(pNames("adminResource"), .t3, .s3) Quit 1
    If ##class(Security.Roles).Exists(pNames("adminRole"), .t4, .s4) Quit 1
    If ##class(Security.Applications).Exists(pNames("application"), .t5, .s5) Quit 1
    If ##class(Config.MapGlobals).Exists(pInstallNs, pNames("mappingPattern"), .t6, .s6) Quit 1
    If ##class(%File).Exists(pNames("directory") _ "IRIS.DAT") Quit 1
    If ##class(Security.Events).Exists(pNames("eventSource"), pNames("eventType"), pNames("eventName"), .t7, .s7) Quit 1
    Quit 0
}

/// <p>Remove every object <var>pProfile</var> owns: <b>first</b> the opt-in demo fixture
/// set through <class>OcuPilot.Install.Fixture</class> (AD-25) -- read from this profile's
/// <class>OcuPilot.Kernel.State.Demo</class> inventory while it and its escalation route
/// still exist -- <b>then</b> the mapping, the privileged routine application, the
/// administrative role and resource, the database's guarding resource, the database
/// itself (config entry, <code>IRIS.DAT</code> and directory), and the audit event.
/// <b>This order is load-bearing</b> (review finding, HIGH): fixture removal used to run
/// last, by which point the mapping and database it needs to read
/// <class>OcuPilot.Kernel.State.Demo</class> through were already gone, silently
/// orphaning every production fixture. Absent objects are never an error; without
/// <var>pConfirmDataLoss</var> the method changes nothing (including the fixtures) and
/// names what it would have destroyed.</p>
/// <p>Also purges the <class>OcuPilot.Kernel.State.Stamp</class> rows recorded for
/// <var>pProfile</var> once the named objects above are gone -- a purge failure is
/// reported through the logger but does not turn an otherwise-successful uninstall into
/// an error, since AC11's own success criteria are the named objects, never stamp
/// history.</p>
/// <p><b>The purge is meaningful for the <code>"probe"</code> profile only, and that is
/// the whole reason it exists.</b> Probe rows land in the <i>production</i> protected
/// database (Stamp's own data global starts with <code>OcuPilot</code> and so matches the
/// production mapping, never the probe's distinct <code>ProbeOcuPilotState*</code>
/// pattern), so nothing else would ever remove them. Production rows need no purge: they
/// live inside the very database this method has just deleted. For
/// <var>pProfile</var> <code>""</code> the DELETE additionally matches nothing by
/// construction -- see <method>OcuPilot.Kernel.State.Stamp.DeleteByProfile</method>.</p>
ClassMethod Uninstall(pProfile As %String = "", pConfirmDataLoss As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit
        Set tInstallNs = ..ResolveNamespace()

        ; Review finding (build-auto review, 2026-09-10): AnyObjectExists below checked
        ; only the core installer-managed objects (database, resources, role,
        ; application, mapping, audit event) -- never the demo fixture inventory. If
        ; those core objects were ever removed by some path other than this method
        ; (e.g. a manual Management Portal cleanup) while fixture objects/rows survived,
        ; AnyObjectExists would return false and this method would return $$$OK without
        ; ever reaching the fixture-removal call below -- the exact orphaning the H1 fix
        ; three lines below exists to prevent. Resolved BEFORE the %SYS switch, in the
        ; install namespace where Kernel.State.Demo is compiled (the same reason
        ; tInstallNs above is resolved here and not after the switch).
        ; Review finding (MED, round 2): a GuardedIdsForProfile ERROR used to fall
        ; through to tFixturesExist's initial 0 identically to a genuine "no rows"
        ; result -- combined with AnyObjectExists also false (core objects already
        ; removed by some other path), that let this method return $$$OK having
        ; removed nothing, on a read failure that never actually established there was
        ; nothing to remove. Failing closed here means "unable to tell" is treated as
        ; "assume something might exist" -- Uninstall proceeds rather than silently
        ; taking the early-return shortcut -- matching Install's own "a read failure is
        ; never read as an absent/first-install state" discipline, adapted to this
        ; method's own early-exit shape rather than a hard refusal.
        Set tFixturesExist = 1
        Set tFixtureIdsSC = ##class(OcuPilot.Kernel.State.Demo).GuardedIdsForProfile(pProfile, .tFixtureIds)
        If $$$ISOK(tFixtureIdsSC) {
            Set tFixturesExist = $Select($Data(tFixtureIds): 1, 1: 0)
        } Else {
            Do ..LogWarn("Could not determine whether this profile's demo fixture inventory has any rows -- treating fixtures as present so Uninstall does not silently skip removal", {"profile": (pProfile), "error": ($System.Status.GetErrorText(tFixtureIdsSC))})
        }

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        If '..AnyObjectExists(.tNames, tInstallNs) && 'tFixturesExist {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        If 'pConfirmDataLoss {
            Set tSC = $$$ERROR($$$GeneralError, "Uninstall('" _ pProfile _ "') would destroy: database '" _ tNames("database") _ "' at " _ tNames("directory") _ ", resources '" _ tNames("dbResource") _ "' and '" _ tNames("adminResource") _ "', role '" _ tNames("adminRole") _ "', application '" _ tNames("application") _ "', mapping '" _ tNames("mappingPattern") _ "', audit event '" _ tNames("eventSource") _ "/" _ tNames("eventType") _ "/" _ tNames("eventName") _ "', and any opt-in demo fixture objects this profile owns (AD-25). Pass pConfirmDataLoss=1 to proceed.")
            Set $NAMESPACE = tOrigNS
            Quit
        }

        ; Review finding (HIGH): fixture removal used to run at the very end of this
        ; method, AFTER the mapping/application/database block below had already
        ; deleted the OcuPilot* mapping and the OCUPILOT database those fixture
        ; inventory rows themselves live in -- so by the time Install.Fixture.Remove
        ; tried to read Kernel.State.Demo, the data (and the escalation route to it)
        ; was already gone, Remove reported $$$OK having found and removed nothing, and
        ; every production fixture (the demo web application, SSL/TLS configuration,
        ; X.509 credential, task) was orphaned -- directly contradicting AD-25's "and
        ; uninstall removes it". Fixture.Remove needs the install namespace for its own
        ; read phase (Kernel.State.Demo is compiled only there), so this restores to it
        ; first, runs removal to completion while every object it needs still exists,
        ; then re-enters %SYS for the destructive block that follows -- read-in-the-
        ; install-namespace, remove-in-%SYS, purge-after-restore, exactly the ordering
        ; this story's own Design Notes prescribe for OcuPilot.Kernel.State.Stamp.
        Set $NAMESPACE = tOrigNS
        Kill tFixtureReports
        Do ##class(OcuPilot.Install.Fixture).Remove(pProfile, .tFixtureReports)
        Set tFN = $Order(tFixtureReports(""))
        While tFN '= "" {
            If tFixtureReports(tFN, "level") = "warn" {
                Do ..LogWarn(tFixtureReports(tFN, "message"), tFixtureReports(tFN, "data"))
            } Else {
                Do ..LogInfo(tFixtureReports(tFN, "message"), tFixtureReports(tFN, "data"))
            }
            Set tFN = $Order(tFixtureReports(tFN))
        }

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        If ##class(Config.MapGlobals).Exists(tInstallNs, tNames("mappingPattern"), .tE1, .tS1) {
            Set tSC = ##class(Config.MapGlobals).Delete(tInstallNs, tNames("mappingPattern"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Applications).Exists(tNames("application"), .tE2, .tS2) {
            Set tSC = ##class(Security.Applications).Delete(tNames("application"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Roles).Exists(tNames("adminRole"), .tE3, .tS3) {
            Set tSC = ##class(Security.Roles).Delete(tNames("adminRole"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Resources).Exists(tNames("adminResource"), .tE4, .tS4) {
            Set tSC = ##class(Security.Resources).Delete(tNames("adminResource"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Config.Databases).Exists(tNames("database"), .tE5, .tS5) {
            Set tSC = ##class(Config.Databases).Delete(tNames("database"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(%File).Exists(tNames("directory") _ "IRIS.DAT") {
            Set tSC = ##class(SYS.Database).DeleteDatabase(tNames("directory"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Resources).Exists(tNames("dbResource"), .tE6, .tS6) {
            Set tSC = ##class(Security.Resources).Delete(tNames("dbResource"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(%File).DirectoryExists(tNames("directory")) {
            Do ##class(%File).RemoveDirectoryTree(tNames("directory"))
        }
        If ##class(Security.Events).Exists(tNames("eventSource"), tNames("eventType"), tNames("eventName"), .tE7, .tS7) {
            Set tSC = ##class(Security.Events).Delete(tNames("eventSource"), tNames("eventType"), tNames("eventName"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }

        Set $NAMESPACE = tOrigNS

        ; Stamp's own storage lives in the same table for every profile -- nothing
        ; about that row-storage boundary is profile-specific the way the objects
        ; just removed are (AC11 lists exactly those, never Stamp rows) -- so without
        ; this, the disposable "probe" profile's own bookkeeping would survive every
        ; confirmed uninstall and grow without bound across repeated test runs.
        ; OcuPilot.Kernel.State.Stamp is compiled only into the install namespace,
        ; hence called here, after the restore, like RecordStamp.
        Set tStampSC = ##class(OcuPilot.Kernel.State.Stamp).DeleteByProfile(pProfile)
        If $$$ISERR(tStampSC) {
            Do ..LogWarn("Uninstall removed every named object but could not purge this profile's install-stamp history", {"profile": (pProfile)})
        }

        ; The version row is the same kind of per-profile bookkeeping Stamp's own purge
        ; above exists for -- AC11 never lists it either, but leaving it would grow
        ; without bound across repeated probe cycles, exactly like Stamp's did before
        ; Story 1.3's own fix.
        Set tVerDeleteSC = ##class(OcuPilot.Kernel.State.Version).DeleteByProfile(pProfile)
        If $$$ISERR(tVerDeleteSC) {
            Do ..LogWarn("Uninstall removed every named object but could not purge this profile's version row", {"profile": (pProfile)})
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
