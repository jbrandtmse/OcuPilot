/// <p>The licensing screens' codes (AD-39, Story 18.6): every <code>LICENSE.*</code> code License key
/// and License servers answer, and the one sentence each carries. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit
/// of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
Class OcuPilot.Api.LicenseError Extends %RegisteredObject
{

/// <p>Violation and envelope code: no key text was given. Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422, on <code>Key</code>, by
/// <class>OcuPilot.Port.LicensePort</class> before any vendor call.</p>
Parameter KEYEMPTY = "LICENSE.KEY.EMPTY";

Parameter REASONKEYEMPTY = "Paste the license key's text or load it from its file.";

/// <p>Violation and envelope code: the text is not a valid license key for this instance, or is
/// longer than <parameter>OcuPilot.Port.LicensePort.KEYMAXLENGTH</parameter>. Rendered with 422 on
/// <code>Key</code>; the vendor's own reason is never carried.</p>
Parameter KEYINVALID = "LICENSE.KEY.INVALID";

Parameter REASONKEYINVALID = "This is not a valid license key for this instance.";

/// <p>Envelope code: a license server write refused on one or more of its fields, its
/// <code>detail.violations</code> naming each.</p>
Parameter SERVERVALIDATION = "LICENSE.SERVER.VALIDATION";

Parameter REASONSERVERVALIDATION = "The license server was refused.";

/// <p>Violation code: a license server name outside
/// <parameter>OcuPilot.Area.OsMgmt.LicenseRules.NAMEPATTERN</parameter>, on <code>Name</code>.</p>
Parameter SERVERNAMESHAPE = "LICENSE.SERVER.NAME.SHAPE";

Parameter REASONSERVERNAMESHAPE = "Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit.";

/// <p>Violation code: the instance already defines a license server of that name in any case, on
/// <code>Name</code>.</p>
Parameter SERVERNAMETAKEN = "LICENSE.SERVER.NAME.TAKEN";

Parameter REASONSERVERNAMETAKEN = "A license server of that name already exists.";

/// <p>Violation code: an empty address, or one longer than 256 characters, on
/// <code>Address</code>.</p>
Parameter SERVERADDRESS = "LICENSE.SERVER.ADDRESS";

Parameter REASONSERVERADDRESS = "Enter the license server's host name or IP address.";

/// <p>Violation code: a port that is not a whole number from 1 to 65535, on <code>Port</code>.</p>
Parameter SERVERPORT = "LICENSE.SERVER.PORT";

Parameter REASONSERVERPORT = "Enter a port from 1 to 65535.";

/// <p>Every <code>LICENSE.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#KEYEMPTY, ..#KEYINVALID, ..#SERVERVALIDATION, ..#SERVERNAMESHAPE, ..#SERVERNAMETAKEN, ..#SERVERADDRESS, ..#SERVERPORT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#KEYEMPTY, ..#KEYINVALID, ..#SERVERNAMESHAPE, ..#SERVERNAMETAKEN, ..#SERVERADDRESS, ..#SERVERPORT)
}

/// <p>The field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#KEYEMPTY) || (pCode = ..#KEYINVALID) Quit "Key"
    If (pCode = ..#SERVERNAMESHAPE) || (pCode = ..#SERVERNAMETAKEN) Quit "Name"
    If pCode = ..#SERVERADDRESS Quit "Address"
    If pCode = ..#SERVERPORT Quit "Port"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#KEYEMPTY Quit ..#REASONKEYEMPTY
    If pCode = ..#KEYINVALID Quit ..#REASONKEYINVALID
    If pCode = ..#SERVERVALIDATION Quit ..#REASONSERVERVALIDATION
    If pCode = ..#SERVERNAMESHAPE Quit ..#REASONSERVERNAMESHAPE
    If pCode = ..#SERVERNAMETAKEN Quit ..#REASONSERVERNAMETAKEN
    If pCode = ..#SERVERADDRESS Quit ..#REASONSERVERADDRESS
    If pCode = ..#SERVERPORT Quit ..#REASONSERVERPORT
    Quit ""
}

}
