/// <p>Analytics' term list export (AD-6, AD-21, AD-51, AD-53, AD-65, Story 24.10): the vendor's own CSV of one term list, the classic Term List
/// Manager's export, either to a server file or to this browser. Two callers reach it: the Term lists row actions <code>export</code>, to a server
/// file named by its two values, and <code>export-browser</code>, which names none and answers the CSV lines for the page to save; and the agent's
/// proposal and confirmation, which always names a server file.</p>
/// <p><b>The file is named by <code>root</code> and <code>path</code></b>, an allowed directory and a relative name under it (AD-21's sixth case),
/// resolved by <class>OcuPilot.Port.PathPort</class> as an overwriting file whose overwrite the port declares
/// (<parameter>OcuPilot.Port.AnalyticsPort.EXPORTOVERWRITES</parameter>), never a caller value; the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.AnalyticsTermListExportMint</class>), so a refusal lands on its field. A file already at the name is replaced
/// (<method>Consequence</method>).</p>
/// <p><b>An export only reads the namespace</b>: it declares the screen's own pairs, READ on the database <code>^DeepSee.TermList</code> maps to
/// and <code>%Admin_FileSystemAccess:USE</code>, since it writes a file (AD-8), PathPort's pairs when it names a server file
/// (<method>ArgumentPairs</method>), and is not destructive. The CSV lines answered to the screen are its output alone (AD-39's fifth exception). The
/// file holds every key and value of the list, so a value the list holds reaches it; the lines and the file are never stored or logged.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListExport Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.export";

Parameter DESCRIPTION = "Propose writing one term list to a file on the server, in the CSV form the instance's own Term List Manager exports, so it can be imported again. Name the list exactly as the Term lists list reports it in its Name column. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The file holds the list's properties and every entry's key and values, so say so in the rationale. A list the namespace does not hold is refused.";

/// <p>The fresh read: one term list, echoing the file the query names.</p>
Parameter READTYPE = "EXPORTLIST";

Parameter READANSWERS = "Name,Caption,Description,Pattern,SubjectArea,Fields,HideValue,Modified,Namespace,root,path";

/// <p>The fresh read is not composed from the call's values: the file's two values are the card's rows, as the lookup export's are.</p>
Parameter READSVALUES As BOOLEAN = 0;

/// <p>The export only reads the term list database, and writes a file the file system's resource guards.</p>
Parameter DESTINATIONPERMISSION = "READ";

Parameter FILERESOURCE = "%Admin_FileSystemAccess";

/// <p>The list's export to a server file, whose two values are the file, and its export to this browser, which admits none.</p>
Parameter SCREENACTIONS = "export,export-browser";

Parameter SCREENVALUES = "export=root:path";

Parameter WRITETYPE = "EXPORT";

Parameter CHANGEACTION = "updated";

/// <p>The list as reviewed, the namespace and the file. The file is in the subject because the stored payload is narrowed to it, and
/// <method>PortQuery</method> reads it from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Name,Modified,Namespace,root,path";

Parameter PRECONDITIONFIELD = "Modified";

Parameter PRECONDITIONCODES = "ANALYTICS.NAMESPACE";

/// <p>The consequence code the proposal carries when it names a server file: a file already at the name is replaced.</p>
Parameter CONSEQUENCE = "EXPLORER.EXPORT.REPLACES";

/// <p>The action that names no file and answers the CSV lines.</p>
Parameter BROWSERACTION = "export-browser";

/// <p><class>OcuPilot.Screen.Tool.AnalyticsTermListExportMint</class>, which resolves the file first.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsTermListExportMint"
}

/// <p><code>root</code> and <code>path</code>: the tool sends no body, and the two reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY)
}

/// <p>The derived schema with the list's name described and <code>root</code> and <code>path</code> added, both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The term list to export, named exactly as this namespace's Term lists list reports it in its Name column. A list the namespace does not hold is refused.", "string")
    }
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>PathPort's pairs when <var>pArgs</var> names a server file by a non-empty <code>root</code> (AD-21's sixth case, AD-29); none
/// otherwise.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerExport).FilePairs(pArgs, .pResolved)
}

/// <p>The agent's file arguments refused by <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own <code>PATH.*</code> refusal reaches the field it is
/// about (AD-56 (ii)); <parameter>BROWSERACTION</parameter> sends none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If pActionId = ..#BROWSERACTION Quit $$$OK
    For tField = ##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then the stored payload's file arguments
/// under the port's own query keys where each is a non-empty string, so the confirm's write and the screen's carry the file the user reviewed, and
/// an export to this browser carries none (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>What the screen shows of the export the port answered <var>pWritten</var> for: the CSV <code>lines</code> of an export to this browser, or the
/// <code>root</code> and <code>path</code> of the file an export wrote. Never stored, logged or put on the ledger, and never sent to the model
/// (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    If pWritten.%GetTypeOf("lines") = "array" {
        Do tOutput.%Set("lines", pWritten.%Get("lines"))
    } Else {
        Do tOutput.%Set(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, pWritten.%Get(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY), "string")
        Do tOutput.%Set(##class(OcuPilot.Port.AnalyticsPort).#PATHKEY, pWritten.%Get(##class(OcuPilot.Port.AnalyticsPort).#PATHKEY), "string")
    }
    Quit tOutput
}

/// <p><parameter>CONSEQUENCE</parameter> when the payload names a server file (a file already at the name is replaced), else none: an export to this
/// browser writes no file.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY) = "string") && (pPayload.%Get(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY) '= "") Quit ..#CONSEQUENCE
    Quit ""
}

}
