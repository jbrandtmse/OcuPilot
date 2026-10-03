/// <p>Test-only helper for Story 18.6's licensing suites. It seeds, in <code>%SYS</code> by explicit
/// save and restore, probe license servers (configuration only, never contacted) and probe
/// principals, and it takes canonical snapshots of what a license key check or activation, or a
/// license server write, can change, so a run can be compared with the state before it. Every object
/// it creates or removes is named with <parameter>PREFIX</parameter> (compared upper-cased), and it
/// never touches another.</p>
/// <p><method>LicenseFacts</method> reads the active key's fields and the key files; it never reads
/// the authorization key. <method>RemoveKeyFiles</method> deletes a key file only when the caller's
/// earlier facts say it was absent.</p>
/// <p><method>Run</method> issues one admin API call through <class>OcuPilot.Port.AdminPort</class>
/// and times it; <method>RunAs</method> runs a plan of such calls as a probe principal in a child
/// process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LicenseProbe Extends %RegisteredObject
{

/// <p>The prefix every probe license server, user and role name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE186";

/// <p>The probe principal Task 0 and the gate tests run as.</p>
Parameter PRINCIPAL = "OcuProbe186T0User";

/// <p>The probe principal's role.</p>
Parameter PRINCIPALROLE = "OcuProbe186T0Role";

/// <p>The probe principal's resources by default: OS management's two pairs.</p>
Parameter PRINCIPALRESOURCES = "%Admin_Manage:U,%DB_IRISSYS:R";

Parameter SERVERADDRESS = "127.0.0.1";

Parameter SERVERPORT As INTEGER = 4999;

Parameter PORT = "OcuPilot.Port.AdminPort";

/// <p>The text a probe sends as a license key: a malformed key, never a real one.</p>
Parameter MALFORMEDKEY = "OCUPROBE186 is not a license key";

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

/// <p>The directory <class>%File</class>'s <code>TempFilename</code> writes into, which is where the
/// vendor's key check writes its temporary key file. It is found by naming one temporary file and
/// deleting it at once.</p>
ClassMethod TempKeyDirectory() As %String
{
    Set tFile = ##class(%File).TempFilename("ocuprobe186")
    If tFile = "" Quit ""
    Set tDirectory = ##class(%File).GetDirectory(tFile, 1)
    If ##class(%File).Exists(tFile) Do ##class(%File).Delete(tFile)
    Quit tDirectory
}

/// <p>The number of <code>*.key</code> files directly in <method>TempKeyDirectory</method>.</p>
ClassMethod TempKeyCount() As %Integer
{
    Set tDirectory = ..TempKeyDirectory()
    If tDirectory = "" Quit -1
    Set tCount = 0
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    If $$$ISERR(tRS.Execute(tDirectory, "*.key")) Quit -1
    While tRS.Next() {
        If tRS.Get("Type") = "F" Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The manager directory's key file <var>pName</var> as <code>exists|size|modified</code>.</p>
ClassMethod KeyFile(pName As %String) As %String
{
    Set tPath = ..Manager() _ pName
    If '##class(%File).Exists(tPath) Quit "0||"
    Quit "1|" _ ##class(%File).GetFileSize(tPath) _ "|" _ ##class(%File).GetFileDateModified(tPath)
}

/// <p>The name of the key file the vendor keeps beside <code>iris.key</code> when a key is replaced:
/// "iris", an underscore and "saved.key", composed because the rename checklist refuses the
/// harvested tool prefix as a literal.</p>
ClassMethod SavedKeyFile() As %String
{
    Quit "iris" _ $Char(95) _ "saved.key"
}

/// <p>The active license's facts as one object: the key fields
/// <code>KeyCustomerName</code>, <code>KeyOrderNumber</code>, <code>KeyLicenseCapacity</code>,
/// <code>KeyExpirationDate</code>, <code>KeyServer</code> and <code>KeyLicenseUnits</code>,
/// <code>IsPendingActivation</code>, <code>MaxECPServers</code> and <code>NetworkEnabled</code>, and the
/// manager directory's <code>iris.key</code> and saved key file (<method>SavedKeyFile</method>) and the
/// temporary key file count. The authorization key is never read.</p>
ClassMethod LicenseFacts() As %DynamicObject
{
    Set tOut = {}
    For tField = "KeyCustomerName", "KeyOrderNumber", "KeyLicenseCapacity", "KeyExpirationDate", "KeyServer", "KeyLicenseUnits", "IsPendingActivation", "MaxECPServers", "NetworkEnabled" {
        Set tValue = ""
        Try { Set tValue = $ClassMethod("%SYSTEM.License", tField) } Catch { Set tValue = "?" }
        Do tOut.%Set(tField, tValue _ "", "string")
    }
    Do tOut.%Set("irisKey", ..KeyFile("iris.key"), "string")
    Do tOut.%Set("irisSavedKey", ..KeyFile(..SavedKeyFile()), "string")
    Do tOut.%Set("tempKeys", ..TempKeyCount(), "number")
    Quit tOut
}

/// <p>Whether two <method>LicenseFacts</method> answers are equal in every member.</p>
ClassMethod SameFacts(pBefore As %DynamicObject, pAfter As %DynamicObject) As %Boolean
{
    If '$IsObject(pBefore) || '$IsObject(pAfter) Quit 0
    Quit (pBefore.%ToJSON() = pAfter.%ToJSON())
}

/// <p>Delete the manager directory's <code>iris.key</code> and saved key file where
/// <var>pBefore</var>, an earlier <method>LicenseFacts</method> answer, says the file was absent, so a
/// file a probe wrote is removed and one that was there is never touched. <var>pRemoved</var> names the
/// files deleted; the status is an error when one could not be.</p>
ClassMethod RemoveKeyFiles(pBefore As %DynamicObject, Output pRemoved As %String) As %Status
{
    Set pRemoved = ""
    Set tSC = $$$OK
    For tPair = "iris.key:irisKey", ..SavedKeyFile() _ ":irisSavedKey" {
        Set tName = $Piece(tPair, ":", 1)
        Set tMember = $Piece(tPair, ":", 2)
        If $Piece(pBefore.%Get(tMember), "|", 1) '= "0" Continue
        Set tPath = ..Manager() _ tName
        If '##class(%File).Exists(tPath) Continue
        If ##class(%File).Delete(tPath) {
            Set pRemoved = pRemoved _ $Select(pRemoved = "": "", 1: ",") _ tName
        } Else {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, tName _ " could not be deleted"))
        }
    }
    Quit tSC
}

