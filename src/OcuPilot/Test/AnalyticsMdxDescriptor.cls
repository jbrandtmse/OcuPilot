/// <p>Pins MDX query's screen descriptor (AD-5, AD-8, AD-44, AD-64, Story 20.33): the declaration's values; that the instance validates it with its
/// three prompts; that its classic page is the class the portal's own resolver makes of the vendor's <code>_DeepSee.UI.MDXQuery.zen</code>, whose
/// compiled <code>RESOURCE</code> still names <code>%Development</code>, the resource this screen's own pair stands for; that its two pairs open it
/// and a custom resource an operator assigns to the classic page refuses it, named; and that its tool identifier resolves to it. It writes
/// nothing, so it needs no arming.</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and the classic portal's classes. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.AnalyticsMdxDescriptor Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AnalyticsMdxQuery";

/// <p>The classic MDX Query Tool's class.</p>
Parameter PAGE = "%DeepSee.UI.MDXQuery";

/// <p>The declaration's values: route, area, label, position, archetype, pairs, entity, aliases, three prompts, classic page and tool identifier, no
/// read, no table, no action and no context.</p>
/// <p>Mutation (Rule 19): change <code>sideBarPosition</code> in the descriptor -- this goes red.</p>
Method TestTheDeclarationsValues()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.labelKey _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.built _ "|" _ tDeclaration.refreshes, "analytics/mdx-query|analytics|analyticsMdxQueryLabel|7|form-page|1|0", "its route, area, label, position, archetype and flags")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ "|" _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%DeepSee_Portal"",""permission"":""USE""},{""resource"":""%Development"",""permission"":""USE""}]|[{""resource"":""%Development"",""permission"":""USE""}]", "its pairs are the area's and its own %Development:USE")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "cube|namespace|none|0||{""fields"":[],""secretFields"":[]}", "it is about a cube, scoped to the namespace, keyed by nothing, with no action and no context field")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table"), "unassigned|unassigned", "and no read and no table")
    Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), "[""mdx query"",""run mdx"",""mdx""]", "its command aliases")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "it declares three suggested prompts")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, ..#PAGE _ "|analytics.mdxquery", "its classic page and tool identifier")
}

/// <p>The instance validates the declaration, its classic page is the one the portal's resolver names for the vendor's <code>.zen</code> page, the
/// compiled classic page's <code>RESOURCE</code> names <code>%Development</code> among its either-of list, its two pairs open it, a custom resource on the
/// page refuses it, named, and its tool identifier resolves to it.</p>
/// <p>Mutation (Rule 19): declare another classic page -- the equality leg goes red.</p>
Method TestTheInstanceValidatesItAndTheClassicPageGatesIt()
{
    Set tClass = ..#DESCRIPTOR
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicLinkExemption.exempt, ..#PAGE _ "|0", "keyed to the classic MDX Query Tool, with no exemption")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("_DeepSee.UI.MDXQuery.zen"), ..#PAGE, "which the portal's own resolver answers")
    Set tResource = $Parameter(..#PAGE, "RESOURCE")
    Do $$$AssertTrue(tResource [ "%Development", "the compiled classic page's RESOURCE names %Development: " _ tResource)
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%DeepSee_Portal", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", tClass, .tFailed) && (tFailed = "%Development:USE"), "the portal's pair alone does not open it, and its own pair is named: " _ tFailed)
    Do $ClassMethod(tGate, "Hold", "%Development", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", tClass, .tFailed), "the two pairs open it while the page carries no custom resource")
    Do $ClassMethod(tGate, "AssignClassic", ..#PAGE, "OcuPilotTestCustomResource")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", tClass, .tFailed) && (tFailed = "OcuPilotTestCustomResource:USE"), "and a custom resource on the page refuses it, named: " _ tFailed)
    Do $ClassMethod(tGate, "Reset")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("analytics.mdxquery"), tClass, "its tool identifier resolves to it")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

}
