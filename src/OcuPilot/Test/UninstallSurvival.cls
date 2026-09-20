/// <p>Story 13.1, AC3 and AC4 -- what a confirmed uninstall must <b>not</b> destroy, and what
/// install puts back. AC3 asserts as one pair that the registration of an OcuPilot audit triple
/// is gone after uninstall while a row already emitted under it is <b>still readable</b> from
/// <class>%SYS.Audit</class>, with instance auditing still on: the registration is OcuPilot's,
/// the rows are the instance's record (AD-15, AD-46). AC4 asserts that uninstall then install
/// returns the profile to a byte-identical
/// <method>OcuPilot.Install.Installer.StateFingerprint</method> and that the profile's
/// unauthenticated API application answers over loopback again.</p>
/// <p>Audit reads carry <code>%NOINDEX</code> on the three event predicates and a
/// <code>UTCTimeStamp</code> bound (DW-85): <class>%SYS.Audit</class>'s event indexes are
/// brought up to date by a background pass about every 60 seconds, so a plan that reads them
/// cannot see a row this run just wrote and answers a false zero.</p>
/// <p>Every assertion runs against the disposable <code>"probe"</code> profile, and the class
/// also runs OcuPilot's <b>production</b> install, so it runs on a throwaway container only
/// (<file>scripts/ci-throwaway.sh</file>). <method>OnBeforeAllTests</method> refuses unless
/// <b>both</b> <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>AUDITARMINGVARIABLE</parameter> arm it, and
/// <method>OnAfterAllTests</method> carries the same guard, because
/// <class>%UnitTest.Manager</class> calls it even after
/// <method>OnBeforeAllTests</method> returned an error.</p>
Class OcuPilot.Test.UninstallSurvival Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the production install this class runs, and the one
/// value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The environment variable that arms the audit-event work: this class emits a row into
/// the instance's audit database and then removes the registration it was emitted under.</p>
Parameter AUDITARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_EVENTS";

/// <p>The profile suffix <method>OcuPilot.Install.Installer.Names</method> applies to the
/// disposable profile's object names.</p>
Parameter PROBESUFFIX As %String = "Probe";

/// <p>The dispatch class of the one unauthenticated API application AD-45 puts readiness on,
/// so the loopback leg finds its path through the roster rather than spelling it.</p>
Parameter READINESSCLASS As %String = "OcuPilot.Api.Readiness";

/// <p>The description every row this class emits carries. Under
/// <class>%SYS.Audit</class>'s own 128-byte bound.</p>
Parameter EMITDESCRIPTION As %String = "OcuPilot.Test.UninstallSurvival probe row (AC3)";

/// <p>Refuse to run at all unless this instance is armed for both effects.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallSurvival runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#AUDITARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallSurvival writes a row into this instance's audit database and removes the registration it was emitted under, and runs on a throwaway container only. " _ ..#AUDITARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Production first, then the probe: every install records its stamp through production's
/// privileged routine application, and production's install is what enables instance auditing
/// so an emission can land at all.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

