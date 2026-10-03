/// <p>Pins Story 19.1's declarations: the System Explorer area's row, its two lists and two viewers
/// -- each validated, read through the source code API port, gated on the measured pair, keyed to a
/// classic page the portal's own resolver answers, and carrying at least three prompts in the Code
/// group -- the two editors since Story 19.3, form pages with no read and no classic page; Search,
/// Compare and Macros since Story 19.4, two reads with no classic page and a form page keyed to the
/// classic Compare Routines page; and the area's tools since Story 19.2: six reads and the two lists'
/// compile, delete, export, import and save, each write's baseline key, and the actions the lists
/// declare for them.</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and the classic portal's
/// classes. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.ExplorerDescriptor Extends %UnitTest.TestCase
{

/// <p>The nine descriptors: the five listed, in side-bar order, then viewers, then editors.</p>
Parameter DESCRIPTORS = "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList,OcuPilot.Screen.Descriptor.ExplorerSearch,OcuPilot.Screen.Descriptor.ExplorerCompare,OcuPilot.Screen.Descriptor.ExplorerMacro,OcuPilot.Screen.Descriptor.ExplorerClassDocument,OcuPilot.Screen.Descriptor.ExplorerRoutineDocument,OcuPilot.Screen.Descriptor.ExplorerClassEditor,OcuPilot.Screen.Descriptor.ExplorerRoutineEditor";

/// <p>The measured pair set every screen and the area declare.</p>
Parameter PAIRS = "[{""resource"":""%Development"",""permission"":""USE""}]";

/// <p>The area's row, as the rail declares it.</p>
Method TestTheAreaIsTheEighthRailItem()
{
    Set tArea = ##class(OcuPilot.Screen.Area).Find("system-explorer")
    Do $$$AssertTrue($IsObject(tArea), "the area is declared")
    If '$IsObject(tArea) Quit
    Do $$$AssertEquals(tArea.railPosition _ "|" _ tArea.labelKey _ "|" _ tArea.navigates _ "|" _ tArea.pinBottom, "8|navAreaSystemExplorer|0|0", "rail position 8, its own label, not navigating, not pinned")
    Do $$$AssertEquals(tArea.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE alone")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Area).Find("agent").railPosition, 9, "Agent co-pilot moves to 9")
    Set tSC = ##class(OcuPilot.Screen.Registry).ListedScreensForArea("system-explorer", .tListed)
    Do $$$AssertStatusOK(tSC, "the side bar reads")
    Do $$$AssertEquals($ListToString(tListed), "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList,OcuPilot.Screen.Descriptor.ExplorerSearch,OcuPilot.Screen.Descriptor.ExplorerCompare,OcuPilot.Screen.Descriptor.ExplorerMacro", "its side bar lists Classes, Routines, Search, Compare and Macros")
}

/// <p>Each declaration that reads validates, is gated on the measured pair, reads through the
/// atelier port, and keys a classic page the portal's own resolver answers (AD-44), or, for Search
/// and Macros, none.</p>
Method TestEachDeclarationValidatesAndIsGatedOnTheMeasuredPair()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the roster validates: " _ tProblem)
    Set tPackage = "OcuPilot.Screen.Descriptor."
    Set tExpected = $ListBuild($ListBuild("ExplorerClassList", "system-explorer/classes", 1, "list (server criteria)", "class", "Classes", "%CSP.UI.Portal.ClassList", "explorer.classes"), $ListBuild("ExplorerRoutineList", "system-explorer/routines", 2, "list (server criteria)", "routine", "Routines", "%CSP.UI.Portal.RoutineList", "explorer.routines"), $ListBuild("ExplorerClassDocument", "system-explorer/classes/document", 0, "viewer (source)", "class", "Class", "%CSP.UI.Portal.ClassList", "explorer.class"), $ListBuild("ExplorerRoutineDocument", "system-explorer/routines/document", 0, "viewer (source)", "routine", "Routine", "%CSP.UI.System.ViewCode", "explorer.routine"), $ListBuild("ExplorerSearch", "system-explorer/search", 3, "list (server criteria)", "class", "Search", "", "explorer.search"), $ListBuild("ExplorerMacro", "system-explorer/macros", 5, "list (server criteria)", "routine", "Macro", "", "explorer.macro"))
    For tI = 1:1:$ListLength(tExpected) {
        Set tWant = $List(tExpected, tI)
        Set tClass = tPackage _ $List(tWant, 1)
        Set tWant = $List(tWant, 2, *)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": the declaration, its read and its criteria validate")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.area, $List(tWant, 1) _ "|" _ $List(tWant, 2) _ "|" _ $List(tWant, 3) _ "|" _ $List(tWant, 4) _ "|namespace|system-explorer", tClass _ ": its route, position, archetype, type and scope")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": gated on %Development:USE")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint, "atelier|" _ $List(tWant, 5), tClass _ ": read through the atelier port")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tWant, 6), tClass _ ": its classic page")
        If $List(tWant, 6) '= "" {
            Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace($List(tWant, 6), "%", "%25") _ ".zen"), $List(tWant, 6), tClass _ ": which the portal's own resolver answers")
            Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId($List(tWant, 6)), tClass _ ": and which is a compiled class")
        }
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tWant, 7)), tClass, tClass _ ": its tool identifier resolves to it")
        Do $$$AssertEquals(tDeclaration.read.%Get("document"), "", tClass _ ": declares no document of its own")
    }
}

