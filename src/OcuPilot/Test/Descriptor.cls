/// <p>The declaration contract (AD-5): one descriptor is the source of a screen's route, its
/// navigation entry and its privilege gate, and it can express the three awkward forms the
/// mechanism has to carry -- several entity types, a sub-resource's parent, and a composite
/// id -- plus a tool identity that is not derived from either.</p>
/// <p>The production roster holds one real screen (Home, whose page is Story 1.12's), so the
/// awkward forms are exercised over fixture descriptors under
/// <code>OcuPilot.Test.Screen.</code>, enumerated by
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
