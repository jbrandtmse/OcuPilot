/// <p>Pins Story 21.19's resource export and import port and tools in process (AD-10, AD-21, AD-29, AD-51, AD-52): the gate names the pair a
/// caller lacks before any read or vendor call; the export target answers every resource and one, and 404 for a name the instance does not
/// hold; the import review answers the file's names, digest, replaced count and per-resource letters from a local text, runs the vendor's
/// preview, and refuses what is not a resource export, a file too large, and a local text named beside a server file; an export refuses a
/// root outside the allowed directories and a name whose directory is absent on its field; the kernel's own-resource rule judges every
/// resource a file holds; and the two tools' declarations and baseline keys.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled and at least one allowed directory. It writes nothing on the instance: every
/// vendor call is a read or a preview, and every text names resources the test invents.</p>
Class OcuPilot.Test.ResourceTransferRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Test.ResourceTransferFixture";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.ResourceExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.ResourceImport";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Quit $$$OK
}

/// <p>An export file's text holding <var>pEntries</var>, a <code>$ListBuild</code> of <code>$ListBuild(name, bits)</code>.</p>
ClassMethod Text(pEntries As %List) As %String
{
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<ResourcesExport>" _ $Char(10)
    For tI = 1:1:$ListLength(pEntries) {
        Set tEntry = $List(pEntries, tI)
        Set tText = tText _ "<Resources><Description>t21 probe</Description><Name>" _ $List(tEntry, 1) _ "</Name><PublicPermission>" _ $List(tEntry, 2) _ "</PublicPermission><Type>2147483648</Type><Version>2</Version></Resources>" _ $Char(10)
    }
    Quit tText _ "</ResourcesExport>"
}

