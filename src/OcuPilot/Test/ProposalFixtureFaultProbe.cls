/// <p>Not a test: <class>OcuPilot.Test.ProposalFixture</class> whose <method>Update</method> breaks the one
/// delete a caller arms, and whose proposal or turn count can be made unreadable, so
/// <method>RemoveSeeded</method>'s failure paths can be driven without breaking the store. For the turn key
/// <method>ArmFault</method> names, mode <parameter>FAIL</parameter> answers an error for the proposal delete,
/// mode <parameter>FAILAFTER</parameter> runs that delete and then answers an error, mode
/// <parameter>KEEPTURN</parameter> answers success without deleting the turn, mode
/// <parameter>UNREADABLE</parameter> answers -1 for the proposal count and mode
/// <parameter>UNREADABLETURN</parameter> answers -1 for the turn count. Every other statement is the
/// superclass's. The arming lives in <code>^||OcuPilotProposalFixtureFault</code>, which
/// <method>Disarm</method> removes.</p>
Class OcuPilot.Test.ProposalFixtureFaultProbe Extends OcuPilot.Test.ProposalFixture
{

/// <p>The mode that fails the armed key's proposal delete.</p>
Parameter FAIL = "fail";

/// <p>The mode that skips the armed key's turn delete and answers success.</p>
Parameter KEEPTURN = "keepturn";

/// <p>The mode that makes the armed key's proposal count unreadable.</p>
Parameter UNREADABLE = "unreadable";

/// <p>The mode that makes the armed key's turn count unreadable.</p>
Parameter UNREADABLETURN = "unreadableturn";

/// <p>The mode that deletes the armed key's proposals and then reports the delete as failed.</p>
Parameter FAILAFTER = "failafter";

/// <p>Arm <var>pMode</var> (<parameter>FAIL</parameter>, <parameter>FAILAFTER</parameter>,
/// <parameter>KEEPTURN</parameter>, <parameter>UNREADABLE</parameter> or <parameter>UNREADABLETURN</parameter>)
/// for the turn key <var>pKey</var>.</p>
ClassMethod ArmFault(pKey As %String, pMode As %String)
{
    Set ^||OcuPilotProposalFixtureFault("key") = pKey
    Set ^||OcuPilotProposalFixtureFault("mode") = pMode
}

/// <p>Forget the arming.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotProposalFixtureFault
}

/// <p>The superclass's count, except that the armed key's proposals cannot be read in mode
/// <parameter>UNREADABLE</parameter>.</p>
ClassMethod ProposalCountForTurn(pTurnKey As %String) As %Integer
{
    If (pTurnKey '= "") && (pTurnKey = $Get(^||OcuPilotProposalFixtureFault("key"))) && ($Get(^||OcuPilotProposalFixtureFault("mode")) = ..#UNREADABLE) Quit -1
    Quit ##super(pTurnKey)
}

/// <p>The superclass's count, except that the armed key's turns cannot be read in mode
/// <parameter>UNREADABLETURN</parameter>.</p>
ClassMethod TurnCountForTurn(pTurnKey As %String) As %Integer
{
    If (pTurnKey '= "") && (pTurnKey = $Get(^||OcuPilotProposalFixtureFault("key"))) && ($Get(^||OcuPilotProposalFixtureFault("mode")) = ..#UNREADABLETURN) Quit -1
    Quit ##super(pTurnKey)
}

/// <p>The superclass's write, except that the armed key's delete is broken as its mode says.</p>
ClassMethod Update(pSql As %String, pFirst As %String, pSecond As %String = "") As %Status [ Private ]
{
    Set tKey = $Get(^||OcuPilotProposalFixtureFault("key"))
    If (tKey '= "") && (pFirst = tKey) && ($Extract(pSql, 1, 6) = "DELETE") {
        Set tMode = $Get(^||OcuPilotProposalFixtureFault("mode"))
        If (tMode = ..#FAIL) && (pSql [ "OcuPilot_Kernel_State.Proposal") {
            Quit $$$ERROR($$$GeneralError, "the probe proposal delete is made to fail")
        }
        If (tMode = ..#FAILAFTER) && (pSql [ "OcuPilot_Kernel_State.Proposal") {
            Set tDone = ##super(pSql, pFirst, pSecond)
            If $$$ISERR(tDone) Quit tDone
            Quit $$$ERROR($$$GeneralError, "the probe proposal delete is made to fail after it ran")
        }
        If (tMode = ..#KEEPTURN) && (pSql [ "OcuPilot_Kernel_State.Turn") Quit $$$OK
    }
    Quit ##super(pSql, pFirst, pSecond)
}

}
