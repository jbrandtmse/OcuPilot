/// <p>Story 20.20's script, run (QA; AD-59, AD-53, AD-54, DW-2241, DW-2247): the ObjectScript step an agent's
/// class or routine save or create takes as a script is executed, not read. An agent save or create is minted
/// through the dispatcher on probe documents in <code>USER</code>, its draft is taken with
/// <method>OcuPilot.Kernel.Proposal.Draft.Take</method>, and the step is compiled into a method of a probe class
/// and called, or pasted line by line as a terminal runs it. What the document holds afterwards is the text the
/// card reviewed; a routine's UDL header line is not written into its body; a create runs only while nothing
/// takes its name, either way it is run; and the vendor refuses a put over a held document that carries no
/// version.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and a
/// <code>USER</code> namespace whose routines database the suite account can write. It creates and removes the
/// documents <class>OcuPilot.Test.ExplorerCreateProbe</class> names and the probe class
/// <parameter>RUNNER</parameter>, and snapshots the stored governance policy around each test.</p>
Class OcuPilot.Test.AtelierPortScriptRun Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerCreateProbe";

Parameter PORT = "OcuPilot.Port.AtelierPort";

Parameter CLASSCREATE = "explorer.classes.create";

Parameter ROUTINECREATE = "explorer.routines.create";

Parameter CLASSSAVE = "explorer.classes.save";

Parameter ROUTINESAVE = "explorer.routines.save";

/// <p>The probe class whose one method is the script under test. It is in the probe package, so
/// <method>OcuPilot.Test.ExplorerCreateProbe.Remove</method> deletes it.</p>
Parameter RUNNER = "OcuProbe2020.ScriptRun";

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
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document and the script runner are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Mint <var>pTool</var> for <var>pInput</var> through the agent's dispatcher in the probe namespace, asserting
/// it is minted, and answer the proposal.</p>
Method Mint(pTool As %String, pInput As %DynamicObject) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Test.ExplorerCreateFlow).Dispatch(..#PROBENAMESPACE, pTool, pInput, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), pTool _ " is minted: " _ $Extract($Get(tContent), 1, 300))
    Quit $Get(tProposal)
}

/// <p>The agent's create input: the name and the whole text.</p>
ClassMethod CreateInput(pName As %String, pText As %String) As %DynamicObject
{
    Quit {"Names": (pName), "Text": (pText), "rationale": "a probe create", "expectedImpact": "the probe document is held", "reverse": "delete the probe document"}
}

/// <p>The agent's save input: the name and the one replacement.</p>
ClassMethod SaveInput(pName As %String, pOld As %String, pNew As %String) As %DynamicObject
{
    Quit {"Names": (pName), "Edits": [{"Old": (pOld), "New": (pNew)}]}
}

/// <p>Take the draft of proposal <var>pProposal</var> as the test process's user, asserting it is the one
/// <code>objectscript</code> step, and answer that step's text.</p>
Method Take(pProposal As %DynamicObject) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(pProposal.proposalId, $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200), "the draft is taken: " _ tHttp _ " " _ $Get(tCode))
    If $$$ISERR(tSC) || '$IsObject(tAnswer) Quit ""
    Do $$$AssertEquals(tAnswer.draft.steps.%Size() _ " " _ tAnswer.draft.steps.%Get(0).kind, "1 objectscript", "the draft is one ObjectScript step")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(pProposal.proposalId, "ClosedReason"), "draft", "and the proposal is closed as a draft")
    Quit tAnswer.draft.steps.%Get(0).text
}

