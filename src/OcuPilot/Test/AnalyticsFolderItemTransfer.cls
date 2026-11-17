/// <p>Pins Story 24.10's folder manager (Batch 2: AD-21, AD-54, AD-65) against <code>USER</code>, with analytics on through
/// <class>OcuPilot.Test.AnalyticsProbe</class>, folder items named with this class's own marker and server files in
/// <class>OcuPilot.Test.ExplorerTransferProbe</class>'s directory. The port legs are the story's matrix through
/// <class>OcuPilot.Test.AnalyticsTermListSeam</class>, which counts the vendor calls: an export to a file and to the browser, the round trip, the classic
/// page's file, a file that holds more than folder items, a taken name, a file that changed after its review, an import that fails after the vendor
/// returned, a delete and its refusals, a path that is refused, each write's script form and OcuPilot's own audit rows. The route legs drive both callers
/// over HTTP: the person's Export, Import and Delete, and the agent's three proposals, minted and confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in
/// <code>USER</code> and writes folder items and files there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsFolderItemTransfer Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter NAMESPACE = "USER";

/// <p>The prefix of every item and folder this class makes: a folder of this name, or a root item whose name starts with it.</p>
Parameter MARKER = "OcuProbeFI2410";

Parameter ITEMS = "/screens/analytics.folderitems/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemTransfer turns analytics on in USER and writes folder items and files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the items, the folders and the directory; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Sweep()
    Set tSC = $ClassMethod(..#FILES, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemTransfer left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && (..Marked() '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemTransfer left folder items or folders in USER: " _ ..Marked())
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..Sweep()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $ClassMethod(..#FILES, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Sweep()
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Delete every item whose name starts with the marker, hidden ones too, then every folder of that name, deepest first, in <code>USER</code>.</p>
ClassMethod Sweep()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%DeepSee.UserLibrary.Utils).%GetFolderItemList(.tIds, "", 1, "")
        Set tAt = ""
        For {
            Set tAt = $Order(tIds(tAt))
            If tAt = "" Quit
            Set tItem = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(tIds(tAt))
            If $IsObject(tItem) && ($ZConvert($Extract(tItem.fullName, 1, $Length(..#MARKER)), "U") = $ZConvert(..#MARKER, "U")) Do ##class(%DeepSee.UserLibrary.FolderItem).%DeleteId(tIds(tAt))
            Set tItem = ""
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID FROM %DeepSee_UserLibrary.Folder WHERE folder IS NOT NULL OR name %STARTSWITH ? ORDER BY LENGTH(%ID) DESC", ..#MARKER)
        While tRS.%Next() {
            If ##class(%DeepSee.UserLibrary.Folder).%ExistsId(tRS.%GetData(1)) Do ##class(%DeepSee.UserLibrary.Folder).%DeleteId(tRS.%GetData(1))
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The items and folders this class made that remain in <code>USER</code>, comma-separated.</p>
ClassMethod Marked() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tNames = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%DeepSee.UserLibrary.Utils).%GetFolderItemList(.tIds, "", 1, "")
        Set tAt = ""
        For {
            Set tAt = $Order(tIds(tAt))
            If tAt = "" Quit
            Set tItem = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(tIds(tAt))
            If $IsObject(tItem) && ($ZConvert($Extract(tItem.fullName, 1, $Length(..#MARKER)), "U") = $ZConvert(..#MARKER, "U")) Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tItem.fullName
            Set tItem = ""
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID FROM %DeepSee_UserLibrary.Folder WHERE name %STARTSWITH ?", ..#MARKER)
        While tRS.%Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ "folder " _ tRS.%GetData(1)
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>Every node of the item and folder globals, as one string, so that "nothing was written" is a comparison.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tGlobal = "^DeepSee.FolderItemD", "^DeepSee.FolderD" {
            Set tRef = tGlobal
            Set tNode = $Query(@tRef@(""))
            While tNode '= "" {
                Set tText = tText _ tNode _ "=" _ $Get(@tNode) _ $Char(10)
                Set tNode = $Query(@tNode)
            }
        }
    } Catch ex {
        Set tText = "unreadable " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>The call <var>pType</var> on the folder items for <var>pId</var> through the seam port, with the query members of <var>pExtra</var> added, as
/// <code>&lt;http&gt; &lt;code&gt;</code>; the answer is in <var>pResult</var>, the fault in <var>pFault</var>. <var>pAction</var> composes a read for that write, and <var>pSeam</var> names another port subclass than <parameter>SEAM</parameter>.</p>
ClassMethod T(pType As %String, pId As %String, pExtra As %DynamicObject, Output pResult, Output pFault, pAction As %String = "", pSeam As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod($Select(pSeam = "": ..#SEAM, 1: pSeam), "Invoke", "FolderItems", pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The dashboard <var>pName</var> (its full name, folder and extension) with a title holding a double quote, an ampersand, a less-than sign and an accented
/// letter, saved in <code>USER</code>; the item's full name as stored, or <code>""</code>.</p>
ClassMethod Item(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tStored = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tItem = ##class(%DeepSee.Dashboard.Definition).%New()
        Set tItem.fullName = pName
        Set tItem.title = "T " _ $Char(34) _ "q" _ $Char(34) _ " & <b> " _ $Char(233)
        If $$$ISOK(tItem.%Save()) Set tStored = tItem.fullName
    } Catch {
        Set tStored = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tStored
}

/// <p>The vendor's own XML of the item <var>pName</var>, as <code>%Export</code> writes it to a stream, <code>""</code> when it is not held.</p>
ClassMethod Exported(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        If $$$ISOK(##class(%DeepSee.UserLibrary.Utils).%Export(pName, tStream, 0)) {
            Do tStream.Rewind()
            Set tText = tStream.Read(3000000)
        }
    } Catch {
        Set tText = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>What <code>%FolderItemExists</code> answers for <var>pName</var> in <code>USER</code>.</p>
ClassMethod Exists(pName As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tCode = ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(pName)
    Set $NAMESPACE = tOrigNS
    Quit tCode
}

/// <p>The classic Folder Manager's export of the items <var>pNames</var> (a comma-separated list of root-level items, whose document names hold no
/// <code>-</code>), as <code>$System.OBJ.ExportToStream</code> writes it.</p>
ClassMethod ClassicText(pNames As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tList = ""
        For tAt = 1:1:$Length(pNames, ",") {
            Set tList = tList _ $Select(tList = "": "", 1: ",") _ $Piece(pNames, ",", tAt) _ ".DFI"
        }
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = $System.OBJ.ExportToStream(tList, tStream, "/diffexport=0 /displaylog=0 /displayerror=0")
        Do tStream.Rewind()
        Set tText = tStream.Read(3000000)
    } Catch {
        Set tText = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p><var>pText</var> with carriage returns and trailing line ends removed, so two exports compare by their lines.</p>
ClassMethod Plain(pText As %String) As %String
{
    Quit $ZStrip($Replace(pText, $Char(13), ""), ">", $Char(10))
}

/// <p>The server file <var>pName</var> as the query members that name it.</p>
ClassMethod FileQuery(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#FILES, "Root")), "path": ($ClassMethod(..#FILES, "RelativeName", pName))}
}

/// <p>The lines of <var>pText</var>, as an array.</p>
ClassMethod LinesOf(pText As %String) As %DynamicArray
{
    Quit ##class(OcuPilot.Port.AtelierPort).Lines(pText)
}

/// <p>The reviewed digest of the import the query <var>pExtra</var> names, from the port's read.</p>
ClassMethod DigestOf(pExtra As %DynamicObject) As %String
{
    Set tStatus = ..T("IMPORTFILE", "import", pExtra, .tRead, .tFault, "IMPORT")
    If $IsObject(tRead) Quit tRead.Digest
    Quit ""
}

/// <p>The import of the local text <var>pText</var>, reviewed first, through the port; the answer in <var>pResult</var>.</p>
ClassMethod Import(pText As %String, Output pResult, Output pFault, pId As %String = "import") As %String
{
    Set tExtra = {"fileName": "a.xml", "content": (pText)}
    Do tExtra.%Set("digest", ##class(OcuPilot.Port.AnalyticsPort).TextDigest(pText))
    Quit ..T("IMPORT", pId, tExtra, .pResult, .pFault)
}

/// <p>The count of <code>ConfigChange</code> rows of the item <var>pId</var> with the verb <var>pVerb</var> since <var>pSince</var>.</p>
ClassMethod Rows(pSince As %String, pId As %String, pVerb As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "AuditRows", pSince, "folder-item", pId, pVerb, .tData)
}

/// <p>A person's route <var>pPath</var> with <var>pBody</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %Integer
{
    Do $ClassMethod(..#CONTROL, "CallWide", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The person's screen action <var>pAction</var> on <var>pId</var> with the values <var>pValues</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Quit ..Post(..#ITEMS, tBody, .pAnswer)
}

/// <p>Confirm <var>pProposal</var> over HTTP: the answer in <var>pAnswer</var>, the status returned.</p>
ClassMethod Confirm(pProposal, Output pAnswer, Output pRaw) As %Integer
{
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>AC1: an export writes the vendor's XML to a server file and, with no file, answers its lines to the browser, which are the file's. The answers carry
/// the file or the lines and nothing else; the item's title holds a double quote, an ampersand, a less-than sign and an accented letter, which the XML
/// escapes and the file holds in UTF-8; an item that is not there is refused.</p>
/// <p>Mutation (Rule 19): skip the file in <method>OcuPilot.Port.AnalyticsPort.VendorFolderItemExport</method> (export through the stream whatever the file) -- the file leg
/// goes red.</p>
Method TestAnExportWritesTheVendorsXmlToAFileAndToTheBrowser()
{
    Set tName = ..#MARKER _ "/Export.dashboard"
    Do $$$AssertEquals(..Item(tName), tName, "the item is saved")
    Set tFile = ..FileQuery("a.xml")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the export to a file answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Namespace _ "|" _ tRes.root _ "|" _ tRes.path _ "|" _ tRes.%GetTypeOf("lines"), tName _ "|USER|" _ tFile.root _ "|" _ tFile.path _ "|unassigned", "its answer names the file and holds no lines")
    Set tText = $ClassMethod(..#FILES, "ReadFile", "a.xml")
    Set tQuote = $Char(34)
    Do $$$AssertTrue(tText [ ("title=" _ tQuote _ "T &quot;q&quot; &amp; &lt;b&gt; " _ $Char(233) _ tQuote), "the file holds the item's XML, its title escaped and in UTF-8")
    Do $$$AssertEquals(..Plain($Piece(tText, $Char(10), 2, *)), ..Plain(..Exported(tName)), "and the rest of it is the vendor's own export")
    Do $$$AssertEquals(..T("EXPORT", tName, "", .tBrowser, .tFault), "200 ", "the export to the browser answers 200")
    If $IsObject(tBrowser) {
        Do $$$AssertEquals(tBrowser.%GetTypeOf("root") _ "|" _ tBrowser.%GetTypeOf("lines"), "unassigned|array", "its answer holds lines and no file")
        Do $$$AssertEquals(tBrowser.lines.%ToJSON(), ..LinesOf(tText).%ToJSON(), "and the lines are the file's lines")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 2, "each export made one vendor call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("EXPORT", ..#MARKER _ "/Gone.dashboard", tFile, .tRes, .tFault), "404 ANALYTICS.FOLDERITEM.ABSENT", "an item that is not there is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "before any vendor call")
}

/// <p>AC1: an export to the browser past the text bound is refused <code>TOOLARGE</code>, and one to a file is not.</p>
/// <p>Mutation (Rule 19): drop the bound in <method>OcuPilot.Port.AnalyticsPort.VendorFolderItemExport</method> -- the refusal leg goes red.</p>
Method TestAnExportToTheBrowserPastTheTextBoundIsRefused()
{
    Set tName = ..#MARKER _ "Large.theme"
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tTheme = ##class(%DeepSee.Dashboard.Theme).%New()
    Set tTheme.fullName = tName
    For tAt = 1:1:110 {
        Do tTheme.overrides.SetAt($Translate($Justify("", 30000), " ", "x"), "k" _ tAt)
    }
    Set tSC = tTheme.%Save()
    Set tTheme = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "a theme of 110 overrides of 30,000 characters is saved")
    Do $$$AssertEquals(..T("EXPORT", tName, "", .tBrowser, .tFault), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "the browser's export past 3,000,000 characters is refused")
    Do $$$AssertEquals(..T("EXPORT", tName, ..FileQuery("big.xml"), .tFileRes, .tFault), "200 ", "the same item exports to a file")
}

/// <p>Delete the item <var>pName</var> through the vendor, in <code>USER</code>.</p>
ClassMethod Drop(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Do ##class(%DeepSee.UserLibrary.Utils).%DeleteFolderItem(pName)
    Set $NAMESPACE = tOrigNS
}

/// <p>One <code>Document</code> of the classic page's export holding the empty dashboard <var>pName</var> (full name), as a hand-made file may.</p>
ClassMethod Doc(pName As %String) As %String
{
    Set tFolder = $Piece(pName, "/", 1, $Length(pName, "/") - 1)
    Set tBase = $Piece(pName, "/", $Length(pName, "/"))
    Quit "<Document name=""" _ $Translate(pName, "/", "-") _ ".DFI""><dashboard xmlns=""http://www.intersystems.com/deepsee/library"" name=""" _ $Piece(tBase, ".", 1, $Length(tBase, ".") - 1) _ """ folderName=""" _ tFolder _ """/></Document>"
}

/// <p>An <code>Export</code> file holding <var>pBody</var>, as the classic page writes it.</p>
ClassMethod Wrap(pBody As %String) As %String
{
    Quit "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Export generator=""IRIS"" version=""26"">" _ pBody _ "</Export>"
}

/// <p>Whether <var>pClass</var> is defined in <code>USER</code>.</p>
ClassMethod ClassDefined(pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tHas = ##class(%Dictionary.ClassDefinition).%ExistsId(pClass)
    Set $NAMESPACE = tOrigNS
    Quit tHas
}

/// <p>AC2: export an item, delete it and import the export from the server file; the vendor's export of the re-created item equals the first, the import's
/// read names the item and the count first, and a second read finds the name taken.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.VendorFolderItemImport</method> answer OK without calling <code>%Import</code> -- the round trip and the
/// classic-file legs go red.</p>
Method TestAnExportImportsBackAsTheSameItem()
{
    Set tName = ..#MARKER _ "/Round/Trip.dashboard"
    Do ..Item(tName)
    Set tFile = ..FileQuery("round.xml")
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the item exports")
    Set tFirst = ..Exported(tName)
    Do $$$AssertTrue(tFirst [ "name=""Trip""", "and the vendor reads it")
    Do $$$AssertEquals(..T("DELETE", tName, "", .tRes, .tFault), "200 ", "the item is deleted")
    Do $$$AssertEquals(..Exists(tName), 0, "and is gone")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tFile, .tRead, .tFault, "IMPORT"), "200 ", "the import's read answers: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Items.%ToJSON() _ "|" _ tRead.Count _ "|" _ tRead.Present, "[""" _ tName _ """]|1|0", "it names the item the file holds, how many, and that none is held")
    Do tFile.%Set("digest", tRead.Digest)
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "200 ", "the import answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Count _ "|" _ tRes.Namespace _ "|" _ tRes.Type, tName _ "|1|USER|Dashboard", "its answer is the item read again, and the count")
    Do $$$AssertEquals(..Exported(tName), tFirst, "the vendor's export of the re-created item equals the first")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tFile, .tAgain, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TAKEN", "and a second import's read finds the name taken")
}

/// <p>AC2: the classic page's export of two items imports from a local file; each re-created item's export equals its first.</p>
Method TestTheClassicPagesFileImportsBothItems()
{
    Set tA = ..#MARKER _ "ClassicA.dashboard"
    Set tB = ..#MARKER _ "ClassicB.dashboard"
    Do ..Item(tA)
    Do ..Item(tB)
    Set tText = ..ClassicText(tA _ "," _ tB)
    Do $$$AssertEquals($Length(tText, "<Document name=") - 1, 2, "the classic export holds two documents")
    Set tFirstA = ..Exported(tA)
    Set tFirstB = ..Exported(tB)
    Do ..Drop(tA)
    Do ..Drop(tB)
    Do $$$AssertEquals(..Import(tText, .tRes, .tFault, tA), "200 ", "the import of the classic file answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Count, 2, "it created two items")
    Do $$$AssertEquals(..Exported(tA) _ "|" _ ..Exported(tB), tFirstA _ "|" _ tFirstB, "and each equals its first export")
}

/// <p>AC4, AC5: a file that holds more than folder items, or none, or something the import cannot read as one, is refused <code>IMPORTSHAPE</code> by the write and by
/// the read composed for it, before any vendor call. No class of the file is defined, no item is created, and the globals are as they were. A file of 101 items is
/// <code>TOOLARGE</code>.</p>
/// <p>Mutation (Rule 19): admit a <code>Class</code> child in <method>OcuPilot.Port.AnalyticsPort.FolderItemsInText</method> (treat any element as an item) -- the mixed-file leg goes red.</p>
Method TestAFileThatHoldsMoreThanFolderItemsCreatesNothing()
{
    Set tOne = ..#MARKER _ "Mix.dashboard"
    Set tEvil = "<Document name=""" _ ..#MARKER _ "Evil.cls""><Class name=""" _ ..#MARKER _ "Evil""><Super>%RegisteredObject</Super></Class></Document>"
    Set tLib = " xmlns=""http://www.intersystems.com/deepsee/library"""
    Set tMany = ""
    For tAt = 1:1:101 {
        Set tMany = tMany _ ..Doc(..#MARKER _ "Many" _ tAt _ ".dashboard")
    }
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    For tCase = $ListBuild("a class and an item", ..Wrap(tEvil _ ..Doc(tOne))), $ListBuild("a class alone", ..Wrap(tEvil)), $ListBuild("no document", ..Wrap("")), $ListBuild("a folder", "<folder" _ tLib _ " name=""" _ ..#MARKER _ "Dir""/>"), $ListBuild("a document of another type", ..Wrap("<Document name=""x.LUT""><lookupTable/></Document>")), $ListBuild("a document with no item", ..Wrap("<Document name=""a.dashboard.DFI""></Document>")), $ListBuild("a document with two items", ..Wrap($Replace(..Doc(tOne), "</Document>", "<dashboard" _ tLib _ " name=""Other"" folderName=""""/></Document>"))), $ListBuild("one item twice, in two cases", ..Wrap(..Doc(tOne) _ ..Doc($ZConvert(tOne, "U")))), $ListBuild("an item outside the library namespace", "<dashboard name=""" _ ..#MARKER _ "Ns"" folderName=""""/>"), $ListBuild("an item with no name", "<dashboard" _ tLib _ " folderName=""""/>"), $ListBuild("a document type definition", "<!DOCTYPE dashboard [<!ENTITY e ""x"">]><dashboard" _ tLib _ " name=""" _ ..#MARKER _ "Dtd"" folderName=""""/>"), $ListBuild("text that is no XML", "not a folder item") {
        Do $$$AssertEquals(..Import($List(tCase, 2), .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", $List(tCase, 1) _ " is refused")
        Set tExtra = {"fileName": "a.xml", "content": ($List(tCase, 2))}
        Do $$$AssertEquals(..T("IMPORTFILE", "import", tExtra, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", $List(tCase, 1) _ " is refused by the read composed for the import")
    }
    Do $$$AssertEquals(..Import(..Wrap(tMany), .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "a file of 101 items is too large")
    Do $$$AssertEquals(..Import(..Wrap(..Doc(tOne)), .tRes, .tFault, "Other.dashboard"), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", "and so is a file whose first item is not the one named")
    Do $$$AssertEquals(..ClassDefined(..#MARKER _ "Evil"), 0, "the class the mixed file names is not defined")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "and nothing was written and no vendor call was made")
}

/// <p>AC4: an item of the file held in another letter case refuses the whole import <code>TAKEN</code>, before any write, and the read composed for it too; a
/// file rewritten after its review, or sent with no reviewed digest, is refused <code>IMPORTCHANGED</code>.</p>
/// <p>Mutation (Rule 19): make the taken check of <method>OcuPilot.Port.AnalyticsPort.PerformFolderImport</method> <code>If 0</code> -- the taken leg goes red; skip the digest
/// comparison there -- the changed leg goes red.</p>
Method TestATakenNameAndAChangedFileWriteNothing()
{
    Set tHeld = ..#MARKER _ "/Held.dashboard"
    Do ..Item(tHeld)
    Set tText = ..Wrap(..Doc(..#MARKER _ "/Free.dashboard") _ ..Doc(..#MARKER _ "/HELD.dashboard"))
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Import(tText, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TAKEN", "an import of a file that names a held item in another case is refused")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", {"fileName": "a.xml", "content": (tText)}, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TAKEN", "and so is its read composed for the import")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", {"fileName": "a.xml", "content": (tText)}, .tRead, .tFault), "200 ", "while the plain read answers")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Count _ "|" _ tRead.Present, "2|1", "naming both items and that one is held")
    Do $$$AssertEquals(..Snapshot() _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "nothing was written and no vendor call was made")
    Set tName = ..#MARKER _ "/Moved.dashboard"
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "c.xml", ..Wrap(..Doc(tName))), "the file is written")
    Set tFile = ..FileQuery("c.xml")
    Do tFile.%Set("digest", ..DigestOf(tFile))
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "c.xml", ..Wrap(..Doc(tName) _ ..Doc(..#MARKER _ "/Moved2.dashboard"))), "the file is rewritten")
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.IMPORTCHANGED", "the write is refused")
    Do tFile.%Remove("digest")
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.IMPORTCHANGED", "and so is one that names no reviewed file")
    Do $$$AssertEquals(..Exists(tName) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "0|0", "nothing was created and no vendor call was made")
}

/// <p>AC4: the seam answers an error after the vendor's import of a two-item file into a new folder has returned: the write fails, no item and no new folder remain,
/// no transaction is left open and nothing is audited.</p>
/// <p>Mutation (Rule 19): make the <code>TROLLBACK</code> of <method>OcuPilot.Port.AnalyticsPort.PerformFolderImport</method> a <code>TCOMMIT</code> -- this goes red.</p>
Method TestAnImportThatFailsAfterTheVendorReturnedLeavesNothing()
{
    Set tText = ..Wrap(..Doc(..#MARKER _ "/NewDir/One.dashboard") _ ..Doc(..#MARKER _ "/NewDir/Two.dashboard"))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "failimport")
    Do $$$AssertEquals($Extract(..Import(tText, .tRes, .tFault), 1, 3), "500", "the import answers its failure")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "after one vendor call")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no item and no folder remain")
    Do $$$AssertEquals($TLevel, 0, "and no transaction is left open")
    Do $$$AssertEquals(..Rows(tSince, ..#MARKER _ "/NewDir/One.dashboard", "analytics.folderitems.import"), 0, "and nothing was audited")
}

/// <p>AC3, AC4: a delete removes an unlocked item, which then reads gone; a locked item and an item that is not there are refused before any vendor call, by the
/// write and by the read composed for it, and the globals are as they were.</p>
/// <p>Mutation (Rule 19): skip the <code>VendorFolderItemDelete</code> call in <method>OcuPilot.Port.AnalyticsPort.PerformFolderDelete</method> -- the delete leg goes red.</p>
Method TestADeleteRemovesAnUnlockedItemAndRefusesALockedOrAbsentOne()
{
    Set tName = ..#MARKER _ "/Del.dashboard"
    Set tLocked = ..#MARKER _ "/Locked.dashboard"
    Do ..Item(tName)
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tItem = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tItem.fullName = tLocked
    Set tItem.locked = 1
    Do tItem.%Save()
    Set tItem = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(..Exists(tLocked), 3, "the locked item reads locked")
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("DELETE", tLocked, "", .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.LOCKED", "a locked item is refused")
    Do $$$AssertEquals(..T("FOLDERITEM", tLocked, "", .tRead, .tFault, "DELETE"), "409 ANALYTICS.FOLDERITEM.LOCKED", "and so is its read composed for the delete")
    Do $$$AssertEquals(..T("FOLDERITEM", tLocked, "", .tRead, .tFault), "200 ", "while the plain read answers")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Name _ "|" _ tRead.Locked _ "|" _ tRead.Type, tLocked _ "|1|Dashboard", "with its name, lock and type")
    Do $$$AssertEquals(..T("DELETE", ..#MARKER _ "/None.dashboard", "", .tRes, .tFault), "404 ANALYTICS.FOLDERITEM.ABSENT", "an item that is not there is refused")
    Do $$$AssertEquals(..T("FOLDERITEM", ..#MARKER _ "/None.dashboard", "", .tRead, .tFault, "DELETE"), "404 ANALYTICS.FOLDERITEM.ABSENT", "and so is its read composed for the delete")
    Do $$$AssertEquals(..T("FOLDERITEM", ..#MARKER _ "/None.dashboard", "", .tRead, .tFault), "404 PORT.NOTFOUND", "a plain read answers the port's not found")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made")
    Do $$$AssertEquals(..Snapshot() _ "|" _ ..Exists(tLocked), tBefore _ "|3", "and nothing was deleted")
    Do $$$AssertEquals(..T("DELETE", tName, "", .tRes, .tFault), "200 ", "an unlocked item is deleted: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Exists(tName), 0, "and the vendor reads it gone")
    Do $$$AssertEquals(..T("FOLDERITEM", tName, "", .tRead, .tFault), "404 PORT.NOTFOUND", "so does the read-back")
}

/// <p>AC4: a <code>root</code> that is not allowed and a <code>path</code> with <code>..</code> are refused by PathPort on their field, an export's before the vendor
/// call and an import's before the file is read; a directory that does not exist is refused.</p>
Method TestAPathThatIsNotAllowedIsRefusedOnItsField()
{
    Set tName = ..#MARKER _ "Path.dashboard"
    Do ..Item(tName)
    Do $ClassMethod(..#SEAM, "Reset")
    Set tRoot = $ClassMethod(..#FILES, "Root")
    Do $$$AssertEquals($Extract(..T("EXPORT", tName, {"root": "/nowhere/", "path": "a.xml"}, .tRes, .tFault), 1, 9), "400 PATH.", "an export to a root that is not allowed is refused by PathPort")
    If $IsObject(tFault) && $IsObject(tFault.detail) && $IsObject(tFault.detail.violations) Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "root", "on the root")
    Do $$$AssertEquals($Extract(..T("EXPORT", tName, {"root": (tRoot), "path": "../a.xml"}, .tRes, .tFault), 1, 9), "400 PATH.", "an export to a path with .. is refused")
    If $IsObject(tFault) && $IsObject(tFault.detail) && $IsObject(tFault.detail.violations) Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "path", "on the path")
    Do $$$AssertEquals(..T("EXPORT", tName, {"root": (tRoot), "path": "NoSuchDirectory/a.xml"}, .tRes, .tFault), "409 EXPLORER.EXPORT.DIRECTORY", "an export into a directory that does not exist is refused")
    Do $$$AssertEquals($Extract(..T("IMPORT", "import", {"root": "/nowhere/", "path": "a.xml"}, .tRes, .tFault), 1, 9), "400 PATH.", "an import from a root that is not allowed is refused")
    Do $$$AssertEquals($Extract(..T("IMPORTFILE", "import", {"root": (tRoot), "path": "../a.xml"}, .tRes, .tFault), 1, 9), "400 PATH.", "and from a path with ..")
    Do $$$AssertEquals(..T("IMPORT", "import", {"root": (tRoot), "path": "a.xml", "fileName": "a.xml", "content": "x"}, .tRes, .tFault), "400 PORT.VALIDATION", "and both a server file and a local one")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made")
}

/// <p>Run the script steps <var>pSteps</var> in <code>USER</code>, one line at a time, rolling back a transaction a failed script left open; 1 when the script's own
/// <code>tSC</code> reads OK at the end. The script's variables are public, so they are read by indirection.</p>
ClassMethod RunScript(pSteps As %DynamicArray) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tLevel = $TLevel
    XECUTE "Kill tSC"
    Try {
        Set tText = pSteps.%Get(0).text
        For tAt = 1:1:$Length(tText, $Char(10)) {
            Set tLine = $Piece(tText, $Char(10), tAt)
            If tLine '= "" XECUTE tLine
        }
    } Catch {
    }
    While $TLevel > tLevel {
        TROLLBACK 1
    }
    Set $NAMESPACE = tOrigNS
    Quit ''$System.Status.IsOK($Get(@"tSC"))
}

/// <p>The script steps of the write <var>pType</var> of <var>pId</var> with the query members of <var>pExtra</var>.</p>
ClassMethod Script(pType As %String, pId As %String, pExtra As %DynamicObject = "") As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Quit ##class(OcuPilot.Port.AnalyticsPort).Snippet("FolderItems", pType, .tQuery)
}

/// <p>AC7: each write's script form, run in <code>USER</code>, makes the change the write makes: a delete removes the item, an export writes the file the write
/// would, and an import creates the items of its server file; a script whose item is not there or is locked, whose name is taken, whose file is not the reviewed text
/// or holds another first item, or whose file the write would refuse, only sets the refusal. An import of a local text has no script form.</p>
/// <p>Mutation (Rule 19): drop the <code>%DeleteFolderItem</code> call from <method>OcuPilot.Port.AnalyticsPort.FolderItemSnippet</method> -- the delete leg goes red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tName = ..#MARKER _ "/Script.dashboard"
    Do ..Item(tName)
    Do $$$AssertEquals(##class(OcuPilot.Port.AnalyticsPort).SnippetForm("FolderItems", "DELETE") _ "|" _ ##class(OcuPilot.Port.AnalyticsPort).SnippetForm("FolderItems", "IMPORT") _ "|" _ ##class(OcuPilot.Port.AnalyticsPort).SnippetForm("FolderItems", "FOLDERITEM"), "objectscript|objectscript|", "the three writes have a script form and a read has none")
    Set tFile = ..FileQuery("script.xml")
    Do $$$AssertEquals(..RunScript(..Script("EXPORT", tName, tFile)), 1, "the export's script runs")
    Do $$$AssertTrue($ClassMethod(..#FILES, "FileExists", "script.xml") && ($ClassMethod(..#FILES, "ReadFile", "script.xml") [ "name=""Script"""), "and writes the file under the allowed directory")
    Do $$$AssertEquals(..RunScript(..Script("EXPORT", tName, {"root": (tFile.root), "path": "../x.xml"})), 0, "a file the write would refuse only sets the refusal")
    Do $$$AssertTrue(..Script("EXPORT", tName).%Get(0).text [ "tStream.OutputToDevice()", "and with no file it writes the XML to the current device")
    Do $$$AssertEquals(..RunScript(..Script("EXPORT", ..#MARKER _ "/None.dashboard", tFile)), 0, "an export of an item that is not there only sets the refusal")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName)), 1, "the delete's script runs")
    Do $$$AssertEquals(..Exists(tName), 0, "and removes the item")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName)), 0, "a second run is refused: the item is not there")
    Set tReview = {"root": (tFile.root), "path": (tFile.path)}
    Do tReview.%Set("digest", "0")
    Do $$$AssertEquals(..RunScript(..Script("IMPORT", "import", tReview)), 0, "an import whose file is not the reviewed text only sets the refusal")
    Do tReview.%Set("digest", ..DigestOf(tFile))
    Do $$$AssertEquals(..RunScript(..Script("IMPORT", "Other.dashboard", tReview)), 0, "and so does one whose first item is not the one named")
    Do $$$AssertEquals(..Exists(tName), 0, "neither creates the item")
    Do $$$AssertEquals(..RunScript(..Script("IMPORT", "import", tReview)), 1, "the import's script runs")
    Do $$$AssertEquals(..Exists(tName), 1, "and creates the item the file holds")
    Do $$$AssertEquals(..RunScript(..Script("IMPORT", "import", tReview)), 0, "a second run is refused: the name is taken")
    Set tLocal = ..Wrap(..Doc(..#MARKER _ "/ScriptLocal.dashboard"))
    Do $$$AssertEquals(..Script("IMPORT", "import", {"fileName": "a.xml", "content": (tLocal), "digest": (##class(OcuPilot.Port.AnalyticsPort).TextDigest(tLocal))}).%Size(), 0, "an import of a local text that reads as folder items has no script form")
    Do $$$AssertEquals(..RunScript(..Script("IMPORT", "import", {"fileName": "a.xml", "content": "x", "digest": "0"})), 0, "and one that does not only sets the refusal")
    Set tLocked = ..#MARKER _ "/ScriptLocked.dashboard"
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tItem = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tItem.fullName = tLocked
    Set tItem.locked = 1
    Do tItem.%Save()
    Set tItem = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tLocked)) _ "|" _ ..Exists(tLocked), "0|3", "a locked item's script only sets the refusal and leaves it")
}

/// <p>AC7: each write leaves one <code>ConfigChange</code> row of OcuPilot's own, naming its tool and the item, and never a definition.</p>
/// <p>Mutation (Rule 19): drop the <code>AuditWrite</code> of <method>OcuPilot.Port.AnalyticsPort.PerformFolderExport</method> -- the export leg goes red.</p>
Method TestEachWriteIsAudited()
{
    Set tName = ..#MARKER _ "/Audit.dashboard"
    Do ..Item(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tFile = ..FileQuery("audit.xml")
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the export runs")
    Do $$$AssertEquals(..T("DELETE", tName, "", .tRes, .tFault), "200 ", "the delete runs")
    Do tFile.%Set("digest", ..DigestOf(tFile))
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "200 ", "the import runs")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.folderitems.export"), 1, "one audit row names the export")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.folderitems.delete"), 1, "one audit row names the delete")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.folderitems.import"), 1, "one audit row names the import and its first item")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", "&lt;b&gt;", .tMarker), 0, "and none holds a title")
}

}
