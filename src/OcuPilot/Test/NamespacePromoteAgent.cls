/// <p>Pins the agent's side of Story 24.9's promote (AD-6, AD-10, AD-22, AD-40, AD-52, AD-53): <code>explorer.namespacediff.promote</code>
/// sent through the agent's dispatcher over the <code>OcuProbe248</code> documents in <code>USER</code> and
/// <code>HSCUSTOM</code>, with its key enabled through the stored setting and put back after each test. At the shipped value the
/// dispatcher, and a confirm of a proposal minted there, are refused by governance. With the key enabled the call mints a card
/// listing the steps and the documents left alone, stating that nothing is undone; its confirm writes and compiles the documents;
/// and a re-save of a document in the other namespace between the mint and the confirm refuses the confirm as target-changed, by
/// the fingerprint. A set naming a document of OcuPilot's own is refused at the mint, and the kernel's arm refuses it for this
/// tool; the agent's fence and the tool's schema and description are pinned directly.</p>
/// <p>Needs the install namespace and the namespaces <code>USER</code> and <code>HSCUSTOM</code>. It saves and removes the probe
/// documents in both around every test, snapshots the stored governance policy before each test and restores it after it, and
/// seeds one completed turn as the running principal and removes it.</p>
Class OcuPilot.Test.NamespacePromoteAgent Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerNamespacePromote";

Parameter TOOLNAME = "explorer.namespacediff.promote";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter STEPS = "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248Mac.mac";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#HERE)
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit ..Remove()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit ..Remove()
}

/// <p>Remove the probe documents from both namespaces.</p>
Method Remove() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE)
    Do $$$AssertStatusOK(tSC, "the probe documents are removed from both namespaces")
    Quit $$$OK
}

