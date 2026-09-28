/// <p>Test-only screen action route whose port and prohibited set both answer
/// <class>OcuPilot.Test.ProposalFixture</class>'s armed rows: <class>OcuPilot.Test.SslActionFixture</class>
/// with <method>ProhibitedClassName</method> replaced by <class>OcuPilot.Test.ProhibitedFixture</class>,
/// whose predicates are the shipped ones. A web session under one of OcuPilot's own applications
/// cannot be made on an instance, so the route's refusal of one is driven over a composed row.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WebSessionActionFixture Extends OcuPilot.Test.SslActionFixture
{

ClassMethod ProhibitedClassName() As %String
{
    Quit "OcuPilot.Test.ProhibitedFixture"
}

}
