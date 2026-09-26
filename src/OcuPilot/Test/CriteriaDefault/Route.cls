/// <p>The screen read route over <class>OcuPilot.Test.Read.ReadFixture</class>, with a no-argument
/// entry point per screen so <method>OcuPilot.Test.Dispatch.InvokeHandler</method> can drive it
/// against stub <code>%request</code> query parameters. The real registry and the real gate
/// answer; only the port is the fixture's.</p>
Class OcuPilot.Test.CriteriaDefault.Route Extends OcuPilot.Api.ScreenRead
{

ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Test.Read.ReadFixture"
}

/// <p>The audit database viewer's read.</p>
ClassMethod Audit() As %Status
{
    Quit ..Handle("logs.audit")
}

}
