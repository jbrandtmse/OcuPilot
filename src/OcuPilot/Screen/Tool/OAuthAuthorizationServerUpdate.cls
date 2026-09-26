/// <p>The OAuth 2.0 screen's authorization server edit tool (AD-4, AD-6, AD-55): propose a change to
/// this instance's one authorization server configuration. It reads the configuration fresh through
/// <class>OcuPilot.Port.OAuthAuthorizationServerPort</class>, merges the arguments over that object,
/// and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field the
/// arguments omit keeps the instance's value (AD-4). <code>SupportedScopes</code> and
/// <code>CustomizationRoles</code> are sent whole; <code>Metadata</code> is the fresh read's whole
/// object with the members the arguments name set over it (<method>MergeUpdate</method>).</p>
/// <p><b>Every registered client is in the reviewed state.</b> The fresh read carries
/// <code>Clients</code> and <code>ClientsHidden</code>, so the fingerprint refuses a confirm after a
/// client was registered or removed, and the card names the clients the change reaches; the port
/// removes both before the write.</p>
Class OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserver.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter DESCRIPTION = "Propose a change to this instance's OAuth 2.0 authorization server configuration. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send only the fields to change. SupportedScopes and CustomizationRoles, when sent, replace the whole list; Metadata changes only the members it names. Every client registered with the server is affected, and the card names them. The key password is never an argument.";

Parameter READTYPE = "GET";

/// <p>The vendor's change request type.</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthAuthorizationServerPort";

Parameter WRITERESOURCE = "%Admin_OAuth2_Server";

Parameter WRITEPERMISSION = "USE";

Parameter RULES = "OcuPilot.Area.Security.OAuthAuthorizationServerRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Server"
}

/// <p>The fields the merge may set (<method>OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate.SettableFields</method>).</p>
ClassMethod SettableFields() As %List
{
    Set tCreate = "OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate"
    Quit ..AdmittedFields() _ $ListBuild($Parameter(tCreate, "SCOPESFIELD"), $Parameter(tCreate, "METADATAFIELD"))
}

/// <p>The derived schema, described, with the two object arguments added.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate).Described(tSchema, 0)
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
    Quit ##class(OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate).RuleProblem(pArgs, "update", tFresh, .pProblem)
}

/// <p>The kernel's merge over the arguments with their <code>Metadata</code> set over the fresh
/// read's, so the diff, the payload and the digest are one computation for the mint, the confirm and
/// the Save. The card draws the lists as names and the metadata as one row per member it changes,
/// and names the registered clients when anything changes.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tMetadata = $Parameter("OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate", "METADATAFIELD")
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    If tArgs.%GetTypeOf(tMetadata) = "object" {
        Do tArgs.%Set(tMetadata, $ClassMethod(..#RULES, "MergedMetadata", pFresh, tArgs.%Get(tMetadata)))
        Do $ClassMethod(..#RULES, "WithRefreshGrant", tArgs.%Get(tMetadata))
    }
    Set tScopes = $Parameter("OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate", "SCOPESFIELD")
    If tArgs.%GetTypeOf(tScopes) = "array" Do tArgs.%Set(tScopes, $ClassMethod(..#RULES, "OrderedScopes", tArgs.%Get(tScopes)))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = $ClassMethod(..#RULES, "CardRows", pFresh, pPayload, pDiff)
    If pDiff.%Size() = 0 Quit $$$OK
    Set tClients = $ClassMethod(..#RULES, "ClientsRow", pFresh, 0)
    If $IsObject(tClients) Do pDiff.%Push(tClients)
    Quit $$$OK
}

/// <p>Hold the body to the template fields (<method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Expand</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do $ClassMethod(..#RULES, "Expand", pPayload)
}

/// <p>The kernel-owned consequence of this payload
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ServerConsequence</method>).</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).ServerConsequence("", pPrivileged, pEffect)
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
