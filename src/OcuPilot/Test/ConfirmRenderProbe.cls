/// <p>Test-only <class>OcuPilot.Api.Confirm</class> subclass whose kernel confirm is
/// <class>OcuPilot.Test.ConfirmFixture</class>, so a write fault armed on
/// <class>OcuPilot.Test.ProposalFixture</class> reaches the shipped
/// <method>OcuPilot.Api.Confirm.HandleConfirm</method> and its refusal renderer from a real confirm.
/// <method>DispatchRequest</method> has <class>OcuPilot.Test.Dispatch</class>'s router signature, and its
/// URL is <code>/&lt;proposal id&gt;/confirm</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfirmRenderProbe Extends OcuPilot.Api.Confirm
{

ClassMethod KernelConfirm(pId As %String, pBody As %DynamicObject, pUser As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String, Output pDetail As %DynamicObject, Output pReason As %String) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Test.ConfirmFixture).Confirm(pId, pBody, pUser, .pResult, .pHttpStatus, .pCode, .pDetail, .pReason)
}

ClassMethod DispatchRequest(pUrl As %String, pMethod As %String) As %Status
{
    Quit ..HandleConfirm($Piece(pUrl, "/", 2))
}

}
