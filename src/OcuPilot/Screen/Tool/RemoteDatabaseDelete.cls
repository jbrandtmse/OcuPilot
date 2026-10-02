/// <p>The Remote databases list's delete tool (AD-6, AD-8, AD-51, Story 18.16): propose removing one
/// remote database from this instance's configuration. Its file is on the data server and stays. It
/// reads the configuration fresh through <code>Database.ConfigCRUD</code>'s <code>GET</code> and mints
/// a proposal whose card lists the data server and directory it removes and whose impact names the
/// namespaces that use the database and the web applications that run in them. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): no argument and no body. Its port,
/// <class>OcuPilot.Port.RemoteDatabasePort</class>, refuses a local configuration
/// (<parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter>) and sends <code>DELETE /database</code>
/// alone, which the vendor refuses while a namespace uses the database
/// (<parameter>OcuPilot.Api.DatabaseError.INUSE</parameter>).</p>
/// <p><b>Its fingerprint covers the data server and the directory</b>: a configuration does not move
/// by itself, so a re-point since the mint refuses the confirm.</p>
/// <p>Deleting OcuPilot's own database or one of the instance's own is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTDATABASE</parameter>) on both callers.</p>
Class OcuPilot.Screen.Tool.RemoteDatabaseDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.remotedatabases.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RemoteDatabaseList";

Parameter DESCRIPTION = "Propose removing one remote database from this instance's configuration. Its file on the data server stays. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the remote databases list reports it. The instance refuses the delete while a namespace uses the database.";

/// <p>The port that refuses a local configuration before the delete (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.RemoteDatabasePort";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted configuration is gone, and OcuPilot keeps no copy to restore it from.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the Remote databases list's Delete carries out (AD-53), which sends no value.</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475).</p>
Parameter READANSWERS = "Directory,Server,MountAtStartup,MountRequired";

Parameter PRECONDITIONFIELD = "Server";

Parameter FINGERPRINTSUBJECT = "Server,Directory";

/// <p>The rows the card lists: what the configuration delete removes.</p>
Parameter REMOVALROWS = "Server,Directory";

/// <p>The pair the delete needs beyond the list's own: the system database's <code>WRITE</code>
/// (AD-8, measured at Story 18.16's Task 0).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic dialog whose operation this tool performs, which the classic Remote Databases page
/// opens with <code>Remote=1</code> (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.DatabaseDelete";

ClassMethod Endpoint() As %String
{
    Quit "Database.ConfigCRUD"
}

/// <p>None: the tool sends no body and takes no argument.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The identifying property described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The remote database to remove, as this instance's own remote databases list reports it. A database this instance does not hold, or a local one, is refused.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state.
/// A local configuration (an empty data server) is the port's refusal at the write, on both
/// callers.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report that database's data server, and a database whose server is unknown is not one to remove"
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
