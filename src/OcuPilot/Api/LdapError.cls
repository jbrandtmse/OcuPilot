/// <p>The LDAP and Kerberos editor's codes (AD-39, Story 16.14): every <code>LDAP.*</code> code the
/// editor, its tools and its test route add to Story 9.9's, and the one sentence each carries. They
/// live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290), as <class>OcuPilot.Api.ServiceError</class>
/// does; <method>OcuPilot.Api.Error.ReasonForLdap</method> answers these codes through
/// <method>ReasonFor</method> and <method>OcuPilot.Api.Error.LdapViolationCodes</method> lists them,
/// so every caller still asks the one writer.</p>
Class OcuPilot.Api.LdapError Extends %RegisteredObject
{

/// <p>Violation code: <code>LDAPFlags</code> carrying both 64 (enabled) and 128 (Kerberos only),
/// which the instance stores as 128 alone (measured).</p>
Parameter FLAGSKERBEROS = "LDAP.FLAGS.KERBEROS";

Parameter REASONFLAGSKERBEROS = "A Kerberos-only configuration cannot also be LDAP enabled.";

/// <p>Violation code: a configuration name that <code>Security.LDAPConfigs.FormatName</code> would
/// store differently other than by case -- a bare name, which gains <code>.com</code>, or one
/// carrying a character it strips. A name this instance already holds is admitted as stored for a
/// read, a change, a test or a delete; on a create such a name is always refused.</p>
Parameter NAMEFORM = "LDAP.NAME.FORM";

Parameter REASONNAMEFORM = "Use the full name the instance stores, such as example.com.";

/// <p>Violation code: a create whose name this instance already holds.</p>
Parameter NAMETAKEN = "LDAP.NAME.TAKEN";

Parameter REASONNAMETAKEN = "An LDAP configuration with this name already exists.";

/// <p>Violation code: no host name on a configuration that is not Kerberos-only, which the vendor
/// refuses late (#1482, measured).</p>
Parameter HOSTREQUIRED = "LDAP.HOST.REQUIRED";

Parameter REASONHOSTREQUIRED = "Enter at least one host name.";

/// <p>Violation code: a test of authentication with no user name or no password.</p>
Parameter TESTREQUIRED = "LDAP.TEST.REQUIRED";

Parameter REASONTESTREQUIRED = "Enter a user name and a password to test with.";

/// <p>Violation code: a test user name carrying <code>@</code>. The vendor's test picks the
/// configuration by the domain after <code>@</code>, and the route supplies this configuration's.</p>
Parameter TESTUSERNAME = "LDAP.TEST.USERNAME";

Parameter REASONTESTUSERNAME = "Enter the user name without a domain; the test uses this configuration.";

/// <p>Violation code: an edit that would leave <code>LDAPAttributes</code> holding no name while the
/// configuration holds one. The vendor's <code>PUT</code> keeps the stored list when sent an empty
/// one and fails on a list of empty names, while the classic page's own save,
/// <code>Security.LDAPConfigs.Modify</code> with an empty list, clears it (each measured), so the
/// edit is refused before any write.</p>
Parameter ATTRIBUTESLASTONE = "LDAP.ATTRIBUTES.LASTONE";

Parameter REASONATTRIBUTESLASTONE = "Keep at least one attribute to retrieve; the last one can be removed only on the classic portal.";

/// <p>Every code this class declares, as a <class>%List</class>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#FLAGSKERBEROS, ..#NAMEFORM, ..#NAMETAKEN, ..#HOSTREQUIRED, ..#TESTREQUIRED, ..#TESTUSERNAME, ..#ATTRIBUTESLASTONE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#FLAGSKERBEROS Quit ..#REASONFLAGSKERBEROS
    If pCode = ..#NAMEFORM Quit ..#REASONNAMEFORM
    If pCode = ..#NAMETAKEN Quit ..#REASONNAMETAKEN
    If pCode = ..#HOSTREQUIRED Quit ..#REASONHOSTREQUIRED
    If pCode = ..#TESTREQUIRED Quit ..#REASONTESTREQUIRED
    If pCode = ..#TESTUSERNAME Quit ..#REASONTESTUSERNAME
    If pCode = ..#ATTRIBUTESLASTONE Quit ..#REASONATTRIBUTESLASTONE
    Quit ""
}

}
