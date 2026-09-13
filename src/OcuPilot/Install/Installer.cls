/// <p>OcuPilot's one installer class (AD-17). Creates, guard-then-act and idempotently,
/// a dedicated database holding OcuPilot's <b>globals only</b> (AD-9), a <code>%DB_</code>
/// resource guarding it that no ordinary role holds, the OcuPilot administrative resource
/// and a role granting it, a privileged routine application, one global mapping, and
/// registers and emits OcuPilot's audit events -- leaving OcuPilot's <b>code</b> in the
/// install namespace's normal database. Also unexpires the instance's documented default
/// account's password on a genuinely first install reached through the container start path,
/// never through IPM (AC14, DW-73), forward-migrates OcuPilot's own protected state
/// against a version stamp (<class>OcuPilot.Kernel.State.Version</class>, AD-38, AC5/AC6),
/// reports the CSP Gateway registration gap and its response timeout as information
/// (AC8), and, under an explicit opt-in flag, creates and removes the five demo
/// walkthrough fixtures through <class>OcuPilot.Install.Fixture</class> (AD-25, AC9).
/// <method>StartPath</method> is the container start hook's single install entry point (Story
/// 1.4); the hook's one other call, <method>MarkInstalling</method> before it recompiles,
/// installs nothing (DW-72).</p>
/// <p><b>Story 1.5 added OcuPilot's two web applications to this same class</b> (AD-17, so
/// the Docker path and the IPM path cannot drift): the unauthenticated
/// <code>/ocupilot</code> shell dispatching to <class>OcuPilot.Api.StaticHandler</class>,
/// the password-authenticated <code>/api/ocupilot</code> dispatching to
/// <class>OcuPilot.Api.Router</class>, the shell's one purpose-built read-only matching role
/// (AD-21 -- database READ is routine-execution permission, so an anonymous request cannot
/// load the dispatch class without it), and the bundle directory the shell serves from.
/// <method>Uninstall</method> removes all four; <method>AnyObjectExists</method> names them
/// and <method>StateFingerprint</method> folds every setting the ensure steps assert.</p>
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

/// <p>The names this class refuses as an install target, whatever the caller's current
/// namespace is: <code>%SYS</code> and every other <code>%</code>-prefixed namespace, plus the
/// reserved vendor names below. Those are a refusal list, not a namespace roster -- some are
/// namespaces on a standard install (<code>ENSLIB</code>, <code>DOCBOOK</code>, the
/// <code>HS*</code> ones) and the rest are system <b>database</b> names, listed because a name
/// that never appears as a namespace is simply never matched and costs nothing to refuse.
/// Everything else is an ordinary namespace
/// OcuPilot may install into, which is what lets an IPM install land in the namespace
/// <code>zpm install</code> was run from (DW-12). Compared case-insensitively.</p>
Parameter SYSTEMNAMESPACES As %String = "ENSLIB,DOCBOOK,HSLIB,HSSYS,HSSYSLOCALTEMP,IRISAUDIT,IRISLIB,IRISLOCALDATA,IRISSYS,IRISTEMP";

/// <p>The environment variable that overrides <method>ResolveNamespace</method>'s default on
/// the container start path (DW-12). Optional, like <code>OCUPILOT_DEMO</code>: no environment
/// variable is required to run. Named here so <file>scripts/container-start.sh</file>,
/// <file>scripts/container-health.sh</file> and this class's refusal messages spell it once.</p>
Parameter NAMESPACEOVERRIDEVAR As %String = "OCUPILOT_NAMESPACE";

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

/// <p>How long <method>Install</method>, <method>StartPath</method>, <method>MarkInstalling</method>
/// and <method>Uninstall</method> wait for their profile's install lock
/// (<method>InstallLockName</method>) before refusing (DW-47, DW-84). Measured on this
/// instance, a repeat install of one profile takes about 30 ms and a first install of the probe
/// profile, which creates its database, about 0.3 s, so a second caller that overlaps one waits
/// it out and then runs against the row the first one wrote; one that is still blocked after
/// this long refuses, naming the profile, and writes nothing.</p>
Parameter INSTALLLOCKSECONDS As %Integer = 10;

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

        ; Story 1.5's two web applications, the shell's purpose-built read-only role and the
        ; bundle directory that role exists to make servable. The probe's web paths are
        ; wholly distinct literals rather than suffixed derivatives, for the same reason the
        ; mapping pattern above is: IRIS resolves a web application by longest path prefix,
        ; so "/ocupilotprobe" would nest inside "/ocupilot" and the two profiles could not be
        ; installed side by side. "/probeocupilot" nests inside nothing.
        ;
        ; Story 1.16: the two applications' paths and asserted property sets come from
        ; OcuPilot.Install.Roster, the one declaration module.xml is generated from, and are
        ; resolved here for the same reason shellDirectory below is -- Names runs in the
        ; install namespace, and every ensure step that needs them runs switched to %SYS,
        ; where an OcuPilot class reference raises <CLASS DOES NOT EXIST> (this class's own
        ; header). Both profiles read the same roster: the probe is a disposable copy of
        ; production's shape under distinct names, not a differently configured application.
        ; Reading the production path here rather than restating it is what keeps
        ; <WebApplication Name> and the application install creates from being two
        ; declarations of one fact.
        Set tSC = ..RosterNames("shell", .pNames)
        If $$$ISERR(tSC) Quit
        Set tSC = ..RosterNames("api", .pNames)
        If $$$ISERR(tSC) Quit

        Set pNames("shellApplication") = $Select(tIsProbe: "/probeocupilot", 1: pNames("appPath", "shell"))
        Set pNames("apiApplication") = $Select(tIsProbe: "/api/probeocupilot", 1: pNames("appPath", "api"))
        Set pNames("shellRole") = $Select(tIsProbe: "ProbeOcuPilotShell", 1: "OcuPilotShell")
        ; One rule, one implementation: the handler resolves this same directory per request
        ; from the matched application's own name (AD-21), and calling it here is what keeps
        ; the installer's copy target and the handler's read root from drifting. Safe at this
        ; point -- Names runs in the install namespace, before Install's %SYS switch.
        Set pNames("shellDirectory") = ##class(OcuPilot.Api.StaticHandler).RootDirectory(pNames("shellApplication"))
        If pNames("shellDirectory") = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the shell bundle directory for application '" _ pNames("shellApplication") _ "'")
            Quit
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Resolve the roster's declaration for application <var>pKey</var> into
/// <var>pNames</var>: <code>("appManifest", pKey, &lt;property&gt;)</code> for each value the
/// manifest asserts verbatim, <code>("appInstaller", pKey, &lt;property&gt;)</code> for each
/// property name the roster marks instance-derived,
/// <code>("appPath", pKey)</code>, <code>("appDescription", pKey)</code>, and
/// <code>("appProperties", pKey)</code>, the sorted union of the two property sets as a
/// comma-separated list.</p>
/// <p>Refuses rather than resolving a short set: a roster that cannot be read would otherwise
/// leave <method>EnsureWebApplication</method> comparing no properties, which reports every
/// drifted application correct.</p>
ClassMethod RosterNames(pKey As %String, ByRef pNames) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Install.Roster).Application(pKey, .tApp)
        If $$$ISERR(tSC) Quit
        Set pNames("appPath", pKey) = tApp.path
        If $Extract($Get(pNames("appPath", pKey))) '= "/" {
            Set tSC = $$$ERROR($$$GeneralError, "the roster declares no absolute path for application '" _ pKey _ "'")
            Quit
        }
        Set pNames("appDescription", pKey) = tApp.description
        Set tIterator = tApp.manifest.%GetIterator()
        While tIterator.%GetNext(.tProperty, .tValue) {
            Set pNames("appManifest", pKey, tProperty) = tValue
        }
        Set tIterator2 = tApp.installer.%GetIterator()
        While tIterator2.%GetNext(.tIndex, .tName) {
            Set pNames("appInstaller", pKey, tName) = ""
        }
        Set pNames("appProperties", pKey) = ##class(OcuPilot.Install.Roster).AssertedProperties(pKey)
        If pNames("appProperties", pKey) = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the roster declares no asserted property for application '" _ pKey _ "'")
            Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The default install namespace: <code>HSCUSTOM</code> when it exists on this instance,
/// <code>USER</code> when that does, and <code>""</code> when neither does (DW-12) -- an
/// answer the three entry-point guards refuse on, never a name they then fail to find.
/// Each candidate is probed through <method>NamespaceExists</method>.</p>
/// <p>It is the <b>default</b>, not the target: the container start path resolves it the same
/// way (<file>scripts/container-start.sh</file>) unless
/// <parameter>NAMESPACEOVERRIDEVAR</parameter> names another, and an IPM install lands in the
/// namespace <code>zpm install</code> was run from. What every entry point actually installs
/// into is <method>GuardInstallNamespace</method>'s answer.</p>
ClassMethod ResolveNamespace() As %String
{
    If ..NamespaceExists("HSCUSTOM") Quit "HSCUSTOM"
    If ..NamespaceExists("USER") Quit "USER"
    Quit ""
}

/// <p>Whether <var>pName</var> names a namespace on this instance.
/// <code>%SYS.Namespace</code> is a percent-package class, reachable from any namespace
/// without a switch.</p>
/// <p>It is the single place <method>ResolveNamespace</method> asks, which is what lets a test
/// arm the instance shape it needs -- an instance carrying neither candidate -- without
/// creating or removing a namespace, and while leaving <method>ResolveNamespace</method>'s own
/// candidate order and empty answer as the code under test rather than as something the test
/// replaced.</p>
ClassMethod NamespaceExists(pName As %String) As %Boolean
{
    Quit ##class(%SYS.Namespace).Exists(pName)
}

