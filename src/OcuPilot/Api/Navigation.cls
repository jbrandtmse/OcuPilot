/// <p>The handler behind <code>GET /api/ocupilot/navigation</code>: every area and every built
/// screen, in declared order, each carrying whether the calling process may reach it and, when
/// it may not, the <code>(resource, permission)</code> pair that failed.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the roster is
/// <class>OcuPilot.Screen.Registry</class>'s, the verdict is
/// <class>OcuPilot.Screen.Gate</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12).</p>
/// <p><b>Recomputed on every call</b> (AD-8). Nothing here is resolved at startup or cached
/// between requests, which is the server half of "privileges change after load": a role revoked
/// after the map was fetched is reflected the next time the client asks, and the client asks
/// again on any 403.</p>
/// <p><b>Never a partial list.</b> A gate that cannot be evaluated is a refusal, not an omitted
/// entry -- an entry missing from the map would read as a screen that does not exist, which is
/// the one thing the gating contract forbids.</p>
Class OcuPilot.Api.Navigation Extends %RegisteredObject
{

/// <p>Build the response body, writing nothing.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tSC = ##class(OcuPilot.Screen.Registry).Roster(.tRoster)
        If $$$ISERR(tSC) Quit
        Set tAreas = []
        Set tIterator = tRoster.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            Set tEntry = {}
            Do tEntry.%Set("key", tArea.key)
            Do tEntry.%Set("labelKey", tArea.labelKey)
            Do tEntry.%Set("railPosition", +tArea.railPosition, "number")
            Do tEntry.%Set("navigates", ''tArea.navigates, "boolean")
            Do tEntry.%Set("pinBottom", ''tArea.pinBottom, "boolean")
            Do ..SetVerdict(tEntry, tArea.key)

            Set tScreens = []
            Set tScreenIterator = tArea.screens.%GetIterator()
            While tScreenIterator.%GetNext(.tScreenIndex, .tScreen) {
                Set tScreenEntry = {}
                Do tScreenEntry.%Set("route", tScreen.route)
                Do tScreenEntry.%Set("labelKey", tScreen.labelKey)
                Do tScreenEntry.%Set("sideBarPosition", +tScreen.sideBarPosition, "number")
                Do ..SetVerdict(tScreenEntry, tScreen.descriptor)
                Do tScreens.%Push(tScreenEntry)
            }
            Do tEntry.%Set("screens", tScreens)
            Do tAreas.%Push(tEntry)
        }
        Set pObject = {}
        Do pObject.%Set("areas", tAreas)
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Evaluate <var>pTarget</var> in the calling process and record the answer on
/// <var>pEntry</var>: <code>allowed</code> always, and <code>failedPair</code> only when the
/// answer is no -- the key is omitted rather than sent empty, so a client cannot read "denied
/// for no stated reason" out of an allowed entry.</p>
ClassMethod SetVerdict(pEntry As %DynamicObject, pTarget As %String)
{
    Set tFailedPair = ""
    Set tAllowed = ##class(OcuPilot.Screen.Gate).Evaluate(pTarget, .tFailedPair)
    Do pEntry.%Set("allowed", ''tAllowed, "boolean")
    If 'tAllowed, tFailedPair '= "" Do pEntry.%Set("failedPair", tFailedPair)
}

/// <p>Answer the request: one success envelope through the one success writer, or the one
/// generic internal envelope when the roster could not be built.</p>
ClassMethod Handle() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Payload(.tObject)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tObject)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
