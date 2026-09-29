/// <p>The Local databases list's delete tool (AD-6, AD-8, AD-51, AD-56 (ii)): propose deleting one
/// database configuration and, when asked, its file. It reads the configuration fresh through
/// <code>Database.ConfigCRUD</code>'s <code>GET</code> and mints a proposal whose card lists the
/// directory and mounting settings it removes and whose impact names the namespaces and web
/// applications that use the database and the configuration names that share its file. It writes
/// nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor reads no body for <code>DELETE</code>, and the one
/// argument, <parameter>DELETEFILEFIELD</parameter>, reaches <class>OcuPilot.Port.DatabasePort</class>
/// through the port query (<method>PortQuery</method>). The port deletes the configuration, which the
/// vendor refuses while a namespace uses it, and then the file only when asked, when the database is
/// local and when no other configuration name shares its directory.</p>
/// <p><b>Its fingerprint covers the directory, the data server and the argument</b>: configuration
/// does not move by itself, so any change since the mint refuses the confirm, and what the user
/// reviewed is whether the file goes too.</p>
/// <p>Deleting OcuPilot's own database, the install namespace's globals or routines database, or one
/// of the instance's own databases is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTDATABASE</parameter>) on both callers.</p>
Class OcuPilot.Screen.Tool.LocalDatabaseDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.localdatabases.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose deleting one local database from this instance's configuration, and optionally its file. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the local databases list reports it and say whether its file and volume files are deleted too. The instance refuses the delete while a namespace uses the database, and a file another database name shares is never deleted.";

/// <p>The port that sequences the delete (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DatabasePort";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted configuration, and a deleted file with its data, are gone, and OcuPilot
/// keeps no copy to restore them from.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the Local databases list's Delete carries out (AD-53), whose one value is
/// <parameter>DELETEFILEFIELD</parameter> (AD-56 (ii)).</p>
Parameter SCREENACTIONS = "delete";

Parameter SCREENVALUES = "delete=DeleteFile";

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475): the configuration's
/// fields and the argument field it adds.</p>
Parameter READANSWERS = "Directory,Server,MountAtStartup,MountRequired,DeleteFile";

Parameter PRECONDITIONFIELD = "Directory";

Parameter FINGERPRINTSUBJECT = "Directory,Server,DeleteFile";

/// <p>The rows the card lists: the settings the configuration delete removes.</p>
Parameter REMOVALROWS = "Directory,MountAtStartup,MountRequired";

/// <p>The one argument: whether the database's file and volume files are deleted too.</p>
Parameter DELETEFILEFIELD = "DeleteFile";

/// <p>The pair the delete needs beyond the list's own: the system database's <code>WRITE</code>
/// (AD-8 as amended 2026-09-29).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.DatabaseDelete";

ClassMethod Endpoint() As %String
{
    Quit "Database.ConfigCRUD"
}

/// <p><parameter>DELETEFILEFIELD</parameter> alone: the tool sends no body, so its field list is
/// empty by derivation, and the one argument reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#DELETEFILEFIELD)
}

/// <p>The identifying property described and <parameter>DELETEFILEFIELD</parameter> required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The database to delete, as this instance's own local databases list reports it. A database this instance does not hold is refused.", "string")
    }
    Do tProperties.%Set(..#DELETEFILEFIELD, {"type": "boolean", "description": "Whether the database's file and its volume files are deleted too. A file another database name shares is kept whatever this says."})
    Do tSchema.%Get("required").%Push(..#DELETEFILEFIELD)
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state.
/// A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that database's directory, and a database whose file is unknown is not one to delete"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The stored payload's <parameter>DELETEFILEFIELD</parameter> under the port's own query key, so
/// the confirm's write and the screen's write carry what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tType = pPayload.%GetTypeOf(..#DELETEFILEFIELD)
    If (tType = "unassigned") || (tType = "null") Quit
    Set pQuery(##class(OcuPilot.Port.DatabasePort).#DELETEFILEQUERY) = $Select(##class(OcuPilot.Port.DatabasePort).Truthy(pPayload.%Get(..#DELETEFILEFIELD)): "1", 1: "0")
}

/// <p>The screen's <code>delete</code> value as this tool's argument (AD-56 (ii)): <code>true</code>
/// or <code>false</code>, and any other spelling refused.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) Set tValue = $ZConvert(pValues.%Get(..#DELETEFILEFIELD), "L")
    If (tValue '= "true") && (tValue '= "false") {
        Set pProblem = "'" _ ..#DELETEFILEFIELD _ "' is true or false"
        Quit $$$OK
    }
    Do pArgs.%Set(..#DELETEFILEFIELD, (tValue = "true"), "boolean")
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> dialog, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
