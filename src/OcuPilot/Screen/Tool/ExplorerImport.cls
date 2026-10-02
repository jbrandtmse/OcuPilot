/// <p>System Explorer's import of one file (AD-6, AD-10, AD-21, AD-51, AD-53, Story 19.13): what the
/// Classes and Routines lists' import tools share. An XML export or one UDL document is loaded into the
/// namespace, replacing any document of the same name, and compiled when <code>Compile</code> is on.
/// Two callers reach it: the list's <code>import</code>, from a server file named by its
/// <code>root</code> and <code>path</code> values, and <code>import-local</code>, from a file on the
/// person's computer sent as its <code>fileName</code> and <code>content</code> values; and the
/// agent's proposal and confirmation, which names a server file only.</p>
/// <p><b>The target is the literal <parameter>OcuPilot.Port.AtelierPort.IMPORTID</parameter></b>,
/// whatever the caller sends, and the file is resolved again at the write (AD-21's sixth case). A
/// local file's name and text are screen values alone: the input schema never carries them
/// (<method>InputSchema</method>), and nothing stores or logs them.</p>
/// <p><b>The reviewed <code>documents</code></b> is the port's <code>PREVIEW</code> of the file: the
/// agent's mint stores it (<class>OcuPilot.Screen.Tool.ExplorerImportMint</class>) and the screen's
/// action reads it before the write (<method>ScreenActionDelta</method>). The port refuses the write
/// <code>EXPLORER.IMPORT.CHANGED</code> unless the file reads the same summary at the write, and the
/// kernel refuses an import whose reviewed documents name one of OcuPilot's own
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>).</p>
/// <p><b>It is destructive</b>: an import replaces existing code without asking, which cannot be
/// undone from OcuPilot. It declares WRITE on the namespace's routines database (AD-8) and PathPort's
/// pairs when it names a server file. Its console lines and imported names reach the screen and the
/// proposal card only (AD-39's fifth exception). It performs the classic Import dialog's operation
/// (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerImport Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>The list's import from a server file and from a local one.</p>
Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path:Compile,import-local=fileName:content:Compile";

/// <p>The argument naming the target, whose one value is <parameter>OcuPilot.Port.AtelierPort.IMPORTID</parameter>.</p>
Parameter IDARGUMENT = "Id";

Parameter READTYPE = "IMPORTTARGET";

Parameter WRITETYPE = "IMPORT";

/// <p>Declared: an import replaces existing documents without asking.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>Documents are created, or replaced, so a list showing them re-reads (AD-14).</p>
Parameter CHANGEACTION = "created";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,root,path,fileName,content,documents,Compile";

/// <p>The file and the documents the user reviewed, the namespace and the compile choice.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,root,path,fileName,content,documents,Compile";

/// <p>An import acts on the documents its file was reviewed with.</p>
Parameter PRECONDITIONFIELD = "documents";

/// <p>The classic dialog whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.Import";

/// <p>The consequence code the proposal carries: each document of the same name is replaced.</p>
Parameter CONSEQUENCE = "EXPLORER.IMPORT.REPLACES";

/// <p>The query key the port reads the target from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#IDKEY
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file is previewed
/// (<class>OcuPilot.Screen.Tool.ExplorerImportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerImportMint"
}

/// <p>Every argument the port reads beyond the target: the server file, the local file, the reviewed
/// summary and the compile choice. They reach the port through <method>PortQuery</method>; only
/// <code>root</code>, <code>path</code> and <code>Compile</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY, ##class(OcuPilot.Port.AtelierPort).#FILENAMEKEY, ##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#DOCUMENTSKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
}

/// <p>The schema: the literal target, the server file and the compile choice, each required, and the
/// agent's own words. The local file and the reviewed summary are never advertised, so the closed
/// schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "Send the literal 'import': an import names its file by root and path, not by a document."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY, {"type": "boolean", "description": "true compiles each document the file loads, as the classic Import dialog's Compile imported items does."})
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>PathPort's pairs when <var>pArgs</var> names a server file by a non-empty <code>root</code>
/// (AD-21's sixth case, AD-29); none otherwise.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerExport).FilePairs(pArgs, .pResolved)
}

/// <p>What is wrong with the agent's arguments, or <code>""</code>: the file by
/// <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method>, then a <code>Compile</code> that is
/// not a boolean (AD-55). The target is the mint's to set.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    If (pProblem = "") && (pArgs.%GetTypeOf(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY) '= "boolean") Set pProblem = "'" _ ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY _ "' is true or false"
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments -- the file as sent, unresolved, and
/// <code>Compile</code> from <code>true</code> or <code>false</code>, any other spelling refused (AD-56
/// (ii)) -- with <code>documents</code> the port's <code>PREVIEW</code> of the file in the fresh read
/// <var>pFresh</var>'s namespace. A preview the port refuses leaves <code>documents</code> empty, so
/// the write answers that refusal itself.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY, ##class(OcuPilot.Port.AtelierPort).#FILENAMEKEY, ##class(OcuPilot.Port.AtelierPort).#CONTENTKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set tCompile = ""
    If $IsObject(pValues) Set tCompile = pValues.%Get(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
    If (tCompile '= "true") && (tCompile '= "false") {
        Set pArgs = {}
        Set pProblem = "'" _ ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY _ "' is true or false"
        Quit $$$OK
    }
    Do pArgs.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY, (tCompile = "true"), "boolean")
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#IDKEY) = ##class(OcuPilot.Port.AtelierPort).#IMPORTID
    Do ..PortQuery(pFresh, .tQuery)
    Do ..PortQuery(pArgs, .tQuery)
    Set tDocuments = ""
    Set tPreviewSC = $ClassMethod(..#PORTCLASS, "Invoke", ..Endpoint(), ##class(OcuPilot.Port.AtelierPort).#TYPEPREVIEW, .tQuery, "", .tPreview, .tHttp, .tFault)
    If $$$ISOK(tPreviewSC) && $IsObject($Get(tPreview)) Set tDocuments = tPreview.%Get(##class(OcuPilot.Port.AtelierPort).#DOCUMENTSKEY)
    Do pArgs.%Set(##class(OcuPilot.Port.AtelierPort).#DOCUMENTSKEY, tDocuments, "string")
    Quit $$$OK
}

/// <p>The namespace, then every other subject value of the stored payload <var>pPayload</var> under
/// the port's own query keys -- each string that is not empty, and <code>Compile</code> as
/// <code>1</code> or <code>0</code> -- so the confirm's write and the screen's import the file the
/// user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY, ##class(OcuPilot.Port.AtelierPort).#PATHKEY, ##class(OcuPilot.Port.AtelierPort).#FILENAMEKEY, ##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#DOCUMENTSKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    Set tCompile = ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY
    If pPayload.%GetTypeOf(tCompile) = "boolean" Set pQuery(tCompile) = $Select(pPayload.%Get(tCompile): 1, 1: 0)
}

/// <p>No state row: the merge's <code>root</code>, <code>path</code>, <code>documents</code> and
/// <code>Compile</code> rows are the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: each document of the same name is
/// replaced.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
