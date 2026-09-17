/// <p>The application error log's read tool, and the registry's <b>second</b> source: a tool with a
/// class of its own rather than a descriptor-derived one (AD-36,
/// <class>OcuPilot.Screen.Tool.Registry</class>'s "two sources, one list").
/// <class>OcuPilot.Screen.Descriptor.LogErrorList</class> declares no <code>read</code> -- the
/// declared-read pipeline is admin-port-only by two independent hard-codings and could not serve
/// this source -- so its tool is declared here instead, with its own <code>TOOLNAME</code>,
/// <code>KIND</code> and input schema.</p>
/// <p><b>It reads through the same entry point the list route reads through</b>:
/// <method>OcuPilot.Port.LogSourcePort.Errors</method> at its <code>list</code> level. "One read,
/// two callers" (AD-36) is met at the port, which is where this source's read actually lives,
/// rather than at a descriptor grammar that cannot express three drill levels.</p>
/// <p><b>Five fields, and the captured detail is not reachable from here at all</b> (AD-48). The
/// payload carries <code>errorNumber</code>, <code>time</code>, <code>errorText</code>,
/// <code>routine</code> and <code>line</code> -- the summary set AD-48 names -- and drops the
/// screen-only <code>username</code> and <code>process</code>, so the tool's view is the screen's
/// narrowed and never wider. The variable table is not filtered out of this answer: it is never
/// fetched, because the summary path calls <code>ErrorList</code> and
/// <code>ErrorDetail</code> is reachable only from the detail route. A user reads that table on
/// screen; the agent does not.</p>
/// <p><b>It answers the one tool contract</b> (<class>OcuPilot.Screen.Tool.Base</class>): its pairs
/// are its descriptor's plus the named namespace's, the dispatcher checks both against the caller's
/// current grants, and the port's own per-namespace gate still decides whether the read may run
/// (AD-8, AD-29). A port refusal reaches the caller as the port's own HTTP status and fault.</p>
Class OcuPilot.Screen.Tool.ErrorRead Extends OcuPilot.Screen.Tool.Base
{

/// <p>The tool's name, <code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code> in lower case
/// (Conventions, Tool naming). It is <b>not</b>
/// <code>&lt;toolIdentifier&gt;.read</code> by derivation -- a class tool declares its own name --
/// but it is spelled to match the descriptor's <code>toolIdentifier</code>, so a reader looking for
/// this screen's tool finds one name and not two.</p>
Parameter TOOLNAME = "logs.applicationerrors.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Read one namespace and date's application errors, bounded, with the summary fields only: error number, time, error text, routine and code line. The captured variable table is never returned.";

/// <p>The screen this tool reads for. Its pairs are this tool's (<method>PrivilegePairs</method>);
/// its rows are not, because this tool's rows come from the port rather than from a declared
/// read.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LogErrorList";

/// <p>The port this tool reads through. Overridable so a fixture can count what the tool executes;
/// production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.LogSourcePort"
}

/// <p>The summary fields this tool's rows carry, comma-separated and in the order AD-48 names them.
/// A field outside this list is dropped from the port's row, so widening the port's projection
/// cannot widen the tool's answer.</p>
Parameter SUMMARYFIELDS = "errorNumber,time,errorText,routine,line";

/// <p>The tool's input schema: the namespace and the date the caller drilled to, both required
/// because this source has no default scope, and an optional <code>maxRows</code>.</p>
/// <p>The descriptions name the shape the instance expects, because the caller is a model: the
/// namespace is one the instance's own enumeration answered with, and the date is the string the
/// instance emitted for that namespace, byte for byte. Neither is a value a caller may invent --
/// the port refuses anything its own enumerations do not carry -- and neither is ever concatenated
/// into a query (AD-21).</p>
/// <p><var>pDescriptor</var> is ignored: a tool with a class of its own derives nothing from a
/// descriptor.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "namespace": {"type": "string", "description": "The namespace to read errors for, exactly as this instance's own namespace list reports it. A namespace it does not report is refused."},
            "date": {"type": "string", "description": "The date to read errors for, exactly as this instance's own date list reports it for that namespace (MM/DD/YYYY in the instance's clock). A date it does not report is refused."},
            "maxRows": {"type": "integer", "minimum": 1, "description": "The most rows to read. Absent, or above the tool's row cap, reads the cap."}
        },
        "required": ["namespace", "date"],
        "additionalProperties": false
    }
}

