/// <p>Pins <class>OcuPilot.Install.Roster</class> against what
/// <method>OcuPilot.Install.Installer.Install</method> actually asserts, and against the bundle
/// destination <file>module.xml</file>'s <code>&lt;FileCopy&gt;</code> resolves (Story 1.16,
/// AD-17, AD-21).</p>
/// <p><b>Why the manifest's own bytes are not read here.</b> The repository is not mounted into
/// this instance -- <file>docker-compose.yml</file> mounts <file>src/</file>,
/// <file>scripts/</file> and <file>ui/</file> and never the repository root -- so no
/// <code>%UnitTest</code> running inside IRIS can open <file>module.xml</file>. The committed
/// file's bytes are pinned where they are reachable, in
/// <file>ui/tools/ipm-manifest.test.mjs</file>; what is pinned here is the half that only a
/// running instance can answer: that the values the manifest is generated from are the values
/// install puts on the instance, and that the expression the manifest hands IPM resolves to the
/// directory the handler serves from.</p>
/// <p>Every assertion reads the <b>production</b> profile: the roster declares
/// <code>/ocupilot</code> and <code>/api/ocupilot</code>, and a repeat production install is a
/// no-op by construction. Nothing here uninstalls.</p>
Class OcuPilot.Test.Manifest Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Quit ##class(OcuPilot.Install.Installer).Install("")
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

/// <p>The roster declares exactly the two production applications this epic installs, at the
/// paths the installer's own name roster uses. Without this, every comparison below could
/// agree about an application nothing serves.</p>
/// <p>Mutation (Rule 19): change either <code>path</code> in
/// <class>OcuPilot.Install.Roster</class>'s <code>XData Manifest</code> block -- red.</p>
Method TestRosterDeclaresTheTwoProductionApplications()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Get(.tRoster), "the roster reads")
    Do $$$AssertEquals(tRoster.applications.%Size(), 2, "Epic 1 declares the shell and the API, and no third application")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application("shell", .tShell), "the roster declares the shell application")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application("api", .tApi), "the roster declares the API application")
    Do $$$AssertEquals(tShell.path, "/ocupilot", "the roster's shell path is the one the installer creates")
    Do $$$AssertEquals(tApi.path, "/api/ocupilot", "the roster's API path is the one the installer creates")

    Set tSC = ##class(OcuPilot.Install.Roster).Application("nosuchkey", .tMissing)
    Do $$$AssertStatusNotOK(tSC, "an absent key is refused rather than answered with an empty declaration")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "nosuchkey", "and the refusal names the key")
}

/// <p>Every value the roster's <code>manifest</code> half declares is the value the live
/// application carries after install -- read from <class>Security.Applications</class>, not
/// from the installer's own copy of it.</p>
/// <p>Mutation (Rule 19): change any <code>manifest</code> value in
/// <class>OcuPilot.Install.Roster</class> and re-run install -- red on that property.</p>
Method TestInstalledApplicationsCarryEveryRosterManifestValue()
{
    Set tChecked = 0
    For tKey = "shell", "api" {
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application(tKey, .tApp), "the roster declares '" _ tKey _ "'")
        Do $$$AssertTrue(..ReadApplication(tApp.path, .tProps), "the application " _ tApp.path _ " exists after install")
        Set tIterator = tApp.manifest.%GetIterator()
        While tIterator.%GetNext(.tProperty, .tValue) {
            Do $$$AssertEquals($Get(tProps(tProperty)), tValue, tApp.path _ " carries the roster's " _ tProperty)
            Set tChecked = tChecked + 1
        }
    }
    ; A roster that declared nothing would pass every assertion above by making none, which is
    ; the vacuous pass this whole story exists to prevent.
    Do $$$AssertTrue(tChecked >= 10, "both applications' manifest halves were actually compared, not skipped (" _ tChecked _ " properties)")
}

