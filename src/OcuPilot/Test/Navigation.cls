/// <p>The privilege gate's set semantics (AD-8) and the classic-page union (AD-44), over
/// fixture descriptors.</p>
/// <p><b>Every answer here comes from a fixture seam, and that is deliberate.</b>
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which
/// <code>$System.Security.Check</code> answers yes to every resource name -- including one the
/// instance does not define, measured 2026-09-12 -- so no denial can be observed in process
/// against the real check. <class>OcuPilot.Test.ScreenGate</class> answers from a declared set
/// instead, which is what makes "all pairs required" and "the first failure is named"
/// falsifiable. The <i>real</i> check is exercised by <class>OcuPilot.Test.Wire</class>, over
/// the wire, as a throwaway principal holding exactly one administrative resource.</p>
/// <p><b>No custom resource is ever written to <class>%SYS.Portal.Resources</class>.</b> The
/// union is exercised through the same fixture's classic-resource seam; that store is empty on
/// this instance and stays so, and its write path is an operator's.</p>
Class OcuPilot.Test.Navigation Extends %UnitTest.TestCase
{

/// <p>The fixture descriptor whose privilege set holds two pairs and whose classic page is
/// named.</p>
Parameter GATEDSCREEN = "OcuPilot.Test.Screen.Gated";

/// <p>The classic page <parameter>GATEDSCREEN</parameter> declares.</p>
Parameter GATEDCLASSICPAGE = "OcuPilotTestClassicPageGated";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>AC2 -- a two-pair set is refused when <b>either</b> pair is missing and allowed only
/// with both, and the refusal names the pair that failed. One name is not enough on 2026.2:
/// the security APIs need <code>%DB_IRISSYS:READ</code> and <code>%Admin_Secure:USE</code>
/// together.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Gate.EvaluatePairs</method> return allowed as
/// soon as any one pair is held -> the two single-pair cases go red, while the both-held and
/// neither-held cases stay green, which is what shows the AND is what carries this.</p>
Method TestATwoPairSetIsRequiredWholeAndTheFailureIsNamed()
{
    Set tPairs = $ClassMethod(..#GATEDSCREEN, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tPairs), 2, "the descriptor declares two pairs")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).EvaluatePairs(tPairs, .tFailed), "holding neither pair is refused")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "naming the first pair that failed")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).EvaluatePairs(tPairs, .tFailed), "holding only the first pair is refused")
    Do $$$AssertEquals(tFailed, "%Admin_Secure:USE", "naming the one that is missing")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).EvaluatePairs(tPairs, .tFailed), "holding only the second pair is refused too")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "naming the other one")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).EvaluatePairs(tPairs, .tFailed), "holding both is allowed")
    Do $$$AssertEquals(tFailed, "", "and names nothing")
}

/// <p>The permission is part of the pair, not decoration: the same resource at a different
/// permission is a different requirement.</p>
Method TestThePermissionIsPartOfThePair()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).EvaluatePairs($ListBuild($ListBuild("%DB_IRISSYS", "READ")), .tFailed), "holding a resource at another permission is not holding the pair")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "and the refusal names the permission it wanted")
}

/// <p>An empty set is satisfied by everyone. That is how an area or a screen that never gates
/// is expressed, and it is why the rail's Home and Agent co-pilot items carry no second "never
/// gates" flag.</p>
Method TestAnEmptySetIsHeldByEveryone()
{
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).EvaluatePairs("", .tFailed), "an empty pair set is allowed")
    Do $$$AssertEquals(tFailed, "", "with nothing named")
}

