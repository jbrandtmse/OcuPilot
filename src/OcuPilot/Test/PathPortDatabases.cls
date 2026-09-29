/// <p>Pins <class>OcuPilot.Port.PathPort</class>'s database-directory read against a configuration that
/// moves (Story 18.3, AD-21's sixth case, DW-1795, DW-1796): a file in a database's additional volume
/// directory is the instance's own, a configured stream location and a configuration's removal are
/// followed between two resolutions in one process, a failed volume read refuses, and a directory in
/// the mirror or data-server form is never listed. Every resolution is an overwrite through the real
/// reader, never a seam naming the directories.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the manager directory among the
/// allowed directories, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// class creates and deletes probe databases, a volume file and probe files in their directories
/// (<class>OcuPilot.Test.DatabaseWriteProbe</class>). <method>OnBeforeAllTests</method> refuses anywhere
/// it does not; every probe object is removed by exact name before all, after each and after all.</p>
Class OcuPilot.Test.PathPortDatabases Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseWriteProbe";

Parameter PORT = "OcuPilot.Port.PathPort";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortDatabases creates and deletes databases and files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe database object is removed by exact name")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>DW-1795: a probe database's new volume directory holds its volume file and
/// <code>iris.dbdir</code>, each refused <code>PATH.INSTANCE</code> to an overwrite, while a file in a
/// subdirectory of it resolves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.DatabaseDirectories</method> skips
/// <method>OcuPilot.Port.PathPort.VolumeDirectories</method> -> the volume file resolves and this goes
/// red.</p>
Method TestAVolumeDirectorysFilesAreTheInstances()
{
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "pv")
    Set tVolume = $ClassMethod(..#PROBE, "DirectoryFor", "pv-vol")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183PV"), "a probe database is created")
    Do $$$AssertStatusOK(..NewVolume(tDirectory, tVolume), "its new volume directory is set and a volume file made there")
    Do $$$AssertTrue(##class(%File).Exists(tVolume _ "IRIS-0001.VOL") && ##class(%File).Exists(tVolume _ "iris.dbdir"), "the volume directory holds the volume file and iris.dbdir")
    Do $$$AssertStatusOK(..WriteProbe(tVolume _ "sub/probe.txt"), "and a file in a subdirectory of it")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tName = "IRIS-0001.VOL", "iris.dbdir" {
        Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pv-vol/" _ tName), ##class(OcuPilot.Api.Error).#PATHINSTANCE, tName _ " is refused as the instance's own")
    }
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pv-vol/sub/probe.txt"), "", "a file in a subdirectory of the volume directory resolves")
}

/// <p>DW-1796 (i): a file in a probe database's configured stream location is refused while one in
/// its directory's <code>stream/</code> resolves, and once the location is cleared in the same process
/// the two answers swap.</p>
/// <p>Mutation (Rule 19): the reader ignores a configured stream location -> the first answers are
/// swapped and this goes red.</p>
Method TestAConfiguredStreamLocationIsFollowed()
{
    Set tName = "OCUPROBE183PS"
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "ps")
    Set tStreams = $ClassMethod(..#PROBE, "DirectoryFor", "ps-streams")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Do $$$AssertStatusOK(..WriteProbe(tStreams _ "probe.txt"), "a file in its stream location to be")
    Do $$$AssertStatusOK(..WriteProbe(tDirectory _ "stream/probe.txt"), "and one in its directory's stream/")
    Do $$$AssertStatusOK(..StreamLocation(tName, tDirectory, tStreams), "its stream location is set")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183ps-streams/probe.txt"), ##class(OcuPilot.Api.Error).#PATHINSTANCE, "a file in the configured stream location is refused")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183ps/stream/probe.txt"), "", "one in the directory's stream/ resolves")
    Do $$$AssertStatusOK(..StreamLocation(tName, tDirectory, ""), "the stream location is cleared")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183ps-streams/probe.txt"), "", "in the same process the first now resolves")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183ps/stream/probe.txt"), ##class(OcuPilot.Api.Error).#PATHINSTANCE, "and the second is refused")
}

/// <p>DW-1796 (iii): a file directly in a probe database's directory is refused, and once its
/// configuration is deleted with the file kept, the same resolution in the same process resolves --
/// the reader keeps nothing between calls.</p>
/// <p>Mutation (Rule 19): the reader keeps its answer in a process-private global -> the second
/// resolution is still refused and this goes red.</p>
Method TestTheReaderKeepsNothing()
{
    Set tName = "OCUPROBE183PK"
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "pk")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Do $$$AssertStatusOK(..WriteProbe(tDirectory _ "probe.txt"), "with a file directly in its directory")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pk/probe.txt"), ##class(OcuPilot.Api.Error).#PATHINSTANCE, "the file is refused while the database is configured")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName, 0), "its configuration is deleted, the file kept")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pk/probe.txt"), "", "and in the same process the same file resolves")
}

