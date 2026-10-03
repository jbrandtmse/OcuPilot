/// <p>SQL query's confirmed run (Story 19.6, AD-6, AD-10, AD-51, AD-53): one statement that changes
/// data, the schema or calls a procedure, run by <class>OcuPilot.Port.SqlPort</class> in the
/// namespace the console is scoped to, once the person has confirmed the dialog the console's run
/// route asked for. Its target is the literal <code>sql</code> under <code>class</code> in that
/// namespace (AD-13), which serializes console writes per namespace (AD-34).</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): the
/// provider's tool list, the dispatch lookup and the screen context's <code>tools</code> never carry
/// it, and its baseline key ships disabled; a person's own run is never asked governance (AD-22).</p>
/// <p><b>The statement, its values and its row cap are screen values</b>
/// (<parameter>SCREENVALUES</parameter>), checked and bounded by <method>ScreenActionDelta</method>.
/// The port classifies the statement again at the write and refuses a statement that only reads
/// (<code>EXPLORER.SQL.READS</code>), and the kernel judges it by
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method> inside the target's hold.</p>
/// <p><b>It is destructive</b>: a change made by SQL cannot be undone from OcuPilot. It declares no
/// pair beyond its screen's own (AD-8): the statement's SQL privileges are checked at its prepare, and
/// the databases it writes are the instance's to refuse. Its answer -- rows, a row count, an SQL error
/// -- reaches the screen only (<method>WriteOutput</method>, AD-39's sixth exception). It declares no
/// <parameter>CLASSICPAGES</parameter>: the descriptor's own classic page performs it (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlRun Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.sqlquery.run";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

Parameter DESCRIPTION = "Run one SQL statement that changes data, the schema or calls a procedure, as SQL query's Run does once confirmed. A person's own confirmed run reaches this tool; it is never offered to the agent.";

/// <p>Reached by a person's confirmed Run alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The port that classifies and runs the statement (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

Parameter SCREENACTIONS = "run";

Parameter SCREENVALUES = "run=statement:parameters:maxRows";

/// <p>The fresh read: the statement's guard, with the three declared values empty beside it.</p>
Parameter READTYPE = "GUARD";

Parameter WRITETYPE = "RUN";

/// <p>No body: the port runs the statement the declared values carry.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a change made by SQL cannot be undone from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Kind";

/// <p>A run acts on a statement of the kind the guard read.</p>
Parameter PRECONDITIONFIELD = "Kind";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Kind,StatementType,Tables,RecordsTables,Parameters,Columns,DefaultSchema,statement,parameters,maxRows";

/// <p>The namespace, the statement's kind, type and tables, and the statement, values and row cap
/// run.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Kind,StatementType,Tables,statement,parameters,maxRows";

/// <p>The argument naming the target, whose one value is the port's
/// <parameter>OcuPilot.Port.SqlPort.IDVALUE</parameter>.</p>
Parameter IDARGUMENT = "Target";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTSQL
}

ClassMethod IdArgument() As %String
{
    Quit ..#IDARGUMENT
}

/// <p>The query key the port reads the target from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#IDKEY
}

/// <p>The screen's own pairs, the classic SQL page's custom resource among them, and nothing beyond
/// them (AD-8, AD-44): the statement's SQL privileges are checked at its prepare.
/// <var>pResolved</var> is 0 when the screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>The three declared values the port reads beyond the target.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.SqlPort).#STATEMENTKEY, ##class(OcuPilot.Port.SqlPort).#PARAMETERSKEY, ##class(OcuPilot.Port.SqlPort).#MAXROWSKEY)
}

