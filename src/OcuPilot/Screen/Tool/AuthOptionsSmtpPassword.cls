/// <p>The authentication options' SMTP password tool (AD-51, AD-56 (i), Story 18.8): propose setting or
/// clearing the password OcuPilot's two-factor SMS text authentication signs in to the SMTP server with.
/// It reads the options fresh through <class>OcuPilot.Port.AdminPort</class> and mints a proposal whose
/// card asks for the password at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's <code>CHANGESMTPPWD</code>
/// request type takes exactly <code>{SMTPPassword}</code>. The kernel carries the secret as the
/// descriptor's one declaration (<parameter>SECRETBODY</parameter>) and supplies it at the write
/// (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>); the model can never supply it,
/// because the tool admits no settable field and the mint refuses a declared secret outright.</p>
/// <p><b>An empty value clears the password</b> (<parameter>CLEARABLESECRETS</parameter>): the vendor's
/// <code>CHANGESMTPPWD</code> clears on <code>""</code> (measured at Story 18.8's Task 0). The card
/// requires a value, so clearing is the form's; a confirm that sends <code>""</code> clears it as the
/// user's own act.</p>
/// <p><b>Its fingerprint covers <code>SMTPUsername</code></b>, the account the password belongs to; the
/// password is never part of it, and no read answers one. The form's Save writes through this tool's
/// operation too (<method>OcuPilot.Area.Security.AuthOptionsSave.StorePassword</method>, AD-55).</p>
Class OcuPilot.Screen.Tool.AuthOptionsSmtpPassword Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.authoptions.smtppassword";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuthOptions";

Parameter DESCRIPTION = "Propose setting a new SMTP password for this instance's two-factor SMS text authentication, the password of the account it signs in to the SMTP server with. It changes nothing by itself: it answers a proposal the user reviews, and the user types the new password on the card when confirming. Never send a password: send the literal 'SYSTEM' as the name and nothing else.";

/// <p>The vendor's own SMTP password request type.</p>
Parameter WRITETYPE = "CHANGESMTPPWD";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The declared secret the write's body is made of, under the vendor's own key.</p>
Parameter SECRETBODY = "SMTPPassword";

/// <p>The secret whose explicitly supplied empty value clears the stored one (AD-56 (i)).</p>
Parameter CLEARABLESECRETS = "SMTPPassword";

/// <p>The card's one row is labelled <code>SMTPPassword</code>, which names the secret the card asks for
/// rather than a field the payload carries (AD-10, AD-51).</p>
Parameter STATEFIELD = "SMTPPassword";

Parameter PRECONDITIONFIELD = "SMTPUsername";

Parameter FINGERPRINTSUBJECT = "SMTPUsername";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.WebAuth"
}

/// <p>None: the write sends no merge body.</p>
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one set of authentication options, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. The new password is typed by the user at confirmation and is never an argument.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: Authentication options' own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and the custom resource of
/// each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "SMTPPassword", before:
/// "", after: ""}</code>. It names the declared secret, so the card masks it and asks for it; neither side
/// carries a value, because no read returns one and the new one is supplied at confirm. A read that
/// answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report the account its SMTP password belongs to, so no SMTP password is set for it"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
