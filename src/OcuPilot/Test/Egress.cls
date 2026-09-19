/// <p>AC4's write-time half: every address row of the story's I/O matrix, driven through
/// <class>OcuPilot.Kernel.Egress</class> and through the validation rule that reads it.</p>
/// <p><b>It resolves real names against this instance's own resolver</b>, which is the point: the
/// obfuscated loopback literals are only refused because the resolver canonicalises them, and a
/// fixture that answered canned addresses would pin the test's own arithmetic instead of the
/// instance's. Nothing here writes anything, and no address is connected to.</p>
/// <p>The marked-local escape is driven through <class>OcuPilot.Test.CatalogProbe</class>'s
/// <code>probe-local</code> row, because every shipped row sets <code>allowsLocal</code> false --
/// so the escape has no shipped case, and a rule with no case either way is not enforced.</p>
Class OcuPilot.Test.Egress Extends %UnitTest.TestCase
{

/// <p>The class under test.</p>
Parameter EGRESS = "OcuPilot.Kernel.Egress";

/// <p>The validator reading <class>OcuPilot.Test.CatalogProbe</class>, so the two extra provider
/// rows are in the vocabulary.</p>
Parameter RULES = "OcuPilot.Test.AgentRulesProbe";

/// <p>A host name that resolves to nothing, in a reserved-for-failure top-level domain so it
/// cannot start resolving because somebody registered it.</p>
Parameter UNRESOLVABLE = "no-such-host-ocupilot.invalid";

/// <p>Assert that <var>pUrl</var> classifies as <var>pKind</var>.</p>
Method AssertKind(pUrl As %String, pKind As %String, pWhat As %String)
{
    Do $ClassMethod(..#EGRESS, "Classify", $ClassMethod(..#EGRESS, "HostOf", pUrl), .tKind, .tAddress)
    Do $$$AssertEquals(tKind, pKind, pWhat _ ": " _ pUrl _ " classifies as " _ tKind _ " (" _ tAddress _ ")")
}

/// <p>Assert that <var>pUrl</var> is permitted, or not, for the given flags.</p>
Method AssertPermitted(pUrl As %String, pMarkedLocal As %Boolean, pAllowsLocal As %Boolean, pExpected As %Boolean, pWhat As %String)
{
    Set tPermitted = $ClassMethod(..#EGRESS, "IsPermitted", pUrl, pMarkedLocal, pAllowsLocal, .tKind)
    Do $$$AssertEquals(''tPermitted, ''pExpected, pWhat _ ": " _ pUrl _ " (markedLocal " _ +pMarkedLocal _ ", allowsLocal " _ +pAllowsLocal _ ") -> " _ tKind)
}

/// <p>The authority's host, without the port and without an IPv6 literal's brackets, and whatever
/// path, query or fragment follows it.</p>
Method TestTheHostIsReadOffTheAuthorityAlone()
{
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://api.example.com/v1/messages"), "api.example.com", "a plain authority")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://api.example.com:8443/v1"), "api.example.com", "a port is not part of the host")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://[::1]:8443/v1"), "::1", "an IPv6 literal loses its brackets and its port")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://api.example.com?a=b"), "api.example.com", "a query begins the non-authority part")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://api.example.com#frag"), "api.example.com", "so does a fragment")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", "https://user:secret@api.example.com/v1"), "api.example.com", "userinfo is stripped, so a credential in the field never reaches the resolver")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "HostOf", ""), "", "an empty URL has no host")
}

/// <p>AC4 -- the three obfuscated spellings of the loopback address are refused, because every
/// literal is canonicalised through the resolver <b>before</b> any range test.</p>
/// <p>Mutation: range-test the literal before canonicalising it in
/// <method>OcuPilot.Kernel.Egress.Classify</method> -- the decimal and short forms go red, since
/// each resolves to <code>127.0.0.1</code> while <code>AddrType</code> calls all three IPv4 and a
/// dotted-quad test alone passes them.</p>
Method TestEveryLoopbackSpellingIsRefused()
{
    For tUrl = "https://127.0.0.1/v1", "https://2130706433/v1", "https://0177.0.0.1/v1", "https://127.1/v1", "https://localhost/v1" {
        Do ..AssertKind(tUrl, "loopback", "a loopback spelling")
        Do ..AssertPermitted(tUrl, 0, 0, 0, "loopback without the escape")
        Do ..AssertPermitted(tUrl, 1, 0, 0, "loopback marked local on a row that forbids it")
        Do ..AssertPermitted(tUrl, 0, 1, 0, "loopback on a row that allows it but a definition not marked")
        Do ..AssertPermitted(tUrl, 1, 1, 1, "loopback marked local on a row that allows it")
    }
    Do ..AssertKind("https://[::1]/v1", "loopback", "the IPv6 loopback")
    Do ..AssertPermitted("https://[::1]/v1", 0, 0, 0, "the IPv6 loopback without the escape")
}

/// <p>AC4 -- the unspecified address reaches this host, so it is loopback and not public, and the
/// rest of its reserved block is refused with it.</p>
/// <p><b>Measured, not reasoned about.</b> Using <class>%Net.HttpRequest</class> -- the client the
/// provider path itself uses -- a request to <code>0.0.0.0</code> answered HTTP 200 from this
/// container's own web server, while <code>::</code>, <code>::127.0.0.1</code>,
/// <code>0.0.0.1</code>, <code>0.0.0.5</code> and <code>0.1.2.3</code> were all refused at the
/// socket. Every one of them is classified as reaching this host regardless, because "not routable
/// on the stack we measured" is not a property to license an endpoint on -- that is the reasoning
/// that admitted <code>0.0.0.0</code> in the first place.</p>
/// <p>Mutation: narrow <method>OcuPilot.Kernel.Egress.IsLoopback</method>'s zero arm from
/// <code>$Piece(pAddress, ".", 1) = 0</code> back to <code>pAddress = "0.0.0.0"</code> -- the
/// <code>0.0.0.1</code> leg goes red, reporting public and permitted; dropping the arm altogether
/// reddens the <code>0.0.0.0</code> leg too, which is a loopback endpoint accepted with no
/// marked-local flag and no catalog escape.</p>
Method TestTheUnspecifiedAddressIsNotPublic()
{
    For tUrl = "https://0.0.0.0/v1", "https://[::]/v1", "https://[0:0:0:0:0:0:0:0]/v1", "https://[::127.0.0.1]/v1", "https://0.0.0.1/v1", "https://0.1.2.3/v1" {
        Do ..AssertKind(tUrl, "loopback", "the unspecified address or another of its reserved block")
        Do ..AssertPermitted(tUrl, 0, 0, 0, "and it is refused without the escape")
    }
}

/// <p>AC4 -- <b>the worst kind wins</b> over a host whose records mix kinds: the socket picks one
/// of them, so a name answering both a public and a refused address is as dangerous as its worst
/// answer.</p>
/// <p>Driven through <class>OcuPilot.Test.EgressProbe</class>, because no name this instance can
/// resolve answers two different kinds -- see that class for why the seam exists.</p>
/// <p>Mutation: take the first classified address in
/// <method>OcuPilot.Kernel.Egress.Classify</method> instead of the highest-ranked one -- the
/// mixed legs go red, reporting public for a set containing a loopback address.</p>
Method TestTheWorstKindWinsOverAMixedRecordSet()
{
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ..AssertProbeKind("public", "93.184.216.34", "a set of one public address")
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34,127.0.0.1")
    Do ..AssertProbeKind("loopback", "127.0.0.1", "a public record beside a loopback one")
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("127.0.0.1,93.184.216.34")
    Do ..AssertProbeKind("loopback", "127.0.0.1", "and the same set in the other order")
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34,127.0.0.1,169.254.169.254")
    Do ..AssertProbeKind("linklocal", "169.254.169.254", "link-local outranks loopback, which outranks public")
    ; Cleared and then classified THROUGH THE PROBE: asserting through ..#EGRESS would measure the
    ; shipped class, which has no seam to clear and would answer the same either way. This is the
    ; only assertion that reaches the probe's fall-through to the real resolver.
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).Classify("api.anthropic.com", .tKind, .tAddress)
    Do $$$AssertEquals(tKind, "public", "and with the seam cleared the probe falls through to the instance's own resolver")
    Do $$$AssertNotEquals(tAddress, "", "which answers a real address rather than nothing: " _ tAddress)
}

/// <p>AC4 -- the worst-kind-wins ranking's middle position. The mixed-record-set method above
/// exercises <code>public</code>, <code>loopback</code> and <code>linklocal</code> against each
/// other, but never against <code>instance</code>, so a rank that quietly tied
/// <code>instance</code> to <code>public</code> would leave every existing assertion in this class
/// green: <method>TestTheInstancesOwnAddressIsRefused</method> classifies one address alone, where
/// any positive rank wins regardless of its value.</p>
/// <p>Mutation: in <method>OcuPilot.Kernel.Egress.Rank</method>, change the
/// <parameter>KINDINSTANCE</parameter> case from 3 to 1 -- the first leg goes red, reporting
/// <code>loopback</code> instead of <code>instance</code> for a set naming both.</p>
Method TestTheWorstKindWinsPlacesTheInstanceRankBetweenLoopbackAndLinkLocal()
{
    Set tOwn = ..FirstInterfaceAddress()
    Do $$$AssertNotEquals(tOwn, "", "this instance reports at least one interface address: " _ tOwn)
    If tOwn = "" Quit
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("127.0.0.1," _ tOwn)
    Do ..AssertProbeKind("instance", tOwn, "an instance address outranks a loopback one in the same record set")
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses(tOwn _ ",169.254.169.254")
    Do ..AssertProbeKind("linklocal", "169.254.169.254", "and link-local outranks the instance address in turn")
}

/// <p><b>DW-338</b> -- the probe substitutes the <i>lookup</i> and nothing above it, so the legs
/// above run <method>OcuPilot.Kernel.Egress.Addresses</method>'s own body: its address-family
/// loop, its union of the multi and single forms, and its per-entry guard.</p>
/// <p>Asserted structurally rather than by behaviour, because behaviour cannot tell a shipped
/// method from an identical copy of it: the compiled origin of <code>Addresses</code> on the probe
/// is the kernel class, and the compiled origin of <code>MultiLookup</code> is the probe.</p>
/// <p>Mutation: move the probe's override back up to <code>Addresses</code> -- this goes red
/// naming the origin it now reports.</p>
Method TestTheProbeReplacesTheLookupAndNotTheUnionAboveIt()
{
    Set tAddresses = ##class(%Dictionary.CompiledMethod).%OpenId("OcuPilot.Test.EgressProbe||Addresses", 0, .tOneSC)
    Do $$$AssertTrue($IsObject(tAddresses), "the probe's compiled Addresses is readable")
    If $IsObject(tAddresses) Do $$$AssertEquals(tAddresses.Origin, "OcuPilot.Kernel.Egress", "and it is the kernel's own, so the union loop the legs above depend on is production's")
    Set tLookup = ##class(%Dictionary.CompiledMethod).%OpenId("OcuPilot.Test.EgressProbe||MultiLookup", 0, .tTwoSC)
    Do $$$AssertTrue($IsObject(tLookup), "the probe's compiled MultiLookup is readable")
    If $IsObject(tLookup) Do $$$AssertEquals(tLookup.Origin, "OcuPilot.Test.EgressProbe", "and it is the probe's, which is the one seam this class substitutes")
}

/// <p>AC9 (DW-413) -- the single-record lookup is <b>inside</b> the seam, so an armed probe's set is
/// the whole set even for a host the instance's own resolver answers for. Until the move,
/// <method>OcuPilot.Kernel.Egress.Addresses</method> called
/// <method>$System.INetInfo.HostNameToAddr</method> itself, so a real host's real addresses were
/// unioned in behind the probe's back and this case could not be written at all.</p>
/// <p><code>localhost</code> is the host chosen because every instance resolves it -- the test is
/// only meaningful against a name the resolver does answer for -- and the assertion is that the
/// probe's own public address is the verdict, which the real <code>127.0.0.1</code> would outrank
/// if it were still being unioned in.</p>
/// <p>Mutation: move the <code>HostNameToAddr</code> call back out of
/// <method>OcuPilot.Kernel.Egress.MultiLookup</method> into
/// <method>OcuPilot.Kernel.Egress.Addresses</method> -- this goes red, reporting
/// <code>loopback</code>.</p>
Method TestAnArmedProbeOwnsTheWholeAddressSetEvenForAResolvableHost()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Kernel.Egress).Classify("localhost", .tRealKind, .tRealAddress)
    Do $$$AssertEquals(tRealKind, "loopback", "this instance's own resolver does answer for localhost, which is what makes the next leg a test: " _ tRealAddress)
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("localhost", .tKind, .tAddress)
    Do $$$AssertEquals(tKind _ "|" _ tAddress, "public|93.184.216.34", "with the probe armed the set is exactly the probe's, with no real address unioned in")
}

