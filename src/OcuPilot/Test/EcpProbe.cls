/// <p>Test-only helper for Story 18.20's ECP data server suites. It seeds, in <code>%SYS</code> by
/// explicit save and restore, probe ECP data servers (configuration only, at
/// <parameter>SERVERADDRESS</parameter>:<parameter>SERVERPORT</parameter>, never contacted by the
/// seeding), probe remote databases on them, and a probe principal; and it takes canonical snapshots of
/// what a data server write or status change can reach, so a run can be compared with the state before
/// it. Every object it creates or removes is named with <parameter>PREFIX</parameter> (compared
/// upper-cased), and it never touches another.</p>
/// <p><method>RemoveAll</method> removes every probe object by exact name, in order: the probe remote
/// databases, the probe data servers, the principals, the async task rows a probe account queued, the
/// probe SSL/TLS computer names (<parameter>DNPREFIX</parameter>) and the SSL/TLS configurations this
/// helper marked (<parameter>SSLMARKER</parameter>), and restores the ECP settings it is handed.</p>
/// <p>Story 18.21 adds the ECP settings (<method>Settings</method>, <method>RestoreSettings</method>,
/// <method>PendingRestart</method>), the SSL/TLS authorizations (<method>SeedAuthorized</method>,
/// <method>RemoveAuthorized</method>, <method>AuthorizedNames</method>, <method>PendingNames</method>)
/// and the <code>%ECPClient</code> and <code>%ECPServer</code> configurations (<method>SeedSsl</method>,
/// <method>RemoveSsl</method>), each in <code>%SYS</code>.</p>
/// <p><method>Run</method> issues one admin API call through a port and times it; <method>RunAs</method>
/// runs a plan of such calls as a probe principal in a child process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EcpProbe Extends %RegisteredObject
{

/// <p>The prefix every probe data server, remote database, user and role name starts with, compared
/// upper-cased. No other probe prefix matches it.</p>
Parameter PREFIX = "OCUPROBEECP";

/// <p>A TEST-NET-1 address (RFC 5737), which no configuration write can ever connect to.</p>
Parameter SERVERADDRESS = "192.0.2.10";

Parameter SERVERPORT As INTEGER = 1972;

/// <p>The probe user and its role.</p>
Parameter USER = "OCUPROBEECPUSER";

Parameter ROLE = "OCUPROBEECPROLE";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ENDPOINT = "ECP.DataServer";

/// <p>The ECP job types (<code>%syPidtab.inc</code>: <code>ECPWorker</code> 31 through
/// <code>ECPSrvW</code> 35).</p>
Parameter ECPJOBTYPES = "31,32,33,34,35";

/// <p>The ECP daemons' routine names.</p>
Parameter ECPROUTINES = "ECPWorker,ECPCliR,ECPCliW,ECPSrvR,ECPSrvW";

/// <p>The prefix every probe SSL/TLS computer name starts with, compared upper-cased.</p>
Parameter DNPREFIX = "CN=OCUPROBEECP";

/// <p>The description that marks an SSL/TLS configuration this helper created, and so may remove.</p>
Parameter SSLMARKER = "OcuPilot ECP probe (throwaway)";

/// <p>The two SSL/TLS configurations ECP reads, by their fixed names.</p>
Parameter SSLNAMES = "%ECPClient,%ECPServer";

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

/// <p>Define the probe data server <var>pName</var> at <var>pAddress</var>:<var>pPort</var> with
/// <var>pMirror</var> as its mirror connection, when it is absent (test-only seeding in
/// <code>%SYS</code>; nothing is contacted).</p>
ClassMethod SeedServer(pName As %String, pAddress As %String = {..#SERVERADDRESS}, pPort As %Integer = {..#SERVERPORT}, pMirror As %Integer = 0) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe data server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.ECPServers).Exists(pName) {
            Kill tServer
            Set tServer("Address") = pAddress
            Set tServer("Port") = pPort
            If pMirror '= 0 Set tServer("MirrorConnection") = pMirror
            Set tSC = ##class(Config.ECPServers).Create(pName, .tServer)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe remote database <var>pName</var> on the probe data server <var>pServer</var>,
/// over the directory <code>/&lt;name lower-cased&gt;/</code>, defining the server first when it is
/// absent (test-only seeding in <code>%SYS</code>).</p>
ClassMethod SeedRemote(pName As %String, pServer As %String) As %Status
{
    If '..IsProbe(pName) || '..IsProbe(pServer) Quit $$$ERROR($$$GeneralError, "a probe remote database and its server start with " _ ..#PREFIX)
    Set tSC = ..SeedServer(pServer)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.Databases).Exists($ZConvert(pName, "U")) {
            Kill tProperties
            Set tProperties("Server") = $ZConvert(pServer, "U")
            Set tProperties("Directory") = "/" _ $ZConvert(pName, "L") _ "/"
            Set tSC = ##class(Config.Databases).Create($ZConvert(pName, "U"), .tProperties)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the probe remote database <var>pName</var> when it exists.</p>
ClassMethod RemoveRemote(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe remote database's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Databases).Exists($ZConvert(pName, "U")) Set tSC = ##class(Config.Databases).Delete($ZConvert(pName, "U"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe data server <var>pName</var> when it is defined, as another writer could
/// (test-only, in <code>%SYS</code>), setting a Disabled one back to Not Connected first when its
/// delete is refused.</p>
ClassMethod RemoveServer(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe data server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.ECPServers).Exists(pName) {
            Set tSC = ##class(Config.ECPServers).Delete(pName)
            If $$$ISERR(tSC) && (##class(SYS.ECP).GetServerConnState(pName) = 4) {
                Do ##class(SYS.ECP).ServerAction(pName, 1, 1)
                Set tSC = ##class(Config.ECPServers).Delete(pName)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds the <code>%ECPClient</code> SSL/TLS configuration, read in
/// <code>%SYS</code>: 1, 0, or -1 when it cannot be read.</p>
ClassMethod ClientConfigured() As %Integer
{
    Set tExists = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.SSLConfigs).Exists("%ECPClient")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = -1
    }
    Quit tExists
}

/// <p>How many data servers the instance defines, as the admin API's <code>LIST</code> answers them,
/// or -1 when the read fails.</p>
ClassMethod ServerCount() As %Integer
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) || 'tResult.%IsA("%Library.DynamicArray") Quit -1
    Quit tResult.%Size()
}

/// <p>How many <code>%System/%System/ConfigurationChange</code> audit events reading
/// <code>Create section ECPServer <var>pName</var></code> the instance recorded at or after the UTC time
/// <var>pSince</var> (<code>YYYY-MM-DD HH:MM:SS</code>), read in <code>%SYS</code>, or -1 when they cannot
/// be read. Bounded by <code>UTCTimeStamp</code> with <code>%NOINDEX</code> on the event predicates,
/// because the table's event indexes are brought up to date by a background pass
/// (<class>OcuPilot.Test.AuditMarker</class>, DW-85).</p>
ClassMethod CreateEvents(pName As %String, pSince As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tWanted = "Create section ECPServer " _ $ZConvert(pName, "U")
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, "%System", "%System", "ConfigurationChange")
        If tResult.%SQLCODE >= 0 {
            Set tCount = 0
            While tResult.%Next() {
                If tResult.%Get("Description") = tWanted Set tCount = tCount + 1
            }
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The stored impact of the proposal <var>pProposalId</var>, as an object, or <code>""</code>.</p>
ClassMethod ProposalImpact(pProposalId As %String) As %DynamicObject
{
    Set tImpact = ""
    Try {
        Kill tValues
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
        If $$$ISOK(tSC) && tFound && ($Get(tValues("impact")) '= "") Set tImpact = ##class(%DynamicObject).%FromJSON(tValues("impact"))
    } Catch {
        Set tImpact = ""
    }
    Quit tImpact
}

/// <p>An impact <var>pImpact</var> as <code>kind|refused|part...</code>, each part
/// <code>part:count|names|unchecked</code>, or <code>(no impact)</code>.</p>
ClassMethod Said(pImpact As %DynamicObject) As %String
{
    If '$IsObject(pImpact) Quit "(no impact)"
    Set tOut = pImpact.%Get("kind") _ "|" _ $Select($IsObject(pImpact.%Get("refused")): pImpact.refused.code, 1: "")
    If pImpact.%GetTypeOf("parts") '= "array" Quit tOut
    Set tIterator = pImpact.%Get("parts").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPart) {
        Set tNames = ""
        If $IsObject(tPart) && (tPart.%GetTypeOf("names") = "array") {
            Set tNameIterator = tPart.%Get("names").%GetIterator()
            While tNameIterator.%GetNext(.tNameIndex, .tName) {
                Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
            }
        }
        Set tOut = tOut _ "|" _ $Select($IsObject(tPart): tPart.%Get("part") _ ":" _ tPart.%Get("count") _ "|" _ tNames _ "|" _ tPart.%Get("unchecked"), 1: "?")
    }
    Quit tOut
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone with password <var>pPassword</var>
/// (a random one when empty), replacing either when it exists.</p>
ClassMethod SeedPrincipal(pUser As %String = {..#USER}, pRole As %String = {..#ROLE}, pResources As %String = "", pPassword As %String = "") As %Status
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
        Set tGrants = tCode _ $Select(pResources = "": "", 1: "," _ pResources)
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot ECP data server probe (throwaway)", tGrants, "")
        Set tPassword = $Select(pPassword = "": $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), 1: pPassword)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, tPassword, "OcuPilot ECP data server probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.EcpProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe object, each by its exact name, in order: probe remote databases, probe data
/// servers (a server a probe left Disabled is set back to Not Connected first when its delete is
/// refused), the principals, the probe task rows, the probe SSL/TLS computer names and the marked
/// SSL/TLS configurations; then restore <var>pSettings</var>, a <method>Settings</method> answer, when
/// one is given. <var>pRemaining</var> is how many survived, and the status is an error when any
/// did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer, pSettings As %DynamicObject = "") As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tRemotes = ..ProbeRemotes()
        Set tServers = ..ProbeServers()
        Set tUsers = ..ProbeNames("Security.Users:List", "Name")
        Set tRoles = ..ProbeNames("Security.Roles:List", "Name")
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tRemotes) {
            Set tSC = $$$ADDSC(tSC, ##class(Config.Databases).Delete($List(tRemotes, tI)))
        }
        For tI = 1:1:$ListLength(tServers) {
            Set tName = $List(tServers, tI)
            Set tDeleteSC = ##class(Config.ECPServers).Delete(tName)
            If $$$ISERR(tDeleteSC) {
                Set tState = ""
                Try { Set tState = ##class(SYS.ECP).GetServerConnState(tName) } Catch { Set tState = "" }
                If tState = 4 {
                    Do ##class(SYS.ECP).ServerAction(tName, 1, 1)
                    Set tDeleteSC = ##class(Config.ECPServers).Delete(tName)
                }
            }
            Set tSC = $$$ADDSC(tSC, tDeleteSC)
        }
        For tI = 1:1:$ListLength(tUsers) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        For tI = 1:1:$ListLength(tRoles) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ..RemoveProbeTaskRows(.tRemoved))
        Set tNames = ..ProbeDns()
        For tI = 1:1:$ListLength(tNames) {
            Set tSC = $$$ADDSC(tSC, ..RemoveAuthorized($List(tNames, tI)))
        }
        For tI = 1:1:$Length(..#SSLNAMES, ",") {
            Set tSC = $$$ADDSC(tSC, ..RemoveSsl($Piece(..#SSLNAMES, ",", tI)))
        }
        If $IsObject(pSettings) Set tSC = $$$ADDSC(tSC, ..RestoreSettings(pSettings))
        Set pRemaining = ..Remaining()
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe object(s) survived their removal"))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>How many probe objects the instance holds: remote databases, data servers, users, roles, task
/// rows, SSL/TLS computer names and marked SSL/TLS configurations.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..ProbeRemotes()) + $ListLength(..ProbeServers()) + $ListLength(..ProbeNames("Security.Users:List", "Name")) + $ListLength(..ProbeNames("Security.Roles:List", "Name")) + $ListLength(..ProbeTaskRows()) + $ListLength(..ProbeDns()) + ..MarkedSsl()
}

/// <p>The probe data servers the instance defines.</p>
ClassMethod ProbeServers() As %List
{
    Quit ..ProbeNames("Config.ECPServers:List", "Name")
}

/// <p>The probe database configurations the instance defines.</p>
ClassMethod ProbeRemotes() As %List
{
    Quit ..ProbeNames("Config.Databases:List", "Name")
}

/// <p>The names column <var>pColumn</var> of query <var>pQuery</var> answers that start with
/// <parameter>PREFIX</parameter>, compared upper-cased, read in <code>%SYS</code>.</p>
ClassMethod ProbeNames(pQuery As %String, pColumn As %String) As %List
{
    Set tPrefix = ..#PREFIX
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

/// <p>The admin API async task rows a probe account queued, as <code>GUID|Username|State</code>
/// entries.</p>
ClassMethod ProbeTaskRows() As %List
{
    Set tRows = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTaskClass = $Parameter(..#PORT, "ASYNCTASKCLASS")
        Set tTable = ##class(%Dictionary.CompiledClass).%OpenId(tTaskClass).SqlQualifiedNameQ
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(GUID) AS GUID, %EXACT(Username) AS Username, %EXACT(State) AS State FROM " _ tTable)
        While tResult.%Next() {
            If ..IsProbe(tResult.%Get("Username")) Set tRows = tRows _ $ListBuild(tResult.%Get("GUID") _ "|" _ tResult.%Get("Username") _ "|" _ tResult.%Get("State"))
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRows
}

/// <p>Delete, as objects in <code>%SYS</code>, the admin API's async task rows a probe account queued,
/// which that account could not delete itself; any other row is left. <var>pRemoved</var> is how many
/// were deleted.</p>
ClassMethod RemoveProbeTaskRows(Output pRemoved As %Integer) As %Status
{
    Set pRemoved = 0
    Set tSC = $$$OK
    Set tRows = ..ProbeTaskRows()
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTaskClass = $Parameter(..#PORT, "ASYNCTASKCLASS")
        Set $NAMESPACE = "%SYS"
        Set tPointer = 0
        While $ListNext(tRows, tPointer, tRow) {
            Set tDeleteSC = $ClassMethod(tTaskClass, "%DeleteId", $Piece(tRow, "|", 1))
            If $$$ISOK(tDeleteSC) Set pRemoved = pRemoved + 1
            Set tSC = $$$ADDSC(tSC, tDeleteSC)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many processes run an ECP job: a job type in <parameter>ECPJOBTYPES</parameter>, or a routine
/// named in <parameter>ECPROUTINES</parameter>. -1 when the process table cannot be read.</p>
ClassMethod EcpJobs() As %Integer
{
    Set tCount = 0
    Set tTypes = $ListFromString(..#ECPJOBTYPES)
    Set tRoutines = $ListFromString(..#ECPROUTINES)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPid = ""
        For {
            Set tPid = $Order(^$JOB(tPid))
            If tPid = "" Quit
            Set tProcess = ""
            Try { Set tProcess = ##class(%SYS.ProcessQuery).%OpenId(tPid) } Catch { Set tProcess = "" }
            If '$IsObject(tProcess) Continue
            If $ListFind(tTypes, tProcess.JobType) || $ListFind(tRoutines, $Piece(tProcess.Routine, "^", *)) || $ListFind(tRoutines, tProcess.Routine) Set tCount = tCount + 1
            Set tProcess = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The probe data server <var>pName</var>'s connection state as <code>SYS.ECP</code> answers it
/// (1 Not Connected, 4 Disabled, 5 Normal), or <code>""</code> when it is not defined.</p>
ClassMethod ConnState(pName As %String) As %String
{
    Set tState = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.ECPServers).Exists(pName) Set tState = ##class(SYS.ECP).GetServerConnState(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tState = "?"
    }
    Quit tState
}

/// <p>The data server <var>pName</var>'s row as the admin API's <code>LIST</code> answers it, matched
/// without regard to case, or <code>""</code> when no row matches or the read fails.</p>
ClassMethod ListRow(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit ""
    Set tRows = $Select(tResult.%IsA("%DynamicArray"): tResult, 1: tResult.%Get("rows"))
    If '$IsObject(tRows) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert(tRow.%Get("Name"), "U") = $ZConvert(pName, "U") Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>The data server <var>pName</var>'s <code>GET</code>, or <code>""</code> when it is not held.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit ""
    Quit tResult
}

/// <p>Whether the instance holds the data server <var>pName</var>, read through the admin API: 1 when
/// the read answers, 0 when it answers 404, and -1 for any other failure.</p>
ClassMethod Holds(pName As %String) As %Integer
{
    Kill tQuery
    Set tQuery("name") = pName
    If $$$ISOK($ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)) Quit 1
    Quit $Select(+$Get(tHttp) = 404: 0, 1: -1)
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
/// <code>[{endpoint, type, query, body, port}]</code>, as the probe account <var>pUser</var> in a child
/// process, and answer <code>{username, loggedIn, steps}</code>, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 180) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.EcpProbe).Child($Job, pUser, tPlan)::10
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
            Do tSteps.%Push(..Run(tStep.%Get("endpoint"), tStep.%Get("type"), tStep.%Get("query"), tStep.%Get("body"), tStep.%Get("port")))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Whether <var>pName</var> is a probe SSL/TLS computer name (<parameter>DNPREFIX</parameter>,
/// compared upper-cased).</p>
ClassMethod IsProbeDn(pName As %String) As %Boolean
{
    Quit ($Extract($ZConvert(pName, "U"), 1, $Length(..#DNPREFIX)) = ..#DNPREFIX)
}

/// <p>Pre-authorize the probe SSL/TLS computer name <var>pName</var> (test-only seeding through
/// <code>SYS.ECP</code> in <code>%SYS</code>, the only way to make a row).</p>
ClassMethod SeedAuthorized(pName As %String) As %Status
{
    If '..IsProbeDn(pName) Quit $$$ERROR($$$GeneralError, "a probe SSL/TLS computer name starts with " _ ..#DNPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.ECP).AddAuthorizedCN(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the probe SSL/TLS computer name <var>pName</var> from the authorized list (test-only, in
/// <code>%SYS</code>); an absent name is no error.</p>
ClassMethod RemoveAuthorized(pName As %String) As %Status
{
    If '..IsProbeDn(pName) Quit $$$ERROR($$$GeneralError, "a probe SSL/TLS computer name starts with " _ ..#DNPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.ECP).RemoveAuthorizedCN(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every authorized SSL/TLS computer name, as <code>SYS.ECP:SSLAuthorizedConnections</code> answers
/// them in <code>%SYS</code>.</p>
ClassMethod AuthorizedNames() As %List
{
    Quit ..QueryNames("SYS.ECP:SSLAuthorizedConnections")
}

/// <p>Every pending SSL/TLS computer name, as <code>SYS.ECP:SSLPendingConnections</code> answers them
/// in <code>%SYS</code>.</p>
ClassMethod PendingNames() As %List
{
    Quit ..QueryNames("SYS.ECP:SSLPendingConnections")
}

/// <p>The probe SSL/TLS computer names the authorized list holds.</p>
ClassMethod ProbeDns() As %List
{
    Set tOut = ""
    Set tNames = ..AuthorizedNames()
    Set tPointer = 0
    While $ListNext(tNames, tPointer, tName) {
        If ..IsProbeDn(tName) Set tOut = tOut _ $ListBuild(tName)
    }
    Quit tOut
}

/// <p>The <code>SSLComputerName</code> column of <var>pQuery</var>, read in <code>%SYS</code>.</p>
ClassMethod QueryNames(pQuery As %String) As %List [ Private ]
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(pQuery)
        If $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                Set tNames = tNames _ $ListBuild(tRS.Get("SSLComputerName"))
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>Create the ECP SSL/TLS configuration <var>pName</var> (<code>%ECPClient</code> or
/// <code>%ECPServer</code>), a server configuration when <var>pServer</var> is 1, enabled as
/// <var>pEnabled</var> says and marked with <parameter>SSLMARKER</parameter>, only when no
/// configuration of that name exists (test-only, in <code>%SYS</code>). An existing one is an error and
/// is left alone.</p>
ClassMethod SeedSsl(pName As %String, pServer As %Boolean = 0, pEnabled As %Boolean = 0) As %Status
{
    If '$ListFind($ListFromString(..#SSLNAMES), pName) Quit $$$ERROR($$$GeneralError, "this helper seeds only " _ ..#SSLNAMES)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(pName) {
            Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ pName _ " already exists, and this helper will not adopt it")
        } Else {
            Kill tProps
            Set tProps("Type") = $Select(pServer: 1, 1: 0)
            Set tProps("VerifyPeer") = 0
            Set tProps("Enabled") = ''pEnabled
            Set tProps("Description") = ..#SSLMARKER
            Set tSC = ##class(Security.SSLConfigs).Create(pName, .tProps)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the ECP SSL/TLS configuration <var>pName</var> when this helper marked it; one that is
/// anybody else's is left alone, and an absent one is no error.</p>
ClassMethod RemoveSsl(pName As %String) As %Status
{
    If '$ListFind($ListFromString(..#SSLNAMES), pName) Quit $$$ERROR($$$GeneralError, "this helper removes only " _ ..#SSLNAMES)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(pName, .tConfig) && (tConfig.Description = ..#SSLMARKER) {
            Set tConfig = ""
            Set tSC = ##class(Security.SSLConfigs).Delete(pName)
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the marked ECP SSL/TLS configuration <var>pName</var>'s <code>Enabled</code> to
/// <var>pEnabled</var> (test-only, in <code>%SYS</code>); a configuration this helper did not mark is an
/// error and is left alone.</p>
ClassMethod EnableSsl(pName As %String, pEnabled As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.SSLConfigs).Exists(pName, .tConfig) || (tConfig.Description '= ..#SSLMARKER) {
            Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ pName _ " is not this helper's own")
        } Else {
            Set tConfig = ""
            Kill tProps
            Set tProps("Enabled") = ''pEnabled
            Set tSC = ##class(Security.SSLConfigs).Modify(pName, .tProps)
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many of <parameter>SSLNAMES</parameter> exist carrying <parameter>SSLMARKER</parameter>.</p>
ClassMethod MarkedSsl() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#SSLNAMES, ",") {
            If ##class(Security.SSLConfigs).Exists($Piece(..#SSLNAMES, ",", tI), .tConfig) && (tConfig.Description = ..#SSLMARKER) Set tCount = tCount + 1
            Set tConfig = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The six ECP settings as the instance stores them, read in <code>%SYS</code>:
/// <code>{MaxServers, MaxServerConn}</code> from <code>Config.config</code>,
/// <code>{ClientReconnectDuration, ClientReconnectInterval, ServerTroubleDuration}</code> from
/// <code>Config.ECP</code> and <code>SSLECPServer</code> from <code>Security.System</code>, each a
/// number; an object carrying <code>error</code> when they cannot be read.</p>
ClassMethod Settings() As %DynamicObject
{
    Set tOut = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tConfig, tECP, tSystem
        Set tSC = ##class(Config.config).Get(.tConfig)
        Set tSC = $$$ADDSC(tSC, ##class(Config.ECP).Get(.tECP))
        Set tSC = $$$ADDSC(tSC, ##class(Security.System).Get(, .tSystem))
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", $System.Status.GetErrorText(tSC))
        } Else {
            Do tOut.%Set("MaxServers", +$Get(tConfig("MaxServers")), "number")
            Do tOut.%Set("MaxServerConn", +$Get(tConfig("MaxServerConn")), "number")
            Do tOut.%Set("ClientReconnectDuration", +$Get(tECP("ClientReconnectDuration")), "number")
            Do tOut.%Set("ClientReconnectInterval", +$Get(tECP("ClientReconnectInterval")), "number")
            Do tOut.%Set("ServerTroubleDuration", +$Get(tECP("ServerTroubleDuration")), "number")
            Do tOut.%Set("SSLECPServer", +$Get(tSystem("SSLECPServer")), "number")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Write back each of <var>pSettings</var>' six members (a <method>Settings</method> answer) that
/// differs from the stored value, through <code>Config.config</code>, <code>Config.ECP</code> and
/// <code>Security.System</code> in <code>%SYS</code> (test-only). Nothing is written when nothing
/// differs.</p>
ClassMethod RestoreSettings(pSettings As %DynamicObject) As %Status
{
    If '$IsObject(pSettings) || (pSettings.%GetTypeOf("error") '= "unassigned") Quit $$$ERROR($$$GeneralError, "no ECP settings to restore")
    Set tNow = ..Settings()
    If tNow.%GetTypeOf("error") '= "unassigned" Quit $$$ERROR($$$GeneralError, tNow.%Get("error"))
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Kill tConfig, tECP, tSystem
        For tMember = "MaxServers", "MaxServerConn" {
            If pSettings.%Get(tMember) '= tNow.%Get(tMember) Set tConfig(tMember) = pSettings.%Get(tMember)
        }
        For tMember = "ClientReconnectDuration", "ClientReconnectInterval", "ServerTroubleDuration" {
            If pSettings.%Get(tMember) '= tNow.%Get(tMember) Set tECP(tMember) = pSettings.%Get(tMember)
        }
        If pSettings.%Get("SSLECPServer") '= tNow.%Get("SSLECPServer") Set tSystem("SSLECPServer") = pSettings.%Get("SSLECPServer")
        Set $NAMESPACE = "%SYS"
        If $Data(tSystem) Set tSC = $$$ADDSC(tSC, ##class(Security.System).Modify(, .tSystem))
        If $Data(tECP) Set tSC = $$$ADDSC(tSC, ##class(Config.ECP).Modify(.tECP))
        If $Data(tConfig) Set tSC = $$$ADDSC(tSC, ##class(Config.config).Modify(.tConfig))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Whether the instance needs a restart to activate a modified configuration parameter
/// (<code>Config.CPF.PendingRestart</code>, read in <code>%SYS</code>), with its reasons' text in
/// <var>pReasons</var>, one per <code>pReasons(n)</code>; -1 when it cannot be read.</p>
ClassMethod PendingRestart(Output pReasons) As %Integer
{
    Kill pReasons
    Set tPending = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tReasons
        Set tPending = +##class(Config.CPF).PendingRestart(.tReasons)
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:+$Get(tReasons) {
            Set pReasons(tI) = $Get(tReasons(tI))
        }
        Set pReasons = +$Get(tReasons)
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tPending = -1
    }
    Quit tPending
}

/// <p>A canonical snapshot of what a data server write or status change can reach, as a sorted array
/// of lines: the license facts; every ECP data server with its listed status and connection state;
/// every remote database configuration; the count of processes per job type and of ECP jobs;
/// <code>Config.ECP</code> and <code>Config.config</code>'s ECP values; <code>%Service_ECP</code>'s
/// enablement; the <code>%ECPClient</code> and <code>%ECPServer</code> SSL/TLS configurations; the monitor
/// state; the line counts of <code>messages.log</code> and <code>alerts.log</code> and of ERROR #7846
/// lines; the async task rows a probe account queued; the six ECP settings; whether a restart is
/// pending; and the authorized and pending SSL/TLS computer names.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Kill tLines
    Set tLines("license|" _ ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()) = ""
    Set tLines("ecpjobs|" _ ..EcpJobs()) = ""
    Set tTasks = ..ProbeTaskRows()
    Set tPointer = 0
    While $ListNext(tTasks, tPointer, tTask) {
        Set tLines("task|" _ tTask) = ""
    }
    Set tLines("ecpsettings|" _ ..Settings().%ToJSON()) = ""
    Set tLines("pendingrestart|" _ ..PendingRestart()) = ""
    For tKind = "authorized", "pending" {
        Set tNames = $Select(tKind = "authorized": ..AuthorizedNames(), 1: ..PendingNames())
        Set tPointer = 0
        While $ListNext(tNames, tPointer, tName) {
            Set tLines("sslname|" _ tKind _ "|" _ tName) = ""
        }
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.ECPServers:StatusList")
        If $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Set tState = ""
                Try { Set tState = ##class(SYS.ECP).GetServerConnState(tName) } Catch { Set tState = "?" }
                Set tLines("ecpserver|" _ tName _ "|" _ tRS.Get("RemoteAddress") _ "|" _ tRS.Get("RemotePort") _ "|" _ tRS.Get("StatusEnglish") _ "|" _ tRS.Get("MirrorConnection") _ "|" _ tRS.Get("SSLConfig") _ "|" _ tRS.Get("BatchMode") _ "|" _ tState) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                If tRS.Get("Server") = "" Continue
                Set tLines("remotedatabase|" _ tRS.Get("Name") _ "|" _ tRS.Get("Server") _ "|" _ tRS.Get("Directory")) = ""
            }
        }
        Set tRS = ""
        Kill tTypes
        Set tPid = ""
        For {
            Set tPid = $Order(^$JOB(tPid))
            If tPid = "" Quit
            Set tType = "?"
            Try {
                Set tProcess = ##class(%SYS.ProcessQuery).%OpenId(tPid)
                If $IsObject(tProcess) Set tType = tProcess.JobType
                Set tProcess = ""
            } Catch { Set tType = "?" }
            Set tTypes(tType) = $Get(tTypes(tType)) + 1
        }
        Set tType = ""
        For {
            Set tType = $Order(tTypes(tType))
            If tType = "" Quit
            Set tLines("jobtype|" _ tType _ "|" _ tTypes(tType)) = ""
        }
        Set tECP = ##class(Config.ECP).Open()
        Set tLines("configecp|" _ tECP.ClientReconnectDuration _ "|" _ tECP.ClientReconnectInterval _ "|" _ tECP.ServerTroubleDuration) = ""
        Set tECP = ""
        Set tConfig = ##class(Config.config).Open()
        Set tLines("configconfig|" _ tConfig.MaxServers _ "|" _ tConfig.MaxServerConn) = ""
        Set tConfig = ""
        Set tService = ##class(Security.Services).%OpenId("%service_ecp")
        Set tLines("service|%Service_ECP|" _ $Select($IsObject(tService): tService.Enabled, 1: "absent")) = ""
        Set tService = ""
        Set tSSL = ##class(Security.SSLConfigs).Exists("%ECPClient", .tSSLObject)
        Set tLines("sslconfig|%ECPClient|" _ tSSL _ "|" _ $Select(tSSL && $IsObject($Get(tSSLObject)): tSSLObject.Enabled, 1: "")) = ""
        Set tSSLObject = ""
        Set tSSL = ##class(Security.SSLConfigs).Exists("%ECPServer", .tSSLObject)
        Set tLines("sslconfig|%ECPServer|" _ tSSL _ "|" _ $Select(tSSL && $IsObject($Get(tSSLObject)): tSSLObject.Enabled, 1: "")) = ""
        Set tSSLObject = ""
        Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""
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

/// <p>How many of <var>pLines</var> contain <var>pText</var>.</p>
ClassMethod CountContaining(pLines As %DynamicArray, pText As %String) As %Integer
{
    Set tCount = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLine [ pText Set tCount = tCount + 1
    }
    Quit tCount
}

}
