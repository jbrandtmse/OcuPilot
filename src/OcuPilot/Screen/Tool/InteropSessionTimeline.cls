/// <p>One session's headers in order, optionally between two times (Story 24.4): the port's <code>SessionMessages</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionTimeline Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.session.timeline";

Parameter DESCRIPTION = "One row per message header of the named session in ID order, with its Step (1 to n), time, type, status, source, target, body class and error flag, optionally between beginDateTime and endDateTime; maxRows bounds the rows. It is the session as the message viewer lists it; interop.messages.read lists headers across sessions.";

Parameter ENDPOINTS = "SessionMessages";

Parameter FIELDS = "Step,ID,TimeCreated,Type,Status,Source,Target,BodyClass,Error,SessionId";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "The session id, digits."})
    Do tProperties.%Set("beginDateTime", {"type": "string", "maxLength": 19, "description": "Only headers created at or after this, as this instance's local time written YYYY-MM-DD HH:MM:SS."})
    Do tProperties.%Set("endDateTime", {"type": "string", "maxLength": 19, "description": "Only headers created at or before this, as this instance's local time written YYYY-MM-DD HH:MM:SS."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["session"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Do ..Carry(pArgs, "session", .pQuery, "session")
    Do ..Carry(pArgs, "beginDateTime", .pQuery, "beginDateTime")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
