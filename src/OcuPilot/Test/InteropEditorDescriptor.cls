/// <p>Pins Story 20.7's three editor screens with nothing written (AD-5, AD-8, AD-44, AD-63): the rule, BPL and DTL
/// editors are unlisted <code>viewer (source)</code> screens at their list's route with <code>/document</code> appended,
/// each declaring the pair set of the lists that open it, no read and no table, three prompts and the classic editor page the
/// portal's own resolver names, and each classic page's compiled <code>RESOURCE</code> holds the screen's own pair.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and the <code>EnsPortal</code> editor pages, which
/// the <code>HSCUSTOM</code> namespace holds. It runs unarmed and writes nothing.</p>
Class OcuPilot.Test.InteropEditorDescriptor Extends %UnitTest.TestCase
{

/// <p>The three screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;label key&gt;|&lt;empty key&gt;|&lt;classic page&gt;|&lt;tool identifier&gt;|&lt;prompt key prefix&gt;</code>.</p>
Parameter SCREENS = "InteropRuleEditor|interoperability/rules/document|interopRuleEditorTitle|interopRuleEditorEmpty|EnsPortal.RuleEditor|interop.ruleeditor|interopRuleEditorPrompt;InteropProcessEditor|interoperability/processes/document|interopBplEditorTitle|interopBplEditorEmpty|EnsPortal.BPLEditor|interop.processeditor|interopBplEditorPrompt;InteropTransformEditor|interoperability/transforms/document|interopDtlEditorTitle|interopDtlEditorEmpty|EnsPortal.DTLEditor|interop.transformeditor|interopDtlEditorPrompt";

/// <p>The pair set every editor declares: the Interoperability menu's and, as its own, the code lists'.</p>
Parameter PAIRS = "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Code"",""permission"":""READ""}]";

Parameter OWNPAIRS = "[{""resource"":""%Ens_Code"",""permission"":""READ""}]";

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
/// when no permission is given), so the screen opens for exactly the roles that open the classic editor (AD-8, AD-44).</p>
/// <p>Mutation (Rule 19): declare <code>%Ens_Code:USE</code> as one editor's own pair -- this goes red naming the page.</p>
Method TestEachClassicEditorSharesTheScreensPair()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Set tPage = $Piece(tRow, "|", 5)
        Do $$$AssertTrue(##class(OcuPilot.Test.DeveloperFloor).Compiled(tPage), tClass _ ": its classic page " _ tPage _ " is compiled")
        Set tResource = ##class(OcuPilot.Test.DeveloperFloor).ClassicResource(tPage, .tHasResource)
        Do $$$AssertTrue(tHasResource, tPage _ " compiles a RESOURCE parameter: '" _ tResource _ "'")
        Set tShared = 0
        For tJ = 1:1:$Length(tResource, ",") {
            Set tMember = $Piece($Piece(tResource, ",", tJ), ":", 1)
            Set tPermission = $Piece($Piece(tResource, ",", tJ), ":", 2)
            If tMember = "" Continue
            If tPermission = "" Set tPermission = "USE"
            If $ListFind($ClassMethod(tClass, "OwnPrivilegePairs"), $ListBuild(tMember, tPermission)) Set tShared = 1
        }
        Do $$$AssertTrue(tShared, tClass _ ": its own pair is a member of " _ tPage _ "'s RESOURCE '" _ tResource _ "'")
        Do $$$AssertTrue(tResource [ "%Ens_Code:READ", tPage _ "'s RESOURCE names %Ens_Code:READ: '" _ tResource _ "'")
    }
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
