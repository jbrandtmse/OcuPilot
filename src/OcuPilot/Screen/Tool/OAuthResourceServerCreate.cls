/// <p>The OAuth 2.0 screen's resource server create tool (AD-54, AD-55): propose a new resource server
/// -- a definition this instance validates OAuth 2.0 access tokens with, against one of its server
/// descriptions. It reads the intended name fresh through
/// <class>OcuPilot.Port.OAuthResourceServerPort</class>, requires that read to answer <b>nothing</b>,
/// composes the payload from its arguments and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>The name is the id</b> (AD-13), sent as the vendor's <code>name</code> query, which cannot
/// change after the create. The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is
/// what refuses a name taken since the mint (AD-54).</p>
/// <p><b><code>Authenticator</code> is one object argument</b>: the authenticator's namespace, class
/// and settings, held by <method>ArgumentProblem</method> to a class that namespace compiles and to
/// the settings it describes. A credential-named setting is never an argument.</p>
/// <p>The client secret is not this tool's: it is written only by
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerSetSecret</class> (AD-56). Service mappings are
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerAddMapping</class>'s.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthresourceservers.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter DESCRIPTION = "Propose a new OAuth 2.0 resource server on this instance: a definition it validates OAuth 2.0 access tokens with, against one of its server descriptions. It creates nothing by itself: it answers a proposal the user reviews and confirms. Give the name, the issuer endpoint of a server description and at least one audience. The client secret is never an argument, and service mappings are added separately.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's upsert, which answers 201 on an absent name.</p>
Parameter WRITETYPE = "PUT";

Parameter PORTCLASS = "OcuPilot.Port.OAuthResourceServerPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>; the tab already
/// declares it (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The argument the authenticator travels under.</p>
Parameter AUTHENTICATORFIELD = "Authenticator";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ResourceServer"
}

/// <p>The fields the composed payload may set: the <code>ordinary</code> template fields, derived
/// (AD-3), and <code>Authenticator</code>, which this tool carries as one object.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#AUTHENTICATORFIELD)
}

/// <p>The derived schema, described, with <code>Authenticator</code> added and the create's own
/// required fields required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the fields the rules read described and <code>Authenticator</code>
/// added, for a create when <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        If pCreates {
            Do tProperties.%Get("Name").%Set("description", "The name of the new resource server: 1 to 128 characters, compared exactly. A name this instance already has is refused, so check the resource servers list first. It cannot be changed later.", "string")
        } Else {
            Do tProperties.%Get("Name").%Set("description", "The resource server to change, by its name exactly as the resource servers list reports it. The name itself cannot be changed.", "string")
        }
    }
    Set tTexts = {}
    Do tTexts.%Set("IssuerEndpoint", "The issuer endpoint of the server description whose tokens this server validates, exactly as the server descriptions list reports it.", "string")
    Do tTexts.%Set("Audiences", "Every audience an access token's aud claim may name, each 1 to 256 characters and listed once. At least one. It replaces the whole list.", "string")
    Do tTexts.%Set("Description", "A description of at most 256 characters.", "string")
    Do tTexts.%Set("ScopeRequiredToConnect", "A scope every access token must carry, or an empty string for none. At most 256 characters.", "string")
    Do tTexts.%Set("ClientId", "The client ID this instance presents to the introspection endpoint, or an empty string.", "string")
    Do tTexts.%Set("IntrospectionAuthMethod", "How this instance authenticates to the introspection endpoint: client_secret_basic, client_secret_post, none, or an empty string.", "string")
    Do tTexts.%Set("Enabled", "Whether the resource server is enabled.", "string")
    Do tTexts.%Set("AccessTokenIsJWT", "Whether access tokens are JWTs this instance validates itself.", "string")
    Do tTexts.%Set("AlwaysCallIntrospection", "Whether this instance also calls the introspection endpoint for every JWT.", "string")
    Do tTexts.%Set("UseOIDC", "Whether this instance calls the userinfo endpoint when a token carries the openid scope.", "string")
    Set tIterator = tTexts.%GetIterator()
    While tIterator.%GetNext(.tField, .tText) {
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tText, "string")
    }
    If pCreates {
        Set tText = "The authenticator that maps a validated token to a user: {""Namespace"": <namespace>, ""Implementation"": <class>, <setting>: <value>, ...}. Omit it for the instance's default, %OAuth2.ResourceServer.SimpleAuthenticator in %SYS. A setting left out takes the class's default. A setting whose name is a credential's is never accepted."
    } Else {
        Set tText = "The authenticator that maps a validated token to a user: {""Namespace"": <namespace>, ""Implementation"": <class>, <setting>: <value>, ...}. With the same namespace and class, a setting left out keeps its stored value; with another, it takes the new class's default. Omit it to leave the authenticator as it is. A setting whose name is a credential's is never accepted."
    }
    Set tAuthenticator = {"type": "object"}
    Do tAuthenticator.%Set("description", tText, "string")
    Do tProperties.%Set(..#AUTHENTICATORFIELD, tAuthenticator)
    If pCreates && (pSchema.%GetTypeOf("required") = "array") {
        For tField = "IssuerEndpoint", "Audiences" {
            If tProperties.%GetTypeOf(tField) = "object" Do pSchema.%Get("required").%Push(tField)
        }
    }
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode, the name look-up skipped
/// because the mint's absence read has answered it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.Security.OAuthResourceServerRules.Validate</method> over <var>pArgs</var>
/// for <var>pIdValue</var> in mode <var>pMode</var>, against <var>pFresh</var> where an edit has one,
/// as one <var>pProblem</var> naming each field and its sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Validate(pIdValue, pArgs, .tViolations, pMode, 0, pFresh)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Problem(.tViolations)
    Quit $$$OK
}

/// <p>Hold the body to the template fields just before the port is called
/// (<method>OcuPilot.Area.Security.OAuthResourceServerRules.Expand</method>): a field the arguments
/// leave out is not sent, so the vendor sets its own default. The values the user reviewed are
/// unchanged.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Expand(pPayload)
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
