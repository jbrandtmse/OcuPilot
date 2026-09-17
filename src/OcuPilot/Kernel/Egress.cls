/// <p>The endpoint address policy (AD-42, DW-21): whether OcuPilot will open a connection to the
/// host a URL names. One implementation, read by <b>both</b> the write-time rules
/// (<class>OcuPilot.Kernel.AgentRules</class>) and the call-time port
/// (<class>OcuPilot.Port.ProviderPort</class>), so the field an operator is refused on and the
/// call that is refused later cannot answer differently.</p>
/// <p><b>Every name is resolved and every literal is canonicalised before any range test.</b>
/// Probed on this instance (IRIS for Health 2026.2, 2026-09-15): <code>2130706433</code>,
/// <code>0177.0.0.1</code> and <code>127.1</code> all resolve to <code>127.0.0.1</code>, and
/// <code>AddrType</code> calls all three IPv4 -- so a dotted-quad range test on the literal passes
/// every one of them. The resolver is what turns the three spellings into the one address.</p>
/// <p><b>Both families are queried explicitly.</b> Family <code>0</code> follows
/// <method>%SYSTEM.INetInfo.IsIPV6Enabled</method>, which is an operator setting (<code>0</code>
/// here) and not a guarantee; the AAAA lookup works regardless. So families 1 and 2 are asked
/// separately and <b>every</b> address either answers with is classified, worst kind winning.</p>
/// <p><b><method>%SYSTEM.INetInfo.CheckAddressExist</method> is never called.</b> It reads like
/// "is this address the instance's" and is a ping: probed, it answers 1 for
/// <code>160.79.104.10</code>, which is Anthropic's own address. Using it would refuse every
/// reachable endpoint. The instance's own addresses come from
/// <method>%SYSTEM.INetInfo.GetInterfacesInfo</method> instead, and loopback is a range test
/// because that call does not report <code>lo</code> on this container.</p>
/// <p><b>Private ranges are not refused.</b> AD-42 names the instance, loopback and link-local and
/// nothing else, and this container's own address is <code>172.19.0.2</code> -- a blanket RFC-1918
/// refusal would be wider than the decision and would refuse the instance's own network.</p>
Class OcuPilot.Kernel.Egress Extends %RegisteredObject
{

/// <p>Kind: the address is none of the three refused classes.</p>
Parameter KINDPUBLIC = "public";

/// <p>Kind: the address reaches this host itself -- <code>127.0.0.0/8</code>,
/// <code>0.0.0.0/8</code>, <code>::1</code>, or the unspecified address <code>::</code>.</p>
/// <p><b>The unspecified address belongs here</b>, and it is not a hardening guess: measured on
/// this build with <class>%Net.HttpRequest</class>, the client this port uses, a request to
/// <code>0.0.0.0</code> answered <code>200</code> from the instance's own web server. A classifier
/// that called it public would license the loopback endpoint AD-42 refuses, with no marked-local
/// flag and no catalog escape.</p>
Parameter KINDLOOPBACK = "loopback";

/// <p>Kind: the address is in <code>169.254.0.0/16</code> or <code>fe80::/10</code>.</p>
Parameter KINDLINKLOCAL = "linklocal";

/// <p>Kind: the address is one this instance's own interfaces carry.</p>
Parameter KINDINSTANCE = "instance";

/// <p>Kind: the host resolved to no address in either family.</p>
Parameter KINDUNRESOLVABLE = "unresolvable";

/// <p>The host <var>pUrl</var>'s authority names, without its port and without the brackets an
/// IPv6 literal carries. <code>""</code> when there is no authority to read.</p>
/// <p>Userinfo is already refused upstream by
/// <method>OcuPilot.Kernel.AgentRules.IsAbsoluteHttps</method>; it is stripped here anyway, so
/// this method answers the host whatever it is handed.</p>
ClassMethod HostOf(pUrl As %String) As %String
{
    Set tHost = ""
    Try {
        If pUrl = "" Quit
        Set tRest = pUrl
        If pUrl [ "://" Set tRest = $Piece(pUrl, "://", 2, *)
        Set tAuthority = $Piece($Piece($Piece(tRest, "/", 1), "?", 1), "#", 1)
        If tAuthority [ "@" Set tAuthority = $Piece(tAuthority, "@", 2, *)
        If tAuthority = "" Quit
        If $Extract(tAuthority) = "[" {
            Set tHost = $Piece($Extract(tAuthority, 2, *), "]", 1)
        } Else {
            Set tHost = $Piece(tAuthority, ":", 1)
        }
    } Catch ex {
        Set tHost = ""
    }
    Quit tHost
}

/// <p>What kind of address <var>pHost</var> resolves to, and which address decided it.</p>
/// <p><var>pKind</var> is one of <parameter>KINDPUBLIC</parameter>,
/// <parameter>KINDLOOPBACK</parameter>, <parameter>KINDLINKLOCAL</parameter>,
/// <parameter>KINDINSTANCE</parameter> and <parameter>KINDUNRESOLVABLE</parameter>;
/// <var>pAddress</var> is the resolved address that produced it, or <code>""</code> when nothing
/// resolved.</p>
/// <p><b>The worst kind wins.</b> A name with several A and AAAA records is as dangerous as its
/// most dangerous answer, and the socket picks one of them; ranking them and reporting the worst
/// is what makes a round-robin that mixes a public and a loopback record a refusal rather than a
/// coin toss. The order is link-local, instance, loopback, public.</p>
/// <p>A host that resolves to nothing is an ordinary answer, never an exception: probed,
/// <method>HostNameToAddr</method> returns <code>""</code> for an unresolvable name.</p>
ClassMethod Classify(pHost As %String, Output pKind As %String, Output pAddress As %String)
{
    Set pKind = ..#KINDUNRESOLVABLE
    Set pAddress = ""
    Try {
        If pHost = "" Quit
        Do ..Addresses(pHost, .tResolved)
        If '$Data(tResolved) Quit
        Do ..InstanceAddresses(.tInstance)
        Set tWorst = 0
        Set tAddress = $Order(tResolved(""))
        While tAddress '= "" {
            Set tKind = ..KindOf(tAddress, .tInstance)
            Set tRank = ..Rank(tKind)
            If tRank > tWorst {
                Set tWorst = tRank
                Set pKind = tKind
                Set pAddress = tAddress
            }
            Set tAddress = $Order(tResolved(tAddress))
        }
    } Catch ex {
        Set pKind = ..#KINDUNRESOLVABLE
        Set pAddress = ""
    }
}

/// <p>Whether OcuPilot will call <var>pUrl</var>, with the kind it classified as
/// <var>pKind</var> so a caller can name the refusal.</p>
/// <p><parameter>KINDLINKLOCAL</parameter> is refused whatever <var>pMarkedLocal</var> and
/// <var>pAllowsLocal</var> say -- that range is FR-27's metadata service and has no escape.
/// <parameter>KINDLOOPBACK</parameter> and <parameter>KINDINSTANCE</parameter> are permitted only
/// when the definition is marked local <b>and</b> its provider's catalog row allows it.
/// <parameter>KINDUNRESOLVABLE</parameter> is refused: a host OcuPilot cannot resolve is a host it
/// cannot judge, and the operator is told so on the field rather than at the first turn.</p>
ClassMethod IsPermitted(pUrl As %String, pMarkedLocal As %Boolean, pAllowsLocal As %Boolean, Output pKind As %String) As %Boolean
{
    Set pKind = ..#KINDUNRESOLVABLE
    Set tPermitted = 0
    Try {
        Do ..Classify(..HostOf(pUrl), .pKind, .tAddress)
        If pKind = ..#KINDPUBLIC {
            Set tPermitted = 1
            Quit
        }
        If (pKind = ..#KINDLINKLOCAL) || (pKind = ..#KINDUNRESOLVABLE) Quit
        Set tPermitted = (''pMarkedLocal && ''pAllowsLocal)
    } Catch ex {
        Set tPermitted = 0
    }
    Quit tPermitted
}

/// <p>Every address <var>pHost</var> resolves to, as subscripts of <var>pAddresses</var>.</p>
/// <p>Four lookups, deliberately: <method>HostNameToAddrMulti</method> and
/// <method>HostNameToAddr</method>, each in family 1 and family 2. The multi form answers every
/// record a name carries; the single form is what was probed to canonicalise the obfuscated
/// address literals. The union is what is classified, so an address either form alone would have
/// missed is still judged.</p>
/// <p><b>The union loop is this method's; the multi-record lookup is
/// <method>MultiLookup</method>'s</b>, and that is where a test substitutes (DW-338). Overriding
/// this method wholesale replaced the union, the family loop and the single-form fallback along
/// with the lookup, so the body a production call takes was not the body under test.
/// <method>Classify</method>'s worst-kind-wins ranking only does anything for a host answering
/// addresses of more than one kind, and no name this instance can resolve does that, so without
/// a seam the ranking is code nothing exercises -- but the seam belongs at the lookup, not around
/// everything above it. Production never overrides either.</p>
ClassMethod Addresses(pHost As %String, Output pAddresses)
{
    Kill pAddresses
    For tFamily = 1, 2 {
        Try {
            Set tList = ..MultiLookup(pHost, tFamily)
            If $ListValid(tList) {
                For tI = 1:1:$ListLength(tList) {
                    Set tEntry = $List(tList, tI)
                    If tEntry '= "" Set pAddresses(tEntry) = ""
                }
            }
        } Catch ex {
        }
        Try {
            Set tOne = $System.INetInfo.HostNameToAddr(pHost, tFamily)
            If tOne '= "" Set pAddresses(tOne) = ""
        } Catch ex {
        }
    }
}

/// <p>Every address <var>pHost</var> carries in address family <var>pFamily</var>, as the
/// <class>%List</class> <method>$System.INetInfo.HostNameToAddrMulti</method> answers.</p>
/// <p><b>The one overridable seam on this path.</b> A test that needs a host answering two kinds
/// of address replaces this and leaves <method>Addresses</method>' own union loop, the family
/// loop, the single-form fallback and everything <method>Classify</method> does above them
/// running as shipped. Production never overrides it.</p>
ClassMethod MultiLookup(pHost As %String, pFamily As %Integer) As %List
{
    Quit $System.INetInfo.HostNameToAddrMulti(pHost, pFamily)
}

/// <p>Every address this instance's own interfaces carry, as subscripts of
/// <var>pAddresses</var>.</p>
/// <p><method>GetInterfacesInfo</method> separates interfaces by <code>$Char(0)</code> and, within
/// one interface, its name from its addresses by <code>$Char(1)</code>; an address may carry a
/// <code>/prefix</code> suffix, which is stripped. Observed on this container:
/// <code>eth0</code> + <code>$Char(1)</code> + <code>172.19.0.2/16</code>, and
/// <code>GetInterfacesInfo("lo")</code> answers <code>""</code> -- which is why loopback is a
/// range test here rather than an interface test.</p>
/// <p>Read on every classification and never cached: an interface can be added or removed under a
/// running instance, and a cached set would judge an address against a machine that has moved.</p>
ClassMethod InstanceAddresses(Output pAddresses) [ Private ]
{
    Kill pAddresses
    Try {
        Set tInfo = $System.INetInfo.GetInterfacesInfo()
        If tInfo = "" Quit
        For tI = 1:1:$Length(tInfo, $Char(0)) {
            Set tInterface = $Piece(tInfo, $Char(0), tI)
            If tInterface = "" Continue
            For tJ = 2:1:$Length(tInterface, $Char(1)) {
                Set tAddress = $Piece($Piece(tInterface, $Char(1), tJ), "/", 1)
                If tAddress = "" Continue
                Set pAddresses(..Canonical(tAddress)) = ""
            }
        }
    } Catch ex {
        Kill pAddresses
    }
}

/// <p>The kind of one resolved address, with <var>pInstance</var> the set
/// <method>InstanceAddresses</method> answered.</p>
ClassMethod KindOf(pAddress As %String, ByRef pInstance) As %String [ Private ]
{
    Set tKind = ..#KINDPUBLIC
    Set tAddress = ..Canonical(pAddress)
    If ..IsLinkLocal(tAddress) {
        Set tKind = ..#KINDLINKLOCAL
    } ElseIf ..IsLoopback(tAddress) {
        Set tKind = ..#KINDLOOPBACK
    } ElseIf $Data(pInstance(tAddress)) {
        Set tKind = ..#KINDINSTANCE
    }
    Quit tKind
}

/// <p>How bad a kind is, so <method>Classify</method> can take the worst of several answers.</p>
ClassMethod Rank(pKind As %String) As %Integer [ Private ]
{
    If pKind = ..#KINDLINKLOCAL Quit 4
    If pKind = ..#KINDINSTANCE Quit 3
    If pKind = ..#KINDLOOPBACK Quit 2
    If pKind = ..#KINDPUBLIC Quit 1
    Quit 0
}

/// <p>One comparable spelling of <var>pAddress</var>: folded to lower case, its IPv6 zone index
/// dropped, and an IPv4-mapped IPv6 address unwrapped to the IPv4 address it carries.</p>
/// <p><b>The unwrap is load-bearing.</b> Probed: <code>AddrType("::ffff:127.0.0.1")</code> answers
/// 2 (IPv6), so an IPv4 range test never sees it and an IPv6 one does not match
/// <code>::1</code> -- the loopback would classify public. Both spellings of the mapped form are
/// unwrapped: the dotted tail IRIS produces, and the two-group hex tail the address family also
/// admits.</p>
ClassMethod Canonical(pAddress As %String) As %String [ Private ]
{
    Set tAddress = $ZConvert(pAddress, "L")
    If tAddress [ "%" Set tAddress = $Piece(tAddress, "%", 1)
    ; The deprecated IPv4-compatible form ::a.b.c.d carries an IPv4 address exactly as the mapped
    ; form does, and the group parser refuses any literal containing a dot -- so without this the
    ; loopback in ::127.0.0.1 is never seen by either range test.
    If ($Extract(tAddress, 1, 2) = "::") && ..IsDottedQuad($Extract(tAddress, 3, *)) Quit $Extract(tAddress, 3, *)
    If $Extract(tAddress, 1, 7) '= "::ffff:" Quit tAddress
    Set tTail = $Extract(tAddress, 8, *)
    If ..IsDottedQuad(tTail) Quit tTail
    If $Length(tTail, ":") '= 2 Quit tAddress
    Set tHigh = ..HexGroup($Piece(tTail, ":", 1))
    Set tLow = ..HexGroup($Piece(tTail, ":", 2))
    If (tHigh < 0) || (tLow < 0) Quit tAddress
    Quit (tHigh \ 256) _ "." _ (tHigh # 256) _ "." _ (tLow \ 256) _ "." _ (tLow # 256)
}

/// <p>Whether <var>pAddress</var> reaches this host itself: <code>127.0.0.0/8</code>,
/// <code>0.0.0.0/8</code>, or the IPv6 <code>::1</code> and <code>::</code> in any of their
/// spellings (measured -- see <parameter>KINDLOOPBACK</parameter>).</p>
/// <p><b>Both IPv4 arms are the whole reserved block, not the one literal that was measured to
/// reach here.</b> Of <code>0.0.0.0/8</code> only <code>0.0.0.0</code> itself answered on this
/// stack; <code>0.0.0.1</code>, <code>0.0.0.5</code> and <code>0.1.2.3</code> were all refused at
/// the socket. The block is refused whole anyway, because "not routable on the stack we measured"
/// is not a property to license an endpoint on -- RFC 1122 reserves the whole of
/// <code>0.0.0.0/8</code>, and a classifier that enumerates the spellings it was shown is the
/// shape that already admitted <code>0.0.0.0</code> once.</p>
ClassMethod IsLoopback(pAddress As %String) As %Boolean [ Private ]
{
    If ..IsDottedQuad(pAddress) Quit ($Piece(pAddress, ".", 1) = 127) || ($Piece(pAddress, ".", 1) = 0)
    If '..V6Groups(pAddress, .tGroups) Quit 0
    Set tLeadingZero = 1
    For tI = 1:1:7 {
        If tGroups(tI) '= 0 {
            Set tLeadingZero = 0
            Quit
        }
    }
    If 'tLeadingZero Quit 0
    ; 1 is ::1; 0 is the unspecified address ::, which reaches this host for the same reason
    ; 0.0.0.0 does.
    Quit (tGroups(8) = 1) || (tGroups(8) = 0)
}

/// <p>Whether <var>pAddress</var> is link-local: <code>169.254.0.0/16</code>, or
/// <code>fe80::/10</code> -- the first ten bits, so the whole of
/// <code>fe80::</code>-<code>febf::</code> and not <code>fe80::</code> alone.</p>
ClassMethod IsLinkLocal(pAddress As %String) As %Boolean [ Private ]
{
    If ..IsDottedQuad(pAddress) {
        Quit ($Piece(pAddress, ".", 1) = 169) && ($Piece(pAddress, ".", 2) = 254)
    }
    If '..V6Groups(pAddress, .tGroups) Quit 0
    Quit (tGroups(1) >= 65152) && (tGroups(1) <= 65215)
}

/// <p>Whether <var>pValue</var> is a dotted-quad IPv4 address, every octet 0-255.</p>
ClassMethod IsDottedQuad(pValue As %String) As %Boolean [ Private ]
{
    If '$Match(pValue, "^[0-9]{1,3}(\.[0-9]{1,3}){3}$") Quit 0
    Set tOk = 1
    For tI = 1:1:4 {
        If +$Piece(pValue, ".", tI) > 255 Set tOk = 0
    }
    Quit tOk
}

/// <p>The eight sixteen-bit groups of the IPv6 literal <var>pAddress</var>, as
/// <var>pGroups</var>(1) through <var>pGroups</var>(8). Answers 0, with <var>pGroups</var>
/// killed, for anything that is not one.</p>
/// <p>The compressed <code>::</code> run is expanded here rather than compared textually: without
/// it <code>::1</code> and <code>0:0:0:0:0:0:0:1</code> are different strings for the same
/// loopback, and a substring test that called both loopback would call <code>::10</code> loopback
/// too.</p>
ClassMethod V6Groups(pAddress As %String, Output pGroups) As %Boolean [ Private ]
{
    Kill pGroups
    Set tOk = 0
    Try {
        If '(pAddress [ ":") Quit
        If pAddress [ "." Quit
        If $Length(pAddress, "::") > 2 Quit
        Set tCompressed = (pAddress [ "::")
        Set tBad = 0
        Set tLeadCount = 0
        Set tTailCount = 0
        Set tLead = $Piece(pAddress, "::", 1)
        Set tTail = $Select(tCompressed: $Piece(pAddress, "::", 2), 1: "")
        If tLead '= "" {
            For tI = 1:1:$Length(tLead, ":") {
                Set tValue = ..HexGroup($Piece(tLead, ":", tI))
                If tValue < 0 {
                    Set tBad = 1
                    Quit
                }
                Set tLeadCount = tLeadCount + 1
                Set tLeadGroup(tLeadCount) = tValue
            }
        }
        If tBad Quit
        If tTail '= "" {
            For tI = 1:1:$Length(tTail, ":") {
                Set tValue = ..HexGroup($Piece(tTail, ":", tI))
                If tValue < 0 {
                    Set tBad = 1
                    Quit
                }
                Set tTailCount = tTailCount + 1
                Set tTailGroup(tTailCount) = tValue
            }
        }
        If tBad Quit
        If 'tCompressed {
            If tLeadCount '= 8 Quit
        } ElseIf (tLeadCount + tTailCount) > 7 {
            Quit
        }
        For tI = 1:1:8 {
            Set pGroups(tI) = 0
        }
        For tI = 1:1:tLeadCount {
            Set pGroups(tI) = tLeadGroup(tI)
        }
        For tI = 1:1:tTailCount {
            Set pGroups(8 - tTailCount + tI) = tTailGroup(tI)
        }
        Set tOk = 1
    } Catch ex {
        Kill pGroups
        Set tOk = 0
    }
    If 'tOk Kill pGroups
    Quit tOk
}

/// <p>Whether <var>pAddress</var> is a private-range address: <code>10.0.0.0/8</code>,
/// <code>172.16.0.0/12</code>, <code>192.168.0.0/16</code> (RFC 1918), or <code>fc00::/7</code>
/// (unique local IPv6). Distinct from <method>IsLoopback</method> and
/// <method>IsLinkLocal</method>, and from <method>IsPermitted</method>'s own judgement, which does
/// not refuse a private address at all (AD-42 names the instance, loopback and link-local, and
/// nothing else).</p>
ClassMethod IsPrivate(pAddress As %String) As %Boolean
{
    Set tAddress = ..Canonical(pAddress)
    If ..IsDottedQuad(tAddress) {
        Set tOctet1 = +$Piece(tAddress, ".", 1)
        Set tOctet2 = +$Piece(tAddress, ".", 2)
        Quit (tOctet1 = 10) || ((tOctet1 = 172) && (tOctet2 >= 16) && (tOctet2 <= 31)) || ((tOctet1 = 192) && (tOctet2 = 168))
    }
    If '..V6Groups(tAddress, .tGroups) Quit 0
    ; fc00::/7 is the top seven bits 1111 110x, i.e. the first group's value in 0xFC00-0xFDFF.
    Quit (tGroups(1) >= 64512) && (tGroups(1) <= 65023)
}

/// <p>Whether a provider call to <var>pHost</var>, through the proxy <var>pProxyHost</var> when
/// one is configured, leaves this instance (Story 4.4's context status read, AD-42). A proxy is a
/// destination too, judged by its addresses alone: when it leaves, the call leaves. Otherwise false
/// when <var>pMarkedLocal</var>, and else <var>pHost</var> is judged the same way.</p>
ClassMethod LeavesInstance(pHost As %String, pMarkedLocal As %Boolean, pProxyHost As %String = "") As %Boolean
{
    If (pProxyHost '= "") && ..HostLeaves(pProxyHost) Quit 1
    If pMarkedLocal Quit 0
    Quit ..HostLeaves(pHost)
}

/// <p>Whether <var>pHost</var> is unresolvable or resolves to any address that is not loopback,
/// link-local or private (<method>IsPrivate</method>).</p>
ClassMethod HostLeaves(pHost As %String) As %Boolean [ Private ]
{
    Do ..Addresses(pHost, .tAddresses)
    If '$Data(tAddresses) Quit 1
    Set tLeaves = 0
    Set tAddress = $Order(tAddresses(""))
    While tAddress '= "" {
        If '(..IsLoopback(tAddress) || ..IsLinkLocal(tAddress) || ..IsPrivate(tAddress)) {
            Set tLeaves = 1
        }
        Set tAddress = $Order(tAddresses(tAddress))
    }
    Quit tLeaves
}

/// <p>The value of one IPv6 group written as one to four hexadecimal digits, or <code>-1</code>
/// for anything else.</p>
ClassMethod HexGroup(pPiece As %String) As %Integer [ Private ]
{
    If '$Match(pPiece, "^[0-9A-Fa-f]{1,4}$") Quit -1
    Set tValue = 0
    For tI = 1:1:$Length(pPiece) {
        Set tValue = (tValue * 16) + ($Find("0123456789abcdef", $ZConvert($Extract(pPiece, tI), "L")) - 2)
    }
    Quit tValue
}

}
