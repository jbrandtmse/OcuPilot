/// <p>DW-67 (rework iteration 6). Fault-injection subclass of
/// <class>OcuPilot.Install.Installer</class> whose live Web Gateway registry read
/// (<method>OcuPilot.Install.Installer.GatewayTimeoutFromRegistry</method>) can be made to
/// answer nothing, to fail, or to answer a stub value, so the real, unmodified
/// <method>OcuPilot.Install.Installer.GatewayResponseTimeout</method> can be driven down
/// its configuration-file fallback on an instance whose registry does answer. Before this
/// seam, the fallback call was reachable only on a container whose Gateway had not
/// registered yet.</p>
/// <p>The mode lives in a process-private global rather than a property, as in
/// <class>OcuPilot.Test.MigrateFault</class> and for the same reason: the real code path
/// makes class-method dispatches that never carry an instance.</p>
Class OcuPilot.Test.GatewayGap Extends OcuPilot.Install.Installer
{

/// <p>The value the registry "answers" in <parameter>STUBMODE</parameter> -- deliberately
/// not a value any real <code>CSP.ini</code> carries, so a test can tell which source
/// answered.</p>
Parameter STUBTIMEOUT = 7777;

/// <p>0: the real registry read (the default). 1: the registry answers nothing.</p>
Parameter SILENTMODE = 1;

/// <p>2: the registry read fails with an error status.</p>
Parameter FAILMODE = 2;

/// <p>3: the registry answers <parameter>STUBTIMEOUT</parameter>.</p>
Parameter STUBMODE = 3;

/// <p>Select the registry's behavior -- see the mode parameters.</p>
ClassMethod SetRegistryMode(pMode As %Integer)
{
    Set ^||OcuPilotGatewayGapMode = pMode
}

/// <p>Back to the real registry read. Called from every driving test's own cleanup path,
/// including its <code>Catch</code>.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotGatewayGapMode
}

/// <p>The registry read, forced into the selected mode (default: the real read).</p>
ClassMethod GatewayTimeoutFromRegistry(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = ""
    Set pSource = ""
    Set tMode = +$Get(^||OcuPilotGatewayGapMode, 0)
    If tMode = ..#SILENTMODE Quit $$$OK
    If tMode = ..#FAILMODE Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GatewayGap: induced Gateway registry read failure")
    If tMode = ..#STUBMODE {
        Set pTimeout = ..#STUBTIMEOUT
        Set pSource = "stub Gateway registry"
        Quit $$$OK
    }
    Quit ##super(.pTimeout, .pSource)
}

}
