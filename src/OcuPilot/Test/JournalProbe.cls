/// <p>Test-only helper for Story 18.5's journal suites. It seeds, in <code>%SYS</code> by explicit save
/// and restore, a probe alternate journal directory and probe principals; switches the journal file
/// where the list names no closed file (<method>EnsureClosedFile</method>); restores the journal state a
/// caller captured before it ran; and takes canonical snapshots of what a journal read or write can
/// change, so a run can be compared with the state before it. Every user, role and directory it
/// creates or removes is named with <parameter>PREFIX</parameter> (users and roles compared without
/// case), and it never touches another.</p>
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

/// <p>How many journal file switches <method>EnsureClosedFile</method> makes before it gives up.</p>
Parameter SWITCHLIMIT = 3;

Parameter PORT = "OcuPilot.Port.AdminPort";

/// <p>The <code>Config.Journal</code> properties <method>RestoreJournal</method> puts back.</p>
Parameter JOURNALPROPERTIES = "AlternateDirectory,ArchiveName,BackupsBeforePurge,CompressFiles,CurrentDirectory,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived";

/// <p>The probe database <method>SeedProbeDatabase</method> creates (Story 18.19), its directory
/// suffix under <parameter>DIRPREFIX</parameter>, and the resource guarding it.</p>
Parameter PROBEDATABASE = "OCUPROBE185D";

Parameter PROBESUFFIX = "d";

Parameter PROBERESOURCE = "%DB_OCUPROBE185D";

/// <p>The global the probe database's journaled sets write, and the text every value it sets starts
/// with, the marker a test looks for where no value may reach.</p>
Parameter PROBEGLOBAL = "OcuProbe185";

Parameter PROBEMARKER = "OcuProbe185Value-";

/// <p>The probe database's global journal state: 3, journaled, the value HSCUSTOM's database
/// carries.</p>
Parameter PROBEJOURNALSTATE As INTEGER = 3;

/// <p>The length of the one long value <method>SeedProbeDatabase</method> sets.</p>
Parameter PROBELONG As INTEGER = 1500;

/// <p>The one value <method>SeedProbeDatabase</method> sets that is markup, which a page must render
/// as text.</p>
Parameter PROBEMARKUP = "<b>x</b>";

/// <p>The global <method>SetReadable</method> sets in the install namespace's routines database, the
/// database every probe principal reads (<method>SeedPrincipal</method>), so a principal that cannot
/// read the probe database still has a record it can list and open.</p>
Parameter READABLEGLOBAL = "OcuReadable185";

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

/// <p>Create the probe directory <method>DirectoryFor</method>(<var>pSuffix</var>) when it is absent,
/// and answer it in <var>pDirectory</var>. No journal setting changes.</p>
ClassMethod SeedDirectory(pSuffix As %String, Output pDirectory As %String) As %Status
{
    Set pDirectory = ..DirectoryFor(pSuffix)
    If ##class(%File).DirectoryExists(pDirectory) Quit $$$OK
    If '##class(%File).CreateDirectoryChain(pDirectory) Quit $$$ERROR($$$GeneralError, "the probe directory could not be created")
    Quit $$$OK
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

/// <p>Remove every probe user and role by exact name, the probe database
/// (<method>RemoveProbeDatabase</method>) and the readable record (<method>KillReadable</method>), and
/// every probe directory that holds no file. A probe
/// directory holding a file -- a journal file a switch wrote there -- is left in place.
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
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ..RemoveProbeDatabase())
        Set tSC = $$$ADDSC(tSC, ..KillReadable())
        Set $NAMESPACE = "%SYS"
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