/// <p>The port's answer to <var>pType</var> for the local text <var>pText</var>, <code>http|code</code>, the result in <var>pOut</var>.</p>
ClassMethod Review(pText As %String, Output pOut, pType As %String = "IMPORTSET") As %String
{
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "resources.xml"
    Set tQuery("content") = pText
    Quit $ClassMethod(..#PORT, "Ask", pType, .tQuery, .pOut)
}

/// <p>How many resources the instance holds, by its own list query.</p>
ClassMethod VendorCount() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%ResultSet).%New("Security.Resources:List")
        Do tResult.Execute("*", -1, -1)
        While tResult.Next() {
            Set tCount = tCount + 1
        }
    } Catch {
        Set tCount = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p><b>AC1, AC6.</b> A caller that lacks a pair of the port's gate is refused <code>PORT.ACCESSDENIED</code> naming it, on every type, before any vendor call.</p>
/// <p>Mutation (Rule 19): <code>Invoke</code> not asking <method>Gate</method> -> the denial rows go red.</p>
Method TestTheGateNamesThePairACallerLacksBeforeAnyVendorCall()
{
    Set tPairs = $ListFromString($Parameter(..#PORT, "PAIRS"))
    Do $$$AssertEquals($ListLength(tPairs), 2, "the port declares the vendor's two measured pairs")
    For tI = 1:1:$ListLength(tPairs) {
        Do $ClassMethod(..#PORT, "DenyPair", $List(tPairs, tI))
        For tType = "EXPORTSET", "IMPORTSET", "EXPORT", "IMPORT" {
            Kill tQuery
            Set tQuery("id") = $Select((tType = "EXPORTSET") || (tType = "EXPORT"): "*", 1: "import")
            Set tQuery("fileName") = "a.xml"
            Set tQuery("content") = "x"
            Set tQuery("root") = ""
            Set tSC = $ClassMethod(..#PORT, "Invoke", "ResourceTransfer", tType, .tQuery, "", .tOut, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.detail.failedPair, "403|PORT.ACCESSDENIED|" _ $List(tPairs, tI), tType _ " without " _ $List(tPairs, tI) _ " is refused naming the pair")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "no vendor call was made")
}

/// <p><b>AC1.</b> The export target answers every resource's count for <code>*</code>, one resource by its name, and 404 for a name the instance does not hold or a name no
/// resource can carry.</p>
Method TestTheExportTargetAnswersAllOneAndAnAbsentName()
{
    Kill tQuery
    Set tQuery("id") = "*"
    Set tStatus = $ClassMethod(..#PORT, "Ask", "EXPORTSET", .tQuery, .tAll)
    Do $$$AssertEquals(tStatus _ "|" _ tAll.%Get("Count"), "200||" _ ..VendorCount(), "every resource counts, as the vendor's own list does")
    Set tQuery("id") = "%DB_IRISSYS"
    Set tStatus = $ClassMethod(..#PORT, "Ask", "EXPORTSET", .tQuery, .tOne)
    Do $$$AssertEquals(tStatus _ "|" _ tOne.%Get("Name") _ "|" _ tOne.%Get("Count"), "200||%DB_IRISSYS|1", "one resource counts one")
    For tName = "T21Pm24NoSuchResource", "%DB_IRISSYS,%DB_IRISLIB", "" {
        Set tQuery("id") = tName
        Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "EXPORTSET", .tQuery, .tNone), "404|PORT.NOTFOUND", "'" _ tName _ "' is not a resource the instance holds")
    }
}

/// <p><b>AC2.</b> The review of a local text answers its names in file order, the SHA-256 of the text, the count, how many resources the instance already holds and each
/// resource's letters and held letters, never the text itself, and the vendor is asked its preview (<code>Flags</code> 1) and nothing else.</p>
/// <p>Mutation (Rule 19): <code>Review</code> counting no held resource -> the replaced row goes red.</p>
Method TestTheImportReviewAnswersTheFilesNamesDigestAndLetters()
{
    Set tHeld = ##class(OcuPilot.Port.ResourceTransferPort).LettersOf(0)
    Do $$$AssertEquals(tHeld, "", "no bit is no letter")
    Do $$$AssertEquals(##class(OcuPilot.Port.ResourceTransferPort).LettersOf(7) _ "|" _ ##class(OcuPilot.Port.ResourceTransferPort).LettersOf(5), "RWU|RU", "the bits map to R, W and U")
    Set tText = ..Text($ListBuild($ListBuild("T21Pm24Rd1", 1), $ListBuild("T21Pm24Rd2", 3), $ListBuild("%DB_IRISSYS", 1)))
    Set tStatus = ..Review(tText, .tOut)
    Do $$$AssertEquals(tStatus, "200|", "the review answers")
    Do $$$AssertEquals(tOut.%Get("Names") _ "|" _ tOut.%Get("Count") _ "|" _ tOut.%Get("Replaces"), "T21Pm24Rd1,T21Pm24Rd2,%DB_IRISSYS|3|1", "names in file order, the count and the one resource already held")
    Do $$$AssertTrue($Match(tOut.%Get("Digest"), "^[0-9a-f]{64}$"), "the digest is a SHA-256 in lower-case hex")
    Do $$$AssertEquals(tOut.%Get("content") _ "|" _ tOut.%Get("fileName"), "|resources.xml", "the row never holds the text, and echoes the local file's name")
    Set tEntries = tOut.%Get("Entries")
    Do $$$AssertEquals(tEntries.%Get(0).%Get("PublicPermission") _ "|" _ tEntries.%Get(0).%GetTypeOf("Held") _ "|" _ tEntries.%Get(1).%Get("PublicPermission"), "R|null|RW", "each entry carries the letters the file gives, and null where the instance holds none")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "IMPORT 1", "the vendor was asked its preview and nothing else")
    Set tOther = ..Text($ListBuild($ListBuild("T21Pm24Rd1", 1)))
    Do ..Review(tOther, .tOtherOut)
    Do $$$AssertTrue(tOtherOut.%Get("Digest") '= tOut.%Get("Digest"), "another text has another digest")
}

/// <p><b>AC2.</b> What is not a resource export is refused <code>RESOURCEFILE.SHAPE</code>, a file of more than 2,000 resources <code>RESOURCEFILE.TOOLARGE</code>, an id other than
/// the import's is 404, and a text named beside a server file, or no file, is 400; no vendor write is made.</p>
Method TestTheImportReviewRefusesWhatIsNotAResourceExport()
{
    Set tHead = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10)
    Set tOne = "<Resources><Name>T21Pm24Rd1</Name><PublicPermission>1</PublicPermission></Resources>"
    Set tCases = $ListBuild("garbage|this is not xml", "wrongroot|" _ tHead _ "<Foo>" _ tOne _ "</Foo>", "emptyroot|" _ tHead _ "<ResourcesExport></ResourcesExport>", "doctype|" _ tHead _ "<!DOCTYPE foo [<!ENTITY x ""y"">]><ResourcesExport>" _ tOne _ "</ResourcesExport>", "duplicate|" _ tHead _ "<ResourcesExport>" _ tOne _ tOne _ "</ResourcesExport>", "nameless|" _ tHead _ "<ResourcesExport><Resources><PublicPermission>1</PublicPermission></Resources></ResourcesExport>", "badpermission|" _ tHead _ "<ResourcesExport><Resources><Name>T21Pm24Rd1</Name><PublicPermission>9</PublicPermission></Resources></ResourcesExport>", "comma|" _ tHead _ "<ResourcesExport><Resources><Name>T21,Pm24</Name><PublicPermission>1</PublicPermission></Resources></ResourcesExport>")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do $$$AssertEquals(..Review($Piece(tCase, "|", 2, *), .tOut), "409|RESOURCEFILE.SHAPE", $Piece(tCase, "|", 1) _ " is not a resource export")
    }
    Set tMany = tHead _ "<ResourcesExport>"
    For tI = 1:1:2001 {
        Set tMany = tMany _ "<Resources><Name>T21Pm24M" _ tI _ "</Name><PublicPermission>1</PublicPermission></Resources>"
    }
    Do $$$AssertEquals(..Review(tMany _ "</ResourcesExport>", .tOut), "409|RESOURCEFILE.TOOLARGE", "more than 2,000 resources is too large")
    Do $$$AssertEquals(..Review($Translate($Justify("", 3000001), " ", "a"), .tOut), "409|RESOURCEFILE.TOOLARGE", "a local text past the character cap is too large")
    Kill tQuery
    Set tQuery("id") = "other"
    Set tQuery("fileName") = "a.xml"
    Set tQuery("content") = tOne
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "IMPORTSET", .tQuery, .tOut), "404|PORT.NOTFOUND", "an id other than import is not found")
    Set tQuery("id") = "import"
    Set tQuery("root") = "/x/"
    Set tQuery("path") = "a.xml"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "IMPORTSET", .tQuery, .tOut), "400|PORT.VALIDATION", "a local text beside a server file is refused")
    Kill tQuery
    Set tQuery("id") = "import"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "IMPORTSET", .tQuery, .tOut), "400|PORT.VALIDATION", "no file is refused")
    Kill tQuery
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "dir/a.xml"
    Set tQuery("content") = tOne
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "IMPORTSET", .tQuery, .tOut), "400|PORT.VALIDATION", "a local file's name holds no slash")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "no vendor call was made by a refusal")
}

