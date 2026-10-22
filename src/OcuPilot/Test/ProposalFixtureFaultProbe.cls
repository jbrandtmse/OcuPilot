/// <p>Not a test: <class>OcuPilot.Test.ProposalFixture</class> whose <method>Update</method> breaks the one
/// delete a caller arms, and whose proposal count can be made unreadable, so <method>RemoveSeeded</method>'s
/// failure paths can be driven without breaking the store. For the turn key <method>ArmFault</method> names,
/// mode <parameter>FAIL</parameter> answers an error for the proposal delete, mode
/// <parameter>KEEPTURN</parameter> answers success without deleting the turn, and mode
/// <parameter>UNREADABLE</parameter> answers -1 for the proposal count. Every other statement is the
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

/// <p>Arm <var>pMode</var> (<parameter>FAIL</parameter>, <parameter>KEEPTURN</parameter> or
/// <parameter>UNREADABLE</parameter>) for the turn key <var>pKey</var>.</p>
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

/// <p>The superclass's write, except that the armed key's delete is broken as its mode says.</p>
ClassMethod Update(pSql As %String, pFirst As %String, pSecond As %String = "") As %Status [ Private ]
{
    Set tKey = $Get(^||OcuPilotProposalFixtureFault("key"))
    If (tKey '= "") && (pFirst = tKey) && ($Extract(pSql, 1, 6) = "DELETE") {
        Set tMode = $Get(^||OcuPilotProposalFixtureFault("mode"))
        If (tMode = ..#FAIL) && (pSql [ "OcuPilot_Kernel_State.Proposal") {
            Quit $$$ERROR($$$GeneralError, "the probe proposal delete is made to fail")
        }
        If (tMode = ..#KEEPTURN) && (pSql [ "OcuPilot_Kernel_State.Turn") Quit $$$OK
    }
    Quit ##super(pSql, pFirst, pSecond)
}

}
