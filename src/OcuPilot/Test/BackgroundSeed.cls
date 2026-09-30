/// <p>Seeds real background work for the Background tasks tests (Story 16.5) and removes exactly what
/// it made: a scratch database, <parameter>DATABASE</parameter>, filled and half freed so a compact
/// has work to do, and a Management Portal compact of it paused at once.
/// <class>OcuPilot.Test.BackgroundTasksLive</class> and
/// <file>ui/browser/background-tasks.browser-spec.mjs</file> both use it, so the recipes live once.</p>
/// <p><b>It creates a database, its resource and a running job</b>, so every method that makes, holds,
/// stops or removes something refuses unless <parameter>ARMINGVARIABLE</parameter> reads 1, which only
/// <file>scripts/ci-throwaway.sh</file> sets. The jobs it started are kept in
/// <code>^IRIS.Temp.OcuPilotBackgroundSeed</code>, so the removal may run in another process than the
/// seed. A task <method>Hold</method> holds is released by a <method>Remove</method> in the process
/// that holds it, or when that process ends.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundSeed Extends %RegisteredObject
{

/// <p>The variable that arms this class, as it arms every class that creates security objects.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The scratch database's name and directory name.</p>
Parameter DATABASE = "OCUBGSEED";

/// <p>The resource guarding the scratch database, created before the database.</p>
Parameter RESOURCE = "%DB_OCUBGSEED";

/// <p>How many 3,900-byte nodes the fill writes before half are killed: about 1.2 GB, which a
/// compact takes about two seconds to work through (measured on this build: 410 MB in 0.66 s), so
/// a test has time to act on it while it runs.</p>
Parameter NODES As INTEGER = 300000;

/// <p>The free space, in MB, the compact aims to leave at the end of the file: more than the
/// database can free, so it compacts all it can.</p>
Parameter TARGETMB As INTEGER = 5000;

/// <p>The portal's name for the compact task, as <code>%CSP.UI.System.BackgroundTask</code> runs
/// it.</p>
Parameter COMPACTTASK = "CompactDBSpace";

/// <p>How long, in seconds, <method>Remove</method> keeps reading a task it canceled for the
/// vendor's record of its end. The cancel before it blocks about 18 s on a job that does not respond,
/// and the last read can wait out the lock timeout (10 s) past this bound. A job that does not respond
/// acts on the cancel only once it runs again, as a compact on a host whose writes stall does
/// (inference).</p>
Parameter ENDSECONDS As INTEGER = 60;

/// <p>A refusal status unless this instance is armed.</p>
ClassMethod Armed() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) = 1 Quit $$$OK
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.BackgroundSeed creates a database and starts a compact of it, and runs on a throwaway container only; " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was made")
}

/// <p>The scratch database's directory, under the manager directory.</p>
ClassMethod Directory() As %String
{
    Quit ##class(%File).NormalizeDirectory(##class(%File).SubDirectoryName($System.Util.ManagerDirectory(), $ZConvert(..#DATABASE, "L")))
}

