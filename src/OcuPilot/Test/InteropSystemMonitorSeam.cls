/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, with the namespace it was written in, so a test reads what a failed
/// read put in the log (Story 24.17 Batch 5); whose <method>VendorMetrics</method> answers what <code>^IRIS.Temp.OcuProbe2417SmMode</code> says: <code>values</code> for fixed meters and tables (the
/// tables with padding rows), <code>status</code> for an error status that carries a marker text, <code>fault</code> to switch to <code>%SYS</code> and raise, <code>roles</code> to change the
/// process's roles and answer success, <code>rolesfault</code> to change them and then raise, anything else the vendor's own call. Each call adds one to the mode's
/// <code>calls</code> subscript, and the namespace and roles before the call are kept under <code>ranIn</code> and <code>before</code>. <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropSystemMonitorSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2417Sm";

/// <p>Keep the line, its text and the namespace the call was made in.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotSmSeamLog)
    Set ^||OcuPilotSmSeamLog(tAt) = tText
    Set ^||OcuPilotSmSeamLog(tAt, "ns") = $NAMESPACE
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotSmSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotSmSeamLog(tAt)
    }
    Quit tText
}

/// <p>The namespaces the kept lines were written in, comma-separated, one for each line.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotSmSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotSmSeamLog(tAt, "ns")
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotSmSeamLog
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417SmMode</code>.</p>
ClassMethod VendorMetrics(Output pValues) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417SmMode)
    Set ^IRIS.Temp.OcuProbe2417SmMode("calls") = $Get(^IRIS.Temp.OcuProbe2417SmMode("calls")) + 1
    Set ^IRIS.Temp.OcuProbe2417SmMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417SmMode("before") = $ROLES
    If tMode = "values" {
        Set pValues("EnsNamespace") = "Seam Namespaces"
        Set pValues("EnsProductionsRunning") = "7"
        Set pValues("UpTime") = "1d  2h 03m"
        Set pValues("EnsBusyProcesses") = ";[System];1879;1,200^USER;OcuItem;42;9^USER;OcuItemTwo;43;8^USER;OcuItemThree;44;7^;;;^;;;"
        Set pValues("EnsBusyQueues") = "USER;Queue.A;5^HSCUSTOM;Queue.B;4^USER;Queue.C;3^USER;Queue.D;2^^;;"
        Set pValues("UpcomingTasks") = "Task one;13:01;Scheduled^Task two;13:05;Suspended^^Task three;13:10;Scheduled^Task four;13:15;Scheduled"
        Quit $$$OK
    }
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered")
    If tMode = "fault" {
        Set $NAMESPACE = "%SYS"
        Set ^IRIS.Temp.OcuProbe2417SmMode("hereIn") = $NAMESPACE
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised in %SYS"))
    }
    If (tMode = "roles") || (tMode = "rolesfault") {
        Try {
            Set $ROLES = "%DB_USER"
        } Catch {
        }
        Set ^IRIS.Temp.OcuProbe2417SmMode("inside") = $ROLES
        If tMode = "rolesfault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised"))
        Set pValues("EnsProductionsRunning") = "1"
        Quit $$$OK
    }
    Quit ##super(.pValues)
}

}
