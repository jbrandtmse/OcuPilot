Include %occErrors

/// <p>The disposable <code>"probe"</code> profile's web applications, derived from
/// <class>OcuPilot.Install.Roster</class> rather than listed, for test setup, teardown and the
/// CI runner's after-class check (DW-242).</p>
/// <p><method>OcuPilot.Install.Installer.Uninstall</method> removes only the applications a
/// provenance row records (DW-94), their matching roles while no other application carries them,
/// and the shell's bundle directory while no application stays at the shell's path, so a test that
/// deletes a probe row while the probe profile is installed leaves an application, its role and
/// the directory that no later uninstall can remove. <method>Remove</method> removes all three,
/// and <method>Existing</method> is what <file>scripts/ci-unit-test.sh</file> reads before and
/// after every class. <method>Existing</method> also names the namespace, database and directory
/// <class>OcuPilot.Test.CompileWithoutInterop</class> creates, while they exist.</p>
Class OcuPilot.Test.ProbeApps Extends %RegisteredObject
{

/// <p>The roster key of the shell application, whose bundle directory <method>ShellDirectory</method>
/// derives. The key is named here rather than read from the roster's
/// <code>bundle.destinationApplication</code>; <class>OcuPilot.Test.Manifest</class> pins the
/// roster's keys, so a key that moved fails there rather than silently here.</p>
Parameter SHELLKEY As %String = "shell";

/// <p>The probe class that <class>OcuPilot.Test.CompileWithoutInterop</class> creates its namespace and
/// database through.</p>
Parameter COMPILEPROBE = "OcuPilot.Test.CompileWithoutInteropProbe";

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

/// <p>The probe profile's shell application path, derived from the roster's
/// <parameter>SHELLKEY</parameter> entry rather than transcribed; <code>""</code> when the roster
/// declares no such application or its path carries no probe form.</p>
ClassMethod ShellPath() As %String
{
    Set tPath = ""
    Try {
        Set tSC = ##class(OcuPilot.Install.Roster).Application(..#SHELLKEY, .tApp)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tApp) Quit
        Set tPath = ##class(OcuPilot.Install.Installer).ProbeApplicationPath(tApp.path)
    } Catch ex {
        Set tPath = ""
    }
    Quit tPath
}

/// <p>The probe profile's shell-application bundle directory, resolved from <method>ShellPath</method>
/// through <method>OcuPilot.Api.StaticHandler.RootDirectory</method> as
/// <method>OcuPilot.Install.Installer.Names</method> resolves it. <code>""</code> when the roster
/// declares no shell application.</p>
ClassMethod ShellDirectory() As %String
{
    Set tDir = ""
    Try {
        Set tPath = ..ShellPath()
        If tPath = "" Quit
        Set tDir = ##class(OcuPilot.Api.StaticHandler).RootDirectory(tPath)
    } Catch ex {
        Set tDir = ""
    }
    Quit tDir
}

/// <p>The probe application paths that exist on this instance, space-separated, followed by the
/// <code>OCUPROBE2028</code> objects <method>CompileProbeLeftovers</method> names, or <code>""</code>.
/// A failed existence check, whether it raises or answers with any status other
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
    If $Extract(tExisting, 1, 6) '= "error:" {
        Set tCompileProbe = ..CompileProbeLeftovers()
        Set tExisting = $Select($Extract(tCompileProbe, 1, 6) = "error:": tCompileProbe, 1: tExisting _ tCompileProbe)
    }
    Quit $ZStrip(tExisting, "<W")
}

/// <p>The namespace, database and directory of <parameter>COMPILEPROBE</parameter> that exist on this
/// instance, each as a space-led token naming its kind (<code>namespace:&lt;name&gt;</code>,
/// <code>database:&lt;name&gt;</code>, <code>directory:&lt;leaf&gt;</code>), or <code>""</code>. A failed
/// check is answered <code>error: &lt;text&gt;</code>, never as <code>""</code>. Each is looked up by its
/// exact name, so a surviving one reads as a probe leftover to the CI runner's after-class check.</p>
ClassMethod CompileProbeLeftovers() As %String
{
    Set tFound = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tProbe = ..#COMPILEPROBE
        Set tNamespace = $Parameter(tProbe, "NAMESPACENAME")
        Set tDatabase = $Parameter(tProbe, "LOCALNAME")
        Set tDirectory = $ClassMethod(tProbe, "DirectoryFor", $Extract(tDatabase, $Length($Parameter(tProbe, "PREFIX")) + 1, *))
        Set tLeaf = $Extract(tDirectory, $Length($ClassMethod(tProbe, "Manager")) + 1, *-1)
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Namespaces).Exists(tNamespace) Set tFound = tFound _ " namespace:" _ tNamespace
        If ##class(Config.Databases).Exists(tDatabase) Set tFound = tFound _ " database:" _ tDatabase
        If ##class(%File).DirectoryExists(tDirectory) Set tFound = tFound _ " directory:" _ tLeaf
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFound = "error: " _ ex.DisplayString()
    }
    Quit tFound
}

/// <p>Uninstall the probe profile, then remove every probe application the roster declares
/// that is still present, with its matching role, and the shell's bundle directory once no probe
/// shell application remains. A provenance row is deleted only once its application is known to
/// be gone, so a failed delete or a failed check never leaves an application without its row.
/// Returns the uninstall's status, or the first failed removal when the uninstall succeeded.</p>
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
    Set tDirSC = ..RemoveShellDirectory()
    If $$$ISOK(tSC) Set tSC = tDirSC
    Quit tSC
}

/// <p>Remove the probe shell's bundle directory unless a probe shell application still sits at the
/// shell's path. An uninstall that leaves that application in place leaves the directory too.
/// Answers the failure when the directory is still there afterwards.</p>
ClassMethod RemoveShellDirectory() As %Status
{
    Set tSC = $$$OK
    Set tDir = ..ShellDirectory()
    If (tDir = "") || '##class(%File).DirectoryExists(tDir) Quit tSC
    Set tShellPath = ..ShellPath()
    Set tShellKept = 1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tShellKept = ''##class(Security.Applications).Exists(tShellPath)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    If tShellKept Quit tSC
    If '##class(%File).RemoveDirectoryTree(tDir) || ##class(%File).DirectoryExists(tDir) {
        Set tSC = $$$ERROR($$$GeneralError, "probe shell bundle directory " _ tDir _ " is still present after removal")
    }
    Quit tSC
}

}
