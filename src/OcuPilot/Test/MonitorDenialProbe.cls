/// <p>The child process <class>OcuPilot.Test.MonitorPortDenial</class> starts to call
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> directly as a real principal. It logs in as that
/// principal, arms <class>OcuPilot.Test.MonitorSensorFixture</class> so any vendor call would succeed
/// and be counted, invokes the endpoint through <class>OcuPilot.Test.MonitorPortFixture</class> --
/// whose gate is the real one -- then invokes the production <class>OcuPilot.Port.MonitorPort</class>
/// itself, and signals the outcome to its parent as JSON.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process
/// ends when <method>Run</method> returns.</p>
Class OcuPilot.Test.MonitorDenialProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var>, invoke the endpoint, and signal
/// <code>{loggedIn, username, Alerts: {http, calls, fault}, Port: {http, fault, rows}}</code> to
/// process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)

        Do ##class(OcuPilot.Test.MonitorSensorFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", "[]")
        Kill tQuery
        Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
        Set tLeg = {}
        Do tLeg.%Set("http", +tHttp, "number")
        Do tLeg.%Set("calls", ##class(OcuPilot.Test.MonitorSensorFixture).EntryCount(), "number")
        If $IsObject(tFault) Do tLeg.%Set("fault", tFault)
        Do tOut.%Set("Alerts", tLeg)

        Kill tQuery
        Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
        Set tLeg = {}
        Do tLeg.%Set("http", +tHttp, "number")
        Do tLeg.%Set("rows", $Select($IsObject(tRows): tRows.%Size(), 1: -1), "number")
        If $IsObject(tFault) Do tLeg.%Set("fault", tFault)
        Do tOut.%Set("Port", tLeg)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
