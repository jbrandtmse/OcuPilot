/// <p>The bounded provider loop a turn job runs (AD-7, AD-30, AD-31, AD-41). Before the first call it
/// takes the tool array from <method>DispatchClass</method>'s <code>Advertise</code> once, and every
/// provider request carries it; a turn whose tools cannot be advertised ends <code>failed</code>
/// with no provider call. It calls the provider through <method>PortClass</method>, answers each
/// tool call through <method>DispatchTools</method>, writes progress steps as it goes, and stops at
/// the first step boundary that says so. The system prompt is the built-in one or the definition's
/// override, whole; no tool result is ever joined to it (AD-11).</p>
/// <p><b>The boundary</b> runs before every provider call and before every tool call (AD-30: between
/// every step), in this order: the stop flag, the sign-out flag, the kill switch
/// (<class>OcuPilot.Kernel.Restraint</class>, whose code is recorded as given), enforced read-only
/// against the snapshot the turn started with, the user's current grants over the resource list the
/// handler passed, the poll lease, the wall clock and the token spend. Every one of them is a live
/// read; nothing is cached for the length of the turn.</p>
/// <p><b>Caller contract:</b> the caller is the turn's job, has begun the turn
/// (<method>OcuPilot.Kernel.State.Turn.GuardedBegin</method>), and finishes it with the outcome this
/// answers. Not called from an escalated frame (AD-9).</p>
/// <p>Seams a subclass overrides: <method>LimitsClass</method>, <method>PortClass</method>,
/// <method>DispatchClass</method>, <method>Restraint</method>, <method>DispatchTools</method> and
/// <method>LogFault</method>. Production overrides none.</p>
Class OcuPilot.Kernel.Agent.Loop Extends %RegisteredObject
{

/// <p>The step name every provider call is recorded under.</p>
Parameter MODELSTEP = "provider";

/// <p>The class every limit is read from.</p>
ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Limits"
}

/// <p>The port every provider call goes through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.ProviderPort"
}

/// <p>The dispatcher that advertises the tools and answers every tool call.</p>
ClassMethod DispatchClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Dispatch"
}

/// <p>Log a loop failure with the code the turn ends with.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String)
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", pMessage, pStatus, pCode)
}

/// <p>The kill switch and read-only verdict for <var>pUser</var>, read afresh.</p>
ClassMethod Restraint(pUser As %String, Output pVerdict) As %Status
{
    Quit ##class(OcuPilot.Kernel.Restraint).Resolved(pUser, .pVerdict)
}

/// <p>Answer tool calls. <var>pToolUses</var> holds <code>tool_use</code> blocks of the reply --
/// <method>AnswerTools</method> passes one at a time; <var>pResults</var> comes back with one
/// <code>tool_result</code> block per call and <var>pNames</var> with each call's canonical tool
/// name, both in the same order, from
/// <method>DispatchClass</method>'s <code>Answer</code> for <var>pUser</var> under
/// <var>pDefinitionId</var> and the caps <var>pLimitsClass</var> declares.</p>
/// <p><var>pRowCap</var> and <var>pMaxLength</var> are optional overrides
/// (<method>OcuPilot.Kernel.Agent.Dispatch.Answer</method>'s own), passed through unchanged.</p>
/// <p><var>pDetails</var> is <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method>'s own parallel
/// detail array (Story 4.5) -- one <code>{target, arguments, result, reason, failedPair}</code>
/// per call, passed through unchanged.</p>
ClassMethod DispatchTools(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray, pRowCap As %Integer = 0, pMaxLength As %Integer = 0, Output pDetails As %DynamicArray) As %Status
{
    Quit $ClassMethod(..DispatchClass(), "Answer", pKey, pUser, pDefinitionId, pToolUses, pLimitsClass, .pResults, .pNames, pRowCap, pMaxLength, .pDetails)
}

