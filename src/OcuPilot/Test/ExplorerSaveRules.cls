/// <p>Story 20.21's agent save refusals, each asserted to mint no proposal (AD-6, AD-10, AD-53, DW-2228): a
/// bad replacement (an absent, repeated, empty or no-op <code>Old</code>; a header rename; a <code>New</code>
/// the sanitizer strips; an item without exactly Old and New), a key-shaped copy the instance does not hold
/// (<code>[redacted]</code>), a change wider than one card, OcuPilot's own class, a name beginning with
/// <code>%</code>, a class in <code>%SYS</code>, a class stored in another database, and the confirm's own rule.
/// The hunk's context and first-line rules are pinned on <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class>'s
/// pure <method>Hunk</method>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over
/// HTTP, a <code>USER</code> namespace with the probe documents <class>OcuPilot.Test.ExplorerSaveAgentProbe</class>
/// names, and the <code>ENSLIB</code> database mapped for <code>Ens.Director</code>. It removes what it creates,
/// snapshots the stored governance policy before each test, clears it and puts it back after it, and runs under
/// one test run at a time.</p>
Class OcuPilot.Test.ExplorerSaveRules Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.ExplorerSaveAgentProbe";

Parameter PROBENAMESPACE = "USER";

Parameter ALPHA = "OcuProbe2021.Rules";

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
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
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

/// <p>Asserts that the agent's Edit of <var>pInput</var> in <var>pNamespace</var> is refused with a message
/// containing <var>pText</var>, and that no proposal is minted.</p>
Method Refused(pNamespace As %String, pTool As %String, pInput As %DynamicObject, pText As %String, pLabel As %String)
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Set tSC = tWrite.DispatchFor(pTool, pNamespace, pInput, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError, pLabel _ " is refused: " _ $Extract($Get(tContent), 1, 240))
    Do $$$AssertTrue($Find($Get(tContent), pText) > 0, pLabel _ " names its rule (" _ pText _ "): " _ $Extract($Get(tContent), 1, 240))
    Do $$$AssertTrue('$IsObject($Get(tProposal)) || (tProposal.%GetTypeOf("proposalId") '= "string"), pLabel _ " mints no proposal")
}

/// <p>Write class <var>pName</var> in <var>pNamespace</var> whose one method holds <var>pLine</var>.</p>
ClassMethod WriteWithLine(pNamespace As %String, pName As %String, pLine As %String) As %Status
{
    Set tText = "Class " _ pName _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ $Char(10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(10) _ "{" _ $Char(10) _ pLine _ $Char(10)
    Set tText = tText _ "    Quit 1" _ $Char(10) _ "}" _ $Char(10) _ $Char(10) _ "}" _ $Char(10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, tText, $Char(10))
}

Method TestAnAbsentOldIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 7", "New": "    Quit 8"}]}, "occurs 0 times", "an absent Old")
}

Method TestARepeatedOldIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do $$$AssertStatusOK(..WriteWithLine(..#PROBENAMESPACE, ..#ALPHA, "    Quit 1"), "the class repeats the line")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, "occurs 2 times", "a repeated Old")
}

/// <p>An edit whose result saves as the stored lines is a no-op, a line-ending carriage return included: the
/// port's save drops it, so the card would show no change and Confirm would save none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Mint</method> compares the raw texts
/// (<code>tNew = tOld</code>) -- the carriage-return leg goes red.</p>
Method TestAnEmptyOrNoOpEditIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": "    Quit 1"}]}, "the edits change nothing", "a no-op edit")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": ("    Quit 1" _ $Char(13))}]}, "the edits change nothing", "an edit adding only a line-ending carriage return")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "", "New": "x"}]}, "Old is empty", "an empty Old")
}

Method TestAHeaderRenameIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "Class OcuProbe2021.Rules Extends", "New": "Class OcuProbe2021.Other Extends"}]}, "change the document's name", "a header rename")
}

/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSaveMint</parameter> step 4's strip check
/// removed -- the bidirectional-override leg goes red.</p>
Method TestAStrippedNewIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Set tNew = "    Quit 2" _ $Char(8238)
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": (tNew)}]}, "control or invisible", "a New holding U+202E")
}

/// <p>AC7: an Old that differs from the stored text only in case is refused; the match is exact.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Occurrences</method> compares case-folded
/// text -- this leg goes red.</p>
Method TestAnOldThatDiffersOnlyInCaseIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    quit 1", "New": "    Quit 2"}]}, "occurs 0 times", "an Old differing only in case")
}

Method TestAnItemWithoutNewIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA), "a probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Quit 1"}]}, "exactly Old and New", "an item {Old}")
}

