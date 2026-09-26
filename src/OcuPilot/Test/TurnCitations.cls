/// <p>A turn's citations (Story 11.4, AD-11, AD-13, AD-37): which returned rows become candidates,
/// which backticked spans of the reply cite them, and that a finished turn's poll and its restored
/// conversation entry both carry them.</p>
/// <p>The candidate and span legs run on synthetic read content. The turn leg runs the real loop in
/// process through <class>OcuPilot.Test.TurnLoopProbe</class> over
/// <class>OcuPilot.Test.ProviderStub</class>'s scripted answers, as the suite's own account, which
/// must hold <code>%All</code> for the in-process Users and web-application reads. <b>Live-safe</b>:
/// it spawns nothing and opens no socket; it writes one probe definition, one turn and one
/// conversation in OcuPilot's own database and removes them after the method.</p>
Class OcuPilot.Test.TurnCitations Extends %UnitTest.TestCase
{

Parameter LOOP = "OcuPilot.Test.TurnLoopProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter STUB = "OcuPilot.Test.ProviderStub";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

Parameter USERS = "OcuPilot.Screen.Descriptor.UserList";

/// <p>Every turn key a method created, so teardown removes exactly those.</p>
Property PreparedKeys [ MultiDimensional ];

/// <p>The conversation a method created, or <code>""</code>.</p>
Property PreparedConvKey As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Kill ..PreparedKeys
    Set ..PreparedConvKey = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do $ClassMethod(..#LOOP, "Reset")
    Kill ..PreparedKeys
    Set ..PreparedConvKey = ""
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#LOOP, "Reset")
    Set tKey = ""
    For {
        Set tKey = $Order(..PreparedKeys(tKey))
        If tKey = "" Quit
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey), "turn " _ tKey _ " is removed")
    }
    If ..PreparedConvKey '= "" Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedDelete(..PreparedConvKey), "the conversation is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner($Username), "", "no turn slot is left held")
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

/// <p>A read result whose rows carry <var>pField</var> with each of <var>pIds</var>.</p>
ClassMethod Content(pField As %String, pIds As %List) As %String
{
    Set tRows = []
    For tI = 1:1:$ListLength(pIds) {
        Set tRow = {}
        Do tRow.%Set(pField, $List(pIds, tI), "string")
        Do tRows.%Push(tRow)
    }
    Set tPayload = {}
    Do tPayload.%Set("rows", tRows)
    Quit tPayload.%ToJSON()
}

/// <p>The candidates <var>pDescriptor</var>'s rows of <var>pField</var> carrying <var>pIds</var> yield.</p>
ClassMethod CandidatesOf(pDescriptor As %String, pField As %String, pIds As %List) As %DynamicArray
{
    Set tInto = []
    Do ##class(OcuPilot.Kernel.Agent.Citations).Candidates(pDescriptor, ..Content(pField, pIds), tInto)
    Quit tInto
}

