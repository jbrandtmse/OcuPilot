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

/// <p>The agent ledger every provider call and every tool call of this turn is recorded in (Story
/// 4.9, AD-41). Overridable for the same reason <method>DispatchClass</method> is; production never
/// overrides it.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Ledger"
}

/// <p>The screen-context route <var>pContextJson</var> carries, or <code>""</code> for a turn that
/// carried no context (Story 4.9). The payload is the one
/// <method>OcuPilot.Screen.Context.Build</method> already produced, so this reads a value rather
/// than resolving a screen -- which is what lets <class>OcuPilot.Kernel.Agent.Job</class> record the
/// same route on the turn row without reaching a registry either.</p>
ClassMethod ContextRoute(pContextJson As %String) As %String
{
    Set tRoute = ""
    Try {
        If pContextJson = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pContextJson)
        If $IsObject(tParsed) && (tParsed.%GetTypeOf("route") = "string") Set tRoute = tParsed.%Get("route")
    } Catch ex {
        Set tRoute = ""
    }
    Quit tRoute
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
/// per call, passed through unchanged. <var>pRoute</var> is the turn's screen-context route (Story
/// 4.9), passed through the same way.</p>
ClassMethod DispatchTools(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray, pRowCap As %Integer = 0, pMaxLength As %Integer = 0, Output pDetails As %DynamicArray, pRoute As %String = "") As %Status
{
    Quit $ClassMethod(..DispatchClass(), "Answer", pKey, pUser, pDefinitionId, pToolUses, pLimitsClass, .pResults, .pNames, pRowCap, pMaxLength, .pDetails, pRoute)
}

