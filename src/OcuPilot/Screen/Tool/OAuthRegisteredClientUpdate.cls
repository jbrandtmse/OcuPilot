/// <p>The OAuth 2.0 screen's server client edit tool (AD-4, AD-6, AD-55): propose a change to one
/// client registered with this instance's authorization server. It reads the client fresh through
/// <class>OcuPilot.Port.OAuthRegisteredClientPort</class>, merges the arguments over that object, and
/// mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field the
/// arguments omit keeps the instance's value (AD-4). <code>RedirectURL</code> is sent whole;
/// <code>Metadata</code> is the fresh read's whole object with the members the arguments name set over
/// it (<method>MergeUpdate</method>). The fresh read carries no secret member, and none is ever
/// sent, so the stored ones are kept.</p>
/// <p><b>It is keyed by <code>ClientId</code></b>, the vendor's IdKey; <code>Name</code> is not unique
/// and may be changed.</p>
Class OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverclients.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter DESCRIPTION = "Propose a change to one client registered with this instance's OAuth 2.0 authorization server. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the client by its client id exactly as the server client descriptions list reports it, and send only the fields to change. RedirectURL, when sent, replaces the whole list; Metadata changes only the members it names. The client secret is never an argument.";

Parameter READTYPE = "GET";

/// <p>The vendor's change request type, which answers 404 for an absent client.</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthRegisteredClientPort";

Parameter WRITERESOURCE = "%Admin_OAuth2_Registration";

Parameter WRITEPERMISSION = "USE";

Parameter RULES = "OcuPilot.Area.Security.OAuthRegisteredClientRules";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientCreate";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ServerClients"
}

/// <p>The client's IdKey, as the server client descriptions list reports it.</p>
ClassMethod IdArgument() As %String
{
    Quit "ClientId"
}

/// <p>The vendor's query parameter for the client.</p>
ClassMethod IdParam() As %String
{
    Quit "clientId"
}

/// <p>The fields the merge may set (<method>OcuPilot.Screen.Tool.OAuthRegisteredClientCreate.SettableFields</method>).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild($Parameter(..#CREATETOOL, "METADATAFIELD"))
}

/// <p>The derived schema, described, with the object argument added and the identifying property's
/// description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = $ClassMethod(..#CREATETOOL, "Described", ##super(pDescriptor), 0)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client to change, by its client id, exactly as this instance's own server client descriptions list reports it. A name is not accepted, because two clients may share one.", "string")
    Quit tSchema
}

/// <p>The editor's own rules over the agent's arguments, read against this tool's own fresh read
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Quit $ClassMethod(..#CREATETOOL, "RuleProblem", pArgs, "update", tFresh, .pProblem)
}

/// <p>The kernel's merge over the arguments with their <code>Metadata</code> set over the fresh
/// read's, so the diff, the payload and the digest are one computation for the mint, the confirm and
/// the Save. The card draws the redirect URLs as URLs and the metadata as one row per member it
/// changes.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tMetadata = $Parameter(..#CREATETOOL, "METADATAFIELD")
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    If tArgs.%GetTypeOf(tMetadata) = "object" Do tArgs.%Set(tMetadata, $ClassMethod(..#RULES, "MergedMetadata", pFresh, tArgs.%Get(tMetadata)))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = $ClassMethod(..#RULES, "CardRows", pFresh, pPayload, pDiff)
    Quit $$$OK
}

/// <p>Hold the body to the template fields (<method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Expand</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do $ClassMethod(..#RULES, "Expand", pPayload)
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
