/// <p>The Namespaces list's edit tool (AD-4, AD-6, AD-10, AD-55): propose a change to one namespace's
/// databases. It reads the namespace fresh through the vendor's own <code>Namespace.Namespace</code>
/// <code>GET</code>, merges the arguments over that object, and mints a proposal the user confirms.
/// It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete
/// <code>{Globals, Routines, TempGlobals}</code> with the changed ones applied (AD-4), and the
/// fingerprint covers every field it sends. The vendor's <code>PUT</code> is an upsert, so the
/// confirm's fingerprint re-read is what refuses a namespace deleted since the mint. The name is the
/// id and never changes.</p>
/// <p>The rules check only the fields the arguments change, against the fresh read.</p>
Class OcuPilot.Screen.Tool.NamespaceUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.namespaces.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter DESCRIPTION = "Propose a change to the databases one namespace reads its globals, routines or temporary globals from. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace as the namespaces list reports it and send only the fields to change. Its name cannot be changed.";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same three).</p>
Parameter PERMITTEDFIELDS = "Globals,Routines,TempGlobals";

/// <p>The pair every namespace write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.NamespaceCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose operation this tool performs beyond the list's own (AD-44, DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.NamespaceEdit";

ClassMethod Endpoint() As %String
{
    Quit "Namespace.Namespace"
}

/// <p>The <code>ordinary</code> top-level fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the name and the three fields described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.NamespaceCreate).Described(tSchema, 0)
}

/// <p>The namespace editor's own rules over the fields the agent's arguments change, read against
/// this tool's own fresh read of <var>pIdValue</var> (AD-55). A namespace the read no longer finds has
/// every supplied field checked; the mint has already refused one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Quit ##class(OcuPilot.Screen.Tool.NamespaceCreate).RuleProblem(pIdValue, ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Changed(pArgs, tFresh), "update", tFresh, .pProblem)
}

/// <p>Each database field in the databases list's spelling
/// (<method>OcuPilot.Screen.Tool.NamespaceCreate.DerivedFields</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Spell(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
