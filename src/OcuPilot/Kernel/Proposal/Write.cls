/// <p>The single gate every instance mutation made through the agent passes (AD-6, AD-34, AD-40):
/// a write proceeds only against a valid, unexpired, unburned token, claimed by the user who
/// minted it, on a turn that ended normally.</p>
/// <p><b>The write path refuses, not its caller.</b> A call arriving with no token at all is
/// <parameter>NOTOKEN</parameter> here rather than being rejected somewhere upstream, so there is
/// no path to a mutation that did not pass this method.</p>
/// <p><b>It evaluates no policy of its own</b> (AD-40). The prohibited set, enforced read-only, the
/// kill switch and later governance are evaluated at the write, inside Story 5.3's atomic
/// transition, against state that may have moved since the mint. This method answers one question:
/// is this token a claim on a proposal that is still claimable?</p>
/// <p><b>Burning the token and committing are Story 5.3's.</b> This story ships the gate and its
/// refusals; nothing here writes.</p>
/// <p><b>The order of the refusals is the order they are listed below</b>, and it is the order the
/// tests drive one at a time: a proposal that trips two conditions answers the earlier one.</p>
Class OcuPilot.Kernel.Proposal.Write Extends %RegisteredObject
{

/// <p>No proposal id or no token was supplied. The refusal a write path makes when nothing
/// claimed anything.</p>
Parameter NOTOKEN = "PROPOSAL.NOTOKEN";

/// <p>No live proposal carries that token, or it carries a different id.</p>
Parameter UNKNOWN = "PROPOSAL.UNKNOWN";

/// <p>The claim is not the minting user's. It says nothing about whether the id exists.</p>
Parameter NOTYOURS = "PROPOSAL.NOTYOURS";

/// <p>The proposal's own ten-minute window has passed
/// (<parameter>OcuPilot.Kernel.Agent.Limits.PROPOSALEXPIRYSECONDS</parameter>).</p>
Parameter EXPIRED = "PROPOSAL.EXPIRED";

/// <p>The token has already been spent.</p>
Parameter BURNED = "PROPOSAL.BURNED";

/// <p>The minting turn ended abnormally, or its record is gone. A turn that ended
/// <code>completed</code> is not this: a turn ends the moment it emits the card, so the ordinary
/// path runs through a completed turn and must not trip here.</p>
Parameter TURNENDED = "PROPOSAL.TURNENDED";

/// <p>The turn states that make a proposal unconfirmable, comma-separated (AD-40).</p>
Parameter ABNORMALSTATES = "stopped,abandoned,failed";

/// <p>Confirm was called from a process acting on behalf of the model
/// (<method>OcuPilot.Kernel.Proposal.Caller.IsTurn</method>). Confirm is a user-originated request
/// and the barrier is explicit, because AD-1 removed the HTTP one (AD-40).</p>
Parameter FROMTURN = "PROPOSAL.FROMTURN";

/// <p>The confirm body carried a key that is not a declared secret-typed field of that tool, or the
/// identifying key. The channel is closed: such a key is rejected outright, never ignored
/// (AD-6).</p>
Parameter CLOSEDCHANNEL = "PROPOSAL.CLOSEDCHANNEL";

/// <p>The proposal's conversation has moved on -- a newer turn, or the conversation replaced
/// (FR-17).</p>
Parameter CONVERSATION = "PROPOSAL.CONVERSATION";

/// <p>The agent definition in force at the mint has changed or been deleted (FR-17).</p>
Parameter DEFINITION = "PROPOSAL.DEFINITION";

/// <p>The target was re-read and the re-computed digest no longer matches the stored one: the
/// target moved under the diff (AD-6, FR-17). Terminal -- the row closes and Re-propose is the
/// accommodation.</p>
Parameter TARGETCHANGED = "PROPOSAL.TARGETCHANGED";

/// <p>Every <code>PROPOSAL.*</code> code this class declares, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NOTOKEN, ..#UNKNOWN, ..#NOTYOURS, ..#EXPIRED, ..#BURNED, ..#TURNENDED, ..#FROMTURN, ..#CLOSEDCHANNEL, ..#CONVERSATION, ..#DEFINITION, ..#TARGETCHANGED)
}

/// <p>The written sentence a <code>PROPOSAL.*</code> code carries, or <code>""</code> for any other
/// code (AD-39). The handler renders it beside the code; no other family's resolver is named
/// here.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NOTOKEN Quit "This request named no proposal."
    If pCode = ..#UNKNOWN Quit "No proposal of yours carries that identifier."
    If pCode = ..#NOTYOURS Quit "That proposal was made for another account."
    If pCode = ..#EXPIRED Quit "That proposal's ten-minute window has passed. Ask the agent to propose it again."
    If pCode = ..#BURNED Quit "That proposal has already been decided."
    If pCode = ..#TURNENDED Quit "The turn that made that proposal did not finish normally, so it cannot be confirmed."
    If pCode = ..#FROMTURN Quit "A proposal is confirmed by a person, never by the agent."
    If pCode = ..#CLOSEDCHANNEL Quit "A confirmation carries only the fields this screen declares secret, and nothing else."
    If pCode = ..#CONVERSATION Quit "This conversation has moved on since that proposal was made. Ask the agent to propose it again."
    If pCode = ..#DEFINITION Quit "The agent definition in force has changed since that proposal was made."
    If pCode = ..#TARGETCHANGED Quit "The target changed after this proposal was made, so the change was not applied. Ask the agent to propose it again."
    Quit ""
}

