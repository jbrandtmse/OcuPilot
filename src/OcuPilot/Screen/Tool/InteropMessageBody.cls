/// <p>One message's body as text lines (Story 24.4): the port's <code>MessageContents</code> read, which records the vendor's view audit
/// row once for each call as the classic Contents pane does (AD-62). It holds the header pair and the content pair. With
/// <code>summary</code> the text is cut after <parameter>SUMMARYLENGTH</parameter> characters.</p>
Class OcuPilot.Screen.Tool.InteropMessageBody Extends OcuPilot.Screen.Tool.InteropInspect
{

Parameter TOOLNAME = "interop.message.body";

Parameter DESCRIPTION = "One row per line of the named message's body as text (Line, Text), up to maxRows (1 to 500, default 50); with summary true, only its first 256 characters. It needs the message content permission, and a body that is not text answers INTEROP.MESSAGE.CONTENTS; interop.message.detail adds the header properties.";

Parameter ENDPOINTS = "MessageContents";

Parameter FIELDS = "Line,Text";

/// <p>The characters a summary keeps.</p>
Parameter SUMMARYLENGTH As INTEGER = 256;

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tProperties = {}
    Do tProperties.%Set("message", {"type": "string", "maxLength": 19, "description": "The message header's ID: digits, not beginning with zero."})
    Do tProperties.%Set("summary", {"type": "boolean", "description": "True to keep only the first 256 characters of the text. Absent, the whole text up to maxRows lines."})
    Do ..RowsProperty(tProperties)
    Quit ..Schema(tProperties, ["message"])
}

ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Do ..Carry(pArgs, "message", .pQuery, "message")
}

/// <p>The port's lines and, for a summary, the lines kept while their text totals at most <parameter>SUMMARYLENGTH</parameter>
/// characters, the last of them cut to fit; <var>pCut</var> is 1 when anything was dropped or cut.</p>
ClassMethod Fetch(pArgs As %DynamicObject, ByRef pQuery, pLimit As %Integer, Output pRows As %DynamicArray, Output pCut As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##super(pArgs, .pQuery, pLimit, .pRows, .pCut, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || '$IsObject(pRows) || (pArgs.%Get("summary") '= 1) Quit tSC
    Set tKept = []
    Set tLeft = ..#SUMMARYLENGTH
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLeft < 1 {
            Set pCut = 1
            Quit
        }
        Set tText = tLine.%Get("Text")
        If $Length(tText) > tLeft {
            Do tLine.%Set("Text", $Extract(tText, 1, tLeft), "string")
            Set pCut = 1
        }
        Set tLeft = tLeft - $Length(tLine.%Get("Text"))
        Do tKept.%Push(tLine)
    }
    Set pRows = tKept
    Quit tSC
}

}
