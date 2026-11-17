/// <p>Analytics' term list import (AD-6, AD-10, AD-21, AD-51, AD-53, AD-54, AD-65, Story 24.10): the term list a CSV export file holds is created in
/// the request's namespace, with its header, its fields and every entry. Two callers reach it: the Term lists page's <code>import</code>, from a
/// server file named by its <code>root</code> and <code>path</code> values, and <code>import-local</code>, from a file on the person's computer sent
/// as its <code>fileName</code> and <code>content</code> values; and the agent's proposal and confirmation, which names a server file only.</p>
/// <p><b>It only creates.</b> A list of the name the file holds, compared without regard to case, is refused <code>ANALYTICS.TERMLIST.TAKEN</code>
/// before any vendor call; nothing is overwritten, which the classic Import does after a confirm. The port reads the text itself
/// (<method>OcuPilot.Port.AnalyticsPort.TermListParse</method>), judges every name, field, key and value by the editor's own rules, and writes
/// through the editor's seams in one transaction; it never calls the vendor's <code>%ImportCSV</code>.</p>
/// <p><b>The target is the list the file names.</b> The person's import names it by the literal <parameter>OcuPilot.Port.AnalyticsPort.IMPORTID</parameter>;
/// the agent names the list it expects the file to hold in <code>Name</code>, and the port refuses a file that holds another
/// (<code>ANALYTICS.TERMLIST.IMPORTSHAPE</code>). A local file's name and text are screen values alone: the input schema never carries them, and
/// nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's digest</b> and whether the name is free: the fresh read composes them, the fingerprint holds them, and the
/// port refuses the write <code>ANALYTICS.TERMLIST.IMPORTCHANGED</code> unless the file reads the same at the write.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListImport Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.import";

Parameter DESCRIPTION = "Propose importing one term list from an export file on the server, which creates the term list the file holds, with its properties, its fields and every entry. Nothing is replaced: a term list of that name must not exist already (names are compared without regard to case). Name the list the file holds in `Name`, exactly as the file's first %%NAME line spells it. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must be a term list export in the form the Export action writes, with at least one entry; a name, field, key or value over the editor's limits is refused. If the file changes before the proposal is confirmed, nothing is imported.";

/// <p>The fresh read: the file's list, composed from the file and the name as it stands.</p>
Parameter READTYPE = "IMPORTFILE";

Parameter READANSWERS = "Name,FileEntries,Digest,Present,Namespace,root,path,fileName,content";

Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path,import-local=fileName:content";

Parameter WRITETYPE = "IMPORT";

/// <p>The import creates a list, so the change event is a creation.</p>
Parameter CHANGEACTION = "created";

/// <p>The import read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Digest";

/// <p>The file and the list the user reviewed, and the namespace. A local file's <code>content</code> is in it so the screen's write carries the text
/// it read; it is empty in an agent's proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,root,path,fileName,content,Name,FileEntries,Digest,Present";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.TAKEN,ANALYTICS.TERMLIST.IMPORTSHAPE,ANALYTICS.TERMLIST.TOOLARGE,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

/// <p>The reviewed value the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>.</p>
Parameter REVIEWED = "Digest=digest";

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed digest. They reach the port through
/// <method>PortQuery</method>; only <code>Name</code>, <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY, ##class(OcuPilot.Port.AnalyticsPort).#FILENAMEKEY, ##class(OcuPilot.Port.AnalyticsPort).#CONTENTKEY, "Digest")
}

/// <p>The schema: the list the file holds and the server file, each required, and the agent's own words. The local file and the reviewed digest are
/// never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": "The term list the file holds, named exactly as the file's %%NAME line spells it. A file that holds another list is refused, and so is a list this namespace already holds."})
    Do tSchema.%Get("required").%Push(..IdArgument())
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>PathPort's pairs when <var>pArgs</var> names a server file by a non-empty <code>root</code> (AD-21's sixth case, AD-29); none
/// otherwise.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerExport).FilePairs(pArgs, .pResolved)
}

/// <p>What is wrong with the agent's arguments, or <code>""</code>: the file, by <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method>
/// (AD-55). The screen's local file names none, and the port judges it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If $IsObject(pArgs) && ((pArgs.%GetTypeOf(##class(OcuPilot.Port.AnalyticsPort).#FILENAMEKEY) = "string") || (pArgs.%GetTypeOf(##class(OcuPilot.Port.AnalyticsPort).#CONTENTKEY) = "string")) Quit $$$OK
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments -- the file as sent, unresolved -- and, once the fresh read <var>pFresh</var> is there, the
/// reviewed <code>Digest</code> it answered, so the write compares the file as the user saw it. The fresh read is composed from the file's values,
/// so the first call, before it, carries only the file (AD-51).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY, ##class(OcuPilot.Port.AnalyticsPort).#FILENAMEKEY, ##class(OcuPilot.Port.AnalyticsPort).#CONTENTKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Digest") = "string") Do pArgs.%Set("Digest", pFresh.%Get("Digest"), "string")
    Quit $$$OK
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then every subject value of the payload
/// <var>pPayload</var> under the port's own query keys -- each file string that is not empty, and the reviewed digest where the payload has it -- so
/// the confirm's write and the screen's import the file the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY, ##class(OcuPilot.Port.AnalyticsPort).#FILENAMEKEY, ##class(OcuPilot.Port.AnalyticsPort).#CONTENTKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    For tI = 1:1:$Length(..#REVIEWED, ",") {
        Set tField = $Piece($Piece(..#REVIEWED, ",", tI), "=", 1)
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery($Piece($Piece(..#REVIEWED, ",", tI), "=", 2)) = pPayload.%Get(tField)
    }
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's),
/// <code>Name</code> (the list the file creates) and <code>Entries</code> (the entries the file holds). A read that answered no list or no entry
/// count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Name") '= "string") || (pFresh.%Get("Name") = "") || (pFresh.%GetTypeOf("FileEntries") '= "number") {
            Set pProblem = "this instance did not read the import file's term list and its entries, and a file whose list is unknown is not one to import"
            Quit
        }
        Set tFile = $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName"))
        Do ..PushRow(pRows, "File", "", tFile)
        Do ..PushRow(pRows, "Name", "", pFresh.%Get("Name"))
        Do ..PushRow(pRows, "Entries", 0, pFresh.%Get("FileEntries"))
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One card row on <var>pRows</var>.</p>
ClassMethod PushRow(pRows As %DynamicArray, pField As %String, pBefore As %String, pAfter As %String) [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", pBefore, "string")
    Do tRow.%Set("after", pAfter, "string")
    Do pRows.%Push(tRow)
}

/// <p>The list's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the screen shows of the import the port answered <var>pWritten</var> for: the <code>Name</code> of the list it created, for the line
/// that says what was imported. Never stored, logged or put on the ledger, and never sent to the model (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit {"Name": (pWritten.%Get("Name"))}
}

/// <p>The name of the list the confirmed import <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
