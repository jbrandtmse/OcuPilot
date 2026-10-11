/// <p>Pins Story 20.22's declarations (AD-3, AD-5, AD-8, AD-13, AD-36, AD-41, AD-44, AD-51, AD-59, AD-62): the Item
/// settings descriptor and its two tools; the setting decision matrix
/// (<method>OcuPilot.Port.InteropPort.SettingRefusalToken</method>); the item criterion's two spellings; the location
/// kinds; the scripts; every setting code resolving to its sentence; the shared parent of the production, item and
/// setting tools (DW-2268); the mint's four parts; and the per-call secret names the dispatcher redacts.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. It starts nothing and reads no production, so
/// it runs on any instance.</p>
Class OcuPilot.Test.InteropSettingDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.InteropItemSettingList";

/// <p>The two tools, <code>&lt;class&gt;|&lt;tool&gt;|&lt;write type&gt;|&lt;screen actions&gt;|&lt;sends body&gt;|&lt;subject&gt;</code>.</p>
Parameter TOOLS = "InteropSettingSet|interop.itemsettings.set|SET|set|1|;InteropSettingReset|interop.itemsettings.reset|RESET|reset|0|Value,Source,Default,Namespace";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The descriptor declares what the spec names: a built, unlisted tab (a <code>detail</code>, the item group's second) under the Production items list, its
/// four-part composite id, the Production items list's pairs, no primary action and Set and Reset as row actions,
/// three prompts, no secret field (the port answers none), and the interop source's Settings endpoint with the item
/// as its one criterion; and it passes the registry.</p>
/// <p>Mutation (Rule 19): change <code>parentScope</code> to <code>interoperability/productions</code> -- this goes
/// red.</p>
Method TestTheDescriptorDeclaresTheItemSettingsList()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.parentScope, "interoperability/productions/items/settings|interoperability|0|detail|namespace|interoperability/productions/items", "an unlisted namespace-scoped tab under the Production items list (Story 20.4 made it the item group's second tab)")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON(), "production-item-setting|composite|[""Production"",""Item"",""Target"",""Name""]", "the entity type and the composite [Production, Item, Target, Name]")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ "|" _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""}]|[{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""}]", "the Production items list's pairs, the classic page's resource as its own")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.primaryAction.id, "EnsPortal.ProductionConfig|interop.itemsettings|", "its classic page and tool identifier, and no primary action")
    Set tActions = ""
    Set tIterator = tDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions _ "|" _ tDeclaration.context.fields.%ToJSON() _ "|" _ tDeclaration.context.secretFields.%ToJSON(), "set,reset|[""Target"",""Name"",""Value"",""Source""]|[]", "its two row actions, its context fields and no secret field")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three suggested prompts")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "interop|Settings|LIST", "read through the interop port's Settings endpoint")
    Set tCriterion = tDeclaration.read.criteria.fields.%Get(0)
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Size() _ "|" _ tCriterion.param _ "|" _ tCriterion.maxLength _ "|" _ (tCriterion.hint '= ""), "1|item|352|1", "one criterion, the item, with a hint")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so do its criteria")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("production-item-setting"), "production-item-setting is in the kernel's vocabulary")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), "production-item-setting") > 0, "and in the prohibited set's covered types")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("production-item-setting")), "Value", "a change may set the value and nothing else")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("EnsPortal.Dialog.ProductionItemSettings"), "EnsPortal.Dialog.ProductionItemSettings", "the classic dialog is spelled as NormalizePage answers it (AD-44)")
}

