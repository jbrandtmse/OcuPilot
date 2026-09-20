/// <p>Fixture: the recorder <class>OcuPilot.Test.AsTheUserProbe.Tool</class> and
/// <class>OcuPilot.Test.AsTheUserProbe.Port</class> write into, so a test can read what
/// <code>$USERNAME</code> and <code>$ROLES</code> were <b>at the moment a tool body ran</b> and
/// <b>inside a port call</b> (Story 5.4, AC1 and AC4).</p>
/// <p>Nothing here escalates, spawns or writes to the instance: the observations live in
/// <code>^||OcuPilotAsTheUser</code> and die with the process.</p>
Class OcuPilot.Test.AsTheUserProbe Extends %RegisteredObject
{

/// <p>Forget every observation.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotAsTheUser
}

/// <p>Record <code>$USERNAME</code> and <code>$ROLES</code> as they read at this instant, under
/// <var>pWhere</var> (<code>tool</code> or <code>port</code>). Called from the recording frame
/// itself, never from a helper -- a snapshot taken one frame out is a snapshot of the wrong
/// frame.</p>
ClassMethod Record(pWhere As %String)
{
    Set ^||OcuPilotAsTheUser(pWhere, "user") = $Username
    Set ^||OcuPilotAsTheUser(pWhere, "roles") = $Roles
    Set ^||OcuPilotAsTheUser(pWhere, "count") = $Get(^||OcuPilotAsTheUser(pWhere, "count"), 0) + 1
}

/// <p>What was observed at <var>pWhere</var>: <code>user</code>, <code>roles</code> or
/// <code>count</code>.</p>
ClassMethod Observed(pWhere As %String, pField As %String) As %String
{
    Quit $Get(^||OcuPilotAsTheUser(pWhere, pField), "")
}

/// <p>Whether <var>pRoles</var>, a comma-separated <code>$ROLES</code> value, carries
/// <var>pRole</var>. Role names normalize to upper case in <code>$ROLES</code>, so the comparison
/// is made upper-case on both sides.</p>
ClassMethod CarriesRole(pRoles As %String, pRole As %String) As %Boolean
{
    Quit $ListFind($ListFromString($ZConvert(pRoles, "U"), ","), $ZConvert(pRole, "U")) > 0
}

}
