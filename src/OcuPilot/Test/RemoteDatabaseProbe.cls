/// <p>Test-only helper for Story 18.16's remote database suites. It seeds, in <code>%SYS</code> by
/// explicit save and restore, the probe ECP data server <parameter>SERVERNAME</parameter> (configuration
/// only, never contacted by the seeding), probe remote configurations, a probe local database in a
/// directory under the manager directory, a probe namespace over it with a global mapping, and probe
/// principals; and it takes canonical snapshots of what a remote database write or a directory listing
/// can change, so a run can be compared with the state before it. Every object it creates or removes
/// is named with <parameter>PREFIX</parameter> (users and roles compared without case), and it never
/// touches another.</p>
/// <p><method>RemoveAll</method> removes every probe object by exact name: the mapping and the
/// namespace first, then each configuration, the local probe database's file, directory and resource,
/// the principals, and the data server last.</p>
/// <p><method>Run</method> issues one admin API call through <class>OcuPilot.Port.AdminPort</class>
/// and times it; <method>RunAs</method> runs a plan of such calls as a probe principal in a child
/// process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseProbe Extends %RegisteredObject
{

/// <p>The prefix every probe database, namespace, server, user and role name starts with, compared
/// upper-cased.</p>
Parameter PREFIX = "OCUPROBE1816";

/// <p>The prefix every probe directory's name starts with under the manager directory, compared
/// lower-cased.</p>
Parameter DIRPREFIX = "ocuprobe1816";

/// <p>The prefix every probe resource's name starts with, compared upper-cased.</p>
Parameter RESOURCEPREFIX = "%DB_OCUPROBE1816";

/// <p>The probe ECP data server.</p>
Parameter SERVERNAME = "OCUPROBE1816SRV";

Parameter SERVERADDRESS = "127.0.0.1";

Parameter SERVERPORT As INTEGER = 1972;

/// <p>The probe local database the probe namespace reads its globals and routines from.</p>
Parameter LOCALNAME = "OCUPROBE1816L";

/// <p>The probe namespace.</p>
Parameter NAMESPACENAME = "OCUPROBE1816N";

/// <p>The probe namespace's one global mapping.</p>
Parameter MAPPINGNAME = "OcuProbe1816*";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter CONFIG = "Database.ConfigCRUD";

/// <p>Whether <var>pName</var> is a probe name.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit ($Extract($ZConvert(pName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX)
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

/// <p>Define the probe data server <var>pName</var> (<parameter>SERVERNAME</parameter> when empty) at
/// <parameter>SERVERADDRESS</parameter>:<parameter>SERVERPORT</parameter> when it is absent
/// (test-only seeding in <code>%SYS</code>; nothing is contacted).</p>
ClassMethod SeedServer(pName As %String = "") As %Status
{
    Set tName = $Select(pName = "": ..#SERVERNAME, 1: pName)
    If '..IsProbe(tName) Quit $$$ERROR($$$GeneralError, "a probe data server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.ECPServers).Exists(tName) {
            Kill tServer
            Set tServer("Address") = ..#SERVERADDRESS
            Set tServer("Port") = ..#SERVERPORT
            Set tSC = ##class(Config.ECPServers).Create(tName, .tServer)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe remote configuration <var>pName</var> on the probe data server, over
/// <var>pDirectory</var> (<code>/&lt;name lower-cased&gt;/</code> when empty), defining the server
/// first when it is absent (test-only seeding in <code>%SYS</code>).</p>
ClassMethod SeedRemote(pName As %String, pDirectory As %String = "") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe configuration's name starts with " _ ..#PREFIX)
    Set tSC = ..SeedServer()
    If $$$ISERR(tSC) Quit tSC
    Set tDirectory = $Select(pDirectory = "": "/" _ $ZConvert(pName, "L") _ "/", 1: pDirectory)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Server") = ..#SERVERNAME
        Set tProperties("Directory") = tDirectory
        Set tSC = ##class(Config.Databases).Create($ZConvert(pName, "U"), .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe local database <parameter>LOCALNAME</parameter> in its own probe directory:
/// its <code>%DB_</code> resource first, then the directory and file, then the configuration
/// (test-only seeding in <code>%SYS</code>).</p>
ClassMethod SeedLocal() As %Status
{
    Set tName = ..#LOCALNAME
    Set tDirectory = ..DirectoryFor($Extract(tName, $Length(..#PREFIX) + 1, *))
    Set tResource = "%DB_" _ tName
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(tResource) Set tSC = ##class(Security.Resources).Create(tResource, "OcuPilot remote database probe (throwaway)", "")
        If $$$ISOK(tSC) && '##class(%File).DirectoryExists(tDirectory) {
            If '##class(%File).CreateDirectoryChain(tDirectory) Set tSC = $$$ERROR($$$GeneralError, "the probe directory could not be created")
        }
        If $$$ISOK(tSC) && '##class(%File).Exists(tDirectory _ "IRIS.DAT") Set tSC = ##class(SYS.Database).CreateDatabase(tDirectory, 1, , , tResource)
        If $$$ISOK(tSC) && '##class(Config.Databases).Exists(tName) {
            Kill tProperties
            Set tProperties("Directory") = tDirectory
            Set tSC = ##class(Config.Databases).Create(tName, .tProperties)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe namespace <parameter>NAMESPACENAME</parameter> over the probe local database,
/// for both its globals and its routines, creating that database first when it is absent (test-only
/// seeding in <code>%SYS</code>).</p>
ClassMethod SeedNamespace() As %Status
{
    Set tSC = ..SeedLocal()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.Namespaces).Exists(..#NAMESPACENAME) {
            Kill tProperties
            Set tProperties("Globals") = ..#LOCALNAME
            Set tProperties("Routines") = ..#LOCALNAME
            Set tSC = ##class(Config.Namespaces).Create(..#NAMESPACENAME, .tProperties)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Map the globals <parameter>MAPPINGNAME</parameter> of the probe namespace to the probe database
/// <var>pDatabase</var>, creating the namespace first when it is absent (test-only seeding in
/// <code>%SYS</code>).</p>
ClassMethod SeedMapping(pDatabase As %String) As %Status
{
    If '..IsProbe(pDatabase) Quit $$$ERROR($$$GeneralError, "a probe mapping maps to a probe database")
    Set tSC = ..SeedNamespace()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Database") = $ZConvert(pDatabase, "U")
        Set tSC = ##class(Config.MapGlobals).Create(..#NAMESPACENAME, ..#MAPPINGNAME, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The configuration <var>pName</var>'s field <var>pField</var> as the admin API's
/// <code>GET</code> answers it, a boolean as <code>true</code> or <code>false</code>, or
/// <code>""</code> when it is not held.</p>
ClassMethod Stored(pName As %String, pField As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#CONFIG, "GET", .tQuery, "", .tConfig, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tConfig)) Quit ""
    Set tType = tConfig.%GetTypeOf(pField)
    If tType = "boolean" Quit $Select(tConfig.%Get(pField): "true", 1: "false")
    If (tType = "unassigned") || (tType = "null") Quit ""
    Quit tConfig.%Get(pField)
}

/// <p>Whether the instance holds the configuration <var>pName</var>, read through the admin API: 1 when
/// the read answers, 0 when it answers 404, and -1 for any other failure, so a failed read never
/// passes as an absence.</p>
ClassMethod Holds(pName As %String) As %Integer
{
    Kill tQuery
    Set tQuery("name") = pName
    If $$$ISOK($ClassMethod(..#PORT, "Invoke", ..#CONFIG, "GET", .tQuery, "", .tConfig, .tHttp, .tFault)) Quit 1
    Quit $Select(+$Get(tHttp) = 404: 0, 1: -1)
}

/// <p>Remove the probe namespace's global mapping when it exists.</p>
ClassMethod RemoveMapping() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Namespaces).Exists(..#NAMESPACENAME) && ##class(Config.MapGlobals).Exists(..#NAMESPACENAME, ..#MAPPINGNAME) Set tSC = ##class(Config.MapGlobals).Delete(..#NAMESPACENAME, ..#MAPPINGNAME)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone with password <var>pPassword</var>
/// (a random one when empty), replacing either when it exists.</p>
ClassMethod SeedPrincipal(pUser As %String, pRole As %String, pResources As %String, pPassword As %String = "") As %Status
{
    If '..IsProbe(pUser) || '..IsProbe(pRole) Quit $$$ERROR($$$GeneralError, "a probe principal's names start with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tNamespace = ""
        Set tDatabase = ""
        If ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
        If ##class(Security.Roles).Exists(pRole) Do ##class(Security.Roles).Delete(pRole)
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot remote database probe (throwaway)", tCode _ "," _ pResources, "")
        Set tPassword = $Select(pPassword = "": $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), 1: pPassword)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, tPassword, "OcuPilot remote database probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.RemoteDatabaseProbe")
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
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        ; The mapping and the namespace first: a namespace that uses a probe database blocks its delete.
        Set tNamespaces = ..ProbeNamespaces()
        For tI = 1:1:$ListLength(tNamespaces) {
            Set tNamespace = $List(tNamespaces, tI)
            Set tRS = ##class(%ResultSet).%New("Config.MapGlobals:List")
            Set tMaps = ""
            If $$$ISOK(tRS.Execute(tNamespace, "*")) {
                While tRS.Next() {
                    Set tMaps = tMaps _ $ListBuild(tRS.Get("Name"))
                }
            }
            Set tRS = ""
            For tJ = 1:1:$ListLength(tMaps) {
                Set tSC = $$$ADDSC(tSC, ##class(Config.MapGlobals).Delete(tNamespace, $List(tMaps, tJ)))
            }
            Set tSC = $$$ADDSC(tSC, ##class(Config.Namespaces).Delete(tNamespace))
        }
        ; Each configuration, remote and local, then each probe file and directory.
        Set tNames = ..ProbeConfigurations()
        For tI = 1:1:$ListLength(tNames) {
            Set tSC = $$$ADDSC(tSC, ##class(Config.Databases).Delete($List(tNames, tI)))
        }
        Set tDirectories = ..ProbeDirectories()
        For tI = 1:1:$ListLength(tDirectories) {
            Set tDirectory = $List(tDirectories, tI)
            If ##class(%File).Exists(tDirectory _ "IRIS.DAT") Set tSC = $$$ADDSC(tSC, ##class(SYS.Database).DeleteDatabase(tDirectory))
            Do ##class(%File).RemoveDirectoryTree(tDirectory)
        }
        ; The principals, the resources, and the data server last.
        Set tUsers = ..ProbeUsers()
        For tI = 1:1:$ListLength(tUsers) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        Set tResources = ..ProbeResources()
        For tI = 1:1:$ListLength(tResources) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete($List(tResources, tI)))
        }
        Set tRoles = ..ProbeRoles()
        For tI = 1:1:$ListLength(tRoles) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set tServers = ..ProbeServers()
        For tI = 1:1:$ListLength(tServers) {
            Set tSC = $$$ADDSC(tSC, ##class(Config.ECPServers).Delete($List(tServers, tI)))
        }
        Set pRemaining = ..Remaining()
        Set $NAMESPACE = tOrigNS
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe object(s) survived their removal"))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>How many probe objects the instance holds: namespaces, configurations, directories, users,
/// roles, resources and data servers.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..ProbeNamespaces()) + $ListLength(..ProbeConfigurations()) + $ListLength(..ProbeDirectories()) + $ListLength(..ProbeUsers()) + $ListLength(..ProbeRoles()) + $ListLength(..ProbeResources()) + $ListLength(..ProbeServers())
}

/// <p>The probe namespaces the instance defines.</p>
ClassMethod ProbeNamespaces() As %List
{
    Quit ..ProbeNames("Config.Namespaces:List", "Namespace")
}

/// <p>The probe database configurations the instance defines, local and remote.</p>
ClassMethod ProbeConfigurations() As %List
{
    Quit ..ProbeNames("Config.Databases:List", "Name")
}

/// <p>The probe ECP data servers the instance defines.</p>
ClassMethod ProbeServers() As %List
{
    Quit ..ProbeNames("Config.ECPServers:List", "Name")
}

/// <p>The probe accounts.</p>
ClassMethod ProbeUsers() As %List
{
    Quit ..ProbeNames("Security.Users:List", "Name")
}

/// <p>The probe roles, and the roles named for a probe resource.</p>
ClassMethod ProbeRoles() As %List
{
    Set tNames = ..ProbeNames("Security.Roles:List", "Name")
    Set tOthers = ..ProbeNames("Security.Roles:List", "Name", ..#RESOURCEPREFIX)
    For tI = 1:1:$ListLength(tOthers) {
        If '$ListFind(tNames, $List(tOthers, tI)) Set tNames = tNames _ $ListBuild($List(tOthers, tI))
    }
    Quit tNames
}

/// <p>The probe resources.</p>
ClassMethod ProbeResources() As %List
{
    Quit ..ProbeNames("Security.Resources:List", "Name", ..#RESOURCEPREFIX)
}

/// <p>The names column <var>pColumn</var> of query <var>pQuery</var> answers that start with
/// <var>pPrefix</var> (<parameter>PREFIX</parameter> when empty), compared upper-cased, read in
/// <code>%SYS</code>.</p>
ClassMethod ProbeNames(pQuery As %String, pColumn As %String, pPrefix As %String = "") As %List
{
    Set tPrefix = $Select(pPrefix = "": ..#PREFIX, 1: pPrefix)
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(pQuery)
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get(pColumn)
                If $Extract($ZConvert(tName, "U"), 1, $Length(tPrefix)) = tPrefix Set tNames = tNames _ $ListBuild(tName)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
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

/// <p>One admin API call through <parameter>PORT</parameter> (or <var>pPort</var>), timed: the query
/// is <var>pQuery</var>'s members, and the answer is
/// <code>{endpoint, type, ok, http, seconds, result, fault, status}</code>, <code>seconds</code>
/// the wall clock to three decimals.</p>
ClassMethod Run(pEndpoint As %String, pType As %String, pQuery As %DynamicObject = "", pBody As %DynamicAbstractObject = "", pPort As %String = "") As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("endpoint", pEndpoint, "string")
    Do tOut.%Set("type", pType, "string")
    Kill tQuery
    If $IsObject(pQuery) {
        Set tIterator = pQuery.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tQuery(tName) = tValue
        }
    }
    Set tPort = $Select(pPort = "": ..#PORT, 1: pPort)
    Set tStart = $ZHorolog
    Try {
        Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, pType, .tQuery, pBody, .tResult, .tHttp, .tFault)
        Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
        If $$$ISERR(tSC) Do tOut.%Set("status", $System.Status.GetErrorText(tSC), "string")
    } Catch ex {
        Do tOut.%Set("ok", 0, "boolean")
        Do tOut.%Set("status", ex.DisplayString(), "string")
    }
    Do tOut.%Set("seconds", $Normalize($ZHorolog - tStart, 3), "number")
    Do tOut.%Set("http", +$Get(tHttp), "number")
    If $IsObject($Get(tResult)) Do tOut.%Set("result", tResult)
    If $IsObject($Get(tFault)) Do tOut.%Set("fault", tFault)
    Quit tOut
}

/// <p>Run the JSON array <var>pPlan</var> of <method>Run</method> steps,
/// <code>[{endpoint, type, query, body}]</code>, as the probe account <var>pUser</var> in a child
/// process, and answer <code>{username, loggedIn, steps}</code>, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 180) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.RemoteDatabaseProbe).Child($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", pWaitSeconds)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within " _ pWaitSeconds _ " seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>RunAs</method> starts: log in as <var>pUser</var>, run each step of
/// <var>pPlan</var> through <method>Run</method>, and signal the answers to <var>pParent</var>.</p>
ClassMethod Child(pParent As %Integer, pUser As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUser), "boolean")
        Do tOut.%Set("username", $Username, "string")
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Run(tStep.%Get("endpoint"), tStep.%Get("type"), tStep.%Get("query"), tStep.%Get("body")))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> for
/// <var>pUser</var>, this process's user by default, over a completed turn seeded for that user; <var>pProposal</var> is <code>""</code> when the
/// mint refused, with its problem in <var>pProblem</var>.</p>
ClassMethod Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> through <class>OcuPilot.Test.DatabaseConfirm</class> as this process's user,
/// answering <code>http code</code>, the code a field refusal's first violation's where there is
/// one, with the confirm's answer in <var>pResult</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set pResult = ""
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pProposal.%Get("proposalId"), "", $Username, .pResult, .tHttp, .tCode, .tDetail)
    If $$$ISOK(tSC) && ($Get(tCode) = "") Quit "200 "
    If $IsObject($Get(tDetail)) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.violations.%Size() > 0) Set tCode = tDetail.violations.%Get(0).%Get("code")
    Quit +$Get(tHttp) _ " " _ $Get(tCode)
}

/// <p>The consequence code the stored proposal <var>pProposal</var> carries, or <code>""</code>.</p>
ClassMethod Consequence(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit ""
    Quit $Get(tValues("consequence"))
}

/// <p>A refusal as <code>http field:code</code>, from the first violation of <var>pFault</var>.</p>
ClassMethod Refusal(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject) As %String
{
    If $$$ISOK(pSC) Quit "ok"
    Set tText = +$Get(pHttp)
    If $IsObject($Get(pFault)) && $IsObject(pFault.%Get("detail")) && (pFault.detail.%GetTypeOf("violations") = "array") && (pFault.detail.violations.%Size() > 0) {
        Set tRow = pFault.detail.violations.%Get(0)
        Quit tText _ " " _ tRow.%Get("field") _ ":" _ tRow.%Get("code")
    }
    Quit tText _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The first violation's reason, or the fault's own.</p>
ClassMethod Reason(pFault As %DynamicObject) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    If $IsObject(pFault.%Get("detail")) && (pFault.detail.%GetTypeOf("violations") = "array") && (pFault.detail.violations.%Size() > 0) Quit pFault.detail.violations.%Get(0).%Get("reason")
    Quit pFault.%Get("reason")
}

/// <p>The rows <var>pRows</var> as <code>Name:Directory</code>, comma-joined.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    If '$IsObject($Get(pRows)) Quit "(none)"
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ tRow.%Get("Directory")
    }
    Quit tOut
}

/// <p>The <var>pField</var> values the declared read of <var>pDescriptor</var> answers, wrapped in
/// commas, or <code>""</code> when the read fails, so a caller asserting an absence can tell a failed
/// read from an empty one.</p>
ClassMethod ListText(pDescriptor As %String, pField As %String) As %String
{
    Set tOut = ","
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, 1000, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit ""
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ tRow.%Get(pField) _ ","
    }
    Quit tOut
}

/// <p>A canonical snapshot of what a remote database write or a directory listing can change, as a
/// sorted array of lines: every ECP data server with its listed status and connection state; every
/// database configuration with its server and directory; every service's enablement; the ECP and
/// connection settings; the monitor state; the line counts of <code>messages.log</code> and
/// <code>alerts.log</code> and the count of ERROR #7846 lines; each process with its job type; the
/// <code>^%SYS</code> nodes whose subscripts name ECP or a probe; and OcuPilot's own objects -- its
/// applications, roles, resources, its database, and the install namespace's and <code>%ALL</code>'s
/// mappings, with every namespace.</p>
/// <p>Each vendor read runs in <code>%SYS</code> by explicit save and restore, and calls nothing of
/// this class while it is there.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Kill tLines
    Set tInstallNs = $ZConvert(##class(OcuPilot.Install.Installer).ResolveNamespace(), "U")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.ECPServers:StatusList")
        If $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Set tState = ""
                Try { Set tState = ##class(SYS.ECP).GetServerConnState(tName) } Catch { Set tState = "?" }
                Set tLines("ecpserver|" _ tName _ "|" _ tRS.Get("RemoteAddress") _ "|" _ tRS.Get("RemotePort") _ "|" _ tRS.Get("StatusEnglish") _ "|" _ tState) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("database|" _ tRS.Get("Name") _ "|" _ tRS.Get("Server") _ "|" _ tRS.Get("Directory") _ "|" _ tRS.Get("MountRequired") _ "|" _ tRS.Get("MountAtStartup")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Config.Namespaces:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("namespace|" _ tRS.Get("Namespace") _ "|" _ tRS.Get("Globals") _ "|" _ tRS.Get("Routines") _ "|" _ tRS.Get("Temp Storage")) = ""
            }
        }
        For tNamespace = tInstallNs, "%ALL", ..#NAMESPACENAME {
            If '##class(Config.Namespaces).Exists(tNamespace) Continue
            For tKind = "Globals", "Routines", "Packages" {
                Set tRS = ##class(%ResultSet).%New("Config.Map" _ tKind _ ":List")
                If $$$ISERR(tRS.Execute(tNamespace, "*")) Continue
                While tRS.Next() {
                    Set tLines("mapping|" _ tNamespace _ "|" _ tKind _ "|" _ tRS.Get("Name") _ "|" _ tRS.Get("Database")) = ""
                }
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Services:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("service|" _ tRS.Get("Name") _ "|" _ tRS.Get("EnabledBoolean")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Kill tProperties
                Do ##class(Security.Applications).Get(tName, .tProperties)
                Set tLines("application|" _ tName _ "|" _ $Get(tProperties("NameSpace")) _ "|" _ $Get(tProperties("MatchRoles")) _ "|" _ $Get(tProperties("Enabled"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Kill tProperties
                Do ##class(Security.Roles).Get(tName, .tProperties)
                Set tLines("role|" _ tName _ "|" _ $Get(tProperties("Resources")) _ "|" _ $Get(tProperties("GrantedRoles"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("resource|" _ tRS.Get("Name") _ "|" _ tRS.Get("PublicPermission")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("user|" _ tRS.Get("Name") _ "|" _ tRS.Get("Enabled") _ "|" _ tRS.Get("Roles")) = ""
            }
        }
        Set tRS = ""
        Set tECP = ##class(Config.ECP).Open()
        Set tLines("configecp|" _ tECP.ClientReconnectDuration _ "|" _ tECP.ClientReconnectInterval _ "|" _ tECP.ServerTroubleDuration) = ""
        Set tECP = ""
        Set tConfig = ##class(Config.config).Open()
        Set tLines("configconfig|" _ tConfig.MaxServers _ "|" _ tConfig.MaxServerConn) = ""
        Set tConfig = ""
        Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""
        Set tLines("license|" _ $SYSTEM.License.NetworkEnabled() _ "|" _ $SYSTEM.License.MaxECPServers() _ "|" _ $SYSTEM.License.KeyServer()) = ""
        Set tPid = ""
        For {
            Set tPid = $Order(^$JOB(tPid))
            If tPid = "" Quit
            Set tType = ""
            Try {
                Set tProcess = ##class(%SYS.ProcessQuery).%OpenId(tPid)
                If $IsObject(tProcess) Set tType = tProcess.JobType
                Set tProcess = ""
            } Catch { Set tType = "?" }
            Set tLines("process|" _ tPid _ "|" _ tType) = ""
        }
        Set tNode = "^%SYS"
        For {
            Set tNode = $Query(@tNode)
            If tNode = "" Quit
            Set tNamed = 0
            For tI = 1:1:$QLength(tNode) {
                Set tSub = $ZConvert($QSubscript(tNode, tI), "U")
                If (tSub [ "ECP") || (tSub [ ..#PREFIX) Set tNamed = 1 Quit
            }
            If 'tNamed Continue
            Set tLines("global|" _ tNode _ "=" _ $Extract($Get(@tNode), 1, 120)) = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLines("error|" _ ex.DisplayString()) = ""
    }
    For tFile = "messages.log", "alerts.log" {
        Set tLines("log|" _ tFile _ "|" _ ..LineCount(tFile)) = ""
    }
    Set tLines("log|7846|" _ ..LineCount("messages.log", "ERROR #7846")) = ""
    Set tOut = []
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>The lines of <var>pAfter</var> not in <var>pBefore</var>, as <code>added</code>, and of
/// <var>pBefore</var> not in <var>pAfter</var>, as <code>removed</code>.</p>
ClassMethod Diff(pBefore As %DynamicArray, pAfter As %DynamicArray) As %DynamicObject
{
    Kill tBefore, tAfter
    Set tIterator = pBefore.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tBefore(tLine) = ""
    }
    Set tIterator = pAfter.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tAfter(tLine) = ""
    }
    Set tAdded = []
    Set tRemoved = []
    Set tLine = ""
    For {
        Set tLine = $Order(tAfter(tLine))
        If tLine = "" Quit
        If '$Data(tBefore(tLine)) Do tAdded.%Push(tLine)
    }
    Set tLine = ""
    For {
        Set tLine = $Order(tBefore(tLine))
        If tLine = "" Quit
        If '$Data(tAfter(tLine)) Do tRemoved.%Push(tLine)
    }
    Quit {"added": (tAdded), "removed": (tRemoved)}
}

/// <p>The number of lines of the manager directory's file <var>pFile</var>, or of those containing
/// <var>pContaining</var> when it is given; -1 when the file cannot be read.</p>
ClassMethod LineCount(pFile As %String, pContaining As %String = "") As %Integer
{
    Set tCount = 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(..Manager() _ pFile)) Quit -1
    If '##class(%File).Exists(..Manager() _ pFile) Quit 0
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        If (pContaining = "") || (tLine [ pContaining) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The lines of the manager directory's file <var>pFile</var> after its first <var>pFrom</var>
/// lines, as an array.</p>
ClassMethod LinesAfter(pFile As %String, pFrom As %Integer) As %DynamicArray
{
    Set tOut = []
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(..Manager() _ pFile)) Quit tOut
    Set tCount = 0
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        Set tCount = tCount + 1
        If tCount > pFrom Do tOut.%Push(tLine)
    }
    Quit tOut
}

}
