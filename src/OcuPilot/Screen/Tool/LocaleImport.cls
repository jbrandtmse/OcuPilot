/// <p>Locale definitions' Import (Story 21.15, AD-6, AD-10, AD-21, AD-51, AD-52, AD-53, AD-58): the custom locales, tables and sub-tables an export
/// file holds replace those of the same name on this instance, or are created, through <class>OcuPilot.Port.LocalePort</class>. Two callers
/// reach it: the list's <code>import</code>, from a server file named by its <code>root</code> and <code>path</code> values, and
/// <code>import-local</code>, from a file on the person's computer sent as its <code>fileName</code> and <code>content</code> values; and the
/// agent's proposal and confirmation, which names a server file only.</p>
/// <p><b>The target is the literal <parameter>OcuPilot.Port.LocalePort.IMPORTID</parameter></b>, whatever the caller sends, and the file is
/// <code>root</code> and <code>path</code> (AD-21's sixth case), resolved as a source. The port reviews the file's text: it keeps only the custom
/// records, counts the shipped ones it drops, and refuses a file that is not an export, holds no custom record, or would replace the current locale
/// or a table it loads (<code>LOCALE.IMPORT.CURRENT</code>), key on or off. A local file's name and text are screen values alone: the input
/// schema never carries them, and nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's digest and the count of records it replaces</b>: the fresh read composes them, the fingerprint holds them,
/// and the port refuses the write <code>LOCALE.IMPORT.CHANGED</code> unless the file and the records read the same at the write.</p>
/// <p><b>It is destructive</b>: an import replaces a custom locale or table without asking, which cannot be undone from OcuPilot. It declares
/// <code>%DB_IRISSYS:WRITE</code> (AD-8), PathPort's pairs when it names a server file, and performs the classic Import Locale page's operation
/// (AD-44).</p>
Class OcuPilot.Screen.Tool.LocaleImport Extends OcuPilot.Screen.Tool.LocaleAction
{

Parameter TOOLNAME = "osmgmt.locales.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

Parameter DESCRIPTION = "Propose importing the custom locales and tables of an export file on the server, which replaces a custom locale or table of the same name, or creates it; that cannot be undone. Send the literal 'import' as the name. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must be in the form the locale Export action writes. Only the custom records, whose names start with y, are imported; the records InterSystems ships are skipped. A file that is not an export, holds no custom record, or would replace the current locale or a table it loads is refused. If the file or the locales change before the proposal is confirmed, nothing is imported.";

/// <p>The fresh read: the file as reviewed, composed from the file's values.</p>
Parameter READTYPE = "IMPORTFILE";

Parameter READSVALUES As BOOLEAN = 1;

Parameter READANSWERS = "Digest,Locales,Truncated,LocaleCount,TableCount,SubTableCount,Replaces,Skipped,root,path,fileName,content";

Parameter WRITETYPE = "IMPORT";

Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path,import-local=fileName:content";

/// <p>Declared: an import replaces a custom locale or table without asking.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The file and the counts the user reviewed. A local file's <code>content</code> is in it so the screen's write carries the text it read; it is
/// empty in an agent's proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "root,path,fileName,content,Digest,LocaleCount,TableCount,SubTableCount,Replaces";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "LOCALE.IMPORT.SHAPE,LOCALE.IMPORT.EMPTY,LOCALE.IMPORT.CURRENT,LOCALE.TOOLARGE";

Parameter CLASSICPAGES = "%CSP.UI.Portal.NLSImport";

Parameter CONSEQUENCECODE = "LOCALE.IMPORT";

/// <p>The read-back compares the digest of the file the write was made from with the file read again.</p>
Parameter READBACKFIELDS = "Digest";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

Parameter IDDESCRIPTION = "Send the literal 'import': an import names the file by root and path, not by a locale.";

/// <p>The reviewed values the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>, comma-separated.</p>
Parameter REVIEWED = "Digest=digest,Replaces=replaces";

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed values. They reach the port through
/// <method>PortQuery</method>; only <code>Name</code>, <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.LocalePort).#ROOTPARAM, ##class(OcuPilot.Port.LocalePort).#PATHPARAM, ##class(OcuPilot.Port.LocalePort).#FILENAMEPARAM, ##class(OcuPilot.Port.LocalePort).#CONTENTPARAM, "Digest", "Replaces")
}

