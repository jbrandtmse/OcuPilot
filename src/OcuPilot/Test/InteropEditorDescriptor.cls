/// <p>Pins Story 20.7's three editor screens with nothing written (AD-5, AD-8, AD-44, AD-63): the rule, BPL and DTL
/// editors are unlisted <code>viewer (source)</code> screens at their list's route with <code>/document</code> appended,
/// each declaring the pair set of the lists that open it, no read and no table, three prompts and the classic editor page the
/// portal's own resolver names, and each classic page's compiled <code>RESOURCE</code> holds the screen's own pair. Story 20.8's
/// Schema viewer and Configuration diagram are pinned the same way, and the viewer's three classic pages each gate it
/// through <code>CLASSICPAGES</code>.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and the <code>EnsPortal</code> editor pages, which
/// the <code>HSCUSTOM</code> namespace holds. It runs unarmed and writes nothing.</p>
Class OcuPilot.Test.InteropEditorDescriptor Extends %UnitTest.TestCase
{

/// <p>The three screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;label key&gt;|&lt;empty key&gt;|&lt;classic page&gt;|&lt;tool identifier&gt;|&lt;prompt key prefix&gt;</code>.</p>
Parameter SCREENS = "InteropRuleEditor|interoperability/rules/document|interopRuleEditorTitle|interopRuleEditorEmpty|EnsPortal.RuleEditor|interop.ruleeditor|interopRuleEditorPrompt;InteropProcessEditor|interoperability/processes/document|interopBplEditorTitle|interopBplEditorEmpty|EnsPortal.BPLEditor|interop.processeditor|interopBplEditorPrompt;InteropTransformEditor|interoperability/transforms/document|interopDtlEditorTitle|interopDtlEditorEmpty|EnsPortal.DTLEditor|interop.transformeditor|interopDtlEditorPrompt";

/// <p>The pair set every editor declares: the Interoperability menu's and, as its own, the code lists'.</p>
Parameter PAIRS = "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Code"",""permission"":""READ""}]";

Parameter OWNPAIRS = "[{""resource"":""%Ens_Code"",""permission"":""READ""}]";

/// <p>Story 20.8's two screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;side-bar position&gt;|&lt;label key&gt;|&lt;empty key&gt;|&lt;classic page&gt;|&lt;tool identifier&gt;|&lt;prompt key prefix&gt;|&lt;entity type&gt;|&lt;parent scope&gt;|&lt;id kind&gt;|&lt;aliases&gt;|&lt;CLASSICPAGES&gt;|&lt;own resource&gt;</code>.
/// The pair set of each is the Interoperability menu's and, as its own, <code>&lt;own resource&gt;:READ</code>.</p>
Parameter VIEWERS = "InteropSchemaViewer|interoperability/schema-viewer|10|interopSchemaViewerTitle||EnsPortal.HL7.SchemaMain|interop.schemaviewer|interopSchemaViewerPrompt|||none|schema viewer,hl7 schemas,x12 schemas,astm schemas|EnsPortal.EDI.X12.SchemaMain,EnsPortal.EDI.ASTM.SchemaMain|%Ens_EDISchema;InteropProductionDiagram|interoperability/productions/diagram|0|interopProductionDiagramTitle|interopProductionDiagramEmpty|EnsPortal.ProductionConfig|interop.productiondiagram|interopProductionDiagramPrompt|production|interoperability/productions|single|||%Ens_ProductionConfig";

/// <p>The custom resource a probe assigns to a classic page of the Schema viewer, in <method>TestTheSchemaViewerHonorsEveryClassicPage</method>.</p>
Parameter PROBERESOURCE = "OcuProbe208";

/// <p>Each declaration carries the table's values, and the registry validates it: an unlisted, id-keyed
/// <code>viewer (source)</code> screen of the interoperability area at the list's route with <code>/document</code>, scoped to the
/// namespace, with no read, table, action or alias, no context field, three <code>promptGroupGettingStarted</code> prompts and
/// the classic editor page <code>%SYS.Portal.Resources.NormalizePage</code> answers for the <code>.zen</code> page.</p>
/// <p>Mutation (Rule 19): move one editor's route off <code>/document</code> -- the route leg goes red here and
/// <file>ui/tools/navigation.test.mjs</file>'s pairing test goes red there. Drop <code>%Ens_Code:READ</code> from one
/// editor -- the pair legs go red here, and <class>OcuPilot.Test.InteropFloor</class>'s Administrator roster goes red.</p>
Method TestTheThreeEditorScreensRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Kill tDeclaration
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.built _ "|" _ tDeclaration.refreshes, $Piece(tRow, "|", 2) _ "|interoperability|0|viewer (source)|namespace|1|0", tClass _ ": route, area, unlisted position, archetype, scope, built and not refreshing")
        Do $$$AssertEquals(tDeclaration.labelKey _ "|" _ tDeclaration.emptyStateKey _ "|" _ tDeclaration.toolIdentifier, $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 6), tClass _ ": label, empty sentence and tool identifier")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": the Interoperability menu's pair, then the code lists'")
        Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), ..#OWNPAIRS, tClass _ ": %Ens_Code:READ is its own pair")
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.parentScope _ "|" _ tDeclaration.id.%ToJSON(), "class||{""kind"":""single"",""parts"":[]}", tClass _ ": a class, one id segment, no parent")
        Do $$$AssertEquals(tDeclaration.%IsDefined("read") _ tDeclaration.%IsDefined("table"), "00", tClass _ ": no read and no table of its own")
        Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.commandAliases.%Size() _ "|" _ tDeclaration.context.fields.%Size() _ "|" _ tDeclaration.context.secretFields.%Size() _ "|" _ tDeclaration.primaryAction.id, "0|0|0|0|", tClass _ ": no action, alias or context field")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        For tJ = 1:1:3 {
            Set tPrompt = tDeclaration.suggestedPrompts.%Get(tJ - 1)
            Do $$$AssertEquals($Select($IsObject(tPrompt): tPrompt.groupKey _ "|" _ tPrompt.textKey, 1: ""), "promptGroupGettingStarted|" _ $Piece(tRow, "|", 7) _ tJ, tClass _ ": prompt " _ tJ _ " is its own, in the getting-started group")
        }
        Set tPage = $Piece(tRow, "|", 5)
        Do $$$AssertEquals(tDeclaration.classicPage, tPage, tClass _ ": its classic editor page")
        Do $$$AssertEquals(..NormalizedPage(tPage _ ".zen"), tPage, tClass _ ": which the portal's own resolver answers for the page")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($Piece(tRow, "|", 6)), tClass, tClass _ ": its tool identifier resolves to it")
    }
}

