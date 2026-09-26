/// <p>The one declaration of the facts <file>module.xml</file> and
/// <class>OcuPilot.Install.Installer</class> would otherwise each carry a copy of (AD-17,
/// AD-3): the module's name, version and sources root, its system requirements, the seven
/// fixed package folders under <file>src/OcuPilot/</file>, the shipped resource list, the
/// built client bundle's source directory, and, per production web application, its path,
/// its description, the properties the manifest asserts and the properties only
/// <method>OcuPilot.Install.Installer.Install</method> can assert.</p>
/// <p>Three consumers read this block and nothing else declares its contents:
/// <method>Get</method> here (through <class>%Dictionary.XDataDefinition</class>, the idiom
/// <class>OcuPilot.Screen.Area</class> uses), <file>ui/tools/ipm-manifest.mjs</file>, which
/// generates and drift-checks <file>module.xml</file> from it, and
/// <file>scripts/check-objectscript.py</file>, which takes its fixed-package set from it.</p>
/// <p><b>The <code>manifest</code>/<code>installer</code> split is the contract.</b>
/// <code>manifest</code> holds instance-independent values, emitted verbatim as
/// <code>&lt;WebApplication&gt;</code> attributes. <code>installer</code> names the
/// properties whose values are instance-derived -- the install namespace, the resolved
/// bundle directory, the profile's matching role -- which the manifest must never state and
/// <method>OcuPilot.Install.Installer.Install</method> asserts at runtime. Their union is
/// the property set every consumer uses: the set
/// <method>OcuPilot.Install.Installer.EnsureWebApplication</method> compares and repairs,
/// and the set <method>OcuPilot.Install.Installer.StateFingerprint</method> folds. Adding a
/// property to an application's asserted set is one edit here.</p>
/// <p><code>MatchRoles</code> and <code>Roles</code> are <code>installer</code> properties on
/// every application by rule (AD-10, AD-21): a privilege set is asserted by the installer,
/// never widened by a manifest, and <file>ui/tools/ipm-manifest.mjs</file> refuses a roster
/// that names either under <code>manifest</code>.</p>
/// <p><b>Every application declares its own <code>matchRole</code></b> (Story 1.17, AD-21).
/// It is the name of the one purpose-built role
/// <method>OcuPilot.Install.Installer.EnsureApplicationRoles</method> creates and asserts for
/// that application -- read-only on the install namespace's code database and nothing else --
/// and <code>""</code> means the application carries no matching role at all, which is what
/// the password-authenticated API declares so that a request runs with exactly the privileges
/// its own account holds (AD-8). The field is required on every application and refused when
/// absent, so a fourth application cannot arrive with its privilege floor unstated.</p>
/// <p><b><code>description</code> is an asserted property, not a create-time decoration</b>
/// (Story 1.17, DW-199). <method>AssertedProperties</method> names <code>Description</code>
/// alongside the <code>manifest</code> and <code>installer</code> sets, so a description
/// edited on the instance is repaired on the next install like every other drifted property
/// and moves <method>OcuPilot.Install.Installer.StateFingerprint</method> the same way. It
/// stays a top-level field rather than a <code>manifest</code> key because
/// <file>ui/tools/ipm-manifest.mjs</file> emits it as the <code>&lt;WebApplication&gt;</code>
/// element's own <code>Description</code> attribute; declaring it twice would be two
/// declarations of one fact.</p>
/// <p><code>bundle.destinationTemplate</code> is the directory the manifest's
/// <code>&lt;FileCopy&gt;</code> copies the built client into, written in IPM's own
/// <code>${dataDir}</code> placeholder form. It is <b>not</b> a second spelling of a path:
/// <method>OcuPilot.Test.Manifest.TestBundleDestinationIsTheHandlersOwnAnswer</method> expands
/// it against the live instance and requires the result to equal
/// <method>OcuPilot.Api.StaticHandler.RootDirectory</method>'s answer for
/// <code>destinationApplication</code> and the <code>Path</code> install actually set, so the
/// two implementations are pinned together and a drift in either is red.</p>
/// <p><b>IPM's arbitrary-ObjectScript form <code>#{##class(...)...}</code> cannot be used here.</b>
/// Verified on a throwaway container: <code>&lt;FileCopy&gt;</code>'s
/// <code>InstallDirectory</code> is <code>Required</code> and is validated in the
/// <code>Validate</code> phase, which runs <i>before</i> <code>Compile</code> -- so on the
/// install this manifest is for, the handler class it would call is loaded but not yet
/// compiled, the expression evaluates to <code>""</code>, and the whole module fails
/// validation. <code>${cspdir}</code> is wrong for a different reason:
/// <file>src/OcuPilot/Api/StaticHandler.cls</file> records that the install directory's
/// <code>csp</code> is not writable on the pinned image.</p>
/// <p>Each resource declares <code>filenameExtension</code>, and it is load-bearing rather than
/// decorative: a <code>.PKG</code> resource is loaded with
/// <code>$System.OBJ.ImportDir(&lt;sources root&gt;, "*" _ FilenameExtension, ...)</code>
/// recursively, and the property's IPM default is empty -- a wildcard of <code>"*"</code>, which
/// tries to import <b>every file</b> under <file>src/</file>. The four
/// <file>.gitkeep</file> placeholders that keep empty package folders in version control are
/// enough to fail the whole load with "not a supported type", naming a file and no module.</p>
/// <p>The <code>autheEnabled</code> numbers are the bits
/// <file>irissys/%sySecurityMacros.inc</file> defines for
/// <code>Security.Applications.AutheEnabled</code>: <code>$$$AutheUnauthenticated</code> is
/// <code>64</code> and <code>$$$AuthePassword</code> is <code>32</code>. They are written as
/// numbers rather than as <code>#{$$$...}</code> manifest expressions so that one value is
/// read the same way by all three consumers, only one of which runs inside IRIS.</p>
Class OcuPilot.Install.Roster Extends %RegisteredObject
{

/// <p>The name of the <code>XData</code> block <method>Get</method> reads, so a caller and
/// this class name it once.</p>
Parameter ROSTERXDATA As %String = "Manifest";

XData Manifest
{
{
  "module": {
    "name": "ocupilot",
    "version": "1.0.1",
    "description": "An agent co-pilot for the InterSystems IRIS System Management Portal: an Angular shell over an ObjectScript REST API.",
    "packaging": "module",
    "sourcesRoot": "src"
  },
  "systemRequirements": {
    "version": ">=2026.2",
    "ipmVersion": ">=0.10.0"
  },
  "packages": ["Api", "Area", "Install", "Kernel", "Port", "Screen", "Test"],
  "resources": [
    {"name": "OcuPilot.PKG", "filenameExtension": "cls"},
    {"name": "OcuPilot.Test.PKG", "scope": "test", "filenameExtension": "cls"}
  ],
  "bundle": {
    "source": "ui/dist/ocupilot-ui/browser/",
    "destinationApplication": "/ocupilot",
    "destinationTemplate": "${dataDir}csp/ocupilot/"
  },
  "applications": [
    {
      "key": "shell",
      "path": "/ocupilot",
      "description": "OcuPilot shell (unauthenticated static serving with a deep-link fallback)",
      "matchRole": "OcuPilotShell",
      "manifest": {
        "AutheEnabled": 64,
        "DispatchClass": "OcuPilot.Api.StaticHandler",
        "Enabled": 1,
        "Resource": "",
        "ServeFiles": 0
      },
      "installer": ["MatchRoles", "NameSpace", "Path"]
    },
    {
      "key": "api",
      "path": "/api/ocupilot",
      "description": "OcuPilot REST API (password authentication, JWT, no server session)",
      "matchRole": "",
      "manifest": {
        "AutheEnabled": 32,
        "DispatchClass": "OcuPilot.Api.Router",
        "Enabled": 1,
        "GroupById": "%ISCMgtPortal",
        "JWTAccessTokenTimeout": 60,
        "JWTAuthEnabled": 1,
        "JWTRefreshTokenTimeout": 900,
        "Resource": "",
        "ServeFiles": 0
      },
      "installer": ["MatchRoles", "NameSpace"]
    },
    {
      "key": "readiness",
      "path": "/api/ocupilot/readiness",
      "description": "OcuPilot readiness (unauthenticated: whether OcuPilot is installed, nothing else)",
      "matchRole": "OcuPilotReadiness",
      "manifest": {
        "AutheEnabled": 64,
        "DispatchClass": "OcuPilot.Api.Readiness",
        "Enabled": 1,
        "Resource": "",
        "ServeFiles": 0
      },
      "installer": ["MatchRoles", "NameSpace"]
    }
  ],
  "invoke": {
    "class": "OcuPilot.Install.Installer",
    "method": "Install",
    "phase": "Activate",
    "when": "After"
  }
}
}

/// <p>The declaration as a <class>%DynamicObject</class>. Re-read on every call rather than
/// cached: the cost is one dictionary open, and a cached copy is a second source of truth a
/// recompile does not reach.</p>
/// <p>Returns a failing <code>%Status</code> when the block is missing or unparseable, and
/// never an empty object: a caller that read an unreadable roster as "no properties" would
/// assert nothing and report every drifted application correct.</p>
ClassMethod Get(Output pRoster As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pRoster = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), ..#ROSTERXDATA, , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the roster XData block '" _ ..#ROSTERXDATA _ "' is missing from " _ $ClassName())
            Quit
        }
        Do tXData.Data.Rewind()
        Set pRoster = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        If '$IsObject(pRoster) {
            Set pRoster = ""
            Set tSC = $$$ERROR($$$GeneralError, "the roster XData block in " _ $ClassName() _ " is not a JSON object")
        }
    } Catch ex {
        Set pRoster = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every application key the roster declares, in declaration order, as a comma-separated
/// list -- the one place a consumer learns how many applications there are and what they are
/// called (DW-192). <method>OcuPilot.Install.Installer.Names</method> iterates this rather
/// than naming <code>shell</code> and <code>api</code>, so a fourth application is one edit to
/// the <code>XData</code> block above and no edit anywhere else.</p>
/// <p>Returns <code>""</code> on any failure, which
/// <method>OcuPilot.Install.Installer.Names</method> turns into a failing <code>%Status</code>
/// before install asserts anything: an empty list would make install assert no application at
/// all and report every drifted one correct.</p>
ClassMethod Keys() As %String
{
    Set tOut = ""
    Try {
        Set tSC = ..Get(.tRoster)
        If $$$ISERR(tSC) Quit
        Set tApps = tRoster.applications
        If '$IsObject(tApps) Quit
        Set tIterator = tApps.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tApp) {
            If '$IsObject(tApp) Continue
            If tApp.key = "" Continue
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tApp.key
        }
    } Catch {
        Set tOut = ""
    }
    Quit tOut
}

