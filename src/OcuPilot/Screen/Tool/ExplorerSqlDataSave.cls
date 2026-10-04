/// <p>Data browser's Save (Story 19.8, AD-6, AD-10, AD-51, AD-53): the grid's staged rows -- each an
/// update guarded by the values read, an insert or a delete by key -- saved by
/// <class>OcuPilot.Port.SqlPort</class> in the namespace the screen is scoped to, once the person has
/// confirmed the save dialog. Its target is the literal <code>sql</code> under <code>class</code> in
/// that namespace (AD-13), the console's, so a save and a console run in one namespace serialize
/// (AD-34).</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): a row's
/// values never reach the model (AD-36), so the provider's tool list, the dispatch lookup and the
/// screen context's <code>tools</code> never carry it, and its baseline key ships disabled; a person's
/// own Save is never asked governance (AD-22).</p>
/// <p><b>The schema, the table and the changes are screen values</b> (<parameter>SCREENVALUES</parameter>),
/// checked and bounded by <method>ScreenActionDelta</method>. The payload's <code>statement</code> is
/// the table's delimited name, which the kernel's prohibited set judges first, and then the tables the
/// fresh read resolves for it, a view's base tables among them
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>), inside the target's hold.</p>
/// <p><b>It is destructive</b>: a saved row cannot be put back from OcuPilot. It declares no pair
/// beyond its screen's own (AD-8): each statement's SQL privileges are the instance's at its prepare.
/// It declares no <parameter>CLASSICPAGES</parameter> (AD-44). Its answer -- each row's outcome,
/// SQLCODE and message -- reaches the screen only (<method>WriteOutput</method>, AD-39's sixth
/// exception).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlDataSave Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.sqldata.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlData";

Parameter DESCRIPTION = "Save the data browser's staged row changes to one table, as Data browser's Save does once confirmed. A person's own confirmed save reaches this tool; it is never offered to the agent.";

/// <p>Reached by a person's confirmed Save alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The port that plans the table and saves the rows (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

Parameter SCREENACTIONS = "save";

Parameter SCREENVALUES = "save=schema:table:changes";

/// <p>The fresh read: the plan of the table the payload names. A screen action's fresh read carries
/// no payload, so it answers the empty plan after the gate; the table is planned inside the
/// prohibited check and again by the save.</p>
Parameter READTYPE = "PLAN";

Parameter WRITETYPE = "RUN";

/// <p>No body: the port composes each row's statement from the declared values.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a saved row cannot be put back from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Kind";

/// <p>A save acts on a table of the kind the plan read.</p>
Parameter PRECONDITIONFIELD = "Kind";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Kind,Tables,RecordsTables,DefaultSchema,statement,schema,table,changes";

/// <p>The namespace, the table's kind and tables, and the statement, table and changes saved.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Kind,Tables,statement,schema,table,changes";

/// <p>The argument naming the target, whose one value is the port's
/// <parameter>OcuPilot.Port.SqlPort.IDVALUE</parameter>.</p>
Parameter IDARGUMENT = "Target";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTDATA
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

/// <p>The screen's own pairs, the classic Open Table page's custom resource among them, and nothing
/// beyond them (AD-8, AD-44): each statement's SQL privileges are the instance's to check.
/// <var>pResolved</var> is 0 when the screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>The four values the port reads beyond the target: the statement the prohibited set judges,
/// and the schema, table and changes the save composes from.</p>
ClassMethod SettableFields() As %List
{
    Set tPort = "OcuPilot.Port.SqlPort"
    Quit $ListBuild($Parameter(tPort, "STATEMENTKEY"), $Parameter(tPort, "SCHEMAKEY"), $Parameter(tPort, "TABLEKEY"), $Parameter(tPort, "CHANGESKEY"))
}

/// <p>The schema: the table's schema and name, the changes as JSON array text, and the agent's own
/// words.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tPort = "OcuPilot.Port.SqlPort"
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set($Parameter(tPort, "SCHEMAKEY"), {"type": "string", "description": "The table's schema, as the catalog spells it."})
    Do tProperties.%Set($Parameter(tPort, "TABLEKEY"), {"type": "string", "description": "The table's name, as the catalog spells it."})
    Do tProperties.%Set($Parameter(tPort, "CHANGESKEY"), {"type": "string", "description": "The staged rows as JSON array text, 1 to 100 changes, each an update with its key, the values read and the values set, an insert with its values, or a delete with its key."})
    For tKey = $Parameter(tPort, "SCHEMAKEY"), $Parameter(tPort, "TABLEKEY"), $Parameter(tPort, "CHANGESKEY") {
        Do tSchema.%Get("required").%Push(tKey)
    }
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Quit tSchema
}