/// <p>AC10 (DW-334) -- a verdict is reused for
/// <parameter>OcuPilot.Kernel.Egress.JUDGEMENTCACHESECONDS</parameter>: three classifications of
/// one host inside the window perform one set of family lookups and one interface read, and the
/// first classification after the window performs them again.</p>
/// <p>The claim is a count, and counts are what this asserts -- through
/// <class>OcuPilot.Test.EgressProbe</class>'s own counters, because a cache is a claim about how
/// often something is read. The TTL itself is the one thing that can only be waited out; five
/// seconds is cheaper than a second clock seam.</p>
/// <p>Mutation: set that parameter to 0 -- the cached legs go red, reporting six lookups and three
/// interface reads.</p>
Method TestAVerdictIsReusedForTheDeclaredTtlAndTakenAgainAfterIt()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    For tCall = 1:1:3 {
        Do ##class(OcuPilot.Test.EgressProbe).Classify("cache.example.invalid", .tKind, .tAddress)
        Do $$$AssertEquals(tKind, "public", "call " _ tCall _ " answers the same verdict")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).MultiLookups(), 2, "one set of family lookups served all three classifications")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 1, "and this instance's interface set was read once")
    ; The TTL is short by design, so waiting it out is cheaper than a second clock seam -- and it
    ; is the bound itself that is under test, not a stand-in for it.
    Hang $Parameter("OcuPilot.Kernel.Egress", "JUDGEMENTCACHESECONDS") + 1
    Do ##class(OcuPilot.Test.EgressProbe).Classify("cache.example.invalid", .tKind, .tAddress)
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).MultiLookups(), 4, "once the window has passed the lookups are taken again")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 2, "and so is the interface set, so nothing is held past the declared TTL")
}

