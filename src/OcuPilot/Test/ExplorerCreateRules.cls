/// <p>Story 20.20's refusals of an agent's create (AD-6, AD-10, AD-54, AD-55): each rule the mint and Confirm
/// apply to a new name and text, through the agent's dispatcher on probe documents in <code>USER</code>. Every
/// refusal answers its code and sentence, and adds no proposal. A name the namespace holds, in any case or
/// through its other kind, is refused at the mint; a free name beside it is proposed; and Confirm's own
/// refusal (<method>ConfirmProblem</method>) refuses what the mint would.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, a <code>USER</code>
/// namespace whose routines database the running account can write, and the <code>ENSLIB</code> database mapped for
/// the <code>Ens</code> package. It runs in process and opens no HTTP request. It creates and removes the documents
/// <class>OcuPilot.Test.ExplorerCreateProbe</class> names, and snapshots the stored governance policy around each
/// test.</p>
Class OcuPilot.Test.ExplorerCreateRules Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerCreateProbe";

Parameter CLASSTOOL = "explorer.classes.create";

Parameter ROUTINETOOL = "explorer.routines.create";

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
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The problem sentence a refusal carries in <code>detail.problem</code>, or <code>""</code>.</p>
ClassMethod ProblemOf(pContent As %String) As %String
{
    Set tProblem = ""
    Try {
        Set tProblem = ##class(%DynamicAbstractObject).%FromJSON(pContent).detail.problem
    } Catch {
        Set tProblem = ""
    }
    Quit tProblem
}

/// <p>The input for a create of <var>pName</var> with <var>pText</var>.</p>
ClassMethod Input(pName As %String, pText As %String) As %DynamicObject
{
    Quit {"Names": (pName), "Text": (pText), "rationale": "a probe", "expectedImpact": "none"}
}

/// <p>Asserts that the call of <var>pTool</var> for <var>pName</var> with <var>pBody</var> in <var>pNamespace</var>
/// is refused with <var>pCode</var>, with <var>pSentence</var> in its problem, and that no proposal row is added for
/// the tool. The dispatch is <class>OcuPilot.Test.ExplorerCreateFlow</class>'s.</p>
Method Refused(pNamespace As %String, pTool As %String, pName As %String, pBody As %String, pCode As %String, pSentence As %String)
{
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool)
    Do $$$AssertTrue(tBefore >= 0, "the proposal count reads")
    Set tSC = ##class(OcuPilot.Test.ExplorerCreateFlow).Dispatch(pNamespace, pTool, ..Input(pName, pBody), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError, pName _ " is refused: " _ $Extract($Get(tContent), 1, 240))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerCreateFlow).CodeOf($Get(tContent)), pCode, pName _ " answers " _ pCode)
    If pSentence '= "" Do $$$AssertTrue(..ProblemOf($Get(tContent)) [ pSentence, pName _ " names its reason (" _ pSentence _ "): " _ ..ProblemOf($Get(tContent)))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(pTool), tBefore, pName _ " adds no proposal")
}

/// <p>A name the instance's own code rule names, a name holding <code>%</code> anywhere, one in <code>%SYS</code>,
/// one the namespace stores in another database, and a class without a package are refused before anything is
/// stored, each with its sentence. At the confirm, stored arguments that are not an object are refused as unreadable,
/// and <code>{}</code> for its missing namespace.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method> ignores <code>pCreate</code>
/// -- the <code>%</code>-anywhere leg goes red. <method>OcuPilot.Screen.Tool.ExplorerCreate.ConfirmProblem</method>
/// treating <code>{}</code> as unreadable -- the missing-namespace leg goes red.</p>
Method TestTheNamesThatAreNeverCreated()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", "OcuPilotProbe2020.New")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuPilotProbe2020.New.cls", tText, "PROHIBITED.OCUPILOTCODE", "")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "%Probe2020.New.cls", $ClassMethod(..#PROBE, "NewClassText", "%Probe2020.New"), "TOOL.ARGUMENTS", "holds %")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.%A.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.%A"), "TOOL.ARGUMENTS", "holds %")
    Do ..Refused("%SYS", ..#CLASSTOOL, "OcuProbe2020.New.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.New"), "TOOL.ARGUMENTS", "in %SYS")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "Ens.OcuProbe2020.cls", $ClassMethod(..#PROBE, "NewClassText", "Ens.OcuProbe2020"), "TOOL.ARGUMENTS", "database ENSLIB")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "EnsOcuProbe2020.mac", $ClassMethod(..#PROBE, "NewRoutineText", "EnsOcuProbe2020.mac"), "TOOL.ARGUMENTS", "database ENSLIB")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "%OcuProbe2020.mac", $ClassMethod(..#PROBE, "NewRoutineText", "%OcuProbe2020.mac"), "TOOL.ARGUMENTS", "holds %")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020Bare.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020Bare"), "TOOL.ARGUMENTS", "with a package")
    Set tSC = ##class(OcuPilot.Screen.Tool.ExplorerClassCreate).ConfirmProblem("%Probe2020.New.cls", {"Namespace": "USER"}, .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "holds %"), "Confirm refuses a name the mint would refuse: " _ $Get(tProblem))
    For tCase = $ListBuild("OcuPilot.Screen.Tool.ExplorerClassCreate", "OcuProbe2020.New.cls"), $ListBuild("OcuPilot.Screen.Tool.ExplorerRoutineCreate", "OcuProbe2020Mac.mac") {
        Set tProblem = ""
        Set tSC = $ClassMethod($List(tCase, 1), "ConfirmProblem", $List(tCase, 2), "", .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 2) _ " with stored arguments that are not an object answers")
        Do $$$AssertTrue(tProblem [ "could not be read", $List(tCase, 2) _ " with stored arguments that are not an object is refused at the confirm: " _ tProblem)
        Set tProblem = ""
        Set tSC = $ClassMethod($List(tCase, 1), "ConfirmProblem", $List(tCase, 2), {}, .tProblem)
        Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "the namespace is not known"), $List(tCase, 2) _ " with stored arguments {} is refused for its missing namespace, not as unreadable: " _ tProblem)
    }
}

