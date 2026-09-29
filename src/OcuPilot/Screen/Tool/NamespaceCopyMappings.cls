/// <p>The Namespaces list's copy-mappings tool (AD-51, AD-52, AD-53, Story 18.14): copy every global,
/// routine and package mapping of one namespace into another. The agent reaches it through a
/// proposal the user confirms; the Namespaces list reaches it through its <code>copy-mappings</code>
/// row action on the destination's row, with the source as the action's one value (AD-56 (ii)).</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.NamespacePort</class> composes the vendor's <code>Namespace.Namespace</code>
/// <code>MAPPINGS</code> body from the destination, the target, and <code>SourceNamespace</code>,
/// which travels in the port query (<method>PortQuery</method>). The vendor queues the copy and the
/// port awaits it within its bound, reading the finished result once (AD-26); past the bound the port
/// answers that the copy has started, and the worker finishes it.</p>
/// <p><b>It is destructive</b>: a mapping the destination already holds under a source mapping's
/// name is replaced, and nothing keeps the one replaced. The card states the copy's consequence
/// (<method>Consequence</method>).</p>
/// <p><b>The fingerprint subject is the destination's three databases and the argument</b>: the
/// destination's configuration does not move by itself, so any change since the mint refuses the
/// confirm, and what the user reviewed is this source. A source the instance does not hold, and the
/// destination itself, are refused before any task is queued.</p>
/// <p><b>Its pairs are the Namespaces list's, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:WRITE</code></b> (AD-8 as amended 2026-09-28): the port polls the queued copy
/// through the <code>AsyncResult</code> endpoint, whose own gate names <code>%Admin_Operate</code>, and
/// the copy writes the system database, measured refused without it. The New Namespace page, which
/// holds the classic copy, is its replaced classic page (AD-44, DW-1784).</p>
/// <p>Copying OcuPilot's own mappings into the install namespace or <code>%ALL</code> is refused by
/// the kernel (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTMAPPING</parameter>) on both
/// callers.</p>
Class OcuPilot.Screen.Tool.NamespaceCopyMappings Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.namespaces.copymappings";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter DESCRIPTION = "Propose copying every global, routine and package mapping of one namespace into another. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the destination namespace and the source namespace as the namespaces list reports them. A mapping the destination already holds under the same name is replaced; its other mappings stay.";

/// <p>The port that composes the vendor body (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.NamespacePort";

/// <p>The fresh read: the destination namespace, answered by the port with the argument field
/// empty.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "MAPPINGS";

/// <p>No body: the port composes it.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Declared: a same-named mapping of the destination is replaced, and nothing keeps it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The Namespaces list's <code>copy-mappings</code> row action (AD-53), whose one value is
/// <parameter>SOURCEFIELD</parameter>.</p>
Parameter SCREENACTIONS = "copy-mappings";

Parameter SCREENVALUES = "copy-mappings=SourceNamespace";

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475).</p>
Parameter READANSWERS = "Globals,Routines,TempGlobals,SourceNamespace";

Parameter PRECONDITIONFIELD = "Globals";

/// <p>The destination's three databases and the source the user reviewed. The source is in the
/// subject because the stored payload is narrowed to it (AD-51), and <method>PortQuery</method> reads
/// the source from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Globals,Routines,TempGlobals,SourceNamespace";

/// <p>The one argument this tool admits: the namespace whose mappings are copied.</p>
Parameter SOURCEFIELD = "SourceNamespace";

/// <p>The pairs the write needs beyond the list's own: the poll's <code>%Admin_Operate:USE</code>,
/// and the system database's <code>WRITE</code> (AD-8).</p>
Parameter POLLRESOURCE = "%Admin_Operate";

Parameter POLLPERMISSION = "USE";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose operation this tool performs beyond the list's own: the New Namespace
/// page's "Copy namespace mappings from" (AD-44, DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Namespace";