/// <p>AC10 -- the interface set is cached in its own right: two <b>different</b> hosts judged
/// inside one window pay two sets of family lookups and share a single
/// <method>GetInterfacesInfo</method> read.</p>
/// <p>Its own method because the repeat-host case cannot see this half at all: the second and
/// third judgements of one host answer from the verdict cache and never enter
/// <method>OcuPilot.Kernel.Egress.InstanceAddresses</method>, so their interface count is 1
/// whether that cache exists or not.</p>
/// <p>Mutation: remove the cache read and write from
/// <method>OcuPilot.Kernel.Egress.InstanceAddresses</method> -- this goes red, reporting two
/// interface reads.</p>
Method TestTheInterfaceSetIsCachedAcrossDifferentHosts()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("first.example.invalid", .tFirstKind, .tFirstAddress)
    Do ##class(OcuPilot.Test.EgressProbe).Classify("second.example.invalid", .tSecondKind, .tSecondAddress)
    Do $$$AssertEquals(tFirstKind _ "|" _ tSecondKind, "public|public", "both hosts are judged, so both reached the classifier")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).MultiLookups(), 4, "each host paid its own family lookups, so neither answered from the other's verdict")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 1, "and this instance's interface set was read once for the two of them")
}

/// <p>AC10 -- a verdict reached with nothing resolved is never cached: an unresolvable host
/// classified twice inside <parameter>OcuPilot.Kernel.Egress.JUDGEMENTCACHESECONDS</parameter>
/// pays its family lookups both times, because <code>Classify</code> only caches a host that
/// resolved to at least one address.</p>
/// <p>A cached refusal would answer "unresolvable" for the whole TTL even if the resolver started
/// answering for that host a moment later, and the write-time and call-time paths would then
/// disagree with a resolver that had already recovered.</p>
/// <p>Mutation: drop the <code>If $Data(tResolved)</code> guard in
/// <method>OcuPilot.Kernel.Egress.Classify</method> so every verdict is cached regardless -- this
/// goes red, reporting 2 lookups instead of 4.</p>
Method TestAnUnresolvedHostsVerdictIsNeverCached()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).Classify(..#UNRESOLVABLE, .tFirstKind, .tFirstAddress)
    Do $$$AssertEquals(tFirstKind, "unresolvable", "the host resolves to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).MultiLookups(), 2, "the first classification pays its own two family lookups")
    Do ##class(OcuPilot.Test.EgressProbe).Classify(..#UNRESOLVABLE, .tSecondKind, .tSecondAddress)
    Do $$$AssertEquals(tSecondKind, "unresolvable", "and resolves to nothing again")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).MultiLookups(), 4, "a verdict reached with nothing resolved is never cached, so the second classification pays the lookups again rather than answering from a cached refusal")
}

