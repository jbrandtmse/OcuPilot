/// <p>AD-21's sixth case at <class>OcuPilot.Port.PathPort</class>, the instance's database and
/// journal files: to a caller that overwrites, every existing file directly in a configured
/// database's directory or under its stream location, and every existing file directly in a journal
/// directory, is refused 400 <code>PATH.INSTANCE</code> on the name's field, the directories read
/// from the instance at each call and compared ignoring case, and a failed read refusing; an
/// ordinary file in a subdirectory still resolves. It also pins the port's two reads against the
/// instance's own answers. <class>OcuPilot.Test.PathPortServed</class> pins OcuPilot's own served
/// directory.</p>
/// <p>Each method records the allow-list before it runs and restores it exactly afterwards, failure
/// included, through <class>OcuPilot.Test.PathPortFixture</class>, which is why
/// <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms it.
/// The refusal legs only resolve names and write nothing to the instance's own files. The
/// permitting leg creates a scratch directory under the manager directory, and the seam legs one
/// under <parameter>TMPROOT</parameter>; each removes what it created. The former-directory leg
/// switches journaling to a probe alternate and back (<class>OcuPilot.Test.JournalProbe</class>) and
/// restores the journal settings it found; the journal files it creates are kept, which is why
/// <parameter>JOURNALVARIABLE</parameter> arms it too. Needs a process holding <code>%All</code>,
/// journaling on, and a configured database outside the manager directory.</p>
Class OcuPilot.Test.PathPortInstance Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the former-directory leg's journal switches.</p>
Parameter JOURNALVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Port.PathPort";

/// <p>Its seam subclass, and the allow-list helpers.</p>
Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

/// <p>The class whose resolution and refusal helpers this one shares.</p>
Parameter HELPERS = "OcuPilot.Test.PathPort";

/// <p>A directory every Linux instance has.</p>
Parameter TMPROOT = "/tmp/";

/// <p>Whether the purpose existed before the method ran. Prefix deliberately not "Test".</p>
Property SavedExists As %Boolean [ InitialExpression = 0 ];

/// <p>Whether it was restricted.</p>
Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

/// <p>Its root paths, in the vendor's order.</p>
Property SavedPaths As %List;

/// <p>Whether <method>OnBeforeOneTest</method> recorded the allow-list, so a restore has
/// something to put back.</p>
Property SavedOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Set ..SavedOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortInstance changes this instance's %GUIFileSelector allow-list and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#JOURNALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortInstance switches this instance's journal directory and runs on a throwaway container only. " _ ..#JOURNALVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Reset")
    If '..SavedOk Quit $$$OK
    Set ..SavedOk = 0
    Quit $ClassMethod(..#FIXTURE, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
}