/// <p>Run the script text <var>pScript</var> as a person would run it where blocks are allowed: it becomes the body
/// of <parameter>RUNNER</parameter>'s class method, which is compiled and called in the probe namespace with its
/// output captured in <var>pOutput</var>, line by line joined with line feeds. The caller's namespace is restored.</p>
ClassMethod Run(pScript As %String, Output pOutput As %String) As %Status
{
    Set pOutput = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tCapturing = 0
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Do $System.OBJ.Delete(..#RUNNER, "-d")
        Set tClass = ##class(%Dictionary.ClassDefinition).%New(..#RUNNER)
        Set tClass.Super = "%RegisteredObject"
        Set tMethod = ##class(%Dictionary.MethodDefinition).%New(..#RUNNER _ ":Run")
        Set tMethod.ClassMethod = 1
        Do tMethod.Implementation.Write(pScript)
        Do tClass.Methods.Insert(tMethod)
        Set tSC = tClass.%Save()
        If $$$ISERR(tSC) Quit
        Set tSC = $System.OBJ.Compile(..#RUNNER, "ck-d")
        If $$$ISERR(tSC) Quit
        Set tSC = $$BeginCapture^%SYS.Capture(.tCookie)
        If $$$ISERR(tSC) Quit
        Set tCapturing = 1
        Do $ClassMethod(..#RUNNER, "Run")
        Set $NAMESPACE = ..#PROBENAMESPACE
        Set tCapturing = 0
        Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
        If $IsObject($Get(tLines)) {
            Set tIterator = tLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                Set pOutput = pOutput _ $Select(pOutput = "": "", 1: $Char(10)) _ tLine
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        If tCapturing Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Run the script text <var>pScript</var> as a terminal runs what is pasted into it: each line on its own, in
/// the process's public scope, a line that fails reporting its error and the next line running anyway. The output,
/// then a line naming each failing line and its error, is in <var>pOutput</var>, and <var>pErrors</var> counts the
/// failing lines. The caller's namespace is restored and the script's variables are removed.</p>
ClassMethod RunLines(pScript As %String, Output pOutput As %String, Output pErrors As %Integer) As %Status
{
    Set pOutput = ""
    Set pErrors = 0
    Set tFailed = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tCapturing = 0
    Try {
        Xecute "Kill tFree, tSC, tText, tRoutine, tI"
        Set tSC = $$BeginCapture^%SYS.Capture(.tCookie)
        If $$$ISERR(tSC) Quit
        Set tCapturing = 1
        For tLine = 1:1:$Length(pScript, $Char(10)) {
            Try {
                Xecute $Piece(pScript, $Char(10), tLine)
            } Catch ex {
                Set pErrors = pErrors + 1
                Set tFailed = tFailed _ $Char(10) _ "line " _ tLine _ " failed: " _ ex.Name
            }
        }
        Set tCapturing = 0
        Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
        If $IsObject($Get(tLines)) {
            Set tIterator = tLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tText) {
                Set pOutput = pOutput _ $Select(pOutput = "": "", 1: $Char(10)) _ tText
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        If tCapturing Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
    }
    Set $NAMESPACE = tOrigNS
    Xecute "Kill tFree, tSC, tText, tRoutine, tI"
    Set pOutput = pOutput _ tFailed
    Quit tSC
}

/// <p>The routine <var>pName</var> as it is stored, line by line joined with line feeds: what
/// <code>%Routine</code> holds, without the <code>ROUTINE</code> header line the Atelier read prepends.</p>
ClassMethod RawRoutine(pName As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Set tRoutine = ##class(%Routine).%New(pName)
        Do tRoutine.Rewind()
        Set tFirst = 1
        While 'tRoutine.AtEnd {
            Set tText = tText _ $Select(tFirst: "", 1: $Char(10)) _ tRoutine.ReadLine()
            Set tFirst = 0
        }
    } Catch {
        Set tText = "<unreadable>"
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>What probe class <var>pName</var>'s <code>Probe</code> method answers, called in the probe namespace; the
/// caller's namespace is restored.</p>
ClassMethod Answer(pName As %String) As %String
{
    Set tAnswer = "<unavailable>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Set tAnswer = $ClassMethod(pName, "Probe")
    } Catch {
        Set tAnswer = "<unavailable>"
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The document <var>pName</var> in the probe namespace as the viewer reads it: lines joined with line feeds.</p>
ClassMethod Stored(pName As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, pName)
}

/// <p>An agent's class save, taken as a script and run: the class holds the text the card reviewed, the edit's new
/// line replaces the old, the card's changed lines are in the stored text, and the class compiled by the script
/// runs the new code.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> renders the placeholder
/// <code>"&lt;content&gt;"</code> for the lines -- this goes red.</p>
Method TestTheScriptOfAnAgentClassSaveWritesTheReviewedText()
{
    Set tName = "OcuProbe2020.RunSave"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), "a probe class is held")
    Set tBefore = ..Stored(tName _ ".cls")
    Set tProposal = ..Mint(..#CLASSSAVE, ..SaveInput(tName _ ".cls", "    Quit 1", "    Quit 2"))
    If '$IsObject(tProposal) Quit
    Set tRow = tProposal.changed.%Get(0)
    Set tExpected = $Replace(tBefore, "    Quit 1", "    Quit 2")
    Set tScript = ..Take(tProposal)
    Do $$$AssertTrue(tScript '= "", "the script is rendered")
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tBefore, "taking the script writes nothing")
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the script runs: " _ tOutput)
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tExpected, "the class holds the reviewed text, byte for byte")
    Do $$$AssertTrue(..Stored(tName _ ".cls") [ tRow.after, "and the changed lines the card showed")
    Do $$$AssertTrue(tOutput '[ "ERROR", "the script reports no error: " _ tOutput)
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tName), "the class is compiled")
    Do $$$AssertEquals(..Answer(tName), 2, "and runs the reviewed code")
}

/// <p>An agent's routine save, taken as a script and run: the routine holds the text the card reviewed, one
/// <code>ROUTINE</code> header line from the read and none written into its body.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> writes the header line too -- the
/// body leg goes red.</p>
Method TestTheScriptOfAnAgentRoutineSaveWritesTheReviewedTextWithoutItsHeaderLine()
{
    Set tName = "OcuProbe2020Mac.mac"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, tName), "a probe routine is held")
    Set tBefore = ..Stored(tName)
    Do $$$AssertTrue($Piece(tBefore, $Char(10), 1) = "ROUTINE OcuProbe2020Mac", "the read begins with the header line: " _ $Piece(tBefore, $Char(10), 1))
    Set tProposal = ..Mint(..#ROUTINESAVE, ..SaveInput(tName, " Quit", " Set tProbe = 2 Quit"))
    If '$IsObject(tProposal) Quit
    Set tRow = tProposal.changed.%Get(0)
    Set tExpected = $Replace(tBefore, " Quit", " Set tProbe = 2 Quit")
    Set tScript = ..Take(tProposal)
    Do $$$AssertTrue(tScript '= "", "the script is rendered")
    Do $$$AssertTrue(tScript '[ "ROUTINE OcuProbe2020Mac", "it carries no header line")
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the script runs: " _ tOutput)
    Do $$$AssertEquals(..Stored(tName), tExpected, "the routine holds the reviewed text, byte for byte")
    Do $$$AssertTrue((..Stored(tName) _ $Char(10)) [ tRow.after, "and the changed lines the card showed")
    Do $$$AssertTrue(..RawRoutine(tName) '[ "ROUTINE ", "and no header line was written into its body: " _ ..RawRoutine(tName))
    Do $$$AssertTrue(tOutput '[ "ERROR", "the script reports no error: " _ tOutput)
}

/// <p>An agent's class create, taken as a script and run: the class is created holding the text the card
/// showed as added lines, the same as the port's own create stores, and is compiled.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> skips the class's lines -- this goes
/// red.</p>
Method TestTheScriptOfAnAgentClassCreateWritesTheReviewedText()
{
    Set tName = "OcuProbe2020.RunMade"
    Set tText = $ClassMethod(..#PROBE, "NewClassText", tName)
    Set tProposal = ..Mint(..#CLASSCREATE, ..CreateInput(tName _ ".cls", tText))
    If '$IsObject(tProposal) Quit
    Set tRow = tProposal.changed.%Get(0)
    Set tScript = ..Take(tProposal)
    Do $$$AssertTrue(tScript '= "", "the script is rendered")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, tName _ ".cls"), "taking the script creates nothing")
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the script runs: " _ tOutput)
    Set tByScript = ..Stored(tName _ ".cls")
    Do $$$AssertEquals(tByScript, tText _ $Char(10), "the class holds the reviewed text, byte for byte, and the vendor's closing empty line")
    Do $$$AssertEquals(tRow.after, tText _ $Char(10), "which is the text the card showed as added lines")
    Do $$$AssertTrue(tOutput '[ "ERROR", "the script reports no error: " _ tOutput)
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tName), "the class is compiled")
    Do $$$AssertEquals(..Answer(tName), 1, "and runs the reviewed code")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "the class is removed to compare with the port's own create")
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("names") = tName _ ".cls"
    Set tQuery("content") = tText
    Set tQuery("Compile") = 1
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Classes", "CREATE", .tQuery, "", .tResult, .tHttp, .tFault, .tDocument)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200), "the port's own create is answered: " _ tHttp)
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tByScript, "and stores what the script stored")
}

/// <p>An agent's routine and include-file creates, taken as scripts and run: each document holds the text the card
/// showed, with its header line from the read and none in the body, the same as the port's own create stores.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> writes the header line too -- the
/// body legs go red.</p>
Method TestTheScriptOfAnAgentRoutineCreateWritesTheReviewedTextWithoutItsHeaderLine()
{
    For tName = "OcuProbe2020Mac.mac", "OcuProbe2020Mac.inc" {
        Set tText = $ClassMethod(..#PROBE, "NewRoutineText", tName)
        Set tProposal = ..Mint(..#ROUTINECREATE, ..CreateInput(tName, tText))
        If '$IsObject(tProposal) Continue
        Set tRow = tProposal.changed.%Get(0)
        Set tScript = ..Take(tProposal)
        Do $$$AssertTrue(tScript '= "", tName _ ": the script is rendered")
        Do $$$AssertTrue(tScript '[ "ROUTINE OcuProbe2020Mac", tName _ ": it carries no header line")
        Do $$$AssertStatusOK(..Run(tScript, .tOutput), tName _ ": the script runs: " _ tOutput)
        Set tByScript = ..Stored(tName)
        Do $$$AssertEquals(tByScript, tText, tName _ ": the document holds the reviewed text, byte for byte")
        Do $$$AssertEquals(tRow.after, tText _ $Char(10), tName _ ": which is the text the card showed as added lines")
        Do $$$AssertTrue(..RawRoutine(tName) '[ "ROUTINE ", tName _ ": and no header line was written into its body: " _ ..RawRoutine(tName))
        Do $$$AssertTrue(tOutput '[ "ERROR", tName _ ": the script reports no error: " _ tOutput)
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), tName _ ": the document is removed to compare with the port's own create")
        Kill tQuery
        Set tQuery("namespace") = ..#PROBENAMESPACE
        Set tQuery("names") = tName
        Set tQuery("content") = tText
        Set tQuery("Compile") = 1
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Routines", "CREATE", .tQuery, "", .tResult, .tHttp, .tFault, .tDocument)
        Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200), tName _ ": the port's own create is answered: " _ tHttp)
        Do $$$AssertEquals(..Stored(tName), tByScript, tName _ ": and stores what the script stored")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), tName _ ": the port's document is removed")
    }
}

/// <p>A create's script runs only while the name is free: a class another writer holds under the same name after
/// the mint stands unchanged, and the script says nothing was created.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> renders a create without its
/// existence guard -- this goes red.</p>
Method TestTheScriptOfACreateLeavesAHeldNameAlone()
{
    Set tName = "OcuProbe2020.Taken"
    Set tProposal = ..Mint(..#CLASSCREATE, ..CreateInput(tName _ ".cls", $ClassMethod(..#PROBE, "NewClassText", tName)))
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), "another writer takes the name")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, tName, "7"), "and saves its own text")
    Set tOther = ..Stored(tName _ ".cls")
    Do $$$AssertTrue(tOther [ "Quit 7", "the other writer's text is held")
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the script runs: " _ tOutput)
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tOther, "the other writer's class stands")
    Do $$$AssertTrue(tOutput [ (tName _ ".cls is taken"), "and the script says nothing was created: " _ tOutput)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tName), "and compiled nothing")
}

/// <p>The same create script pasted line by line into a terminal, which runs each line on its own: every line
/// runs without an error, the other writer's class stands, the script says nothing was created, and nothing is
/// compiled.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> wraps the create's steps in one
/// block <code>If ... {</code> spanning lines -- this goes red: the block's lines fail and every step between
/// them writes over the held class.</p>
Method TestTheScriptOfACreatePastedLineByLineLeavesAHeldNameAlone()
{
    Set tName = "OcuProbe2020.Lines"
    Set tProposal = ..Mint(..#CLASSCREATE, ..CreateInput(tName _ ".cls", $ClassMethod(..#PROBE, "NewClassText", tName)))
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tName), "another writer takes the name")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Rewrite", ..#PROBENAMESPACE, tName, "7"), "and saves its own text")
    Set tOther = ..Stored(tName _ ".cls")
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..RunLines(tScript, .tOutput, .tErrors), "the script is pasted line by line")
    Do $$$AssertEquals(tErrors, 0, "every line runs on its own: " _ tOutput)
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tOther, "the other writer's class stands")
    Do $$$AssertTrue(tOutput [ (tName _ ".cls is taken"), "and the script says nothing was created: " _ tOutput)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tName), "and compiled nothing")
}

