/// <p>Interoperability's lookup table export (AD-6, AD-21, AD-51, AD-53, AD-62, Story 20.5): the vendor's own export of one table's
/// <code>.LUT</code> document, the classic Lookup Tables page's form, either to a server file or to this browser. Two callers reach it:
/// the tables list's row action <code>export</code>, to a server file named by its two values, and <code>export-browser</code>, which
/// names none and answers the XML lines for the page to save; and the agent's proposal and confirmation, which always names a server
/// file.</p>
/// <p><b>The file is named by <code>root</code> and <code>path</code></b>, an allowed directory and a relative name under it (AD-21's
/// sixth case), resolved by <class>OcuPilot.Port.PathPort</class> as an overwriting file whose overwrite the port declares
/// (<parameter>OcuPilot.Port.InteropPort.EXPORTOVERWRITES</parameter>), never a caller value; the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.InteropLookupTableExportMint</class>), so a refusal lands on its field. A file already at the name is
/// replaced (<method>Consequence</method>).</p>
/// <p><b>An export only reads the namespace</b>: it declares the screen's own pairs, READ on the namespace's globals database and
/// <code>%Admin_FileSystemAccess:USE</code>, as the Task schedule's export does, since it writes a file (AD-8), PathPort's pairs when
/// it names a server file (<method>ArgumentPairs</method>), and is not destructive. The XML lines answered
/// to the screen are its output alone (AD-39's fifth exception). It reads the table's values into a file, so a value the table holds
/// reaches the file; the lines and the file are never stored or logged.</p>
Class OcuPilot.Screen.Tool.InteropLookupTableExport Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.lookuptables.export";

Parameter DESCRIPTION = "Propose writing one lookup table to a new file on the server, in the instance's own lookup table export format, so another instance can import it. Name the table exactly as the Lookup tables list reports it in its Name column, letter case included. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The file holds every key and value of the table, so say so in the rationale. A table the namespace does not hold is refused.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropLookupTableList";

/// <p>The fresh read: one table, echoing the file the query names.</p>
Parameter READTYPE = "LOOKUPTABLE";

Parameter READANSWERS = "Name,Entries,Modified,Namespace,root,path";

/// <p>The fresh read is not composed from the call's values: the file's two values are the card's rows, as the Explorer export's are.</p>
Parameter READSVALUES As BOOLEAN = 0;

/// <p>The file the agent's export writes is the file system's, so no principal that only reads holds this tool.</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

Parameter DATABASEPERMISSION = "READ";

/// <p>The list's export to a server file, whose two values are the file, and its export to this browser, which admits none.</p>
Parameter SCREENACTIONS = "export,export-browser";

Parameter SCREENVALUES = "export=root:path";

Parameter WRITETYPE = "EXPORT";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The table read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Modified";

/// <p>The table as reviewed, the namespace and the file. The file is in the subject because the stored payload is narrowed to it, and
/// <method>PortQuery</method> reads it from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Name,Entries,Modified,Namespace,root,path";

Parameter PRECONDITIONFIELD = "Entries";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

/// <p>The consequence code the proposal carries when it names a server file: a file already at the name is replaced.</p>
Parameter CONSEQUENCE = "EXPLORER.EXPORT.REPLACES";

/// <p>The action that names no file and answers the XML lines.</p>
Parameter BROWSERACTION = "export-browser";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTLOOKUPTABLES
}

/// <p><class>OcuPilot.Screen.Tool.InteropLookupTableExportMint</class>, which resolves the file first.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropLookupTableExportMint"
}

/// <p><code>root</code> and <code>path</code>: the tool sends no body, and the two reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY)
}

/// <p>The derived schema with the table's name described and <code>root</code> and <code>path</code> added, both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The lookup table to export, named exactly as this namespace's Lookup tables list reports it in its Name column, letter case included. A table the list does not report is refused.", "string")
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

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own <code>PATH.*</code> refusal reaches the field it
/// is about (AD-56 (ii)); <parameter>BROWSERACTION</parameter> sends none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If pActionId = ..#BROWSERACTION Quit $$$OK
    For tField = ##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The namespace, then the stored payload's file arguments under the port's own query keys where each is a non-empty string, so the
/// confirm's write and the screen's carry the file the user reviewed, and an export to this browser carries none (AD-52). The action
/// key is only the writes' (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>The one state row this proposal's card shows beside the file's rows: <code>Entries</code>, whose after-value is the count of the
/// entries the file will hold. A read that answered no count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Entries") '= "number") {
        Set pProblem = "this instance did not report the table's entries"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", "Entries", "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get("Entries"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>The table's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the screen shows of the export the port answered <var>pWritten</var> for: the XML <code>lines</code> of an export to this
/// browser, or the <code>root</code> and <code>path</code> of the file an export wrote. Never stored, logged or put on the ledger, and
/// never sent to the model (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    If pWritten.%GetTypeOf("lines") = "array" {
        Do tOutput.%Set("lines", pWritten.%Get("lines"))
    } Else {
        Do tOutput.%Set(##class(OcuPilot.Port.InteropPort).#ROOTKEY, pWritten.%Get(##class(OcuPilot.Port.InteropPort).#ROOTKEY), "string")
        Do tOutput.%Set(##class(OcuPilot.Port.InteropPort).#PATHKEY, pWritten.%Get(##class(OcuPilot.Port.InteropPort).#PATHKEY), "string")
    }
    Quit tOutput
}

/// <p><parameter>CONSEQUENCE</parameter> when the payload names a server file (a file already at the name is replaced), else none: an
/// export to this browser writes no file.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf(##class(OcuPilot.Port.InteropPort).#ROOTKEY) = "string") && (pPayload.%Get(##class(OcuPilot.Port.InteropPort).#ROOTKEY) '= "") Quit ..#CONSEQUENCE
    Quit ""
}

}
