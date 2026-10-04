/// <p>The ECP screens' codes (AD-39, Stories 18.20 and 18.21): every <code>ECP.*</code> code ECP data
/// servers, ECP settings and ECP application servers answer, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in
/// it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
/// <p><parameter>REASONLICENSE</parameter>, every settings refusal's sentence and the SSL/TLS
/// authorizations' two state refusals are published once in EXPERIENCE.md's Fixed strings and pinned
/// equal to the client's copies (<file>ui/tools/self-protection.test.mjs</file>).</p>
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

/// <p>Envelope code: an ECP settings write refused on one or more of its members, its
/// <code>detail.violations</code> naming each as <code>&lt;Object&gt;.&lt;member&gt;</code> (Story
/// 18.21).</p>
Parameter SETTINGSVALIDATION = "ECP.SETTINGS.VALIDATION";

Parameter REASONSETTINGSVALIDATION = "The ECP settings were refused.";

/// <p>Violation code: a maximum number of data servers or of application servers that is not a whole
/// number from 0 to 254, on <code>AppServerSettings.MaxServers</code> or
/// <code>DataServerSettings.MaxServerConn</code>.</p>
Parameter SETTINGSCOUNT = "ECP.SETTINGS.COUNT";

Parameter REASONSETTINGSCOUNT = "Enter a whole number from 0 to 254.";

/// <p>Violation code: a time to wait for recovery outside 10 to 65535 seconds, on
/// <code>AppServerSettings.ClientReconnectDuration</code>.</p>
Parameter SETTINGSRECOVERY = "ECP.SETTINGS.RECOVERY";

Parameter REASONSETTINGSRECOVERY = "Enter a whole number of seconds from 10 to 65535.";

/// <p>Violation code: a time between reconnections outside 1 to 60 seconds, on
/// <code>AppServerSettings.ClientReconnectInterval</code>.</p>
Parameter SETTINGSINTERVAL = "ECP.SETTINGS.INTERVAL";

Parameter REASONSETTINGSINTERVAL = "Enter a whole number of seconds from 1 to 60.";

/// <p>Violation code: a time interval for the Troubled state outside 20 to 65535 seconds, on
/// <code>DataServerSettings.ServerTroubleDuration</code>.</p>
Parameter SETTINGSTROUBLE = "ECP.SETTINGS.TROUBLE";

Parameter REASONSETTINGSTROUBLE = "Enter a whole number of seconds from 20 to 65535.";

/// <p>Violation code: an ECP SSL/TLS support other than 0, 1 or 2 (Disabled, Enabled, Required), on
/// <code>DataServerSettings.SSLECPServer</code>.</p>
Parameter SETTINGSSSLSHAPE = "ECP.SETTINGS.SSL.SHAPE";

Parameter REASONSETTINGSSSLSHAPE = "Choose Disabled, Enabled or Required.";

/// <p>Violation code: ECP SSL/TLS support 1 or 2 while the <code>%ECPServer</code> SSL/TLS configuration
/// is absent or disabled, on <code>DataServerSettings.SSLECPServer</code>, refused by
/// <class>OcuPilot.Port.EcpPort</class> before the settings <code>PUT</code>.</p>
Parameter SETTINGSSSLSERVER = "ECP.SETTINGS.SSLSERVER";

Parameter REASONSETTINGSSSLSERVER = "Create and enable the %ECPServer SSL/TLS configuration before using SSL/TLS.";

/// <p>Violation code: a maximum number of data servers below the number of data servers the instance
/// defines, on <code>AppServerSettings.MaxServers</code>, refused by <class>OcuPilot.Port.EcpPort</class>
/// before the settings <code>PUT</code>, where the vendor would refuse it (#456) after storing the other
/// members.</p>
Parameter SETTINGSSERVERS = "ECP.SETTINGS.SERVERS";

Parameter REASONSETTINGSSERVERS = "This instance defines more ECP data servers than that. Delete one first, or enter a larger number.";

/// <p>Consequence code: the write changes the maximum number of application servers, which the instance
/// applies only after it restarts; no field.</p>
Parameter SETTINGSRESTART = "ECP.SETTINGS.RESTART";

Parameter REASONSETTINGSRESTART = "A changed maximum number of application servers takes effect only after the instance restarts.";

/// <p>Consequence codes of the SSL/TLS authorization's authorize and reject.</p>
Parameter SSLAUTHORIZE = "ECP.SSL.AUTHORIZE";

Parameter REASONSSLAUTHORIZE = "Authorizing lets the application server that presents this certificate connect to this instance over ECP.";

Parameter SSLREJECT = "ECP.SSL.REJECT";

