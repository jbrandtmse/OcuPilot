/// <p>What creates, repairs and removes the <b>identity</b> privileged routine application and
/// its role -- the second escalation AD-9 was amended for (DW-444) -- and what detects drift on
/// it. Added at Story 5.4's code review.</p>
/// <p><b>Why it is not optional coverage.</b> The escalation behind that pair is entered on every
/// dispatched request. An application that is absent, disabled or pointed at the wrong routine,
/// or a role that no longer carries
/// <parameter>OcuPilot.Kernel.State.Base.IDENTITYRESOURCES</parameter>, refuses <i>every</i>
/// account on the instance. Until this class existed, nothing read either object back: the whole
/// suite, the browser gate and <file>scripts/smoke.sh</file> stayed green for any shape of it,
/// because an enabled account still answered enabled.</p>
/// <p>It also pins the containment claim the class headers make -- the role grants the two
/// resources the read needs and nothing else, and the application admits one class -- so widening
/// either reddens a test rather than passing unnoticed.</p>
/// <p><b>It runs OcuPilot's production install and the disposable <code>"probe"</code> profile's,
/// so it runs on a throwaway container only</b> (<file>scripts/ci-throwaway.sh</file>,
/// <code>ocupilot-ci</code>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Every object it reads, drifts and
/// repairs is the probe profile's; the production pair is never written.</p>
Class OcuPilot.Test.IdentityInstall Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. The same variable <class>OcuPilot.Test.Installer</class> uses, for the same
/// reason: this class runs the production install.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The disposable profile every object below belongs to.</p>
Parameter PROFILE = "probe";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.IdentityInstall runs OcuPilot's PRODUCTION install and the probe profile's on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Production first, then the probe: every <method>OcuPilot.Install.Installer.Install</method>
/// ends by recording a version row through the <i>production</i> privileged routine application,
/// so the probe install cannot succeed on an instance production has never reached. Same ordering
/// <class>OcuPilot.Test.Installer</class> establishes.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Quit ##class(OcuPilot.Install.Installer).Install(..#PROFILE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Quit ##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 1)
}

/// <p>The probe profile's identity application and role name -- the suffixed derivative
/// <method>OcuPilot.Install.Installer.Names</method> builds, resolved here rather than
/// transcribed, so a rename moves both together.</p>
ClassMethod IdentityName() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION _ "Probe"
}

/// <p>The routine database of the install namespace, which is what the application's
/// <code>Routines</code> entry must name. <b>Caller contract:</b> answers <code>""</code> when it
/// cannot be resolved, which every caller asserts against rather than folding into a comparison.</p>
ClassMethod CodeDatabase() As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If $IsObject(tNsObj) Set tOut = tNsObj.Routines
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The live shape of the probe's identity pair, as
/// <code>&lt;role Resources&gt;|&lt;role GrantedRoles&gt;|&lt;app Enabled&gt;|&lt;app Type&gt;|&lt;app MatchRoles&gt;|&lt;app Routines&gt;</code>.
/// An absent object contributes <code>ABSENT</code> and a failed read <code>READFAILED</code>, so
/// the two can never compare equal -- the discipline
/// <method>OcuPilot.Install.Installer.StateFingerprint</method> already follows.</p>
ClassMethod IdentityShape() As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tName = ..IdentityName()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tRolePart = "ABSENT|ABSENT"
        If ##class(Security.Roles).Exists(tName, .tRoleObj, .tRoleSC) {
            Set tGetSC = ##class(Security.Roles).Get(tName, .tRoleProps, .tRoleObj2)
            If $$$ISERR(tGetSC) {
                Set tRolePart = "READFAILED|READFAILED"
            } Else {
                Set tRolePart = $Get(tRoleProps("Resources")) _ "|" _ $Get(tRoleProps("GrantedRoles"))
            }
        }
        Set tAppPart = "ABSENT|ABSENT|ABSENT|ABSENT"
        If ##class(Security.Applications).Exists(tName, .tAppObj, .tAppSC) {
            Set tGetSC2 = ##class(Security.Applications).Get(tName, .tAppProps)
            If $$$ISERR(tGetSC2) {
                Set tAppPart = "READFAILED|READFAILED|READFAILED|READFAILED"
            } Else {
                Set tAppPart = +$Get(tAppProps("Enabled")) _ "|" _ +$Get(tAppProps("Type")) _ "|" _ $Get(tAppProps("MatchRoles")) _ "|" _ $Get(tAppProps("Routines"))
            }
        }
        Set tOut = tRolePart _ "|" _ tAppPart
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "RAISED"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>Write <var>pProps</var> onto the probe's identity application, or the application
/// <var>pName</var> names, and answer whether the modify succeeded. Used to induce drift; every method that calls it repairs by re-installing.</p>
ClassMethod DriftApplication(ByRef pProps, pName As %String = "") As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tName = $Select(pName = "": ..IdentityName(), 1: pName)
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Applications).Modify(tName, .pProps)
        Set tOk = $$$ISOK(tSC)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tOk
}

