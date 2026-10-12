/// <p>The OAuth 2.0 screen's server description edit tool (AD-4, AD-6, AD-55): propose a change to
/// one server description. It reads the description fresh through
/// <class>OcuPilot.Port.OAuthServerPort</class>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field
/// the arguments omit keeps the instance's value (AD-4). <code>Metadata</code> is one object
/// argument that changes only the members it names (<method>MergeUpdate</method>), a member sent as
/// <code>""</code> or <code>[]</code> being cleared; just before the port is called the body is made
/// the complete set (<method>DerivedFields</method>), so a member the merged metadata leaves out is
/// sent empty and cleared -- the vendor merges <code>Metadata</code> member by member and would
/// otherwise keep it. The fingerprint covers every field the fresh read answers.</p>
/// <p>The agent names the description by its issuer, which it cannot change; the editor's Save
/// renames through the same tool (<class>OcuPilot.Area.Security.OAuthServerSave</class>).</p>
Class OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverdescriptions.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter DESCRIPTION = "Propose a change to one OAuth 2.0 server description on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the description by its issuer endpoint exactly as the server descriptions list reports it, and send only the fields to change. Metadata, when sent, changes only the members it names; send an empty string or an empty list to clear one.";

Parameter READTYPE = "GET";

/// <p>The vendor's change request type, which answers 404 for an absent description.</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthServerPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>, already the tab's.</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ServerDefinition"
}

/// <p>The description's id: its issuer endpoint.</p>
ClassMethod IdArgument() As %String
{
    Quit "IssuerEndpoint"
}

/// <p>The port's query parameter for the issuer.</p>
ClassMethod IdParam() As %String
{
    Quit "issuer"
}

/// <p>The fields the merge may set: the <code>ordinary</code> template fields, derived (AD-3), and
/// <code>Metadata</code> (<method>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate.SettableFields</method>).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild($Parameter("OcuPilot.Screen.Tool.OAuthServerDescriptionCreate", "METADATAFIELD"))
}

/// <p>The derived schema, described, with <code>Metadata</code> added.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.OAuthServerDescriptionCreate).Described(tSchema, 0)
}

/// <p>The editor's own rules over the agent's arguments, read against this tool's own fresh read of
/// <var>pIdValue</var> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Quit ##class(OcuPilot.Screen.Tool.OAuthServerDescriptionCreate).RuleProblem(pIdValue, pArgs, "update", tFresh, .pProblem)
}

/// <p>The kernel's merge over the arguments with their <code>Metadata</code> applied member by member
/// over the fresh read's, so the diff, the payload and the digest are one computation for the mint,
/// the confirm and the Save. The card draws the metadata as one row per member it changes.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tRules = "OcuPilot.Area.Security.OAuthServerRules"
    Set tArgs = $ClassMethod(tRules, "MergedArguments", pFresh, pArgs)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = $ClassMethod(tRules, "CardRows", pFresh, pPayload, pDiff)
    Quit $$$OK
}

/// <p>Make the body the complete set (<method>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate.DerivedFields</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.Security.OAuthServerRules).Expand(pPayload)
}

/// <p>The tab's own pairs together with <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// appended only when the tab does not already declare it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
