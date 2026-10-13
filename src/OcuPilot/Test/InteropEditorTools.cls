/// <p>Pins Story 20.16's six editor tools with nothing saved (AD-5, AD-8, AD-22, AD-24, AD-53, AD-62): each editor screen
/// binds a read and an agent-only save under its own tool identifier; every tool is advertised, bound to its descriptor and
/// requires the screen's pairs plus <code>%Development:USE</code>, a save adding <code>%Ens_Code:WRITE</code> and
/// declaring the routines database's WRITE as an argument pair; the three save keys ship enabled; every description carries
/// the warning sentence; each editor's context lists exactly its read and its save while the System Explorer screens' lists
/// stay as they were; the tools that list themselves in a screen's context without an action are exactly the three saves;
/// and <method>OcuPilot.Port.InteropPort.IsCodeOfKind</method> answers for each kind, the base class, a coded process and
/// a namespace it cannot read.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and a <code>USER</code> namespace that runs
/// interoperability. It makes and removes the <code>OcuProbe2016</code> probe package in <code>USER</code>
/// (<class>OcuPilot.Test.InteropEditorProbe</class>) and snapshots the stored governance policy before each test and puts it back
/// after it.</p>
Class OcuPilot.Test.InteropEditorTools Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

Parameter TOOLPACKAGE = "OcuPilot.Screen.Tool.";

/// <p>The three editors, <code>&lt;probe kind&gt;|&lt;descriptor&gt;|&lt;tool identifier&gt;|&lt;kind base&gt;|&lt;read class&gt;|&lt;save class&gt;</code>.</p>
Parameter EDITORS = "rule|InteropRuleEditor|interop.ruleeditor|Ens.Rule.Definition|InteropRuleEditorSource|InteropRuleEditorSave;process|InteropProcessEditor|interop.processeditor|Ens.BusinessProcessBPL|InteropProcessEditorSource|InteropProcessEditorSave;transform|InteropTransformEditor|interop.transformeditor|Ens.DataTransformDTL|InteropTransformEditorSource|InteropTransformEditorSave";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
    For tKind = "rule", "process", "transform", "coded" {
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Make", tKind, ..#PACKAGE)
    }
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Quit $$$OK
}

/// <p><var>pPairs</var> as <code>resource:permission</code> text, comma-separated.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    }
    Quit tText
}

/// <p>The registered tool entries by name, in <var>pByName</var>.</p>
ClassMethod ToolsByName(ByRef pByName) As %Status
{
    Kill pByName
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set pByName(tTool.name) = tTool
    }
    Quit $$$OK
}

