/// <p>AD-21's sixth case at <class>OcuPilot.Port.PathPort</class>, OcuPilot's own served directory
/// (AD-47): under the directory OcuPilot's client is served from, every file is refused 400
/// <code>PATH.SERVED</code> on the name's field to every file consumer, a new one as well as an
/// existing one and a source as well as a file to write, and that directory and every directory
/// under it are refused as a directory a consuming tool's vendor writes into; a file or directory
/// beside it resolves. The served directory is the port's read at each call, the bundle
/// application's own path, compared ignoring case, and a read that fails refuses.</p>
/// <p>Each method records the allow-list before it runs and restores it exactly afterwards, failure
/// included, through <class>OcuPilot.Test.PathPortFixture</class>, which is why
/// <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms it.
/// The legs on the instance's served directory and its parent resolve names only and write nothing
/// there; the seam legs create a scratch directory under <parameter>TMPROOT</parameter> and remove
/// it. Needs a process holding <code>%All</code>, and OcuPilot installed in the namespace it runs
/// in with its client deployed.</p>
Class OcuPilot.Test.PathPortServed Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Port.PathPort";

/// <p>Its seam subclass, and the allow-list helpers.</p>
Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

/// <p>The class whose resolution and refusal helpers this one shares.</p>
Parameter HELPERS = "OcuPilot.Test.PathPort";

/// <p>A directory every Linux instance has.</p>
Parameter TMPROOT = "/tmp/";

