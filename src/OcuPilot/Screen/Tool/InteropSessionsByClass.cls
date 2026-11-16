/// <p>Sessions in which a class name appears as source, target or body class, in a window of at most a week (Story 24.4): <code>kind</code> <code>class</code> of the port's <code>Sessions</code> read. A host's configuration name equals its class only when it was named so.</p>
Class OcuPilot.Screen.Tool.InteropSessionsByClass Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.byclass";

Parameter DESCRIPTION = "One row per session with a message whose source, target or body class (or the one match names) equals the class name in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 168, default 24) ending at endDateTime, and maxRows (1 to 100, default 20) bounds the rows.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

Parameter DEFAULTROWS As INTEGER = 20;

Parameter MAXROWS As INTEGER = 100;

Parameter MAXHOURS As INTEGER = 168;

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("className", {"type": "string", "maxLength": 256, "description": "A class name such as Ens.StringRequest, matched whole in any letter case."})
    Do tProperties.%Set("match", {"type": "string", "description": "Where the class name must appear: any (the default), source, target or body."})
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["className"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "class"
    Do ..Carry(pArgs, "className", .pQuery, "className")
    Do ..Carry(pArgs, "match", .pQuery, "match")
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