/// <p>The consequence code the proposal carries, the copy dialog's own sentence on the card.</p>
Parameter CONSEQUENCE = "NAMESPACE.COPYMAPPINGS";

ClassMethod Endpoint() As %String
{
    Quit "Namespace.Namespace"
}

/// <p><parameter>SOURCEFIELD</parameter> alone: the tool sends no body, so its field list is empty by
/// derivation, and the one argument it takes reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#SOURCEFIELD)
}

/// <p>The identifying property described as the destination, and <parameter>SOURCEFIELD</parameter>,
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace the mappings are copied into, as this instance's own namespaces list reports it. A namespace this instance does not hold is refused.", "string")
    }
    Do tProperties.%Set(..#SOURCEFIELD, {"type": "string", "description": "The namespace whose mappings are copied, exactly as this instance's namespaces list reports it. The destination itself and a namespace this instance does not have are refused."})
    Do tSchema.%Get("required").%Push(..#SOURCEFIELD)
    Quit tSchema
}

/// <p>No state row: the merge's <parameter>SOURCEFIELD</parameter> row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The stored payload's <parameter>SOURCEFIELD</parameter>, under the port's own query key, so the
/// confirm's write and the screen's write carry the source the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#SOURCEFIELD) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.NamespacePort).#SOURCEQUERY) = pPayload.%Get(..#SOURCEFIELD)
}

/// <p>What is wrong with <var>pSource</var> as the namespace whose mappings are copied into
/// <var>pDestination</var>, or <code>""</code>: it must be a namespace this instance has, and not the
/// destination itself, compared without regard to case. The vendor queues an absent source and then
/// fails it (measured), so it is refused before any task is queued.</p>
ClassMethod SourceProblem(pDestination As %String, pSource As %String) As %String
{
    If pSource = "" Quit "'" _ ..#SOURCEFIELD _ "' names the namespace whose mappings are copied and cannot be empty"
    If $ZConvert(pSource, "U") = $ZConvert(pDestination, "U") Quit "'" _ ..#SOURCEFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#NAMESPACESOURCESAME)
    If '..SourceHeld(pSource) Quit "'" _ ..#SOURCEFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#NAMESPACESOURCEABSENT)
    Quit ""
}

/// <p>Whether the instance holds the namespace <var>pSource</var>, read through this tool's own port
/// and read type as the caller. A read that fails for any reason but absence reads as held, so the
/// vendor's own answer, not a guess here, decides it.</p>
ClassMethod SourceHeld(pSource As %String) As %Boolean
{
    Set tHeld = 1
    Try {
        Kill tQuery
        Set tQuery(..IdParam()) = pSource
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) && (+$Get(tHttp) = 404) Set tHeld = 0
    } Catch {
        Set tHeld = 1
    }
    Quit tHeld
}

/// <p>The agent's arguments refused by <method>SourceProblem</method> before anything is stored
/// (AD-55). <var>pIdValue</var> is the destination.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..SourceProblem(pIdValue, pArgs.%Get(..#SOURCEFIELD))
    Quit $$$OK
}

/// <p>The screen's <code>copy-mappings</code> value as this tool's argument, refused by
/// <method>SourceProblem</method> exactly as the agent's is (AD-56 (ii)). The destination travels
/// beside the values as the tool's id argument.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tSource = ""
    Set tDestination = ""
    If $IsObject(pValues) {
        Set tSource = pValues.%Get(..#SOURCEFIELD)
        Set tDestination = pValues.%Get(..IdArgument())
    }
    Set pProblem = ..SourceProblem(tDestination, tSource)
    If pProblem = "" Do pArgs.%Set(..#SOURCEFIELD, tSource, "string")
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: the copy always replaces the
/// destination's same-named mappings.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>What the caller must hold: the list's own pairs, then
/// <parameter>POLLRESOURCE</parameter>:<parameter>POLLPERMISSION</parameter> and
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#POLLRESOURCE, ..#POLLPERMISSION), $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