/// <p>Whether <var>pNamespace</var> is one OcuPilot refuses to install into
/// (<parameter>SYSTEMNAMESPACES</parameter>).</p>
ClassMethod IsSystemNamespace(pNamespace As %String) As %Boolean
{
    Set tName = $ZConvert(pNamespace, "U")
    If tName = "" Quit 1
    If $Extract(tName) = "%" Quit 1
    Quit ("," _ ..#SYSTEMNAMESPACES _ ",") [ ("," _ tName _ ",")
}

/// <p>The namespace <var>pWhat</var> is to install into, or a failing <code>%Status</code>
/// naming what it refused and why (DW-12). The one guard
/// <method>Install</method>, <method>StartPath</method> and <method>MarkInstalling</method>
/// each run as their first act, before any object is created and before any <code>%SYS</code>
/// switch.</p>
/// <p>Two refusals, and only two. An instance carrying <b>neither</b> candidate namespace is
/// refused naming both and the <parameter>NAMESPACEOVERRIDEVAR</parameter> override, because a
/// shape OcuPilot cannot recognize is not one to guess an install target on. A caller standing
/// in a <b>system</b> namespace (<method>IsSystemNamespace</method>) is refused naming it.
/// Otherwise the caller's own current namespace is the install target -- which is what makes
/// an IPM install land where <code>zpm install</code> was run rather than being refused for
/// standing anywhere but <method>ResolveNamespace</method>'s default.</p>
ClassMethod GuardInstallNamespace(pWhat As %String, Output pInstallNs As %String) As %Status
{
    Set pInstallNs = ""
    Set tDefault = ..ResolveNamespace()
    If tDefault = "" {
        Quit $$$ERROR($$$GeneralError, pWhat _ " refused: this instance carries neither of OcuPilot's candidate install namespaces, 'HSCUSTOM' nor 'USER'. Create one of them and start again. " _ ..#NAMESPACEOVERRIDEVAR _ " does not substitute for that: it chooses which namespace the container start path installs into, and this refusal is reached before it is read. Nothing was changed.")
    }
    Set tCurrent = $NAMESPACE
    If ..IsSystemNamespace(tCurrent) {
        Quit $$$ERROR($$$GeneralError, pWhat _ " must be called from an ordinary namespace, not the system namespace '" _ tCurrent _ "'. Call it from the namespace OcuPilot is to install into; this instance's default is '" _ tDefault _ "'. Nothing was changed.")
    }
    Set pInstallNs = tCurrent
    Quit $$$OK
}

/// <p>The name of the lock that serializes install work on one profile (DW-47, DW-84):
/// <method>Install</method> holds it from the moment its profile is validated until its
/// version row records the outcome, <method>StartPath</method> holds it for the production
/// profile across that install and the demo fixtures it creates afterwards,
/// <method>MarkInstalling</method> holds it while it marks, and <method>Uninstall</method> holds
/// it from the moment its profile is validated until it returns. Two overlapping installs of
/// one profile used to be able to read "no version row" together and insert two rows; now the
/// second one waits for the first (<parameter>INSTALLLOCKSECONDS</parameter>) and then reads
/// the row the first one wrote. An
/// install and an uninstall of one profile used to be able to overlap too, and on 2026-09-11
/// one did: a probe <method>Uninstall</method>'s database delete and a probe
/// <method>Install</method>'s database create interleaved in two processes and left the probe
/// database's directory mounted with no <code>IRIS.DAT</code> (DW-83). Now whichever comes
/// second waits for the first and refuses if it is still blocked.</p>
/// <p><b>Why this name: <code>^|"%SYS"|OcuPilotInstallLock(&lt;profile&gt;)</code>, an extended
/// reference into <code>%SYS</code>.</b> Each alternative was probed on this build before it
/// was chosen:</p>
/// <ul>
/// <li>A lock on a global follows the caller's global mappings. From the install namespace,
/// <code>^OcuPilot...</code> was recorded against the protected database's directory
/// (<code>/durable/iris/mgr/ocupilot/</code>), because the <code>OcuPilot*</code> mapping
/// sends it there. A genuinely first install creates that mapping part-way through and
/// <method>Uninstall</method> deletes it, so such a lock would change identity under a running
/// install, and two callers could each hold "the same" lock. (That it resolves to the install
/// namespace's own globals database before the mapping exists is how global mapping works; it
/// was not probed without the mapping.)</li>
/// <li>An extended reference names its namespace, so it ignores the caller's mappings: taken
/// from the install namespace, this lock was recorded against
/// <code>^["^^/durable/iris/mgr/"]</code>, the <code>IRISSYS</code> database <code>%SYS</code>
/// keeps its globals in. It is one lock for the whole instance however the install
/// namespace's mappings change, and nothing is ever written to that global.</li>
/// <li>A lock on a global is checked against the caller's privilege on the database it
/// resolves to. Probed with a roleless account on a throwaway container: it got
/// <code>&lt;PROTECT&gt;</code> taking a lock under this same <code>^|"%SYS"|</code> reference
/// (<code>%DB_IRISSYS</code> has no public permission), and also taking a lock under the protected
/// <code>^OcuPilot...</code> prefix;
/// but it could take a plain local lock name (no caret) and a <code>^IRIS.Temp...</code> one
/// (<code>%DB_IRISTEMP</code> is public <code>RW</code>). So with this name an ordinary account
/// cannot hold the install lock to stall an install, while any principal that can run
/// <method>Install</method> can take it. <i>Inference, not probed:</i> install creates
/// configuration and security objects that <code>%SYS</code> holds, so a principal without
/// access to <code>IRISSYS</code> could not complete an install anyway.</li>
/// </ul>
/// <p><class>OcuPilot.Test.InstallLock</class> pins where the lock table records it, and
/// <method>OcuPilot.Test.State.TestDeniedUserCannotHoldTheInstallLock</method> pins that a
/// purpose-built unprivileged account is refused it.</p>
/// <p>Public so <class>OcuPilot.Test.InstallLock</class>'s second process can hold exactly the
/// lock these methods take; production has no other caller.</p>
ClassMethod InstallLockName(pProfile As %String) As %String
{
    Set tKey = $Select(pProfile = "": "production", 1: pProfile)
    Quit "^|""%SYS""|OcuPilotInstallLock(""" _ $Replace(tKey, """", """""") _ """)"
}

/// <p>Take <var>pProfile</var>'s install lock (<method>InstallLockName</method>), waiting up to
/// <parameter>INSTALLLOCKSECONDS</parameter>. Returns an error naming the profile and
/// <var>pWhat</var> (the refused operation) when the wait runs out; the caller then writes
/// nothing. A process that already holds the lock takes it again at once, which is why the
/// pins need a second process (<class>OcuPilot.Test.InstallLock</class>).</p>
ClassMethod LockInstall(pProfile As %String, pWhat As %String) As %Status [ Private ]
{
    Set tName = ..InstallLockName(pProfile)
    Set tWait = ..#INSTALLLOCKSECONDS
    Lock +@tName:tWait
    If $Test Quit $$$OK
    Quit $$$ERROR($$$GeneralError, pWhat _ " refused for profile '" _ pProfile _ "'" _ $Select(pProfile = "": " (production)", 1: "") _ ": another install, uninstall or start mark of that profile still held its install lock after " _ tWait _ " seconds. Nothing was changed; run it again once the other one has finished.")
}

/// <p>Release what <method>LockInstall</method> took.</p>
ClassMethod UnlockInstall(pProfile As %String) [ Private ]
{
    Set tName = ..InstallLockName(pProfile)
    Lock -@tName
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
        ; AD-16: the restore is the first line of every Catch (code review round 3). Install
        ; catches everything itself, so this Catch is reached only if the switch above
        ; throws; pNamespaceAfterInstall then stays "" because Install never returned.
        Set $NAMESPACE = tOrig
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
/// <p><b>One install of a profile at a time (DW-47).</b> Once the profile is validated,
/// <method>Install</method> takes that profile's install lock (<method>InstallLockName</method>)
/// and holds it until the version row has recorded the outcome, so two overlapping calls can
/// no longer both read "no row" and both insert one. A call that is still blocked after
/// <parameter>INSTALLLOCKSECONDS</parameter> refuses with an error naming the profile and
/// writes nothing -- no ensure step runs and no version row is touched. <method>Uninstall</method>
/// takes the same lock (DW-84), so an install that meets an uninstall of its profile waits for
/// it the same way, and refuses if it is still blocked.</p>
/// <p><b><var>pUnexpire</var> is the container start path's, and only
/// <method>StartPath</method> sets it (DW-73, AD-17 as amended 2026-09-11).</b> The
/// <code>_SYSTEM</code> unexpire step runs only when it is true. IPM's
/// <code>&lt;Invoke&gt;</code> in <file>module.xml</file> carries no <code>&lt;Arg&gt;</code> at
/// all, so it calls <method>Install</method> with this argument at its <code>0</code> default,
/// never <method>StartPath</method>, and an IPM install
/// never unexpires anything (AD-17, DW-92): on an instance reached through IPM, an expired
/// <code>_SYSTEM</code> may be the operator's deliberate choice. The step keeps its place in
/// the sequence -- after the grant, before the version row is written -- so a failed
/// unexpire on a first install still leaves the row <code>failed</code> at schema version 0
/// and the next start retries it.</p>
/// <p><b><var>pBundleSource</var> is the built client bundle's source directory</b>
/// (Story 1.5): the directory <method>EnsureShellFiles</method> copies into the shell
/// application's own directory, replacing what is there. The container start path passes the
/// read-only mount it finds the bundle on; every other caller, including an install run from
/// the MCP tools and IPM's <code>&lt;Invoke&gt;</code>, passes nothing and the step leaves
/// whatever bundle is already installed untouched. An absent or empty source is a
/// <code>warn</code> naming the directory and never an error -- an instance with no client
/// bundle still installs, still answers the API, and answers the shell with
/// <code>STATIC.NOBUNDLE</code> until a bundle arrives.</p>
ClassMethod Install(pProfile As %String = "", pUnexpire As %Boolean = 0, pBundleSource As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tFailingStep = ""
    Set tStoredVersion = 0
    Set tLocked = 0
    Kill tReports
    Kill tCreatedApps
    Try {
        ; The namespace guard runs before ANYTHING else -- even before Names() --
        ; because Names() itself unconditionally references
        ; ##class(OcuPilot.Kernel.State.Base) for the production profile's object names,
        ; and that fresh ##class() dispatch re-resolves against whatever namespace is
        ; CURRENT (this class's own header); verified live that calling it while
        ; $NAMESPACE is %SYS or USER raises <CLASS DOES NOT EXIST> on Kernel.State.Base,
        ; not this guard's own message. GuardInstallNamespace itself is always safe -- it
        ; reads %SYS.Namespace, a %-package class reachable from any namespace, and this
        ; class's own parameters.
        Set tSC = ..GuardInstallNamespace("Install", .tInstallNs)
        If $$$ISERR(tSC) Quit

        ; No failing step is named for Names() (code review round 3): it refuses a profile
        ; that does not exist, and naming the step made the block after the Try/Catch
        ; record a "failed" version row FOR that non-existent profile -- a row nothing ever
        ; removes, since Uninstall refuses the same profile. A refused profile writes nothing.
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit

        ; DW-47: one install of a profile at a time. Taken before the version row is read, so
        ; the first-install and stored-version answers below, and the upsert EnsureVersion makes
        ; at the end, all belong to this run alone. No failing step is named on a refusal: a
        ; refused install writes nothing, not even a "failed" row.
        Set tSC = ..LockInstall(pProfile, "Install")
        If $$$ISERR(tSC) {
            Do ..Report(.tReports, "warn", "Install refused: another install, uninstall or start mark of this profile holds its install lock -- nothing was changed", {"profile": (pProfile), "waitedSeconds": (..#INSTALLLOCKSECONDS)})
            Quit
        }
        Set tLocked = 1

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
        ; Story 1.5, in this order: the role first, because the shell application names it in
        ; MatchRoles; the directory next, because the shell application carries it as its
        ; Path; then the two applications.
        Set tFailingStep = "EnsureShellRole"
        Set tSC = ..EnsureShellRole(.tNames, tInstallNs, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureShellFiles"
        Set tSC = ..EnsureShellFiles(.tNames, pBundleSource, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureShellApplication"
        Set tSC = ..EnsureShellApplication(.tNames, tInstallNs, .tReports, .tCreatedApps)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tFailingStep = "EnsureApiApplication"
        Set tSC = ..EnsureApiApplication(.tNames, tInstallNs, .tReports, .tCreatedApps)
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
        ; DW-73: only the container start path unexpires (AD-17). The step keeps its place, so
        ; a failed unexpire on a first install still leaves a "failed" row at schema version 0
        ; that the next start retries; an IPM install (pUnexpire = 0) never reaches it.
        If pUnexpire {
            Set tFailingStep = "EnsureUnexpired"
            Set tSC = ..EnsureUnexpired(..#UNEXPIREACCOUNT, tFirstInstall, .tReports)
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        } Else {
            Do ..Report(.tReports, "info", "Skipped the password-unexpire step -- only the container start path unexpires the install account, and this install was not started by it", "")
        }

        ; Never fails install (AD-27's fallback) -- ReportGatewayGap always returns OK.
        Do ..ReportGatewayGap(.tReports, .tCreatedApps)

        Set $NAMESPACE = tOrigNS
        Set tFailingStep = ""

        ; Runs in the install namespace, not the %SYS window above: a SQL GRANT is executed
        ; where the table lives, and the grantee role is created inside that window a few
        ; steps earlier.
        Set tFailingStep = "EnsureSqlPrivileges"
        Set tSC = ..EnsureSqlPrivileges(.tReports)
        If $$$ISERR(tSC) Quit
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
        ; AC3 (amended 2026-09-11): the failing step is named on the returned status itself,
        ; so StartPath hands it to the start hook, which prints it. Before this (code review
        ; round 3) the status was the step's own raw error, and on a first install that
        ; fails before EnsureApplication -- where no version row can be written -- the step
        ; name appeared nowhere at all.
        Set tSC = $$$ADDSC($$$ERROR($$$GeneralError, "Install failed at step '" _ tFailingStep _ "'"), tSC)
        Set tVerFailWriteSC = ..EnsureVersion(pProfile, "failed", tFailingStep, tStoredVersion, .tNames, .tReports)
        If $$$ISERR(tVerFailWriteSC) {
            Do ..Report(.tReports, "warn", "Install failed and could not record the failure on the version row either", {"failingStep": (tFailingStep), "error": ($System.Status.GetErrorText(tVerFailWriteSC))})
        }
    }

    ; DW-47: released only here, once the version row has recorded this run's outcome, on
    ; every exit that took it -- the argumentless Quit in each guard above, and the Catch.
    ; $NAMESPACE is the install namespace again at this point (see FlushReports below), and the
    ; lock is an extended reference into %SYS, which resolves the same from any namespace anyway
    ; (InstallLockName).
    If tLocked Do ..UnlockInstall(pProfile)

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

/// <p>The container start hook's single install entry point (Story 1.4;
/// <file>scripts/container-start.sh</file> is the hook's own shell side, and its one other
/// call, <method>MarkInstalling</method> before the recompile, installs nothing). Repeats
/// <method>Install</method>'s namespace guard as its own first act, before delegating to
/// it, so a caller that invokes <method>StartPath</method> from the wrong namespace is
/// refused identically (AC13) rather than reaching <method>Install</method> and being
/// refused a frame later. Always installs the production profile
/// (<code>""</code>); only when that succeeds, and only when <var>pDemo</var> is true,
/// creates the five opt-in demo fixtures through <class>OcuPilot.Install.Fixture</class>
/// (AD-25) -- there is no reason to seed a walkthrough on top of a failed install.</p>
/// <p>It is the one caller that asks <method>Install</method> for the <code>_SYSTEM</code>
/// unexpire step (<var>pUnexpire</var> = 1; DW-73, AD-17): a fresh Community container
/// expires <code>_SYSTEM</code> on first login, and the container start path is the only
/// path on which that is known to be the vendor's default rather than an operator's choice.</p>
/// <p><b>It holds the production profile's install lock for its whole run (step-04 review of
/// rework iteration 8).</b> <method>Install</method> releases the lock once its version row has
/// recorded the outcome, and the demo fixtures are created after that. Without a lock of its own,
/// an <method>Uninstall</method> in another process could take the lock in that gap, read the
/// inventory and drop the protected database while <class>OcuPilot.Install.Fixture</class> was
/// still creating objects and writing their inventory rows into it -- orphaning them, which
/// DW-65 forbids. The lock is incremental, so <method>Install</method> takes it again at once in
/// this process. A call that is still blocked after <parameter>INSTALLLOCKSECONDS</parameter>
/// refuses with an error naming the profile, and changes nothing.</p>
/// <p><var>pBundleSource</var> is the built client bundle's directory on the container's own
/// filesystem (Story 1.5), passed straight to <method>Install</method>. The start hook
/// <b>always</b> names that directory, present or not, so install stays the one place that
/// decides what an absent bundle means: a named-but-absent source is a <code>warn</code> and
/// the start carries on, so a clone whose client has never been built still starts. The
/// empty argument is the other case entirely -- a caller that never asked for a bundle (the
/// IRIS MCP tools, IPM's <code>&lt;Invoke&gt;</code>) -- and reports an <code>info</code>.</p>
ClassMethod StartPath(pDemo As %Boolean = 0, pBundleSource As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tGuardSC = ..GuardInstallNamespace("StartPath", .tInstallNs)
    If $$$ISERR(tGuardSC) {
        Quit tGuardSC
    }

    Set tSC = $$$OK
    Set tLocked = 0
    ; Released on every exit that took it, a thrown error included: an MCP call runs in a
    ; long-lived process, where a lock left behind would stall every later install, mark and
    ; uninstall of the profile until that process ended. Taken inside the Try, as Install,
    ; MarkInstalling and Uninstall take it (code review round 4): the lock itself raises
    ; <PROTECT> for a caller with no privilege on IRISSYS (InstallLockName), and that now comes
    ; back as a status instead of escaping StartPath as a thrown error.
    Try {
        Set tSC = ..LockInstall("", "StartPath")
        If $$$ISERR(tSC) {
            Do ..LogWarn("StartPath refused: another install, uninstall or start mark of the production profile holds its install lock -- nothing was changed", {"profile": "", "waitedSeconds": (..#INSTALLLOCKSECONDS)})
            Quit
        }
        Set tLocked = 1
        Set tSC = ..StartPathLocked(pDemo, pBundleSource)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If tLocked Do ..UnlockInstall("")
    Quit tSC
}

/// <p>The body of <method>StartPath</method>, run while it holds the production profile's
/// install lock: install production, then, only when that succeeded and <var>pDemo</var> is
/// true, create the demo fixtures. <code>[ Private ]</code>: not an entry point.</p>
ClassMethod StartPathLocked(pDemo As %Boolean, pBundleSource As %String = "") As %Status [ Private ]
{
    Set tSC = ..Install("", 1, pBundleSource)
    If $$$ISERR(tSC) Quit tSC

    If pDemo {
        Kill tFixtureReports
        Do ..CreateDemoFixtures(.tFixtureReports)
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

/// <p>The pre-recompile mark (DW-72, AD-38 as amended 2026-09-11): flip
/// <var>pProfile</var>'s version row from <code>installed</code> to <code>installing</code>, so
/// <method>GateStatus</method> stops answering <code>installed</code> from the moment a container
/// start begins recompiling OcuPilot until that start's <method>Install</method> records its own
/// outcome. <file>scripts/container-start.sh</file> calls it before it loads and compiles
/// <code>src/OcuPilot/</code>. Without it, a restart at the same schema version served the
/// previous start's <code>installed</code> row for the whole recompile and re-install.</p>
/// <p>It changes only an <code>installed</code> row, and only its phase (and
/// <property>UpdatedAt</property>): the <property>SchemaVersion</property> stays what it was, so
/// <method>PlanMigration</method>'s answer on the install that follows is unchanged, and so is
/// <method>Install</method>'s first-install answer (a <code>failed</code> row at schema version 0).
/// A <code>failed</code> row, an <code>installing</code> row and an absent row are left exactly as
/// they are, since each already refuses traffic; a mark never creates a row, and never rewrites
/// the failed-at-0 row that keeps the <code>_SYSTEM</code> unexpire retrying after a failed
/// first install. The write goes through <method>OcuPilot.Kernel.State.Base.GuardedSave</method>,
/// the same escalation every version-row write uses.</p>
/// <p><var>pOutcome</var>: <code>marked</code>, <code>norow</code> (no row, or no protected
/// state to hold one yet), or <code>left-</code> followed by the phase it found. It holds the
/// profile's install lock while it reads and writes (DW-47), so it never marks a row an
/// install is in the middle of recording; still blocked after
/// <parameter>INSTALLLOCKSECONDS</parameter>, it refuses and writes nothing.</p>
/// <p>Not an install entry point: it installs nothing, and a failed or refused mark never fails
/// a start -- the hook logs it and carries on. <var>pProfile</var> defaults to production; the
/// suite pins it on the <code>"probe"</code> profile (<class>OcuPilot.Test.InstallMark</class>).</p>
/// <p><b>A start that fails before its install records an outcome</b> -- a compile that fails, a
/// session that crashes, an install refused by the lock, a version row that cannot be read, a
/// refused downgrade -- leaves a marked row <code>installing</code>, with no failing step named,
/// until a later start's install records one. The gate answers <code>INSTALL.INSTALLING</code>
/// rather than <code>INSTALL.FAILED</code> meanwhile; the hook's log names the failure, and the
/// container stops after its restart retries (AD-38 leaves the mark in place until an install
/// records an outcome). On a downgrade, <method>Install</method> itself changes nothing, but the
/// newer code's mark has already turned the row <code>installing</code>.</p>
/// <p><b>Its call shape is a contract across versions.</b> The hook calls this method on the
/// class the <i>previous</i> start compiled, with this start's arguments
/// (<code>MarkInstalling("", .tMarkOutcome)</code>), and checks only that the method exists. A
/// change to its signature must keep that call working; otherwise the first start after the
/// change logs a failed mark and serves the previous row through its recompile.</p>
ClassMethod MarkInstalling(pProfile As %String = "", Output pOutcome As %String) As %Status
{
    Set tSC = $$$OK
    Set pOutcome = ""
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Kill tReports
    Try {
        ; The same namespace guard as Install and StartPath: Names() and the version row both
        ; need OcuPilot classes, which are mapped only into the install namespace.
        Set tSC = ..GuardInstallNamespace("MarkInstalling", .tInstallNs)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit

        Set tSC = ..LockInstall(pProfile, "MarkInstalling")
        If $$$ISERR(tSC) Quit
        Set tLocked = 1

        ; For production, no privileged routine application yet means no protected database
        ; yet, so no row can exist to mark. For the "probe" profile this reads the probe's own
        ; application, while the probe's rows live in production's protected database: the same
        ; probe-only gap as Install's first-install check (DW-78). Its own "genuinely first
        ; install" line belongs to Install, not here, so its report goes into a scratch array
        ; that is never flushed.
        Kill tScratch
        If ..IsEscalationInfrastructureAbsent(.tNames, .tScratch) {
            Set pOutcome = "norow"
            Quit
        }
        Set tRow = $$$NULLOREF
        Set tSC = ..CurrentVersionRow(pProfile, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set pOutcome = "norow"
            Quit
        }
        If tRow.Phase '= "installed" {
            Set pOutcome = "left-" _ tRow.Phase
            Quit
        }
        Set tRow.Phase = "installing"
        Set tRow.FailingStep = ""
        Set tRow.UpdatedAt = $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
        Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
        If $$$ISERR(tSC) Quit
        Set pOutcome = "marked"
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If tLocked Do ..UnlockInstall(pProfile)

    If $$$ISERR(tSC) {
        Do ..Report(.tReports, "warn", "Could not mark the version row installing before the recompile", {"profile": (pProfile), "error": ($System.Status.GetErrorText(tSC))})
    } ElseIf pOutcome = "marked" {
        Do ..Report(.tReports, "info", "Marked the version row installing until this start's install records its outcome", {"profile": (pProfile)})
    } Else {
        Do ..Report(.tReports, "info", "Left the version row as it is -- only an installed row is marked", {"profile": (pProfile), "outcome": (pOutcome)})
    }
    ; Only after the namespace guard passed can FlushReports reach OcuPilot.Kernel.Audit.Log
    ; (this class's header); a refusal from the wrong namespace goes back as the status alone.
    ; A refused guard leaves tInstallNs "", which never equals a namespace name.
    If $NAMESPACE = $Get(tInstallNs) Do ..FlushReports(.tReports)
    Quit tSC
}

/// <p>Create the production profile's opt-in demo fixtures (AD-25) -- the one call
/// <method>StartPath</method> makes into <class>OcuPilot.Install.Fixture</class>, and only
/// when its <var>pDemo</var> flag is set. Always returns what
/// <method>OcuPilot.Install.Fixture.Create</method> returns (<code>$$$OK</code>; fixture
/// failures are warns in <var>pFixtureReports</var>).</p>
/// <p><b>A seam, extracted for DW-56 (rework iteration 5).</b> AC9's flag-absent pin used
/// to observe the flag only through the production inventory's row count, and on an
/// instance that already carries the production fixtures -- which is exactly this
/// repository's own configuration, <code>OCUPILOT_DEMO: "1"</code> -- a
/// <method>StartPath</method> that ignored the flag and ran the fixtures anyway found
/// every object already present, noted nothing new, and left that count unchanged: the
/// gate could not fail where it mattered. <class>OcuPilot.Test.InstallerProbe</class>
/// overrides this to record the call instead of making it, so
/// <class>OcuPilot.Test.DemoOptIn</class> can assert the flag is honoured at the call site
/// in both directions without touching a real production fixture. Production never
/// overrides this.</p>
/// <p><b><code>[ Private ]</code></b> (rework iteration 5 review): this is not a second
/// installer entry point, and it must not look like one. A subclass can still override it,
/// and <method>StartPath</method> reaches it by <code>..</code> dispatch.</p>
ClassMethod CreateDemoFixtures(ByRef pFixtureReports) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Install.Fixture).Create("", .pFixtureReports)
}

/// <p>Remove <var>pProfile</var>'s opt-in demo fixtures (AD-25) -- the one call
/// <method>Uninstall</method> makes into <class>OcuPilot.Install.Fixture</class> to do it.
/// Always returns what <method>OcuPilot.Install.Fixture.Remove</method> returns
/// (<code>$$$OK</code>; removal failures are warns in <var>pFixtureReports</var>).</p>
/// <p><b>A seam, extracted for DW-65 (rework iteration 6)</b>, the same shape as
/// <method>CreateDemoFixtures</method>. <method>Uninstall</method>'s refusal to drop the
/// protected database while an inventory row remains can only be pinned by making a
/// fixture delete fail for real, and the call used to be hardcoded to the base
/// <class>OcuPilot.Install.Fixture</class>, which no test can make fail.
/// <class>OcuPilot.Test.UninstallFault</class> overrides this to remove through
/// <class>OcuPilot.Test.FixtureFault</class>, whose delete faults a test can arm.
/// Production never overrides this, and like <method>CreateDemoFixtures</method> it is
/// <code>[ Private ]</code> -- not a second entry point.</p>
ClassMethod RemoveDemoFixtures(pProfile As %String, ByRef pFixtureReports) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Install.Fixture).Remove(pProfile, .pFixtureReports)
}

/// <p>Read back what <var>pProfile</var>'s fixture inventory still records after
/// <method>RemoveDemoFixtures</method> -- the one call <method>Uninstall</method> makes into
/// <method>OcuPilot.Install.Fixture.Remaining</method>, and what it returns.</p>
/// <p><b>A seam (rework iteration 6 review)</b>, the same shape as
/// <method>RemoveDemoFixtures</method>: <method>Uninstall</method>'s refusal when this read
/// fails could not be forced by any test while the call was hardcoded to the base class.
/// <class>OcuPilot.Test.UninstallFault</class> overrides it to fail on demand. Production
/// never overrides it, and it is <code>[ Private ]</code> -- not a second entry point.</p>
ClassMethod RemainingDemoFixtures(pProfile As %String, Output pLeft) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Install.Fixture).Remaining(pProfile, .pLeft)
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
    ; Fail-safe (rework iteration 5 review): no application name means Names() did not
    ; succeed. Treat that as "present", like every other failure here. Before this line,
    ; Security.Applications.Exists("") answered 0, so an invalid-profile call reported
    ; "genuinely first install" and skipped the read (seen live in messages.log).
    Set tApplication = $Get(pNames("application"))
    If tApplication = "" Quit 0
    Set tAbsent = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tAbsent = '..EscalationApplicationExists(tApplication)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tAbsent = 0
    }
    If tAbsent {
        Do ..Report(.pReports, "info", "Escalation infrastructure not found yet -- this is a genuinely first install on this durable volume", {"application": (tApplication)})
    }
    Quit tAbsent
}

/// <p>Whether the privileged routine application named <var>pApplication</var> exists.
/// The one decision <method>IsEscalationInfrastructureAbsent</method> makes, extracted
/// into its own narrow, non-private, overridable method (DW-63, rework iteration 5) so
/// <class>OcuPilot.Test.EscalationGap</class> can force the "genuinely absent" state --
/// the state of a first-ever install on a fresh durable volume -- without a disposable
/// container. Before this seam existed, the live-discovered <code>ERROR #868</code> fix
/// it serves had no test at all: every instance this suite runs against has carried
/// <code>OcuPilotState</code> since an early story, so the branch was unreachable.
/// Production never overrides this. <b>Caller contract:</b> <code>$NAMESPACE</code> must
/// already be <code>%SYS</code> -- <method>IsEscalationInfrastructureAbsent</method>
/// opens that window around this call.</p>
ClassMethod EscalationApplicationExists(pApplication As %String) As %Boolean
{
    Quit ''##class(Security.Applications).Exists(pApplication, .tE, .tS)
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
/// <code>installed</code> <b>and</b> its stored schema version equals the deployed one;
/// otherwise <code>installing</code> (an unfinished row -- including one a container start has
/// marked before its recompile, <method>MarkInstalling</method> -- an absent or unreadable row,
/// or a stored version ahead of the deployed code), <code>failed</code>, or
/// <code>upgraderequired</code> (a stored version behind it). Built on
/// <method>Phase</method>'s own fail-closed discipline -- a read failure or an absent row is
/// never <code>installed</code>. Every rung is pinned by <class>OcuPilot.Test.GateLadder</class>
/// against synthetic, unsaved rows (code review round 3).</p>
/// <p>The phase is read before the version, so on the container path an upgrade answers
/// <code>installing</code> while it runs: the start's mark has turned the row
/// <code>installing</code> at its old version. <code>upgraderequired</code> is what an instance
/// answers when its code is newer than an <code>installed</code> row and no install has run yet
/// -- an IPM upgrade before its <code>&lt;Invoke&gt;</code>, or a container start whose mark was
/// skipped or failed.</p>
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
/// <p><b>Correction at its origin (rework iteration 5, 2026-09-11) -- the paragraph above
/// overclaims.</b> The guard does make this method skip the escalated <i>read</i> when the
/// escalation infrastructure is absent (pinned by
/// <method>OcuPilot.Test.Escalation.TestEnsureVersionSkipsTheEscalatedReadWhenAbsent</method>),
/// but it does <b>not</b> get the <code>failed</code> row written on such a run: the
/// <method>OcuPilot.Kernel.State.Base.GuardedSave</method> two statements later opens the
/// same escalation (<code>$SYSTEM.Security.AddRoles</code> on the same application) and
/// fails identically -- verified live this pass that <code>AddRoles</code> on an
/// application that does not exist returns <code>ERROR #868: Application ... not
/// found.</code> On a genuinely first install that fails <i>before</i>
/// <method>EnsureApplication</method>, there is no protected database and no privileged
/// application to record into yet, so no version row can be written by construction; the
/// run still fails loudly (<method>StartPath</method> returns the error naming the failing
/// step, the start hook exits non-zero and logs it -- true only since code review round 3,
/// which made <method>Install</method> put the step's name on its returned status) and <method>Phase</method> /
/// <method>GateStatus</method> fail closed to <code>installing</code>, so the health check
/// stays unhealthy and the gate refuses traffic -- but AC3's "the version row's phase is
/// <code>failed</code> with the failing step named" is not met on that one path. The guard
/// here is outcome-neutral on that path; the guard that genuinely matters is
/// <method>Install</method>'s own pre-read one, on the success path.</p>
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
/// -- gated on <var>pFirstInstall</var>, which the caller derives from the version row
/// (no row, or a <code>failed</code> row that never reached schema version 1) and passes
/// in, never recomputed here. <method>Install</method> reaches this step only when
/// <method>StartPath</method> asks for it (<var>pUnexpire</var>, DW-73): an IPM install never
/// does. The caller always passes
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

/// <p>Report the CSP Gateway registration gap for every web application this run created --
/// <var>pCreatedApps</var>, the array <method>EnsureShellApplication</method> and
/// <method>EnsureApiApplication</method> note a path into when they create one -- and the
/// current Web Gateway response timeout as information only (AD-17, AD-27), never a
/// prerequisite and never modified. Never fails install: any problem reading the timeout is
/// reported as "not available" rather than propagated.</p>
/// <p><var>pCreatedApps</var> is optional, and callers that predate it pass one argument
/// (<class>OcuPilot.Test.Version</class>, <class>OcuPilot.Test.GatewayIni</class>): an
/// undefined array reads as "this run created none", which is the same line the step emitted
/// before it existed.</p>
ClassMethod ReportGatewayGap(ByRef pReports, ByRef pCreatedApps) As %Status
{
    Set tSC = $$$OK
    Try {
        ; One line per application this run created, each carrying its own data.path -- the
        ; same shape OcuPilot.Install.Fixture.CreateWebApp emits for the demo fixture, so a
        ; reader (and OcuPilot.Test.Demo's assertion helper) matches one line per created
        ; application whichever step created it.
        Set tAppN = $Order(pCreatedApps(""))
        Set tAny = 0
        While tAppN '= "" {
            Set tAny = 1
            Do ..Report(.pReports, "info", "Security.Applications.Create does not notify the CSP Gateway -- this web application may 404 until an SMP Save or a Gateway restart", {"path": ($Get(pCreatedApps(tAppN)))})
            Set tAppN = $Order(pCreatedApps(tAppN))
        }
        If 'tAny {
            ; Fix Pack F-5: this used to say "No web application was created by this run" --
            ; true of Install() alone, which never created one before Story 1.5, but
            ; StartPath drains this report merged with Install.Fixture's own reports into ONE
            ; stream, and the demo fixture's CreateWebApp emits its OWN gap line for the
            ; application it DID just create in that same run whenever the opt-in flag is
            ; set -- two lines that read as contradicting each other. Worded to stay true
            ; regardless of what ran alongside it.
            Do ..Report(.pReports, "info", "Security.Applications.Create does not notify the CSP Gateway -- a new web application may 404 until an SMP Save or a Gateway restart. This install run created no web application; any step that does, including the opt-in demo fixture, reports its own gap.", "")
        }

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
/// registry (<method>GatewayTimeoutFromRegistry</method>) and falling back to the Gateway's
/// own configuration file (<method>GatewayTimeoutFromConfigFile</method>, whose path
/// <method>GatewayConfigFilePath</method> resolves at runtime; AD-21: never a
/// caller-supplied path) whenever the registry does not answer -- no Gateway registered,
/// no default parameters, or a failed read (the AD-27 fallback this story's "Gateway read
/// fails" matrix row names). Neither source answering leaves both outputs <code>""</code>, never an
/// error. Overridable so <class>OcuPilot.Test.MigrateFault</class> can force the "neither
/// answers" branch without needing a genuinely Gateway-less instance; production never
/// overrides this.</p>
/// <p><b>DW-67 (rework iteration 6).</b> The registry read is its own overridable method so
/// <class>OcuPilot.Test.GatewayGap</class> can make the registry silent, or make its read
/// fail, through this real method -- which is what pins the call into the
/// configuration-file fallback below. Before the seam, deleting that call left every test
/// green: <class>OcuPilot.Test.GatewayIni</class> drives the file reader directly, the
/// registry answers on the long-lived instance, and <class>OcuPilot.Test.MigrateFault</class>
/// overrides this whole method. The fallback's only execution evidence was two throwaway
/// containers whose registry had not answered yet at start. A registry read that
/// <i>fails</i> now falls back to the file too; before the seam it returned the error and
/// the file was never consulted.</p>
ClassMethod GatewayResponseTimeout(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = ""
    Set pSource = ""
    Set tSC = $$$OK
    Try {
        Set tRegTimeout = ""
        Set tRegSource = ""
        Set tRegSC = ..GatewayTimeoutFromRegistry(.tRegTimeout, .tRegSource)
        If $$$ISOK(tRegSC) && (tRegTimeout '= "") {
            Set pTimeout = tRegTimeout
            Set pSource = tRegSource
            Quit
        }

        Set tSC = ..GatewayTimeoutFromConfigFile(.pTimeout, .pSource)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The live half of <method>GatewayResponseTimeout</method>:
/// <code>$SYSTEM.CSP.GetGatewayRegistry().GetGatewayMgrs("a")</code>'s first entry's
/// <code>GetDefaultParams</code>, verified live (Story 1.4) to return
/// <code>Server_Response_Timeout=60</code> on this instance. Returns <code>$$$OK</code> with
/// both outputs <code>""</code> when no Gateway is registered, when it carries no such
/// parameter, and when <code>GetDefaultParams</code> itself returns an error status -- all
/// three read as "the registry did not answer". Only a thrown error comes back as an error
/// status. <method>GatewayResponseTimeout</method> treats every one of these the same way,
/// by reading the configuration file instead.</p>
/// <p><b>A seam (DW-67, rework iteration 6)</b> -- <class>OcuPilot.Test.GatewayGap</class>
/// overrides it to make the registry silent or failing. Production never overrides it,
/// and it is <code>[ Private ]</code>: its only caller is
/// <method>GatewayResponseTimeout</method>. Runs inside <method>Install</method>'s
/// <code>%SYS</code> window, reached by <code>..</code> dispatch like every other step
/// there.</p>
ClassMethod GatewayTimeoutFromRegistry(Output pTimeout As %String, Output pSource As %String) As %Status [ Private ]
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
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The Web Gateway's own configuration file, resolved at runtime (AD-21: never a
/// caller-supplied path) -- <code>csp/bin/CSP.ini</code> under the instance's data
/// directory when that copy exists, otherwise under the install directory. Public so a
/// test can assert the resolved path against the file that actually exists on this
/// instance.</p>
/// <p><b>DW-51, corrected at its origin (rework iteration 5, 2026-09-11).</b> The fallback
/// used to probe <code>$System.Util.InstallDirectory() _ "CSP.ini"</code>, i.e.
/// <code>/usr/irissys/CSP.ini</code> -- verified live this pass that
/// <code>##class(%File).Exists()</code> on that path returns <b>0</b>. The only
/// <code>CSP.ini</code> on this container is
/// <code>&lt;installdir&gt;csp/bin/CSP.ini</code> plus its durable twin under the data
/// directory, so the whole fallback branch was unreachable, and anchoring its key match
/// without correcting the path would have been an unfalsifiable change -- there would
/// have been no way to demonstrate it red (Rule 19). The path correction and the
/// anchoring are therefore one fix, not two.</p>
/// <p><b>Why the data directory first.</b> Read live this pass: on this durable-%SYS
/// container <code>$System.Util.DataDirectory()</code> is <code>/durable/iris/</code> and
/// <code>$System.Util.InstallDirectory()</code> is <code>/usr/irissys/</code>; both carry
/// a <code>csp/bin/CSP.ini</code>, byte-identical today, but the install-directory copy is
/// the image's own original (dated with the image build) while the data-directory copy is
/// the one the instance rewrote at start. <i>Inference, not observed:</i> a Gateway
/// setting an operator changes after start lands in the latter, so reading the former
/// could report a stale value. The install-directory copy stays as the fallback for an
/// instance whose data directory holds none. <class>OcuPilot.Test.GatewayIni</class> pins
/// the data-directory-first order.</p>
ClassMethod GatewayConfigFilePath() As %String
{
    Set tDataCopy = ##class(%File).NormalizeFilename("csp/bin/CSP.ini", $System.Util.DataDirectory())
    If ##class(%File).Exists(tDataCopy) Quit tDataCopy
    Quit ##class(%File).NormalizeFilename("csp/bin/CSP.ini", $System.Util.InstallDirectory())
}

/// <p>Extract <code>Server_Response_Timeout</code> from the Gateway configuration file
/// named by <method>GatewayConfigFilePath</method>. Returns <code>$$$OK</code> with both
/// outputs <code>""</code> when the file is absent or carries no such key -- an absent
/// Gateway configuration is not an error (AD-27's fallback). Public so
/// <class>OcuPilot.Test.GatewayIni</class> can drive the real file read directly, which is
/// what pins the corrected path: reverting it to the old
/// <code>&lt;installdir&gt;CSP.ini</code> form makes this method find no file and return
/// nothing.</p>
ClassMethod GatewayTimeoutFromConfigFile(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = ""
    Set pSource = ""
    Set tSC = $$$OK
    Set tFileOpen = 0
    Try {
        Set tCandidate = ..GatewayConfigFilePath()
        If '##class(%File).Exists(tCandidate) Quit
        Set tFile = ##class(%File).%New(tCandidate)
        Set tOpenSC = tFile.Open("RSK\RAW\")
        If $$$ISERR(tOpenSC) Quit
        Set tFileOpen = 1
        Set tText = ""
        While 'tFile.AtEnd {
            Set tText = tText _ tFile.ReadLine() _ $Char(10)
        }
        Do tFile.Close()
        Set tFileOpen = 0
        If ..GatewayTimeoutFromIni(tText, .tValue) {
            Set pTimeout = tValue
            Set pSource = "configuration file (" _ tCandidate _ ")"
        }
    } Catch ex {
        ; Fix Pack F-4: the normal-path Close() above runs only after the read loop
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

/// <p>Pure parser (DW-51): find <code>Server_Response_Timeout</code>'s value in
/// <var>pText</var>, the whole text of a Web Gateway <code>CSP.ini</code>, returning
/// <code>1</code> and setting <var>pTimeout</var> only on an exact, section-scoped,
/// key-anchored match.</p>
/// <p><b>Anchored, not a substring search.</b> The shipped code matched
/// <code>tLine [ "Server_Response_Timeout"</code> and then took everything after the
/// first <code>=</code>, so a commented-out line, a longer key that merely contains the
/// name (<code>Server_Response_Timeout_Override</code>), or the same key under a
/// different section would all be read as the answer. This tracks the current
/// <code>[Section]</code>, skips blank and comment (<code>;</code> / <code>#</code>)
/// lines, splits on the <b>first</b> <code>=</code>, and accepts the value only when the
/// stripped key is exactly <code>Server_Response_Timeout</code> and the current section
/// is <code>SYSTEM</code>.</p>
/// <p><b>Why section-scoped matters here specifically:</b> the real file's
/// <code>[SYSTEM]</code> section also carries a <code>Password=</code> line holding a
/// PBKDF2 hash (read live this pass), so the extraction must stay key-scoped and must
/// never report a whole line. The real file's format, also read live: INI sections
/// (<code>[SYSTEM]</code>, <code>[LOCAL]</code>, <code>[SYSTEM_INDEX]</code>,
/// <code>[APP_PATH_INDEX]</code>, <code>[APP_PATH:/...]</code>) with
/// <code>Key=Value</code> and no spaces around <code>=</code>; comment lines are
/// tolerated here rather than observed, since none are present in the shipped file.</p>
ClassMethod GatewayTimeoutFromIni(pText As %String, Output pTimeout As %String) As %Boolean
{
    Set pTimeout = ""
    Set tSection = ""
    For tI = 1:1:$Length(pText, $Char(10)) {
        Set tLine = $ZStrip($Translate($Piece(pText, $Char(10), tI), $Char(13), ""), "<>W")
        If tLine = "" Continue
        If ($Extract(tLine, 1) = ";") || ($Extract(tLine, 1) = "#") Continue
        If $Extract(tLine, 1) = "[" {
            Set tSection = $ZConvert($Piece($Extract(tLine, 2, *), "]", 1), "U")
            Continue
        }
        If tLine '[ "=" Continue
        Set tKey = $ZStrip($Piece(tLine, "=", 1), "<>W")
        If tKey '= "Server_Response_Timeout" Continue
        If tSection '= "SYSTEM" Continue
        Set pTimeout = $ZStrip($Extract(tLine, $Length($Piece(tLine, "=", 1)) + 2, *), "<>W")
        Quit
    }
    Quit pTimeout '= ""
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
/// <p><b>Every step must be safe to run again.</b> A failure leaves the stored version at
/// <var>pFromVersion</var> (AC5), not at the last step that succeeded, so the next start
/// re-runs every step from there -- including the ones that already completed.</p>
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

/// <p>The guarding resource of <var>pInstallNs</var>'s <b>routine</b> database -- the
/// database OcuPilot's own code is compiled into (AD-9) -- read from
/// <class>SYS.Database</class> rather than assembled from the <code>%DB_&lt;NAME&gt;</code>
/// convention, so a database whose resource was named some other way is still described
/// correctly. <b>Caller contract:</b> <code>$NAMESPACE</code> must already be
/// <code>%SYS</code>.</p>
ClassMethod CodeDatabaseResource(pInstallNs As %String, Output pResource As %String) As %Status [ Private ]
{
    Set pResource = ""
    Set tSC = $$$OK
    Try {
        Set tNsObj = ##class(Config.Namespaces).Open(pInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ pInstallNs)
            Quit
        }
        If tNsObj.Routines = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the routine database for namespace " _ pInstallNs)
            Quit
        }
        Set tSC = ##class(Config.Databases).Get(tNsObj.Routines, .tDbProps)
        If $$$ISERR(tSC) Quit
        Set tDbObj = ##class(SYS.Database).%OpenId($Get(tDbProps("Directory")))
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database of " _ pInstallNs)
            Quit
        }
        Set pResource = tDbObj.ResourceName
        If pResource = "" {
            Set tSC = $$$ERROR($$$GeneralError, "The routine database of " _ pInstallNs _ " carries no guarding resource")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the shell application's <b>one</b> purpose-built matching role exists and
/// grants <b>read on the install namespace's routine database and nothing else</b> (AC1,
/// AD-21 as amended 2026-09-11).</p>
/// <p><b>Why this role exists at all.</b> Database READ is routine-execution permission
/// (AD-9), so an anonymous request cannot load
/// <class>OcuPilot.Api.StaticHandler</class> from the install namespace's database unless
/// the application grants read on it: without the role the same request answers 500 with a
/// <code>&lt;PROTECT&gt;</code> error that also leaks the database directory to the caller.
/// The role buys the right to execute OcuPilot's own code and no data privilege beyond it
/// -- OcuPilot's state lives in the separate protected database (AD-9), which this role does
/// not reach, and the handler reads no global at all.</p>
/// <p>Guard-then-act with drift repair, like every other ensure step: an existing role whose
/// resource set has moved, or which has acquired a granted role (AD-10's "granting privilege
/// through any path"), is repaired back and the repair reported.</p>
ClassMethod EnsureShellRole(ByRef pNames, pInstallNs As %String, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tName = pNames("shellRole")
        Set tSC = ..CodeDatabaseResource(pInstallNs, .tCodeResource)
        If $$$ISERR(tSC) Quit
        Set tWantResources = tCodeResource _ ":R"

        If ##class(Security.Roles).Exists(tName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Roles).Get(tName, .tProps, .tRoleObj)
            If $$$ISERR(tSC) Quit
            If ($Get(tProps("Resources")) '= tWantResources) || ($Get(tProps("GrantedRoles")) '= "") {
                Set tModProps("Resources") = tWantResources
                Set tModProps("GrantedRoles") = ""
                Set tModProps("ForceSave") = 2
                Set tSC = ##class(Security.Roles).Modify(tName, .tModProps)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired the shell application's read-only role", {"role": (tName), "resources": (tWantResources)})
            } Else {
                Do ..Report(.pReports, "info", "Shell application role already correct", {"role": (tName)})
            }
        } Else {
            Set tSC = ##class(Security.Roles).Create(tName, "OcuPilot shell: read-only on the install namespace's code database", tWantResources, "")
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "info", "Created the shell application's read-only role", {"role": (tName), "resources": (tWantResources)})
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the shell application's own directory exists and, when
/// <var>pBundleSource</var> names a directory that actually holds a built client, that the
/// directory carries that bundle and nothing else (AC11).</p>
/// <p><b>Never an error for a missing bundle.</b> A source that is named but absent, or that
/// holds no <code>index.html</code>, is a <code>warn</code> naming the directory, and the
/// shell directory is left exactly as it is. A run that names <b>no</b> source at all -- the
/// MCP tools, IPM's <code>&lt;Invoke&gt;</code> -- is not that case and reports it as its own
/// <code>info</code>: it never looked for a bundle, so saying it failed to find one would be
/// a warning for a non-event on every such run.</p>
/// <p>With a usable source the directory's contents are replaced, so a bundle whose hashed
/// filenames have changed does not accumulate alongside the new one. The clearing step's
/// result is checked: a directory that could not be cleared leaves the previously installed
/// bundle in place and reports it, rather than accumulating a second bundle's hashed files
/// beside the first while reporting success.</p>
ClassMethod EnsureShellFiles(ByRef pNames, pBundleSource As %String, ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tTarget = pNames("shellDirectory")
        If '##class(%File).DirectoryExists(tTarget) {
            Do ##class(%File).CreateDirectoryChain(tTarget, .tMkReturn)
            If '##class(%File).DirectoryExists(tTarget) {
                Set tSC = $$$ERROR($$$GeneralError, "Could not create the shell bundle directory " _ tTarget _ " (" _ $Get(tMkReturn) _ ")")
                Quit
            }
        }

        If pBundleSource = "" {
            Do ..Report(.pReports, "info", "No client bundle source was named for this run, so whatever bundle is already installed is left exactly as it is", {"directory": (tTarget)})
            Quit
        }
        Set tSource = ##class(%File).NormalizeDirectory(pBundleSource)
        If ('##class(%File).DirectoryExists(tSource)) || ('##class(%File).Exists(tSource _ "index.html")) {
            Do ..Report(.pReports, "warn", "No built client bundle was installed: the source directory named for this run holds no index.html, so the shell will report that no bundle is installed until one is built and install runs again", {"source": (pBundleSource), "directory": (tTarget)})
            Quit
        }
        ; Equality is not the only destructive overlap: the clearing step below removes the
        ; target tree, so a source ANYWHERE INSIDE the target is destroyed before the copy,
        ; and a target inside the source is a directory copied into itself. Both directions
        ; are refused. Both strings are normalized directories carrying a trailing
        ; separator, so a prefix test cannot match a sibling.
        If ($Extract(tSource, 1, $Length(tTarget)) = tTarget) || ($Extract(tTarget, 1, $Length(tSource)) = tSource) {
            Do ..Report(.pReports, "warn", "The named client bundle source overlaps the shell application's own directory, so nothing was copied -- clearing the target first would have destroyed the source", {"source": (tSource), "directory": (tTarget)})
            Quit
        }

        If '##class(%File).RemoveDirectoryTree(tTarget) {
            Do ..Report(.pReports, "warn", "The shell application's directory could not be cleared, so the bundle already installed there is left in place and the new one was not copied", {"source": (tSource), "directory": (tTarget)})
            Quit
        }
        Do ##class(%File).CreateDirectoryChain(tTarget, .tMkReturn2)
        If '##class(%File).DirectoryExists(tTarget) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not recreate the shell bundle directory " _ tTarget _ " (" _ $Get(tMkReturn2) _ ")")
            Quit
        }
        Set tCopied = 0
        Set tSC = ..CopyTree(tSource, tTarget, .tCopied)
        If $$$ISERR(tSC) Quit
        Do ..Report(.pReports, "info", "Installed the built client bundle into the shell application's directory", {"source": (tSource), "directory": (tTarget), "files": (tCopied)})
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Copy every file under <var>pSource</var> into <var>pTarget</var>, recursing into
/// subdirectories and counting what it copied. Both paths are resolved on the instance --
/// nothing here comes from a request (AD-21).</p>
ClassMethod CopyTree(pSource As %String, pTarget As %String, ByRef pCopied As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tRS = ##class(%ResultSet).%New("%File:FileSet")
        Set tSC = tRS.Execute(pSource, "*", "", 1)
        If $$$ISERR(tSC) Quit
        While tRS.Next() {
            Set tName = tRS.Get("Name")
            Set tType = tRS.Get("Type")
            Set tLeaf = tRS.Get("ItemName")
            If tLeaf = "" Continue
            If tType = "D" {
                Set tChildTarget = ##class(%File).NormalizeDirectory(pTarget _ tLeaf)
                Do ##class(%File).CreateDirectoryChain(tChildTarget, .tMk)
                Set tSC = ..CopyTree(##class(%File).NormalizeDirectory(tName), tChildTarget, .pCopied)
                If $$$ISERR(tSC) Quit
            } Else {
                If '##class(%File).CopyFile(tName, pTarget _ tLeaf, 1, .tCopyReturn) {
                    Set tSC = $$$ERROR($$$GeneralError, "Could not copy " _ tLeaf _ " into the shell bundle directory (" _ $Get(tCopyReturn) _ ")")
                    Quit
                }
                Set pCopied = $Get(pCopied) + 1
            }
        }
        Do tRS.Close()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ensure the unauthenticated <code>/ocupilot</code> shell application (AC1, AD-28):
/// enabled, in the install namespace, dispatching to
/// <class>OcuPilot.Api.StaticHandler</class>, serving no files itself
/// (<code>ServeFiles = 0</code> -- the dispatch class is the only thing that reads the
/// bundle directory), carrying that directory as its <code>Path</code>, carrying <b>no
/// application resource</b>, and carrying exactly one matching role, the purpose-built
/// read-only one <method>EnsureShellRole</method> owns.</p>
/// <p>Guard-then-act with drift repair. Records the path in <var>pCreatedApps</var> only
/// when it actually creates the application, so <method>ReportGatewayGap</method> names the
/// CSP Gateway registration gap for this run's own creations and for nothing else.</p>
ClassMethod EnsureShellApplication(ByRef pNames, pInstallNs As %String, ByRef pReports, ByRef pCreatedApps) As %Status [ Private ]
{
    Kill tComputed
    Set tComputed("NameSpace") = pInstallNs
    Set tComputed("MatchRoles") = ":" _ pNames("shellRole")
    Set tComputed("Path") = pNames("shellDirectory")
    Set tSC = ..WantFromRoster(.pNames, "shell", .tComputed, .tWant, .tDescription)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsureWebApplication(pNames("shellApplication"), tDescription, .tWant, .pReports, .pCreatedApps)
}

/// <p>Ensure the password-authenticated <code>/api/ocupilot</code> application (AC2,
/// FR-65, AD-28): enabled, in the install namespace, dispatching to
/// <class>OcuPilot.Api.Router</class>, JWT enabled at the vendor's own 60-second access and
/// 900-second refresh timeouts, joined to the vendor's <code>%ISCMgtPortal</code> group so a
/// browser already signed in to the classic portal mints silently, and with <b>no</b>
/// application resource and <b>no</b> matching role of any kind -- a request runs with
/// exactly the privileges its own account holds (AD-8).</p>
ClassMethod EnsureApiApplication(ByRef pNames, pInstallNs As %String, ByRef pReports, ByRef pCreatedApps) As %Status [ Private ]
{
    Kill tComputed
    Set tComputed("NameSpace") = pInstallNs
    Set tComputed("MatchRoles") = ""
    Set tSC = ..WantFromRoster(.pNames, "api", .tComputed, .tWant, .tDescription)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsureWebApplication(pNames("apiApplication"), tDescription, .tWant, .pReports, .pCreatedApps)
}

/// <p>The property set to assert on the roster application keyed <var>pKey</var>: the values
/// <method>RosterNames</method> resolved out of the roster's <code>manifest</code>, plus the
/// instance-derived values <var>pComputed</var> carries. Runs switched to <code>%SYS</code>,
/// so it reads <var>pNames</var> and never the roster class itself.</p>
/// <p><b>It refuses rather than returning a short set.</b> The roster's
/// <code>installer</code> list and <var>pComputed</var>'s names must be the same set: a
/// property the roster marks instance-derived that install computes no value for, a computed
/// value the roster does not mark, and a property declared on both halves are each an error.
/// <method>EnsureWebApplication</method> compares exactly the properties handed to it, so a
/// set short by one reports a drifted application correct.</p>
/// <p><b>Public, not <code>[ Private ]</code></b> -- the same documented deviation
/// <method>EnsureGrant</method> already carries -- so <class>OcuPilot.Test.RosterWant</class>
/// can drive its three refusal branches directly, with hand-built <var>pNames</var> and
/// <var>pComputed</var> arrays, rather than reaching them only through a full install.</p>
ClassMethod WantFromRoster(ByRef pNames, pKey As %String, ByRef pComputed, Output pWant, Output pDescription As %String) As %Status
{
    Set tSC = $$$OK
    Kill pWant
    Set pDescription = $Get(pNames("appDescription", pKey))
    Try {
        Set tProperty = $Order(pNames("appManifest", pKey, ""))
        While tProperty '= "" {
            Set pWant(tProperty) = pNames("appManifest", pKey, tProperty)
            Set tProperty = $Order(pNames("appManifest", pKey, tProperty))
        }

        Set tName = $Order(pNames("appInstaller", pKey, ""))
        While tName '= "" {
            If $Data(pWant(tName)) {
                Set tSC = $$$ERROR($$$GeneralError, "the roster declares '" _ tName _ "' for application '" _ pKey _ "' both as a manifest value and as instance-derived")
                Quit
            }
            If '$Data(pComputed(tName)) {
                Set tSC = $$$ERROR($$$GeneralError, "the roster marks '" _ tName _ "' instance-derived for application '" _ pKey _ "', and install computed no value for it")
                Quit
            }
            Set pWant(tName) = pComputed(tName)
            Set tName = $Order(pNames("appInstaller", pKey, tName))
        }
        If $$$ISERR(tSC) Quit

        Set tComputedName = $Order(pComputed(""))
        While tComputedName '= "" {
            If '$Data(pNames("appInstaller", pKey, tComputedName)) {
                Set tSC = $$$ERROR($$$GeneralError, "install computed '" _ tComputedName _ "' for application '" _ pKey _ "', which the roster does not mark instance-derived")
                Quit
            }
            Set tComputedName = $Order(pComputed(tComputedName))
        }
        If $$$ISERR(tSC) Quit

        If $Order(pWant("")) = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the roster resolved no asserted property for application '" _ pKey _ "'")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pWant
    Quit tSC
}

/// <p>The guard-then-act body both web-application steps share: create <var>pName</var>
/// with exactly the properties <var>pWant</var> carries when it is absent, and when it is
/// present compare every one of them and repair the ones that have drifted, reporting which.
/// Only the properties <var>pWant</var> names are compared, so a setting OcuPilot does not
/// assert is never quietly rewritten.</p>
/// <p><b>Both applications are created by <method>Install</method> itself</b> (AD-17), so
/// the Docker path and the IPM path cannot produce different applications, and both are
/// removed by <method>Uninstall</method>, named in <method>AnyObjectExists</method> and
/// folded into <method>StateFingerprint</method>.</p>
ClassMethod EnsureWebApplication(pName As %String, pDescription As %String, ByRef pWant, ByRef pReports, ByRef pCreatedApps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        If ##class(Security.Applications).Exists(pName, .tExisting, .tExistSC) {
            Set tSC = ##class(Security.Applications).Get(pName, .tProps)
            If $$$ISERR(tSC) Quit
            Kill tMod
            Set tDrifted = ""
            Set tKey = $Order(pWant(""))
            While tKey '= "" {
                If $Get(tProps(tKey)) '= pWant(tKey) {
                    Set tMod(tKey) = pWant(tKey)
                    Set tDrifted = tDrifted _ $Select(tDrifted = "": "", 1: ",") _ tKey
                }
                Set tKey = $Order(pWant(tKey))
            }
            If tDrifted '= "" {
                Set tSC = ##class(Security.Applications).Modify(pName, .tMod)
                If $$$ISERR(tSC) Quit
                Do ..Report(.pReports, "warn", "Repaired a drifted OcuPilot web application", {"path": (pName), "properties": (tDrifted)})
            } Else {
                Do ..Report(.pReports, "info", "OcuPilot web application already correct", {"path": (pName)})
            }
        } Else {
            Kill tCreate
            Merge tCreate = pWant
            Set tCreate("Type") = 2
            Set tCreate("Description") = pDescription
            Set tSC = ##class(Security.Applications).Create(pName, .tCreate)
            If $$$ISERR(tSC) Quit
            Set pCreatedApps($Increment(pCreatedApps)) = pName
            Do ..Report(.pReports, "info", "Created an OcuPilot web application", {"path": (pName)})
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
/// <p>The read and the write go through <method>AuditEnabledSetting</method> and
/// <method>EnableInstanceAuditing</method> (rework iteration 6 review, DW-45) so
/// <class>OcuPilot.Test.AuditOff</class> can report auditing as off and record the write
/// without making it: this image starts with <code>AuditEnabled = 1</code>, so no instance
/// the suite runs against reaches the enable branch, and the Never list forbids turning
/// auditing off on the shared instance to get there.</p>
ClassMethod EnsureAuditingEnabled(ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        ; A failed read is an error, never a silent "it is off" that would then write the
        ; setting.
        Set tEnabled = ""
        Set tSC = ..AuditEnabledSetting(.tEnabled)
        If $$$ISERR(tSC) Quit
        If tEnabled = 1 {
            Do ..Report(.pReports, "info", "Instance auditing already enabled", "")
        } Else {
            Set tSC = ..EnableInstanceAuditing()
            If $$$ISERR(tSC) Quit
            Do ..Report(.pReports, "warn", "Enabled instance auditing", "")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The instance-wide <code>AuditEnabled</code> setting, as <code>0</code> or
/// <code>1</code>. Reads <code>Security.System.Get</code>, not the <code>[ Internal ]</code>
/// <code>IsAuditingEnabled()</code> helper -- see <method>StateFingerprint</method>'s note.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>. A
/// seam for <class>OcuPilot.Test.AuditOff</class>; production never overrides it.</p>
ClassMethod AuditEnabledSetting(Output pEnabled As %Boolean) As %Status [ Private ]
{
    Set pEnabled = ""
    Set tSC = ##class(Security.System).Get("SYSTEM", .tSysProps)
    If $$$ISOK(tSC) Set pEnabled = +$Get(tSysProps("AuditEnabled"))
    Quit tSC
}

/// <p>Turn instance-wide auditing on. Never touches <code>AuditEncrypt</code>.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>. A
/// seam for <class>OcuPilot.Test.AuditOff</class>, which records the call instead of
/// making it; production never overrides it.</p>
ClassMethod EnableInstanceAuditing() As %Status [ Private ]
{
    Set tProps("AuditEnabled") = 1
    Quit ##class(Security.System).Modify("SYSTEM", .tProps)
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

/// <p>Grant OcuPilot's protected schema to the role every escalated statement acquires.</p>
/// <p><b>Found live, Story 1.5:</b> a signed-in caller who does not hold <code>%All</code>
/// was answered <code>INSTALL.INSTALLING</code> by the API forever, on a fully installed
/// instance. <class>OcuPilot.Kernel.State.Base</class>'s guarded reads run <b>dynamic</b>
/// SQL (<code>%SQL.Statement</code>), which enforces SQL privileges; the escalated frame adds
/// the protected database's implicit role, and that role holds the database but no SQL
/// privilege on the tables inside it. So <method>GateStatus</method>'s version-row read
/// failed and, correctly failing closed, reported <code>installing</code>. Every test until
/// then ran as <code>_SYSTEM</code>, whose <code>%All</code> bypasses the check, so nothing
/// could see it. Verified by granting and re-requesting as a purpose-built principal, and
/// pinned over the wire by <class>OcuPilot.Test.Wire</class>.</p>
/// <p>The grant is schema-scoped and goes to <b>one</b> grantee: the role named by
/// <parameter>OcuPilot.Kernel.State.Base.DBRESOURCE</parameter>, which is the only role any
/// escalated statement ever acquires -- that class names exactly one privileged routine
/// application and one resource, whatever profile is installing. The schema is likewise one
/// per namespace, so a single grant covers every profile's rows wherever the global mapping
/// routes them. It widens nothing outside the escalated frame: the role is granted
/// by <code>$SYSTEM.Security.AddRoles</code> inside <code>New $ROLES</code> and is gone when
/// the frame unwinds, and no ordinary role holds it (AD-9).</p>
/// <p>Idempotent: re-granting an existing privilege is a no-op, so a repeat install changes
/// nothing. <method>Uninstall</method> issues no matching revoke, and does not need to: the
/// grantee is the protected database's own role, so a grant that outlived it names a role
/// that no longer exists, and a later install recreating that role re-grants exactly this
/// privilege anyway. (Not verified against a completed uninstall -- it is stated here as the
/// reason the step has no counterpart, not as an observation.)</p>
/// <p>The two names are concatenated into the statement because a <code>GRANT</code> takes no
/// bound parameter for a schema or a grantee. Neither comes from a caller: the schema is a
/// literal here and the grantee is <parameter>OcuPilot.Kernel.State.Base.DBRESOURCE</parameter>.
/// AD-21's rule is about caller-supplied values, and this statement admits none.</p>
ClassMethod EnsureSqlPrivileges(ByRef pReports) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tRole = ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE
        Set tSchema = "OcuPilot_Kernel_State"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA " _ tSchema _ " TO " _ tRole)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "Could not grant OcuPilot's protected schema to " _ tRole _ ": SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        Do ..Report(.pReports, "info", "Granted OcuPilot's protected schema to the escalation role, so a caller without %All can be read for", {"schema": (tSchema), "role": (tRole)})
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
        ; The install namespace is the one this call is standing in (DW-12), captured before
        ; the %SYS switch below, exactly as Install's own guard resolves it.
        Set tInstallNs = tOrigNS

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

        ; Story 1.5: the shell role's resources and every asserted setting of both web
        ; applications, so a drift on any of them moves this fingerprint the same way a
        ; drift on the Story 1.3 objects already does (AC12).
        Set tShellRoleResources = ""
        If ##class(Security.Roles).Exists(tNames("shellRole"), .tShellRoleObj, .tShellRoleSC) {
            Set tGetSC = ##class(Security.Roles).Get(tNames("shellRole"), .tShellRoleProps, .tShellRoleObj2)
            Set tShellRoleResources = $Select($$$ISERR(tGetSC): "READFAILED", 1: $Get(tShellRoleProps("Resources")))
        }
        ; The property lists come from the roster, resolved by Names() before the switch above
        ; (Story 1.16): the set folded here is the set Install asserts, so a property added to
        ; an application is one roster edit rather than three that can drift apart.
        Set tShellApp = ..ApplicationFingerprint(tNames("shellApplication"), tNames("appProperties", "shell"))
        Set tApiApp = ..ApplicationFingerprint(tNames("apiApplication"), tNames("appProperties", "api"))

        Set tResult = tDbResourceName _ "|" _ tRoleResources _ "|" _ tAppEnabled _ "|" _ tAppMatchRoles _ "|" _ tAppRoutines _ "|" _ tMapDatabase _ "|" _ tEventEnabled _ "|" _ tDbResourcePublic _ "|" _ tDbResourceType _ "|" _ tAdminResourcePublic _ "|" _ tAuditingEnabled _ "|" _ tVerSchemaVersion _ "|" _ tVerPhase _ "|" _ tShellRoleResources _ "|" _ tShellApp _ "|" _ tApiApp
    } Catch ex {
        Set tResult = "ERROR:" _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tResult
}

/// <p>The live values of the named <var>pProperties</var> of the web application
/// <var>pName</var>, folded into one component of <method>StateFingerprint</method>. An
/// absent application contributes an empty component; a failed read contributes
/// <code>READFAILED</code>, so a read failure can never compare equal to an absent object.
/// An empty <var>pProperties</var> contributes <code>NOPROPERTIES</code> rather than an empty
/// component, so "nothing was compared" is not read back as "the application is absent". It
/// does not make a fingerprint over no properties informative -- both spellings are constant
/// across runs; <method>RosterNames</method> refuses an empty asserted set before this is
/// reachable, and that refusal is what keeps the oracle from folding no evidence.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code> --
/// except for the <code>NOPROPERTIES</code> guard itself, which returns before touching
/// <code>Security.Applications</code> and so needs no switch.</p>
/// <p><b>Public, not <code>[ Private ]</code></b> -- the same documented deviation
/// <method>EnsureGrant</method> already carries -- so <class>OcuPilot.Test.RosterWant</class>
/// can pin the <code>NOPROPERTIES</code> guard directly.</p>
ClassMethod ApplicationFingerprint(pName As %String, pProperties As %String) As %String
{
    If pProperties = "" Quit "NOPROPERTIES"
    If '##class(Security.Applications).Exists(pName, .tObj, .tExistSC) Quit ""
    Set tGetSC = ##class(Security.Applications).Get(pName, .tProps)
    If $$$ISERR(tGetSC) Quit "READFAILED"
    Set tOut = ""
    For tI = 1:1:$Length(pProperties, ",") {
        Set tOut = tOut _ $Select(tI = 1: "", 1: ";") _ $Get(tProps($Piece(pProperties, ",", tI)))
    }
    Quit tOut
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
    If ##class(Security.Applications).Exists(pNames("shellApplication"), .t8, .s8) Quit 1
    If ##class(Security.Applications).Exists(pNames("apiApplication"), .t9, .s9) Quit 1
    If ##class(Security.Roles).Exists(pNames("shellRole"), .t10, .s10) Quit 1
    If ##class(%File).DirectoryExists(pNames("shellDirectory")) Quit 1
    Quit 0
}

/// <p>Remove every object <var>pProfile</var> owns: <b>first</b> the opt-in demo fixture
/// set through <class>OcuPilot.Install.Fixture</class> (AD-25) -- read from this profile's
/// <class>OcuPilot.Kernel.State.Demo</class> inventory while it and its escalation route
/// still exist -- <b>then</b> the two web applications, the shell's matching role and its
/// bundle directory, the mapping, the privileged routine application, the
/// administrative role and resource, the database's guarding resource, the database
/// itself (config entry, <code>IRIS.DAT</code> and directory), and the audit event.
/// <b>This order is load-bearing</b> (review finding, HIGH): fixture removal used to run
/// last, by which point the mapping and database it needs to read
/// <class>OcuPilot.Kernel.State.Demo</class> through were already gone, silently
/// orphaning every production fixture. Absent objects are never an error; without
/// <var>pConfirmDataLoss</var> the method changes nothing (including the fixtures) and
/// names what it would have destroyed.</p>
/// <p><b>It stops before the database while any of this profile's fixture inventory rows
/// remains (DW-65, the owner's decision, rework iteration 6).</b> Only this profile's rows
/// are read: a production uninstall does not look at rows another profile left in the same
/// protected database (a <code>"probe"</code> test run that was interrupted, say), and those
/// are lost with the database (code review round 3, accepted as low). <method>OcuPilot.Install.Fixture.Remove</method>
/// keeps this profile's whole inventory whenever any fixture object could not be removed,
/// so that a later run can retry. That inventory lives in the protected database, behind
/// the <code>OcuPilot*</code> mapping this method is about to delete, so dropping them
/// anyway destroyed the only record of an object still on the instance and orphaned it.
/// So after fixture removal this method re-reads the inventory. When any row remains, or
/// the inventory cannot be read, it removes nothing else. It reports every remaining row,
/// with its kind, name, scope and whether the object is still on the instance, and returns
/// an error. The operator clears whatever blocked the removal and runs
/// <method>Uninstall</method> again: every delete is guarded by an existence check, so the
/// retry skips what the first attempt already removed. AD-25 says "uninstall removes it";
/// the owner's DW-65 decision reads that as: never destroy the only record of an object
/// uninstall can still see. That record lives in the database this method drops only for
/// the production profile; a <code>"probe"</code> profile's rows live in production's
/// protected database, which a probe uninstall never drops, so for the probe the refusal
/// keeps the retry behaviour identical rather than protecting the rows themselves.</p>
/// <p>One exception, so that a repeat run stays a no-op (absent objects are never an
/// error): when the inventory cannot be read because
/// <class>OcuPilot.Kernel.State.Base</class>'s privileged routine application no longer
/// exists, nothing can read -- or have kept -- a row. This method deletes that application
/// only after the check above has passed, so its absence means an earlier
/// <method>Uninstall</method> already found the inventory empty (a completed uninstall, or
/// one that failed further down), or the protected state was dismantled by hand. That is
/// reported as a warn and the method carries on. A read that fails while the application
/// exists is refused. <b>The by-hand case is not safe:</b> if the application was deleted
/// by hand while inventory rows still existed, carrying on drops the database with those
/// rows and leaves their fixture objects on the instance with no record (code review round
/// 3, accepted as low; reopened if the application can vanish any other way while the
/// <code>OCUPILOT</code> database remains).</p>
/// <p><b>One install, uninstall or start mark of a profile at a time (DW-84).</b> Once the
/// profile is validated, and before anything is read or removed, this method takes that
/// profile's install lock (<method>InstallLockName</method>), the same lock
/// <method>Install</method> and <method>MarkInstalling</method> take, and holds it until it
/// returns. A call that is still blocked after <parameter>INSTALLLOCKSECONDS</parameter>
/// refuses with an error naming the profile, and removes nothing. Without it an install and an
/// uninstall of one profile could run at once, and on 2026-09-11 they did: a probe uninstall's
/// database delete and a probe install's database create interleaved in two processes and left
/// the probe database's directory mounted with no <code>IRIS.DAT</code>, which neither a
/// dismount nor a delete could clear; a restart of the instance did (DW-83). An install, a
/// start path or a mark that meets an uninstall holding the lock
/// waits up to <parameter>INSTALLLOCKSECONDS</parameter> for it: it runs once the uninstall has
/// returned, and refuses, changing nothing, if it is still blocked by then.</p>
/// <p>For a non-production profile it also purges the <class>OcuPilot.Kernel.State.Stamp</class>
/// and <class>OcuPilot.Kernel.State.Version</class> rows recorded for <var>pProfile</var> once
/// the named objects above are gone -- a purge failure is reported through the logger but does
/// not turn an otherwise-successful uninstall into an error, since AC11's own success criteria
/// are the named objects, never stamp history.</p>
/// <p><b>The purge is for the <code>"probe"</code> profile only, and that is the whole reason
/// it exists.</b> Probe rows land in the <i>production</i> protected database (Stamp's own data
/// global starts with <code>OcuPilot</code> and so matches the production mapping, never the
/// probe's distinct <code>ProbeOcuPilotState*</code> pattern), so nothing else would ever
/// remove them. Production rows need no purge: they lived inside the very database this method
/// has just deleted, and so did the privileged routine application every escalated statement
/// needs, so a production purge could only fail. It used to be attempted anyway and logged two
/// false "could not purge" warns on every completed production uninstall (Fix Pack F-1, code
/// review round 3).</p>
ClassMethod Uninstall(pProfile As %String = "", pConfirmDataLoss As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit
        ; The namespace whose mapping and applications this profile owns is the one the call
        ; is standing in -- the same answer Install's guard gives (DW-12).
        Set tInstallNs = tOrigNS

        ; DW-84: one install, uninstall or start mark of a profile at a time. Taken before the
        ; inventory read below and before any %SYS switch, so every decision this run makes and
        ; every object it removes belong to this run alone; a refusal removes nothing. An
        ; uninstall that overlapped a probe install left the probe database's directory mounted
        ; with no IRIS.DAT on the live instance (DW-83).
        Set tSC = ..LockInstall(pProfile, "Uninstall")
        If $$$ISERR(tSC) {
            Do ..LogWarn("Uninstall refused: another install, uninstall or start mark of this profile holds its install lock -- nothing was changed", {"profile": (pProfile), "waitedSeconds": (..#INSTALLLOCKSECONDS)})
            Quit
        }
        Set tLocked = 1

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
            Set tSC = $$$ERROR($$$GeneralError, "Uninstall('" _ pProfile _ "') would destroy: database '" _ tNames("database") _ "' at " _ tNames("directory") _ ", resources '" _ tNames("dbResource") _ "' and '" _ tNames("adminResource") _ "', roles '" _ tNames("adminRole") _ "' and '" _ tNames("shellRole") _ "', applications '" _ tNames("application") _ "', '" _ tNames("shellApplication") _ "' and '" _ tNames("apiApplication") _ "', the shell bundle directory " _ tNames("shellDirectory") _ ", mapping '" _ tNames("mappingPattern") _ "', audit event '" _ tNames("eventSource") _ "/" _ tNames("eventType") _ "/" _ tNames("eventName") _ "', and any opt-in demo fixture objects this profile owns (AD-25). Pass pConfirmDataLoss=1 to proceed.")
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
        Do ..RemoveDemoFixtures(pProfile, .tFixtureReports)
        Set tFN = $Order(tFixtureReports(""))
        While tFN '= "" {
            If tFixtureReports(tFN, "level") = "warn" {
                Do ..LogWarn(tFixtureReports(tFN, "message"), tFixtureReports(tFN, "data"))
            } Else {
                Do ..LogInfo(tFixtureReports(tFN, "message"), tFixtureReports(tFN, "data"))
            }
            Set tFN = $Order(tFixtureReports(tFN))
        }

        ; DW-65 (the owner's decision, rework iteration 6): Fixture.Remove keeps this
        ; profile's WHOLE inventory whenever any fixture object could not be removed, so a
        ; later run can retry -- but the inventory lives in the protected database, behind
        ; the OcuPilot* mapping the block below deletes. Dropping them anyway destroyed the
        ; only record of an object still on the instance, orphaning it, and made Remove's
        ; own "inventory left in place so a later run can retry" warn false on this path.
        ; So re-read the inventory here, in the install namespace, and remove nothing else
        ; while any row remains -- or while the inventory cannot be read at all, since
        ; "could not tell" must never be read as "nothing left" (the same fail-closed
        ; discipline as tFixturesExist above).
        Set tInventoryAppExists = 1
        Set tLeftSC = ..RemainingDemoFixtures(pProfile, .tLeft)
        If $$$ISERR(tLeftSC) {
            ; Rework iteration 6 review: every profile's inventory is read through
            ; Kernel.State.Base's own privileged routine application, and only a production
            ; Uninstall deletes it -- in the block below, after this check has passed. So when
            ; it is gone, an earlier Uninstall already found the inventory empty (a repeat
            ; run, or a re-run after a failure further down), or the protected state was
            ; dismantled by hand; no row can be read or kept for a retry either way. Refusing
            ; there turned an already-uninstalled instance into an error whose only remedy
            ; was to reinstall (observed on a throwaway container). The parameter is read
            ; before the switch: no ##class(OcuPilot.*) call while $NAMESPACE sits in %SYS.
            Set tInventoryApp = ##class(OcuPilot.Kernel.State.Base).#APPLICATION
            Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
            If $$$ISERR(tSC) Quit
            Set tInventoryAppExists = ..EscalationApplicationExists(tInventoryApp)
            Set $NAMESPACE = tOrigNS
        }
        If $$$ISERR(tLeftSC) && 'tInventoryAppExists {
            Do ..LogWarn("Could not check the demo fixture inventory after fixture removal: its privileged routine application no longer exists, so no row can be read or kept for a retry -- continuing, because an earlier Uninstall already passed this check or the protected state was dismantled", {"profile": (pProfile), "application": (tInventoryApp), "error": ($System.Status.GetErrorText(tLeftSC))})
            Kill tLeft
            Set tLeft = 0
        } ElseIf $$$ISERR(tLeftSC) {
            Do ..LogWarn("Uninstall stopped before removing the protected database: the demo fixture inventory could not be read after fixture removal, so nothing is known about what it still records", {"profile": (pProfile), "error": ($System.Status.GetErrorText(tLeftSC))})
            Set tSC = $$$ERROR($$$GeneralError, "Uninstall('" _ pProfile _ "') stopped before removing the protected database: the demo fixture inventory could not be read after fixture removal (" _ $System.Status.GetErrorText(tLeftSC) _ "), so removing the database could orphan an object it still records. Nothing else was removed. Repair the production profile's protected state, which holds every profile's inventory (run Install with no profile), and run Uninstall again.")
            Quit
        }
        If +$Get(tLeft) {
            Set tLeftList = []
            Set tLeftText = ""
            For tLI = 1:1:tLeft {
                Set tLeftKind = $Get(tLeft(tLI, "kind"))
                Set tLeftName = $Get(tLeft(tLI, "name"))
                Set tLeftState = $Get(tLeft(tLI, "state"))
                Do tLeftList.%Push({"kind": (tLeftKind), "name": (tLeftName), "scope": ($Get(tLeft(tLI, "scope"))), "state": (tLeftState)})
                Set tLeftText = tLeftText _ $Select(tLeftText = "": "", 1: "; ") _ $Select(tLeftKind = "": "inventory row " _ $Get(tLeft(tLI, "id")), 1: tLeftKind _ " '" _ tLeftName _ "'") _ " (" _ tLeftState _ ")"
            }
            Do ..LogWarn("Uninstall stopped before removing the protected database: demo fixture inventory rows remain, and removing the database would orphan what they record", {"profile": (pProfile), "left": (tLeftList)})
            Set tSC = $$$ERROR($$$GeneralError, "Uninstall('" _ pProfile _ "') stopped before removing the protected database: " _ tLeft _ " demo fixture inventory row(s) remain -- " _ tLeftText _ ". The database, its mapping and every other installer object were left in place, so the inventory survives for a retry. Clear what blocked the removal (the warnings logged above name it) and run Uninstall again.")
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        ; Story 1.5's objects go first: the two web applications, then the shell's matching
        ; role (an application that still names a deleted role would be drift nothing
        ; removes), then the bundle directory the shell application pointed at.
        If ##class(Security.Applications).Exists(tNames("shellApplication"), .tEW1, .tSW1) {
            Set tSC = ##class(Security.Applications).Delete(tNames("shellApplication"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Applications).Exists(tNames("apiApplication"), .tEW2, .tSW2) {
            Set tSC = ##class(Security.Applications).Delete(tNames("apiApplication"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        If ##class(Security.Roles).Exists(tNames("shellRole"), .tEW3, .tSW3) {
            Set tSC = ##class(Security.Roles).Delete(tNames("shellRole"))
            If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        }
        ; The result is kept, not discarded: AnyObjectExists reads this directory, so a
        ; removal that silently failed would leave the next run calling the profile
        ; installed with nothing saying why. Reported after the namespace restore below,
        ; because LogWarn reaches OcuPilot.Kernel.Audit.Log, which %SYS cannot see.
        Set tShellDirLeft = 0
        If ##class(%File).DirectoryExists(tNames("shellDirectory")) {
            If '##class(%File).RemoveDirectoryTree(tNames("shellDirectory")) Set tShellDirLeft = 1
        }

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

        If tShellDirLeft {
            Do ..LogWarn("Uninstall removed every named object, but the shell application's bundle directory could not be removed and is still on disk", {"directory": (tNames("shellDirectory"))})
        }

        ; Fix Pack F-1 (code review round 3): the two purges below are for a non-production
        ; profile only. A production profile's Stamp and Version rows lived in the OCUPILOT
        ; database this method has just deleted, together with the OcuPilotState application
        ; every escalated statement needs, so for production both purges could only fail with
        ; ERROR #868 and log two false "could not purge" warns on every completed uninstall
        ; (seen on a throwaway container: dw65-docker.log, 11:42:08Z, 11:52:11Z, 11:52:29Z).
        ; A "probe" profile's rows live in production's protected database, which a probe
        ; uninstall never drops, so they still need purging.
        If pProfile '= "" {
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
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    ; DW-84: released only here, after the purges, on every exit that took it -- each
    ; argumentless Quit above and the Catch. The lock is an extended reference into %SYS, so it
    ; resolves the same whichever namespace the method left $NAMESPACE in (InstallLockName).
    If tLocked Do ..UnlockInstall(pProfile)
    Quit tSC
}

}
