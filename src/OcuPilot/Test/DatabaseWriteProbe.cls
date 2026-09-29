/// <p>Test-only helper for the database suites (Story 18.3): creates and removes probe databases named
/// with <parameter>PREFIX</parameter> in directories under the manager directory named with
/// <parameter>DIRPREFIX</parameter>, through <class>OcuPilot.Port.AdminPort</class> and never through
/// <class>Config.Databases</class>; and seeds, in <code>%SYS</code> by explicit save and restore, the
/// <code>%DB_</code> resources, probe namespaces, probe global, routine and package mappings, the web applications
/// <parameter>APPPREFIX</parameter>, a probe remote configuration and a probe database's second volume file
/// those suites need. It never
/// touches an object whose name is outside those prefixes.</p>
/// <p><method>RemoveAll</method> removes every probe object by exact name: the namespaces and
/// applications first, then each configuration, then each database file, directory and resource, and
/// the remote configuration's data server last.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseWriteProbe Extends %RegisteredObject
{

/// <p>The prefix every probe database's and namespace's name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE183";

/// <p>The prefix every probe directory's name starts with under the manager directory, compared
/// lower-cased.</p>
Parameter DIRPREFIX = "ocuprobe183";

/// <p>The prefix every probe web application's path starts with, compared lower-cased.</p>
Parameter APPPREFIX = "/csp/ocuprobe183";

/// <p>The prefix every probe resource's name starts with, compared upper-cased.</p>
Parameter RESOURCEPREFIX = "%DB_OCUPROBE183";

/// <p>The probe ECP data server a probe remote configuration names.</p>
Parameter SERVERNAME = "OCUPROBE183SRV";

/// <p>The name corpus's names outside <parameter>PREFIX</parameter>, removed by exact name should any
/// ever be created.</p>
Parameter EXTRANAMES = "1OCUPROBE183,%OCUPROBE183";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter CONFIG = "Database.ConfigCRUD";

Parameter FILE = "Database.SysCRUD";

/// <p>Whether <var>pName</var> is a database or namespace name this helper may create or remove.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Set tName = $ZConvert(pName, "U")
    If $Extract(tName, 1, $Length(..#PREFIX)) = ..#PREFIX Quit 1
    Quit ''$ListFind($ListFromString(..#EXTRANAMES), tName)
}

/// <p>The manager directory, normalized with its trailing separator.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>The probe directory <parameter>DIRPREFIX</parameter><var>pSuffix</var> under the manager
/// directory, lower-cased, with its trailing separator.</p>
ClassMethod DirectoryFor(pSuffix As %String) As %String
{
    Quit ..Manager() _ ..#DIRPREFIX _ $ZConvert(pSuffix, "L") _ "/"
}

/// <p>Whether normalized directory <var>pDirectory</var> is a probe directory.</p>
ClassMethod IsProbeDirectory(pDirectory As %String) As %Boolean
{
    Set tPrefix = $ZConvert(..Manager() _ ..#DIRPREFIX, "L")
    Quit ($Extract($ZConvert(pDirectory, "L"), 1, $Length(tPrefix)) = tPrefix)
}

/// <p>Create the probe database <var>pName</var> in <var>pDirectory</var> (its own probe directory
/// when empty), guarded by <var>pResource</var> (<code>%DB_&lt;NAME&gt;</code>, created here, when
/// empty): the resource in <code>%SYS</code>, the file through the port's <code>POST</code> and the
/// configuration through its <code>PUT</code>.</p>
ClassMethod Add(pName As %String, pDirectory As %String = "", pResource As %String = "") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tDirectory = $Select(pDirectory = "": ..DirectoryFor($Extract(pName, $Length(..#PREFIX) + 1, *)), 1: pDirectory)
    If '..IsProbeDirectory(tDirectory) Quit $$$ERROR($$$GeneralError, "a probe database's directory starts with " _ ..#DIRPREFIX)
    Set tResource = $Select(pResource = "": "%DB_" _ $ZConvert(pName, "U"), 1: pResource)
    If pResource = "" {
        Set tSC = ..AddResource(tResource)
        If $$$ISERR(tSC) Quit tSC
    }
    Kill tNone
    Set tBody = {"Size": 1}
    Do tBody.%Set("Directory", tDirectory, "string")
    Do tBody.%Set("ResourceName", tResource, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#FILE, "POST", .tNone, tBody, .tFile, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Quit ..AddConfiguration(pName, tDirectory)
}

/// <p>Create the configuration <var>pName</var> over <var>pDirectory</var> alone, through the port's
/// <code>PUT</code>: a second name over a probe database's file, or a name whose directory holds no
/// file.</p>
ClassMethod AddConfiguration(pName As %String, pDirectory As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    If '..IsProbeDirectory(pDirectory) Quit $$$ERROR($$$GeneralError, "a probe configuration's directory starts with " _ ..#DIRPREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = {}
    Do tBody.%Set("Directory", pDirectory, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe configuration " _ pName _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Send <var>pName</var> to the vendor's configuration <code>PUT</code> over a probe directory that
/// holds no file, whatever its shape, answering the HTTP status in <var>pHttp</var>: the name corpus's
/// question to the instance. A name outside the probe names is refused before the port.</p>
ClassMethod Attempt(pName As %String, Output pHttp As %Integer) As %Status
{
    Set pHttp = 0
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = {}
    Do tBody.%Set("Directory", ..DirectoryFor("corpus"), "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "PUT", .tQuery, tBody, .tResult, .pHttp, .tFault)
    Quit $$$OK
}

/// <p>The configuration <var>pName</var> as the vendor's <code>GET</code> answers it, or
/// <code>""</code>.</p>
ClassMethod Read(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) || 'tResult.%IsA("%Library.DynamicObject") Quit ""
    Quit tResult
}

/// <p>The file in <var>pDirectory</var> as the vendor's <code>GET</code> answers it, or
/// <code>""</code>.</p>
ClassMethod ReadFile(pDirectory As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#FILE, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) || 'tResult.%IsA("%Library.DynamicObject") Quit ""
    Quit tResult
}

/// <p>Whether the instance holds the configuration <var>pName</var>.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Quit $IsObject(..Read(pName))
}

/// <p>The configuration <var>pName</var>'s stored <var>pField</var>, rendered, or <code>""</code>.</p>
ClassMethod Stored(pName As %String, pField As %String) As %String
{
    Set tRead = ..Read(pName)
    If '$IsObject(tRead) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(tRead.%Get(pField), tRead.%GetTypeOf(pField))
}

/// <p>The file in <var>pDirectory</var>'s stored <var>pField</var>, rendered, or <code>""</code>.</p>
ClassMethod StoredFile(pDirectory As %String, pField As %String) As %String
{
    Set tRead = ..ReadFile(pDirectory)
    If '$IsObject(tRead) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(tRead.%Get(pField), tRead.%GetTypeOf(pField))
}

/// <p>Whether <var>pDirectory</var> holds a database file.</p>
ClassMethod HoldsFile(pDirectory As %String) As %Boolean
{
    Quit ''##class(%File).Exists(##class(%File).NormalizeDirectory(pDirectory) _ "IRIS.DAT")
}

/// <p>The file name of a database's first volume after <code>IRIS.DAT</code>.</p>
Parameter FIRSTVOLUME = "IRIS-0001.VOL";

/// <p>Give the probe database in <var>pDirectory</var> a second volume file,
/// <parameter>FIRSTVOLUME</parameter>, in the same directory, through
/// <code>SYS.Database.NewVolume</code> in <code>%SYS</code> (test-only); a directory outside the probe
/// directories is refused.</p>
ClassMethod AddVolume(pDirectory As %String) As %Status
{
    If '..IsProbeDirectory(pDirectory) Quit $$$ERROR($$$GeneralError, "a probe directory starts with " _ ..#DIRPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.Database).NewVolume(pDirectory, pDirectory, 1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pDirectory</var> holds <parameter>FIRSTVOLUME</parameter>.</p>
ClassMethod HoldsVolume(pDirectory As %String) As %Boolean
{
    Quit ''##class(%File).Exists(##class(%File).NormalizeDirectory(pDirectory) _ ..#FIRSTVOLUME)
}

/// <p>Whether the directory <var>pDirectory</var> exists.</p>
ClassMethod HoldsDirectory(pDirectory As %String) As %Boolean
{
    Quit ''##class(%File).DirectoryExists(pDirectory)
}

/// <p>Whether the file in <var>pDirectory</var> reads mounted, from its <code>INFO</code>.</p>
ClassMethod Mounted(pDirectory As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#FILE, "INFO", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit 0
    Quit ''tResult.%Get("Mounted")
}

/// <p>Remove the configuration <var>pName</var> through the port when it is present, and its file
/// when <var>pFile</var> is 1; an error when the configuration survives.</p>
ClassMethod Remove(pName As %String, pFile As %Boolean = 1) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tRead = ..Read(pName)
    If '$IsObject(tRead) Quit $$$OK
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    If pFile && ..IsProbeDirectory(tRead.%Get("Directory")) && ..HoldsFile(tRead.%Get("Directory")) Do ..RemoveFile(tRead.%Get("Directory"))
    If ..Holds(pName) Quit $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe configuration " _ pName _ " is still present after its removal"))
    Quit $$$OK
}

/// <p>Delete the database file in the probe directory <var>pDirectory</var> through the port.</p>
ClassMethod RemoveFile(pDirectory As %String) As %Status
{
    If '..IsProbeDirectory(pDirectory) Quit $$$ERROR($$$GeneralError, "a probe directory starts with " _ ..#DIRPREFIX)
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Quit $ClassMethod(..#PORT, "Invoke", ..#FILE, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
}

/// <p>Create the resource <var>pName</var> in <code>%SYS</code> when it is absent; a name outside
/// <parameter>RESOURCEPREFIX</parameter> is refused.</p>
ClassMethod AddResource(pName As %String) As %Status
{
    If $Extract($ZConvert(pName, "U"), 1, $Length(..#RESOURCEPREFIX)) '= ..#RESOURCEPREFIX Quit $$$ERROR($$$GeneralError, "a probe resource's name starts with " _ ..#RESOURCEPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(pName) Set tSC = ##class(Security.Resources).Create(pName, "OcuPilot database probe (throwaway)", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the resource <var>pName</var> exists.</p>
ClassMethod HoldsResource(pName As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''##class(Security.Resources).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHeld
}

/// <p>Create the probe namespace <var>pName</var> over <var>pGlobals</var> and <var>pRoutines</var>,
/// and over <var>pTempGlobals</var> for its temporary globals when given, through the port.</p>
ClassMethod AddNamespace(pName As %String, pGlobals As %String, pRoutines As %String, pTempGlobals As %String = "") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe namespace's name starts with " _ ..#PREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = {}
    Do tBody.%Set("Globals", pGlobals, "string")
    Do tBody.%Set("Routines", pRoutines, "string")
    If pTempGlobals '= "" Do tBody.%Set("TempGlobals", pTempGlobals, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Namespace.Namespace", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe namespace " _ pName _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Create the web application <var>pPath</var> in the probe namespace <var>pNamespace</var>; a path
/// outside <parameter>APPPREFIX</parameter> is refused.</p>
ClassMethod AddApplication(pPath As %String, pNamespace As %String) As %Status
{
    If $Extract($ZConvert(pPath, "L"), 1, $Length(..#APPPREFIX)) '= ..#APPPREFIX Quit $$$ERROR($$$GeneralError, "a probe application's path starts with " _ ..#APPPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("NameSpace") = pNamespace
        Set tProperties("Enabled") = 1
        Set tProperties("AutheEnabled") = 32
        Set tProperties("Description") = "OcuPilot database probe (throwaway)"
        Set tSC = ##class(Security.Applications).Create(pPath, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Map <var>pName</var> of the probe namespace <var>pNamespace</var> to the probe database
/// <var>pDatabase</var>: a global, or with <var>pKind</var> <code>Routines</code> or
/// <code>Packages</code> a routine or a package.</p>
ClassMethod AddMapping(pNamespace As %String, pName As %String, pDatabase As %String, pKind As %String = "Globals") As %Status
{
    If '..IsProbe(pNamespace) || '..IsProbe(pDatabase) Quit $$$ERROR($$$GeneralError, "a probe mapping maps a probe namespace to a probe database")
    If '$ListFind($ListBuild("Globals", "Routines", "Packages"), pKind) Quit $$$ERROR($$$GeneralError, "a probe mapping is of globals, routines or packages")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Database") = $ZConvert(pDatabase, "U")
        Set tSC = $ClassMethod("Config.Map" _ pKind, "Create", $ZConvert(pNamespace, "U"), pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe remote configuration <var>pName</var> on the probe data server
/// <parameter>SERVERNAME</parameter>, which is created here and never contacted: test-only seeding in
/// <code>%SYS</code>.</p>
ClassMethod AddRemote(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.ECPServers).Exists(..#SERVERNAME) {
            Kill tServer
            Set tServer("Address") = "127.0.0.1"
            Set tServer("Port") = 1972
            Set tSC = ##class(Config.ECPServers).Create(..#SERVERNAME, .tServer)
        }
        If $$$ISOK(tSC) {
            Kill tProperties
            Set tProperties("Server") = ..#SERVERNAME
            Set tProperties("Directory") = "/ocuprobe183remote/"
            Set tSC = ##class(Config.Databases).Create($ZConvert(pName, "U"), .tProperties)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe object, each by its exact name. <var>pRemaining</var> is how many survived,
/// and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Try {
        ; Namespaces and applications first: a namespace using a probe database blocks its delete.
        Set tNamespaces = ..ProbeNamespaces()
        For tI = 1:1:$ListLength(tNamespaces) {
            Kill tQuery
            Set tQuery("name") = $List(tNamespaces, tI)
            Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PORT, "Invoke", "Namespace.Namespace", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
        }
        Set tApps = ..ProbeApplications()
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            For tI = 1:1:$ListLength(tApps) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Applications).Delete($List(tApps, tI)))
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ADDSC(tSC, ex.AsStatus())
        }
        ; Each configuration, then every file in a probe directory, then the directories.
        Set tNames = ..ProbeConfigurations()
        For tI = 1:1:$ListLength(tNames) {
            Kill tQuery
            Set tQuery("name") = $List(tNames, tI)
            Set tDeleteSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
        }
        Set tDirectories = ..ProbeDirectories()
        For tI = 1:1:$ListLength(tDirectories) {
            Set tDirectory = $List(tDirectories, tI)
            If ..HoldsFile(tDirectory) Do ..RemoveFile(tDirectory)
            Do ##class(%File).RemoveDirectoryTree(tDirectory)
        }
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            If ##class(Config.ECPServers).Exists(..#SERVERNAME) Set tSC = $$$ADDSC(tSC, ##class(Config.ECPServers).Delete(..#SERVERNAME))
            Set tResources = ..ProbeResources()
            For tI = 1:1:$ListLength(tResources) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete($List(tResources, tI)))
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ADDSC(tSC, ex.AsStatus())
        }
        Set pRemaining = $ListLength(..ProbeNamespaces()) + $ListLength(..ProbeApplications()) + $ListLength(..ProbeConfigurations()) + $ListLength(..ProbeDirectories()) + $ListLength(..ProbeResources()) + ..HoldsServer()
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe database object(s) survived their removal"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe configurations the instance holds, local and remote, as the vendor's list names
/// them.</p>
ClassMethod ProbeConfigurations() As %List
{
    Set tNames = ""
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>The probe namespaces the instance holds.</p>
ClassMethod ProbeNamespaces() As %List
{
    Set tNames = ""
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Namespace.Namespace", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>The probe directories under the manager directory, each with its trailing separator.</p>
ClassMethod ProbeDirectories() As %List
{
    Set tDirectories = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    If $$$ISERR(tRS.Execute(..Manager(), "*", "", 1)) Quit ""
    While tRS.Next() {
        If tRS.Get("Type") '= "D" Continue
        Set tDirectory = ##class(%File).NormalizeDirectory(tRS.Get("Name"))
        If ..IsProbeDirectory(tDirectory) Set tDirectories = tDirectories _ $ListBuild(tDirectory)
    }
    Quit tDirectories
}

/// <p>The probe resources the instance holds.</p>
ClassMethod ProbeResources() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $Extract($ZConvert(tName, "U"), 1, $Length(..#RESOURCEPREFIX)) = ..#RESOURCEPREFIX Set tNames = tNames _ $ListBuild(tName)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>The probe web applications the instance holds, by exact path.</p>
ClassMethod ProbeApplications() As %List
{
    Set tApps = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $Extract($ZConvert(tName, "L"), 1, $Length(..#APPPREFIX)) = ..#APPPREFIX Set tApps = tApps _ $ListBuild(tName)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tApps
}

/// <p>1 when the probe data server exists, else 0.</p>
ClassMethod HoldsServer() As %Integer
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''##class(Config.ECPServers).Exists(..#SERVERNAME)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHeld
}

/// <p>Whether the instance's configuration file validates, and whether it names any probe database
/// or namespace, in <var>pNamesProbe</var>.</p>
ClassMethod CpfValid(Output pNamesProbe As %Boolean) As %Boolean
{
    Set pNamesProbe = 0
    Set tValid = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If $$$ISOK(tStream.LinkToFile(##class(%SYS.System).GetCPFFileName())) {
            While 'tStream.AtEnd {
                If $ZConvert(tStream.ReadLine(), "U") [ ..#PREFIX Set pNamesProbe = 1
            }
        }
        Set tStream = ""
        Set tValid = $$$ISOK(##class(Config.CPF).Validate())
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValid = 0
    }
    Quit tValid
}

}
