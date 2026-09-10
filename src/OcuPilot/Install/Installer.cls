/// <p>OcuPilot's one installer class (AD-17). Creates, guard-then-act and idempotently,
/// a dedicated database holding OcuPilot's <b>globals only</b> (AD-9), a <code>%DB_</code>
/// resource guarding it that no ordinary role holds, the OcuPilot administrative resource
/// and a role granting it, a privileged routine application, one global mapping, and
/// registers and emits OcuPilot's audit events -- leaving OcuPilot's <b>code</b> in the
/// install namespace's normal database. No web application is created here (Story 1.5);
/// no container start hook, image pin, demo fixture, <code>_SYSTEM</code> unexpire or
/// schema-version stamp is created here (Story 1.4).</p>
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
ClassMethod Install(pProfile As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Kill tReports
    Try {
        Set tSC = ..Names(pProfile, .tNames)
        If $$$ISERR(tSC) Quit
        Set tInstallNs = ..ResolveNamespace()

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tSC = ..EnsureDatabaseResource(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureDatabase(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureAdminResource(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureAdminRole(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureApplication(.tNames, tInstallNs, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureMapping(.tNames, tInstallNs, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureAuditEvent(.tNames, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureAuditingEnabled(.tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }
        Set tSC = ..EnsureGrant(.tNames, .tGrantOutcome, .tGrantedUser, .tGrantCommand, $Username, .tReports)
        If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }

        Set $NAMESPACE = tOrigNS

        Set tSC = ..RecordStamp(.tNames, tGrantOutcome, tGrantedUser, tGrantCommand)
        If $$$ISERR(tSC) {
            Do ..Report(.tReports, "warn", "Install ran every ensure step but could not record the install stamp -- the run is reported as failed", {"profile": (pProfile)})
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
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
/// including <code>Enabled</code> on the privileged routine application (AC7, AC8).
/// Excludes nothing that a caller can observe changing between two correct installs.</p>
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

        Set tResult = tDbResourceName _ "|" _ tRoleResources _ "|" _ tAppEnabled _ "|" _ tAppMatchRoles _ "|" _ tAppRoutines _ "|" _ tMapDatabase _ "|" _ tEventEnabled _ "|" _ tDbResourcePublic _ "|" _ tDbResourceType _ "|" _ tAdminResourcePublic _ "|" _ tAuditingEnabled
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

/// <p>Remove every object <var>pProfile</var> owns: the mapping, the privileged routine
/// application, the administrative role and resource, the database's guarding resource,
/// the database itself (config entry, <code>IRIS.DAT</code> and directory), and the
/// audit event. Absent objects are never an error; without
/// <var>pConfirmDataLoss</var> the method changes nothing and names what it would have
/// destroyed.</p>
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

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        If '..AnyObjectExists(.tNames, tInstallNs) {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        If 'pConfirmDataLoss {
            Set tSC = $$$ERROR($$$GeneralError, "Uninstall('" _ pProfile _ "') would destroy: database '" _ tNames("database") _ "' at " _ tNames("directory") _ ", resources '" _ tNames("dbResource") _ "' and '" _ tNames("adminResource") _ "', role '" _ tNames("adminRole") _ "', application '" _ tNames("application") _ "', mapping '" _ tNames("mappingPattern") _ "', and audit event '" _ tNames("eventSource") _ "/" _ tNames("eventType") _ "/" _ tNames("eventName") _ "'. Pass pConfirmDataLoss=1 to proceed.")
            Set $NAMESPACE = tOrigNS
            Quit
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
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
