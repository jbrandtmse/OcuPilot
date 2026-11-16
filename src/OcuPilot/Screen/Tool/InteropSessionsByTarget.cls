/// <p>Sessions with a message to one host, in a time window (Story 24.4): <code>kind</code> <code>target</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsByTarget Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bytarget";

Parameter DESCRIPTION = "One row per session with a message to the named host in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 720, default 24) ending at endDateTime, and maxRows bounds the rows; for one header per row use interop.messages.read.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("target", {"type": "string", "maxLength": 256, "description": "The host's configuration name as a message header holds it, matched whole in any letter case."})
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["target"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "target"
    Do ..Carry(pArgs, "target", .pQuery, "target")
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
