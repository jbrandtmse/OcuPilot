/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass that reads every target through
/// <class>OcuPilot.Test.SuperserverSeamPort</class> and answers the serving port a test names in
/// <code>^||OcuPilotSuperserverServing</code> (<code>""</code> when none), so AD-10's superserver arm judges what
/// a test armed. Every predicate is the shipped set's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Quit "OcuPilot.Test.SuperserverSeamPort"
}

ClassMethod ServingSuperserverPort() As %String
{
    Quit $Get(^||OcuPilotSuperserverServing)
}

}