/// <p>Every property the roster marks <code>installer</code> -- the instance-derived ones the
/// manifest must never state -- carries the value install asserted, computed here from the
/// instance rather than read back from the installer.</p>
/// <p>Mutation (Rule 19): move <code>NameSpace</code> or <code>Path</code> from an
/// application's <code>installer</code> list into its <code>manifest</code> map -- the
/// generator refuses first, and dropping it from both lists leaves this red.</p>
Method TestInstanceDerivedPropertiesAreTheOnesInstallAsserts()
{
    Set tInstallNs = $NAMESPACE
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application("shell", .tShell), "the roster declares the shell application")
    Do $$$AssertTrue(..ReadApplication(tShell.path, .tShellProps), "the shell application exists after install")
    Set tShellNames = ..InstallerNames(tShell)
    Do $$$AssertEquals(tShellNames, "MatchRoles,NameSpace,Path", "the shell's instance-derived set is namespace, matching role and bundle path")
    Do $$$AssertEquals($Get(tShellProps("NameSpace")), tInstallNs, "the shell application runs in the namespace install was run from")
    Do $$$AssertEquals($Get(tShellProps("MatchRoles")), ":OcuPilotShell", "and carries the purpose-built read-only role install asserts")
    Do $$$AssertEquals($Get(tShellProps("Path")), ##class(OcuPilot.Api.StaticHandler).RootDirectory(tShell.path), "and the bundle directory the handler resolves for its own path")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application("api", .tApi), "the roster declares the API application")
    Do $$$AssertTrue(..ReadApplication(tApi.path, .tApiProps), "the API application exists after install")
    Do $$$AssertEquals(..InstallerNames(tApi), "MatchRoles,NameSpace", "the API's instance-derived set is namespace and matching role")
    Do $$$AssertEquals($Get(tApiProps("NameSpace")), tInstallNs, "the API application runs in the namespace install was run from")
    Do $$$AssertEquals($Get(tApiProps("MatchRoles")), "", "and carries no matching role of any kind (AD-8)")
}

/// <p>The instance-derived property names <var>pApplication</var> declares, sorted and
/// comma-separated.</p>
Method InstallerNames(pApplication As %DynamicObject) As %String
{
    Kill tNames
    Set tIterator = pApplication.installer.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tNames(tName) = ""
    }
    Set tOut = ""
    Set tName2 = $Order(tNames(""))
    While tName2 '= "" {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName2
        Set tName2 = $Order(tNames(tName2))
    }
    Quit tOut
}

/// <p>No application declares a privilege property in its <code>manifest</code> half (AD-10,
/// AD-21): a matching-role set is asserted by install, never widened by a distribution
/// manifest. <file>ui/tools/ipm-manifest.mjs</file> refuses such a roster before it can be
/// generated; this asserts the same rule about the roster the instance actually reads.</p>
/// <p>Mutation (Rule 19): add <code>"MatchRoles": ":%All"</code> to either application's
/// <code>manifest</code> map -- red.</p>
Method TestNoApplicationWidensPrivilegeFromItsManifestHalf()
{
    For tKey = "shell", "api" {
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application(tKey, .tApp), "the roster declares '" _ tKey _ "'")
        Set tIterator = tApp.manifest.%GetIterator()
        Set tSeen = 0
        While tIterator.%GetNext(.tProperty, .tValue) {
            Set tSeen = tSeen + 1
            Do $$$AssertNotEquals(tProperty, "MatchRoles", tKey _ " declares no MatchRoles in its manifest half")
            Do $$$AssertNotEquals(tProperty, "Roles", tKey _ " declares no Roles in its manifest half")
            Do $$$AssertNotEquals(tProperty, "AddedRoles", tKey _ " declares no AddedRoles in its manifest half")
            Do $$$AssertEquals($ZConvert(tValue, "U") [ "%ALL", 0, tKey _ "'s " _ tProperty _ " grants no %All")
        }
        Do $$$AssertTrue(tSeen > 0, tKey _ "'s manifest half was actually inspected")
        Do $$$AssertTrue((", " _ ..InstallerNames(tApp) _ ",") [ "MatchRoles,", tKey _ " names MatchRoles as instance-derived, so install asserts it")
    }
}

/// <p><method>OcuPilot.Install.Roster.AssertedProperties</method> is exactly the union of both
/// halves, which is the set <method>OcuPilot.Install.Installer.StateFingerprint</method> folds
/// and the set <method>OcuPilot.Install.Installer.EnsureWebApplication</method> compares. It is
/// the reason adding a property to an application is one edit rather than three.</p>
/// <p>Mutation (Rule 19): drop the <code>installer</code> half from
/// <method>OcuPilot.Install.Roster.AssertedProperties</method> -- red.</p>
Method TestAssertedPropertiesIsTheUnionOfBothHalves()
{
    For tKey = "shell", "api" {
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Application(tKey, .tApp), "the roster declares '" _ tKey _ "'")
        Set tAsserted = ##class(OcuPilot.Install.Roster).AssertedProperties(tKey)
        Do $$$AssertTrue(tAsserted '= "", tKey _ " asserts a non-empty property set")

        Kill tWant
        Set tIterator = tApp.manifest.%GetIterator()
        While tIterator.%GetNext(.tProperty, .tValue) {
            Set tWant(tProperty) = ""
        }
        Set tIterator2 = tApp.installer.%GetIterator()
        While tIterator2.%GetNext(.tIndex, .tName) {
            Do $$$AssertEquals($Data(tWant(tName)), 0, tKey _ " declares " _ tName _ " on one half only")
            Set tWant(tName) = ""
        }
        Set tExpected = ""
        Set tName2 = $Order(tWant(""))
        While tName2 '= "" {
            Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ tName2
            Set tName2 = $Order(tWant(tName2))
        }
        Do $$$AssertEquals(tAsserted, tExpected, tKey _ "'s asserted set is the union of its two halves")

        ; Every asserted name is a property the live application actually carries, so a typo in
        ; the roster fails here rather than becoming a name the installer compares against ""
        ; forever and the fingerprint folds as an empty component.
        Do $$$AssertTrue(..ReadApplication(tApp.path, .tProps), "the application " _ tApp.path _ " exists after install")
        For tI = 1:1:$Length(tAsserted, ",") {
            Set tProperty2 = $Piece(tAsserted, ",", tI)
            Do $$$AssertEquals($Data(tProps(tProperty2)), 1, tKey _ "'s asserted property " _ tProperty2 _ " is one Security.Applications actually carries")
        }
    }
}

