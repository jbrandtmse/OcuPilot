/// <p>Sessions with a message carrying one body class, in a time window (Story 24.4): <code>kind</code> <code>bodyclass</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsByBodyClass Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bybodyclass";

Parameter DESCRIPTION = "One row per session with a message whose body is of the named class in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 720, default 24) ending at endDateTime, and maxRows bounds the rows; for one header per row use interop.messages.read.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("bodyClass", {"type": "string", "maxLength": 256, "description": "The message body class, as a class name such as Ens.StringRequest, matched whole in any letter case."})
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["bodyClass"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "bodyclass"
    Do ..Carry(pArgs, "bodyClass", .pQuery, "bodyClass")
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
