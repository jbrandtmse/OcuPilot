/// <p>The LDAP / Kerberos list's search-password tool (AD-51, AD-56 (i)): propose setting one LDAP
/// configuration's search password. It reads the configuration fresh through the vendor's own
/// <code>Security.LDAP</code> <code>GET</code> and mints a proposal whose card asks for the password
/// at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's <code>CHANGEPWD</code>
/// request type takes exactly <code>{LDAPSearchPassword}</code> and sets only the password. The kernel
/// carries the secret as the descriptor's one declaration (<parameter>SECRETBODY</parameter>) and
/// supplies it at the write (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>); the
/// model can never supply it, because the tool admits no settable field and the mint refuses a
/// declared secret outright.</p>
/// <p><b>An empty value clears the password</b> (<parameter>CLEARABLESECRETS</parameter>): the
/// vendor's <code>CHANGEPWD</code> clears on <code>""</code> (measured). The card requires a value, so
/// clearing is the editor's; a confirm that sends <code>""</code> clears it as the user's own act.</p>
/// <p><b>Its fingerprint covers <code>LDAPSearchUsername</code></b>, the account the password belongs
/// to; the password is never part of it, and no read answers one. The editor's Save writes through
/// this tool's operation too (<method>OcuPilot.Area.Security.LdapSave.StorePassword</method>,
/// AD-55).</p>
Class OcuPilot.Screen.Tool.LdapPassword Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ldap.password";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LdapConfigList";

Parameter DESCRIPTION = "Propose setting a new search password for one LDAP configuration on this instance, the password of the user it searches the directory as. It changes nothing by itself: it answers a proposal the user reviews, and the user types the new password on the card when confirming. Never send a password: name the configuration exactly as the LDAP / Kerberos list reports it, and nothing else.";

/// <p>The vendor's own change-password request type.</p>
Parameter WRITETYPE = "CHANGEPWD";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The declared secret the write's body is made of, under the vendor's own key.</p>
Parameter SECRETBODY = "LDAPSearchPassword";

/// <p>The secret whose explicitly supplied empty value clears the stored one (AD-56 (i)).</p>
Parameter CLEARABLESECRETS = "LDAPSearchPassword";

/// <p>The card's one row is labelled <code>LDAPSearchPassword</code>, which names the secret the card
/// asks for rather than a field the payload carries (AD-10, AD-51).</p>
Parameter STATEFIELD = "LDAPSearchPassword";

/// <p>The read's names the subject names, which the list's own read does not answer.</p>
Parameter READANSWERS = "LDAPSearchUsername";

Parameter PRECONDITIONFIELD = "LDAPSearchUsername";

Parameter FINGERPRINTSUBJECT = "LDAPSearchUsername";

/// <p>The classic editor, whose password options this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.LDAP";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.LDAP"
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
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The LDAP configuration whose search password is to be set, exactly as this instance's own LDAP / Kerberos list reports it. The new password is typed by the user at confirmation and is never an argument.", "string")
    Quit tSchema
}

/// <p>The name's own rule (<method>OcuPilot.Area.Security.LdapRules.NameViolation</method>), as its
/// field and published sentence (AD-13, AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tViolations
    Set tViolations = 0
    Set tSC = ##class(OcuPilot.Area.Security.LdapRules).NameViolation(pIdValue, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.LdapRules).Problem(.tViolations)
    Quit $$$OK
}

/// <p>The name's own rule asked again at the agent's confirm (AD-6, AD-13): a stored name that
/// is gone by then can find another configuration by its short form, which the fingerprint's re-read
/// does not tell apart.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and the custom
/// resource of the <parameter>CLASSICPAGES</parameter> page, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field:
/// "LDAPSearchPassword", before: "", after: ""}</code>. It names the declared secret, so the card
/// masks it and asks for it; neither side carries a value, because no read returns one and the new
/// one is supplied at confirm. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report that configuration's search user, and a configuration whose search user is unknown is not one to set a password for"
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
