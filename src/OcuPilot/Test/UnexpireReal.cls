/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> whose install account
/// (<parameter>UNEXPIREACCOUNT</parameter>) is a throwaway account
/// <class>OcuPilot.Test.UnexpireScope</class> creates expired and deletes again (code review
/// round 4). So a <method>OcuPilot.Install.Installer.StartPath</method>-form install of the
/// <code>"probe"</code> profile through this class runs the real
/// <method>OcuPilot.Install.Installer.EnsureUnexpired</method> from inside
/// <method>OcuPilot.Install.Installer.Install</method>'s <code>%SYS</code> region, as a clean
/// clone's first start does, without touching <code>_SYSTEM</code>. Nothing else is
/// overridden. <b>Call only <code>Install("probe", 1)</code> on it</b>: any production call would
/// run the real install of production with this account in place of <code>_SYSTEM</code>.</p>
Class OcuPilot.Test.UnexpireReal Extends OcuPilot.Install.Installer
{

/// <p>The throwaway account <class>OcuPilot.Test.UnexpireScope</class> creates, never a real
/// one.</p>
Parameter UNEXPIREACCOUNT As %String = "OcuPilotTestUnexpireReal";

}
