/// <p>The managed file transfer connections' codes (AD-39, Story 18.26): every <code>MFT.*</code> code the
/// Managed file transfer screens and <code>security.mftconnections.create</code>, <code>.update</code>,
/// <code>.delete</code> and <code>.revoketoken</code> answer, and the one sentence each carries. They live
/// beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of
/// 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35).</p>
Class OcuPilot.Api.MftConnectionError Extends %RegisteredObject
{

/// <p>Envelope code: the connection was refused on one or more of its fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter VALIDATION = "MFT.VALIDATION";

Parameter REASONVALIDATION = "The connection was refused.";

/// <p>Violation code: a name that is empty, over 64 characters or holds a control character, on
/// <code>Name</code>.</p>
Parameter NAME = "MFT.NAME";

Parameter REASONNAME = "The name is 1 to 64 characters with no control character.";

/// <p>Violation code: a connection already exists under that name, on <code>Name</code>.</p>
Parameter TAKEN = "MFT.TAKEN";

Parameter REASONTAKEN = "A connection with that name already exists.";

/// <p>Violation code: a service other than Box, Dropbox or Kiteworks, on <code>Service</code>.</p>
Parameter SERVICE = "MFT.SERVICE";

Parameter REASONSERVICE = "The service is Box, Dropbox or Kiteworks.";

/// <p>Violation code: a URL that is not an absolute http or https URL ending in a slash, or is over 1024
/// characters, on <code>URL</code>.</p>
Parameter URL = "MFT.URL";

Parameter REASONURL = "The URL is an absolute http or https URL ending in /, at most 1024 characters.";

/// <p>Violation code: an SSL/TLS configuration that is absent or is not a client configuration, on
/// <code>SSLConfiguration</code>.</p>
Parameter SSLCONFIG = "MFT.SSLCONFIG";

Parameter REASONSSLCONFIG = "The SSL/TLS configuration must exist and be a client configuration.";

/// <p>Violation code: an email address that is empty or over 160 characters, on <code>Username</code>.</p>
Parameter USERNAME = "MFT.USERNAME";

Parameter REASONUSERNAME = "The email address is 1 to 160 characters.";

/// <p>Violation code: an OAuth 2.0 client configuration name that is empty or over 64 characters, on
/// <code>ApplicationName</code>.</p>
Parameter APPLICATIONNAME = "MFT.APPLICATIONNAME";

Parameter REASONAPPLICATIONNAME = "The OAuth 2.0 client configuration name is 1 to 64 characters.";

/// <p>Refusal code (409): the connection holds no access token to revoke. The revoke's fresh read answers
/// it, so nothing is minted or sent, and a confirm reads it as the target having moved.</p>
Parameter TOKENNONE = "MFT.TOKEN.NONE";

Parameter REASONTOKENNONE = "This connection holds no access token to revoke.";

/// <p>The longest connection name, OAuth 2.0 client configuration name, address and URL the instance
/// stores.</p>
Parameter NAMEMAX = 64;

Parameter APPLICATIONNAMEMAX = 64;

Parameter USERNAMEMAX = 160;

Parameter URLMAX = 1024;

/// <p>Every <code>MFT.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAME, ..#TAKEN, ..#SERVICE, ..#URL, ..#SSLCONFIG, ..#USERNAME, ..#APPLICATIONNAME, ..#TOKENNONE)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAME, ..#TAKEN, ..#SERVICE, ..#URL, ..#SSLCONFIG, ..#USERNAME, ..#APPLICATIONNAME)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#NAME) || (pCode = ..#TAKEN) Quit "Name"
    If pCode = ..#SERVICE Quit "Service"
    If pCode = ..#URL Quit "URL"
    If pCode = ..#SSLCONFIG Quit "SSLConfiguration"
    If pCode = ..#USERNAME Quit "Username"
    If pCode = ..#APPLICATIONNAME Quit "ApplicationName"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAME Quit ..#REASONNAME
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    If pCode = ..#SERVICE Quit ..#REASONSERVICE
    If pCode = ..#URL Quit ..#REASONURL
    If pCode = ..#SSLCONFIG Quit ..#REASONSSLCONFIG
    If pCode = ..#USERNAME Quit ..#REASONUSERNAME
    If pCode = ..#APPLICATIONNAME Quit ..#REASONAPPLICATIONNAME
    If pCode = ..#TOKENNONE Quit ..#REASONTOKENNONE
    Quit ""
}

}
