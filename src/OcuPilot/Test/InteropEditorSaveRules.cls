/// <p>Pins what Story 20.16's editor saves refuse (AD-10, AD-53, AD-62 item 14, AC5): a save admits only a class of its editor's
/// kind, and refuses before the class is read a class of another kind, a coded process, a class that does not exist, a class
/// stored in another database, an OcuPilot class, a name beginning with <code>%</code> and a class in <code>%SYS</code>, each
/// answering its code and adding no proposal; Confirm's rule refuses a class that is not of the kind, and a namespace that does
/// not report interoperability cannot be read, so the save refuses it too.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, a <code>USER</code> namespace that
/// runs interoperability, the <code>ENSLIB</code> database mapped for the <code>Ens</code> package and its classes, and a
/// namespace other than <code>%SYS</code> that does not report interoperability (<code>HSSYSLOCALTEMP</code> on this image). It
/// makes and removes the <code>OcuProbe2016</code> probe package (<class>OcuPilot.Test.InteropEditorProbe</class>) and snapshots the
/// stored governance policy before each test and puts it back after it.</p>
Class OcuPilot.Test.InteropEditorSaveRules Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

Parameter RULETOOL = "interop.ruleeditor.save";

Parameter PROCESSTOOL = "interop.processeditor.save";

Parameter TRANSFORMTOOL = "interop.transformeditor.save";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
    For tKind = "rule", "process", "transform", "coded" {
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Make", tKind, ..#PACKAGE)
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), "every probe document, generated class and cache node is removed")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.InteropEditorProbe", "ForgetLedger"), "the ledger rows of the probe turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Asserts that the call of <var>pTool</var> for <var>pName</var> in <var>pNamespace</var> is refused with <var>pCode</var>, with
/// <var>pText</var> in its problem (when it is given), and that no proposal row is added for the tool. A refusal that comes before the class is read
/// answers its own code for a class that does not exist, where a read would answer <code>PORT.NOTFOUND</code>.</p>
Method Refused(pNamespace As %String, pTool As %String, pName As %String, pCode As %String, pText As %String)
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool)
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Set tSC = tWrite.DispatchFor(pTool, pNamespace, {"Names": (pName), "Edits": [{"Old": "x", "New": "y"}]}, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError, pTool _ " on " _ pName _ " is refused: " _ $Extract($Get(tContent), 1, 240))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSaveFlow).CodeOf($Get(tContent)), pCode, pTool _ " on " _ pName _ " answers " _ pCode)
    Set tProblem = ##class(OcuPilot.Test.ExplorerSaveFlow).ProblemOf($Get(tContent))
    If pText '= "" Do $$$AssertTrue(tProblem [ pText, pTool _ " on " _ pName _ " names its reason (" _ pText _ "): " _ tProblem)
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool), tBefore, pTool _ " on " _ pName _ " adds no proposal")
}

