/// <p>The child process <class>OcuPilot.Test.ToolSetFull</class> starts to assemble a turn's
/// advertised tool set as a <b>real least-privileged principal</b> (Story 5.4, AC3). It logs in as
/// that principal, asks <method>OcuPilot.Kernel.Agent.Dispatch.Advertise</method> for the array
/// every provider request of a turn carries, and signals the roster it got to its parent.</p>
/// <p>It runs in its own process so the login never touches the test's own identity, which holds
/// <code>%All</code> and for which the real privilege check answers yes to everything.</p>
Class OcuPilot.Test.ToolSetProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var>, advertise, and signal
/// <code>{loggedIn, username, roles, count, names, status}</code> to process <var>pParent</var>,
/// or <code>{error}</code> when something raised. <code>names</code> is the wire names in the
/// order they were advertised, comma-separated.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Do tOut.%Set("roles", $Roles)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Advertise(.tTools)
        Do tOut.%Set("status", $System.Status.GetErrorText(tSC))
        Set tNames = ""
        For tI = 1:1:+$Get(tTools) {
            Set tNames = tNames _ $Select(tI = 1: "", 1: ",") _ $Get(tTools(tI, "name"))
        }
        Do tOut.%Set("count", +$Get(tTools), "number")
        Do tOut.%Set("names", tNames, "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
