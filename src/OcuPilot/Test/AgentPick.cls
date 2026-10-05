/// <p>Pins the agent definition a user picks (Story 19.11, AD-24, AD-30, AD-42, AD-50): the pick is a
/// <code>shell</code> member validated before any write; <method>OcuPilot.Kernel.State.Agent.ResolveFor</method>
/// answers it while it names an enabled definition and the default otherwise, for that user alone; it
/// moves no default marker and writes no audit event; the context answer, the restraint footer and the
/// Guardrails read name the definition in force; a conversation replays only the entries that ran with
/// the turn's own definition; and a proposal is stamped with the turn's definition, which the restraint
/// judges: a picked read/write definition over a read-only default mints and confirms, and enforced
/// read-only, a per-user hold and the kill switch still bind it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reading <code>1</code> (the
/// proposal legs use that probe's table). The instance's own definitions are set aside for the class and
/// put back after it, and every row this class writes -- definitions, picks, holds, switches, proposals,
/// conversations -- is removed after each test.</p>
Class OcuPilot.Test.AgentPick Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The user whose pick the state-level legs drive, and a second user the pick must not reach. Weak
/// references (AD-37): the instance holds no principal of these names.</p>
Parameter PICKUSER = "OcuPilotProbePickUser";

Parameter OTHERUSER = "OcuPilotProbePickOther";

/// <p>The second definition's endpoint, on another host than the first's.</p>
Parameter SECONDURL = "https://api.example.test/v1/messages";

Parameter TOOLNAME = "explorer.sqlquery.run";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NAMESPACE = "USER";

/// <p>The two probe definitions' ids: A is the default, B is enabled and read/write.</p>
Property PreparedA As %String;

Property PreparedB As %String;

Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedA = ""
    Set ..PreparedB = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentPick builds probe SQL objects and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Make")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions())
}

/// <p>Two enabled, verified definitions -- A the default, B on another host -- no pick, no hold and no
/// switch, and the stored governance policy cleared.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Do ..ForgetPicks()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "PickA", 1, 1, .tRowA)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedA = tRowA.%Id()
    Set tRowA = ""
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "PickB", 1, 1, .tRowB)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedB = tRowB.%Id()
    Set tRowB = ""
    Set tSC = ##class(OcuPilot.Test.TurnWireFixture).SetEndpoint(..PreparedB, ..#SECONDURL)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedA)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "the switches and holds are removed")
    Do ..ForgetPicks()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions), "the probe definitions are removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    Do ..PutBack()
    Quit $$$OK
}

/// <p>Remove every pick the test could have written: the two probe users' and the HTTP test account's.</p>
ClassMethod ForgetPicks()
{
    For tUser = ..#PICKUSER, ..#OTHERUSER, ##class(OcuPilot.Test.Http).GetTestUsername() {
        Do ##class(OcuPilot.Kernel.State.Pref).GuardedRemove(tUser, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL, ##class(OcuPilot.Kernel.State.Pref).#SHELLAGENTDEFINITION)
    }
}

/// <p>The probe table as the probe made it.</p>
ClassMethod PutBack()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuProbe196.Granted SET Num = CAST(SUBSTRING(Name, 2) AS INTEGER)")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Store <var>pUser</var>'s pick through the store, as the route does after its checks.</p>
ClassMethod Pick(pUser As %String, pId As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL, ##class(OcuPilot.Kernel.State.Pref).#SHELLAGENTDEFINITION, pId)
}

/// <p>The definition in force for <var>pUser</var>.</p>
ClassMethod InForce(pUser As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Agent).ResolveFor(pUser, .tId)
    Quit tId
}

/// <p>One request over the wire as the test account: the HTTP status and the parsed answer.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer)
{
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, "/api/ocupilot" _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"))
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
}

