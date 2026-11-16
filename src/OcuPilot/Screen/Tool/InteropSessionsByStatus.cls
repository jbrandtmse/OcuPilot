/// <p>Sessions holding a header in any of the given statuses, in a time window (Story 24.4): <code>kind</code> <code>status</code> of the port's <code>Sessions</code> read.</p>
Class OcuPilot.Screen.Tool.InteropSessionsByStatus Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.sessions.bystatus";

Parameter DESCRIPTION = "One row per session with a message in any of the given statuses in the window: SessionId, FirstTime, a Source, Target and BodyClass, the lowest Status, and the Messages and Errors it holds there. The window is the last hours (1 to 720, default 24) ending at endDateTime, and maxRows bounds the rows; for one header per row use interop.messages.read.";

Parameter ENDPOINTS = "Sessions";

Parameter FIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("status", {"type": "array", "minItems": 1, "maxItems": 9, "items": {"type": "string"}, "description": "One to nine of Created, Queued, Delivered, Discarded, Suspended, Deferred, Aborted, Error, Completed. A session qualifies when it holds a message in any of them."})
    Do ..WindowProperties(tProperties)
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["status"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Set pQuery("kind") = "status"
    Set tWords = ""
    Set tIterator = pArgs.status.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tWord) {
        Set tWords = tWords _ $Select(tWords = "": "", 1: ",") _ tWord
    }
    Set pQuery("status") = tWords
    Do ..Carry(pArgs, "hours", .pQuery, "hours")
    Do ..Carry(pArgs, "endDateTime", .pQuery, "endDateTime")
}

}
