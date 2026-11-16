/// <p>The other sessions that share a session's super-session key, with no time window (Story 24.4): <code>kind</code> <code>related</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsRelated Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.related";

Parameter DESCRIPTION = "One row per session that shares the named session's super-session key, without the session itself, with no time window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds under the key. A session with no key answers no rows; maxRows bounds the rows.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "The session id, digits, whose related sessions are read."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["session"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "related"
    Do ..Carry(pArgs, "session", .pQuery, "session")
}

}