/// <p>The screen and the tools describe one row: the tools' read answers are the declared read fields and the
/// port's two additions, and each tool reads the descriptor's tool identifier (AD-36, AD-52).</p>
/// <p>Mutation (Rule 19): drop <code>DefaultSource</code> from the descriptor's <code>read.fields</code> -- this goes
/// red.</p>
Method TestTheScreenAndTheToolsDescribeOneRow()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    If '$IsObject($Get(tDeclaration)) Quit
    Set tFields = ""
    Set tIterator = tDeclaration.read.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tField
    }
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece($Piece(..#TOOLS, ";", tI), "|", 1)
        Do $$$AssertEquals($Parameter(tTool, "READANSWERS"), tFields _ ",Namespace,Count", $Parameter(tTool, "TOOLNAME") _ ": its fresh read answers the screen's fields, the namespace and the count")
        Do $$$AssertEquals($Parameter(tTool, "DESCRIPTORCLASS"), ..#DESCRIPTOR, $Parameter(tTool, "TOOLNAME") _ ": it writes for the Item settings screen")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).NameFor(..#DESCRIPTOR), "interop.itemsettings.read", "the derived read tool is interop.itemsettings.read")
}

/// <p>Each tool declares what the spec names: the port and endpoint, the <code>SETTING</code> read, its own write
/// type and screen action, body or none, the subject and the markers of its fingerprint, the change action, its
/// governance key enabled, the mint, and the one value an action may send empty.</p>
/// <p>Mutation (Rule 19): set <code>interop.itemsettings.reset</code> <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- this goes red.</p>
Method TestTheToolShapes()
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Set tSet = ($Piece(tRow, "|", 3) = "SET")
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|SETTING|" _ ..#PORT _ "|Settings", tTool _ ": its name, write and read types, port and endpoint")
        Do $$$AssertEquals($ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "Creates"), $Piece(tRow, "|", 5) _ "|0|updated|" _ $Piece(tRow, "|", 4) _ "|0", tTool _ ": body, not destructive, updated, its one action, not a create")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")), $Piece(tRow, "|", 6), tTool _ ": its fingerprint subject")
        Do $$$AssertEquals($ClassMethod(tTool, "MintClass"), "OcuPilot.Screen.Tool.InteropSettingMint", tTool _ ": it mints the four-part composite id")
        Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") = 1, tTool _ " is advertised")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", tTool _ " passes the subject's adequacy rule")
        Do $$$AssertEquals($Parameter(tTool, "STATEMARKER"), "Source", tTool _ ": the stored payload is marked by its source")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionValueNames", $Piece(tRow, "|", 4))) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionEmptyNames", $Piece(tRow, "|", 4))), $Select(tSet: "Value|Value", 1: "|"), tTool _ ": only the set takes a value, and may take it empty")
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"Name": "N"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")), $Piece(tRow, "|", 3), tTool _ ": the read made from the call's arguments is composed for its action")
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"Source": "production", "Namespace": "USER"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("namespace")), "|USER", tTool _ ": the read made from the stored payload names its namespace and no action")
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertEquals(tSchema.required.%ToJSON(), $Select(tSet: "[""Name"",""Production"",""Item"",""Target"",""Value""]", 1: "[""Name"",""Production"",""Item"",""Target""]"), tTool _ " requires " _ tSchema.required.%ToJSON())
        Do $$$AssertEquals(tSchema.properties.Target.enum.%ToJSON(), "[""Core"",""Host"",""Adapter""]", tTool _ ": the group is one of the three")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed($Piece(tRow, "|", 2), .tListed) _ "|" _ tListed, "1|1", tTool _ ": listed in the governance baseline, enabled")
    }
    Set tReset = "OcuPilot.Screen.Tool.InteropSettingReset"
    Do $$$AssertEquals($Parameter(tReset, "STATEFIELD") _ "|" _ $Parameter(tReset, "PRECONDITIONFIELD") _ "|" _ $Parameter(tReset, "CLASSICPAGES"), "Source|Source|EnsPortal.Dialog.ProductionItemSettings", "reset: its markers and the classic dialog where a reset is chosen")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.InteropSettingSet", "CLASSICPAGES"), "", "set declares no classic page: it is performed on the production configuration page itself")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.InteropSettingSet", "READBACKFIELDS"), "Value", "set's read-back compares the value")
}