/// <p>Create the scratch database where it is absent -- resource first, then directory, database
/// and configuration -- and fill it afresh: <parameter>NODES</parameter> nodes, the first half then
/// killed, so its free space lies before its data.</p>
ClassMethod Prepare() As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tDir = ..Directory()
        If $ListLength(..Tasks(1)) > 0 {
            Set tSC = $$$ERROR($$$GeneralError, "a background task still runs over the seed database, so it is not refilled")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(..#RESOURCE) {
            Set tSC = ##class(Security.Resources).Create(..#RESOURCE, "OcuPilot test: the background task seed (throwaway)", "", "")
            If $$$ISERR(tSC) {
                Set $NAMESPACE = tOrigNS
                Quit
            }
        }
        If '##class(%File).DirectoryExists(tDir) && '##class(%File).CreateDirectoryChain(tDir) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the seed directory could not be created")
            Quit
        }
        If '##class(SYS.Database).%ExistsId(tDir) {
            Set tSC = ##class(SYS.Database).CreateDatabase(tDir, 1, 8192, 0, ..#RESOURCE, 2)
            If $$$ISERR(tSC) {
                Set $NAMESPACE = tOrigNS
                Quit
            }
        }
        If '##class(Config.Databases).Exists(..#DATABASE) {
            Kill tProps
            Set tProps("Directory") = tDir
            Set tSC = ##class(Config.Databases).Create(..#DATABASE, .tProps)
            If $$$ISERR(tSC) {
                Set $NAMESPACE = tOrigNS
                Quit
            }
        }
        Set tGlobal = "^|""^^" _ tDir _ """|OcuPilotSeed"
        Kill @tGlobal
        Set tValue = $Justify("", 3900)
        For tI = 1:1:..#NODES {
            Set @tGlobal@(tI) = tValue
        }
        For tI = 1:1:(..#NODES \ 2) {
            Kill @tGlobal@(tI)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Prepare the scratch database and start the portal's compact of it, as the classic page starts
/// one, then pause it as soon as its background task exists, answering the job number in
/// <var>pJob</var> and the background task's id in <var>pTaskId</var>. An error status names a
/// step that failed, including a compact that ended before it could be paused.</p>
ClassMethod PausedCompact(Output pJob As %String, Output pTaskId As %String) As %Status
{
    Set pJob = ""
    Set pTaskId = ""
    Set tSC = ..Prepare()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tParms
        Set tParms("Directory") = ..Directory()
        Set tParms("Target") = ..#TARGETMB
        Set tParms("DBName") = ..#DATABASE
        Set tSC = ##class(%CSP.UI.System.BackgroundTask).RunTask(..#COMPACTTASK, "%SYS", .tParms, , .pJob)
        If $$$ISERR(tSC) || (+pJob = 0) {
            Set $NAMESPACE = tOrigNS
            If $$$ISOK(tSC) Set tSC = $$$ERROR($$$GeneralError, "the compact did not start")
            Quit
        }
        Set ^IRIS.Temp.OcuPilotBackgroundSeed("job", pJob) = ""
        For tI = 1:1:400 {
            Set pTaskId = $Get(^IRIS.Temp.MgtPortalTask(pJob, "SysBGTaskId"))
            If pTaskId '= "" Quit
            Hang 0.005
        }
        If pTaskId = "" {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the compact registered no background task")
            Quit
        }
        ; The id is recorded while the task is still Starting, and a pause is refused until it runs.
        For tI = 1:1:400 {
            Set tTask = ##class(%SYS.BackgroundTask).%OpenId(pTaskId)
            Set tState = $Select($IsObject(tTask): tTask.RunningState, 1: "")
            Set tTask = ""
            If tState '= "Starting" Quit
            Hang 0.005
        }
        Set tTask = ##class(%SYS.BackgroundTask).%OpenId(pTaskId)
        Set tPauseSC = $Select($IsObject(tTask): tTask.Pause(), 1: $$$ERROR($$$GeneralError, "the background task did not open"))
        Set tTask = ""
        Set tState = ..Settled(pTaskId, "Running")
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tPauseSC) {
            Set tSC = tPauseSC
            Quit
        }
        If tState '= "Paused" Set tSC = $$$ERROR($$$GeneralError, "the compact reads " _ tState _ ", not Paused")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The state background task <var>pTaskId</var> reads once it has left <var>pFrom</var>, read
/// every 10 ms for at most 30 s: a pause or resume the vendor accepted is carried out by the task at
/// its next checkpoint, which a slow host reaches later, so the state read at once can still be the
/// one it left.</p>
ClassMethod Settled(pTaskId As %String, pFrom As %String = "Running") As %String
{
    Set tState = ..State(pTaskId)
    For tI = 1:1:3000 {
        If tState '= pFrom Quit
        Hang 0.01
        Set tState = ..State(pTaskId)
    }
    Quit tState
}

/// <p>The state background task <var>pTaskId</var> reads now, opened afresh, or <code>""</code>.</p>
ClassMethod State(pTaskId As %String) As %String
{
    Quit ..Read(pTaskId, "RunningState")
}

/// <p>The request background task <var>pTaskId</var> records now -- 1 a pause, 2 a cancel, 0 none or
/// a resume -- opened afresh, or <code>""</code>.</p>
ClassMethod RequestOf(pTaskId As %String) As %String
{
    Quit ..Read(pTaskId, "Request")
}

/// <p>Property <var>pName</var> of background task <var>pTaskId</var>, opened afresh in
/// <code>%SYS</code>, or <code>""</code> when it does not open.</p>
ClassMethod Read(pTaskId As %String, pName As %String) As %String [ Private ]
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.BackgroundTask).%OpenId(pTaskId)
        If $IsObject(tTask) Set tValue = $Property(tTask, pName)
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Hold background task <var>pTaskId</var>'s lock in this process, so the task cannot record its
/// end: once its work is done its job waits in the vendor's <code>End()</code>, and the task reads
/// Running. That wait lasts the instance's lock timeout (<code>$zu(115,4)</code>, 10 s on this
/// build); past it <code>End()</code> gives up and the job exits unrecorded (inference), so a caller
/// finishes with the task within that time of its work ending. A pause, resume or cancel sent from
/// this process is not held up by the lock, because the lock is this process's own; one sent from
/// any other process waits for the lock and fails once the lock timeout passes (inference).
/// <method>Remove</method>, called in this process, cancels a held task before it releases it.</p>
ClassMethod Hold(pTaskId As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If $Data(^||OcuPilotBackgroundSeedHold(pTaskId)) Quit $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.BackgroundTask).%LockId(pTaskId, 0, 5)
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) Set ^||OcuPilotBackgroundSeedHold(pTaskId) = ""
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Release this process's <method>Hold</method> on background task <var>pTaskId</var>, if it
/// holds one.</p>
ClassMethod Release(pTaskId As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    If '$Data(^||OcuPilotBackgroundSeedHold(pTaskId)) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.BackgroundTask).%UnlockId(pTaskId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Kill ^||OcuPilotBackgroundSeedHold(pTaskId)
    Quit tSC
}

/// <p>Stop job <var>pJob</var> for <var>pSeconds</var>, then let it run again, as a host whose
/// writes stall stops a compact. A shell started through <code>$ZF(-100)</code> continues the job
/// after the wait, and the job is stopped only once that shell has started, so it always runs again.
/// A job number is its process id on this platform. Needs <code>%System_CallOut:USE</code>.</p>
ClassMethod Stall(pJob As %String, pSeconds As %Integer) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If '$Match(pJob, "^[1-9][0-9]{0,9}$") || '$Match(pSeconds, "^[1-9][0-9]{0,2}$") Quit $$$ERROR($$$GeneralError, "a stall takes a job number and a whole number of seconds")
    Try {
        Set tRC = $ZF(-100, "/ASYNC", "/bin/sh", "-c", "sleep " _ pSeconds _ "; kill -CONT " _ pJob)
        If tRC '= 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the shell that continues the job could not be started: " _ tRC)
            Quit
        }
        Set tRC = $ZF(-100, "", "/bin/kill", "-STOP", pJob)
        If tRC '= 0 Set tSC = $$$ERROR($$$GeneralError, "the job could not be stopped: kill answered " _ tRC)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The ids of the background tasks over the scratch database, as a <class>%List</class>: every
/// one, or only those not yet ended when <var>pRunning</var> is 1. The vendor's query answers the
/// directory in upper case, so it is compared without regard to case.</p>
ClassMethod Tasks(pRunning As %Boolean = 0) As %List
{
    Set tIds = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tDir = $ZConvert(..Directory(), "U")
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.BackgroundTask:DatabaseList")
        If $IsObject(tRS) && $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                If $ZConvert(tRS.Get("Database"), "U") '= tDir Continue
                If pRunning && tRS.Get("HasEnded") Continue
                Set tIds = tIds _ $ListBuild(tRS.Get("ID"))
            }
            Do tRS.Close()
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tIds
}

/// <p>Remove everything the seed made: every background task over the scratch database, canceled
/// first when it opens and has not ended and then released when this process holds it, then deleted
/// once the vendor records its end or <parameter>ENDSECONDS</parameter> have passed; the portal job
/// log entry of every job it started; and the database, its configuration, its directory and its
/// resource. A held task is canceled under the hold and only then released, because a held task
/// released first is stranded. A task whose row exists but does not open has not ended: once
/// released, a held job waiting to record its end takes the task's lock, and an open fails on it
/// until the job acts on the cancel. While a task over the database has not ended, the database is
/// left in place and that refusal is answered; otherwise the first failure is answered, after every
/// step has been tried.</p>
ClassMethod Remove() As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tFirst = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tDir = ..Directory()
        Set tIds = ..Tasks(0)
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tIds) {
            Set tId = $List(tIds, tI)
            Set tTask = ##class(%SYS.BackgroundTask).%OpenId(tId)
            If $IsObject(tTask) && 'tTask.HasEnded Do tTask.Cancel()
            Set tTask = ""
            Set tStepSC = ..Release(tId)
            If $$$ISERR(tStepSC) && $$$ISOK(tFirst) Set tFirst = tStepSC
            Set tDeadline = $ZHorolog + ..#ENDSECONDS
            For tJ = 1:1:(..#ENDSECONDS * 50) {
                Set tTask = ##class(%SYS.BackgroundTask).%OpenId(tId)
                Set tEnded = $Select($IsObject(tTask): tTask.HasEnded, 1: '##class(%SYS.BackgroundTask).%ExistsId(tId))
                Set tTask = ""
                If tEnded || ($ZHorolog > tDeadline) Quit
                Hang 0.02
            }
            Set tDeleteSC = ##class(%SYS.BackgroundTask).%DeleteId(tId)
            If $$$ISERR(tDeleteSC) && $$$ISOK(tFirst) Set tFirst = tDeleteSC
        }
        Set tId = ""
        For {
            Set tId = $Order(^||OcuPilotBackgroundSeedHold(tId))
            If tId = "" Quit
            Set tStepSC = ..Release(tId)
            If $$$ISERR(tStepSC) && $$$ISOK(tFirst) Set tFirst = tStepSC
        }
        Set tJob = ""
        For {
            Set tJob = $Order(^IRIS.Temp.OcuPilotBackgroundSeed("job", tJob))
            If tJob = "" Quit
            Kill ^IRIS.Temp.MgtPortalTask(tJob)
        }
        Kill ^IRIS.Temp.OcuPilotBackgroundSeed
        Set $NAMESPACE = tOrigNS
        If $ListLength(..Tasks(1)) > 0 {
            Set tFirst = $$$ERROR($$$GeneralError, "a background task still runs over the seed database, so the database is left in place")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        If ##class(SYS.Database).%ExistsId(tDir) {
            Do ##class(SYS.Database).DismountDatabase(tDir)
        }
        If ##class(Config.Databases).Exists(..#DATABASE) {
            Set tStepSC = ##class(Config.Databases).Delete(..#DATABASE)
            If $$$ISERR(tStepSC) && $$$ISOK(tFirst) Set tFirst = tStepSC
        }
        If ##class(SYS.Database).%ExistsId(tDir) {
            Set tStepSC = ##class(SYS.Database).DeleteDatabase(tDir)
            If $$$ISERR(tStepSC) && $$$ISOK(tFirst) Set tFirst = tStepSC
        }
        If ##class(%File).DirectoryExists(tDir) && '##class(%File).RemoveDirectoryTree(tDir) && $$$ISOK(tFirst) Set tFirst = $$$ERROR($$$GeneralError, "the seed directory could not be removed")
        If ##class(Security.Resources).Exists(..#RESOURCE) {
            Set tStepSC = ##class(Security.Resources).Delete(..#RESOURCE)
            If $$$ISERR(tStepSC) && $$$ISOK(tFirst) Set tFirst = tStepSC
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tFirst) Set tFirst = ex.AsStatus()
    }
    Quit tFirst
}

}
