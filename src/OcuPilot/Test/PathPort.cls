/// <p>AD-21's sixth case at the port: <class>OcuPilot.Port.PathPort</class>'s roots in each state of
/// the <code>%GUIFileSelector</code> allow-list, its resolver's answers and refusals, its
/// containment check, its own gate refusing before any admin port call (AD-29), and the screen read
/// and read tool answering the port's rows (AD-36).</p>
/// <p>Each method records the allow-list before it runs and restores it exactly afterwards, failure
/// included, through <class>OcuPilot.Test.PathPortFixture</class>; on a fresh instance the purpose is
/// absent, so restoring clears it. Changing the instance's own allow-list is why
/// <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms it.
/// Needs <parameter>TMPROOT</parameter> to exist and be writable, the install directory to exist,
/// a process holding <code>%All</code>, and OcuPilot installed in the namespace it runs in.</p>
Class OcuPilot.Test.PathPort Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Port.PathPort";

/// <p>Its seam subclass, and the allow-list helpers.</p>
Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

/// <p>The screen the port feeds.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AllowedDirectoryList";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPort changes this instance's %GUIFileSelector allow-list and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>The roots through <var>pPort</var>, as <code>&lt;status&gt;|&lt;rows as JSON&gt;</code>.</p>
ClassMethod RootsOf(pPort As %String = {..#PORT}, pMaxRows As %Integer = 1000) As %String
{
    Set tSC = $ClassMethod(pPort, "Roots", pMaxRows, .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tHttp _ "|" _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: "")
    Quit tHttp _ "|" _ tRows.%ToJSON()
}

/// <p>One resolution, as <code>&lt;status&gt;|&lt;resolved path or fault as JSON&gt;</code>.
/// <var>pOverwrite</var> and <var>pVendorWrites</var> are passed on only when given, so otherwise
/// the resolver's own defaults answer.</p>
ClassMethod ResolveOf(pRoot As %String, pPath As %String, pKind As %String, pRootField As %String = "root", pPathField As %String = "path", pPort As %String = {..#PORT}, pOverwrite As %String = "", pVendorWrites As %String = "") As %String
{
    If pVendorWrites '= "" {
        Set tSC = $ClassMethod(pPort, "Resolve", pRoot, pPath, pKind, pRootField, pPathField, .tResolved, .tHttp, .tFault, +pOverwrite, pVendorWrites)
    } ElseIf pOverwrite = "" {
        Set tSC = $ClassMethod(pPort, "Resolve", pRoot, pPath, pKind, pRootField, pPathField, .tResolved, .tHttp, .tFault)
    } Else {
        Set tSC = $ClassMethod(pPort, "Resolve", pRoot, pPath, pKind, pRootField, pPathField, .tResolved, .tHttp, .tFault, pOverwrite)
    }
    If $$$ISERR(tSC) Quit tHttp _ "|" _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: "")
    Quit tHttp _ "|" _ tResolved
}

/// <p>The 400 a refusal on one field answers, as <method>ResolveOf</method> spells it: the code's
/// published sentence, and one violation on <var>pField</var> carrying the same pair.</p>
ClassMethod Refusal(pCode As %String, pField As %String) As %String
{
    Set tReason = $Parameter("OcuPilot.Api.Error", "REASON" _ $Translate(pCode, "."))
    Set tFault = {"error": (##class(OcuPilot.Api.Error).#BADREQUEST), "reason": (tReason), "code": (pCode)}
    Do tFault.%Set("detail", {"violations": [{"field": (pField), "code": (pCode), "reason": (tReason)}]})
    Quit "400|" _ tFault.%ToJSON()
}

/// <p>The one row an unrestricted instance answers.</p>
ClassMethod ManagerRow() As %String
{
    Set tRow = {"Directory": ($System.Util.ManagerDirectory()), "Restricted": false}
    Quit "[" _ tRow.%ToJSON() _ "]"
}

/// <p>Matrix "Unrestricted" -- with the purpose absent, and again present but not restricted and
/// holding a root path, the roots are the manager directory alone, <code>Restricted</code> false;
/// the stored path is ignored. <method>OcuPilot.Port.PathPort.Rows</method> answers the same.</p>
Method TestUnrestrictedAnswersTheManagerDirectoryAlone()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, as on a fresh instance")
    Do $$$AssertEquals(..RootsOf(), "200|" _ ..ManagerRow(), "an absent purpose answers the manager directory alone")
    Set tSC = ##class(OcuPilot.Port.PathPort).Rows("roots", 1000, .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the declared source answers")
    If $$$ISOK(tSC) Do $$$AssertEquals(tRows.%ToJSON(), ..ManagerRow(), "with the same row")

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 0, $ListBuild(..#TMPROOT)), "the purpose holds a root path but is not restricted")
    Do $$$AssertEquals(..RootsOf(), "200|" _ ..ManagerRow(), "and the stored path is ignored")
}

/// <p>Matrix "Restricted" -- a restricted purpose with <parameter>TMPROOT</parameter> and the install
/// directory answers exactly those two rows in the vendor's order, each <code>Restricted</code> true,
/// and not the manager directory; a cap of one answers the first alone.</p>
Method TestRestrictedAnswersExactlyItsRoots()
{
    Set tInstall = $System.Util.InstallDirectory()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tInstall, ..#TMPROOT)), "the purpose is restricted to two roots")
    Set tExpected = [{"Directory": (..#TMPROOT), "Restricted": true}, {"Directory": (tInstall), "Restricted": true}]
    Do $$$AssertEquals(..RootsOf(), "200|" _ tExpected.%ToJSON(), "the two roots, in the vendor's order, and no manager directory")
    Do $$$AssertEquals(..RootsOf(, 1), "200|[" _ tExpected.%Get(0).%ToJSON() _ "]", "a cap of one answers the first")
}

/// <p>Matrix "Restricted, empty" -- a restricted purpose with no root path answers no row.</p>
Method TestRestrictedWithNoRootsAnswersNone()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, ""), "the purpose is restricted and holds no root")
    Do $$$AssertEquals(..RootsOf(), "200|[]", "no row")
}

/// <p>Matrix "No privilege", AC2 -- without <code>%Admin_FileSystemAccess:USE</code>, the roots,
/// the declared source and the resolver each refuse 403 <code>PORT.ACCESSDENIED</code> naming that
/// pair, with no admin port call made; without <code>%DB_IRISSYS:READ</code> they name that one.</p>
/// <p>Mutation (Rule 19): remove the <code>Gate</code> call from
/// <method>OcuPilot.Port.PathPort.Roots</method> -&gt; the roots answer and the call count moves;
/// remove it from <method>OcuPilot.Port.PathPort.Resolve</method> -&gt; the bad-name leg answers
/// 400; check the kind before it -&gt; the unknown-kind leg answers 500.</p>
Method TestTheGateRefusesBeforeAnyAdminPortCall()
{
    Set tPort = ..#FIXTURE
    For tPair = "%Admin_FileSystemAccess:USE", "%DB_IRISSYS:READ" {
        Do $ClassMethod(tPort, "Reset")
        Do $ClassMethod(tPort, "Deny", tPair)
        Set tSC = $ClassMethod(tPort, "Roots", 1000, .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tPair _ " denied: the roots are refused")
        Do $$$AssertEquals(tHttp, 403, tPair _ " denied: 403")
        If $IsObject(tFault) {
            Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, tPair _ " denied: on the port's own code")
            Do $$$AssertEquals($Select($IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), tPair, tPair _ " denied: naming the pair")
        }
        Set tSC = $ClassMethod(tPort, "Rows", "roots", 1000, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 403, tPair _ " denied: the declared source is refused too")
        Do $$$AssertEquals($Piece(..ResolveOf(..#TMPROOT, "a", "directory", , , tPort), "|", 1), 403, tPair _ " denied: and so is a resolution")
        Do $$$AssertEquals($Piece(..ResolveOf(..#TMPROOT, "a..b", "directory", , , tPort), "|", 1), 403, tPair _ " denied: a bad name meets the gate before the name rule")
        Do $$$AssertEquals($Piece(..ResolveOf(..#TMPROOT, "a", "Directory", , , tPort), "|", 1), 403, tPair _ " denied: and so does a kind the port does not know")
        Do $$$AssertEquals($ClassMethod(tPort, "Calls"), 0, tPair _ " denied: no admin port call was made")
    }
    Do $ClassMethod(tPort, "Reset")
    Do $$$AssertEquals($Piece(..RootsOf(tPort), "|", 1), 200, "with nothing denied the seam answers")
    Do $$$AssertTrue($ClassMethod(tPort, "Calls") > 0, "through the admin port: " _ $ClassMethod(tPort, "Calls"))
}

/// <p>Matrix "Resolve OK" -- under the allowed root <parameter>TMPROOT</parameter>, an empty name
/// resolves a directory to the root itself, <code>a/b</code> to <code>/tmp/a/b/</code>, and a file
/// <code>exports/t.xml</code> to <code>/tmp/exports/t.xml</code>. Eight names and a 100-character
/// name are admitted.</p>
Method TestResolveComposesUnderAnAllowedRoot()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "", "directory"), "200|/tmp/", "an empty name is the root itself")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a/b", "directory"), "200|/tmp/a/b/", "a directory keeps its trailing separator")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "exports/t.xml", "file"), "200|/tmp/exports/t.xml", "a file names its path")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a/b/c/d/e/f/g/h", "directory"), "200|/tmp/a/b/c/d/e/f/g/h/", "eight names are admitted")
    Set tLong = $Translate($Justify("", 100), " ", "x")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tLong, "file"), "200|/tmp/" _ tLong, "and so is a 100-character name")

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent")
    Set tManager = $System.Util.ManagerDirectory()
    Do $$$AssertEquals(..ResolveOf(tManager, "exports", "directory"), "200|" _ tManager _ "exports/", "unrestricted, the manager directory is the root")
}

/// <p>Matrix "Foreign root" -- while <parameter>TMPROOT</parameter> is allowed, <code>/tmp/a/</code>,
/// <code>/TMP/</code>, the manager directory and <code>/etc/</code> are each refused 400
/// <code>PATH.ROOT</code> on the root's field, echoing nothing; the caller names the field.</p>
/// <p>Mutation (Rule 19): make the membership test a prefix test -&gt; <code>/tmp/a/</code> resolves
/// and this goes red.</p>
Method TestAForeignRootIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHROOT, "root")
    For tRoot = "/tmp/a/", "/TMP/", $System.Util.ManagerDirectory(), "/etc/", "/tmp" {
        Do $$$AssertEquals(..ResolveOf(tRoot, "a", "directory"), tRefused, "'" _ tRoot _ "' is not an allowed root")
    }
    Do $$$AssertEquals(..ResolveOf("/etc/", "a", "directory", "Directory", "Name"), ..Refusal(##class(OcuPilot.Api.Error).#PATHROOT, "Directory"), "the refusal lands on the field the caller named")
}

/// <p>Matrix "Bad name" -- each shape is refused 400 <code>PATH.NAME</code> on the name's field,
/// echoing nothing, and an empty name is refused for a file. A kind outside the three is a caller
/// fault, a 500.</p>
/// <p>Mutation (Rule 19): drop the literal <code>..</code> refusal from
/// <method>OcuPilot.Port.PathPort.NameAdmitted</method> -&gt; <code>a..b</code> resolves and this goes
/// red.</p>
Method TestABadNameIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHNAME, "path")
    Set tNames = $ListBuild("..", "a/../b", "a..b", "/x", "a//b", "a/", "a\b", "c:x", "a/b/c/d/e/f/g/h/i", $Translate($Justify("", 101), " ", "x"), ".hidden", "-x")
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tName, "directory"), tRefused, "'" _ $Extract(tName, 1, 20) _ "' is refused")
    }
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "", "file"), tRefused, "an empty name names no file")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a..b", "file", "Dir", "Name"), ..Refusal(##class(OcuPilot.Api.Error).#PATHNAME, "Name"), "the refusal lands on the field the caller named")
    Do $$$AssertEquals($Piece(..ResolveOf(..#TMPROOT, "a", "Directory"), "|", 1), 500, "a kind other than the three is a caller fault")
}

/// <p>AD-21's containment check in <method>OcuPilot.Port.PathPort.Resolve</method>, behind the name
/// rule: with every name admitted through the seam, <code>../etc</code> normalizes to
/// <code>/etc/</code>, outside <parameter>TMPROOT</parameter>, and is refused 400
/// <code>PATH.NAME</code>, for a file and for a source naming a file that exists there. Scripted
/// through the seam, so the allow-list is not touched.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.PathPort.Contains</method> test from
/// <method>OcuPilot.Port.PathPort.Resolve</method> -&gt; <code>../etc</code> resolves and this goes
/// red.</p>
Method TestResolveRefusesANameThatLeavesItsRoot()
{
    Set tPort = ..#FIXTURE
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Script", "FSAccess.Purpose", "GET", 200, "{""Restricted"":true}")
    Do $ClassMethod(tPort, "Script", "FSAccess.Path", "LIST", 200, "[{""RootPath"":""/tmp/""}]")
    Do $ClassMethod(tPort, "AdmitAnyName")
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHNAME, "path")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a", "directory", , , tPort), "200|/tmp/a/", "a name under the root resolves through the seam")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "../etc", "directory", , , tPort), tRefused, "a directory that normalizes outside the root is refused on the name's field")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "../etc/x.txt", "file", , , tPort), tRefused, "and so is such a file")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "../etc/passwd", "source", , , tPort), tRefused, "and such a source, though the file exists")
}

/// <p>AD-21's sixth case, an existing name -- a file named where a file or directory already
/// exists is refused 400 <code>PATH.EXISTS</code> on the name's field, echoing nothing, unless the
/// caller passes <var>pOverwrite</var>, which resolves an existing file but never a directory
/// standing at that name; a name not taken resolves without it; and a directory is never refused
/// for existing. Works in a scratch directory under <parameter>TMPROOT</parameter> that it
/// creates and removes.</p>
/// <p>Mutation (Rule 19): drop the existence test from
/// <method>OcuPilot.Port.PathPort.Resolve</method> -&gt; the existing file resolves; ignore
/// <var>pOverwrite</var> there -&gt; the overwrite leg is refused; drop its directory test -&gt;
/// the directory resolves to a caller that overwrites.</p>
Method TestAnExistingNameIsRefusedUnlessTheCallerOverwrites()
{
    Set tScratch = "ocupilot-pathport-" _ $Job
    Set tDirectory = ..#TMPROOT _ tScratch _ "/"
    Set tFile = tDirectory _ "existing.xml"
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertTrue(##class(%File).CreateDirectoryChain(tDirectory _ "taken"), "a scratch directory holding a directory")
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Do $$$AssertStatusOK(tStream.LinkToFile(tFile), "and a file")
        Do tStream.Write("x")
        Do $$$AssertStatusOK(tStream.%Save(), "written to disk")
        Set tStream = ""

        Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHEXISTS, "path")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "file"), tRefused, "an existing file is refused to a caller that does not overwrite")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "file", "Dir", "Name"), ..Refusal(##class(OcuPilot.Api.Error).#PATHEXISTS, "Name"), "the refusal lands on the field the caller named")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/taken", "file"), tRefused, "and a directory standing where the file would go is refused too")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "file", , , , 0), tRefused, "as it is when the caller says it does not overwrite")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "file", , , , 1), "200|" _ tFile, "a caller that overwrites resolves the existing file")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/taken", "file", , , , 1), tRefused, "but not a directory standing where the file would go")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/new.xml", "file"), "200|" _ tDirectory _ "new.xml", "a name not taken resolves without overwriting")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/taken", "directory"), "200|" _ tDirectory _ "taken/", "an existing directory is never refused for existing")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the existing-name legs ran to the end")
    }
    Do ##class(%File).Delete(tFile)
    Do ##class(%File).RemoveDirectory(tDirectory _ "taken")
    Do ##class(%File).RemoveDirectory(tDirectory)
    Do $$$AssertTrue('##class(%File).Exists(tDirectory), "the scratch directory is removed")
}