/// <p>What the caller must hold: <parameter>DESCRIPTORCLASS</parameter>'s pairs, unioned with its
/// classic page's custom resource (<method>OcuPilot.Screen.Gate.RequiredPairs</method>).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>What a call naming <var>pArgs</var>'s <code>namespace</code> requires beyond
/// <method>PrivilegePairs</method>: the pairs <method>OcuPilot.Port.LogSourcePort.PairsFor</method>
/// answers for that namespace, the database pairs included, so the dispatcher checks them against
/// the caller's current grants before the port runs (AD-8, AD-31, AD-48).</p>
/// <p>A namespace whose requirement the instance cannot resolve adds no pair here, and is not
/// admitted by that: the port refuses it by its own enumeration and gate before it reads
/// anything.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ##class(OcuPilot.Port.LogSourcePort).PairsFor(##class(OcuPilot.Port.LogSourcePort).#ERRORSKEY, pArgs.%Get("namespace"))
}

/// <p>The result <method>View</method> answers: <code>{fields, rows, truncated}</code>, the fields
/// being <parameter>SUMMARYFIELDS</parameter>. Dispatched through the kernel cutter like any other
/// rows-shaped read result (AD-24, DW-281), so the answer a caller actually sees also carries
/// <code>rowsSent</code>, <code>rowsAvailable</code> and <code>truncatedFields</code>.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "fields": {"type": "array", "items": {"type": "string"}, "description": "The five summary field names."},
            "rows": {"type": "array", "items": {"type": "object"}, "description": "One object per error, carrying exactly the summary fields."},
            "truncated": {"type": "boolean", "description": "True when rows were cut by a cap or a field value was shortened."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "rowsAvailable": {"type": "integer", "description": "How many rows this read produced before the result was bounded. The log is asked for no more than the row cap, so this is not a count of the whole log."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["fields", "rows", "truncated"],
        "additionalProperties": false
    }
}

/// <p>The tool's view of one namespace and date's errors. <var>pArgs</var> is validated against
/// <method>InputSchema</method> before anything is read; a refusal is 400
/// <code>TOOL.ARGUMENTS</code> naming the argument and the rule, and no port is called.
/// <var>pContextCap</var> is the row cap on what the tool returns (AD-24), supplied by the caller;
/// it is a whole number above zero. <var>pDescriptor</var> is ignored.</p>
/// <p>The port is asked for the model's <code>maxRows</code> or the cap, whichever is smaller
/// (DW-298).</p>
/// <p><var>pResult</var> is <code>{fields, rows, truncated}</code>: the five summary fields, each
/// row carrying exactly those keys, at most <var>pContextCap</var> rows in the port's own
/// newest-first order, and <code>truncated</code> true when the port truncated or the cap cut rows.
/// A port refusal is returned as the port's status, HTTP status and fault, with
/// <var>pResult</var> empty.</p>
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

        Set tSC = $ClassMethod(..PortClass(), "Errors", ##class(OcuPilot.Port.LogSourcePort).#LEVELLIST, tArgs.%Get("namespace"), tArgs.%Get("date"), "", ..BoundedMaxRows(tArgs, pContextCap), .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tAnswer) {
            Set tSC = ..InternalRefusal("the application error log answered no payload", .pHttpStatus, .pFault)
            Quit
        }

        Set tFields = []
        For tI = 1:1:$Length(..#SUMMARYFIELDS, ",") {
            Do tFields.%Push($Piece(..#SUMMARYFIELDS, ",", tI))
        }
        Set tRows = []
        Set tTruncated = ''tAnswer.%Get("truncated")
        Set tIterator = tAnswer.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tSourceRow) {
            If tRows.%Size() >= pContextCap {
                Set tTruncated = 1
                Quit
            }
            Set tRow = {}
            Set tFieldIterator = tFields.%GetIterator()
            While tFieldIterator.%GetNext(.tFieldIndex, .tField) {
                ; The hint is stated rather than copied from the source row: a field the port
                ; stopped emitting would otherwise be typed "unassigned" and dropped, which would
                ; shrink the key set this tool's own test pins.
                If tSourceRow.%GetTypeOf(tField) = "number" {
                    Do tRow.%Set(tField, +tSourceRow.%Get(tField), "number")
                } Else {
                    Do tRow.%Set(tField, tSourceRow.%Get(tField), "string")
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
        Set tSC = ..InternalRefusal("the application error read tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
