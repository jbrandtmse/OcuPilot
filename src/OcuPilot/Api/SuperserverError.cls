/// <p>The superservers' codes (AD-39, Story 18.25): every <code>SUPERSERVER.*</code> code the Superservers
/// screens, <code>security.superservers.create</code>, <code>.update</code> and <code>.delete</code> answer, and
/// the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it because
/// that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35).</p>
Class OcuPilot.Api.SuperserverError Extends %RegisteredObject
{

/// <p>Envelope code: the superserver was refused on one or more of its fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter VALIDATION = "SUPERSERVER.VALIDATION";

Parameter REASONVALIDATION = "The superserver was refused.";

/// <p>Violation code: a port that is not a whole number from 100 to 65535, on <code>Port</code>.</p>
Parameter PORT = "SUPERSERVER.PORT";

Parameter REASONPORT = "The port is a whole number from 100 to 65535.";

/// <p>Violation code: a superserver already exists on that port and address, on <code>Port</code>.</p>
Parameter TAKEN = "SUPERSERVER.TAKEN";

Parameter REASONTAKEN = "A superserver already exists on that port and address.";

/// <p>Violation code: a description over 256 characters, on <code>Description</code>.</p>
Parameter DESCRIPTION = "SUPERSERVER.DESCRIPTION.LENGTH";

Parameter REASONDESCRIPTION = "The description is at most 256 characters.";

/// <p>Violation code: an SSL/TLS support level other than 0, 1 or 2, on <code>SSLSupportLevel</code>.</p>
Parameter SSLLEVEL = "SUPERSERVER.SSLLEVEL";

Parameter REASONSSLLEVEL = "The SSL/TLS support level is 0 (disabled), 1 (enabled) or 2 (required).";

/// <p>Violation code, on <code>SSLConfig</code>: a level of 1 or 2 with no SSL/TLS configuration named, or a
/// configuration that does not exist or is not a server configuration.</p>
Parameter SSLCONFIG = "SUPERSERVER.SSLCONFIG";

Parameter REASONSSLCONFIG = "SSL/TLS support level 1 or 2 needs an SSL/TLS configuration that exists and is a server configuration.";

/// <p>Violation code: ECP, mirroring or sharding turned on for a superserver that is not the system default,
/// on <code>EnableECP</code>, <code>EnableMirror</code> or <code>EnableSharding</code>.</p>
Parameter SYSTEMONLY = "SUPERSERVER.SYSTEMONLY";

Parameter REASONSYSTEMONLY = "ECP, mirroring and sharding can be turned on for the system default superserver only.";

/// <p>Violation code: SNMP turned on where the instance does not run on Windows, on <code>EnableSNMP</code>.</p>
Parameter SNMP = "SUPERSERVER.SNMP.PLATFORM";

Parameter REASONSNMP = "SNMP is available on Windows only.";

/// <p>Refusal code (409), on <code>Port</code>: a write that would start a listener on a port another process
/// holds. Nothing is stored.</p>
Parameter INUSE = "SUPERSERVER.PORT.INUSE";

Parameter REASONINUSE = "Another process on this server is already listening on that port.";

/// <p>Consequence code of an SSL/TLS change to a superserver OcuPilot is served through, which
/// <class>OcuPilot.Kernel.Proposal.Mint</class> stores and the card renders. The sentence is published in
/// EXPERIENCE.md's Fixed strings and pinned equal to <code>superserverServesConsequence</code> by
/// <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter SERVESOCUPILOT = "SUPERSERVER.SERVESOCUPILOT";

Parameter REASONSERVESOCUPILOT = "OcuPilot is served through this superserver. An SSL/TLS change can stop the web gateway connecting through it, which would cut off every user, including you.";

/// <p>The lowest and highest port a superserver takes.</p>
Parameter PORTMIN = 100;

Parameter PORTMAX = 65535;

/// <p>The longest description accepted.</p>
Parameter DESCRIPTIONMAX = 256;

/// <p>Every <code>SUPERSERVER.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#PORT, ..#TAKEN, ..#DESCRIPTION, ..#SSLLEVEL, ..#SSLCONFIG, ..#SYSTEMONLY, ..#SNMP, ..#INUSE, ..#SERVESOCUPILOT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#PORT, ..#TAKEN, ..#DESCRIPTION, ..#SSLLEVEL, ..#SSLCONFIG, ..#SYSTEMONLY, ..#SNMP, ..#INUSE)
}

/// <p>The form field a violation code refuses, or <code>""</code>. <parameter>SYSTEMONLY</parameter> names
/// three fields, so it answers none here: its field is the one the rule found.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#PORT) || (pCode = ..#TAKEN) || (pCode = ..#INUSE) Quit "Port"
    If pCode = ..#DESCRIPTION Quit "Description"
    If pCode = ..#SSLLEVEL Quit "SSLSupportLevel"
    If pCode = ..#SSLCONFIG Quit "SSLConfig"
    If pCode = ..#SNMP Quit "EnableSNMP"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#PORT Quit ..#REASONPORT
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    If pCode = ..#DESCRIPTION Quit ..#REASONDESCRIPTION
    If pCode = ..#SSLLEVEL Quit ..#REASONSSLLEVEL
    If pCode = ..#SSLCONFIG Quit ..#REASONSSLCONFIG
    If pCode = ..#SYSTEMONLY Quit ..#REASONSYSTEMONLY
    If pCode = ..#SNMP Quit ..#REASONSNMP
    If pCode = ..#INUSE Quit ..#REASONINUSE
    If pCode = ..#SERVESOCUPILOT Quit ..#REASONSERVESOCUPILOT
    Quit ""
}

}
