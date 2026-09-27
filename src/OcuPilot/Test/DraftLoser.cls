/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Draft</class> subclass whose replaced seam is the
/// store: every read is <class>OcuPilot.Kernel.State.Propose</class>'s own, and
/// <method>GuardedClose</method> reports the row as closed by another request first, so a draft
/// reaches the lost-race refusal with the row left as it was.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
/// <p><code>DependsOn</code> is required: <parameter>STATELIVE</parameter> and
/// <parameter>REASONDRAFT</parameter> are compile-time expressions over
/// <class>OcuPilot.Kernel.State.Propose</class>, so that class must be compiled first.</p>
Class OcuPilot.Test.DraftLoser Extends OcuPilot.Kernel.Proposal.Draft [ DependsOn = OcuPilot.Kernel.State.Propose ]
{

Parameter STATELIVE = {##class(OcuPilot.Kernel.State.Propose).#STATELIVE};

Parameter REASONDRAFT = {##class(OcuPilot.Kernel.State.Propose).#REASONDRAFT};

ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Test.DraftLoser"
}

ClassMethod GuardedExpireStale(pUser As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Propose).GuardedExpireStale(pUser)
}

ClassMethod GuardedByKey(pKey As %String, Output pFound As %Boolean, Output pValues) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .pFound, .pValues)
}

/// <p>Closes nothing and reports that another request closed the row first.</p>
ClassMethod GuardedClose(pKey As %String, pUser As %String, pReason As %String, Output pClosed As %Boolean) As %Status
{
    Set pClosed = 0
    Quit $$$OK
}

}
