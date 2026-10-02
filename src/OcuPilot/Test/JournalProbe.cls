/// <p>Test-only helper for Story 18.5's journal suites. It seeds, in <code>%SYS</code> by explicit save
/// and restore, a probe alternate journal directory and probe principals; restores the journal state a
/// caller captured before it ran; and takes canonical snapshots of what a journal read or write can
/// change, so a run can be compared with the state before it. Every object it creates or removes is
/// named with <parameter>PREFIX</parameter> (users and roles compared without case), and it never
/// touches another.</p>
/// <p><b>It never deletes a journal file.</b> The journal history the instance lists stops at the first
/// missing file, so a probe directory that holds one is left in place; the instance's own purge ages
/// those files out.</p>
/// <p><method>Run</method> issues one admin API call through a port and times it; <method>RunAs</method>
/// runs a plan of such calls, and of the two vendor reads the path port's journal seams make, as a
/// probe principal in a child process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalProbe Extends %RegisteredObject
{

/// <p>The prefix every probe user and role name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE185";

/// <p>The prefix every probe directory's name starts with under the manager directory, compared
/// lower-cased.</p>
Parameter DIRPREFIX = "ocuprobe185";

/// <p>The probe alternate journal directory's suffix.</p>
Parameter ALTSUFFIX = "alt";

Parameter PORT = "OcuPilot.Port.AdminPort";

/// <p>The <code>Config.Journal</code> properties <method>RestoreJournal</method> puts back.</p>
Parameter JOURNALPROPERTIES = "AlternateDirectory,ArchiveName,BackupsBeforePurge,CompressFiles,CurrentDirectory,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived";

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

/// <p>The probe alternate journal directory.</p>
ClassMethod AlternateDirectory() As %String
{
    Quit ..DirectoryFor(..#ALTSUFFIX)
}

/// <p>Whether normalized directory <var>pDirectory</var> is a probe directory.</p>
ClassMethod IsProbeDirectory(pDirectory As %String) As %Boolean
{
    Set tPrefix = $ZConvert(..Manager() _ ..#DIRPREFIX, "L")
    Quit ($Extract($ZConvert(pDirectory, "L"), 1, $Length(tPrefix)) = tPrefix)
}

/// <p>The instance's <code>Config.Journal</code> properties
/// (<parameter>JOURNALPROPERTIES</parameter>) as a JSON object, read in <code>%SYS</code>; a caller
/// keeps it to hand to <method>RestoreJournal</method>.</p>
ClassMethod JournalSettings() As %DynamicObject
{
    Set tOut = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tSC = ##class(Config.Journal).Get(.tProperties)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$Length(..#JOURNALPROPERTIES, ",") {
            Set tName = $Piece(..#JOURNALPROPERTIES, ",", tI)
            Do tOut.%Set(tName, $Get(tProperties(tName)), "string")
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tOut = {}
    }
    Quit tOut
}

/// <p>The directory of the file journaling writes now, normalized.</p>
ClassMethod CurrentDirectory() As %String
{
    Quit ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(##class(%SYS.Journal.System).GetCurrentFileName()))
}

/// <p>Create the probe alternate directory and make it the instance's alternate journal directory
/// (test-only <code>Config.Journal</code> seeding in <code>%SYS</code>). Journaling is not
/// switched.</p>
ClassMethod SeedAlternate() As %Status
{
    Set tDirectory = ..AlternateDirectory()
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(%File).DirectoryExists(tDirectory) {
            If '##class(%File).CreateDirectoryChain(tDirectory) Set tSC = $$$ERROR($$$GeneralError, "the probe alternate directory could not be created")
        }
        If $$$ISOK(tSC) {
            Kill tProperties
            Set tProperties("AlternateDirectory") = tDirectory
            Set tSC = ##class(Config.Journal).Modify(.tProperties)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Put the journal state <var>pBefore</var> (<method>JournalSettings</method>'s answer) back: first,
/// when journaling writes outside <var>pBefore</var>'s <code>CurrentDirectory</code>, switch it back to
/// that directory -- through the vendor's own directory switch while the configured alternate is the
/// directory journaling writes in, and otherwise by switching the file into it -- and then modify every
/// <parameter>JOURNALPROPERTIES</parameter> property that differs (test-only seeding in
/// <code>%SYS</code>). No journal file is deleted.</p>
ClassMethod RestoreJournal(pBefore As %DynamicObject) As %Status
{
    If '$IsObject(pBefore) || (pBefore.%Get("CurrentDirectory") = "") Quit $$$ERROR($$$GeneralError, "no journal state to restore")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPrimary = ##class(%File).NormalizeDirectory(pBefore.%Get("CurrentDirectory"))
        Set tWrites = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(##class(%SYS.Journal.System).GetCurrentFileName()))
        If $ZConvert(tWrites, "L") '= $ZConvert(tPrimary, "L") {
            Kill tNow
            Set tSC = ##class(Config.Journal).Get(.tNow)
            If $$$ISOK(tSC) && ($ZConvert(##class(%File).NormalizeDirectory(tNow("CurrentDirectory")), "L") = $ZConvert(tPrimary, "L")) && ($ZConvert(##class(%File).NormalizeDirectory(tNow("AlternateDirectory")), "L") = $ZConvert(tWrites, "L")) {
                Set tSC = ##class(%SYS.Journal.System).SwitchDirectory(.tNewFile)
            } ElseIf $$$ISOK(tSC) {
                Set tSC = ##class(%SYS.Journal.System).SwitchFile(tPrimary, pBefore.%Get("AlternateDirectory"))
            }
        }
        If $$$ISOK(tSC) {
            Kill tNow, tChanged
            Set tSC = ##class(Config.Journal).Get(.tNow)
            For tI = 1:1:$Length(..#JOURNALPROPERTIES, ",") {
                Set tName = $Piece(..#JOURNALPROPERTIES, ",", tI)
                If pBefore.%IsDefined(tName) && ($Get(tNow(tName)) '= pBefore.%Get(tName)) Set tChanged(tName) = pBefore.%Get(tName)
            }
            If $$$ISOK(tSC) && $Data(tChanged) Set tSC = ##class(Config.Journal).Modify(.tChanged)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone, replacing either when it
/// exists.</p>
ClassMethod SeedPrincipal(pUser As %String, pRole As %String, pResources As %String) As %Status
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot journal probe (throwaway)", tCode _ $Select(pResources = "": "", 1: "," _ pResources), "")
        Set tPassword = $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18))
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, tPassword, "OcuPilot journal probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.JournalProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe user and role by exact name, and every probe directory that holds no file.
/// A probe directory holding a file -- a journal file a switch wrote there -- is left in place.
/// <var>pRemaining</var> is how many probe users and roles survived, and the status is an error when
/// any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tUsers = ..ProbeNames("Security.Users:List", "Name")
        For tI = 1:1:$ListLength(tUsers) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        Set tRoles = ..ProbeNames("Security.Roles:List", "Name")
        For tI = 1:1:$ListLength(tRoles) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set tDirectories = ..ProbeDirectories()
        For tI = 1:1:$ListLength(tDirectories) {
            Set tDirectory = $List(tDirectories, tI)
            If ..FileCount(tDirectory) = 0 Do ##class(%File).RemoveDirectory(tDirectory)
        }
        Set pRemaining = $ListLength(..ProbeNames("Security.Users:List", "Name")) + $ListLength(..ProbeNames("Security.Roles:List", "Name"))
        Set $NAMESPACE = tOrigNS
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe principal(s) survived their removal"))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
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
                If ..IsProbe(tName) Set tNames = tNames _ $ListBuild(tName)
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

/// <p>The files directly in <var>pDirectory</var>, as <code>name:size</code> lines in name order.</p>
ClassMethod Files(pDirectory As %String) As %List
{
    Set tFiles = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    If $$$ISERR(tRS.Execute(pDirectory, "*", "Name", 0)) Quit ""
    While tRS.Next() {
        If tRS.Get("Type") '= "F" Continue
        Set tFiles = tFiles _ $ListBuild(##class(%File).GetFilename(tRS.Get("Name")) _ ":" _ tRS.Get("Size"))
    }
    Quit tFiles
}

/// <p>How many files <var>pDirectory</var> holds directly.</p>
ClassMethod FileCount(pDirectory As %String) As %Integer
{
    Quit $ListLength(..Files(pDirectory))
}

/// <p>The journal file list as the admin API's <code>LIST</code> answers it, whole, through
/// <parameter>PORT</parameter>, or <code>""</code> when it cannot be read.</p>
ClassMethod Listed() As %DynamicArray
{
    Kill tQuery
    Set tQuery("maxRows") = 0
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Journal.File", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Quit tRows
}

/// <p>The newest listed journal file's name, or <code>""</code>.</p>
ClassMethod Newest() As %String
{
    Set tRows = ..Listed()
    If '$IsObject(tRows) || (tRows.%Size() = 0) Quit ""
    Quit tRows.%Get(0).%Get("Name")
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

/// <p>Run the JSON array <var>pPlan</var> as the probe account <var>pUser</var> in a child process,
/// and answer <code>{username, loggedIn, steps}</code>, or an object carrying <code>error</code>. A
/// step is a <method>Run</method> step, <code>{endpoint, type, query, body, port}</code>, or a vendor
/// read the path port's journal seams make, <code>{read: "history"}</code> or
/// <code>{read: "wij"}</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 180) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.JournalProbe).Child($Job, pUser, tPlan)::10
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
/// <var>pPlan</var>, and signal the answers to <var>pParent</var>.</p>
ClassMethod Child(pParent As %Integer, pUser As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUser), "boolean")
        Do tOut.%Set("username", $Username, "string")
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            If tStep.%Get("read") '= "" {
                Do tSteps.%Push(..VendorRead(tStep.%Get("read")))
            } Else {
                Do tSteps.%Push(..Run(tStep.%Get("endpoint"), tStep.%Get("type"), tStep.%Get("query"), tStep.%Get("body"), tStep.%Get("port")))
            }
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>One of the two vendor reads the path port's journal seams make, as the calling process's user,
/// timed: <code>history</code>, the <code>%SYS.Journal.File:ByTimeReverseOrder</code> names, and
/// <code>wij</code>, <code>Config.config</code>'s <code>wijdir</code> read in <code>%SYS</code>. The
/// answer is <code>{read, ok, seconds, count, first, value, status}</code>.</p>
ClassMethod VendorRead(pRead As %String) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("read", pRead, "string")
    Set tStart = $ZHorolog
    Set tOrigNS = $NAMESPACE
    Try {
        If pRead = "history" {
            Set tRS = ##class(%ResultSet).%New("%SYS.Journal.File:ByTimeReverseOrder")
            Set tSC = tRS.Execute()
            Set tCount = 0
            Set tFirst = ""
            While $$$ISOK(tSC) && tRS.Next(.tSC) {
                Set tCount = tCount + 1
                If tFirst = "" Set tFirst = tRS.Get("Name")
            }
            Set tRS = ""
            Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
            Do tOut.%Set("count", tCount, "number")
            Do tOut.%Set("first", tFirst, "string")
            If $$$ISERR(tSC) Do tOut.%Set("status", $System.Status.GetErrorText(tSC), "string")
        } Else {
            Set $NAMESPACE = "%SYS"
            Kill tProperties
            Set tSC = ##class(Config.config).Get(.tProperties)
            Set $NAMESPACE = tOrigNS
            Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
            Do tOut.%Set("value", $Get(tProperties("wijdir")), "string")
            If $$$ISERR(tSC) Do tOut.%Set("status", $System.Status.GetErrorText(tSC), "string")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("ok", 0, "boolean")
        Do tOut.%Set("status", ex.DisplayString(), "string")
    }
    Do tOut.%Set("seconds", $Normalize($ZHorolog - tStart, 3), "number")
    Quit tOut
}

/// <p>A canonical snapshot of what a journal read or write can change, as a sorted array of lines: the
/// file journaling writes now and the journal state; every <code>Config.Journal</code> property and
/// <code>Config.config</code>'s <code>wijdir</code> and <code>targwijsz</code>; the listed file count
/// and the newest five names; each probe directory's files; the admin API's async task rows; the
/// monitor state; the line counts of <code>messages.log</code> and <code>alerts.log</code> and the
/// count of ERROR #7846 lines; and the instance's users, roles, resources and OcuPilot's
/// applications.</p>
/// <p>Each vendor read runs in <code>%SYS</code> by explicit save and restore.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Kill tLines
    Set tLines("journal|current|" _ ##class(%SYS.Journal.System).GetCurrentFileName()) = ""
    Set tLines("journal|state|" _ ##class(%SYS.Journal.System).GetState()) = ""
    Set tSettings = ..JournalSettings()
    Set tIterator = tSettings.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tLines("configjournal|" _ tName _ "|" _ tValue) = ""
    }
    Set tRows = ..Listed()
    If $IsObject(tRows) {
        Set tLines("journal|listed|" _ tRows.%Size()) = ""
        For tI = 0:1:4 {
            If tI >= tRows.%Size() Quit
            Set tLines("journal|newest" _ (tI + 1) _ "|" _ tRows.%Get(tI).%Get("Name")) = ""
        }
    } Else {
        Set tLines("journal|listed|unreadable") = ""
    }
    Set tDirectories = ..ProbeDirectories()
    For tI = 1:1:$ListLength(tDirectories) {
        Set tDirectory = $List(tDirectories, tI)
        Set tFiles = ..Files(tDirectory)
        Set tLines("probedir|" _ tDirectory _ "|" _ $ListLength(tFiles)) = ""
        For tJ = 1:1:$ListLength(tFiles) {
            Set tLines("probefile|" _ tDirectory _ $Piece($List(tFiles, tJ), ":", 1)) = ""
        }
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTaskTable = ##class(%Dictionary.CompiledClass).%OpenId($Parameter(..#PORT, "ASYNCTASKCLASS")).SqlQualifiedNameQ
        Set $NAMESPACE = "%SYS"
        Kill tConfig
        Do ##class(Config.config).Get(.tConfig)
        Set tLines("configconfig|wijdir|" _ $Get(tConfig("wijdir"))) = ""
        Set tLines("configconfig|targwijsz|" _ $Get(tConfig("targwijsz"))) = ""
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) AS N FROM " _ tTaskTable)
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute()
            If tResult.%Next() Set tLines("asynctask|rows|" _ tResult.%Get("N")) = ""
            Set tResult = ""
        }
        Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("user|" _ tRS.Get("Name") _ "|" _ tRS.Get("Enabled") _ "|" _ tRS.Get("Roles")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("role|" _ tRS.Get("Name")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tLines("resource|" _ tRS.Get("Name") _ "|" _ tRS.Get("PublicPermission")) = ""
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
        Set tRS = ""
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
