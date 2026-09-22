/// <p>Fixture: the shipped <class>OcuPilot.Port.AdminPort</class> with its one privilege
/// consultation instrumented, so a test can read <code>$USERNAME</code> and <code>$ROLES</code> as
/// they are <b>inside the port's own call frame</b> (Story 5.4, AC4). The answer is the shipped
/// one; only the recording is added.</p>
/// <p><b>The recording is written inline, not dispatched to
/// <class>OcuPilot.Test.AsTheUserProbe</class>.</b> The port's invocation sequence runs in
/// <code>%SYS</code> (AD-2, AD-16), where an <code>OcuPilot.*</code> class reference raises
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code>. A process-private global is visible from either
/// namespace, so this writes the recorder's own nodes directly.</p>
Class OcuPilot.Test.AsTheUserProbe.Port Extends OcuPilot.Port.AdminPort
{

ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Set ^||OcuPilotAsTheUser("port", "user") = $Username
    Set ^||OcuPilotAsTheUser("port", "roles") = $Roles
    Set ^||OcuPilotAsTheUser("port", "count") = $Get(^||OcuPilotAsTheUser("port", "count"), 0) + 1
    Quit ##super(pResource)
}

}
