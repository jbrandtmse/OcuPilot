/// <p>The provider connection's codes (AD-32, AD-39, AD-42, Story 18.40): every <code>EGRESS.*</code> violation code
/// <code>PUT /agent/switches/egress</code> answers on a field, and the one sentence each carries. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForViolation</method> answers these codes through
/// <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.EgressError Extends %RegisteredObject
{

/// <p>Violation code (422): <code>proxyServer</code> is not a bare host name, IPv4 address or IPv6 address of at most
/// <parameter>HOSTMAX</parameter> characters. Nothing is stored.</p>
Parameter PROXYHOST = "EGRESS.PROXYHOST";

Parameter REASONPROXYHOST = "The proxy is a host name or an IP address on its own, with no scheme, path, port, user name or space, in at most 253 characters.";

/// <p>Violation code (422): <code>proxyPort</code> is absent or outside 1 to 65535 while a proxy is named. Nothing is
/// stored.</p>
Parameter PROXYPORT = "EGRESS.PROXYPORT";

Parameter REASONPROXYPORT = "The proxy's port is a whole number from 1 to 65535.";

/// <p>Violation code (422): <code>proxyServer</code> resolves to a loopback or link-local address or to this instance.
/// Nothing is stored.</p>
Parameter PROXYADDRESS = "EGRESS.PROXYADDRESS";

Parameter REASONPROXYADDRESS = "That proxy resolves to a loopback or link-local address or to this instance, which provider calls will not go through.";

/// <p>Violation code (422): <code>sslConfiguration</code> names a configuration the instance does not hold. Nothing is
/// stored.</p>
Parameter SSLABSENT = "EGRESS.SSLABSENT";

Parameter REASONSSLABSENT = "No SSL/TLS configuration of that name exists on this instance.";

/// <p>Violation code (422): <code>sslConfiguration</code> names a configuration that is a server, is disabled, or does
/// not require the server's certificate. Nothing is stored.</p>
Parameter SSLUNVERIFIED = "EGRESS.SSLUNVERIFIED";

Parameter REASONSSLUNVERIFIED = "Provider calls need an enabled client configuration that requires the server's certificate.";

/// <p>The longest proxy host stored, in characters.</p>
Parameter HOSTMAX = 253;

/// <p>Every <code>EGRESS.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#PROXYHOST, ..#PROXYPORT, ..#PROXYADDRESS, ..#SSLABSENT, ..#SSLUNVERIFIED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#PROXYHOST Quit ..#REASONPROXYHOST
    If pCode = ..#PROXYPORT Quit ..#REASONPROXYPORT
    If pCode = ..#PROXYADDRESS Quit ..#REASONPROXYADDRESS
    If pCode = ..#SSLABSENT Quit ..#REASONSSLABSENT
    If pCode = ..#SSLUNVERIFIED Quit ..#REASONSSLUNVERIFIED
    Quit ""
}

}
