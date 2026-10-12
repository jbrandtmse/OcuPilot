/// <p>Subclass of <class>OcuPilot.Api.Switches</class> that observes the marking flags through
/// <class>OcuPilot.Test.MarkingPort</class> and exposes <method>RestraintBody</method>, so
/// <class>OcuPilot.Test.MarkingRestraint</class> and <class>OcuPilot.Test.SwitchesWire</class>
/// run the restraint read's marking rule over armed answers.</p>
Class OcuPilot.Test.MarkingRestraintFixture Extends OcuPilot.Api.Switches
{

ClassMethod MarkingPortClass() As %String [ Private ]
{
    Quit "OcuPilot.Test.MarkingPort"
}

/// <p><var>pUser</var>'s restraint body, as <method>OcuPilot.Api.Switches.RestraintBody</method>
/// builds it.</p>
ClassMethod Body(pUser As %String, Output pBody As %DynamicObject) As %Status
{
    Quit ..RestraintBody(pUser, .pBody)
}

}
