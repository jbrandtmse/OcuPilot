/// <p>Where a proposal becomes a write (AD-34, AD-40, AD-6, AD-7). One user-originated request
/// claims one stored proposal, and the claim is a single conditional update exactly one caller
/// wins: it burns the token, writes the terminal state and cancels every sibling on the same
/// scoped target in one transaction. The vendor call follows that commit.</p>
/// <p><b>Confirm is not a tool.</b> No method here is reachable from the registry, and the first
/// thing <method>Confirm</method> does is refuse a process carrying
/// <method>OcuPilot.Kernel.Proposal.Caller.IsTurn</method> -- the explicit barrier AD-40 asks for,
/// explicit because AD-1 removed the HTTP one. The agent cannot approve its own proposal.</p>
/// <p><b>The executed write is the stored one</b> (AD-6). The arguments, the payload, the target
/// and the digest all come from the row; the request carries the proposal id in its route and, in
/// its body, only the fields the descriptor declared secret-typed for that tool. Any other key is
/// rejected outright rather than ignored, and the identifying key is never accepted at all.</p>
/// <p><b>Every gate is evaluated here, at the write, never at the mint</b> (AD-40): the AD-10
/// prohibited-set seam, the restraint verdict, the declared
/// <code>(resource, permission)</code> pairs, the conversation, the agent definition's version and
/// the fingerprint re-read. All six run before the claim commits, against state that may have moved
/// since the proposal was minted.</p>
/// <p><b>The marker and the ledger row are the executor's, and neither can fail the write</b>
/// (AD-15, AD-41). The ledger row opens before the port call and is finalized after it with what
/// was actually executed; the audit marker is emitted once, here, after the write reads OK, and its
/// return value is checked because an unregistered triple drops the event silently. A failure of
/// either is recorded on the row and answered as <code>auditMarked</code>; neither ever changes
/// the status the caller receives.</p>
/// <p><b>Why the port call follows the commit.</b> AD-34's transition is the point of no return --
/// burning the token and committing to the write. A vendor call inside a <code>TSTART</code> frame
/// is refused on two grounds: the project's ObjectScript rule forbids a side effect inside a
/// transaction, and the vendor's own endpoints run transactions of their own, so a rollback could
/// leave a vendor write half-undone. Single-use survives either way -- a claim that commits and a
/// write that then fails leaves the proposal burned and confirmed, refused on any re-attempt.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method>, <method>StoreClass</method>,
/// <method>LedgerClass</method>, <method>EventClass</method>, <method>LimitsClass</method>,
/// <method>ToolRegistryClass</method> and <method>ProhibitedClassName</method>. The first two are
/// <class>OcuPilot.Kernel.Proposal.Mint</class>'s own; <method>ToolRegistryClass</method> answers
/// the same class <method>OcuPilot.Kernel.Proposal.Mint.RegistryClass</method> does, named for the
/// registry it resolves because this class carries five other <code>*Class</code> seams beside it.
/// Production overrides none of them.</p>
Class OcuPilot.Kernel.Proposal.Confirm Extends %RegisteredObject
{

/// <p>The admin request type the target's fresh re-read is made with when the proposal's tool
/// declares none (AD-36's single-object <code>GET</code>). The tool's own
/// <method>OcuPilot.Screen.Tool.Write.ReadType</method> is what the re-read uses, so the digest
/// compared here covers the same read the mint digested (AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The admin request type the confirmed write is issued with when the proposal's tool declares
/// none. It resolves through the vendor endpoint's own <code>TYPE&lt;suffix&gt;</code> parameter,
/// exactly as the read does (<parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter>); an
/// action-style tool declares the vendor's own request type through
/// <method>OcuPilot.Screen.Tool.Write.WriteType</method> and sends no body (AD-51).</p>
Parameter WRITETYPE = "PUT";

/// <p>The class a write tool's port declaration lives on, whose own value is the default every
/// shipped tool carries (AD-52).</p>
Parameter WRITETOOLBASE = "OcuPilot.Screen.Tool.Write";

/// <p>The port the fresh re-read and the write go through when the proposal's tool declares the
/// base's own default (AD-52). Overridable so a fixture can answer a known object and record what
/// was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The port <var>pToolClass</var> declares its target lives behind (AD-52), or
/// <method>PortClass</method> where it declares the base's own default, names no class, or cannot
/// be asked.</p>
/// <p>The fingerprint re-read and the write itself both resolve through this one answer, so a
/// confirm can never compare a digest taken from one port against a write issued at another.</p>
ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Set tPort = ""
    Try {
        If pToolClass '= "" Set tPort = $ClassMethod(pToolClass, "PortClass")
    } Catch {
        Set tPort = ""
    }
    If (tPort = "") || (tPort = $Parameter(..#WRITETOOLBASE, "PORTCLASS")) Quit ..PortClass()
    Quit tPort
}

/// <p>The proposal store. Overridable for the same reason; production never overrides it.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Propose"
}

/// <p>The agent ledger the confirmed write's own row is opened and finalized through (AD-41).
/// Overridable so a test can observe what a transition recorded without reading the store;
/// production never overrides it.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Ledger"
}

/// <p>The audit emitter the write's marker is written through (AD-15). Overridable for the reason
/// <class>OcuPilot.Test.EventProbe</class> exists -- a dropped emission produces no row and no
/// console line of its own, so the report is otherwise unobservable. Production never overrides
/// it.</p>
ClassMethod EventClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Event"
}

