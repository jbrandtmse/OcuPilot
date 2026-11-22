/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, the message, the code and the status
/// text, so a test reads what a refused or failed purge put in the log (Story 24.16), and whose <method>VendorPurge</method> answers what
/// <code>^IRIS.Temp.OcuProbe2416Mode</code> says: <code>fault</code> to raise an error, <code>roles</code> to raise one after the process has added a role to its own, <code>after</code> to
/// raise one after the vendor's own call has run, <code>status</code> to answer an error status that carries a marker text, anything else the vendor's own call. The days it
/// was given are kept under the global's <code>days</code> subscript. <method>ClearLog</method> forgets the lines. In <code>roles</code> mode the process adds a role before
/// the error, which the port's frame must take back.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropPurgeSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2416";

/// <p>Keep the line and its text.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set ^||OcuPilotPurgeSeamLog($Increment(^||OcuPilotPurgeSeamLog)) = tText
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotPurgeSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotPurgeSeamLog(tAt)
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotPurgeSeamLog
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2416Mode</code>; the roles the process held before and inside the call are kept under the global's
/// <code>before</code> and <code>inside</code> subscripts.</p>
ClassMethod VendorPurge(pDays As %Integer, pKeepIntegrity As %Boolean, pBodiesToo As %Boolean, pBitmap As %Boolean, Output pDeleted) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2416Mode)
    Set ^IRIS.Temp.OcuProbe2416Mode("before") = $ROLES
    Set ^IRIS.Temp.OcuProbe2416Mode("days") = pDays
    If tMode = "after" {
        Set tSC = ##super(pDays, pKeepIntegrity, pBodiesToo, pBitmap, .pDeleted)
        Set ^IRIS.Temp.OcuProbe2416Mode("inside") = $ROLES
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised after the vendor's purge"))
    }
    If (tMode = "fault") || (tMode = "roles") {
        If tMode = "roles" {
            Try {
                Set $ROLES = "%DB_USER"
            } Catch {
            }
        }
        Set ^IRIS.Temp.OcuProbe2416Mode("inside") = $ROLES
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised"))
    }
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered")
    Quit ##super(pDays, pKeepIntegrity, pBodiesToo, pBitmap, .pDeleted)
}

}
