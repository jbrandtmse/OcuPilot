/// <p>Test-only <class>OcuPilot.Install.Installer</class> subclass that arms which namespaces
/// <method>OcuPilot.Install.Installer.NamespaceExists</method> reports, so DW-12's namespace
/// outcomes can be driven on an instance that carries <code>HSCUSTOM</code> -- without creating
/// or removing a namespace.</p>
/// <p><b>The seam is deliberately namespace existence, not
/// <method>OcuPilot.Install.Installer.ResolveNamespace</method>.</b> Overriding the resolver
/// itself would replace the candidate order and the empty answer that DW-12 is about, leaving
/// them untested: every assertion would pass against a resolver that had no failure branch at
/// all. Arming existence instead leaves the production resolver as the code under test.</p>
/// <p>Every entry point reaches the resolver through <code>..</code> dispatch, so an armed
/// instance shape reaches <method>OcuPilot.Install.Installer.GuardInstallNamespace</method> and
/// the three guards that call it without touching the production class. Arming <code>""</code>
/// is the instance that carries neither candidate; arming one candidate other than the current
/// namespace is what distinguishes "installs into the default" from "installs into the
/// namespace it was called from".</p>
/// <p>The armed shape lives in a process-private global, cleared by <method>Reset</method>, so
/// nothing survives the process that armed it. Unarmed, it answers exactly what the production
/// class answers.</p>
Class OcuPilot.Test.NamespaceProbe Extends OcuPilot.Install.Installer
{

/// <p>Forget the armed shape, so <method>NamespaceExists</method> answers the instance again.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotNamespaceProbe
}

/// <p>Arm the instance shape: <var>pNamespaces</var> is the comma-separated list of namespaces
/// that are to be reported as existing, and may be <code>""</code> for none.</p>
ClassMethod Arm(pNamespaces As %String)
{
    Set ^||OcuPilotNamespaceProbe("armed") = 1
    Set ^||OcuPilotNamespaceProbe("namespaces") = pNamespaces
}

ClassMethod NamespaceExists(pName As %String) As %Boolean
{
    If '+$Get(^||OcuPilotNamespaceProbe("armed"), 0) Quit ##super(pName)
    Quit ("," _ $Get(^||OcuPilotNamespaceProbe("namespaces"), "") _ ",") [ ("," _ pName _ ",")
}

}
