/// <p>The Resources list's Import (Story 21.19, AD-6, AD-10, AD-21, AD-51, AD-52, AD-53, AD-58): every resource an export file holds replaces the
/// resource of the same name on this instance, or is created, through <class>OcuPilot.Port.ResourceTransferPort</class>. Two callers reach it:
/// the list's <code>import</code>, from a server file named by its <code>root</code> and <code>path</code> values, and <code>import-local</code>,
/// from a file on the person's computer sent as its <code>fileName</code> and <code>content</code> values; and the agent's proposal and
/// confirmation, which names a server file only.</p>
/// <p><b>The target is the literal <parameter>OcuPilot.Port.ResourceTransferPort.IMPORTID</parameter></b>, whatever the caller sends, and the file is
/// <code>root</code> and <code>path</code> (AD-21's sixth case), resolved as a source. The port reviews the file's text and refuses a file that is
/// not a resource export or holds no resource. A local file's name and text are screen values alone: the input schema never carries them, and
/// nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's resource names and digest and the count of resources it replaces</b>: the fresh read composes them, the
/// fingerprint holds them, and the port refuses the write <code>RESOURCEFILE.CHANGED</code> unless the file reads the same at the write. A file
/// that gives one of OcuPilot's own resources a public permission it does not hold is refused as every resource write is
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ImportedResources</method>), at the confirm, in the screen's gate and again in the port's write.</p>
/// <p><b>It is destructive</b>: an import overwrites a resource of the same name without asking, which cannot be undone from OcuPilot. It
/// declares the screen's own pairs, PathPort's pairs when it names a server file (<method>ArgumentPairs</method>), and performs the classic
/// import's operation (AD-44).</p>
Class OcuPilot.Screen.Tool.ResourceImport Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.resources.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DESCRIPTION = "Propose importing every resource of a resource export file on the server, which overwrites a resource of the same name, or creates it; that cannot be undone. Send the literal 'import' as the name. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must be in the form the resources Export action writes. A file that is not an export, or holds no resource, is refused, and so is one that gives an OcuPilot resource a public permission it does not hold. If the file or the resources change before the proposal is confirmed, nothing is imported.";

/// <p>The port that resolves the file, reads its resources and calls the vendor (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.ResourceTransferPort";

/// <p>The fresh read: the file as reviewed, composed from the file's values.</p>
Parameter READTYPE = "IMPORTSET";

Parameter READSVALUES As BOOLEAN = 1;

Parameter READANSWERS = "Names,Digest,Count,Replaces,Entries,root,path,fileName,content";

Parameter WRITETYPE = "IMPORT";

/// <p>The list's import from a server file and from a local file.</p>
Parameter SCREENACTIONS = "import,import-local";

Parameter SCREENVALUES = "import=root:path,import-local=fileName:content";

/// <p>No body: the port composes the call (<parameter>OcuPilot.Port.ResourceTransferPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: an import overwrites a resource of the same name without asking.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The file and the resources the user reviewed. A local file's <code>content</code> is in it so the screen's write carries the text it read;
/// it is empty in an agent's proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "root,path,fileName,content,Names,Digest,Count,Replaces";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "RESOURCEFILE.SHAPE,RESOURCEFILE.TOOLARGE";

/// <p>The classic page whose Import this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.ExportResource";

/// <p>The pair the write itself names, which the screen's own set already holds.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The consequence code the proposal card and the dialog carry.</p>
Parameter CONSEQUENCECODE = "RESOURCEFILE.IMPORT";

/// <p>The read-back compares the digest of the file the write was made from with the file read again.</p>
Parameter READBACKFIELDS = "Digest";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p>The reviewed values the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>, comma-separated.</p>
Parameter REVIEWED = "Names=names,Digest=digest";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.ResourceTransferPort).#ENDPOINT
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.ResourceTransferPort).#IDPARAM
}

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed values. They reach the port through
/// <method>PortQuery</method>; only <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#FILENAMEPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#CONTENTPARAM, "Names", "Digest")
}

/// <p>The schema: the literal target and the server file, each required, and the agent's own words. The local file and the reviewed values are
/// never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'import': an import names the file by root and path, not by a resource.", "string")
    }
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>The screen's own pairs, then the custom resource of the <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
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
    If (pProblem = "") && ($ZConvert(pIdValue, "L") '= ##class(OcuPilot.Port.ResourceTransferPort).#IMPORTID) Set pProblem = "'" _ ..IdArgument() _ "' is the literal 'import'"
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments -- the file as sent, unresolved -- and, once the fresh read <var>pFresh</var> is there, the
/// reviewed <code>Names</code> and <code>Digest</code> it answered, so the write compares the file as the user saw it.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#FILENAMEPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#CONTENTPARAM {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    If $IsObject(pFresh) {
        For tField = "Names", "Digest" {
            If pFresh.%GetTypeOf(tField) = "string" Do pArgs.%Set(tField, pFresh.%Get(tField), "string")
        }
    }
    Quit $$$OK
}

/// <p>Every subject value of the payload <var>pPayload</var> under the port's own query keys -- each file string that is not empty, and the
/// reviewed names and digest where the payload has them -- so the confirm's write and the screen's import the file the user reviewed
/// (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#FILENAMEPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#CONTENTPARAM {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    For tI = 1:1:$Length(..#REVIEWED, ",") {
        Set tField = $Piece($Piece(..#REVIEWED, ",", tI), "=", 1)
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery($Piece($Piece(..#REVIEWED, ",", tI), "=", 2)) = pPayload.%Get(tField)
    }
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's),
/// <code>Resources</code> (the file's resource names), and <code>Replaced</code> (how many of them the instance already holds, only when above
/// zero). A read that answered no names is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Names") '= "string") || (pFresh.%GetTypeOf("Replaces") '= "number") {
        Set pProblem = "this instance did not read the import file's resources, and a file whose resources are unknown is not one to import"
        Quit $$$OK
    }
    Do ..PushRow(pRows, "File", $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName")))
    Do ..PushRow(pRows, "Resources", $Replace(pFresh.%Get("Names"), ##class(OcuPilot.Port.ResourceTransferPort).#NAMESEPARATOR, ", "))
    If pFresh.%Get("Replaces") > 0 Do ..PushRow(pRows, "Replaced", pFresh.%Get("Replaces"))
    Quit $$$OK
}

/// <p>One card row on <var>pRows</var>, whose after-value is <var>pAfter</var>.</p>
ClassMethod PushRow(pRows As %DynamicArray, pField As %String, pAfter As %String) [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pAfter, "string")
    Do pRows.%Push(tRow)
}

/// <p>What the screen shows of the import the port answered <var>pWritten</var> for: the count the vendor imported, never the file.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    Do tOutput.%Set("Count", +pWritten.%Get("Count"), "number")
    Quit tOutput
}

/// <p><parameter>CONSEQUENCECODE</parameter>, whatever the payload: an import overwrites a resource of the same name.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
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
