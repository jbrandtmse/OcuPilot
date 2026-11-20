/// <p>The Resources list's export tool (AD-6, AD-21, AD-51, AD-52, AD-53, Story 21.19): write one resource, or every resource, to a server file
/// in the instance's own resource export format. Two callers reach it: the list's <code>export</code> row action, for the selected resource,
/// and <code>export-all</code>, for every resource, through <class>OcuPilot.Api.ScreenAction</class> with the file as the action's two values
/// (AD-56 (ii)); and the agent's proposal and confirmation.</p>
/// <p><b>The target is a resource's name, or the literal <parameter>OcuPilot.Port.ResourceTransferPort.ALLID</parameter> for every
/// resource</b>, and the file is two arguments, <code>root</code> and <code>path</code>, an allowed directory and a relative name under it
/// (AD-21's sixth case). <class>OcuPilot.Port.ResourceTransferPort</class> resolves them through <class>OcuPilot.Port.PathPort</class> as an
/// overwriting file whose overwrite the port declares, at the write, and the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.ResourceExportMint</class>), so a refusal lands on its field on either path. A file already at the name is
/// replaced (<method>Consequence</method>).</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and the port composes the vendor's <code>Export</code> call from the target and
/// the file. It changes no resource: it declares the screen's own pairs and <code>%Admin_FileSystemAccess:USE</code>, since it writes a file
/// (AD-8), and is not destructive. The file holds the resources' public permissions and descriptions, no secret.</p>
Class OcuPilot.Screen.Tool.ResourceExport Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.resources.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DESCRIPTION = "Propose writing one resource, or every resource, to a file on the server, in the instance's own resource export format, so another instance can import it. Name the resource exactly as the resources list reports it, or send * to export every resource. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. A resource this instance does not hold is refused.";

/// <p>The port that resolves the file and calls the vendor (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.ResourceTransferPort";

/// <p>The list's export of the selected resource and of every resource, whose two values are the file.</p>
Parameter SCREENACTIONS = "export,export-all";

Parameter SCREENVALUES = "export=root:path,export-all=root:path";

/// <p>The fresh read: the target, echoing the file the query names.</p>
Parameter READTYPE = "EXPORTSET";

Parameter WRITETYPE = "EXPORT";

/// <p>No body: the port composes the call (<parameter>OcuPilot.Port.ResourceTransferPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>What <parameter>READTYPE</parameter> answers of the subject (DW-1475).</p>
Parameter READANSWERS = "Name,Count,root,path";

/// <p>The target as reviewed and the file. The file is in the subject because the stored payload is narrowed to it, and
/// <method>PortQuery</method> reads it from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Name,Count,root,path";

/// <p>A target whose name the read did not answer is not one to export.</p>
Parameter PRECONDITIONFIELD = "Name";

/// <p>The classic page whose Export this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.ExportResource";

/// <p>The pair every file consumer declares beyond the screen's own (AD-21).</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

/// <p>The consequence code the proposal carries: a file already at the name is replaced.</p>
Parameter CONSEQUENCE = "EXPLORER.EXPORT.REPLACES";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.ResourceTransferPort).#ENDPOINT
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.ResourceTransferPort).#IDPARAM
}

/// <p><code>root</code> and <code>path</code>: the tool sends no body, and the two arguments reach the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file is resolved
/// (<class>OcuPilot.Screen.Tool.ResourceExportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ResourceExportMint"
}

/// <p>The derived schema with the target described and <code>root</code> and <code>path</code> added, both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The resource to export, exactly as this instance's own resources list reports it, or * to export every resource. A resource the list does not report is refused.", "string")
    }
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>The screen's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom resource of
/// the <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-21, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The file the agent names, refused by <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method>, where
/// <code>ResourceExportMint</code> asks it.</p>
ClassMethod FileProblem(pArgs As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
}

/// <p>The agent's file arguments refused by <method>FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own <code>PATH.*</code> refusal reaches the field it is about
/// (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ..FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The stored payload's file arguments under the port's own query keys, so the confirm's write and the screen's carry the file the user
/// reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM {
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>One state row, <code>Resources</code>: how many resources the file will hold.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Count") '= "number") {
        Set pProblem = "this instance did not report how many resources the export holds"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", "Resources", "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get("Count"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>What the screen shows of the export the port answered <var>pWritten</var> for: the <code>root</code> and <code>path</code> of the file and
/// the count of resources it holds, never the file.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    Do tOutput.%Set(##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM, pWritten.%Get(##class(OcuPilot.Port.ResourceTransferPort).#ROOTPARAM), "string")
    Do tOutput.%Set(##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM, pWritten.%Get(##class(OcuPilot.Port.ResourceTransferPort).#PATHPARAM), "string")
    Do tOutput.%Set("Count", +pWritten.%Get("Count"), "number")
    Quit tOutput
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: a file already at the name is replaced.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>The target's own name from the fresh read, which the card titles the export by.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    Quit pId
}

}