/// <p>Run turn <var>pKey</var> for <var>pUser</var> under definition <var>pDefinitionId</var>,
/// starting from <var>pMessage</var>. <var>pReadOnly</var> is enforced read-only as the handler read
/// it, <var>pResources</var> the comma-separated resources the grants check reads, and
/// <var>pStartedSeconds</var> the turn's start in
/// <method>OcuPilot.Kernel.State.Turn.NowSeconds</method> units.</p>
/// <p><var>pOutcome</var> comes back subscripted by <code>state</code>, <code>code</code>,
/// <code>limit</code>, <code>reply</code> and <code>errorSeq</code>. An error status means the loop
/// itself failed; the outcome then reads <code>failed</code>.</p>
/// <p><var>pContext</var> is the already-bounded screen-context payload JSON the turn request
/// built, or <code>""</code> for a turn with none; with one, the messages this turn opens with
/// carry the synthetic <code>screen_context</code> tool call and result ahead of the caller's own
/// message (AD-11 rule 1). <var>pContextRowCap</var> is the resolved row cap
/// (<code>Switch.ContextRowCap</code>) every tool call in this turn is answered under (AD-24);
/// <code>0</code> falls back to <var>pLimitsClass</var>'s own <code>TOOLROWS</code>. Both are
/// optional and trailing so an existing caller with no context keeps calling this unchanged.</p>
/// <p><var>pConvo</var> (Story 4.5), when supplied, is the turn's already-open, already-locked
/// conversation OREF (<method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method>): its prior turns
/// with a reply seed the messages this turn opens with, ahead of the screen-context pair and the
/// caller's own message. Optional and trailing so a caller with no conversation -- every test that
/// predates Story 4.5 -- keeps calling this unchanged.</p>
ClassMethod Run(pKey As %String, pUser As %String, pDefinitionId As %String, pMessage As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, Output pOutcome, pContext As %String = "", pContextRowCap As %Integer = 0, pConvo As OcuPilot.Kernel.State.Convo = "") As %Status
{
    Set tSC = $$$OK
    Kill pOutcome
    Set pOutcome("state") = ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED
    Set pOutcome("code") = ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE
    Set pOutcome("limit") = ""
    Set pOutcome("reply") = ""
    Set pOutcome("errorSeq") = 0
    Set tLastSeq = 0
    Try {
        Set tLimits = ..LimitsClass()
        Set tCap = ..IterationCap(pDefinitionId)
        Kill tMessages
        Set tHistoryCount = 0
        If $IsObject(pConvo) {
            Set tHistorySC = ##class(OcuPilot.Kernel.State.Convo).HistoryMessages(pConvo, +$Parameter(tLimits, "HISTORYMAXLENGTH"), .tHistory)
            If $$$ISOK(tHistorySC) {
                Set tHistoryIterator = tHistory.%GetIterator()
                While tHistoryIterator.%GetNext(.tHistoryIndex, .tHistoryMsg) {
                    Set tHistoryCount = tHistoryCount + 1
                    Set tMessages(tHistoryCount, "role") = tHistoryMsg.%Get("role")
                    Set tMessages(tHistoryCount, "content") = tHistoryMsg.%Get("content")
                }
            }
        }
        If pContext '= "" {
            Set tMessages = tHistoryCount + 3
            Set tMessages(tHistoryCount + 1, "role") = "user"
            Set tMessages(tHistoryCount + 1, "content") = ##class(OcuPilot.Kernel.Agent.Prompt).ContextPreamble()
            Set tUseBlocks = []
            Set tUseBlock = {}
            Do tUseBlock.%Set("type", "tool_use", "string")
            Do tUseBlock.%Set("id", "ocupilot_screen_context", "string")
            Do tUseBlock.%Set("name", "screen_context", "string")
            Do tUseBlock.%Set("input", {})
            Do tUseBlocks.%Push(tUseBlock)
            Set tMessages(tHistoryCount + 2, "role") = "assistant"
            Set tMessages(tHistoryCount + 2, "blocks") = tUseBlocks.%ToJSON()
            Set tUserBlocks = []
            Set tResultBlock = {}
            Do tResultBlock.%Set("type", "tool_result", "string")
            Do tResultBlock.%Set("tool_use_id", "ocupilot_screen_context", "string")
            Do tResultBlock.%Set("content", pContext, "string")
            Do tUserBlocks.%Push(tResultBlock)
            Set tTextBlock = {}
            Do tTextBlock.%Set("type", "text", "string")
            Do tTextBlock.%Set("text", pMessage, "string")
            Do tUserBlocks.%Push(tTextBlock)
            Set tMessages(tHistoryCount + 3, "role") = "user"
            Set tMessages(tHistoryCount + 3, "blocks") = tUserBlocks.%ToJSON()
        } Else {
            Set tMessages = tHistoryCount + 1
            Set tMessages(tHistoryCount + 1, "role") = "user"
            Set tMessages(tHistoryCount + 1, "content") = pMessage
        }
        Set tIterations = 0
        Set tInput = 0
        Set tOutput = 0
        Set tToolLog = []
        Kill tTools
        Set tAdvertiseSC = $ClassMethod(..DispatchClass(), "Advertise", .tTools)
        If $$$ISERR(tAdvertiseSC) {
            Do ..LogFault("the turn's tools could not be advertised", tAdvertiseSC, pOutcome("code"))
            Quit
        }
        For {
            If ..Boundary(pKey, pUser, pReadOnly, pResources, pStartedSeconds, tInput + tOutput, .tState, .tCode) {
                If tCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED {
                    Set tStopSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "model", ..#MODELSTEP, "stopped", "", "", "", tLimits, .tStopSeq, .tStopStored)
                    If $$$ISOK(tStopSC) Set tLastSeq = tStopSeq
                }
                Set pOutcome("state") = tState
                Set pOutcome("code") = tCode
                Set pOutcome("errorSeq") = tLastSeq
                Quit
            }
            Set tIterations = tIterations + 1
            Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "model", ..#MODELSTEP, "running", "", "", "", tLimits, .tSeq)
            If $$$ISERR(tSC) Quit
            Set tLastSeq = tSeq
            Do $ClassMethod(..PortClass(), "Invoke", pDefinitionId, .tMessages, .tTools, ##class(OcuPilot.Kernel.Agent.Prompt).Builtin(), .tResponse, .tHttpStatus, .tFault)
            If $IsObject($Get(tResponse)) {
                Set tInput = tInput + tResponse.RequestTokens
                Set tOutput = tOutput + tResponse.ResponseTokens
            }
            Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedProgress(pKey, tIterations, tInput, tOutput)
            If $$$ISERR(tSC) Quit
            If $IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedUpdate(pKey, tSeq, "error", tFault.reason, "", tFault.code, tLimits)
                If $$$ISERR(tSC) Quit
                Set pOutcome("state") = ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED
                Set pOutcome("code") = tFault.code
                Set pOutcome("errorSeq") = tSeq
                Quit
            }
            Set tToolUses = ..ToolUses(tResponse.ToolCallsJson)
            Set tSummary = tResponse.StopReason _ "; " _ tResponse.RequestTokens _ " input and " _ tResponse.ResponseTokens _ " output tokens"
            Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedUpdate(pKey, tSeq, "ok", tSummary, tResponse.Text, "", tLimits)
            If $$$ISERR(tSC) Quit
            If tToolUses.%Size() = 0 {
                Set pOutcome("state") = ##class(OcuPilot.Kernel.State.Turn).#STATECOMPLETED
                Set pOutcome("code") = ""
                Set pOutcome("reply") = tResponse.Text
                Quit
            }
            Set tSC = ..AnswerTools(pKey, pUser, pDefinitionId, tResponse.Text, tToolUses, tLimits, .tMessages, tToolLog, .tLastSeq, pReadOnly, pResources, pStartedSeconds, tInput + tOutput, .tState, .tCode, pContextRowCap)
            If $$$ISERR(tSC) Quit
            If tState '= "" {
                Set pOutcome("state") = tState
                Set pOutcome("code") = tCode
                Set pOutcome("errorSeq") = tLastSeq
                Quit
            }
            If tIterations >= tCap {
                Set pOutcome("state") = ##class(OcuPilot.Kernel.State.Turn).#STATECOMPLETED
                Set pOutcome("code") = ""
                Set pOutcome("limit") = ##class(OcuPilot.Kernel.State.Turn).#LIMITITERATIONS
                Set pOutcome("reply") = ..FallbackReply(tToolLog)
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pOutcome("state") = ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED
        Set pOutcome("code") = ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE
        Set pOutcome("errorSeq") = tLastSeq
    }
    Quit tSC
}

