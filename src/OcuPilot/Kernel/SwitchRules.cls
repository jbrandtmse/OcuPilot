/// <p>The rules that keep the agent switches and the per-user holds honest, applied in one pass that
/// <b>accumulates every violation</b> rather than stopping at the first -- the shape
/// <class>OcuPilot.Kernel.AgentRules</class> established, and for the same reason: an operator
/// filling in a form is told everything that is wrong with it at once.</p>
/// <p>Each violation is <code>{field, code, reason}</code> -- the field it lands on, a stable
/// machine code declared in <class>OcuPilot.Api.Error</class>, and that code's written sentence from
/// the same class (AD-39). Rendering them is
/// <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method>, which resolves a sentence by code,
/// so there is one violation renderer rather than two.</p>
/// <p><b>Not under <package>OcuPilot.Kernel.State</package></b>: that package may not name
/// <class>OcuPilot.Api.Error</class>, and this class needs its code vocabulary. It sits beside
/// <class>OcuPilot.Kernel.AgentRules</class>, which makes the same reference for the same
/// reason.</p>
Class OcuPilot.Kernel.SwitchRules Extends %RegisteredObject
{

/// <p>The longest kill-switch reason either surface stores, matching both properties' own
/// <code>MAXLEN</code>.</p>
Parameter MAXREASONLENGTH As %Integer = 512;

/// <p>The longest user name a hold may carry, matching
/// <property>OcuPilot.Kernel.State.Hold.UserName</property>'s own <code>MAXLEN</code>.</p>
Parameter MAXUSERNAMELENGTH As %Integer = 160;

/// <p>Every violation the instance-wide switch values <var>pValues</var> commit, appended to
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>; returns how
/// many.</p>
/// <p><b>The kill switch may not be on without a reason.</b> The published banner carries the
/// operator's reason in front of everyone it affects, so a switch with none would leave a sentence
/// with a hole in it. Turning the switch off leaves the reason alone -- it is history at that
/// point, not a claim.</p>
/// <p><b>The length rule applies whichever way the switch is set</b>, because it is the column's
/// limit rather than the banner's: a reason longer than <parameter>MAXREASONLENGTH</parameter>
/// fails <method>%Save</method> on the datatype, so a rule that skipped it while the switch was off
/// would answer 500 where every other bad field on this surface answers 422.</p>
/// <p><b>The row cap must be a whole number from 1 to 1,000</b> (Story 4.4, AD-24): the bound a
/// turn's screen context and every read tool result are cut to.
/// <method>OcuPilot.Api.Switches.MergeBody</method> turns a value that is not a JSON number into
/// <code>""</code>, which this rule refuses on the field.</p>
/// <p><b>Turns an hour must be a whole number from 0 to 10,000</b> (Story 14.6, AD-41), where 0 is
/// no limit, and <b>turns running at once must be <class>OcuPilot.Kernel.Agent.Limits</class>'s
/// <code>CONCURRENTTURNS</code></b>, 1: <code>concurrentTurns</code> is carried
/// only for this rule and is never stored. Each applies only when its value is present.</p>
ClassMethod ValidateSwitches(ByRef pValues, Output pViolations) As %Integer
{
    Kill pViolations
    Set tReason = $Get(pValues("killSwitchReason"))
    If (''+$Get(pValues("killSwitch")) && ($ZStrip(tReason, "<>W") = "")) || ($Length(tReason) > ..#MAXREASONLENGTH) {
        Do ..Add(.pViolations, "killSwitchReason", ##class(OcuPilot.Api.Error).#AGENTSWITCHREASONREQUIRED)
    }
    Set tRowCap = $Get(pValues("contextRowCap"))
    If (tRowCap = "") || '$Match(tRowCap, "^[0-9]+$") || (+tRowCap < 1) || (+tRowCap > 1000) {
        Do ..Add(.pViolations, "contextRowCap", ##class(OcuPilot.Api.Error).#AGENTSWITCHCONTEXTROWCAP)
    }
    If $Data(pValues("turnsPerHour")) {
        Set tTurns = pValues("turnsPerHour")
        If '$Match(tTurns, "^[0-9]+$") || (+tTurns > 10000) {
            Do ..Add(.pViolations, "turnsPerHour", ##class(OcuPilot.Api.Error).#AGENTSWITCHTURNSPERHOUR)
        }
    }
    If $Data(pValues("concurrentTurns")) {
        Set tConcurrent = pValues("concurrentTurns")
        If (tConcurrent = "") || (+tConcurrent '= ##class(OcuPilot.Kernel.Agent.Limits).#CONCURRENTTURNS) {
            Do ..Add(.pViolations, "concurrentTurns", ##class(OcuPilot.Api.Error).#AGENTSWITCHCONCURRENTTURNS)
        }
    }
    Quit +$Get(pViolations)
}

/// <p>Every violation the per-user hold <var>pValues</var> -- <code>userName</code> and
/// <code>reason</code> -- commits, in the order they are reported.</p>
/// <p><var>pHeldAlready</var> is whether the instance already holds that user, which the caller
/// reads through <method>OcuPilot.Kernel.State.Hold.GuardedIdForUser</method>: the unique index
/// refuses a second hold anyway, and the rule answers first so the caller gets a field rather than
/// <code>#5808</code>.</p>
ClassMethod ValidateHold(ByRef pValues, pHeldAlready As %Boolean = 0, Output pViolations) As %Integer
{
    Kill pViolations
    Set tUserName = $Get(pValues("userName"))
    If ($ZStrip(tUserName, "<>W") = "") || ($Length(tUserName) > ..#MAXUSERNAMELENGTH) {
        Do ..Add(.pViolations, "userName", ##class(OcuPilot.Api.Error).#AGENTHOLDUSERREQUIRED)
    } ElseIf ''pHeldAlready {
        Do ..Add(.pViolations, "userName", ##class(OcuPilot.Api.Error).#AGENTHOLDDUPLICATE)
    }
    Set tReason = $Get(pValues("reason"))
    If ($ZStrip(tReason, "<>W") = "") || ($Length(tReason) > ..#MAXREASONLENGTH) {
        Do ..Add(.pViolations, "reason", ##class(OcuPilot.Api.Error).#AGENTHOLDREASONREQUIRED)
    }
    Quit +$Get(pViolations)
}

/// <p>Every violation the provider connection <var>pValues</var> -- <code>proxyServer</code>,
/// <code>proxyPort</code> and <code>sslConfiguration</code> -- commits, appended to <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code>; returns how many (Story 18.40, AD-32, AD-42).</p>
/// <p><b>A proxy is judged as the call judges it</b>: a bare host name, IPv4 address or IPv6 address
/// (<code>EGRESS.PROXYHOST</code>), a port from 1 to 65535 (<code>EGRESS.PROXYPORT</code>), and an address that is not
/// loopback, link-local or this instance's own (<code>EGRESS.PROXYADDRESS</code>, from
/// <method>OcuPilot.Kernel.AgentRules.AddressViolation</method> with no local escape). A name that does not resolve is
/// not a violation, as an endpoint's is not. No rule applies to an empty <code>proxyServer</code>.</p>
/// <p><var>pFresh</var> is the configuration the caller read for a name just changed to a non-default one, as the
/// SSL/TLS form's own read answers it, and <code>""</code> otherwise. A configuration that is not an enabled client
/// with <code>VerifyPeer</code> 1 is <code>EGRESS.SSLUNVERIFIED</code> on <code>sslConfiguration</code>; one that is such a
/// client with a <code>TLSMinVersion</code> below <parameter>OcuPilot.Port.ProviderPort.MINTLSVERSION</parameter> is
/// <code>EGRESS.SSLWEAK</code> (AD-32), so the save judges the floor the call holds.</p>
ClassMethod ValidateEgress(ByRef pValues, pFresh As %DynamicObject = "", Output pViolations) As %Integer
{
    Kill pViolations
    Set tHost = $Get(pValues("proxyServer"))
    If tHost '= "" {
        If '..ProxyHostShaped(tHost) {
            Do ..Add(.pViolations, "proxyServer", ##class(OcuPilot.Api.EgressError).#PROXYHOST)
        } Else {
            ; The stored proxy is a bare host, and Egress.HostOf cuts a bare host at its first colon, so a bare IPv6
            ; address is bracketed for the judgement, as ProviderPort.ProxyHostOf does at the call.
            Set tJudged = $Select($Length(tHost, ":") > 2: "[" _ tHost _ "]", 1: tHost)
            If ##class(OcuPilot.Kernel.AgentRules).AddressViolation(tJudged, 0, 0) '= "" {
                Do ..Add(.pViolations, "proxyServer", ##class(OcuPilot.Api.EgressError).#PROXYADDRESS)
            }
        }
        Set tPort = $Get(pValues("proxyPort"))
        If '$Match(tPort, "^[0-9]+$") || (+tPort < 1) || (+tPort > 65535) {
            Do ..Add(.pViolations, "proxyPort", ##class(OcuPilot.Api.EgressError).#PROXYPORT)
        }
    }
    If $IsObject(pFresh) {
        If '..EnabledVerifyingClient(pFresh) {
            Do ..Add(.pViolations, "sslConfiguration", ##class(OcuPilot.Api.EgressError).#SSLUNVERIFIED)
        } ElseIf +pFresh.%Get("TLSMinVersion") < ##class(OcuPilot.Port.ProviderPort).#MINTLSVERSION {
            Do ..Add(.pViolations, "sslConfiguration", ##class(OcuPilot.Api.EgressError).#SSLWEAK)
        }
    }
    Quit +$Get(pViolations)
}

/// <p>Whether <var>pHost</var> is a bare host name, an IPv4 address or a bare IPv6 address of at most
/// <parameter>OcuPilot.Api.EgressError.HOSTMAX</parameter> characters. A scheme, a path, a port, a user name, brackets,
/// white space and every other character a host does not carry fail it.</p>
ClassMethod ProxyHostShaped(pHost As %String) As %Boolean [ Private ]
{
    If ($Length(pHost) = 0) || ($Length(pHost) > ##class(OcuPilot.Api.EgressError).#HOSTMAX) Quit 0
    If pHost '[ ":" Quit $Match(pHost, "^[A-Za-z0-9_.-]+$")
    ; A colon is either a port, which is refused, or an IPv6 address: three to nine groups of at most four hexadecimal
    ; digits, the last of them a dotted IPv4 address where the address embeds one.
    If '$Match(pHost, "^[0-9A-Fa-f:.]+$") Quit 0
    Set tGroups = $Length(pHost, ":")
    If (tGroups < 3) || (tGroups > 9) Quit 0
    Set tShaped = 1
    For tI = 1:1:tGroups {
        Set tGroup = $Piece(pHost, ":", tI)
        If (tI = tGroups) && (tGroup [ ".") {
            If '$Match(tGroup, "^[0-9]{1,3}(\.[0-9]{1,3}){3}$") Set tShaped = 0
        } ElseIf ($Length(tGroup) > 4) || (tGroup [ ".") {
            Set tShaped = 0
        }
    }
    Quit tShaped
}

/// <p>Whether <var>pFresh</var>, a configuration as the SSL/TLS form's read answers it, is an enabled client that
/// requires the server's certificate: <code>Type</code> the number 0, <code>Enabled</code> true and
/// <code>VerifyPeer</code> the number 1. Anything a field does not say plainly fails.</p>
ClassMethod EnabledVerifyingClient(pFresh As %DynamicObject) As %Boolean
{
    If '$IsObject(pFresh) Quit 0
    If (pFresh.%GetTypeOf("Type") '= "number") || (pFresh.%Get("Type") '= 0) Quit 0
    If pFresh.%GetTypeOf("Enabled") '= "boolean" Quit 0
    If 'pFresh.%Get("Enabled") Quit 0
    Quit (pFresh.%GetTypeOf("VerifyPeer") = "number") && (pFresh.%Get("VerifyPeer") = 1)
}

/// <p>Append one violation as <code>$ListBuild(field, code)</code>, whose sentence
/// <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method> resolves by code (AD-39).</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
