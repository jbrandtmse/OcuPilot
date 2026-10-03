/// <p>Test-only <class>OcuPilot.Port.JournalPort</class> whose journal integrity check is answered by
/// the test (Story 18.5): a <code>Journal.File</code> <code>INTEGRITYCHECK</code> is recorded and
/// answered, without reaching the vendor, with the console lines <method>AnswerLines</method> armed --
/// the finished task's answer the admin port reads -- or with <code>PORT.TIMEOUT</code> after
/// <method>AnswerTimeout</method>, so <class>OcuPilot.Port.JournalPort</class>'s started conversion is
/// what the caller sees. Every other call is the journal port's, sent to the instance. Each call is
/// recorded (<method>Calls</method>), so a gate test can show a refusal made before any port call.
/// State lives in <code>^||OcuPilotJournalIntegrityPort</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalIntegrityPort Extends OcuPilot.Port.JournalPort
{

/// <p>Forget what was armed and recorded.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotJournalIntegrityPort
}

/// <p>Answer the next checks with the console lines <var>pLines</var>, a JSON array of strings.</p>
ClassMethod AnswerLines(pLines As %DynamicArray)
{
    Set ^||OcuPilotJournalIntegrityPort("lines") = pLines.%ToJSON()
    Kill ^||OcuPilotJournalIntegrityPort("timeout")
}

/// <p>Answer the next checks as still running at the port's bound.</p>
ClassMethod AnswerTimeout()
{
    Set ^||OcuPilotJournalIntegrityPort("timeout") = 1
}

/// <p>How many calls this port has made since <method>Clear</method>, and their
/// <code>endpoint/type</code>s joined by commas in <var>pTypes</var>.</p>
ClassMethod Calls(Output pTypes As %String) As %Integer
{
    Set pTypes = $Get(^||OcuPilotJournalIntegrityPort("types"))
    Quit +$Get(^||OcuPilotJournalIntegrityPort("calls"))
}

/// <p>The bodies the checks were sent with, each as its JSON, joined by <code>|</code>.</p>
ClassMethod Bodies() As %String
{
    Quit $Get(^||OcuPilotJournalIntegrityPort("bodies"))
}

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotJournalIntegrityPort("calls") = $Get(^||OcuPilotJournalIntegrityPort("calls")) + 1
    Set tTypes = $Get(^||OcuPilotJournalIntegrityPort("types"))
    Set ^||OcuPilotJournalIntegrityPort("types") = tTypes _ $Select(tTypes = "": "", 1: ",") _ pEndpoint _ "/" _ pType
    If (pEndpoint '= ..#FILEENDPOINT) || (pType '= ..#INTEGRITYTYPE) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tBodies = ..Bodies()
    Set ^||OcuPilotJournalIntegrityPort("bodies") = tBodies _ $Select(tBodies = "": "", 1: "|") _ $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set pResult = ""
    Set pFault = ""
    If $Get(^||OcuPilotJournalIntegrityPort("timeout")) {
        Set pHttpStatus = 503
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTTIMEOUT, "The instance did not finish that operation in time")
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTTIMEOUT)
    }
    Set tAnswer = {"State": "Finished", "Result": {}}
    Do tAnswer.%Set("Console", ##class(%DynamicArray).%FromJSON($Get(^||OcuPilotJournalIntegrityPort("lines"), "[]")))
    Set pResult = ##class(OcuPilot.Port.AdminPort).Consoled(tAnswer, 0)
    Set pHttpStatus = 200
    Quit $$$OK
}

}