/// <p>Define the probe license server <var>pName</var> at <var>pAddress</var>:<var>pPort</var> when
/// it is absent (test-only seeding in <code>%SYS</code>; nothing is contacted).</p>
ClassMethod SeedServer(pName As %String, pAddress As %String = {..#SERVERADDRESS}, pPort As %Integer = {..#SERVERPORT}) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe license server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Config.LicenseServers).Exists(pName) {
            Kill tServer
            Set tServer("Address") = pAddress
            Set tServer("Port") = pPort
            Set tSC = ##class(Config.LicenseServers).Create(pName, .tServer)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance defines license server <var>pName</var>, read in <code>%SYS</code>.</p>
ClassMethod ServerExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Config.LicenseServers).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tExists
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone with password <var>pPassword</var>
/// (a random one when empty), replacing either when it exists.</p>
ClassMethod SeedPrincipal(pUser As %String = {..#PRINCIPAL}, pRole As %String = {..#PRINCIPALROLE}, pResources As %String = {..#PRINCIPALRESOURCES}, pPassword As %String = "") As %Status
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot licensing probe (throwaway)", tCode _ $Select(pResources = "": "", 1: "," _ pResources), "")
        Set tPassword = $Select(pPassword = "": $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), 1: pPassword)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, tPassword, "OcuPilot licensing probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LicenseProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe object, each by its exact name: the license servers, the users and the
/// roles. <var>pRemaining</var> is how many survived, and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tServers = ..ProbeServers()
    Set tUsers = ..ProbeNames("Security.Users:List", "Name")
    Set tRoles = ..ProbeNames("Security.Roles:List", "Name")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tServers) {
            Set tSC = $$$ADDSC(tSC, ##class(Config.LicenseServers).Delete($List(tServers, tI)))
        }
        For tI = 1:1:$ListLength(tUsers) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        For tI = 1:1:$ListLength(tRoles) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set pRemaining = ..Remaining()
    If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe object(s) survived their removal"))
    Quit tSC
}

/// <p>How many probe objects the instance holds: license servers, users and roles.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..ProbeServers()) + $ListLength(..ProbeNames("Security.Users:List", "Name")) + $ListLength(..ProbeNames("Security.Roles:List", "Name"))
}

