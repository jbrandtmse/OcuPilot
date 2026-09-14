/// <p>The declaration contract (AD-5): one descriptor is the source of a screen's route, its
/// navigation entry and its privilege gate, and it can express the three awkward forms the
/// mechanism has to carry -- several entity types, a sub-resource's parent, and a composite
/// id -- plus a tool identity that is not derived from either.</p>
/// <p>The production roster holds Home and the web applications list, so the awkward forms are
/// exercised over fixture descriptors under <code>OcuPilot.Test.Screen.</code>, enumerated by
/// <class>OcuPilot.Test.ScreenRegistry</class>. The real roster is asserted here too -- it is
/// what the shell serves -- but it cannot demonstrate forms it does not contain.</p>
Class OcuPilot.Test.Descriptor Extends %UnitTest.TestCase
{

/// <p>The one real descriptor this epic authors.</p>
Parameter HOMEDESCRIPTOR = "OcuPilot.Screen.Descriptor.Home";

/// <p>AC1 -- one declaration drives all three. The route lookup, the roster entry and the gate
/// each resolve Home, and each reads the same declaration rather than a copy of it: the
/// roster's route is the descriptor's own <method>Route</method>, and the gate's requirement is
/// the descriptor's own <method>PrivilegePairs</method>.</p>
/// <p>Mutation: change <code>"route"</code> in
/// <class>OcuPilot.Screen.Descriptor.Home</class>'s declaration -> the lookup and the roster
/// assertions go red together, which is the evidence that they are one source and not two.</p>
Method TestOneDeclarationDrivesRouteNavigationAndGate()
{
    Set tRoute = $ClassMethod(..#HOMEDESCRIPTOR, "Route")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute), ..#HOMEDESCRIPTOR, "the route table resolves the declared route to the declaring class")

    Set tSC = ##class(OcuPilot.Screen.Registry).Roster(.tRoster)
    Do $$$AssertStatusOK(tSC, "the roster builds")
    Set tHomeArea = ..AreaEntry(tRoster, "home")
    Do $$$AssertTrue($IsObject(tHomeArea), "the roster carries the home area")
    If $IsObject(tHomeArea) {
        Do $$$AssertEquals(tHomeArea.screens.%Size(), 1, "with exactly the one built screen declared for it")
        Do $$$AssertEquals(tHomeArea.screens.%Get(0).route, tRoute, "whose navigation entry names the declared route")
        Do $$$AssertEquals(tHomeArea.screens.%Get(0).descriptor, ..#HOMEDESCRIPTOR, "and the declaring class")
    }

    Set tFailed = "x"
    Do $$$AssertTrue(##class(OcuPilot.Screen.Gate).Evaluate(..#HOMEDESCRIPTOR, .tFailed), "the gate resolves the same descriptor")
    Do $$$AssertEquals(tFailed, "", "and names no failed pair, because Home declares none")
}

/// <p>The production roster is sound: every descriptor parses, names a declared area, uses
/// only kernel entity types, declares a tool identifier and holds a route no sibling
/// claims.</p>
/// <p>Mutation: point <class>OcuPilot.Screen.Descriptor.Home</class>'s <code>"area"</code> at a
/// key <class>OcuPilot.Screen.Area</class> does not declare -> this goes red naming the class
/// and the key.</p>
Method TestTheProductionRosterValidates()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "the production descriptor roster is sound")
    Do $$$AssertStatusOK(tSC, "and the refusal travels in the status too")
}

/// <p>AC7 -- the web applications list's declaration passes the read grammar on its own, and its
/// classic page names a class compiled on this instance, spelled in that class's own case: the
/// custom-resource lookup does not case-fold, so a mis-cased name would silently union no
/// resource onto the gate (AD-44).</p>
/// <p>Mutation: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> -> the classic-page and compiled-class
/// assertions go red.</p>
Method TestTheWebApplicationsListValidatesAndNamesItsClassicPageInItsOwnCase()
{
    Set tClass = "OcuPilot.Screen.Descriptor.WebAppList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem($ClassMethod(tClass, "Archetype"), $ClassMethod(tClass, "ClassicPage"), $ClassMethod(tClass, "ClassicLinkExempt"), $ClassMethod(tClass, "ClassicLinkExemptionReason"), $ClassMethod(tClass, "ClassicLinkLabel"), $ClassMethod(tClass, "ClassicLinkHref")), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("web-applications/list"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("webapp.list"), tClass, "and so does its tool identifier")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Applications.WebList", "the classic page is the vendor's web application list")
    ; The dictionary lookup is keyed on the exact name, so a mis-cased declaration opens nothing.
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>The abstract base lives in the descriptor package and is not a screen. A registry that
/// enumerated it would try to read a declaration it does not carry and refuse a sound
/// roster.</p>
Method TestTheBaseClassIsNotEnumerated()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the descriptor list builds")
    Do $$$AssertEquals($ListFind(tList, "OcuPilot.Screen.Descriptor.Base"), 0, "the abstract base is not a descriptor")
    Do $$$AssertTrue($ListFind(tList, ..#HOMEDESCRIPTOR) > 0, "while a real descriptor is")
}

/// <p>A class that sits in the descriptor package without extending the base is not a
/// descriptor and is not enumerated. The package prefix says where a class lives, not what it
/// is, and a misplaced class that reached the roster would raise
/// <code>&lt;METHOD DOES NOT EXIST&gt;</code> on the first accessor -- taking down
/// <method>OcuPilot.Screen.Registry.Roster</method> and with it
/// <code>GET /api/ocupilot/navigation</code>, which leaves the client with no map and every
/// area reading ungated.</p>
/// <p>Mutation: drop the <code>%Extends</code> filter from
/// <method>OcuPilot.Screen.Registry.Descriptors</method> -> the membership assertion goes red
/// and both the roster and the validation assertions below it go red with it, because
/// <class>OcuPilot.Test.Screen.Stray</class> answers no accessor.</p>
Method TestAClassInThePackageThatIsNotADescriptorIsNotEnumerated()
{
    Set tSC = ##class(OcuPilot.Test.ScreenRegistry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the fixture descriptor list builds")
    Do $$$AssertEquals($ListFind(tList, "OcuPilot.Test.Screen.Stray"), 0, "a class in the package that does not extend the base is not a descriptor")
    Do $$$AssertTrue($ListFind(tList, "OcuPilot.Test.Screen.Multi") > 0, "while one that does extend it still is")

    Set tRosterSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 0, .tAll)
    Do $$$AssertStatusOK(tRosterSC, "and the roster walk does not throw on it")

    Set tValidateSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "nor does validation refuse a sound roster because of it")
    Do $$$AssertStatusOK(tValidateSC, "and the refusal travels in the status too")
}

/// <p>AC3, the multi-entity form -- a screen administering several entity types declares a
/// primary plus secondaries, and all of them participate in change-event routing.</p>
/// <p>Mutation: move <code>"oauth2-server-definition"</code> out of
/// <class>OcuPilot.Test.Screen.Multi</class>'s secondaries -> the count and the membership
/// assertions go red, while the primary stays green.</p>
Method TestAMultiEntityDescriptorDeclaresPrimaryAndSecondaryTypes()
{
    Set tClass = "OcuPilot.Test.Screen.Multi"
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "oauth2-client-configuration", "the primary type drives the route and the change-event key")
    Set tSecondary = $ClassMethod(tClass, "SecondaryEntityTypes")
    Do $$$AssertEquals($ListLength(tSecondary), 2, "two secondary types are declared")
    Do $$$AssertTrue($ListFind(tSecondary, "oauth2-server-definition") > 0, "the server definition is one of them")
    Do $$$AssertTrue($ListFind(tSecondary, "oauth2-resource-server") > 0, "and the resource server is the other")

    Set tAll = $ClassMethod(tClass, "EntityTypes")
    Do $$$AssertEquals($ListLength(tAll), 3, "all three participate in change-event routing")
    Do $$$AssertEquals($List(tAll, 1), "oauth2-client-configuration", "with the primary first")

    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExempt"), "and the exemption flag is readable")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExemptionReason") '= "", "with the reason AD-44 requires alongside it")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkLabel") '= "", "the classic page's own name, which labels the card's action")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkHref"), "/csp/sys/OcuPilotTestClassicPageMulti.csp", "and the declared target, which is never derived from classicPage")
}

