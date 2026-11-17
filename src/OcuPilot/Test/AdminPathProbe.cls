/// <p>The child process <class>OcuPilot.Test.AdminPathWrite</class> starts to run the installer's
/// grant and target-key steps as a <b>real principal</b>, in one process, in the order
/// <method>OcuPilot.Install.Installer.Install</method> runs them. It adds those steps to
/// <class>OcuPilot.Test.OwnerStateWriteProbe</class>; any step it does not name is the parent's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AdminPathProbe Extends OcuPilot.Test.OwnerStateWriteProbe
{

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..PathKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds. <code>Install.EnsureGrant</code> makes the grant
/// <method>OcuPilot.Install.Installer.EnsureGrant</method> makes, <code>Security.Users.AddRoles</code>
/// of the administrative role to the process's own user in <code>%SYS</code> (the installer's method
/// cannot be dispatched from <code>%SYS</code> by a caller outside its own frame); <code>Install.EnsureProposalTargetKeys</code> runs that
/// install step in the install namespace; <code>Roles.AddAdministrator</code> adds the administrative role
/// to the process's own <code>$ROLES</code>, which IRIS admits only to a process that can write the system
/// database. Each answers <code>roles</code> and <code>holdsAdmin</code> as the process reads them after
/// the step. <code>Install.ProbeInstall</code> and <code>Install.ProbeUninstall</code> run
/// <method>OcuPilot.Install.Installer.Install</method> and <method>OcuPilot.Install.Installer.Uninstall</method>
/// (confirmed) for the probe profile, as the principal.</p>
ClassMethod PathKinds() As %List
{
    Quit $ListBuild("Install.EnsureGrant", "Install.EnsureProposalTargetKeys", "Roles.AddAdministrator", "Install.ProbeInstall", "Install.ProbeUninstall")
}

/// <p>Run one step of the plan, answered as <code>{kind, ok, code, text, roles, holdsAdmin}</code>
/// plus what the kind adds.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..PathKinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tBase = "OcuPilot.Kernel.State.Base"
        If tKind = "Install.EnsureGrant" {
            Set tRoles = $Parameter(tBase, "ADMINRESOURCE")
            Set $NAMESPACE = "%SYS"
            Set tSC = ##class(Security.Users).AddRoles($Username, .tRoles)
            Set $NAMESPACE = tOrigNS
        } ElseIf tKind = "Roles.AddAdministrator" {
            Set $ROLES = $ROLES _ "," _ $Parameter("OcuPilot.Kernel.State.Base", "ADMINRESOURCE")
        } ElseIf tKind = "Install.EnsureProposalTargetKeys" {
            Set tSC = ##class(OcuPilot.Install.Installer).EnsureProposalTargetKeys(.tReports)
            Do tLeg.%Set("report", $Get(tReports(1, "message")), "string")
        } ElseIf tKind = "Install.ProbeInstall" {
            Set tSC = ##class(OcuPilot.Install.Installer).Install("probe")
        } ElseIf tKind = "Install.ProbeUninstall" {
            Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do tLeg.%Set("kind", tKind, "string")
    Do tLeg.%Set("ok", ''$$$ISOK(tSC), "boolean")
    Do tLeg.%Set("code", $Select($$$ISOK(tSC): "", 1: $Piece($System.Status.GetErrorCodes(tSC), ",", 1)), "string")
    Do tLeg.%Set("text", $Select($$$ISOK(tSC): "", 1: $System.Status.GetErrorText(tSC)), "string")
    Do tLeg.%Set("roles", $Roles, "string")
    Do tLeg.%Set("holdsAdmin", ''$System.Security.Check($Parameter("OcuPilot.Kernel.State.Base", "ADMINRESOURCE"), "USE"), "boolean")
    Quit tLeg
}

}