/// <p>DW-1796 (iii): with a failing volume read (<method>OcuPilot.Test.PathPortFixture.FailVolumeDirectories</method>),
/// an unrelated existing file is refused, since the reader fails closed; without it the file
/// resolves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.DatabaseDirectories</method> drops a volume
/// read's error -> the file resolves under the failing read and this goes red.</p>
Method TestAFailedVolumeReadRefuses()
{
    Set tFile = $ClassMethod(..#PROBE, "DirectoryFor", "pq") _ "sub/probe.txt"
    Do $$$AssertStatusOK(..WriteProbe(tFile), "an unrelated file exists")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pq/sub/probe.txt", ..#FIXTURE), "", "it resolves while the volume read answers")
    Do $ClassMethod(..#FIXTURE, "FailVolumeDirectories")
    Do $$$AssertEquals(..Resolved(tRoot, "ocuprobe183pq/sub/probe.txt", ..#FIXTURE), ##class(OcuPilot.Api.Error).#PATHINSTANCE, "and is refused when that read fails")
}

/// <p>DW-1795: a configuration whose directory holds no <code>IRIS.DAT</code> has no volume directories
/// to read, so it refuses nothing: with such a probe configuration present, an unrelated file under
/// the manager directory still resolves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.VolumeDirectories</method> drops its answer for
/// a directory with no <code>IRIS.DAT</code> -> the volume read fails, the reader fails closed and this
/// goes red.</p>
Method TestAConfigurationWithNoFileRefusesNothing()
{
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "pc")
    Do $$$AssertTrue(##class(%File).CreateDirectoryChain(tDirectory), "a probe directory exists")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddConfiguration", "OCUPROBE183PC", tDirectory), "and a configuration names it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", tDirectory), 0, "with no database file there")
    Do $$$AssertStatusOK(..WriteProbe($ClassMethod(..#PROBE, "DirectoryFor", "pq") _ "sub/probe.txt"), "an unrelated file exists")
    Do $$$AssertEquals(..Resolved($ClassMethod(..#PROBE, "Manager"), "ocuprobe183pq/sub/probe.txt"), "", "and resolves")
}

/// <p>DW-1796 (ii): a directory in the mirror or data-server form, and an empty one, name no local
/// path, and a real directory does. The instance cannot be configured with such a directory
/// (measured: <code>Config.Databases.Create</code> stores it under the manager directory), so the
/// predicate the reader admits rows by is pinned here.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.LocalDirectory</method> answers 1 for a
/// leading <code>:</code> -> this goes red.</p>
Method TestAColonDirectoryIsNeverListed()
{
    For tDirectory = ":mirror:M:DB", ":ds:X", "" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "LocalDirectory", tDirectory), 0, "'" _ tDirectory _ "' names no local path")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "LocalDirectory", $ClassMethod(..#PROBE, "Manager")), 1, "a real directory does")
}

/// <p>The code a file overwrite of <var>pPath</var> under <var>pRoot</var> is refused with through
/// <var>pPort</var>'s <code>Resolve</code>, or <code>""</code> when it resolves.</p>
ClassMethod Resolved(pRoot As %String, pPath As %String, pPort As %String = {..#PORT}) As %String
{
    Set tSC = $ClassMethod(pPort, "Resolve", pRoot, pPath, "file", "root", "path", .tResolved, .tHttp, .tFault, 1, 0)
    If $$$ISOK(tSC) Quit ""
    Quit $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: $System.Status.GetErrorText(tSC))
}

/// <p>Write one line to <var>pFile</var>, creating its directory first; a file outside a probe
/// directory is refused.</p>
ClassMethod WriteProbe(pFile As %String) As %Status
{
    If '$ClassMethod(..#PROBE, "IsProbeDirectory", ##class(%File).GetDirectory(pFile)) Quit $$$ERROR($$$GeneralError, "a probe file lives in a probe directory")
    If '##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(pFile)) Quit $$$ERROR($$$GeneralError, "the probe file's directory could not be made")
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pFile)
    If $$$ISOK(tSC) Set tSC = tStream.WriteLine("OcuPilot probe (throwaway)")
    If $$$ISOK(tSC) Set tSC = tStream.%Save()
    Set tStream = ""
    Quit tSC
}

/// <p>Set the probe database in <var>pDirectory</var>'s new volume directory to <var>pVolume</var>
/// through the port's file <code>PUT</code>, then make its first volume file there through
/// <code>SYS.Database.NewVolume</code> in <code>%SYS</code> (test-only).</p>
ClassMethod NewVolume(pDirectory As %String, pVolume As %String) As %Status
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tBody = {}
    Do tBody.%Set("NewVolumeDirectory", pVolume, "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.Database).NewVolume(pDirectory, pVolume, 1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set configuration <var>pName</var>'s stream location to <var>pStreams</var> (empty for its
/// default) through the port's configuration <code>PUT</code>, keeping its directory.</p>
ClassMethod StreamLocation(pName As %String, pDirectory As %String, pStreams As %String) As %Status
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = {}
    Do tBody.%Set("Directory", pDirectory, "string")
    Do tBody.%Set("StreamLocation", pStreams, "string")
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Database.ConfigCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
}

}