/// <p>AD-44's vocabulary half -- <code>archetype</code> is a closed vocabulary with a link-out
/// class per key, which is what gives "only a detail view may declare a classic link-out" a
/// predicate to evaluate. While it was free text, a typo answered "not a detail view" and
/// passed.</p>
/// <p>Mutation: change <code>form-page</code>'s <code>linkOut</code> in
/// <class>OcuPilot.Screen.Archetype</class> to <code>none</code> -> the
/// <method>MayLinkOut</method> assertion goes red, and
/// <method>TestAClassicLinkDeclarationOutsideThePermittedShapesIsRefused</method>'s fixture
/// roster stops being refused for the reason it names.</p>
Method TestTheArchetypeVocabularyIsClosedAndClassified()
{
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).Exists("list"), "a declared key is known")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).Exists("form-page (tabs)"), "including one whose spelling carries a space and parentheses")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).Exists("lst"), "a near miss is not")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).Exists(""), "and neither is the empty string")
    ; Pinned to a literal. Comparing Count() with the size of List() restates Count()'s own
    ; definition and cannot fail, so a key dropped from the block would go unnoticed.
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).Count(), 16, "sixteen keys: EXPERIENCE.md's twelve state-matrix rows, the form row holding three, plus shell and external")

    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("list"), "list", "a list archetype is classified list")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("log-viewer"), "list", "and so is a viewer of rows under another name")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("form-page"), "detail", "a reduced form is a form-page, which is a detail view")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("home"), "none", "and Home is neither")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("lst"), "", "an undeclared key has no classification")

    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut("detail"), "only a detail view may link out")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut("wizard"), "which the wizard archetype is")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("list"), "a list archetype never does")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("drill-down"), "nor one classified list under another name")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("meters"), "nor one classified neither")
    ; The default is refusal, so a mis-classification refuses a link rather than permitting one.
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("lst"), "and an archetype outside the vocabulary fails closed")
}