/// <p><b>The bundle destination the manifest resolves is the directory the handler serves
/// from</b> (AD-21). The manifest's <code>&lt;FileCopy Target&gt;</code> is the roster's
/// <code>bundle.destinationTemplate</code>, an IPM placeholder string; this expands it the way
/// IPM expands it and requires the result to equal
/// <method>OcuPilot.Api.StaticHandler.RootDirectory</method>'s answer for the roster's
/// <code>destinationApplication</code>, and the <code>Path</code> install actually set. That
/// equality is the only thing keeping the template and the handler's rule from drifting: the
/// template is a string, and nothing else on either side would notice if one of them changed.</p>
/// <p>The template cannot call the handler directly. <code>&lt;FileCopy&gt;</code>'s
/// <code>InstallDirectory</code> is <code>Required</code> and is validated in IPM's
/// <code>Validate</code> phase, which runs <b>before</b> <code>Compile</code>; on the install
/// this manifest is for, the handler is loaded and not yet compiled, so
/// <code>#{##class(OcuPilot.Api.StaticHandler).RootDirectory(...)}</code> evaluates to
/// <code>""</code> and the module fails validation. Observed on a throwaway container.</p>
/// <p>Mutation (Rule 19): change <code>bundle.destinationTemplate</code> in
/// <class>OcuPilot.Install.Roster</class> to any other directory, or make
/// <method>OcuPilot.Api.StaticHandler.RootDirectory</method> resolve under the install
/// directory rather than the data directory -- red either way.</p>
Method TestBundleDestinationIsTheHandlersOwnAnswer()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Get(.tRoster), "the roster reads")
    Set tApplication = tRoster.bundle.destinationApplication
    Do $$$AssertEquals(tApplication, "/ocupilot", "the bundle lands in the shell application's own directory")

    Set tDataDir = ##class(%File).NormalizeDirectory($System.Util.DataDirectory())
    Set tTemplate = tRoster.bundle.destinationTemplate
    Do $$$AssertTrue(tTemplate [ "${dataDir}", "the template resolves under the data directory placeholder: " _ tTemplate)
    Do $$$AssertEquals($ZConvert(tTemplate, "L") [ "cspdir", 0, "and never under the install directory's csp, which is not writable on this image")
    Set tResolved = $Replace(tTemplate, "${dataDir}", tDataDir)
    Set tDirect = ##class(OcuPilot.Api.StaticHandler).RootDirectory(tApplication)

    Do $$$AssertTrue(tDirect '= "", "the handler resolves a bundle directory for this application")
    Do $$$AssertEquals(tResolved, tDirect, "the manifest's expanded target is the handler's own answer")
    Do $$$AssertEquals($Extract(tResolved, 1, $Length(tDataDir)), tDataDir, "under the data directory, which is writable on this image")

    Do $$$AssertTrue(..ReadApplication(tApplication, .tProps), "the shell application exists after install")
    Do $$$AssertEquals($Get(tProps("Path")), tResolved, "and install put exactly that directory on it, so the copy target and the serve root cannot drift")
}

/// <p>The roster's <code>invoke</code> declaration -- what the generator turns into
/// <file>module.xml</file>'s single <code>&lt;Invoke&gt;</code> -- names the one install entry
/// point, in the one phase that runs. <code>Phase</code> is load-bearing: its IPM default is
/// <code>Configure</code>, which is not in the <code>activate</code> chain, so a declaration
/// that omitted it would be accepted and never run.</p>
/// <p>Mutation (Rule 19): change <code>invoke.method</code> to <code>StartPath</code>, or
/// <code>invoke.phase</code> to <code>Configure</code> -- red.</p>
Method TestInvokeDeclarationNamesTheOneInstallEntryPoint()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Get(.tRoster), "the roster reads")
    Do $$$AssertEquals(tRoster.invoke.class, "OcuPilot.Install.Installer", "the manifest invokes the one installer class (AD-17)")
    Do $$$AssertEquals(tRoster.invoke.method, "Install", "and Install, never StartPath -- the IPM path never unexpires (DW-92)")
    Do $$$AssertEquals(tRoster.invoke.phase, "Activate", "in the Activate phase, the only one the activate chain runs")
    Do $$$AssertEquals(tRoster.invoke.when, "After", "after it, so the FileCopy that runs at the phase's start has already placed the bundle")

    Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId(tRoster.invoke.class _ "||" _ tRoster.invoke.method), "the class and method the manifest names are compiled on this instance")
}