/// <p>The lists' criteria carry the classic page's defaults; the viewers' carry the name and a form
/// defaulting to UDL. Their context never names the description or the text.</p>
Method TestTheCriteriaCarryTheClassicDefaults()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassList", "pattern=*,system=no,generated=no,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineList", "pattern=*.mac,system=no,generated=yes,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassDocument", "name=,form=udl"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineDocument", "name=,form=udl"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSearch", "text=,scope=all,case=no"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerMacro", "document=,macro=") {
        Set tSC = $ClassMethod($List(tCase, 1), "DeclarationJson", .tDeclaration)
        Set tSeen = ""
        Set tIterator = tDeclaration.read.criteria.fields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tField.param _ "=" _ tField.%Get("default")
        }
        Do $$$AssertEquals(tSeen, $List(tCase, 2), $List(tCase, 1) _ ": its criteria and defaults")
    }
    Set tSC = ##class(OcuPilot.Screen.Descriptor.ExplorerClassDocument).DeclarationJson(.tDeclaration)
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), "[""Kind"",""Name"",""Type"",""Flags""]", "screen context carries kind, name, type and flags alone")
}

/// <p>The read tools tell the model each declared default, since omitting a criterion reads it
/// (AD-36): the Routines pattern names <code>*.mac</code>, each include choice its own default, and
/// the viewer's form <code>udl</code>.</p>
/// <p>Mutation: drop the default clause from
/// <method>OcuPilot.Screen.Tool.Read.AddCriteria</method> -&gt; every assertion here goes red.</p>
Method TestTheReadToolsNameEachDefault()
{
    Set tRoutines = ##class(OcuPilot.Screen.Tool.Read).InputSchema("OcuPilot.Screen.Descriptor.ExplorerRoutineList").properties
    Do $$$AssertTrue(tRoutines.pattern.description [ "screen's default (*.mac)", "the Routines pattern names *.mac: " _ tRoutines.pattern.description)
    Do $$$AssertTrue(tRoutines.system.description [ "screen's default (no)", "system names no: " _ tRoutines.system.description)
    Do $$$AssertTrue(tRoutines.generated.description [ "screen's default (yes)", "generated names yes: " _ tRoutines.generated.description)
    Set tClass = ##class(OcuPilot.Screen.Tool.Read).InputSchema("OcuPilot.Screen.Descriptor.ExplorerClassDocument").properties
    Do $$$AssertTrue(tClass.form.description [ "screen's default (udl)", "the viewer's form names udl: " _ tClass.form.description)
}

/// <p>Every screen of the area declares at least three suggested prompts in the Code group.</p>
Method TestEveryScreenDeclaresThreePromptsInTheCodeGroup()
{
    For tI = 1:1:$Length(..#DESCRIPTORS, ",") {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Set tCount = 0
        Set tGroups = ""
        Set tIterator = tDeclaration.suggestedPrompts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPrompt) {
            Set tCount = tCount + 1
            If tPrompt.groupKey '= "webAppPromptGroupCode" Set tGroups = tGroups _ " " _ tPrompt.groupKey
        }
        Do $$$AssertTrue(tCount >= 3, tClass _ ": declares at least three prompts")
        Do $$$AssertEquals(tGroups, "", tClass _ ": all in the Code group")
    }
}

/// <p>Stories 19.2 AC9, 19.13 AC7 and 19.4 AC6: the area's advertised tools are its six reads and
/// eight writes, the lists' compile, delete, export and import, each over the source code API port with its
/// own request type, fingerprint subject and precondition -- a delete covers each document's modified
/// time and an import its reviewed documents; the compile and export keys are enabled and the delete,
/// import and save keys disabled at the baseline; and the two lists declare the seven row actions,
/// compile, delete and export acting on the checked rows, at most one hundred, while the viewers and
/// editors declare none. The two unadvertised saves are
/// <method>TestTheTwoSavesAreUnadvertisedDestructiveWrites</method>'s.</p>
/// <p>Mutation (Rule 19): enable a delete key in the baseline -- the baseline leg goes red.</p>
Method TestTheAreaHoldsSixReadsAndEightWrites()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists")
    If $$$ISERR(tSC) Quit
    Set tExplorer = ""
    Set tWriters = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If '##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tTool) Continue
        If $Extract(tTool.name, 1, 9) = "explorer." Set tExplorer = tExplorer _ $Select(tExplorer = "": "", 1: ",") _ tTool.name _ ":" _ tTool.kind
        If (tTool.kind '= "write") || (tTool.class = "") || ($Extract($Parameter(tTool.class, "DESCRIPTORCLASS"), 1, 35) '= "OcuPilot.Screen.Descriptor.Explorer") Continue
        Set tClass = tTool.class
        Set tWriters = tWriters _ $Select(tWriters = "": "", 1: ",") _ tTool.name _ ":" _ $Piece($Parameter(tClass, "DESCRIPTORCLASS"), ".", *) _ "/" _ $ClassMethod(tClass, "PortClass") _ "/" _ $ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "Destructive") _ "/" _ $ListToString($ClassMethod(tClass, "FingerprintSubject"), "+") _ "/" _ $ClassMethod(tClass, "PreconditionField")
    }
    Do $$$AssertEquals(tExplorer, "explorer.class.read:read,explorer.classes.compile:write,explorer.classes.delete:write,explorer.classes.export:write,explorer.classes.import:write,explorer.classes.read:read,explorer.macro.read:read,explorer.routine.read:read,explorer.routines.compile:write,explorer.routines.delete:write,explorer.routines.export:write,explorer.routines.import:write,explorer.routines.read:read,explorer.search.read:read", "the area's advertised tools are six reads and eight writes, and Compare has none")
    Do $$$AssertEquals(tWriters, "explorer.classes.compile:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/COMPILE/0/Present+Absent+Namespace+KeepSource+CompileDependents+SkipUpToDate/Present,explorer.classes.delete:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/DELETE/1/Modified+Absent+Namespace/Modified,explorer.classes.export:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/EXPORT/0/Present+Absent+Namespace+root+path/Present,explorer.classes.import:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/IMPORT/1/Namespace+root+path+fileName+content+documents+Compile/documents,explorer.routines.compile:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/COMPILE/0/Present+Absent+Namespace+KeepSource+CompileDependents+SkipUpToDate/Present,explorer.routines.delete:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/DELETE/1/Modified+Absent+Namespace/Modified,explorer.routines.export:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/EXPORT/0/Present+Absent+Namespace+root+path/Present,explorer.routines.import:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/IMPORT/1/Namespace+root+path+fileName+content+documents+Compile/documents", "each write names its list, the source code API port, its endpoint and type, its fingerprint subject and precondition, and the deletes and imports are destructive")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
    Do $$$AssertStatusOK(tSC, "the baseline reads")
    If $$$ISERR(tSC) Quit
    Set tBaselined = ""
    Set tIterator = tKeys.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $Extract(tKey, 1, 9) = "explorer." Set tBaselined = tBaselined _ $Select(tBaselined = "": "", 1: ",") _ tKey _ "=" _ $Select(tValue: "true", 1: "false")
    }
    Do $$$AssertEquals(tBaselined, "explorer.classes.compile=true,explorer.classes.delete=false,explorer.routines.compile=true,explorer.routines.delete=false,explorer.classes.export=true,explorer.routines.export=true,explorer.classes.import=false,explorer.classes.save=false,explorer.routines.save=false,explorer.routines.import=false", "the compile and export keys ship enabled and the delete, import and save keys disabled")
    For tI = 1:1:$Length(..#DESCRIPTORS, ",") {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Set tMulti = $Select($$$ISOK(tSC) && (tDeclaration.%GetTypeOf("multiSelect") = "object"): tDeclaration.multiSelect.%ToJSON(), 1: "")
        Set tWant = $Select(tI <= 2: "|compile,delete,export,export-browser,import,import-local,save|{""action"":""compile"",""max"":100,""extraActions"":[""delete"",""export""]}", 1: "||")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")) _ "|" _ tMulti, tWant, tClass _ ": its actions")
    }
}

