/// <p>Pins the provider's call-time TLS verification read for every caller (AD-9's third purpose, AD-32, Story 18.40): a
/// configuration the egress row names that no longer requires the server's certificate refuses a <code>%Developer</code>-only
/// caller, an <code>%Operator</code> caller and a <code>%All</code> caller alike, before any request is sent, because the
/// read runs through <code>OcuPilotSslRead</code> and not through what the caller may read of the security database; a
/// configuration that verifies serves the <code>%Developer</code> caller; and a read that cannot be entered refuses with the
/// sentence that names the repair.</p>
/// <p>Each caller is a real principal in a child process (<class>OcuPilot.Test.ProviderSslCallerProbe</class>) that makes
/// the call through <class>OcuPilot.Test.ProviderPortProbe</class>, whose adapter is a stub, so no socket is opened. A
/// principal holds its vendor role and a probe role granting read of the install namespace's code and globals databases,
/// which a request through OcuPilot's web application gives every caller.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>SSLARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes three users, a role and an
/// SSL/TLS configuration and briefly disables OcuPilot's own TLS read application, which every test restores to the state it
/// recorded.</p>
Class OcuPilot.Test.ProviderSslCallers Extends %UnitTest.TestCase
{

/// <p>The environment variables that arm this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SSLARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter PROBE = "OcuPilotProbeCallers";

Parameter CODEROLE = "OcuProbe1840CodeRole";

Parameter DEVELOPER = "OcuProbe1840Developer";

Parameter OPERATOR = "OcuProbe1840Operator";

Parameter ALLHOLDER = "OcuProbe1840AllHolder";

/// <p>The probe principals' password, drawn at random per run.</p>
Property PreparedPassword As %String;

/// <p>The stored fields of OcuPilot's TLS read application before the test, to put back after it.</p>
Property PreparedApp [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

/// <p>Refuse to run unless this instance is armed for throwaway principals and configurations, then create the role and the
/// three users and read back what each holds.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#SSLARMINGVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProviderSslCallers creates and deletes IRIS users, a role and an SSL/TLS configuration on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#SSLARMINGVARIABLE _ " do not both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).CodeDatabaseResource(tOrigNS, .tResources, .tGrants)
        If $$$ISERR(tSC) Quit
        Set ..PreparedPassword = "OcuPilotCallers" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Do ..RemovePrincipals()
        Set tSC = ##class(Security.Roles).Create(..#CODEROLE, "OcuPilot test: code database read (throwaway)", tGrants, "")
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateUser(..#DEVELOPER, "%Developer," _ ..#CODEROLE)
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateUser(..#OPERATOR, "%Operator," _ ..#CODEROLE)
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateUser(..#ALLHOLDER, "%All")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the egress row, the probe configuration, the users and the role, and return a failing status if any survives.
/// A test whose <method>OnBeforeOneTest</method> failed after creating the probe is not followed by its
/// <method>OnAfterOneTest</method>, so the probe and the row are removed here as well.</p>
Method OnAfterAllTests() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tLeft = ""
    Try {
        Do ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
        Do ##class(OcuPilot.Test.EgressSslProbe).Remove(..#PROBE)
        If ##class(OcuPilot.Test.EgressSslProbe).Exists(..#PROBE) Set tLeft = " configuration " _ ..#PROBE
        Set $NAMESPACE = "%SYS"
        Set tLeft = tLeft _ ..RemovePrincipals()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = "removal raised: " _ ex.DisplayString()
    }
    Quit $Select(tLeft = "": $$$OK, 1: $$$ERROR($$$GeneralError, "probe principals survived the class:" _ tLeft))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(##class(OcuPilot.Test.ProviderSslCallTime).#PROBEKEY)
    Kill ..PreparedApp
    Set tSC = ##class(OcuPilot.Test.OwnRoutineApplication).Stored(##class(OcuPilot.Kernel.State.Base).#SSLREADAPPLICATION, .tProps)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedApp = tProps
    Set tSC = ##class(OcuPilot.Test.EgressSslProbe).Ensure(..#PROBE)
    If $$$ISERR(tSC) Quit tSC
    Set tValues("sslConfiguration") = ..#PROBE
    Quit ##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues)
}

Method OnAfterOneTest() As %Status
{
    Kill tWas
    Merge tWas = ..PreparedApp
    Do $$$AssertStatusOK(##class(OcuPilot.Test.OwnRoutineApplication).PutBack(##class(OcuPilot.Kernel.State.Base).#SSLREADAPPLICATION, .tWas), "OcuPilot's TLS read application is put back as it was recorded")
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "the egress row this method wrote is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Remove(..#PROBE), "the probe configuration is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressSslProbe).Exists(..#PROBE), 0, "and none survives")
    Quit $$$OK
}

/// <p>A configuration the egress row names that does not require the server's certificate refuses a <code>%Developer</code>
/// caller, an <code>%Operator</code> caller and a <code>%All</code> caller the same: <code>PROVIDER.TLS</code> at 503
/// naming the configuration and the remedy, the transport never entered, and <code>$ROLES</code> as it was after the
/// call.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.State.Base.GuardedSslConfigRead</method> replace the
/// <code>AddRoles</code> of <parameter>SSLREADAPPLICATION</parameter> with <code>$$$OK</code> -- the
/// <code>%Developer</code> and <code>%Operator</code> legs go red, those callers reading an unavailable answer, and the
/// <code>%All</code> leg stays green.</p>
Method TestEveryCallerIsRefusedAConfigurationThatDoesNotVerify()
{
    Set tProps("VerifyPeer") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .tProps), "the probe configuration stops requiring the server's certificate outside OcuPilot")
    For tUser = ..#DEVELOPER, ..#OPERATOR, ..#ALLHOLDER {
        Set tCall = ..CallAs(tUser)
        Do $$$AssertEquals(tCall.%Get("loggedIn"), 1, tUser _ " signs in: " _ tCall.%ToJSON())
        Do $$$AssertEquals(tCall.%Get("code") _ " " _ tCall.%Get("status"), "PROVIDER.TLS 503", tUser _ ": the call is refused")
        Do $$$AssertTrue((tCall.%Get("reason") [ ..#PROBE) && (tCall.%Get("reason") [ "Clear the name on Switches"), tUser _ ": naming the configuration and the remedy: " _ tCall.%Get("reason"))
        Do $$$AssertEquals(tCall.%Get("calls"), 0, tUser _ ": and the transport is not entered")
        Do $$$AssertEquals(tCall.%Get("rolesKept"), 1, tUser _ ": and the roles are as they were after the call")
    }
    Set tDeveloper = ..CallAs(..#DEVELOPER)
    Do $$$AssertTrue((tDeveloper.%Get("roles") [ "%Developer") && '(tDeveloper.%Get("roles") [ "%All"), "the %Developer principal holds no wider role: " _ tDeveloper.%Get("roles"))
}

/// <p>A configuration that requires the server's certificate serves a <code>%Developer</code> caller and an
/// <code>%Operator</code> caller: the call is not refused and reaches the transport once.</p>
/// <p>Mutation (Rule 19): as above, the elevation dropped -- both legs go red.</p>
Method TestAVerifyingConfigurationServesAnOrdinaryCaller()
{
    For tUser = ..#DEVELOPER, ..#OPERATOR {
        Set tCall = ..CallAs(tUser)
        Do $$$AssertEquals(tCall.%Get("code"), "", tUser _ ": the call is not refused: " _ tCall.%ToJSON())
        Do $$$AssertEquals(tCall.%Get("calls"), 1, tUser _ ": and reaches the transport")
    }
}

/// <p>A TLS read application that is disabled refuses every caller with the sentence that names the repair, and nothing is
/// sent; a name the vendor cannot hold is absent without the read being entered at all, so the disabled application
/// changes nothing for it. Enabled again, the next call goes through.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.State.Base.GuardedSslConfigRead</method> drop the shape check -- the
/// last leg reads an unavailable answer and goes red.</p>
Method TestADisabledReadApplicationRefusesWithTheRepairSentence()
{
    Set tApp = ##class(OcuPilot.Kernel.State.Base).#SSLREADAPPLICATION
    Do $$$AssertTrue(..SetApplicationEnabled(tApp, 0), "OcuPilot's TLS read application is disabled and the instance reads it back disabled")
    For tUser = ..#DEVELOPER, ..#ALLHOLDER {
        Set tCall = ..CallAs(tUser)
        Do $$$AssertEquals(tCall.%Get("code") _ " " _ tCall.%Get("status"), "PROVIDER.TLS 503", tUser _ ": the call is refused")
        Do $$$AssertTrue((tCall.%Get("reason") [ "run install again") && (tCall.%Get("reason") [ ..#PROBE), tUser _ ": naming the configuration and the repair: " _ tCall.%Get("reason"))
        Do $$$AssertEquals(tCall.%Get("calls"), 0, tUser _ ": and the transport is not entered")
    }
    Set tPort = "OcuPilot.Port.ProviderPort"
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", ..#PROBE), "unavailable", "in this process too, the read is unavailable")
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", $Translate($Justify("", 65), " ", "x")), "absent", "a name longer than the vendor holds is absent without the read being entered")
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", "x" _ $Char(1) _ "y"), "absent", "so is one carrying a control character")
    Do $$$AssertTrue(..SetApplicationEnabled(tApp, 1), "the application is enabled again")
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", ..#PROBE), "ok", "and the next read answers")
    Set tCall = ..CallAs(..#DEVELOPER)
    Do $$$AssertEquals(tCall.%Get("code"), "", "and the %Developer caller's call is served: " _ tCall.%ToJSON())
}

/// <p>A TLS read application that is absent refuses every caller the same way: the repair sentence, nothing sent. The test
/// puts the application back from the state it recorded.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.State.Base.GuardedSslConfigRead</method> let a failed
/// <code>AddRoles</code> answer instead of quitting unanswered -- the refusals read "not present" and not the repair, and
/// this and the disabled-application leg go red.</p>
Method TestAMissingReadApplicationRefusesWithTheRepairSentence()
{
    Do $$$AssertTrue(..RemoveApplication(##class(OcuPilot.Kernel.State.Base).#SSLREADAPPLICATION), "OcuPilot's TLS read application is removed and the instance no longer holds it")
    For tUser = ..#DEVELOPER, ..#ALLHOLDER {
        Set tCall = ..CallAs(tUser)
        Do $$$AssertEquals(tCall.%Get("code") _ " " _ tCall.%Get("status"), "PROVIDER.TLS 503", tUser _ ": the call is refused")
        Do $$$AssertTrue((tCall.%Get("reason") [ "run install again") && (tCall.%Get("reason") [ ..#PROBE), tUser _ ": naming the configuration and the repair: " _ tCall.%Get("reason"))
        Do $$$AssertEquals(tCall.%Get("calls"), 0, tUser _ ": and the transport is not entered")
    }
}

/// <p>The escalation is gone when the read returns: this process holds the roles and the namespace it held before, for a
/// configuration that is present, one that is absent and a name that is not asked. This process holds <code>%All</code>, so
/// its role comparison is the weaker half; the children's <code>rolesKept</code> in
/// <method>TestEveryCallerIsRefusedAConfigurationThatDoesNotVerify</method> is the one that reddens when the role frame is
/// dropped.</p>
/// <p>Mutation (Rule 19): delete the namespace restore after the read in
/// <method>OcuPilot.Kernel.State.Base.GuardedSslConfigRead</method> -- this goes red, and the class stops after its first
/// failure because this process is left in <code>%SYS</code>.</p>
Method TestTheReadLeavesTheCallersRolesAndNamespaceAlone()
{
    Set tPort = "OcuPilot.Port.ProviderPort"
    Set tRoles = $ROLES
    Set tNs = $NAMESPACE
    For tName = ..#PROBE, ..#PROBE _ "Absent", "" {
        Do $ClassMethod(tPort, "SslConfigurationState", tName)
        Do $$$AssertEquals($ROLES, tRoles, "the roles are as they were after the read of '" _ tName _ "'")
        Do $$$AssertEquals($NAMESPACE, tNs, "and so is the namespace")
    }
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", ..#PROBE _ "Absent"), "absent", "a configuration no one holds reads absent")
    Do $$$AssertEquals($ClassMethod(tPort, "SslConfigurationState", ..#PROBE), "ok", "and one that verifies reads ok")
}

/// <p>One provider call made by the principal <var>pUser</var> in a child process, as <code>{loggedIn, username, roles, code,
/// status, reason, calls, rolesKept}</code>, or an object carrying <code>error</code>.</p>
ClassMethod CallAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.ProviderSslCallerProbe).Run($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Set the application <var>pName</var>'s <code>Enabled</code> to <var>pEnabled</var> and answer whether the instance reads
/// it back so.</p>
ClassMethod SetApplicationEnabled(pName As %String, pEnabled As %Boolean) As %Boolean
{
    Set tNow = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Enabled") = pEnabled
        Set tSC = ##class(Security.Applications).Modify(pName, .tProps)
        Kill tProps
        If $$$ISOK(tSC) {
            Set tSC = ##class(Security.Applications).Get(pName, .tProps)
            If $$$ISOK(tSC) Set tNow = +$Get(tProps("Enabled"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit (tNow = pEnabled)
}

/// <p>Delete the application <var>pName</var> and answer whether the instance no longer holds it.</p>
ClassMethod RemoveApplication(pName As %String) As %Boolean
{
    Set tGone = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Applications).Delete(pName)
        Set tGone = ($$$ISOK(tSC) && '##class(Security.Applications).Exists(pName))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tGone
}

/// <p>Create the probe user <var>pUser</var> holding the roles <var>pRoles</var>. <code>%SYS</code> must be current.</p>
Method CreateUser(pUser As %String, pRoles As %String) As %Status
{
    Quit ##class(Security.Users).Create(pUser, pRoles, ..PreparedPassword, "OcuPilot provider TLS read test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ProviderSslCallers; deleted in OnAfterAllTests")
}

/// <p>Delete the probe users and role when they exist, and answer what survived, one name per entry, or <code>""</code>.
/// <code>%SYS</code> must be current.</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = ""
    For tUser = ..#DEVELOPER, ..#OPERATOR, ..#ALLHOLDER {
        If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        If ##class(Security.Users).Exists(tUser) Set tLeft = tLeft _ " user " _ tUser
    }
    If ##class(Security.Roles).Exists(..#CODEROLE) Do ##class(Security.Roles).Delete(..#CODEROLE)
    If ##class(Security.Roles).Exists(..#CODEROLE) Set tLeft = tLeft _ " role " _ ..#CODEROLE
    Quit tLeft
}

}
