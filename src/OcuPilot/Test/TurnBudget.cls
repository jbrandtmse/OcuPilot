/// <p>Story 18.39's request budget through the turn loop, in process (AD-24, AD-31): the Anthropic
/// adapter marks the last tool and the final message's last block <code>cache_control</code> on every
/// call of a turn over the same tool array, the turn row counts cached tokens as spend, a turn's
/// tool results share one budget that cuts and then refuses, and no message already sent is changed
/// by a later call -- each observed on the requests <class>OcuPilot.Test.ProviderStub</class>
/// recorded.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> over the counting fixture tools, as
/// <class>OcuPilot.Test.TurnTools</class> is. <b>Live-safe</b>: it spawns nothing and opens no
/// socket, and removes every probe definition and turn it wrote after each method.</p>
Class OcuPilot.Test.TurnBudget Extends OcuPilot.Test.TurnToolsCase
{

/// <p>The member name the Anthropic adapter marks a cache breakpoint with.</p>
Parameter MARK = "cache_control";

/// <p>The member's value, as JSON.</p>
Parameter EPHEMERAL = "{""type"":""ephemeral""}";

/// <p>The limits that make three replies of about 5,500 characters meet a 9,000-character turn
/// budget.</p>
Parameter BUDGETLIMITS = "OcuPilot.Test.TurnLimitsBudget";

/// <p>Rows and characters a row carries in the budget turn's tool calls: a result of about 5,500
/// characters, inside the 6,000-character reply budget and over what the turn budget leaves after it.</p>
Parameter BUDGETROWS = 33;

Parameter BUDGETWIDTH = 150;

/// <p><var>pBody</var>, a <method>OcuPilot.Test.TurnToolsCase.Reply</method> body, with the usage
/// figures it reports set.</p>
ClassMethod Used(pBody As %String, pInput As %Integer, pCreation As %Integer, pRead As %Integer) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody)
    Do tBody.usage.%Set("input_tokens", pInput, "number")
    Do tBody.usage.%Set("cache_creation_input_tokens", pCreation, "number")
    Do tBody.usage.%Set("cache_read_input_tokens", pRead, "number")
    Do tBody.usage.%Set("output_tokens", 3, "number")
    Quit tBody.%ToJSON()
}

