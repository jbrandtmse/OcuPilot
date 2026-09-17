/// <p>The one read tool every read-declaring screen descriptor yields (AD-36). It has no class per
/// screen: <class>OcuPilot.Screen.Tool.Registry</class> registers
/// <code>&lt;toolIdentifier&gt;.read</code> for each descriptor that declares a read, and this class
/// answers for all of them, taking the descriptor as its first argument.</p>
/// <p><b>The tool's view is the screen's view, narrowed.</b> <method>View</method> runs the same
/// <method>OcuPilot.Screen.Read.Execute</method> the screen's route runs, under the screen's row cap,
/// the same <method>OcuPilot.Screen.Read.ApplyView</method> the screen's table applies, and then the
/// context cap. The descriptor's <code>context.secretFields</code> are already gone:
/// <method>OcuPilot.Screen.Read.Execute</method> strips them for the route and the tool alike. It
/// never issues a wider or separately written query.</p>
/// <p><b>A read that searches on the server carries its criteria into the tool</b> (AD-21). The
/// schema gains one property per declared criterion, named by the criterion's own query parameter,
/// and <method>View</method> passes those values to the same executor the route calls -- so the
/// model sends the search the screen sends, and neither can send a parameter the descriptor does
/// not declare.</p>
Class OcuPilot.Screen.Tool.Read Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

Parameter KIND = "read";

/// <p>The verb a read tool's name ends in.</p>
Parameter VERB = "read";

Parameter DESCRIPTION = "Read the rows the named screen lists, bounded and with secret fields removed.";

/// <p>The executor <method>View</method> reads through. Overridable so a fixture can reach
/// <class>OcuPilot.Test.PortFixture</class>; production never overrides it.</p>
ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Screen.Read"
}

/// <p>The most rows the executor reads when its caller names no cap: the cap a screen's read is
/// bounded by (<parameter>OcuPilot.Screen.Read.DEFAULTMAXROWS</parameter>).</p>
ClassMethod ReadCap() As %Integer
{
    Quit +$Parameter(..ReadClass(), "DEFAULTMAXROWS")
}

/// <p>The read tool's name for <var>pDescriptor</var>: its declared <code>toolIdentifier</code>
/// followed by <parameter>VERB</parameter>, never derived from its route (AD-5).</p>
ClassMethod NameFor(pDescriptor As %String) As %String
{
    Quit $ClassMethod(pDescriptor, "ToolIdentifier") _ "." _ ..#VERB
}

/// <p>The description the model is given: <parameter>DESCRIPTION</parameter> with the descriptor's
/// <code>toolIdentifier</code> in place of "the named screen", so each read tool says which screen it
/// reads.</p>
ClassMethod Description(pDescriptor As %String = "") As %String
{
    Quit $Replace(..#DESCRIPTION, "the named screen", "the " _ $ClassMethod(pDescriptor, "ToolIdentifier") _ " screen")
}

/// <p>What <var>pDescriptor</var> requires of the caller:
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method>, the screen's declared pairs unioned with its
/// classic page's custom resource, so the tool requires what the screen requires (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(pDescriptor, .pResolved)
}

/// <p>The result <method>View</method> answers: <code>{fields, rows, truncated}</code>.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "fields": {"type": "array", "items": {"type": "string"}, "description": "The read's field names, secret fields removed."},
            "rows": {"type": "array", "items": {"type": "object"}, "description": "One object per row, carrying exactly the fields."},
            "truncated": {"type": "boolean", "description": "True when rows were cut by a cap or a field value was shortened."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "rowsAvailable": {"type": "integer", "description": "How many rows matched, before any cap."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["fields", "rows", "truncated"],
        "additionalProperties": false
    }
}

/// <p>The input schema for <var>pDescriptor</var>'s read tool: optional <code>filter</code>
/// (string), <code>sort</code> (one of the declared <code>sort.fields</code>),
/// <code>direction</code> (<code>asc</code> or <code>desc</code>) and <code>maxRows</code> (an
/// integer of at least 1), <b>plus one property per declared server-search criterion</b> (AD-21),
/// and no other property. <code>""</code> when the descriptor declares no read.</p>
/// <p>A criterion is a string; a <code>choice</code> criterion additionally carries its declared
/// <code>options</code> as an <code>enum</code>, so the model cannot propose a value the executor
/// would refuse. The schema is closed (<code>additionalProperties: false</code>), so the tool's
/// search is exactly the screen's search -- one read, two callers (AD-36).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tRead = $ClassMethod(pDescriptor, "Read")
    If '$IsObject(tRead) Quit ""
    Set tSortFields = []
    Set tSort = tRead.%Get("sort")
    If $IsObject(tSort) && $IsObject(tSort.%Get("fields")) Set tSortFields = tSort.%Get("fields")
    Set tSchema = {
        "type": "object",
        "properties": {
            "filter": {"type": "string", "description": "Keep the rows whose filterable fields contain this text."},
            "sort": {"type": "string", "description": "The field to sort on."},
            "direction": {"type": "string", "enum": ["asc", "desc"], "description": "The sort direction."},
            "maxRows": {"type": "integer", "minimum": 1, "description": "The most rows to read before the filter and sort apply, as the screen's own row limit does. Absent, or above the screen's row cap, reads that cap."}
        },
        "required": [],
        "additionalProperties": false
    }
    Do tSchema.properties.sort.%Set("enum", tSortFields)
    Do ..AddCriteria(tRead, tSchema)
    Quit tSchema
}

