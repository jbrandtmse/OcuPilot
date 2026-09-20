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
/// <p><b>Why the port call follows the commit.</b> AD-34's transition is the point of no return --
/// burning the token and committing to the write. A vendor call inside a <code>TSTART</code> frame
/// is refused on two grounds: the project's ObjectScript rule forbids a side effect inside a
/// transaction, and the vendor's own endpoints run transactions of their own, so a rollback could
/// leave a vendor write half-undone. Single-use survives either way -- a claim that commits and a
/// write that then fails leaves the proposal burned and confirmed, refused on any re-attempt.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method> and <method>StoreClass</method>,
/// mirroring <class>OcuPilot.Kernel.Proposal.Mint</class>'s. Production overrides neither.</p>
Class OcuPilot.Kernel.Proposal.Confirm Extends %RegisteredObject
{

/// <p>The admin request type the target's fresh re-read is made with (AD-36's single-object
/// <code>GET</code>).</p>
Parameter READTYPE = "GET";

/// <p>The admin request type the confirmed write is issued with. It resolves through the vendor
/// endpoint's own <code>TYPE&lt;suffix&gt;</code> parameter, exactly as the read does
/// (<parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter>).</p>
Parameter WRITETYPE = "PUT";

/// <p>The port the fresh re-read and the write go through. Overridable so a fixture can answer a
/// known object and record what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The proposal store. Overridable for the same reason; production never overrides it.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Propose"
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
/// <code>{proposalId, state, closedReason, confirmedAt}</code>. On a refusal the status is an
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

        ; The declared secret-typed names, re-read from the tool rather than carried in from the
        ; channel check, so the merge below and that check read one declaration.
        Set tSecretNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tSecretsDeclared)
        If 'tSecretsDeclared {
            Set tSC = ..Internal("the secret arguments of " _ $Get(pRow("toolName")) _ " could not be read", .pHttpStatus, .pCode)
            Quit
        }

        ; AD-10's single call site: asked inside the transition and before the port call. The set
        ; is handed the stored row's tool, target, payload and diff, and nothing of the request's.
        Set tProhibited = ..ProhibitedClassName()
        If tProhibited '= "" {
            Set tProhibitSC = $ClassMethod(tProhibited, "Prohibits", $Get(pRow("toolName")), $Get(pRow("targetRef")), $Get(pRow("payload")), $Get(pRow("diff")), .tProhibits, .tProhibitCode)
            If $$$ISERR(tProhibitSC) {
                Set tSC = ..Internal("the prohibited set could not be read", .pHttpStatus, .pCode)
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

        ; AD-8: the declared pairs, re-checked at the moment of the call rather than at the mint.
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tPairsResolved)
        If 'tPairsResolved {
            Set tSC = ..Internal("the privilege pairs of " _ $Get(pRow("toolName")) _ " could not be read", .pHttpStatus, .pCode)
            Quit
        }
        Set tFailedPair = ..MissingPair(pUser, tPairs)
        If tFailedPair '= "" {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, .pHttpStatus, .pCode)
            Set pDetail = {}
            Do pDetail.%Set("failedPair", tFailedPair, "string")
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
        Set tBody = ..WithSecrets($Get(pRow("payload")), pSuppliedSecrets, tSecretNames)
        Kill tQuery
        Set tQuery(tIdParam) = tIdValue
        Set tWriteSC = $ClassMethod(..PortClass(), "Invoke", tEndpoint, ..#WRITETYPE, .tQuery, tBody, .tWritten, .tWriteHttp, .tWriteFault)
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
            Set tSC = tWriteSC
            Quit
        }

        Set tSC = ..Answer(pProposalId, .pResult, .pHttpStatus, .pCode)
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
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pToolName, .tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tTool) {
        Set pProblem = 1
        Quit $$$OK
    }
    Set pNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tDeclared)
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
/// and the stored payload the port will actually be sent. The second is what makes the fingerprint
/// cover the complete property set the write sends -- the mint stores the digest of that very
/// payload, so a genuine row passes it, and a row whose payload does not describe the write its
/// fingerprint promises does not match whatever its diff says.</p>
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
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, ..#READTYPE, .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
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
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, tExcludes, .tDigest)
        If $$$ISERR(tSC) Quit
        If tDigest '= $Get(pRow("fingerprint")) Quit
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(..ParsedObject($Get(pRow("payload"))), tExcludes, .tStoredDigest)
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
/// <code>{proposalId, state, closedReason, confirmedAt}</code>, read back from the row so the
/// answer and the wire cannot disagree. A row that is no longer there is answered as an internal
/// failure, never as a 200 carrying empty fields.</p>
ClassMethod Answer(pProposalId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String) As %Status [ Private ]
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
    Set pHttpStatus = 200
    Quit $$$OK
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
