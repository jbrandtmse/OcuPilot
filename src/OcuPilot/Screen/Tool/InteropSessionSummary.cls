/// <p>One session's counts and time span (Story 24.4): the port's <code>SessionSummary</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionSummary Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.session.summary";

Parameter DESCRIPTION = "At most one row, for the named session: SessionId, its Messages and Errors, the FirstTime and LastTime of its messages, the Seconds between them and the RootBodyClass of its first message. A session no header holds answers no rows; for its headers use interop.session.headers.";

Parameter ENDPOINTS = "SessionSummary";

Parameter FIELDS = "SessionId,Messages,Errors,FirstTime,LastTime,Seconds,RootBodyClass";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "The session id, digits."})
    Quit ..Schema(tProperties, ["session"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Do ..Carry(pArgs, "session", .pQuery, "session")
}

}