/// <p>The screen's three values as this tool's arguments (AD-56 (ii)): <code>schema</code> and
/// <code>table</code> held to <method>OcuPilot.Port.SqlPort.BrowseName</method>, as the data
/// browser's read holds them, and <code>changes</code> from JSON array text to an array held to
/// <method>OcuPilot.Port.SqlPort.SaveChanges</method>'s bounds; any other spelling is refused. The
/// arguments add <code>statement</code>, the table's delimited name
/// (<method>OcuPilot.Port.SqlPort.Quoted</method>), which the prohibited set judges first.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tPort = "OcuPilot.Port.SqlPort"
    Set tSchema = ""
    Set tTable = ""
    Set tText = ""
    If $IsObject(pValues) {
        If pValues.%GetTypeOf($Parameter(tPort, "SCHEMAKEY")) = "string" Set tSchema = pValues.%Get($Parameter(tPort, "SCHEMAKEY"))
        If pValues.%GetTypeOf($Parameter(tPort, "TABLEKEY")) = "string" Set tTable = pValues.%Get($Parameter(tPort, "TABLEKEY"))
        If pValues.%GetTypeOf($Parameter(tPort, "CHANGESKEY")) = "string" Set tText = pValues.%Get($Parameter(tPort, "CHANGESKEY"))
    }
    If '##class(OcuPilot.Port.SqlPort).BrowseName(tSchema) || '##class(OcuPilot.Port.SqlPort).BrowseName(tTable) {
        Set pProblem = "'" _ $Parameter(tPort, "SCHEMAKEY") _ "' and '" _ $Parameter(tPort, "TABLEKEY") _ "' are names of 1 to 128 characters with no control character"
        Quit $$$OK
    }
    If '##class(OcuPilot.Port.SqlPort).SaveChanges(tText, .tChanges, .tProblem) {
        Set pProblem = tProblem
        Quit $$$OK
    }
    Do pArgs.%Set($Parameter(tPort, "STATEMENTKEY"), ##class(OcuPilot.Port.SqlPort).Quoted(tSchema) _ "." _ ##class(OcuPilot.Port.SqlPort).Quoted(tTable), "string")
    Do pArgs.%Set($Parameter(tPort, "SCHEMAKEY"), tSchema, "string")
    Do pArgs.%Set($Parameter(tPort, "TABLEKEY"), tTable, "string")
    Do pArgs.%Set($Parameter(tPort, "CHANGESKEY"), tChanges)
    Quit $$$OK
}

/// <p>The namespace, the schema, the table and the changes as JSON array text, from the payload
/// <var>pPayload</var> under the port's own query keys, so the save writes what the person confirmed
/// where the plan read it (AD-52). A fresh read, whose payload is empty, is scoped by the port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.SqlPort"
    If (pPayload.%GetTypeOf("Namespace") = "string") && (pPayload.%Get("Namespace") '= "") Set pQuery($Parameter(tPort, "NAMESPACEKEY")) = pPayload.%Get("Namespace")
    For tKey = $Parameter(tPort, "SCHEMAKEY"), $Parameter(tPort, "TABLEKEY") {
        If (pPayload.%GetTypeOf(tKey) = "string") && (pPayload.%Get(tKey) '= "") Set pQuery(tKey) = pPayload.%Get(tKey)
    }
    Set tChanges = $Parameter(tPort, "CHANGESKEY")
    If pPayload.%GetTypeOf(tChanges) = "array" Set pQuery(tChanges) = pPayload.%Get(tChanges).%ToJSON()
    If pPayload.%GetTypeOf(tChanges) = "string" Set pQuery(tChanges) = pPayload.%Get(tChanges)
}

/// <p>The state the save moves: the table's kind and the tables the plan resolves for it, as the
/// fresh read answers them, which are empty for a screen action's fresh read
/// (<parameter>READTYPE</parameter>).</p>
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

/// <p>What the screen shows of the save the port answered <var>pWritten</var> for: its outcome object,
/// each row's result in it, or <code>""</code>. Never stored, logged or put on the ledger, and never
/// sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("outcome") '= "string" Quit ""
    Quit pWritten
}

}