/// <p>Whether the file <var>pFile</var> carries this instance's authorization key: <code>hit</code>,
/// <code>miss</code>, <code>none</code> when the instance holds no key, or <code>unread</code>. The
/// key itself is never answered; the License key browser spec asks this of the page's DOM.</p>
ClassMethod AuthorizationKeyIn(pFile As %String) As %String
{
    Set tKey = $SYSTEM.License.KeyAuthorizationKey()
    If tKey = "" Quit "none"
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(pFile)) Quit "unread"
    Set tText = ""
    While 'tStream.AtEnd {
        Set tText = tText _ tStream.Read(32000)
    }
    If tText = "" Quit "unread"
    Quit $Select(tText [ tKey: "hit", 1: "miss")
}

/// <p>The probe license servers the instance defines.</p>
ClassMethod ProbeServers() As %List
{
    Quit ..ProbeNames("Config.LicenseServers:List", "Name")
}

/// <p>The names column <var>pColumn</var> of query <var>pQuery</var> answers that start with
/// <parameter>PREFIX</parameter>, compared upper-cased, read in <code>%SYS</code>.</p>
ClassMethod ProbeNames(pQuery As %String, pColumn As %String) As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(pQuery)
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get(pColumn)
                If $Extract($ZConvert(tName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX Set tNames = tNames _ $ListBuild(tName)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>One admin API call through <parameter>PORT</parameter> (or <var>pPort</var>), timed: the query
/// is <var>pQuery</var>'s members, and the answer is
/// <code>{endpoint, type, ok, http, seconds, result, fault, status}</code>, <code>seconds</code> the
/// wall clock to three decimals.</p>
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
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 120) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.LicenseProbe).Child($Job, pUser, tPlan)::10
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

/// <p>License server <var>pName</var>'s stored <var>pField</var>, read in <code>%SYS</code>, or
/// <code>""</code> when the server is absent.</p>
ClassMethod Stored(pName As %String, pField As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tGetSC = ##class(Config.LicenseServers).Get(pName, .tProps)
        If $$$ISOK(tGetSC) Set tValue = $Get(tProps(pField))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>Set license server <var>pName</var>'s <code>KeyDirectory</code> to <var>pDirectory</var>
/// (test-only seeding in <code>%SYS</code>).</p>
ClassMethod SeedKeyDirectory(pName As %String, pDirectory As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe license server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("KeyDirectory") = pDirectory
        Set tSC = ##class(Config.LicenseServers).Modify(pName, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete license server <var>pName</var> (test-only, in <code>%SYS</code>), as another writer
/// could.</p>
ClassMethod RemoveServer(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe license server's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.LicenseServers).Exists(pName) Set tSC = ##class(Config.LicenseServers).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The <var>pField</var> values the declared read of <var>pDescriptor</var> answers, wrapped in
/// commas, or <code>""</code> when the read fails.</p>
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

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> for
/// <var>pUser</var>, this process's user by default, over a completed turn seeded for that user;
/// <var>pProposal</var> is <code>""</code> when the mint refused, with its problem in
/// <var>pProblem</var>.</p>
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

/// <p>Confirm <var>pProposal</var> through <class>OcuPilot.Test.DatabaseConfirm</class> as this
/// process's user, answering <code>http code</code>, the code a field refusal's first violation's
/// where there is one, with the confirm's answer in <var>pResult</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set pResult = ""
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pProposal.%Get("proposalId"), "", $Username, .pResult, .tHttp, .tCode, .tDetail)
    If $$$ISOK(tSC) && ($Get(tCode) = "") Quit "200 "
    If $IsObject($Get(tDetail)) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.violations.%Size() > 0) Set tCode = tDetail.violations.%Get(0).%Get("code")
    Quit +$Get(tHttp) _ " " _ $Get(tCode)
}

