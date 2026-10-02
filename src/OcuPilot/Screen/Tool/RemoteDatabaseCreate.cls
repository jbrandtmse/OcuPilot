/// <p>The Remote databases list's create tool (AD-54, AD-55, Story 18.16): propose a new remote
/// database, a configuration whose file is on an ECP data server. It reads the intended configuration
/// name fresh through <code>Database.ConfigCRUD</code>'s <code>GET</code>, requires that read to answer
/// <b>nothing</b>, composes <code>{Server, Directory}</code> from its arguments and mints a proposal the
/// user confirms. It writes nothing.</p>
/// <p><b>The mint lists nothing</b> (AD-7): it asks the name's shape, whether the data server is
/// defined and whether a directory is named (<method>ArgumentProblem</method>). The directory is
/// checked against the data server's own listing by <class>OcuPilot.Port.RemoteDatabasePort</class>
/// at the confirm and at a Save (AD-21's seventh case), and the card states that wait before the
/// confirm (<method>Consequence</method>).</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed
/// create rewriting a configuration somebody else created since the mint (AD-54).</p>
Class OcuPilot.Screen.Tool.RemoteDatabaseCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.remotedatabases.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RemoteDatabaseList";

Parameter DESCRIPTION = "Propose a new remote database on this instance: a database configuration whose file is on an ECP data server. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the database, the data server as this instance's data servers list reports it, and the database's directory exactly as that data server lists it. The directory is checked against the data server's own listing only when the user confirms, which can take up to 20 seconds; this instance's license must include ECP.";

/// <p>The port that sequences the create (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.RemoteDatabasePort";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>The configuration template fields this tool never admits: a remote database takes no mount
/// setting, and its stream location is shown, never set.</p>
Parameter EXCLUDEDFIELDS = "StreamLocation,ClusterMountMode,MountAtStartup,MountRequired";

/// <p>The pair the create needs beyond the list's own: the system database's <code>WRITE</code>,
/// since the vendor's configuration <code>PUT</code> writes it (AD-8, measured at Story 18.16's
/// Task 0).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.RemoteDatabase";

/// <p>The consequence code the card states: the confirm lists the data server's databases first.</p>
Parameter CONSEQUENCE = "DATABASE.REMOTELIST";

ClassMethod Endpoint() As %String
{
    Quit "Database.ConfigCRUD"
}

/// <p>The derived fields this tool admits: <code>Server</code> and <code>Directory</code>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>EXCLUDEDFIELDS</parameter>.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListFromString(..#EXCLUDEDFIELDS)
}

/// <p>The derived schema with the name, the data server and the directory described, the last two
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions("Name") = "The name the new database will take: a letter, then letters, digits, _ or -, at most 64 characters. The instance stores it upper case, and a name it already holds in any case, local or remote, is refused."
    Set tDescriptions("Server") = "The ECP data server the database's file is on, exactly as this instance's data servers list reports it."
    Set tDescriptions("Directory") = "The database's directory on the data server, exactly as that data server lists it. Its IRISSYS directory is refused."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    For tField = "Server", "Directory" {
        If tProperties.%GetTypeOf(tField) = "object" Do tSchema.%Get("required").%Push(tField)
    }
    Quit tSchema
}

/// <p>The create rules of <method>OcuPilot.Area.OsMgmt.RemoteDatabaseRules.Problem</method> over the
/// agent's arguments (AD-55). The name look-up is skipped, the mint's absence read having answered it,
/// and nothing is listed.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.RemoteDatabaseRules).Problem(pIdValue, pArgs, "create", .pProblem)
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: every confirm lists the data server's
/// databases before it writes.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>, then the custom resource of the
/// <parameter>CLASSICPAGES</parameter> dialog, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
