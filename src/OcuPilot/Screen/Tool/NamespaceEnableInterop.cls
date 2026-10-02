/// <p>The Namespaces list's enable-interoperability tool (AD-26, AD-51, AD-53, Story 18.15): enable
/// interoperability on one namespace. The agent reaches it through a proposal the user confirms; the
/// Namespaces list reaches it through its <code>enable-interop</code> row action, behind the
/// typed-name dialog.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.NamespacePort</class> sends the vendor's <code>Namespace.Namespace</code>
/// <code>INTEROP</code> with the namespace alone. The vendor queues it and the port awaits it within its
/// bound, reading the finished result once (AD-26); past the bound the port answers that it has
/// started, and the worker finishes it.</p>
/// <p><b>It is destructive</b>: on InterSystems IRIS for Health the vendor's enable also runs the
/// HealthShare Foundation install, which changes the whole instance, and nothing undoes it. The card
/// and the dialog state its consequence (<method>Consequence</method>).</p>
/// <p><b>The fingerprint subject is the namespace's globals and routines databases</b>: configuration
/// does not move by itself, so any change since the mint refuses the confirm.</p>
/// <p><b>Its pairs are the Namespaces list's, <code>%All:USE</code> and
/// <code>%Admin_Operate:USE</code></b> (AD-8 as amended 2026-10-01): every narrower principal measured
/// either failed <code>&lt;PROTECT&gt;</code> half-way or skipped the HealthShare half, and the port
/// polls the queued enable through the <code>AsyncResult</code> endpoint, whose own gate names
/// <code>%Admin_Operate</code>. No resource is named <code>%All</code>, so only a user assigned the
/// <code>%All</code> role directly passes that pair; a user whose own role only grants <code>%All</code>
/// is refused it. The New Namespace page, which holds the classic enable, is
/// its replaced classic page (AD-44).</p>
/// <p><code>%SYS</code> and <code>%ALL</code> are refused by <method>SystemProblem</method> on both
/// callers, after the fresh read and before anything is queued.</p>
Class OcuPilot.Screen.Tool.NamespaceEnableInterop Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.namespaces.enableinterop";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter DESCRIPTION = "Propose enabling interoperability on one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace as the namespaces list reports it; %SYS and %ALL are refused. On InterSystems IRIS for Health the instance also runs the HealthShare Foundation install, which grants the Admin user an administrative role, creates roles, resources and a task, and starts a Java language server. It cannot be undone, and only a user assigned the %All role itself may propose or confirm it.";

/// <p>The port that sends the enable (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.NamespacePort";

/// <p>The fresh read: the namespace, answered by the port with <code>SourceNamespace</code> added
/// empty.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "INTEROP";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Declared: the enable changes the whole instance and nothing undoes it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The Namespaces list's <code>enable-interop</code> row action (AD-53), which takes no value.</p>
Parameter SCREENACTIONS = "enable-interop";

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475).</p>
Parameter READANSWERS = "Globals,Routines,TempGlobals,SourceNamespace";

Parameter PRECONDITIONFIELD = "Globals";

Parameter FINGERPRINTSUBJECT = "Globals,Routines";

/// <p>The pair the poll of the queued enable needs beyond the list's own (AD-8).</p>
Parameter POLLRESOURCE = "%Admin_Operate";

Parameter POLLPERMISSION = "USE";

/// <p>The classic page whose operation this tool performs beyond the list's own: the New Namespace
/// page's interoperability step (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Namespace";

/// <p>The consequence code the proposal carries, the dialog's own sentence on the card.</p>
Parameter CONSEQUENCE = "NAMESPACE.INTEROP";

/// <p>The refusal of <code>%SYS</code> and <code>%ALL</code>, published at EXPERIENCE.md's Namespaces
/// fixed strings.</p>
Parameter SYSTEMREASON = "Interoperability cannot be enabled in %SYS or %ALL.";

ClassMethod Endpoint() As %String
{
    Quit "Namespace.Namespace"
}

/// <p>None: the write sends no body and takes no argument (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace to enable, as this instance's namespaces list reports it; %SYS and %ALL are refused.", "string")
    Quit tSchema
}

/// <p>No state row: the card states the consequence instead.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>SYSTEMREASON</parameter> when <var>pName</var> is <code>%SYS</code> or
/// <code>%ALL</code>, ignoring case, and <code>""</code> otherwise.</p>
ClassMethod SystemProblem(pName As %String) As %String
{
    If $ListFind($ListBuild("%SYS", "%ALL"), $ZConvert(pName, "U")) Quit ..#SYSTEMREASON
    Quit ""
}

/// <p>The agent's target refused by <method>SystemProblem</method> before anything is stored
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SystemProblem(pIdValue)
    Quit $$$OK
}

/// <p>The screen's target refused by <method>SystemProblem</method> exactly as the agent's is
/// (AD-56 (ii)); the action takes no value, so its arguments are empty. The target travels beside the
/// values as the tool's id argument.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set tName = ""
    If $IsObject(pValues) Set tName = pValues.%Get(..IdArgument())
    Set pProblem = ..SystemProblem(tName)
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>What the caller must hold, each pair once: the list's own pairs, then <code>%All:USE</code>, then
/// <parameter>POLLRESOURCE</parameter>:<parameter>POLLPERMISSION</parameter>, then the custom resource
/// of the <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44). A caller without <code>%All</code> is
/// refused naming that pair.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(##class(OcuPilot.Kernel.Shell.Effective).#ALLROLE, "USE"), $ListBuild(..#POLLRESOURCE, ..#POLLPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
