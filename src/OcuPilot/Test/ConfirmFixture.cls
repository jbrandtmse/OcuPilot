/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass with three replaced seams:
/// the port answers <class>OcuPilot.Test.ProposalFixture</class>'s armed objects and records what a
/// write was sent, and the privilege check honours that fixture's refused pair.</p>
/// <p>Everything else -- the turn barrier, the closed channel, the claim, the gate order, the
/// fingerprint re-read and the secret merge -- is the shipped code.</p>
/// <p><b>Nothing this class reaches writes to the instance.</b> The confirmed write goes to the
/// fixture, which is what lets the suite drive a real confirmed write without pointing one at a web
/// application.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfirmFixture Extends OcuPilot.Kernel.Proposal.Confirm
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

/// <p>The shipped check, except for the one pair
/// <method>OcuPilot.Test.ProposalFixture.DeniedPair</method> names -- so AD-8's re-check at the
/// write is driven without revoking a grant on the instance.</p>
ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    If ##class(OcuPilot.Test.ProposalFixture).DeniedPair() = (pResource _ ":" _ pPermission) Quit 0
    Quit ##super(pUser, pResource, pPermission)
}

/// <p>The shipped seam, except for the class
/// <method>OcuPilot.Test.ProposalFixture.ProhibitedClass</method> names -- so AD-10's refusal branch
/// is driven against an armed target rather than the instance's own. <code>""</code> falls through
/// to the shipped set.</p>
ClassMethod ProhibitedClassName() As %String
{
    Set tArmed = ##class(OcuPilot.Test.ProposalFixture).ProhibitedClass()
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

/// <p><method>OcuPilot.Kernel.Proposal.Confirm.WithSecrets</method> as a test can reach it: the
/// shipped merge, called with <var>pNames</var> standing for a descriptor's declared secret-typed
/// keys. Nothing but a test calls this.</p>
ClassMethod MergeSecrets(pPayloadJson As %String, pBody As %DynamicObject, pNames As %List) As %DynamicObject
{
    Quit ..WithSecrets(pPayloadJson, pBody, pNames)
}

/// <p><method>OcuPilot.Kernel.Proposal.Confirm.Answer</method> as a test can reach it, so the
/// read-back's own refusal can be driven with an id no row carries -- the state a row deleted
/// between the transition and the read-back leaves behind. Nothing but a test calls this.</p>
ClassMethod AnswerFor(pProposalId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String) As %Status
{
    Quit ..Answer(pProposalId, .pResult, .pHttpStatus, .pCode)
}

}
