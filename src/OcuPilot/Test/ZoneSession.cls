/// <p>Test-only launcher of a child <code>iris session</code> whose environment sets <code>TZ</code>: the way a
/// test on a UTC instance runs code in another zone, because a process can set <code>$ZTIMEZONE</code> without
/// moving the vendor's <code>-3</code> conversions, which follow the operating system's zone for the process.</p>
/// <p>It needs <code>%System_CallOut:USE</code> and a child session that signs in without a password, as the
/// operating system's user of the instance does in the container. It writes nothing to the instance; the child's
/// output files are deleted unread.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ZoneSession Extends %RegisteredObject
{

/// <p>Run <var>pCommand</var>, the routine argument of <code>iris session</code>, in a new session in the
/// caller's namespace whose environment sets <code>TZ</code> to <var>pZone</var>, and answer the JSON object the
/// child signals to this process (<code>$System.Event.Signal($Job, ...)</code>), or an object carrying
/// <code>error</code> when nothing arrives within <var>pWaitSeconds</var> or the launch raises.</p>
ClassMethod Signalled(pZone As %String, pCommand As %String, pWaitSeconds As %Integer = 120) As %DynamicObject
{
    Set tOut = {}
    Set tFile = ##class(%File).TempFilename("txt")
    Try {
        Do $System.Event.Clear($Job)
        Set tCode = $ZF(-100, "/ASYNC /STDOUT=""" _ tFile _ """ /STDERR=""" _ tFile _ ".err""", "/usr/bin/env", "TZ=" _ pZone, $System.Util.BinaryDirectory() _ "iris", "session", ##class(%SYS.System).GetInstanceName(), "-U", $NAMESPACE, pCommand)
        Set tMessage = $System.Event.WaitMsg("", pWaitSeconds)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child session signalled nothing within " _ pWaitSeconds _ " seconds, code " _ tCode)
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Set tDeleted = ##class(%File).Delete(tFile)
    Set tDeleted = ##class(%File).Delete(tFile _ ".err")
    Quit tOut
}

}
