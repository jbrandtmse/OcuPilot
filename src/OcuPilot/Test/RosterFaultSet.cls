/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam:
/// <method>ServesOcuPilot</method> fails as a roster or install record that cannot be read does, so a
/// predicate's fail-closed branch for that fault can be driven. Every predicate is the shipped
/// code.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RosterFaultSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod ServesOcuPilot(pPath As %String, Output pServes As %Boolean) As %Status [ Private ]
{
    Set pServes = 0
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RosterFaultSet: the install roster cannot be read")
}

}
