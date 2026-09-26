/// <p>The OAuth 2.0 screen's resource server edit tool (AD-4, AD-6, AD-55): propose a change to one
/// resource server. It reads the server fresh through
/// <class>OcuPilot.Port.OAuthResourceServerPort</class>, merges the arguments over that object, and
/// mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field the
/// arguments omit keeps the instance's value (AD-4). <code>Audiences</code> is sent whole. The vendor
/// replaces <code>Authenticator</code> whole, so an argument naming the stored namespace and class has
/// every setting it leaves out filled from the fresh read before the merge (<method>MergeUpdate</method>);
/// one naming another class sends only its own settings, and the rest take that class's defaults.
/// The fingerprint covers every field the fresh read answers, which carries no credential.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthresourceservers.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter DESCRIPTION = "Propose a change to one OAuth 2.0 resource server on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server exactly as the resource servers list reports it, and send only the fields to change. Audiences, when sent, replaces the whole list. The client secret is never an argument, and service mappings are changed separately.";

Parameter READTYPE = "GET";

/// <p>The vendor's change request type.</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthResourceServerPort";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ResourceServer"
}

/// <p>The fields the merge may set (<method>OcuPilot.Screen.Tool.OAuthResourceServerCreate.SettableFields</method>).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild($Parameter("OcuPilot.Screen.Tool.OAuthResourceServerCreate", "AUTHENTICATORFIELD"))
}

/// <p>The derived schema, described, with <code>Authenticator</code> added.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.OAuthResourceServerCreate).Described(tSchema, 0)
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
    Quit ##class(OcuPilot.Screen.Tool.OAuthResourceServerCreate).RuleProblem(pIdValue, pArgs, "update", tFresh, .pProblem)
}

/// <p>The kernel's merge over the arguments with their <code>Authenticator</code> completed from
/// <var>pFresh</var> (<method>OcuPilot.Area.Security.OAuthResourceServerRules.Expand</method>), so the
/// diff, the payload and the digest are one computation for the mint, the confirm and the Save.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    Do ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Expand(tArgs, pFresh)
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>Hold the body to the template fields (<method>OcuPilot.Area.Security.OAuthResourceServerRules.Expand</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Expand(pPayload)
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
