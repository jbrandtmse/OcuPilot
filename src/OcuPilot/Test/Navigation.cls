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

/// <p>An area's own set is evaluated the same way a screen's is, and a denial names its pair.
/// This is what Home's tile grid gates on (Story 1.12) and what the rail item carries as its
/// reason. Every gated area needs <code>%DB_IRISSYS:READ</code> as well as its own administrative
/// resource, as every screen in it does -- Logs included since Story 2.10, whose audit database
/// viewer is the area's first screen with an admin API endpoint behind it.</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from the <code>permissions</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the "%Admin_Secure alone" assertions go red; drop it from
/// <code>tasks</code> -> the "%Admin_Task alone" assertion goes red; drop
/// <code>%Admin_Manage:USE</code> from <code>os-management</code> -> the "%Admin_Operate alone"
/// assertion goes red naming the database read instead, while the <code>logs</code> one keeps
/// naming <code>%Admin_Secure:USE</code>, which is what separates the two areas on the resource
/// they share.</p>
Method TestAnAreaGatesOnItsOwnDeclaredSet()
{
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("permissions", .tFailed), "an area whose pair is not held is refused")
    Do $$$AssertEquals(tFailed, "%Admin_Secure:USE", "naming the pair")

    ; Logs from nothing held: %Admin_Operate:USE is what it declares first, and it is the pair the
    ; audit viewer's own async-result poll requires (AD-26). Asserted here, before anything is
    ; held, because every later step in this method holds more.
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("logs", .tFailed), "logs is refused with nothing held")
    Do $$$AssertEquals(tFailed, "%Admin_Operate:USE", "naming the pair it declares first")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    For tArea = "permissions", "web-applications", "security" {
        Set tFailed = "unset"
        Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate(tArea, .tFailed), tArea _ ": %Admin_Secure alone is refused")
        Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", tArea _ ": %Admin_Secure alone is refused naming the system database read")
    }

    ; Tasks takes a different administrative resource and the same database read, so holding the
    ; first alone is refused on the second -- the pair order the wire fixtures pin.
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Task", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("tasks", .tFailed), "tasks: %Admin_Task alone is refused")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "tasks: naming the system database read")

    ; OS management and Logs both name %Admin_Operate first, and holding it alone opens neither.
    ; OS management wants two more -- %Admin_Manage:USE, which the CONTROLPANEL query behind its
    ; first screen checks for itself, then the database read (Story 2.9); Logs wants
    ; %Admin_Secure:USE, its audit viewer's own endpoint gate, then the same database read (Story
    ; 2.10). Each is named in declared order as it is held, which is the whole of what "the gate
    ; names the FIRST unheld pair" means -- and the two areas are separated by which pair they name
    ; from the same starting point.
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("os-management", .tFailed), "os-management: %Admin_Operate alone is refused")
    Do $$$AssertEquals(tFailed, "%Admin_Manage:USE", "os-management: naming the query's own resource, not the database read behind it")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("logs", .tFailed), "logs: refused too, since Story 2.10 -- %Admin_Operate no longer opens it alone")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "logs: naming the one pair of its three still unheld here, the audit endpoint's own %Admin_Secure:USE being held above")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.ScreenGate).Evaluate("os-management", .tFailed), "os-management: two of its three pairs is still refused")
    Do $$$AssertEquals(tFailed, "%DB_IRISSYS:READ", "os-management: now naming the system database read")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("logs", .tFailed), "and the logs area is admitted once its three are held")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("tasks", .tFailed), "and the tasks area is admitted once both are held")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("os-management", .tFailed), "and so is the os-management area")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("permissions", .tFailed), "and admitted once both are held")

    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("home", .tFailed), "while Home never gates")
    Do $$$AssertTrue(##class(OcuPilot.Test.ScreenGate).Evaluate("agent", .tFailed), "and neither does the agent rail item")
}

/// <p>The navigation payload's shape: every area in declared order, each with an
/// <code>allowed</code> verdict, its built screens, and <b>no</b> <code>failedPair</code> key
/// when the answer is yes -- an allowed entry carrying an empty reason would read as a denial
/// with nothing said. The denied shape is asserted over the wire by
/// <class>OcuPilot.Test.Wire</class>, which is the only place a principal without
/// <code>%All</code> evaluates the real check.</p>
Method TestThePayloadCarriesEveryAreaWithAVerdict()
{
    Set tSC = ##class(OcuPilot.Api.Navigation).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.areas.%Size(), 8, "every area is emitted, never a partial list")

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

    ; OS management is the area Story 2.9 gave its first screen to, so it is the one that proves
    ; the screen half follows the roster rather than a fixed list: it answered an empty array
    ; through Epic 1 and four stories of Epic 2, and answers two entries now -- Story 6.8's
    ; unlisted Process details sorts first at sideBarPosition 0, ahead of the processes list.
    Set tOsMgmt = ##class(OcuPilot.Test.Descriptor).AreaEntry(tObject.areas, "os-management")
    Do $$$AssertTrue($IsObject(tOsMgmt), "the payload carries the os-management area")
    If $IsObject(tOsMgmt) {
        Do $$$AssertEquals(tOsMgmt.screens.%Size(), 2, "which now carries its two built screens")
        Do $$$AssertEquals(tOsMgmt.screens.%Get(0).route, "os-management/processes/details", "the unlisted process details")
        Do $$$AssertEquals(tOsMgmt.screens.%Get(0).labelKey, "processDetailsLabel", "under its own label key")
        Do $$$AssertEquals(tOsMgmt.screens.%Get(1).route, "os-management/processes", "then the processes list")
        Do $$$AssertEquals(tOsMgmt.screens.%Get(1).labelKey, "processListLabel", "under its own label key")
    }
}

}
