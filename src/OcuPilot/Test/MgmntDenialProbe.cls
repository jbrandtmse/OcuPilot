/// <p>The child process <class>OcuPilot.Test.MgmntPortDenial</class> starts to call
/// <method>OcuPilot.Port.MgmntPort.Invoke</method> directly as a real principal. It logs in as that
/// principal, arms <class>OcuPilot.Test.MgmntImplFixture</class> so any vendor call would succeed
/// and be counted, invokes both endpoints through <class>OcuPilot.Test.MgmntPortFixture</class> --
/// whose gate is the real one -- then invokes the production <class>OcuPilot.Port.MgmntPort</class>
/// itself, and signals the outcome to its parent as JSON.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process
/// ends when <method>Run</method> returns.</p>
Class OcuPilot.Test.MgmntDenialProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var>, invoke both endpoints, and signal
/// <code>{loggedIn, username, Applications: {http, calls, fault}, Document: {...}, Port: {http, fault}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tEndpoint = "Applications", "Document" {
            Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
            Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetWebRESTApps", "200 OK", "[]")
            Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetRESTApps", "200 OK", "[]")
            Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetApplication", "200 OK", "{""paths"":{}}")
            Kill tQuery
            Set tQuery("namespace") = "HSCUSTOM"
            Set tQuery("application") = "Probe.v1"
            Set tSC = ##class(OcuPilot.Test.MgmntPortFixture).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            Do tLeg.%Set("calls", ##class(OcuPilot.Test.MgmntImplFixture).CallCount(), "number")
            If $IsObject(tFault) Do tLeg.%Set("fault", tFault)
            Do tOut.%Set(tEndpoint, tLeg)
        }
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tSC = ##class(OcuPilot.Port.MgmntPort).Invoke("Applications", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
        Set tLeg = {}
        Do tLeg.%Set("http", +tHttp, "number")
        If $IsObject(tFault) Do tLeg.%Set("fault", tFault)
        Do tOut.%Set("Port", tLeg)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