/// <p>AD-21's sixth case, the manager directory -- a file named directly in it, where the
/// instance keeps its own files, is refused 400 <code>PATH.MANAGER</code> on the name's field,
/// echoing nothing: one name under the unrestricted root, an instance file even to a caller that
/// overwrites, one name under a restricted root that is the manager directory, and a name reaching
/// it from a root above. A file in a subdirectory of it resolves, and a directory is not refused.
/// Creates no file.</p>
/// <p>Mutation (Rule 19): drop the manager-directory test from
/// <method>OcuPilot.Port.PathPort.Resolve</method> -&gt; each refused leg resolves, except the existing
/// instance file, which is refused as a taken name; test the existing name before it -&gt; that
/// file is refused as a taken name.</p>
Method TestAFileDirectlyInTheManagerDirectoryIsRefused()
{
    Set tManager = $System.Util.ManagerDirectory()
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHMANAGER, "path")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
    Do $$$AssertEquals(..ResolveOf(tManager, "ocupilot-pathport-none.xml", "file"), tRefused, "a new file directly in it is refused")
    Do $$$AssertEquals(..ResolveOf(tManager, "IRIS.DAT", "file", , , , 1), tRefused, "and so is an instance file, even to a caller that overwrites")
    Do $$$AssertEquals(..ResolveOf(tManager, "IRIS.DAT", "file"), tRefused, "and to a caller that does not, an instance file is refused as the manager directory's, not as a taken name")
    Do $$$AssertEquals(..ResolveOf(tManager, "ocupilot-pathport-none.xml", "file", "Dir", "Name"), ..Refusal(##class(OcuPilot.Api.Error).#PATHMANAGER, "Name"), "the refusal lands on the field the caller named")
    Do $$$AssertEquals(..ResolveOf(tManager, "exports/t.xml", "file"), "200|" _ tManager _ "exports/t.xml", "a file in a subdirectory of it resolves")
    Do $$$AssertEquals(..ResolveOf(tManager, "", "directory"), "200|" _ tManager, "and the directory itself is not refused")

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tManager)), "the purpose is restricted to the manager directory")
    Do $$$AssertEquals(..ResolveOf(tManager, "t.xml", "file"), tRefused, "one name under a restricted root that is the manager directory is refused")

    Set tParent = ##class(%File).ParentDirectoryName(tManager)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tParent)), "the purpose is restricted to the directory above it")
    Do $$$AssertEquals(..ResolveOf(tParent, $Piece(tManager, "/", *-1) _ "/t.xml", "file"), tRefused, "and so is a file reaching it from a root above")
}

