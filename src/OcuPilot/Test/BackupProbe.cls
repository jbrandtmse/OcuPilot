/// <p>The probe objects <class>OcuPilot.Test.BackupWrite</class> creates and removes: two local databases, each in a directory of its
/// own under the manager directory (<parameter>DATABASE</parameter> for the list tests, <parameter>RUNDATABASE</parameter> for the
/// backups a test runs), one user-defined backup task whose device is another directory of its own, and the backup database list as
/// the test found it. The built-in tasks write to a directory the instance may not be able to create, so the run test runs a task it
/// defines. A database a backup touched is never deleted before <method>WaitForNoBackup</method> reports no backup running. Every
/// vendor call here runs in <code>%SYS</code> by explicit save and restore. Not a test case.</p>
Class OcuPilot.Test.BackupProbe Extends %RegisteredObject
{

Parameter DATABASE = "OCUPROBEBACKUP";

Parameter TASK = "OcuProbeBackupTask";

Parameter DATABASEDIRECTORY = "ocuprobebackup/";

/// <p>The database a backup runs over; no list test uses it.</p>
Parameter RUNDATABASE = "OCUPROBERUNBACKUP";

Parameter RUNDIRECTORY = "ocuproberunbackup/";

Parameter DEVICEDIRECTORY = "ocuprobebackupdev/";

/// <p>The manager-directory-relative directory the backup's log files land in.</p>
Parameter LOGDIRECTORY = "Backup/";

/// <p>The names on the backup database list, comma-separated, in list order.</p>
ClassMethod ListedNames() As %String
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Backup.General:DatabaseList")
        Set tSC = tRS.Execute()
        While $$$ISOK(tSC) && tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.GetData(1)
        }
    } Catch {
        Set tNames = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>Replace the backup database list with <var>pNames</var>, comma-separated; the empty text empties it.</p>
ClassMethod SetList(pNames As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Backup.General).ClearDatabaseList()
        For tI = 1:1:$Length(pNames, ",") {
            Set tName = $Piece(pNames, ",", tI)
            If (tName = "") || $$$ISERR(tSC) Continue
            Set tSC = ##class(Backup.General).AddDatabaseToList(tName)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The probe directory <var>pRelative</var> under the manager directory.</p>
ClassMethod Directory(pRelative As %String) As %String
{
    Quit ##class(%File).NormalizeDirectory(pRelative, $System.Util.ManagerDirectory())
}

/// <p>The directory, relative to the manager directory, of the probe database <var>pDatabase</var>, or <code>""</code> for a name
/// that is not a probe database.</p>
ClassMethod RelativeDirectory(pDatabase As %String) As %String [ Private ]
{
    If pDatabase = ..#DATABASE Quit ..#DATABASEDIRECTORY
    If pDatabase = ..#RUNDATABASE Quit ..#RUNDIRECTORY
    Quit ""
}

/// <p>Create the probe database <var>pDatabase</var> (<parameter>DATABASE</parameter> when none is given), in its own directory.
/// Creating <parameter>RUNDATABASE</parameter> also creates the probe task, whose device is the other directory.</p>
ClassMethod Create(pDatabase As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If pDatabase = "" Set pDatabase = ..#DATABASE
        Set tRelative = ..RelativeDirectory(pDatabase)
        If tRelative = "" {
            Set tSC = $$$ERROR($$$GeneralError, "not a probe database: " _ pDatabase)
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ..Directory(tRelative)
        Do ##class(%File).CreateDirectoryChain(tDirectory)
        Set tSC = ##class(SYS.Database).CreateDatabase(tDirectory)
        If $$$ISERR(tSC) Quit
        Set tConfig("Directory") = tDirectory
        Set tSC = ##class(Config.Databases).Create(pDatabase, .tConfig)
        If $$$ISERR(tSC) Quit
        ; The instance lists a database when it is configured, so the probe starts unlisted only once it is taken off.
        Set tIgnored = ##class(Backup.General).RemoveDatabaseFromList(pDatabase)
        If pDatabase '= ..#RUNDATABASE Quit
        Set tDevice = ..Directory(..#DEVICEDIRECTORY)
        Do ##class(%File).CreateDirectoryChain(tDevice)
        Set tTask = ##class(Backup.Task).%New(..#TASK)
        Set tTask.Type = 0
        Set tTask.Device = tDevice
        Set tTask.Description = "OcuPilot probe"
        Set tTask.SwitchJournal = 0
        Set tSC = tTask.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the probe database <var>pDatabase</var> (both probe databases when none is given) and whatever else
/// <method>Create</method> made, by exact name and directory, and the backup's log files the probe task left. Nothing is deleted,
/// dismounted or removed until <method>WaitForNoBackup</method> reports no backup running; when it does not within two minutes this
/// answers <code>backup</code> and changes nothing. A database is deleted through the vendor, retried while the instance still
/// refuses it, and its directory is removed only once no database is mounted there: a directory removed under a mounted database
/// leaves a mount nothing clears. Answers what is still there, or <code>""</code>.</p>
ClassMethod Remove(pDatabase As %String = "") As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        If '..WaitForNoBackup(120) {
            Set tLeft = " backup"
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tNames = $Select(pDatabase = "": ..#DATABASE _ "," _ ..#RUNDATABASE, 1: pDatabase)
        For tI = 1:1:$Length(tNames, ",") {
            Set tName = $Piece(tNames, ",", tI)
            Set tRelative = ..RelativeDirectory(tName)
            If tRelative = "" Continue
            Set tDirectory = ..Directory(tRelative)
            Set tIgnored = ##class(Backup.General).RemoveDatabaseFromList(tName)
            If ##class(Config.Databases).Exists(tName) Do ##class(Config.Databases).Delete(tName)
            If ##class(%File).Exists(tDirectory _ "IRIS.DAT") {
                For tJ = 1:1:30 {
                    If $$$ISOK(##class(SYS.Database).DeleteDatabase(tDirectory)) Quit
                    Hang 0.5
                }
            }
            If ..Mounted(tDirectory) {
                Set tLeft = tLeft _ " mounted"
            } ElseIf ##class(%File).DirectoryExists(tDirectory) {
                Do ##class(%File).RemoveDirectoryTree(tDirectory)
            }
            If ##class(Config.Databases).Exists(tName) Set tLeft = tLeft _ " database"
            If ##class(%File).DirectoryExists(tDirectory) Set tLeft = tLeft _ " directory"
        }
        If (pDatabase = "") || (pDatabase = ..#RUNDATABASE) {
            If ##class(Backup.Task).%ExistsId(..#TASK) Do ##class(Backup.Task).%DeleteId(..#TASK)
            Set tDevice = ..Directory(..#DEVICEDIRECTORY)
            If ##class(%File).DirectoryExists(tDevice) Do ##class(%File).RemoveDirectoryTree(tDevice)
            Set tLogs = ..Directory(..#LOGDIRECTORY)
            Set tFile = $ZSearch(tLogs _ ..#TASK _ "_*.log")
            While tFile '= "" {
                Do ##class(%File).Delete(tFile)
                Set tFile = $ZSearch("")
            }
            If ##class(Backup.Task).%ExistsId(..#TASK) Set tLeft = tLeft _ " task"
        }
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>Whether a backup process is running on the instance, read fresh in <code>%SYS</code>: a process whose routine is named
/// <code>DBACK...</code> (<code>DBACKA</code>, measured on <code>ocupilot-ci</code>). A failed read counts as running.</p>
ClassMethod BackupProcessRunning() As %Boolean
{
    Set tRunning = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Routine FROM %SYS.ProcessQuery")
        If tRS.%SQLCODE '= 0 {
            Set tRunning = 1
        } Else {
            While tRS.%Next() {
                If $Extract(tRS.%Get("Routine"), 1, 5) = "DBACK" Set tRunning = 1
            }
        }
    } Catch {
        Set tRunning = 1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tRunning
}

/// <p>Wait up to <var>pSeconds</var> for a backup process to exist: the probe task reads <code>Running</code> a moment before its
/// process shows. Answers whether one does.</p>
ClassMethod WaitForBackupProcess(pSeconds As %Integer) As %Boolean
{
    For tI = 1:1:pSeconds * 10 {
        If ..BackupProcessRunning() Quit
        Hang 0.1
    }
    Quit ..BackupProcessRunning()
}

/// <p>Wait up to <var>pSeconds</var> for the signal that no backup is running: the probe task does not read <code>Running</code>, no
/// backup process exists, and database writes are not suspended (a backup's own suspension outlasts its Completed status). The signal
/// must hold on two reads half a second apart. Answers whether it came.</p>
ClassMethod WaitForNoBackup(pSeconds As %Integer) As %Boolean
{
    Set tQuiet = 0
    For tI = 1:1:pSeconds * 2 {
        If (..TaskStatus() '= "Running") && '..BackupProcessRunning() && '..WritesFrozen() {
            Set tQuiet = tQuiet + 1
            If tQuiet >= 2 Quit
        } Else {
            Set tQuiet = 0
        }
        Hang 0.5
    }
    Quit (tQuiet >= 2)
}

/// <p>Whether a database is mounted at <var>pDirectory</var>, read fresh in <code>%SYS</code> (the caller's namespace).</p>
ClassMethod Mounted(pDirectory As %String) As %Boolean [ Private ]
{
    Set tMounted = 0
    Try {
        Set tDatabase = ##class(SYS.Database).%OpenId(pDirectory)
        Set tMounted = $IsObject(tDatabase) && tDatabase.Mounted
        Set tDatabase = ""
    } Catch {
        Set tMounted = 0
    }
    Quit tMounted
}

/// <p>Resume database writes, whatever state they are in, and answer whether they are frozen afterwards.</p>
ClassMethod Thaw() As %Boolean
{
    Set tFrozen = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Backup.General).IsWDSuspended() Do ##class(Backup.General).ExternalThaw()
        Set tFrozen = ''##class(Backup.General).IsWDSuspended()
    } Catch {
        Set tFrozen = 1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFrozen
}

/// <p>The probe task's status as the vendor lists it, or <code>(absent)</code>.</p>
ClassMethod TaskStatus() As %String
{
    Set tStatus = "(absent)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Backup.Task:List")
        Set tSC = tRS.Execute()
        While $$$ISOK(tSC) && tRS.Next() {
            If tRS.GetData(1) = ..#TASK Set tStatus = tRS.GetData(8)
        }
    } Catch {
        Set tStatus = "(error)"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tStatus
}

/// <p>Whether database writes are frozen, as 1 or 0.</p>
ClassMethod WritesFrozen() As %Boolean
{
    Set tFrozen = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFrozen = ''##class(Backup.General).IsWDSuspended()
    } Catch {
        Set tFrozen = 1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFrozen
}

/// <p>Start the probe task in the background through the vendor, as an operator's run would.</p>
ClassMethod Start() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Backup.General).StartTask(..#TASK, 1, 1)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>How many backups the history holds.</p>
ClassMethod HistoryCount() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tKey = ""
        For {
            Set tKey = $Order(^SYS("BUHISTORY", tKey))
            If tKey = "" Quit
            If (tKey = +tKey) && (+tKey > 0) Set tCount = tCount + 1
        }
    } Catch {
        Set tCount = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>Replace the backup history with <var>pCount</var> entries, keeping what it held once (<method>KeepHistory</method>) for
/// <method>RestoreHistory</method> to put back. Armed classes only: it rewrites an instance global.</p>
ClassMethod SeedHistory(pCount As %Integer)
{
    Do ..KeepHistory()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill ^SYS("BUHISTORY")
        For tI = 1:1:pCount {
            Set tKey = 66000000000 + tI
            Set ^SYS("BUHISTORY", tKey, "TYPE") = "Full"
            Set ^SYS("BUHISTORY", tKey, "STATUS") = "Completed"
            Set ^SYS("BUHISTORY", tKey, "DESC") = "seeded " _ tI
        }
    } Catch {
        Do ..RestoreHistory()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>Keep the history as it stands in the process-private copy <method>RestoreHistory</method> puts back, so the backups a test
/// runs leave no row; a second call keeps the first call's copy. Armed classes only.</p>
ClassMethod KeepHistory()
{
    If $Data(^||OcuPilotBackupHistorySaved) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set ^||OcuPilotBackupHistorySaved = $Data(^SYS("BUHISTORY"))
        If $Data(^SYS("BUHISTORY")) Merge ^||OcuPilotBackupHistorySaved("data") = ^SYS("BUHISTORY")
    } Catch {
        Kill ^||OcuPilotBackupHistorySaved
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>Put back the history <method>SeedHistory</method> or <method>KeepHistory</method> kept; nothing when it kept none.</p>
ClassMethod RestoreHistory()
{
    If '$Data(^||OcuPilotBackupHistorySaved) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill ^SYS("BUHISTORY")
        If ^||OcuPilotBackupHistorySaved Merge ^SYS("BUHISTORY") = ^||OcuPilotBackupHistorySaved("data")
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Kill ^||OcuPilotBackupHistorySaved
}

/// <p>Wait up to <var>pSeconds</var> for the probe task's status to read <var>pStatus</var>; whether it did.</p>
ClassMethod WaitForStatus(pStatus As %String, pSeconds As %Integer) As %Boolean
{
    For tI = 1:1:pSeconds * 2 {
        If ..TaskStatus() = pStatus Quit
        Hang 0.5
    }
    Quit (..TaskStatus() = pStatus)
}

/// <p>Wait up to <var>pSeconds</var> for the instance's own suspension of writes to end: a backup that read Completed still holds writes
/// for about a second (measured), and a thaw is not asked of it. Answers whether writes read resumed.</p>
ClassMethod WaitForSettled(pSeconds As %Integer) As %Boolean
{
    Set tSettled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:pSeconds * 2 {
            If '##class(Backup.General).IsWDSuspended() Quit
            Hang 0.5
        }
        Set tSettled = '##class(Backup.General).IsWDSuspended()
    } Catch {
        Set tSettled = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSettled
}

/// <p>Wait up to <var>pSeconds</var> for the history to hold <var>pCount</var> backups: the vendor writes a backup's row as it
/// finishes. Answers whether it did.</p>
ClassMethod WaitForHistory(pCount As %Integer, pSeconds As %Integer) As %Boolean
{
    For tI = 1:1:pSeconds * 2 {
        If ..HistoryCount() >= pCount Quit
        Hang 0.5
    }
    Quit (..HistoryCount() >= pCount)
}

/// <p>Wait up to <var>pSeconds</var> for the probe task to stop running; whether it did.</p>
ClassMethod WaitForIdle(pSeconds As %Integer) As %Boolean
{
    For tI = 1:1:pSeconds * 2 {
        If ..TaskStatus() '= "Running" Quit
        Hang 0.5
    }
    Quit (..TaskStatus() '= "Running")
}

}
