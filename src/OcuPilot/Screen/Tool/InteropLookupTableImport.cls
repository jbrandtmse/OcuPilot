/// <p>Interoperability's lookup table import (AD-6, AD-10, AD-21, AD-51, AD-53, AD-62, Story 20.5): the one lookup table an export file
/// holds replaces the table of that name, or creates it; keys the file lacks are removed. Two callers reach it: the tables list's
/// <code>import</code>, from a server file named by its <code>root</code> and <code>path</code> values, and <code>import-local</code>,
/// from a file on the person's computer sent as its <code>fileName</code> and <code>content</code> values; and the agent's proposal and
/// confirmation, which names a server file only.</p>
/// <p><b>The target is the table the file names.</b> The person's import of a local file names it as the page reads it from the
/// file, and of a server file, which the page never reads, by the literal <parameter>OcuPilot.Port.InteropPort.IMPORTID</parameter>;
/// the agent names the table it expects the file to hold in <code>Name</code>; and the port refuses a file that holds another
/// (<code>INTEROP.LOOKUP.IMPORTSHAPE</code>). A file that is not exactly one lookup table
/// with at least one entry and nothing else is refused by that code before any load: no class, routine or other document in a file is
/// ever loaded, and the legacy form is refused too. A file whose table is absent under exactly that name but held in another letter case is
/// refused <code>INTEROP.LOOKUP.TABLECASE</code>, since the import would create a second table. A local file's name and text are screen
/// values alone: the input schema never carries them, and nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's digest, the table's entry count and its stamp</b>: the fresh read composes them, the
/// fingerprint holds them, and the port refuses the write <code>INTEROP.LOOKUP.IMPORTCHANGED</code> unless the file and the table read the
/// same at the write.</p>
/// <p><b>It is destructive</b>: an import replaces the table's entries without asking, which cannot be undone from OcuPilot. It
/// declares <code>%Ens_LookupTables:WRITE</code> and WRITE on the namespace's globals database (AD-8), PathPort's pairs when it names a
/// server file, and performs the classic Import dialog's operation (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropLookupTableImport Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.lookuptables.import";

Parameter DESCRIPTION = "Propose importing one lookup table from an export file on the server, which replaces the table of that name, or creates it, with the file's entries; keys the file lacks are removed, and that cannot be undone. Name the table the file holds in `Name`, exactly as the Lookup tables list reports it in its Name column. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must hold exactly one lookup table with at least one entry, in the form the Export action writes, and nothing else: a file with a class, a routine, two tables or no entry is refused. If the file or the table changes before the proposal is confirmed, nothing is imported.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropLookupTableList";

/// <p>The fresh read: the file's table, composed from the file and the table as it stands.</p>
Parameter READTYPE = "IMPORTTABLE";

Parameter READANSWERS = "Table,FileEntries,Digest,Present,Entries,Modified,Namespace,root,path,fileName,content";

Parameter WRITERESOURCE = "%Ens_LookupTables";

Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path,import-local=fileName:content";

Parameter WRITETYPE = "IMPORT";

/// <p>Declared: an import replaces a table's entries without asking.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The import read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Digest";

/// <p>The file and the table the user reviewed, and the namespace. A local file's <code>content</code> is in it so the screen's write
/// carries the text it read; it is empty in an agent's proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,root,path,fileName,content,Table,FileEntries,Digest,Present,Entries,Modified";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "INTEROP.LOOKUP.IMPORTSHAPE,INTEROP.LOOKUP.TOOLARGE,INTEROP.LOOKUP.TABLECASE,INTEROP.LOOKUP.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The classic dialog whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.Dialog.Import";

Parameter CONSEQUENCECODE = "INTEROP.LOOKUP.IMPORT";

/// <p>The reviewed values the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>, comma-separated.</p>
Parameter REVIEWED = "Digest=digest,Entries=entries,Modified=modified";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTLOOKUPTABLES
}

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed values. They reach the port
/// through <method>PortQuery</method>; only <code>Name</code>, <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY, ##class(OcuPilot.Port.InteropPort).#FILENAMEKEY, ##class(OcuPilot.Port.InteropPort).#CONTENTKEY, "Digest", "Entries", "Modified")
}

/// <p>The schema: the table the file holds and the server file, each required, and the agent's own words. The local file and the
/// reviewed values are never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": "The lookup table the file holds, named exactly as the Lookup tables list reports it in its Name column, letter case included. A file that holds another table is refused."})
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

/// <p>What is wrong with the agent's arguments, or <code>""</code>: the file, by
/// <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments -- the file as sent, unresolved -- and, once the fresh read <var>pFresh</var> is
/// there, the reviewed <code>Digest</code>, <code>Entries</code> and <code>Modified</code> it answered, so the write compares the file
/// and the table as the user saw them. The fresh read is composed from the file's values, so the first call, before it, carries only
/// the file (AD-51).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY, ##class(OcuPilot.Port.InteropPort).#FILENAMEKEY, ##class(OcuPilot.Port.InteropPort).#CONTENTKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    If $IsObject(pFresh) {
        If pFresh.%GetTypeOf("Digest") = "string" Do pArgs.%Set("Digest", pFresh.%Get("Digest"), "string")
        If pFresh.%GetTypeOf("Entries") = "number" Do pArgs.%Set("Entries", pFresh.%Get("Entries"), "number")
        If pFresh.%GetTypeOf("Modified") = "string" Do pArgs.%Set("Modified", pFresh.%Get("Modified"), "string")
    }
    Quit $$$OK
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>), then every subject value of the
/// payload <var>pPayload</var> under the port's own query keys -- each file string that is not empty, and the reviewed digest, count and
/// stamp where the payload has them, an empty stamp included -- so the confirm's write and the screen's import the file the user reviewed
/// (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY, ##class(OcuPilot.Port.InteropPort).#FILENAMEKEY, ##class(OcuPilot.Port.InteropPort).#CONTENTKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    For tI = 1:1:$Length(..#REVIEWED, ",") {
        Set tField = $Piece($Piece(..#REVIEWED, ",", tI), "=", 1)
        Set tType = pPayload.%GetTypeOf(tField)
        If (tType = "string") || (tType = "number") Set pQuery($Piece($Piece(..#REVIEWED, ",", tI), "=", 2)) = pPayload.%Get(tField)
    }
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's),
/// <code>Table</code> (the table the file holds, and the table that stands now when there is one) and <code>Entries</code> (the
/// entries the table holds now, and the file's). A read that answered no table or no entry count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Table") '= "string") || (pFresh.%Get("Table") = "") || (pFresh.%GetTypeOf("FileEntries") '= "number") || (pFresh.%GetTypeOf("Entries") '= "number") {
            Set pProblem = "this instance did not read the import file's table and its entries, and a file whose table is unknown is not one to import"
            Quit
        }
        Set tPresent = +pFresh.%Get("Present")
        Set tFile = $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName"))
        Do ..PushRow(pRows, "File", "", tFile)
        Do ..PushRow(pRows, "Table", $Select(tPresent: pFresh.%Get("Table"), 1: ""), pFresh.%Get("Table"))
        Do ..PushRow(pRows, "Entries", $Select(tPresent: pFresh.%Get("Entries"), 1: 0), pFresh.%Get("FileEntries"))
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

/// <p>The table's name, which the card titles it by: the fresh read's <code>Table</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Table") = "string") Quit pFresh.%Get("Table")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

}
