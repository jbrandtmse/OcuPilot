/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, the message, the code and the status text, and the namespace it was
/// written in, so a test reads what a refused or failed managed alert update put in the log (Story 24.17 Batch 1); whose <method>VendorAlertUpdate</method> answers what
/// <code>^IRIS.Temp.OcuProbe2417Mode</code> says: <code>status</code> to answer an error status that carries a marker text, <code>fault</code> to raise an error, anything else the vendor's own
/// call; and whose <method>AlertHere</method> raises when the mode is <code>here</code>. The namespace and the changes of the last vendor call are kept under the global's <code>ranIn</code> and
/// <code>bits</code> subscripts. <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropAlertSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault, a probe status and a probe reason carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2417Alert";

/// <p>Keep the line, its text and the namespace the call was made in.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotAlertSeamLog)
    Set ^||OcuPilotAlertSeamLog(tAt) = tText
    Set ^||OcuPilotAlertSeamLog(tAt, "ns") = $NAMESPACE
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotAlertSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotAlertSeamLog(tAt)
    }
    Quit tText
}

/// <p>The namespaces the kept lines were written in, comma-separated, one for each line.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotAlertSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotAlertSeamLog(tAt, "ns")
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotAlertSeamLog
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417Mode</code>.</p>
ClassMethod VendorAlertUpdate(pId As %String, pBits As %Integer, ByRef pChanges, pReason As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417Mode)
    Set ^IRIS.Temp.OcuProbe2417Mode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417Mode("bits") = pBits
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered")
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised"))
    Quit ##super(pId, pBits, .pChanges, pReason)
}

/// <p>Raise inside each namespace-switched block when the mode is <code>here</code>.</p>
ClassMethod AlertHere() [ Private ]
{
    If $Get(^IRIS.Temp.OcuProbe2417Mode) = "here" {
        Set ^IRIS.Temp.OcuProbe2417Mode("hereIn") = $NAMESPACE
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised in the alert's namespace"))
    }
}

}