/// <p>The proposal store. Overridable so a fixture can answer a known row; production never
/// overrides it.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Propose"
}

/// <p>The turn store the minting turn's state is read from. Overridable for the same reason.</p>
ClassMethod TurnClass() As %String
{
    Quit "OcuPilot.Kernel.State.Turn"
}

/// <p>Claim proposal <var>pProposalId</var> with <var>pToken</var>, for <var>pUser</var>.</p>
/// <p>On success the status is OK and <var>pProposal</var> carries the stored row as data -- the
/// arguments, the payload, the diff, the target reference and the fingerprint the write executes
/// from (AD-6: the executed write comes from the stored arguments, never from the request).</p>
/// <p>On a refusal the status is an error whose <var>pCode</var> is one of this class's six
/// parameters, and <var>pProposal</var> is empty. A store that cannot be read is an error with no
/// code, which a caller must treat as a refusal too: an unreadable proposal is not a claimable
/// one.</p>
ClassMethod Claim(pProposalId As %String, pToken As %String, pUser As %String, Output pProposal, Output pCode As %String) As %Status
{
    Kill pProposal
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If (pProposalId = "") || (pToken = "") {
            Set tSC = ..Refuse(..#NOTOKEN, .pCode)
            Quit
        }
        Set tSC = $ClassMethod(..StoreClass(), "GuardedByToken", pToken, .tFound, .tValues)
        If $$$ISERR(tSC) Quit
        If 'tFound || (tValues("proposalId") '= pProposalId) {
            Set tSC = ..Refuse(..#UNKNOWN, .pCode)
            Quit
        }
        If tValues("user") '= pUser {
            Set tSC = ..Refuse(..#NOTYOURS, .pCode)
            Quit
        }
        Set tExpires = $ClassMethod(..StoreClass(), "SecondsOf", tValues("expiresAt"))
        If (tExpires = "") || ($ClassMethod(..StoreClass(), "NowSeconds") > tExpires) {
            Set tSC = ..Refuse(..#EXPIRED, .pCode)
            Quit
        }
        If tValues("burned") {
            Set tSC = ..Refuse(..#BURNED, .pCode)
            Quit
        }
        Set tTurnSC = $ClassMethod(..TurnClass(), "GuardedForOwner", tValues("turnKey"), pUser, .tTurnFound, .tTurn)
        If $$$ISERR(tTurnSC) {
            Set tSC = tTurnSC
            Quit
        }
        If 'tTurnFound || ..IsAbnormal($Get(tTurn("state"))) {
            Set tSC = ..Refuse(..#TURNENDED, .pCode)
            Quit
        }
        Merge pProposal = tValues
    } Catch ex {
        Kill pProposal
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pProposal
    Quit tSC
}

/// <p>Claim proposal <var>pProposalId</var> for <var>pUser</var>, resolving the token from the
/// stored row.</p>
/// <p><b>The token never crosses the wire.</b> A confirm request carries the proposal id in its
/// route and nothing else identifying; the single-use token is the store's, so it is read here and
/// handed to <method>Claim</method>, which answers the same six refusals it answers a caller that
/// held one. An id no row carries is <parameter>UNKNOWN</parameter>, the same answer a wrong token
/// earns, so neither says whether the other exists.</p>
ClassMethod ClaimById(pProposalId As %String, pUser As %String, Output pProposal, Output pCode As %String) As %Status
{
    Kill pProposal
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If pProposalId = "" {
            Set tSC = ..Refuse(..#NOTOKEN, .pCode)
            Quit
        }
        Set tSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tFound, .tValues)
        If $$$ISERR(tSC) Quit
        If 'tFound {
            Set tSC = ..Refuse(..#UNKNOWN, .pCode)
            Quit
        }
        Set tSC = ..Claim(pProposalId, $Get(tValues("token")), pUser, .pProposal, .pCode)
    } Catch ex {
        Kill pProposal
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pProposal
    Quit tSC
}

/// <p>The class AD-10's prohibited set is answered by, or <code>""</code> while none exists.</p>
/// <p><b>This is AD-10's single call site and nothing more.</b> Story 5.5 creates the kernel home
/// for the set and points this method at it; until then the confirm transition asks the question,
/// is told "not prohibited", and carries on. The seam is here rather than in
/// <class>OcuPilot.Kernel.Proposal.Confirm</class> so the set has exactly one home to be named
/// from (AD-10).</p>
ClassMethod ProhibitedClass() As %String
{
    Quit ""
}

/// <p>Whether <var>pState</var> is one of <parameter>ABNORMALSTATES</parameter>. An empty state --
/// a turn whose record is gone -- is not one of them; that case is answered by the caller's own
/// "not found" branch, so the two are never confused.</p>
ClassMethod IsAbnormal(pState As %String) As %Boolean
{
    If pState = "" Quit 0
    Quit $ListFind($ListFromString(..#ABNORMALSTATES), pState) > 0
}

/// <p>The refusal <var>pCode</var> as a status, with the code in <var>pCode</var> for a caller
/// that renders it.</p>
ClassMethod Refuse(pCode As %String, Output pOutCode As %String) As %Status [ Private ]
{
    Set pOutCode = pCode
    Quit $$$ERROR($$$GeneralError, pCode)
}

}
