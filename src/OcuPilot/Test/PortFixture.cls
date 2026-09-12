/// <p>Subclass of <class>OcuPilot.Port.AdminPort</class> overriding <b>only</b> the two
/// class-name seams, so <class>OcuPilot.Test.Instance</class> can run the port's real
/// derivation and its real probe contract against fixture classes. Nothing about the
/// instance's own admin API, version row or security is touched, and the derivation itself
/// is never replaced by a hardcoded number.</p>
/// <p>Each seam falls back to <code>##super()</code> when the caller has armed nothing, so
/// an unconfigured call behaves like production -- the same fallback shape
/// <class>OcuPilot.Test.GateFixture</class> uses for the install gate.</p>
Class OcuPilot.Test.PortFixture Extends OcuPilot.Port.AdminPort
{

/// <p>Point the derivation at <var>pClass</var> instead of the vendor's routing class.
/// <code>""</code> restores the production value.</p>
ClassMethod SetAdminApiClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("api") = pClass
}

/// <p>Point the probe at <var>pClass</var> instead of the vendor's endpoint.
/// <code>""</code> restores the production value.</p>
ClassMethod SetProbeEndpointClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("probe") = pClass
}

/// <p>Forget both overrides.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotPortFixture
}

ClassMethod AdminApiClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("api"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ProbeEndpointClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("probe"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

}
