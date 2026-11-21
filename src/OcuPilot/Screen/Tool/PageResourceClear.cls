/// <p>Page resources' Clear (AD-51, AD-53, AD-64, Story 21.37): remove the custom resource of one classic page, so the classic portal and every OcuPilot
/// screen that declares the page stop requiring it. <class>OcuPilot.Port.PortalResourcePort</class> deletes it through the vendor's own call and
/// refuses 409 <code>ACCESS.PAGE.NOTASSIGNED</code> when the page holds none; an accepted clear records <code>SecurityChange</code>.</p>
/// <p>The mint's and a screen action's read are composed for a clear (<method>PortQuery</method>), so a page with no resource is refused before
/// anything is stored; the confirm's re-read and the read-back are not, because their payload carries the reviewed <code>Resource</code>, which the
/// fingerprint holds. The read-back is gone once <code>Resource</code> reads empty (<method>ReadBackGone</method>).</p>
Class OcuPilot.Screen.Tool.PageResourceClear Extends OcuPilot.Screen.Tool.PageResourceAction
{

Parameter TOOLNAME = "permissions.pageresources.clear";

Parameter DESCRIPTION = "Propose clearing the custom resource of a classic portal page, so the classic portal and the OcuPilot screens that follow the page no longer require it. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the page by its class, as the Page resources list reports it. A page that holds no custom resource is refused.";

Parameter WRITETYPE = "DELETE";

/// <p>The resource is removed, which is the verb the change event carries.</p>
Parameter CHANGEACTION = "deleted";

Parameter SCREENACTIONS = "clear";

/// <p>The one field the card's removal row names.</p>
Parameter REMOVALROWS = "Resource";

ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The port's clear key, unless the payload carries the reviewed <code>Resource</code> -- the stored payload of a confirm -- which reads plain.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("Resource") = "string") Quit
    Set pQuery(##class(OcuPilot.Port.PortalResourcePort).#CLEARPARAM) = 1
}

/// <p>The resource is gone once the re-read reports the page with none.</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) || (pAfter.%GetTypeOf("Resource") '= "string") Quit 0
    Quit (pAfter.%Get("Resource") = "")
}

/// <p>The card's removal row, the resource the page holds taken away, and the row naming the screens that follow the page.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set pRows = ..RemovalRows(pFresh)
    Set tScreens = ..ScreenRows(pFresh).%GetIterator()
    While tScreens.%GetNext(.tKey, .tRow) {
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The card's title.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    Quit ..Summary(..#SUMMARYCLEAR, ..PageOf(pFresh, pId), "")
}

}
