/// <p>Story 20.20's agent create through the dispatcher and Confirm on probe documents in <code>USER</code> (AD-6,
/// AD-10, AD-53, AD-54, DW-2242): the two creates are advertised, non-destructive, agent-only writes whose keys are
/// enabled; a minted class or routine card shows the whole new document as added lines from line 1 and writes
/// nothing; Confirm writes the document, compiles it as the person, and marks and ledgers it; a document that
/// saved but did not compile is said plainly; a name taken after the mint is refused as a changed target and never
/// overwritten; and the create key governs the agent at the dispatcher and at Confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and a <code>USER</code>
/// namespace whose routines database the running account can write. It runs in process and opens no HTTP request. It
/// creates and removes the documents <class>OcuPilot.Test.ExplorerCreateProbe</class> names, and snapshots the stored
/// governance policy around each test.</p>
Class OcuPilot.Test.ExplorerCreateFlow Extends %UnitTest.TestCase
{

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerCreateProbe";

Parameter CLASSTOOL = "explorer.classes.create";

Parameter ROUTINETOOL = "explorer.routines.create";

Parameter ALPHA = "OcuProbe2020.Flow";

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
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Sends <var>pTool</var> with <var>pInput</var> through the agent's dispatcher in <var>pNamespace</var>.</p>
ClassMethod Dispatch(pNamespace As %String, pTool As %String, pInput As %DynamicObject, Output pContent, Output pIsError, Output pProposal) As %Status
{
    Set tWrite = ##class(OcuPilot.Test.ExplorerWrite).%New("")
    Quit tWrite.DispatchFor(pTool, pNamespace, pInput, .pContent, .pIsError, .pProposal)
}

/// <p>The <code>code</code> member of the JSON result <var>pContent</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pContent As %String) As %String
{
    Set tCode = ""
    Try {
        Set tCode = ##class(%DynamicAbstractObject).%FromJSON(pContent).%Get("code")
    } Catch {
        Set tCode = ""
    }
    Quit tCode
}

/// <p>The create's input: the name and the whole text, with the agent's own words.</p>
ClassMethod Input(pName As %String, pText As %String) As %DynamicObject
{
    Quit {"Names": (pName), "Text": (pText), "rationale": "a probe create", "expectedImpact": "the probe document is held", "reverse": "delete the probe document"}
}

/// <p>The provider's view of each create: advertised, in the provider list and the dispatch lookup, with the schema
/// the closed set of names and the two required members, and its key enabled.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerClassCreate.ADVERTISED</parameter> 0 -- the
/// advertised leg goes red.</p>
Method TestTheCreatesAreAdvertisedAgentOnlyWrites()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    For tCase = $ListBuild(..#CLASSTOOL, "OcuPilot.Screen.Tool.ExplorerClassCreate"), $ListBuild(..#ROUTINETOOL, "OcuPilot.Screen.Tool.ExplorerRoutineCreate") {
        Set tWire = $ClassMethod(tRegistry, "WireName", $List(tCase, 1))
        Set tSchema = ""
        For tI = 1:1:+$Get(tProvider) {
            If tProvider(tI, "name") = tWire Set tSchema = ##class(%DynamicAbstractObject).%FromJSON(tProvider(tI, "inputSchema"))
        }
        Do $$$AssertTrue($IsObject(tSchema), $List(tCase, 1) _ " is in the provider list")
        Do $$$AssertEquals($Parameter($List(tCase, 2), "ADVERTISED"), 1, $List(tCase, 1) _ " is advertised")
        Do $$$AssertEquals($Parameter($List(tCase, 2), "DESTRUCTIVE"), 0, $List(tCase, 1) _ " is not destructive")
        Do $$$AssertEquals($Parameter($List(tCase, 2), "SCREENACTIONS"), "", $List(tCase, 1) _ " has no screen action")
        Set tNames = ""
        Set tIterator = tSchema.properties.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tNames, "Names,Text,rationale,expectedImpact,reverse", $List(tCase, 1) _ "'s schema offers the name, the text and the agent's words")
        Do $$$AssertEquals(tSchema.required.%ToJSON() _ " " _ tSchema.additionalProperties, "[""Names"",""Text""] 0", $List(tCase, 1) _ " requires the name and the text and allows nothing else")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys), "the baseline reads")
    Do $$$AssertEquals(tKeys.%Get(..#CLASSTOOL) _ " " _ tKeys.%Get(..#ROUTINETOOL), "1 1", "both keys ship enabled")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, {"Names": (..#ALPHA _ ".cls")}, .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && (..CodeOf($Get(tContent)) = "TOOL.ARGUMENTS"), "a call carrying only the name is refused 400: " _ $Extract($Get(tContent), 1, 200))
}

/// <p>A class's proposal: one row, the whole new text as added lines from line 1 with an empty before, destructive
/// false, its consequence the compile, WRITE required on the routines database, and the agent's words stored; and
/// nothing is written before Confirm.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerCreateMint.Mint</method> stores the text with
/// <code>Compile</code> false -- the stored-arguments leg goes red. The stored <code>Compile</code> argument is pinned
/// only as stored: the Confirm compiles unconditionally on create, so a stored false changes no compile.</p>
Method TestAClassCreateShowsTheWholeTextAndWritesNothing()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ ".cls", tText), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the create is minted: " _ $Extract($Get(tContent), 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size(), 1, "the proposal shows one row")
    If tProposal.changed.%Size() '= 1 Quit
    Set tRow = tProposal.changed.%Get(0)
    Do $$$AssertEquals(tRow.kind _ " " _ tRow.line _ " [" _ tRow.before _ "]", "lines 1 []", "the row is a lines row from line 1 with nothing before")
    Do $$$AssertEquals(tRow.after, tText _ $Char(10), "and holds the whole new text")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the proposal is stored")
    Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "0 EXPLORER.SAVE.COMPILES", "it is not destructive and its consequence is the compile")
    Do $$$AssertTrue($Get(tValues("requiredPairs")) [ "%DB_USER:WRITE", "it requires WRITE on the routines database: " _ $Get(tValues("requiredPairs")))
    Do $$$AssertTrue(($Get(tValues("arguments")) [ """Compile"":true") && ($Get(tValues("arguments")) [ "Quit 1"), "its stored arguments hold the whole text and compile true")
    Do $$$AssertEquals($Get(tValues("rationale")) _ "|" _ $Get(tValues("expectedImpact")) _ "|" _ $Get(tValues("reverse")), "a probe create|the probe document is held|delete the probe document", "and the agent's words, for the card")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "nothing is written before Confirm")
}

/// <p>A confirmed class create writes the text, compiles it as the person, and is marked and ledgered: the class
/// holds the text, is compiled, reports no error, its confirm answers the change action <code>created</code>, and
/// the compile's own lines come back for the card.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerCreate.ComposeCreate</method> puts
/// <code>Compile</code> false in the payload -- the compiled and output legs go red.</p>
Method TestAConfirmedClassCreateIsWrittenCompiledAndMarked()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ ".cls", tText), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the create is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ " " _ tResult.action _ " " _ tResult.auditMarked, "confirmed created 1", "the proposal is confirmed, as a create, and marked")
    Do $$$AssertEquals($ZStrip($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "<>WC"), $ZStrip(tText, "<>WC"), "the class holds the text")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and is compiled")
    Do $$$AssertTrue($IsObject(tResult.output) && (tResult.output.%GetTypeOf("errors") = "boolean"), "the confirm answers a compile errors flag")
    Do $$$AssertEquals(tResult.output.errors, 0, "and its compile reports no error: " _ tResult.%ToJSON())
    Do $$$AssertTrue((tResult.output.%GetTypeOf("lines") = "array") && (tResult.output.lines.%ToJSON() [ ("Compiling class " _ ..#ALPHA)), "and the compile's own lines, for the card: " _ tResult.output.%ToJSON())
}

/// <p>A create whose class does not compile is still saved: the confirm answers the compile's error, the class
/// exists, and it is not compiled.</p>
Method TestASavedNotCompiledClassIsSaidPlainly()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA, 1)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ ".cls", tText), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the create is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm writes: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.output.errors, 1, "the confirm reports the compile's error")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "the class is held, uncompiled")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, ..#ALPHA), "and is not compiled")
}

/// <p>A name taken after the mint is refused 409 <code>TARGETCHANGED</code> at Confirm, and the other writer's
/// document stands: nothing is overwritten.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> skips the absence
/// digest's comparison -- this goes red.</p>
Method TestANameTakenAfterTheMintIsNeverOverwritten()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ ".cls", tText), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the create is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, ..#ALPHA, 0), "another writer takes the name")
    Set tOther = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), tOther, "and the other writer's document stands")
}

/// <p>A routine, an include file and an intermediate routine are each proposed and, on Confirm, written and
/// compiled with no error, with the name and header of the document held.</p>
Method TestARoutineAndAnIncludeFileAreCreatedOnConfirm()
{
    For tName = "OcuProbe2020Mac.mac", "OcuProbe2020Mac.inc", "OcuProbe2020Int.int" {
        Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#ROUTINETOOL, ..Input(tName, $ClassMethod(..#PROBE, "NewRoutineText", tName)), .tContent, .tIsError, .tProposal)
        If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, tName _ " is minted: " _ $Extract($Get(tContent), 1, 300)) Continue
        Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tName _ " is confirmed: " _ $Get(tCode))
        If '$IsObject($Get(tResult)) Continue
        Do $$$AssertEquals(tResult.state _ " " _ tResult.action, "confirmed created", tName _ " is confirmed as a create")
        Do $$$AssertTrue($IsObject(tResult.output) && (tResult.output.%GetTypeOf("errors") = "boolean") && 'tResult.output.errors, tName _ " compiles with no error: " _ tResult.%ToJSON())
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, tName), tName _ " is held")
        Do $$$AssertEquals($ZStrip($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, tName), "<>WC"), $ZStrip($ClassMethod(..#PROBE, "NewRoutineText", tName), "<>WC"), tName _ " holds its text")
    }
}

/// <p>The create key governs the agent: disabled, the dispatcher refuses the call and mints nothing; a proposal
/// minted while it was enabled is refused 403 at Confirm, with nothing written.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Kernel.Governance.Baseline</class> lists the key as write-exempt -- both
/// refusals go red.</p>
Method TestTheCreateKeyGovernsTheAgentAtTheDispatcherAndAtConfirm()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA)
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ ".cls", tText), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the create is minted while the key is enabled: " _ $Extract($Get(tContent), 1, 300)) Quit
    Kill tSettings
    Set tSettings(..#CLASSTOOL) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is disabled through its stored setting")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL)
    Do $$$AssertTrue(tBefore >= 0, "the proposal count reads")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input("OcuProbe2020.Other.cls", $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Other")), .tRefused, .tRefusedIsError, .tNone)
    Do $$$AssertTrue(tRefusedIsError && (..CodeOf($Get(tRefused)) = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), "the dispatcher refuses the call: " _ $Extract($Get(tRefused), 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLASSTOOL), tBefore, "and mints nothing")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#PROBENAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the earlier proposal is refused at Confirm")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, ..#ALPHA _ ".cls"), "and nothing is written")
}

/// <p>Replace the stored payload's text of proposal <var>pKey</var> with 1,000,001 characters, keeping its other
/// members, so its draft renders past the script bound.</p>
ClassMethod StorePastBound(pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit $$$ERROR($$$GeneralError, "the proposal row is not found")
    Set tRow = ##class(OcuPilot.Kernel.State.Propose).%OpenId(tRS.%Get("ID"))
    If '$IsObject(tRow) Quit $$$ERROR($$$GeneralError, "the proposal row does not open")
    Do tRow.Payload.Rewind()
    Set tPayload = ##class(%DynamicObject).%FromJSON(tRow.Payload.Read(100000))
    Do tPayload.%Set(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, $Translate($Justify("", 1000001), " ", "x"), "string")
    Do tRow.Payload.Clear()
    Do tRow.Payload.Write(tPayload.%ToJSON())
    Set tSC = tRow.%Save()
    Quit tSC
}

/// <p>Take the draft of proposal <var>pKey</var> as the test process's user, through the draft's kernel entry the route
/// calls: the status, the answer, and the refusal code.</p>
ClassMethod Draft(pKey As %String, Output pHttp As %Integer, Output pAnswer As %DynamicObject, Output pCode As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Proposal.Draft).Take(pKey, $Username, "http://localhost", .pAnswer, .pHttp, .pCode)
}

/// <p>The copy-out draft of a create (AD-59, Story 20.20): a create whose script passes the 1,000,000-character bound
/// answers 409 <code>PROPOSAL.NODRAFT</code> with the proposal still live, and a create within the bound answers its
/// script and closes the proposal <code>canceled</code> reason <code>draft</code>.</p>
Method TestACreateDraftIsRefusedPastTheBoundAndClosesWithinIt()
{
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ "Big.cls", $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA _ "Big")), .tBigContent, .tBigIsError, .tBigProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tBigIsError && $IsObject($Get(tBigProposal)), "the create is minted: " _ $Extract($Get(tBigContent), 1, 300))
    If '$IsObject($Get(tBigProposal)) || tBigIsError Quit
    Set tBigKey = tBigProposal.proposalId
    ; A create's wire text is capped at 30,000 characters, so the over-bound script is stored past the mint: the
    ; stored payload's text is replaced by 1,000,001 characters, which is what the draft renders.
    Set tSC = ..StorePastBound(tBigKey)
    Do $$$AssertStatusOK(tSC, "the stored text is replaced past the bound")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Draft(tBigKey, .tBigHttp, .tBigAnswer, .tBigCode)
    Do $$$AssertStatusNotOK(tSC, "the over-bound draft is refused")
    Do $$$AssertEquals(tBigHttp, 409, "the over-bound draft answers 409")
    Do $$$AssertEquals(tBigCode, ##class(OcuPilot.Kernel.Proposal.Write).#NODRAFT, "as a write with no script form")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tBigKey, "State"), "live", "and the proposal stays live")
    Set tSC = ..Dispatch(..#PROBENAMESPACE, ..#CLASSTOOL, ..Input(..#ALPHA _ "Draft.cls", $ClassMethod(..#PROBE, "NewClassText", ..#ALPHA _ "Draft")), .tSmallContent, .tSmallIsError, .tSmallProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tSmallIsError && $IsObject($Get(tSmallProposal)), "the within-bound create is minted: " _ $Extract($Get(tSmallContent), 1, 300))
    If '$IsObject($Get(tSmallProposal)) || tSmallIsError Quit
    Set tSmallKey = tSmallProposal.proposalId
    Set tSC = ..Draft(tSmallKey, .tSmallHttp, .tSmallAnswer, .tSmallCode)
    Do $$$AssertStatusOK(tSC, "the within-bound draft is answered")
    Do $$$AssertEquals(tSmallHttp, 200, "the within-bound draft answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tSmallAnswer)): tSmallAnswer.%Get("closedReason"), 1: ""), "draft", "its answer carries the draft reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSmallKey, "State"), "canceled", "the proposal closes canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSmallKey, "ClosedReason"), "draft", "with the draft reason")
}

}
