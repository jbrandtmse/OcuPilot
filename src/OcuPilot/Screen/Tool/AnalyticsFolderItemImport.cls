/// <p>Analytics' folder item import (AD-6, AD-10, AD-21, AD-51, AD-53, AD-54, AD-65, Story 24.10): every folder item a file holds is created in the
/// request's namespace, all or none. Two callers reach it: the Folder items page's <code>import</code>, from a server file named by its <code>root</code>
/// and <code>path</code> values, and <code>import-local</code>, from a file on the person's computer sent as its <code>fileName</code> and
/// <code>content</code> values; and the agent's proposal and confirmation, which names a server file only.</p>
/// <p><b>It only creates folder items.</b> The port reads the text first and accepts exactly the forms the export and the classic Folder Manager's export
/// write; a class, a routine, any other document, or a folder is <code>ANALYTICS.FOLDERITEM.IMPORTSHAPE</code>, and nothing is loaded or compiled. An item
/// whose name the instance already holds, in any letter case, is <code>ANALYTICS.FOLDERITEM.TAKEN</code> before any write; nothing is replaced, which the
/// classic page does. A file of more than 100 items is <code>TOOLARGE</code>.</p>
/// <p><b>The target is the first item the file names.</b> The person's import names it by the literal <parameter>OcuPilot.Port.AnalyticsPort.IMPORTID</parameter>;
/// the agent names the first item it expects the file to hold in <code>Name</code>, by its full name, and the port refuses a file whose first item is another.
/// A local file's name and text are screen values alone: the input schema never carries them, and nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's digest</b> and whether any name is held: the fresh read composes them, the fingerprint holds them, and the port
/// refuses the write <code>ANALYTICS.FOLDERITEM.IMPORTCHANGED</code> unless the file reads the same at the write.</p>
Class OcuPilot.Screen.Tool.AnalyticsFolderItemImport Extends OcuPilot.Screen.Tool.AnalyticsFolderItemAction
{

Parameter TOOLNAME = "analytics.folderitems.import";

Parameter DESCRIPTION = "Propose importing folder items (pivots, dashboards and the other items of the Folder items list) from an export file on the server, which creates every item the file holds, all or none. Nothing is replaced: no item of those names may exist already (names are compared without regard to case), and a file that holds a class, a routine or anything but folder items is refused. Name the first item the file holds in `Name`, by its full name exactly as the Folder items list would report it, folder and extension included. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must be one an export of the Folder items screen or of the classic Folder Manager wrote, with at most 100 items. If the file changes before the proposal is confirmed, nothing is imported.";

/// <p>The fresh read: the file's items, composed from the file and the names as they stand.</p>
Parameter READTYPE = "IMPORTFILE";

Parameter READANSWERS = "Items,Count,Digest,Present,Namespace,root,path,fileName,content";

Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path,import-local=fileName:content";

Parameter WRITETYPE = "IMPORT";

/// <p>The import creates items, so the change event is a creation.</p>
Parameter CHANGEACTION = "created";

/// <p>The import read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Digest";

/// <p>The file and the items the user reviewed, and the namespace. A local file's <code>content</code> is in it so the screen's write carries the text
/// it read; it is empty in an agent's proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,root,path,fileName,content,Items,Count,Digest,Present";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "ANALYTICS.FOLDERITEM.TAKEN,ANALYTICS.FOLDERITEM.IMPORTSHAPE,ANALYTICS.FOLDERITEM.TOOLARGE,ANALYTICS.FOLDERITEM.READONLY,ANALYTICS.FOLDERITEM.NOTJOURNALED,ANALYTICS.NAMESPACE";

/// <p>The reviewed value the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>.</p>
Parameter REVIEWED = "Digest=digest";

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed digest. They reach the port through
/// <method>PortQuery</method>; only <code>Name</code>, <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AnalyticsPort).#ROOTKEY, ##class(OcuPilot.Port.AnalyticsPort).#PATHKEY, ##class(OcuPilot.Port.AnalyticsPort).#FILENAMEKEY, ##class(OcuPilot.Port.AnalyticsPort).#CONTENTKEY, "Digest")
}

/// <p>The schema: the first item the file holds and the server file, each required, and the agent's own words. The local file and the reviewed digest
/// are never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": "The first folder item the file holds, named by its full name, folder and extension included, as the file's first item reads. A file whose first item is another is refused, and so is a file that names an item this namespace already holds."})
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

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's), <code>Items</code>
/// (the full names the file creates, comma-separated) and <code>Count</code>. A read that answered no items or no count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Items") '= "array") || (pFresh.%GetTypeOf("Count") '= "number") {
            Set pProblem = "this instance did not read the import file's folder items, and a file whose items are unknown is not one to import"
            Quit
        }
        Set tNames = ""
        Set tIterator = pFresh.Items.%GetIterator()
        While tIterator.%GetNext(.tAt, .tName) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ", ") _ tName
        }
        Set tFile = $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName"))
        Do ..PushRow(pRows, "File", "", tFile)
        Do ..PushRow(pRows, "Items", "", tNames)
        Do ..PushRow(pRows, "Count", 0, pFresh.%Get("Count"))
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

/// <p>What the screen shows of the import the port answered <var>pWritten</var> for: the <code>Name</code> of the first item it created and how many it
/// created (<code>Count</code>), for the line that says what was imported. Never stored, logged or put on the ledger, and never sent to the model
/// (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") || (pWritten.%GetTypeOf("Count") '= "number") Quit ""
    Quit {"Name": (pWritten.%Get("Name")), "Count": (pWritten.%Get("Count"))}
}

/// <p>The full name of the first item the confirmed import <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