/// <p>AC10 -- an empty <code>GetInterfacesInfo</code> answer is never cached either: caching it
/// would classify this instance's own address <code>public</code> for
/// <parameter>OcuPilot.Kernel.Egress.JUDGEMENTCACHESECONDS</parameter>, because an empty interface
/// set means nothing is ever this instance's. Only a read that produced at least one address is
/// cached (<method>OcuPilot.Kernel.Egress.CacheInterfaces</method>'s own doc comment); this is the
/// test that reads it back.</p>
/// <p>Driven through <method>OcuPilot.Test.EgressProbe.ArmEmptyInterfacesOnce</method>, because
/// this probe cannot make the real <code>GetInterfacesInfo</code> answer nothing on demand.</p>
/// <p>Mutation: set <code>tRead = 1</code> unconditionally in
/// <method>OcuPilot.Kernel.Egress.InstanceAddresses</method> before the emptiness check -- this
/// goes red, reporting 1 interface read for the two classifications instead of 2.</p>
Method TestAnEmptyInterfaceReadIsNotCachedAsAnEmptySet()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ##class(OcuPilot.Test.EgressProbe).ArmEmptyInterfacesOnce()
    Do ##class(OcuPilot.Test.EgressProbe).Classify("empty-interfaces-first.example.invalid", .tFirstKind, .tFirstAddress)
    Do $$$AssertEquals(tFirstKind, "public", "the address itself still classifies, whatever the interface read answered")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 1, "one interface read was attempted, and it answered nothing")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("empty-interfaces-second.example.invalid", .tSecondKind, .tSecondAddress)
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 2, "an empty answer is not cached, so the next classification reads the interface set live again rather than reusing an empty one")
}

