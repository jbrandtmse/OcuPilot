/// <p>Screen permissions' Reset (AD-51, AD-53, AD-64, Story 20.15): remove a screen's adjustment, so it
/// requires its declared permissions again. <class>OcuPilot.Port.ScreenAccessPort</class> deletes the row
/// and refuses 409 <code>ACCESS.NOTADJUSTED</code> when there is none.</p>
/// <p>The mint's and a screen action's read are composed for a reset (<method>PortQuery</method>), so a screen
/// nothing adjusts is refused before anything is stored; the confirm's re-read and the read-back are not,
/// because their payload carries the reviewed <code>Adjusted</code>, which the fingerprint holds. The read
/// back is gone once <code>Adjusted</code> reads false (<method>ReadBackGone</method>).</p>
Class OcuPilot.Screen.Tool.ScreenAccessReset Extends OcuPilot.Screen.Tool.ScreenAccessAction
{

Parameter TOOLNAME = "agent.screenpermissions.reset";

Parameter DESCRIPTION = "Propose clearing a screen's adjusted permissions, so it requires the permissions its descriptor declares again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the screen as the Screen permissions list reports it. A screen that is not adjusted is refused.";

Parameter WRITETYPE = "DELETE";

/// <p>The adjustment is removed, which is the verb the change event carries.</p>
Parameter CHANGEACTION = "deleted";

Parameter SCREENACTIONS = "reset";

Parameter PRECONDITIONFIELD = "Adjusted";

Parameter FINGERPRINTSUBJECT = "Pairs,Adjusted";

Parameter READANSWERS = "Screen,Pairs,Adjusted,Result";

ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The port's reset key, unless the payload carries the reviewed <code>Adjusted</code> -- the stored
/// payload of a confirm -- which reads plain.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("Adjusted") = "boolean") Quit
    Set pQuery(##class(OcuPilot.Port.ScreenAccessPort).#RESETKEY) = 1
}

/// <p>The adjustment is gone once the re-read reports the screen unadjusted.</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) || (pAfter.%GetTypeOf("Adjusted") '= "boolean") Quit 0
    Quit 'pAfter.%Get("Adjusted")
}

}
