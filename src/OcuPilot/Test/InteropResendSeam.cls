/// <p><class>OcuPilot.Test.InteropItemSeam</class> with the two vendor calls of the message resends named by a test (Story 20.31): the
/// resend of the message ids <method>FailResendOf</method> lists is answered with a vendor error without calling the vendor, and an
/// edit-and-resend whose clone was saved is refused by the vendor after the save (<method>RefuseEditAfterSave</method>).
/// <method>Disarm</method> clears both. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropResendSeam Extends OcuPilot.Test.InteropItemSeam
{

/// <p>Answer the resend of each message id in <var>pIds</var> (comma-separated) with a vendor error, until <method>Disarm</method>.</p>
ClassMethod FailResendOf(pIds As %String)
{
    Set ^||OcuPilotResendFail = "," _ pIds _ ","
}

/// <p>Save the edited body, then answer the vendor's resend of it with an error, until <method>Disarm</method>, so the body
/// is saved and no header names it.</p>
ClassMethod RefuseEditAfterSave()
{
    Set ^||OcuPilotResendEditRefuse = 1
}

ClassMethod Disarm()
{
    Do ##super()
    Kill ^||OcuPilotResendFail
    Kill ^||OcuPilotResendEditRefuse
}

ClassMethod VendorResend(pNamespace As %String, pId As %String, Output pNewId As %String, Output pCaught) As %Status [ Private ]
{
    If $Get(^||OcuPilotResendFail) [ ("," _ pId _ ",") {
        Set pNewId = ""
        Set pCaught = ""
        Quit $System.Status.Error(5001, "resend refused for the test: " _ pId)
    }
    Quit ##super(pNamespace, pId, .pNewId, .pCaught)
}

ClassMethod VendorResendWithBody(pHeaderId As %String, pClone As %RegisteredObject, Output pNewId As %String) As %Status [ Private ]
{
    If $Get(^||OcuPilotResendEditRefuse) {
        Set pNewId = ""
        Set tSC = pClone.%Save()
        If $$$ISERR(tSC) Quit tSC
        Quit $System.Status.Error(5001, "resend refused after the body was saved for the test")
    }
    Quit ##super(pHeaderId, pClone, .pNewId)
}

}
