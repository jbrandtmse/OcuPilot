/// <p>The turn a tool call is being made on behalf of, carried as a value through the calling
/// process (AD-40).</p>
/// <p>A tool's contract hands it the descriptor, the model's arguments and a row cap and nothing
/// about who is calling: it runs in the caller's process, with the caller's identity, and anything
/// else it needs arrives as a value (<class>OcuPilot.Screen.Tool.Base</class>). A minted proposal
/// records which turn and which conversation produced it, so the turn job stashes both here once,
/// at the top of <method>OcuPilot.Kernel.Agent.Loop.Run</method>, and clears them when it
/// unwinds.</p>
/// <p><b>Set means "acting on behalf of the model".</b> That is the marker AD-40 names: confirm is
/// a user-originated request and refuses any call whose originating context is a turn, and the
/// refusal Story 5.3 writes reads this same stash. A request process that has never run a turn
/// carries nothing here, which is exactly the condition confirm requires.</p>
/// <p>Backed by a process-private global holding a two-piece string. It is per process and never
/// shared: a turn job is one process, and the tool bodies it dispatches run inside it.</p>
Class OcuPilot.Kernel.Proposal.Caller Extends %RegisteredObject
{

/// <p>Record turn <var>pTurnKey</var> of conversation <var>pConvKey</var> as the turn this process
/// is acting for.</p>
ClassMethod Set(pTurnKey As %String, pConvKey As %String = "")
{
    Set ^||OcuPilotProposalCaller = pTurnKey _ $Char(1) _ pConvKey
}

/// <p>The turn this process is acting for, or <code>""</code>.</p>
ClassMethod TurnKey() As %String
{
    Quit $Piece($Get(^||OcuPilotProposalCaller), $Char(1), 1)
}

/// <p>That turn's conversation, or <code>""</code>.</p>
ClassMethod ConvKey() As %String
{
    Quit $Piece($Get(^||OcuPilotProposalCaller), $Char(1), 2)
}

/// <p>Whether this process is acting on behalf of the model (AD-40).</p>
ClassMethod IsTurn() As %Boolean
{
    Quit ..TurnKey() '= ""
}

/// <p>Forget the stash, so a process reused for a later request carries no turn.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotProposalCaller
}

}