/// <p>One resolution by a caller that overwrites, as <code>&lt;status&gt;|&lt;resolved path or
/// fault as JSON&gt;</code>, through <var>pPort</var>.</p>
ClassMethod Overwrite(pRoot As %String, pPath As %String, pPort As %String = {..#PORT}) As %String
{
    Quit $ClassMethod(..#HELPERS, "ResolveOf", pRoot, pPath, "file", "root", "path", pPort, 1)
}

/// <p>The configured local databases, read here in <code>%SYS</code> rather than through the port:
/// their names, their directories normalized, each followed by the additional volume directories its
/// <code>SYS.Database</code> lists when its file exists, and each one's stream location as the vendor's
/// own <code>Config.Databases.GetStreamLocation</code> answers it, normalized. A row whose directory
/// is empty or in the mirror or data-server form, beginning with <code>:</code>, names no local path
/// and is skipped.</p>
ClassMethod LocalDatabases(Output pNames As %List, Output pDirectories As %List, Output pStreams As %List) As %Status
{
    Set tSC = $$$OK
    Set pNames = ""
    Set pDirectories = ""
    Set pStreams = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        Set tSC = tRS.Execute("*", "", 1)
        While $$$ISOK(tSC) && tRS.Next(.tSC) {
            If (tRS.Get("Directory") = "") || ($Extract(tRS.Get("Directory")) = ":") Continue
            Set tDirectory = ##class(%File).NormalizeDirectory(tRS.Get("Directory"))
            Set pNames = pNames _ $ListBuild(tRS.Get("Name"))
            Set pDirectories = pDirectories _ $ListBuild(tDirectory)
            If ##class(%File).Exists(tDirectory _ "IRIS.DAT") {
                Set tVolumes = ##class(SYS.Database).%OpenId(tDirectory).VolumeDirectoryList
                For tI = 1:1:$ListLength(tVolumes) {
                    If $ListGet(tVolumes, tI) '= "" Set pDirectories = pDirectories _ $ListBuild(##class(%File).NormalizeDirectory($ListGet(tVolumes, tI)))
                }
            }
            Set pStreams = pStreams _ $ListBuild(##class(%File).NormalizeDirectory(##class(Config.Databases).GetStreamLocation(tRS.Get("Name"))))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The instance's primary and alternate journal directories, read here from
/// <class>%SYS.Journal.System</class> rather than through the port, normalized and named once.</p>
ClassMethod Journals() As %List
{
    Set tJournals = ""
    For tDirectory = ##class(%SYS.Journal.System).GetPrimaryDirectory(), ##class(%SYS.Journal.System).GetAlternateDirectory() {
        If tDirectory = "" Continue
        Set tDirectory = ##class(%File).NormalizeDirectory(tDirectory)
        If '$ListFind(tJournals, tDirectory) Set tJournals = tJournals _ $ListBuild(tDirectory)
    }
    Quit tJournals
}

/// <p>Write one character to <var>pFile</var>, creating its directory first.</p>
ClassMethod WriteFile(pFile As %String) As %Status
{
    If '##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(pFile)) Quit $$$ERROR($$$GeneralError, "the scratch directory could not be created")
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pFile)
    If $$$ISERR(tSC) Quit tSC
    Do tStream.Write("x")
    Quit tStream.%Save()
}

/// <p>Every existing file directly in each configured database's directory, the manager directory's
/// own aside (<code>PATH.MANAGER</code> refuses those), is refused <code>PATH.INSTANCE</code> to a
/// caller that overwrites, reached from that directory as the root: the database file, its lock
/// file and whatever else stands there. A database outside the manager directory's is refused as
/// well from the directory above it; a caller that does not overwrite is refused as a taken name,
/// and a new name there resolves. Resolves names only.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.PathPort.InDatabaseDirectory</method> from
/// <method>OcuPilot.Port.PathPort.InstanceFile</method> -&gt; the lock-file legs, and every leg
/// outside the manager directory, resolve.</p>
Method TestAnOverwriteNeverReachesADatabasesFiles()
{
    Set tManager = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
    Do $$$AssertStatusOK(..LocalDatabases(.tNames, .tAll, .tStreams), "the configured local databases are read")
    Set tDatabases = ""
    Set tOutside = ""
    For tI = 1:1:$ListLength(tAll) {
        Set tDirectory = $List(tAll, tI)
        If tDirectory = tManager Continue
        Set tDatabases = tDatabases _ $ListBuild(tDirectory)
        If (tOutside = "") && '##class(OcuPilot.Port.PathPort).Contains(tManager, tDirectory) Set tOutside = tDirectory
    }
    Do $$$AssertTrue($ListLength(tDatabases) > 0, "databases stand beside the manager directory's own: " _ $ListToString(tDatabases, " "))
    Do $$$AssertTrue(tOutside '= "", "and one stands outside the manager directory")
    Set tAbove = $Select(tOutside '= "": ##class(%File).ParentDirectoryName(tOutside), 1: "")
    Set tRoots = tDatabases
    If (tAbove '= "") && '$ListFind(tRoots, tAbove) Set tRoots = tRoots _ $ListBuild(tAbove)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, tRoots), "the purpose is restricted to the databases' directories and the one above the outside one")

    Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
    Set tLocks = 0
    For tI = 1:1:$ListLength(tDatabases) {
        Set tDirectory = $List(tDatabases, tI)
        Set tFiles = $ClassMethod(..#HELPERS, "NamesIn", tDirectory, 0)
        Do $$$AssertTrue($ListFind(tFiles, ##class(OcuPilot.Port.PathPort).#DATABASEFILE) > 0, tDirectory _ " holds its database file: " _ $ListToString(tFiles, " "))
        For tJ = 1:1:$ListLength(tFiles) {
            Set tFile = $List(tFiles, tJ)
            If tFile = "iris.lck" Set tLocks = tLocks + 1
            Do $$$AssertEquals(..Overwrite(tDirectory, tFile), tRefused, "'" _ tDirectory _ tFile _ "' is refused to a caller that overwrites")
        }
    }
    Do $$$AssertTrue(tLocks > 0, "lock files were among them: " _ tLocks)

    If tOutside '= "" {
        Set tName = $Piece(tOutside, "/", *-1) _ "/" _ ##class(OcuPilot.Port.PathPort).#DATABASEFILE
        Do $$$AssertEquals(..Overwrite(tAbove, tName), tRefused, "the outside database's file is refused from the directory above it too")
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "ResolveOf", tOutside, ##class(OcuPilot.Port.PathPort).#DATABASEFILE, "file"), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHEXISTS, "path"), "and to a caller that does not overwrite, as a taken name")
        Do $$$AssertEquals(..Overwrite(tOutside, "ocupilot-pathport-none.dat"), "200|" _ tOutside _ "ocupilot-pathport-none.dat", "a new name there resolves")
    }
}

/// <p>A file anywhere under a database's stream location is the database's, a file directly in its
/// directory is too, and a file in any other subdirectory of that directory is not; the
/// databases are the port's read at each call, so naming none frees the same file, and a failed
/// read refuses every overwrite. Works through the fixture's database seam over a scratch directory
/// under <parameter>TMPROOT</parameter> that it creates and removes.</p>
/// <p>Mutation (Rule 19): drop the stream-location test from
/// <method>OcuPilot.Port.PathPort.InDatabaseDirectory</method> -&gt; the stream legs resolve; test
/// only a file directly in the stream location -&gt; the deeper stream leg resolves; answer
/// false on a failed read -&gt; the failed-read leg resolves; keep the first read's directories in a
/// process-private global and answer from it -&gt; the freed file stays refused; test containment
/// under a database's directory -&gt; the ordinary subdirectory file is refused.</p>
Method TestAStreamFileIsTheDatabasesAndTheReadIsNeverKept()
{
    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-db-" _ $Job _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        For tFile = "held.dat", "stream/s.stream", "stream/deep/s.stream", "sub/t.xml" {
            Do $$$AssertStatusOK(..WriteFile(tScratch _ tFile), "a scratch file " _ tFile)
        }
        Set tRelative = $Piece(tScratch, "/", *-1)
        Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")

        Do $ClassMethod(tPort, "UseDatabaseDirectories", $ListBuild(tScratch), $ListBuild(tScratch _ "stream/"))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), tRefused, "a file directly in a database's directory is the database's")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/stream/s.stream", tPort), tRefused, "and so is a file under its stream location")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/stream/deep/s.stream", tPort), tRefused, "and one deeper under it")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/sub/t.xml", tPort), "200|" _ tScratch _ "sub/t.xml", "but a file in another subdirectory of it is not")

        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), "200|" _ tScratch _ "held.dat", "once no database names that directory, the same file resolves")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/stream/s.stream", tPort), "200|" _ tScratch _ "stream/s.stream", "and so does the stream file")

        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "", 1)
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/sub/t.xml", tPort), tRefused, "while the databases cannot be read, every overwrite is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the stream legs ran to the end")
    }
    For tFile = "held.dat", "stream/s.stream", "stream/deep/s.stream", "sub/t.xml" {
        Do ##class(%File).Delete(tScratch _ tFile)
    }
    Do ##class(%File).RemoveDirectory(tScratch _ "stream/deep/")
    Do ##class(%File).RemoveDirectory(tScratch _ "stream/")
    Do ##class(%File).RemoveDirectory(tScratch _ "sub/")
    Do ##class(%File).RemoveDirectory(tScratch)
    Do $$$AssertTrue('##class(%File).Exists(tScratch), "the scratch directory is removed")
}

