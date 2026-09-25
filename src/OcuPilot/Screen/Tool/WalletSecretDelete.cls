/// <p>The Secrets list's delete tool (AD-6, AD-51, AD-52, AD-53, FR-46): propose removing one wallet
/// secret. It reads the secret fresh through <class>OcuPilot.Port.WalletPort</class> (AD-27's third
/// case) and mints a proposal whose card lists what would go. It writes nothing; the list's Delete
/// reaches the same write through the screen-action route.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body, and the tool admits no settable
/// field. The <code>DELETE</code> itself is the admin port's own call, which the wallet port passes
/// through unchanged.</p>
/// <p><b>Its fingerprint covers the secret's type</b>, the one thing the read answers for every kind
/// of secret. The stored value is never read (AD-27), so a new value set since the mint is not
/// detected.</p>
/// <p><b>No secret travels</b>: a delete carries no value, so <method>SecretArguments</method>
/// answers none, whatever the Secrets list declares for its create and edit.</p>
Class OcuPilot.Screen.Tool.WalletSecretDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.secrets.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter DESCRIPTION = "Propose deleting one secret from a wallet collection on this instance, with its stored value. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the secret exactly as the collection's Secrets list reports it, collection included, case included.";

/// <p>The fresh read: the wallet port's completed read, which answers the secret's type.</p>
Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type, which answers 404 for an absent or wrong-case name.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted secret's value is gone, and OcuPilot never read it, so nothing puts it
/// back.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The port the read and the write go through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.WalletPort";

/// <p>The Secrets list's row action this write carries out (AD-53): Delete, bodyless.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off
/// <class>OcuPilot.Port.WalletPort</class>: a key-value secret answers all four, any other its
/// type alone.</p>
Parameter READANSWERS = "Type,Usage,RequireTLS,AllowedHosts";

/// <p>The secret's type is the precondition and the whole subject: a secret replaced by one of
/// another type since the mint is not the one the user reviewed.</p>
Parameter PRECONDITIONFIELD = "Type";

Parameter FINGERPRINTSUBJECT = "Type";

Parameter WRITERESOURCE = "%Admin_Wallet";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Wallet.Secret"
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The secret to delete, as <collection>.<name>, exactly as the collection's Secrets list reports it, case included.", "string")
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

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>READANSWERS</parameter> name the read answered, carrying the value the instance holds
/// and no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that secret's type, and a secret whose type is unknown is not one to delete"
            Quit
        }
        Set tNames = ..ReadAnswers()
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            If pFresh.%GetTypeOf(tField) = "unassigned" Continue
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
