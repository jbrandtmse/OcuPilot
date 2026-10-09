/// <p>Story 20.21's agent save, below the dispatcher (AD-6, AD-10, AD-53, DW-2228): the pure pieces of
/// <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> and <class>OcuPilot.Screen.Tool.ExplorerSave</class>
/// asked directly, so each rule is pinned on its own boundary -- the shape of the replacement list (one to
/// twenty objects with exactly <code>Old</code> and <code>New</code>), what the sanitizer would change in a
/// <code>New</code> and what it keeps, the exact-once match applied in order to the text the earlier
/// replacements left, the hunk's context and its prefix and suffix limits, the agent's destination rule
/// for classes and routines (a failed lookup refuses), the confirm's own rule, and the merge that puts the
/// mint's hunk in place of the kernel's rows.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace whose own routines database
/// holds no mapping for the probe names, and the <code>ENSLIB</code> database mapped for the <code>Ens</code>
/// package and its routines. It creates and writes nothing.</p>
Class OcuPilot.Test.ExplorerSaveMintUnit Extends %UnitTest.TestCase
{

Parameter MINT = "OcuPilot.Screen.Tool.ExplorerSaveMint";

Parameter CLASSSAVE = "OcuPilot.Screen.Tool.ExplorerClassSave";

Parameter ROUTINESAVE = "OcuPilot.Screen.Tool.ExplorerRoutineSave";

Parameter PORT = "OcuPilot.Port.AtelierPort";

/// <p>The rule sentence the match refusals end with, so a refusal's end can be told from its start.</p>
Parameter RULE = "THE-RULE.";

/// <p>A list of <var>pCount</var> well formed replacements.</p>
ClassMethod Edits(pCount As %Integer) As %DynamicArray
{
    Set tEdits = []
    For tI = 1:1:pCount {
        Do tEdits.%Push({"Old": ("old" _ tI), "New": ("new" _ tI)})
    }
    Quit tEdits
}

/// <p>The problem <method>OcuPilot.Screen.Tool.ExplorerSaveMint.EditProblem</method> finds in an argument
/// object holding <var>pEdits</var> as its replacements.</p>
ClassMethod ProblemOf(pEdits) As %String
{
    Quit $ClassMethod(..#MINT, "EditProblem", {"Names": "X.cls", "Edits": (pEdits)})
}

/// <p>The replacement list is one to twenty objects, each with exactly <code>Old</code> and <code>New</code>,
/// both strings, <code>Old</code> not empty.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.EditItemProblem</method> accepts an
/// object with a third member -- the extra-member leg goes red.</p>
Method TestAMalformedReplacementListIsRefused()
{
    Set tShape = "'Edits' is a list of one to 20 replacements"
    Do $$$AssertEquals(..ProblemOf([{"Old": "a", "New": "b"}]), "", "one well formed replacement is accepted")
    Do $$$AssertEquals(..ProblemOf(..Edits(20)), "", "twenty replacements are accepted")
    Do $$$AssertEquals(..ProblemOf([{"Old": "a", "New": ""}]), "", "an empty New (a deletion) is accepted")
    Do $$$AssertTrue(..ProblemOf(..Edits(21)) [ tShape, "twenty-one replacements are refused with the list's shape")
    Do $$$AssertTrue(..ProblemOf([]) [ tShape, "an empty list is refused with the list's shape")
    Do $$$AssertTrue(..ProblemOf("a string") [ tShape, "Edits sent as a string is refused")
    Do $$$AssertTrue(..ProblemOf({"Old": "a", "New": "b"}) [ tShape, "Edits sent as one object is refused")
    Do $$$AssertTrue($ClassMethod(..#MINT, "EditProblem", {"Names": "X.cls"}) [ tShape, "no Edits member is refused")
    Do $$$AssertTrue($ClassMethod(..#MINT, "EditProblem", "") [ tShape, "arguments that are not an object are refused")
    Do $$$AssertTrue(..ProblemOf(["a string"]) [ "edit 1 is an object with exactly Old and New", "an item that is a string is refused, numbered")
    Do $$$AssertTrue(..ProblemOf([{"Old": "a", "New": "b", "Extra": "c"}]) [ "exactly Old and New", "an item with a third member is refused")
    Do $$$AssertTrue(..ProblemOf([{"Old": 1, "New": "b"}]) [ "exactly Old and New", "a numeric Old is refused")
    Do $$$AssertTrue(..ProblemOf([{"Old": "a", "New": null}]) [ "exactly Old and New", "a null New is refused")
    Do $$$AssertTrue(..ProblemOf([{"Old": "a", "New": "b"}, {"Old": "", "New": "c"}]) [ "edit 2: Old is empty", "an empty Old is refused, naming the second edit")
}

/// <p>A <code>New</code> is refused only where <code>Kernel.Agent.Sanitize.Strip</code> would change it: the
/// bidirectional overrides, zero-width and byte order characters, C0 and C1 controls other than tab, line
/// feed and carriage return, and tag characters. Tabs, line breaks and ordinary non-ASCII text -- what code
/// holds -- are kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.EditItemProblem</method> compares
/// <code>New</code> with a stripped copy of itself that also drops tab -- the "kept" leg goes red.</p>
Method TestANewIsRefusedOnlyWhereTheSanitizerWouldChangeIt()
{
    Set tTab = $Char(9)
    Set tLF = $Char(10)
    Set tCR = $Char(13)
    Set tKept = "Set x = 1" _ tTab _ "; accented " _ $Char(233) _ ", Japanese " _ $Char(26085, 26412) _ tLF _ "second line" _ tCR _ tLF
    Do $$$AssertEquals(..ProblemOf([{"Old": "a", "New": (tKept)}]), "", "tab, line breaks and non-ASCII letters are kept")
    For tCode = 1, 8, 11, 31, 127, 133, 159, 8203, 8206, 8234, 8238, 8288, 8294, 8297, 65279 {
        Set tNew = "x" _ $Char(tCode) _ "y"
        Set tProblem = ..ProblemOf([{"Old": "a", "New": (tNew)}])
        Do $$$AssertTrue(tProblem [ "sanitizer", "U+" _ $ZHex(tCode) _ " in a New is refused: " _ tProblem)
    }
    Set tTag = "x" _ $Char(56128, 56330) _ "y"
    Do $$$AssertTrue(..ProblemOf([{"Old": "a", "New": (tTag)}]) [ "sanitizer", "a tag character in a New is refused")
}

/// <p>Each <code>Old</code> must occur exactly once in the text the earlier replacements left: a later
/// <code>Old</code> sees an earlier <code>New</code>, which can make it unique, absent or repeated. The
/// refusal names the edit, its count and the rule; the match is exact -- case, trailing spaces and line
/// endings included -- and overlaps count.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Apply</method> counts every
/// <code>Old</code> against the unedited text -- the sequential legs go red.</p>
Method TestEachOldMustOccurOnceInTheTextTheEarlierEditsLeft()
{
    Set tLF = $Char(10)
    Set tText = "alpha" _ tLF _ "beta" _ tLF _ "gamma"
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": "beta", "New": "BETA"}], ..#RULE, .tNew)
    Do $$$AssertEquals(tProblem _ "|" _ tNew, "|alpha" _ tLF _ "BETA" _ tLF _ "gamma", "one edit replaces its one occurrence")
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": "beta", "New": "BETA"}, {"Old": "BETA", "New": "Delta"}], ..#RULE, .tNew)
    Do $$$AssertEquals(tProblem _ "|" _ tNew, "|alpha" _ tLF _ "Delta" _ tLF _ "gamma", "a later Old matches what an earlier New wrote")
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": "beta", "New": "gamma"}, {"Old": "gamma", "New": "x"}], ..#RULE, .tNew)
    Do $$$AssertTrue(tProblem [ "edit 2: Old occurs 2 times", "an Old an earlier New made repeated is refused, naming edit 2: " _ tProblem)
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": "beta", "New": "x"}, {"Old": "beta", "New": "y"}], ..#RULE, .tNew)
    Do $$$AssertTrue(tProblem [ "edit 2: Old occurs 0 times", "an Old an earlier edit replaced is absent, naming edit 2")
    Do $$$AssertEquals($Extract(tProblem, *-$Length(..#RULE) + 1, *), ..#RULE, "and a refusal ends with the rule")
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": ("alpha" _ tLF _ "beta"), "New": "ab"}], ..#RULE, .tNew)
    Do $$$AssertEquals(tProblem _ "|" _ tNew, "|ab" _ tLF _ "gamma", "an Old may span lines")
    Set tSpecial = "$1 " _ $Char(92) _ "0 & %"
    Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": "beta", "New": (tSpecial)}], ..#RULE, .tNew)
    Do $$$AssertEquals(tNew, "alpha" _ tLF _ tSpecial _ tLF _ "gamma", "a New is inserted literally")
    For tOld = "Beta", "beta ", " beta", ("alpha" _ $Char(13) _ tLF _ "beta"), "delta", (tText _ tLF) {
        Set tProblem = $ClassMethod(..#MINT, "Apply", tText, [{"Old": (tOld), "New": "x"}], ..#RULE, .tNew)
        Do $$$AssertTrue(tProblem [ "occurs 0 times", "an Old that differs from the stored text in case, spacing or line ending is absent: [" _ tOld _ "]")
    }
    Set tProblem = $ClassMethod(..#MINT, "Apply", "aaa", [{"Old": "aa", "New": "b"}], ..#RULE, .tNew)
    Do $$$AssertTrue(tProblem [ "occurs 2 times", "overlapping occurrences count: " _ tProblem)
}

/// <p>The occurrence count is a literal search: pattern characters are ordinary, overlaps count, and an
/// empty text holds none.</p>
Method TestOccurrencesAreCountedLiterally()
{
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "aaa", "aa"), 2, "overlaps count")
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "abc", "d"), 0, "an absent Old counts none")
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "", "a"), 0, "an empty text holds none")
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "a.b%c?d", "."), 1, "a dot is a dot")
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "a.b%c?d", "%"), 1, "a percent sign is a percent sign")
    Do $$$AssertEquals($ClassMethod(..#MINT, "Occurrences", "ABC", "abc"), 0, "case matters")
}

/// <p>The document's lines are joined by line feeds with none added after the last; a last line the read
/// reports empty leaves the text ending in a line feed.</p>
Method TestTheStoredLinesAreJoinedByLineFeeds()
{
    Set tLF = $Char(10)
    Do $$$AssertEquals($ClassMethod(..#MINT, "JoinLines", ["a", "b"]), "a" _ tLF _ "b", "two lines")
    Do $$$AssertEquals($ClassMethod(..#MINT, "JoinLines", ["a", "b", ""]), "a" _ tLF _ "b" _ tLF, "a reported empty last line ends the text in a line feed")
    Do $$$AssertEquals($ClassMethod(..#MINT, "JoinLines", []), "", "no lines")
    Do $$$AssertEquals($ClassMethod(..#MINT, "JoinLines", ""), "", "no array")
}

/// <p>Builds <var>pCount</var> lines <code>l1</code> to <code>l&lt;pCount&gt;</code> joined by line feeds, with
/// line <var>pChanged</var> (a $LIST of numbers) written in upper case.</p>
ClassMethod Lines(pCount As %Integer, pChanged As %List = "") As %String
{
    Set tText = ""
    For tI = 1:1:pCount {
        Set tLine = $Select($ListFind(pChanged, tI): "L" _ tI, 1: "l" _ tI)
        Set tText = tText _ $Select(tI = 1: "", 1: $Char(10)) _ tLine
    }
    Quit tText
}

/// <p>The hunk of a removal and of two distant changes: the first shown line is three before the first
/// change, the last shown is three after the last, and every unchanged line between the changes is kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method> ends the old side at
/// <code>nA - s</code> (no trailing context) -- the distant-changes leg goes red.</p>
Method TestTheHunkSpansFromTheFirstChangeToTheLastWithContext()
{
    Set tLF = $Char(10)
    Set tRow = $ClassMethod(..#MINT, "Hunk", "a" _ tLF _ "b" _ tLF _ "c" _ tLF _ "d" _ tLF _ "e", "a" _ tLF _ "b" _ tLF _ "d" _ tLF _ "e")
    Do $$$AssertEquals(tRow.field _ " " _ tRow.kind _ " " _ tRow.line, "Text lines 1", "a removal's row is a lines row from line 1")
    Do $$$AssertEquals(tRow.before, "a" _ tLF _ "b" _ tLF _ "c" _ tLF _ "d" _ tLF _ "e" _ tLF, "the old side holds the removed line among its context")
    Do $$$AssertEquals(tRow.after, "a" _ tLF _ "b" _ tLF _ "d" _ tLF _ "e" _ tLF, "the new side lacks it")
    Do $$$AssertEquals(tRow.%GetTypeOf("line"), "number", "the line is a number")
    Do $$$AssertEquals(tRow.%GetTypeOf("before") _ " " _ tRow.%GetTypeOf("after"), "string string", "and the sides are strings")

    Set tFar = $ClassMethod(..#MINT, "Hunk", ..Lines(30), ..Lines(30, $ListBuild(10, 20)))
    Do $$$AssertEquals(tFar.line, 7, "the first shown line is three before the change at ten")
    Do $$$AssertEquals($Length(tFar.before, tLF) - 1, 17, "seventeen lines: lines 7 to 23")
    Do $$$AssertEquals($Piece(tFar.before, tLF, 1) _ " " _ $Piece(tFar.before, tLF, 17), "l7 l23", "the old side runs from l7 to l23, three past the last change at twenty")
    Do $$$AssertEquals($Piece(tFar.after, tLF, 4) _ " " _ $Piece(tFar.after, tLF, 14) _ " " _ $Piece(tFar.after, tLF, 9), "L10 L20 l15", "the new side holds both changes and the unchanged lines between them")
}

/// <p>A change on the last line shows three lines before it and none past the end; and a prefix and a suffix
/// that would overlap are counted once, so an appended or removed duplicate line is still shown.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method> counts the suffix
/// without the <code>p + s &lt; min</code> limit -- the duplicate-line legs go red.</p>
Method TestTheHunkAtTheEndsAndOnDuplicateLines()
{
    Set tLF = $Char(10)
    Set tLast = $ClassMethod(..#MINT, "Hunk", ..Lines(10), ..Lines(10, $ListBuild(10)))
    Do $$$AssertEquals(tLast.line, 7, "a change on the last line shows from line 7")
    Do $$$AssertEquals(tLast.before, "l7" _ tLF _ "l8" _ tLF _ "l9" _ tLF _ "l10" _ tLF, "the old side ends at the last line")
    Do $$$AssertEquals(tLast.after, "l7" _ tLF _ "l8" _ tLF _ "l9" _ tLF _ "L10" _ tLF, "and so does the new side")
    Set tNine = $Translate($Justify("", 9), " ", "x")
    Set tTen = $Translate($Justify("", 10), " ", "x")
    Set tXs9 = $Replace(tNine, "x", "x" _ tLF)
    Set tXs10 = $Replace(tTen, "x", "x" _ tLF)
    Set tDrop = $ClassMethod(..#MINT, "Hunk", $Extract(tXs10, 1, *-1), $Extract(tXs9, 1, *-1))
    Do $$$AssertEquals(tDrop.line _ "|" _ tDrop.before _ "|" _ tDrop.after, "7|" _ $Extract(tXs10, 1, 8) _ "|" _ $Extract(tXs10, 1, 6), "a removed duplicate line among ten is shown as four old lines and three new, from line 7")
    Set tAdd = $ClassMethod(..#MINT, "Hunk", $Extract(tXs9, 1, *-1), $Extract(tXs10, 1, *-1))
    Do $$$AssertEquals(tAdd.line _ "|" _ tAdd.before _ "|" _ tAdd.after, "7|" _ $Extract(tXs10, 1, 6) _ "|" _ $Extract(tXs10, 1, 8), "an added duplicate line among nine is shown as three old lines and four new, from line 7")
    Set tFirst = $ClassMethod(..#MINT, "Hunk", ..Lines(10), ..Lines(10, $ListBuild(1)))
    Do $$$AssertEquals(tFirst.line _ " " _ $Piece(tFirst.before, tLF, 1) _ " " _ $Piece(tFirst.after, tLF, 1) _ " " _ $Piece(tFirst.before, tLF, 4), "1 l1 L1 l4", "a change on the first line shows from line 1 with three after it")
}

/// <p>The agent's destination rule, asked directly for classes and routines. Refused: an empty namespace, a
/// namespace of any case that is <code>%SYS</code>, a name beginning with <code>%</code>, a namespace whose
/// database cannot be read (a failed lookup refuses), and a class or routine stored in another database --
/// named by its database and with the editor as the person's way. A document in the namespace's own routines
/// database is allowed, whatever its kind.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method> reads a routine's
/// destination with <code>GetRoutineDest(pNamespace)</code> alone -- the mapped routine legs go red.</p>
Method TestTheAgentsDestinationRuleRefusesWhatItCannotVouchFor()
{
    For tCase = $ListBuild("USER", "OcuProbe2021.Alpha.cls", ""), $ListBuild("USER", "OcuProbe2021Mac.mac", ""), $ListBuild("USER", "OcuProbe2021Inc.inc", ""), $ListBuild("USER", "OcuProbe2021Int.int", "") {
        Set tProblem = $ClassMethod(..#CLASSSAVE, "AgentProblem", $List(tCase, 1), $List(tCase, 2))
        Do $$$AssertEquals(tProblem, "", $List(tCase, 2) _ " in " _ $List(tCase, 1) _ " is the namespace's own and is allowed: " _ tProblem)
    }
    For tCase = $ListBuild("USER", "Ens.NoSuch2021.cls", "database ENSLIB"), $ListBuild("USER", "EnsUtil.mac", "database ENSLIB"), $ListBuild("USER", "Ensemble.inc", "database ENSLIB") {
        Set tProblem = $ClassMethod(..#ROUTINESAVE, "AgentProblem", $List(tCase, 1), $List(tCase, 2))
        Do $$$AssertTrue(tProblem [ $List(tCase, 3), $List(tCase, 2) _ " names its database: " _ tProblem)
        Do $$$AssertTrue(tProblem [ "class or routine editor", $List(tCase, 2) _ " names the editor as the person's way: " _ tProblem)
    }
    For tCase = $ListBuild("USER", "%Library.String.cls", "begins with %"), $ListBuild("USER", "%occInclude.inc", "begins with %"), $ListBuild("%SYS", "Security.Users.cls", "in %SYS"), $ListBuild("%sys", "Security.Users.cls", "in %SYS"), $ListBuild("", "OcuProbe2021.Alpha.cls", "namespace of the document is not known"), $ListBuild("NOSUCHNS2021", "OcuProbe2021.Alpha.cls", "could not be read"), $ListBuild("NOSUCHNS2021", "OcuProbe2021Mac.mac", "could not be read") {
        Set tProblem = $ClassMethod(..#CLASSSAVE, "AgentProblem", $List(tCase, 1), $List(tCase, 2))
        Do $$$AssertTrue(tProblem [ $List(tCase, 3), "[" _ $List(tCase, 1) _ "] " _ $List(tCase, 2) _ " is refused: " _ tProblem)
    }
    Set tOdd = $ClassMethod(..#CLASSSAVE, "AgentProblem", "A B""C^D", "OcuProbe2021.Alpha.cls")
    Do $$$AssertTrue(tOdd '= "", "a namespace the instance cannot look up is refused, never allowed: " _ tOdd)
}

/// <p>The confirm's own rule asks the namespace the mint stored: a document of the namespace's own database
/// passes, a stored namespace that is missing, <code>%SYS</code> or unknown refuses, and so does a name
/// the mint would have refused, for a routine as for a class.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.ConfirmProblem</method> asks nothing -- the
/// refusing legs go red.</p>
Method TestTheConfirmRuleAsksTheStoredNamespace()
{
    Set tOk = ""
    Do $ClassMethod(..#CLASSSAVE, "ConfirmProblem", "OcuProbe2021.Alpha.cls", {"Namespace": "USER"}, .tOk)
    Do $$$AssertEquals(tOk, "", "a document of the stored namespace's own database passes: " _ tOk)
    Do $ClassMethod(..#ROUTINESAVE, "ConfirmProblem", "OcuProbe2021Mac.mac", {"Namespace": "USER"}, .tOk)
    Do $$$AssertEquals(tOk, "", "and so does a routine: " _ tOk)
    For tCase = $ListBuild(..#CLASSSAVE, "OcuProbe2021.Alpha.cls", "{}"), $ListBuild(..#CLASSSAVE, "OcuProbe2021.Alpha.cls", "{""Namespace"":""%SYS""}"), $ListBuild(..#CLASSSAVE, "OcuProbe2021.Alpha.cls", "{""Namespace"":""NOSUCHNS2021""}"), $ListBuild(..#ROUTINESAVE, "EnsUtil.mac", "{""Namespace"":""USER""}"), $ListBuild(..#ROUTINESAVE, "%Foo.mac", "{""Namespace"":""USER""}") {
        Set tProblem = ""
        Do $ClassMethod($List(tCase, 1), "ConfirmProblem", $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProblem)
        Do $$$AssertTrue(tProblem '= "", $List(tCase, 2) _ " with " _ $List(tCase, 3) _ " is refused at the confirm: " _ tProblem)
    }
}

/// <p>The save's merge keeps the kernel's payload and puts the mint's hunk in place of the kernel's diff: one
/// row when the stored arguments carry a hunk object, none when they carry none or carry something else -- so
/// a re-merge at the confirm matches the mint, and an argument set without a hunk shows no rows.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.MergeUpdate</method> keeps the kernel's
/// diff -- both diff legs go red.</p>
Method TestTheMergeShowsTheHunkAndNothingElse()
{
    Set tFresh = {"Present": true, "Modified": "2026-01-01 00:00:00.000", "Absent": false, "Namespace": "USER", "content": "old text", "version": "2026-01-01 00:00:00.000", "Compile": false}
    Set tHunk = {"field": "Text", "kind": "lines", "line": 7, "before": "old\n", "after": "new\n"}
    Set tSettable = $ClassMethod(..#CLASSSAVE, "SettableFields")
    Set tArgs = {"Names": "OcuProbe2021.Alpha.cls", "content": "new text", "version": "2026-01-01 00:00:00.000", "Compile": true, "Namespace": "USER", "Hunk": (tHunk)}
    Set tSC = $ClassMethod(..#CLASSSAVE, "MergeUpdate", tFresh, tArgs, "Names", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the merge answers")
    Do $$$AssertEquals($Get(tProblem), "", "with no problem")
    Do $$$AssertEquals(tPayload.content _ "|" _ tPayload.Compile, "new text|1", "the payload carries the stored text and the compile choice")
    Do $$$AssertEquals(tDiff.%Size(), 1, "one diff row")
    Do $$$AssertEquals(tDiff.%Get(0).%ToJSON(), tHunk.%ToJSON(), "and it is the mint's hunk")
    Do tArgs.%Remove("Hunk")
    Set tSC = $ClassMethod(..#CLASSSAVE, "MergeUpdate", tFresh, tArgs, "Names", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tDiff.%Size(), 0, "without a hunk there is no diff row, though the text differs")
    Do $$$AssertEquals(tPayload.content, "new text", "and the payload still carries the stored text")
    Do tArgs.%Set("Hunk", "not an object", "string")
    Set tSC = $ClassMethod(..#CLASSSAVE, "MergeUpdate", tFresh, tArgs, "Names", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tDiff.%Size(), 0, "a hunk that is not an object shows no row")
}

/// <p>Each list reads the document through its own endpoint, and the abstract save names none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerRoutineSave.DocumentEndpoint</method> answers the
/// class endpoint -- the routine leg goes red.</p>
Method TestEachListReadsTheDocumentThroughItsOwnEndpoint()
{
    Do $$$AssertEquals($ClassMethod(..#CLASSSAVE, "DocumentEndpoint"), $Parameter(..#PORT, "ENDPOINTCLASS"), "the Classes list reads one class")
    Do $$$AssertEquals($ClassMethod(..#ROUTINESAVE, "DocumentEndpoint"), $Parameter(..#PORT, "ENDPOINTROUTINE"), "the Routines list reads one routine")
    Do $$$AssertNotEquals($Parameter(..#PORT, "ENDPOINTCLASS"), $Parameter(..#PORT, "ENDPOINTROUTINE"), "and the two endpoints differ")
}

}