/// <p>Every existing file directly in each of the instance's journal directories -- its journal
/// files and its lock file -- is refused <code>PATH.INSTANCE</code> to a caller that overwrites,
/// from the journal directory as the root and, where it lies under the manager directory, from that
/// directory as the unrestricted root; a caller that does not overwrite is refused as a taken name,
/// and a new name there resolves. Through the fixture's journal seam over a scratch directory under
/// <parameter>TMPROOT</parameter>, which it creates and removes, a file directly in a directory the
/// read names is refused while one in a subdirectory of it resolves, the same file resolves once
/// the read names none, and a failed read refuses.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.PathPort.InJournalDirectory</method> from
/// <method>OcuPilot.Port.PathPort.InstanceFile</method> -&gt; each refused leg resolves; answer
/// false on a failed read -&gt; the failed-read leg resolves; test containment under a journal
/// directory -&gt; the subdirectory leg is refused.</p>
Method TestAnOverwriteNeverReachesAJournalFile()
{
    Set tManager = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
    Set tJournals = ..Journals()
    Do $$$AssertTrue($ListLength(tJournals) > 0, "the instance names its journal directories")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, tJournals), "the purpose is restricted to them")
    Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
    Set tUnder = ""
    For tI = 1:1:$ListLength(tJournals) {
        Set tDirectory = $List(tJournals, tI)
        Set tFiles = $ClassMethod(..#HELPERS, "NamesIn", tDirectory, 0)
        Do $$$AssertTrue($ListLength(tFiles) > 0, tDirectory _ " holds journal files: " _ $ListToString(tFiles, " "))
        For tJ = 1:1:$ListLength(tFiles) {
            Set tGot = ..Overwrite(tDirectory, $List(tFiles, tJ))
            ; A journal file closed moments ago is compressed under a new name (CompressFiles), so a
            ; name that no longer exists by the time it resolves names no instance file.
            If (tGot '= tRefused) && '##class(%File).Exists(tDirectory _ $List(tFiles, tJ)) Continue
            Do $$$AssertEquals(tGot, tRefused, "'" _ tDirectory _ $List(tFiles, tJ) _ "' is refused to a caller that overwrites")
        }
        If $ListLength(tFiles) {
            Do $$$AssertEquals($ClassMethod(..#HELPERS, "ResolveOf", tDirectory, $List(tFiles, 1), "file"), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHEXISTS, "path"), "and to a caller that does not overwrite, as a taken name")
            If (tUnder = "") && ##class(OcuPilot.Port.PathPort).Contains(tManager, tDirectory) Set tUnder = $Extract(tDirectory, $Length(tManager) + 1, *) _ $List(tFiles, 1)
        }
        Do $$$AssertEquals(..Overwrite(tDirectory, "ocupilot-pathport-none.001"), "200|" _ tDirectory _ "ocupilot-pathport-none.001", "a new name in " _ tDirectory _ " resolves")
    }
    If tUnder '= "" {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
        Do $$$AssertEquals(..Overwrite(tManager, tUnder), tRefused, "a journal file is refused from the manager directory too")
    }

    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-jrn-" _ $Job _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertStatusOK(..WriteFile(tScratch _ "20260101.001"), "a scratch journal-like file")
        Do $$$AssertStatusOK(..WriteFile(tScratch _ "sub/20260101.002"), "and one in a subdirectory")
        Set tName = $Piece(tScratch, "/", *-1) _ "/20260101.001"
        Do $ClassMethod(tPort, "UseJournalDirectories", $ListBuild(tScratch))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "a file directly in a directory the journal read names is refused")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, $Piece(tScratch, "/", *-1) _ "/sub/20260101.002", tPort), "200|" _ tScratch _ "sub/20260101.002", "but one in a subdirectory of it resolves")
        Do $ClassMethod(tPort, "UseJournalDirectories", "")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), "200|" _ tScratch _ "20260101.001", "and resolves once the read names none")
        Do $ClassMethod(tPort, "UseJournalDirectories", "", 1)
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "while the journal directories cannot be read, it is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the journal seam legs ran to the end")
    }
    Do ##class(%File).Delete(tScratch _ "20260101.001")
    Do ##class(%File).Delete(tScratch _ "sub/20260101.002")
    Do ##class(%File).RemoveDirectory(tScratch _ "sub/")
    Do ##class(%File).RemoveDirectory(tScratch)
    Do $$$AssertTrue('##class(%File).Exists(tScratch), "the scratch directory is removed")
}