/// <p><b>AC3.</b> An export names its file on the field a refusal is about: a root outside the allowed directories on <code>root</code>, and a name whose directory the allowed root
/// lacks <code>TASK.EXPORT.DIRECTORY</code> on <code>path</code>, each before any vendor call.</p>
/// <p>Mutation (Rule 19): <code>ExportFile</code> skipping the directory check -> the directory row goes red.</p>
Method TestAnExportRefusesAFileOnTheFieldItIsAbout()
{
    Kill tQuery
    Set tQuery("id") = "*"
    Set tQuery("root") = "/t21pm24-no-such-allowed-root/"
    Set tQuery("path") = "a.xml"
    Set tStatus = $ClassMethod(..#PORT, "Ask", "EXPORT", .tQuery, .tOut)
    Do $$$AssertTrue($Piece(tStatus, "|", 1) = 400, "a root outside the allowed directories is refused: " _ tStatus)
    Set tRoot = ##class(OcuPilot.Test.TaskTransferFixture).FirstRoot()
    Do $$$AssertTrue(tRoot '= "", "the instance has an allowed directory")
    Set tQuery("root") = tRoot
    Set tQuery("path") = "t21pm24-absent-directory/a.xml"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "EXPORT", .tQuery, .tOut), "400|TASK.EXPORT.DIRECTORY", "a name whose directory is absent is refused")
    Set tCheck = $ClassMethod(..#PORT, "CheckExport", tRoot, "t21pm24-absent-directory/a.xml", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|TASK.EXPORT.DIRECTORY", "the mint's check refuses it the same way")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "no vendor call was made")
}

/// <p><b>AC4.</b> The kernel's own-resource rule judges every resource of a file: one of OcuPilot's own that the file gives a public permission letter it does not hold, or
/// that the instance lacks and the file gives one, is refused; the same letters, fewer, or no letters are not; another resource is not. The port refuses an import of such a
/// file, after its review and before any vendor write.</p>
/// <p>Mutation (Rule 19): <code>ImportedResources</code> reading only the first entry -> the second-entry row goes red.</p>
Method TestTheOwnResourceRuleJudgesEveryResourceOfAFile()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Set tSC = $ClassMethod(tProhibited, "OcuPilotResources", .tOwn)
    Do $$$AssertTrue($ListLength(tOwn) >= 1, "the kernel names OcuPilot's own resources")
    Set tName = $List(tOwn, 1)
    Set tCode = $Parameter(tProhibited, "OCUPILOTRESOURCE")
    Set tRows = $ListBuild("RWU||1", "RW|R|1", "R|R|0", "|R|0", "R||1")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tEntry = {"Name": (tName), "PublicPermission": ($Piece(tRow, "|", 1))}
        Do tEntry.%Set("Held", $Piece(tRow, "|", 2), "string")
        Set tOther = {"Name": "T21Pm24Rd1", "PublicPermission": "RWU", "Held": ""}
        Set tSC = $ClassMethod(tProhibited, "ImportedResources", [(tOther), (tEntry)], .tProhibits, .tFound)
        Do $$$AssertEquals(tProhibits _ "|" _ tFound, $Piece(tRow, "|", 3) _ "|" _ $Select($Piece(tRow, "|", 3): tCode, 1: ""), "an own resource given '" _ $Piece(tRow, "|", 1) _ "' where the instance holds '" _ $Piece(tRow, "|", 2) _ "' (second entry)")
    }
    Set tText = ..Text($ListBuild($ListBuild("T21Pm24Rd1", 1), $ListBuild(tName, 7)))
    Set tQuery("id") = "import"
    Set tQuery("fileName") = "own.xml"
    Set tQuery("content") = tText
    Set tQuery("names") = "T21Pm24Rd1," _ tName
    Do ..Review(tText, .tReview)
    Set tQuery("names") = tReview.%Get("Names")
    Set tQuery("digest") = tReview.%Get("Digest")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Ask", "IMPORT", .tQuery, .tOut), "403|" _ tCode, "the port refuses an import that opens OcuPilot's own resource")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "IMPORT 1|IMPORT 1", "and only the two previews (the test's review and the write's) reached the vendor")
}