/// <p>Add one property to <var>pSchema</var> per criterion <var>pRead</var> declares, named by the
/// criterion's own query parameter.</p>
/// <p>The description names the shape the instance expects, because the caller is a model and
/// "state the expected format explicitly in the parameter's description" is what keeps it from
/// guessing one: a name criterion is a comma list the vendor matches with <code>*</code>, and a
/// <code>datetime</code> one is the instance's own local <code>YYYY-MM-DD HH:MM:SS</code>, time
/// part included -- <method>OcuPilot.Screen.Read.SeedCriteria</method> refuses a date alone.</p>
ClassMethod AddCriteria(pRead As %DynamicObject, pSchema As %DynamicObject) [ Private ]
{
    Set tCriteria = pRead.%Get("criteria")
    If '$IsObject(tCriteria) || 'tCriteria.%IsA("%Library.DynamicObject") Quit
    Set tFields = tCriteria.%Get("fields")
    If '$IsObject(tFields) || 'tFields.%IsA("%Library.DynamicArray") Quit
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If '$IsObject(tField) Continue
        Set tParam = tField.%Get("param")
        If tParam = "" Continue
        Set tKind = tField.%Get("kind")
        Set tProperty = {"type": "string"}
        ; DW-279. Published rather than left implicit: the caller is a model, and a bound it cannot
        ; see is one it will exceed and then be refused for. `maxLength` is JSON Schema's own
        ; keyword, so it needs no description of its own.
        Set tMaxLength = tField.%Get("maxLength")
        If tMaxLength > 0 Do tProperty.%Set("maxLength", tMaxLength, "number")
        If tKind = "datetime" {
            Do tProperty.%Set("description", "A server-search criterion, as instance local time in the form YYYY-MM-DD HH:MM:SS. The time part is required; a date alone is refused before the search runs. Omit it to leave that bound unset.")
        } ElseIf tKind = "choice" {
            Do tProperty.%Set("description", "A server-search criterion. One of the listed values, spelled exactly; any other value is refused before the search runs.")
            Do tProperty.%Set("enum", ##class(%DynamicAbstractObject).%FromJSON(tField.%Get("options").%ToJSON()))
        } Else {
            Do tProperty.%Set("description", "A server-search criterion, as a comma-separated list of names. * matches any name. Omit it to match every name.")
        }
        Do pSchema.properties.%Set(tParam, tProperty)
    }
}

/// <p>The tool's view of <var>pDescriptor</var>'s read. <var>pArgs</var> is validated against
/// <method>InputSchema</method> before anything is read; a refusal is 400
/// <code>TOOL.ARGUMENTS</code> naming the argument and the rule, and no port is called.
/// <var>pContextCap</var> is the row cap on what the tool returns (AD-24), supplied by the caller;
/// it is a whole number above zero.</p>
/// <p><b>It reads what the screen reads, then narrows it</b> (AD-36). The executor is asked for the
/// model's <code>maxRows</code> or the read's own row cap (<method>ReadCap</method>), whichever is
/// smaller -- the rows a screen at that row limit reads -- so the filter and sort run over those
/// rows, and only then is the result cut to <var>pContextCap</var>.</p>
/// <p><var>pResult</var> is <code>{fields, rows, truncated}</code>: the read's fields and rows as
/// <method>OcuPilot.Screen.Read.Execute</method> answers them, secret fields already removed, at
/// most <var>pContextCap</var> rows in <method>OcuPilot.Screen.Read.ApplyView</method>'s order, and
/// <code>truncated</code> true when the read truncated or the context cap cut rows. A read failure is
/// returned as the executor's status, HTTP status and fault, with <var>pResult</var> empty.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tRead = $ClassMethod(pDescriptor, "Read")
        If '$IsObject(tRead) {
            Set tSC = ..InternalRefusal(pDescriptor _ " declares no read", .pHttpStatus, .pFault)
            Quit
        }
        If '$Match(pContextCap, "^[1-9][0-9]*$") {
            Set tSC = ..InternalRefusal("the context cap must be a whole number above zero", .pHttpStatus, .pFault)
            Quit
        }
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(pDescriptor), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }

        ; The declared roster again (AD-21): a criterion reaches the executor only where the
        ; descriptor names it, which is the same allow-list the route is filtered through, so the
        ; tool cannot search wider than the screen.
        Kill tCriteria
        Set tParams = $ClassMethod(..ReadClass(), "CriteriaParams", pDescriptor)
        For tI = 1:1:$ListLength(tParams) {
            Set tParam = $List(tParams, tI)
            Set tCriteria(tParam) = tArgs.%Get(tParam)
        }
        Set tSC = $ClassMethod(..ReadClass(), "Execute", pDescriptor, ..BoundedMaxRows(tArgs, ..ReadCap()), .tFetched, .pHttpStatus, .pFault, .tCriteria)
        If $$$ISERR(tSC) Quit

        Set tView = $ClassMethod(..ReadClass(), "ApplyView", tFetched.rows, tRead, tArgs.%Get("filter"), tArgs.%Get("sort"), tArgs.%Get("direction"))

        Set tRows = []
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRows.%Size() = +pContextCap Quit
            Do tRows.%Push(tRow)
        }

        Set pResult = {}
        Do pResult.%Set("fields", tFetched.fields)
        Do pResult.%Set("rows", tRows)
        Do pResult.%Set("truncated", ''tFetched.truncated || (tView.%Size() > +pContextCap), "boolean")
        ; The real count before this cut, so the kernel cutter downstream (AD-24) can report a
        ; true rowsAvailable rather than one already narrowed by this method's own cap.
        Do pResult.%Set("rowsAvailable", tView.%Size(), "number")
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the read tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