/// <p>AD-44's refusal half -- every classic link-out declaration outside the permitted shapes is
/// refused, as values here and over a real roster below. <method>Validate</method> reports only
/// the first problem in a roster, so eight malformed shapes would otherwise be eight fixture
/// packages.</p>
/// <p>Mutation: drop the <method>OcuPilot.Screen.Archetype.MayLinkOut</method> comparison from
/// <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method> -> the list, log-viewer and
/// meters rows stop being refused and the fixture-roster assertions go red with them, while a
/// list screen would ship an outbound classic link FR-9 forbids.</p>
Method TestAClassicLinkDeclarationOutsideThePermittedShapesIsRefused()
{
    Set tReason = "no rebuilt equivalent yet"
    Set tLabel = "OcuPilot test classic page"
    Set tHref = "/csp/sys/OcuPilotTestClassicPage.csp"
    Set tPage = "OcuPilotTestClassicPage"

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 1, tReason, tLabel, tHref), "", "a detail view with a complete exemption is honored")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("home", tPage, 0, "", "", ""), "", "and a screen that declares no exemption is sound")

    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("list", tPage, 1, tReason, tLabel, tHref), "", "a list archetype never links out")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("log-viewer", tPage, 1, tReason, tLabel, tHref), "", "nor does one classified list under another name")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("meters", tPage, 1, tReason, tLabel, tHref), "", "nor one classified neither")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("lst", tPage, 0, "", "", ""), "", "an archetype outside the vocabulary is refused whether or not it exempts")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 1, "", tLabel, tHref), "", "an exemption with no reason is refused: the check reports the reason of every one it honors")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 1, tReason, "", tHref), "", "an exemption with no label is refused: the card's action names the page it opens")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 1, tReason, tLabel, ""), "", "an exemption with no href is refused: no URL is ever derived from classicPage")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", "", 1, tReason, tLabel, tHref), "", "an exemption with no classic equivalent has nothing to link out to")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 0, "", tLabel, ""), "", "a label without an exemption is a half-made declaration")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem("detail", tPage, 0, "", "", tHref), "", "and so is an href without one")

    ; AD-47: the origin is a trust boundary, so the target is a path on this instance or it is
    ; not a value. The two engines are hand-maintained copies of one rule, in two languages, so
    ; this corpus is deliberately the same twelve values ui/tools/classic-links.test.mjs runs
    ; through hrefProblem -- kept in step by hand, not by a shared source. A value added to one
    ; list belongs in the other; a divergence here is the build and the instance disagreeing
    ; about what same-origin means.
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("https://elsewhere/x"), "", "an absolute URL names another origin")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("http://elsewhere/x"), "", "at any scheme")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("//host/x"), "", "and so does a protocol-relative one")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("../x"), "", "a relative path is not root-relative")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("csp/sys/UtilHome.csp"), "", "nor is one that merely omits the leading slash")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/csp/../../etc/passwd"), "", "and a traversing one is refused even when it starts at the root")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/csp/sys\Util.csp"), "", "a backslash is outside the characters a path is spelled with")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/csp/sys/Util Home.csp"), "", "and so is whitespace")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("javascript:alert(1)"), "", "and a scheme that is not a path at all is refused")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/csp/sys/UtilHome.csp"), "", "a root-relative path on this instance is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/csp/sys/sec/%25CSP.UI.Portal.cls?id=1#tab"), "", "including one carrying an escape, a query and a fragment")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem("/"), "", "and the bare root")

    Set tSC = ##class(OcuPilot.Test.ClassicLinkRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a list archetype that declares an exemption is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.ClassicLink.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.ClassicLink.Bad).#BADARCHETYPE, "and the offending archetype")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster whose one exemption is a detail view is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>AD-44's agreement property, exhausted rather than sampled. The test above drives