/// <p><b>AC6.</b> The export key ships enabled and the import key disabled; the import is destructive and the export is not; both name the classic page and the one port; the
/// import's schema never advertises the local file or the reviewed values.</p>
Method TestTheKeysAndTheToolsAreDeclaredAsTheStoryRules()
{
    Set tBaseline = "OcuPilot.Kernel.Governance.Baseline"
    Do $$$AssertEquals($ClassMethod(tBaseline, "Seed", "permissions.resources.export", .tListed) _ "|" _ tListed, "1|1", "the export key is listed and enabled")
    Do $$$AssertEquals($ClassMethod(tBaseline, "Seed", "permissions.resources.import", .tListed) _ "|" _ tListed, "0|1", "the import key is listed and disabled")
    Do $$$AssertEquals($Parameter(..#IMPORTTOOL, "DESTRUCTIVE") _ "|" _ $Parameter(..#EXPORTTOOL, "DESTRUCTIVE"), "1|0", "an import is destructive and an export is not")
    Do $$$AssertEquals($Parameter(..#IMPORTTOOL, "PORTCLASS") _ "|" _ $Parameter(..#EXPORTTOOL, "PORTCLASS"), "OcuPilot.Port.ResourceTransferPort|OcuPilot.Port.ResourceTransferPort", "both reach the resource transfer port")
    Do $$$AssertEquals($Parameter(..#IMPORTTOOL, "CLASSICPAGES") _ "|" _ $Parameter(..#EXPORTTOOL, "CLASSICPAGES"), "%CSP.UI.Portal.Dialog.ExportResource|%CSP.UI.Portal.Dialog.ExportResource", "both perform the classic dialog's operation")
    Set tProperties = $ClassMethod(..#IMPORTTOOL, "InputSchema", "OcuPilot.Screen.Descriptor.ResourceList").%Get("properties")
    Set tNames = ""
    Set tIterator = tProperties.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames = tNames _ tKey _ ";"
    }
    Do $$$AssertTrue((tNames [ "root;") && (tNames [ "path;") && (tNames '[ "content") && (tNames '[ "fileName") && (tNames '[ "Names") && (tNames '[ "Digest"), "the import's schema advertises the server file alone: " _ tNames)
}

}
