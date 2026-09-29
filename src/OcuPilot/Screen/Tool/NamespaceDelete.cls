/// <p>The Namespaces list's delete tool (AD-6, AD-8, AD-51): propose deleting one namespace. It reads
/// the namespace fresh through the vendor's own <code>Namespace.Namespace</code> <code>GET</code> and
/// mints a proposal whose card lists the databases it names and whose impact names the web
/// applications deleted with it. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor reads no body for <code>DELETE</code>, the tool
/// admits no settable field, and its query carries the name alone. The vendor deletes the namespace,
/// its mappings and every web application bound to it, and never a database.</p>
/// <p><b>Its fingerprint covers the three databases the read answers</b>; configuration does not
/// move by itself, so any change since the mint refuses the confirm. The vendor's answer is re-read
/// before it is believed (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>).</p>
/// <p>Deleting OcuPilot's install namespace or <code>%SYS</code> is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTNAMESPACE</parameter>) on both
/// callers.</p>
Class OcuPilot.Screen.Tool.NamespaceDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.namespaces.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter DESCRIPTION = "Propose deleting one namespace from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace as the namespaces list reports it. The instance also deletes its mappings and every web application that runs in it; its databases stay.";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type, which answers 404 for an absent namespace.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted namespace and the web applications deleted with it are gone, and OcuPilot
/// keeps no copy to restore them from.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the Namespaces list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the vendor's
/// <code>ObjToJson</code> on this build.</p>
Parameter READANSWERS = "Globals,Routines,TempGlobals";

Parameter PRECONDITIONFIELD = "Globals";

Parameter FINGERPRINTSUBJECT = "Globals,Routines,TempGlobals";

/// <p>The rows the card lists: the databases the namespace names, which stay.</p>
Parameter REMOVALROWS = "Globals,Routines,TempGlobals";

/// <p>The pairs the write needs beyond the list's own: every namespace write's
/// <code>%DB_IRISSYS:WRITE</code>, and <code>%Admin_Secure:USE</code>, without which the vendor's
/// delete of the bound web applications fails after the namespace is gone (AD-8, measured on
/// <code>ocupilot-b-ci</code>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter APPLICATIONRESOURCE = "%Admin_Secure";

Parameter APPLICATIONPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Namespace.Namespace"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace to delete, as this instance's own namespaces list reports it. A namespace this instance does not hold is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and
/// <parameter>APPLICATIONRESOURCE</parameter>:<parameter>APPLICATIONPERMISSION</parameter>, each
/// pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION), $ListBuild(..#APPLICATIONRESOURCE, ..#APPLICATIONPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit tPairs
}

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the
/// instance holds and no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that namespace's globals database, and a namespace whose databases are unknown is not one to delete"
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

}
