/// <p>Pins Story 19.1's declarations: the System Explorer area's row, its two lists and two viewers
/// -- each validated, read through the source code API port, gated on the measured pair, keyed to a
/// classic page the portal's own resolver answers, and carrying at least three prompts in the Code
/// group -- and the area's tools since Story 19.2: four reads and the two lists' compile and delete,
/// each write's baseline key, and the actions the lists declare for them.</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and the classic portal's
/// classes. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.ExplorerDescriptor Extends %UnitTest.TestCase
{

/// <p>The four descriptors, in side-bar order then viewers.</p>
Parameter DESCRIPTORS = "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList,OcuPilot.Screen.Descriptor.ExplorerClassDocument,OcuPilot.Screen.Descriptor.ExplorerRoutineDocument";

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
    Do $$$AssertEquals($ListToString(tListed), "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList", "its side bar lists Classes then Routines")
}

/// <p>Each declaration validates, is gated on the measured pair, reads through the atelier port,
/// and keys a classic page the portal's own resolver answers (AD-44).</p>
Method TestEachDeclarationValidatesAndIsGatedOnTheMeasuredPair()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the roster validates: " _ tProblem)
    Set tExpected = $ListBuild($ListBuild("system-explorer/classes", 1, "list (server criteria)", "class", "Classes", "%CSP.UI.Portal.ClassList", "explorer.classes"), $ListBuild("system-explorer/routines", 2, "list (server criteria)", "routine", "Routines", "%CSP.UI.Portal.RoutineList", "explorer.routines"), $ListBuild("system-explorer/classes/document", 0, "viewer (source)", "class", "Class", "%CSP.UI.Portal.ClassList", "explorer.class"), $ListBuild("system-explorer/routines/document", 0, "viewer (source)", "routine", "Routine", "%CSP.UI.System.ViewCode", "explorer.routine"))
    For tI = 1:1:4 {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tWant = $List(tExpected, tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": the declaration, its read and its criteria validate")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.area, $List(tWant, 1) _ "|" _ $List(tWant, 2) _ "|" _ $List(tWant, 3) _ "|" _ $List(tWant, 4) _ "|namespace|system-explorer", tClass _ ": its route, position, archetype, type and scope")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": gated on %Development:USE")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint, "atelier|" _ $List(tWant, 5), tClass _ ": read through the atelier port")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tWant, 6), tClass _ ": its classic page")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace($List(tWant, 6), "%", "%25") _ ".zen"), $List(tWant, 6), tClass _ ": which the portal's own resolver answers")
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId($List(tWant, 6)), tClass _ ": and which is a compiled class")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tWant, 7)), tClass, tClass _ ": its tool identifier resolves to it")
        Do $$$AssertEquals(tDeclaration.read.%Get("document"), "", tClass _ ": declares no document of its own")
    }
}

/// <p>The lists' criteria carry the classic page's defaults; the viewers' carry the name and a form
/// defaulting to UDL. Their context never names the description or the text.</p>
Method TestTheCriteriaCarryTheClassicDefaults()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassList", "pattern=*,system=no,generated=no,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineList", "pattern=*.mac,system=no,generated=yes,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassDocument", "name=,form=udl"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineDocument", "name=,form=udl") {
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
    For tI = 1:1:4 {
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

/// <p>Story 19.2 AC9: the area's tools are its four reads and four writes, the lists' compile and
/// delete, each over the source code API port with its own request type; the compile keys are
/// enabled and the delete keys disabled at the baseline; and the two lists declare compile and
/// delete as row actions acting on the checked rows, at most one hundred, while the viewers declare
/// none.</p>
/// <p>Mutation (Rule 19): enable a delete key in the baseline -- the baseline leg goes red.</p>
Method TestTheAreaHoldsFourReadsAndFourWrites()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists")
    If $$$ISERR(tSC) Quit
    Set tExplorer = ""
    Set tWriters = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If $Extract(tTool.name, 1, 9) = "explorer." Set tExplorer = tExplorer _ $Select(tExplorer = "": "", 1: ",") _ tTool.name _ ":" _ tTool.kind
        If (tTool.kind '= "write") || (tTool.class = "") || ($Extract($Parameter(tTool.class, "DESCRIPTORCLASS"), 1, 35) '= "OcuPilot.Screen.Descriptor.Explorer") Continue
        Set tClass = tTool.class
        Set tWriters = tWriters _ $Select(tWriters = "": "", 1: ",") _ tTool.name _ ":" _ $Piece($Parameter(tClass, "DESCRIPTORCLASS"), ".", *) _ "/" _ $ClassMethod(tClass, "PortClass") _ "/" _ $ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "Destructive")
    }
    Do $$$AssertEquals(tExplorer, "explorer.class.read:read,explorer.classes.compile:write,explorer.classes.delete:write,explorer.classes.read:read,explorer.routine.read:read,explorer.routines.compile:write,explorer.routines.delete:write,explorer.routines.read:read", "the area's tools are four reads and four writes")
    Do $$$AssertEquals(tWriters, "explorer.classes.compile:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/COMPILE/0,explorer.classes.delete:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/DELETE/1,explorer.routines.compile:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/COMPILE/0,explorer.routines.delete:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/DELETE/1", "each write names its list, the source code API port, its endpoint and type, and the deletes are destructive")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
    Do $$$AssertStatusOK(tSC, "the baseline reads")
    If $$$ISERR(tSC) Quit
    Set tBaselined = ""
    Set tIterator = tKeys.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $Extract(tKey, 1, 9) = "explorer." Set tBaselined = tBaselined _ $Select(tBaselined = "": "", 1: ",") _ tKey _ "=" _ $Select(tValue: "true", 1: "false")
    }
    Do $$$AssertEquals(tBaselined, "explorer.classes.compile=true,explorer.classes.delete=false,explorer.routines.compile=true,explorer.routines.delete=false", "the compile keys ship enabled and the delete keys disabled")
    For tI = 1:1:4 {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Set tMulti = $Select($$$ISOK(tSC) && (tDeclaration.%GetTypeOf("multiSelect") = "object"): tDeclaration.multiSelect.%ToJSON(), 1: "")
        Set tWant = $Select(tI <= 2: "|compile,delete|{""action"":""compile"",""max"":100,""extraActions"":[""delete""]}", 1: "||")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")) _ "|" _ tMulti, tWant, tClass _ ": its actions")
    }
}

}
