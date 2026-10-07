/// <p>What Interoperability's five production actions share (AD-6, AD-51, AD-52, AD-53, AD-62, Story
/// 20.2): an action-style write of one production of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Productions row action
/// through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. None
/// sends a body, and none removes data (Clean, which does, is never called).</p>
/// <p><b>The fresh read is the port's <code>STATE</code></b>, composed for the action at the mint and at
/// a screen action (<method>PortQuery</method>): a state the vendor would answer as a silent success is
/// refused by the port with the action's own <code>INTEROP.*</code> code, 409 (<method>PreconditionCodes</method>).
/// The confirm's re-read is not composed for the action, so a state that moved closes the proposal
/// through the fingerprint, and the write itself refuses again by the same codes.
/// <method>StateDiff</method> repeats the refusal for a read that reached it unrefused.</p>
/// <p><b>The namespace travels in the payload</b>: <code>Namespace</code> is part of every tool's
/// fingerprint subject, and <method>PortQuery</method> sends it back, so a confirm acts in the
/// namespace the proposal read even when the confirming request is scoped elsewhere (AD-52).</p>
/// <p><b>It declares <code>%Ens_ProductionRun:USE</code> and WRITE on the namespace's globals
/// database</b> beyond the screen's pairs (AD-8, AD-62), each refused by name before any port call, then
/// the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropProductionAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropProductionList";

/// <p>The port that reads and controls a production (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.InteropPort";

/// <p>The fresh read: one production's state in its namespace.</p>
Parameter READTYPE = "STATE";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the
/// mint as at the confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Namespace,State,Current,NeedsUpdate";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The label the card's one state row carries.</p>
Parameter STATEFIELD = "State";

Parameter PRECONDITIONFIELD = "State";

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The pair the write itself names, which the vendor checks before it starts, stops, restarts or
/// updates a production.</p>
Parameter WRITERESOURCE = "%Ens_ProductionRun";

Parameter WRITEPERMISSION = "USE";

/// <p>The permission required on the resource guarding the namespace's globals database.</p>
Parameter DATABASEPERMISSION = "WRITE";

/// <p>The classic pages whose operations these tools perform (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.ProductionConfig,EnsPortal.Dialog.UpdateProduction,EnsPortal.StartStopFrame";

/// <p>The state word the action leaves the production in, which the card's row shows as its
/// <code>after</code>.</p>
Parameter AFTERWORD;

/// <p>The consequence code the proposal carries, or <code>""</code> for none. The client maps each to
/// its published sentence.</p>
Parameter CONSEQUENCECODE;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTPRODUCTIONS
}

/// <p>The production's class name, which the list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#IDKEY
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The refusals the port's <code>STATE</code> read answers with when the action does not fit the
/// production's state, and a namespace that runs no productions (AD-51).</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Port.InteropPort).PreconditionCodes()
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// production, named exactly as the Productions list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The production, named exactly as this namespace's Productions list reports it (its class name, case included). A production the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, then <parameter>WRITERESOURCE</parameter> and
/// WRITE on the globals database of the namespace the request is scoped to, then the custom resource
/// of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44, AD-62).
/// <var>pResolved</var> is 0 when the namespace's globals database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Set tResource = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(##class(OcuPilot.Kernel.Scope).Current(), .tResource, .tReadOnly) || (tResource = "") {
        Set pResolved = 0
        Quit ""
    }
    Set tDatabase = $ListBuild(tResource, ..#DATABASEPERMISSION)
    If '$ListFind(tPairs, tDatabase) Set tPairs = tPairs _ $ListBuild(tDatabase)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>Compose the port's <code>STATE</code> read (AD-52). Given the call's <b>arguments</b> -- the mint's
/// and a screen action's, which carry no <code>State</code> -- the read is asked for this tool's action
/// (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>), so a state the action does not fit is
/// refused with its own code before anything is stored. Given the <b>stored payload</b> -- the confirm's
/// re-read and read-back, which carry the reviewed <code>State</code> -- the read names only the
/// namespace the payload (<parameter>NAMESPACEFIELD</parameter>) holds, or the request's scope when it
/// holds none: the fingerprint is what refuses a state that moved, and a read-back after the write must
/// read the state the write left.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf("State") '= "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <code>State</code>
/// moving from the production's word to <parameter>AFTERWORD</parameter>. A state the action does not
/// fit is <var>pProblem</var>, the sentence of the code <method>OcuPilot.Port.InteropPort.Refusal</method>
/// names; a read that answered no state refuses too, since a state nobody established is not one to
/// act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("State") '= "string") {
            Set pProblem = "this instance did not report the production's state"
            Quit
        }
        Set tState = pFresh.%Get("State")
        Set tNeeds = (pFresh.%GetTypeOf("NeedsUpdate") = "boolean") && pFresh.%Get("NeedsUpdate")
        Set tCode = ##class(OcuPilot.Port.InteropPort).Refusal(..#WRITETYPE, tState, pFresh.%Get("Current"), pFresh.%Get("Name"), tNeeds)
        If tCode '= "" {
            Set pProblem = ##class(OcuPilot.Port.InteropPort).ReasonFor(tCode)
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tState, "string")
        Do tRow.%Set("after", ..#AFTERWORD, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