/// <p>AD-21's sixth case, a file the consumer reads -- a <code>source</code> resolves only where a
/// file already stands, with or without <var>pOverwrite</var>. An absent name, even to a caller
/// passing <var>pOverwrite</var>, and a directory at the name, are refused 400
/// <code>PATH.NOFILE</code> on the name's field, echoing nothing; an empty name is refused
/// <code>PATH.NAME</code>; and a file directly in the manager directory is refused
/// <code>PATH.MANAGER</code> though it exists. Works in a scratch directory under
/// <parameter>TMPROOT</parameter> that it creates and removes.</p>
/// <p>Mutation (Rule 19): drop the source's existence test -&gt; the absent name resolves; drop its
/// directory test -&gt; the directory resolves; resolve a source passed <var>pOverwrite</var> as a
/// file -&gt; the absent name resolves to that caller; refuse a source that exists -&gt; the
/// existing file is refused; test the manager directory for a file alone -&gt; the source in it
/// resolves.</p>
Method TestASourceMustBeAnExistingFile()
{
    Set tScratch = "ocupilot-pathport-source-" _ $Job
    Set tDirectory = ..#TMPROOT _ tScratch _ "/"
    Set tFile = tDirectory _ "existing.xml"
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertTrue(##class(%File).CreateDirectoryChain(tDirectory _ "taken"), "a scratch directory holding a directory")
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Do $$$AssertStatusOK(tStream.LinkToFile(tFile), "and a file")
        Do tStream.Write("x")
        Do $$$AssertStatusOK(tStream.%Save(), "written to disk")
        Set tStream = ""

        Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHNOFILE, "path")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "source"), "200|" _ tFile, "an existing file resolves as a source")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/existing.xml", "source", , , , 1), "200|" _ tFile, "and the same to a caller passing overwrite")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/absent.xml", "source"), tRefused, "an absent name is refused")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/absent.xml", "source", , , , 1), tRefused, "and overwrite does not make it a new file")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/taken", "source"), tRefused, "a directory at the name is refused")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/absent.xml", "source", "Dir", "Name"), ..Refusal(##class(OcuPilot.Api.Error).#PATHNOFILE, "Name"), "the refusal lands on the field the caller named")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "", "source"), ..Refusal(##class(OcuPilot.Api.Error).#PATHNAME, "path"), "an empty name names no file")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the source legs ran to the end")
    }
    Do ##class(%File).Delete(tFile)
    Do ##class(%File).RemoveDirectory(tDirectory _ "taken")
    Do ##class(%File).RemoveDirectory(tDirectory)
    Do $$$AssertTrue('##class(%File).Exists(tDirectory), "the scratch directory is removed")

    Set tManager = $System.Util.ManagerDirectory()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
    Do $$$AssertEquals(..ResolveOf(tManager, "IRIS.DAT", "source"), ..Refusal(##class(OcuPilot.Api.Error).#PATHMANAGER, "path"), "a source directly in the manager directory is refused, though it exists")
}

/// <p>AD-21's sixth case, the instance's own files -- to a caller that overwrites, each existing
/// file beside the instance's configuration file, and each existing database file one directory
/// below the manager directory, from that directory as the root or from the one above it, is
/// refused 400 <code>PATH.INSTANCE</code> on the name's field, echoing nothing; a caller that does
/// not overwrite is refused them as taken names, and a new name in either place resolves. A
/// database file's name is matched ignoring case, and any other file below the manager directory
/// is not the instance's. The configuration file's directory is the one the port reads, so a
/// configuration file named through the seam moves the refusal with it, and one it cannot read
/// refuses every file. Its seam leg works in a scratch directory under
/// <parameter>TMPROOT</parameter> that it creates and removes.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PathPort.DirectlyInConfigurationDirectory</method>
/// answers false -&gt; the configuration legs resolve;
/// <method>OcuPilot.Port.PathPort.DatabaseFileBelowManagerDirectory</method> answers false -&gt; the
/// lower-case name is not the instance's, while the database legs stay refused as configured
/// databases' files; the configuration directory is taken as the manager directory's parent
/// -&gt; the seam leg resolves; the existence test in front of the instance's files dropped -&gt;
/// the new names are refused; the database file's name compared with its case -&gt; the lower-case
/// name is not the instance's; its name test dropped, or the configuration directory tested as a
/// prefix -&gt; the ordinary file is the instance's; an empty configuration file no longer failing
/// closed -&gt; the file resolves while none can be read.</p>
Method TestAnOverwriteNeverReachesTheInstancesOwnFiles()
{
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHINSTANCE, "path")
    Set tTaken = ..Refusal(##class(OcuPilot.Api.Error).#PATHEXISTS, "path")
    Set tConfiguration = ##class(%File).GetFilename(##class(%SYS.System).GetCPFFileName())
    Set tData = ##class(%File).GetDirectory(##class(%SYS.System).GetCPFFileName())
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tData)), "the purpose is restricted to the configuration file's directory")
    Set tNames = ..NamesIn(tData, 0)
    Do $$$AssertTrue($ListFind(tNames, tConfiguration) > 0, "the configuration file is among the files there: " _ $ListToString(tNames))
    For tI = 1:1:$ListLength(tNames) {
        Do $$$AssertEquals(..ResolveOf(tData, $List(tNames, tI), "file", , , , 1), tRefused, "'" _ $List(tNames, tI) _ "' is refused to a caller that overwrites")
    }
    Do $$$AssertEquals(..ResolveOf(tData, tConfiguration, "file"), tTaken, "and to one that does not, as a taken name")
    Do $$$AssertEquals(..ResolveOf(tData, tConfiguration, "file", "Dir", "Name", , 1), ..Refusal(##class(OcuPilot.Api.Error).#PATHINSTANCE, "Name"), "the refusal lands on the field the caller named")
    Do $$$AssertEquals(..ResolveOf(tData, "ocupilot-pathport-none.cpf", "file", , , , 1), "200|" _ tData _ "ocupilot-pathport-none.cpf", "a new name there resolves")

    Set tManager = $System.Util.ManagerDirectory()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
    Set tNames = ..NamesIn(tManager, 1)
    Do $$$AssertTrue($ListLength(tNames) > 0, "database files stand one directory below the manager directory: " _ $ListToString(tNames))
    For tI = 1:1:$ListLength(tNames) {
        Do $$$AssertEquals(..ResolveOf(tManager, $List(tNames, tI), "file", , , , 1), tRefused, "'" _ $List(tNames, tI) _ "' is refused to a caller that overwrites")
    }
    If $ListLength(tNames) Do $$$AssertEquals(..ResolveOf(tManager, $List(tNames, 1), "file"), tTaken, "and to one that does not, as a taken name")
    Do $$$AssertEquals(..ResolveOf(tManager, "ocupilot-pathport-none/IRIS.DAT", "file", , , , 1), "200|" _ tManager _ "ocupilot-pathport-none/IRIS.DAT", "a new database file name resolves")
    Do $$$AssertTrue(##class(OcuPilot.Port.PathPort).DatabaseFileBelowManagerDirectory(tManager _ "ocupilot-pathport-none/iris.dat"), "a database file's name is matched ignoring case")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).InstanceFile(tManager _ "ocupilot-pathport-none/t.xml"), "but any other file one directory below the manager directory is not the instance's")
    Set tParent = ##class(%File).ParentDirectoryName(tManager)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tParent)), "the purpose is restricted to the directory above the manager directory")
    If $ListLength(tNames) Do $$$AssertEquals(..ResolveOf(tParent, $Piece(tManager, "/", *-1) _ "/" _ $List(tNames, 1), "file", , , , 1), tRefused, "and a database file reached from a root above is refused too")

    Set tScratch = "ocupilot-pathport-cpf-" _ $Job
    Set tFile = ..#TMPROOT _ tScratch _ "/copy.cpf"
    Try {
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT)), "the purpose is restricted to /tmp/")
        Do $$$AssertTrue(##class(%File).CreateDirectoryChain(..#TMPROOT _ tScratch), "a scratch directory")
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Do $$$AssertStatusOK(tStream.LinkToFile(tFile), "holding a file")
        Do tStream.Write("x")
        Do $$$AssertStatusOK(tStream.%Save(), "written to disk")
        Set tStream = ""
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/copy.cpf", "file", , , , 1), "200|" _ tFile, "it is overwritable while the configuration file is elsewhere")
        Do $ClassMethod(..#FIXTURE, "UseConfigurationFile", ..#TMPROOT _ tScratch _ "/iris.cpf")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/copy.cpf", "file", , , ..#FIXTURE, 1), tRefused, "and refused once the configuration file is read there")
        Do $ClassMethod(..#FIXTURE, "UseConfigurationFile", "")
        Do $$$AssertEquals(..ResolveOf(..#TMPROOT, tScratch _ "/copy.cpf", "file", , , ..#FIXTURE, 1), tRefused, "and refused while no configuration file can be read, which fails closed")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the seam legs ran to the end")
    }
    Do ##class(%File).Delete(tFile)
    Do ##class(%File).RemoveDirectory(..#TMPROOT _ tScratch)
    Do $$$AssertTrue('##class(%File).Exists(..#TMPROOT _ tScratch), "the scratch directory is removed")
}

/// <p>A directory a consuming tool's vendor writes its own files into -- passed
/// <var>pVendorWrites</var>, the manager directory itself is refused 400
/// <code>PATH.MANAGERDIR</code> on the name's field, echoing nothing, as the unrestricted root
/// with an empty name and as a name reaching it from a root above. A subdirectory of it resolves,
/// and without <var>pVendorWrites</var> the manager directory resolves as any directory does.
/// Creates nothing.</p>
/// <p>Mutation (Rule 19): drop the vendor-directory test from
/// <method>OcuPilot.Port.PathPort.Resolve</method> -&gt; each refused leg resolves; drop its
/// <var>pVendorWrites</var> condition -&gt; the undeclared leg is refused;
/// <method>OcuPilot.Port.PathPort.IsManagerDirectory</method> tests containment -&gt; the
/// subdirectory is refused.</p>
Method TestAVendorsDirectoryIsNeverTheManagerDirectory()
{
    Set tManager = $System.Util.ManagerDirectory()
    Set tRefused = ..Refusal(##class(OcuPilot.Api.Error).#PATHMANAGERDIR, "path")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent, so the manager directory is the one root")
    Do $$$AssertEquals(..ResolveOf(tManager, "", "directory", , , , , 1), tRefused, "the manager directory itself is refused to a vendor that writes into it")
    Do $$$AssertEquals(..ResolveOf(tManager, "", "directory", "Dir", "Name", , , 1), ..Refusal(##class(OcuPilot.Api.Error).#PATHMANAGERDIR, "Name"), "the refusal lands on the field the caller named")
    Do $$$AssertEquals(..ResolveOf(tManager, "ocupilot-pathport-db", "directory", , , , , 1), "200|" _ tManager _ "ocupilot-pathport-db/", "a subdirectory of it resolves")
    Do $$$AssertEquals(..ResolveOf(tManager, "", "directory", , , , , 0), "200|" _ tManager, "and without the declaration the manager directory resolves as any directory does")

    Set tParent = ##class(%File).ParentDirectoryName(tManager)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tParent)), "the purpose is restricted to the directory above it")
    Do $$$AssertEquals(..ResolveOf(tParent, $Piece(tManager, "/", *-1), "directory", , , , , 1), tRefused, "and so is the manager directory reached from a root above")
}

/// <p>The relative names a test resolves under directory <var>pDirectory</var>, only those the
/// port's name rule admits: each file directly in it, or, with <var>pDatabases</var>,
/// <code>&lt;name&gt;/IRIS.DAT</code> for each directory directly in it holding one.</p>
ClassMethod NamesIn(pDirectory As %String, pDatabases As %Boolean = 0) As %List
{
    Set tNames = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Do tRS.Execute(pDirectory, "*", "", 1)
    While tRS.Next() {
        Set tName = tRS.Get("ItemName")
        If '$Match(tName, ##class(OcuPilot.Port.PathPort).#SEGMENTPATTERN) Continue
        If 'pDatabases {
            If tRS.Get("Type") = "F" Set tNames = tNames _ $ListBuild(tName)
        } ElseIf (tRS.Get("Type") = "D") && ##class(%File).Exists(pDirectory _ tName _ "/IRIS.DAT") {
            Set tNames = tNames _ $ListBuild(tName _ "/IRIS.DAT")
        }
    }
    Quit tNames
}

/// <p>Matrix "Not cached" -- a root removed between two resolutions refuses the second.</p>
/// <p>Mutation (Rule 19): keep the roots <method>OcuPilot.Port.PathPort.Roots</method> answers in a
/// process-private global and answer from it -&gt; the second resolution succeeds and this goes
/// red.</p>
Method TestTheRootsAreNotCached()
{
    Set tInstall = $System.Util.InstallDirectory()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT, tInstall)), "the purpose is restricted to two roots")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a", "directory"), "200|/tmp/a/", "the first resolution succeeds")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RemoveRoot", ..#TMPROOT), "/tmp/ is removed from the allow-list")
    Do $$$AssertEquals(..ResolveOf(..#TMPROOT, "a", "directory"), ..Refusal(##class(OcuPilot.Api.Error).#PATHROOT, "root"), "the second is refused")
    Do $$$AssertEquals(..ResolveOf(tInstall, "a", "directory"), "200|" _ tInstall _ "a/", "while the root left in place still resolves")
}

/// <p><method>OcuPilot.Port.PathPort.Contains</method> is non-strict and keeps the root's trailing
/// separator: the root itself and anything under it are inside, a sibling sharing its prefix is
/// not.</p>
/// <p>Mutation (Rule 19): compare against the root without its trailing separator -&gt; the
/// <code>/a/bc/</code> leg goes red.</p>
Method TestContainsKeepsTheTrailingSeparator()
{
    Do $$$AssertTrue(##class(OcuPilot.Port.PathPort).Contains("/a/b/", "/a/b/"), "the root itself is inside")
    Do $$$AssertTrue(##class(OcuPilot.Port.PathPort).Contains("/a/b/", "/a/b/c/"), "a directory under it is inside")
    Do $$$AssertTrue(##class(OcuPilot.Port.PathPort).Contains("/a/b/", "/a/b/c.txt"), "and so is a file")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).Contains("/a/b/", "/a/bc/"), "a sibling sharing its prefix is not")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).Contains("/a/b", "/a/bc/"), "nor with the root written without its separator")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).Contains("/a/b/", "/a/"), "nor is its parent")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).Contains("", "/a/"), "an empty root contains nothing")
    Do $$$AssertTrue('##class(OcuPilot.Port.PathPort).Contains("/a/", ""), "and nothing is inside anything")
}

/// <p>Matrix "Integration", AC1 -- the screen's declared read and its read tool answer the rows
/// <method>OcuPilot.Port.PathPort.Rows</method> answers, restricted and not (AD-36).</p>
Method TestTheScreenReadAndToolAnswerThePortsRows()
{
    Set tInstall = $System.Util.InstallDirectory()
    For tState = "absent", "restricted", "empty" {
        If tState = "absent" Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), tState _ ": the purpose is absent")
        If tState = "restricted" Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT, tInstall)), tState _ ": the purpose is restricted to two roots")
        If tState = "empty" Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, ""), tState _ ": the purpose is restricted to none")
        Set tSC = ##class(OcuPilot.Port.PathPort).Rows("roots", 1001, .tPortRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tState _ ": the port answers")
        If $$$ISERR(tSC) Continue

        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tState _ ": the screen's declared read answers")
        If $$$ISOK(tSC) {
            Do $$$AssertEquals(tResult.rows.%ToJSON(), tPortRows.%ToJSON(), tState _ ": with the port's rows")
            Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Directory"",""Restricted""]", tState _ ": under the two declared fields")
            Do $$$AssertEquals(tResult.truncated, 0, tState _ ": uncut")
        }

        Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, {}, 1000, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tState _ ": the read tool answers")
        Do $$$AssertTrue($$$ISERR(tSC) || $IsObject(tView), tState _ ": with a view")
        If $$$ISOK(tSC) && $IsObject(tView) {
            Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tPortRows, $ClassMethod(..#DESCRIPTOR, "Read"))
            Do $$$AssertEquals(tView.rows.%ToJSON(), tOrdered.%ToJSON(), tState _ ": the tool's rows are the port's in the declared order")
        }
    }

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT, tInstall)), "cut: the purpose is restricted to two roots")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "cut: the screen's declared read answers at a cap of one")
    If $$$ISOK(tSC) {
        Do $$$AssertEquals(tResult.rows.%Size(), 1, "cut: one row")
        Do $$$AssertEquals(tResult.truncated, 1, "cut: and the read says it was cut (AD-36)")
    }
}

