/// <p>Test-only seam for <class>OcuPilot.Test.UserCopyRefusals</class>: <class>OcuPilot.Port.UserCopyPort</class> whose
/// vendor call answers the error code the test set with <method>SetCode</method>, so the port's mapping of a vendor
/// refusal is reached through its public <method>OcuPilot.Port.UserCopyPort.Invoke</method> for the codes a real call
/// cannot be made to raise (#838, #845, #958 and an unlisted one), and a source read that fails without being an
/// absence. Production never calls this class.</p>
Class OcuPilot.Test.UserCopyVendorFault Extends OcuPilot.Port.UserCopyPort
{

/// <p>What the answered status's text carries, followed by the code, so a test can tell whether the vendor's text
/// reached a response or the log.</p>
Parameter TEXTMARKER = "OcuRf1829VendorText";

/// <p>Make the next vendor calls of this process answer error <var>pCode</var>; with <var>pQuote</var> 1 its text
/// also quotes the password the copy was given, as a vendor refusal that quotes a value it was sent would.</p>
ClassMethod SetCode(pCode As %Integer, pQuote As %Boolean = 0)
{
    Set ^||OcuProbe1829VendorCode = pCode
    Set ^||OcuProbe1829VendorQuote = pQuote
}

/// <p>Make the next source reads of this process fail as a read that is not an absence (a 500 with no fault).</p>
ClassMethod SetSourceFault()
{
    Set ^||OcuProbe1829SourceFault = 1
}

/// <p>Stop answering an error: the next vendor call answers OK and the source is read as the instance holds it.</p>
ClassMethod ClearCode()
{
    Kill ^||OcuProbe1829VendorCode
    Kill ^||OcuProbe1829VendorQuote
    Kill ^||OcuProbe1829SourceFault
}

/// <p>Answer the error the test named, with text carrying <parameter>TEXTMARKER</parameter> and the code. When no code
/// is set the call answers OK, as a vendor that copied.</p>
ClassMethod VendorCopy(pFrom As %String, pName As %String, pFullName As %String, pPassword As %String) As %Status [ Private ]
{
    Set tCode = $Get(^||OcuProbe1829VendorCode)
    If tCode = "" Quit $$$OK
    Quit $System.Status.Error(tCode, ..#TEXTMARKER _ tCode _ $Select(+$Get(^||OcuProbe1829VendorQuote): " " _ pPassword, 1: ""))
}

/// <p>The source read, or, after <method>SetSourceFault</method>, a read that fails with 500 and no fault.</p>
ClassMethod SourceOf(pFrom As %String, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pSC As %Status) As %DynamicObject
{
    If +$Get(^||OcuProbe1829SourceFault) {
        Set pHttp = 500
        Set pFault = ""
        Set pSC = $System.Status.Error(5001, ..#TEXTMARKER _ "source")
        Quit ""
    }
    Quit ##super(pFrom, .pHttp, .pFault, .pSC)
}

}
