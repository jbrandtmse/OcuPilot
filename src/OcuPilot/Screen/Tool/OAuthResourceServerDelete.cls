/// <p>The OAuth 2.0 screen's resource server delete tool (AD-6, AD-51, AD-53): propose removing one
/// resource server. It reads the server's service mappings fresh through
/// <class>OcuPilot.Port.OAuthResourceServerPort</class>'s <code>MAPPINGS</code> read and mints a
/// proposal whose card lists what would go. It writes nothing. The Resource servers tab's
/// <code>delete</code> row action is the same operation (AD-53).</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, and the tool
/// admits no settable field.</p>
/// <p><b>It is destructive</b>: the vendor deletes the server's service mappings with it, and nothing
/// proposes them back. The fingerprint covers the issuer endpoint and the mappings, so a mapping
/// added or moved since the mint refuses the confirm.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthresourceservers.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter DESCRIPTION = "Propose deleting one OAuth 2.0 resource server from this instance, together with its service mappings. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server exactly as the resource servers list reports it.";

/// <p>The row action this tool carries out from the Resource servers tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The port's mapping read and the vendor's delete (AD-51, AD-52).</p>
Parameter READTYPE = "MAPPINGS";

Parameter WRITETYPE = "DELETE";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted resource server and its service mappings are gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names the <code>MAPPINGS</code> read answers.</p>
Parameter READANSWERS = "IssuerEndpoint,Mappings,Held,Service,Key";

Parameter PRECONDITIONFIELD = "IssuerEndpoint";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint,Mappings";

Parameter PORTCLASS = "OcuPilot.Port.OAuthResourceServerPort";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ResourceServer"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The resource server to delete, by its name exactly as the resource servers list reports it. A server the list does not report is refused.", "string")
    Quit tSchema
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the <code>MAPPINGS</code> read
/// <var>pFresh</var>: the issuer endpoint, and the service mappings removed with the server. A read
/// that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that resource server's own record, so it is not one to delete"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", "IssuerEndpoint", "string")
    Do tRow.%Set("before", pFresh.%Get("IssuerEndpoint"), "string")
    Do tRow.%Set("after", "", "string")
    Do tRow.%Set("removed", 1, "boolean")
    Do pRows.%Push(tRow)
    Set tRow = {}
    Do tRow.%Set("field", "Mappings", "string")
    Do tRow.%Set("before", ##class(OcuPilot.Area.Security.OAuthResourceServerRules).MappingsText(pFresh.%Get("Mappings")), "string")
    Do tRow.%Set("after", "", "string")
    Do tRow.%Set("removed", 1, "boolean")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
