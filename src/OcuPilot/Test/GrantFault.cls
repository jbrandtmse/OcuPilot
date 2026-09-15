/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> whose grant read-back
/// (<method>OcuPilot.Install.Installer.SqlPrivilegeHeld</method>) reports one armed table as not
/// held, so <class>OcuPilot.Test.GrantReadBack</class> can drive a grant that did not take
/// without revoking anything. Every other table reads back through the real check.</p>
/// <p>The armed table lives in a process-private global, because the install path dispatches
/// class methods and never carries an instance.</p>
Class OcuPilot.Test.GrantFault Extends OcuPilot.Install.Installer
{

/// <p>Report <var>pTable</var> as not held until <method>Disarm</method>.</p>
ClassMethod ArmNotHeld(pTable As %String)
{
    Set ^||OcuPilotGrantFault = pTable
}

/// <p>Back to the real read-back.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotGrantFault
}

ClassMethod SqlPrivilegeHeld(pRole As %String, pTable As %String, pNamespace As %String) As %Boolean
{
    If $Get(^||OcuPilotGrantFault) = pTable Quit 0
    Quit ##super(pRole, pTable, pNamespace)
}

}