/// <p>DW-2228: a copy the read sends with <code>[redacted]</code> in place of a key-shaped value is refused,
/// and the refusal states that Old is matched exactly against the stored text.</p>
Method TestAKeyShapedOldIsRefusedWithTheMatchRule()
{
    Set tKey = "sk-" _ "abcdefghijklmnopqrstuvwx"
    Set tLine = "    Set key = " _ $Char(34) _ tKey _ $Char(34)
    Set tCopy = "    Set key = " _ $Char(34) _ "[redacted]" _ $Char(34)
    Do $$$AssertStatusOK(..WriteWithLine(..#PROBENAMESPACE, ..#ALPHA, tLine), "a probe class holds a key-shaped value")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": (tCopy), "New": "    Set key = 0"}]}, "matched exactly", "a copy with [redacted]")
}

/// <p>The card's width: two edits at the first and last of a 2,000-line class are one change too wide to show.</p>
Method TestAChangeWiderThanOneCardIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Wide", ..#PROBENAMESPACE, ..#ALPHA, 2000), "a 2,000-line probe class is saved")
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": (..#ALPHA _ ".cls"), "Edits": [{"Old": "    Set x1 = 1", "New": "    Set x1 = 0"}, {"Old": "    Set x2000 = 2000", "New": "    Set x2000 = 0"}]}, "wider than one card", "a change across 2,000 lines")
}

/// <p>OcuPilot's own class is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> before anything is read.</p>
Method TestOcuPilotsOwnClassIsRefused()
{
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": "OcuPilotProbe2021.Own.cls", "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, "PROHIBITED.OCUPILOTCODE", "an OcuPilot class")
}

Method TestAPercentNameIsRefused()
{
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": "%Library.String.cls", "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, "begins with %", "a % class")
}

Method TestASystemNamespaceIsRefused()
{
    Do ..Refused("%SYS", "explorer.classes.save", {"Names": "Security.Users.cls", "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, "in %SYS", "a class in %SYS")
}

/// <p>A class stored in another database is refused by name; the answer names ENSLIB and the editor.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method> answers "" -- this goes red.</p>
Method TestAMappedClassIsRefusedByItsDatabase()
{
    Do ..Refused(..#PROBENAMESPACE, "explorer.classes.save", {"Names": "Ens.Director.cls", "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}]}, "ENSLIB", "a mapped class")
}

/// <p>The confirm's own rule refuses a name the mint would refuse, with nothing else asked.</p>
Method TestTheConfirmRuleRefusesWhatTheMintWould()
{
    Set tProblem = ""
    Do ##class(OcuPilot.Screen.Tool.ExplorerClassSave).ConfirmProblem("%Foo.cls", {"Namespace": "USER"}, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "a % class is refused at the confirm")
    Do ##class(OcuPilot.Screen.Tool.ExplorerClassSave).ConfirmProblem("Ens.Director.cls", {"Namespace": "USER"}, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "a mapped class is refused at the confirm")
}

/// <p>Hunk legs: an interior change keeps three lines of context each side and numbers from the first of them;
/// a change on the first line numbers from 1; an appended line keeps the shared lines as context; and a final
/// line feed, which the save puts as an empty last line, is shown as that line.</p>
/// <p>Mutation (Rule 19), last leg: <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method> reads both sides
/// with <method>OcuPilot.Port.AtelierPort.Lines</method> alone -- the final-line-feed leg goes red.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method> with the context cut at four
/// lines -- the interior leg goes red.</p>
Method TestTheHunkKeepsThreeLinesOfContext()
{
    Set tOld = "a" _ $Char(10) _ "b" _ $Char(10) _ "c" _ $Char(10) _ "d" _ $Char(10) _ "e" _ $Char(10) _ "f" _ $Char(10) _ "g" _ $Char(10) _ "h" _ $Char(10) _ "i" _ $Char(10) _ "j"
    Set tNew = $Replace(tOld, "e", "E")
    Set tRow = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk(tOld, tNew)
    Do $$$AssertEquals(tRow.line, 2, "the first shown line is two, three above the change at five")
    Do $$$AssertEquals(tRow.before, "b" _ $Char(10) _ "c" _ $Char(10) _ "d" _ $Char(10) _ "e" _ $Char(10) _ "f" _ $Char(10) _ "g" _ $Char(10) _ "h" _ $Char(10), "the old lines: three of context, the change, three of context")
    Do $$$AssertEquals(tRow.after, "b" _ $Char(10) _ "c" _ $Char(10) _ "d" _ $Char(10) _ "E" _ $Char(10) _ "f" _ $Char(10) _ "g" _ $Char(10) _ "h" _ $Char(10), "the new lines")
    Set tFirst = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("a" _ $Char(10) _ "b", "A" _ $Char(10) _ "b")
    Do $$$AssertEquals(tFirst.line, 1, "a change on the first line numbers from 1")
    Set tAppend = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("a" _ $Char(10) _ "b", "a" _ $Char(10) _ "b" _ $Char(10) _ "c")
    Do $$$AssertEquals(tAppend.after, "a" _ $Char(10) _ "b" _ $Char(10) _ "c" _ $Char(10), "an appended line is shown after the shared lines")
    Set tEmptyLast = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("a" _ $Char(10) _ "b", "a" _ $Char(10) _ "b" _ $Char(10))
    Do $$$AssertEquals(tEmptyLast.before _ "|" _ tEmptyLast.after, "a" _ $Char(10) _ "b" _ $Char(10) _ "|a" _ $Char(10) _ "b" _ $Char(10) _ $Char(10), "a final line feed the save puts as an empty last line is shown as that line")
}

}