/// <p>The bounds the confirmed write's ledger row is written under (AD-41). Overridable so a test
/// can drive the row cap; production never overrides it.</p>
ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Limits"
}

/// <p>The tool registry <method>ChannelProblem</method> resolves a proposal's tool through, to ask
/// that tool what its descriptor declares secret. Overridable so a test can arm the closed
/// channel's accept arm against a probe screen's <b>real</b> declaration rather than against a name
/// list it supplies itself; production never overrides it.</p>
ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>AD-10's prohibited set, as <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method>
/// answers it -- <class>OcuPilot.Kernel.Proposal.Prohibited</class>.</p>
/// <p>Overridable for the reason <method>PortClass</method> and <method>StoreClass</method> are: a
/// fixture answers with the set reading an armed target, so the refusal branch is driven without
/// the instance's own. Production never overrides it, and the set itself is still named in exactly
/// one place (AD-10).</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass()
}

/// <p>Confirm proposal <var>pProposalId</var> for <var>pUser</var>, with
/// <var>pSuppliedSecrets</var> as the body the request carried.</p>
/// <p>On success the status is OK, <var>pHttpStatus</var> 200 and <var>pResult</var>
/// <code>{proposalId, state, closedReason, confirmedAt, auditMarked}</code> -- the last being
/// whether the write's audit marker landed a row, which never changes the status (AD-15). On a refusal the status is an
/// error, <var>pCode</var> is the machine code, <var>pHttpStatus</var> the HTTP status it is
/// rendered at, and <var>pDetail</var> carries the structured detail that code owns
/// (<code>failedPair</code> for a privilege refusal) or is <code>""</code>.</p>
/// <p><b>Caller contract:</b> <var>pUser</var> is the authenticated caller, read by the handler as
/// <code>$Username</code> and never taken from the body. <var>pSuppliedSecrets</var> is the parsed
/// body -- a flat object, or <code>""</code> for none. Every refusal before the claim leaves the
/// row exactly as it was; a fingerprint mismatch is the one refusal that closes it.</p>
ClassMethod Confirm(pProposalId As %String, pSuppliedSecrets As %DynamicObject, pUser As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String, Output pDetail As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pCode = ""
    Set pDetail = ""
    Set tSC = $$$OK
    Try {
        ; AD-40. A request process has never run a turn, so this is the whole barrier.
        If ##class(OcuPilot.Kernel.Proposal.Caller).IsTurn() {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, .pHttpStatus, .pCode)
            Quit
        }

        ; AD-6. The row is read first only to learn which tool's declaration the channel is closed
        ; to; a row this caller cannot claim falls through to the claim below, which answers
        ; UNKNOWN or NOTYOURS without this step saying anything about the row.
        Set tPeekSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tPeeked, .tPeek)
        If $$$ISERR(tPeekSC) {
            Set tSC = tPeekSC
            Quit
        }
        If tPeeked && ($Get(tPeek("user")) = pUser) {
            Set tChannelSC = ..ChannelProblem($Get(tPeek("toolName")), pSuppliedSecrets, .tSecretNames, .tProblem)
            If $$$ISERR(tChannelSC) {
                Set tSC = tChannelSC
                Quit
            }
            If tProblem {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Kernel.Proposal.Write).#CLOSEDCHANNEL, .pHttpStatus, .pCode)
                Quit
            }
        }

        ; The shipped claim gate: the token resolved from the row, the minting user, the window,
        ; the burn and the minting turn's own outcome.
        Set tClaimSC = ##class(OcuPilot.Kernel.Proposal.Write).ClaimById(pProposalId, pUser, .tRow, .tClaimCode)
        If $$$ISERR(tClaimSC) {
            If tClaimCode = "" {
                Set tSC = tClaimSC
                Quit
            }
            Set tSC = ..Refuse(..StatusForClaim(tClaimCode), tClaimCode, .pHttpStatus, .pCode)
            Quit
        }

        Set tSC = ..Transition(pProposalId, pUser, .tRow, pSuppliedSecrets, .pResult, .pHttpStatus, .pCode, .pDetail)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the confirm failed: " _ ex.DisplayString(), .pHttpStatus, .pCode)
    }
    Quit tSC
}

/// <p>Cancel proposal <var>pProposalId</var> for <var>pUser</var>: the user's own decision not to
/// apply it. On success <var>pResult</var> is the same shape <method>Confirm</method> answers, with
/// the row closed <code>canceled</code> reason <code>you</code>.</p>
/// <p>Refused from a turn for the reason confirm is (AD-40): a cancel the agent could make is a
/// decision the agent made. An id no live row of this caller's carries is
/// <parameter>OcuPilot.Kernel.Proposal.Write.UNKNOWN</parameter> at 404 -- a row already terminal
/// and an id nobody minted are the same answer, so a cancel says nothing about either.</p>
ClassMethod Cancel(pProposalId As %String, pUser As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If ##class(OcuPilot.Kernel.Proposal.Caller).IsTurn() {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, .pHttpStatus, .pCode)
            Quit
        }
        Set tCloseSC = $ClassMethod(..StoreClass(), "GuardedClose", pProposalId, pUser, $Parameter(..StoreClass(), "REASONYOU"), .tClosed)
        If $$$ISERR(tCloseSC) {
            Set tSC = tCloseSC
            Quit
        }
        If 'tClosed {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, .pHttpStatus, .pCode)
            Quit
        }
        Set tSC = ..Answer(pProposalId, .pResult, .pHttpStatus, .pCode)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the cancel failed: " _ ex.DisplayString(), .pHttpStatus, .pCode)
    }
    Quit tSC
}

