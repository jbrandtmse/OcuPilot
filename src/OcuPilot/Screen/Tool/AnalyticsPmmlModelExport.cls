/// <p>Analytics' PMML export to a cube (AD-3, AD-6, AD-7, AD-51, AD-52, AD-53, AD-56, AD-58, AD-61, AD-65, Story 24.14 Batch 4): the classic Model Tester's Export test results to cube, as a confirmed write of one PMML model. Two callers
/// reach it: the Test screen's Export to cube, whose values are the test's source and the four names, and the agent's proposal and confirmation.</p>
/// <p><b>It runs the model's own test and makes new classes.</b> In the confirmed request it tests the model again with the person's rights against the chosen source, copies the test's rows into a new persistent result class, and saves a new
/// cube class that reads them, restricted to that test. It never builds the cube: building stays the Cube manager's Build. It refuses a result class, cube class, package or cube that is held, so it never overwrites anything, and it puts back every class
/// it saved when a later step fails (<class>OcuPilot.Port.AnalyticsPort</class>, <method>OcuPilot.Port.AnalyticsPort.PerformPmmlExport</method>).</p>
/// <p><b>The target is the model</b>, its composite id <code>[Class, Model]</code>, kept exactly (AD-13). <b>The fresh read is the port's <code>PMMLEXPORT</code></b>, composed for the action at the mint and at a screen action
/// (<method>PortQuery</method>): the write's own refusals are made before anything is proposed, and the model's row answers the names the namespace holds, empty for a free name. The stored payload carries <code>Held</code>, so the confirm's
/// re-read answers the row, and a name taken since the review moves the payload and closes the proposal as target-changed.</p>
/// <p><b>It declares</b> the screen's own pairs, WRITE on the resource guarding the database <code>^DeepSee.Fact</code> maps to, the source code API's pairs and the pairs <code>AtelierPort.WritePairs</code> names for the namespace (the write saves,
/// compiles and deletes a class, which is WRITE on the routines database), and READ on the routines database, each refused by name before any port call (AD-8, AD-44). The vendor checks none of them.</p>
/// <p><b>The answer reaches the screen only</b> (<method>WriteOutput</method>, AD-39's fifth exception): the three names and the number of rows copied, stored nowhere and never sent to the model.</p>
Class OcuPilot.Screen.Tool.AnalyticsPmmlModelExport Extends OcuPilot.Screen.Tool.AnalyticsAction
{

Parameter TOOLNAME = "analytics.pmmlmodel.export";

Parameter DESCRIPTION = "Propose exporting one PMML model's test results to a new cube, in the namespace the user is working in. The model is tested again with the user's rights against one of its data sources, its verification records or one SQL query; the results are copied into a new result class, and a new cube class reads them. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the model as analytics.pmmlmodels.read reports it, its Class, then two vertical bars and its Model, and give the test's source in `Source` (dataset, verification or custom), with `DataSource` for a dataset and `SQL` for a custom query. Give the new result class in `ResultClass`, the new cube class in `CubeClass` and the cube's name in `Cube`; the classic defaults are the model's class and name followed by .Result and .ResultCube, and ModelTestResults. `SourceClass`, optional, is a class of the namespace the result rows link to. The cube is not built; the Cube manager builds it. A result class, cube class or package the namespace already holds, a cube it already holds, a class name that is malformed or begins with % or OcuPilot, two classes where one is in the other's package, a cube name over 250 characters or holding a control character or a } character, a class to link to that the namespace does not hold, and a test that does not finish are refused. OcuPilot cannot undo an export.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest";

Parameter CLASSICPAGES = "%DeepSee.PMML.UI.ModelTester";

Parameter SCREENACTIONS = "export";

/// <p>The test's source and the four names the Export to cube dialog sends, under the names the tool's arguments carry.</p>
Parameter SCREENVALUES = "export=Source:DataSource:SQL:ResultClass:CubeClass:Cube:SourceClass";

/// <p>A dataset names a data source and a custom source an SQL text, never both, and the class to link to is optional.</p>
Parameter SCREENOPTIONAL = "export=DataSource:SQL:SourceClass";

Parameter WRITETYPE = "TOCUBE";

/// <p>The write sends its payload as its body: the test's source and the three names and the class to link to the person or agent reviewed.</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>The fresh read: one model with the names an export would make.</p>
Parameter READTYPE = "PMMLEXPORT";

Parameter READANSWERS = "Class,Model,Type,Target,TargetType,DataSources,Verification,Source,DataSource,SQL,SourceClass,ResultClass,CubeClass,Cube,Held,Namespace";

/// <p>The three names, read back from the namespace as the export made them.</p>
Parameter READBACKFIELDS = "ResultClass,CubeClass,Cube";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Held";

/// <p>No state row: the card's rows are the arguments the review moves from empty.</p>
Parameter STATEFIELD = "";

/// <p>A body-sending write is fingerprinted over its merged payload, not over a subject (AD-6, AD-51).</p>
Parameter FINGERPRINTSUBJECT = "";

Parameter PRECONDITIONFIELD = "";

Parameter PRECONDITIONCODES = "ANALYTICS.PMML.TAKEN,ANALYTICS.PMML.CUBETAKEN,ANALYTICS.PMML.READONLY,ANALYTICS.CUBE.READONLY,ANALYTICS.NAMESPACE";

/// <p>The consequence the write states: the test runs again, its results are copied into new classes, the cube is not built and nothing is undone (published once in EXPERIENCE.md's Fixed strings).</p>
Parameter CONSEQUENCECODE = "ANALYTICS.PMML.EXPORT";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTPMMLMODEL
}