/// <p>Write <var>pResources</var> onto the probe's identity role, and answer whether the modify
/// succeeded. See <method>DriftApplication</method>.</p>
ClassMethod DriftRole(pResources As %String) As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tName = ..IdentityName()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("Resources") = pResources
        Set tProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(tName, .tProps)
        Set tOk = $$$ISOK(tSC)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tOk
}

/// <p>A fresh install creates the identity pair in exactly the shape the escalation needs, and
/// grants nothing beyond it. This is the executable form of the containment claim
/// <class>OcuPilot.Kernel.State.Base</class> and
/// <method>OcuPilot.Install.Installer.EnsureIdentityApplication</method> both state in prose.</p>
/// <p>Mutation (Rule 19): widen
/// <parameter>OcuPilot.Kernel.State.Base.IDENTITYRESOURCES</parameter> to include
/// <code>%DB_OCUPILOT:RW</code>, or change <code>tWantRoutines</code> in
/// <method>EnsureIdentityApplication</method> to a package wildcard, and recompile
/// <code>OcuPilot.*</code> -> this goes red. Before this class existed both mutations were
/// invisible to the whole suite.</p>
Method TestAFreshInstallCreatesTheIdentityPairInItsDeclaredShape()
{
    Set tCodeDb = ..CodeDatabase()
    Do $$$AssertNotEquals(tCodeDb, "", "the install namespace's routine database resolves, so the expected Routines entry is derived and not assumed")
    If tCodeDb = "" Quit

    Set tExpected = ##class(OcuPilot.Kernel.State.Base).#IDENTITYRESOURCES _ "||1|4|:" _ ..IdentityName() _ "|OcuPilot.Kernel.State.Base:" _ tCodeDb _ ":1"
    Do $$$AssertEquals(..IdentityShape(), tExpected, "the identity role grants exactly IDENTITYRESOURCES and no granted roles, and the application is enabled, of routine type, matches only its own role and admits only OcuPilot.Kernel.State.Base")

    ; The containment half stated as its own assertion, so a future widening that happened to
    ; keep the shape string parseable still names what went wrong.
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Base).#IDENTITYRESOURCES '[ ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "the identity role reaches none of OcuPilot's own data")
}