/// <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method> against three of the sixteen
/// declared keys (<code>list</code>, <code>log-viewer</code>, <code>meters</code>);
/// <file>ui/tools/classic-links.test.mjs</file>'s equivalent already loops over all sixteen. This
/// closes that asymmetry, over every key <method>OcuPilot.Screen.Archetype.List</method>
/// returns rather than a hand-picked few.</p>
/// <p><b>The oracle is the same hardcoded four-key literal
/// <file>ui/tools/classic-links.test.mjs</file>'s <code>mayLinkOut</code> assertion uses, not
/// <method>Archetype.MayLinkOut</method>.</b> <method>ClassicLinkProblem</method> calls
/// <method>MayLinkOut</method> internally, so comparing its verdict against
/// <method>MayLinkOut</method>'s own answer would restate that one call and could never fail --
/// a vocabulary edit moves both sides together. Against the independent literal, a
/// classification drift in any of the thirteen keys the sampled test above never asks about is
/// caught here instead of passing this live suite silently.</p>
/// <p>Mutation: change <code>drill-down</code>'s <code>linkOut</code> in
/// <class>OcuPilot.Screen.Archetype</class>'s <code>XData Archetypes</code> block from
/// <code>list</code> to <code>detail</code> and recompile -> <method>MayLinkOut("drill-down")</method>
/// then answers true and <method>ClassicLinkProblem</method> honors the exemption, but this loop's
/// literal still says <code>drill-down</code> may not link out, so the assertion goes red naming
/// it, while <method>TestAClassicLinkDeclarationOutsideThePermittedShapesIsRefused</method> stays
/// green because it never asks about that key.</p>
Method TestEveryArchetypeKeyAgreesBetweenRegistryAndTheVocabularysOwnClassification()
{
    ; The same four keys ui/tools/classic-links.test.mjs's "mayLinkOut" literal names -- kept in
    ; step by hand, not by a shared source, the same discipline the href corpus above follows.
    Set tMayLinkOutKeys = $ListBuild("detail", "form-page", "form-page (tabs)", "wizard")

    Set tReason = "no rebuilt equivalent yet"
    Set tLabel = "OcuPilot test classic page"
    Set tHref = "/csp/sys/OcuPilotTestClassicPage.csp"
    Set tPage = "OcuPilotTestClassicPage"

    Set tSC = ##class(OcuPilot.Screen.Archetype).List(.tArchetypes)
    Do $$$AssertStatusOK(tSC, "the vocabulary reads")
    ; Pinned to the same "sixteen" TestTheArchetypeVocabularyIsClosedAndClassified pins, so a key
    ; silently dropped from the block does not quietly shrink this loop to a smaller sample.
    Do $$$AssertEquals(tArchetypes.%Size(), 16, "every declared key participates below, not a sample")

    Set tIterator = tArchetypes.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArchetype) {
        Set tKey = tArchetype.key
        Set tShouldLinkOut = $ListFind(tMayLinkOutKeys, tKey) > 0

        ; A non-exempting declaration is always sound, whatever the archetype -- the archetype
        ; alone is never refused, only a declared exemption it does not permit.
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tKey, tPage, 0, "", "", ""), "", tKey _ ": a screen that declares no exemption is always sound")

        Set tExemptProblem = ##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tKey, tPage, 1, tReason, tLabel, tHref)
        If tShouldLinkOut {
            Do $$$AssertEquals(tExemptProblem, "", tKey _ ": one of the four detail-classified keys, so a complete exemption is honored")
        } Else {
            Do $$$AssertNotEquals(tExemptProblem, "", tKey _ ": not one of the four detail-classified keys, so an exemption is refused")
            Do $$$AssertTrue(tExemptProblem [ tKey, tKey _ ": the refusal names the archetype")
        }
    }
}