/// <p>AC2, the union (AD-44) -- an operator who has assigned a custom resource to the classic
/// page a screen replaces has an expectation OcuPilot honours: the screen's requirement is its
/// declared set <b>plus</b> that resource at <code>USE</code>. An unassigned page reads
/// <code>""</code> and adds nothing.</p>
/// <p>The permission is <code>USE</code> because that is what the portal itself checks
/// (<file>irissys/%ZEN/Controller.cls</file>, read directly), and the store is keyed by the
/// normalized class name rather than by a URL.</p>
/// <p>Mutation: drop the union from <method>OcuPilot.Screen.Gate.RequiredPairs</method> -> the
/// assigned case goes red, because the caller holding both declared pairs is then allowed
/// through a resource the operator meant to gate on.</p>
Method TestTheClassicPagesCustomResourceIsUnionedOn()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")

    Set tUnassigned = ##class(OcuPilot.Test.ScreenGate).RequiredPairs(..#GATEDSCREEN)
    Do $$$AssertEquals($ListLength(tUnassigned), 2, "an unassigned classic page adds nothing")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate(..#GATEDSCREEN, .tFailed), "so the declared pairs alone admit the caller")

    Do ##class(OcuPilot.Test.ScreenGate).AssignClassic(..#GATEDCLASSICPAGE, "OcuPilotTestCustomResource")
    Set tAssigned = ##class(OcuPilot.Test.ScreenGate).RequiredPairs(..#GATEDSCREEN)
    Do $$$AssertEquals($ListLength(tAssigned), 3, "an assigned one is unioned onto the declared set")
    Do $$$AssertEquals($List($List(tAssigned, 3), 1), "OcuPilotTestCustomResource", "as the operator's resource")
    Do $$$AssertEquals($List($List(tAssigned, 3), 2), "USE", "at the permission the portal itself checks")

    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate(..#GATEDSCREEN, .tFailed), "and the same caller is now refused")
    Do $$$AssertEquals(tFailed, "OcuPilotTestCustomResource:USE", "naming the operator's own resource")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("OcuPilotTestCustomResource", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate(..#GATEDSCREEN, .tFailed), "until they hold it too")
}

/// <p>The union is keyed by the descriptor's <b>own</b> classic page: an assignment on another
/// page adds nothing, and a screen that declares no page is never looked up at all.</p>
Method TestTheUnionIsKeyedByTheDescriptorsOwnClassicPage()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).ClassicResource(""), "", "a screen with no classic page is never looked up")

    Do ##class(OcuPilot.Test.ScreenGate).AssignClassic(..#GATEDCLASSICPAGE, "OcuPilotTestCustomResource")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Test.ScreenGate).RequiredPairs("OcuPilot.Screen.Descriptor.Home")), 0, "an assignment on another page adds nothing to Home, which declares none of its own")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Test.ScreenGate).RequiredPairs(..#GATEDSCREEN)), 3, "while the screen whose page it names takes it on")
}

/// <p>DW-9, the server half -- the gate is recomputed from live state on every call and holds
/// nothing from the last one. The same target, asked twice with the privilege set changed in
/// between, answers differently.</p>
/// <p>Mutation: memoise <method>OcuPilot.Screen.Gate.Evaluate</method>'s answer per target ->
/// the second half goes red, because a revoked privilege would keep reading as held.</p>
Method TestTheGateRecomputesRatherThanCaching()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate(..#GATEDSCREEN, .tFailed), "the caller is allowed while holding both pairs")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate(..#GATEDSCREEN, .tFailed), "and refused the moment one is revoked, with no reload and no second call shape")
    Do $$$AssertEquals(tFailed, "%Admin_Secure:USE", "naming the pair that was taken away")
}

/// <p>An area key and a descriptor class name are the two things the gate accepts, and a
/// target that is neither is refused rather than admitted. A gate that opened on a typo would
/// be worse than one that refuses a valid target.</p>
Method TestAnUnresolvableTargetIsRefused()
{
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("OcuPilot.Screen.Descriptor.NoSuchScreen", .tFailed), "a class that does not exist is refused")
    Do $$$AssertEquals(tFailed, "", "with no requirement to name")
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("no-such-area", .tFailed), "and so is an area key that is not declared")
}

/// <p>A requirement that could not be read is not an empty requirement. A compiled class that
/// is not a descriptor carries no declaration, and an empty pair set is held by everyone -- so
/// reading the failure as an empty set is a gate that opens on anything that compiles.</p>
/// <p>Mutation: have <method>OcuPilot.Screen.Gate.RequiredPairs</method> report
/// <var>pResolved</var> 1 on its <code>Catch</code> path -> every assertion here goes red with
/// the target allowed.</p>
Method TestAClassThatIsNotADescriptorIsRefusedRatherThanAdmitted()
{
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("%Library.File", .tFailed), "a compiled class that is no descriptor is refused, not admitted")
    Do $$$AssertEquals(tFailed, "", "with no requirement to name")
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("OcuPilot.Api.Router", .tFailed), "including one of this project's own non-descriptor classes")
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("OcuPilot.Screen.Descriptor.Base", .tFailed), "and the abstract base, which declares no screen")

    Set tResolved = "unset"
    Do ##class(OcuPilot.Test.ScreenGate).RequiredPairs("%Library.File", .tResolved)
    Do $$$AssertEquals(tResolved, 0, "the requirement reports that it could not be read")
    Set tResolved = "unset"
    Do ##class(OcuPilot.Test.ScreenGate).RequiredPairs(..#GATEDSCREEN, .tResolved)
    Do $$$AssertEquals(tResolved, 1, "while a real descriptor's requirement resolves")
}

