/// <p>Pins the bounds of Story 24.10's folder item import file (Batch 2: AD-21, AD-54, AD-65) that <class>OcuPilot.Test.AnalyticsFolderItemTransfer</class> does not, against
/// <code>USER</code> and through that class's helpers. A file of exactly <parameter>OcuPilot.Port.AnalyticsPort:MAXIMPORTITEMS</parameter> items is read, and one of one more is
/// <code>TOOLARGE</code> from a local file, from a server file and by the read composed for the import. An item name the vendor cannot address (one holding a slash or a control
/// character, or a name or folder past <parameter>OcuPilot.Port.AnalyticsPort:NAMEMAX</parameter> characters) is <code>IMPORTSHAPE</code>, with the globals as they were; one at
/// the bound, and a document named <code>.dfi</code> in lower case, is read. Every leg reads only: nothing is imported.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns
/// analytics on in <code>USER</code> and writes server files there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsFolderItemBounds Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter BASE = "OcuPilot.Test.AnalyticsFolderItemTransfer";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter MARKER = "OcuProbeFI2410";

Parameter LIBRARY = "http://www.intersystems.com/deepsee/library";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemBounds turns analytics on in USER and writes server files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemBounds left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#BASE, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemBounds left folder items or folders in USER: " _ $ClassMethod(..#BASE, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#BASE, "Sweep")
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $ClassMethod(..#FILES, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#BASE, "Sweep")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Quit $$$OK
}

/// <p>An export file of <var>pCount</var> empty dashboards named with the marker, in the classic page's form.</p>
ClassMethod Many(pCount As %Integer) As %String
{
    Set tBody = ""
    For tAt = 1:1:pCount {
        Set tBody = tBody _ $ClassMethod(..#BASE, "Doc", ..#MARKER _ "Cap" _ tAt _ ".dashboard")
    }
    Quit $ClassMethod(..#BASE, "Wrap", tBody)
}

/// <p>A file whose root is one dashboard named <var>pName</var> in the folder <var>pFolder</var>, as the export writes it; both are XML attribute text.</p>
ClassMethod Raw(pName As %String, pFolder As %String) As %String
{
    Quit "<dashboard xmlns=""" _ ..#LIBRARY _ """ name=""" _ pName _ """ folderName=""" _ pFolder _ """/>"
}

/// <p>The marker followed by letters, <var>pLength</var> characters in all, so that a name of exactly the bound can be made and whatever a failing run creates is swept.</p>
ClassMethod Letters(pLength As %Integer) As %String
{
    Quit ..#MARKER _ $Translate($Justify("", pLength - $Length(..#MARKER)), " ", "n")
}

/// <p>The read of the local text <var>pText</var> as <var>pAction</var> composes it (<code>""</code> for the plain read), as <code>&lt;http&gt; &lt;code&gt;</code>.</p>
ClassMethod Read(pText As %String, Output pRead, pAction As %String = "") As %String
{
    Quit $ClassMethod(..#BASE, "T", "IMPORTFILE", "import", {"fileName": "b.xml", "content": (pText)}, .pRead, .tFault, pAction)
}

/// <p>AC4: a file of exactly 100 items is read, whether it is sent from the browser or read from the server, and a file of 101 is refused 409
/// <code>ANALYTICS.FOLDERITEM.TOOLARGE</code> by the plain read, by the read composed for the import, from a server file, and by the write. Nothing is written and no vendor call is made.</p>
/// <p>Mutation (Rule 19): make the bound of <method>OcuPilot.Port.AnalyticsPort.FolderItemsInText</method> <code>MAXIMPORTITEMS - 1</code> -- the 100-item legs go red; make it
/// <code>MAXIMPORTITEMS + 1</code> -- the 101-item legs go red.</p>
Method TestAFileOfOneHundredItemsIsReadAndOneOfOneHundredAndOneIsTooLarge()
{
    Set tMax = $Parameter(..#PORT, "MAXIMPORTITEMS")
    Do $$$AssertEquals(tMax, 100, "the bound is one hundred items")
    Set tAt = ..Many(tMax)
    Set tOver = ..Many(tMax + 1)
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Do $$$AssertEquals(..Read(tAt, .tRead), "200 ", "a local file of 100 items is read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Count _ "|" _ tRead.Items.%Size() _ "|" _ tRead.Present, "100|100|0", "naming all 100 and none held")
    Do $$$AssertEquals(..Read(tAt, .tRead, "IMPORT"), "200 ", "and so is the read composed for the import")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "at.xml", tAt), "the 100-item file is written to the server")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", $ClassMethod(..#BASE, "FileQuery", "at.xml"), .tRead, .tFault, "IMPORT"), "200 ", "a server file of 100 items is read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Count, 100, "naming all 100")
    Do $$$AssertEquals(..Read(tOver, .tRead), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "a local file of 101 items is too large to read")
    Do $$$AssertEquals(..Read(tOver, .tRead, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "and to read for the import")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "over.xml", tOver), "the 101-item file is written to the server")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", $ClassMethod(..#BASE, "FileQuery", "over.xml"), .tRead, .tFault, "IMPORT"), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "a server file of 101 items is too large")
    Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORT", "import", $ClassMethod(..#BASE, "FileQuery", "over.xml"), .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.TOOLARGE", "and so is its write")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot") _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "nothing was written and no vendor call was made")
}