/// <p>The gates, the claim and the write, in that order. <var>pRow</var> is the stored proposal as
/// <method>OcuPilot.Kernel.Proposal.Write.ClaimById</method> answered it.</p>
/// <p>Every gate here is evaluated against state <b>as it is now</b>, never against an answer the
/// mint recorded (AD-40). The claim is the last thing before the commit, and the port call is the
/// first thing after it.</p>
ClassMethod Transition(pProposalId As %String, pUser As %String, ByRef pRow, pSuppliedSecrets As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String, Output pDetail As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tTool = ""
        Set tResolveSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Get(pRow("toolName")), .tTool)
        If $$$ISERR(tResolveSC) || '$IsObject(tTool) {
            Set tSC = ..Internal("the proposal names a tool this instance does not carry", .pHttpStatus, .pCode)
            Quit
        }
        Set tToolClass = tTool.%Get("class")

        ; The declared secret-typed names, re-read from the tool rather than carried in from the
        ; channel check, so the merge below and that check read one declaration.
        Set tSecretNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tSecretsDeclared)
        If 'tSecretsDeclared {
            Set tSC = ..Internal("the secret arguments of " _ $Get(pRow("toolName")) _ " could not be read", .pHttpStatus, .pCode)
            Quit
        }

        ; AD-8: the declared pairs, re-checked at the moment of the call rather than at the mint.
        ;
        ; **First of the three gates, and that order is load-bearing.** The prohibited set below
        ; reads live state through the port (AD-10), and the port's own gate requires the very pair
        ; this check names -- so a caller who has lost it reached that read first and was answered
        ; a generic internal failure, which is the one thing AD-8 forbids: "a denial names the pair
        ; that failed, so the UX can say which privilege is missing". Asked here, the caller is
        ; told which privilege it needs, and the instance spends no live read deciding whether a
        ; change it may not make at all is also prohibited (DW-1208, Story 5.8).
        ;
        ; It is therefore also above the restraint verdict below, which is a deliberate consequence
        ; and not an accident of the move: AD-30 requires a confirm to re-evaluate read-only and
        ; refuse, which it does either way, while AD-8 requires a denial to name the pair that
        ; failed. So a caller who is both under read-only and short of a pair is told about the
        ; pair. Both orders refuse and neither reaches the port; the order is pinned in both
        ; directions by ProposalConfirm's TestThePrivilegeGateAnswersBeforeTheProhibitedSet and
        ; TestThePrivilegeGateAnswersBeforeTheRestraintVerdict, so it cannot drift back silently.
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tPairsResolved)
        If 'tPairsResolved {
            Set tSC = ..Internal("the privilege pairs of " _ $Get(pRow("toolName")) _ " could not be read", .pHttpStatus, .pCode)
            Quit
        }
        ; AD-8, AD-48. A tool whose requirement depends on its own argument -- the namespace this
        ; delete names -- declares that half through ArgumentPairs, and the confirm resolves it
        ; from the STORED arguments so it re-checks the set the dispatcher checked at the call.
        ; Empty for every tool whose requirement is its screen's alone, so their check is
        ; unchanged. Without it such a caller passes this gate short of a pair the port's own gate
        ; requires, reaches the prohibited set's live read, and is answered the generic internal
        ; failure AD-8 exists to prevent.
        Set tArgumentPairs = ##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tTool, ..ParsedObject($Get(pRow("arguments"))), .tArgumentsResolved)
        If 'tArgumentsResolved {
            Set tSC = ..Internal("the argument privilege pairs of " _ $Get(pRow("toolName")) _ " could not be read", .pHttpStatus, .pCode)
            Quit
        }
        Set tPairs = tPairs _ tArgumentPairs
        Set tFailedPair = ..MissingPair(pUser, tPairs)
        If tFailedPair '= "" {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, .pHttpStatus, .pCode)
            Set pDetail = {}
            Do pDetail.%Set("failedPair", tFailedPair, "string")
            Quit
        }

        ; AD-10's single call site: asked inside the transition and before the port call. The set
        ; is handed the stored row's tool, target, payload and diff, and nothing of the request's.
        Set tProhibited = ..ProhibitedClassName()
        If tProhibited '= "" {
            Set tProhibitSC = $ClassMethod(tProhibited, "Prohibits", $Get(pRow("toolName")), $Get(pRow("targetRef")), $Get(pRow("payload")), $Get(pRow("diff")), .tProhibits, .tProhibitCode)
            If $$$ISERR(tProhibitSC) {
                ; The underlying text, not just "could not be read": the set reads live state, so
                ; the cause is a property of the instance at this moment and is the only thing a
                ; reader of the log can act on. Internal() renders a generic reason to the caller
                ; and logs the detail (AD-12), so this reaches the log and never the client.
                Set tSC = ..Internal("the prohibited set could not be read: " _ $System.Status.GetErrorText(tProhibitSC), .pHttpStatus, .pCode)
                Quit
            }
            If tProhibits {
                Set tSC = ..Refuse(403, tProhibitCode, .pHttpStatus, .pCode)
                Quit
            }
        }

        ; AD-30. The kill switch, enforced read-only and the definition's own read-only flag, in
        ; the one place that answers them; this renders the verdict and derives no part of it.
        Kill tVerdict
        Set tVerdictSC = ##class(OcuPilot.Kernel.Restraint).Verdict(pUser, $Get(pRow("definitionId")), .tVerdict)
        If $$$ISERR(tVerdictSC) {
            Set tSC = ..Internal("the restraint verdict could not be read", .pHttpStatus, .pCode)
            Quit
        }
        If +$Get(tVerdict("blocked")) {
            If $Get(tVerdict("code")) = "" {
                Set tSC = ..Internal("the restraint verdict blocked with no code", .pHttpStatus, .pCode)
                Quit
            }
            Set tSC = ..Refuse(403, tVerdict("code"), .pHttpStatus, .pCode)
            Quit
        }

        ; FR-17: the conversation. The proactive close at turn start and at conversation create is
        ; the mechanism; this is the backstop that reads its result and the newer turn directly.
        Set tConvSC = ..ConversationMoved($Get(pRow("convKey")), $Get(pRow("turnKey")), pUser, pProposalId, .tMoved)
        If $$$ISERR(tConvSC) {
            Set tSC = ..Internal("the proposal's conversation could not be read", .pHttpStatus, .pCode)
            Quit
        }
        If tMoved {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Kernel.Proposal.Write).#CONVERSATION, .pHttpStatus, .pCode)
            ; The proactive close at turn start has already closed the row, so the card reads its
            ; own state from the instance rather than inferring one from the code.
            Do ..ClosedDetail(pProposalId, .pDetail)
            Quit
        }

        ; FR-17: the agent definition in force. "" is "no row", never 0, on both sides.
        Set tDefinitionSC = ..DefinitionMoved($Get(pRow("definitionId")), $Get(pRow("definitionVersion")), .tDefinitionMoved)
        If $$$ISERR(tDefinitionSC) {
            Set tSC = ..Internal("the agent definition's version could not be read", .pHttpStatus, .pCode)
            Quit
        }
        If tDefinitionMoved {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Kernel.Proposal.Write).#DEFINITION, .pHttpStatus, .pCode)
            Quit
        }

        ; AD-6: the target is read fresh, the stored arguments are merged over it again, and the
        ; digest is re-taken. A mismatch is terminal -- the row closes and Re-propose is the
        ; accommodation.
        Set tPrintSC = ..FingerprintMatches(tTool, .pRow, .tMatches, .tEndpoint, .tIdParam, .tIdValue)
        If $$$ISERR(tPrintSC) {
            Set tSC = ..Internal("the proposal's target could not be re-read: " _ $System.Status.GetErrorText(tPrintSC), .pHttpStatus, .pCode)
            Quit
        }
        If 'tMatches {
            Set tCloseSC = $ClassMethod(..StoreClass(), "GuardedClose", pProposalId, pUser, $Parameter(..StoreClass(), "REASONTARGETCHANGED"), .tClosed)
            If $$$ISERR(tCloseSC) {
                Set tSC = ..Internal("the changed target's proposal could not be closed", .pHttpStatus, .pCode)
                Quit
            }
            Set tSC = ..Refuse(409, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, .pHttpStatus, .pCode)
            Do ..ClosedDetail(pProposalId, .pDetail)
            Quit
        }

        ; AD-34. One conditional update, one winner; the burn, the terminal state and the sibling
        ; cancel commit together.
        Set tVersionSC = $ClassMethod(..StoreClass(), "GuardedRowVersion", pProposalId, .tVersion)
        If $$$ISERR(tVersionSC) {
            Set tSC = ..Internal("the proposal's version could not be read", .pHttpStatus, .pCode)
            Quit
        }
        Set tClaimSC = $ClassMethod(..StoreClass(), "GuardedClaimAndClose", pProposalId, tVersion, $Get(pRow("targetRef")), .tWon, .tTerminal)
        If $$$ISERR(tClaimSC) {
            Set tSC = ..Internal("the claim could not be made: " _ $System.Status.GetErrorText(tClaimSC), .pHttpStatus, .pCode)
            Quit
        }
        If 'tWon {
            ; The loser reads the row's terminal state and is refused with it. Never retried.
            Set tSC = ..Refuse(409, ##class(OcuPilot.Kernel.Proposal.Write).#BURNED, .pHttpStatus, .pCode)
            Do ..ClosedDetail(pProposalId, .pDetail)
            Quit
        }

        ; AD-35: the supplied secrets are merged in here and nowhere else -- never stored, never
        ; logged, never part of the digest that was just compared.
        ;
        ; AD-51: an action-style write sends no body at all, so there is nothing to merge a secret
        ; into and nothing for the ledger to name. The vendor's own request type reads no body
        ; (OcuPilot.Port.AdminPort.BODYLESSTYPES), and a body sent anyway would be a payload the
        ; user never reviewed.
        Set tSendsBody = ..ToolSendsBody(tToolClass)
        Set tBody = ""
        If tSendsBody Set tBody = ..WithSecrets($Get(pRow("payload")), pSuppliedSecrets, tSecretNames)
        Kill tQuery
        Set tQuery(tIdParam) = tIdValue
        ; AD-52. A port that addresses a set rather than an object needs more than the identifying
        ; parameter, and what it needs is the tool's own declaration read off the STORED payload --
        ; the one the fingerprint just compared. Empty for every tool that ships against an admin
        ; endpoint, so their query is byte-identical.
        Do ..ToolPortQuery(tToolClass, $Get(pRow("payload")), .tQuery)

        ; AD-41: the row is opened BEFORE the port call and finalized after it. A row that only
        ; ever appeared on success could not record a write that raised mid-flight; the `pending`
        ; row this leaves is that trace. AD-3: the field names are taken from the body with the
        ; descriptor's declared secret names excluded here, at write time, never redacted later.
        Set tFieldNames = ..FieldNames(tBody, tSecretNames)
        Set tLedgerKey = ""
        Do $ClassMethod(..LedgerClass(), "OpenConfirmedWrite", $Get(pRow("turnKey")), pUser, $Get(pRow("toolName")), $Get(pRow("targetRef")), ..LimitsClass(), .tLedgerKey, tPairs)
        ; The window the marker and the vendor's own change row are joined inside: taken on the
        ; instance immediately before the call, so the vendor row is the *Change row for this
        ; target and this user at or after it.
        Set tWrittenAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()

        Set tWriteSC = $ClassMethod(..PortClassOf(tToolClass), "Invoke", tEndpoint, ..ToolWriteType(tToolClass), .tQuery, tBody, .tWritten, .tWriteHttp, .tWriteFault)
        If $$$ISERR(tWriteSC) {
            ; The claim has committed and the token is spent: the proposal stays confirmed and the
            ; port's own normalized envelope is what the caller is answered with. There is no
            ; automatic re-attempt, which is what single-use means.
            Set pHttpStatus = +$Get(tWriteHttp)
            If pHttpStatus = 0 Set pHttpStatus = 500
            Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
            If $IsObject($Get(tWriteFault)) && (tWriteFault.%Get("code") '= "") Set pCode = tWriteFault.%Get("code")
            ; The row closed even though the write did not, so the caller is told its new state --
            ; the same detail the other two closing refusals carry. Without it a card would fall
            ; back to the state its last poll saw and offer Confirm again on a spent token.
            Do ..ClosedDetail(pProposalId, .pDetail)
            ; The write did not happen, so no marker is emitted and the row makes no claim about
            ; marking. The row stops being `pending`, which is what separates "it failed" from
            ; "nobody can account for it".
            Do $ClassMethod(..LedgerClass(), "FinalizeConfirmedWrite", tLedgerKey, "error", pCode, $Get(pRow("targetRef")), tFieldNames, tPairs, $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDNONE"))
            Set tSC = tWriteSC
            Quit
        }

        ; AD-15. The write has succeeded; this is the one place a marker is emitted, so a write
        ; made any other way emits none. The return value is checked here because
        ; $System.Security.Audit answers 0 and drops the event when its triple is unregistered,
        ; with no error and no log line -- and the marker never fails the write and never
        ; propagates: tSC is untouched on either arm.
        Set tMarkSC = $ClassMethod(..EventClass(), "RecordAgentWrite", pProposalId, $Get(pRow("toolName")), $Get(pRow("targetRef")), pUser, tWrittenAt, tFieldNames, .tEmitted)
        Set tMarked = $$$ISOK(tMarkSC)
        Do $ClassMethod(..LedgerClass(), "FinalizeConfirmedWrite", tLedgerKey, "ok", "", $Get(pRow("targetRef")), tFieldNames, tPairs, $Select(tMarked: $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), 1: $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDNO")))
        ; The emission's own answer is the instance's answer to "are writes being marked", and it
        ; is the only one a least-privileged process can get. Recorded so the panel's banner is
        ; showing on the next read; a refresh that fails is logged and never propagated.
        ; Only when the instance was actually asked (DW-1379): a marker that failed before the
        ; audit call -- an unparseable stored reference -- says nothing about the instance, and
        ; recording it would show the banner to every user over one write's own fault. That write
        ; is still reported as not marked on its own card and its own ledger row, which is where a
        ; per-write failure belongs.
        If $Get(tEmitted, 0) Do $ClassMethod(..EventClass(), "RecordMarking", tMarked)

        Set tSC = ..Answer(pProposalId, .pResult, .pHttpStatus, .pCode, $Select(tMarked: 1, 1: 0), ..ToolChangeAction(tToolClass))
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the confirm transition failed: " _ ex.DisplayString(), .pHttpStatus, .pCode)
    }
    Quit tSC
}

/// <p>Whether <var>pBody</var> carries a key the confirm channel is not open to (AD-6), in
/// <var>pProblem</var>, with the tool's declared secret-typed names in <var>pNames</var>.</p>
/// <p>The channel is open to exactly the descriptor's <code>secretArguments</code> for
/// <var>pToolName</var>. Every other key is a problem -- including the identifying key, which names
/// the target and is the row's, not the request's. An empty body is always sound.</p>
ClassMethod ChannelProblem(pToolName As %String, pBody As %DynamicObject, Output pNames As %List, Output pProblem As %Boolean) As %Status
{
    Set pNames = ""
    Set pProblem = 0
    Set tSC = $ClassMethod(..ToolRegistryClass(), "Resolve", pToolName, .tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tTool) {
        Set pProblem = 1
        Quit $$$OK
    }
    Set pNames = $ClassMethod(..ToolRegistryClass(), "SecretArguments", tTool, .tDeclared)
    If 'tDeclared {
        Set pProblem = 1
        Quit $$$OK
    }
    If '$IsObject(pBody) Quit $$$OK
    If 'pBody.%IsA("%Library.DynamicObject") {
        Set pProblem = 1
        Quit $$$OK
    }
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(pNames, tKey) {
            Set pProblem = 1
            Quit
        }
        ; A secret is a scalar. Refusing a structured value here, before the claim, is what keeps
        ; it from raising in the merge after the claim has already committed the burn.
        Set tType = pBody.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Set pProblem = 1
            Quit
        }
    }
    Quit $$$OK
}

