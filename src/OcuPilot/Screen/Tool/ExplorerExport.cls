/// <p>System Explorer's XML export of a set of documents (AD-6, AD-21, AD-51, AD-53, Story 19.13): what
/// the Classes and Routines lists' export tools share. Two callers reach it: the list's
/// <code>export</code> over its checked rows, to a server file named by its two values, and
/// <code>export-browser</code>, which names none and answers the XML lines for the page to save; and
/// the agent's proposal and confirmation, which always names a server file.</p>
/// <p><b>The file is named by <code>root</code> and <code>path</code></b>, an allowed directory and a
/// relative name under it (AD-21's sixth case). They travel in the port query
/// (<method>PortQuery</method>); <class>OcuPilot.Port.AtelierPort</class> resolves them at the write
/// as an overwriting file, and the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.ExplorerExportMint</class>), so a refusal lands on its field. A file
/// already at the name is replaced (<method>Consequence</method>).</p>
/// <p><b>An export only reads the namespace</b>: it declares the screen's own pairs and no routines
/// WRITE (AD-8), PathPort's pairs when it names a server file (<method>ArgumentPairs</method>), and
/// the kernel does not judge it against OcuPilot's own code (AD-10). It is not destructive. Its fresh
/// read is the port's <code>EXPORTDOCS</code>; the subject is the set held and missing, the namespace
/// and the file. The XML lines answered to the screen are its output alone (AD-39's fifth
/// exception). It performs the classic Export dialog's operation (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerExport Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>The list's export to a server file, whose two values are the file, and its export to this
/// browser, which admits none.</p>
Parameter SCREENACTIONS = "export,export-browser";

Parameter SCREENVALUES = "export=root:path";

Parameter READTYPE = "EXPORTDOCS";

Parameter WRITETYPE = "EXPORT";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Present,Modified,Absent,Namespace,root,path";

/// <p>An export acts on the documents present; a set none of whose documents the read answered is not
/// one to export.</p>
Parameter PRECONDITIONFIELD = "Present";

/// <p>The set held and missing, the namespace and the file the user reviewed. The file is in the
/// subject because the stored payload is narrowed to it, and <method>PortQuery</method> reads it from
/// that payload.</p>
Parameter FINGERPRINTSUBJECT = "Present,Absent,Namespace,root,path";

/// <p>The classic dialog whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.Export";

/// <p>The consequence code the proposal carries: a file already at the name is replaced.</p>
Parameter CONSEQUENCE = "EXPLORER.EXPORT.REPLACES";

/// <p>The action that names no file and answers the XML lines.</p>
Parameter BROWSERACTION = "export-browser";

/// <p>The class the agent's proposal is minted by: the set's own mint, after the file is resolved
/// (<class>OcuPilot.Screen.Tool.ExplorerExportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerExportMint"
}

/// <p><code>root</code> and <code>path</code>: the tool sends no body, and the two reach the port
/// through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY)
}

/// <p>The set's schema with <code>root</code> and <code>path</code> added, both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>The screen's own pairs, then the custom resource of each <parameter>CLASSICPAGES</parameter>
/// page, each pair once (AD-8, AD-44): an export writes no database, so no routines WRITE.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>PathPort's pairs when <var>pArgs</var> names a server file by a non-empty <code>root</code>
/// (AD-21's sixth case, AD-29); none otherwise.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ..FilePairs(pArgs, .pResolved)
}

/// <p>PathPort's pairs when <var>pArgs</var>' <code>root</code> is a non-empty string, else none, for
/// an export's and an import's <method>ArgumentPairs</method>.</p>
ClassMethod FilePairs(pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) Quit ""
    Set tRoot = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY
    If (pArgs.%GetTypeOf(tRoot) '= "string") || (pArgs.%Get(tRoot) = "") Quit ""
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(##class(OcuPilot.Port.PathPort).#PAIRS)
}

/// <p>The set refused by <method>OcuPilot.Screen.Tool.ExplorerWrite.SetProblem</method>, then the
/// file by <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SetProblem(pIdValue)
    If pProblem = "" Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own
/// <code>PATH.*</code> refusal reaches the field it is about (AD-56 (ii)); <parameter>BROWSERACTION</parameter>
/// sends none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If pActionId = ..#BROWSERACTION Quit $$$OK
    For tField = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The namespace, then the stored payload's file arguments under the port's own query keys where
/// each is a non-empty string, so the confirm's write and the screen's carry the file the user
/// reviewed, and an export to this browser carries none (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>The one state row this proposal's card shows beside the file's rows: <code>Documents</code>,
/// whose after-value names the documents the fresh read <var>pFresh</var> holds.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", ..NamesShown(pFresh, "Present"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: a file already at the name is
/// replaced.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
