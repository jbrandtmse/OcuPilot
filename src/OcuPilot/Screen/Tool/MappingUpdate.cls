/// <p>The base of the three namespace mapping edit tools (AD-4, AD-6, AD-10, AD-55, Story 18.14):
/// propose a change to one mapping's template fields. It reads the mapping fresh through the vendor's
/// own <code>GET</code>, merges the arguments over that object, and mints a proposal the user
/// confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete template set with the changed fields
/// applied (AD-4), and the fingerprint covers every field it sends. The vendor's <code>PUT</code> is
/// an upsert, so the confirm's fingerprint re-read is what refuses a mapping deleted since the mint.
/// The namespace and name are the id and never change.</p>
/// <p>A concrete subclass declares <parameter>TOOLNAME</parameter>,
/// <parameter>DESCRIPTORCLASS</parameter>, <parameter>DESCRIPTION</parameter>,
/// <parameter>ENDPOINT</parameter>, <parameter>MAPPINGKIND</parameter>,
/// <parameter>PERMITTEDFIELDS</parameter> and <parameter>CLASSICPAGES</parameter>.</p>
Class OcuPilot.Screen.Tool.MappingUpdate Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The port that splits the composite id (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.NamespacePort";

/// <p>The kind's admin endpoint, declared by the subclass.</p>
Parameter ENDPOINT;

/// <p>The kind, declared by the subclass.</p>
Parameter MAPPINGKIND;

/// <p>The derived top-level fields this tool admits, declared by the subclass
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same).</p>
Parameter PERMITTEDFIELDS;

/// <p>The pair every mapping write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.MappingCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINT
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

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MappingMint"
}

/// <p>The derived schema with the namespace, the name and the template fields described
/// (<method>OcuPilot.Screen.Tool.MappingCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit $ClassMethod(..CreateTool(), "Described", tSchema, 0)
}

/// <p>The kind's create tool, whose schema description and rule helper this tool shares.</p>
ClassMethod CreateTool() As %String
{
    Quit $Replace($ClassName(), "MappingUpdate", "MappingCreate")
}

/// <p>The editor's own rules over the fields the agent's arguments change, read against this tool's
/// own fresh read of <var>pIdValue</var> (AD-55). A mapping the read no longer finds has every
/// supplied field checked; the mint has already refused one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Quit $ClassMethod(..CreateTool(), "RuleProblem", pIdValue, ##class(OcuPilot.Area.OsMgmt.MappingRules).Changed(..#MAPPINGKIND, pArgs, tFresh), "update", .pProblem)
}

/// <p>Each database field in the databases list's spelling
/// (<method>OcuPilot.Area.OsMgmt.MappingRules.Spell</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.MappingRules).Spell(pPayload)
}

/// <p>What the caller must hold: the list's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> dialog, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
