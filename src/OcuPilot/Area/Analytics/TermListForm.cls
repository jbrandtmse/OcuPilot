/// <p>Term lists' form read (AD-5, AD-29, AD-36, AD-65, Story 24.2): <code>GET /analytics/term-lists/form?name=</code> answers one term list's
/// header as the Edit term list and the Add entry dialogs show it: <code>{Name, Caption, Description, Pattern, SubjectArea, Fields, HideValue,
/// Modified, Namespace}</code>, read through <class>OcuPilot.Port.AnalyticsPort</class>'s <code>TERMLIST</code> type in the request's namespace,
/// after the Term lists screen's pairs. It writes nothing and reads no entry. A name the instance does not hold is 404, a missing or malformed
/// one 400 <code>PORT.VALIDATION</code>, and any other refusal the gate's or the port's own envelope.</p>
Class OcuPilot.Area.Analytics.TermListForm Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsTermListList";

/// <p>The query parameter naming the term list.</p>
Parameter NAMEPARAM = "name";

/// <p>The port the read goes through. Overridable so a fixture can observe it; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AnalyticsPort"
}

ClassMethod HandleRead() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tName = %request.Get(..#NAMEPARAM, "")
        If (tName = "") || '$ClassMethod(..PortClass(), "NameShaped", tName) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Port.AnalyticsPort).#REASONTERMLISTREQUIRED, ##class(OcuPilot.Api.Error).#PORTVALIDATION)
            Quit
        }
        Kill tQuery
        Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#IDKEY) = tName
        Set tQuery("namespace") = ##class(OcuPilot.Kernel.Scope).Current()
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTTERMLISTS, ##class(OcuPilot.Port.AnalyticsPort).#TYPETERMLIST, .tQuery, "", .tRow, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            } Else {
                Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            }
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tRow)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
