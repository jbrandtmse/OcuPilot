/// <p>The shared read behind the agent's session and message tools (Story 24.4, AD-22, AD-24, AD-36, AD-62): each concrete subclass
/// reads one or two endpoints of <class>OcuPilot.Port.InteropPort</class> in the turn's namespace and answers
/// <code>{fields, rows, truncated}</code>. A subclass declares <parameter>TOOLNAME</parameter>,
/// <parameter>DESCRIPTION</parameter>, <parameter>ENDPOINTS</parameter>, <parameter>FIELDS</parameter>, its input schema and its
/// <method>Query</method>; one with narrower bounds also declares its own row and hour parameters, and one that reads two endpoints or
/// shapes the rows overrides <method>Fetch</method>.</p>
/// <p><b>The privilege pairs are the port's.</b> <method>PrivilegePairs</method> is the union of the pairs
/// <method>OcuPilot.Port.InteropPort.Pairs</method> answers for each endpoint, so the dispatcher refuses a caller who lacks one by name
/// before the port is reached, and the port's own gate still decides whether the read may run (AD-8, AD-29).</p>
/// <p><b>The namespace is the turn's</b> (<method>OcuPilot.Kernel.Scope.Current</method>), never an argument. The port is asked for one
/// row more than the cap, so <code>truncated</code> says whether the cap cut anything.</p>
Class OcuPilot.Screen.Tool.InteropInspect Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

Parameter KIND = "read";

/// <p>The port endpoints the tool reads, comma-separated. The first is the one <method>Fetch</method> reads.</p>
Parameter ENDPOINTS = "";

/// <p>The fields each answered row carries, comma-separated and in order. A field of the port's row outside this list is dropped, so
/// widening the port's projection cannot widen the tool's answer.</p>
Parameter FIELDS = "";

/// <p>The rows a call without <code>maxRows</code> reads, and the most <code>maxRows</code> may name.</p>
Parameter DEFAULTROWS As INTEGER = 50;

Parameter MAXROWS As INTEGER = 500;

/// <p>The most hours a window may span (a subclass whose window is narrower declares its own).</p>
Parameter MAXHOURS As INTEGER = 720;

Parameter DEFAULTHOURS As INTEGER = 24;

/// <p>The port the endpoints are read through. Overridable so a fixture can answer the read; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.InteropPort"
}

/// <p>The pairs the caller must hold: each endpoint's, in order, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ""
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpointPairs = $ClassMethod(..PortClass(), "Pairs", $Piece(..#ENDPOINTS, ",", tI), "LIST")
        For tJ = 1:1:$ListLength(tEndpointPairs) {
            If '$ListFind(tPairs, $List(tEndpointPairs, tJ)) Set tPairs = tPairs _ $ListBuild($List(tEndpointPairs, tJ))
        }
    }
    Set pResolved = ($ListLength(tPairs) > 0)
    Quit tPairs
}