/// <p>Whether the conversation <var>pConvKey</var> has moved on since turn <var>pTurnKey</var>
/// minted the proposal <var>pProposalId</var>, in <var>pMoved</var> (FR-17).</p>
/// <p>Three readings of one condition: the conversation is no longer <var>pUser</var>'s to read; a
/// turn later than the minting one has been recorded in it; or the proposal's own row has already
/// been closed with the reason a typed message closes one, which is the proactive cancel this check
/// backstops.</p>
ClassMethod ConversationMoved(pConvKey As %String, pTurnKey As %String, pUser As %String, pProposalId As %String, Output pMoved As %Boolean) As %Status [ Private ]
{
    Set pMoved = 0
    Set tSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tFound, .tValues)
    If $$$ISERR(tSC) Quit tSC
    If tFound && ($Get(tValues("closedReason")) = $Parameter(..StoreClass(), "REASONMESSAGE")) {
        Set pMoved = 1
        Quit $$$OK
    }
    If pConvKey = "" Quit $$$OK
    Set tSC = ##class(OcuPilot.Kernel.State.Convo).GuardedOwner(pConvKey, pUser, .tOwned)
    If $$$ISERR(tSC) Quit tSC
    If 'tOwned {
        Set pMoved = 1
        Quit $$$OK
    }
    Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedTurnKeys(pConvKey, .tKeys)
    If $$$ISERR(tSC) Quit tSC
    Set tMintedAt = 0
    Set tHighest = 0
    Set tSeq = ""
    For {
        Set tSeq = $Order(tKeys(tSeq))
        If tSeq = "" Quit
        If +tSeq > tHighest Set tHighest = +tSeq
        If tKeys(tSeq) = pTurnKey Set tMintedAt = +tSeq
    }
    ; A minting turn that has not been recorded yet is the ordinary path -- the card is emitted
    ; before the turn's entry is appended -- and says nothing about a newer turn.
    If tMintedAt = 0 Quit $$$OK
    If tHighest > tMintedAt Set pMoved = 1
    Quit $$$OK
}