/// <p>How many times <var>pText</var> carries the cache member.</p>
ClassMethod Marks(pText As %String) As %Integer
{
    Quit $Length(pText, ..#MARK) - 1
}

/// <p>The cache member <var>pBlock</var> carries, as JSON, or <code>(none)</code> -- read here so a
/// block without one fails its assertion rather than raising.</p>
ClassMethod MarkOf(pBlock As %RawString) As %String
{
    If '$IsObject(pBlock) || (pBlock.%GetTypeOf(..#MARK) '= "object") Quit "(none)"
    Quit pBlock.%Get(..#MARK).%ToJSON()
}

/// <p>The request the stub recorded on call <var>pCall</var>, parsed.</p>
ClassMethod Sent(pCall As %Integer) As %DynamicObject
{
    Quit ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", pCall))
}

/// <p>Message <var>pIndex</var> of <var>pMessages</var> as JSON with the cache member removed from
/// every block, so two sends of one message compare equal wherever the marker stood.</p>
ClassMethod Unmarked(pMessages As %DynamicArray, pIndex As %Integer) As %String
{
    Set tMessage = ##class(%DynamicAbstractObject).%FromJSON(pMessages.%Get(pIndex).%ToJSON())
    If tMessage.%GetTypeOf("content") = "array" {
        Set tBlocks = tMessage.content.%GetIterator()
        While tBlocks.%GetNext(.tAt, .tBlock) {
            If $IsObject(tBlock) Do tBlock.%Remove(..#MARK)
        }
    }
    Quit tMessage.%ToJSON()
}

/// <p>The first <code>tool_result</code> block of message <var>pMessage</var> of call
/// <var>pCall</var>, its content unframed.</p>
ClassMethod ResultOf(pCall As %Integer, pMessage As %Integer, Output pIsError As %Boolean) As %String
{
    Set tBlock = ..Sent(pCall).messages.%Get(pMessage).content.%Get(0)
    Set pIsError = +tBlock."is_error"
    Quit ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tBlock.content, .tWrapped)
}

/// <p>Prompt cache and cached spend -- a two-call turn on the shipped limits, no screen context,
/// each reply reporting cache figures: call 1 marks the last tool and nothing else, call 2 the last
/// tool and the final message's last block and nothing else, the tool array is the same text on both,
/// <code>system</code> stays a string, and the turn row's input tokens sum every input figure of
/// both replies.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.Anthropic.CallMessages</method> marks no tool, then
/// no message block -> this goes red on each marker count;
/// <method>OcuPilot.Kernel.Provider.Anthropic.MapResponse</method> leaves out
/// <code>cache_read_input_tokens</code> -> the input-token total goes red.</p>
Method TestTheCacheMarkersRideTheLastToolAndTheTailAndCachedTokensCountAsSpend()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $$$AssertEquals($Parameter("OcuPilot.Kernel.Agent.Limits", "TURNRESULTMAXLENGTH"), 262144, "the shipped turn budget is 262,144 characters")
    Do $$$AssertStatusOK($ClassMethod($ClassMethod(..#DISPATCH, "RegistryClass"), "ProviderTools", .tAdvertised), "the fixture registry advertises")
    Do $$$AssertTrue(+$Get(tAdvertised) > 1, "more than one tool, so the last is told from the rest")
    Set tCalls = [{"id": "toolu_1", "name": "probe_counter_read", "input": {"marker": "m1"}}]
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Used(..Reply("looking", tCalls), 10, 200, 0))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Used(..Reply("done"), 20, 0, 3000))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "after two provider calls")
    For tCall = 1, 2 {
        Set tText = $ClassMethod(..#STUB, "Recorded", "body", tCall)
        Set tSent = ..Sent(tCall)
        Set tTools = tSent.tools
        Set tLast = tTools.%Get(tTools.%Size() - 1)
        Do $$$AssertEquals(tTools.%Size(), +$Get(tAdvertised), "call " _ tCall _ " carries every advertised tool")
        Do $$$AssertEquals(tLast.name, tAdvertised(tAdvertised, "name"), "call " _ tCall _ ": the last tool is the registry's last")
        Do $$$AssertEquals(..MarkOf(tLast), ..#EPHEMERAL, "call " _ tCall _ ": the last tool carries the marker")
        Do $$$AssertEquals(..Marks(tTools.%ToJSON()), 1, "call " _ tCall _ ": and no other tool does")
        Do $$$AssertEquals(..Marks(tSent.messages.%ToJSON()), tCall - 1, "call " _ tCall _ ": messages carry " _ (tCall - 1) _ " marker(s)")
        Do $$$AssertEquals(..Marks(tText), tCall, "call " _ tCall _ ": " _ tCall _ " marker(s) in all")
        Do $$$AssertEquals(tSent.%GetTypeOf("system"), "string", "call " _ tCall _ ": system stays a string")
        Set tTail = tSent.messages.%Get(tSent.messages.%Size() - 1)
        If tCall = 1 Do $$$AssertEquals(tTail.%GetTypeOf("content"), "string", "call 1's only message is plain text, so there is no block to mark")
        If tCall = 2 {
            Do $$$AssertEquals(..MarkOf(tTail.content.%Get(tTail.content.%Size() - 1)), ..#EPHEMERAL, "call 2: the final message's last block carries the marker")
            Do $$$AssertEquals(..Marks(tSent.messages.%Get(1).%ToJSON()), 0, "call 2: the echoed assistant message does not")
        }
    }
    Do $$$AssertEquals(..Sent(1).tools.%ToJSON(), ..Sent(2).tools.%ToJSON(), "the tool array is the same text on both calls")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "InputTokens"), 3230, "the turn row's input tokens sum input, cache writes and cache reads of both calls")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "OutputTokens"), 6, "and its output tokens both calls' output")
}

/// <p>The first call of a turn that carries screen context ends in a user message of blocks, so it
/// marks the last tool and that message's last block, and nothing else.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.Anthropic.CallMessages</method> marks no message
/// block -> this goes red.</p>
Method TestTheFirstCallOfAContextTurnMarksItsTail()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Do ..RunTurn(.tOutcome, "", 0, 0, "{""route"":""logs/audit""}")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tSent = ..Sent(1)
    Set tTail = tSent.messages.%Get(tSent.messages.%Size() - 1)
    Do $$$AssertEquals(tTail.%GetTypeOf("content"), "array", "the final message is blocks")
    Do $$$AssertEquals(..MarkOf(tTail.content.%Get(tTail.content.%Size() - 1)), ..#EPHEMERAL, "its last block carries the marker")
    Do $$$AssertEquals(..Marks(tSent.messages.%ToJSON()), 1, "and it is the only marker in the messages")
    Do $$$AssertEquals(..Marks(tSent.tools.%ToJSON()), 1, "with one on the tools")
}