/// <p>The module's shipped identity: a name and a semantic version the manifest can carry, and
/// requirements that are measurable rather than prose (NFR-13).</p>
/// <p>Mutation (Rule 19): blank <code>module.version</code> or
/// <code>systemRequirements.ipmVersion</code> in <class>OcuPilot.Install.Roster</class> --
/// red.</p>
Method TestModuleIdentityAndRequirementsAreDeclared()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Get(.tRoster), "the roster reads")
    Do $$$AssertEquals(tRoster.module.name, "ocupilot", "the module ships under its own name")
    Do $$$AssertTrue($Match(tRoster.module.version, "^[0-9]+\.[0-9]+\.[0-9]+$"), "with a semantic version: " _ tRoster.module.version)
    Do $$$AssertEquals(tRoster.module.sourcesRoot, "src", "and a sources root that resolves OcuPilot.PKG to src/OcuPilot/")
    Do $$$AssertTrue(tRoster.systemRequirements.ipmVersion '= "", "NFR-13's 'IPM 0.10.x' is declared as a version expression IPM evaluates")
    Do $$$AssertTrue(tRoster.systemRequirements.version '= "", "and the IRIS version requirement with it")

    ; The test classes are shipped out of scope, so an install needs no test fixtures; the
    ; production package is shipped whole.
    Set tScoped = ""
    Set tShipped = ""
    Set tIterator = tRoster.resources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tResource) {
        If tResource.scope = "test" {
            Set tScoped = tScoped _ $Select(tScoped = "": "", 1: ",") _ tResource.name
        } Else {
            Set tShipped = tShipped _ $Select(tShipped = "": "", 1: ",") _ tResource.name
        }
    }
    Do $$$AssertEquals(tShipped, "OcuPilot.PKG", "one shipped resource, the whole production package")
    Do $$$AssertEquals(tScoped, "OcuPilot.Test.PKG", "and the test package, scoped out of a shipped install (AD-25)")
}

}
