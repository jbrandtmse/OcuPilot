/// <p>The mobile phone providers' create tool (AD-54, AD-55, Story 21.10): propose a new mobile phone provider. It reads
/// the intended name fresh through <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>GET</code>, requires that read to
/// answer <b>nothing</b>, composes the body from the SMS gateway the arguments supply and mints a proposal the user
/// confirms. It writes nothing.</p>
/// <p>The vendor finds a provider by its exact name, so the absence fingerprint is what stops a confirmed create racing a
/// provider somebody else created since the mint (AD-54), and the port refuses a name that exists. The rules of
/// <method>OcuPilot.Area.Security.PhoneProviderRules.Check</method> refuse the arguments at the mint, the same rules the
/// screen's Save and the port apply.</p>
Class OcuPilot.Screen.Tool.PhoneProviderCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.phoneproviders.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PhoneProviderList";

Parameter DESCRIPTION = "Propose a new mobile phone provider, a business a user can name for two-factor text messages. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the provider and give its SMS gateway, the DNS name of the SMTP-to-SMS gateway, each 1 to 50 characters. A provider that already exists under that exact name is refused.";

/// <p>The port that reads and writes the provider (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.PhoneProviderPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The port's create.</p>
Parameter WRITETYPE = "CREATE";

/// <p>The one setting this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "SMSGateway";

/// <p>The member the read-back compares: the port is not an admin endpoint, so no generated field list names it (AD-58).</p>
Parameter READBACKFIELDS = "SMSGateway";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool of
/// the area (AD-8). The list's set is what the write needs, measured at Story 21.10's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.PhoneProvider";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.PhoneProviderRules";

ClassMethod Endpoint() As %String
{
    Quit "PhoneProviders"
}

/// <p><class>OcuPilot.Screen.Tool.PhoneProviderMint</class>, which refuses an empty name in the published sentence.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.PhoneProviderMint"
}

/// <p>The port's <code>name</code> query parameter, which carries the provider's exact name.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
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

/// <p>The one field a create sends, a string (AD-3): the port is not an admin endpoint, so no generated field list
/// holds it.</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild("SMSGateway", "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with every field described and the SMS gateway required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ..Described(##super(pDescriptor), 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        If tSchema.%Get("properties").%GetTypeOf("SMSGateway") = "object" Do tSchema.%Get("required").%Push("SMSGateway")
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with the name and the SMS gateway described, for a create when <var>pCreates</var> is 1 and for
/// an edit or a delete otherwise. Every mobile phone provider tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If pCreates {
        Set tDescriptions("Name") = "The name the new provider takes, 1 to 50 characters with no control character, kept exactly as written. A provider that already exists under that exact name is refused."
    } Else {
        Set tDescriptions("Name") = "The provider, exactly as the Mobile phone providers list reports its name; a different capitalization names a different provider."
    }
    Set tDescriptions("SMSGateway") = "The DNS name of the provider's SMTP-to-SMS gateway, 1 to 50 characters with no control character. It is not checked for any other format."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit pSchema
}

/// <p>The rules over the agent's arguments, create mode, each broken one as its field and published sentence (AD-55).
/// <var>pIdValue</var> is the name.</p>
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