/// <p>A class of another kind is refused 400 <code>TOOL.ARGUMENTS</code> naming the kind and pointing at the class save: each
/// editor's save on a probe of each of the other two kinds, on a plain class, and on a class that does not exist, which is
/// refused as a wrong kind and not read.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropEditorSave.AgentProblem</method> skips the kind check -- the legs
/// here go red, as do the Confirm-rule and coded legs.</p>
Method TestAClassOfAnotherKindIsRefusedBeforeItIsRead()
{
    Set tArguments = "TOOL.ARGUMENTS"
    Set tPlain = ..#PACKAGE _ ".Plain"
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.ExplorerSaveProbe", "Rewrite", ..#NAMESPACE, tPlain, "1"), "a plain probe class is saved")
    Set tRule = "is not a business rule in namespace USER"
    Set tProcess = "is not a business process written in BPL in namespace USER"
    Set tTransform = "is not a data transformation written in DTL in namespace USER"
    For tCase = $ListBuild(..#TRANSFORMTOOL, "Process", tTransform), $ListBuild(..#TRANSFORMTOOL, "Rule", tTransform), $ListBuild(..#TRANSFORMTOOL, "Plain", tTransform), $ListBuild(..#TRANSFORMTOOL, "Missing", tTransform), $ListBuild(..#PROCESSTOOL, "Transform", tProcess), $ListBuild(..#PROCESSTOOL, "Rule", tProcess), $ListBuild(..#PROCESSTOOL, "Missing", tProcess), $ListBuild(..#RULETOOL, "Plain", tRule), $ListBuild(..#RULETOOL, "Process", tRule), $ListBuild(..#RULETOOL, "Transform", tRule), $ListBuild(..#RULETOOL, "Missing", tRule) {
        Do ..Refused(..#NAMESPACE, $List(tCase, 1), ..#PACKAGE _ "." _ $List(tCase, 2) _ ".cls", tArguments, $List(tCase, 3))
    }
    Do ..Refused(..#NAMESPACE, ..#TRANSFORMTOOL, ..#PACKAGE _ ".Process.cls", tArguments, "explorer.classes.save changes other classes")
}

/// <p>A business process written as a class is not a BPL process: the process save on it is refused 400
/// <code>TOOL.ARGUMENTS</code>, though the class descends from the BPL's own superclass.</p>
Method TestACodedProcessIsRefused()
{
    Do ..Refused(..#NAMESPACE, ..#PROCESSTOOL, ..#PACKAGE _ ".Coded.cls", "TOOL.ARGUMENTS", "is not a business process written in BPL in namespace USER")
}

/// <p>A vendor class mapped from another database is refused 400 <code>TOOL.ARGUMENTS</code> naming the database, by the class
/// save's own rule, before the kind is asked and before the class is read.</p>
Method TestAMappedVendorClassIsRefusedByName()
{
    Do ..Refused(..#NAMESPACE, ..#PROCESSTOOL, "EnsLib.Background.Process.ExportMessageSearch.cls", "TOOL.ARGUMENTS", "database ENSLIB")
    Do ..Refused(..#NAMESPACE, ..#TRANSFORMTOOL, "Ens.DataTransformDTL.cls", "TOOL.ARGUMENTS", "database ENSLIB")
}

/// <p>OcuPilot's own code is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> for a class that need not exist, a name beginning
/// with <code>%</code> and a class in <code>%SYS</code> are refused 400 <code>TOOL.ARGUMENTS</code>, each before the class is
/// read and adding no proposal.</p>
Method TestOwnCodeAPercentNameAndSysAreRefusedBeforeTheRead()
{
    Do ..Refused(..#NAMESPACE, ..#TRANSFORMTOOL, "OcuPilotProbe2016.Transform.cls", "PROHIBITED.OCUPILOTCODE", "")
    Do ..Refused(..#NAMESPACE, ..#RULETOOL, "%Library.String.cls", "TOOL.ARGUMENTS", "begins with %")
    Do ..Refused("%SYS", ..#PROCESSTOOL, "Security.Users.cls", "TOOL.ARGUMENTS", "in %SYS")
}

/// <p>Confirm asks the kind again: the transformation save's Confirm rule refuses a business process and a missing class with a
/// problem that names the kind, and accepts the transformation, so a class rewritten as another kind after the mint is refused
/// at Confirm too.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropEditorSave.AgentProblem</method> skips the kind check -- the refusal
/// legs here go red.</p>
Method TestConfirmRefusesAClassThatIsNotOfTheKind()
{
    Set tTool = "OcuPilot.Screen.Tool.InteropTransformEditorSave"
    Set tArgs = {"Namespace": (..#NAMESPACE)}
    Do $$$AssertStatusOK($ClassMethod(tTool, "ConfirmProblem", ..#PACKAGE _ ".Process.cls", tArgs, .tProblem), "Confirm's rule answers for a process")
    Do $$$AssertTrue($Get(tProblem) [ "is not a data transformation written in DTL", "a business process is refused: " _ $Get(tProblem))
    Do $$$AssertStatusOK($ClassMethod(tTool, "ConfirmProblem", ..#PACKAGE _ ".Missing.cls", tArgs, .tProblem), "Confirm's rule answers for a missing class")
    Do $$$AssertTrue($Get(tProblem) [ "is not a data transformation written in DTL", "a class the namespace does not hold is refused: " _ $Get(tProblem))
    Do $$$AssertStatusOK($ClassMethod(tTool, "ConfirmProblem", ..#PACKAGE _ ".Transform.cls", tArgs, .tProblem), "Confirm's rule answers for a transformation")
    Do $$$AssertEquals($Get(tProblem), "", "a data transformation is admitted")
}

/// <p>A namespace that does not report interoperability cannot be read for the kind, so the save refuses it with its own
/// sentence, the class save's rules having passed.</p>
Method TestANamespaceWithoutInteroperabilityCannotBeSaved()
{
    Set tNamespace = ""
    Do ##class(%SYS.Namespace).ListAll(.tNames)
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        If ($ZConvert(tName, "U") '= "%SYS") && ($Extract(tName) '= "^") && '##class(%Library.EnsembleMgr).IsEnsembleNamespace(tName) Set tNamespace = tName Quit
    }
    Do $$$AssertTrue(tNamespace '= "", "this instance has a namespace other than %SYS that does not report interoperability")
    If tNamespace = "" Quit
    Set tProblem = $ClassMethod("OcuPilot.Screen.Tool.InteropTransformEditorSave", "AgentProblem", tNamespace, ..#PACKAGE _ ".Transform.cls")
    Do $$$AssertTrue((tProblem [ "could not be read, so the agent does not save it") && (tProblem [ "is a data transformation written in DTL"), "the save refuses " _ tNamespace _ ": " _ tProblem)
}

}
