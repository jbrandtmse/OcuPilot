/// <p>The authentication options' codes (AD-39, Story 18.8): every <code>WEBAUTH.*</code> code the
/// authentication and web session options screen, <code>security.authoptions.update</code> and
/// <code>security.authoptions.smtppassword</code> answer, and the one sentence each carries. They live
/// beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's
/// limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a password or any part of a caller's input (AD-35).</p>
Class OcuPilot.Api.WebAuthError Extends %RegisteredObject
{

/// <p>Envelope code: the options were refused on one or more of their fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter VALIDATION = "WEBAUTH.VALIDATION";

Parameter REASONVALIDATION = "The authentication options were refused.";

/// <p>Violation code: Always try Delegated authentication on while Delegated authentication is off, on
/// <code>AutheAlwaysTryDelegated</code>.</p>
Parameter DELEGATED = "WEBAUTH.DELEGATED.REQUIRED";

Parameter REASONDELEGATED = "Always try Delegated authentication needs Delegated authentication turned on.";

/// <p>Violation code: LDAP cache credentials on while neither LDAP nor O/S authentication with LDAP
/// authorization is on, on <code>AutheLDAPCache</code>.</p>
Parameter LDAPCACHE = "WEBAUTH.LDAPCACHE.REQUIRED";

Parameter REASONLDAPCACHE = "LDAP cache credentials need LDAP authentication, or O/S authentication with LDAP authorization, turned on.";

/// <p>Violation codes: two-factor SMS text authentication on with no SMTP server, on
/// <code>SMTPServer</code>, or no from address, on <code>TwoFactorFrom</code>.</p>
Parameter SMSSERVER = "WEBAUTH.SMS.SERVER";

Parameter REASONSMSSERVER = "Two-factor SMS text authentication needs the DNS name of an SMTP server.";

Parameter SMSFROM = "WEBAUTH.SMS.FROM";

Parameter REASONSMSFROM = "Two-factor SMS text authentication needs a from address.";

/// <p>Violation codes: a timeout that is not a whole number of seconds, 0 or more, on
/// <code>LoginCookieTimeout</code> and on <code>TwoFactorTimeout</code>.</p>
Parameter COOKIETIMEOUT = "WEBAUTH.COOKIETIMEOUT";

Parameter REASONCOOKIETIMEOUT = "The login cookie expire time is a whole number of seconds, 0 or more.";

Parameter TWOFACTORTIMEOUT = "WEBAUTH.TWOFACTORTIMEOUT";

Parameter REASONTWOFACTORTIMEOUT = "The two-factor timeout is a whole number of seconds, 0 or more.";

/// <p>Violation code: a JWT signature algorithm outside the six the instance offers, on
/// <code>JWTSigAlg</code>.</p>
Parameter JWTSIGALG = "WEBAUTH.JWTSIGALG";

Parameter REASONJWTSIGALG = "The JWT signature algorithm is one of RS256, RS384, RS512, ES256, ES384 or ES512.";

/// <p>Violation code: a JWT issuer longer than 1,024 characters, on <code>JWTIssuer</code>.</p>
Parameter JWTISSUER = "WEBAUTH.JWTISSUER.LENGTH";

Parameter REASONJWTISSUER = "The JWT issuer is at most 1,024 characters.";

/// <p>Consequence code of a changed <code>JWTIssuer</code> or <code>JWTSigAlg</code>, which
/// <class>OcuPilot.Kernel.Proposal.Mint</class> stores and the card renders. The sentence is published
/// in EXPERIENCE.md's Fixed strings and pinned equal to <code>webAuthSignOutConsequence</code> by
/// <file>ui/tools/proposal-view.test.mjs</file>.</p>
Parameter SIGNOUT = "WEBAUTH.SIGNOUT";

Parameter REASONSIGNOUT = "Every session signed in with a token ends, every OcuPilot tab included, and each must sign in again. A new signature algorithm also replaces the instance's signing keys.";

/// <p>The JWT signature algorithms the instance offers, as the classic page lists them.</p>
Parameter SIGALGS = "RS256,RS384,RS512,ES256,ES384,ES512";

/// <p>The longest JWT issuer accepted.</p>
Parameter ISSUERMAX = 1024;

/// <p>Every <code>WEBAUTH.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#DELEGATED, ..#LDAPCACHE, ..#SMSSERVER, ..#SMSFROM, ..#COOKIETIMEOUT, ..#TWOFACTORTIMEOUT, ..#JWTSIGALG, ..#JWTISSUER, ..#SIGNOUT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#DELEGATED, ..#LDAPCACHE, ..#SMSSERVER, ..#SMSFROM, ..#COOKIETIMEOUT, ..#TWOFACTORTIMEOUT, ..#JWTSIGALG, ..#JWTISSUER)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If pCode = ..#DELEGATED Quit "AutheAlwaysTryDelegated"
    If pCode = ..#LDAPCACHE Quit "AutheLDAPCache"
    If pCode = ..#SMSSERVER Quit "SMTPServer"
    If pCode = ..#SMSFROM Quit "TwoFactorFrom"
    If pCode = ..#COOKIETIMEOUT Quit "LoginCookieTimeout"
    If pCode = ..#TWOFACTORTIMEOUT Quit "TwoFactorTimeout"
    If pCode = ..#JWTSIGALG Quit "JWTSigAlg"
    If pCode = ..#JWTISSUER Quit "JWTIssuer"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#DELEGATED Quit ..#REASONDELEGATED
    If pCode = ..#LDAPCACHE Quit ..#REASONLDAPCACHE
    If pCode = ..#SMSSERVER Quit ..#REASONSMSSERVER
    If pCode = ..#SMSFROM Quit ..#REASONSMSFROM
    If pCode = ..#COOKIETIMEOUT Quit ..#REASONCOOKIETIMEOUT
    If pCode = ..#TWOFACTORTIMEOUT Quit ..#REASONTWOFACTORTIMEOUT
    If pCode = ..#JWTSIGALG Quit ..#REASONJWTSIGALG
    If pCode = ..#JWTISSUER Quit ..#REASONJWTISSUER
    If pCode = ..#SIGNOUT Quit ..#REASONSIGNOUT
    Quit ""
}

}