/// <p>AC10 -- an interface description that names an interface but carries no address is not cached
/// either. The guard is on the set the parse produced, not on the raw description: a read this
/// class can take no address from has answered nothing, and holding it would classify this
/// instance's own address <code>public</code> for the whole TTL exactly as an empty read would.</p>
/// <p>Driven through <method>OcuPilot.Test.EgressProbe.ArmInterfacesOnce</method>: an interface
/// with no address section is a shape this container's own
/// <code>$System.INetInfo.GetInterfacesInfo</code> does not produce on demand.</p>
/// <p>Mutation: guard the cache write on the raw read
/// (<code>If tRead Do ..CacheInterfaces(.pAddresses)</code>) in
/// <method>OcuPilot.Kernel.Egress.InstanceAddresses</method> -- this goes red, reporting 1
/// interface read for the two classifications instead of 2.</p>
Method TestAnInterfaceReadCarryingNoAddressIsNotCachedEither()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ##class(OcuPilot.Test.EgressProbe).ArmInterfacesOnce("eth0")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("addressless-first.example.invalid", .tFirstKind, .tFirstAddress)
    Do $$$AssertEquals(tFirstKind, "public", "the address itself still classifies, whatever the interface read answered")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 1, "one interface read was attempted, and it named an interface carrying no address")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("addressless-second.example.invalid", .tSecondKind, .tSecondAddress)
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressProbe).InterfaceReads(), 2, "a read the parse took no address from is not cached, so the next classification reads the interface set live again rather than reusing an empty one")
}

