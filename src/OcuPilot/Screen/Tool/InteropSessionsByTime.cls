/// <p>Sessions with a message created in a time window, newest first (Story 24.4): <code>kind</code> <code>time</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsByTime Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bytime";

Parameter DESCRIPTION = "One row per session with a message created in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 720, default 24) ending at endDateTime, and maxRows bounds the rows; for one header per row use interop.messages.read.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, [])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "time"
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