/// <p>Each of the three journal sources is a journal directory in its own right: with the
/// fixture's journal-source seam naming three distinct scratch directories under
/// <parameter>TMPROOT</parameter>, the port's journal read names all three, in order, and an existing
/// file in the alternate alone is refused <code>PATH.INSTANCE</code> to a caller that overwrites;
/// three sources naming one directory name it once; a source read that fails fails the journal
/// read, which names nothing and so refuses the overwrite. Creates and removes its scratch
/// directory.</p>
/// <p>Mutation (Rule 19): drop any one source from
/// <method>OcuPilot.Port.PathPort.JournalDirectories</method> -&gt; the list lacks it (and, for the
/// alternate, its file resolves); stop naming a directory once -&gt; the repeated one is listed
/// three times; ignore <method>OcuPilot.Port.PathPort.JournalSources</method>' status -&gt; the
/// failed-source legs read OK and resolve.</p>
Method TestEveryJournalSourceIsAJournalDirectory()
{
    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-jsrc-" _ $Job _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertStatusOK(..WriteFile(tScratch _ "alternate/20260101.001"), "a scratch journal-like file in the alternate")
        ; The journal history and the write-image journal name none here, so the three sources are
        ; the whole list (TestTheWriteImageJournalsDirectoryIsRefused pins those two).
        Do $ClassMethod(tPort, "UseJournalHistory", "")
        Do $ClassMethod(tPort, "UseWijDirectory", "")
        Do $ClassMethod(tPort, "UseJournalSources", tScratch _ "primary", tScratch _ "alternate", tScratch _ "current/20260101.002")
        Do $$$AssertStatusOK($ClassMethod(tPort, "JournalDirectories", .tDirectories), "the port reads the three sources")
        Do $$$AssertEquals($ListToString(tDirectories, " "), tScratch _ "primary/ " _ tScratch _ "alternate/ " _ tScratch _ "current/", "the primary, the alternate and the current file's directory, in that order")
        Set tName = $Piece(tScratch, "/", *-1) _ "/alternate/20260101.001"
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path"), "a file in the alternate journal directory alone is refused")

        Do $ClassMethod(tPort, "UseJournalSources", tScratch _ "primary", tScratch _ "primary/", tScratch _ "primary/20260101.003")
        Do $$$AssertStatusOK($ClassMethod(tPort, "JournalDirectories", .tDirectories), "the port reads one directory three times")
        Do $$$AssertEquals($ListToString(tDirectories, " "), tScratch _ "primary/", "and names it once")

        Do $ClassMethod(tPort, "UseJournalSources", tScratch _ "primary", tScratch _ "other", tScratch _ "current/20260101.002", 1)
        Do $$$AssertStatusNotOK($ClassMethod(tPort, "JournalDirectories", .tDirectories), "a source read that fails fails the journal read")
        Do $$$AssertEquals($ListLength(tDirectories), 0, "which names no directory")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path"), "so the overwrite is refused, though no source named that directory")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the journal-source legs ran to the end")
    }
    Do ##class(%File).Delete(tScratch _ "alternate/20260101.001")
    Do ##class(%File).RemoveDirectory(tScratch _ "alternate/")
    Do ##class(%File).RemoveDirectory(tScratch)
    Do $$$AssertTrue('##class(%File).Exists(tScratch), "the scratch directory is removed")
}

