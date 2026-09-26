/// <p>The SSL/TLS configurations list's delete tool (AD-6, AD-51, AD-53, FR-42): propose removing one
/// SSL/TLS configuration. It reads the configuration fresh through the vendor's own
/// <code>Security.SSLConfig</code> <code>GET</code> and mints a proposal whose card lists what would
/// go. It writes nothing; the list's Delete reaches the same write through the screen-action route.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is a put, the
/// test type or the password type, so <code>DELETE</code> reads no body, and the tool admits no
/// settable field.</p>
/// <p><b>Its fingerprint covers what anything connecting through the configuration relies on</b>: its
/// type, peer verification, trusted certificates and whether it is enabled. The identity is outside
/// the subject (AD-13, AD-51).</p>
/// <p><b>OcuPilot's own provider configuration is refused at the write</b>, for both callers, by the
/// kernel's <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSSL</parameter> (AD-10) -- the
/// agent's confirm and the list's Delete alike, with one published sentence -- as OcuPilot's own
/// roles are.</p>
Class OcuPilot.Screen.Tool.SslDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ssl.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter DESCRIPTION = "Propose deleting one SSL/TLS configuration from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration exactly as the SSL/TLS configurations list reports it, case included. OcuPilot's own provider configuration is refused.";

/// <p>The vendor's own delete request type, which answers 404 for an absent configuration.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted configuration is gone, and whatever connected through it fails until one
/// is made again.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The list's row action this write carries out (AD-53): Delete, bodyless.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The top-level names <parameter>READTYPE</parameter> answers that the subject names, read off
/// the vendor's <code>ObjToJson</code> on this build. The list's own read answers
/// <code>Type</code> as a word and none of the other three.</p>
Parameter READANSWERS = "Type,VerifyPeer,CAFile,Enabled";

/// <p>Whether the configuration is enabled is the precondition: a configuration disabled since the
/// mint is not the one the user reviewed.</p>
Parameter PRECONDITIONFIELD = "Enabled";

Parameter FINGERPRINTSUBJECT = "Type,VerifyPeer,CAFile,Enabled";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.SSLConfig"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>None: a delete sends no body, so the confirm channel admits no secret for it (AD-6).</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The configuration to delete, exactly as this instance's own SSL/TLS configurations list reports its name, case included. OcuPilot's own provider configuration is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per subject field, carrying the value the instance holds and no
/// after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report whether that configuration is enabled, and a configuration whose state is unknown is not one to delete"
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
