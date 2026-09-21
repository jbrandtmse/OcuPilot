/// <p>Fixture: a write tool whose descriptor is <class>OcuPilot.Test.ProposalScreen</class>, which
/// declares one secret argument -- so AD-6's closed confirm channel can be driven against a
/// <b>real</b> declaration rather than a name list a test supplies (DW-1278).</p>
/// <p>It exists because no shipped descriptor declares a secret argument: the auditing write this
/// story ships has one boolean field and no secret, and the first shipped one arrives with FR-43's
/// X.509 and FR-46's wallet editors. Until then the accept arm of
/// <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method> and its structured-value
/// refusal have nothing on the instance to run against.</p>
/// <p><b>Nothing registers it in production.</b>
/// <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter> is
/// <code>OcuPilot.Test.</code>, so the shipped registry never lists it;
/// <class>OcuPilot.Test.SecretTool.Registry</class> is the only registry that does.</p>
Class OcuPilot.Test.SecretTool.Probe Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "probe.secret.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Test.ProposalScreen";

Parameter DESCRIPTION = "Fixture: a write tool whose screen declares one secret argument.";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

/// <p>The one field this fixture's merge may set, authored rather than derived: the probe screen's
/// <code>toolIdentifier</code> owns no <class>OcuPilot.Screen.Tool.ToolFields</class> entry, which
/// is the fail-closed case and would leave the list empty.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("Description")
}

}
