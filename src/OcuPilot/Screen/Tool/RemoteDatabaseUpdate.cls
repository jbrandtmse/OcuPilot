/// <p>The Remote databases list's re-point (AD-4, AD-6, AD-55, Story 18.16): propose moving one remote
/// database to another data server or directory. It reads the configuration fresh through
/// <code>Database.ConfigCRUD</code>'s <code>GET</code>, merges the arguments over it and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set with the changed fields applied,
/// and the fingerprint covers every field it sends. Its settable fields are <code>Server</code> and
/// <code>Directory</code>; the stream location and the mount settings are sent as read.
/// <class>OcuPilot.Port.RemoteDatabasePort</class> refuses a local configuration, and its bounded
/// listing checks the directory at the confirm and at a Save (AD-21's seventh case), never at the
/// mint.</p>
Class OcuPilot.Screen.Tool.RemoteDatabaseUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.remotedatabases.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RemoteDatabaseList";

Parameter DESCRIPTION = "Propose moving one remote database to another ECP data server or directory. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the remote databases list reports it and send only what changes: the data server, as this instance's data servers list reports it, or the directory, exactly as that data server lists it. The directory is checked against the data server's own listing only when the user confirms, which can take up to 20 seconds.";

/// <p>The port that sequences the write (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.RemoteDatabasePort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived fields this tool admits, comma-separated.</p>
Parameter PERMITTEDFIELDS = "Server,Directory";

/// <p>The pair every re-point needs beyond the list's own: the system database's <code>WRITE</code>
/// (AD-8, measured at Story 18.16's Task 0).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The pair a write sending <code>MountRequired</code> true needs as well, as the local mounting
/// edit's does (<method>OcuPilot.Screen.Tool.LocalDatabaseUpdateMount.ArgumentPairs</method>).</p>
Parameter OPERATERESOURCE = "%Admin_Operate";

Parameter OPERATEPERMISSION = "USE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.RemoteDatabase";

/// <p>The names the port's read adds that this write never sends.</p>
Parameter READONLYNAMES = "DeleteFile";

/// <p>The consequence code the card states: the confirm lists the data server's databases first.</p>
Parameter CONSEQUENCE = "DATABASE.REMOTELIST";

ClassMethod Endpoint() As %String
{
    Quit "Database.ConfigCRUD"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the name, the data server and the directory described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions("Name") = "The remote database to change, as this instance's remote databases list reports it."
    Set tDescriptions("Server") = "The ECP data server the database's file is on, exactly as this instance's data servers list reports it."
    Set tDescriptions("Directory") = "The database's directory on the data server, exactly as that data server lists it. Its IRISSYS directory is refused."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit tSchema
}

/// <p>The kernel's merge over the fresh read less <parameter>READONLYNAMES</parameter>, so the card's
/// unchanged fields are the ones the write sends. A local configuration is the port's refusal at the
/// write, on both callers.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tFresh = ##class(OcuPilot.Port.DatabasePort).Without(pFresh, $ListFromString(..#READONLYNAMES))
    Quit ##super(tFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The update rules of <method>OcuPilot.Area.OsMgmt.RemoteDatabaseRules.Problem</method> over the
/// agent's arguments (AD-55): a data server it names must be defined and a directory it names
/// non-empty. Nothing is listed.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.RemoteDatabaseRules).Problem(pIdValue, pArgs, "update", .pProblem)
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

/// <p><parameter>OPERATERESOURCE</parameter> when the write sends <code>MountRequired</code> true: when
/// <var>pArgs</var> sets it, or when the configuration its <code>Name</code> argument names holds it
/// true, since the complete set carries the stored value (AD-4). That configuration is read through
/// this tool's own port as the caller; a read that fails for any reason but absence answers the pair,
/// and an absent configuration none, its write refused later.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) Quit ""
    Set tOperate = $ListBuild($ListBuild(..#OPERATERESOURCE, ..#OPERATEPERMISSION))
    Set tType = pArgs.%GetTypeOf("MountRequired")
    If (tType '= "unassigned") && (tType '= "null") Quit $Select(##class(OcuPilot.Port.DatabasePort).Truthy(pArgs.%Get("MountRequired")): tOperate, 1: "")
    If pArgs.%GetTypeOf(..IdArgument()) '= "string" Quit ""
    Kill tQuery
    Set tQuery(..IdParam()) = pArgs.%Get(..IdArgument())
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..#READTYPE, .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: "", 1: tOperate)
    If '$IsObject($Get(tFresh)) Quit ""
    Quit $Select(##class(OcuPilot.Port.DatabasePort).Truthy(tFresh.%Get("MountRequired")): tOperate, 1: "")
}

}