/// <p>Whether the turn stops here, and if so in which state and with which code. See this class's
/// header for the order. A read that fails is logged and stops the turn <code>failed</code>.</p>
ClassMethod Boundary(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String) As %Boolean
{
    Set pState = ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED
    Set pCode = ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE
    Set tAbandoned = ##class(OcuPilot.Kernel.State.Turn).#STATEABANDONED
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(pKey, .tStop, .tAbandon, .tRenewedAt)
    If $$$ISERR(tSC) {
        Do ..LogFault("a step boundary could not read the turn's signals", tSC, pCode)
        Quit 1
    }
    If tStop {
        Set pState = ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED
        Set pCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED
        Quit 1
    }
    If tAbandon {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNABANDONEDSIGNOUT
        Quit 1
    }
    Set tSC = ..Restraint(pUser, .tVerdict)
    If $$$ISERR(tSC) {
        Do ..LogFault("a step boundary could not read the switches", tSC, pCode)
        Quit 1
    }
    If +$Get(tVerdict("killSwitch")) {
        Set pState = ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED
        Set pCode = $Get(tVerdict("code"))
        Quit 1
    }
    If ''$Get(tVerdict("enforcedReadOnly")) '= ''pReadOnly {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNABANDONEDREADONLY
        Quit 1
    }
    If '..HoldsAnyResource(pUser, pResources) {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNABANDONEDPRIVILEGE
        Quit 1
    }
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tLimits = ..LimitsClass()
    If (tRenewedAt = "") || ((tNow - tRenewedAt) >= $Parameter(tLimits, "LEASESECONDS")) {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNABANDONEDLEASE
        Quit 1
    }
    If (tNow - pStartedSeconds) >= $Parameter(tLimits, "WALLCLOCKSECONDS") {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNLIMITDURATION
        Quit 1
    }
    If pTokens >= $Parameter(tLimits, "MAXTOKENS") {
        Set pState = tAbandoned
        Set pCode = ##class(OcuPilot.Api.Error).#TURNLIMITTOKENS
        Quit 1
    }
    Set pState = ""
    Set pCode = ""
    Quit 0
}

