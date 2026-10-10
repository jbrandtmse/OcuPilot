/// <p>What every write tool of Interoperability shares (AD-6, AD-51, AD-52, AD-53, AD-62, Stories 20.2, 20.3 and
/// 20.22): a write reached through <class>OcuPilot.Port.InteropPort</class> by two callers, a row action of its
/// screen and the agent's proposal and confirmation. It holds what the production tools
/// (<class>OcuPilot.Screen.Tool.InteropProductionAction</class>), the item tools
/// (<class>OcuPilot.Screen.Tool.InteropItemAction</class>) and the setting tools
/// (<class>OcuPilot.Screen.Tool.InteropSettingAction</class>) declare alike, and each of those keeps only what
/// differs.</p>
/// <p><b>The fresh read is composed from the action it is read for</b> (<method>PortQuery</method>). Given the
/// call's <b>arguments</b> -- the mint's and a screen action's, which carry no <parameter>STATEMARKER</parameter> --
/// the read is asked for this tool's action (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>), so a
/// state the action does not fit is refused by the port with its own code before anything is stored. Given the
/// <b>stored payload</b> -- the confirm's re-read and read-back, which carry the reviewed state -- the read names
/// only the namespace the payload holds, or the request's scope when it holds none: the fingerprint is what
/// refuses a state that moved, and a read-back after the write must read the state the write left.</p>
/// <p><b>The namespace travels in the payload</b> (AD-52): a confirm acts in the namespace the proposal read,
/// whatever the confirming request is scoped to.</p>
/// <p><b>It declares</b> the screen's own pairs, then <parameter>WRITERESOURCE</parameter> at
/// <parameter>WRITEPERMISSION</parameter>, then <parameter>DATABASEPERMISSION</parameter> on the namespace's globals
/// database (and, for <parameter>ROUTINESDATABASE</parameter>, its routines database), then the custom resource of
/// each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44), each refused by name before any port call.</p>
Class OcuPilot.Screen.Tool.InteropAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that reads and writes the target (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.InteropPort";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as at the
/// confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>An action-style write sends no body (AD-51); a tool that sends one declares <code>1</code>.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The pair beyond the screen's own that the write names.</p>
Parameter WRITERESOURCE = "%Ens_ProductionConfig";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The permission required on the resources guarding the namespace's globals and routines databases.</p>
Parameter DATABASEPERMISSION = "WRITE";

/// <p>Whether the pairs also name WRITE on the resource guarding the namespace's routines database, which a write
/// of the production class needs (<code>^oddDEF</code>). <code>0</code> here: a production action touches no
/// code.</p>
Parameter ROUTINESDATABASE As BOOLEAN = 0;

/// <p>The read field whose absence marks a call's arguments rather than a stored payload: a payload the confirm
/// holds carries it, because the reviewed fresh read did.</p>
Parameter STATEMARKER;

/// <p>The consequence code the proposal carries, or <code>""</code> for none. The client maps each to its published
/// sentence.</p>
Parameter CONSEQUENCECODE;

/// <p>The target's name, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#IDKEY
}

/// <p>None here: the write sends no body (AD-51). A tool that sends one names its fields.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>What the caller must hold: the screen's own pairs, then <parameter>WRITERESOURCE</parameter>, then
/// <parameter>DATABASEPERMISSION</parameter> on the globals database (and the routines database for
/// <parameter>ROUTINESDATABASE</parameter>) of the namespace the request is scoped to, then the custom resource of
/// each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44, AD-62). <var>pResolved</var> is 0
/// when a database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tGlobals = ""
    Set tRoutines = ""
    Set tResources = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(tNamespace, .tGlobals, .tReadOnly) || (tGlobals = "") {
        Set pResolved = 0
        Quit ""
    }
    Set tResources = $ListBuild(tGlobals)
    If ..#ROUTINESDATABASE {
        If '##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(tNamespace, .tRoutines, .tReadOnly) || (tRoutines = "") {
            Set pResolved = 0
            Quit ""
        }
        Set tResources = tResources _ $ListBuild(tRoutines)
    }
    For tI = 1:1:$ListLength(tResources) {
        Set tDatabase = $ListBuild($List(tResources, tI), ..#DATABASEPERMISSION)
        If '$ListFind(tPairs, tDatabase) Set tPairs = tPairs _ $ListBuild(tDatabase)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>Compose the port's read (AD-52): the action key when the call carries no
/// <parameter>STATEMARKER</parameter>, then the namespace the payload (<parameter>NAMESPACEFIELD</parameter>)
/// holds.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#STATEMARKER) = "unassigned" Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
