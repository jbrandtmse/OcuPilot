/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass whose one replaced seam is
/// <method>CopySourceCap</method>: 1, so a copy source holding two mappings of a kind reads as a list
/// cut at its cap, which the copy-into-own predicate refuses (Story 18.14).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingProhibitedFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod CopySourceCap() As %String
{
    Quit "1"
}

}