/// <p>Run turn <var>pKey</var> for <var>pUser</var> under definition <var>pDefinitionId</var>,
/// starting from <var>pMessage</var>. <var>pReadOnly</var> is enforced read-only as the handler read
/// it, <var>pResources</var> the comma-separated resources the grants check reads, and
/// <var>pStartedSeconds</var> the turn's start in
/// <method>OcuPilot.Kernel.State.Turn.NowSeconds</method> units.</p>
/// <p><var>pOutcome</var> comes back subscripted by <code>state</code>, <code>code</code>,
/// <code>limit</code>, <code>reply</code>, <code>citations</code> (the reply's citations as JSON
/// text, <method>OcuPilot.Kernel.Agent.Citations.Cite</method>; <code>""</code> for a turn with no
/// reply) and <code>errorSeq</code>. An error status means the loop
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
    Set pOutcome("citations") = ""
    Set pOutcome("errorSeq") = 0
    Set tLastSeq = 0
    ; The turn a tool call is being made on behalf of, stashed once for the length of the job
    ; (AD-40). A write tool reads it to record which turn and which conversation minted a proposal;
    ; nothing else in the loop reads it, and it is cleared on every exit so a process reused for a
    ; later request carries no turn.
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pKey, $Select($IsObject(pConvo): pConvo.ConvKey, 1: ""))
    Try {
        Set tLimits = ..LimitsClass()
        Set tCap = ..IterationCap(pDefinitionId)
        ; The screen-context route and the definition's provider key and model are read once here
        ; and carried: a turn's route cannot change while it runs, and neither can its definition.
        Set tContextRoute = ..ContextRoute(pContext)
        Do ..Definition(pDefinitionId, .tProviderKey, .tProviderModel)
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
            } Else {
                Do ..LogFault("the conversation's history could not be read; the turn runs without it", tHistorySC, pOutcome("code"))
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
        Set tCandidates = []
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
            ; pUser is the turn owner. The port gates on that account's live grants, never on this
            ; job's frozen $ROLES (AD-31, DW-1309). The sink writes the call's text so far onto this
            ; running step (AD-33).
            Do $ClassMethod(..PortClass(), "Invoke", pDefinitionId, .tMessages, .tTools, ##class(OcuPilot.Kernel.Agent.Prompt).Builtin(), .tResponse, .tHttpStatus, .tFault, pUser, ##class(OcuPilot.Kernel.Agent.StreamStep).%New(pKey, tSeq, tLimits))
            If $IsObject($Get(tResponse)) {
                Set tInput = tInput + tResponse.RequestTokens
                Set tOutput = tOutput + tResponse.ResponseTokens
            }
            ; A refusal is the provider declining (AD-39, DW-1181): the turn fails with a banner and
            ; no reply, whatever text arrived before it, and the ledger row records the same code.
            If '$IsObject($Get(tFault)) && $IsObject($Get(tResponse)) && (tResponse.StopReason = ##class(OcuPilot.Kernel.Provider.MessageAdapter).#REFUSALSTOPREASON) {
                Do ##class(OcuPilot.Kernel.Provider.Base).Fault(##class(OcuPilot.Api.Error).#PROVIDERDECLINED, "", "", .tFault, .tDeclinedHttp)
            }
            ; A tool call the provider could not complete ends the turn the same way, under its own
            ; code, because the model did not decline.
            If '$IsObject($Get(tFault)) && $IsObject($Get(tResponse)) && (tResponse.StopReason = ##class(OcuPilot.Kernel.Provider.MessageAdapter).#TOOLCALLFAILEDSTOPREASON) {
                Do ##class(OcuPilot.Kernel.Provider.Base).Fault(##class(OcuPilot.Api.Error).#PROVIDERTOOLCALLFAILED, "", "", .tFault, .tDeclinedHttp)
            }
            Do ..RecordProviderRow(pKey, pUser, tContextRoute, tProviderKey, tProviderModel, tIterations, $Get(tResponse), $Get(tFault), tLimits, +$Get(tHttpStatus))
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
                Set pOutcome("citations") = ##class(OcuPilot.Kernel.Agent.Citations).Cite(tResponse.Text, tCandidates).%ToJSON()
                Quit
            }
            Set tSC = ..AnswerTools(pKey, pUser, pDefinitionId, tResponse.Text, tToolUses, tLimits, .tMessages, tToolLog, .tLastSeq, pReadOnly, pResources, pStartedSeconds, tInput + tOutput, .tState, .tCode, pContextRowCap, tContextRoute, tResponse.ContentJson, tCandidates)
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
                Set pOutcome("citations") = ##class(OcuPilot.Kernel.Agent.Citations).Cite(pOutcome("reply"), tCandidates).%ToJSON()
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
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
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
/// <code>tool_use</code> blocks verbatim, or the reply's own content where it carries reasoning
/// blocks (<var>pContentJson</var>, below) -- answer the calls one at a time through
/// <method>DispatchTools</method> as one user message of <code>tool_result</code> blocks and nothing
/// else, and record one <code>tool</code> step per call under the tool's canonical name: appended
/// <code>running</code> before the call is dispatched, then set to its outcome.
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
/// <p><var>pContentJson</var> is <property>OcuPilot.Kernel.Provider.Response.ContentJson</property>:
/// when it parses to a non-empty array, that array is the echo, unchanged and in order, because a
/// reply's reasoning blocks must go back to the provider as it sent them. Otherwise the echo is
/// rebuilt from <var>pText</var> and <var>pToolUses</var>.</p>
/// <p><var>pCandidates</var>, when an array, gains the citation candidates of every non-error call
/// to a descriptor-backed read tool answered here (<method>OcuPilot.Kernel.Agent.Citations.Candidates</method>),
/// read from the bounded content the model was handed.</p>
ClassMethod AnswerTools(pKey As %String, pUser As %String, pDefinitionId As %String, pText As %String, pToolUses As %DynamicArray, pLimitsClass As %String, ByRef pMessages, pToolLog As %DynamicArray, ByRef pLastSeq As %Integer, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String, pContextRowCap As %Integer = 0, pRoute As %String = "", pContentJson As %String = "", pCandidates As %DynamicArray = "") As %Status
{
    Set pState = ""
    Set pCode = ""
    Set tAssistant = ""
    If pContentJson '= "" {
        Try {
            Set tEcho = ##class(%DynamicAbstractObject).%FromJSON(pContentJson)
            If $IsObject(tEcho) && tEcho.%IsA("%Library.DynamicArray") && (tEcho.%Size() > 0) Set tAssistant = tEcho
        } Catch ex {
            Set tAssistant = ""
        }
    }
    If '$IsObject(tAssistant) {
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
                Set tStopArgs = $ClassMethod(..DispatchClass(), "StepArguments", tStopInput, ..SecretNamesOf($Get(tStopResolved)), pLimitsClass, .tStopArgsTruncated)
                Set tStopSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tStopName, "stopped", "", "", "", pLimitsClass, .tStopSeq, .tStopStored, tStopTarget, tStopArgs, , , , tStopArgsTruncated)
                If $$$ISOK(tStopSC) Set pLastSeq = tStopSeq
                Do ..RecordRefusedRow(pKey, pUser, pRoute, tStopName, tStopTarget, tStopInput, "stopped", tStopCode, pLimitsClass, $Get(tStopResolved))
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
            Set tBudgetArgs = $ClassMethod(..DispatchClass(), "StepArguments", tBudgetInput, ..SecretNamesOf($Get(tResolvedTool)), pLimitsClass, .tBudgetArgsTruncated)
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
            Do ..RecordRefusedRow(pKey, pUser, pRoute, tName, tBudgetTarget, tBudgetInput, "error", tCode, pLimitsClass, $Get(tResolvedTool))
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("code", tCode, "string")
            Do pToolLog.%Push(tEntry)
            Do tAnswered.%Push(tResult)
            Continue
        }
        ; The step is recorded running before the call is dispatched, so a poll during a slow call
        ; shows the card it is waiting on, then set to the call's outcome.
        Set tRunningName = $Select($IsObject(tBlock): tBlock.%Get("name"), 1: "")
        Kill tRunningResolved
        Do $ClassMethod($ClassMethod(..DispatchClass(), "RegistryClass"), "ResolveWire", tRunningName, .tRunningResolved)
        If $IsObject(tRunningResolved) Set tRunningName = tRunningResolved.%Get("name")
        Set tRunningInput = $Select($IsObject(tBlock): tBlock.%Get("input"), 1: "")
        Set tRunningArgs = $ClassMethod(..DispatchClass(), "StepArguments", tRunningInput, ..SecretNamesOf(tRunningResolved), pLimitsClass, .tRunningArgsTruncated)
        Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tRunningName, "running", "", "", "", pLimitsClass, .tSeq, .tStored, $ClassMethod(..DispatchClass(), "TargetOf", tRunningInput), tRunningArgs, , , , tRunningArgsTruncated)
        If $$$ISERR(tSC) Quit
        Set pLastSeq = tSeq

        Set tFulfilment = "instance"
        If $IsObject(tRunningResolved) Set tFulfilment = $ClassMethod($ClassMethod(..DispatchClass(), "RegistryClass"), "FulfilmentOf", tRunningResolved)
        If tFulfilment = "client" {
            ; A client-fulfilled call (Story 4.7, AD-11 rule 3): Dispatch validates it and answers
            ; a directive rather than a result; this method announces it, waits for the browser,
            ; and settles the tool step from the outcome.
            Set tSC = ..AnswerClientCall(pKey, pUser, pReadOnly, pResources, pStartedSeconds, pTokens, pLimitsClass, tBlock, tSeq, $ClassMethod(..DispatchClass(), "TargetOf", tRunningInput), tRunningArgs, tRunningArgsTruncated, .pLastSeq, .tResult, .tName, .tCode, .pState, .pCode, pRoute)
            If $$$ISERR(tSC) Quit
            If pState '= "" Quit
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("code", tCode, "string")
            Do pToolLog.%Push(tEntry)
            Do tAnswered.%Push(tResult)
            Set tBudget = tBudget - $Length($Select($IsObject(tResult): tResult.%Get("content"), 1: ""))
            If tBudget < 0 Set tBudget = 0
        } Else {
            Set tCall = []
            Do tCall.%Push(tBlock)
            Set tSC = ..DispatchTools(pKey, pUser, pDefinitionId, tCall, pLimitsClass, .tResults, .tNames, pContextRowCap, tBudget, .tDetails, pRoute)
            If $$$ISERR(tSC) {
                Set tUnavailableCode = ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE
                Do ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(pKey, tSeq, tRunningName, "error", tUnavailableCode, pLimitsClass, $ClassMethod(..DispatchClass(), "TargetOf", tRunningInput), tRunningArgs, "", ##class(OcuPilot.Api.Error).ReasonForToolCode(tUnavailableCode), "", tRunningArgsTruncated)
                Quit
            }
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
            ; The bounded result content the model was handed, stored on the step (DW-1052). It is
            ; the tool_result content itself -- already cut to the per-call budget by the
            ; dispatcher -- so the panel's card shows what the model read rather than nothing. The
            ; dispatcher-failed finish above records none: there was no result.
            Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(pKey, tSeq, tName, $Select(tIsError: "error", 1: "ok"), tCode, pLimitsClass, tDetail.target, tDetail.arguments, tDetail.result, tDetail.reason, tDetail.failedPair, tDetail.argumentsTruncated, $Select($IsObject(tResult): tResult.%Get("content"), 1: ""))
            If $$$ISERR(tSC) Quit
            If 'tIsError && $IsObject(tResult) && $IsObject(pCandidates) && ..CitesRows(tRunningResolved) {
                Do ##class(OcuPilot.Kernel.Agent.Citations).Candidates(tRunningResolved.%Get("descriptor"), tResult.%Get("content"), pCandidates)
            }
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("code", tCode, "string")
            Do pToolLog.%Push(tEntry)
            Do tAnswered.%Push(tResult)
            Set tBudget = tBudget - $Length($Select($IsObject(tResult): tResult.%Get("content"), 1: ""))
            If tBudget < 0 Set tBudget = 0
        }
    }
    If $$$ISERR(tSC) Quit tSC
    If pState '= "" Quit $$$OK
    Set pMessages = pMessages + 1
    Set pMessages(pMessages, "role") = "user"
    Set pMessages(pMessages, "blocks") = tAnswered.%ToJSON()
    Quit $$$OK
}

