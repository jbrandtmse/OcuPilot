/// <p>The one read tool every read-declaring screen descriptor yields (AD-36). It has no class per
/// screen: <class>OcuPilot.Screen.Tool.Registry</class> registers
/// <code>&lt;toolIdentifier&gt;.read</code> for each descriptor that declares a read, and this class
/// answers for all of them, taking the descriptor as its first argument.</p>
/// <p><b>The tool's view is the screen's view, narrowed.</b> <method>View</method> runs the same
/// <method>OcuPilot.Screen.Read.Execute</method> the screen's route runs and the same
/// <method>OcuPilot.Screen.Read.ApplyView</method> the screen's table applies, then keeps the first
/// <var>pContextCap</var> rows. The descriptor's <code>context.secretFields</code> are already gone:
/// <method>OcuPilot.Screen.Read.Execute</method> strips them for the route and the tool alike. It
/// never issues a wider or separately written query.</p>
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

/// <p>The read tool's name for <var>pDescriptor</var>: its declared <code>toolIdentifier</code>
/// followed by <parameter>VERB</parameter>, never derived from its route (AD-5).</p>
ClassMethod NameFor(pDescriptor As %String) As %String
{
    Quit $ClassMethod(pDescriptor, "ToolIdentifier") _ "." _ ..#VERB
}

/// <p>The input schema for <var>pDescriptor</var>'s read tool: optional <code>filter</code>
/// (string), <code>sort</code> (one of the declared <code>sort.fields</code>),
/// <code>direction</code> (<code>asc</code> or <code>desc</code>) and <code>maxRows</code> (an
/// integer of at least 1), and no other property. <code>""</code> when the descriptor declares no
/// read.</p>
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
            "maxRows": {"type": "integer", "minimum": 1, "description": "The most rows to read."}
        },
        "required": [],
        "additionalProperties": false
    }
    Do tSchema.properties.sort.%Set("enum", tSortFields)
    Quit tSchema
}

/// <p>The tool's view of <var>pDescriptor</var>'s read. <var>pArgs</var> is validated against
/// <method>InputSchema</method> before anything is read; a refusal is an error status naming the
/// argument and the rule, and no port is called. <var>pContextCap</var> is the row cap on what
/// the tool returns (AD-24), supplied by the caller; it is a whole number above zero.</p>
/// <p><var>pResult</var> is <code>{fields, rows, truncated}</code>: the read's fields and rows as
/// <method>OcuPilot.Screen.Read.Execute</method> answers them, secret fields already removed, at
/// most <var>pContextCap</var> rows in
/// <method>OcuPilot.Screen.Read.ApplyView</method>'s order, and <code>truncated</code> true when the
/// read truncated or the cap cut rows. A read failure is returned as its error status, with
/// <var>pResult</var> empty.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicObject, pContextCap As %Integer, Output pResult As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tRead = $ClassMethod(pDescriptor, "Read")
        If '$IsObject(tRead) {
            Set tSC = $$$ERROR($$$GeneralError, pDescriptor _ " declares no read")
            Quit
        }
        If '$Match(pContextCap, "^[1-9][0-9]*$") {
            Set tSC = $$$ERROR($$$GeneralError, "the context cap must be a whole number above zero")
            Quit
        }
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(pDescriptor), tArgs, .tProblem)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..ReadClass(), "Execute", pDescriptor, tArgs.%Get("maxRows"), .tFetched, .tHttp, .tFault)
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
    } Catch ex {
        Set pResult = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
