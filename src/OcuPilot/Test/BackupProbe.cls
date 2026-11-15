/// <p>The probe objects <class>OcuPilot.Test.BackupWrite</class> creates and removes: one local database in a directory of its own
/// under the manager directory, one user-defined backup task whose device is another directory of its own, and the backup database
/// list as the test found it. The built-in tasks write to a directory the instance may not be able to create, so the run test
/// runs a task it defines. Every vendor call here runs in <code>%SYS</code> by explicit save and restore. Not a test case.</p>
Class OcuPilot.Test.BackupProbe Extends %RegisteredObject
{

Parameter DATABASE = "OCUPROBEBACKUP";

Parameter TASK = "OcuProbeBackupTask";

Parameter DATABASEDIRECTORY = "ocuprobebackup/";

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

/// <p>Create the probe database, in its own directory, and the probe task, whose device is the other directory.</p>
ClassMethod Create() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ..Directory(..#DATABASEDIRECTORY)
        Set tDevice = ..Directory(..#DEVICEDIRECTORY)
        Do ##class(%File).CreateDirectoryChain(tDirectory)
        Do ##class(%File).CreateDirectoryChain(tDevice)
        Set tSC = ##class(SYS.Database).CreateDatabase(tDirectory)
        If $$$ISERR(tSC) Quit
        Set tConfig("Directory") = tDirectory
        Set tSC = ##class(Config.Databases).Create(..#DATABASE, .tConfig)
        If $$$ISERR(tSC) Quit
        ; The instance lists a database when it is configured, so the probe starts unlisted only once it is taken off.
        Set tIgnored = ##class(Backup.General).RemoveDatabaseFromList(..#DATABASE)
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

/// <p>Remove whatever <method>Create</method> made, by exact name and directory, and the backup's log files and history rows the
/// probe task left. Answers what is still there, or <code>""</code>.</p>
ClassMethod Remove() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ..Directory(..#DATABASEDIRECTORY)
        Set tIgnored = ##class(Backup.General).RemoveDatabaseFromList(..#DATABASE)
        If ##class(Backup.Task).%ExistsId(..#TASK) Do ##class(Backup.Task).%DeleteId(..#TASK)
        If ##class(Config.Databases).Exists(..#DATABASE) Do ##class(Config.Databases).Delete(..#DATABASE)
        If ##class(%File).Exists(tDirectory _ "IRIS.DAT") Do ##class(SYS.Database).DeleteDatabase(tDirectory)
        If ##class(%File).DirectoryExists(tDirectory) Do ##class(%File).RemoveDirectoryTree(tDirectory)
        Set tDevice = ..Directory(..#DEVICEDIRECTORY)
        If ##class(%File).DirectoryExists(tDevice) Do ##class(%File).RemoveDirectoryTree(tDevice)
        Set tLogs = ..Directory(..#LOGDIRECTORY)
        Set tFile = $ZSearch(tLogs _ ..#TASK _ "_*.log")
        While tFile '= "" {
            Do ##class(%File).Delete(tFile)
            Set tFile = $ZSearch("")
        }
        If ##class(Backup.Task).%ExistsId(..#TASK) Set tLeft = tLeft _ " task"
        If ##class(Config.Databases).Exists(..#DATABASE) Set tLeft = tLeft _ " database"
        If ##class(%File).DirectoryExists(tDirectory) Set tLeft = tLeft _ " directory"
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tLeft
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

/// <p>Replace the backup history with <var>pCount</var> entries, keeping what it held once in a process-private copy that
/// <method>RestoreHistory</method> puts back. A second call keeps the first call's copy. Armed classes only: it rewrites an
/// instance global.</p>
ClassMethod SeedHistory(pCount As %Integer)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '$Data(^||OcuPilotBackupHistorySaved) {
            Set ^||OcuPilotBackupHistorySaved = $Data(^SYS("BUHISTORY"))
            If $Data(^SYS("BUHISTORY")) Merge ^||OcuPilotBackupHistorySaved("data") = ^SYS("BUHISTORY")
        }
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

/// <p>Put back the history <method>SeedHistory</method> kept; nothing when it kept none.</p>
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
/// for a moment, and a thaw is not asked of it.</p>
ClassMethod WaitForSettled(pSeconds As %Integer)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:pSeconds * 2 {
            If '##class(Backup.General).IsWDSuspended() Quit
            Hang 0.5
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
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
