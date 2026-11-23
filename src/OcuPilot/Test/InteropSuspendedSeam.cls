/// <p><class>OcuPilot.Test.InteropResendSeam</class> with the vendor calls of Story 24.16's suspended message writes named by a test: the act on each message id
/// <method>FailActOf</method> lists, for one action (<code>resubmit</code>, <code>discard</code> or <code>delete</code>), is answered with a vendor error that carries
/// <parameter>MARKER</parameter> without calling the vendor, and an edit-and-resubmit whose clone was saved is refused by the vendor after the save
/// (<method>RefuseEditAfterSave</method>), and the removal of a deleted body's search table entries can be refused (<method>FailSearchRemovalOf</method>).
/// <method>LogFault</method> keeps the text of every line the port would log and the namespace it was logged in, so a test reads what a refused or failed write put in the log.
/// <method>Disarm</method> clears all of it. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropSuspendedSeam Extends OcuPilot.Test.InteropResendSeam
{

/// <p>The text a probe refusal carries, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2416s";

/// <p>Answer the act <var>pKind</var> on each message id in <var>pIds</var> (comma-separated) with a vendor error, until <method>Disarm</method>.</p>
ClassMethod FailActOf(pKind As %String, pIds As %String)
{
    Set ^||OcuPilotSuspendedFail(pKind) = "," _ pIds _ ","
}

/// <p>Save the edited body, then answer the vendor's resubmit of it with an error, until <method>Disarm</method>, so the body is saved and no header names it.</p>
ClassMethod RefuseEditAfterSave()
{
    Set ^||OcuPilotSuspendedEditRefuse = 1
}

/// <p>Answer the removal of the search table entries of the deleted body <var>pBodyId</var> with a vendor error that carries <parameter>MARKER</parameter>, until
/// <method>Disarm</method>; the body is deleted all the same.</p>
ClassMethod FailSearchRemovalOf(pBodyId As %String)
{
    Set ^||OcuPilotSuspendedSearchFail = pBodyId
}

ClassMethod Disarm()
{
    Do ##super()
    Kill ^||OcuPilotSuspendedFail
    Kill ^||OcuPilotSuspendedEditRefuse
    Kill ^||OcuPilotSuspendedSearchFail
    Kill ^||OcuPilotSuspendedLog
    Kill ^||OcuPilotSuspendedLogAt
}

/// <p>Keep the line and its text, and the namespace it was logged in, and count it as <method>OcuPilot.Test.InteropItemSeam.Logged</method> does.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##super(pMessage, pStatus, pCode)
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotSuspendedLog)
    Set ^||OcuPilotSuspendedLog(tAt) = tText
    Set ^||OcuPilotSuspendedLogAt(tAt) = $NAMESPACE
}

/// <p>The namespaces every line kept since <method>Disarm</method> was logged in, one after another.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotSuspendedLogAt(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotSuspendedLogAt(tAt)
    }
    Quit tText
}

ClassMethod VendorRemoveSearchEntries(pClass As %String, pId As %String) As %Status [ Private ]
{
    If $Get(^||OcuPilotSuspendedSearchFail) = pId Quit $System.Status.Error(5001, ..#MARKER _ " refused the search table removal of " _ pId)
    Quit ##super(pClass, pId)
}

/// <p>Every line kept since <method>Disarm</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotSuspendedLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotSuspendedLog(tAt)
    }
    Quit tText
}

ClassMethod VendorSuspended(pNamespace As %String, pKind As %String, pId As %String, Output pCaught) As %Status [ Private ]
{
    If $Get(^||OcuPilotSuspendedFail(pKind)) [ ("," _ pId _ ",") {
        Set pCaught = ""
        Quit $System.Status.Error(5001, ..#MARKER _ " refused " _ pKind _ " of " _ pId)
    }
    Quit ##super(pNamespace, pKind, pId, .pCaught)
}

ClassMethod VendorResubmitWithBody(pHeaderId As %String, pClone As %RegisteredObject, Output pNewId As %String) As %Status [ Private ]
{
    If $Get(^||OcuPilotSuspendedEditRefuse) {
        Set pNewId = ""
        Set tSC = pClone.%Save()
        If $$$ISERR(tSC) Quit tSC
        Quit $System.Status.Error(5001, ..#MARKER _ " refused the resubmit after the body was saved")
    }
    Quit ##super(pHeaderId, pClone, .pNewId)
}

}
