/// <p>Test-only helper for the disk operation suites (Story 18.4): <class>OcuPilot.Test.DatabaseWriteProbe</class>
/// under <parameter>PREFIX</parameter> <code>OCUPROBE184</code>, with what those suites seed beyond it --
/// probe globals written and half removed so a compact or a truncate has space to act on
/// (<method>Fill</method>), a file grown to a size (<method>Grow</method>), an admin API compact
/// paused while it runs (<method>PausedAdminCompact</method>), and a data block damaged for an integrity
/// check to find (<method>DamageBlock</method>) -- and a <method>RemoveAll</method> that
/// also ends and removes the background tasks and integrity checks run over a probe directory and the
/// caller's own async tasks those queued.</p>
/// <p>Every seed names a probe database by its probe name and is refused outside the prefix. Globals are
/// written by extended reference, a size set through <code>SYS.Database</code> and a block through the
/// view buffer in <code>%SYS</code>: test-only seeding.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseActionProbe Extends OcuPilot.Test.DatabaseWriteProbe
{

Parameter PREFIX = "OCUPROBE184";

Parameter DIRPREFIX = "ocuprobe184";

Parameter APPPREFIX = "/csp/ocuprobe184";

Parameter RESOURCEPREFIX = "%DB_OCUPROBE184";

Parameter SERVERNAME = "OCUPROBE184SRV";

Parameter EXTRANAMES = "1OCUPROBE184,%OCUPROBE184";

/// <p>The probe global <method>Fill</method> writes.</p>
Parameter GLOBAL = "OcuProbe184Fill";

/// <p>The bytes one filled node carries.</p>
Parameter NODEBYTES As INTEGER = 3900;

/// <p>The endpoint the disk operations queue through, and the text their task names carry.</p>
Parameter ACTIONSENDPOINT = "Database.Actions";

Parameter TASKLABEL = "/database/actions";

/// <p>The directory of the probe database <var>pName</var>, as its configuration names it, or its
/// probe directory when it names none.</p>
ClassMethod DirectoryOf(pName As %String) As %String
{
    Set tDirectory = ..Stored(pName, "Directory")
    If tDirectory = "" Set tDirectory = ..DirectoryFor($Extract(pName, $Length(..#PREFIX) + 1, *))
    Quit tDirectory
}

/// <p>Write about <var>pMB</var> megabytes of <parameter>GLOBAL</parameter> into the probe database
/// <var>pName</var> and remove its first half, so the file holds free space before its data. Test-only
/// seeding by extended reference.</p>
ClassMethod Fill(pName As %String, pMB As %Integer) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tSC = $$$OK
    Try {
        Set tGlobal = "^|""^^" _ ..DirectoryOf(pName) _ """|" _ ..#GLOBAL
        Kill @tGlobal
        Set tNodes = (pMB * 1048576) \ ..#NODEBYTES
        Set tValue = $Justify("", ..#NODEBYTES)
        For tI = 1:1:tNodes {
            Set @tGlobal@(tI) = tValue
        }
        For tI = 1:1:(tNodes \ 2) {
            Kill @tGlobal@(tI)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Grow the probe database <var>pName</var>'s file to <var>pMB</var> megabytes through
/// <code>SYS.Database.ModifyDatabase</code> in <code>%SYS</code> (test-only seeding).</p>
ClassMethod Grow(pName As %String, pMB As %Integer) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tDirectory = ..DirectoryOf(pName)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.Database).ModifyDatabase(tDirectory, pMB)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Damage the probe database <var>pName</var>'s last data block of <parameter>GLOBAL</parameter>,
/// the one <method>Fill</method> writes last and keeps, answering its number in <var>pBlock</var>: its
/// block type is set to 0, so an integrity check finds a pointer to a block that is not a data block.
/// The block is found as the highest-numbered data block (type 8) naming the global; test-only seeding
/// through the view buffer in <code>%SYS</code>, as the vendor's own block editor writes one. A database
/// outside the prefix, and one holding no such block, are refused.</p>
ClassMethod DamageBlock(pName As %String, Output pBlock As %Integer) As %Status
{
    Set pBlock = 0
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe database's name starts with " _ ..#PREFIX)
    Set tDirectory = ..DirectoryOf(pName)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tOpen = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDatabase = ##class(SYS.Database).%OpenId(tDirectory)
        If '$IsObject(tDatabase) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe database did not open")
            Quit
        }
        Set tBlocks = tDatabase.Blocks
        Set tBlockSize = tDatabase.BlockSize
        Set tDatabase = ""
        Set tTypeOffset = $ZUtil(40, 32, 1)
        Open 63:"^^" _ tDirectory
        Set tOpen = 1
        For tBlock = tBlocks:-1:1 {
            View tBlock
            If ($View(tTypeOffset, 0, 1) = 8) && ($View(0, 0, -tBlockSize) [ ..#GLOBAL) Set pBlock = tBlock Quit
        }
        If pBlock = 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the probe database holds no data block of " _ ..#GLOBAL)
            Quit
        }
        View pBlock
        View tTypeOffset:0:1:0
        Set tSwitch = $ZUtil(68, 80, 1)
        View -pBlock
        Do $ZUtil(68, 80, tSwitch)
        Kill tSwitch
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        If $Data(tSwitch) Do $ZUtil(68, 80, tSwitch)
        Set tSC = ex.AsStatus()
    }
    If tOpen Close 63
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Give the probe database in <var>pDirectory</var> a volume file in the probe directory
/// <var>pVolumeDirectory</var>, created when absent, through <code>SYS.Database.NewVolume</code> in
/// <code>%SYS</code> (test-only seeding); a directory outside the probe directories is refused.</p>
ClassMethod AddVolumeIn(pDirectory As %String, pVolumeDirectory As %String) As %Status
{
    If '..IsProbeDirectory(pDirectory) || '..IsProbeDirectory(pVolumeDirectory) Quit $$$ERROR($$$GeneralError, "a probe directory starts with " _ ..#DIRPREFIX)
    If '##class(%File).CreateDirectoryChain(pVolumeDirectory) Quit $$$ERROR($$$GeneralError, "the probe volume directory could not be created")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.Database).NewVolume(pDirectory, pVolumeDirectory, 1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The state of the database in <var>pDirectory</var> as <class>OcuPilot.Port.DatabasePort</class>'s
/// <code>STATE</code> read answers it, or <code>""</code>.</p>
ClassMethod State(pDirectory As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tSC = ##class(OcuPilot.Port.DatabasePort).Invoke(..#ACTIONSENDPOINT, "STATE", .tQuery, "", .tState, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tState)) Quit ""
    Quit tState
}

/// <p>Queue a compact of the probe database <var>pName</var> through
/// <class>OcuPilot.Test.DatabaseQueuedPort</class>, which answers it started, and pause its background
/// task as soon as it exists, answering the async task's GUID in <var>pGuid</var> and the background
/// task's id in <var>pTaskId</var>. The database is filled first with <var>pMB</var> megabytes, half
/// removed, and compacted toward all of its free space, so the compact has work to do while it is
/// paused. An error status names the step that failed, a compact that ended before it could be paused
/// among them.</p>
ClassMethod PausedAdminCompact(pName As %String, Output pGuid As %String, Output pTaskId As %String, pMB As %Integer = 600) As %Status
{
    Set pGuid = ""
    Set pTaskId = ""
    Set tSC = ..Fill(pName, pMB)
    If $$$ISERR(tSC) Quit tSC
    Set tDirectory = ..DirectoryOf(pName)
    Do ##class(OcuPilot.Test.DatabaseQueuedPort).Clear()
    Kill tQuery
    Set tQuery("dir") = tDirectory
    Set tState = ..State(tDirectory)
    Set tQuery("TargetFreeSpace") = $Select($IsObject(tState): tState.%Get("FreeSpace") \ 1, 1: 0)
    Set tSC = ##class(OcuPilot.Test.DatabaseQueuedPort).Invoke(..#ACTIONSENDPOINT, "COMPACT", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set pGuid = ##class(OcuPilot.Test.DatabaseQueuedPort).LastTask()
    If +$Get(tHttp) '= 202 Quit $$$ERROR($$$GeneralError, "the compact was answered " _ $Get(tHttp) _ ", not started")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:1000 {
            Set pTaskId = ..RunningTask(tDirectory)
            If pTaskId '= "" Quit
            Hang 0.005
        }
        If pTaskId = "" {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the compact registered no background task")
            Quit
        }
        Set tTask = ##class(%SYS.BackgroundTask).%OpenId(pTaskId)
        Set tSC = $Select($IsObject(tTask): tTask.Pause(), 1: $$$ERROR($$$GeneralError, "the compact's background task did not open"))
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The id of a <code>%SYS.BackgroundTask:DatabaseList</code> task that has not ended over directory
/// <var>pDirectory</var>, compared without regard to case, or <code>""</code>. Runs in
/// <code>%SYS</code>.</p>
ClassMethod RunningTask(pDirectory As %String) As %String [ Private ]
{
    Set tId = ""
    Set tRS = ##class(%ResultSet).%New("%SYS.BackgroundTask:DatabaseList")
    If $$$ISERR(tRS.Execute()) Quit ""
    While tRS.Next() {
        If tRS.Get("HasEnded") Continue
        If '..SameDirectory(tRS.Get("Database"), pDirectory) Continue
        Set tId = tRS.Get("ID")
        Quit
    }
    Do tRS.Close()
    Quit tId
}

/// <p>Whether two directories name one place, as <method>OcuPilot.Port.DatabasePort.SameDirectory</method>
/// answers it, computed here because <method>RunningTask</method> calls it in <code>%SYS</code>, where
/// that class does not resolve.</p>
ClassMethod SameDirectory(pA As %String, pB As %String) As %Boolean [ Private ]
{
    Set tA = $ZConvert($ZStrip(pA, ">", "/\"), "L")
    Quit (tA '= "") && (tA = $ZConvert($ZStrip(pB, ">", "/\"), "L"))
}

/// <p>End and remove every background task and integrity check run over a probe directory, and settle
/// the caller's own async tasks the disk operations queued, then remove every probe object
/// (<method>OcuPilot.Test.DatabaseWriteProbe.RemoveAll</method>). A background task still running is
/// canceled and waited for, since a database a task runs against cannot be removed.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = ..RemoveTasks()
    Set tSC = $$$ADDSC(tSC, ..SettleOwnTasks())
    Set tSC = $$$ADDSC(tSC, ##super(.pRemaining))
    Quit tSC
}

/// <p>Cancel, wait for and delete every <code>%SYS.BackgroundTask</code> whose database is a probe
/// directory, and every <code>SYS.BackgroundIntegrity</code> check that names one. Runs in
/// <code>%SYS</code>.</p>
ClassMethod RemoveTasks() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ""
        Set tRS = ##class(%ResultSet).%New("%SYS.BackgroundTask:DatabaseList")
        If $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                If ..IsProbeDirectory(##class(%File).NormalizeDirectory(tRS.Get("Database"))) Set tIds = tIds _ $ListBuild(tRS.Get("ID"))
            }
        }
        Do tRS.Close()
        Set tRS = ##class(%ResultSet).%New("SYS.BackgroundIntegrity:ListIntegrityTasks")
        If $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                Set tList = tRS.Get("DatabaseList")
                For tI = 1:1:$ListLength(tList) {
                    If ..IsProbeDirectory(##class(%File).NormalizeDirectory($ListGet(tList, tI))) Set tIds = tIds _ $ListBuild(tRS.Get("ID")) Quit
                }
            }
        }
        Do tRS.Close()
        For tI = 1:1:$ListLength(tIds) {
            Set tId = $List(tIds, tI)
            Set tTask = ##class(%SYS.BackgroundTask).%OpenId(tId)
            If '$IsObject(tTask) Continue
            If 'tTask.HasEnded Do tTask.Cancel()
            Set tClass = $ClassName(tTask)
            Set tTask = ""
            For tWait = 1:1:300 {
                Set tTask = ##class(%SYS.BackgroundTask).%OpenId(tId)
                Set tEnded = '$IsObject(tTask) || tTask.HasEnded
                Set tTask = ""
                If tEnded Quit
                Hang 0.1
            }
            Set tSC = $$$ADDSC(tSC, $ClassMethod(tClass, "%DeleteId", tId))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The caller's own async tasks a disk operation queued (their task name carries
/// <parameter>TASKLABEL</parameter>), each settled through
/// <method>OcuPilot.Test.DatabaseQueuedPort.Settle</method> -- read until terminal, read once when it is,
/// and its row deleted -- read through the admin port's own <code>AsyncResult</code> list.</p>
ClassMethod SettleOwnTasks() As %Status
{
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("AsyncResult", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) Quit $$$OK
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || ($ZConvert(tRow.%Get("TaskName"), "L") '[ ..#TASKLABEL) Continue
        Do ##class(OcuPilot.Test.DatabaseQueuedPort).Settle(tRow.%Get("GUID"))
    }
    Quit $$$OK
}

/// <p>How many of the caller's own async tasks a disk operation queued are still held, read through the
/// admin port's own <code>AsyncResult</code> list; <code>-1</code> when it cannot be read.</p>
ClassMethod OwnTaskCount() As %Integer
{
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("AsyncResult", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit -1
    Set tCount = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($ZConvert(tRow.%Get("TaskName"), "L") [ ..#TASKLABEL) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>How many lines of the instance's <code>messages.log</code> carry
/// <code>ERROR #7846</code>, the vendor's alert for a second read of an ended async task (AD-26);
/// <code>-1</code> when the file does not exist or cannot be read.</p>
ClassMethod SecondReads() As %Integer
{
    Set tCount = 0
    Set tFile = ##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory())
    If '##class(%File).Exists(tFile) Quit -1
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If $$$ISERR(tStream.LinkToFile(tFile)) {
            Set tCount = -1
            Quit
        }
        While 'tStream.AtEnd {
            If tStream.ReadLine() [ "#7846" Set tCount = tCount + 1
        }
        Set tStream = ""
    } Catch {
        Set tCount = -1
    }
    Quit tCount
}

}