/// <p>Whether the agent definition <var>pDefinitionId</var> has changed or gone since the mint read
/// <var>pStoredVersion</var> from it, in <var>pMoved</var> (FR-17, DW-430).</p>
/// <p><code>""</code> is "no row" on both sides and is never conflated with <code>0</code>: a
/// deleted definition answers <code>""</code> and moves the verdict, while a proposal minted before
/// this column existed carries <code>""</code> itself and is left alone. The call is wrapped here
/// because the method it reaches carries no trap of its own.</p>
ClassMethod DefinitionMoved(pDefinitionId As %String, pStoredVersion As %String, Output pMoved As %Boolean) As %Status [ Private ]
{
    Set pMoved = 0
    Set tSC = $$$OK
    If (pDefinitionId = "") || (pStoredVersion = "") Quit tSC
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedVersion(pDefinitionId, .tVersion)
        If $$$ISERR(tSC) Quit
        If tVersion '= pStoredVersion Set pMoved = 1
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the target still digests to the fingerprint the row stored, in <var>pMatches</var>
/// (AD-6), with the endpoint and the identifying parameter the write will use.</p>
/// <p>The target is read fresh through the port, the <b>stored</b> arguments are merged over that
/// read exactly as the mint merged them, and the digest is taken with the descriptor's own
/// exclusions. A target the instance no longer holds does not match, which closes the row rather
/// than writing to something that is not there.</p>
/// <p><b>Two digests must equal the stored one, not one</b> (AD-6): the fresh read merged as above,
/// and the stored payload the port will actually be sent.</p>
/// <p>What the second one does, stated exactly, because it is easy to read more into it. The mint
/// takes the row's fingerprint over that same payload, so for every row a mint produced the two are
/// equal by construction and this comparison refuses nothing -- it is not what makes the fingerprint
/// cover the write. What it refuses is a row whose payload no mint wrote: one stored directly into
/// OcuPilot's protected tables, or altered after minting. Both sit outside the threat model AD-9 and
/// AD-33 draw, so this is a backstop behind them rather than a gate the product's own path depends
/// on -- what keeps a stored payload and its diff describing each other is that the mint writes both
/// or saves no row at all (DW-1353).</p>
/// <p>Two things it does not reach either way: a field the descriptor excludes, since both digests
/// use the same exclusions, and a declared secret's value, which is merged over the payload after
/// this method returns. Neither is reachable for a registered write tool --
/// <method>OcuPilot.Test.Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField</method> asserts
/// that no tool excludes a field it can set and declares no secret outside the prohibited set's
/// reviewed few -- and that assertion is what holds it, not this comparison.</p>
ClassMethod FingerprintMatches(pTool As %DynamicObject, ByRef pRow, Output pMatches As %Boolean, Output pEndpoint As %String, Output pIdParam As %String, Output pIdValue As %String) As %Status [ Private ]
{
    Set pMatches = 0
    Set pEndpoint = ""
    Set pIdParam = ""
    Set pIdValue = ""
    Set tSC = $$$OK
    Try {
        Set tClass = pTool.%Get("class")
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set pEndpoint = $ClassMethod(tClass, "Endpoint")
        Set pIdParam = $ClassMethod(tClass, "IdParam")
        Set tIdArgument = $ClassMethod(tClass, "IdArgument")
        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse($Get(pRow("targetRef")), .tType, .tScope, .tId)
        If $$$ISERR(tSC) Quit
        Set pIdValue = tId
        If (pEndpoint = "") || (pIdParam = "") || (pIdValue = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the proposal's target could not be addressed")
            Quit
        }
        Kill tQuery
        Set tQuery(pIdParam) = pIdValue
        ; AD-52. The re-read asks the port the tool's own question about the reviewed target, which
        ; for a set-addressing port is "which of these ids still exist". Empty for every shipped
        ; tool, so their re-read is byte-identical to the mint's.
        Do ..ToolPortQuery(tClass, $Get(pRow("payload")), .tQuery)
        Set tReadSC = $ClassMethod(..PortClassOf(tClass), "Invoke", pEndpoint, ..ToolReadType(tClass), .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) {
            ; A target that is gone, or a read that refused, is "the target moved" -- never a
            ; write issued against a record nobody could read back.
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") Quit
        Set tArgs = ..ParsedObject($Get(pRow("arguments")))
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, tIdArgument, tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" Quit
        Set tExcludes = ""
        If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
        ; AD-51 as amended: an action-style write's digest covers the subject its tool declares,
        ; which is the same selection the mint made.
        Set tSubject = ##class(OcuPilot.Kernel.Proposal.Mint).FingerprintSubjectOf(tClass, .tSubjectProblem)
        If tSubjectProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, tSubjectProblem)
            Quit
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, tExcludes, .tDigest, tSubject)
        If $$$ISERR(tSC) Quit
        If tDigest '= $Get(pRow("fingerprint")) Quit
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(..ParsedObject($Get(pRow("payload"))), tExcludes, .tStoredDigest, tSubject)
        If $$$ISERR(tSC) Quit
        Set pMatches = (tStoredDigest = $Get(pRow("fingerprint")))
    } Catch ex {
        Set pMatches = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The stored payload <var>pPayloadJson</var> with the values <var>pBody</var> supplied for the
/// declared secret names <var>pNames</var> merged in (AD-35).</p>
/// <p>This is the only point at which a secret value exists in the request's data: it is not stored,
/// not logged, and was not part of the digest compared a moment earlier. A name the body did not
/// carry is left exactly as the payload holds it.</p>
ClassMethod WithSecrets(pPayloadJson As %String, pBody As %DynamicObject, pNames As %List) As %DynamicObject [ Private ]
{
    Set tPayload = ..ParsedObject(pPayloadJson)
    If '$IsObject(pBody) Quit tPayload
    If 'pBody.%IsA("%Library.DynamicObject") Quit tPayload
    For tI = 1:1:$ListLength(pNames) {
        Set tName = $List(pNames, tI)
        If pBody.%GetTypeOf(tName) = "unassigned" Continue
        Do tPayload.%Set(tName, pBody.%Get(tName), pBody.%GetTypeOf(tName))
    }
    Quit tPayload
}

/// <p><var>pText</var> parsed as a JSON object, or <code>{}</code> when it is empty or unreadable.</p>
ClassMethod ParsedObject(pText As %String) As %DynamicObject [ Private ]
{
    Set tObject = {}
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = {}
    }
    Quit tObject
}

/// <p>The admin request type <var>pToolClass</var>'s fresh re-read is made with (AD-51), or
/// <parameter>READTYPE</parameter> when the class declares none or cannot be asked.</p>
ClassMethod ToolReadType(pToolClass As %String) As %String [ Private ]
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "ReadType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#READTYPE
    Quit tType
}