/// <p>A second run repairs a drifted identity application and reports the repair, exactly as the
/// storage application's does. Without this, a regression in that branch is a silent total
/// lockout that every other gate reports as green.</p>
/// <p>Mutation (Rule 19): invert the <code>tNeedsRepair</code> test in
/// <method>OcuPilot.Install.Installer.EnsureIdentityApplication</method>, or delete its repair
/// arm, and recompile <code>OcuPilot.*</code> -> this goes red.</p>
Method TestASecondRunRepairsADriftedIdentityApplication()
{
    Set tBefore = ..IdentityShape()
    Kill tProps
    Set tProps("Enabled") = 0
    Set tProps("Routines") = "OcuPilot.Kernel.State.*:" _ ..CodeDatabase() _ ":1"
    Do $$$AssertTrue(..DriftApplication(.tProps), "the identity application is manually disabled and widened to a package wildcard")
    Do $$$AssertNotEquals(..IdentityShape(), tBefore, "the drift is real: the live shape differs from the installed one")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install(..#PROFILE)
    Do $$$AssertStatusOK(tSC, "a second install succeeds against the drifted pair")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertEquals(..IdentityShape(), tBefore, "and repaired it back to the installed shape")
    Do $$$AssertTrue(tWarnings [ "identity routine application", "the repair was reported through the logger, not silently applied")
}

/// <p>A second run repairs the probe's storage routine application when only its
/// <code>Type</code> has drifted, and reports the repair. An application of any other type grants
/// no role, so every escalation into OcuPilot's own state would be refused. The instance accepts
/// the drift: <code>Security.Applications.Modify</code> sets <code>Type</code> 5 on a routine
/// application and keeps its <code>MatchRoles</code> and <code>Routines</code>, so only the
/// <code>Type</code> comparison can see it.</p>
/// <p>Mutation (Rule 19): delete the <code>Type</code> comparison from
/// <method>OcuPilot.Install.Installer.EnsureApplication</method> and recompile
/// <code>OcuPilot.*</code> -> this goes red.</p>
Method TestASecondRunRepairsAStorageApplicationWhoseTypeDrifted()
{
    Set tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION _ "Probe"
    Do $$$AssertEquals(..ApplicationType(tName), 4, "the probe's storage application is installed as a privileged routine application")
    Kill tProps
    Set tProps("Type") = 5
    Do $$$AssertTrue(..DriftApplication(.tProps, tName), "its Type is manually drifted")
    Do $$$AssertEquals(..ApplicationType(tName), 5, "the drift is real")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install(..#PROFILE)
    Do $$$AssertStatusOK(tSC, "a second install succeeds against the drifted application")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertEquals(..ApplicationType(tName), 4, "and repaired its Type")
    Do $$$AssertTrue(tWarnings [ "Repaired the privileged routine application", "the repair was reported")
    ; The instance refuses to delete an application of type 5, so a failed repair is undone here
    ; before the uninstall in OnAfterOneTest.
    If ..ApplicationType(tName) '= 4 {
        Kill tBack
        Set tBack("Type") = 4
        Do ..DriftApplication(.tBack, tName)
    }
}

/// <p>The live <code>Type</code> of the application <var>pName</var>, or <code>""</code>.</p>
ClassMethod ApplicationType(pName As %String) As %String
{
    Set tType = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC), ##class(Security.Applications).Exists(pName, .tObj, .tExistSC) {
            If $$$ISOK(##class(Security.Applications).Get(pName, .tProps)) Set tType = +$Get(tProps("Type"))
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tType
}

/// <p>The same for the role: a second run restores a role whose resources were widened or
/// stripped. A role that grants nothing is the fault <code>AddRoles</code> cannot report, because
/// the application is still enabled and the call still succeeds.</p>
/// <p>Mutation (Rule 19): delete the role-repair arm from
/// <method>OcuPilot.Install.Installer.EnsureIdentityApplication</method> and recompile
/// <code>OcuPilot.*</code> -> this goes red.</p>
Method TestASecondRunRepairsADriftedIdentityRole()
{
    Set tBefore = ..IdentityShape()
    Do $$$AssertTrue(..DriftRole("%DB_IRISSYS:R"), "the identity role loses %Admin_Secure")
    Do $$$AssertNotEquals(..IdentityShape(), tBefore, "the drift is real")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install(..#PROFILE)
    Do $$$AssertStatusOK(tSC, "a second install succeeds against the drifted role")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertEquals(..IdentityShape(), tBefore, "and repaired the role's resources back to IDENTITYRESOURCES")
    Do $$$AssertTrue(tWarnings [ "identity role", "the repair was reported")
}

/// <p>The install drift oracle folds the identity pair, so drift on the new escalation moves the
/// fingerprint the way drift on the storage pair already does. An oracle that did not fold it
/// would report a fully locked-out instance as correct.</p>
/// <p>Mutation (Rule 19): remove the four identity components from
/// <method>OcuPilot.Install.Installer.StateFingerprint</method>'s result and recompile
/// <code>OcuPilot.*</code> -> both legs go red.</p>
Method TestTheDriftOracleFoldsTheIdentityPair()
{
    Set tBase = ##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE)
    Do $$$AssertTrue(tBase '[ "ERROR:", "the oracle answers a fingerprint rather than an error")

    Kill tProps
    Set tProps("Enabled") = 0
    Do $$$AssertTrue(..DriftApplication(.tProps), "the identity application is disabled")
    Do $$$AssertNotEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "a disabled identity application moves the fingerprint")

    Kill tProps2
    Set tProps2("Enabled") = 1
    Do $$$AssertTrue(..DriftApplication(.tProps2), "the application is re-enabled")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "and the fingerprint returns, so the movement was that property and not drift elsewhere")

    Do $$$AssertTrue(..DriftRole(""), "the identity role's resources are stripped")
    Do $$$AssertNotEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "a role that grants nothing moves the fingerprint too")
}

/// <p>Uninstall removes both objects. The confirmation message names them, so leaving them behind
/// would be a destructive confirmation that overstated what it destroyed.</p>
/// <p>Mutation (Rule 19): delete the identity deletion block from
/// <method>OcuPilot.Install.Installer.Uninstall</method> and recompile <code>OcuPilot.*</code> ->
/// this goes red.</p>
Method TestUninstallRemovesTheIdentityPair()
{
    Do $$$AssertNotEquals(..IdentityShape(), "ABSENT|ABSENT|ABSENT|ABSENT|ABSENT|ABSENT", "the pair exists before the uninstall, so its absence afterwards is a removal and not a never-created")
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 1)
    Do $$$AssertStatusOK(tSC, "the confirmed uninstall succeeds")
    Do $$$AssertEquals(..IdentityShape(), "ABSENT|ABSENT|ABSENT|ABSENT|ABSENT|ABSENT", "and both the identity role and the identity application are gone")
}

}
