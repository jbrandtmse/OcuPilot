/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.SecretTool.Probe</class> alone, so
/// <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method> resolves a tool whose
/// descriptor really declares a secret argument (DW-1278).</p>
/// <p>Its screen registry points at a package with no descriptor in it, so no read tool is derived
/// beside the one write tool -- the idiom <class>OcuPilot.Test.LedgerTool.Registry</class>
/// established.</p>
Class OcuPilot.Test.SecretTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.SecretTool."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.DispatchTool.Screens"
}

}
