/// <p><class>OcuPilot.Port.HarvestPort</class> replaced for <class>OcuPilot.Test.BackupRead</class>: <method>Invoke</method> records
/// the body JSON it is handed, runs nothing, and answers one entry for a history request and one success for a run, so a test sees
/// exactly which requests <class>OcuPilot.Port.BackupPort</class> sends the harvested body and no backup starts.
/// <b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackupHarvestRecorder Extends OcuPilot.Port.HarvestPort
{

/// <p>Forget the recorded requests.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotBackupHarvest
}

/// <p>The recorded body JSON texts, joined by <code>|</code>.</p>
ClassMethod Requests() As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(^||OcuPilotBackupHarvest(tKey), 1, tText)
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tText
    }
    Quit tOut
}

ClassMethod Invoke(pHandler As %String, pMethod As %String, pPairs As %List, ByRef pQuery, pBody = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pConsole As %DynamicArray, pArgs...) As %Status
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Set ^||OcuPilotBackupHarvest($Increment(^||OcuPilotBackupHarvest)) = pHandler _ "." _ pMethod _ " " _ tText
    Set pFault = ""
    Set pConsole = ""
    Set pHttpStatus = 200
    Set pResult = {}
    If $IsObject(pBody) && (pBody.%Get("action") = "listHistory") {
        Set tEntry = {"timestamp": "2026-01-02 03:04:05", "type": "Full", "status": "Completed", "list": "List", "description": "recorded"}
        Set pResult = {"entries": [(tEntry)], "count": 1}
    }
    Quit $$$OK
}

}
