/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass for <class>OcuPilot.Test.InteropEditorSaveConfirm</class>,
/// with two replaced seams and a real port: the privilege check honours the pair
/// <method>OcuPilot.Test.ProposalFixture.DeniedPair</method> names, so a pair revoked after the mint is driven without changing a grant
/// on the instance; and the fingerprint answers a match while <method>MatchFingerprint</method> is armed, so the rule the confirm asks
/// after the digest is reached for a class that changed after the mint (a changed class otherwise closes the row at the digest).</p>
/// <p>Everything else, the port included, is the shipped confirm: a refusal here writes nothing, and a confirm that gets past both
/// seams saves to the instance.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. The arming is process-private.</p>
Class OcuPilot.Test.InteropEditorConfirm Extends OcuPilot.Kernel.Proposal.Confirm
{

/// <p>Answer a fingerprint match for every confirm in this process from now on when <var>pOn</var> is 1, the shipped answer when 0.</p>
ClassMethod MatchFingerprint(pOn As %Boolean = 1)
{
    If pOn Set ^||OcuPilotInteropEditorConfirm("match") = 1
    If 'pOn Kill ^||OcuPilotInteropEditorConfirm
}

/// <p>The shipped check, except for the one pair <method>OcuPilot.Test.ProposalFixture.DeniedPair</method> names.</p>
ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    If ##class(OcuPilot.Test.ProposalFixture).DeniedPair() = (pResource _ ":" _ pPermission) Quit 0
    Quit ##super(pUser, pResource, pPermission)
}

/// <p>The shipped re-read and digest, with the match overridden to 1 while <method>MatchFingerprint</method> is armed. The re-read's
/// endpoint, identifying parameter and id are the shipped ones, which the rule asked after the digest takes.</p>
ClassMethod FingerprintMatches(pTool As %DynamicObject, ByRef pRow, Output pMatches As %Boolean, Output pEndpoint As %String, Output pIdParam As %String, Output pIdValue As %String, Output pFresh As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##super(pTool, .pRow, .pMatches, .pEndpoint, .pIdParam, .pIdValue, .pFresh)
    If $$$ISERR(tSC) Quit tSC
    If $Get(^||OcuPilotInteropEditorConfirm("match")) Set pMatches = 1
    Quit tSC
}

}