/// <p>The schema: the literal target and the server file, each required, and the agent's own words. The local file and the reviewed values are
/// never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>PathPort's pairs when <var>pArgs</var> names a server file by a non-empty <code>root</code> (AD-21's sixth case, AD-29); none
/// otherwise.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerExport).FilePairs(pArgs, .pResolved)
}

/// <p>What is wrong with the agent's arguments, or <code>""</code>: the file, by <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method>
/// (AD-55); the target must be the literal.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    If (pProblem = "") && (pIdValue '= ##class(OcuPilot.Port.LocalePort).#IMPORTID) Set pProblem = "'" _ ..IdArgument() _ "' is the literal 'import'"
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments -- the file as sent, unresolved -- and, once the fresh read <var>pFresh</var> is there, the
/// reviewed <code>Digest</code> and <code>Replaces</code> it answered, so the write compares the file and the records as the user saw them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.LocalePort).#ROOTPARAM, ##class(OcuPilot.Port.LocalePort).#PATHPARAM, ##class(OcuPilot.Port.LocalePort).#FILENAMEPARAM, ##class(OcuPilot.Port.LocalePort).#CONTENTPARAM {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    If $IsObject(pFresh) {
        If pFresh.%GetTypeOf("Digest") = "string" Do pArgs.%Set("Digest", pFresh.%Get("Digest"), "string")
        If pFresh.%GetTypeOf("Replaces") = "number" Do pArgs.%Set("Replaces", pFresh.%Get("Replaces"), "number")
    }
    Quit $$$OK
}

/// <p>Every subject value of the payload <var>pPayload</var> under the port's own query keys -- each file string that is not empty, and the
/// reviewed digest and count where the payload has them -- so the confirm's write and the screen's import the file the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.LocalePort).#ROOTPARAM, ##class(OcuPilot.Port.LocalePort).#PATHPARAM, ##class(OcuPilot.Port.LocalePort).#FILENAMEPARAM, ##class(OcuPilot.Port.LocalePort).#CONTENTPARAM {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    For tI = 1:1:$Length(..#REVIEWED, ",") {
        Set tField = $Piece($Piece(..#REVIEWED, ",", tI), "=", 1)
        Set tType = pPayload.%GetTypeOf(tField)
        If (tType = "string") || (tType = "number") Set pQuery($Piece($Piece(..#REVIEWED, ",", tI), "=", 2)) = pPayload.%Get(tField)
    }
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's),
/// <code>Locales</code> (the custom locales' names), <code>Tables</code> and <code>Subtables</code> (the counts kept), <code>Replaced</code>
/// (how many of the kept records the instance already holds) and <code>Skipped</code> (the records dropped), the last two only when above zero. A
/// read that answered no counts is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("LocaleCount") '= "number") || (pFresh.%GetTypeOf("TableCount") '= "number") || (pFresh.%GetTypeOf("SubTableCount") '= "number") || (pFresh.%GetTypeOf("Locales") '= "array") {
            Set pProblem = "this instance did not read the import file's records, and a file whose records are unknown is not one to import"
            Quit
        }
        Set tFile = $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName"))
        Set tNames = ""
        Set tIterator = pFresh.%Get("Locales").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ", ") _ tName
        }
        Do ..PushRow(pRows, "File", "", tFile)
        Do ..PushRow(pRows, "Locales", "", tNames)
        Do ..PushRow(pRows, "Tables", "", pFresh.%Get("TableCount"))
        Do ..PushRow(pRows, "Subtables", "", pFresh.%Get("SubTableCount"))
        If pFresh.%Get("Replaces") > 0 Do ..PushRow(pRows, "Replaced", "", pFresh.%Get("Replaces"))
        If pFresh.%Get("Skipped") > 0 Do ..PushRow(pRows, "Skipped", "", pFresh.%Get("Skipped"))
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

/// <p>What the screen shows of the import the port answered <var>pWritten</var> for: the counts the vendor imported, never the file.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    For tField = "Locales", "Tables", "SubTables" {
        Do tOutput.%Set(tField, +pWritten.%Get(tField), "number")
    }
    Quit tOutput
}

/// <p>The file's name, which the card titles the import by: the fresh read's <code>path</code> or <code>fileName</code>, else the agent's
/// own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("path") = "string") && (pFresh.%Get("path") '= "") Quit pFresh.%Get("path")
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("fileName") = "string") && (pFresh.%Get("fileName") '= "") Quit pFresh.%Get("fileName")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("path") = "string") Quit pArgs.%Get("path")
    Quit ""
}

}