/// <p>AD-44's honored path, on the archetype the rule names literally: a
/// <code>detail</code> descriptor declaring a complete exemption validates, and every part the
/// card renders is readable from the declaration.</p>
/// <p><b>The target is declared, never derived.</b> The falsifiable form is that the href shares
/// no spelling with <method>ClassicPage</method>: the classic portal keys custom page resources
/// by normalized class name and publishes no inverse, so a descriptor that wanted a link had to
/// say where it goes.</p>
Method TestADetailDescriptorDeclaresAnHonoredExemption()
{
    Set tClass = "OcuPilot.Test.Screen.Detail"
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", "the archetype AD-44's rule names literally")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut($ClassMethod(tClass, "Archetype")), "which may link out")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExempt"), "and declares that it does")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExemptionReason") '= "", "with its reason")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkLabel") '= "", "the page name its card's action carries")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkHref"), "/csp/sys/OcuPilotTestClassicPageDetail.csp", "and the declared target")

    Set tHref = $ClassMethod(tClass, "ClassicLinkHref")
    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertNotEquals(tHref, tPage, "the target is not the class name")
    Do $$$AssertNotEquals(tHref, "/" _ tPage, "nor the class name under a root")
    Do $$$AssertNotEquals(tHref, "/csp/sys/" _ tPage, "nor the class name under a guessed sub-application")

    Do $$$AssertTrue('$ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkExempt"), "Home links out to nothing")
    Do $$$AssertEquals($ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkHref"), "", "so it declares no target")
    Do $$$AssertEquals($ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkLabel"), "", "and no label")
}

/// <p>AC3, the sub-resource form -- task history is not a task, so it declares its own entity
/// type and names the route of the screen whose entity it hangs from.</p>
Method TestASubResourceDescriptorNamesItsParentScope()
{
    Set tClass = "OcuPilot.Test.Screen.Sub"
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "task-history-entry", "its rows are not the entity its route identifies")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "tasks/schedule", "and it names the route it hangs from")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "namespace", "its data scope is the namespace, not the instance")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Screen.Multi", "ParentScope"), "", "a screen that is nobody's sub-resource declares no parent")
}