/// <p>A name no deployed file or directory carries, beside the served directory or under it.</p>
Parameter NEWNAME = "ocupilot-pathport-none";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortServed changes this instance's %GUIFileSelector allow-list and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>One resolution of kind <var>pKind</var> through <var>pPort</var>, as
/// <code>&lt;status&gt;|&lt;resolved path or fault as JSON&gt;</code>: a file to write with
/// <var>pOverwrite</var>, or a directory with <var>pVendorWrites</var>; a source takes
/// neither.</p>
ClassMethod Resolved(pRoot As %String, pPath As %String, pKind As %String, pOverwrite As %Boolean = 0, pVendorWrites As %Boolean = 0, pPort As %String = {..#PORT}) As %String
{
    Quit $ClassMethod(..#HELPERS, "ResolveOf", pRoot, pPath, pKind, "root", "path", pPort, pOverwrite, pVendorWrites)
}

/// <p>The 400 <code>PATH.SERVED</code> answers on the name's field.</p>
ClassMethod Refused() As %String
{
    Quit $ClassMethod(..#HELPERS, "Refusal", ##class(OcuPilot.Api.Error).#PATHSERVED, "path")
}

/// <p>The instance's served directory, as the port reads it, with the directory above it, the
/// served directory's own name, the deployed files directly in it and those in its
/// <code>media/</code>, and the allow-list restricted to the served directory and the one above
/// it. Reads names only.</p>
Method Deployed(Output pServed As %String, Output pParent As %String, Output pName As %String, Output pFiles As %List, Output pMedia As %List)
{
    Set pServed = ##class(OcuPilot.Port.PathPort).ServedDirectory()
    Set pParent = ##class(%File).ParentDirectoryName(pServed)
    Set pName = $Piece(pServed, "/", *-1)
    Set pFiles = $ClassMethod(..#HELPERS, "NamesIn", pServed, 0)
    Set pMedia = $ClassMethod(..#HELPERS, "NamesIn", pServed _ "media/", 0)
    Do $$$AssertTrue($ListFind(pFiles, "index.html") && $ListLength(pMedia), "the installer deployed files in " _ pServed _ " and its media/: " _ $ListToString(pFiles, " "))
    Do $$$AssertTrue((pParent '= "") && (pName '= ""), "the served directory has a parent and a name")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(pServed, pParent)), "the purpose is restricted to the served directory and the one above it")
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

/// <p>The scratch files the seam legs use, relative to the scratch directory: a served stand-in
/// <code>app/</code>, a sibling and a sibling whose name begins with the stand-in's.</p>
ClassMethod ScratchFiles() As %List
{
    Quit $ListBuild("app/held.js", "app/media/m.svg", "sibling/held.js", "appx/held.js")
}

/// <p>Remove the scratch directory <var>pScratch</var> and every file <method>ScratchFiles</method>
/// names in it, and answer whether it is gone.</p>
ClassMethod RemoveScratch(pScratch As %String) As %Boolean
{
    Set tFiles = ..ScratchFiles()
    For tI = 1:1:$ListLength(tFiles) {
        Do ##class(%File).Delete(pScratch _ $List(tFiles, tI))
    }
    For tDirectory = "app/media/", "app/", "sibling/", "appx/", "" {
        Do ##class(%File).RemoveDirectory(pScratch _ tDirectory)
    }
    Quit '##class(%File).Exists(pScratch)
}

/// <p>A file to write under the served directory is refused <code>PATH.SERVED</code>, new or
/// existing, whether or not the caller overwrites: each deployed file, one in
/// <code>media/</code>, and a new name directly in it, in <code>media/</code> and in a subdirectory
/// that does not exist, from the served directory as the root and from the one above it. Resolves
/// names only.</p>
/// <p>Mutation (Rule 19): refuse only a file that exists under the served directory -&gt; the new
/// name legs resolve; remove the check from the file and source kinds -&gt; every leg
/// resolves.</p>
Method TestAFileUnderTheServedDirectoryIsRefused()
{
    Do ..Deployed(.tServed, .tParent, .tName, .tFiles, .tMedia)
    Set tRefused = ..Refused()
    For tI = 1:1:$ListLength(tFiles) {
        Do $$$AssertEquals(..Resolved(tServed, $List(tFiles, tI), "file", 1), tRefused, "'" _ $List(tFiles, tI) _ "' is refused to a caller that overwrites")
    }
    If $ListLength(tMedia) Do $$$AssertEquals(..Resolved(tServed, "media/" _ $List(tMedia, 1), "file", 1), tRefused, "and so is a deployed file in media/")
    Do $$$AssertEquals(..Resolved(tServed, "index.html", "file", 0), tRefused, "and index.html to a caller that does not overwrite")
    For tPath = ..#NEWNAME _ ".txt", "media/" _ ..#NEWNAME _ ".svg", ..#NEWNAME _ "/a.txt" {
        For tOverwrite = 0, 1 {
            Do $$$AssertEquals(..Resolved(tServed, tPath, "file", tOverwrite), tRefused, "the new name " _ tPath _ " is refused, overwrite " _ tOverwrite)
        }
    }
    Do $$$AssertEquals(..Resolved(tParent, tName _ "/" _ ..#NEWNAME _ ".txt", "file", 0), tRefused, "a new name is refused from the directory above too")
    Do $$$AssertEquals(..Resolved(tParent, tName _ "/index.html", "file", 1), tRefused, "and so is index.html to an overwrite")
}

/// <p>A file to read under the served directory is refused <code>PATH.SERVED</code>: each deployed
/// file and one in <code>media/</code> as a source, from the served directory as the root and from
/// the one above it, and a name no file carries there, which is refused as served rather than as
/// missing. Resolves names only.</p>
/// <p>Mutation (Rule 19): skip the check for a source -&gt; each leg resolves; check a source only
/// once it exists -&gt; the missing name is refused <code>PATH.NOFILE</code>.</p>
Method TestASourceUnderTheServedDirectoryIsRefused()
{
    Do ..Deployed(.tServed, .tParent, .tName, .tFiles, .tMedia)
    Set tRefused = ..Refused()
    For tI = 1:1:$ListLength(tFiles) {
        Do $$$AssertEquals(..Resolved(tServed, $List(tFiles, tI), "source"), tRefused, "'" _ $List(tFiles, tI) _ "' is refused as a source")
    }
    If $ListLength(tMedia) Do $$$AssertEquals(..Resolved(tServed, "media/" _ $List(tMedia, 1), "source"), tRefused, "and so is a deployed file in media/")
    Do $$$AssertEquals(..Resolved(tParent, tName _ "/index.html", "source"), tRefused, "and index.html from the directory above")
    Do $$$AssertEquals(..Resolved(tServed, ..#NEWNAME _ ".txt", "source"), tRefused, "a name no file carries there is refused as served, not as missing")
}

/// <p>The served directory, its <code>media/</code> and a subdirectory that does not exist are
/// each refused <code>PATH.SERVED</code> as a directory the consuming tool's vendor writes into,
/// from the served directory as the root and from the one above it; to a tool whose vendor does
/// not write there, the served directory still resolves. Resolves names only.</p>
/// <p>Mutation (Rule 19): remove the check from the directory kind -&gt; each refused leg
/// resolves.</p>
Method TestTheServedDirectoryIsRefusedAsAVendorsDirectory()
{
    Do ..Deployed(.tServed, .tParent, .tName, .tFiles, .tMedia)
    Set tRefused = ..Refused()
    For tPath = "", "media", ..#NEWNAME {
        Do $$$AssertEquals(..Resolved(tServed, tPath, "directory", 0, 1), tRefused, "'" _ tPath _ "' under the served directory is refused to a vendor that writes there")
    }
    Do $$$AssertEquals(..Resolved(tParent, tName, "directory", 0, 1), tRefused, "and the served directory is refused from the directory above")
    Do $$$AssertEquals(..Resolved(tServed, "", "directory", 0, 0), "200|" _ tServed, "to a vendor that does not write there, it resolves")
}

/// <p>A file or directory beside the served directory is unaffected. From the directory above it,
/// a new file under a sibling whose name begins with the served directory's own resolves, and so
/// do that sibling and the directory above as a vendor's directory. Through the fixture's seam over
/// a scratch directory under <parameter>TMPROOT</parameter>, which it creates and removes, an
/// existing file in a sibling of the stand-in, and in one whose name extends the stand-in's,
/// resolves to an overwrite and as a source, and each sibling resolves as a vendor's
/// directory.</p>
/// <p>Mutation (Rule 19): test the served directory without its trailing separator -&gt; the
/// sibling legs whose name extends it are refused.</p>
Method TestASiblingOfTheServedDirectoryIsUnaffected()
{
    Do ..Deployed(.tServed, .tParent, .tName, .tFiles, .tMedia)
    Set tSibling = tName _ "-" _ ..#NEWNAME
    Do $$$AssertEquals(..Resolved(tParent, tSibling _ "/a.txt", "file", 0), "200|" _ tParent _ tSibling _ "/a.txt", "a new file in a sibling resolves")
    Do $$$AssertEquals(..Resolved(tParent, tSibling, "directory", 0, 1), "200|" _ tParent _ tSibling _ "/", "and the sibling resolves as a vendor's directory")
    Do $$$AssertEquals(..Resolved(tParent, "", "directory", 0, 1), "200|" _ tParent, "and so does the directory above")

    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-served-" _ $Job _ "/"
    Set tRelative = $Piece(tScratch, "/", *-1) _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Set tFiles = ..ScratchFiles()
        For tI = 1:1:$ListLength(tFiles) {
            Do $$$AssertStatusOK(..WriteFile(tScratch _ $List(tFiles, tI)), "a scratch file " _ $List(tFiles, tI))
        }
        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "")
        Do $ClassMethod(tPort, "UseJournalDirectories", "")
        Do $ClassMethod(tPort, "UseServedDirectory", tScratch _ "app/")
        Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ "app/held.js", "file", 1, 0, tPort), ..Refused(), "the stand-in's own file is refused")
        For tSibling = "sibling", "appx" {
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ tSibling _ "/held.js", "file", 1, 0, tPort), "200|" _ tScratch _ tSibling _ "/held.js", tSibling _ "'s file resolves to an overwrite")
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ tSibling _ "/held.js", "source", 0, 0, tPort), "200|" _ tScratch _ tSibling _ "/held.js", "and as a source")
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ tSibling, "directory", 0, 1, tPort), "200|" _ tScratch _ tSibling _ "/", "and " _ tSibling _ " resolves as a vendor's directory")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the sibling seam legs ran to the end")
    }
    Do $$$AssertTrue(..RemoveScratch(tScratch), "the scratch directory is removed")
}