/// <p>Whether the resolved tool <var>pTool</var> is one whose rows a citation may name: a read-kind,
/// instance-fulfilled tool answered by the registry's descriptor-backed read class for a
/// descriptor (Story 11.4).</p>
ClassMethod CitesRows(pTool As %DynamicObject) As %Boolean [ Private ]
{
    If '$IsObject(pTool) Quit 0
    If (pTool.%Get("kind") '= "read") || (pTool.%Get("descriptor") = "") Quit 0
    Set tRegistry = $ClassMethod(..DispatchClass(), "RegistryClass")
    If $ClassMethod(tRegistry, "FulfilmentOf", pTool) '= "instance" Quit 0
    Quit pTool.%Get("class") = $ClassMethod(tRegistry, "ReadToolClass")
}

/// <p>Answer one client-fulfilled tool call (Story 4.7, AD-11 rule 3): resolve and validate it
/// through <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method>, and when it validates,
/// announce the move, wait for the browser, and settle the tool step from the outcome.</p>
/// <p><var>pSeq</var> is the tool step's own sequence, already appended <code>running</code> by the
/// caller; <var>pTarget</var>, <var>pArguments</var> and <var>pArgumentsTruncated</var> are that
/// step's own values (Story 4.5), already computed by the caller. <var>pLastSeq</var> is updated to
/// whichever step this method appends last.</p>
/// <p><var>pTurnState</var>/<var>pTurnCode</var> come back non-empty only when
/// <method>Boundary</method> stopped the turn during the wait, in which case <var>pAnswered</var> is
/// left unset and the caller must not add it to the reply -- the same contract the per-call
/// boundary check above already keeps. Otherwise <var>pAnswered</var> is the finished
/// <code>tool_result</code> block, <var>pToolName</var> its canonical name and <var>pCode</var> the
/// machine code it carries (<code>""</code> for a navigated call).</p>
/// <p><b>Four exits record a ledger row</b> (Story 4.9): a refusal before any announcement, a call
/// whose announcement was counted past the step cap, a turn stopped during the wait, and the settle
/// -- every exit at which the model was answered. An exit that could not write the call's own step
/// (an announce append, a request write, a finish) returns its error status and records nothing,
/// because a row about a call whose step never landed would outlive the only thing it reconciles
/// with. Each row carries the outcome code the model was answered with and the target screen's own
/// argument-derived pairs, which for <code>shell.screen.open</code> are the whole requirement.</p>
ClassMethod AnswerClientCall(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, pLimitsClass As %String, pBlock As %DynamicObject, pSeq As %Integer, pTarget As %String, pArguments As %String, pArgumentsTruncated As %Boolean, ByRef pLastSeq As %Integer, Output pAnswered As %DynamicObject, Output pToolName As %String, Output pCode As %String, Output pTurnState As %String, Output pTurnCode As %String, pRoute As %String = "") As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswered = ""
    Set pToolName = ""
    Set pCode = ""
    Set pTurnState = ""
    Set pTurnCode = ""
    Try {
        Set tSC = $ClassMethod(..DispatchClass(), "ResolveClientCall", pUser, pBlock, pLimitsClass, .tPending, .tToolName, .tRoute, .tEntityId, .tCTarget, .tCArguments, .tCArgsTruncated, .tIsError, .tContent, .tReason, .tFailedPair, pKey, .tCInput, .tCDeclaredPairs, .tCCallPairs, .tCSecretNames, .tCSecretDeclared, .tCPairsResolved, .tCriterion, .tCriteria)
        If $$$ISERR(tSC) Quit
        Set pToolName = tToolName

        If 'tPending {
            ; Refused before any announcement exists (AC2): no announce step, no directive are
            ; ever written.
            Set tRefusedCode = ""
            Try {
                Set tRefusedCode = ##class(%DynamicAbstractObject).%FromJSON(tContent).code
            } Catch {
                Set tRefusedCode = ""
            }
            Set pCode = tRefusedCode
            Set tFinishSC = ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(pKey, pSeq, tToolName, "error", tRefusedCode, pLimitsClass, pTarget, pArguments, "", tReason, tFailedPair, pArgumentsTruncated)
            If $$$ISERR(tFinishSC) {
                Set tSC = tFinishSC
                Quit
            }
            Do ..RecordClientRow(pKey, pUser, pRoute, tToolName, pTarget, tCInput, tCDeclaredPairs, tCCallPairs, tCSecretNames, "error", tRefusedCode, pLimitsClass, tCSecretDeclared, $Get(tCPairsResolved, 0))
            Set pAnswered = ..ClientResult(pBlock, tIsError, tContent)
            Quit
        }

        Set tAnnounceSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "announce", tToolName, "running", "", tEntityId, "", pLimitsClass, .tAnnounceSeq, .tAnnounceStored, tRoute, "", "", "", "", 0)
        If $$$ISERR(tAnnounceSC) {
            Set tSC = tAnnounceSC
            Quit
        }
        If 'tAnnounceStored {
            ; The turn is at MAXSTEPS, so the announcement was counted rather than stored and no
            ; reader can ever see it. A directive whose announcement does not exist is precisely
            ; what GuardedRequest refuses, so the call lapses here instead of asking for one: an
            ; ordinary tool result with nothing announced (AD-11 rule 3, AD-31), not a failed turn.
            Set tDroppedCode = ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE
            Set tDroppedDetail = {}
            Do tDroppedDetail.%Set("route", tRoute, "string")
            Do tDroppedDetail.%Set("entityId", tEntityId, "string")
            Set tDroppedJson = ""
            Do $ClassMethod(..DispatchClass(), "SettleClient", tDroppedDetail, "unavailable", tDroppedCode, .tDroppedJson)
            Set pCode = tDroppedCode
            Set tDroppedSC = ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(pKey, pSeq, tToolName, "ok", "", pLimitsClass, pTarget, pArguments, "", "", "", pArgumentsTruncated)
            If $$$ISERR(tDroppedSC) {
                Set tSC = tDroppedSC
                Quit
            }
            Do ..RecordClientRow(pKey, pUser, pRoute, tToolName, pTarget, tCInput, tCDeclaredPairs, tCCallPairs, tCSecretNames, "ok", tDroppedCode, pLimitsClass, tCSecretDeclared, $Get(tCPairsResolved, 0))
            Set pAnswered = ..ClientResult(pBlock, 0, tDroppedJson)
            Quit
        }
        Set pLastSeq = tAnnounceSeq

        Set tRequestSC = ##class(OcuPilot.Kernel.State.Nav).GuardedRequest(pKey, tAnnounceSeq, tRoute, tEntityId, $Get(tCriterion), $Get(tCriteria))
        If $$$ISERR(tRequestSC) {
            Set tSC = tRequestSC
            Quit
        }

        Set tWaitLimit = +$Parameter(pLimitsClass, "NAVWAITSECONDS")
        Set tWaitStarted = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
        Set tOutcome = ""
        Set tOutcomeCode = ""
        For {
            If ..Boundary(pKey, pUser, pReadOnly, pResources, pStartedSeconds, pTokens, .tBState, .tBCode) {
                ; Named for what it was waiting on, the same way a stop caught before dispatch is
                ; (this class's Design Notes, AD-30): the running announce and tool steps are left
                ; as they are and settle to `error` on read through the client's own settledSteps
                ; conversion once the turn is terminal; this new step is the explicit record of
                ; where the turn actually stopped. The directive itself is settled `unavailable`
                ; for the same reason the lapse branch below settles its own: an unsettled row
                ; keeps GuardedView emitting `navigation` for the whole retention window, so a
                ; browser still polling would act on a directive this turn has abandoned.
                Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(pKey, tAnnounceSeq, "unavailable", ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE, .tStopClaimed)
                Set tStopSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(pKey, "tool", tToolName, "stopped", "", "", "", pLimitsClass, .tStopSeq, .tStopStored, pTarget, pArguments, , , , pArgumentsTruncated)
                If $$$ISOK(tStopSC) && tStopStored Set pLastSeq = tStopSeq
                Do ..RecordClientRow(pKey, pUser, pRoute, tToolName, pTarget, tCInput, tCDeclaredPairs, tCCallPairs, tCSecretNames, "stopped", tBCode, pLimitsClass, tCSecretDeclared, $Get(tCPairsResolved, 0))
                Set pTurnState = tBState
                Set pTurnCode = tBCode
                Quit
            }
            Set tPendingSC = ##class(OcuPilot.Kernel.State.Nav).GuardedPending(pKey, .tPendingSeq, .tPendingRoute, .tPendingEntity, .tPendingSettled, .tPendingOutcome, .tPendingCode)
            If $$$ISERR(tPendingSC) {
                Do ..LogFault("turn " _ pKey _ ": the navigation directive could not be read while waiting", tPendingSC, ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE)
                Set tOutcome = "unavailable"
                Set tOutcomeCode = ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE
                ; Settle it here too, the same as the wait-limit branch below -- otherwise the Nav
                ; row is left open after the turn has already reported it lapsed, and a later
                ; genuine browser settle for this same directive would still be claimed.
                Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(pKey, tAnnounceSeq, tOutcome, tOutcomeCode, .tClaimed)
                Quit
            }
            If tPendingSettled && (+tPendingSeq = tAnnounceSeq) {
                Set tOutcome = tPendingOutcome
                Set tOutcomeCode = tPendingCode
                Quit
            }
            If (##class(OcuPilot.Kernel.State.Turn).NowSeconds() - tWaitStarted) >= tWaitLimit {
                Set tOutcome = "unavailable"
                Set tOutcomeCode = ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE
                Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(pKey, tAnnounceSeq, tOutcome, tOutcomeCode, .tClaimed)
                If 'tClaimed {
                    ; The browser's own settle won the race in the instant between this pass's own
                    ; GuardedPending read above and this lapse check -- read back what it actually
                    ; recorded rather than reporting "unavailable" for a call that just succeeded.
                    Do ##class(OcuPilot.Kernel.State.Nav).GuardedPending(pKey, .tRacedSeq, .tRacedRoute, .tRacedEntity, .tRacedSettled, .tRacedOutcome, .tRacedCode)
                    If tRacedSettled && (+tRacedSeq = tAnnounceSeq) {
                        Set tOutcome = tRacedOutcome
                        Set tOutcomeCode = tRacedCode
                    }
                }
                Quit
            }
            Hang 0.25
        }
        If pTurnState '= "" Quit

        Set tAnnounceStatus = $Select(tOutcome = "opened": "ok", 1: "error")
        Set tAnnounceCode = $Select(tOutcome = "opened": "", 1: tOutcomeCode)
        ; The entity id is carried through unchanged on settle (pText) -- GuardedUpdate's own
        ; ApplyContent unconditionally overwrites Text, so passing "" here would erase the row
        ; selection an "opened" announcement already recorded, and any later read (a poll before
        ; the next render, a reload) would then render the no-entity phrasing for a navigation
        ; that did select a row.
        Set tUpdateSC = ##class(OcuPilot.Kernel.State.Step).GuardedUpdate(pKey, tAnnounceSeq, tAnnounceStatus, "", tEntityId, tAnnounceCode, pLimitsClass)
        If $$$ISERR(tUpdateSC) {
            Set tSC = tUpdateSC
            Quit
        }

        Set tDetail = {}
        Do tDetail.%Set("route", tRoute, "string")
        Do tDetail.%Set("entityId", tEntityId, "string")
        Set tContentJson = ""
        Do $ClassMethod(..DispatchClass(), "SettleClient", tDetail, tOutcome, tOutcomeCode, .tContentJson)

        Set pCode = tAnnounceCode
        Do ..RecordClientRow(pKey, pUser, pRoute, tToolName, pTarget, tCInput, tCDeclaredPairs, tCCallPairs, tCSecretNames, "ok", tAnnounceCode, pLimitsClass, tCSecretDeclared, $Get(tCPairsResolved, 0))
        Set tFinishSC = ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(pKey, pSeq, tToolName, "ok", "", pLimitsClass, pTarget, pArguments, "", "", "", pArgumentsTruncated)
        If $$$ISERR(tFinishSC) {
            Set tSC = tFinishSC
            Quit
        }
        Set pAnswered = ..ClientResult(pBlock, 0, tContentJson)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The provider key and model definition <var>pDefinitionId</var> names, read the way
