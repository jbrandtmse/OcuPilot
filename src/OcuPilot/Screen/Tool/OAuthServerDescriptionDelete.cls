/// <p>The OAuth 2.0 screen's server description delete tool (AD-6, AD-51, FR-44): propose removing
/// one server description and its metadata. It reads the description fresh through
/// <class>OcuPilot.Port.OAuthServerPort</class> and mints a proposal whose card lists what would go.
/// It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is a put, a post
/// or the token type, so <code>DELETE</code> reads no body and the tool admits no settable
/// field.</p>
/// <p><b>A description a client configuration uses is refused by name</b>, at the agent's mint
/// (<method>ArgumentProblem</method>) and by the port before the vendor is called, which the screen's
/// row action reaches; the vendor refuses it too, with a 500 that names nothing. A description a
/// resource server uses is deleted, and the vendor leaves the resource server's reference dangling,
/// which the delete's consequence line states. Its fingerprint covers the issuer and both counts, so
/// a client configured against it since the mint refuses the confirm.</p>
Class OcuPilot.Screen.Tool.OAuthServerDescriptionDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverdescriptions.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter DESCRIPTION = "Propose deleting one OAuth 2.0 server description, and its metadata, from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the description by its issuer endpoint exactly as the server descriptions list reports it. A description a client configuration uses is refused; a resource server that uses it is left without one.";

/// <p>The row action this tool carries out from the Server descriptions tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted description and its metadata are gone, and OcuPilot keeps no copy.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter PORTCLASS = "OcuPilot.Port.OAuthServerPort";

/// <p>The top-level names the port's <code>GET</code> answers that the card and the fingerprint
/// read.</p>
Parameter READANSWERS = "IssuerEndpoint,ClientCount,ResourceCount";

/// <p>The read field the delete's precondition reads: no client configuration may use the
/// description.</p>
Parameter PRECONDITIONFIELD = "ClientCount";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint,ClientCount,ResourceCount";

Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ServerDefinition"
}

ClassMethod IdArgument() As %String
{
    Quit "IssuerEndpoint"
}

ClassMethod IdParam() As %String
{
    Quit "issuer"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The description to delete, by its issuer endpoint exactly as the server descriptions list reports it.", "string")
    Quit tSchema
}

/// <p>A description a client configuration uses is refused by name at the mint, with the port's own
/// sentence (<parameter>OcuPilot.Api.Error.OAUTHSERVERINUSE</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If $IsObject($Get(tFresh)) && (+tFresh.%Get(..#PRECONDITIONFIELD) > 0) Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERINUSE
    Quit $$$OK
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// subject field, with no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report how many client configurations use that server description, and a description whose use is unknown is not one to delete"
            Quit
        }
        Set tSubject = ..FingerprintSubject()
        For tI = 1:1:$ListLength(tSubject) {
            Set tField = $List(tSubject, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