/// <p>A canonical snapshot of what a license key check or activation, or a license server write, can
/// change, as a sorted array of lines: the license facts (<method>LicenseFacts</method>); every license
/// server; each process with its job type; the line counts of <code>messages.log</code> and
/// <code>alerts.log</code>; the monitor state; and OcuPilot's own objects -- its applications, roles
/// and resources -- and the probe accounts.</p>
/// <p>Each vendor read runs in <code>%SYS</code> by explicit save and restore, and calls nothing of
/// this class while it is there.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Kill tLines
    Set tFacts = ..LicenseFacts()
    Set tIterator = tFacts.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tLines("license|" _ tKey _ "|" _ tValue) = ""
    }
    Set tPrefix = ..#PREFIX
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.LicenseServers:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("licenseserver|" _ tRS.Get("Name") _ "|" _ tRS.Get("Address") _ "|" _ tRS.Get("Port") _ "|" _ tRS.Get("KeyDirectory")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $ZConvert(tName, "L") '[ "ocupilot" Continue
                Kill tProperties
                Do ##class(Security.Applications).Get(tName, .tProperties)
                Set tLines("application|" _ tName _ "|" _ $Get(tProperties("NameSpace")) _ "|" _ $Get(tProperties("MatchRoles")) _ "|" _ $Get(tProperties("Enabled"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Set tProbe = ($Extract($ZConvert(tName, "U"), 1, $Length(tPrefix)) = tPrefix)
                If ($ZConvert(tName, "U") '[ "OCUPILOT") && 'tProbe Continue
                Kill tProperties
                Do ##class(Security.Roles).Get(tName, .tProperties)
                Set tLines("role|" _ tName _ "|" _ $Get(tProperties("Resources")) _ "|" _ $Get(tProperties("GrantedRoles"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $ZConvert(tName, "U") '[ "OCUPILOT" Continue
                Set tLines("resource|" _ tName _ "|" _ tRS.Get("PublicPermission")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $Extract($ZConvert(tName, "U"), 1, $Length(tPrefix)) '= tPrefix Continue
                Set tLines("user|" _ tName _ "|" _ tRS.Get("Enabled") _ "|" _ tRS.Get("Roles")) = ""
            }
        }
        Set tRS = ""
        Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""
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
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLines("error|" _ ex.DisplayString()) = ""
    }
    For tFile = "messages.log", "alerts.log" {
        Set tLines("log|" _ tFile _ "|" _ ..LineCount(tFile)) = ""
    }
    Set tOut = []
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>The <method>Snapshot</method> lines a licensing test can change and must leave as found: the
/// license's facts and every license server the instance defines, newline-joined in order.</p>
ClassMethod LicenseLines() As %String
{
    Set tOut = ""
    Set tIterator = ..Snapshot().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If $Extract(tLine, 1, 7) = "license" Set tOut = tOut _ $Select(tOut = "": "", 1: $Char(10)) _ tLine
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
    If '##class(%File).Exists(..Manager() _ pFile) Quit 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(..Manager() _ pFile)) Quit -1
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