/// <p>A declared pair missing its resource or its permission is refused by the registry. It is
/// dropped rather than carried everywhere else, so without this refusal a descriptor that
/// misspells <code>permission</code> declares a gate and ships ungated.</p>
/// <p>Mutation: spell the fixture's key <code>permission</code> -> the refusal assertions go
/// red, because the roster becomes sound.</p>
Method TestAMalformedPrivilegePairIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.PairRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster whose declared pair is missing a half is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Pair.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ "missing its resource or its permission", "and says what is wrong with it")

    ; The same declaration, read the way the gate reads it, yields no pairs at all -- which is
    ; the ungated screen the refusal above exists to prevent.
    Do $$$AssertEquals($ListLength($ClassMethod("OcuPilot.Test.Pair.Bad", "PrivilegePairs")), 0, "the malformed pair contributes nothing to the requirement")
}

/// <p>AD-8 as amended for DW-1768: an area opens when any screen its side bar lists is allowed, and
/// each screen keeps its own gate. Driven through the fixture seam over the shipped areas and
/// descriptors: a holder of <code>%Operator</code>'s grants opens Logs, OS management, Tasks and
/// Web applications and is still refused the audit database viewer and the processes list; a holder
/// of only a wallet or only the OAuth 2.0 client resource opens Security and secrets and is still
/// refused SSL/TLS; a holder of nothing opens only the two areas that never gate, each other area
/// naming the first pair of its declared set.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.EvaluateArea</method> answer
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> over the area's declared set -- the all-pairs
/// rule -- and recompile the package -> the <code>%Operator</code>, wallet and OAuth 2.0 area rows go
/// red, while the screen rows and the holder-of-nothing rows stay green.</p>
Method TestAnAreaOpensWhenAnyScreenItListsIsAllowed()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Set tDescriptor = "OcuPilot.Screen.Descriptor."

    ; Nothing held: the two areas that declare no pair never gate, and every other area is refused
    ; on the first pair of its declared set.
    Set tExpected = "home=open logs=%Admin_Operate:USE os-management=%Admin_Operate:USE tasks=%Admin_Task:USE permissions=%Admin_Secure:USE web-applications=%Admin_Secure:USE security=%Admin_Secure:USE system-explorer=%Development:USE agent=open"
    Do $$$AssertEquals(..AreaVerdicts(), tExpected, "a holder of nothing opens Home and Agent co-pilot alone, each other area naming its set's first pair")

    ; %Operator's six grants on a stock instance: %Admin_Operate:U, %DB_IRISLOCALDATA:R,
    ; %DB_IRISSYS:RW, %DB_IRISTEMP:RW, %Service_DocDB:U and %Service_WebGateway:U.
    Do $ClassMethod(tGate, "Hold", "%Admin_Operate", "USE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISLOCALDATA", "READ")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "WRITE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISTEMP", "READ")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISTEMP", "WRITE")
    Do $ClassMethod(tGate, "Hold", "%Service_DocDB", "USE")
    Do $ClassMethod(tGate, "Hold", "%Service_WebGateway", "USE")
    Set tExpected = "home=open logs=open os-management=open tasks=open permissions=%Admin_Secure:USE web-applications=open security=%Admin_Secure:USE system-explorer=%Development:USE agent=open"
    Do $$$AssertEquals(..AreaVerdicts(), tExpected, "%Operator's grants open Logs, OS management, Tasks and Web applications, and not Permissions or Security")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "LogMessageViewer"), "open", "messages.log opens for them")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "AuditList"), "%Admin_Secure:USE", "while the audit database viewer keeps its own gate")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "LogEventViewer"), "%Ens_EventLog:USE", "and so does the interoperability event log")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "LockList"), "open", "Locks opens for them")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "ProcessList"), "%Admin_Manage:USE", "while Processes keeps its own gate")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "TaskScheduleList"), "%Admin_Task:USE", "and so does the task schedule, inside the Tasks area Background tasks opens")

    ; A wallet holder and an OAuth 2.0 holder, each with the database read and no %Admin_Secure.
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Admin_Wallet", "USE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", "security", .tFailed), "a wallet holder opens Security and secrets")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "WalletCollectionList"), "open", "and its Wallet list")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "SslConfigList"), "%Admin_Secure:USE", "and is refused SSL/TLS on its own gate")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "OAuthServerDescriptionTab"), "%Admin_OAuth2_Client:USE", "and OAuth 2.0 on its own")

    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Admin_OAuth2_Client", "USE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", "security", .tFailed), "an OAuth 2.0 client holder opens Security and secrets")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "OAuthServerDescriptionTab"), "open", "and its OAuth 2.0 entry")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "WalletCollectionList"), "%Admin_Wallet:USE", "and is refused the Wallet list on its own gate")
    Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "SslConfigList"), "%Admin_Secure:USE", "and SSL/TLS on its own")
}