/// <p>AC4, AC5: a dashboard whose name holds a slash or a control character, or whose name or folder is longer than 255 characters, is refused 409
/// <code>ANALYTICS.FOLDERITEM.IMPORTSHAPE</code> by the write and by the read composed for it, with the globals as they were and no vendor call made; the same item with a
/// name and a folder of exactly 255 characters is read by its shape, as one item.</p>
/// <p>Mutation (Rule 19): drop the slash test, the control-character test or either length test from the guard of <method>OcuPilot.Port.AnalyticsPort.FolderItemsInText</method>
/// -- that leg goes red.</p>
Method TestAnItemNameTheVendorCannotAddressIsRefusedAsShape()
{
    Set tMax = $Parameter(..#PORT, "NAMEMAX")
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    For tCase = $ListBuild("a name holding a slash", ..Raw(..#MARKER _ "a/b", "")), $ListBuild("a name holding a control character", ..Raw(..#MARKER _ "a&#9;b", "")), $ListBuild("a name past the bound", ..Raw(..Letters(tMax + 1), "")), $ListBuild("a folder past the bound", ..Raw(..#MARKER _ "Long", ..Letters(tMax + 1))), $ListBuild("a folder holding a control character", ..Raw(..#MARKER _ "Ctl", ..#MARKER _ "F&#9;G")) {
        Do $$$AssertEquals($ClassMethod(..#BASE, "Import", $List(tCase, 2), .tRes, .tFault), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", $List(tCase, 1) _ " is refused")
        Do $$$AssertEquals(..Read($List(tCase, 2), .tRead, "IMPORT"), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", $List(tCase, 1) _ " is refused by the read composed for the import")
    }
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot") _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "nothing was written and no vendor call was made")
    Kill tClasses
    Do $ClassMethod(..#PORT, "FolderItemClasses", "USER", .tClasses, .tCaught)
    Do $$$AssertTrue('$IsObject(tCaught), "the folder item classes are read")
    Set tShaped = $ClassMethod(..#PORT, "FolderItemsInText", ..Raw(..Letters(tMax), ..Letters(tMax)), .tClasses, .tItems, .tCode)
    Do $$$AssertEquals(tShaped _ "|" _ tCode _ "|" _ tItems, "1||1", "a name and a folder of exactly the bound are one item by their shape")
}

/// <p>AC2: the classic page's file is read whatever the case of its document's extension: a document named <code>.dfi</code> in lower case holds one item, and a document of
/// another extension is still refused.</p>
/// <p>Mutation (Rule 19): drop the upper-casing of the document's extension in <method>OcuPilot.Port.AnalyticsPort.FolderItemsInText</method> -- the lower-case leg goes red.</p>
Method TestTheClassicFilesDocumentExtensionIsReadInAnyCase()
{
    Set tText = $Replace(..Many(1), ".DFI""", ".dfi""")
    Do $$$AssertTrue(tText [ ".dfi""", "the document is named in lower case")
    Do $$$AssertEquals(..Read(tText, .tRead), "200 ", "the file is read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Count _ "|" _ tRead.Items.%Get(0), "1|" _ ..#MARKER _ "Cap1.dashboard", "as one item")
    Do $$$AssertEquals(..Read($Replace(..Many(1), ".DFI""", ".TXT"""), .tRead), "409 ANALYTICS.FOLDERITEM.IMPORTSHAPE", "while a document of another extension is refused")
}

}
