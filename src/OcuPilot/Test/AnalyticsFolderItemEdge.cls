/// <p>Pins the edges of Story 24.10's folder manager (Batch 2: AD-21, AD-54, AD-65) that <class>OcuPilot.Test.AnalyticsFolderItemTransfer</class> does not, against
/// <code>USER</code> and through that class's helpers: an item the caller's resources hide is absent to the export, the delete and the reads, and held to the import; an
/// import file past the text bound is <code>TOOLARGE</code> whether it is read from the server or sent from the browser, and one at the bound is judged by its shape; an
/// import creates the items of its file and leaves every other item as it was; and the import's and the delete's cards name what they act on.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns
/// analytics on in <code>USER</code> and writes folder items and files there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsFolderItemEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter BASE = "OcuPilot.Test.AnalyticsFolderItemTransfer";

Parameter HIDDEN = "OcuPilot.Test.AnalyticsFolderItemHiddenSeam";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter MARKER = "OcuProbeFI2410";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemEdge turns analytics on in USER and writes folder items and files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#BASE, "Sweep")
    Set tSC = $ClassMethod(..#FILES, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#BASE, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemEdge left folder items or folders in USER: " _ $ClassMethod(..#BASE, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#BASE, "Sweep")
    Do $ClassMethod(..#HIDDEN, "Reset")
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Quit $ClassMethod(..#FILES, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#HIDDEN, "Reset")
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Do $ClassMethod(..#BASE, "Sweep")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Quit $$$OK
}

/// <p>The call <var>pType</var> for <var>pId</var> through the seam that can hide an item.</p>
ClassMethod H(pType As %String, pId As %String, pExtra As %DynamicObject, Output pResult, Output pFault, pAction As %String = "") As %String
{
    Quit $ClassMethod(..#BASE, "T", pType, pId, pExtra, .pResult, .pFault, pAction, ..#HIDDEN)
}

/// <p>AC4: an item the caller's resources hide (<code>%FolderItemExists</code> 2) is absent to the export, the delete and the single-object reads, and is a taken name to
/// an import and to the read composed for it: each refusal is made before any vendor call and the globals are as they were. With the item not hidden, the same calls run.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.FolderItemVisible</method> answer 1 for 2 -- the absent legs go red.</p>
Method TestAnItemTheCallerCannotSeeIsAbsentAndItsNameIsTaken()
{
    Set tName = ..#MARKER _ "/Hidden.dashboard"
    Do $$$AssertEquals($ClassMethod(..#BASE, "Item", tName), tName, "the item is saved")
    Set tFile = $ClassMethod(..#BASE, "FileQuery", "hidden.xml")
    Set tText = $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", tName))
    Set tExtra = {"fileName": "h.xml", "content": (tText)}
    Do $$$AssertEquals(..H("EXPORT", tName, "", .tRes, .tFault), "200 ", "while it is not hidden its export runs")
    Do $$$AssertEquals(..H("EXPORTITEM", tName, tFile, .tRes, .tFault), "200 ", "and so does the export's read")
    Do $ClassMethod(..#HIDDEN, "Hide", tName)
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Do $ClassMethod(..#HIDDEN, "Reset")
    Do $$$AssertEquals(..H("EXPORT", tName, "", .tRes, .tFault), "404 ANALYTICS.FOLDERITEM.ABSENT", "hidden, its export is refused as absent")
    Do $$$AssertEquals(..H("EXPORTITEM", tName, tFile, .tRes, .tFault, "EXPORT"), "404 ANALYTICS.FOLDERITEM.ABSENT", "and so is the read composed for the export")
    Do $$$AssertEquals(..H("DELETE", tName, "", .tRes, .tFault), "404 ANALYTICS.FOLDERITEM.ABSENT", "and its delete")
    Do $$$AssertEquals(..H("FOLDERITEM", tName, "", .tRes, .tFault, "DELETE"), "404 ANALYTICS.FOLDERITEM.ABSENT", "and the delete's read")
    Do $$$AssertEquals($Extract(..H("FOLDERITEM", tName, "", .tRes, .tFault), 1, 3) _ $Extract(..H("EXPORTITEM", tName, tFile, .tRes, .tFault), 1, 3), "404404", "and the plain reads find nothing")
    Do tExtra.%Set("digest", ##class(OcuPilot.Port.AnalyticsPort).TextDigest(tText))
    Do $$$AssertEquals(..H("IMPORT", "import", tExtra, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TAKEN", "an import of a file that names it is refused as taken")
    Do $$$AssertEquals(..H("IMPORTFILE", "import", tExtra, .tRes, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TAKEN", "and so is the read composed for it")
    Do $$$AssertEquals($ClassMethod(..#HIDDEN, "Calls") _ "|" _ $ClassMethod(..#BASE, "Snapshot"), "0|" _ tBefore, "no vendor call was made and nothing was written")
}

/// <p>The file text of <var>pPadding</var> spaces after the root of an export of the item <var>pName</var>, so that its length is exactly <var>pLength</var> characters.</p>
ClassMethod Padded(pName As %String, pLength As %Integer) As %String
{
    Set tText = $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", pName))
    Quit tText _ $Justify("", pLength - $Length(tText))
}

/// <p>AC4: an import file longer than <code>AtelierPort.MAXIMPORTCHARACTERS</code> is refused 409 <code>ANALYTICS.FOLDERITEM.TOOLARGE</code>, sent from the browser or
/// read from the server and by the read composed for it, with the globals as they were; a file of exactly the bound is read by its shape.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.FolderItemImportFile</method> pass the term list's too-large code, or drop the bound there -- the over-bound
/// legs go red.</p>
Method TestAnImportFilePastTheTextBoundIsTooLargeAndOneAtTheBoundIsRead()
{
    Set tBound = $Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS")
    Set tName = ..#MARKER _ "/Bound.dashboard"
    Set tOver = ..Padded(tName, tBound + 1)
    Set tAt = ..Padded(tName, tBound)
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Do $$$AssertEquals($Length(tOver) - $Length(tAt), 1, "the two texts differ by one character")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Import", tOver, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "a local file past the bound is too large")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", {"fileName": "o.xml", "content": (tOver)}, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "and so is its composed read")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "over.xml", tOver), "the over-bound file is written to the server")
    Set tServer = $ClassMethod(..#BASE, "FileQuery", "over.xml")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", tServer, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "a server file past the bound is too large")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORT", "import", tServer, .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "and so is the write")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot"), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", {"fileName": "a.xml", "content": (tAt)}, .tRead, .tFault, "IMPORT"), "200 ", "a local file at the bound is read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Count _ "|" _ tRead.Items.%ToJSON(), "1|[""" _ tName _ """]", "by its shape, as one item")
}

/// <p>AC2, AC5: an import creates the items its file holds and nothing else changes: an item the file does not name is held, and exports as it did, after the import.</p>
/// <p>Mutation (Rule 19): make the <code>pKill</code> argument of the vendor's <code>%Import</code> in <method>OcuPilot.Port.AnalyticsPort.VendorFolderItemImport</method> 1 -- the
/// bystander is deleted and this goes red.</p>
Method TestAnImportLeavesEveryOtherItemAsItWas()
{
    Set tBystander = ..#MARKER _ "/Bystander.dashboard"
    Set tName = ..#MARKER _ "/Incoming.dashboard"
    Do $$$AssertEquals($ClassMethod(..#BASE, "Item", tBystander), tBystander, "the bystander is saved")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Item", tName), tName, "and so is the item to import")
    Set tBystanderXml = $ClassMethod(..#BASE, "Exported", tBystander)
    Set tText = $ClassMethod(..#BASE, "Exported", tName)
    Do $ClassMethod(..#BASE, "Drop", tName)
    Do $$$AssertEquals($ClassMethod(..#BASE, "Import", tText, .tRes, .tFault, tName), "200 ", "the import answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tName), 1, "the item is created")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exists", tBystander), 1, "the item the file does not name is held")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Exported", tBystander), tBystanderXml, "and exports as it did")
}

/// <p>AC3, AC4: the import's card lists the file, the items it creates and their count, and a read that names no items is a problem; the delete's card lists the item's
/// name, type and owner, and a read that names no target is a problem. These cards are what the person confirms.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsFolderItemImport.StateDiff</method> push no <code>Items</code> row -- the import's leg goes red.</p>
Method TestTheImportsAndTheDeletesCardsNameWhatTheyActOn()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.AnalyticsFolderItemImport).StateDiff({"path": "a.xml", "Items": ["F/A.dashboard", "B.dashboard"], "Count": 2}, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the import's card is built")
    Do $$$AssertEquals(..Fields(tRows) _ "|" _ tProblem, "File=a.xml;Items=F/A.dashboard, B.dashboard;Count=2|", "it lists the file, the items and the count")
    Set tSC = ##class(OcuPilot.Screen.Tool.AnalyticsFolderItemImport).StateDiff({}, .tRows, .tProblem)
    Do $$$AssertEquals(tRows.%Size() _ "|" _ (tProblem '= ""), "0|1", "a read that names no items is a problem and builds no card")
    Set tSC = ##class(OcuPilot.Screen.Tool.AnalyticsFolderItemDelete).StateDiff({"Name": "F/A.dashboard", "Type": "Dashboard", "Owner": "u", "Namespace": "USER"}, .tRows, .tProblem)
    Do $$$AssertEquals(..Fields(tRows, "before") _ "|" _ tProblem, "Name=F/A.dashboard;Type=Dashboard;Owner=u|", "the delete's card lists the name, the type and the owner")
    Set tSC = ##class(OcuPilot.Screen.Tool.AnalyticsFolderItemDelete).StateDiff({}, .tRows, .tProblem)
    Do $$$AssertEquals(tRows.%Size() _ "|" _ (tProblem '= ""), "0|1", "a read that names no target is a problem and builds no card")
}

/// <p>The rows <var>pRows</var> of a card as <code>field=value</code> pairs joined by <code>;</code>, the value being the row's <var>pMember</var> (<code>after</code> by default).</p>
ClassMethod Fields(pRows As %DynamicArray, pMember As %String = "after") As %String
{
    Set tText = ""
    For tAt = 0:1:pRows.%Size() - 1 {
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ pRows.%Get(tAt).field _ "=" _ pRows.%Get(tAt).%Get(pMember)
    }
    Quit tText
}

}
