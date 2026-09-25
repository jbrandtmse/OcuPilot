/// <p>The OAuth 2.0 screen's server client create tool (AD-54, AD-55): propose registering one client
/// with this instance's authorization server. It reads the registered clients fresh through
/// <class>OcuPilot.Port.OAuthRegisteredClientPort</class>, requires that no client holds the name,
/// composes the complete body and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>Its target is the client's name</b> (AD-13, AD-54). The vendor generates the client id on the
/// write and accepts a duplicate name, so the absence read is the list filtered to the one row whose
/// <code>Name</code> equals the argument, compared without regard to case: a name any client holds
/// refuses the mint, and one taken since the mint refuses the confirm.</p>
/// <p><b>The body is complete</b>: a field the arguments leave out takes the classic page's value for
/// a new client (<method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Defaults</method>) and is
/// counted unchanged. <code>Metadata</code> is an object argument the tool adds to the derived schema,
/// its members set over the new client's.</p>
/// <p>The client secret is not this tool's: it is written only by
/// <class>OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret</class> (AD-56). The secret the vendor
/// generates for a new client is never shown.</p>
Class OcuPilot.Screen.Tool.OAuthRegisteredClientCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverclients.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter DESCRIPTION = "Propose registering one client with this instance's OAuth 2.0 authorization server. It creates nothing by itself: it answers a proposal the user reviews and confirms. Give the client's name, a name no registered client has, and for a confidential or public client at least one redirect URL; every field left out takes the value the classic portal gives a new client. The client secret is never an argument: propose setting it afterwards.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The absence read: the list, holding the one row whose <code>Name</code> equals the argument
/// (AD-51 as amended). The vendor's list reads no query parameter, so the id the read sends it is
/// ignored.</p>
Parameter READTYPE = "LIST";

Parameter READROWKEY = "Name";

/// <p>The vendor's create, which answers 201 with the new client id in its <code>Location</code>
/// header.</p>
Parameter WRITETYPE = "POST";

Parameter PORTCLASS = "OcuPilot.Port.OAuthRegisteredClientPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>; the tab already
/// declares it (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Registration";

Parameter WRITEPERMISSION = "USE";

/// <p>The object argument this tool adds to the derived schema.</p>
Parameter METADATAFIELD = "Metadata";

Parameter RULES = "OcuPilot.Area.Security.OAuthRegisteredClientRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ServerClients"
}

/// <p>The vendor's query parameter for a client; its create and its list read none.</p>
ClassMethod IdParam() As %String
{
    Quit "clientId"
}

/// <p>The fields the composed payload may set: the <code>ordinary</code> template fields, derived
/// (AD-3), and the object argument.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#METADATAFIELD)
}

/// <p>The derived schema, described, with the object argument added and the create's own required
/// fields required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the fields the rules read described and the object argument added, for
/// a create when <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tTexts = {}
    If 'pCreates Do tTexts.%Set("Name", "The client's name. Two clients may share a name.", "string")
    Do tTexts.%Set("ClientType", "confidential, public, or resource (a resource server that is not also a client).", "string")
    Do tTexts.%Set("RedirectURL", "Every redirect URL the client uses, each an absolute URL with a scheme and a host. At least one for a confidential or public client. It replaces the whole list.", "string")
    Do tTexts.%Set("LaunchURL", "The URL the client is launched at, an absolute URL, or an empty string.", "string")
    Do tTexts.%Set("Description", "A description of the client.", "string")
    Do tTexts.%Set("ClientCredentials", "The X.509 credential holding the client's certificate, or an empty string.", "string")
    Do tTexts.%Set("DefaultScope", "The scopes an access token request that names none receives, separated by spaces, or an empty string.", "string")
    Set tIterator = tTexts.%GetIterator()
    While tIterator.%GetNext(.tField, .tText) {
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tText, "string")
    }
    Set tMetadata = {"type": "object"}
    Do tMetadata.%Set("description", "The client's registration metadata, each member optional: grant_types (a list naming at least one of authorization_code, implicit, password, client_credentials, jwt_authorization; refresh_token is always added), response_types (a list of code, id_token, 'id_token token', token), token_endpoint_auth_method (none, client_secret_basic, client_secret_post, client_secret_jwt, private_key_jwt), client_name, logo_uri, client_uri, policy_uri, tos_uri and frontchannel_logout_uri (absolute URLs on the scheme and host of a redirect URL), contacts (a list of email addresses), default_max_age (whole seconds), frontchannel_logout_session_required (a boolean), jwks_uri (the http or https URL of the client's public keys), and the signing, encryption and key algorithms for the ID token, userinfo, access token and request object. client_secret and registration_access_token are never accepted. A member left out " _ $Select(pCreates: "takes the new client's value.", 1: "keeps its stored value."), "string")
    Do tProperties.%Set(..#METADATAFIELD, tMetadata)
    If pCreates && (pSchema.%GetTypeOf("required") = "array") && (tProperties.%GetTypeOf("RedirectURL") = "object") Do pSchema.%Get("required").%Push("RedirectURL")
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    Do tArgs.%Set(..IdArgument(), pIdValue, "string")
    Quit ..RuleProblem(tArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Validate</method> over <var>pArgs</var>
/// in mode <var>pMode</var>, against <var>pFresh</var> where an edit has one, as one
/// <var>pProblem</var> naming each field and its sentence.</p>
ClassMethod RuleProblem(pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, .tViolations, pMode, pFresh)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(..#RULES, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The complete body: <method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Defaults</method>
/// with each supplied settable argument set over it, <code>Metadata</code> member by member, and the
/// name. One diff row per supplied field, and every other template field counted unchanged
/// (AD-54).</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tDefaults = $ClassMethod(..#RULES, "Defaults")
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
        If tArgs.%GetTypeOf(..#METADATAFIELD) = "object" Do tArgs.%Set(..#METADATAFIELD, $ClassMethod(..#RULES, "MergedMetadata", tDefaults, tArgs.%Get(..#METADATAFIELD)))
        ; The name is the target's id and a template field: it is composed like any other field.
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tArgs, "", pSettable, .tComposed, .tDiff, .tUnchanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        Set pPayload = tDefaults
        Set tSupplied = 0
        Set tIterator = tComposed.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = tComposed.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do pPayload.%Set(tKey, tValue)
            } Else {
                Do pPayload.%Set(tKey, tValue, tType)
            }
            Set tSupplied = tSupplied + 1
        }
        Set pDiff = $ClassMethod(..#RULES, "CardRows", $ClassMethod(..#RULES, "Defaults"), pPayload, tDiff)
        Set tTotal = 0
        Set tIterator = pPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) { Set tTotal = tTotal + 1 }
        Set pUnchanged = tTotal - tSupplied
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Hold the body to the template fields just before the port is called
/// (<method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Expand</method>). The values the user
/// reviewed are unchanged.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do $ClassMethod(..#RULES, "Expand", pPayload)
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
