/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose only addition is the
/// tool registry: <class>OcuPilot.Test.SecretTool.Registry</class>, so the shipped
/// <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method> resolves a tool whose descriptor
/// declares a secret argument and runs its accept arm and its structured-value refusal against that
/// declaration (DW-1278).</p>
/// <p><b>It arms the check; it does not replace it.</b> Every line of the shipped channel check runs
/// -- the resolution, the declared-list read, the membership test and the type guard -- and what
/// changes is which registry answers, which is the same shape
/// <method>OcuPilot.Kernel.Proposal.Mint.PortClass</method> already uses.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SecretConfirmFixture Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Test.SecretTool.Registry"
}

}