/// <p>Whether <var>pUser</var>'s current grants hold <code>USE</code> on any resource in the
/// comma-separated <var>pResources</var> (AD-8, AD-31). A user the instance no longer holds holds
/// nothing.</p>
ClassMethod HoldsAnyResource(pUser As %String, pResources As %String) As %Boolean
{
    Set tHolds = 0
    Try {
        For tI = 1:1:$Length(pResources, ",") {
            Set tResource = $Piece(pResources, ",", tI)
            If tResource = "" Continue
            If $SYSTEM.Security.CheckUserPermission(pUser, tResource, "USE") = 1 {
                Set tHolds = 1
                Quit
            }
        }
    } Catch ex {
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>The iteration cap: the lower of the definition's own maximum and the limit. A definition that
/// cannot be read contributes nothing, and the limit alone applies.</p>
ClassMethod IterationCap(pDefinitionId As %String) As %Integer
{
    Set tCap = +$Parameter(..LimitsClass(), "MAXITERATIONS")
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(pDefinitionId, .tExists)
        If $$$ISERR(tSC) || 'tExists Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pDefinitionId, .tRow)
        If $$$ISERR(tSC) || '$IsObject(tRow) Quit
        If (+tRow.MaxIterationsPerTurn > 0) && (+tRow.MaxIterationsPerTurn < tCap) Set tCap = +tRow.MaxIterationsPerTurn
        Set tRow = ""
    } Catch ex {
    }
    Quit tCap
}

/// <p>The <code>tool_use</code> blocks <var>pJson</var> carries, as an array; empty when there are
/// none or the text is not an array.</p>
ClassMethod ToolUses(pJson As %String) As %DynamicArray
{
    Set tUses = []
    Try {
        If pJson = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pJson)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tUses = tParsed
    } Catch ex {
        Set tUses = []
    }
    Quit tUses
}

