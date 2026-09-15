/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> that makes
/// <method>EnsureGrant</method> <b>throw</b>, rather than return a bad
/// <code>%Status</code> as <class>OcuPilot.Test.InstallerFault</class> does. The two
/// together are what make AC12 falsifiable across both of its error paths, which are
/// genuinely different code:</p>
/// <ul>
/// <li><class>OcuPilot.Test.InstallerFault</class> drives the inline
/// <code>If $$$ISERR(tSC) { Set $NAMESPACE = tOrigNS  Quit }</code> guards -- an
/// argumentless <code>Quit</code> inside a <code>Try</code> never enters the
/// <code>Catch</code>, which is the HIGH-severity defect this story's review pass found
/// and fixed.</li>
/// <li>This class drives <method>OcuPilot.Install.Installer.Install</method>'s
/// <code>Catch</code> block itself, whose restore-as-the-first-line ordering AD-16 and
/// AC12 require and which no test in the tree exercised: every ensure step converts its
/// own exceptions to a <code>%Status</code>, so nothing else in the suite can reach it.
/// The falsifying mutation is to delete <code>Set $NAMESPACE = tOrigNS</code> from that
/// <code>Catch</code> -- <code>$NAMESPACE</code> then returns stuck at <code>%SYS</code>
/// and the following <method>FlushReports</method> call cascades with
/// <code>&lt;CLASS DOES NOT EXIST&gt;OcuPilot.Kernel.Audit.Log</code>, exactly the
/// failure shape <file>.claude/rules/objectscript-debugging.md</file> describes.</li>
/// </ul>
/// <p><code>EnsureGrant</code> is deliberately the <b>last</b> ensure step, so every
/// earlier step has already run for real against the <code>"probe"</code> profile by the
/// time this fires, and <code>Uninstall("probe", 1)</code> in
/// <class>OcuPilot.Test.Installer</class>'s <method>OnAfterOneTest</method> still cleans
/// up everything it induced.</p>
Class OcuPilot.Test.InstallerThrow Extends OcuPilot.Install.Installer
{

/// <p>Always throws, without touching <var>pReports</var> or granting anything.</p>
ClassMethod EnsureGrant(ByRef pNames, Output pOutcome As %String, Output pGrantedUser As %String, Output pCommand As %String, pUsername As %String = {$Username}, ByRef pReports) As %Status
{
    Set pOutcome = ""
    Set pGrantedUser = ""
    Set pCommand = ""
    Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot.Test.InstallerThrow: induced test exception inside the %SYS-switched window"))
}

}
