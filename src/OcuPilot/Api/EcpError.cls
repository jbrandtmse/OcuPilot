/// <p>The ECP screens' codes (AD-39, Story 18.20): every <code>ECP.*</code> code ECP data servers answer,
/// and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in
/// it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
/// <p><parameter>REASONLICENSE</parameter> is published once in EXPERIENCE.md's Fixed strings and pinned
/// equal to the client's copy (<file>ui/tools/self-protection.test.mjs</file>).</p>
Class OcuPilot.Api.EcpError Extends %RegisteredObject
{

/// <p>Violation and envelope code: Normal was chosen on an instance whose license enables no ECP, on
/// <code>Status</code>. Rendered with 422 by <class>OcuPilot.Port.EcpPort</class> before any vendor
/// call.</p>
Parameter LICENSE = "ECP.LICENSE";

Parameter REASONLICENSE = "This instance's license does not include ECP.";

/// <p>Violation and envelope code: the status chosen is the data server's current one, on
/// <code>Status</code>, with nothing queued.</p>
Parameter STATUSSAME = "ECP.STATUS.SAME";

Parameter REASONSTATUSSAME = "The data server already has that status.";

/// <p>Envelope code: the instance's queued status change failed, rendered with 409; the vendor's own
/// reason is logged and never carried.</p>
Parameter STATUSREFUSED = "ECP.STATUS.REFUSED";

Parameter REASONSTATUSREFUSED = "The instance refused that status change.";

/// <p>Envelope code: a data server write refused on one or more of its fields, its
/// <code>detail.violations</code> naming each.</p>
Parameter DATASERVERVALIDATION = "ECP.DATASERVER.VALIDATION";

Parameter REASONDATASERVERVALIDATION = "The ECP data server was refused.";

/// <p>Violation code: a data server name outside
/// <parameter>OcuPilot.Area.OsMgmt.EcpRules.NAMEPATTERN</parameter>, on <code>Name</code>.</p>
Parameter NAMESHAPE = "ECP.DATASERVER.NAME.SHAPE";

Parameter REASONNAMESHAPE = "Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit.";

/// <p>Violation code: the instance already defines a data server of that name in any case, on
/// <code>Name</code>.</p>
Parameter NAMETAKEN = "ECP.DATASERVER.NAME.TAKEN";

Parameter REASONNAMETAKEN = "An ECP data server of that name already exists.";

/// <p>Violation code: an address <class>Config.Host</class> would not store, on
/// <code>Address</code>.</p>
Parameter ADDRESS = "ECP.DATASERVER.ADDRESS";

Parameter REASONADDRESS = "Enter the data server's host name or IP address.";

/// <p>Violation code: a port that is not a whole number from 1 to 65535, on <code>Port</code>.</p>
Parameter PORT = "ECP.DATASERVER.PORT";

Parameter REASONPORT = "Enter a port from 1 to 65535.";

/// <p>Violation code: a mirror connection other than 0 or 1, or a change to a stored non-zero one, on
/// <code>MirrorConnection</code>.</p>
Parameter MIRROR = "ECP.DATASERVER.MIRROR";

Parameter REASONMIRROR = "A data server's mirror connection cannot be turned off once it is set.";

/// <p>Violation code: SSL/TLS chosen while the instance holds no <code>%ECPClient</code> SSL/TLS
/// configuration, on <code>SSLConfig</code>; the vendor's own refusal (#1454) answered on the field.</p>
Parameter SSLCLIENT = "ECP.DATASERVER.SSLCLIENT";

Parameter REASONSSLCLIENT = "Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS.";

/// <p>Envelope code: the delete was refused because remote databases use the data server (the vendor's
/// 409, #423), rendered with 409.</p>
Parameter INUSE = "ECP.DATASERVER.INUSE";

Parameter REASONINUSE = "Remote databases use this data server. Delete them or move them to another data server first.";

/// <p>Envelope code: a create refused with 409 because the configured data servers already reach
/// <code>ECP.Settings</code>' <code>AppServerSettings.MaxServers</code>, by
/// <class>OcuPilot.Port.EcpPort</class>'s check or by the vendor's own refusal (#456). The sentence
/// names the limit (<method>Limit</method>).</p>
Parameter SERVERLIMIT = "ECP.SERVER.LIMIT";

Parameter REASONSERVERLIMIT = "This instance allows no more ECP data servers. Delete one, or raise the limit in ECP settings, first.";

/// <p>Every <code>ECP.*</code> refusal code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#LICENSE, ..#STATUSSAME, ..#STATUSREFUSED, ..#DATASERVERVALIDATION, ..#NAMESHAPE, ..#NAMETAKEN, ..#ADDRESS, ..#PORT, ..#MIRROR, ..#SSLCLIENT, ..#INUSE, ..#SERVERLIMIT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#LICENSE, ..#STATUSSAME, ..#NAMESHAPE, ..#NAMETAKEN, ..#ADDRESS, ..#PORT, ..#MIRROR, ..#SSLCLIENT)
}

/// <p>The field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#LICENSE) || (pCode = ..#STATUSSAME) Quit "Status"
    If (pCode = ..#NAMESHAPE) || (pCode = ..#NAMETAKEN) Quit "Name"
    If pCode = ..#ADDRESS Quit "Address"
    If pCode = ..#PORT Quit "Port"
    If pCode = ..#MIRROR Quit "MirrorConnection"
    If pCode = ..#SSLCLIENT Quit "SSLConfig"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#LICENSE Quit ..#REASONLICENSE
    If pCode = ..#STATUSSAME Quit ..#REASONSTATUSSAME
    If pCode = ..#STATUSREFUSED Quit ..#REASONSTATUSREFUSED
    If pCode = ..#DATASERVERVALIDATION Quit ..#REASONDATASERVERVALIDATION
    If pCode = ..#NAMESHAPE Quit ..#REASONNAMESHAPE
    If pCode = ..#NAMETAKEN Quit ..#REASONNAMETAKEN
    If pCode = ..#ADDRESS Quit ..#REASONADDRESS
    If pCode = ..#PORT Quit ..#REASONPORT
    If pCode = ..#MIRROR Quit ..#REASONMIRROR
    If pCode = ..#SSLCLIENT Quit ..#REASONSSLCLIENT
    If pCode = ..#INUSE Quit ..#REASONINUSE
    If pCode = ..#SERVERLIMIT Quit ..#REASONSERVERLIMIT
    Quit ""
}

/// <p><parameter>REASONSERVERLIMIT</parameter>'s refusal naming the limit <var>pMaximum</var>: the
/// instance's own <code>AppServerSettings.MaxServers</code>, or, for a caller who cannot read it, the
/// number of data servers the instance defines.</p>
ClassMethod Limit(pMaximum As %Integer) As %String
{
    Quit "This instance allows at most " _ (+pMaximum) _ " ECP data server" _ $Select(+pMaximum = 1: "", 1: "s") _ ". Delete one, or raise the limit in ECP settings, first."
}

}
