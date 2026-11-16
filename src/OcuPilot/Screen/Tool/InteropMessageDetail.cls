/// <p>One message header with the start of its body (Story 24.4): the port's <code>MessageHeader</code> read, then its
/// <code>MessageContents</code> read, which records the vendor's view audit row as the classic Contents pane does (AD-62). It holds the
/// header pair and the content pair. Rule decisions are not read here: the classic page that shows them has a resource of its own.</p>
Class OcuPilot.Screen.Tool.InteropMessageDetail Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.message.detail";

Parameter DESCRIPTION = "One row per header property of the named message (23 of them: Name, Position, Value), then the first lines of its body as rows named Body, up to maxRows (1 to 500, default 50). It reads the body, which needs the message content permission, and it leaves out rule decisions, which have a log of their own; interop.message.body reads the whole body.";

Parameter ENDPOINTS = "MessageHeader,MessageContents";

Parameter FIELDS = "Name,Position,Value";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("message", {"type": "string", "maxLength": 19, "description": "The message header's ID: digits, not beginning with zero."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["message"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Do ..Carry(pArgs, "message", .pQuery, "message")
}

/// <p>The header's rows, then the body's lines as <code>{Name: "Body", Position, Value}</code>, <code>Position</code> continuing after the
/// header's last. A header no row holds answers no rows and reads no body. The body is asked for <var>pLimit</var> lines, so the
/// combined rows are cut by <method>View</method> at <var>pLimit</var>.</p>
ClassMethod Fetch(pArgs As %DynamicObject, ByRef pQuery, pLimit As %Integer, Output pRows As %DynamicArray, Output pCut As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pCut = 0
    Kill tHeaderQuery
    Merge tHeaderQuery = pQuery
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $Piece(..#ENDPOINTS, ",", 1), "LIST", .tHeaderQuery, "", .tHeader, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tHeader) Quit $$$ERROR($$$GeneralError, "the message header read answered no rows")
    Set pRows = tHeader
    If 'tHeader.%Size() Quit $$$OK
    Kill tBodyQuery
    Merge tBodyQuery = pQuery
    Set tBodyQuery("maxRows") = pLimit
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $Piece(..#ENDPOINTS, ",", 2), "LIST", .tBodyQuery, "", .tBody, .pHttpStatus, .pFault, .pCut)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tBody) Quit $$$ERROR($$$GeneralError, "the message contents read answered no rows")
    Set tIterator = tBody.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tRow = {}
        Do tRow.%Set("Name", "Body", "string")
        Do tRow.%Set("Position", tHeader.%Size() + tLine.%Get("Line"), "number")
        Do tRow.%Set("Value", tLine.%Get("Text"), "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