/// <p>Story 19.3 AC7: the two lists' saves are unadvertised, destructive, action-style writes over the
/// source code API port's <code>SAVEDOCS</code> and <code>SAVE</code>, fingerprinting the document's
/// version, the namespace and the three values the list's <code>save</code> action declares -- the
/// text, the version and the compile choice -- none of which their closed schema advertises; and
/// they declare no classic page.</p>
Method TestTheTwoSavesAreUnadvertisedDestructiveWrites()
{
    For tCase = $ListBuild("OcuPilot.Screen.Tool.ExplorerClassSave", "explorer.classes.save", "ExplorerClassList", "Classes"), $ListBuild("OcuPilot.Screen.Tool.ExplorerRoutineSave", "explorer.routines.save", "ExplorerRoutineList", "Routines") {
        Set tClass = $List(tCase, 1)
        Do ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 2), .tEntry, 1)
        Do $$$AssertTrue($IsObject($Get(tEntry)) && (tEntry.class = tClass) && (tEntry.kind = "write") && (tEntry.advertised = 0), $List(tCase, 2) _ ": a registered, unadvertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "Advertised") _ "/" _ $Piece($Parameter(tClass, "DESCRIPTORCLASS"), ".", *) _ "/" _ $ClassMethod(tClass, "PortClass") _ "/" _ $ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "ReadType") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "SendsBody") _ "/" _ $ClassMethod(tClass, "Destructive") _ "/" _ $ClassMethod(tClass, "ChangeAction") _ "/" _ $ListToString($ClassMethod(tClass, "FingerprintSubject"), "+") _ "/" _ $ClassMethod(tClass, "PreconditionField") _ "/" _ $Parameter(tClass, "CLASSICPAGES"), "0/" _ $List(tCase, 3) _ "/OcuPilot.Port.AtelierPort/" _ $List(tCase, 4) _ "/SAVEDOCS/SAVE/0/1/updated/Modified+Absent+Namespace+content+version+Compile/Modified/", $List(tCase, 2) _ ": its declarations")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", $List(tCase, 2) _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "save")) _ " " _ $ListToString($ClassMethod(tClass, "SettableFields")), "save content,version,Compile content,version,Compile", $List(tCase, 2) _ ": carrying the list's save and its three values")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Set tNames = ""
        Set tIterator = tSchema.properties.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) { Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName }
        Do $$$AssertEquals(tNames _ " " _ tSchema.required.%ToJSON() _ " " _ tSchema.additionalProperties, "Names,rationale,expectedImpact,reverse [""Names""] 0", $List(tCase, 2) _ ": a closed schema naming the document alone")
        Set tOne = $Select($List(tCase, 4) = "Classes": "A.cls", 1: "A.mac")
        Do $$$AssertEquals($ClassMethod(tClass, "SetProblem", tOne) _ "|" _ ($ClassMethod(tClass, "SetProblem", tOne _ "," _ $Replace(tOne, "A.", "B.")) '= ""), "|1", $List(tCase, 2) _ ": exactly one document")
    }
}