Method OnAfterOneTest() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$OK
    }
    If $System.Util.GetEnviron(..#AUDITARMINGVARIABLE) '= 1 {
        Quit $$$OK
    }
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>AC3 -- a row emitted under the probe triple outlives the deletion of that triple's
/// registration. The pair is what discriminates: the registration must be absent <b>and</b>
/// the row still readable. Either half alone would pass under a regression that destroyed
/// the instance's own record, or under one that never removed the registration.</p>
Method TestAnEmittedRowOutlivesItsRegistration()
{
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tEvent = $ListGet(##class(OcuPilot.Kernel.Audit.Event).Names(..#PROBESUFFIX), 1)
    Do $$$AssertTrue(tEvent '= "", "the probe roster declares a triple to emit through")
    Do $$$AssertEquals(..RegistrationExists(tSource, tType, tEvent), 1, "the probe triple " _ tEvent _ " is registered after install")

    Set tMarker = ..Marker()
    Set tSince = ..Now()
    Set tEmitSC = $System.Security.Audit(tSource, tType, tEvent, tMarker, ..#EMITDESCRIPTION)
    Do $$$AssertStatusOK(tEmitSC, "the emission through the registered probe triple returns OK")
    Set tRowsBefore = ..RowsCarrying(tSince, tEvent, tMarker)
    Do $$$AssertEquals(tRowsBefore, 1, "exactly one row carrying this run's marker is readable before uninstall; read=" _ tRowsBefore)

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds: " _ $System.Status.GetErrorText(tSC))

    Set tStillRegistered = ..RegistrationExists(tSource, tType, tEvent)
    Do $$$AssertEquals(tStillRegistered, 0, "the triple's registration is gone after uninstall; read=" _ tStillRegistered)
    Set tRowsAfter = ..RowsCarrying(tSince, tEvent, tMarker)
    Do $$$AssertEquals(tRowsAfter, 1, "and the row emitted under it is STILL readable from %SYS.Audit -- the rows are the instance's record, not OcuPilot's (AD-15, AD-46); read=" _ tRowsAfter)
    Set tAuditing = ..AuditingEnabled()
    Do $$$AssertEquals(tAuditing, 1, "and instance-wide auditing is still enabled; read=" _ tAuditing)
}

/// <p>AC4 -- uninstall then install returns the profile to the state it was in, and the
/// profile's unauthenticated API application serves again. The fingerprint is read three
/// times, and the middle reading is what makes the equality load-bearing: on its own,
/// <var>tAfter</var> = <var>tBefore</var> is an <b>idempotency</b> guard that a `Uninstall`
/// regressed to a complete no-op would also satisfy, because uninstall deletes every object
/// the fingerprint folds and install recreates them from roster constants. Asserting that the
/// post-uninstall reading <b>differs</b> pins that the cycle the equality spans actually
/// happened. The fingerprint does not cover the SQL grant, and it is compared only against
/// itself, so the loopback request stands beside it as a live oracle: an anonymous GET proves
/// the recreated application is reachable, routes, and loads its dispatch class behind its
/// AD-21 floor. The request asserts reachability only --
/// <method>OcuPilot.Api.Readiness</method> answers 200 in every gate state and reports the
/// state in its body, so a 200 is not itself a claim that the instance is installed.</p>
Method TestUninstallThenInstallRestoresTheProfileAndServes()
{
    Set tPath = ..ReadinessPath()
    Do $$$AssertTrue(tPath '= "", "the roster declares the unauthenticated readiness application, so the loopback leg asserts something")
    Set tBefore = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertTrue($Extract(tBefore, 1, 6) '= "ERROR:", "the pre-uninstall fingerprint was read: " _ tBefore)
    Set tBeforeStatus = ..Answers(tPath)
    Do $$$AssertEquals(tBeforeStatus, 200, "the probe API answers over loopback before the cycle; status=" _ tBeforeStatus)

    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do $$$AssertStatusOK(tSC, "confirmed uninstall succeeds: " _ $System.Status.GetErrorText(tSC))
    Set tMid = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertNotEquals(tMid, tBefore, "the uninstall moved the state the fingerprint folds, so the equality below compares two readings a real cycle separates; before=" _ tBefore _ " mid=" _ tMid)
    Set tSC2 = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusOK(tSC2, "the reinstall succeeds: " _ $System.Status.GetErrorText(tSC2))

    Set tAfter = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")
    Do $$$AssertTrue($Extract(tAfter, 1, 6) '= "ERROR:", "the post-reinstall fingerprint was read: " _ tAfter)
    Do $$$AssertEquals(tAfter, tBefore, "the fingerprint is byte-identical after uninstall then install; before=" _ tBefore _ " after=" _ tAfter)
    Set tAfterStatus = ..Answers(tPath)
    Do $$$AssertEquals(tAfterStatus, 200, "and the probe API answers over loopback again; status=" _ tAfterStatus)
}

/// <p>Whether the triple <var>pSource</var>/<var>pType</var>/<var>pEvent</var> is registered:
/// <code>1</code> registered, <code>0</code> absent, <code>-1</code> when the read itself
/// failed. Three-valued rather than Boolean because the caller asserts the <b>negative</b>
/// after uninstall, and a failed lookup read as a negative result would pass that assertion on
/// no evidence. Switches to <code>%SYS</code> and restores (AD-16).</p>
Method RegistrationExists(pSource As %String, pType As %String, pEvent As %String) As %Integer
{
    Set tExists = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) Set tExists = ''##class(Security.Events).Exists(pSource, pType, pEvent, .tObj, .tS)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tExists = -1
    }
    Quit tExists
}

/// <p>Whether instance-wide auditing is on, read from <class>Security.System</class>'s own
/// record rather than from the <code>[ Internal ]</code> helper. <code>-1</code> when the
/// read failed, so a failure never compares equal to "off".</p>
Method AuditingEnabled() As %Integer
{
    Set tOn = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            Set tGetSC = ##class(Security.System).Get("SYSTEM", .tProps)
            If $$$ISOK(tGetSC) Set tOn = +$Get(tProps("AuditEnabled"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOn = -1
    }
    Quit tOn
}

/// <p>How many rows the audit database's master map holds for <var>pEvent</var> since
/// <var>pSince</var> whose <code>EventData</code> carries <var>pMarker</var>.
/// <code>-1</code> when the read itself failed.</p>
/// <p><b><var>pSince</var> bounds the read; the marker identifies the row.</b>
/// <code>$ZTimeStamp</code>'s resolution is coarser than the interval between two consecutive
/// writes on this build, so a time bound alone cannot name "the row this run wrote".</p>
Method RowsCarrying(pSince As %String, pEvent As %String, pMarker As %String) As %Integer
{
    Set tRows = -1
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, tSource, tType, pEvent)
        If tRS.%SQLCODE < 0 {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRows = 0
        While tRS.%Next() {
            If tRS.%Get("EventData") '[ pMarker Continue
            Set tRows = tRows + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>A marker unique to this call, so a read bounded by time cannot be satisfied by a row an
/// earlier run wrote in the same second.</p>
Method Marker() As %String
{
    Quit "OcuPilotProbeSurvival" _ $Translate($System.Util.CreateGUID(), "-", "")
}

/// <p>A lower bound for the read below, in the ODBC form <code>%SYS.Audit.UTCTimeStamp</code>
/// carries. <b>Truncated to whole seconds deliberately:</b> that column is
/// <class>%String</class>, so <code>&gt;=</code> compares lexicographically, and a bound
/// carrying more fractional digits than the stored value sorts <i>after</i> the very row it
/// must include. Widening the bound costs nothing -- the run's own marker, not the time, is
/// what identifies the row.</p>
Method Now() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, , 0)
}

/// <p>The probe profile's path for the unauthenticated readiness application, derived from
/// the roster entry whose declared dispatch class is <parameter>READINESSCLASS</parameter>,
/// with the trailing slash its root route takes. <code>""</code> when the roster declares no
/// such application.</p>
Method ReadinessPath() As %String
{
    Set tFound = ""
    Try {
        Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
        For tI = 1:1:$Length(tKeys, ",") {
            Set tKey = $Piece(tKeys, ",", tI)
            If tKey = "" Continue
            Set tSC = ##class(OcuPilot.Install.Roster).Application(tKey, .tApp)
            If $$$ISERR(tSC) Continue
            If '$IsObject(tApp) Continue
            If '$IsObject(tApp.manifest) Continue
            If tApp.manifest.DispatchClass '= ..#READINESSCLASS Continue
            Set tFound = ##class(OcuPilot.Install.Installer).ProbeApplicationPath(tApp.path)
            Quit
        }
    } Catch ex {
        Set tFound = ""
    }
    If tFound = "" Quit ""
    Quit tFound _ "/"
}

/// <p>The HTTP status an anonymous loopback GET of <var>pPath</var> answers -- the
/// application is unauthenticated, so sending credentials would prove nothing about it.
/// <code>-1</code> when the request itself could not be made.</p>
Method Answers(pPath As %String) As %Integer
{
    Set tStatus = -1
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, "", "", .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit -1
    Quit +tStatus
}

}