/// <p>The admin request type <var>pToolClass</var>'s confirmed write is issued with (AD-51), or
/// <parameter>WRITETYPE</parameter> when the class declares none or cannot be asked.</p>
ClassMethod ToolWriteType(pToolClass As %String) As %String [ Private ]
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "WriteType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#WRITETYPE
    Quit tType
}

/// <p>Add <var>pToolClass</var>'s own port query parameters, read off the stored payload
/// <var>pPayloadJson</var>, to <var>pQuery</var> (AD-52,
/// <method>OcuPilot.Screen.Tool.Write.PortQuery</method>). Called before the fingerprint re-read
/// and again before the write, so both reach the port with the same question about the same
/// reviewed set.</p>
/// <p>A class that cannot be asked adds nothing, which is the answer every shipped tool's own
/// declaration gives: the vendor identifies a target by the one identifying parameter already
/// set.</p>
ClassMethod ToolPortQuery(pToolClass As %String, pPayloadJson As %String, ByRef pQuery) [ Private ]
{
    Try {
        If pToolClass = "" Quit
        Do $ClassMethod(pToolClass, "PortQuery", ..ParsedObject(pPayloadJson), .pQuery)
    } Catch {
        ; Deliberately empty: a tool that cannot answer adds no parameter, and the port refuses the
        ; call it then receives rather than issuing a delete with no subject.
    }
}

