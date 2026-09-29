/// <p>The Local databases list's create tool (AD-54, AD-55): propose a new local database. It reads
/// the intended configuration name fresh through <code>Database.ConfigCRUD</code>'s <code>GET</code>,
/// requires that read to answer <b>nothing</b>, composes the payload from its arguments and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It admits no derived field</b>: every template field of the configuration is excluded, and
/// the five declared arguments (<parameter>ARGUMENTS</parameter>) are the whole payload.
/// <class>OcuPilot.Port.DatabasePort</class> reads them from the port query
/// (<method>PortQuery</method>) and sequences the resource, the file and the configuration (AD-52 as
/// amended 2026-09-29). The directory is named by a root and a relative path, resolved through
/// <class>OcuPilot.Port.PathPort</class> at the mint (<method>ArgumentProblem</method>) and again at
/// the write, and sent only as the vendor's own <code>Directory</code> (AD-21's sixth case).</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed
/// create rewriting a configuration somebody else created since the mint (AD-54).</p>
Class OcuPilot.Screen.Tool.LocalDatabaseCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.localdatabases.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose a new local database on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the database, choose one of the instance's allowed directories as root and a new subdirectory under it as path, and optionally its initial size, whether new globals are journaled, and an existing %DB_ resource to guard it; without a resource the instance creates %DB_<NAME>.";

/// <p>The port that sequences the create (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DatabasePort";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>The declared arguments, comma-separated: the directory's root and relative path, the initial
/// size in megabytes, whether new globals are journaled, and an existing resource.</p>
Parameter ARGUMENTS = "root,path,Size,GlobalJournalState,ResourceName";

/// <p>The configuration template fields this tool never admits: the port sends the resolved
/// <code>Directory</code>, and every other field keeps the vendor's default.</p>
Parameter EXCLUDEDFIELDS = "Server,Directory,StreamLocation,ClusterMountMode,MountAtStartup,MountRequired";

/// <p>The pairs the create needs beyond the list's own (AD-8 as amended 2026-09-29): the system
/// database's <code>WRITE</code>, <code>%Admin_Secure:USE</code> for the resource the port creates or
/// checks, and <class>OcuPilot.Port.PathPort</class>'s <code>%Admin_FileSystemAccess:USE</code>.</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter SECURERESOURCE = "%Admin_Secure";

Parameter FILESYSTEMRESOURCE = "%Admin_FileSystemAccess";

Parameter USEPERMISSION = "USE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.DatabaseWizard";

/// <p>The file's initial size when the arguments name none, in megabytes.</p>
Parameter DEFAULTSIZE As INTEGER = 1;

ClassMethod Endpoint() As %String
{
    Quit "Database.ConfigCRUD"
}

/// <p>The derived fields this tool admits (none) and <parameter>ARGUMENTS</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListFromString(..#ARGUMENTS)
}

/// <p><parameter>EXCLUDEDFIELDS</parameter>.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListFromString(..#EXCLUDEDFIELDS)
}

/// <p>The derived schema (the name alone) with the five arguments described, <code>root</code>
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", "The name the new database will take: a letter, then letters, digits, _ or -, at most 64 characters. The instance stores it upper case, and a name it already holds in any case is refused, so check the local databases list first.", "string")
    }
    Do tProperties.%Set("root", {"type": "string", "description": "One of this instance's allowed directories, exactly as its Allowed directories list reports it."})
    Do tProperties.%Set("path", {"type": "string", "description": "The new database's directory under root: up to eight names separated by /, each letters, digits, '.', '_' or '-'. A directory that already holds a database is refused."})
    Do tProperties.%Set("Size", {"type": "integer", "minimum": 1, "description": "The file's initial size in megabytes. Omit it for 1."})
    Do tProperties.%Set("GlobalJournalState", {"type": "boolean", "description": "Whether new globals in the database are journaled. Omit it for true."})
    Do tProperties.%Set("ResourceName", {"type": "string", "description": "An existing resource whose name begins %DB_ to guard the database. Omit it and the instance creates %DB_<NAME>."})
    Do tSchema.%Get("required").%Push("root")
    Quit tSchema
}

/// <p>The kernel's composition with the two defaults the port applies made explicit, so the card
/// shows the size and journal state the create will use (AD-54).</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tArgs = {}
    If $IsObject(pArgs) Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tArgs.%GetTypeOf("Size") = "unassigned" Do tArgs.%Set("Size", ..#DEFAULTSIZE, "number")
    If tArgs.%GetTypeOf("GlobalJournalState") = "unassigned" Do tArgs.%Set("GlobalJournalState", 1, "boolean")
    Quit ##super(tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The create rules of <method>OcuPilot.Area.OsMgmt.DatabaseRules.Validate</method> over the
/// agent's arguments, the directory resolved and its database file tested (AD-55). The name look-up
/// is skipped: the mint's absence read has answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.DatabaseRules).Problem(pIdValue, pArgs, "create", .pProblem)
}

/// <p>The resolved directory as <code>Directory</code>, just before the port is invoked, so the
/// read-back compares the directory the configuration names. A root or path that no longer
/// resolves leaves the payload as it is, and the port's own resolution refuses the write.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve(pPayload.%Get("root"), pPayload.%Get("path"), ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, "root", "path", .tDirectory, .tHttp, .tFault, 0, 1)
    If $$$ISOK(tSC) && (tDirectory '= "") Do pPayload.%Set("Directory", tDirectory, "string")
}

/// <p>The stored payload's arguments under the port's own query keys, so the confirm's write and the
/// screen's write carry what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tNames = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = pPayload.%GetTypeOf(tName)
        If (tType = "unassigned") || (tType = "null") Continue
        If tType = "boolean" {
            Set pQuery(tName) = $Select(pPayload.%Get(tName): "1", 1: "0")
        } Else {
            Set pQuery(tName) = pPayload.%Get(tName)
        }
    }
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>, <parameter>SECURERESOURCE</parameter> and
/// <parameter>FILESYSTEMRESOURCE</parameter>, then the custom resource of the
/// <parameter>CLASSICPAGES</parameter> dialog, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION), $ListBuild(..#SECURERESOURCE, ..#USEPERMISSION), $ListBuild(..#FILESYSTEMRESOURCE, ..#USEPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
