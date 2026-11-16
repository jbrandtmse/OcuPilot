/// <p>The sessions indexed under one super-session key, with no time window (Story 24.4): <code>kind</code> <code>supersession</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsBySuperSession Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bysupersession";

Parameter DESCRIPTION = "One row per session indexed under one super-session key, given directly or taken from a session you name, with no time window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds under the key. Give superSession or session, not both; maxRows bounds the rows.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("superSession", {"type": "string", "maxLength": 300, "description": "The super-session key, matched whole in any letter case."})
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "A session id, digits, whose own super-session key is used."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties)
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "supersession"
    Do ..Carry(pArgs, "superSession", .pQuery, "superSession")
    Do ..Carry(pArgs, "session", .pQuery, "session")
}

}