/// <p>Declared: none (AD-3). No argument of these tools can hold a credential.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>Add the window's two properties to <var>pProperties</var>: <code>hours</code>, 1 to <parameter>MAXHOURS</parameter>, and
/// <code>endDateTime</code>, the instance's local time.</p>
ClassMethod WindowProperties(pProperties As %DynamicObject)
{
    Set tHours = {"type": "integer", "minimum": 1}
    Do tHours.%Set("maximum", ..#MAXHOURS, "number")
    Do tHours.%Set("description", "How many hours the window spans, ending at endDateTime: 1 to " _ ..#MAXHOURS _ ". Absent, " _ ..#DEFAULTHOURS _ ".", "string")
    Do pProperties.%Set("hours", tHours)
    Set tEnd = {"type": "string", "maxLength": 19}
    Do tEnd.%Set("description", "When the window ends, as this instance's local time written YYYY-MM-DD HH:MM:SS. Absent, now.", "string")
    Do pProperties.%Set("endDateTime", tEnd)
}

/// <p>Add the <code>maxRows</code> property to <var>pProperties</var>: 1 to <parameter>MAXROWS</parameter>.</p>
ClassMethod RowsProperty(pProperties As %DynamicObject)
{
    Set tRows = {"type": "integer", "minimum": 1}
    Do tRows.%Set("maximum", ..#MAXROWS, "number")
    Do tRows.%Set("description", "The most rows to read: 1 to " _ ..#MAXROWS _ ". Absent, " _ ..#DEFAULTROWS _ ". When more exist, truncated is true.", "string")
    Do pProperties.%Set("maxRows", tRows)
}

/// <p>A closed input schema over <var>pProperties</var>, requiring the names in <var>pRequired</var> (a <class>%DynamicArray</class>, none
/// when it is not given).</p>
ClassMethod Schema(pProperties As %DynamicObject, pRequired As %DynamicArray = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "additionalProperties": false}
    Do tSchema.%Set("properties", pProperties)
    Do tSchema.%Set("required", $Select($IsObject(pRequired): pRequired, 1: []))
    Quit tSchema
}

/// <p>The port query this call asks, set into <var>pQuery</var> from the validated arguments <var>pArgs</var>: the endpoint's criteria,
/// by the names the port takes. The namespace and the row bound are set by <method>View</method>. A subclass overrides it.</p>
ClassMethod Query(pArgs As %DynamicObject, ByRef pQuery)
{
    Quit
}

/// <p>Copy <var>pArgs</var>'s <var>pArgName</var> into <var>pQuery</var>(<var>pQueryName</var>) when the call gave it.</p>
ClassMethod Carry(pArgs As %DynamicObject, pArgName As %String, ByRef pQuery, pQueryName As %String)
{
    If pArgs.%GetTypeOf(pArgName) = "unassigned" Quit
    Set pQuery(pQueryName) = pArgs.%Get(pArgName)
}

/// <p>Read the port's rows for the query <var>pQuery</var>, at most <var>pLimit</var> of them wanted (the query asks one more). The
/// default reads the first of <parameter>ENDPOINTS</parameter> at <code>LIST</code>. <var>pCut</var> is 1 when the port cut a text it
/// answered. A subclass that reads two endpoints, or shapes the rows, overrides it.</p>
ClassMethod Fetch(pArgs As %DynamicObject, ByRef pQuery, pLimit As %Integer, Output pRows As %DynamicArray, Output pCut As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pCut = 0
    Quit $ClassMethod(..PortClass(), "Invoke", $Piece(..#ENDPOINTS, ",", 1), "LIST", .pQuery, "", .pRows, .pHttpStatus, .pFault, .pCut)
}

/// <p>The most rows a call may answer: its <code>maxRows</code>, or <parameter>DEFAULTROWS</parameter> when it gave none, and never more
/// than <var>pCap</var>, the caller's row cap (AD-24).</p>
ClassMethod RowLimit(pArgs As %DynamicAbstractObject, pCap As %Integer) As %Integer
{
    Set tLimit = ..#DEFAULTROWS
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("maxRows") = "number") && $Match(pArgs.%Get("maxRows"), "^[1-9][0-9]*$") Set tLimit = pArgs.%Get("maxRows")
    Quit $Select(tLimit < pCap: +tLimit, 1: +pCap)
}

/// <p>The result: <code>{fields, rows, truncated}</code> as <method>View</method> answers it, and the three counts the dispatcher's
/// cutter adds to any rows-shaped result (AD-24).</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "fields": {"type": "array", "items": {"type": "string"}, "description": "The field names every row carries."},
            "rows": {"type": "array", "items": {"type": "object"}, "description": "One object per row, carrying exactly the fields."},
            "truncated": {"type": "boolean", "description": "True when more rows exist than were read, or when a text or a field value was cut."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "rowsAvailable": {"type": "integer", "description": "How many rows this read produced before the result was bounded."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["fields", "rows", "truncated"],
        "additionalProperties": false
    }
}

/// <p>Read through the port and answer the rows. <var>pArgs</var> is validated against <method>InputSchema</method> first; a refusal is
/// 400 <code>TOOL.ARGUMENTS</code> naming the argument and the rule, and no port is called. A port refusal is returned as the port's
/// own status, HTTP status and fault, with <var>pResult</var> empty.</p>
/// <p><var>pResult</var> is <code>{fields, rows, truncated}</code>: <parameter>FIELDS</parameter>, each row carrying exactly those keys,
/// at most <method>RowLimit</method> rows in the port's order, <code>truncated</code> true when the port held more or cut a text.</p>
/// <p>Caller contract: not called from an escalated frame (AD-9). The caller's namespace is read from
/// <method>OcuPilot.Kernel.Scope.Current</method> and not changed.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '$Match(pContextCap, "^[1-9][0-9]*$") {
            Set tSC = ..InternalRefusal("the context cap must be a whole number above zero", .pHttpStatus, .pFault)
            Quit
        }
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tLimit = ..RowLimit(tArgs, pContextCap)
        Kill tQuery
        Do ..Query(tArgs, .tQuery)
        Set tQuery("namespace") = ##class(OcuPilot.Kernel.Scope).Current()
        Set tQuery("maxRows") = tLimit + 1
        Set tSC = ..Fetch(tArgs, .tQuery, tLimit, .tSource, .tCut, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tSource) {
            Set tSC = ..InternalRefusal("the interoperability read answered no rows", .pHttpStatus, .pFault)
            Quit
        }

        Set tFields = []
        For tI = 1:1:$Length(..#FIELDS, ",") {
            Do tFields.%Push($Piece(..#FIELDS, ",", tI))
        }
        Set tRows = []
        Set tTruncated = ''tCut
        Set tIterator = tSource.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tSourceRow) {
            If tRows.%Size() >= tLimit {
                Set tTruncated = 1
                Quit
            }
            Set tRow = {}
            Set tFieldIterator = tFields.%GetIterator()
            While tFieldIterator.%GetNext(.tFieldIndex, .tField) {
                Set tType = tSourceRow.%GetTypeOf(tField)
                ; The hint is stated rather than copied, so a field the port stopped emitting is an empty string and not dropped.
                If (tType = "number") || (tType = "boolean") {
                    Do tRow.%Set(tField, tSourceRow.%Get(tField), tType)
                } Else {
                    Do tRow.%Set(tField, tSourceRow.%Get(tField) _ "", "string")
                }
            }
            Do tRows.%Push(tRow)
        }
        Set pResult = {}
        Do pResult.%Set("fields", tFields)
        Do pResult.%Set("rows", tRows)
        Do pResult.%Set("truncated", ''tTruncated, "boolean")
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the interoperability read tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