/// <p>Create the probe database <parameter>PROBEDATABASE</parameter> -- its resource first, then its
/// directory <method>DirectoryFor</method>(<parameter>PROBESUFFIX</parameter>), the journaled database
/// and its configuration -- in <code>%SYS</code> (test-only seeding), and set
/// <parameter>PROBEGLOBAL</parameter><code>(i)</code> in it to <parameter>PROBEMARKER</parameter><code>_i</code>
/// for each <code>i</code> from 1 to <var>pCount</var>, one at a time so each is its own journal
/// record: the value at <code>pCount\2</code> is <parameter>PROBELONG</parameter> characters long and
/// the one after it is <parameter>PROBEMARKUP</parameter>. <var>pFile</var> is the journal file
/// journaling writes after the sets, which are synced to it, and <var>pOffset</var> that file's
/// offset just before the first set, so a list from it reads this seed's records and no earlier
/// seed's. Refused, with nothing made, unless <var>pArmed</var> is true. An existing probe database is
/// removed first; a journal switch during the sets is an error.</p>
ClassMethod SeedProbeDatabase(pArmed As %Boolean, Output pFile As %String, pCount As %Integer = 30, Output pOffset As %Integer) As %Status
{
    Set pFile = ""
    Set pOffset = ""
    If 'pArmed Quit $$$ERROR($$$GeneralError, "the journal probe database is created on a throwaway container only, and the calling class's arming variable does not read 1 here, so nothing was made")
    Set tSC = ..RemoveProbeDatabase()
    If $$$ISERR(tSC) Quit tSC
    Set tDirectory = ..DirectoryFor(..#PROBESUFFIX)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Resources).Create(..#PROBERESOURCE, "OcuPilot journal probe database (throwaway)", "", "")
        If $$$ISOK(tSC) && '##class(%File).CreateDirectoryChain(tDirectory) Set tSC = $$$ERROR($$$GeneralError, "the probe database directory could not be created")
        If $$$ISOK(tSC) Set tSC = ##class(SYS.Database).CreateDatabase(tDirectory, 1, 8192, 0, ..#PROBERESOURCE, ..#PROBEJOURNALSTATE)
        If $$$ISOK(tSC) {
            Kill tProperties
            Set tProperties("Directory") = tDirectory
            Set tSC = ##class(Config.Databases).Create(..#PROBEDATABASE, .tProperties)
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        Set tGlobal = "^|""^^" _ tDirectory _ """|" _ ..#PROBEGLOBAL
        Do ##class(%SYS.Journal.System).Sync()
        Set tBefore = ##class(%SYS.Journal.System).GetCurrentFileName()
        Set tOffset = ##class(%SYS.Journal.System).GetCurrentFileOffset()
        For tI = 1:1:pCount {
            Set tValue = ..#PROBEMARKER _ tI
            If tI = (pCount \ 2) Set tValue = $Extract(tValue _ $Translate($Justify("", ..#PROBELONG), " ", "x"), 1, ..#PROBELONG)
            If tI = ((pCount \ 2) + 1) Set tValue = ..#PROBEMARKUP
            Set @tGlobal@(tI) = tValue
        }
        Do ##class(%SYS.Journal.System).Sync()
        Set pFile = ##class(%SYS.Journal.System).GetCurrentFileName()
        If pFile '= tBefore {
            Set tSC = $$$ERROR($$$GeneralError, "the journal file switched while the probe records were written")
            Set pFile = ""
            Quit
        }
        Set pOffset = tOffset
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set <parameter>READABLEGLOBAL</parameter><code>(1)</code> in the install namespace's routines
/// database as one journaled record and sync the journal; <var>pNode</var> is the node as a record's
/// <code>GlobalNode</code> reads it. <method>KillReadable</method> removes it.</p>
ClassMethod SetReadable(Output pNode As %String) As %Status
{
    Set pNode = ""
    Set tSC = ..ReadableReference(.tGlobal)
    If $$$ISERR(tSC) Quit tSC
    Set @tGlobal@(1) = "OcuReadable"
    Do ##class(%SYS.Journal.System).Sync()
    Set pNode = "^" _ ..#READABLEGLOBAL _ "(1)"
    Quit $$$OK
}

/// <p>Kill what <method>SetReadable</method> set.</p>
ClassMethod KillReadable() As %Status
{
    Set tSC = ..ReadableReference(.tGlobal)
    If $$$ISERR(tSC) Quit tSC
    Kill @tGlobal
    Quit $$$OK
}

/// <p><parameter>READABLEGLOBAL</parameter> as an extended reference into the install namespace's
/// routines database, read in <code>%SYS</code>.</p>
ClassMethod ReadableReference(Output pGlobal As %String) As %Status [ Private ]
{
    Set pGlobal = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ##class(Config.Databases).Open(##class(Config.Namespaces).Open(tInstallNs).Routines).Directory
        Set $NAMESPACE = tOrigNS
        Set pGlobal = "^|""^^" _ tDirectory _ """|" _ ..#READABLEGLOBAL
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the probe database <method>SeedProbeDatabase</method> creates, each part by its exact
/// name where it exists -- dismounted, its configuration, its file and directory, and its resource --
/// in <code>%SYS</code>. Its records stay in the journal file.</p>
ClassMethod RemoveProbeDatabase() As %Status
{
    Set tSC = $$$OK
    Set tDirectory = ..DirectoryFor(..#PROBESUFFIX)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(SYS.Database).%ExistsId(tDirectory) Do ##class(SYS.Database).DismountDatabase(tDirectory)
        If ##class(Config.Databases).Exists(..#PROBEDATABASE) Set tSC = $$$ADDSC(tSC, ##class(Config.Databases).Delete(..#PROBEDATABASE))
        If ##class(SYS.Database).%ExistsId(tDirectory) Set tSC = $$$ADDSC(tSC, ##class(SYS.Database).DeleteDatabase(tDirectory))
        If ##class(%File).DirectoryExists(tDirectory) && '##class(%File).RemoveDirectoryTree(tDirectory) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe database directory could not be removed"))
        If ##class(Security.Resources).Exists(..#PROBERESOURCE) Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(..#PROBERESOURCE))
        Set $NAMESPACE = tOrigNS
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

/// <p>Whether the journal file list <var>pRows</var> (<method>Listed</method>'s answer) lacks what the
/// journal suites need, so a switch must close a file: it names fewer than two files, or its second
/// is <var>pCurrent</var>, the file journaling writes now.</p>
ClassMethod NeedsSwitch(pRows As %DynamicArray, pCurrent As %String) As %Boolean
{
    If pRows.%Size() < 2 Quit 1
    Quit (pRows.%Get(1).%Get("Name") = pCurrent)
}

/// <p>Arrange the journal suites' shared precondition on an instance of any age: while the journal
/// file list needs a switch (<method>NeedsSwitch</method>), switch the journal file
/// (<method>SwitchFile</method>), at most <parameter>SWITCHLIMIT</parameter> times. Unless
/// <var>pArmed</var> is true, a list that needs a switch is an error and nothing is switched.
/// <var>pSwitched</var> is how many switches were made. <var>pFirst</var>, when given, stands in for
/// the first list read, so a test can hand it a list the instance no longer has. No journal file is
/// deleted.</p>
ClassMethod EnsureClosedFile(pArmed As %Boolean, Output pSwitched As %Integer, pFirst As %DynamicArray = "") As %Status
{
    Set pSwitched = 0
    Set tSC = $$$OK
    Set tRows = pFirst
    For {
        If '$IsObject(tRows) Set tRows = ..Listed()
        If '$IsObject(tRows) {
            Set tSC = $$$ERROR($$$GeneralError, "the journal file list could not be read")
            Quit
        }
        If '..NeedsSwitch(tRows, ##class(%SYS.Journal.System).GetCurrentFileName()) Quit
        If 'pArmed {
            Set tSC = $$$ERROR($$$GeneralError, "the journal file list names " _ tRows.%Size() _ " file(s) and no closed file after the current one; closing one takes a journal switch, which the calling class's arming variable does not allow here (a throwaway from scripts/ci-throwaway.sh sets it), so nothing was switched")
            Quit
        }
        If pSwitched >= ..#SWITCHLIMIT {
            Set tSC = $$$ERROR($$$GeneralError, "the journal file list names no closed file after " _ pSwitched _ " switches")
            Quit
        }
        Set tSC = ..SwitchFile()
        If $$$ISERR(tSC) Quit
        Set pSwitched = pSwitched + 1
        Set tRows = ""
    }
    Quit tSC
}

/// <p>Close the file journaling writes now and start the next one in the same directory (test-only
/// <code>%SYS.Journal.System</code> seeding in <code>%SYS</code>).</p>
ClassMethod SwitchFile() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Journal.System).RollToNextFile(, .tNewFile)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
/// step is a <method>Run</method> step, <code>{endpoint, type, query, body, port}</code>, a vendor
/// read the path port's journal seams make, <code>{read: "history"}</code> or
/// <code>{read: "wij"}</code>, or the journal record detail route, <code>{route: "record", file,
/// address}</code> (<method>RouteRead</method>).</p>
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
            } ElseIf tStep.%Get("route") '= "" {
                Do tSteps.%Push(..RouteRead(tStep.%Get("file"), tStep.%Get("address")))
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

