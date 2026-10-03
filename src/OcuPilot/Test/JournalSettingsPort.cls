/// <p>Test-only <class>OcuPilot.Test.JournalIntegrityPort</class> for Story 18.18's journal settings
/// suites: every call is recorded as that seam records it (<method>Calls</method>), and the body of
/// each settings <code>PUT</code> is kept before it is sent to the instance (<method>PutBody</method>),
/// so a test reads exactly what the vendor was sent, or that nothing was. After <method>Hold</method>
/// a settings <code>PUT</code> is recorded and answered 200 without reaching the instance, so a
/// refusal a test expects cannot change the journal settings if it fails to happen. State lives in
/// <code>^||OcuPilotJournalSettingsPort</code> and the parent's global; <method>Clear</method> forgets
/// both.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalSettingsPort Extends OcuPilot.Test.JournalIntegrityPort
{

/// <p>Forget what was armed and recorded.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotJournalSettingsPort
    Do ##super()
}

/// <p>Answer the next settings <code>PUT</code>s 200 without sending them, until
/// <method>Clear</method>.</p>
ClassMethod Hold()
{
    Set ^||OcuPilotJournalSettingsPort("hold") = 1
}

/// <p>Send the next settings <code>PUT</code>s to the instance again, as before <method>Hold</method>.</p>
ClassMethod Release()
{
    Kill ^||OcuPilotJournalSettingsPort("hold")
}

/// <p>Answer the settings <code>GET</code> with <code>ArchiveName</code> reading <var>pName</var>, until
/// <method>Clear</method>, so a test reaches the port's purge rule for an archive target without
/// creating one.</p>
ClassMethod Archive(pName As %String)
{
    Set ^||OcuPilotJournalSettingsPort("archive") = pName
}

/// <p>How many settings <code>PUT</code>s were sent since <method>Clear</method>.</p>
ClassMethod Puts() As %Integer
{
    Quit +$Get(^||OcuPilotJournalSettingsPort)
}

/// <p>The JSON body the <var>pIndex</var>th settings <code>PUT</code> was sent with, or
/// <code>""</code>.</p>
ClassMethod PutBody(pIndex As %Integer = 1) As %String
{
    Quit $Get(^||OcuPilotJournalSettingsPort(pIndex))
}

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#SETTINGSENDPOINT) && (pType = "PUT") {
        Set ^||OcuPilotJournalSettingsPort($Increment(^||OcuPilotJournalSettingsPort)) = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
        If $Get(^||OcuPilotJournalSettingsPort("hold")) {
            Set pResult = {}
            Set pHttpStatus = 200
            Set pFault = ""
            Quit $$$OK
        }
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If (pEndpoint = ..#SETTINGSENDPOINT) && (pType = "GET") && ($Get(^||OcuPilotJournalSettingsPort("archive")) '= "") && $IsObject($Get(pResult)) {
        Do pResult.%Set("ArchiveName", ^||OcuPilotJournalSettingsPort("archive"), "string")
    }
    Quit tSC
}

}
