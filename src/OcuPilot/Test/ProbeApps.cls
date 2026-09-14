Include %occErrors

/// <p>The disposable <code>"probe"</code> profile's web applications, derived from
/// <class>OcuPilot.Install.Roster</class> rather than listed, for test setup, teardown and the
/// CI runner's after-class check (DW-242).</p>
/// <p><method>OcuPilot.Install.Installer.Uninstall</method> removes only the applications a
/// provenance row records (DW-94), and only those applications' matching roles, so a test that
/// deletes a probe row while the probe profile is installed leaves an application and its role
/// that no later uninstall can remove. <method>Remove</method> removes both, and
/// <method>Existing</method> is what <file>scripts/ci-unit-test.sh</file> reads before and after
/// every class.</p>
Class OcuPilot.Test.ProbeApps Extends %RegisteredObject
{

/// <p>Every probe application path the roster declares, as a <code>$List</code>, in the
/// roster's own order, with <var>pRoles</var>(path) set to that application's probe matching
/// role, or <code>""</code> when it declares none. A roster key that cannot be read or carries no
/// derivable path is skipped; <method>OcuPilot.Install.Installer.Install</method> refuses on
/// both.</p>
ClassMethod Paths(Output pRoles) As %List
{
    Kill pRoles
    Set tPaths = ""
    Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
    For tI = 1:1:$Length(tKeys, ",") {
        Set tKey = $Piece(tKeys, ",", tI)
        If tKey = "" Continue
        Set tSC = ##class(OcuPilot.Install.Roster).Application(tKey, .tApp)
        If $$$ISERR(tSC) Continue
        Set tPath = ##class(OcuPilot.Install.Installer).ProbeApplicationPath(tApp.path)
        If tPath = "" Continue
        Set tPaths = tPaths _ $ListBuild(tPath)
        ; The probe role is "Probe" + the roster's matchRole, as Installer.Names derives it.
        Set pRoles(tPath) = $Select(tApp.matchRole = "": "", 1: "Probe" _ tApp.matchRole)
    }
    Quit tPaths
}

/// <p>The probe application paths that exist on this instance, space-separated, or
/// <code>""</code>. A failed existence check, whether it raises or answers with any status other
/// than "does not exist", is answered as <code>error: &lt;text&gt;</code>, never as
/// <code>""</code>, so a caller cannot read "could not tell" as "none".</p>
ClassMethod Existing() As %String
{
    Set tPaths = ..Paths()
    If tPaths = "" Quit "error: the roster yielded no probe application path"
    Set tExisting = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tPaths) {
            Set tPath = $ListGet(tPaths, tI)
            If ##class(Security.Applications).Exists(tPath, , .tExistSC) {
                Set tExisting = tExisting _ " " _ tPath
            } ElseIf '$System.Status.Equals(tExistSC, $$$ERRORCODE($$$ApplicationDoesNotExist)) {
                Set tExisting = "error: " _ tPath _ ": " _ $System.Status.GetErrorText(tExistSC)
                Quit
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tExisting = "error: " _ ex.DisplayString()
    }
    Quit $ZStrip(tExisting, "<W")
}

/// <p>Uninstall the probe profile, then remove every probe application the roster declares
/// that is still present, with its matching role. A provenance row is deleted only once its
/// application is known to be gone, so a failed delete or a failed check never leaves an
/// application without its row. Returns the uninstall's status, or the first failed removal when
/// the uninstall succeeded.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Set tPaths = ..Paths(.tRoles)
    Set tOrigNS = $NAMESPACE
    For tI = 1:1:$ListLength(tPaths) {
        Set tPath = $ListGet(tPaths, tI)
        Set tRole = $Get(tRoles(tPath))
        Set tGone = 0
        Set tDeleteSC = $$$OK
        Try {
            Set $NAMESPACE = "%SYS"
            If ##class(Security.Applications).Exists(tPath) {
                Set tDeleteSC = ##class(Security.Applications).Delete(tPath)
                ; Only the role of an application removed here, as Uninstall does for its own.
                If $$$ISOK(tDeleteSC), tRole '= "", ##class(Security.Roles).Exists(tRole) Set tDeleteSC = ##class(Security.Roles).Delete(tRole)
            }
            Set tGone = '##class(Security.Applications).Exists(tPath, , .tExistSC)
            If tGone, '$System.Status.Equals(tExistSC, $$$ERRORCODE($$$ApplicationDoesNotExist)) {
                Set tGone = 0
                If $$$ISOK(tDeleteSC) Set tDeleteSC = tExistSC
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tDeleteSC = ex.AsStatus()
        }
        If tGone {
            Set tRowSC = ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(tPath)
            If $$$ISOK(tSC) Set tSC = $Select($$$ISERR(tDeleteSC): tDeleteSC, 1: tRowSC)
        } ElseIf $$$ISOK(tSC) {
            Set tSC = $Select($$$ISERR(tDeleteSC): tDeleteSC, 1: $$$ERROR($$$GeneralError, "probe web application " _ tPath _ " is still present after removal"))
        }
    }
    Quit tSC
}

}