/// <p>Each tool's pairs are the screen's two, then <code>%Ens_ProductionConfig:WRITE</code>, then WRITE on the
/// request namespace's globals database, then the routines database's where it is another resource, then the custom
/// resource of each classic page the tool declares; in <code>USER</code>, <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <code>ROUTINESDATABASE</code> from
/// <class>OcuPilot.Screen.Tool.InteropItemAction</class> -- the routines row of a split namespace goes red in
/// <class>OcuPilot.Test.InteropItemGateSplit</class>.</p>
Method TestTheToolPairsAreTheItemWrites()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tGlobals, .tReadOnly)
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase("USER", .tRoutines, .tReadOnly)
    Set tExpected = "%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:WRITE," _ tGlobals _ ":WRITE" _ $Select(tRoutines = tGlobals: "", 1: "," _ tRoutines _ ":WRITE")
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece($Piece(..#TOOLS, ";", tI), "|", 1)
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Do $$$AssertEquals(tResolved _ "|" _ tText, "1|" _ tExpected, $Parameter(tTool, "TOOLNAME") _ "'s pairs")
    }
}

/// <p>The decision matrix of <method>OcuPilot.Port.InteropPort.SettingRefusalToken</method>: a name two items bear,
/// a value a service registry supplies, a system default's Core setting, and for a reset an item's own property and a
/// setting the production holds no value of; and the codes the tokens name.</p>
/// <p>Mutation (Rule 19): drop the <code>CORE</code> refusal -- the Core reset rows go red; swap the <code>CORE</code>
/// and <code>DEFAULTED</code> lines -- the Core row with a class default goes red; drop the <code>registry</code> arm of
/// <method>OcuPilot.Port.InteropPort.SourceWord</method> -- the source-word row goes red.</p>
Method TestTheSettingRefusalTokenMatrix()
{
    ; type, target, source, count, expected
    For tCase = $ListBuild("SET", "Host", 1, 1, ""), $ListBuild("SET", "Host", 2, 1, ""), $ListBuild("SET", "Host", 3, 1, ""), $ListBuild("SET", "Adapter", 4, 1, "SUPPLIED"), $ListBuild("SET", "Core", 2, 1, "SUPPLIED"), $ListBuild("SET", "Core", 1, 1, ""), $ListBuild("SET", "Core", 3, 1, ""), $ListBuild("SET", "Host", 1, 2, "AMBIGUOUS"),
        $ListBuild("RESET", "Host", 1, 1, ""), $ListBuild("RESET", "Host", 3, 1, "DEFAULTED"), $ListBuild("RESET", "Host", 2, 1, "DEFAULTED"), $ListBuild("RESET", "Adapter", 4, 1, "SUPPLIED"), $ListBuild("RESET", "Core", 1, 1, "CORE"), $ListBuild("RESET", "Core", 3, 1, "CORE"), $ListBuild("RESET", "Core", 2, 1, "SUPPLIED"), $ListBuild("RESET", "Host", 1, 3, "AMBIGUOUS") {
        Set tToken = $ClassMethod(..#PORT, "SettingRefusalToken", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Do $$$AssertEquals(tToken, $List(tCase, 5), $List(tCase, 1) _ " of a " _ $List(tCase, 2) _ " setting from source " _ $List(tCase, 3) _ ", " _ $List(tCase, 4) _ " item(s)")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "SettingCode", "AMBIGUOUS"), "INTEROP.ITEM.AMBIGUOUS", "an ambiguous name is the item code")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SettingCode", "DEFAULTED"), "INTEROP.SETTING.DEFAULTED", "any other token is a setting code")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SettingCode", ""), "", "and none is none")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SameValue", "Host", 1, "7", "7") _ $ClassMethod(..#PORT, "SameValue", "Host", 3, "7", "7") _ $ClassMethod(..#PORT, "SameValue", "Core", 3, "a", "a") _ $ClassMethod(..#PORT, "SameValue", "Core", 1, "a", "b"), "1010", "a Host value is the same only when the production holds it; a Core one when the property does")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SourceWord", 1) _ "," _ $ClassMethod(..#PORT, "SourceWord", 2) _ "," _ $ClassMethod(..#PORT, "SourceWord", 3) _ "," _ $ClassMethod(..#PORT, "SourceWord", 4) _ "," _ $ClassMethod(..#PORT, "SourceWord", 0), "production,systemDefault,classDefault,registry,", "each value source code reads as its word, a service registry entry as registry, and any other code as none")
}

/// <p>The Settings list's item criterion takes the item's composite id, which the screen's route carries, and the
/// vendor's config name <code>Production||Item</code>, which the read tool's hint asks for; no other spelling.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ItemParts</method> accept a vertical bar inside a
/// name -- the bar rows go red.</p>
Method TestTheItemCriterionTakesTwoSpellings()
{
    Set tSep = $Char(1)
    For tCase = $ListBuild("P" _ tSep _ "I", 1, "P", "I"), $ListBuild("P||I", 1, "P", "I"), $ListBuild("A.B||My Item", 1, "A.B", "My Item"), $ListBuild("", 0, "", ""), $ListBuild("P", 0, "", ""), $ListBuild("P" _ tSep, 0, "", ""), $ListBuild(tSep _ "I", 0, "", ""), $ListBuild("P" _ tSep _ "I" _ tSep _ "X", 0, "", ""), $ListBuild("P||", 0, "", ""), $ListBuild("||I", 0, "", ""), $ListBuild("P||I|X", 0, "", ""), $ListBuild("P|I", 0, "", "") {
        Set tOk = $ClassMethod(..#PORT, "ItemParts", $List(tCase, 1), .tProduction, .tItem)
        Do $$$AssertEquals(tOk _ "|" _ tProduction _ "|" _ tItem, $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), "'" _ $Translate($List(tCase, 1), tSep, "~") _ "'")
    }
}

/// <p>An editor context is a server path when its component, the part before <code>?</code>, is a directory or a file
/// selector (Story 20.22).</p>
/// <p>Mutation (Rule 19): drop <code>fileSelector</code> from
/// <method>OcuPilot.Port.InteropPort.LocationKind</method> -- the file rows go red.</p>
Method TestTheLocationKinds()
{
    For tCase = $ListBuild("directorySelector", "directory"), $ListBuild("fileSelector", "file"), $ListBuild("directorySelector?multiSelect=1", "directory"), $ListBuild("fileSelector?x=1&y=2", "file"), $ListBuild("", ""), $ListBuild("selector?context={a}", ""), $ListBuild("scheduleSelector", ""), $ListBuild("directoryselector", ""), $ListBuild("notdirectorySelector", "") {
        Do $$$AssertEquals($ClassMethod(..#PORT, "LocationKind", $List(tCase, 1)), $List(tCase, 2), "'" _ $List(tCase, 1) _ "'")
    }
}

/// <p>AD-59: each write's script switches to the namespace, opens the production with its lock, stores or removes
/// the setting through string literals, saves the item and the production class and drops the production on its last
/// line; a hostile name or value cannot become code, and the vendor's unsafe calls are never named.</p>
/// <p>Mutation (Rule 19): render the value without <code>Literal</code> -- the hostile-value row goes red.</p>
Method TestTheScriptForms()
{
    Set tQ = $Char(34)
    Set tSep = $Char(1)
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "P.Prod" _ tSep _ "Item" _ tSep _ "Host" _ tSep _ "InitSeconds"
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Settings", "SET") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Settings", "RESET") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Settings", "SETTING") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Settings", "LIST"), "objectscript|objectscript||", "a write has a script and a read has none")
    Set tBody = {"Value": "7"}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Settings", "SET", .tQuery, tBody)
    Set tText = tSteps.%Get(0).text
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", "one ObjectScript step")
    Set tWant = $ListBuild("Set $NAMESPACE = " _ tQ _ "USER" _ tQ, "%OpenId(" _ tQ _ "P.Prod" _ tQ _ ", 4)", "FindItemByConfigName(" _ tQ _ "Item" _ tQ _ ")", "FindSettingByName(" _ tQ _ "InitSeconds" _ tQ _ ", " _ tQ _ "Host" _ tQ _ ")", "tSetting.Value = " _ tQ _ "7" _ tQ, "tItem.%Save()", "SaveToClass(tItem)")
    Set tMissing = ""
    For tI = 1:1:$ListLength(tWant) {
        If tText '[ $List(tWant, tI) Set tMissing = tMissing _ $List(tWant, tI) _ "; "
    }
    Do $$$AssertEquals(tMissing, "", "a Host set names the namespace, the lock, the setting, the value, both saves")
    Do $$$AssertEquals($Piece(tText, $Char(10), $Length(tText, $Char(10))), " Kill tSetting, tItem, tProduction", "the production is dropped on the last line")
    Set tQuery("id") = "P.Prod" _ tSep _ "Item" _ tSep _ "Core" _ tSep _ "Comment"
    Set tBody = {"Value": ("a " _ tQ _ "quoted" _ tQ _ " value")}
    Set tText = $ClassMethod(..#PORT, "Snippet", "Settings", "SET", .tQuery, tBody).%Get(0).text
    Set tExpected = "Set $Property(tItem, " _ tQ _ "Comment" _ tQ _ ") = " _ tQ _ "a " _ tQ _ tQ _ "quoted" _ tQ _ tQ _ " value" _ tQ
    Do $$$AssertEquals((tText [ tExpected) _ "|" _ (tText [ "FindSettingByName"), "1|0", "a Core set stores the property, with the quotes doubled: " _ tText)
    Set tQuery("id") = "P.Prod" _ tSep _ "Item" _ tSep _ "Adapter" _ tSep _ "FilePath"
    Set tText = $ClassMethod(..#PORT, "Snippet", "Settings", "RESET", .tQuery, "").%Get(0).text
    Do $$$AssertEquals((tText [ "Settings.RemoveAt(tI)") _ (tText [ ("Name = " _ tQ _ "FilePath" _ tQ _ ")")) _ (tText [ ("Target = " _ tQ _ "Adapter" _ tQ _ ")")) _ (tText [ "SaveToClass(tItem)") _ (tText [ "tSetting.Value"), "11110", "a reset removes the element and sets no value: " _ tText)
    Set tQuery("id") = "P.Prod" _ tSep _ "Item" _ tSep _ "Host" _ tSep _ "InitSeconds"
    Set tBody = {"Value": ("x" _ $Char(13) _ tQ _ ");Kill ^X;")}
    Set tText = $ClassMethod(..#PORT, "Snippet", "Settings", "SET", .tQuery, tBody).%Get(0).text
    Set tLiteral = tQ _ "x" _ tQ _ "_$Char(13)_" _ tQ _ tQ _ tQ _ ");Kill ^X;" _ tQ
    Do $$$AssertEquals((tText [ tLiteral) _ "|" _ (tText [ "CleanProduction") _ "|" _ (tText [ "UpdateProduction"), "1|0|0", "a hostile value stays a literal: " _ tText)
    Set tRead = $ClassMethod(..#PORT, "Snippet", "Settings", "SETTING", .tQuery, "")
    Do $$$AssertEquals(tRead.%Size(), 0, "a read answers no step")
}

/// <p>Every setting code carries its published sentence through <class>OcuPilot.Api.InteropError</class>, a refused
/// tool call and a violation; the location consequence is a consequence; the refusals a setting tool's fresh read
/// answers are all declared, each through <class>OcuPilot.Api.Error</class>'s <code>ReasonForViolation</code>, the three
/// path codes among them; and the two violations and <code>SAME</code> are not among them.</p>
/// <p>Mutation (Rule 19): drop <code>SETTINGDESCENT</code> from
/// <method>OcuPilot.Api.InteropError.ReasonFor</method> -- this goes red.</p>
Method TestEverySettingCodeResolves()
{
    Set tError = "OcuPilot.Api.InteropError"
    Set tCodes = $ClassMethod(tError, "SettingCodes") _ $ListBuild($Parameter(tError, "SETTINGLOCATION"))
    Do $$$AssertEquals($ListLength(tCodes), 8, "seven setting codes and one consequence")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tError, "ReasonFor", tCode)
        Do $$$AssertTrue((tCode [ "INTEROP.SETTING.") && (tReason '= ""), tCode _ ": a code and a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": a refused tool call carries it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": and a violation")
    }
    Do $$$AssertTrue($ListFind($ClassMethod(tError, "ConsequenceCodes"), $Parameter(tError, "SETTINGLOCATION")) > 0, "the location code is a consequence")
    For tCode = $Parameter(tError, "SETTINGVALUE"), $Parameter(tError, "SETTINGDESCENT"), $Parameter(tError, "SETTINGSAME"), $Parameter(tError, "SETTINGLOCATION") {
        Do $$$AssertTrue('$ListFind($ClassMethod(tError, "SettingPreconditionCodes"), tCode), tCode _ " is not a refusal of a fresh read")
    }
    Set tReset = $ClassMethod("OcuPilot.Screen.Tool.InteropSettingReset", "PreconditionCodes")
    Do $$$AssertEquals($ListLength(tReset), 11, "reset names eleven refusals of its fresh read")
    For tI = 1:1:$ListLength(tReset) {
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).ReasonForViolation($List(tReset, tI)) '= "", $List(tReset, tI) _ ": a sentence through ReasonForViolation")
    }
    For tCode = "PATH.MANAGERDIR", "PATH.SERVED", "PATH.MANAGER" {
        Do $$$AssertTrue($ListFind(tReset, tCode) > 0, tCode _ ": reset names it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), ##class(OcuPilot.Api.Error).ReasonForPath(tCode), tCode _ ": with PathPort's own sentence")
    }
}

/// <p>DW-2268: the production, item and setting tools inherit what they declare alike from
/// <class>OcuPilot.Screen.Tool.InteropAction</class>: neither <class>OcuPilot.Screen.Tool.InteropProductionAction</class>
/// nor <class>OcuPilot.Screen.Tool.InteropItemAction</class> declares the six methods any more, and the parent does.</p>
/// <p>Mutation (Rule 19): add <code>PortQuery</code> back to <class>OcuPilot.Screen.Tool.InteropItemAction</class> -- this
/// goes red.</p>
Method TestTheSharedParentHoldsTheSixMethods()
{
    Set tParent = "OcuPilot.Screen.Tool.InteropAction"
    For tMethod = "IdArgument", "IdParam", "SettableFields", "Consequence", "PortQuery", "PrivilegePairs" {
        Do $$$AssertTrue(##class(%Dictionary.MethodDefinition).%ExistsId(tParent _ "||" _ tMethod), tMethod _ " is declared once, on the parent")
        For tChild = "InteropProductionAction", "InteropItemAction" {
            Do $$$AssertTrue('##class(%Dictionary.MethodDefinition).%ExistsId("OcuPilot.Screen.Tool." _ tChild _ "||" _ tMethod), tChild _ " does not declare " _ tMethod)
        }
    }
    For tChild = "InteropProductionAction", "InteropItemAction", "InteropSettingAction" {
        Do $$$AssertTrue($ClassMethod("OcuPilot.Screen.Tool." _ tChild, "%Extends", tParent), tChild _ " extends the parent")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.InteropProductionAction", "STATEMARKER") _ "|" _ $Parameter("OcuPilot.Screen.Tool.InteropItemAction", "STATEMARKER") _ "|" _ $Parameter("OcuPilot.Screen.Tool.InteropProductionAction", "ROUTINESDATABASE") _ "|" _ $Parameter("OcuPilot.Screen.Tool.InteropItemAction", "ROUTINESDATABASE"), "State|Enabled|0|1", "each keeps its own marker and whether it writes the routines database")
}

/// <p>The mint joins the four parts of a setting's id in order and holds each of the three leading ones to the rules
/// of the first: not empty and free of the composite separator, with the argument named in the refusal; a mapping
/// mint is unchanged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.MappingMint.PartArguments</method> answer only the first
/// argument -- the Item row goes red.</p>
Method TestTheMintHoldsEachLeadingPart()
{
    Set tMint = "OcuPilot.Screen.Tool.InteropSettingMint"
    Do $$$AssertEquals($ListToString($ClassMethod(tMint, "PartArguments")), "Production,Item,Target", "a setting's leading parts")
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.InteropItemMint", "PartArguments")), "Production", "an item's")
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.MappingMint", "PartArguments")), "Namespace", "and a mapping's")
    Set tSep = $Char(1)
    For tCase = $ListBuild("Production", "", "'Production' names the production the item belongs to and cannot be empty"), $ListBuild("Item", "", "'Item' names the item the setting belongs to and cannot be empty"), $ListBuild("Target", "", "'Target' names the group the setting belongs to: Core, Host or Adapter and cannot be empty"), $ListBuild("Name", "", "'Name' names the setting and cannot be empty"),
        $ListBuild("Item", "a" _ tSep _ "b", "'Item' carries the character U+0001, which no production, item, group or setting name holds"), $ListBuild("Name", "a" _ tSep _ "b", "'Name' carries the character U+0001, which no production, item, group or setting name holds") {
        Set tArgs = {"Production": "P", "Item": "I", "Target": "Host", "Name": "N"}
        Do tArgs.%Set($List(tCase, 1), $List(tCase, 2), "string")
        Set tSC = $ClassMethod(tMint, "Mint", "d", "t", "u", "", "", tArgs, "", .tProposal, .tHttp, .tFault, "Settings", "id", tArgs.Name, "Name")
        Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.detail.problem, 1: ""), "400|" _ $List(tCase, 3), "an argument of '" _ $List(tCase, 1) _ "' that breaks the rule is refused")
    }
}

/// <p>AD-3, AD-41: a tool answers the argument names its ledger row and step redact for one call
/// (<method>OcuPilot.Screen.Tool.Write.CallSecretNames</method>): none by default, and <code>Value</code> from a
/// setting tool whose call names a setting the credential pattern matches; the registry answers the tool's names
/// and none for a read tool or a call that is not an object.</p>
/// <p>Mutation (Rule 19): answer <code>Value</code> whatever the name -- the ordinary-name rows go red.</p>
Method TestTheCallSecretNamesAreTheSettingToolsAlone()
{
    Do $$$AssertEquals($ListLength($ClassMethod("OcuPilot.Screen.Tool.InteropItemEnable", "CallSecretNames", {"Name": "ApiToken"})), 0, "a tool that names none answers none")
    For tTool = "InteropSettingSet", "InteropSettingReset" {
        Set tClass = "OcuPilot.Screen.Tool." _ tTool
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CallSecretNames", {"Name": "ApiToken", "Value": "x"})), "Value", tTool _ ": a credential-named setting redacts the value")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CallSecretNames", {"Name": "client_secret"})), "Value", tTool _ ": so does a compound name")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Name": "InitSeconds", "Value": "7"})), 0, tTool _ ": an ordinary name redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Value": "7"})), 0, tTool _ ": a call with no name redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", "")), 0, tTool _ ": and a call that is not an object redacts nothing")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.itemsettings.set", .tSet)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.itemsettings.read", .tRead)
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.Registry).CallSecretNames(tSet, {"Name": "ApiToken"})), "Value", "the registry answers the set tool's names")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Tool.Registry).CallSecretNames(tRead, {"Name": "ApiToken"})), 0, "and none for the read tool")
}

}