/// <p>A name that is not one new document of the tool's kind is refused: a routine named to the Classes tool, a
/// class named to the Routines tool, a file of another kind, and a set of two names.</p>
Method TestTheKindOfTheNameIsChecked()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Kind")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020Kind.mac", tText, "TOOL.ARGUMENTS", "class with a package")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "OcuProbe2020Foo.bas", tText, "TOOL.ARGUMENTS", "routine or include file")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Kind.cls,OcuProbe2020.Two.cls", tText, "TOOL.ARGUMENTS", "names one new class")
}

/// <p>The text is one non-empty string, carries no character the sanitizer would strip, has a header that names the
/// new document, and fits one card.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerCreateMint.TextProblem</method> skips the header
/// check -- the header leg goes red.</p>
Method TestTheTextIsOneCardOfTheNamedDocument()
{
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Text.cls", "", "TOOL.ARGUMENTS", "whole text")
    Set tOther = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Other")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Text.cls", tOther, "TOOL.ARGUMENTS", "header names")
    Set tHidden = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Text")
    Set tHidden = $Extract(tHidden, 1, 14) _ $Char(8238) _ $Extract(tHidden, 15, *)
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Text.cls", tHidden, "TOOL.ARGUMENTS", "control or invisible character")
    Set tWide = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Text") _ $Char(10) _ "/// " _ $TRANSLATE($Justify("", 31000), " ", "x")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Text.cls", tWide, "TOOL.ARGUMENTS", "wider than one card")
}

/// <p>A name the namespace holds is refused at the mint, and nothing is proposed: the exact class, the class in
/// another case, <code>X.mac</code> while <code>X.int</code> is held, and <code>X.int</code> while <code>X.mac</code>
/// is held. A name that differs only in case, and an include file beside a routine of its name, are proposed.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.Takes</method> compares a class in exact case -- the
/// other-case leg goes red.</p>
Method TestAHeldNameIsRefusedAtTheMintAndAFreeOneIsProposed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe2020.Held"), "a probe class is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), "a probe intermediate routine is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Mac.mac"), "a probe routine is held")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.Held.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Held"), "TOOL.ARGUMENTS", "already held")
    Do ..Refused(..#PROBENAMESPACE, ..#CLASSTOOL, "OcuProbe2020.HELD.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.HELD"), "TOOL.ARGUMENTS", "already held")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "OcuProbe2020Int.mac", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Int.mac"), "TOOL.ARGUMENTS", "already held")
    Do ..Refused(..#PROBENAMESPACE, ..#ROUTINETOOL, "OcuProbe2020Mac.int", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Mac.int"), "TOOL.ARGUMENTS", "already held")
    Set tSC = ##class(OcuPilot.Test.ExplorerCreateFlow).Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, ..Input("OcuProbe2020Mac.inc", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Mac.inc")), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "an include file beside a held routine of its name is proposed: " _ $Extract($Get(tContent), 1, 200))
    Set tSC = ##class(OcuPilot.Test.ExplorerCreateFlow).Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, ..Input("OcuProbe2020INT.mac", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020INT.mac")), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "a routine name differing only in case is proposed: " _ $Extract($Get(tContent), 1, 200))
}

}
