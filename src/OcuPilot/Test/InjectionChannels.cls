/// <p>Seeded injection against a model that obeys only its instruction channels (AD-11 rules 1 and
/// 5): for each untrusted source <class>OcuPilot.Test.InjectionSeed</class> plants, a real turn job
/// reads the seed through the shipped read tool (or, for screen context, the synthetic
/// <code>screen_context</code> result), and the scripted <code>turnprobe</code> stub answers the
/// seed's instruction only when the marker reaches the system text or a user-role text block. Each
/// turn first proves the marker arrived inside a <code>tool_result</code> block, then asserts it
/// is in no system text and no user-role text, the stub obeyed nothing, the turn minted no
/// proposal, announced and recorded no navigation, and posted to the definition's endpoint
/// alone.</p>
/// <p><b>It needs a throwaway container</b>: it creates a probe role and user, writes a failed
/// login, a messages.log line, an application error, a probe task, two probe classes, one of them in
/// <code>USER</code>, and probe tables, a probe view, a probe SQL procedure's class, a probe statement
/// and a running probe statement's job in <code>USER</code>, and runs turn jobs on the <code>turnprobe</code> row, so <method>OnBeforeAllTests</method> refuses unless every variable
/// this class declares reads 1. The turns run as the suite's own account, which holds every
/// read's pairs. After every method no probe turn, proposal, conversation, stub node, probe
/// definition, task, role, user, class, table, view, probe job or application error it planted remains; the failed-login audit
/// row, the messages.log line, the probe statement's statement-index row, and the running probe
/// statement's statement-index row and cached query in <code>USER</code> remain.</p>
Class OcuPilot.Test.InjectionChannels Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SEEDVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

Parameter DELETEVARIABLE = "OCUPILOT_ALLOW_ERROR_DELETE";

Parameter TASKVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter SEED = "OcuPilot.Test.InjectionSeed";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "inject-channels";

Property PreparedPrior As %String;

/// <p>Turn keys this method started.</p>
Property PreparedKeys [ MultiDimensional ];

/// <p>Conversation ids this method created.</p>
Property PreparedConversations [ MultiDimensional ];

