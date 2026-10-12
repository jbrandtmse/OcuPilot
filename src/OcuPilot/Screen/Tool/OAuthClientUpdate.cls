/// <p>The OAuth 2.0 screen's client configuration edit tool (AD-4, AD-6, AD-55): propose a change to
/// one client configuration. It reads the configuration fresh through
/// <class>OcuPilot.Port.OAuthClientPort</class>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field the
/// arguments omit keeps the instance's value (AD-4). <code>Metadata</code> is one object argument that
/// changes only the settable members it names (<method>MergeUpdate</method>), a member sent as
/// <code>""</code> or <code>[]</code> being cleared; just before the port is called the body is made
/// the complete set (<method>DerivedFields</method>), so a member the merged metadata leaves out is
/// sent empty and cleared. The registration's own members are never an argument, and the port sends
/// them as the instance holds them. The fingerprint covers every field the fresh read answers, which carries no
/// secret.</p>
Class OcuPilot.Screen.Tool.OAuthClientUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose a change to one OAuth 2.0 client configuration on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration by its application name exactly as the client configurations list reports it, and send only the fields to change. Metadata, when sent, changes only the members it names; send an empty string or an empty list to clear one. Secrets are never arguments.";

Parameter READTYPE = "GET";

/// <p>The vendor's change request type.</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthClientPort";

Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ClientConfiguration"
}

ClassMethod IdArgument() As %String
{
    Quit "ApplicationName"
}

ClassMethod IdParam() As %String
{
    Quit "applicationName"
}

/// <p>The fields the merge may set (<method>OcuPilot.Screen.Tool.OAuthClientCreate.SettableFields</method>).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild($Parameter("OcuPilot.Screen.Tool.OAuthClientCreate", "METADATAFIELD"))
}

/// <p>The derived schema, described, with <code>Metadata</code> added.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.OAuthClientCreate).Described(tSchema, 0)
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
    Quit ##class(OcuPilot.Screen.Tool.OAuthClientCreate).RuleProblem(pIdValue, pArgs, "update", tFresh, .pProblem)
}

/// <p>The kernel's merge over the arguments with their <code>Metadata</code> applied member by member
/// over the fresh read's settable members, so the diff, the payload and the digest are one computation
/// for the mint, the confirm and the Save. The card draws the metadata as one row per member it
/// changes.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tRules = "OcuPilot.Area.Security.OAuthClientRules"
    Set tMetadata = $Parameter(tRules, "FIELDMETADATA")
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    If tArgs.%GetTypeOf(tMetadata) = "object" Do tArgs.%Set(tMetadata, $ClassMethod(tRules, "MergedMetadata", pFresh, tArgs.%Get(tMetadata)))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = $ClassMethod(tRules, "CardRows", pFresh, pPayload, pDiff)
    Quit $$$OK
}

/// <p>Make the body the complete set (<method>OcuPilot.Area.Security.OAuthClientRules.Expand</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.Security.OAuthClientRules).Expand(pPayload)
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
