/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Mint</class> subclass whose one replaced seam is the
/// port: a fresh read answers <class>OcuPilot.Test.ProposalFixture</class>'s armed object instead of
/// the instance. Everything else -- the merge, the diff, the fingerprint, the store -- is the
/// shipped code.</p>
/// <p>It exists so the merge can be driven against a property set no live endpoint happens to
/// carry, which is what makes "the payload's property names are the fresh read's" a falsifiable
/// claim rather than a coincidence of one endpoint.</p>
Class OcuPilot.Test.ProposalMint Extends OcuPilot.Kernel.Proposal.Mint
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