/// <p>Enable the promote's key through its stored setting.</p>
Method EnableKey()
{
    Kill tSettings
    Set tSettings(..#TOOLNAME) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the promote's key is enabled through its stored setting")
}

/// <p>The arguments of a call promoting <var>pDocuments</var> from the route's namespace into <code>HSCUSTOM</code>.</p>
ClassMethod Arguments(pDocuments As %String) As %DynamicObject
{
    Set tArgs = {"rationale": "Move the reviewed documents.", "expectedImpact": "The other namespace holds them."}
    Do tArgs.%Set("target", ..#THERE, "string")
    Do tArgs.%Set("spec", ..#SPEC, "string")
    Do tArgs.%Set("Documents", pDocuments, "string")
    Quit tArgs
}

/// <p>The agent's call of the promote tool with <var>pInput</var>, sent as one <code>tool_use</code> block through the
/// dispatcher inside a completed turn seeded for the running account: <var>pContent</var> is the tool result the model reads,
/// <var>pIsError</var> whether it is an error and <var>pProposal</var> that result parsed.</p>
Method DispatchFor(pInput As %DynamicObject, Output pContent As %String, Output pIsError As %Boolean, Output pProposal) As %Status
{
    Set pContent = ""
    Set pIsError = 1
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tUse = {"type": "tool_use", "id": "toolu_promote"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set pContent = tResults.%Get(0).%Get("content")
    Set pIsError = tResults.%Get(0).%Get("is_error")
    Try {
        Set pProposal = ##class(%DynamicObject).%FromJSON(pContent)
    } Catch {
        Set pProposal = ""
    }
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> in process as the running account.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The stored proposal <var>pProposalId</var>'s value <var>pName</var>.</p>
ClassMethod Stored(pProposalId As %String, pName As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
    Quit $Get(tValues(pName))
}

/// <p>The hash of <var>pDocument</var> in <var>pNamespace</var>, or <code>""</code>.</p>
ClassMethod HashOf(pNamespace As %String, pDocument As %String) As %String
{
    Kill tCriteria
    Set tCriteria("spec") = pDocument
    Set tCriteria("namespace") = pNamespace
    Set tSC = ##class(OcuPilot.Port.DevToolPort).Invoke("DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) || (tRows.%Size() = 0) Quit ""
    Quit tRows.%Get(0).%Get("Hash")
}

/// <p>AC5: with the key enabled, the agent's call mints a card of the three steps and the one document left alone, destructive,
/// with the no-rollback consequence and no <code>reverse</code>; nothing is written by the mint; and the confirm writes the three
/// documents into the other namespace as the person's action does, answering each outcome to the screen alone, so the tool result
/// the model read and the stored proposal hold no console line. At the shipped value governance refuses the call.</p>
/// <p>Mutation (Rule 19): set <code>"explorer.namespacediff.promote"</code> to <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the governance leg and <class>OcuPilot.Test.GovernanceBaseline</class> go
/// red.</p>
Method TestTheAgentPromotesThroughMintAndConfirmOnlyWithItsKeyEnabled()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Set tSC = ..DispatchFor(..Arguments(..#STEPS), .tRefused, .tIsError, .tAnswer)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && $IsObject($Get(tAnswer)) && (tAnswer.%Get("code") = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), "at the shipped value the dispatcher refuses the call: " _ tRefused)
    Do ..EnableKey()
    Set tBefore = ..HashOf(..#THERE, "OcuProbe248.Changed.cls")
    Set tSC = ..DispatchFor(..Arguments(..#STEPS), .tContent, .tIsError, .tProposal)
    Do $$$AssertTrue($$$ISOK(tSC) && 'tIsError && $IsObject($Get(tProposal)), "the call is minted through the dispatcher: " _ $Extract(tContent, 1, 300))
    If '$IsObject($Get(tProposal)) Quit
    Set tCard = tProposal.changed.%Get(0)
    Do $$$AssertEquals(tCard.field _ "|" _ tCard.after, "Documents|OcuProbe248.Changed.cls -- Content differs" _ $Char(10) _ "OcuProbe248.OnlyHere.cls -- Only in this namespace" _ $Char(10) _ "OcuProbe248Mac.mac -- Only in this namespace" _ $Char(10) _ "1 document only in the other namespace stays as it is.", "its card lists the steps and the document left alone")
    Do $$$AssertEquals(..Stored(tProposal.proposalId, "consequence") _ "|" _ (..Stored(tProposal.proposalId, "destructive") + 0) _ "|" _ ..Stored(tProposal.proposalId, "reverse"), "EXPLORER.PROMOTE.NOROLLBACK|1|", "it is destructive, states no rollback and carries no reverse")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "class|USER|OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248Mac.mac", "its target is the document set in the route's namespace")
    Set tStoredArguments = ##class(%DynamicObject).%FromJSON(..Stored(tProposal.proposalId, "arguments"))
    Do $$$AssertEquals(tStoredArguments.Namespace _ "|" _ tStoredArguments.Target _ "|" _ tStoredArguments.Generated, "USER|HSCUSTOM|no", "its stored arguments hold the namespaces and the generated choice")
    Do $$$AssertEquals(..HashOf(..#THERE, "OcuProbe248.Changed.cls"), tBefore, "the mint wrote nothing")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm runs: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.state _ "|" _ tResult.action, "confirmed|updated", "it is confirmed as an update")
    Do $$$AssertEquals(tResult.output.documents.%Size() _ "|" _ tResult.output.stopped, "3|0", "its output answers each document to the screen")
    For tDocument = "OcuProbe248.Changed.cls", "OcuProbe248.OnlyHere.cls", "OcuProbe248Mac.mac" {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": the other namespace holds the source's text")
    }
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue((tStored '[ "Compiling") && (tStored '[ "Compilation"), "the stored proposal and ledger hold no console line")
}

/// <p>AC2, AC5: a proposal minted at the shipped value is refused at its confirm by governance and writes nothing; and with the key
/// enabled, a re-save of <code>Changed</code> in the other namespace between the mint and the confirm refuses the confirm as
/// <code>PROPOSAL.TARGETCHANGED</code>, by the fingerprint, with nothing written and the re-saved text kept.</p>
/// <p>Mutation (Rule 19): make the reviewed-hash comparison inert in <method>OcuPilot.Port.DevToolPort.Promote</method> -- this
/// stays green, the person's stale leg of <class>OcuPilot.Test.NamespacePromote</class> goes red; take <code>PlanHash</code> out of
/// <parameter>OcuPilot.Screen.Tool.ExplorerNamespacePromote.FINGERPRINTSUBJECT</parameter> -- the target-changed leg goes red.</p>
Method TestAChangedNamespaceRefusesTheConfirmAndGovernanceRefusesTheBaseline()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Set tBefore = ..HashOf(..#THERE, "OcuProbe248.Changed.cls")
    Set tSC = ..Mint(.tBaseline)
    Do $$$AssertStatusOK(tSC, "a promote is minted at the shipped value")
    Set tSC = ..ConfirmIn(tBaseline, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "its confirm is refused by governance")
    Do ..EnableKey()
    Set tSC = ..Mint(.tProposal)
    Do $$$AssertStatusOK(tSC, "a promote is minted with the key enabled")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#THERE, "OcuProbe248.Changed", $ClassMethod(..#PROBE, "PairText", "Changed", "Resaved")), "Changed is saved again in the other namespace")
    Set tResaved = ..HashOf(..#THERE, "OcuProbe248.Changed.cls")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as target-changed")
    Do $$$AssertEquals(..HashOf(..#THERE, "OcuProbe248.Changed.cls") _ "|" _ ..HashOf(..#THERE, "OcuProbe248.OnlyHere.cls"), tResaved _ "|", "nothing was written and the re-saved text is kept")
    Do $$$AssertNotEquals(tResaved, tBefore, "the re-save moved the document")
}

/// <p>Mint the promote of the three steps through the tool's own view, as the dispatcher's governance gate is not in the way, in
/// the route's namespace, inside a completed turn.</p>
Method Mint(Output pProposal) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(..#TOOL, "View", "", ..Arguments(..#STEPS), 0, .pProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Matrix, Own code, at the mint and at the confirm: a set naming a document of OcuPilot's own, from <code>HSCUSTOM</code> into
/// <code>USER</code>, is refused <code>PROHIBITED.OCUPILOTCODE</code> by the mint, with the kernel's own status; the kernel's own
/// arm refuses a target of that set under this tool's name, and permits another.</p>
/// <p>Mutation (Rule 19): drop the OcuPilot check in <class>OcuPilot.Screen.Tool.ExplorerNamespacePromoteMint</class> -- the mint
/// goes on and the first leg goes red.</p>
Method TestADocumentOfOcuPilotsOwnIsRefusedAtTheMintAndByTheKernel()
{
    Do ..EnableKey()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#THERE)
    Set tOwn = "OcuPilot.Port.DevToolPort.cls"
    Set tArgs = ..Arguments(tOwn)
    Do tArgs.%Set("target", ..#HERE, "string")
    Do tArgs.%Set("spec", tOwn, "string")
    Set tSC = ..DispatchFor(tArgs, .tContent, .tIsError, .tAnswer)
    Do $$$AssertTrue($$$ISOK(tSC) && tIsError && $IsObject($Get(tAnswer)), "the call is an error: " _ tContent)
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, "the mint refuses it as OcuPilot's own code")
    For tCase = $ListBuild(tOwn, 1), $ListBuild("OcuProbe248.Changed.cls," _ tOwn, 1), $ListBuild("ocupilot.port.devtoolport.cls", 1), $ListBuild("OcuProbe248.Changed.cls", 0) {
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("class", ..#THERE, $List(tCase, 1), .tRef)
        Do $$$AssertStatusOK(tSC, "the target reference is built for " _ $List(tCase, 1))
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(..#TOOLNAME, tRef, "{}", "[]", .tProhibits, .tCode)
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE, 1: ""), "the kernel's arm answers for " _ $List(tCase, 1))
    }
}

/// <p>The agent's fence for each step of a plan, at the mint and at the confirm: a create of a name holding <code>%</code>, and any
/// write into <code>%SYS</code>, are refused with the fence's own sentence, and a step of a plain document into the namespace that
/// holds it is not.</p>
Method TestTheAgentsFenceHoldsEachStep()
{
    Set tPlan = {"Steps": [{"Document": "Probe%Name.cls", "Change": "Only in this namespace"}]}
    Do $$$AssertEquals($ClassMethod(..#TOOL, "StepsProblem", ..#THERE, tPlan), ##class(OcuPilot.Screen.Tool.ExplorerSave).AgentProblem(..#THERE, "Probe%Name.cls", 1), "a create of a name holding % is refused with the fence's sentence")
    Do $$$AssertNotEquals($ClassMethod(..#TOOL, "StepsProblem", ..#THERE, tPlan), "", "and the sentence is not empty")
    Set tPlain = {"Steps": [{"Document": "OcuProbe248.Changed.cls", "Change": "Content differs"}, {"Document": "OcuProbe248.OnlyHere.cls", "Change": "Only in this namespace"}]}
    Do $$$AssertEquals($ClassMethod(..#TOOL, "StepsProblem", ..#THERE, tPlain), "", "plain documents of the namespace's own database are not refused")
    Do $$$AssertNotEquals($ClassMethod(..#TOOL, "StepsProblem", "%SYS", tPlain), "", "a write into %SYS is refused")
}

/// <p>The review line for the documents the plan leaves alone is the written sentence with the count for two or more, the
/// singular sentence for one, and absent for none.</p>
/// <p>Mutation (Rule 19): drop the count's replacement in <method>OcuPilot.Screen.Tool.ExplorerNamespacePromote.StateDiff</method>
/// -- the plural leg goes red.</p>
Method TestTheReviewCountsTheDocumentsLeftAlone()
{
    For tCase = $ListBuild(0, ""), $ListBuild(1, "1 document only in the other namespace stays as it is."), $ListBuild(3, "3 documents only in the other namespace stay as they are.") {
        Set tFresh = {"Steps": [{"Document": "OcuProbe248.Changed.cls", "Change": "Content differs"}]}
        Do tFresh.%Set("Warnings", $List(tCase, 1), "number")
        Do $$$AssertStatusOK($ClassMethod(..#TOOL, "StateDiff", tFresh, .tRows, .tProblem), "the review is built for " _ $List(tCase, 1) _ " left alone")
        Do $$$AssertEquals(tRows.%Get(0).after, "OcuProbe248.Changed.cls -- Content differs" _ $Select($List(tCase, 2) = "": "", 1: $Char(10) _ $List(tCase, 2)), "the line reads as written for " _ $List(tCase, 1))
    }
}

/// <p>The tool's schema advertises the other namespace, the pattern, the generated choice, the set and the agent's own words, and
/// no <code>reverse</code> and no reviewed hash; it requires the namespace, the pattern and the set; and its description, the card's
/// consequence and the screen's dialog each state that there is no rollback.</p>
Method TestTheSchemaAdvertisesNoReverseAndTheDescriptionStatesNoRollback()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tNames = ""
    Set tIterator = tSchema.properties.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tNames, "target,spec,generated,Documents,rationale,expectedImpact", "the advertised properties")
    Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""target"",""spec"",""Documents""]", "the required ones")
    Do $$$AssertTrue($Parameter(..#TOOL, "DESCRIPTION") [ "There is no rollback", "the description states there is no rollback")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Consequence", {}), "EXPLORER.PROMOTE.NOROLLBACK", "the card's consequence names the absence of a rollback")
}

}
