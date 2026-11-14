/// <p>What the cube manager's two write tools share (AD-6, AD-51, AD-52, AD-53, AD-65, Story 20.34): a write reached through
/// <class>OcuPilot.Port.AnalyticsPort</class> by two callers, the Cube manager's row actions and the agent's proposal and
/// confirmation. Neither sends a body.</p>
/// <p><b>The fresh read is the port's <code>STATE</code></b>, composed for the action at the mint and at a screen action
/// (<method>PortQuery</method>): a cube, or a cube that depends on it, that is being built or synchronized, and for a synchronize
/// one whose source records no changes or that has never been built, is refused by the port with its own
/// <code>ANALYTICS.CUBE.*</code> code, 409, before any vendor call (<parameter>PRECONDITIONCODES</parameter>). The confirm's re-read is
/// not composed for the action, so a cube that moved closes the proposal through the fingerprint, and the write refuses again by the
/// same codes. <method>StateDiff</method> repeats the refusal for a read that reached it unrefused.</p>
/// <p><b>The target is the cube's logical name</b>, the <code>Name</code> column of the Cube manager and of the Cubes list, kept exactly
/// (AD-13).</p>
/// <p><b>It declares</b> the screen's own pairs, then WRITE on the resource guarding the database <code>^DeepSee.Fact</code> maps to in
/// the namespace, then READ on the resource guarding its routines database, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44), each refused by name before any port call. The vendor checks none of them.</p>
/// <p><b>The answer reaches the screen only</b> (<method>WriteOutput</method>, AD-39's fifth exception): the output lines of the
/// build or synchronize, stored nowhere and never sent to the model.</p>
Class OcuPilot.Screen.Tool.AnalyticsAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsCubeManager";

/// <p>The port that reads and writes the target (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AnalyticsPort";

/// <p>The fresh read: one cube, judged over it and its dependents, composed for the action.</p>
Parameter READTYPE = "STATE";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Namespace,Facts,LastBuild,BuildStamp,LastUpdate,Built,Synchronizes,Updating,DependentCubes";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as at the confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>An action-style write sends no body (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The read field whose absence marks a call's arguments rather than a stored payload: a payload the confirm holds carries it.</p>
Parameter STATEMARKER = "Updating";

/// <p>The state row's label: the facts, which the card shows and which a prohibited-set sweep must not read as a payload field.</p>
Parameter STATEFIELD = "Facts";

/// <p>The classic page whose Build and Synchronize this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%DeepSee.UI.CubeRegistry";

/// <p>The consequence code the proposal carries; the client maps it to its published sentence.</p>
Parameter CONSEQUENCECODE;

/// <p>The card row that moves, and the word it moves to.</p>
Parameter AFTERROW;

Parameter AFTERWORD;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTCUBEMANAGER
}

/// <p>The cube's logical name, which the rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#IDKEY
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The derived schema with the cube's description replaced: the target is one cube, named exactly as the Cube manager or the Cubes
/// list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The cube, named by its logical name exactly as the Cube manager or the Cubes list reports it in the Name column. A cube it does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The title the card gives the cube: its name.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    Quit ""
}

/// <p>What the caller must hold: the screen's own pairs, then WRITE on the resource guarding the database
/// <code>^DeepSee.Fact</code> maps to in the namespace the request is scoped to, then READ on the resource guarding its routines
/// database, then the custom resource of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44, AD-65).
/// <var>pResolved</var> is 0 when a database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tFacts = ""
    Set tReadOnly = 0
    Set tMounted = 0
    Set tRoutines = ""
    If '##class(OcuPilot.Port.AnalyticsPort).DestinationDatabase(tNamespace, ##class(OcuPilot.Port.AnalyticsPort).#FACTGLOBAL, .tFacts, .tReadOnly, .tMounted) || (tFacts = "") {
        Set pResolved = 0
        Quit ""
    }
    If '##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(tNamespace, .tRoutines, .tReadOnly) || (tRoutines = "") {
        Set pResolved = 0
        Quit ""
    }
    Set tWrite = $ListBuild(tFacts, ##class(OcuPilot.Port.AnalyticsPort).#WRITEPERMISSION)
    If '$ListFind(tPairs, tWrite) Set tPairs = tPairs _ $ListBuild(tWrite)
    Set tRead = $ListBuild(tRoutines, ##class(OcuPilot.Port.AnalyticsPort).#READPERMISSION)
    If '$ListFind(tPairs, tRead) Set tPairs = tPairs _ $ListBuild(tRead)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The namespace a call's rules are judged in (AD-52): the one the arguments <var>pArgs</var> carry under
/// <parameter>NAMESPACEFIELD</parameter>, else the request's scope.</p>
ClassMethod ArgumentNamespace(pArgs As %DynamicObject) As %String
{
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pArgs.%Get(..#NAMESPACEFIELD) '= "") Quit pArgs.%Get(..#NAMESPACEFIELD)
    Quit ##class(OcuPilot.Kernel.Scope).Current()
}

/// <p>Compose the port's read (AD-52): the action key when the call carries no <parameter>STATEMARKER</parameter>, then the namespace
/// the payload (<parameter>NAMESPACEFIELD</parameter>) holds.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#STATEMARKER) = "unassigned" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>The rows this proposal's card shows, from the fresh read <var>pFresh</var>: the cube, its facts, its last build, its last update
/// and the cubes that depend on it, <parameter>AFTERROW</parameter> moving to <parameter>AFTERWORD</parameter> and the others
/// unchanged. A cube the action does not fit is <var>pProblem</var>, the sentence of the code
/// <method>OcuPilot.Port.AnalyticsPort.StateRefusal</method> names; a read that answered no <code>Updating</code> flag refuses too,
/// since a state nobody established is not one to act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Updating") '= "boolean") {
            Set pProblem = "this instance did not report the cube's state"
            Quit
        }
        Set tCode = ##class(OcuPilot.Port.AnalyticsPort).StateRefusal(..#WRITETYPE, pFresh)
        If tCode '= "" {
            Set pProblem = ##class(OcuPilot.Port.AnalyticsPort).ReasonFor(tCode)
            Quit
        }
        For tField = "Cube", "Facts", "Last build", "Last update", "Dependent cubes" {
            Set tKey = $Case(tField, "Cube": "Name", "Facts": "Facts", "Last build": "LastBuild", "Last update": "LastUpdate", : "DependentCubes")
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tKey), pFresh.%GetTypeOf(tKey))
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", tBefore, "string")
            Do tRow.%Set("after", $Select(tField = ..#AFTERROW: ..#AFTERWORD, 1: tBefore), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>What the screen shows of the update the port answered <var>pWritten</var> for: <code>{lines, errors}</code>, the output lines
/// and whether a cube built with errors. <code>""</code> for any other answer. Never stored, logged or put on the ledger, and never sent
/// to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("lines") '= "array" Quit ""
    Set tOutput = {}
    Do tOutput.%Set("lines", pWritten.%Get("lines"))
    Do tOutput.%Set("errors", ''pWritten.%Get("errors"), "boolean")
    Quit tOutput
}

}
