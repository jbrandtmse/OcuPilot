/// <p>The X.509 credentials list's delete tool (AD-6, AD-51): propose removing one X.509
/// credential. It reads the credential's certificate fresh through the vendor's own
/// <code>Security.X509Credential</code> <code>CERTINFO</code> and mints a proposal whose card lists
/// what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>PUT</code> or <code>POST</code>, so <code>DELETE</code> reads no body, the tool admits no
/// settable field, and its field list is empty by derivation (AD-3).</p>
/// <p><b>Its fingerprint covers the certificate the user reviewed</b>: its serial number and issuer.
/// A certificate replaced under the same alias since the mint refuses the confirm. The identity is
/// outside the subject (AD-13, AD-51).</p>
Class OcuPilot.Screen.Tool.X509Delete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.x509.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter DESCRIPTION = "Propose deleting one X.509 credential from this instance, with its certificate and any private key. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the credential by its alias exactly as the X.509 credentials list reports it, case included.";

/// <p>The fresh read: the vendor's certificate read, which answers the subject, issuer, serial
/// number and validity the single-object <code>GET</code> does not.</p>
Parameter READTYPE = "CERTINFO";

/// <p>The vendor's own delete request type, which answers 404 for an absent alias.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted credential is gone with its private key, which OcuPilot cannot restore.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the vendor's
/// <code>RunCertInfo</code> on this build.</p>
Parameter READANSWERS = "SubjectDN,IssuerDN,SerialNumber,ValidityNotBefore,ValidityNotAfter,HasPrivateKey";

/// <p>The serial number is the precondition: together with the issuer it names the one certificate
/// the user reviewed.</p>
Parameter PRECONDITIONFIELD = "SerialNumber";

Parameter FINGERPRINTSUBJECT = "SerialNumber,IssuerDN";

/// <p>The rows the card lists, in order: the certificate as the fresh read describes it.</p>
Parameter REMOVALROWS = "SubjectDN,IssuerDN,SerialNumber,ValidityNotBefore,ValidityNotAfter,HasPrivateKey";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.X509Credential"
}

/// <p>The input property that names the target: a credential is keyed by its alias.</p>
ClassMethod IdArgument() As %String
{
    Quit "Alias"
}

/// <p>The vendor's own query parameter for the alias.</p>
ClassMethod IdParam() As %String
{
    Quit "alias"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>None: a delete sends no body, so the confirm channel admits no
/// secret for it (AD-6); they travel only in an import.</p>
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The credential to delete, exactly as this instance's own X.509 credentials list reports its alias, case included.", "string")
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

/// <p>The removal rows this proposal's card shows, from the fresh <code>CERTINFO</code>
/// <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the
/// instance holds and no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that credential's certificate serial number, and a credential whose certificate is unknown is not one to delete"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
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