/// <p>The journal record detail route for <var>pFile</var> and <var>pAddress</var>, run in this process
/// through <class>OcuPilot.Test.JournalRecordDetailFixture</class>, which reads through
/// <class>OcuPilot.Test.JournalCountPort</class>: <code>{route, status, body, calls}</code>,
/// <code>body</code> the parsed envelope and <code>calls</code> the vendor calls it made.</p>
ClassMethod RouteRead(pFile As %String, pAddress As %String) As %DynamicObject
{
    Set tOut = {"route": "record"}
    Try {
        Do ##class(OcuPilot.Test.JournalCountPort).Reset()
        Set tSC = ##class(OcuPilot.Test.JournalRecordDetailFixture).Route(pFile, pAddress, .tBody, .tStatus)
        Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
        Do tOut.%Set("status", +$Get(tStatus), "number")
        Do tOut.%Set("calls", ##class(OcuPilot.Test.JournalCountPort).Calls(), "number")
        If $Get(tBody) '= "" Do tOut.%Set("body", ##class(%DynamicAbstractObject).%FromJSON(tBody))
        Do ##class(OcuPilot.Test.JournalCountPort).Reset()
    } Catch ex {
        Do tOut.%Set("ok", 0, "boolean")
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Quit tOut
}

/// <p>Delete, as objects in <code>%SYS</code>, the admin API's async task rows a probe account queued
/// (its <code>Username</code> a probe name, <method>IsProbe</method>), which that account could not
/// delete itself; any other row is left. <var>pRemoved</var> is how many were deleted.</p>
ClassMethod RemoveProbeTaskRows(Output pRemoved As %Integer) As %Status
{
    Set pRemoved = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTaskClass = $Parameter(..#PORT, "ASYNCTASKCLASS")
        Set tTable = ##class(%Dictionary.CompiledClass).%OpenId(tTaskClass).SqlQualifiedNameQ
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(GUID) AS GUID, %EXACT(Username) AS Username FROM " _ tTable)
        Set tGuids = ""
        While tResult.%Next() {
            If ..IsProbe(tResult.%Get("Username")) Set tGuids = tGuids _ $ListBuild(tResult.%Get("GUID"))
        }
        Set tResult = ""
        Set tPointer = 0
        While $ListNext(tGuids, tPointer, tGuid) {
            Set tDeleteSC = $ClassMethod(tTaskClass, "%DeleteId", tGuid)
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
