/// <p><class>OcuPilot.Port.AnalyticsPort</class> that waits no time for the namespace's settings lock, so a test renders the script forms of the settings writes with a lock line that gives up at once and runs
/// them while another process holds the lock without waiting out the production wait. It also holds that lock from a process of its own (<method>Hold</method>), because a lock this process took is
/// one a script run in it takes again. It overrides nothing else.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsSettingsLockSeam Extends OcuPilot.Port.AnalyticsPort
{

Parameter SETTINGLOCKSECONDS As INTEGER = 0;

/// <p>The longest a held lock is kept, in seconds, whatever the test does: the holder then lets go and ends.</p>
Parameter HOLDSECONDS As INTEGER = 90;

/// <p>Start a process that takes the settings lock of <var>pNamespace</var> and keeps it until <method>Release</method> or <parameter>HOLDSECONDS</parameter>, and wait until it holds it: 1 when it does.</p>
ClassMethod Hold(pNamespace As %String) As %Boolean
{
    Kill ^CacheTemp.OcuPilotLockSeam
    Job ##class(OcuPilot.Test.AnalyticsSettingsLockSeam).Holder(pNamespace)
    For tWait = 1:1:100 {
        If $Get(^CacheTemp.OcuPilotLockSeam("held")) Quit
        Hang 0.1
    }
    Quit +$Get(^CacheTemp.OcuPilotLockSeam("held"))
}

/// <p>The holder process: take the lock, say so, and keep it until released or until <parameter>HOLDSECONDS</parameter> have passed.</p>
ClassMethod Holder(pNamespace As %String)
{
    Lock +^CacheTemp.OcuPilotAnalyticsSettings(pNamespace):5
    If '$Test Quit
    Set ^CacheTemp.OcuPilotLockSeam("held") = 1
    For tWait = 1:1:(..#HOLDSECONDS * 10) {
        If $Get(^CacheTemp.OcuPilotLockSeam("release")) Quit
        Hang 0.1
    }
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(pNamespace)
    Kill ^CacheTemp.OcuPilotLockSeam("held")
    Set ^CacheTemp.OcuPilotLockSeam("done") = 1
}

/// <p>Let the holder go and wait until it has released the lock.</p>
ClassMethod Release(pNamespace As %String)
{
    Set ^CacheTemp.OcuPilotLockSeam("release") = 1
    For tWait = 1:1:100 {
        If $Get(^CacheTemp.OcuPilotLockSeam("done")) Quit
        If '$Get(^CacheTemp.OcuPilotLockSeam("held")) Quit
        Hang 0.1
    }
    Kill ^CacheTemp.OcuPilotLockSeam
}

}
