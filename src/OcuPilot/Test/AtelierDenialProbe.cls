/// <p>The child process <class>OcuPilot.Test.AtelierPortDenial</class> starts to call
/// <class>OcuPilot.Port.AtelierPort</class> directly as a real principal. It logs in as that
/// principal, then, for each namespace it is given, invokes the <code>Classes</code>,
/// <code>Class</code>, <code>Search</code>, <code>Macro</code>, <code>Catalog.Tables</code> and
/// <code>Catalog.Triggers</code> endpoints through
/// <class>OcuPilot.Test.AtelierPortFixture</class> -- whose gate
/// and database resources are the real ones and whose routes are canned and counted -- and the
/// production port itself, and signals the outcome to its parent as JSON.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process
/// ends when <method>Run</method> returns.</p>
Class OcuPilot.Test.AtelierDenialProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var> and signal
/// <code>{loggedIn, username, &lt;namespace&gt;: {Classes: {http, calls, code, failedPair},
/// Class: {...}, Search: {...}, Macro: {...}, Catalog.Tables: {...}, Catalog.Triggers: {...}, Port:
/// {http, code, failedPair, rows}}}</code> to process
/// <var>pParent</var> for each
/// of the comma-separated <var>pNamespaces</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pNamespaces As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(pNamespaces, ",") {
            Set tNamespace = $Piece(pNamespaces, ",", tI)
            Set tLegs = {}
            For tEndpoint = "Classes", "Class", "Search", "Macro", "Catalog.Tables", "Catalog.Triggers" {
                Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
                Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
                Kill tQuery
                Set tQuery("namespace") = tNamespace
                Set tQuery("name") = "Probe.Denial.cls"
                Set tQuery("text") = "Probe"
                Set tQuery("document") = "Probe.Denial.cls"
                Set tQuery("macro") = "Probe"
                Set tQuery("table") = "Probe.Denial"
                Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
                Set tLeg = ..Leg(tHttp, tFault)
                Do tLeg.%Set("calls", ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "number")
                Do tLegs.%Set(tEndpoint, tLeg)
            }
            Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
            Kill tQuery
            Set tQuery("namespace") = tNamespace
            Set tQuery("maxRows") = 1
            Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
            Set tLeg = ..Leg(tHttp, tFault)
            Do tLeg.%Set("rows", $Select($IsObject(tRows): tRows.%Size(), 1: -1), "number")
            Do tLegs.%Set("Port", tLeg)
            Do tOut.%Set(tNamespace, tLegs)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>One leg's status, code and failed pair.</p>
ClassMethod Leg(pHttp As %Integer, pFault) As %DynamicObject
{
    Set tLeg = {}
    Do tLeg.%Set("http", +pHttp, "number")
    If $IsObject(pFault) {
        Do tLeg.%Set("code", pFault.%Get("code"))
        If $IsObject(pFault.%Get("detail")) Do tLeg.%Set("failedPair", pFault.detail.%Get("failedPair"))
    }
    Quit tLeg
}

}