/// <p>Story 19.3 AC2: the two editors validate as unlisted form pages at their list's route plus
/// <code>/editor</code>, gated on the measured pair, declaring no read, no table, no action and no
/// context field, the viewer's own prompts, and no classic page and no exemption, so they carry no
/// classic link: new capability, not parity. Their screen context names no tool.</p>
/// <p>Mutation (Rule 19): set <code>classicPage</code> on
/// <class>OcuPilot.Screen.Descriptor.ExplorerClassEditor</class> -- this goes red.</p>
Method TestTheEditorsAreFormPagesWithNoClassicPage()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassEditor", "system-explorer/classes/editor", "class", "explorer.classeditor", "OcuPilot.Screen.Descriptor.ExplorerClassDocument"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineEditor", "system-explorer/routines/editor", "routine", "explorer.routineeditor", "OcuPilot.Screen.Descriptor.ExplorerRoutineDocument") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.area _ "|" _ tDeclaration.id.kind, $List(tCase, 2) _ "|0|form-page|" _ $List(tCase, 3) _ "|namespace|system-explorer|single", tClass _ ": an unlisted form page keyed by one document")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": gated on %Development:USE")
        Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "unassigned|unassigned|0||{""fields"":[],""secretFields"":[]}", tClass _ ": no read, no table, no action and no context field")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicPage _ "|" _ tDeclaration.classicLinkExemption.exempt, "||0", tClass _ ": no classic page and no exemption")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 4)), tClass, tClass _ ": its tool identifier resolves to it")
        Set tSC = $ClassMethod($List(tCase, 5), "DeclarationJson", .tViewer)
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%ToJSON(), $Select($$$ISOK(tSC): tViewer.suggestedPrompts.%ToJSON(), 1: ""), tClass _ ": the viewer's own prompts")
        Kill tTools
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), tClass _ ": its context tools build")
        Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[]", tClass _ ": and name none")
    }
}

