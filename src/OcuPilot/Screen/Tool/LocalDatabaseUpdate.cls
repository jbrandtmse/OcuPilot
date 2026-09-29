/// <p>The Local databases list's file edit (AD-4, AD-6, AD-55): propose a change to one local
/// database's file settings and volume settings. It reads the file fresh through
/// <code>Database.SysCRUD</code>'s <code>GET</code>, keyed by the configuration name whose directory
/// <class>OcuPilot.Port.DatabasePort</class> resolves, merges the arguments over it and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete template set with the changed fields
/// applied, and the fingerprint covers every field it sends and the directory the name resolved to.
/// A remote configuration is refused by the port, 409
/// <parameter>OcuPilot.Api.DatabaseError.REMOTE</parameter>, before anything is sent.</p>
/// <p><b>A new volume directory is a root and a relative path</b> (<code>volumeRoot</code>,
/// <code>volumePath</code>), resolved through <class>OcuPilot.Port.PathPort</class> at the mint and
/// again at the write and sent only as the vendor's own <code>NewVolumeDirectory</code> (AD-21's sixth
/// case).</p>
Class OcuPilot.Screen.Tool.LocalDatabaseUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.localdatabases.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose a change to one local database's file settings: its maximum and expansion size, its resource, whether new globals are kept and journaled, whether it is read only, and its new volume threshold and directory. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the local databases list reports it and send only the settings to change.";

/// <p>The port that finds the file's directory (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DatabasePort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "MaxSize,ExpansionSize,ResourceName,NewGlobalIsKeep,GlobalJournalState,ReadOnly,NewVolumeThreshold";

/// <p>The template fields this tool never admits: the new volume directory, which only a root and a
/// path set, and the two it does not edit.</p>
Parameter EXCLUDEDFIELDS = "NewVolumeDirectory,NewGlobalCollation,ClusterMountMode";

/// <p>The two declared arguments a new volume directory is named by.</p>
Parameter VOLUMEARGUMENTS = "volumeRoot,volumePath";

/// <p>The pairs a change needs as well, by argument (AD-8 as amended 2026-09-29): a resource change
/// <code>%Admin_Secure:USE</code> (the vendor's #822 without it, measured on
/// <code>ocupilot-b-ci</code>), and a new volume directory <class>OcuPilot.Port.PathPort</class>'s
/// <code>%Admin_FileSystemAccess:USE</code>.</p>
Parameter SECURERESOURCE = "%Admin_Secure";

Parameter FILESYSTEMRESOURCE = "%Admin_FileSystemAccess";

Parameter USEPERMISSION = "USE";

/// <p>The classic pages whose operation this tool performs (AD-44, DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Database,%CSP.UI.Portal.DatabaseVolumes";

ClassMethod Endpoint() As %String
{
    Quit "Database.SysCRUD"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3) and
/// <parameter>VOLUMEARGUMENTS</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListFromString(..#VOLUMEARGUMENTS)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><parameter>EXCLUDEDFIELDS</parameter>.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListFromString(..#EXCLUDEDFIELDS)
}

/// <p>The derived schema with each field and the two volume arguments described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions("Name") = "The database to change, as this instance's local databases list reports it."
    Set tDescriptions("MaxSize") = "The largest the database may grow, in megabytes; 0 is unlimited."
    Set tDescriptions("ExpansionSize") = "How much the database grows at a time, in megabytes; 0 is the instance's default."
    Set tDescriptions("ResourceName") = "An existing resource whose name begins %DB_ to guard the database."
    Set tDescriptions("NewGlobalIsKeep") = "Whether a new global keeps its directory entry when it is killed."
    Set tDescriptions("GlobalJournalState") = "Whether new globals in the database are journaled."
    Set tDescriptions("ReadOnly") = "Whether the database is mounted read only."
    Set tDescriptions("NewVolumeThreshold") = "The size, in megabytes, at which the instance starts a new volume file; 0 never does."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Do tProperties.%Set("volumeRoot", {"type": "string", "description": "For a new volume directory: one of this instance's allowed directories, exactly as its Allowed directories list reports it."})
    Do tProperties.%Set("volumePath", {"type": "string", "description": "For a new volume directory: the directory under volumeRoot, up to eight names separated by /."})
    Quit tSchema
}

/// <p>The kernel's merge, with the two volume arguments left out of the payload when the arguments do
/// not name them, so the card's unchanged fields are the ones the write sends.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tFresh = pFresh
    If '$IsObject(pArgs) || ((pArgs.%GetTypeOf("volumeRoot") = "unassigned") && (pArgs.%GetTypeOf("volumePath") = "unassigned")) {
        Set tFresh = ##class(OcuPilot.Port.DatabasePort).Without(pFresh, $ListFromString(..#VOLUMEARGUMENTS))
    }
    Quit ##super(tFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The file rules of <method>OcuPilot.Area.OsMgmt.DatabaseRules.Validate</method> over the fields
/// the agent's arguments change, the new volume directory resolved (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.DatabaseRules).Problem(pIdValue, pArgs, "update", .pProblem)
}

/// <p>The resolved new volume directory as <code>NewVolumeDirectory</code>, just before the port is
/// invoked, so the read-back compares it. Arguments that no longer resolve leave the payload as it
/// is, and the port's own resolution refuses the write.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf("volumeRoot") '= "string" Quit
    If pPayload.%Get("volumeRoot") = "" Quit
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve(pPayload.%Get("volumeRoot"), pPayload.%Get("volumePath"), ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, "volumeRoot", "volumePath", .tDirectory, .tHttp, .tFault, 0, 1)
    If $$$ISOK(tSC) && (tDirectory '= "") Do pPayload.%Set("NewVolumeDirectory", tDirectory, "string")
}

/// <p>The stored payload's volume arguments under the port's own query keys (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tNames = $ListFromString(..#VOLUMEARGUMENTS)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If pPayload.%GetTypeOf(tName) '= "string" Continue
        If pPayload.%Get(tName) = "" Continue
        Set pQuery(tName) = pPayload.%Get(tName)
    }
}

/// <p>What the caller must hold: the screen's own pairs, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once. A file edit writes no system database
/// (measured on <code>ocupilot-b-ci</code>).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p><parameter>SECURERESOURCE</parameter> when <var>pArgs</var> sends <code>ResourceName</code>, and
/// <parameter>FILESYSTEMRESOURCE</parameter> when it sends <code>volumeRoot</code>.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Set tPairs = ""
    If '$IsObject(pArgs) Quit tPairs
    If pArgs.%GetTypeOf("ResourceName") = "string" Set tPairs = tPairs _ $ListBuild($ListBuild(..#SECURERESOURCE, ..#USEPERMISSION))
    If (pArgs.%GetTypeOf("volumeRoot") = "string") && (pArgs.%Get("volumeRoot") '= "") Set tPairs = tPairs _ $ListBuild($ListBuild(..#FILESYSTEMRESOURCE, ..#USEPERMISSION))
    Quit tPairs
}

}