/// <p>Each editor binds an advertised read and an advertised, agent-only, destructive save to its descriptor: the classes
/// extend the System Explorer's class read and class save, declare no screen action or value, list themselves in the
/// screen's context, name the editor-reload consequence and carry no classic page.</p>
Method TestEachEditorBindsAnAdvertisedReadAndAnAgentOnlySave()
{
    Do $$$AssertStatusOK(..ToolsByName(.tByName), "the tool registry lists")
    For tI = 1:1:$Length(..#EDITORS, ";") {
        Set tRow = $Piece(..#EDITORS, ";", tI)
        Set tDescriptor = ..#DESCRIPTORPACKAGE _ $Piece(tRow, "|", 2)
        Set tRead = $Piece(tRow, "|", 3) _ ".source"
        Set tSave = $Piece(tRow, "|", 3) _ ".save"
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($Piece(tRow, "|", 3)), tDescriptor, tDescriptor _ ": its tool identifier resolves to it")
        For tName = tRead, tSave {
            Do $$$AssertTrue($Data(tByName(tName)), tName _ " is registered")
            If '$Data(tByName(tName)) Continue
            Do $$$AssertEquals(tByName(tName).kind, $Select(tName = tRead: "read", 1: "write"), tName _ " declares its kind")
            Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tByName(tName)), tName _ " is advertised")
            Do $$$AssertEquals($Parameter(tByName(tName).class, "DESCRIPTORCLASS"), tDescriptor, tName _ " is bound to " _ tDescriptor)
        }
        If '$Data(tByName(tSave)) || '$Data(tByName(tRead)) Continue
        Set tReadClass = tByName(tRead).class
        Set tSaveClass = tByName(tSave).class
        Do $$$AssertEquals(tReadClass, ..#TOOLPACKAGE _ $Piece(tRow, "|", 5), tRead _ " is its class")
        Do $$$AssertEquals(tSaveClass, ..#TOOLPACKAGE _ $Piece(tRow, "|", 6), tSave _ " is its class")
        Do $$$AssertTrue($ClassMethod(tReadClass, "%Extends", "OcuPilot.Screen.Tool.ExplorerClassSource"), tRead _ " extends the class source read")
        Do $$$AssertTrue($ClassMethod(tSaveClass, "%Extends", "OcuPilot.Screen.Tool.ExplorerClassSave"), tSave _ " extends the class save")
        Do $$$AssertEquals($Parameter(tSaveClass, "SCREENACTIONS") _ "|" _ $Parameter(tSaveClass, "SCREENVALUES"), "|", tSave _ " is agent-only: no screen action or value")
        Do $$$AssertEquals($Parameter(tSaveClass, "SCREENLISTED") _ "|" _ $Parameter(tSaveClass, "DESTRUCTIVE") _ "|" _ $Parameter(tSaveClass, "CLASSICPAGES"), "1|1|", tSave _ " lists itself in its screen's context, is destructive and names no classic page")
        Do $$$AssertEquals($Parameter(tSaveClass, "CONSEQUENCE"), "INTEROP.EDITOR.RELOADS", tSave _ " names the editor-reload consequence")
        Do $$$AssertEquals($Parameter(tSaveClass, "KINDBASE"), $Piece(tRow, "|", 4), tSave _ " admits the editor's kind")
        Do $$$AssertEquals($Parameter(tSaveClass, "READWITH"), tRead, tSave _ " tells the model to read with " _ tRead)
        Set tMatch = $Parameter(tSaveClass, "MATCHRULE")
        Do $$$AssertTrue((tMatch [ "interop.ruleeditor.source") && (tMatch [ "interop.processeditor.source") && (tMatch [ "interop.transformeditor.source") && (tMatch '[ "explorer.class.source") && (tMatch '[ "explorer.routine.source"), tSave _ "'s match rule names the three editor reads: " _ tMatch)
        Set tEdits = $ClassMethod(tSaveClass, "InputSchema").properties.Edits.description
        Do $$$AssertTrue(tEdits [ ("Read the document first with " _ tRead _ ", and copy each Old from that read."), tSave _ "'s Edits description names its read: " _ tEdits)
    }
    Set tDefault = $ClassMethod("OcuPilot.Screen.Tool.ExplorerClassSave", "InputSchema").properties.Edits.description
    Do $$$AssertTrue(tDefault [ "Read the document first with explorer.class.source or explorer.routine.source, and copy each Old from that read.", "the System Explorer save's Edits description is unchanged: " _ tDefault)
}

/// <p>The tools that list themselves in a screen's context with no action to carry them are exactly the three saves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Context.ScreenTools</method> ignores <parameter>SCREENLISTED</parameter> --
/// the editors' context legs go red here and in <class>OcuPilot.Test.InteropEditorSaveTurn</class>.</p>
Method TestOnlyTheThreeSavesListThemselvesInAScreensContext()
{
    Do $$$AssertStatusOK(..ToolsByName(.tByName), "the tool registry lists")
    Set tListed = ""
    Set tName = $Order(tByName(""))
    While tName '= "" {
        If (tByName(tName).kind = "write") && ##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tByName(tName)) && ''+$Parameter(tByName(tName).class, "SCREENLISTED") Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tName
        Set tName = $Order(tByName(tName))
    }
    Do $$$AssertEquals(tListed, "interop.processeditor.save,interop.ruleeditor.save,interop.transformeditor.save", "exactly the three editor saves declare SCREENLISTED")
}

/// <p>The three save keys resolve enabled with no stored setting, because the baseline lists each as <code>true</code> (AD-22).</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Kernel.Governance.Baseline</class> lists <code>interop.transformeditor.save</code> as
/// <code>false</code> -- this goes red.</p>
Method TestTheThreeSaveKeysShipEnabled()
{
    For tI = 1:1:$Length(..#EDITORS, ";") {
        Set tKey = $Piece($Piece(..#EDITORS, ";", tI), "|", 3) _ ".save"
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed) _ "|" _ tListed, "1|1", tKey _ " is listed in the baseline as true")
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(tKey, "write", .tEnabled, .tSource)
        Do $$$AssertStatusOK(tSC, tKey _ " resolves")
        Do $$$AssertEquals(+$Get(tEnabled), 1, tKey _ " resolves enabled (" _ $Get(tSource) _ ")")
    }
}

/// <p>Each read requires its screen's pairs and <code>%Development:USE</code>; each save requires those and
/// <code>%Ens_Code:WRITE</code>, and its arguments add WRITE on the routines database of the request's namespace.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropEditorSave.PrivilegePairs</method> drops
/// <code>%Ens_Code:WRITE</code> -- this goes red, and so does the save gate's vendor-write leg.</p>
Method TestEachToolRequiresItsScreensPairsAndTheDevelopmentPair()
{
    Do $$$AssertStatusOK(..ToolsByName(.tByName), "the tool registry lists")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tCodeWrite = ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs({}, .tCodeResolved)
    Do $$$AssertTrue(tCodeResolved, "the routines database's WRITE resolves")
    For tI = 1:1:$Length(..#EDITORS, ";") {
        Set tRow = $Piece(..#EDITORS, ";", tI)
        Set tScreen = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORPACKAGE _ $Piece(tRow, "|", 2), .tScreenResolved)
        Do $$$AssertTrue(tScreenResolved && ($ListLength(tScreen) > 0), $Piece(tRow, "|", 2) _ " declares pairs")
        Set tRead = $Piece(tRow, "|", 3) _ ".source"
        Set tSave = $Piece(tRow, "|", 3) _ ".save"
        If '$Data(tByName(tRead)) || '$Data(tByName(tSave)) Continue
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tByName(tRead), .tResolved)
        Do $$$AssertTrue(tResolved, tRead _ ": its pairs resolve")
        Do $$$AssertEquals(..PairsText(tPairs), ..PairsText(tScreen) _ ",%Development:USE", tRead _ " requires its screen's pairs and %Development:USE")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tByName(tSave), .tResolved)
        Do $$$AssertTrue(tResolved, tSave _ ": its pairs resolve")
        Do $$$AssertEquals(..PairsText(tPairs), ..PairsText(tScreen) _ ",%Development:USE,%Ens_Code:WRITE", tSave _ " requires its screen's pairs, %Development:USE and %Ens_Code:WRITE")
        Set tAdded = ##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tByName(tSave), {}, .tAddedResolved)
        Do $$$AssertEquals(tAddedResolved _ "|" _ ..PairsText(tAdded), "1|" _ ..PairsText(tCodeWrite), tSave _ "'s arguments add the routines database's WRITE")
    }
}

/// <p>Every description carries the warning sentence, which tells the model to say that it works from what is saved before it
/// reads or changes the document, and the read's copy is the save's.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.InteropEditorSave.WARN</parameter> loses "tell the person you work from
/// what is saved" -- this goes red.</p>
Method TestEveryDescriptionCarriesTheWarning()
{
    Do $$$AssertStatusOK(..ToolsByName(.tByName), "the tool registry lists")
    Set tWarn = $Parameter("OcuPilot.Screen.Tool.InteropEditorSave", "WARN")
    Do $$$AssertTrue(tWarn [ "tell the person you work from what is saved", "the sentence tells the model to say it works from what is saved: " _ tWarn)
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.InteropEditorSource", "WARN"), tWarn, "the reads' sentence is the saves'")
    For tI = 1:1:$Length(..#EDITORS, ";") {
        Set tPrefix = $Piece($Piece(..#EDITORS, ";", tI), "|", 3)
        For tName = tPrefix _ ".source", tPrefix _ ".save" {
            If '$Data(tByName(tName)) Continue
            Set tDescription = ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tByName(tName))
            Do $$$AssertTrue(tDescription [ tWarn, tName _ "'s description holds the warning sentence")
        }
        If '$Data(tByName(tPrefix _ ".save")) Continue
        Set tSaveText = ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tByName(tPrefix _ ".save"))
        Do $$$AssertTrue((tSaveText [ "which the user confirms") && (tSaveText [ "opens the document again in the editor") && (tSaveText [ ("Read the class's text first with " _ tPrefix _ ".source")) && (tSaveText [ "explorer.classes.save changes other classes"), tPrefix _ ".save's description gives the confirmation, the reload, the read and the refusals")
    }
}

/// <p>Each editor's context lists exactly its read and its save, read first; the System Explorer class screens' lists stay as
/// they were.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Context.ScreenTools</method> ignores <parameter>SCREENLISTED</parameter> -- the
/// editors' lists lose the save and this goes red.</p>
Method TestEachEditorsContextListsExactlyItsReadAndSave()
{
    For tI = 1:1:$Length(..#EDITORS, ";") {
        Set tRow = $Piece(..#EDITORS, ";", tI)
        Set tPrefix = $Translate($Piece(tRow, "|", 3), ".", "_")
        Kill tTools
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTORPACKAGE _ $Piece(tRow, "|", 2), .tTools), $Piece(tRow, "|", 2) _ ": its context tools build")
        Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[""" _ tPrefix _ "_source"",""" _ tPrefix _ "_save""]", $Piece(tRow, "|", 2) _ ": its context lists its read and its save")
    }
    For tCase = $ListBuild("ExplorerClassDocument", "[""explorer_class_read"",""explorer_class_source""]"), $ListBuild("ExplorerClassEditor", "[]"), $ListBuild("ExplorerClassList", "[""explorer_classes_read"",""explorer_classes_compile"",""explorer_classes_delete"",""explorer_classes_export"",""explorer_classes_import"",""explorer_classes_save""]") {
        Kill tTools
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTORPACKAGE _ $List(tCase, 1), .tTools), $List(tCase, 1) _ ": its context tools build")
        Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), $List(tCase, 2), $List(tCase, 1) _ ": its context tools are unchanged")
    }
}

/// <p><method>OcuPilot.Port.InteropPort.IsCodeOfKind</method> answers 1 for a probe of each kind against its own base, and for
/// the DTL probe against the broader <code>Ens.DataTransform</code>; 0 for a probe of another kind and for a coded process,
/// all read; 0 for the base class itself, read; and 0 with the dictionary unread for <code>%SYS</code> and a namespace that
/// does not exist, neither of which reports interoperability.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.IsCodeOfKind</method> answers 1 for every readable name -- the
/// other-kind, coded and base legs go red.</p>
Method TestTheKindPredicateAnswersForEachKind()
{
    Set tOrigNS = $NAMESPACE
    Set tBpl = "Ens.BusinessProcessBPL"
    Set tDtl = "Ens.DataTransformDTL"
    Set tRule = "Ens.Rule.Definition"
    For tCase = $ListBuild("rule", tRule, 1), $ListBuild("rule", tBpl, 0), $ListBuild("rule", tDtl, 0), $ListBuild("process", tBpl, 1), $ListBuild("process", tRule, 0), $ListBuild("process", tDtl, 0), $ListBuild("transform", tDtl, 1), $ListBuild("transform", "Ens.DataTransform", 1), $ListBuild("transform", tBpl, 0), $ListBuild("transform", tRule, 0), $ListBuild("coded", tBpl, 0), $ListBuild("coded", tDtl, 0), $ListBuild("coded", tRule, 0) {
        Set tName = $ClassMethod(..#PROBE, "Name", $List(tCase, 1), ..#PACKAGE)
        Set tKind = ##class(OcuPilot.Port.InteropPort).IsCodeOfKind(..#NAMESPACE, tName, $List(tCase, 2), .tRead)
        Do $$$AssertEquals(tKind _ "|" _ tRead, $List(tCase, 3) _ "|1", tName _ " against " _ $List(tCase, 2))
    }
    For tBase = tBpl, tDtl, tRule {
        Set tKind = ##class(OcuPilot.Port.InteropPort).IsCodeOfKind(..#NAMESPACE, tBase, tBase, .tRead)
        Do $$$AssertEquals(tKind _ "|" _ tRead, "0|1", tBase _ " is not a class of its own kind, and the dictionary was read")
    }
    Set tName = $ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE)
    For tNamespace = "%SYS", "NOSUCHNS2016", "" {
        Set tKind = ##class(OcuPilot.Port.InteropPort).IsCodeOfKind(tNamespace, tName, tDtl, .tRead)
        Do $$$AssertEquals(tKind _ "|" _ tRead, "0|0", "'" _ tNamespace _ "' cannot be read as an interoperability namespace")
    }
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "the caller's namespace is restored")
}

}