/// <p>Each classic editor page compiles a <code>RESOURCE</code> that holds a member the screen declares as its own pair:
/// <code>%Ens_Code:READ</code>, read as the classic portal reads a member (<code>resource[:permission]</code>, <code>USE</code>
/// when no permission is given), so every role that holds the screen's pair also opens the classic editor. The classic page
/// also admits a role through another member of its list, which the screen refuses: <code>%EnsRole_RulesDeveloper</code>
/// opens the classic rule editor through <code>%Ens_Rules:READ</code> (AD-8, AD-44).</p>
/// <p>Mutation (Rule 19): declare <code>%Ens_Code:USE</code> as one editor's own pair -- this goes red naming the page.</p>
Method TestEachClassicEditorSharesTheScreensPair()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Set tPage = $Piece(tRow, "|", 5)
        Set tResource = ..AssertPageSharesOwnPair(tClass, tPage)
        Do $$$AssertTrue(tResource [ "%Ens_Code:READ", tPage _ "'s RESOURCE names %Ens_Code:READ: '" _ tResource _ "'")
    }
}

/// <p>Each classic page of the two Story 20.8 screens -- the descriptor's <code>classicPage</code> and each page of its
/// <code>CLASSICPAGES</code> -- compiles a <code>RESOURCE</code> that holds the screen's own pair (AD-8, AD-44), so every
/// role that holds the screen's pair also opens that classic page.</p>
/// <p>Mutation (Rule 19): declare <code>%Ens_EDISchema:USE</code> as the Schema viewer's own pair -- this goes red naming the pages.</p>
Method TestEachViewerClassicPageSharesTheScreensPair()
{
    For tI = 1:1:$Length(..#VIEWERS, ";") {
        Set tRow = $Piece(..#VIEWERS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Set tPages = $ListBuild($Piece(tRow, "|", 6)) _ $ListFromString($Piece(tRow, "|", 13), ",")
        For tJ = 1:1:$ListLength(tPages) {
            Do ..AssertPageSharesOwnPair(tClass, $List(tPages, tJ))
        }
        Do $$$AssertEquals($ListLength(tPages), $Select($Piece(tRow, "|", 13) = "": 1, 1: 3), tClass _ ": the pages it replaces are its own and its CLASSICPAGES")
    }
}

/// <p>Assert that <var>pPage</var> is compiled and that its <code>RESOURCE</code> holds a member <var>pClass</var> declares as
/// its own pair, read as the classic portal reads a member (<code>resource[:permission]</code>, <code>USE</code> when no
/// permission is given); answer the page's <code>RESOURCE</code>.</p>
Method AssertPageSharesOwnPair(pClass As %String, pPage As %String) As %String [ Private ]
{
    Do $$$AssertTrue(##class(OcuPilot.Test.DeveloperFloor).Compiled(pPage), pClass _ ": its classic page " _ pPage _ " is compiled")
    Set tResource = ##class(OcuPilot.Test.DeveloperFloor).ClassicResource(pPage, .tHasResource)
    Do $$$AssertTrue(tHasResource, pPage _ " compiles a RESOURCE parameter: '" _ tResource _ "'")
    Set tShared = 0
    For tJ = 1:1:$Length(tResource, ",") {
        Set tMember = $Piece($Piece(tResource, ",", tJ), ":", 1)
        Set tPermission = $Piece($Piece(tResource, ",", tJ), ":", 2)
        If tMember = "" Continue
        If tPermission = "" Set tPermission = "USE"
        If $ListFind($ClassMethod(pClass, "OwnPrivilegePairs"), $ListBuild(tMember, tPermission)) Set tShared = 1
    }
    Do $$$AssertTrue(tShared, pClass _ ": its own pair is a member of " _ pPage _ "'s RESOURCE '" _ tResource _ "'")
    Quit tResource
}

/// <p>Story 20.8's two screens each carry the values <parameter>VIEWERS</parameter> names, and the registry validates them: a
/// <code>viewer (source)</code> screen of the interoperability area, scoped to the namespace, with no read, table, action or
/// context field, three <code>promptGroupGettingStarted</code> prompts, the Interoperability menu's pair and its own, and the
/// classic page <code>%SYS.Portal.Resources.NormalizePage</code> answers for the <code>.zen</code> page, each page of its
/// <code>CLASSICPAGES</code> included. The Schema viewer is listed, takes no id and has no entity type; the Configuration
/// diagram is unlisted, parent-scoped under Productions, and keyed by a production.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_EDISchema:READ</code> from the Schema viewer -- the pair legs go red here, and
/// <class>OcuPilot.Test.InteropFloor</class>'s Administrator roster goes red. Empty its <code>CLASSICPAGES</code> -- the
/// <code>CLASSICPAGES</code> leg goes red here and <method>TestTheSchemaViewerHonorsEveryClassicPage</method> goes red.</p>
Method TestTheViewerScreensRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    For tI = 1:1:$Length(..#VIEWERS, ";") {
        Set tRow = $Piece(..#VIEWERS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Kill tDeclaration
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.built _ "|" _ tDeclaration.refreshes, $Piece(tRow, "|", 2) _ "|interoperability|" _ $Piece(tRow, "|", 3) _ "|viewer (source)|namespace|1|0", tClass _ ": route, area, side-bar position, archetype, scope, built and not refreshing")
        Do $$$AssertEquals(tDeclaration.labelKey _ "|" _ tDeclaration.emptyStateKey _ "|" _ tDeclaration.toolIdentifier, $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 5) _ "|" _ $Piece(tRow, "|", 7), tClass _ ": label, empty sentence and tool identifier")
        Set tOwn = $Piece(tRow, "|", 14)
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""" _ tOwn _ """,""permission"":""READ""}]", tClass _ ": the Interoperability menu's pair, then its own")
        Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""" _ tOwn _ """,""permission"":""READ""}]", tClass _ ": " _ tOwn _ ":READ is its own pair")
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.parentScope _ "|" _ tDeclaration.id.%ToJSON(), $Piece(tRow, "|", 9) _ "|" _ $Piece(tRow, "|", 10) _ "|{""kind"":""" _ $Piece(tRow, "|", 11) _ """,""parts"":[]}", tClass _ ": its entity type, parent and id")
        Do $$$AssertEquals(tDeclaration.%IsDefined("read") _ tDeclaration.%IsDefined("table"), "00", tClass _ ": no read and no table of its own")
        Set tAliases = ""
        For tJ = 1:1:tDeclaration.commandAliases.%Size() Set tAliases = tAliases _ $Select(tAliases = "": "", 1: ",") _ tDeclaration.commandAliases.%Get(tJ - 1)
        Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.context.fields.%Size() _ "|" _ tDeclaration.context.secretFields.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tAliases, "0|0|0||" _ $Piece(tRow, "|", 12), tClass _ ": no action or context field, and its command aliases")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        For tJ = 1:1:3 {
            Set tPrompt = tDeclaration.suggestedPrompts.%Get(tJ - 1)
            Do $$$AssertEquals($Select($IsObject(tPrompt): tPrompt.groupKey _ "|" _ tPrompt.textKey, 1: ""), "promptGroupGettingStarted|" _ $Piece(tRow, "|", 8) _ tJ, tClass _ ": prompt " _ tJ _ " is its own, in the getting-started group")
        }
        Set tPage = $Piece(tRow, "|", 6)
        Do $$$AssertEquals(tDeclaration.classicPage, tPage, tClass _ ": its classic page")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $Piece(tRow, "|", 13), tClass _ ": the further classic pages it replaces")
        Set tPages = $ListBuild(tPage) _ $ListFromString($Piece(tRow, "|", 13), ",")
        For tJ = 1:1:$ListLength(tPages) {
            Do $$$AssertEquals(..NormalizedPage($List(tPages, tJ) _ ".zen"), $List(tPages, tJ), tClass _ ": the portal's own resolver answers " _ $List(tPages, tJ) _ " for its page")
        }
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($Piece(tRow, "|", 7)), tClass, tClass _ ": its tool identifier resolves to it")
    }
}

/// <p>The Schema viewer replaces three classic pages (AD-44), and a custom resource assigned to any one of them gates it:
/// unarmed, <method>OcuPilot.Screen.Gate.RequiredPairs</method> answers the declared set, and with a resource armed on
/// each page in turn it adds that resource at <code>USE</code>. It runs through <class>OcuPilot.Test.ScreenGate</class>, whose
/// answers live in process-private globals, so nothing is written to the instance.</p>
/// <p>Mutation (Rule 19): drop the <code>CLASSICPAGES</code> line from <method>OcuPilot.Screen.Gate.RequiredPairs</method> -- the
/// X12 and ASTM legs go red.</p>
Method TestTheSchemaViewerHonorsEveryClassicPage()
{
    Set tClass = "OcuPilot.Screen.Descriptor.InteropSchemaViewer"
    Set tPages = $ListBuild($ClassMethod(tClass, "ClassicPage")) _ $ListFromString($Parameter(tClass, "CLASSICPAGES"), ",")
    Do $$$AssertEquals($ListLength(tPages), 3, "the viewer replaces the HL7, X12 and ASTM schema pages")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Try {
        Set tDeclared = ##class(OcuPilot.Test.ScreenGate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertTrue(tResolved, "its requirement resolves")
        Do $$$AssertEquals($ListLength(tDeclared), 2, "unarmed, it requires the declared set")
        Do $$$AssertEquals($List($List(tDeclared, 1), 1) _ ":" _ $List($List(tDeclared, 1), 2) _ "|" _ $List($List(tDeclared, 2), 1) _ ":" _ $List($List(tDeclared, 2), 2), "%Ens_Portal:USE|%Ens_EDISchema:READ", "the Interoperability menu's pair and its own")
        For tI = 1:1:$ListLength(tPages) {
            Set tPage = $List(tPages, tI)
            Do ##class(OcuPilot.Test.ScreenGate).Reset()
            Do ##class(OcuPilot.Test.ScreenGate).AssignClassic(tPage, ..#PROBERESOURCE)
            Set tArmed = ##class(OcuPilot.Test.ScreenGate).RequiredPairs(tClass, .tResolved)
            Do $$$AssertTrue(tResolved, tPage _ ": its requirement resolves")
            Do $$$AssertEquals($ListLength(tArmed), 3, tPage _ ": a custom resource on this page alone is added to the declared set")
            Do $$$AssertEquals($List($List(tArmed, 3), 1) _ ":" _ $List($List(tArmed, 3), 2), ..#PROBERESOURCE _ ":USE", tPage _ ": at USE")
        }
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        For tI = 1:1:$ListLength(tPages) Do ##class(OcuPilot.Test.ScreenGate).AssignClassic($List(tPages, tI), ..#PROBERESOURCE)
        Do $$$AssertEquals($ListLength(##class(OcuPilot.Test.ScreenGate).RequiredPairs(tClass)), 3, "one resource on all three pages is added once")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the gate leg ran: " _ ex.DisplayString())
    }
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p>The page <var>pPage</var> the portal's own resolver names, read in <code>%SYS</code> by explicit save and restore.</p>
ClassMethod NormalizedPage(pPage As %String) As %String
{
    Set tKey = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tKey = ##class(%SYS.Portal.Resources).NormalizePage(pPage)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tKey
}

}