/// <p>AC10 -- arming the resolver empties the verdict cache, so a set a test supplies can never be
/// masked by a judgement reached before it was armed.</p>
/// <p>Mutation: drop the <method>OcuPilot.Kernel.Egress.ClearJudgementCache</method> call from
/// <method>OcuPilot.Test.EgressProbe.SetAddresses</method> -- this goes red, the second
/// classification answering <code>public</code> from the verdict the first set left behind.</p>
Method TestArmingTheResolverEmptiesTheVerdictCache()
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("93.184.216.34")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("swap.example.invalid", .tFirstKind, .tFirstAddress)
    Do $$$AssertEquals(tFirstKind, "public", "the first set is judged public")
    Do ##class(OcuPilot.Test.EgressProbe).SetAddresses("127.0.0.1")
    Do ##class(OcuPilot.Test.EgressProbe).Classify("swap.example.invalid", .tSecondKind, .tSecondAddress)
    Do $$$AssertEquals(tSecondKind, "loopback", "and the second set is judged on its own, not on the verdict the first left behind")
}

/// <p>Classify through the probe and assert the kind and the address that decided it.</p>
Method AssertProbeKind(pKind As %String, pAddress As %String, pWhat As %String)
{
    Do ##class(OcuPilot.Test.EgressProbe).Classify("probe.example.invalid", .tKind, .tAddress)
    Do $$$AssertEquals(tKind, pKind, pWhat _ ": classifies as " _ tKind)
    Do $$$AssertEquals(tAddress, pAddress, pWhat _ ": and names the address that decided it")
}

/// <p>Leave the resolver seam clear for the next method, or the next class.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.EgressProbe).Clear()
    Quit $$$OK
}

/// <p>AC4 -- an IPv4-mapped IPv6 address is unwrapped before it is judged, in both the dotted and
/// the hexadecimal spelling of its tail.</p>
/// <p>Probed: <code>AddrType("::ffff:127.0.0.1")</code> answers 2 (IPv6), so an IPv4 range test
/// never sees it and an IPv6 one does not match <code>::1</code> -- without the unwrap the
/// loopback classifies public.</p>
/// <p>Mutation: delete the <code>::ffff:</code> branch of
/// <method>OcuPilot.Kernel.Egress.Canonical</method> -- both legs go red, reporting public.</p>
Method TestAnIPv4MappedIPv6AddressIsUnwrapped()
{
    Do ..AssertKind("https://[::ffff:127.0.0.1]/v1", "loopback", "the dotted mapped form")
    Do ..AssertKind("https://[::ffff:7f00:1]/v1", "loopback", "the hexadecimal mapped form")
    Do ..AssertKind("https://[::ffff:169.254.169.254]/v1", "linklocal", "a mapped link-local address")
}

/// <p>AC4 -- link-local is refused <b>unconditionally</b>: no catalog row and no marked-local flag
/// opens it, in either family. <code>169.254.169.254</code> is the case FR-27 names, and no local
/// model lives in that range.</p>
/// <p>Mutation: move <code>linklocal</code> into the escapable branch of
/// <method>OcuPilot.Kernel.Egress.IsPermitted</method> -- the marked-local legs go red.</p>
Method TestLinkLocalHasNoEscape()
{
    For tUrl = "https://169.254.169.254/latest/meta-data", "https://[fe80::1]/v1", "https://[febf::1]/v1" {
        Do ..AssertKind(tUrl, "linklocal", "a link-local address")
        Do ..AssertPermitted(tUrl, 0, 0, 0, "link-local plain")
        Do ..AssertPermitted(tUrl, 1, 1, 0, "link-local marked local on a row that allows local")
    }
    ; fe7f:: is one group below the range and fec0:: one above it, so the bound is the ten bits
    ; fe80::/10 names rather than the whole fe00:: block.
    Do ..AssertKind("https://[fe7f::1]/v1", "public", "just below the link-local range")
    Do ..AssertKind("https://[fec0::1]/v1", "public", "just above it")
}