/// <p>The value of the <code>agentDefinition</code> member of a preferences answer's <code>shell</code> list,
/// or <code>""</code> when it holds none.</p>
ClassMethod StoredPick(pAnswer) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("shell") '= "array") Quit ""
    Set tIterator = pAnswer.shell.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.name = ##class(OcuPilot.Kernel.State.Pref).#SHELLAGENTDEFINITION Quit
    }
    Quit $Select($IsObject($Get(tEntry)) && (tEntry.name = ##class(OcuPilot.Kernel.State.Pref).#SHELLAGENTDEFINITION): tEntry.value, 1: "")
}

/// <p>The rows OcuPilot's own audit source wrote since <var>pSince</var>, or <code>-1</code>.</p>
ClassMethod OwnAuditRows(pSince As %String) As %Integer
{
    Set tRows = -1
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ?", pSince, tSource)
        If tRS.%SQLCODE >= 0 {
            Set tRows = 0
            While tRS.%Next() {
                Set tRows = tRows + 1
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRows
}

/// <p>AC2, AC3: a pick resolves while it names an enabled definition and reads as the default when
/// that definition is disabled or deleted, applying again once re-enabled; another user's definition in
/// force, and the default marker, are unchanged by it.</p>
/// <p>Mutation (Rule 19): skip <code>GuardedIsEnabled</code> in
/// <method>OcuPilot.Kernel.State.Agent.ResolveFor</method> -- the disabled and deleted legs answer the
/// pick and this goes red; add <code>SetDefaultGuarded</code> to the pick's write in
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the marker leg of
/// <method>TestAPickIsValidatedStoredAndMovesNothing</method> goes red.</p>
Method TestAPickResolvesOnlyWhileItNamesAnEnabledDefinition()
{
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedA, "with no pick the default is in force")
    Do $$$AssertStatusOK(..Pick(..#PICKUSER, ..PreparedB), "a pick of B is stored")
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedB, "B is in force for that user")
    Do $$$AssertEquals(..InForce(..#OTHERUSER), ..PreparedA, "while another user keeps the default")
    Do ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefault)
    Do $$$AssertEquals(tDefault, ..PreparedA, "and the default marker has not moved")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedB, 0, 1), "B is disabled")
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedA, "the stale pick reads as the default")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedB, 1, 1), "B is enabled again")
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedB, "the pick applies again")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(..PreparedB), "B is deleted")
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedA, "a pick of a deleted definition reads as the default")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedA, 0, 1), "and with every definition disabled")
    Do $$$AssertEquals(..InForce(..#PICKUSER), "", "none is in force, the configuration-empty state")
    Do $$$AssertStatusOK(..Pick(..#PICKUSER, "not-an-id"), "a stored value that is no id")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedA, 1, 1), "is read as no pick once a definition is enabled again")
    Do $$$AssertEquals(..InForce(..#PICKUSER), ..PreparedA, "so the default is in force")
}

/// <p>AC1, AC2: a pick that names a disabled or absent definition, or no id at all, is refused 422
/// <code>PREFERENCES.CHOICE</code> on <code>value</code> before any write; a pick of an enabled
/// definition is stored, listed by the read, and moves neither the Definitions list's Default column nor
/// an audit row; the context answer names the definition in force and its host, the default's without a
/// pick.</p>
/// <p>Mutation (Rule 19): drop the pick's choice check from
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the refusal legs store the value and this
/// goes red.</p>
Method TestAPickIsValidatedStoredAndMovesNothing()
{
    Set tChoice = ##class(OcuPilot.Api.Error).#PREFERENCESCHOICE
    Do ..Call("GET", "/agent/context", "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.definition.id _ " " _ tContext.endpointHost, 1: tStatus), ..PreparedA _ " api.anthropic.com", "without a pick the context names the default and its host")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedB, 0, 1), "B is disabled")
    For tValue = ..PreparedB, "999999999", "B", "0", "1.5" {
        Do ..Call("POST", "/account/preferences", {"kind": "shell", "action": "set", "name": "agentDefinition", "value": (tValue)}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 " _ tChoice, "a pick of '" _ tValue _ "' is refused")
    }
    Do ..Call("GET", "/account/preferences", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(..StoredPick(tAnswer), "", "and nothing was stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedB, 1, 1), "B is enabled")

    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Do ..Call("POST", "/account/preferences", {"kind": "shell", "action": "set", "name": "agentDefinition", "value": (..PreparedB)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..StoredPick(tAnswer), "200 " _ ..PreparedB, "a pick of B is stored and listed")
    Do ..Call("GET", "/agent/context", "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.definition.id _ " " _ tContext.definition.name _ " " _ tContext.endpointHost, 1: tStatus), ..PreparedB _ " " _ ..#PROBEPREFIX _ "PickB api.example.test", "the context names B, its name and its host")
    Do ..Call("GET", "/agent/definitions", "", .tStatus, .tList)
    Set tDefaults = ""
    If $IsObject(tList) {
        Set tIterator = tList.definitions.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.name [ ..#PROBEPREFIX Set tDefaults = tDefaults _ " " _ tRow.id _ "=" _ tRow.default
        }
    }
    Do $$$AssertEquals($ZStrip(tDefaults, "<>W"), ..PreparedA _ "=1 " _ ..PreparedB _ "=0", "the Definitions list's Default column is unchanged")
    Do $$$AssertEquals(..OwnAuditRows(tSince), 0, "and the pick wrote no audit event")
    Do ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefault)
    Do $$$AssertEquals(tDefault, ..PreparedA, "nor moved the default marker")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedB, 0, 1), "disabling B")
    Do ..Call("GET", "/agent/context", "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.definition.id, 1: tStatus), ..PreparedA, "returns the context to the default")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedA, 0, 1), "and with none enabled")
    Do ..Call("GET", "/agent/context", "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.%GetTypeOf("definition") _ " " _ tContext.provider, 1: tStatus), "null ", "the context names no definition")
}

/// <p>AC4, AD-30: the footer line, the restraint answer and Guardrails read the definition in force for
/// the caller. With a read-only default and a picked read/write definition the picker's user is not
/// blocked and another user is.</p>
/// <p>Mutation (Rule 19): resolve <code>ResolveDefault</code> in <method>OcuPilot.Kernel.Restraint.Resolved</method>
/// -- the picker's user is blocked and this goes red.</p>
Method TestTheFooterAndGuardrailsReadThePick()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedA, 1), "the default is read-only")
    Do $$$AssertStatusOK(..Pick(..#PICKUSER, ..PreparedB), "B, which is read/write, is picked")
    Set tDefinitionCode = ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Restraint).Resolved(..#PICKUSER, .tPicked), "the picker's verdict reads")
    Do $$$AssertEquals(tPicked("blocked") _ " " _ tPicked("code") _ " " _ tPicked("footerKey"), "0  statusReadOnlyOff", "it blocks nothing and the footer reads off")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Restraint).Resolved(..#OTHERUSER, .tOther), "another user's verdict reads")
    Do $$$AssertEquals(tOther("blocked") _ " " _ tOther("code") _ " " _ tOther("footerKey"), "1 " _ tDefinitionCode _ " statusReadOnlyByDefinition", "and is blocked by the read-only default")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Shell.Guardrails).Verdict(..#PICKUSER, .tGuard), "Guardrails reads the same for the picker")
    Do $$$AssertEquals(tGuard("blocked") _ " " _ tGuard("footerKey"), "0 statusReadOnlyOff", "the pick")
}

/// <p>AC5: a conversation replays only the entries that ran with the turn's own definition, and an entry
/// that recorded none still replays.</p>
/// <p>Mutation (Rule 19): remove the definition filter from
/// <method>OcuPilot.Kernel.State.Convo.HistoryMessages</method> -- the entry of the other definition is
/// replayed and this goes red.</p>
Method TestAConversationReplaysOnlyItsOwnDefinitionsEntries()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..#PICKUSER, 5, .tStatus, .tConflict)
    Do $$$AssertStatusOK(tStatus, "a conversation is created")
    If '$IsObject(tConvo) Quit
    Set tLimits = ..#LIMITS
    For tCase = $ListBuild("under A", ..PreparedA), $ListBuild("under B", ..PreparedB), $ListBuild("under none", "") {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, $List(tCase, 1), "completed", "reply " _ $List(tCase, 1), "", 0, [], 0, tLimits, "", "", "", $List(tCase, 2), ""), "an entry " _ $List(tCase, 1) _ " is appended")
    }
    For tCase = $ListBuild(..PreparedA, "under A|reply under A|under none|reply under none"), $ListBuild(..PreparedB, "under B|reply under B|under none|reply under none"), $ListBuild("", "under A|reply under A|under B|reply under B|under none|reply under none") {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).HistoryMessages(tConvo, 100000, .tMessages, $List(tCase, 1)), "the history reads for '" _ $List(tCase, 1) _ "'")
        Set tText = ""
        Set tIterator = tMessages.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMessage) {
            Set tText = tText _ $Select(tText = "": "", 1: "|") _ tMessage.content
        }
        Do $$$AssertEquals(tText, $List(tCase, 2), "definition '" _ $List(tCase, 1) _ "' replays its own entries and the unrecorded one")
    }
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tConvo.ConvKey)
    Set tConvo = ""
}

/// <p>AC4: a proposal is stamped with the definition its turn was started with, which the restraint
/// judges. A read-only default with a picked read/write definition mints and confirms for the picked
/// one, and is blocked for the default; enforced read-only, a per-user hold and the kill switch block the
/// picked definition as they block the default.</p>
/// <p>Mutation (Rule 19): stamp <code>ResolveDefault</code> in
/// <method>OcuPilot.Kernel.Proposal.Mint.DefinitionInForce</method> -- the stamp leg goes red. The
/// restraint legs pin that a picked id changes no restraint source; they hold on the dispatcher's own
/// contract, and only the stamp leg is load-bearing for the pick.</p>
Method TestAPickedDefinitionIsStampedAndStillRestrained()
{
    Set tText = "UPDATE OcuProbe196.Granted SET Num = Num + 1 WHERE Name = 'n1'"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedA, 1), "the default is read-only")
    Kill tSettings
    Set tSettings(..#TOOLNAME) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the run's key is enabled")

    Do ..AnswerFor(tText, ..PreparedA, .tDefaultContent, .tDefaultError, .tDefaultTurn)
    Do $$$AssertEquals(tDefaultError _ " " _ $Select($IsObject(tDefaultContent): tDefaultContent.%Get("code"), 1: ""), "1 " _ ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION, "the read-only default blocks the write")
    Do ..AnswerFor(tText, ..PreparedB, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the picked read/write definition mints it: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerTransfer).Stored(tContent.proposalId, "definitionId"), ..PreparedB, "stamped with the picked definition")
    Set tSC = ##class(OcuPilot.Test.SqlAgentWrite).ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "and the confirm is judged by it: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("output")): tResult.output.outcome, 1: ""), "done", "so it runs")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is turned on")
    Do ..AnswerFor(tText, ..PreparedB, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError _ " " _ $Select($IsObject(tContent): tContent.%Get("code"), 1: ""), "1 " _ ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED, "it blocks the picked definition too")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0), "and is turned off")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold($Username, "held for this test", .tHoldId), "the user is held")
    Do ..AnswerFor(tText, ..PreparedB, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError _ " " _ $Select($IsObject(tContent): tContent.%Get("code"), 1: ""), "1 " _ ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER, "a per-user hold blocks it")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "the hold is removed")
    Set tPref = "OcuPilot.Kernel.State.Pref"
    Do $$$AssertStatusOK($ClassMethod(tPref, "GuardedSetValue", $Username, $Parameter(tPref, "KINDRESTRAINT"), $Parameter(tPref, "RESTRAINTREADONLY"), 1), "the user's own read-only choice is turned on")
    Do ..AnswerFor(tText, ..PreparedB, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError _ " " _ $Select($IsObject(tContent): tContent.%Get("code"), 1: ""), "1 " _ ##class(OcuPilot.Api.Error).#AGENTREADONLYUSER, "it blocks the picked definition too")
    Do $$$AssertStatusOK($ClassMethod(tPref, "GuardedRemove", $Username, $Parameter(tPref, "KINDRESTRAINT"), $Parameter(tPref, "RESTRAINTREADONLY")), "and is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "off for this test", 0), "the kill switch is turned on")
    Do ..AnswerFor(tText, ..PreparedB, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError _ " " _ $Select($IsObject(tContent): tContent.%Get("code"), 1: ""), "1 " _ ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "the kill switch blocks it")
}

/// <p>The dispatcher's answer to the agent's call of the run for <var>pText</var> under definition
/// <var>pDefinitionId</var>, on a seeded turn that carries that definition: <var>pContent</var> is the
/// answer parsed and <var>pIsError</var> its error flag.</p>
ClassMethod AnswerFor(pText As %String, pDefinitionId As %String, Output pContent, Output pIsError As %Boolean, Output pTurn As %String) As %Status
{
    Set pContent = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tUpdate = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET DefinitionId = ? WHERE %EXACT(TurnKey) = ?", pDefinitionId, pTurn)
    If tUpdate.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the probe turn's definition could not be set: SQLCODE=" _ tUpdate.%SQLCODE)
    Set tUse = {"type": "tool_use", "id": "toolu_pick", "input": {"Target": "sql", "parameters": [], "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.input.%Set("statement", pText, "string")
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, pDefinitionId, [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set pIsError = ''tResults.%Get(0).%Get("is_error")
    Try { Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tResults.%Get(0).%Get("content")) } Catch { Set pContent = tResults.%Get(0).%Get("content") }
    Quit $$$OK
}

}