/// <p>The schema: the statement, its values and its row cap, and the agent's own words.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(##class(OcuPilot.Port.SqlPort).#STATEMENTKEY, {"type": "string", "description": "One SQL statement, 1 to 100,000 characters, with a ? where each value goes."})
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.SqlPort).#STATEMENTKEY)
    Do tProperties.%Set(##class(OcuPilot.Port.SqlPort).#PARAMETERSKEY, {"type": "array", "items": {"type": "string"}, "description": "One value for each ? that takes a value, in order, at most 100, each at most 32,767 characters."})
    Do tProperties.%Set(##class(OcuPilot.Port.SqlPort).#MAXROWSKEY, {"type": "integer", "description": "The most rows a result set shows, from 1 to 1,000."})
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The screen's three values as this tool's arguments (AD-56 (ii)): <code>statement</code> as
/// sent, <code>parameters</code> from JSON array text to an array of strings, and
/// <code>maxRows</code> from digits to a number, each held to <method>OcuPilot.Port.SqlPort.InputProblem</method>'s
/// bounds; any other spelling is refused.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tPort = "OcuPilot.Port.SqlPort"
    Set tText = ""
    Set tValuesText = ""
    Set tMaxRows = ""
    If $IsObject(pValues) {
        If pValues.%GetTypeOf($Parameter(tPort, "STATEMENTKEY")) = "string" Set tText = pValues.%Get($Parameter(tPort, "STATEMENTKEY"))
        If pValues.%GetTypeOf($Parameter(tPort, "PARAMETERSKEY")) = "string" Set tValuesText = pValues.%Get($Parameter(tPort, "PARAMETERSKEY"))
        If pValues.%GetTypeOf($Parameter(tPort, "MAXROWSKEY")) = "string" Set tMaxRows = pValues.%Get($Parameter(tPort, "MAXROWSKEY"))
    }
    Set tValues = ##class(OcuPilot.Port.SqlPort).ValuesFrom(tValuesText, .tReadable)
    If (tValuesText = "") || 'tReadable {
        Set pProblem = "'" _ $Parameter(tPort, "PARAMETERSKEY") _ "' is a JSON array of strings"
        Quit $$$OK
    }
    If tMaxRows = "" {
        Set pProblem = "'" _ $Parameter(tPort, "MAXROWSKEY") _ "' is a whole number from 1 to 1,000"
        Quit $$$OK
    }
    Set tField = ##class(OcuPilot.Port.SqlPort).InputProblem(tText, tValues, tMaxRows)
    If tField = "statement" {
        Set pProblem = "'" _ $Parameter(tPort, "STATEMENTKEY") _ "' is 1 to 100,000 characters"
        Quit $$$OK
    }
    If tField = "parameters" {
        Set pProblem = "'" _ $Parameter(tPort, "PARAMETERSKEY") _ "' holds at most 100 strings, each at most 32,767 characters"
        Quit $$$OK
    }
    If tField '= "" {
        Set pProblem = "'" _ $Parameter(tPort, "MAXROWSKEY") _ "' is a whole number from 1 to 1,000"
        Quit $$$OK
    }
    Do pArgs.%Set($Parameter(tPort, "STATEMENTKEY"), tText, "string")
    Do pArgs.%Set($Parameter(tPort, "PARAMETERSKEY"), tValues)
    Do pArgs.%Set($Parameter(tPort, "MAXROWSKEY"), +tMaxRows, "number")
    Quit $$$OK
}

/// <p>The namespace, the statement, its values as JSON array text and its row cap, from the payload
/// <var>pPayload</var> under the port's own query keys, so the write runs what the person confirmed
/// where the guard read it (AD-52). A fresh read, whose payload is empty, is scoped by the port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.SqlPort"
    If (pPayload.%GetTypeOf("Namespace") = "string") && (pPayload.%Get("Namespace") '= "") Set pQuery($Parameter(tPort, "NAMESPACEKEY")) = pPayload.%Get("Namespace")
    If (pPayload.%GetTypeOf($Parameter(tPort, "STATEMENTKEY")) = "string") && (pPayload.%Get($Parameter(tPort, "STATEMENTKEY")) '= "") Set pQuery($Parameter(tPort, "STATEMENTKEY")) = pPayload.%Get($Parameter(tPort, "STATEMENTKEY"))
    If pPayload.%GetTypeOf($Parameter(tPort, "PARAMETERSKEY")) = "array" Set pQuery($Parameter(tPort, "PARAMETERSKEY")) = pPayload.%Get($Parameter(tPort, "PARAMETERSKEY")).%ToJSON()
    If pPayload.%GetTypeOf($Parameter(tPort, "MAXROWSKEY")) = "number" Set pQuery($Parameter(tPort, "MAXROWSKEY")) = pPayload.%Get($Parameter(tPort, "MAXROWSKEY"))
}

/// <p>The state the run moves: the statement's kind and the tables the instance records for it, read
/// by the guard.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) Quit $$$OK
    Set tTables = ""
    If pFresh.%GetTypeOf("Tables") = "array" {
        Set tIterator = pFresh.%Get("Tables").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTable) {
            Set tTables = tTables _ $Select(tTables = "": "", 1: ", ") _ tTable
        }
    }
    For tPair = $ListBuild("Kind", pFresh.%Get("Kind")), $ListBuild("Tables", tTables) {
        Set tRow = {}
        Do tRow.%Set("field", $List(tPair, 1), "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", $List(tPair, 2), "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>What the screen shows of the run the port answered <var>pWritten</var> for: its outcome
/// object, or <code>""</code>. Never stored, logged or put on the ledger, and never sent to the model
/// (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("outcome") '= "string" Quit ""
    Quit pWritten
}

}
