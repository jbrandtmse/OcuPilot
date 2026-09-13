/// <p>Install-time suite for OcuPilot's two web applications and the shell's one matching
/// role (AC1, AC2, AC12): every asserted setting after install, drift repair on a second run,
/// fingerprint sensitivity, the CSP Gateway registration gap, and uninstall's removal.</p>
/// <p>The settings assertions read the <b>production</b> applications, because AC1 and AC2
/// are about <code>/ocupilot</code> and <code>/api/ocupilot</code> specifically and a repeat
/// production install is a no-op by construction. Everything destructive -- drift, uninstall,
/// the fingerprint pair -- runs against the disposable <code>"probe"</code> profile, whose
/// web paths are wholly distinct literals rather than derivatives of the production ones, so
/// neither can ever nest inside the other.</p>
Class OcuPilot.Test.WebApp Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

/// <p>Read <var>pName</var>'s live properties into <var>pProps</var>, switching to
/// <code>%SYS</code> and restoring (AD-16). Returns whether the application exists.</p>
Method ReadApplication(pName As %String, Output pProps) As %Boolean
{
    Kill pProps
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        If ##class(Security.Applications).Exists(pName, .tObj, .tExistSC) {
            Set tGetSC = ##class(Security.Applications).Get(pName, .pProps)
            Do $$$AssertStatusOK(tGetSC, "read back the web application " _ pName)
            Set tExists = $$$ISOK(tGetSC)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>The guarding resource of the install namespace's routine database, read independently
/// of the installer's own resolution so the role assertion is not circular.</p>
Method CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If $IsObject(tNsObj) {
            Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
            If $IsObject(tDbObj) {
                Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
                If $IsObject(tSysDb) Set tResource = tSysDb.ResourceName
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

/// <p>AC1 -- <code>/ocupilot</code>, property by property: enabled, in the install
/// namespace, unauthenticated, dispatching to
/// <class>OcuPilot.Api.StaticHandler</class>, serving no files itself, carrying the bundle
/// directory as its path, carrying no application resource, and carrying exactly one matching
/// role -- the purpose-built read-only one and nothing else.</p>
/// <p>Mutation: change any one property in
/// <method>OcuPilot.Install.Installer.EnsureShellApplication</method>'s wanted set, re-run
/// install, and the matching assertion here goes red.</p>
Method TestShellApplicationSettings()
{
    Do $$$AssertTrue(..ReadApplication("/ocupilot", .tProps), "the shell application exists after install")
    Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the shell application is enabled")
    ; $NAMESPACE, not ResolveNamespace(): Story 1.16 demoted the resolver to the container
    ; start path's *default* and made the install target the namespace install was called
    ; from, which is also where the suite's own classes were compiled. Under
    ; OCUPILOT_NAMESPACE, or on an IPM install run from an ordinary namespace, the two differ
    ; and the resolver's answer is the wrong oracle -- this assertion would go red on a
    ; correct install. OcuPilot.Test.Manifest states the same fact the same way.
    Do $$$AssertEquals($Get(tProps("NameSpace")), $NAMESPACE, "the shell application runs in the namespace install was run from")
    Do $$$AssertEquals(+$Get(tProps("AutheEnabled")), 64, "the shell application is unauthenticated")
    Do $$$AssertEquals($Get(tProps("DispatchClass")), "OcuPilot.Api.StaticHandler", "the shell application dispatches to the static handler")
    Do $$$AssertEquals(+$Get(tProps("ServeFiles")), 0, "the shell application serves no files itself -- only its dispatch class reads the bundle")
    Do $$$AssertEquals($Get(tProps("Resource")), "", "the shell application carries no application resource")
    Do $$$AssertEquals($Get(tProps("MatchRoles")), ":OcuPilotShell", "the shell application carries exactly one matching role, the purpose-built read-only one")
    Do $$$AssertEquals(+$Get(tProps("Type")), 2, "the shell application is a CSP/REST application")

    Set tDirectory = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/ocupilot")
    Do $$$AssertTrue(tDirectory '= "", "the handler resolves a bundle directory for this application")
    Do $$$AssertEquals($Get(tProps("Path")), tDirectory, "the shell application carries the bundle directory the handler resolves at request time")
}

/// <p>AC1 -- what the production shell actually serves, in whichever of its two states the
/// instance is in. With a bundle installed, the document declares the non-root base href set
/// at build time and carries the nonce placeholder the handler substitutes. With none, the
/// application answers <code>STATIC.NOBUNDLE</code> over the wire. Whichever state the
/// instance is in is asserted -- the other branch does not run -- so this pins what the
/// production shell serves here and now, and never nothing.</p>
/// <p><b>Two states rather than one assertion, deliberately.</b> Nothing in this suite can
/// install a real bundle: the build runs on the host and a <code>%UnitTest</code> run executes
/// inside the instance, so whether one is installed is a property of the instance's history.
/// Requiring one would make this class red on every clean clone and on CI for an environment
/// reason, and skipping instead would leave an assertion that cannot fail on exactly the
/// instance where the criterion matters most. The build-time half of the criterion -- that the
/// emitted document declares <code>/ocupilot/</code> -- is pinned where it is deterministic,
/// in <file>ui/tools/build-output.test.mjs</file>, which runs a real build every time.</p>
Method TestProductionShellServesWhatIsInstalled()
{
    Set tIndex = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/ocupilot") _ "index.html"
    If '##class(%File).Exists(tIndex) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/ocupilot/", "", "", .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes")
        Do $$$AssertEquals(tStatus, 503, "with no bundle installed the production shell answers 503")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.code, "STATIC.NOBUNDLE", "with the stable machine code, rather than failing or serving a partial page")
        Quit
    }
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Do $$$AssertStatusOK(tStream.LinkToFile(tIndex), "the installed index.html can be read")
    Set tText = ""
    While 'tStream.AtEnd {
        Set tText = tText _ tStream.Read(32000)
    }
    Do $$$AssertTrue(tText [ "<base href=""/ocupilot/""", "the installed document declares the non-root base href /ocupilot/")
    Do $$$AssertTrue(tText [ ##class(OcuPilot.Api.StaticHandler).#NONCEPLACEHOLDER, "the installed document carries the nonce placeholder the handler substitutes")

    Set tSC2 = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/ocupilot/", "", "", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the request completes")
    Do $$$AssertEquals(tStatus2, 200, "and the production shell serves it anonymously")
    Do $$$AssertTrue((tBody2 '[ ##class(OcuPilot.Api.StaticHandler).#NONCEPLACEHOLDER), "with the nonce substituted for the placeholder")
}

/// <p>AC2 -- <code>/api/ocupilot</code>, property by property, including the JWT timeouts,
/// the vendor's management-portal group, the empty <code>MatchRoles</code> and the absent
/// application resource; plus the dispatch class's own <code>UseSession</code> parameter,
/// which is a property of the class rather than of the application and is what makes the API
/// stateless.</p>
/// <p>Mutation: change any one property in
/// <method>OcuPilot.Install.Installer.EnsureApiApplication</method>'s wanted set, re-run
/// install, and the matching assertion here goes red.</p>
Method TestApiApplicationSettings()
{
    Do $$$AssertTrue(..ReadApplication("/api/ocupilot", .tProps), "the API application exists after install")
    Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the API application is enabled")
    ; $NAMESPACE, not ResolveNamespace() -- see TestShellApplicationSettings above.
    Do $$$AssertEquals($Get(tProps("NameSpace")), $NAMESPACE, "the API application runs in the namespace install was run from")
    Do $$$AssertEquals(+$Get(tProps("AutheEnabled")), 32, "the API application is password-authenticated")
    Do $$$AssertEquals($Get(tProps("DispatchClass")), "OcuPilot.Api.Router", "the API application dispatches to the router")
    Do $$$AssertEquals(+$Get(tProps("JWTAuthEnabled")), 1, "the API application has JWT enabled")
    Do $$$AssertEquals(+$Get(tProps("JWTAccessTokenTimeout")), 60, "the access token lifetime is 60 seconds")
    Do $$$AssertEquals(+$Get(tProps("JWTRefreshTokenTimeout")), 900, "the refresh token lifetime is 900 seconds")
    Do $$$AssertEquals($Get(tProps("GroupById")), "%ISCMgtPortal", "the API application joins the vendor's management-portal group")
    Do $$$AssertEquals($Get(tProps("MatchRoles")), "", "the API application carries no matching role of any kind")
    Do $$$AssertEquals($Get(tProps("Resource")), "", "the API application carries no application resource")
    Do $$$AssertEquals(+$Get(tProps("ServeFiles")), 0, "the API application serves no files")

    Do $$$AssertEquals(+$Parameter("OcuPilot.Api.Router", "UseSession"), 0, "the router keeps no CSP session per request")
}

/// <p>AC1 -- the shell's matching role grants read on the install namespace's code database
/// and nothing else, and holds no granted role. The expected resource is read from
/// <class>SYS.Database</class> independently of the installer's own resolution.</p>
/// <p>Mutation: widen the role's resource set in
/// <method>OcuPilot.Install.Installer.EnsureShellRole</method> (to <code>:RW</code>, or by
/// adding a second resource) and the first assertion goes red.</p>
Method TestShellRoleGrantsOnlyReadOnTheCodeDatabase()
{
    Set tExpected = ..CodeDatabaseResource()
    Do $$$AssertTrue(tExpected '= "", "the install namespace's routine database carries a guarding resource")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Do $$$AssertTrue(##class(Security.Roles).Exists("OcuPilotShell", .tObj, .tExistSC), "the shell role exists after install")
        Set tGetSC = ##class(Security.Roles).Get("OcuPilotShell", .tProps, .tRoleObj)
        Do $$$AssertStatusOK(tGetSC, "read back the shell role")
        Do $$$AssertEquals($Get(tProps("Resources")), tExpected _ ":R", "the shell role grants read on the code database and nothing else")
        Do $$$AssertEquals($Get(tProps("GrantedRoles")), "", "the shell role holds no granted role")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC12 -- a second run repairs a drifted web application and reports the repair;
/// existence alone is never read as installed. Driven on the probe profile's shell
/// application, whose <code>MatchRoles</code> is emptied by hand first -- the single worst
/// drift, since an unauthenticated application with no matching role cannot load its own
/// dispatch class.</p>
/// <p>Mutation: make <method>OcuPilot.Install.Installer.EnsureWebApplication</method> return
/// early when the application exists, and both assertions below go red.</p>
Method TestSecondRunRepairsDriftedApplication()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tModProps("MatchRoles") = ""
        Set tModProps("Enabled") = 0
        Set tSC2 = ##class(Security.Applications).Modify("/probeocupilot", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually drift the probe shell application")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "the repairing install succeeds")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue(..ReadApplication("/probeocupilot", .tProps), "the probe shell application still exists")
    Do $$$AssertEquals($Get(tProps("MatchRoles")), ":ProbeOcuPilotShell", "the second run repaired the emptied matching role")
    Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "the second run re-enabled the application")
    Do $$$AssertTrue(tWarns [ "Repaired a drifted OcuPilot web application", "the repair was reported, not silently applied")
    Do $$$AssertTrue(tWarns [ "/probeocupilot", "the report names the application it repaired")
}

/// <p>AC12 -- the same for the shell's matching role: a role whose resources have been
/// widened by hand is narrowed back and the repair reported.</p>
Method TestSecondRunRepairsDriftedShellRole()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tModProps("Resources") = "%DB_IRISTEMP:RW"
        Set tModProps("ForceSave") = 2
        Set tSC2 = ##class(Security.Roles).Modify("ProbeOcuPilotShell", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually widen the probe shell role")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "the repairing install succeeds")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Set tExpected = ..CodeDatabaseResource() _ ":R"
    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC4 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC4, "switch to %SYS")
        Set tGetSC = ##class(Security.Roles).Get("ProbeOcuPilotShell", .tProps, .tRoleObj)
        Do $$$AssertStatusOK(tGetSC, "read back the repaired probe shell role")
        Do $$$AssertEquals($Get(tProps("Resources")), tExpected, "the second run narrowed the role back to read on the code database")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2
    Do $$$AssertTrue(tWarns [ "Repaired the shell application's read-only role", "the repair was reported")
}

/// <p>AC12, AD-10 -- the <b>other</b> half of the shell role's drift condition, on its own.
/// <method>OcuPilot.Install.Installer.EnsureShellRole</method> repairs a role whose
/// <code>Resources</code> have moved <b>or</b> which has acquired a granted role; the test
/// above drifts only <code>Resources</code>, so the second operand is a branch no test
/// executes. It is the operand that matters most here: this role is the sole
/// <code>MatchRoles</code> entry of the <b>unauthenticated</b> shell application, so a role
/// granted to it is held by every anonymous request, which is exactly AD-10's "granting
/// privilege through any path".</p>
/// <p>Mutation: drop <code>|| ($Get(tProps("GrantedRoles")) '= "")</code> from
/// <method>OcuPilot.Install.Installer.EnsureShellRole</method>'s drift condition -> the
/// granted role survives the repeat install and both assertions below go red, while every
/// other test in this class stays green.</p>
Method TestSecondRunNarrowsAGrantedRoleOnTheShellRole()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        ; Resources is left correct on purpose: only the GrantedRoles operand may fire.
        Set tModProps("GrantedRoles") = "%DB_IRISTEMP"
        Set tModProps("ForceSave") = 2
        Set tSC2 = ##class(Security.Roles).Modify("ProbeOcuPilotShell", .tModProps)
        Do $$$AssertStatusOK(tSC2, "manually grant a role to the probe shell role")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "the repairing install succeeds")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC4 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC4, "switch to %SYS")
        Set tGetSC = ##class(Security.Roles).Get("ProbeOcuPilotShell", .tProps, .tRoleObj)
        Do $$$AssertStatusOK(tGetSC, "read back the repaired probe shell role")
        Do $$$AssertEquals($Get(tProps("GrantedRoles")), "", "the second run removed the granted role, so no anonymous request inherits it")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2
    Do $$$AssertTrue(tWarns [ "Repaired the shell application's read-only role", "and reported the repair rather than applying it silently")
}

/// <p>AC11 -- a run that names <b>no</b> bundle source at all (every IRIS MCP install, and
/// IPM's <code>&lt;Invoke&gt;</code>) reports its own <code>info</code> and emits no bundle
/// <code>warn</code>: it never looked for a bundle, so reporting that it failed to find one
/// would warn about a non-event on every such run.
/// <method>TestAbsentBundleSourceIsAWarnAndNeverAnError</method> covers the other case -- a
/// source that is named but absent -- and deliberately passes a named directory, so nothing
/// executed this branch.</p>
/// <p>Mutation: delete the <code>If pBundleSource = ""</code> branch from
/// <method>OcuPilot.Install.Installer.EnsureShellFiles</method> -> execution falls through to
/// <code>%File.NormalizeDirectory("")</code>, which on this build returns the process's own
/// namespace directory, and the warn assertion below goes red.</p>
Method TestNoBundleSourceNamedIsAnInfoAndNeverAWarn()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC, "an install that names no bundle source completes")
    Set tInfos = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("info")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue(tInfos [ "No client bundle source was named", "the no-source run says so as information")
    Do $$$AssertEquals((tWarns [ "No built client bundle was installed"), 0, "and never warns that a bundle it was not asked for is missing")
}

/// <p>AC12 -- two consecutive installs leave the fingerprint byte-identical, and a drift on
/// either application moves it. The second half is what makes the first half evidence:
/// without it, a fingerprint that folded neither application would also compare equal.</p>
/// <p>Mutation: drop any one of the three components this story added to
/// <method>OcuPilot.Install.Installer.StateFingerprint</method> -- either application or the
/// shell role -- and that component's "moves when drifted" assertion goes red while the
/// byte-identical one stays green.</p>
Method TestFingerprintIsIdempotentAndSensitiveToApplicationDrift()
{
    Set tFirst = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a repeat probe install succeeds")
    Set tSecond = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertEquals(tSecond, tFirst, "a repeat install leaves the fingerprint byte-identical")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        Set tShellMod("ServeFiles") = 1
        Do $$$AssertStatusOK(##class(Security.Applications).Modify("/probeocupilot", .tShellMod), "drift the probe shell application")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
    Set tShellDrifted = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertNotEquals(tShellDrifted, tFirst, "a drift on the shell application moves the fingerprint")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Set tApiMod("JWTAccessTokenTimeout") = 300
        Do $$$AssertStatusOK(##class(Security.Applications).Modify("/api/probeocupilot", .tApiMod), "drift the probe API application")
    } Catch ex {
        Set $NAMESPACE = tOrigNS2
        Throw ex
    }
    Set $NAMESPACE = tOrigNS2
    Set tBothDrifted = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertNotEquals(tBothDrifted, tShellDrifted, "a drift on the API application moves it again")

    ; The shell role is the fingerprint's third new component and the only one that is not an
    ; application. Without this drift, dropping it from StateFingerprint leaves every
    ; assertion in this class green while the instrument stops noticing a widened role on the
    ; unauthenticated application.
    Set tOrigNS3 = $NAMESPACE
    Try {
        Set tSC3 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS3)
        Do $$$AssertStatusOK(tSC3, "switch to %SYS")
        Set tRoleMod("Resources") = "%DB_IRISTEMP:RW"
        Set tRoleMod("ForceSave") = 2
        Do $$$AssertStatusOK(##class(Security.Roles).Modify("ProbeOcuPilotShell", .tRoleMod), "widen the probe shell role")
    } Catch ex {
        Set $NAMESPACE = tOrigNS3
        Throw ex
    }
    Set $NAMESPACE = tOrigNS3
    Set tAllDrifted = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertNotEquals(tAllDrifted, tBothDrifted, "a drift on the shell role moves it a third time")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "the repairing install succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).StateFingerprint("probe"), tFirst, "and the repair restores the original fingerprint exactly")
}

/// <p>AC12 -- the CSP Gateway registration gap is reported once per web application
/// <b>this run</b> created, each line carrying that application's own path, and a run that
/// created none says so instead. <code>Security.Applications.Create</code> does not notify
/// the Gateway, so a newly created path can 404 until the Gateway picks it up; on this
/// instance the Gateway's own path index maps <code>/</code> to IRIS, so it does not, which
/// is exactly why the gap is reported as information and never depended on.</p>
/// <p>Mutation: pass no created-applications array to
/// <method>OcuPilot.Install.Installer.ReportGatewayGap</method> and the two per-path
/// assertions go red.</p>
Method TestGatewayGapIsReportedForEachApplicationCreated()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "the probe profile is removed so the next install genuinely creates both applications")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC2 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC2, "the creating install succeeds")
    Set tCreatingRun = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("info")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue(..ReportsGapFor(tCreatingRun, "/probeocupilot"), "the run that created the shell application names the Gateway gap for it")
    Do $$$AssertTrue(..ReportsGapFor(tCreatingRun, "/api/probeocupilot"), "and for the API application")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC3 = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC3, "the repeat install succeeds")
    Set tRepeatRun = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("info")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue('..ReportsGapFor(tRepeatRun, "/probeocupilot"), "a run that created nothing names no gap for the shell application")
    Do $$$AssertTrue('..ReportsGapFor(tRepeatRun, "/api/probeocupilot"), "nor for the API application")
    Do $$$AssertTrue(tRepeatRun [ "This install run created no web application", "it says so instead")
}

/// <p>AC12 -- a repeat install repairs <b>nothing</b>. The drift tests above prove a repair
/// happens when something moved; this proves one does not happen when nothing did.</p>
/// <p>What it guards: <method>OcuPilot.Install.Installer.EnsureWebApplication</method>
/// compares the wanted values against what <code>Security.Applications.Get</code> reads back
/// as strings. If IRIS ever normalized one of the asserted properties on write, every install
/// would "repair" it again, warn again, and rewrite the application on every container start
/// -- and the fingerprint test could not see it, because it compares two post-repair
/// fingerprints.</p>
/// <p>Mutation: assert a property under a value IRIS stores differently (for example
/// <code>tWant("Enabled") = "true"</code> in
/// <method>OcuPilot.Install.Installer.EnsureShellApplication</method>) -> this goes red while
/// every other test in this class stays green.</p>
Method TestRepeatInstallRepairsNothing()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Do $$$AssertStatusOK(tSC, "the repeat install succeeds")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Set tInfos = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("info")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertTrue((tWarns '[ "Repaired a drifted OcuPilot web application"), "a repeat install over unchanged applications repairs neither of them")
    Do $$$AssertTrue((tWarns '[ "Repaired the shell application's read-only role"), "nor the shell role")
    Do $$$AssertTrue(tInfos [ "OcuPilot web application already correct", "it reports them as already correct instead")
}

/// <p>Whether <var>pCaptured</var> -- one report per line, message and data separated by a
/// tab -- carries the Gateway-gap line for <var>pPath</var>. Matches on the line's own data,
/// so a gap line for a different application never satisfies it.</p>
Method ReportsGapFor(pCaptured As %String, pPath As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$Length(pCaptured, $Char(10)) {
        Set tLine = $Piece(pCaptured, $Char(10), tI)
        If (tLine [ "does not notify the CSP Gateway") && ($Piece(tLine, $Char(9), 2) [ ("""path"":""" _ pPath _ """")) Set tFound = 1
    }
    Quit tFound
}

/// <p>AC12 -- uninstall removes both applications, the shell's matching role and the bundle
/// directory. Runs the real <method>OcuPilot.Install.Installer.Uninstall</method> on the
/// probe profile; <method>OnAfterOneTest</method>'s own call afterwards is then a no-op,
/// which is itself the repeat-safety half.</p>
/// <p>Mutation: delete any one of the four deletes from
/// <method>OcuPilot.Install.Installer.Uninstall</method> and the matching assertion goes
/// red.</p>
Method TestUninstallRemovesBothApplicationsTheRoleAndTheDirectory()
{
    Set tDirectory = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/probeocupilot")
    Do $$$AssertTrue(##class(%File).DirectoryExists(tDirectory), "the probe bundle directory exists before uninstall")

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "uninstall succeeds")

    Do $$$AssertTrue('##class(%File).DirectoryExists(tDirectory), "the bundle directory is gone")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue('##class(Security.Applications).Exists("/probeocupilot", .tE1, .tS1), "the shell application is gone")
        Do $$$AssertTrue('##class(Security.Applications).Exists("/api/probeocupilot", .tE2, .tS2), "the API application is gone")
        Do $$$AssertTrue('##class(Security.Roles).Exists("ProbeOcuPilotShell", .tE3, .tS3), "the shell role is gone")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Set tSC3 = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC3, "a second uninstall changes nothing and is not an error")
}

/// <p>AC12 -- an uninstall that has not been confirmed names the two applications, the shell
/// role and the bundle directory among what it would destroy, and removes nothing.</p>
Method TestUnconfirmedUninstallNamesTheNewObjects()
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 0)
    Do $$$AssertStatusNotOK(tSC, "an unconfirmed uninstall refuses")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "/probeocupilot", "the refusal names the shell application")
    Do $$$AssertTrue(tText [ "/api/probeocupilot", "the refusal names the API application")
    Do $$$AssertTrue(tText [ "ProbeOcuPilotShell", "the refusal names the shell role")
    Do $$$AssertTrue(tText [ ##class(OcuPilot.Api.StaticHandler).RootDirectory("/probeocupilot"), "the refusal names the bundle directory")

    Do $$$AssertTrue(..ReadApplication("/probeocupilot", .tProps), "and removes nothing")
}

/// <p>AC11 -- an install whose bundle source is absent reports exactly one <code>warn</code>
/// naming the directory it looked in, and <b>completes</b>: a clone whose client has never
/// been built still installs and still answers the API, and the shell answers
/// <code>STATIC.NOBUNDLE</code> until a bundle arrives
/// (<method>OcuPilot.Test.Static.TestBundleAbsentAnswersNoBundle</method>).</p>
/// <p>The absent source is a directory this method names and removes rather than an empty
/// string, so the assertion is about a source that was looked for and not found -- which is
/// the container's own case when <code>ui/dist</code> has never been built -- and not about
/// the separate "no source named at all" path an IPM or MCP install takes.</p>
/// <p>Mutation: make <method>OcuPilot.Install.Installer.EnsureShellFiles</method> return an
/// error status instead of reporting a warn when the source is absent -> the "install
/// completes" assertion goes red.</p>
Method TestAbsentBundleSourceIsAWarnAndNeverAnError()
{
    Set tMissing = ##class(%File).NormalizeDirectory("ocupilotnobundleprobe", $System.Util.ManagerDirectory())
    Do ##class(%File).RemoveDirectoryTree(tMissing)
    Do $$$AssertTrue('##class(%File).DirectoryExists(tMissing), "the named bundle source does not exist")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 0, tMissing)
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "install completes with no bundle to copy")
    Do $$$AssertTrue(tWarns [ "No built client bundle was installed", "the absent bundle is reported as a warn")
    Do $$$AssertTrue(tWarns [ tMissing, "and the warn names the source directory it looked in")

    Do $$$AssertTrue(..ReadApplication("/probeocupilot", .tProps), "and the shell application is still installed")
    Do $$$AssertEquals(+$Get(tProps("Enabled")), 1, "and still enabled")
}

/// <p>Write a minimal two-file bundle -- an <code>index.html</code> (so
/// <method>OcuPilot.Install.Installer.EnsureShellFiles</method> accepts the directory as a
/// real source) and one named marker file -- into a scratch directory under the manager
/// directory, replacing whatever was there. Returns the scratch directory's own normalized
/// path; the caller removes it once install has copied from it (QA).</p>
Method WriteScratchBundle(pDirName As %String, pMarkerName As %String) As %String
{
    Set tDir = ##class(%File).NormalizeDirectory(pDirName, $System.Util.ManagerDirectory())
    Do ##class(%File).RemoveDirectoryTree(tDir)
    Do ##class(%File).CreateDirectoryChain(tDir, .tMk)
    Do ..WriteScratchFile(tDir _ "index.html", "<!doctype html><html><body>qa scratch bundle</body></html>")
    Do ..WriteScratchFile(tDir _ pMarkerName, "qa scratch marker")
    Quit tDir
}

/// <p>Write <var>pContent</var> to <var>pPath</var> as raw bytes, for
/// <method>WriteScratchBundle</method> (QA).</p>
Method WriteScratchFile(pPath As %String, pContent As %String) As %Status
{
    Set tStream = ##class(%Stream.FileBinary).%New()
    Set tSC = tStream.LinkToFile(pPath)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = tStream.Write(pContent)
    If $$$ISERR(tSC) Quit tSC
    Quit tStream.%Save()
}

/// <p>AC11 -- a bundle source that normalizes to the shell application's own directory is
/// refused with a warn rather than destroyed: clearing the target first would delete the
/// source before anything could be copied from it, so <method>EnsureShellFiles</method>
/// compares the two paths before touching either, and the bundle already installed there is
/// left exactly as it is (QA -- residual risk named in this spec's Auto Run Result: reasoned
/// from a discarded return value, never previously driven by a test).</p>
/// <p>Mutation: delete the <code>If tSource = tTarget</code> guard from
/// <method>OcuPilot.Install.Installer.EnsureShellFiles</method> -> the bundle already in the
/// directory is cleared and then "copied" from the now-empty directory it was just deleted
/// from, so the surviving-marker assertion below goes red.</p>
Method TestBundleSourceEqualToShellDirectoryIsAWarnAndNeverAnError()
{
    Set tTarget = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/probeocupilot")
    Set tSourceA = ..WriteScratchBundle("qaSourceEqualsTargetSeed", "seed-marker.txt")
    Set tSC0 = ##class(OcuPilot.Install.Installer).Install("probe", 0, tSourceA)
    Do ##class(%File).RemoveDirectoryTree(tSourceA)
    Do $$$AssertStatusOK(tSC0, "seeding the shell directory with a real bundle succeeds")
    Do $$$AssertTrue(##class(%File).Exists(tTarget _ "seed-marker.txt"), "the seeded bundle is in the shell directory before the self-referential install")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 0, tTarget)
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "install completes when the named source is the shell directory itself")
    Do $$$AssertTrue(tWarns [ "own directory", "the self-referential source is reported as a warn")
    Do $$$AssertTrue(##class(%File).Exists(tTarget _ "seed-marker.txt"), "the bundle already installed there survives untouched -- nothing was cleared or copied")
}

/// <p>AC11 -- when the shell directory cannot be cleared, the bundle already installed there
/// is left exactly as it is and the failure is reported as a warn, never an error: install
/// still completes rather than accumulating a second bundle beside a first that could not be
/// removed (QA -- the same named residual risk as
/// <method>TestBundleSourceEqualToShellDirectoryIsAWarnAndNeverAnError</method>). Forces the
/// failure for real on the instance's own filesystem
/// (<code>%File.SetReadOnly</code>/<code>SetWriteable</code>) rather than by inspecting the
/// code, which is why write access is restored immediately after the install call, before any
/// assertion -- a failed assertion below must never leave the directory unwritable for the
/// rest of the suite.</p>
/// <p>Mutation: discard <code>RemoveDirectoryTree</code>'s result in
/// <method>OcuPilot.Install.Installer.EnsureShellFiles</method> (always fall through to
/// <method>CopyTree</method> instead of reporting the warn and quitting) -> the copy into the
/// still-read-only directory itself fails, so the "install completes" assertion goes red.</p>
Method TestUnclearableTargetDirectoryLeavesTheOldBundleInPlace()
{
    Set tTarget = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/probeocupilot")
    Set tSourceA = ..WriteScratchBundle("qaUnclearableSeed", "seed-marker.txt")
    Set tSC0 = ##class(OcuPilot.Install.Installer).Install("probe", 0, tSourceA)
    Do ##class(%File).RemoveDirectoryTree(tSourceA)
    Do $$$AssertStatusOK(tSC0, "seeding the shell directory with a real bundle succeeds")

    Set tSourceB = ..WriteScratchBundle("qaUnclearableReplacement", "replacement-marker.txt")
    Set tRO = ##class(%File).SetReadOnly(tTarget, 0, .tRORet)

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 0, tSourceB)
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    ; Restored immediately, before any assertion: an assertion failure below must never
    ; leave the shell directory unwritable for the rest of the suite.
    Set tRestored = ##class(%File).SetWriteable(tTarget, 0, .tWRet)
    Do ##class(%File).RemoveDirectoryTree(tSourceB)

    Do $$$AssertTrue(tRO, "the shell directory was made read-only for this test")
    Do $$$AssertTrue(tRestored, "write access is restored so cleanup can proceed")
    Do $$$AssertStatusOK(tSC, "install completes even though the shell directory could not be cleared")
    Do $$$AssertTrue(tWarns [ "could not be cleared", "the failure to clear is reported as a warn")
    Do $$$AssertTrue(##class(%File).Exists(tTarget _ "seed-marker.txt"), "the bundle already installed there survives because clearing failed before anything was deleted")
    Do $$$AssertTrue('##class(%File).Exists(tTarget _ "replacement-marker.txt"), "and the replacement bundle was never copied in")
}

/// <p>AC12 -- when the shell directory cannot be removed, uninstall still removes every other
/// named object and reports the survivor as a warn, rather than leaving the whole profile
/// installed because one directory would not go (QA -- the third of this spec's named
/// residual risks). Forces the failure the same way as
/// <method>TestUnclearableTargetDirectoryLeavesTheOldBundleInPlace</method>, and restores
/// write access immediately after the call for the same reason.</p>
/// <p>Mutation: delete the <code>If tShellDirLeft { Do ..LogWarn(...) }</code> block from
/// <method>OcuPilot.Install.Installer.Uninstall</method> -> uninstall still succeeds and the
/// directory still survives, but the warn assertion goes red.</p>
Method TestUninstallSurvivesAnUnremovableShellDirectory()
{
    Set tTarget = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/probeocupilot")
    Do $$$AssertTrue(##class(%File).DirectoryExists(tTarget), "the probe shell directory exists before uninstall")

    ; An empty directory's own permissions do not govern whether it can be removed -- that is
    ; controlled by its PARENT directory, which this test never touches. The directory must
    ; hold at least one file of its own before making it read-only actually blocks removal.
    Set tSourceA = ..WriteScratchBundle("qaUninstallSurvivesSeed", "seed-marker.txt")
    Set tSCSeed = ##class(OcuPilot.Install.Installer).Install("probe", 0, tSourceA)
    Do ##class(%File).RemoveDirectoryTree(tSourceA)
    Do $$$AssertStatusOK(tSCSeed, "seeding the shell directory with a real bundle succeeds")
    Do $$$AssertTrue(##class(%File).Exists(tTarget _ "seed-marker.txt"), "the shell directory holds a file of its own before the read-only attempt")

    Set tRO = ##class(%File).SetReadOnly(tTarget, 0, .tRORet)

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Uninstall("probe", 1)
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    ; Restored immediately, before any assertion below: an assertion failure must never leave
    ; the shell directory unwritable for the rest of the suite.
    Set tRestored = ##class(%File).SetWriteable(tTarget, 0, .tWRet)

    Do $$$AssertTrue(tRO, "the shell directory was made read-only for this test")
    Do $$$AssertTrue(tRestored, "write access is restored so cleanup can proceed")
    Do $$$AssertStatusOK(tSC, "uninstall still succeeds when the shell directory could not be removed")
    Do $$$AssertTrue(tWarns [ "could not be removed", "the survivor is reported as a warn")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC2, "switch to %SYS")
        Do $$$AssertTrue('##class(Security.Applications).Exists("/probeocupilot", .tE1, .tS1), "the shell application is still removed")
        Do $$$AssertTrue('##class(Security.Roles).Exists("ProbeOcuPilotShell", .tE2, .tS2), "and the shell role")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS

    Do $$$AssertTrue(##class(%File).DirectoryExists(tTarget), "but the shell directory itself survives, since it could not be removed")

    ; Clean up for real now that write access is restored, so later tests see the profile
    ; fully uninstalled rather than a directory this test left behind.
    Do ##class(%File).RemoveDirectoryTree(tTarget)
    Do $$$AssertTrue('##class(%File).DirectoryExists(tTarget), "the directory is removed once writable again")
}

}
