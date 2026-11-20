/// <p>Test-only <class>OcuPilot.Api.Confirm</class> subclass whose kernel confirm is
/// <class>OcuPilot.Test.ConfirmFixture</class>, so a write fault armed on
/// <class>OcuPilot.Test.ProposalFixture</class> reaches the shipped
/// <method>OcuPilot.Api.Confirm.HandleConfirm</method> and its refusal renderer from a real confirm.
/// <method>DispatchRequest</method> has <class>OcuPilot.Test.Dispatch</class>'s router signature, and its
/// URL is <code>/&lt;proposal id&gt;/confirm</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfirmRenderProbe Extends OcuPilot.Api.Confirm
{

ClassMethod KernelConfirmClass() As %String [ Private ]
{
    Quit "OcuPilot.Test.ConfirmFixture"
}

ClassMethod DispatchRequest(pUrl As %String, pMethod As %String) As %Status
{
    Quit ..HandleConfirm($Piece(pUrl, "/", 2))
}

}