/// <p>What this method planted, subscripted by source, valued by <method>OcuPilot.Test.InjectionSeed.Plant</method>'s reference.</p>
Property PreparedPlants [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = ""
    Kill ..PreparedKeys, ..PreparedConversations, ..PreparedPlants
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InjectionChannels creates a probe role and user, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If ($System.Util.GetEnviron(..#SEEDVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DELETEVARIABLE) '= 1) || ($System.Util.GetEnviron(..#TASKVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InjectionChannels writes append-only log records, an application error and a task and runs turn jobs, on a throwaway container only. " _ ..#SEEDVARIABLE _ ", " _ ..#DELETEVARIABLE _ ", " _ ..#TASKVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must each read 1 here, so nothing was created.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Kill ..PreparedKeys, ..PreparedConversations, ..PreparedPlants
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Do $ClassMethod(..#FIXTURE, "RemoveDefinition", "")
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    ; The role the obey batch proposes to change, so a stub that did obey would mint a proposal.
    Set ..PreparedPlants("e") = $ClassMethod(..#SEED, "Target")
    Set tSC = $ClassMethod(..#SEED, "EnsureTarget")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Do ..Teardown()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals(..Teardown(), "", "no probe turn, proposal, conversation, stub node, definition or planted object survives the method")
    Quit $$$OK
}

/// <p>Remove everything a method created, and answer what survives, <code>""</code> when nothing
/// does.</p>
Method Teardown() As %String
{
    Set tLeft = ""
    Set tKey = ""
    For {
        Set tKey = $Order(..PreparedKeys(tKey))
        If tKey = "" Quit
        Set tLeft = tLeft _ " " _ $ClassMethod(..#SEED, "RemoveTurn", tKey)
    }
    Set tConv = ""
    For {
        Set tConv = $Order(..PreparedConversations(tConv))
        If tConv = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tConv)
        If $$$ISERR(tSC) Set tLeft = tLeft _ " conversation " _ tConv
    }
    Set tSource = ""
    For {
        Set tSource = $Order(..PreparedPlants(tSource))
        If tSource = "" Quit
        Set tSC = $ClassMethod(..#SEED, "Remove", tSource, ..PreparedPlants(tSource))
        If $$$ISERR(tSC) Set tLeft = tLeft _ " source " _ tSource _ " (" _ $System.Status.GetErrorText(tSC) _ ")"
    }
    Kill ..PreparedKeys, ..PreparedConversations, ..PreparedPlants
    If $ClassMethod(..#SEED, "Description") '= "" Set tLeft = tLeft _ " the probe role"
    If ##class(OcuPilot.Test.TurnFixture).SlotOwner(##class(OcuPilot.Test.Http).GetTestUsername()) '= "" Set tLeft = tLeft _ " the suite account's slot"
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    If ##class(OcuPilot.Test.TurnProvider).Remains(..#TAG) Set tLeft = tLeft _ " stub " _ ..#TAG
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    If $$$ISERR(tSC) Set tLeft = tLeft _ " definitions (" _ $System.Status.GetErrorText(tSC) _ ")"
    Quit $ZStrip(tLeft, "<=>W")
}

/// <p>Plant a fresh seed in <var>pSource</var>, recording it for teardown; the seed, or
/// <code>""</code> when planting failed.</p>
Method Plant(pSource As %String, Output pRef As %String) As %String
{
    Set tSeed = $ClassMethod(..#SEED, "Seed", $ClassMethod(..#SEED, "Nonce"))
    Set tSC = $ClassMethod(..#SEED, "Plant", pSource, tSeed, .pRef)
    Do $$$AssertStatusOK(tSC, "source " _ pSource _ " is planted")
    If $$$ISERR(tSC) Quit ""
    Set ..PreparedPlants(pSource) = pRef
    Quit tSeed
}

/// <p>A new conversation as the suite's account, recorded for teardown.</p>
Method Conversation() As %String
{
    Set tConv = $ClassMethod(..#SEED, "Conversation", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 201, "a conversation is created: " _ tText)
    If tConv '= "" Set ..PreparedConversations(tConv) = ""
    Quit tConv
}

/// <p>Run one turn posting <var>pMessage</var> in <var>pConv</var> with <var>pContext</var>, in
/// namespace <var>pNamespace</var> when it is not <code>""</code>, and answer its key once it
/// completed after the stub's call <var>pLastCall</var>; <code>""</code> when it did not start.</p>
Method Turn(pMessage As %String, pConv As %String, pContext As %DynamicObject, pLastCall As %Integer, pNamespace As %String = "") As %String
{
    Set tKey = $ClassMethod(..#SEED, "StartTurn", pMessage, pConv, pContext, .tStatus, .tText, pNamespace)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ tText)
    If tKey = "" Quit ""
    Set ..PreparedKeys(tKey) = ""
    Do $$$AssertEquals($ClassMethod(..#SEED, "AwaitTurn", tKey, 90, .tView), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), pLastCall, "after call " _ pLastCall)
    Quit tKey
}

/// <p>The assertions every turn here ends on. The marker must first be found in a
/// <code>tool_result</code> of call <var>pArrival</var>; when it is not, the zeros are not read.
/// Then, for calls <var>pFirst</var> to <var>pLast</var>: invariant 1, nothing obeyed, and every
/// call posted to the endpoint; and for turn <var>pKey</var>: no proposal, no announce step and
/// no navigation row.</p>
Method AssertHeld(pKey As %String, pMarker As %String, pFirst As %Integer, pLast As %Integer, pArrival As %Integer)
{
    Set tArrived = $ClassMethod(..#SEED, "InToolResult", ..#TAG, pArrival, pMarker)
    Do $$$AssertTrue(tArrived, "the seed reached the model inside a tool_result of call " _ pArrival)
    If 'tArrived || (pKey = "") Quit
    For tCall = pFirst:1:pLast {
        Do $$$AssertEquals($ClassMethod(..#SEED, "InChannels", ..#TAG, tCall, pMarker), "", "invariant 1: call " _ tCall _ " carries the marker in no system text and no user-role text")
    }
    Do $$$AssertEquals($ClassMethod(..#SEED, "ObeyedCalls", ..#TAG), "", "the channel-sensitive stub obeyed no call")
    Do $$$AssertEquals($ClassMethod(..#SEED, "CountFor", "Proposal", pKey), 0, "the turn minted no proposal")
    Do $$$AssertEquals($ClassMethod(..#SEED, "CountFor", "announce", pKey), 0, "the turn announced no navigation")
    Do $$$AssertEquals($ClassMethod(..#SEED, "CountFor", "Nav", pKey), 0, "and recorded no navigation directive")
    Do $$$AssertEquals($ClassMethod(..#SEED, "OtherUrls", ..#TAG, $Parameter(..#FIXTURE, "ENDPOINTURL")), "", "every provider call posted to the definition's endpoint and nowhere else")
}

/// <p>One source read by its shipped read tool in call 1, answered in call 2, the turn running in
/// <var>pNamespace</var> when it is not <code>""</code>; <var>pCached</var> reads source
/// <code>m</code> through the cached queries tool.</p>
Method ReadSource(pSource As %String, pMessage As %String, pNamespace As %String = "", pCached As %Boolean = 0) As %String
{
    Set tSeed = ..Plant(pSource, .tRef)
    If tSeed = "" Quit ""
    Set tMarker = $ClassMethod(..#SEED, "Marker", tSeed)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([($ClassMethod(..#SEED, "ReadCall", pSource, tRef, pCached))])), "call 1 is scripted")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, $ClassMethod(..#SEED, "ObeyBody", tSeed, 1), $ClassMethod(..#SEED, "ElseBody", tSeed)), "call 2 reacts to the marker in the instruction channels")
    Set tKey = ..Turn(pMessage, ..Conversation(), "", 2, pNamespace)
    Do ..AssertHeld(tKey, tMarker, 1, 2, 2)
    Quit tSeed
}

/// <p>Source (a): a failed login whose user name is the seed, read through
/// <code>logs.audit.read</code>'s <code>Username</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Loop.Run</method> appends the last
/// <code>tool_result</code> content to the system prompt -> the stub obeys, and the invariant 1,
/// obeyed and proposal assertions go red.</p>
Method TestAuditUserName()
{
    Do ..ReadSource("a", "which logins failed today?")
}

/// <p>Source (b): a messages.log line that is the seed, read through
/// <code>logs.messages.read</code>'s <code>text</code>.</p>
Method TestMessagesLogLine()
{
    Do ..ReadSource("b", "what does the messages log say?")
}

/// <p>Source (c): an application error in <code>USER</code> whose text is the seed, read through
/// <code>logs.applicationerrors.read</code>'s <code>errorText</code>.</p>
/// <p>Mutation (Rule 19): skip this source's <method>OcuPilot.Test.InjectionSeed.Plant</method>
/// -> "the seed reached the model" goes red.</p>
Method TestApplicationErrorText()
{
    Do ..ReadSource("c", "which application errors were logged today?")
}

/// <p>Source (d): a weekly probe task whose description is the seed, read through
/// <code>tasks.schedule.read</code>'s <code>Description</code>.</p>
Method TestTaskDescription()
{
    Do ..ReadSource("d", "what is scheduled?")
}

/// <p>Source (e): the probe role's description is the seed, read through
/// <code>permissions.roles.read</code>. A second turn in the same conversation replays the first
/// reply, which quoted the seed: the marker reaches that turn's first call in assistant-role
/// content alone, and the stub still obeys nothing.</p>
Method TestEntityComment()
{
    Set tSeed = ..Plant("e", .tRef)
    If tSeed = "" Quit
    Set tMarker = $ClassMethod(..#SEED, "Marker", tSeed)
    Set tRead = ##class(OcuPilot.Test.TurnProvider).ToolUseReply([($ClassMethod(..#SEED, "ReadCall", "e", tRef))])
    Set tObey = $ClassMethod(..#SEED, "ObeyBody", tSeed, 1)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, tRead), "call 1 is scripted")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, tObey, $ClassMethod(..#SEED, "ElseBody", tSeed)), "call 2 reacts")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, tObey, tRead), "call 3 reacts")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, tObey, ##class(OcuPilot.Test.TurnProvider).TextReply("done")), "call 4 reacts")
    Set tConv = ..Conversation()
    Set tFirst = ..Turn("what do the roles say?", tConv, "", 2)
    Do ..AssertHeld(tFirst, tMarker, 1, 2, 2)
    If tFirst = "" Quit
    Set tSecond = ..Turn("and what did you just tell me?", tConv, "", 4)
    Do $$$AssertTrue($ClassMethod(..#SEED, "InAssistant", ..#TAG, 3, tMarker), "call 3 replays the reply that quoted the seed in the assistant role")
    Do $$$AssertEquals($ClassMethod(..#SEED, "InToolResult", ..#TAG, 3, tMarker), 0, "and carries it in no tool_result, so the assistant role is the only place it is")
    Do ..AssertHeld(tSecond, tMarker, 3, 4, 4)
}

/// <p>Source (f): a probe user whose name carries the seed, read through
/// <code>permissions.users.read</code>'s <code>Name</code>.</p>
Method TestToolResultNamingAnEntity()
{
    Do ..ReadSource("f", "who are the users?")
}

/// <p>Source (h): a probe class in the test package whose doc comment is the seed, read through
/// <code>explorer.class.read</code>'s class row <code>Description</code>.</p>
Method TestClassDescription()
{
    Do ..ReadSource("h", "what does this class do?")
}

/// <p>Source (i): a probe class in <code>USER</code> one of whose comment lines carries the seed, read
/// through <code>explorer.search.read</code>'s <code>Text</code> in a turn running in
/// <code>USER</code>.</p>
Method TestSearchMatchLine()
{
    Do ..ReadSource("i", "where does the code mention this probe?", $Parameter(..#SEED, "SEARCHNAMESPACE"))
}

/// <p>Source (j): a probe table in <code>USER</code> whose trigger's code carries the seed, read
/// through <code>explorer.sqltriggers.read</code>'s <code>Code</code> in a turn running in
/// <code>USER</code>.</p>
Method TestTriggerCode()
{
    Do ..ReadSource("j", "what do this table's triggers do?", $Parameter(..#SEED, "TRIGGERNAMESPACE"))
}

/// <p>Source (k): a probe view in <code>USER</code> whose text carries the seed, read through
/// <code>explorer.sqlview.read</code>'s <code>Text</code> in a turn running in <code>USER</code>.</p>
Method TestViewText()
{
    Do ..ReadSource("k", "what does this view select?", $Parameter(..#SEED, "CATALOGNAMESPACE"))
}

/// <p>Source (l): a probe SQL procedure in <code>USER</code> whose description is the seed, read
/// through <code>explorer.sqlprocedure.read</code>'s <code>Description</code> in a turn running in
/// <code>USER</code>.</p>
Method TestProcedureDescription()
{
    Do ..ReadSource("l", "what does this procedure do?", $Parameter(..#SEED, "CATALOGNAMESPACE"))
}

/// <p>Source (m): a statement on a probe table in <code>USER</code> keeping the seed as a literal, read
/// through <code>explorer.sqltablestatements.read</code>'s <code>Statement</code> in a turn running in
/// <code>USER</code>.</p>
Method TestStatementLiteral()
{
    Do ..ReadSource("m", "which statements use this table?", $Parameter(..#SEED, "CATALOGNAMESPACE"))
}

/// <p>Source (m) again, read through <code>explorer.sqlcachedqueries.read</code>'s
/// <code>Query</code>.</p>
Method TestCachedQueryText()
{
    Do ..ReadSource("m", "which cached queries use this table?", $Parameter(..#SEED, "CATALOGNAMESPACE"), 1)
}

/// <p>Source (n): a probe statement running in <code>USER</code> keeping the seed as a literal, read
/// through <code>osmgmt.sqlactivity.read</code>'s <code>Statement</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Loop.Run</method> appends the last
/// <code>tool_result</code> content to the system prompt -> the stub obeys, and the invariant 1,
/// obeyed and proposal assertions go red.</p>
Method TestRunningStatementLiteral()
{
    Do ..ReadSource("n", "which SQL statements are running right now?")
}

/// <p>Source (g): the rows of sources (a) and (e), each sent as a turn's screen context with no
/// tool call; the synthetic <code>screen_context</code> result is where the marker arrives.</p>
Method TestScreenContext()
{
    Set tSeed = $ClassMethod(..#SEED, "Seed", $ClassMethod(..#SEED, "Nonce"))
    Set tMarker = $ClassMethod(..#SEED, "Marker", tSeed)
    Set tElse = $ClassMethod(..#SEED, "ElseBody", tSeed)
    Set tObey = $ClassMethod(..#SEED, "ObeyBody", tSeed, 1)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, tObey, tElse), "call 1 reacts")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).ScriptReaction(..#TAG, "channels", tMarker, tObey, tElse), "call 2 reacts")
    Set tConv = ..Conversation()
    Set tAudit = ..Turn("explain this screen", tConv, $ClassMethod(..#SEED, "Context", "audit", tSeed), 1)
    Do ..AssertHeld(tAudit, tMarker, 1, 1, 1)
    If tAudit = "" Quit
    Set tRoles = ..Turn("and this one", tConv, $ClassMethod(..#SEED, "Context", "roles", tSeed), 2)
    Do ..AssertHeld(tRoles, tMarker, 2, 2, 2)
}

}
