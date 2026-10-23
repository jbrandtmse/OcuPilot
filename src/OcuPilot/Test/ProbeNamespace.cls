/// <p>A namespace a test class creates and removes: a globals database of its own, in a directory of
/// its own under the manager directory (never the manager directory itself) and guarded by a
/// resource of its own, under a namespace whose routines are another namespace's routines database.
/// <class>OcuPilot.Test.InstallTarget</class> and <class>OcuPilot.Test.ContainerStartNamespace</class>
/// build theirs with it. Not a test case.</p>
Class OcuPilot.Test.ProbeNamespace
{

/// <p>Create namespace <var>pNamespace</var> over a new database <var>pDatabase</var> in
/// <code>&lt;mgr&gt;/<var>pDirectory</var>/</code>, guarded by the new resource <var>pResource</var>,
/// with the routines database of <var>pRoutinesFrom</var>. Answers the first failure.</p>
ClassMethod Build(pNamespace As %String, pDatabase As %String, pResource As %String, pDirectory As %String, pRoutinesFrom As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Config.Namespaces).Get(pRoutinesFrom, .tHome)
        If $$$ISERR(tSC) Quit
        Set tDir = ##class(%File).NormalizeDirectory(pDirectory, $System.Util.ManagerDirectory())
        Set tSC = ##class(Security.Resources).Create(pResource, "OcuPilot test probe database " _ pDatabase, "", 2)
        If $$$ISERR(tSC) Quit
        Do ##class(%File).CreateDirectoryChain(tDir)
        Set tSC = ##class(SYS.Database).CreateDatabase(tDir, 1, 8192, 0, pResource)
        If $$$ISERR(tSC) Quit
        Set tDb("Directory") = tDir
        Set tSC = ##class(Config.Databases).Create(pDatabase, .tDb)
        If $$$ISERR(tSC) Quit
        Set tNs("Globals") = pDatabase
        Set tNs("Routines") = tHome("Routines")
        Set tSC = ##class(Config.Namespaces).Create(pNamespace, .tNs)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove what <method>Build</method> creates, whatever part of it exists, after the namespace's
/// global mappings named in <var>pMappings</var> (comma-separated), and answer what is still there
/// (<code>""</code> when nothing is).</p>
ClassMethod Remove(pNamespace As %String, pDatabase As %String, pResource As %String, pDirectory As %String, pMappings As %String = "") As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Set tDir = ##class(%File).NormalizeDirectory(pDirectory, $System.Util.ManagerDirectory())
        For tI = 1:1:$Length(pMappings, ",") {
            Set tMapping = $Piece(pMappings, ",", tI)
            If (tMapping '= "") && ##class(Config.MapGlobals).Exists(pNamespace, tMapping) Do ##class(Config.MapGlobals).Delete(pNamespace, tMapping)
        }
        If ##class(Config.Namespaces).Exists(pNamespace) Do ##class(Config.Namespaces).Delete(pNamespace)
        If ##class(Config.Databases).Exists(pDatabase) Do ##class(Config.Databases).Delete(pDatabase)
        If ##class(%File).Exists(tDir _ "IRIS.DAT") Do ##class(SYS.Database).DeleteDatabase(tDir)
        If ##class(Security.Resources).Exists(pResource) Do ##class(Security.Resources).Delete(pResource)
        If ##class(%File).DirectoryExists(tDir) Do ##class(%File).RemoveDirectoryTree(tDir)
        If ##class(Config.Namespaces).Exists(pNamespace) Set tLeft = tLeft _ " namespace"
        If ##class(Config.Databases).Exists(pDatabase) Set tLeft = tLeft _ " database"
        If ##class(Security.Resources).Exists(pResource) Set tLeft = tLeft _ " resource"
        If ##class(%File).DirectoryExists(tDir) Set tLeft = tLeft _ " directory"
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>Map the globals <var>pPattern</var> of namespace <var>pNamespace</var> onto database
/// <var>pDatabase</var>, replacing a mapping of that pattern there, or remove that mapping when
/// <var>pDatabase</var> is <code>""</code>.</p>
ClassMethod SetMapping(pNamespace As %String, pPattern As %String, pDatabase As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Config.MapGlobals).Exists(pNamespace, pPattern) {
            Set tSC = ##class(Config.MapGlobals).Delete(pNamespace, pPattern)
            If $$$ISERR(tSC) Quit
        }
        If pDatabase '= "" {
            Set tProps("Database") = pDatabase
            Set tSC = ##class(Config.MapGlobals).Create(pNamespace, pPattern, .tProps)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