/// <p>The model's composite id, which the rows carry as <code>Class</code> and <code>Model</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Model"
}

/// <p>The members the export takes: the test's source and the names, in the port's order.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(##class(OcuPilot.Port.AnalyticsPort).#PMMLEXPORTFIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set tFields = ..SettableFields()
    Set pRows = $ListLength(tFields)
    For tI = 1:1:pRows {
        Set pRows(tI) = $ListBuild($List(tFields, tI), "string", 0)
    }
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get(..IdArgument()).%Set("description", "The PMML model, spelled as analytics.pmmlmodels.read answers its Class, then two vertical bars and its Model. A model it does not report is refused.", "string")
    Do tProperties.%Get("Source").%Set("description", "What the model is tested against: dataset (one of its data sources, named in DataSource), verification (its verification records) or custom (one SQL query, in SQL).", "string")
    Do tProperties.%Get("Source").%Set("enum", ["dataset", "verification", "custom"])
    Do tProperties.%Get("DataSource").%Set("description", "The model's data source, for a dataset. Omit it for any other source.", "string")
    Do tProperties.%Get("SQL").%Set("description", "One SQL query, for a custom source. It must be a query, and it runs with the user's rights. Omit it for any other source.", "string")
    Do tProperties.%Get("ResultClass").%Set("description", "The new persistent class that holds the test's results: dotted letters and digits with a package, beginning with neither % nor OcuPilot. A class the namespace holds, or one whose package holds a class, is refused, compared without regard to case.", "string")
    Do tProperties.%Get("CubeClass").%Set("description", "The new class that defines the cube, named as ResultClass is. It must be a different class and not in ResultClass's package, nor ResultClass in its package.", "string")
    Do tProperties.%Get("Cube").%Set("description", "The new cube's name: 1 to 250 characters, with no control character and no } character. A cube the namespace holds is refused.", "string")
    Do tProperties.%Get("SourceClass").%Set("description", "Optional. A class of the namespace the result rows link to, so that a record resolves to its source row. A class the namespace does not hold is refused.", "string")
    For tField = "Source", "ResultClass", "CubeClass", "Cube" {
        Do tSchema.%Get("required").%Push(tField)
    }
    Quit tSchema
}

/// <p>What the caller must hold: <method>OcuPilot.Screen.Tool.AnalyticsAction.PrivilegePairs</method>' (the screen's own pairs, WRITE on the resource guarding the database <code>^DeepSee.Fact</code> maps to, READ on the routines
/// database and the classic page's custom resource), then the source code API's own pairs (<code>AtelierPort.Pairs</code>) and the pairs <code>AtelierPort.WritePairs</code> names for the namespace the request is scoped to, which is WRITE
/// on the routines database the classes are saved in, each once (AD-8, AD-44, AD-65). <var>pResolved</var> is 0 when a database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tWrite = ##class(OcuPilot.Port.AtelierPort).WritePairs(##class(OcuPilot.Kernel.Scope).Current())
    If tWrite = "" {
        Set pResolved = 0
        Quit ""
    }
    Set tExtra = ##class(OcuPilot.Port.AtelierPort).Pairs() _ tWrite
    For tAt = 1:1:$ListLength(tExtra) {
        If '$ListFind(tPairs, $List(tExtra, tAt)) Set tPairs = tPairs _ $ListBuild($List(tExtra, tAt))
    }
    Quit tPairs
}

/// <p>The action key when the call carries no <parameter>STATEMARKER</parameter> and the namespace the payload holds (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then each member of the test's source and names the
/// payload or the arguments carry, under its own name, so the mint, a screen action, the confirm's re-read and the read-back each ask the port one question (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tFields = ..SettableFields()
    For tI = 1:1:$ListLength(tFields) {
        Set tName = $List(tFields, tI)
        If (pPayload.%GetTypeOf(tName) = "string") && (pPayload.%Get(tName) '= "") Set pQuery(tName) = pPayload.%Get(tName)
    }
}

/// <p>The screen's values as this tool's arguments: each declared value that is a string, under its own name (AD-56 (ii)). The port judges each.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    Set tFields = ..SettableFields()
    For tI = 1:1:$ListLength(tFields) {
        Set tName = $List(tFields, tI)
        If pValues.%GetTypeOf(tName) = "string" Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    Quit $$$OK
}

/// <p>The title the card gives the target: the model's name.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Model") = "string") Quit pFresh.%Get("Model")
    Quit ""
}

/// <p>No state rows: the card's rows are the members the review moves from empty (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>). A read that answered no <code>Held</code> is <var>pProblem</var>, since a state
/// nobody established is not one to export from.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Held") '= "string") Set pProblem = "this instance did not report the model, and a model whose state is unknown is not one to export"
    Quit $$$OK
}

/// <p>What the screen shows of the export the port answered <var>pWritten</var> for: <code>{ResultClass, CubeClass, Cube, Records}</code>, or <code>""</code> for any other answer. Never stored, logged or put on the ledger,
/// and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("ResultClass") '= "string" Quit ""
    Quit pWritten
}

}