/// <p>Matrix "Unrestricted", the removed-purpose race, and the fail-closed rule behind it: a purpose
/// read the admin port refuses with anything but 404 passes through with its status and fault,
/// answers no row and reads no list, so a vendor fault never widens the roots to the manager
/// directory; a restricted purpose whose root-path list then answers 404, removed between the
/// two reads, answers the manager directory alone; and one whose list fails otherwise passes that
/// fault through. Scripted through the seam, so the allow-list is not touched.</p>
/// <p>Mutation (Rule 19): drop the 404 test on the purpose read in
/// <method>OcuPilot.Port.PathPort.Roots</method> -&gt; the 500 and 403 legs answer 200; drop the
/// fallback on the list's 404 -&gt; the race leg answers no row; drop the 404 test on the list
/// read -&gt; the list-fault leg answers the manager directory.</p>
Method TestAVendorFaultPassesThroughAndARemovedPurposeFallsBack()
{
    Set tPort = ..#FIXTURE
    For tHttpScripted = 500, 403 {
        Do $ClassMethod(tPort, "Reset")
        Do $ClassMethod(tPort, "Script", "FSAccess.Purpose", "GET", tHttpScripted, "")
        Set tSC = $ClassMethod(tPort, "Roots", 1000, .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tHttpScripted _ " on the purpose read: the roots fail")
        Do $$$AssertEquals(tHttp, tHttpScripted, tHttpScripted _ " on the purpose read: with the port's own status")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), $ClassMethod(tPort, "ScriptedCode", tHttpScripted), tHttpScripted _ " on the purpose read: and its fault")
        Do $$$AssertTrue('$IsObject(tRows), tHttpScripted _ " on the purpose read: no row is answered")
        Do $$$AssertEquals($ClassMethod(tPort, "Calls"), 1, tHttpScripted _ " on the purpose read: and no list is read")
    }

    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Script", "FSAccess.Purpose", "GET", 200, "{""Restricted"":true}")
    Do $ClassMethod(tPort, "Script", "FSAccess.Path", "LIST", 404, "")
    Do $$$AssertEquals(..RootsOf(tPort), "200|" _ ..ManagerRow(), "a purpose removed between the two reads answers the manager directory alone")
    Do $$$AssertEquals($ClassMethod(tPort, "Calls"), 2, "after both reads")

    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Script", "FSAccess.Purpose", "GET", 200, "{""Restricted"":true}")
    Do $ClassMethod(tPort, "Script", "FSAccess.Path", "LIST", 500, "")
    Set tSC = $ClassMethod(tPort, "Roots", 1000, .tRows, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "500 on the root-path list of a restricted purpose: the roots fail")
    Do $$$AssertEquals(tHttp, 500, "500 on the root-path list: with the port's own status")
    Do $$$AssertTrue('$IsObject(tRows), "500 on the root-path list: no row, never the manager directory")
}

}
