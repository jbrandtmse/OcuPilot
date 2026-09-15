/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> that forces
/// <method>EnsureGrant</method> to fail unconditionally, so
/// <class>OcuPilot.Test.Installer</class> can pin AC12's requirement that
/// <code>$NAMESPACE</code> is restored to the caller's namespace even when an ensure
/// step fails with an ordinary <code>%Status</code> error deep inside the
/// <code>%SYS</code>-switched window -- not only when a thrown exception reaches
/// <method>OcuPilot.Install.Installer.Install</method>'s <code>Catch</code> block.
/// <code>EnsureGrant</code> is deliberately the <b>last</b> ensure step
/// <method>OcuPilot.Install.Installer.Install</method> calls, so every earlier step
/// (database, both resources, role, application, mapping, audit event, auditing) has
/// already run for real against the <code>"probe"</code> profile by the time this
/// fires -- <code>Uninstall("probe", 1)</code> in
/// <class>OcuPilot.Test.Installer</class>'s <method>OnAfterOneTest</method> still cleans
/// up everything this induces.</p>
Class OcuPilot.Test.InstallerFault Extends OcuPilot.Install.Installer
{

/// <p>Always fails without touching <var>pReports</var> or granting anything.</p>
ClassMethod EnsureGrant(ByRef pNames, Output pOutcome As %String, Output pGrantedUser As %String, Output pCommand As %String, pUsername As %String = {$Username}, ByRef pReports) As %Status
{
    Set pOutcome = ""
    Set pGrantedUser = ""
    Set pCommand = ""
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallerFault: induced failure inside the %SYS-switched window")
}

}