/// <p>AD-8 as amended for DW-1852: a listed tab group opens its area through any of its tabs, and
/// each tab keeps its own gate. A holder of only the OAuth 2.0 authorization-server or registration
/// resource, with <code>%DB_IRISSYS:READ</code>, opens Security and secrets and its OAuth 2.0 entry
/// while the listed tab and the client configurations tab stay refused on
/// <code>%Admin_OAuth2_Client:USE</code>; without the database read nothing opens and the area names
/// its set's first pair. <method>OcuPilot.Screen.Registry.TabMembersFor</method> answers the group's
/// other tabs in strip order for its head and nothing for any other screen.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.EvaluateArea</method> call
/// <method>OcuPilot.Screen.Gate.Evaluate</method> instead of
/// <method>OcuPilot.Screen.Gate.EvaluateEntry</method> -- the listed tab alone counts -- and recompile
/// the package -> the two area rows go red while the screen rows stay green.</p>
Method TestATabGroupOpensItsAreaThroughAnyOfItsTabs()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Set tDescriptor = "OcuPilot.Screen.Descriptor."
    Set tSC = ##class(OcuPilot.Screen.Registry).TabMembersFor(tDescriptor _ "OAuthServerDescriptionTab", .tMembers)
    Do $$$AssertStatusOK(tSC, "the OAuth 2.0 group's tabs read")
    Do $$$AssertEquals($ListToString(tMembers), tDescriptor _ "OAuthClientTab," _ tDescriptor _ "OAuthResourceServerTab," _ tDescriptor _ "OAuthServerTab," _ tDescriptor _ "OAuthServerClientTab", "the listed tab heads four others, in strip order")
    Set tSC = ##class(OcuPilot.Screen.Registry).TabMembersFor(tDescriptor _ "OAuthServerTab", .tMembers)
    Do $$$AssertStatusOK(tSC, "a tab's own members read")
    Do $$$AssertEquals($ListLength(tMembers), 0, "a tab under another's group heads none")
    Set tSC = ##class(OcuPilot.Screen.Registry).TabMembersFor(tDescriptor _ "SslConfigList", .tMembers)
    Do $$$AssertStatusOK(tSC, "and so do a screen's that is no tab")
    Do $$$AssertEquals($ListLength(tMembers), 0, "which heads none either")

    For tCase = $ListBuild("%Admin_OAuth2_Server", "OAuthServerTab"), $ListBuild("%Admin_OAuth2_Registration", "OAuthServerClientTab") {
        Set tResource = $List(tCase, 1)
        Do $ClassMethod(tGate, "Reset")
        Do $ClassMethod(tGate, "Hold", tResource, "USE")
        Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
        Set tFailed = "unset"
        Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", "security", .tFailed), "a holder of " _ tResource _ " opens Security and secrets: " _ tFailed)
        Do $$$AssertEquals(tFailed, "", "naming nothing")
        Set tFailed = "unset"
        Do $$$AssertTrue($ClassMethod(tGate, "EvaluateEntry", tDescriptor _ "OAuthServerDescriptionTab", .tFailed), "and its OAuth 2.0 entry")
        Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ $List(tCase, 2)), "open", "its own tab opens")
        Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "OAuthServerDescriptionTab"), "%Admin_OAuth2_Client:USE", "while the listed tab keeps its own gate")
        Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "OAuthClientTab"), "%Admin_OAuth2_Client:USE", "and so does the client configurations tab")
        Do $$$AssertEquals(..ScreenVerdict(tDescriptor _ "SslConfigList"), "%Admin_Secure:USE", "and SSL/TLS")

        Do $ClassMethod(tGate, "Reset")
        Do $ClassMethod(tGate, "Hold", tResource, "USE")
        Set tFailed = "unset"
        Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "security", .tFailed), "without %DB_IRISSYS:READ a holder of " _ tResource _ " opens nothing there")
        Do $$$AssertEquals(tFailed, "%Admin_Secure:USE", "and the area names its set's first pair")
        Set tFailed = "unset"
        Do $$$AssertTrue('$ClassMethod(tGate, "EvaluateEntry", tDescriptor _ "OAuthServerDescriptionTab", .tFailed), "nor the OAuth 2.0 entry")
        Do $$$AssertEquals(tFailed, "%Admin_OAuth2_Client:USE", "which names its listed tab's failed pair")
    }

    ; A group whose tabs cannot be read refuses, even to a holder of one of them.
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Admin_OAuth2_Server", "USE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Do $ClassMethod(tGate, "ArmTabMembersFailure", tDescriptor _ "OAuthServerDescriptionTab")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "EvaluateEntry", tDescriptor _ "OAuthServerDescriptionTab", .tFailed), "a tab roster that cannot be read opens no entry")
    Do $$$AssertEquals(tFailed, "%Admin_OAuth2_Client:USE", "naming the listed tab's own pair")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "security", .tFailed), "and no area")
}

