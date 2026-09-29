/// <p>The Local databases list's mounting edit (AD-4, AD-6, AD-55): propose a change to how one
/// database configuration mounts. It reads the configuration fresh through
/// <code>Database.ConfigCRUD</code>'s <code>GET</code>, merges the arguments over it and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete configuration set with the changed
/// fields applied, and the fingerprint covers every field it sends. The vendor's <code>PUT</code> is
/// an upsert, so the confirm's fingerprint re-read is what refuses a configuration deleted since the
/// mint. Its settable fields are the three mounting settings; the directory, data server and stream
/// location are sent as read.</p>
Class OcuPilot.Screen.Tool.LocalDatabaseUpdateMount Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.localdatabases.updatemount";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose a change to how one local database mounts: at startup, required at startup, or in cluster mount mode. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the local databases list reports it and send only the settings to change.";

/// <p>The port every database tool reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DatabasePort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "MountAtStartup,MountRequired,ClusterMountMode";

/// <p>The pair every mounting edit needs beyond the list's own: the system database's
/// <code>WRITE</code>, since the vendor's configuration <code>PUT</code> writes it (AD-8 as amended
/// 2026-09-29).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The pair an edit that sets <code>MountRequired</code> true needs as well (the vendor's #921
/// without it, measured on <code>ocupilot-b-ci</code>).</p>
Parameter OPERATERESOURCE = "%Admin_Operate";

Parameter OPERATEPERMISSION = "USE";

/// <p>The classic page whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Database";

/// <p>The names the port's read adds that this write never sends.</p>
Parameter READONLYNAMES = "DeleteFile";

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

/// <p>The derived schema with the name and the three settings described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions("Name") = "The database to change, as this instance's local databases list reports it."
    Set tDescriptions("MountAtStartup") = "Whether the instance mounts the database when it starts."
    Set tDescriptions("MountRequired") = "Whether the instance refuses to start when it cannot mount the database."
    Set tDescriptions("ClusterMountMode") = "Whether the database is mounted in cluster mode."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit tSchema
}

/// <p>The kernel's merge over the fresh read less <parameter>READONLYNAMES</parameter>, so the card's
/// unchanged fields are the ones the write sends.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tFresh = ##class(OcuPilot.Port.DatabasePort).Without(pFresh, $ListFromString(..#READONLYNAMES))
    Quit ##super(tFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>, then the custom resource of the
/// <parameter>CLASSICPAGES</parameter> page, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p><parameter>OPERATERESOURCE</parameter> when the write sends <code>MountRequired</code> true:
/// when <var>pArgs</var> sets it true, or leaves it out while the configuration its
/// <code>Name</code> argument names holds it true, since the complete set carries the stored value
/// (AD-4) and the vendor answers #921 for it all the same (measured on <code>ocupilot-b-ci</code>).
/// That configuration is read through this tool's own port as the caller; a read that fails for any
/// reason but absence answers the pair, and an absent configuration none, its write refused later.</p>
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
