/// <p>The managed file transfer connections' create tool (AD-54, AD-55, Story 18.26): propose a new connection.
/// It reads the intended name fresh through the vendor's own <code>Security.MFT</code> <code>GET</code>, requires
/// that read to answer <b>nothing</b>, composes the body from the five fields the arguments supply and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert that needs all five fields (201 on create, measured), so the
/// absence fingerprint is what stops a confirmed create rewriting a connection somebody else created since the
/// mint (AD-54). The rules of <method>OcuPilot.Area.Security.MftConnectionRules.Check</method> refuse the arguments
/// at the mint, the same rules the screen's Save applies. <b>It never creates an OAuth 2.0 client
/// configuration</b>: <code>ApplicationName</code> names one, which may not exist yet.</p>
Class OcuPilot.Screen.Tool.MftConnectionCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.mftconnections.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter DESCRIPTION = "Propose a new managed file transfer connection. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the connection and give all five settings: the service (Box, Dropbox or Kiteworks), its URL, the SSL/TLS client configuration, the email address and the name of an OAuth 2.0 client configuration. It does not create the OAuth 2.0 client configuration (use security.oauthclients.create), and the connection must still be authorized on the classic Managed File Transfer Connections page before it can transfer files.";

/// <p>The port that composes the revoke's read and judges a delete (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.MftPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's one write that takes a body, an upsert.</p>
Parameter WRITETYPE = "PUT";

/// <p>The five settings this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "Service,URL,SSLConfiguration,Username,ApplicationName";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool
/// of the area (AD-8). Security's set is what the write needs, measured at Story 18.26's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.MFT.Connection";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.MftConnectionRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.MFT"
}

/// <p><class>OcuPilot.Screen.Tool.MftConnectionMint</class>, which refuses an empty name in the published
/// sentence.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MftConnectionMint"
}

/// <p>The vendor's <code>connection</code> query parameter, which carries the name.</p>
ClassMethod IdParam() As %String
{
    Quit "connection"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with every field described and all five required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ..Described(##super(pDescriptor), 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        For tI = 1:1:$Length(..#PERMITTEDFIELDS, ",") {
            Set tField = $Piece(..#PERMITTEDFIELDS, ",", tI)
            If tSchema.%Get("properties").%GetTypeOf(tField) = "object" Do tSchema.%Get("required").%Push(tField)
        }
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with the name and each setting described, for a create when <var>pCreates</var> is 1 and
/// for an edit, a delete or a revoke otherwise. Every connection tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If pCreates {
        Set tDescriptions("Name") = "The name the new connection takes, 1 to 64 characters with no control character, kept exactly as written. A connection that already has the name is refused."
    } Else {
        Set tDescriptions("Name") = "The connection, exactly as the Managed file transfer connections list reports its name; a different capitalization names a different connection."
    }
    Set tDescriptions("Service") = "The file service: Box, Dropbox or Kiteworks. Only a create sets it; a connection's service cannot be changed."
    Set tDescriptions("URL") = "The service's URL: an absolute http or https URL that ends in /, at most 1024 characters."
    Set tDescriptions("SSLConfiguration") = "The name of an SSL/TLS client configuration that exists on this instance."
    Set tDescriptions("Username") = "The email address of the account on the file service, 1 to 160 characters."
    Set tDescriptions("ApplicationName") = "The name of an OAuth 2.0 client configuration, 1 to 64 characters. It is set up on the OAuth 2.0 screen's Client configurations tab, or with security.oauthclients.create; this tool does not create it. Deleting the connection deletes that client configuration unless another connection names it."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit pSchema
}

/// <p>The rules over the agent's arguments, create mode, each broken one as its field and published sentence
/// (AD-55). <var>pIdValue</var> is the name; the name look-up is skipped, the mint's absence read having answered
/// it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", pIdValue, pArgs, "", "create", ..PortClass(), .pProblem, 1)
}

/// <p>What the caller must hold: the list's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// and the custom resource of the <parameter>CLASSICPAGES</parameter> editor, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
