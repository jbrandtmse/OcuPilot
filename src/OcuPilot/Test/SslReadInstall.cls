/// <p>What creates, repairs and removes the <b>TLS read</b> privileged routine application and its role -- the third
/// escalation AD-9 names, the one the provider's call-time TLS verification read enters -- and what detects drift on it.
/// An application that is absent, disabled or pointed at the wrong routine, or a role that no longer carries
/// <parameter>OcuPilot.Kernel.State.Base.SSLREADRESOURCES</parameter>, refuses every provider call for every caller, so
/// nothing but this class reads the pair back.</p>
/// <p>It pins the containment the class headers state: the role grants the two resources the read needs and nothing else,
/// and the application admits one class.</p>
/// <p>The helpers are <class>OcuPilot.Test.IdentityInstall</class>'s, called with the TLS read pair's name.
/// <b>It runs OcuPilot's production install and the disposable <code>"probe"</code> profile's, so it runs on a throwaway
/// container only</b>, and <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it. Every object it reads, drifts and repairs is the probe profile's.</p>
Class OcuPilot.Test.SslReadInstall Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class: the one <class>OcuPilot.Test.IdentityInstall</class> uses, for the same
/// reason.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The disposable profile every object below belongs to.</p>
Parameter PROFILE = "probe";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslReadInstall runs OcuPilot's PRODUCTION install and the probe profile's on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Production first, then the probe, as <class>OcuPilot.Test.IdentityInstall</class> does.</p>
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

/// <p>The probe profile's TLS read application and role name, as <method>OcuPilot.Install.Installer.Names</method> builds
/// it.</p>
ClassMethod SslReadName() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#SSLREADAPPLICATION _ "Probe"
}

/// <p>A fresh install creates the pair in exactly the shape the read needs and grants nothing beyond it.</p>
/// <p>Mutation (Rule 19): widen <parameter>OcuPilot.Kernel.State.Base.SSLREADRESOURCES</parameter> to include
/// <code>%DB_OCUPILOT:RW</code>, or change <code>tWantRoutines</code> in
/// <method>OcuPilot.Install.Installer.EnsureReadApplication</method> to a package wildcard, and recompile
/// <code>OcuPilot.*</code> -> this goes red.</p>
Method TestAFreshInstallCreatesTheTlsReadPairInItsDeclaredShape()
{
    Set tCodeDb = ##class(OcuPilot.Test.IdentityInstall).CodeDatabase()
    Do $$$AssertNotEquals(tCodeDb, "", "the install namespace's routine database resolves, so the expected Routines entry is derived and not assumed")
    If tCodeDb = "" Quit
    Set tExpected = ##class(OcuPilot.Kernel.State.Base).#SSLREADRESOURCES _ "||1|4|:" _ ..SslReadName() _ "|OcuPilot.Kernel.State.Base:" _ tCodeDb _ ":1"
    Do $$$AssertEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(..SslReadName()), tExpected, "the role grants exactly SSLREADRESOURCES and no granted roles, and the application is enabled, of routine type, matches only its own role and admits only OcuPilot.Kernel.State.Base")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Base).#SSLREADRESOURCES '[ ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "the TLS read role reaches none of OcuPilot's own data")
}

/// <p>A second run repairs a drifted application and a drifted role in one pass, and reports each repair.</p>
/// <p>Mutation (Rule 19): invert the <code>tNeedsRepair</code> test in
/// <method>OcuPilot.Install.Installer.EnsureReadApplication</method>, or delete the role-repair arm, and recompile
/// <code>OcuPilot.*</code> -> this goes red.</p>
Method TestASecondRunRepairsADriftedApplicationAndRole()
{
    Set tName = ..SslReadName()
    Set tBefore = ##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName)
    Set tProps("Enabled") = 0
    Set tProps("Routines") = "OcuPilot.Kernel.State.*:" _ ##class(OcuPilot.Test.IdentityInstall).CodeDatabase() _ ":1"
    Do $$$AssertTrue(##class(OcuPilot.Test.IdentityInstall).DriftApplication(.tProps, tName), "the application is disabled and widened to a package wildcard")
    Do $$$AssertTrue(##class(OcuPilot.Test.IdentityInstall).DriftRole("%DB_IRISSYS:R", tName), "and the role loses %Admin_Secure")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName), tBefore, "the drift is real")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).Install(..#PROFILE), "a second install succeeds against the drifted pair")
    Set tWarnings = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName), tBefore, "and repaired both back to the installed shape")
    Do $$$AssertTrue(tWarnings [ "Repaired the TLS verification routine application", "the application's repair was reported through the logger")
    Do $$$AssertTrue(tWarnings [ "Repaired the TLS verification role", "and so was the role's")
}

/// <p>The install drift oracle folds the pair, so drift on it moves the fingerprint.</p>
/// <p>Mutation (Rule 19): remove the four TLS read components from
/// <method>OcuPilot.Install.Installer.StateFingerprint</method>'s result and recompile <code>OcuPilot.*</code> -> both
/// legs go red.</p>
Method TestTheDriftOracleFoldsTheTlsReadPair()
{
    Set tName = ..SslReadName()
    Set tBase = ##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE)
    Do $$$AssertTrue(tBase '[ "ERROR:", "the oracle answers a fingerprint rather than an error")
    Set tProps("Enabled") = 0
    Do $$$AssertTrue(##class(OcuPilot.Test.IdentityInstall).DriftApplication(.tProps, tName), "the TLS read application is disabled")
    Do $$$AssertNotEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "a disabled application moves the fingerprint")
    Set tProps2("Enabled") = 1
    Do $$$AssertTrue(##class(OcuPilot.Test.IdentityInstall).DriftApplication(.tProps2, tName), "the application is re-enabled")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "and the fingerprint returns, so the movement was that property")
    Do $$$AssertTrue(##class(OcuPilot.Test.IdentityInstall).DriftRole("", tName), "the role's resources are stripped")
    Do $$$AssertNotEquals(##class(OcuPilot.Install.Installer).StateFingerprint(..#PROFILE), tBase, "a role that grants nothing moves the fingerprint too")
}

/// <p>Uninstall removes both objects, and the refusal an unconfirmed one gives names the role and the application.</p>
/// <p>Mutation (Rule 19): delete the TLS read deletion block from <method>OcuPilot.Install.Installer.Uninstall</method>
/// and recompile <code>OcuPilot.*</code> -> this goes red; drop the role's name from the "would destroy" message there
/// -> the naming leg goes red.</p>
Method TestUninstallRemovesTheTlsReadPair()
{
    Set tName = ..SslReadName()
    Set tAbsent = "ABSENT|ABSENT|ABSENT|ABSENT|ABSENT|ABSENT"
    Do $$$AssertNotEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName), tAbsent, "the pair exists before the uninstall")
    Set tRefused = ##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 0)
    Do $$$AssertStatusNotOK(tRefused, "an unconfirmed uninstall is refused")
    Do $$$AssertEquals($Length($System.Status.GetErrorText(tRefused), "'" _ tName _ "'") - 1, 2, "and its message names the TLS read role and the application")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName), tAbsent, "which the refusal left in place")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 1), "the confirmed uninstall succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.IdentityInstall).IdentityShape(tName), tAbsent, "and both the role and the application are gone")
}

}