/// <p>The instance's directories are compared ignoring case, so on a filesystem that ignores case
/// another spelling of an instance file is refused too: with the fixture's seams naming a scratch
/// directory under <parameter>TMPROOT</parameter> in upper case, as a database's directory and
/// stream location, as a journal directory and as the configuration file's directory, an existing
/// file in it is refused <code>PATH.INSTANCE</code> to a caller that overwrites, and resolves while
/// none names it. Creates and removes its scratch directory.</p>
/// <p>Mutation (Rule 19): compare with case in
/// <method>OcuPilot.Port.PathPort.InDatabaseDirectory</method>'s directory test or its stream test,
/// in <method>OcuPilot.Port.PathPort.InJournalDirectory</method>, or in
/// <method>OcuPilot.Port.PathPort.DirectlyInConfigurationDirectory</method> -&gt; that leg
/// resolves.</p>
Method TestAnInstanceDirectoryIsMatchedIgnoringCase()
{
    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-case-" _ $Job _ "/"
    Set tOther = $ZConvert(tScratch, "U")
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        For tFile = "held.dat", "stream/s.stream" {
            Do $$$AssertStatusOK(..WriteFile(tScratch _ tFile), "a scratch file " _ tFile)
        }
        Set tRelative = $Piece(tScratch, "/", *-1)
        Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "")
        Do $ClassMethod(tPort, "UseJournalDirectories", "")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), "200|" _ tScratch _ "held.dat", "while nothing names the directory, the file resolves")

        Do $ClassMethod(tPort, "UseDatabaseDirectories", $ListBuild(tOther), $ListBuild(tOther _ "STREAM/"))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), tRefused, "a file in a database's directory spelled in other case is the database's")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/stream/s.stream", tPort), tRefused, "and so is one under its stream location spelled so")

        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "")
        Do $ClassMethod(tPort, "UseJournalDirectories", $ListBuild(tOther))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), tRefused, "a file in a journal directory spelled in other case is refused")

        Do $ClassMethod(tPort, "UseJournalDirectories", "")
        Do $ClassMethod(tPort, "UseConfigurationFile", tOther _ "IRIS.CPF")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tRelative _ "/held.dat", tPort), tRefused, "and so is a file beside a configuration file spelled in other case")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the case legs ran to the end")
    }
    For tFile = "held.dat", "stream/s.stream" {
        Do ##class(%File).Delete(tScratch _ tFile)
    }
    Do ##class(%File).RemoveDirectory(tScratch _ "stream/")
    Do ##class(%File).RemoveDirectory(tScratch)
    Do $$$AssertTrue('##class(%File).Exists(tScratch), "the scratch directory is removed")
}