/// <p>AC3, the composite-id form -- the descriptor names the parts and the <b>one</b> shared
/// codec joins them, and the result is still a single path segment that survives the wire trip
/// byte for byte (AD-13). A slice never invents a second composite grammar, which is why the
/// join and the split live on <class>OcuPilot.Kernel.EntityId</class> and not here.</p>
/// <p>Mutation: join the parts with a literal <code>"/"</code> instead of
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method> -> the single-segment assertion goes
/// red, because the value stops being one segment.</p>
Method TestACompositeIdRoundTripsThroughTheOneSharedCodec()
{
    Set tClass = "OcuPilot.Test.Screen.Composite"
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "the id accessor declares itself composite")
    Set tParts = $ClassMethod(tClass, "IdParts")
    Do $$$AssertEquals($ListLength(tParts), 2, "and names its parts")
    Do $$$AssertEquals($List(tParts, 1), "namespace", "in order")
    Do $$$AssertEquals($List(tParts, 2), "name", "in order")

    Set tValues = $ListBuild("HSCUSTOM", "/csp/myapp")
    Set tJoined = ##class(OcuPilot.Kernel.EntityId).JoinComposite(tValues)
    Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode(tJoined)
    Do $$$AssertTrue((tEncoded '[ "/"), "a composite id still occupies exactly one path segment")
    Set tDelivered = ##class(OcuPilot.Test.EntityId).ServerDecode(tEncoded)
    Set tSplit = ##class(OcuPilot.Kernel.EntityId).SplitComposite(##class(OcuPilot.Kernel.EntityId).Decode(tDelivered))
    Do $$$AssertEquals($ListLength(tSplit), 2, "and comes back as its parts")
    Do $$$AssertEquals($List(tSplit, 1), "HSCUSTOM", "byte for byte")
    Do $$$AssertEquals($List(tSplit, 2), "/csp/myapp", "including the part that holds a slash")

    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Screen.Sub", "IdKind"), "single", "a single-id screen says so")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.Home", "IdKind"), "none", "and a screen with no entity declares no accessor")
}

/// <p>AC3, tool identity -- the tool name comes from its own declared field, so renaming a
/// screen cannot silently orphan its write tools or their governance keys.</p>
/// <p>The falsifiable form of "renaming the screen does not change it" is that the identifier
/// is <b>not derivable</b> from the route or the label: the fixture's route and its tool
/// identifier share no spelling, and neither of the two obvious derivations produces it.</p>
Method TestAToolIdentifierIsDeclaredAndNotDerived()
{
    Set tClass = "OcuPilot.Test.Screen.Composite"
    Set tTool = $ClassMethod(tClass, "ToolIdentifier")
    Set tRoute = $ClassMethod(tClass, "Route")
    Do $$$AssertEquals(tTool, "webapp.list", "the tool identifier is the declared value")
    Do $$$AssertNotEquals(tTool, tRoute, "it is not the route")
    Do $$$AssertNotEquals(tTool, $Translate(tRoute, "/", "."), "nor the route with its separator swapped")
    Do $$$AssertNotEquals(tTool, $ClassMethod(tClass, "LabelKey"), "nor the display name's key")
}

