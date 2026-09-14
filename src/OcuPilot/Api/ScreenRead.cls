/// <p>The handler behind <code>GET /api/ocupilot/screens/:screen/read?maxRows=</code>: any screen's
/// one declared read (AD-36), addressed by its <code>toolIdentifier</code> (AD-5). One generic
/// route serves every screen, so adding a screen adds no route.</p>
/// <p>In order: the descriptor is resolved, and a screen that does not exist or declares no read
/// is the framework's 404; the descriptor's privilege set is evaluated in the calling process
/// before the port is touched (AD-8), and a refusal is 403 <code>AUTH.NOPRIVILEGE</code> naming the
/// failed pair; then <method>OcuPilot.Screen.Read.Execute</method> runs, whose refusal of a bad
/// <code>maxRows</code> and whose port faults render with their own HTTP status and fault through
/// the one error writer (AD-12, AD-39). The screen filters and sorts on the client, so the route
/// takes no filter or sort.</p>
/// <p>Seams a fixture subclass overrides (<class>OcuPilot.Test.Read.ScreenReadFixture</class>):
/// <method>RegistryClass</method>, <method>GateClass</method> and <method>ReadClass</method>.
/// Production overrides none of them.</p>
Class OcuPilot.Api.ScreenRead Extends %RegisteredObject
{

/// <p>The screen registry the descriptor is resolved from.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>The privilege gate the descriptor is evaluated by.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Screen.Gate"
}

/// <p>The read executor.</p>
ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Screen.Read"
}

/// <p>Answer the request for <var>pScreen</var>, a <code>toolIdentifier</code>: one success
/// envelope carrying <code>{fields, rows, truncated}</code>, or one error envelope.</p>
ClassMethod Handle(pScreen As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForTool", pScreen)
        If (tDescriptor '= "") && '$IsObject($ClassMethod(tDescriptor, "Read")) Set tDescriptor = ""
        If tDescriptor = "" {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
            Quit
        }

        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "Evaluate", tDescriptor, .tFailedPair) {
            Set tDetail = ""
            If tFailedPair '= "" {
                Set tDetail = {}
                Do tDetail.%Set("failedPair", tFailedPair)
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, "This account may not read that screen", ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, tDetail)
            Quit
        }

        Set tReadSC = $ClassMethod(..ReadClass(), "Execute", tDescriptor, %request.Get("maxRows"), .tResult, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If '$IsObject(tFault) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+tHttp: +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
