/// <p>The OAuth 2.0 screen's authorization server create tool (AD-54, AD-55): propose this instance's
/// one authorization server configuration. It reads the configuration fresh through
/// <class>OcuPilot.Port.OAuthAuthorizationServerPort</class>, requires that read to answer
/// <b>nothing</b>, composes the complete body and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>The target is a singleton</b>, keyed by <parameter>OcuPilot.Kernel.EntityRef.RULESINGLETONID</parameter>
/// whatever the identifying argument spells (AD-13). The vendor's <code>PUT</code> is an upsert, so
/// the absence fingerprint is what refuses a configuration made since the mint (AD-54).</p>
/// <p><b>The body is complete</b>, because the vendor refuses a partial create: a field the
/// arguments leave out takes the classic page's value for a new configuration
/// (<method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Defaults</method>) and is counted
/// unchanged. <code>SupportedScopes</code> and <code>Metadata</code> are object arguments the tool
/// adds to the derived schema; <code>Metadata</code> takes only the members the editor sets.</p>
/// <p>The key password is not this tool's: it is written only by
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword</class> (AD-56).</p>
Class OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserver.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter DESCRIPTION = "Propose this instance's OAuth 2.0 authorization server configuration, when it has none. It creates nothing by itself: it answers a proposal the user reviews and confirms. Give the issuer endpoint, at least one supported scope and the customization roles; every field left out takes the value the classic portal gives a new configuration. The key password is never an argument.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's upsert, which answers 201 when the instance has no configuration.</p>
Parameter WRITETYPE = "PUT";

Parameter PORTCLASS = "OcuPilot.Port.OAuthAuthorizationServerPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>; the tab already
/// declares it (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Server";

Parameter WRITEPERMISSION = "USE";

/// <p>The two object arguments this tool adds to the derived schema.</p>
Parameter SCOPESFIELD = "SupportedScopes";

Parameter METADATAFIELD = "Metadata";

Parameter RULES = "OcuPilot.Area.Security.OAuthAuthorizationServerRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Server"
}

/// <p>The fields the composed payload may set: the <code>ordinary</code> template fields, derived
/// (AD-3), and the two object arguments.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#SCOPESFIELD, ..#METADATAFIELD)
}

/// <p>The derived schema, described, with the two object arguments added and the create's own
/// required fields required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the identifying argument and the fields the rules read described and
/// the two object arguments added, for a create when <var>pCreates</var> is 1 and for an edit
/// otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tId = ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one authorization server configuration, so send the literal '" _ tId _ "'. Any other spelling names the same configuration.", "string")
    Set tTexts = {}
    Do tTexts.%Set("IssuerEndpoint", "The issuer endpoint: https://host, an optional port and an optional path, with no query or fragment. The authorization server answers at it with /oauth2 appended.", "string")
    Do tTexts.%Set("Description", "A description of at most 1024 characters.", "string")
    For tField = "AccessTokenInterval", "AuthorizationCodeInterval", "RefreshTokenInterval" Do tTexts.%Set(tField, "A whole number of seconds, at least 1.", "string")
    For tField = "SessionInterval", "ClientSecretInterval" Do tTexts.%Set(tField, "A whole number of seconds, at least 0; 0 turns it off.", "string")
    Do tTexts.%Set("ReturnRefreshToken", "When a refresh token is returned: an empty string for only as OpenID Connect requires, a for always, c for a confidential client, f when the offline_access scope is requested.", "string")
    Do tTexts.%Set("DefaultScope", "The scopes a request that names none receives, separated by spaces, or an empty string.", "string")
    Do tTexts.%Set("CustomizationRoles", "The roles the customization code runs with, at least one, each a role this instance has. It replaces the whole list. Adding %All or an %Admin_ role is confirmed as a destructive change.", "string")
    Do tTexts.%Set("CustomizationNamespace", "The namespace the customization classes are compiled in.", "string")
    For tField = "AuthenticateClass", "SessionClass", "ValidateUserClass", "GenerateTokenClass", "RevokeTokenClass" Do tTexts.%Set(tField, "A class compiled in the customization namespace, at most 256 characters.", "string")
    Do tTexts.%Set("ServerCredentials", "The X.509 credential whose private key signs the server's tokens, or an empty string for keys this instance generates.", "string")
    Do tTexts.%Set("SigningAlgorithm", "RS256, RS384, RS512, HS256, HS384, HS512, ES256, ES384, ES512, PS256, PS384, PS512, or an empty string.", "string")
    Do tTexts.%Set("KeyAlgorithm", "RSA1_5, RSA-OAEP, A128KW, A192KW, A256KW, dir, or an empty string; set together with EncryptionAlgorithm or not at all.", "string")
    Do tTexts.%Set("EncryptionAlgorithm", "A128CBC-HS256, A192CBC-HS384, A256CBC-HS512, or an empty string; set together with KeyAlgorithm or not at all.", "string")
    Do tTexts.%Set("SSLConfiguration", "An SSL/TLS configuration this instance has, or an empty string.", "string")
    Set tIterator = tTexts.%GetIterator()
    While tIterator.%GetNext(.tField, .tText) {
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tText, "string")
    }
    Set tScopes = {"type": "array", "items": {"type": "object"}}
    Do tScopes.%Set("description", "Every scope the server supports, each {""Scope"": <name>, ""Description"": <text>} with no space in the name and listed once. At least one. It replaces the whole list.", "string")
    Do tProperties.%Set(..#SCOPESFIELD, tScopes)
    Set tMetadata = {"type": "object"}
    Do tMetadata.%Set("description", "The discovery settings the editor sets, each optional: grant_types_supported (a list naming at least one of authorization_code, implicit, password, client_credentials, jwt_authorization; refresh_token is always added), frontchannel_logout_supported and frontchannel_logout_session_supported (booleans), and service_documentation, op_policy_uri and op_tos_uri (absolute http or https URLs, or an empty string). A member left out " _ $Select(pCreates: "takes the new configuration's value.", 1: "keeps its stored value."), "string")
    Do tProperties.%Set(..#METADATAFIELD, tMetadata)
    If pCreates && (pSchema.%GetTypeOf("required") = "array") {
        For tField = "IssuerEndpoint", ..#SCOPESFIELD, "CustomizationRoles" {
            If tProperties.%GetTypeOf(tField) = "object" Do pSchema.%Get("required").%Push(tField)
        }
    }
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Validate</method> over
/// <var>pArgs</var> in mode <var>pMode</var>, against <var>pFresh</var> where an edit has one, as one
/// <var>pProblem</var> naming each field and its sentence.</p>
ClassMethod RuleProblem(pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, .tViolations, pMode, pFresh)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(..#RULES, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The complete body: <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Defaults</method>
/// with each supplied settable argument set over it, <code>Metadata</code> member by member. One
/// diff row per supplied field, and every other template field counted unchanged (AD-54).</p>
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
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tArgs, pIdArgument, pSettable, .tComposed, .tDiff, .tUnchanged, .pProblem)
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
/// (<method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Expand</method>). The values the user
/// reviewed are unchanged.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do $ClassMethod(..#RULES, "Expand", pPayload)
}

/// <p>The kernel-owned consequence of this payload: the customization privilege effect when the roles
/// it sets include <code>%All</code> or an <code>%Admin_</code> role, and <code>""</code>
/// otherwise.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).ServerConsequence("", pPrivileged, pEffect)
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
