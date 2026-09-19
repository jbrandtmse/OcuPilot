/// <p>The privilege map the shell reads: every area and every built screen, in declared order, each
/// carrying whether the calling process may reach it and, when it may not, the
/// <code>(resource, permission)</code> pair that failed. <class>OcuPilot.Api.Navigation</class>
/// answers it as <code>GET /api/ocupilot/navigation</code> and
/// <class>OcuPilot.Kernel.Shell.PrivilegesRead</class> as the <code>shell.privileges.read</code>
/// tool, so both answer the one object <method>Payload</method> builds.</p>
/// <p>The roster is <class>OcuPilot.Screen.Registry</class>'s and the verdict
/// <class>OcuPilot.Screen.Gate</class>'s.</p>
/// <p><b>Recomputed on every call</b> (AD-8). Nothing here is resolved at startup or cached
/// between requests, which is the server half of "privileges change after load": a role revoked
/// after the map was fetched is reflected the next time the client asks, and the client asks
/// again on any 403.</p>
/// <p><b>Never a partial list.</b> A gate that cannot be evaluated is a refusal, not an omitted
/// entry -- an entry missing from the map would read as a screen that does not exist, which is
/// the one thing the gating contract forbids.</p>
Class OcuPilot.Kernel.Shell.Navigation Extends %RegisteredObject
{

/// <p>Build the navigation map, writing nothing.</p>
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

}