/// <p>The roster's declaration for the application keyed <var>pKey</var>
/// (<code>"shell"</code>, <code>"api"</code>, <code>"readiness"</code>), or a failing
/// <code>%Status</code> naming the key when the roster carries none.</p>
ClassMethod Application(pKey As %String, Output pApplication As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pApplication = ""
    Try {
        Set tSC = ..Get(.tRoster)
        If $$$ISERR(tSC) Quit
        Set tApps = tRoster.applications
        If '$IsObject(tApps) {
            Set tSC = $$$ERROR($$$GeneralError, "the roster carries no applications array")
            Quit
        }
        Set tIterator = tApps.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tApp) {
            If $IsObject(tApp), tApp.key = pKey {
                Set pApplication = tApp
                Quit
            }
        }
        If '$IsObject(pApplication) {
            Set pApplication = ""
            Set tSC = $$$ERROR($$$GeneralError, "the roster declares no application keyed '" _ pKey _ "'")
        }
    } Catch ex {
        Set pApplication = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The full property set application <var>pKey</var> asserts -- its <code>manifest</code>
/// keys, its <code>installer</code> names and <code>Description</code> (DW-199) -- as a
/// comma-separated list in a stable sorted order. <method>OcuPilot.Install.Installer.StateFingerprint</method> reads it, so the set
/// it folds and the set <method>OcuPilot.Install.Installer.Install</method> asserts cannot
/// differ. Returns <code>""</code> on any failure, which
/// <method>OcuPilot.Install.Installer.RosterNames</method> turns into a failing
/// <code>%Status</code> before install asserts anything, and which
/// <method>OcuPilot.Install.Installer.ApplicationFingerprint</method> renders as
/// <code>NOPROPERTIES</code> rather than as an absent application.</p>
ClassMethod AssertedProperties(pKey As %String) As %String
{
    Set tOut = ""
    Try {
        Set tSC = ..Application(pKey, .tApp)
        If $$$ISERR(tSC) Quit
        Kill tNames
        Set tIterator = tApp.manifest.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tNames(tName) = ""
        }
        Set tIterator2 = tApp.installer.%GetIterator()
        While tIterator2.%GetNext(.tIndex, .tName2) {
            Set tNames(tName2) = ""
        }
        ; DW-199: the description is asserted and repaired like every other property, so it
        ; belongs in the set the installer compares and the fingerprint folds. It is declared
        ; as the application's own top-level "description" rather than as a manifest key
        ; because ui/tools/ipm-manifest.mjs emits it as the <WebApplication> element's own
        ; Description attribute; naming it in both places would be two declarations of one fact.
        Set tNames("Description") = ""
        Set tName3 = $Order(tNames(""))
        While tName3 '= "" {
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName3
            Set tName3 = $Order(tNames(tName3))
        }
    } Catch {
        Set tOut = ""
    }
    Quit tOut
}

}