/// <p>A class's and a routine's create scripts pasted line by line into a terminal on a free name: every line runs
/// without an error, and each document holds the text the card reviewed, the class compiled and running it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> wraps the create's steps in one
/// block <code>If ... {</code> spanning lines -- the error-free legs go red.</p>
Method TestTheScriptOfACreatePastedLineByLineWritesTheReviewedText()
{
    Set tName = "OcuProbe2020.LinesMade"
    Set tText = $ClassMethod(..#PROBE, "NewClassText", tName)
    Set tProposal = ..Mint(..#CLASSCREATE, ..CreateInput(tName _ ".cls", tText))
    If '$IsObject(tProposal) Quit
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..RunLines(tScript, .tOutput, .tErrors), "the class script is pasted line by line")
    Do $$$AssertEquals(tErrors, 0, "every line of the class script runs on its own: " _ tOutput)
    Do $$$AssertEquals(..Stored(tName _ ".cls"), tText _ $Char(10), "the class holds the reviewed text")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tName), "and is compiled")
    Do $$$AssertEquals(..Answer(tName), 1, "and runs the reviewed code")
    Set tRoutine = "OcuProbe2020Mac.mac"
    Set tRoutineText = $ClassMethod(..#PROBE, "NewRoutineText", tRoutine)
    Set tProposal = ..Mint(..#ROUTINECREATE, ..CreateInput(tRoutine, tRoutineText))
    If '$IsObject(tProposal) Quit
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..RunLines(tScript, .tOutput, .tErrors), "the routine script is pasted line by line")
    Do $$$AssertEquals(tErrors, 0, "every line of the routine script runs on its own: " _ tOutput)
    Do $$$AssertEquals(..Stored(tRoutine), tRoutineText, "the routine holds the reviewed text")
    Do $$$AssertTrue(..RawRoutine(tRoutine) '[ "ROUTINE ", "with no header line written into its body: " _ ..RawRoutine(tRoutine))
}

/// <p>A routine create's script runs only while no routine of its base name is held, the rule the port's taken
/// check applies: a <code>.mac</code> whose hand-written <code>.int</code> another writer saved after the mint is
/// not written, run as a method body, so its compile cannot replace that <code>.int</code>; and an
/// <code>.int</code> beside an uncompiled <code>.mac</code> saved after the mint is not written, pasted line by
/// line. Each script says nothing was created.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.FreeCheck</method> checks the exact name with
/// <code>%RoutineMgr.Exists</code> -- both legs go red.</p>
Method TestTheScriptOfARoutineCreateLeavesABaseNameTakerAlone()
{
    Set tProposal = ..Mint(..#ROUTINECREATE, ..CreateInput("OcuProbe2020Int.mac", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Int.mac")))
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), "another writer saves a hand-written intermediate routine of the base name")
    Set tHeld = ..RawRoutine("OcuProbe2020Int.int")
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the .mac script runs: " _ tOutput)
    Do $$$AssertEquals(..RawRoutine("OcuProbe2020Int.int"), tHeld, "the hand-written intermediate routine keeps its text")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020Int.mac"), "and no .mac was written")
    Do $$$AssertTrue(tOutput [ "OcuProbe2020Int.mac is taken", "and the script says nothing was created: " _ tOutput)
    Set tProposal = ..Mint(..#ROUTINECREATE, ..CreateInput("OcuProbe2020Mac.int", $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Mac.int")))
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Mac.mac"), "another writer saves an uncompiled routine of the base name")
    Set tHeld = ..RawRoutine("OcuProbe2020Mac.mac")
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..RunLines(tScript, .tOutput, .tErrors), "the .int script is pasted line by line")
    Do $$$AssertEquals(tErrors, 0, "every line runs on its own: " _ tOutput)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020Mac.int"), "no .int was written beside the routine")
    Do $$$AssertEquals(..RawRoutine("OcuProbe2020Mac.mac"), tHeld, "which keeps its text")
    Do $$$AssertTrue(tOutput [ "OcuProbe2020Mac.int is taken", "and the script says nothing was created: " _ tOutput)
}

/// <p>A class another writer holds in another letter case after the mint is not written by the script: its own check
/// reads the name in any letter case, so the script says the name is taken, writes nothing and compiles nothing,
/// and the held class stands with no second class beside it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.FreeCheck</method> checks the exact name with
/// <code>%RoutineMgr.Exists</code> -- the taken leg goes red (the vendor's #5092 answers instead).</p>
Method TestTheScriptOfAClassCreateDoesNotWriteBesideACaseVariantTakenAfterTheMint()
{
    Set tName = "OcuProbe2020.Case"
    Set tHeld = "OcuProbe2020.CASE"
    Set tProposal = ..Mint(..#CLASSCREATE, ..CreateInput(tName _ ".cls", $ClassMethod(..#PROBE, "NewClassText", tName)))
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tHeld), "another writer takes the name in another case")
    Set tOther = ..Stored(tHeld _ ".cls")
    Do $$$AssertTrue(tOther '= "", "its class is held")
    Set tScript = ..Take(tProposal)
    Do $$$AssertStatusOK(..Run(tScript, .tOutput), "the script runs: " _ tOutput)
    Do $$$AssertEquals(..Stored(tHeld _ ".cls"), tOther, "the held class stands")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, tName _ ".cls"), "and no class of the proposed spelling was written")
    Do $$$AssertTrue(tOutput [ (tName _ ".cls is taken"), "the script's own check refuses it: " _ tOutput)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, tHeld), "and compiles nothing")
}