/// <p>AD-8 as amended for DW-1768: an area none of whose listed screens opens names the first pair
/// of its declared set the caller lacks, and, when the caller holds that whole set, the first failed
/// pair a listed screen names. In every shipped area the first listed screen fails on the pair its
/// area names for a caller who opens nothing there, so the first arm is told apart over an armed
/// roster whose first screen needs another resource; the second arm is reached through the classic-page union (AD-44): a holder of
/// Permissions' two pairs whose every listed screen's classic page carries a custom resource.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.EvaluateArea</method> always name the
/// first failed pair a listed screen names -> the armed-roster arm goes red. Drop its fallback so a
/// caller holding the whole set is named nothing -> the classic-page arm goes red.</p>
Method TestAGatedAreaNamesItsSetsFirstUnheldPairThenItsFirstListedScreens()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "ArmListed", "logs", "OcuPilot.Screen.Descriptor.LogEventViewer,OcuPilot.Screen.Descriptor.AuditList")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "logs", .tFailed), "a Logs roster led by the event log opens nothing for a holder of nothing")
    Do $$$AssertEquals(tFailed, "%Admin_Operate:USE", "and the area names its own set's first pair, not the %Ens_EventLog:USE its first screen fails on")

    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Admin_Secure", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "permissions", .tFailed), "%Admin_Secure alone opens no Permissions screen")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "and the area names the one pair of its set still unheld")

    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Screen.Registry).ListedScreensForArea("permissions", .tListed)
    Do $$$AssertStatusOK(tSC, "the Permissions side bar reads")
    Do $$$AssertEquals($ListLength(tListed), 4, "and lists its four screens")
    For tI = 1:1:$ListLength(tListed) {
        Set tPage = $ClassMethod($List(tListed, tI), "ClassicPage")
        Do $$$AssertTrue(tPage '= "", $List(tListed, tI) _ " replaces a classic page")
        Do $ClassMethod(tGate, "AssignClassic", tPage, "OcuPilotTestCustom" _ tI)
    }
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "permissions", .tFailed), "with every listed screen's classic page carrying a custom resource, the whole set opens none")
    Do $$$AssertEquals(tFailed, "OcuPilotTestCustom1:USE", "and the area names its first listed screen's failed pair")
}

/// <p>An area that lists no screen is answered by its declared set alone, as its Home tile expects;
/// an area whose roster cannot be read is refused naming nothing, even to a holder of its set; and a
/// key the area vocabulary does not declare is refused by
/// <method>OcuPilot.Screen.Gate.EvaluateArea</method> itself, naming nothing.</p>
/// <p>Mutation (Rule 19): drop the no-screen branch from <method>OcuPilot.Screen.Gate.EvaluateArea</method>
/// -> the holder-of-the-set row goes red. Answer a roster failure from the declared set -> the
/// roster-failure row goes red. Drop its vocabulary check -> the unknown-key row goes red.</p>
Method TestAnAreaListingNoScreenIsAnsweredByItsSet()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "ArmListed", "tasks", "")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "tasks", .tFailed), "a Tasks area listing no screen is refused to a holder of nothing")
    Do $$$AssertEquals(tFailed, "%Admin_Task:USE", "naming its set's first pair")
    Do $ClassMethod(tGate, "Hold", "%Admin_Task", "USE")
    Do $ClassMethod(tGate, "Hold", "%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", "tasks", .tFailed), "and opens for a holder of its set: " _ tFailed)

    Do $ClassMethod(tGate, "ArmListedFailure", "tasks")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", "tasks", .tFailed), "a Tasks area whose roster cannot be read is refused to a holder of its set")
    Do $$$AssertEquals(tFailed, "", "naming nothing")

    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "EvaluateArea", "no-such-area", .tFailed), "an undeclared area key is refused")
    Do $$$AssertEquals(tFailed, "", "naming nothing")
}