/// <p>An ordinary file in a subdirectory of the manager directory -- itself the directory of a
/// configured database -- still resolves to a caller that overwrites, and is refused only as a
/// taken name to one that does not. Works in a scratch directory under the manager directory that
/// it creates and removes.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.PathPort.InDatabaseDirectory</method> test
/// containment under each database's directory, or take a database's default stream location as
/// its directory -&gt; the ordinary file is refused <code>PATH.INSTANCE</code>.</p>
Method TestAnOrdinarySubdirectoryFileStillResolves()
{
    Set tManager = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
    Do $$$AssertStatusOK(..LocalDatabases(.tNames, .tAll, .tStreams), "the configured local databases are read")
    Do $$$AssertTrue($ListFind(tAll, tManager) > 0, "the manager directory is a configured database's own directory")
    Set tRelative = "ocupilot-pathport-ordinary-" _ $Job
    Set tFile = tManager _ tRelative _ "/t.xml"
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
        Do $$$AssertStatusOK(..WriteFile(tFile), "an ordinary file in a subdirectory of it")
        Do $$$AssertEquals(..Overwrite(tManager, tRelative _ "/t.xml"), "200|" _ tFile, "resolves to a caller that overwrites")
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "ResolveOf", tManager, tRelative _ "/t.xml", "file"), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHEXISTS, "path"), "and is refused only as a taken name to one that does not")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the ordinary legs ran to the end")
    }
    Do ##class(%File).Delete(tFile)
    Do ##class(%File).RemoveDirectory(tManager _ tRelative)
    Do $$$AssertTrue('##class(%File).Exists(tManager _ tRelative), "the scratch directory is removed")
}