/// <p>Binding: a selectable screen's returned rows are candidates carrying the AD-13 triple and the
/// route; a parent-scoped screen, a composite of two parts, and an id that is empty, too long or
/// cut by the field bound yield none; a one-part composite reads its part.</p>
/// <p>Mutation: drop the <code>ParentScope</code> refusal in <method>OcuPilot.Screen.Tool.Registry.CitationSource</method>
/// -> the parent-scoped assertion goes red.</p>
Method TestCandidatesComeOnlyFromASelectableScreensRows()
{
    Set tLong = ""
    For tI = 1:1:257 Set tLong = tLong _ "a"
    Set tUsers = ..CandidatesOf(..#USERS, "Name", $ListBuild("_SYSTEM", "", tLong, "Admi" _ $Char(8230), "Admin"))
    Do $$$AssertEquals(tUsers.%ToJSON(), "[{""type"":""user"",""scope"":""instance"",""id"":""_SYSTEM"",""route"":""permissions/users""},{""type"":""user"",""scope"":""instance"",""id"":""Admin"",""route"":""permissions/users""}]", "the Users rows are candidates, and an empty, long or cut id is skipped")
    Do $$$AssertEquals(..CandidatesOf("OcuPilot.Screen.Descriptor.WalletSecretList", "Name", $ListBuild("probe")).%Size(), 0, "a parent-scoped screen yields none")
    Do $$$AssertEquals(..CandidatesOf("OcuPilot.Screen.Descriptor.TaskUpcomingList", "Id", $ListBuild("7")).%Size(), 0, "a composite of two parts yields none")
    Set tTasks = ..CandidatesOf("OcuPilot.Screen.Descriptor.TaskScheduleList", "Id", $ListBuild("7"))
    Do $$$AssertEquals(tTasks.%Size() _ "|" _ tTasks.%Get(0).%Get("type") _ "|" _ tTasks.%Get(0).%Get("id"), "1|task|7", "a one-part composite reads its part")
    Set tInto = []
    Do ##class(OcuPilot.Kernel.Agent.Citations).Candidates(..#USERS, "{""code"":""TOOL.ARGUMENTS""}", tInto)
    Do $$$AssertEquals(tInto.%Size(), 0, "content with no rows yields none")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tRest = ..CandidatesOf("OcuPilot.Screen.Descriptor.RestApiList", "Name", $ListBuild("/api/probe"))
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals(tRest.%Size() _ "|" _ $Select(tRest.%Size() > 0: tRest.%Get(0).%Get("scope") _ "|" _ tRest.%Get(0).%Get("route"), 1: ""), "1|USER|web-applications/rest-apis", "a namespace-scoped screen's candidate carries the resolved namespace as its scope")
}

/// <p>Matching: only a span equal to a returned id cites, exactly or in the type's canonical
/// spelling (exactly, for a singleton type), in order of first mention, once per row, never from a
/// fenced block, and at most 20.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Citations.Cite</method> accepts any backticked span
/// -> the not-returned assertion goes red. Matching a singleton type by its normalized id -> the
/// singleton assertion goes red.</p>
Method TestOnlyASpanNamingAReturnedRowCites()
{
    Set tCandidates = ..CandidatesOf(..#USERS, "Name", $ListBuild("_SYSTEM", "Admin", "Fenced"))
    Set tCited = ##class(OcuPilot.Kernel.Agent.Citations).Cite("`Admin` and `NotARow` and ` _SYSTEM ` and `admin` again" _ $Char(10) _ "```" _ $Char(10) _ "`Fenced`" _ $Char(10) _ "```", tCandidates)
    Set tLabels = ""
    For tI = 0:1:tCited.%Size() - 1 Set tLabels = tLabels _ tCited.%Get(tI).%Get("label") _ "|"
    Do $$$AssertEquals(tLabels, "Admin|_SYSTEM|", "a span that names no returned row does not cite, a repeat cites once, in order of first mention")
    Set tFences = ##class(OcuPilot.Kernel.Agent.Citations).Cite("``Admin`` first" _ $Char(10) _ "~~~" _ $Char(10) _ "`_SYSTEM`" _ $Char(10) _ "~~~", tCandidates)
    Do $$$AssertEquals(tFences.%Size() _ "|" _ $Select(tFences.%Size() > 0: tFences.%Get(0).%Get("label"), 1: ""), "1|Admin", "a double-backtick span cites, and a tilde fence is a fenced block")
    Do $$$AssertEquals(tCited.%Get(1).%ToJSON(), "{""type"":""user"",""scope"":""instance"",""id"":""_SYSTEM"",""route"":""permissions/users"",""label"":""_SYSTEM""}", "with the wire shape")

    Set tApps = []
    Do ##class(OcuPilot.Kernel.Agent.Citations).Candidates("OcuPilot.Screen.Descriptor.WebAppList", ..Content("Name", $ListBuild("/csp/user")), tApps)
    Set tCanonical = ##class(OcuPilot.Kernel.Agent.Citations).Cite("See `/CSP/USER/`.", tApps)
    Do $$$AssertEquals(tCanonical.%Size() _ "|" _ tCanonical.%Get(0).%Get("id") _ "|" _ tCanonical.%Get(0).%Get("label"), "1|/csp/user|/CSP/USER/", "a canonical spelling cites the returned id under the reply's label")

    Set tMixed = ..CandidatesOf("OcuPilot.Screen.Descriptor.OAuthServerTab", "IssuerEndpoint", $ListBuild("https://probe/issuer"))
    Do tMixed.%Push(tCandidates.%Get(0))
    Set tSingleton = ##class(OcuPilot.Kernel.Agent.Citations).Cite("`_SYSTEM` and `%All` and `https://probe/issuer`", tMixed)
    Set tLabels = ""
    For tI = 0:1:tSingleton.%Size() - 1 Set tLabels = tLabels _ tSingleton.%Get(tI).%Get("type") _ ":" _ tSingleton.%Get(tI).%Get("label") _ "|"
    Do $$$AssertEquals(tLabels, "user:_SYSTEM|oauth2-server:https://probe/issuer|", "a singleton type's row is cited by its own id only, never by every span")

    Set tIds = ""
    Set tReply = ""
    For tI = 1:1:25 Set tIds = tIds _ $ListBuild("Probe" _ tI), tReply = tReply _ "`Probe" _ tI _ "` "
    Set tMany = ##class(OcuPilot.Kernel.Agent.Citations).Cite(tReply, ..CandidatesOf(..#USERS, "Name", tIds))
    Do $$$AssertEquals(tMany.%Size() _ "|" _ tMany.%Get(19).%Get("id"), "20|Probe20", "at most twenty, the first twenty mentioned")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Agent.Citations).Cite("`_SYSTEM`", []).%ToJSON(), "[]", "with no read there is nothing to cite")
}