/// <p>Story 19.4 AC7: Compare is a listed form page with no read, no table, no action, no context
/// field and no tool, keyed to the classic Compare Routines page, which the portal's own resolver
/// answers and whose compiled <code>RESOURCE</code> is <code>%Development:USE</code>, the pair it
/// declares; Search and Macros declare no classic page.</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Screen.Descriptor.ExplorerCompare</class>'s
/// <code>classicPage</code> to <code>""</code> -- this goes red.</p>
Method TestCompareKeysTheClassicCompareRoutinesPage()
{
    Set tClass = "OcuPilot.Screen.Descriptor.ExplorerCompare"
    Set tPage = "%CSP.UI.Portal.RoutineCompare"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.secondaryEntityTypes.%ToJSON() _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind, "system-explorer/compare|4|form-page|class|[""routine""]|namespace|none", "a listed form page over classes and routines, keyed by nothing")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "unassigned|unassigned|0||{""fields"":[],""secretFields"":[]}", "no read, no table, no action and no context field")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicLinkExemption.exempt, tPage _ "|0", "keyed to the classic Compare Routines page, with no exemption")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace(tPage, "%", "%25") _ ".zen"), tPage, "which the portal's own resolver answers")
    Set tResource = ##class(%Dictionary.CompiledParameter).%OpenId(tPage _ "||RESOURCE")
    Do $$$AssertEquals($Select($IsObject(tResource): tResource.Default, 1: ""), "%Development:USE", "and whose compiled RESOURCE is the pair it declares")
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.compare.read", .tEntry, 1)
    Do $$$AssertTrue('$IsObject($Get(tEntry)), "it has no read tool")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), "its context tools build")
    Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[]", "and name none")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("explorer.compare"), tClass, "its tool identifier resolves to it")
    For tOther = "OcuPilot.Screen.Descriptor.ExplorerSearch", "OcuPilot.Screen.Descriptor.ExplorerMacro" {
        Do $$$AssertEquals($ClassMethod(tOther, "ClassicPage"), "", tOther _ " declares no classic page")
    }
}

}
