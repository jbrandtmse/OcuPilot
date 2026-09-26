/// <p>Drives <class>OcuPilot.Install.Smoke</class>'s <code>agentwrite</code> and
/// <code>auditmarker</code> checks against a web application the instance spells in <b>mixed
/// case</b>, which AD-25's own <code>/csp/myapp</code> cannot be: it folds to itself, so no leg
/// built on it is evidence about case-preserved resolution (Story 5.8, DW-1406).</p>
/// <p><b>What it needs from the environment:</b>
/// <method>OcuPilot.Test.ProposalFixture.EnsureMixedCaseWriteTarget</method>'s application, which
/// that fixture creates only on a throwaway container. The caller arms and removes it; this class
/// only points the shipped check at it.</p>
/// <p>Two seams and nothing else. <method>WriteTarget</method> names the probe application, and
/// <method>WriteTargetOwned</method> answers yes because the ownership read the shipped class
/// makes is about AD-25's fixture inventory, which a probe application is deliberately not in --
/// the shipped answer would skip every run here and assert nothing.</p>
Class OcuPilot.Test.SmokeWriteProbe Extends OcuPilot.Install.Smoke
{

ClassMethod WriteTarget() As %String
{
    Quit ##class(OcuPilot.Test.ProposalFixture).#WRITETARGETMIXEDCASE
}

ClassMethod WriteTargetOwned() As %Boolean
{
    Quit 1
}

/// <p>Run the two checks into <var>pChecks</var>, so a test can read their outcomes and reasons
/// without rendering the whole smoke list. <var>pDemo</var> is the opt-in flag the shipped check
/// reads, passed through unchanged.</p>
ClassMethod RunWriteChecks(ByRef pChecks, pDemo As %String = "1")
{
    Do ..CheckAgentWrite(.pChecks, pDemo)
}

}
