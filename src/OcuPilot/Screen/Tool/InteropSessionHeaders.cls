/// <p>One session's headers in order, optionally the error headers alone (Story 24.4): the port's <code>SessionMessages</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionHeaders Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.session.headers";

Parameter DESCRIPTION = "One row per message header of the named session in ID order, with its Step (1 to n), time, type, status, source, target, body class and error flag; errorsOnly keeps the headers marked as errors, and maxRows bounds the rows. interop.messages.read lists headers across sessions.";

Parameter ENDPOINTS = "SessionMessages";

Parameter FIELDS = "Step,ID,TimeCreated,Type,Status,Source,Target,BodyClass,Error,SessionId";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("session", {"type": "string", "maxLength": 19, "description": "The session id, digits."})
    Do tProperties.%Set("errorsOnly", {"type": "boolean", "description": "True to keep only the headers marked as errors. Absent, every header."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["session"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Do ..Carry(pArgs, "session", .pQuery, "session")
    If pArgs.%Get("errorsOnly") = 1 Set pQuery("errors") = "yes"
}

}