/// <p>AC4 -- one of this instance's own interface addresses is refused unless the definition is
/// marked local on a row that allows it.</p>
/// <p>The address is read from <code>GetInterfacesInfo()</code> rather than written down: the
/// container's own address is not a constant, and an assertion against a literal would pass on the
/// machine it was written on and nowhere else.</p>
Method TestTheInstancesOwnAddressIsRefused()
{
    Set tOwn = ..FirstInterfaceAddress()
    Do $$$AssertNotEquals(tOwn, "", "this instance reports at least one interface address: " _ tOwn)
    If tOwn = "" Quit
    ; Bracketed when it is an IPv6 address: unbracketed, the authority's first colon would be read
    ; as the port separator and this method would assert about a different host entirely -- the
    ; machine-dependent pass FirstInterfaceAddress exists to avoid.
    Set tUrl = "https://" _ $Select(tOwn [ ":": "[" _ tOwn _ "]", 1: tOwn) _ "/v1"
    Do ..AssertKind(tUrl, "instance", "the instance's own address")
    Do ..AssertPermitted(tUrl, 0, 0, 0, "the instance's own address without the escape")
    Do ..AssertPermitted(tUrl, 1, 1, 1, "the instance's own address marked local on a row that allows it")
}

/// <p>AC4 -- a host that resolves to nothing in either family is refused rather than called: a host
/// OcuPilot cannot resolve is one it cannot judge.</p>
/// <p>Probed: <code>HostNameToAddr</code> answers <code>""</code> for such a name and never
/// raises, so this is an ordinary classification and not an error path.</p>
Method TestAnUnresolvableHostIsRefused()
{
    Set tUrl = "https://" _ ..#UNRESOLVABLE _ "/v1"
    Do ..AssertKind(tUrl, "unresolvable", "a name nothing answers for")
    Do ..AssertPermitted(tUrl, 1, 1, 0, "and the local escape does not open it either")
}

/// <p>The control: a real public endpoint is permitted. Without it every refusal above would be
/// satisfied by a classifier that refused everything.</p>
Method TestAPublicEndpointIsPermitted()
{
    Do ..AssertKind("https://api.anthropic.com/v1/messages", "public", "the shipped endpoint")
    Do ..AssertPermitted("https://api.anthropic.com/v1/messages", 0, 0, 1, "the shipped endpoint needs no escape")
}

/// <p>AC4's field half -- the rule reports the address violations on <code>endpointUrl</code>, with
/// link-local told apart from the rest, and the local-unsupported violation on
/// <code>markedLocal</code>.</p>
Method TestTheRuleReportsTheRightCodeOnTheRightField()
{
    Do ..ProbeValues("probe-local", "https://127.0.0.1/v1", 0, .tLoopback)
    Do ..AssertViolation(.tLoopback, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTADDRESS, "a loopback endpoint not marked local")

    Do ..ProbeValues("probe-local", "https://169.254.169.254/v1", 1, .tLinkLocal)
    Do ..AssertViolation(.tLinkLocal, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTLINKLOCAL, "a link-local endpoint, marked local on a row that allows local")

    Do ..ProbeValues("anthropic", "https://api.anthropic.com/v1/messages", 1, .tUnsupported)
    Do ..AssertViolation(.tUnsupported, "markedLocal", ##class(OcuPilot.Api.Error).#AGENTLOCALUNSUPPORTED, "marked local on a provider whose row forbids it")

    Do ..ProbeValues("probe-local", "http://127.0.0.1:11434/v1/messages", 1, .tPlain)
    Set tCount = $ClassMethod(..#RULES, "Validate", .tPlain, "", .tViolations)
    Do $$$AssertEquals(tCount, 0, "a plain-HTTP loopback endpoint, marked local on a row that allows local, is accepted (" _ $ClassMethod(..#RULES, "ViolationsJson", .tViolations).%ToJSON() _ ")")

    Do ..ProbeValues("probe-local", "http://127.0.0.1:11434/v1/messages", 0, .tPlainUnmarked)
    Do ..AssertViolation(.tPlainUnmarked, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTSCHEME, "the same plain-HTTP endpoint without the marked-local flag")
}

/// <p>An endpoint whose host resolves to nothing is <b>accepted at write time</b>, and refused at
/// call time instead.</p>
/// <p>Whether a name resolves is a property of the resolver at that instant, not of the value the
/// operator typed: refusing on it would make the same endpoint acceptable or not depending on when
/// the form was submitted, and would refuse a name deliberately not yet resolvable from this
/// container. <class>OcuPilot.Test.ProviderPort</class> pins the call-time refusal that does
/// apply.</p>
/// <p>Mutation: report <code>unresolvable</code> as an address violation in
/// <method>OcuPilot.Kernel.AgentRules.AddressViolation</method> -- this goes red, and so do two of
/// <class>OcuPilot.Test.AgentRules</class>'s shipped endpoint assertions, whose hosts resolve to
/// nothing from this container.</p>
Method TestAnUnresolvableEndpointIsNotAWriteTimeViolation()
{
    Do ..ProbeValues("probe-local", "https://" _ ..#UNRESOLVABLE _ "/v1", 0, .tValues)
    Set tCount = $ClassMethod(..#RULES, "Validate", .tValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 0, "a host that resolves to nothing is accepted on the field (" _ $ClassMethod(..#RULES, "ViolationsJson", .tViolations).%ToJSON() _ ")")
    Do $$$AssertEquals($ClassMethod(..#EGRESS, "IsPermitted", "https://" _ ..#UNRESOLVABLE _ "/v1", 1, 1, .tKind), 0, "while the policy itself still refuses it, which is what the port reads at call time")
}

/// <p>A submission every other rule accepts, so a method below breaks exactly the one field it
/// names.</p>
ClassMethod ProbeValues(pProvider As %String, pEndpoint As %String, pMarkedLocal As %Boolean, Output pValues)
{
    Kill pValues
    Set pValues("name") = "OcuPilotProbeAgentEgress"
    Set pValues("provider") = pProvider
    Set pValues("model") = "probe-model-1"
    Set pValues("endpointUrl") = pEndpoint
    Set pValues("markedLocal") = pMarkedLocal
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOT_PROBE_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 8000
    Set pValues("temperature") = 0
    Set pValues("maxIterationsPerTurn") = 10
    Set pValues("systemPromptOverride") = ""
    Set pValues("readOnly") = 1
    Set pValues("retentionDays") = 30
    Set pValues("enabled") = 0
    Set pValues("connectionVerified") = 0
}

/// <p>Validate <var>pValues</var> and assert the outcome is exactly one violation, on
/// <var>pField</var>, carrying <var>pCode</var>.</p>
Method AssertViolation(ByRef pValues, pField As %String, pCode As %String, pWhat As %String)
{
    Set tCount = $ClassMethod(..#RULES, "Validate", .pValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 1, pWhat _ ": exactly one violation (" _ $ClassMethod(..#RULES, "ViolationsJson", .tViolations).%ToJSON() _ ")")
    If tCount '= 1 Quit
    Do $$$AssertEquals($List(tViolations(1), 1), pField, pWhat _ ": on the field " _ pField)
    Do $$$AssertEquals($List(tViolations(1), 2), pCode, pWhat _ ": with the code " _ pCode)
}

/// <p>The first address this instance's first interface carries, with any <code>/prefix</code>
/// stripped, or <code>""</code>.</p>
ClassMethod FirstInterfaceAddress() As %String
{
    Set tInfo = $System.INetInfo.GetInterfacesInfo()
    If tInfo = "" Quit ""
    Quit $Piece($Piece($Piece(tInfo, $Char(0), 1), $Char(1), 2), "/", 1)
}

}