/// <p>Every area's verdict through <class>OcuPilot.Test.ScreenGate</class>, in rail order, as
/// <code>key=open</code> or <code>key=failedPair</code>.</p>
ClassMethod AreaVerdicts() As %String
{
    Set tOut = ""
    For tArea = "home", "logs", "os-management", "tasks", "permissions", "web-applications", "security", "system-explorer", "agent" {
        Set tFailed = ""
        Set tAllowed = ##class(OcuPilot.Test.ScreenGate).Evaluate(tArea, .tFailed)
        Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tArea _ "=" _ $Select(tAllowed: "open", 1: tFailed)
    }
    Quit tOut
}

/// <p>One descriptor's verdict through <class>OcuPilot.Test.ScreenGate</class>: <code>open</code>, or
/// its failed pair.</p>
ClassMethod ScreenVerdict(pDescriptor As %String) As %String
{
    Set tFailed = ""
    Set tAllowed = ##class(OcuPilot.Test.ScreenGate).Evaluate(pDescriptor, .tFailed)
    Quit $Select(tAllowed: "open", 1: tFailed)
}

/// <p>The navigation payload's shape: every area in declared order, each with an
/// <code>allowed</code> verdict, its built screens, and <b>no</b> <code>failedPair</code> key
/// when the answer is yes -- an allowed entry carrying an empty reason would read as a denial
/// with nothing said. The denied shape is asserted over the wire by
/// <class>OcuPilot.Test.Wire</class>, which is the only place a principal without
/// <code>%All</code> evaluates the real check.</p>
/// <p><b>The os-management and logs rosters below are pinned by literal index and count,
/// deliberately</b> -- it is what catches a screen landing at the wrong
/// <code>sideBarPosition</code>, which a pin derived from the roster could not. Adding, removing or
/// reordering a <b>built</b> <code>Screen/Descriptor/*.cls</code> in either area therefore requires
/// updating that area's count and per-index assertions with it.</p>
Method TestThePayloadCarriesEveryAreaWithAVerdict()
{
    Set tSC = ##class(OcuPilot.Api.Navigation).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.areas.%Size(), 9, "every area is emitted, never a partial list")

    Set tIterator = tObject.areas.%GetIterator()
    Set tPosition = 0
    While tIterator.%GetNext(.tIndex, .tArea) {
        Set tPosition = tPosition + 1
        Do $$$AssertEquals(+tArea.railPosition, tPosition, "areas are emitted in declared rail order")
        Do $$$AssertEquals(tArea.allowed, 1, "and this suite's account holds everything, so each is allowed")
        Do $$$AssertTrue('tArea.%IsDefined("failedPair"), "the key is omitted on an allowed entry, not sent empty")
        Do $$$AssertTrue(tArea.labelKey '= "", "each names the string key its rail item renders")

        ; The per-screen half, which is what the client keys screenVerdict on. Asserted here
        ; because Payload writes its own screen objects rather than passing Roster's through.
        Do $$$AssertTrue($IsObject(tArea.screens), "every area carries a screens array, even when it is empty")
        Set tScreenIterator = tArea.screens.%GetIterator()
        While tScreenIterator.%GetNext(.tScreenIndex, .tScreen) {
            Do $$$AssertTrue(tScreen.%IsDefined("route"), "each screen entry names the route the client looks it up by")
            Do $$$AssertTrue(tScreen.labelKey '= "", "and the string key its side-bar entry renders")
            Do $$$AssertEquals(tScreen.allowed, 1, "and carries its own verdict")
        }
    }

    ; Home's area carries its one built screen, so the screen half is not vacuously empty.
    Set tHome = tObject.areas.%Get(0)
    Do $$$AssertEquals(tHome.key, "home", "the first area is Home")
    Do $$$AssertEquals(tHome.screens.%Size(), 1, "carrying its one built screen")
    Do $$$AssertEquals(tHome.screens.%Get(0).route, "", "whose route is the application root")

    ; OS management proves the screen half follows the roster rather than a fixed list: it
    ; carries its thirty-five built screens sorted by (sideBarPosition, class name) -- ScreensForArea's
    ; own collation (Registry.cls) -- so the twenty-two unlisted, sideBarPosition-0 screens sort first,
    ; alphabetically by descriptor class name (Database details, Database free-space, Check
    ; integrity, Database volumes, the device editor, the global mapping editor and
    ; list, the journal file databases and details, External language servers' Activity log and editor, License usage's three unlisted tabs,
    ; the local database editor, the namespace editor, the package mapping editor and list, Process
    ; details, the remote database form, then the routine mapping editor and list), ahead of the listed
    ; ones in position order
    ; (Processes, Locks, System usage, Databases, the Integrity log at position 5, Devices, Namespaces,
    ; License usage, the Dashboard at position 9, External language servers at position 10, Local
    ; databases at position 11, Remote databases at position 12, and Journals last at position 13).
    ; Story 6.11 took this from four to eight, Story 6.12 to nine, Story 8.8 to ten, Story 18.2 to
    ; twelve, Story 18.14 to eighteen, Story 16.7 to twenty-three, Story 18.3 to twenty-five, Story
    ; 16.10 to twenty-seven, its unlisted Activity log sorting between the global mappings list and
    ; License usage's tabs, Story 18.4 to twenty-nine, its Check integrity and Integrity log sorting
    ; between Database free-space and Database volumes, and Story 16.25 to thirty, its editor sorting
    ; after the Activity log, and Story 18.16 to thirty-two, its form sorting after Process details,
    ; and Story 18.5 to thirty-five, its two unlisted journal screens sorting after the global
    ; mappings list and Journals last at position 13; an
    ; added os-management screen updates this count and the per-index
    ; assertions below with it.
    ; Story 18.18 took it to thirty-six, Journal settings listed last at position 14.
    ; Story 18.19 took it to thirty-seven, the unlisted Journal records sorting after journal file details.
    Set tOsMgmt = ##class(OcuPilot.Test.Descriptor).AreaEntry(tObject.areas, "os-management")
    Do $$$AssertTrue($IsObject(tOsMgmt), "the payload carries the os-management area")
    If $IsObject(tOsMgmt) {
        Do $$$AssertEquals(tOsMgmt.screens.%Size(), 37, "which carries its thirty-seven built screens -- an added os-management screen updates this count and the per-index assertions below with it")
        Set tExpected = $ListBuild($ListBuild("os-management/databases/details", "databaseDetailsLabel", "the unlisted database details, first alphabetically among sideBarPosition 0"), $ListBuild("os-management/database-free-space", "databaseFreeSpaceLabel", "then the unlisted free-space view"), $ListBuild("os-management/databases/integrity", "databaseIntegrityLabel", "then the unlisted Check integrity flow"), $ListBuild("os-management/databases/volumes", "databaseVolumeListLabel", "then the unlisted volume files"), $ListBuild("os-management/devices/edit", "deviceFormLabel", "then the unlisted device editor"), $ListBuild("os-management/namespaces/global-mappings/edit", "globalMappingFormLabel", "then the unlisted global mapping editor"), $ListBuild("os-management/namespaces/global-mappings", "globalMappingListLabel", "then the unlisted global mappings list"), $ListBuild("os-management/journals/databases", "journalFileDatabaseListLabel", "then the unlisted journal file databases"), $ListBuild("os-management/journals/details", "journalFileDetailsLabel", "then the unlisted journal file details"), $ListBuild("os-management/journal-records", "journalRecordListLabel", "then the unlisted journal records"), $ListBuild("os-management/language-servers/activity", "languageServerActivityLabel", "then the unlisted Activity log of External language servers"), $ListBuild("os-management/language-servers/edit", "languageServerFormLabel", "then the unlisted external language server editor"), $ListBuild("os-management/license-usage/distributed", "licenseUsageDistributed", "then License usage's unlisted Distributed tab"), $ListBuild("os-management/license-usage/processes", "licenseUsageByProcess", "then its unlisted By process tab"), $ListBuild("os-management/license-usage/users", "licenseUsageByUser", "then its unlisted By user tab"), $ListBuild("os-management/local-databases/edit", "systemInfoDatabase", "then the unlisted local database editor"), $ListBuild("os-management/namespaces/edit", "headerNamespaceLabel", "then the unlisted namespace editor"), $ListBuild("os-management/namespaces/package-mappings/edit", "packageMappingFormLabel", "then the unlisted package mapping editor"), $ListBuild("os-management/namespaces/package-mappings", "packageMappingListLabel", "then the unlisted package mappings list"), $ListBuild("os-management/processes/details", "processDetailsLabel", "then the unlisted process details"), $ListBuild("os-management/remote-databases/edit", "remoteDatabaseFormLabel", "then the unlisted remote database form"), $ListBuild("os-management/namespaces/routine-mappings/edit", "routineMappingFormLabel", "then the unlisted routine mapping editor"), $ListBuild("os-management/namespaces/routine-mappings", "routineMappingListLabel", "then the unlisted routine mappings list, last alphabetically among sideBarPosition 0"), $ListBuild("os-management/processes", "processListLabel", "then the processes list, position 1"), $ListBuild("os-management/locks", "lockListLabel", "then Locks, position 2"), $ListBuild("os-management/system-usage", "systemUsageLabel", "then system usage, position 3"), $ListBuild("os-management/databases", "databaseListLabel", "then Databases, position 4"), $ListBuild("os-management/databases/integrity-log", "databaseIntegrityLogLabel", "then the Integrity log, position 5"), $ListBuild("os-management/devices", "deviceListLabel", "then Devices, position 6"), $ListBuild("os-management/namespaces", "namespaceListLabel", "then Namespaces, position 7"), $ListBuild("os-management/license-usage", "licenseUsageLabel", "then License usage, position 8"), $ListBuild("os-management/dashboard", "dashboardLabel", "then the Dashboard, position 9"), $ListBuild("os-management/language-servers", "languageServersLabel", "then External language servers, position 10"), $ListBuild("os-management/local-databases", "localDatabaseListLabel", "then Local databases, position 11"), $ListBuild("os-management/remote-databases", "remoteDatabaseListLabel", "then Remote databases, position 12"), $ListBuild("os-management/journals", "journalListLabel", "and Journals last, position 13"))
        Set tExpected = tExpected _ $ListBuild($ListBuild("os-management/journal-settings", "journalSettingsLabel", "and Journal settings last, at position 14"))
        For tI = 1:1:$ListLength(tExpected) {
            Set tRow = $List(tExpected, tI)
            Do $$$AssertEquals(tOsMgmt.screens.%Get(tI - 1).route, $List(tRow, 1), $List(tRow, 3))
            Do $$$AssertEquals(tOsMgmt.screens.%Get(tI - 1).labelKey, $List(tRow, 2), "under its own label key")
        }
    }

    ; Logs, pinned the same way and for the same reason: its screens declare consecutive side-bar
    ; positions, so a screen landing on the wrong one is only visible as an order. Story 16.8 took
    ; it from four screens to ten, the six secondary logs at positions 5 to 10, and Story 16.9 to
    ; eleven, the log hub at 11; an added Logs screen updates this count and the per-index
    ; assertions with it.
    Set tLogs = ##class(OcuPilot.Test.Descriptor).AreaEntry(tObject.areas, "logs")
    Do $$$AssertTrue($IsObject(tLogs), "the payload carries the logs area")
    If $IsObject(tLogs) {
        Do $$$AssertEquals(tLogs.screens.%Size(), 11, "which carries its eleven built screens -- an added Logs screen updates this count and the per-index assertions below with it")
        Set tOrder = $ListBuild("logs/alerts|alertLogListLabel", "logs/messages|messagesLogListLabel", "logs/errors|errorLogListLabel", "logs/audit|auditListLabel", "logs/systemmonitor|systemMonitorLogListLabel", "logs/taskerrors|taskErrorLogListLabel", "logs/xdbc|xdbcErrorLogListLabel", "logs/sqldiagnostics|sqlDiagnosticsLogListLabel", "logs/eventlog|eventLogListLabel", "logs/analytics|analyticsLogListLabel", "logs/hub|logHubLabel")
        For tAt = 1:1:$ListLength(tOrder) {
            Set tScreen = tLogs.screens.%Get(tAt - 1)
            Do $$$AssertEquals($Select($IsObject(tScreen): tScreen.route _ "|" _ tScreen.labelKey, 1: ""), $List(tOrder, tAt), "logs position " _ tAt _ " is its declared screen, under its own label key")
        }
    }
}

}
