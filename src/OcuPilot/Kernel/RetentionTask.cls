/// <p>The daily retention task (AD-37): a <code>%SYS.Task.Definition</code> whose run is
/// <method>OcuPilot.Kernel.Retention.Sweep</method>. <class>OcuPilot.Install.Installer</class>
/// creates one task of this class, in the install namespace, and removes it on uninstall.</p>
Class OcuPilot.Kernel.RetentionTask Extends %SYS.Task.Definition
{

Parameter TaskName = "OcuPilot transcript retention";

/// <p>Sweep once. A failed step answers its status, which the Task Manager records as the run's
/// result; every other step has still run.</p>
Method OnTask() As %Status
{
    Quit ##class(OcuPilot.Kernel.Retention).Sweep()
}

}
