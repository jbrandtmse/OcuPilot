/// <p>What Interoperability's four item writes share (AD-6, AD-51, AD-52, AD-53, AD-54, AD-62, Story 20.3): a
/// write of one item of one production of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Production items row action or
/// Add, and the agent's proposal and confirmation. Every item write changes the stored production
/// configuration and the production class and nothing else: it never updates, starts or stops a production,
/// so a running production reads update pending until Productions' confirmed Update applies the change.</p>
/// <p><b>The target is the composite <code>[Production, Name]</code></b>
/// (<class>OcuPilot.Screen.Tool.InteropItemMint</class>), never the vendor's integer item id, which a
/// recompile renumbers. The fresh read is the port's <code>ITEM</code>, composed for the action at the mint
/// and at a screen action (<method>PortQuery</method>): a state the vendor would store twice, answer as a
/// silent success or change in the wrong place is refused by the port with the action's own
/// <code>INTEROP.ITEM.*</code> code, 409 (<parameter>PRECONDITIONCODES</parameter>). The confirm's re-read is
/// not composed for the action, so an item that moved closes the proposal through the fingerprint, and the
/// write itself refuses again by the same codes.</p>
/// <p><b>The namespace travels in the payload</b> (AD-52): a confirm writes in the namespace the proposal
/// read, whatever the confirming request is scoped to.</p>
/// <p><b>It declares</b> <code>%Ens_ProductionConfig:WRITE</code> and WRITE on the namespace's globals and
/// routines databases beyond the screen's pairs (AD-8, AD-62), each refused by name before any port call,
/// then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44). It does not declare
/// <code>%Ens_ProductionRun:USE</code>: no item write touches a running job.</p>
Class OcuPilot.Screen.Tool.InteropItemAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropItemList";

/// <p>The port that reads and writes a production item (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.InteropPort";

/// <p>The fresh read: one item, composed for the action.</p>
Parameter READTYPE = "ITEM";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as
/// at the confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Name,ClassName,Type,Enabled,EnabledSource,PoolSize,Category,Comment,Namespace,Count";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The argument naming the production the item belongs to.</p>
Parameter PRODUCTIONARGUMENT = "Production";

/// <p>The pair beyond the screen's own that every item write names.</p>
Parameter WRITERESOURCE = "%Ens_ProductionConfig";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The permission required on the resources guarding the namespace's globals and routines
/// databases.</p>
Parameter DATABASEPERMISSION = "WRITE";

/// <p>The consequence code the proposal carries. The client maps it to its published sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.ITEM.PENDING";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTITEMS
}

/// <p>The item's name, which the list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#IDKEY
}

/// <p><class>OcuPilot.Screen.Tool.InteropItemMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropItemMint"
}

/// <p>None here: an enable, a disable and a remove send no body (AD-51). The add names its own.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The item's name, which the card titles the target by: the fresh read's, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>The derived schema with the production added and required, and the item's name described: the target
/// is one item, named as the Production items list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#PRODUCTIONARGUMENT, {"type": "string", "description": "The production the item belongs to, named exactly as this namespace's Productions list reports it (its class name, case included). A production the list does not report is refused."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#PRODUCTIONARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>What the schema says of the item's name. The item write the tool makes states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The item, named exactly as this production's Production items list reports it. An item the list does not report is refused."
}

/// <p>What the caller must hold: the screen's own pairs, then <parameter>WRITERESOURCE</parameter>, then WRITE
/// on the globals and routines databases of the namespace the request is scoped to, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44, AD-62).
/// <var>pResolved</var> is 0 when either database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tGlobals = ""
    Set tRoutines = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(tNamespace, .tGlobals, .tReadOnly) || (tGlobals = "") || '##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(tNamespace, .tRoutines, .tReadOnly) || (tRoutines = "") {
        Set pResolved = 0
        Quit ""
    }
    For tResource = tGlobals, tRoutines {
        Set tDatabase = $ListBuild(tResource, ..#DATABASEPERMISSION)
        If '$ListFind(tPairs, tDatabase) Set tPairs = tPairs _ $ListBuild(tDatabase)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>Compose the port's <code>ITEM</code> read (AD-52). Given the call's <b>arguments</b> -- the mint's and a
/// screen action's, which carry no <code>Enabled</code> -- the read is asked for this tool's action
/// (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>), so a state the action does not fit is
/// refused with its own code before anything is stored. Given the <b>stored payload</b> -- the confirm's
/// re-read and read-back, which carry the reviewed <code>Enabled</code> -- the read names only the namespace
/// the payload (<parameter>NAMESPACEFIELD</parameter>) holds, or the request's scope when it holds none: the
/// fingerprint is what refuses a state that moved, and a read-back after the write must read the state the
/// write left.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf("Enabled") '= "boolean" Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>The one row an enable or a disable shows, from the fresh read <var>pFresh</var>: <code>Enabled</code>
/// moving from the item's value to its opposite. A read that answered no <code>Enabled</code> is
/// <var>pProblem</var>, since an item nobody established is not one to act on. A remove overrides it.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Enabled") '= "boolean") {
            Set pProblem = "this instance did not report the item's state"
            Quit
        }
        Set tBefore = pFresh.%Get("Enabled")
        Set tRow = {}
        Do tRow.%Set("field", "Enabled", "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(tBefore, "boolean"), "string")
        Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display('tBefore, "boolean"), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
