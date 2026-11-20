/// <p>Test-only <class>OcuPilot.Api.Confirm</class> subclass that answers a confirm the way
/// <method>OcuPilot.Api.Confirm.HandleConfirm</method> does, with the kernel's confirm replaced by
/// <class>OcuPilot.Test.ConfirmFixture</class>, so a write fault armed on
/// <class>OcuPilot.Test.ProposalFixture</class> reaches the shipped
/// <method>OcuPilot.Api.Confirm.RenderRefusal</method> from a real confirm. <method>DispatchRequest</method>
/// has <class>OcuPilot.Test.Dispatch</class>'s router signature, and its URL is
/// <code>/&lt;proposal id&gt;/confirm</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfirmRenderProbe Extends OcuPilot.Api.Confirm
{

ClassMethod DispatchRequest(pUrl As %String, pMethod As %String) As %Status
{
    Set tConfirmSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm($Piece(pUrl, "/", 2), "", ..CallerUsername(), .tResult, .tHttpStatus, .tCode, .tDetail, .tReason)
    If $$$ISERR(tConfirmSC) Quit ..RenderRefusal(tConfirmSC, tHttpStatus, tCode, tDetail, tReason)
    Quit ##class(OcuPilot.Api.Response).JSON(tResult)
}

}
