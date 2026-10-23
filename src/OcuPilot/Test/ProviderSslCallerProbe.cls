/// <p>The child process <class>OcuPilot.Test.ProviderSslCallers</class> starts to make one provider call as a real
/// principal. It logs in as that principal, makes the call through <class>OcuPilot.Test.ProviderPortProbe</class> with the
/// real TLS read (the probe's gate is allowed, its adapter a stub that opens no socket), and signals the outcome to its
/// parent as JSON.</p>
/// <p>It runs in its own process so the login never touches the test's own identity; the process ends when
/// <method>Run</method> returns.</p>
Class OcuPilot.Test.ProviderSslCallerProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var>, make the call <method>OcuPilot.Test.ProviderSslCallTime.Call</method> makes, and
/// signal <code>{loggedIn, username, roles, code, status, reason, calls, rolesKept}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised. <code>rolesKept</code> is 1 when <code>$ROLES</code> reads the same after the
/// call as before it.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Do tOut.%Set("roles", $ROLES)
        Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
        Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(##class(OcuPilot.Test.ProviderSslCallTime).#PROBEKEY)
        Set tRoles = $ROLES
        Set tFault = ##class(OcuPilot.Test.ProviderSslCallTime).Call(.tStatus)
        Do tOut.%Set("code", ##class(OcuPilot.Test.ProviderSslCallTime).Said(tFault))
        Do tOut.%Set("status", +$Get(tStatus), "number")
        Do tOut.%Set("reason", ##class(OcuPilot.Test.ProviderSslCallTime).Reason(tFault))
        Do tOut.%Set("calls", ##class(OcuPilot.Test.ProviderStub).Calls(), "number")
        Do tOut.%Set("rolesKept", (tRoles = $ROLES), "boolean")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