/// <p>The AD-14 action <var>pToolClass</var>'s confirmed write performs
/// (<method>OcuPilot.Screen.Tool.Write.ChangeAction</method>), or <code>""</code> for a class that
/// cannot be asked -- which leaves the answer carrying no action and the client publishing its own
/// default, the behaviour every write had before this seam existed.</p>
ClassMethod ToolChangeAction(pToolClass As %String) As %String [ Private ]
{
    Set tAction = ""
    Try {
        If pToolClass '= "" Set tAction = $ClassMethod(pToolClass, "ChangeAction")
    } Catch {
        Set tAction = ""
    }
    Quit tAction
}

/// <p>Whether <var>pToolClass</var>'s confirmed write carries a body (AD-51). A class that cannot
/// be asked sends one, which is every write that shipped before this seam existed.</p>
ClassMethod ToolSendsBody(pToolClass As %String) As %Boolean [ Private ]
{
    Set tSends = 1
    Try {
        If pToolClass '= "" Set tSends = ''$ClassMethod(pToolClass, "SendsBody")
    } Catch {
        Set tSends = 1
    }
    Quit tSends
}

/// <p>The first pair of <var>pPairs</var> that <var>pUser</var> does not hold, as
/// <code>resource:permission</code>, or <code>""</code> (AD-8).</p>
ClassMethod MissingPair(pUser As %String, pPairs As %List) As %String [ Private ]
{
    Set tFailed = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        If '..HoldsPair(pUser, $List(tPair, 1), $List(tPair, 2)) {
            Set tFailed = $List(tPair, 1) _ ":" _ $List(tPair, 2)
            Quit
        }
    }
    Quit tFailed
}

