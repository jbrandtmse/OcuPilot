/// <p><class>OcuPilot.Test.InteropItemSeam</class> whose <method>LogFault</method> also keeps the text of each line the port would log, the message, the
/// code and the status text, so a test reads what a refusal of a schedule spec put in the log (Story 24.15). The source control answer and the
/// pair sets are the superclass's. <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropScheduleSeam Extends OcuPilot.Test.InteropItemSeam
{

/// <p>Keep the line and its text instead of logging them.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##super(pMessage, pStatus, pCode)
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set ^||OcuPilotScheduleSeamLog($Increment(^||OcuPilotScheduleSeamLog)) = tText
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotScheduleSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotScheduleSeamLog(tAt)
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotScheduleSeamLog
}

}