/// <method>IterationCap</method> reads the same row. A definition that cannot be read contributes
/// <code>""</code> to each, and the turn is unaffected: the ledger never fails a turn.</p>
ClassMethod Definition(pDefinitionId As %String, Output pProvider As %String, Output pModel As %String)
{
    Set pProvider = ""
    Set pModel = ""
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(pDefinitionId, .tExists)
        If $$$ISERR(tSC) || 'tExists Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pDefinitionId, .tRow)
        If $$$ISERR(tSC) || '$IsObject(tRow) Quit
        Set pProvider = tRow.Provider
        Set pModel = tRow.Model
        Set tRow = ""
    } Catch ex {
        Set pProvider = ""
        Set pModel = ""
    }
}

/// <p>Record one provider call in the agent ledger (Story 4.9). <var>pResponse</var> is the call's
/// own response object and <var>pFault</var> its fault, either of which may be absent; a fault is
/// what makes the row <code>error</code> and carries its machine code.</p>
/// <p><var>pHttpStatus</var> is the port's own status output, which is the only one a refused call
/// has: <method>OcuPilot.Port.ProviderPort.Invoke</method> leaves <var>pResponse</var> blank on
/// every refusal while still answering the status it read, so reading it off the response alone
/// would record <code>0</code> for every failure rather than only for a call never made.</p>
/// <p><b><code>Do</code>-and-log, never propagated</b> (AD-15): a ledger failure logs and the turn
/// carries on.</p>
ClassMethod RecordProviderRow(pKey As %String, pUser As %String, pRoute As %String, pProvider As %String, pModel As %String, pIteration As %Integer, pResponse As OcuPilot.Kernel.Provider.Response, pFault As %DynamicObject, pLimitsClass As %String, pHttpStatus As %Integer = 0) [ Private ]
{
    Try {
        Set tRequestTokens = $Select($IsObject(pResponse): +pResponse.RequestTokens, 1: 0)
        Set tResponseTokens = $Select($IsObject(pResponse): +pResponse.ResponseTokens, 1: 0)
        Set tHttpStatus = $Select($IsObject(pResponse) && (+pResponse.HttpStatus > 0): +pResponse.HttpStatus, 1: +pHttpStatus)
        Set tFailed = $IsObject(pFault)
        Do $ClassMethod(..LedgerClass(), "RecordProviderCall", pKey, pUser, pRoute, pProvider, pModel, pIteration, tRequestTokens, tResponseTokens, $Select(tFailed: "error", 1: "ok"), $Select(tFailed: pFault.code, 1: ""), tHttpStatus, pLimitsClass)
    } Catch ex {
        Do ..LogFault("turn " _ pKey _ ": a provider call could not be recorded in the agent ledger", ex.AsStatus(), ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
    }
}

/// <p>Record one tool call this method refused before it reached the dispatcher (Story 4.9) -- a
/// stop caught at the per-call boundary, and the reply-budget refusal.</p>
/// <p><b>The row records the requirement the refusal knows, never one nobody read</b> (DW-1120,
/// DW-1305): the tool's own declared pairs when <var>pTool</var> resolved, under the sense
/// <code>declared</code>, and empty under that same sense when it did not -- which stays withheld
/// cross-user. A tool that resolved and declares no pair records <code>none</code> instead, because
/// its requirement was read and is nothing.
/// Neither refusal this method serves is a pair denial -- a pair denial happens inside
/// <class>OcuPilot.Kernel.Agent.Dispatch</class>, which records its own pairs -- so there is no
/// failed pair to record here. An empty recorded requirement is withheld from a cross-user reader
/// rather than released, so the row that can state nothing fails closed.</p>
/// <p><b>The tool's secret-argument declaration is read the same way.</b> <var>pTool</var> is
/// whatever the refusal site's own <code>ResolveWire</code> answered, so layer 1 of the redaction
/// runs for every call whose wire name resolved (AD-3): a name pattern cannot see a value in a
/// field called <code>Value</code>. A wire name that resolved no tool classified nothing, and the
/// ledger withholds such a row's arguments whole rather than storing a blob the name pattern alone
/// has seen.</p>
ClassMethod RecordRefusedRow(pKey As %String, pUser As %String, pRoute As %String, pName As %String, pTarget As %String, pInput As %DynamicAbstractObject, pStatus As %String, pCode As %String, pLimitsClass As %String, pTool As %DynamicObject = "") [ Private ]
{
    Try {
        Set tSecretNames = ""
        Set tClassified = 0
        Set tDeclaredPairs = ""
        If $IsObject(pTool) {
            Set tRegistry = $ClassMethod(..DispatchClass(), "RegistryClass")
            Set tSecretNames = $ClassMethod(tRegistry, "SecretArguments", pTool, .tSecretDeclared)
            Set tClassified = ''tSecretDeclared
            Set tDeclaredPairs = $ClassMethod(tRegistry, "RequiredPairs", pTool, .tPairsResolved)
            If 'tPairsResolved Set tDeclaredPairs = ""
        }
        Set tSense = $ClassMethod(..LedgerClass(), "SenseFor", $ClassMethod(..LedgerClass(), "SenseDeclared"), tDeclaredPairs, $Get(tPairsResolved, 0))
        Do $ClassMethod(..LedgerClass(), "RecordToolCall", pKey, pUser, pRoute, pName, pTarget, pInput, tDeclaredPairs, "", tSecretNames, pStatus, pCode, pLimitsClass, tClassified, tSense)
    } Catch ex {
        Do ..LogFault("turn " _ pKey _ ": a refused tool call could not be recorded in the agent ledger", ex.AsStatus(), ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
    }
}

/// <p>Record one client-fulfilled tool call at the point its outcome is known (Story 4.9), with the
/// pairs and the secret-argument declaration
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> read for it.
/// <var>pClassified</var> is that resolver's own <code>pSecretDeclared</code> answer, 0 for a wire
/// name it resolved no tool for; the ledger then withholds the row's arguments whole.</p>
/// <p><var>pPairsResolved</var> -- a <b>different</b> answer from the same resolver -- is what says
/// the tool's requirement was read at all, so a resolved tool whose pairs are empty records
/// <code>none</code> and every refusal that returned before the pairs were read keeps
/// <code>checked</code> with an empty set, which stays withheld (DW-1305). It is deliberately not
/// <var>pClassified</var>: the secret-argument declaration is answered three refusals earlier, so
/// reading it as "the requirement was read" releases a user-mismatch, a governance-gate error and a
/// tool denial to every cross-user reader.</p>
ClassMethod RecordClientRow(pKey As %String, pUser As %String, pRoute As %String, pName As %String, pTarget As %String, pInput As %DynamicAbstractObject, pDeclaredPairs As %List, pCallPairs As %List, pSecretNames As %List, pStatus As %String, pCode As %String, pLimitsClass As %String, pClassified As %Boolean = 0, pPairsResolved As %Boolean = 0) [ Private ]
{
    Try {
        Set tSense = $ClassMethod(..LedgerClass(), "SenseFor", $ClassMethod(..LedgerClass(), "SenseChecked"), pDeclaredPairs _ pCallPairs, pPairsResolved)
        Do $ClassMethod(..LedgerClass(), "RecordToolCall", pKey, pUser, pRoute, pName, pTarget, pInput, pDeclaredPairs, pCallPairs, pSecretNames, pStatus, pCode, pLimitsClass, pClassified, tSense)
    } Catch ex {
        Do ..LogFault("turn " _ pKey _ ": a client tool call could not be recorded in the agent ledger", ex.AsStatus(), ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
    }
}

/// <p>The secret-argument declaration <var>pTool</var> answers
/// (<method>OcuPilot.Screen.Tool.Base.SecretArguments</method>), or <code>""</code> when the wire
/// name resolved no tool -- nothing was declared in that case, and there is nothing to read it
/// off of.</p>
ClassMethod SecretNamesOf(pTool As %DynamicObject = "") As %List [ Private ]
{
    Set tNames = ""
    Try {
        If '$IsObject(pTool) Quit
        Set tNames = $ClassMethod($ClassMethod(..DispatchClass(), "RegistryClass"), "SecretArguments", pTool, .tDeclared)
    } Catch ex {
        Set tNames = ""
    }
    Quit tNames
}

/// <p>The <code>tool_result</code> block for a client-fulfilled call, the same shape
/// <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method> builds for an instance-fulfilled one.</p>
ClassMethod ClientResult(pBlock As %DynamicObject, pIsError As %Boolean, pContent As %String) As %DynamicObject [ Private ]
{
    Set tResult = {}
    Do tResult.%Set("type", "tool_result", "string")
    Do tResult.%Set("tool_use_id", $Select($IsObject(pBlock) && (pBlock.%Get("id") '= ""): pBlock.%Get("id"), 1: "unknown"), "string")
    Do tResult.%Set("is_error", ''pIsError, "boolean")
    Do tResult.%Set("content", pContent, "string")
    Quit tResult
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