/// <p>Echo the model's reply back as an assistant message of blocks -- its text, then its
/// <code>tool_use</code> blocks verbatim -- answer the calls one at a time through
/// <method>DispatchTools</method> as one user message of <code>tool_result</code> blocks and nothing
/// else, and record one <code>tool</code> step per call under the tool's canonical name.
/// <var>pToolLog</var> collects <code>{name, code}</code> for the fallback reply.</p>
/// <p><b>Each call is a step, and <method>Boundary</method> runs before it</b> (AD-30, AD-31), with
/// <var>pReadOnly</var>, <var>pResources</var>, <var>pStartedSeconds</var> and <var>pTokens</var> as
/// <method>Run</method> holds them. When it stops the turn, no later call runs and
/// <var>pState</var> and <var>pCode</var> carry its answer; otherwise both are
/// <code>""</code>.</p>
/// <p><b>The reply budget</b> (DW-452): this reply's tool results share
/// <parameter>OcuPilot.Kernel.Agent.Limits.TOOLRESULTMAXLENGTH</parameter> characters between
/// them, starting fresh each call to this method. Each dispatched call's own size cap is what
/// remains of the budget; once fewer than 256 characters remain, the next call is answered
/// <code>TOOL.RESULTTOOLARGE</code> without being dispatched at all, and is still recorded as an
/// error step. <var>pContextRowCap</var> is the row cap every dispatched call in this turn is
/// answered under (<code>0</code> falls back to <var>pLimitsClass</var>'s own
/// <code>TOOLROWS</code>).</p>
ClassMethod AnswerTools(pKey As %String, pUser As %String, pDefinitionId As %String, pText As %String, pToolUses As %DynamicArray, pLimitsClass As %String, ByRef pMessages, pToolLog As %DynamicArray, ByRef pLastSeq As %Integer, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String, pContextRowCap As %Integer = 0) As %Status
{
    Set pState = ""
    Set pCode = ""
    Set tAssistant = []
    If $ZStrip(pText, "<>WC") '= "" {
        Set tTextBlock = {}
        Do tTextBlock.%Set("type", "text", "string")
        Do tTextBlock.%Set("text", pText, "string")
        Do tAssistant.%Push(tTextBlock)
    }
    Set tIterator = pToolUses.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBlock) {
        Do tAssistant.%Push(tBlock)
    }
    Set pMessages = pMessages + 1
    Set pMessages(pMessages, "role") = "assistant"
    Set pMessages(pMessages, "blocks") = tAssistant.%ToJSON()

    Set tSC = $$$OK
    Set tAnswered = []
    Set tBudget = +$Parameter(pLimitsClass, "TOOLRESULTMAXLENGTH")
    For tI = 0:1:pToolUses.%Size() - 1 {
        Set tBlock = pToolUses.%Get(tI)
        If ..Boundary(pKey, pUser, pReadOnly, pResources, pStartedSeconds, pTokens, .tStopState, .tStopCode) {
            Set pState = tStopState
            Set pCode = tStopCode
            If tStopCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED {
                ; Named for what it was about to run (Design Notes, AD-30): the canonical tool
                ; name and target this call would have carried, resolved the same way
                ; OcuPilot.Kernel.Agent.Dispatch would have, without dispatching it.
                Set tStopWire = $Select($IsObject(tBlock): tBlock.%Get("name"), 1: "")
                Set tStopName = tStopWire
                Kill tStopResolved
                Do $ClassMethod($ClassMethod(..DispatchClass(), "RegistryClass"), "ResolveWire", tStopWire, .tStopResolved)
                If $IsObject(tStopResolved) Set tStopName = tStopResolved.%Get("name")
                Set tStopInput = $Select($IsObject(tBlock): tBlock.%Get("input"), 1: "")
                Set tStopTarget = $ClassMethod(..DispatchClass(), "TargetOf", tStopInput)
                Set tStopArgs = $ClassMethod(..DispatchClass(), "RedactedArguments", tStopInput, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .tStopArgsTruncated)
                Set tStopSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tStopName, "stopped", "", "", "", pLimitsClass, .tStopSeq, .tStopStored, tStopTarget, tStopArgs, , , , tStopArgsTruncated)
                If $$$ISOK(tStopSC) Set pLastSeq = tStopSeq
            }
            Quit
        }
        If tBudget < 256 {
            ; The remaining budget cannot answer even a minimal call: refused without dispatch,
            ; and still recorded as an error step (DW-452).
            Set tCode = ##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE
            Set tName = $Select($IsObject(tBlock): tBlock.%Get("name"), 1: "")
            Kill tResolvedTool
            Do $ClassMethod($ClassMethod(..DispatchClass(), "RegistryClass"), "ResolveWire", tName, .tResolvedTool)
            If $IsObject(tResolvedTool) Set tName = tResolvedTool.%Get("name")
            Set tBudgetInput = $Select($IsObject(tBlock): tBlock.%Get("input"), 1: "")
            Set tBudgetTarget = $ClassMethod(..DispatchClass(), "TargetOf", tBudgetInput)
            Set tBudgetArgs = $ClassMethod(..DispatchClass(), "RedactedArguments", tBudgetInput, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .tBudgetArgsTruncated)
            Set tResult = {}
            Do tResult.%Set("type", "tool_result", "string")
            Do tResult.%Set("tool_use_id", $Select($IsObject(tBlock) && (tBlock.%Get("id") '= ""): tBlock.%Get("id"), 1: "unknown"), "string")
            Do tResult.%Set("is_error", 1, "boolean")
            Set tContentObj = {}
            Do tContentObj.%Set("code", tCode, "string")
            Do tResult.%Set("content", tContentObj.%ToJSON(), "string")
            Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tName, "error", tCode, "", tCode, pLimitsClass, .tSeq, .tStored, tBudgetTarget, tBudgetArgs, "", ##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), "", tBudgetArgsTruncated)
            If $$$ISERR(tSC) Quit
            Set pLastSeq = tSeq
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("code", tCode, "string")
            Do pToolLog.%Push(tEntry)
            Do tAnswered.%Push(tResult)
            Continue
        }
        Set tCall = []
        Do tCall.%Push(tBlock)
        Set tSC = ..DispatchTools(pKey, pUser, pDefinitionId, tCall, pLimitsClass, .tResults, .tNames, pContextRowCap, tBudget, .tDetails)
        If $$$ISERR(tSC) Quit
        Set tResult = tResults.%Get(0)
        Set tName = tNames.%Get(0)
        Set tDetail = tDetails.%Get(0)
        Set tIsError = $IsObject(tResult) && tResult."is_error"
        Set tCode = ""
        If tIsError {
            Try {
                Set tCode = ##class(%DynamicAbstractObject).%FromJSON(tResult.content).code
            } Catch ex {
                Set tCode = ""
            }
        }
        Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tName, $Select(tIsError: "error", 1: "ok"), tCode, "", tCode, pLimitsClass, .tSeq, .tStored, tDetail.target, tDetail.arguments, tDetail.result, tDetail.reason, tDetail.failedPair, tDetail.argumentsTruncated)
        If $$$ISERR(tSC) Quit
        Set pLastSeq = tSeq
        Set tEntry = {}
        Do tEntry.%Set("name", tName, "string")
        Do tEntry.%Set("code", tCode, "string")
        Do pToolLog.%Push(tEntry)
        Do tAnswered.%Push(tResult)
        Set tBudget = tBudget - $Length($Select($IsObject(tResult): tResult.%Get("content"), 1: ""))
        If tBudget < 0 Set tBudget = 0
    }
    If $$$ISERR(tSC) Quit tSC
    If pState '= "" Quit $$$OK
    Set pMessages = pMessages + 1
    Set pMessages(pMessages, "role") = "user"
    Set pMessages(pMessages, "blocks") = tAnswered.%ToJSON()
    Quit $$$OK
}

/// <p>The reply a turn that reached its iteration cap ends with: how many tool calls were made, one
/// line per call naming the tool and its outcome, and a suggestion for what to do next. A name is the
/// tool's canonical name, or the model's own for a call that resolved to no tool, and is rendered as
/// untrusted content.</p>
ClassMethod FallbackReply(pToolLog As %DynamicArray) As %String
{
    Set tCount = pToolLog.%Size()
    Set tReply = "I reached this turn's limit on steps after " _ tCount _ " tool call" _ $Select(tCount = 1: "", 1: "s") _ "."
    Set tLines = ""
    Set tIterator = pToolLog.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tLines = tLines _ $Char(10) _ "- " _ tEntry.name _ ": " _ $Select(tEntry.code = "": "answered", 1: tEntry.code)
    }
    If tLines = "" Set tLines = $Char(10) _ "- (no tools were called)"
    Quit tReply _ $Char(10) _ tLines _ $Char(10) _ $Char(10) _ "Ask a narrower question, or send a follow-up to continue from here."
}

}
