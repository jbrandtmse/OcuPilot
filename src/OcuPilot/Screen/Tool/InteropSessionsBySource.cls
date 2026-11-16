/// <p>Sessions with a message from one host, in a time window (Story 24.4): <code>kind</code> <code>source</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsBySource Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bysource";

Parameter DESCRIPTION = "One row per session with a message from the named host in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 720, default 24) ending at endDateTime, and maxRows bounds the rows; for one header per row use interop.messages.read.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("source", {"type": "string", "maxLength": 256, "description": "The host's configuration name as a message header holds it, matched whole in any letter case."})
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["source"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "source"
    Do ..Carry(pArgs, "source", .pQuery, "source")
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