/// <p>The vendor refuses a put over a document the namespace holds when the put carries no version, which is what a
/// create sends after the port's taken check: a held class and a held routine are each refused 409
/// <code>EXPLORER.DOCUMENT.CONFLICT</code> and keep their text, while the same put of a name nothing holds is
/// accepted, so the refusal is the held name's and not the call's.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Test.AtelierPortPutProbe</class> puts with <code>ignoreConflict</code> --
/// the refusal legs go red.</p>
Method TestAPutOverAHeldDocumentWithNoVersionIsRefusedByTheVendor()
{
    Set tProbe = "OcuPilot.Test.AtelierPortPutProbe"
    Set tFree = "OcuProbe2020.PutFree"
    Set tSC = $ClassMethod(tProbe, "PutWithoutVersion", ..#PROBENAMESPACE, tFree _ ".cls", $ClassMethod(..#PROBE, "NewClassText", tFree), .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 201), "a put of a name nothing holds is accepted as a creation: " _ tHttp)
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, tFree _ ".cls"), "and the class is held")
    Set tHeld = "OcuProbe2020.PutHeld"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, tHeld), "a class is held")
    Set tBefore = ..Stored(tHeld _ ".cls")
    Set tSC = $ClassMethod(tProbe, "PutWithoutVersion", ..#PROBENAMESPACE, tHeld _ ".cls", $ClassMethod(..#PROBE, "ClassText", tHeld, "OVERWRITTEN"), .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 409) && $IsObject(tFault) && (tFault.code = "EXPLORER.DOCUMENT.CONFLICT"), "a put over it with no version is refused 409: " _ tHttp)
    Do $$$AssertEquals(..Stored(tHeld _ ".cls"), tBefore, "and the class keeps its text")
    Set tRoutine = "OcuProbe2020Mac.mac"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, tRoutine), "a routine is held")
    Set tBeforeRoutine = ..Stored(tRoutine)
    Set tSC = $ClassMethod(tProbe, "PutWithoutVersion", ..#PROBENAMESPACE, tRoutine, "ROUTINE OcuProbe2020Mac" _ $Char(10) _ " Set tProbe = ""OVERWRITTEN""", .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 409) && $IsObject(tFault) && (tFault.code = "EXPLORER.DOCUMENT.CONFLICT"), "a put over it with no version is refused 409: " _ tHttp)
    Do $$$AssertEquals(..Stored(tRoutine), tBeforeRoutine, "and the routine keeps its text")
}

}