/// <p>AC4, the instance half -- a descriptor naming an entity type outside the kernel enum is
/// refused by the registry, naming the class and the value. The same value is refused by
/// <file>scripts/check-objectscript.py</file> in the tree and by
/// <file>ui/tools/screen-mirror.mjs</file> before the mirror is emitted, which is why the
/// fixture supplies its declaration through the overridable seam rather than an XData
/// block.</p>
/// <p>Mutation: add <code>not-an-entity-type</code> to
/// <parameter>OcuPilot.Kernel.EntityType.TYPES</parameter> -> this goes red, because the
/// vocabulary is what the refusal reads.</p>
Method TestAnUnknownEntityTypeIsRefusedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Test.BadRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster naming an unknown entity type is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Bad.Unknown", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.Bad.Unknown).#BADTYPE, "and the offending value")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that uses declared values is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>AC4's scope half -- a descriptor declaring a <code>scope</code> that is neither
/// <code>namespace</code> nor <code>instance</code> is refused by the registry, naming the class
/// and the value. The two are what <method>OcuPilot.Kernel.EntityRef.ScopeFor</method> resolves,
/// and it answers <code>""</code> for anything else, so without this refusal a third spelling
/// would build references with no scope rather than fail anywhere a reader could see.</p>
/// <p>Mutation: add <code>cluster</code> to the pair
/// <method>OcuPilot.Screen.Registry.Validate</method> accepts -> this goes red, because the two
/// declared values are what the refusal reads.</p>
Method TestADeclaredScopeOutsideTheTwoIsRefusedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Test.ScopeRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster declaring a third scope is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Scope.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.Scope.Bad).#BADSCOPE, "and the offending value")

    ; The same declaration, read the way a reference reads it, resolves to no scope at all --
    ; the silent outcome the refusal above exists to prevent.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor(##class(OcuPilot.Test.Scope.Bad).#BADSCOPE), "", "and it would have produced a reference with no scope")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that declares the two values is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>The vocabulary is closed and kernel-owned: a declared value is known, an undeclared one
/// is not, and the empty string is not -- a screen with no entity type declares <code>""</code>
/// and the registry exempts it rather than <method>IsKnown</method> admitting it.</p>
Method TestTheEntityTypeVocabularyIsClosed()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("web-application"), "a declared value is known")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("log-entry"), "including the last one declared")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown("webapplication"), "a near miss is not")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown(""), "and neither is the empty string")
    ; Pinned to a literal. Comparing Count() with $ListLength(List()) restates Count()'s own
    ; definition and cannot fail, so a value dropped from TYPES would go unnoticed.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).Count(), 26, "the closed vocabulary holds twenty-six values; adding one is a deliberate edit here and in Kernel.EntityType")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.Home", "PrimaryEntityType"), "", "Home administers nothing and says so")
    Do $$$AssertEquals($ListLength($ClassMethod("OcuPilot.Screen.Descriptor.Home", "EntityTypes")), 0, "so it contributes no key to validate")
}

/// <p>AD-43's declaration half -- a screen says in its descriptor whether it refreshes and at
/// what rates, and that is the only place either is said. The rates are whole seconds, so the
/// value read here is what the framework multiplies into the delay it hands its timer seam.</p>
/// <p>Mutation: drop <code>"refreshRates"</code> from
/// <class>OcuPilot.Test.Screen.Refreshing</class>'s declaration -> the rate assertions go red,
/// and <method>TestTheProductionRosterValidates</method>'s fixture sibling below goes red with
/// them, because a refreshing screen with no rates is refused.</p>
Method TestARefreshingScreenDeclaresItsRatesAndHomeDeclaresNone()
{
    Set tClass = "OcuPilot.Test.Screen.Refreshing"
    Do $$$AssertTrue($ClassMethod(tClass, "Refreshes"), "a refreshing screen says so in its descriptor")
    Set tRates = $ClassMethod(tClass, "RefreshRates")
    Do $$$AssertEquals($ListLength(tRates), 1, "and declares the rates its chip may set")
    Do $$$AssertEquals($List(tRates, 1), 10, "in whole seconds")

    Do $$$AssertTrue('$ClassMethod(..#HOMEDESCRIPTOR, "Refreshes"), "Home is not one of the auto-refresh screens")
    Do $$$AssertEquals($ListLength($ClassMethod(..#HOMEDESCRIPTOR, "RefreshRates")), 0, "so it permits no rate")

    ; A descriptor written before the pair existed declares neither, and reads as the screen it
    ; is: one the framework binds nothing for. The registry accepts that pair, so an older
    ; fixture is not retroactively malformed.
    Do $$$AssertTrue('$ClassMethod("OcuPilot.Test.Screen.Multi", "Refreshes"), "an omitted declaration reads as not refreshing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(0, ""), "", "and that pair is sound")
}

/// <p>AD-43's refusal half -- every refresh declaration outside the permitted shapes is refused,
/// as values here and over a real roster below. <method>Validate</method> reports only the first
/// problem in a roster, so six malformed shapes would otherwise be six fixture packages.</p>
/// <p>Mutation: drop the ascending comparison from
/// <method>OcuPilot.Screen.Registry.RefreshProblem</method> -> the repeat and the descent both
/// stop being refused and two assertions go red, while a chip cycling through
/// <code>10, 10</code> would spend one step of its cycle changing nothing.</p>
Method TestARefreshDeclarationOutsideThePermittedShapesIsRefused()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(10)), "", "one positive rate on a refreshing screen is sound")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(5, 10, 30, 60)), "", "and so is an ascending list of them")

    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(0, $ListBuild(10)), "", "a rate on a screen that does not refresh is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, ""), "", "a refreshing screen with no rate is refused: its chip could never turn on")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(0)), "", "zero is spelled by turning the chip off, never by declaring it")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(-10)), "", "a negative rate is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(1.5)), "", "a fraction of a second is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild("ten")), "", "and so is a rate that is not a number")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(10, 10)), "", "a repeat would make one step of the chip's cycle a no-op")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(30, 10)), "", "and a descent would advance the chip backwards")

    Set tSC = ##class(OcuPilot.Test.RefreshRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a malformed refresh declaration is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Refresh.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ "refreshRates", "and the field it is about")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that declares a sound pair is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>A side bar lists only screens that exist (<file>EXPERIENCE.md</file> `:157`). The
