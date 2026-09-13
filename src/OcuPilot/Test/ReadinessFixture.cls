/// <p>Test-only <class>OcuPilot.Api.Readiness</class> subclass that arms which of the install
/// gate's four states the endpoint sees, so all four can be observed without forcing a real
/// install into each of them.</p>
/// <p><b>The seam is the gate read, not the response.</b> Overriding what
/// <method>OcuPilot.Api.Readiness.Readiness</method> writes would replace the code under test;
/// arming <method>GateStatus</method> leaves the whole production body -- the three keys, their
/// types, the version stamp's own rule and the 405 override -- exactly as it ships, and
/// <class>OcuPilot.Test.Dispatch</class> then captures what it actually wrote.</p>
/// <p>The armed state lives in a process-private global, cleared by <method>Reset</method>, so
/// nothing survives the process that armed it. Unarmed, it answers exactly what the production
/// class answers.</p>
Class OcuPilot.Test.ReadinessFixture Extends OcuPilot.Api.Readiness
{

/// <p>Arm <var>pState</var> as the gate's answer for this process.</p>
ClassMethod Arm(pState As %String)
{
    Set ^||OcuPilotReadinessFixture("state") = pState
}

/// <p>Forget the armed state, so the endpoint reads the real gate again.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotReadinessFixture
}

ClassMethod GateStatus() As %String
{
    If '$Data(^||OcuPilotReadinessFixture("state")) Quit ##super()
    Quit ^||OcuPilotReadinessFixture("state")
}

}