/// <p>A turn that read the Users screen, called a web-application read that answered an error,
/// and replied naming <code>_SYSTEM</code>, <code>/csp/user</code> and <code>NotARow</code> cites
/// <code>_SYSTEM</code> alone, the one row a read returned; the finished turn's poll and its
/// restored entry both carry that one citation.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Run</method> leaves <code>citations</code> empty
/// -> every assertion after the outcome's goes red.</p>
Method TestAFinishedTurnCarriesItsCitationsOnThePollAndTheRestore()
{
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Set tCalls = [{"id": "toolu_1", "name": "permissions_users_read", "input": {}}, {"id": "toolu_2", "name": "webapp_list_read", "input": {"nosuch": 1}}]
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ##class(OcuPilot.Test.TurnTools).Reply("", tCalls))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ##class(OcuPilot.Test.TurnTools).Reply("`_SYSTEM` holds %All; `/csp/user` and `NotARow` do not."))
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnCitations"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tRow.MaxIterationsPerTurn = 10
    Set tRow.Enabled = 1
    Set tRow.ConnectionVerified = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a probe definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Set tLimits = "OcuPilot.Kernel.Agent.Limits"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, tId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "the turn is reserved")
    If $Get(tKey) = "" Quit
    Set ..PreparedKeys(tKey) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, $Username, tLimits, .tBegun, .tStarted), "the turn begins")
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "who holds %All?", 0, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .tOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tExpected = "[{""type"":""user"",""scope"":""instance"",""id"":""_SYSTEM"",""route"":""permissions/users"",""label"":""_SYSTEM""}]"
    Do $$$AssertEquals($Get(tOutcome("citations")), tExpected, "only the row a read returned is cited; the spans no read returned are not")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, tOutcome("state"), tOutcome("code"), tOutcome("limit"), tOutcome("reply"), tOutcome("errorSeq"), tLimits, $Get(tOutcome("citations"))), "the turn is finished")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView), "the poll reads")
    Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.%Get("citations").%ToJSON(), 1: ""), tExpected, "the poll carries the citation")

    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", $Username, 5, .tConvoSC, .tConflict)
    Do $$$AssertStatusOK(tConvoSC, "a conversation is created")
    If '$IsObject(tConvo) Quit
    Set ..PreparedConvKey = tConvo.ConvKey
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "older", "completed", "an older reply", "", 0, [], 0, tLimits), "an entry written without citations is appended")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "who holds %All?", "completed", tOutcome("reply"), "", 0, [], 0, tLimits, tKey, $Get(tOutcome("citations"))), "the turn's entry is appended")
    Set tConvo = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedView(..PreparedConvKey, $Username, .tFound, .tRestored), "the conversation reads")
    Do $$$AssertEquals(tRestored.turns.%Get(0).%Get("citations").%ToJSON(), "[]", "an entry with none restores an empty array")
    Do $$$AssertEquals(tRestored.turns.%Get(1).%Get("citations").%ToJSON(), tExpected, "and the restored entry carries the citation")
}

}