/// unbuilt fixture shares an area with a built one, so an implementation that dropped the
/// filter would list two where one is correct rather than turning an empty list into an empty
/// list.</p>
/// <p>Mutation: default <method>OcuPilot.Screen.Registry.ScreensForArea</method>'s
/// <var>pBuiltOnly</var> to 0 -> the first assertion goes red with two entries.</p>
Method TestOnlyBuiltScreensReachASideBar()
{
    Set tSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 1, .tBuilt)
    Do $$$AssertStatusOK(tSC, "the built list builds")
    Do $$$AssertEquals($ListLength(tBuilt), 1, "only the built screen is listed")
    Do $$$AssertEquals($List(tBuilt, 1), "OcuPilot.Test.Screen.Composite", "and it is the one declared built")

    Set tAllSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 0, .tAll)
    Do $$$AssertStatusOK(tAllSC, "the unfiltered list builds")
    Do $$$AssertEquals($ListLength(tAll), 2, "while both are declared")
    Do $$$AssertTrue('$ClassMethod("OcuPilot.Test.Screen.Unbuilt", "IsBuilt"), "and the excluded one is the unbuilt one")
}

/// <p>The area vocabulary is closed and ordered: eight entries in the rail order
/// <file>EXPERIENCE.md</file> `:64` fixes, Home the only one that navigates, Agent co-pilot the
/// only one pinned to the bottom, and neither of those two carrying a privilege pair -- which
/// is how "the rail item itself never gates" is expressed.</p>
/// <p>Mutation: give the <code>agent</code> area a privilege pair -> the last assertion goes
/// red.</p>
Method TestTheAreaVocabularyIsClosedOrderedAndUngatedAtBothEnds()
{
    Set tSC = ##class(OcuPilot.Screen.Area).List(.tAreas)
    Do $$$AssertStatusOK(tSC, "the area list reads")
    Do $$$AssertEquals(tAreas.%Size(), 8, "eight rail entries")

    Set tExpected = $ListBuild("home", "logs", "os-management", "tasks", "permissions", "web-applications", "security", "agent")
    For tI = 1:1:8 {
        Set tArea = tAreas.%Get(tI - 1)
        Do $$$AssertEquals(tArea.key, $List(tExpected, tI), "rail position " _ tI _ " is the declared area")
        Do $$$AssertEquals(+tArea.railPosition, tI, "and declares that position")
    }

    Do $$$AssertTrue(''##class(OcuPilot.Screen.Area).Find("home").navigates, "Home's rail item navigates")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Area).Find("logs").navigates, "and no other area's does")
    Do $$$AssertTrue(''##class(OcuPilot.Screen.Area).Find("agent").pinBottom, "Agent co-pilot is pinned to the bottom")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Area).PrivilegePairs("home")), 0, "Home never gates")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Area).PrivilegePairs("agent")), 0, "and neither does the agent rail item")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Area).PrivilegePairs("permissions")), 1, "while an area that gates declares its pair")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Area).Exists("no-such-area"), "and the vocabulary is closed")
}

/// <p>The roster entry for <var>pKey</var>, or an empty string.</p>
ClassMethod AreaEntry(pRoster As %DynamicArray, pKey As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRoster.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = pKey {
            Set tFound = tArea
            Quit
        }
    }
    Quit tFound
}

}