Parameter REASONSSLREJECT = "Rejecting refuses this application server's pending connection.";

/// <p>The SSL/TLS authorizations' two state refusals, each a tool's <code>StateDiff</code> problem
/// answered as 400 <code>TOOL.ARGUMENTS</code> with <code>detail.problem</code>, and each published once
/// and pinned equal to its self-protection rule's reason (<file>ui/tools/self-protection.test.mjs</file>):
/// authorize and reject need a row reading <code>Pending</code>, and delete one reading
/// <code>Authorized</code>.</p>
Parameter REASONSSLNOTPENDING = "This application server is not waiting for authorization.";

Parameter REASONSSLNOTAUTHORIZED = "This application server is not authorized.";

/// <p>Every <code>ECP.*</code> code, as a <class>%List</class>: the refusals, then Story 18.21's settings
/// refusals and its three consequences.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#LICENSE, ..#STATUSSAME, ..#STATUSREFUSED, ..#DATASERVERVALIDATION, ..#NAMESHAPE, ..#NAMETAKEN, ..#ADDRESS, ..#PORT, ..#MIRROR, ..#SSLCLIENT, ..#INUSE, ..#SERVERLIMIT, ..#SETTINGSVALIDATION, ..#SETTINGSCOUNT, ..#SETTINGSRECOVERY, ..#SETTINGSINTERVAL, ..#SETTINGSTROUBLE, ..#SETTINGSSSLSHAPE, ..#SETTINGSSSLSERVER, ..#SETTINGSSERVERS, ..#SETTINGSRESTART, ..#SSLAUTHORIZE, ..#SSLREJECT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#LICENSE, ..#STATUSSAME, ..#NAMESHAPE, ..#NAMETAKEN, ..#ADDRESS, ..#PORT, ..#MIRROR, ..#SSLCLIENT, ..#SETTINGSCOUNT, ..#SETTINGSRECOVERY, ..#SETTINGSINTERVAL, ..#SETTINGSTROUBLE, ..#SETTINGSSSLSHAPE, ..#SETTINGSSSLSERVER, ..#SETTINGSSERVERS)
}

/// <p>The field a violation code refuses, or <code>""</code>; <parameter>SETTINGSCOUNT</parameter>
/// answers its two fields, comma-separated.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#LICENSE) || (pCode = ..#STATUSSAME) Quit "Status"
    If (pCode = ..#NAMESHAPE) || (pCode = ..#NAMETAKEN) Quit "Name"
    If pCode = ..#ADDRESS Quit "Address"
    If pCode = ..#PORT Quit "Port"
    If pCode = ..#MIRROR Quit "MirrorConnection"
    If pCode = ..#SSLCLIENT Quit "SSLConfig"
    If pCode = ..#SETTINGSCOUNT Quit "AppServerSettings.MaxServers,DataServerSettings.MaxServerConn"
    If pCode = ..#SETTINGSRECOVERY Quit "AppServerSettings.ClientReconnectDuration"
    If pCode = ..#SETTINGSINTERVAL Quit "AppServerSettings.ClientReconnectInterval"
    If pCode = ..#SETTINGSTROUBLE Quit "DataServerSettings.ServerTroubleDuration"
    If (pCode = ..#SETTINGSSSLSHAPE) || (pCode = ..#SETTINGSSSLSERVER) Quit "DataServerSettings.SSLECPServer"
    If pCode = ..#SETTINGSSERVERS Quit "AppServerSettings.MaxServers"
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
    If pCode = ..#SETTINGSVALIDATION Quit ..#REASONSETTINGSVALIDATION
    If pCode = ..#SETTINGSCOUNT Quit ..#REASONSETTINGSCOUNT
    If pCode = ..#SETTINGSRECOVERY Quit ..#REASONSETTINGSRECOVERY
    If pCode = ..#SETTINGSINTERVAL Quit ..#REASONSETTINGSINTERVAL
    If pCode = ..#SETTINGSTROUBLE Quit ..#REASONSETTINGSTROUBLE
    If pCode = ..#SETTINGSSSLSHAPE Quit ..#REASONSETTINGSSSLSHAPE
    If pCode = ..#SETTINGSSSLSERVER Quit ..#REASONSETTINGSSSLSERVER
    If pCode = ..#SETTINGSSERVERS Quit ..#REASONSETTINGSSERVERS
    If pCode = ..#SETTINGSRESTART Quit ..#REASONSETTINGSRESTART
    If pCode = ..#SSLAUTHORIZE Quit ..#REASONSSLAUTHORIZE
    If pCode = ..#SSLREJECT Quit ..#REASONSSLREJECT
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
