/// <p>The OAuth 2.0 screen's server description create tool (AD-54, AD-55): propose a new server
/// description -- an authorization server this instance's OAuth 2.0 clients can be configured
/// against. It reads the intended issuer fresh through
/// <class>OcuPilot.Port.OAuthServerPort</class>, requires that read to answer <b>nothing</b>,
/// composes the payload from its arguments and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>The issuer is the id</b> (AD-13): it travels as the port's <code>issuer</code> query, which
/// the port sends as the body's <code>IssuerEndpoint</code>. The vendor answers a duplicate issuer
/// 409; the absence fingerprint is what refuses one taken since the mint (AD-54).</p>
/// <p><b><code>Metadata</code> is one object argument</b> whose members are the ones derived from the
/// vendor's <code>OAuth2.Server.Metadata</code> (<method>OcuPilot.Area.Security.OAuthServerRules.Members</method>),
/// named in its description and held to their names and shapes by <method>ArgumentProblem</method>.
/// Just before the port is called the body is made the complete set (<method>DerivedFields</method>):
/// every member the argument leaves out is sent empty.</p>
/// <p>The registration access token is not this tool's: it is a declared secret written only by
/// <class>OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken</class> (AD-56).</p>
Class OcuPilot.Screen.Tool.OAuthServerDescriptionCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverdescriptions.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter DESCRIPTION = "Propose a new OAuth 2.0 server description on this instance: the authorization server its OAuth 2.0 client configurations are described against. It creates nothing by itself: it answers a proposal the user reviews and confirms. Give the issuer endpoint, the SSL/TLS configuration used to reach it, and its metadata with at least the authorization and token endpoints.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's create request type, which answers 201, or 409 for an issuer already taken.</p>
Parameter WRITETYPE = "POST";

Parameter PORTCLASS = "OcuPilot.Port.OAuthServerPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>; the tab already
/// declares it, so the resolved set is the tab's own two pairs (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

/// <p>The argument the derived members travel under.</p>
Parameter METADATAFIELD = "Metadata";

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

/// <p>The fields the composed payload may set: the <code>ordinary</code> template fields, derived
/// (AD-3), and <code>Metadata</code>, which the classification calls <code>opaque</code> and this
/// tool carries as an object of the derived members.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#METADATAFIELD)
}

/// <p>The derived schema, described, with <code>Metadata</code> added and both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the identifying property, the two literals and <code>Metadata</code>
/// described, for a create when <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("IssuerEndpoint") = "object" {
        If pCreates {
            Do tProperties.%Get("IssuerEndpoint").%Set("description", "The issuer endpoint of the new description: an absolute http or https URL with no query or fragment, compared exactly. An issuer this instance already describes is refused, so check the server descriptions list first.", "string")
        } Else {
            Do tProperties.%Get("IssuerEndpoint").%Set("description", "The description to change, by its issuer endpoint exactly as the server descriptions list reports it. The issuer itself cannot be changed here.", "string")
        }
    }
    If tProperties.%GetTypeOf("SSLConfiguration") = "object" Do tProperties.%Get("SSLConfiguration").%Set("description", "The name of the SSL/TLS configuration this instance uses to reach the authorization server.", "string")
    If tProperties.%GetTypeOf("ServerCredentials") = "object" Do tProperties.%Get("ServerCredentials").%Set("description", "The alias of an X.509 credential whose certificate holds the authorization server's public key, or an empty string for none.", "string")
    If pCreates {
        Set tText = "The authorization server's metadata, as its discovery document names it. authorization_endpoint and token_endpoint are required."
    } Else {
        Set tText = "The description's whole metadata. It replaces the stored metadata: a member left out is cleared, so send every member to keep, authorization_endpoint and token_endpoint included. Omit it to leave the metadata as it is."
    }
    Set tMetadata = ##class(OcuPilot.Area.Security.OAuthServerRules).MetadataSchema(tText)
    If $IsObject(tMetadata) Do tProperties.%Set(..#METADATAFIELD, tMetadata)
    If pCreates && (pSchema.%GetTypeOf("required") = "array") {
        For tField = "SSLConfiguration", ..#METADATAFIELD {
            If tProperties.%GetTypeOf(tField) = "object" Do pSchema.%Get("required").%Push(tField)
        }
    }
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode, the issuer look-up skipped
/// because the mint's absence read has answered it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.Security.OAuthServerRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var> in mode <var>pMode</var>, against <var>pFresh</var> where an edit has one, as
/// one <var>pProblem</var> naming each field and its sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.OAuthServerRules).Validate(pIdValue, pArgs, .tViolations, pMode, 0, pFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Make the body the complete set just before the port is called
/// (<method>OcuPilot.Area.Security.OAuthServerRules.Expand</method>): the template fields alone, and
/// every derived member of <code>Metadata</code>, a member the arguments left out sent empty. The
/// values the user reviewed are unchanged.</p>
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
