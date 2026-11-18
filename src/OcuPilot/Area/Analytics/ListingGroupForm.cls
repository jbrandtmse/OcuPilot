/// <p>Listing groups' form read (AD-5, AD-29, AD-36, AD-65, Story 24.11): <code>GET /analytics/listing-groups/form?name=</code> answers one listing group as the Edit and Copy dialogs show it:
/// <code>{Name, Class, Caption, Description, TargetCubes, Resource, DefaultResource, Disabled, Compiled, Listings, Version, Namespace}</code>, read through
/// <class>OcuPilot.Port.AnalyticsPort</class>'s <code>LISTINGGROUP</code> type in the request's namespace, after the Listing groups screen's pairs. It writes nothing and reads no listing's SQL. A
/// name the instance does not hold is 404, a missing or malformed one 400 <code>PORT.VALIDATION</code>, and any other refusal the gate's or the port's own envelope.</p>
Class OcuPilot.Area.Analytics.ListingGroupForm Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsListingGroupList";

/// <p>The query parameter naming the listing group.</p>
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
        If (tName = "") || '$ClassMethod(..PortClass(), "ListingNameShaped", tName) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Port.AnalyticsPort).#REASONLISTINGGROUPREQUIRED, ##class(OcuPilot.Api.Error).#PORTVALIDATION)
            Quit
        }
        Kill tQuery
        Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#IDKEY) = tName
        Set tQuery("namespace") = ##class(OcuPilot.Kernel.Scope).Current()
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTLISTINGGROUPS, ##class(OcuPilot.Port.AnalyticsPort).#TYPELISTINGGROUP, .tQuery, "", .tRow, .tHttp, .tFault)
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
