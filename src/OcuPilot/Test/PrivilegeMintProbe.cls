/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Mint</class> subclass whose one replaced seam is the
/// store: <method>StoreClass</method> names this class, whose <property>RequiredPairs</property> is
/// eight characters wide, so any real tool's pair set is longer than the column
/// <method>OcuPilot.Kernel.Proposal.Mint.RecordedPairs</method> reads.
/// <class>OcuPilot.Test.ProposalPrivilege</class> drives the over-long branch with it.</p>
Class OcuPilot.Test.PrivilegeMintProbe Extends OcuPilot.Kernel.Proposal.Mint
{

Property RequiredPairs As %String(MAXLEN = 8);

ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Test.PrivilegeMintProbe"
}

}
