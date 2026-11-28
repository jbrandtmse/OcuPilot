/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, the message, the code and the status text, and the
/// namespace it was written in, so a test reads what a refused or failed archive run put in the log (Story 24.16 Batch 4); whose <method>VendorArchive</method> answers what
/// <code>^IRIS.Temp.OcuProbe2416ArcMode</code> says: <code>status</code> to answer an error status that carries a marker text, <code>fault</code> to raise an error, <code>lock</code> to
/// take one more hold on the vendor's lock and raise, as a run cut short before the vendor's own release would, anything else the vendor's own call; and whose
/// <method>ArchiveTargetHere</method> raises when the mode is <code>target</code>. The namespace each vendor call ran in is kept under the global's <code>ranIn</code> subscript,
/// and whether this process held that namespace's archive lock at the call under <code>heldHere</code>.
/// <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropArchiveSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2416Arc";

/// <p>Keep the line, its text and the namespace the call was made in.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotArchiveSeamLog)
    Set ^||OcuPilotArchiveSeamLog(tAt) = tText
    Set ^||OcuPilotArchiveSeamLog(tAt, "ns") = $NAMESPACE
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotArchiveSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotArchiveSeamLog(tAt)
    }
    Quit tText
}

/// <p>The namespaces the kept lines were written in, comma-separated, one for each line.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotArchiveSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotArchiveSeamLog(tAt, "ns")
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotArchiveSeamLog
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2416ArcMode</code>.</p>
ClassMethod VendorArchive() As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2416ArcMode)
    Set ^IRIS.Temp.OcuProbe2416ArcMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2416ArcMode("heldHere") = ($Get(^$LOCK($Name(^Ens.ArchiveManager("lock")), "OWNER")) = $Job)
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered")
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised"))
    If tMode = "lock" {
        Lock +^Ens.ArchiveManager("lock"):0
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised holding the lock"))
    }
    Quit ##super()
}

/// <p>Raise inside the target-switched read when the mode is <code>target</code>.</p>
ClassMethod ArchiveTargetHere() [ Private ]
{
    If $Get(^IRIS.Temp.OcuProbe2416ArcMode) = "target" {
        Set ^IRIS.Temp.OcuProbe2416ArcMode("targetIn") = $NAMESPACE
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised in the target"))
    }
}

}