/// <p>Whether <var>pUser</var> holds <var>pPermission</var> on <var>pResource</var> right now.
/// Overridable so a test can drive a revoked pair without changing the instance's own grants;
/// production never overrides it.</p>
ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Set tHolds = 0
    Try {
        Set tHolds = ($SYSTEM.Security.CheckUserPermission(pUser, pResource, pPermission) = 1)
    } Catch {
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>The proposal's closed state as the caller is answered it:
/// <code>{proposalId, state, closedReason, confirmedAt}</code>, plus <code>auditMarked</code> where
/// a write was made, read back from the row so the answer and the wire cannot disagree. A row that is no longer there is answered as an internal
/// failure, never as a 200 carrying empty fields.</p>
ClassMethod Answer(pProposalId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String, pAuditMarked As %String = "", pAction As %String = "") As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tFound, .tValues)
    If $$$ISERR(tSC) Quit tSC
    ; A row that cannot be read back after its transition is not a 200 with empty fields: an empty
    ; state projects as expired on the card, which would offer Re-propose over a spent token.
    If 'tFound Quit ..Internal("the proposal could not be read back after its transition", .pHttpStatus, .pCode)
    Set pResult = {}
    Do pResult.%Set("proposalId", pProposalId, "string")
    Do pResult.%Set("state", $Get(tValues("state")), "string")
    Do pResult.%Set("closedReason", $Get(tValues("closedReason")), "string")
    Do pResult.%Set("confirmedAt", $Get(tValues("confirmedAt")), "string")
    ; Present only where a write was made, so a cancel does not answer "this was not marked" about
    ; a write that never happened. The card's collapsed status line reads it (AD-15).
    If pAuditMarked '= "" Do pResult.%Set("auditMarked", ''pAuditMarked, "boolean")
    ; AD-14's action for the write that just happened, present only where one happened. The client
    ; publishes what the instance says rather than inferring it from the shape of the diff: the
    ; vocabulary is the kernel's closed set, and a screen routes on it.
    If pAction '= "" Do pResult.%Set("action", pAction, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The top-level field names <var>pBody</var> carries, minus every name in
/// <var>pSecretNames</var>: what the ledger row records the write as having sent (AD-41).</p>
/// <p><b>The exclusion is at write time, not a redaction afterwards</b> (AD-3): a secret-declared
/// name never reaches the ledger row at all, so there is nothing stored to remove and no window in
/// which it was stored. No value of any field is read here -- only names.</p>
ClassMethod FieldNames(pBody As %DynamicObject, pSecretNames As %List) As %List [ Private ]
{
    Set tNames = ""
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $ListFind(pSecretNames, tKey) Continue
            Set tNames = tNames _ $ListBuild(tKey)
        }
    } Catch ex {
        Set tNames = ""
    }
    Quit tNames
}

/// <p>The state a refusal leaves the row in, as <code>{state, closedReason}</code> in
/// <var>pDetail</var>, or <code>""</code> for a row that could not be read.</p>
/// <p>It is carried on the refusals that <b>close</b> the row -- the fingerprint mismatch, and a
/// claim another caller won -- so the card that was refused reads its new state from the instance
/// rather than inferring one from the code.</p>
ClassMethod ClosedDetail(pProposalId As %String, Output pDetail As %DynamicObject) [ Private ]
{
    Set pDetail = ""
    Try {
        Set tSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tFound, .tValues)
        If $$$ISERR(tSC) || 'tFound Quit
        Set pDetail = {}
        Do pDetail.%Set("state", $Get(tValues("state")), "string")
        Do pDetail.%Set("closedReason", $Get(tValues("closedReason")), "string")
    } Catch {
        Set pDetail = ""
    }
}

/// <p>The HTTP status one of <class>OcuPilot.Kernel.Proposal.Write</class>'s claim refusals is
/// rendered at: 404 for an id nothing carries, 403 for another user's, 409 for a window or a token
/// that has already gone.</p>
ClassMethod StatusForClaim(pCode As %String) As %Integer [ Private ]
{
    If pCode = ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN Quit 404
    If pCode = ##class(OcuPilot.Kernel.Proposal.Write).#NOTOKEN Quit 404
    If pCode = ##class(OcuPilot.Kernel.Proposal.Write).#NOTYOURS Quit 403
    Quit 409
}

/// <p>A refusal as a status, with <var>pCode</var> and its HTTP status for the handler.</p>
ClassMethod Refuse(pStatus As %Integer, pCode As %String, Output pHttpStatus As %Integer, Output pOutCode As %String) As %Status [ Private ]
{
    Set pHttpStatus = pStatus
    Set pOutCode = pCode
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>An internal failure: 500 with the generic code on the wire and <var>pDetail</var> in the
/// status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pCode As %String) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
