/// <p>The OAuth 2.0 screen's client configuration create tool (AD-54, AD-55): propose a new client
/// configuration -- an application this instance acts as an OAuth 2.0 client for, against one of its
/// server descriptions. It reads the intended name fresh through
/// <class>OcuPilot.Port.OAuthClientPort</class>, requires that read to answer <b>nothing</b>, composes
/// the payload from its arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>The application name is the id</b> (AD-13), sent as the vendor's <code>applicationName</code>
/// query, which cannot change after the create. The vendor's <code>PUT</code> is an upsert, so the
/// absence fingerprint is what refuses a name taken since the mint (AD-54).</p>
/// <p><b><code>Metadata</code> is one object argument</b> whose members are the settable ones derived
/// from the vendor's <code>OAuth2.Client.Metadata</code>
/// (<method>OcuPilot.Area.Security.OAuthClientRules.Members</method>), held to their names, shapes and
/// fixed values by <method>ArgumentProblem</method>. Just before the port is called the body is held
/// to the template fields (<method>DerivedFields</method>); a member it leaves out takes the vendor's
/// default.</p>
/// <p>The client secret, the key password and the registration access token are not this tool's:
/// they are declared secrets written only by <class>OcuPilot.Screen.Tool.OAuthClientSetSecrets</class>
/// (AD-56).</p>
Class OcuPilot.Screen.Tool.OAuthClientCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose a new OAuth 2.0 client configuration on this instance: an application this instance is an OAuth 2.0 client for, against one of its server descriptions. It creates nothing by itself: it answers a proposal the user reviews and confirms. Give the application name, the server description's ID, the client type, the SSL/TLS configuration and, unless the client type is resource, the redirect URL. Secrets are never arguments.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's upsert, which answers 201 on an absent name.</p>
Parameter WRITETYPE = "PUT";

Parameter PORTCLASS = "OcuPilot.Port.OAuthClientPort";

/// <p>The endpoint's own <code>ResourcesOR()</code> resource at <code>USE</code>; the tab already
/// declares it (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

/// <p>The argument the derived members travel under.</p>
Parameter METADATAFIELD = "Metadata";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ClientConfiguration"
}

/// <p>The configuration's id: its application name.</p>
ClassMethod IdArgument() As %String
{
    Quit "ApplicationName"
}

/// <p>The vendor's query parameter for the configuration.</p>
ClassMethod IdParam() As %String
{
    Quit "applicationName"
}

/// <p>The fields the composed payload may set: the <code>ordinary</code> template fields, derived
/// (AD-3), and <code>Metadata</code>, which the classification calls <code>opaque</code> and this tool
/// carries as an object of the settable derived members.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#METADATAFIELD)
}

/// <p>The derived schema, described, with <code>Metadata</code> added and the create's own required
/// fields required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the fields the rules read described, <code>Enabled</code> a boolean and
/// <code>JWTInterval</code> an integer, and <code>Metadata</code> added, for a create when
/// <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("ApplicationName") = "object" {
        If pCreates {
            Do tProperties.%Get("ApplicationName").%Set("description", "The application name of the new client configuration: 1 to 128 characters, compared exactly. A name this instance already has is refused, so check the client configurations list first. It cannot be changed later.", "string")
        } Else {
            Do tProperties.%Get("ApplicationName").%Set("description", "The client configuration to change, by its application name exactly as the client configurations list reports it. The name itself cannot be changed.", "string")
        }
    }
    Set tTexts = {}
    Do tTexts.%Set("ServerDefinition", "The ID of the server description this client is configured against, as the server descriptions list reports it.", "string")
    Do tTexts.%Set("ClientType", "One of confidential, public or resource.", "string")
    Do tTexts.%Set("SSLConfiguration", "The name of the SSL/TLS configuration this instance uses to reach the authorization server.", "string")
    Do tTexts.%Set("RedirectionEndpoint", "The client's redirect URL: an absolute http or https URL with a host. Required unless the client type is resource.", "string")
    Do tTexts.%Set("ClientCredentials", "The alias of an X.509 credential with a private key whose keys sign this client's JWTs, or an empty string for none.", "string")
    Do tTexts.%Set("DefaultScope", "The scopes requested by default, separated by spaces.", "string")
    Set tIterator = tTexts.%GetIterator()
    While tIterator.%GetNext(.tField, .tText) {
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tText, "string")
    }
    If tProperties.%GetTypeOf("Enabled") = "object" {
        Do tProperties.%Get("Enabled").%Set("type", "boolean", "string")
        Do tProperties.%Get("Enabled").%Set("description", "Whether the client configuration is enabled.", "string")
    }
    If tProperties.%GetTypeOf("JWTInterval") = "object" {
        Do tProperties.%Get("JWTInterval").%Set("type", "integer", "string")
        Do tProperties.%Get("JWTInterval").%Set("description", "The JWT interval in seconds.", "string")
    }
    If pCreates {
        Set tText = "The client's registration metadata. Leave out a member to leave it empty; the instance sets its own signing-algorithm defaults."
    } Else {
        Set tText = "The client's whole settable metadata. It replaces the stored metadata: a member left out is cleared, so send every member to keep. Omit it to leave the metadata as it is. The registration's own members are kept as the instance holds them."
    }
    Set tMetadata = ##class(OcuPilot.Area.Security.OAuthClientRules).MetadataSchema(tText)
    If $IsObject(tMetadata) Do tProperties.%Set(..#METADATAFIELD, tMetadata)
    If pCreates && (pSchema.%GetTypeOf("required") = "array") {
        For tField = "ServerDefinition", "ClientType", "SSLConfiguration" {
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

/// <p><method>OcuPilot.Area.Security.OAuthClientRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var> in mode <var>pMode</var>, against <var>pFresh</var> where an edit has one, as
/// one <var>pProblem</var> naming each field and its sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.OAuthClientRules).Validate(pIdValue, pArgs, .tViolations, pMode, 0, pFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Hold the body to the template fields and no secret member just before the port is called
/// (<method>OcuPilot.Area.Security.OAuthClientRules.Expand</method>, composed): a member the arguments
/// leave out is not sent, so the vendor sets its own algorithm defaults. The values the user reviewed
/// are unchanged.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.Security.OAuthClientRules).Expand(pPayload, 0)
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