/// <p>Turn budget -- three replies of one counter result each, sized so reply 1 fits the reply
/// budget, reply 2 is cut by whole rows to what the turn has left, and reply 3 is refused
/// <code>TOOL.RESULTTOOLARGE</code> without the tool running; and every later call re-sends every
/// message of the call before it unchanged but for where the marker stood.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> ignores
/// <var>pTurnBudget</var> -> the cut and refusal go red;
/// <method>OcuPilot.Kernel.Agent.Sanitize.Results</method> re-run over every earlier user message
/// -> the unchanged-message leg goes red; <method>OcuPilot.Kernel.Agent.Loop.Run</method> seeds the
/// turn budget from <parameter>TOOLRESULTMAXLENGTH</parameter> -> the retained-length assertion goes
/// red.</p>
Method TestTheTurnBudgetCutsThenRefusesAndEarlierMessagesAreResentUnchanged()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", ..#BUDGETLIMITS)
    Do $$$AssertEquals($Parameter(..#BUDGETLIMITS, "TURNRESULTMAXLENGTH"), 9000, "the turn budget is 9,000 characters")
    Set tInput = {"rows": (..#BUDGETROWS), "width": (..#BUDGETWIDTH)}
    For tI = 1:1:3 {
        Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": ("toolu_" _ tI), "name": "probe_counter_read", "input": (tInput)}]))
    }
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 4, "after four provider calls")

    Set tFirst = ..ResultOf(2, 2, .tFirstError)
    Set tFirstContent = ##class(%DynamicAbstractObject).%FromJSON(tFirst)
    Do $$$AssertEquals(tFirstError _ "|" _ tFirstContent.truncated _ "|" _ tFirstContent.rows.%Size(), "0|0|" _ ..#BUDGETROWS, "reply 1 is answered in full")
    Do $$$AssertTrue($Length(tFirst) <= $Parameter(..#BUDGETLIMITS, "TOOLRESULTMAXLENGTH"), "inside the reply budget: " _ $Length(tFirst))

    Set tSecond = ..ResultOf(3, 4, .tSecondError)
    Set tSecondContent = ##class(%DynamicAbstractObject).%FromJSON(tSecond)
    Do $$$AssertEquals(tSecondError _ "|" _ tSecondContent.truncated, "0|1", "reply 2 is answered, marked truncated")
    Do $$$AssertTrue((tSecondContent.rows.%Size() > 0) && (tSecondContent.rows.%Size() < tFirstContent.rows.%Size()), "with fewer rows than reply 1: " _ tSecondContent.rows.%Size())
    Do $$$AssertEquals(tSecondContent.rowsAvailable, ..#BUDGETROWS, "of the rows the tool had")
    Do $$$AssertTrue(($Length(tFirst) + $Length(tSecond)) <= $Parameter(..#BUDGETLIMITS, "TURNRESULTMAXLENGTH"), "the two results together stay inside the turn budget: " _ ($Length(tFirst) + $Length(tSecond)))
    Do $$$AssertTrue($Length(tSecond) > (($Parameter(..#BUDGETLIMITS, "TURNRESULTMAXLENGTH") - $Length(tFirst)) / 2), "and keeps most of what the turn had left, so the budget is the turn's, not the reply's: " _ $Length(tSecond))

    Set tThird = ..ResultOf(4, 6, .tThirdError)
    Do $$$AssertEquals(tThirdError _ "|" _ tThird, "1|{""code"":""TOOL.RESULTTOOLARGE""}", "reply 3 finds under 256 characters left and is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.counter.read"), 2, "without the tool running")

    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Set tSteps = ""
    For tI = 0:1:tView.steps.%Size() - 1 {
        Set tStep = tView.steps.%Get(tI)
        Set tSteps = tSteps _ tStep.kind _ ":" _ tStep.name _ ":" _ tStep.status _ ";"
    }
    Do $$$AssertEquals(tSteps, "model:provider:ok;tool:probe.counter.read:ok;model:provider:ok;tool:probe.counter.read:ok;model:provider:ok;tool:probe.counter.read:error;model:provider:ok;", "the refused call is still recorded as an error step")

    For tCall = 1:1:3 {
        Set tBefore = ..Sent(tCall).messages
        Set tAfter = ..Sent(tCall + 1).messages
        Do $$$AssertEquals(tAfter.%Size(), tBefore.%Size() + 2, "call " _ (tCall + 1) _ " adds the echo and the results to call " _ tCall _ "'s messages")
        Set tSame = 1
        For tM = 0:1:tBefore.%Size() - 1 {
            If ..Unmarked(tBefore, tM) '= ..Unmarked(tAfter, tM) Set tSame = 0
        }
        Do $$$AssertTrue(tSame, "call " _ (tCall + 1) _ " re-sends every message of call " _ tCall _ " unchanged but for the marker")
        Do $$$AssertEquals(..Marks(tAfter.%ToJSON()) _ "|" _ ..Marks(tAfter.%Get(tBefore.%Size() - 1).%ToJSON()), "1|0", "the one marker moved to call " _ (tCall + 1) _ "'s new tail")
    }
}

}
