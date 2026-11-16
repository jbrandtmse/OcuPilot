/// <p>One session by its id, with no time window (Story 24.4): <code>kind</code> <code>session</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsById Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.byid";

Parameter DESCRIPTION = "At most one row, for the named session, with no time window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds. A session no header holds answers no rows; for one header per row use interop.session.headers.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "The session id, digits."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["session"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "session"
    Do ..Carry(pArgs, "session", .pQuery, "session")
}

}