/// <p>The database file one directory below the manager directory stays refused with no database
/// read at all: with the fixture's database and journal reads naming nothing, an existing
/// <code>&lt;name&gt;/IRIS.DAT</code> there is still refused <code>PATH.INSTANCE</code> to a caller
/// that overwrites. Resolves names only.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.DatabaseFileBelowManagerDirectory</method>
/// answers false -&gt; it resolves.</p>
Method TestADatabaseFileBelowTheManagerDirectoryNeedsNoDatabaseRead()
{
    Set tManager = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
    Set tNames = $ClassMethod(..#HELPERS, "NamesIn", tManager, 1)
    Do $$$AssertTrue($ListLength(tNames) > 0, "database files stand one directory below the manager directory: " _ $ListToString(tNames, " "))
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
    Do $ClassMethod(..#FIXTURE, "UseDatabaseDirectories", "", "")
    Do $ClassMethod(..#FIXTURE, "UseJournalDirectories", "")
    If $ListLength(tNames) Do $$$AssertEquals(..Overwrite(tManager, $List(tNames, 1), ..#FIXTURE), $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path"), "'" _ $List(tNames, 1) _ "' is refused with no database read")
}

/// <p>The port's two reads answer what the instance does:
/// <method>OcuPilot.Port.PathPort.DatabaseDirectories</method> names exactly the configured local
/// databases' directories, in the vendor's order, each with the stream location the vendor's own
/// <code>GetStreamLocation</code> answers; and
/// <method>OcuPilot.Port.PathPort.JournalDirectories</method> names the primary and alternate
/// journal directories and the directory of the current journal file, each source read
/// by <method>OcuPilot.Port.PathPort.JournalSources</method> as the instance answers it.</p>
/// <p>Mutation (Rule 19): take a database's default stream location as its directory -&gt; the
/// stream locations differ; <method>OcuPilot.Port.PathPort.JournalSources</method> answers any one
/// source empty -&gt; that source differs.</p>
Method TestThePortReadsTheInstancesDirectories()
{
    Do $$$AssertStatusOK(..LocalDatabases(.tNames, .tDirectories, .tStreams), "the configured local databases are read")
    Do $$$AssertTrue($ListLength(tDirectories) > 0, "there are some: " _ $ListToString(tNames, " "))
    Do $$$AssertStatusOK(##class(OcuPilot.Port.PathPort).DatabaseDirectories(.tPortDirectories, .tPortStreams), "the port reads them")
    Do $$$AssertEquals($ListToString(tPortDirectories, " "), $ListToString(tDirectories, " "), "the same directories, in the vendor's order")
    Do $$$AssertEquals($ListToString(tPortStreams, " "), $ListToString(tStreams, " "), "each with the vendor's own stream location")

    Do $$$AssertStatusOK(##class(OcuPilot.Port.PathPort).JournalDirectories(.tPortJournals), "the port reads the journal directories")
    Set tJournals = ..Journals()
    Set tCurrent = ##class(%SYS.Journal.System).GetCurrentFileName()
    Do $$$AssertTrue(tCurrent '= "", "journaling writes a file now")
    If tCurrent '= "" {
        Set tCurrent = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tCurrent))
        If '$ListFind(tJournals, tCurrent) Set tJournals = tJournals _ $ListBuild(tCurrent)
    }
    Set tHistory = ..HistoryDirectories()
    For tI = 1:1:$ListLength(tHistory) {
        If '$ListFind(tJournals, $List(tHistory, tI)) Set tJournals = tJournals _ $ListBuild($List(tHistory, tI))
    }
    Set tWij = ..WijDirectory()
    If '$ListFind(tJournals, tWij) Set tJournals = tJournals _ $ListBuild(tWij)
    Do $$$AssertEquals($ListToString(tPortJournals, " "), $ListToString(tJournals, " "), "the primary, the alternate and the current file's directory, then every directory the history lists and the write-image journal's, each once")
    Do $$$AssertStatusOK(##class(OcuPilot.Port.PathPort).JournalHistoryDirectories(.tPortHistory), "the port reads the journal history")
    Do $$$AssertEquals($ListToString(tPortHistory, " "), $ListToString(tHistory, " "), "naming each listed file's directory, newest first, once")
    Do $$$AssertStatusOK(##class(OcuPilot.Port.PathPort).WijDirectory(.tPortWij), "the port reads the write-image journal's directory")
    Do $$$AssertEquals(##class(%File).NormalizeDirectory(tPortWij), tWij, "as Config.config names it, the manager directory when empty")

    Do $$$AssertStatusOK(##class(OcuPilot.Port.PathPort).JournalSources(.tPrimary, .tAlternate, .tCurrentFile), "the port reads the three journal sources")
    Do $$$AssertEquals(tPrimary, ##class(%SYS.Journal.System).GetPrimaryDirectory(), "its primary is the instance's")
    Do $$$AssertEquals(tAlternate, ##class(%SYS.Journal.System).GetAlternateDirectory(), "its alternate is the instance's")
    Do $$$AssertEquals(tCurrentFile, ##class(%SYS.Journal.System).GetCurrentFileName(), "its current file is the instance's")
}


/// <p>The directory of every file the instance's journal history lists, read here from
/// <code>%SYS.Journal.File:ByTimeReverseOrder</code> in <code>%SYS</code> rather than through the
/// port, normalized and named once, newest first.</p>
ClassMethod HistoryDirectories() As %List
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Journal.File:ByTimeReverseOrder")
        Set tSC = tRS.Execute()
        While $$$ISOK(tSC) && tRS.Next(.tSC) {
            Set tDirectory = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tRS.Get("Name")))
            If '$ListFind(tOut, tDirectory) Set tOut = tOut _ $ListBuild(tDirectory)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOut
}

/// <p>The write-image journal's directory, read here from <code>Config.config</code> in
/// <code>%SYS</code>, normalized: the manager directory when <code>wijdir</code> is empty.</p>
ClassMethod WijDirectory() As %String
{
    Set tDirectory = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Do ##class(Config.config).Get(.tProperties)
        Set tDirectory = $Get(tProperties("wijdir"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    If tDirectory = "" Set tDirectory = $System.Util.ManagerDirectory()
    Quit ##class(%File).NormalizeDirectory(tDirectory)
}

/// <p>AC6, DW-1797: a former journal directory -- the probe alternate journaling was switched to and
/// back from, no longer configured -- is named by the journal history alone, and an existing journal
/// file there is refused <code>PATH.INSTANCE</code> to a caller that overwrites, from that directory as
/// the root; through the fixture's history seam naming no directory, the same file resolves. The
/// journal settings found are restored and the files the switches wrote are kept.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.PathPort.JournalHistoryDirectories</method> from
/// <method>OcuPilot.Port.PathPort.JournalDirectories</method> -&gt; the former directory's file
/// resolves and this goes red.</p>
Method TestAFormerJournalDirectoryStaysRefused()
{
    Set tProbe = "OcuPilot.Test.JournalProbe"
    Set tSaved = $ClassMethod(tProbe, "JournalSettings")
    Set tAlternate = $ClassMethod(tProbe, "AlternateDirectory")
    Set tOrigNS = $NAMESPACE
    Try {
        Do $$$AssertStatusOK($ClassMethod(tProbe, "SeedAlternate"), "the probe alternate is configured")
        Set $NAMESPACE = "%SYS"
        Set tSwitchSC = ##class(%SYS.Journal.System).SwitchDirectory(.tThere)
        Set tBackSC = ##class(%SYS.Journal.System).SwitchDirectory(.tBack)
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(tSwitchSC, "journaling switched to the alternate: " _ $Get(tThere))
        Do $$$AssertStatusOK(tBackSC, "and back: " _ $Get(tBack))
        Do $$$AssertStatusOK($ClassMethod(tProbe, "RestoreJournal", tSaved), "the journal settings found are restored")
        Do $$$AssertTrue('$ListFind(..Journals(), tAlternate), "the alternate is no longer configured")
        Do $$$AssertTrue($ListFind(..HistoryDirectories(), tAlternate) > 0, "while the journal history still names it")
        Set tFiles = $ClassMethod(..#HELPERS, "NamesIn", tAlternate, 0)
        Set tJournal = ""
        For tI = 1:1:$ListLength(tFiles) {
            If $Match($List(tFiles, tI), "[0-9]{8}\.[0-9]{3}z?") Set tJournal = $List(tFiles, tI)
        }
        Do $$$AssertTrue(tJournal '= "", "a journal file stands in the former directory: " _ $ListToString(tFiles, " "))
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tAlternate)), "the purpose is restricted to the former directory")
        Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
        Do $$$AssertEquals(..Overwrite(tAlternate, tJournal), tRefused, "'" _ tAlternate _ tJournal _ "' is refused to a caller that overwrites")
        Do $ClassMethod(..#FIXTURE, "UseJournalHistory", "")
        Do $$$AssertEquals(..Overwrite(tAlternate, tJournal, ..#FIXTURE), "200|" _ tAlternate _ tJournal, "and resolves while the history names no directory, so the history read is what refuses it")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(ex.AsStatus(), "the former-directory legs ran to the end")
    }
    Do $$$AssertStatusOK($ClassMethod(tProbe, "RestoreJournal", tSaved), "the journal settings found are in place")
    Do $$$AssertEquals($ClassMethod(tProbe, "JournalSettings").%ToJSON(), tSaved.%ToJSON(), "and read as found")
}

/// <p>AC6, DW-1797: an existing file directly in the write-image journal's directory is refused
/// <code>PATH.INSTANCE</code> to a caller that overwrites, through the fixture's seam naming a scratch
/// directory under <parameter>TMPROOT</parameter>, while a file in a subdirectory resolves; it resolves
/// once the seam names another directory; and a failed read refuses. The same holds for a directory
/// the journal history names. Creates and removes its scratch directory.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.PathPort.WijDirectory</method> from
/// <method>OcuPilot.Port.PathPort.JournalDirectories</method> -&gt; the write-image journal's file
/// resolves and this goes red.</p>
Method TestTheWriteImageJournalsDirectoryIsRefused()
{
    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-wij-" _ $Job _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertStatusOK(..WriteFile(tScratch _ "IRIS.WIJ"), "a scratch write-image journal file")
        Do $$$AssertStatusOK(..WriteFile(tScratch _ "sub/t.xml"), "and a file in a subdirectory")
        Set tName = $Piece(tScratch, "/", *-1) _ "/IRIS.WIJ"
        Set tRefused = $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
        Do $ClassMethod(tPort, "UseJournalHistory", "")
        Do $ClassMethod(tPort, "UseWijDirectory", tScratch)
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "a file directly in the write-image journal's directory is refused")
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, $Piece(tScratch, "/", *-1) _ "/sub/t.xml", tPort), "200|" _ tScratch _ "sub/t.xml", "but one in a subdirectory of it resolves")
        Do $ClassMethod(tPort, "UseWijDirectory", ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), "200|" _ tScratch _ "IRIS.WIJ", "and the same file resolves once the write-image journal is elsewhere")
        Do $ClassMethod(tPort, "UseWijDirectory", "", 1)
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "while its directory cannot be read, the overwrite is refused")
        Do $ClassMethod(tPort, "UseWijDirectory", ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()))
        Do $ClassMethod(tPort, "UseJournalHistory", $ListBuild(tScratch))
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "a file in a directory the journal history names is refused the same way")
        Do $ClassMethod(tPort, "UseJournalHistory", "", 1)
        Do $$$AssertEquals(..Overwrite(..#TMPROOT, tName, tPort), tRefused, "and while the history cannot be read, the overwrite is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the write-image journal legs ran to the end")
    }
    Do ##class(%File).Delete(tScratch _ "IRIS.WIJ")
    Do ##class(%File).Delete(tScratch _ "sub/t.xml")
    Do ##class(%File).RemoveDirectory(tScratch _ "sub/")
    Do ##class(%File).RemoveDirectory(tScratch)
    Do $$$AssertTrue('##class(%File).Exists(tScratch), "the scratch directory is removed")
}

}