/// <p>The served directory is the port's read at each call: on the instance it is the path the
/// instance holds for the roster's bundle destination application. Through the fixture's seam over
/// a scratch directory under <parameter>TMPROOT</parameter>, which it creates and removes, a file to
/// overwrite, a source and a vendor's directory under the stand-in are refused, and so under
/// another spelling; they resolve once the seam names another directory, and are refused while the
/// directory cannot be read.</p>
/// <p>Mutation (Rule 19): compare with case in
/// <method>OcuPilot.Port.PathPort.InServedDirectory</method> -&gt; the other-spelling legs resolve;
/// answer false while the directory cannot be read -&gt; the unread legs resolve.</p>
Method TestTheServedDirectoryIsReadAtEachCall()
{
    Set tServed = ##class(OcuPilot.Port.PathPort).ServedDirectory()
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Roster).Get(.tRoster), "the roster reads")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Applications).Get(tRoster.bundle.destinationApplication, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "the instance holds the bundle destination application")
    Do $$$AssertEquals(tServed, ##class(%File).NormalizeDirectory($Get(tProps("Path"))), "the served directory is that application's own path")

    Set tScratch = ..#TMPROOT _ "ocupilot-pathport-served-" _ $Job _ "/"
    Set tRelative = $Piece(tScratch, "/", *-1) _ "/"
    Set tPort = ..#FIXTURE
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Set tFiles = ..ScratchFiles()
        For tI = 1:1:$ListLength(tFiles) {
            Do $$$AssertStatusOK(..WriteFile(tScratch _ $List(tFiles, tI)), "a scratch file " _ $List(tFiles, tI))
        }
        Do $ClassMethod(tPort, "UseDatabaseDirectories", "", "")
        Do $ClassMethod(tPort, "UseJournalDirectories", "")
        For tCase = $ListBuild(tScratch _ "app/", 1, "the stand-in"), $ListBuild($ZConvert(tScratch, "U") _ "APP/", 1, "the stand-in under another spelling"), $ListBuild(tScratch _ "sibling/", 0, "another directory"), $ListBuild("", 1, "a directory that cannot be read") {
            Do $ClassMethod(tPort, "UseServedDirectory", $List(tCase, 1))
            Set tWhile = "while the seam names " _ $List(tCase, 3)
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ "app/media/m.svg", "file", 1, 0, tPort), $Select($List(tCase, 2): ..Refused(), 1: "200|" _ tScratch _ "app/media/m.svg"), "a file to overwrite " _ tWhile)
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ "app/held.js", "source", 0, 0, tPort), $Select($List(tCase, 2): ..Refused(), 1: "200|" _ tScratch _ "app/held.js"), "a source " _ tWhile)
            Do $$$AssertEquals(..Resolved(..#TMPROOT, tRelative _ "app", "directory", 0, 1, tPort), $Select($List(tCase, 2): ..Refused(), 1: "200|" _ tScratch _ "app/"), "a vendor's directory " _ tWhile)
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the served-directory seam legs ran to the end")
    }
    Do $$$AssertTrue(..RemoveScratch(tScratch), "the scratch directory is removed")
}

}
