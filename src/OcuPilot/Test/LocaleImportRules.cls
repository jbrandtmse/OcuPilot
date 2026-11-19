/// <p>Pins Story 21.15's import (AC3, AC4, AC5; AD-6, AD-21, AD-29, AD-39, AD-51, AD-53, AD-59) without changing a locale: the port runs as
/// <class>OcuPilot.Test.LocaleGateSeam</class>, which records the import instead of making it, so the test sees what the port would hand the vendor. It pins
/// that every refusal of the matrix is answered by the port before any vendor call; that the review keeps only the custom records, counts what it drops, and
/// the write hands the vendor just those; that a digest or a count that differs at the write is <code>LOCALE.IMPORT.CHANGED</code>; the mint's refusal of a
/// file the port refuses; the closed agent schema; the file the port makes for the vendor, which is in a directory made for the transfer and gone with it on every
/// path, an error and an exception included, and a directory already at the name refused; the locks an import takes; the records the vendor's class rejects; and
/// the script an import renders.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory as an allowed root, and an instance that lists no
/// locale, table or sub-table named <code>yqzw</code>, <code>yqone</code> or <code>XLT-yqone-Unicode</code>. It writes only files under the probe directory
/// <class>OcuPilot.Test.ExplorerTransferProbe</class> names and the port's own temporary directory, and removes them.</p>
Class OcuPilot.Test.LocaleImportRules Extends %UnitTest.TestCase
{

Parameter SEAM = "OcuPilot.Test.LocaleGateSeam";

Parameter TRANSFER = "OcuPilot.Test.LocaleTransferSeam";

Parameter TOOL = "OcuPilot.Test.LocaleImportSeam";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter READ = "OcuPilot.Test.LocalePropertyRead";

/// <p>The custom locale, table and sub-table every text names.</p>
Parameter LOCALE = "yqzw";

Parameter TABLE = "yqone";

Parameter SUBTABLE = "XLT-yqone-Unicode";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#TRANSFER, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $ClassMethod(..#PROBE, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#TRANSFER, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Quit $$$OK
}

/// <p>A locale record named <var>pName</var> that holds every element the vendor requires: the current locale's own, renamed.</p>
ClassMethod LocaleXml(pName As %String) As %String
{
    Set tXml = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tLocale = ##class(Config.NLS.Locales).%OpenId(tCurrent)
        Do tLocale.XMLExportToString(.tXml, "Locales")
        Set tXml = $Replace(tXml, "<Name>" _ tCurrent _ "</Name>", "<Name>" _ pName _ "</Name>")
    } Catch {
        Set tXml = ""
    }
    Set tLocale = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tXml
}

/// <p>A locale record named <var>pName</var> whose <code>DateFormat</code> is not a number, which the vendor's class rejects when it imports it.</p>
ClassMethod BadLocaleXml(pName As %String) As %String
{
    Set tXml = ..LocaleXml(pName)
    Set tOld = "<DateFormat>" _ $Piece($Piece(tXml, "<DateFormat>", 2), "</DateFormat>", 1) _ "</DateFormat>"
    Quit $Replace(tXml, tOld, "<DateFormat>abc</DateFormat>")
}

/// <p>A table record, in the vendor's own form.</p>
ClassMethod TableXml(pType As %String, pFrom As %String, pTo As %String, pSubTable As %String) As %String
{
    Quit "<Tables><Description>test</Description><NameFrom>" _ pFrom _ "</NameFrom><NameTo>" _ pTo _ "</NameTo><SubTableName>" _ pSubTable _ "</SubTableName><Type>" _ pType _ "</Type></Tables>"
}

/// <p>A sub-table record, in the vendor's own form.</p>
ClassMethod SubTableXml(pName As %String) As %String
{
    Quit "<SubTables><Description>test</Description><FromTo><FromToItem FromToKey=""65"">66</FromToItem></FromTo><Name>" _ pName _ "</Name><Type>0</Type></SubTables>"
}

/// <p>An export file holding the record texts <var>pLocales</var>, <var>pTables</var> and <var>pSubTables</var>, in the form the vendor writes.</p>
ClassMethod Wrap(pLocales As %String = "", pTables As %String = "", pSubTables As %String = "") As %String
{
    Quit "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<LocalesDeepExport>" _ $Char(10) _ "<LocalesExport>" _ pLocales _ "</LocalesExport>" _ $Char(10) _ "<TablesDeepExport>" _ "<TablesExport>" _ pTables _ "</TablesExport>" _ "<SubTablesExport>" _ pSubTables _ "</SubTablesExport>" _ "</TablesDeepExport>" _ "</LocalesDeepExport>"
}

/// <p>A file with one custom locale, one custom table and its custom sub-table, and a shipped locale, table and sub-table beside them.</p>
ClassMethod MixedText() As %String
{
    Quit ..Wrap(..LocaleXml(..#LOCALE) _ ..LocaleXml("enuw"), ..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE) _ ..TableXml("Pattern", "Unicode", "Latin1", "Standard"), ..SubTableXml(..#SUBTABLE) _ ..SubTableXml("Accent-Unicode-Unicode"))
}

/// <p>The port's answer to the type <var>pType</var> for the local file <var>pContent</var> and <var>pName</var>, with <var>pExtra</var> added to the query,
/// as <code>http|code</code>; the answer in <var>pOut</var>.</p>
Method Call(pType As %String, pFileName As %String, pContent As %String, ByRef pExtra, Output pOut, pPort As %String = {..#SEAM}) As %String
{
    Kill tQuery
    Merge tQuery = pExtra
    If '$Data(tQuery("name")) Set tQuery("name") = "import"
    If pFileName '= "" Set tQuery("fileName") = pFileName
    If pContent '= "" Set tQuery("content") = pContent
    Set tSC = $ClassMethod(pPort, "Invoke", "Locales", pType, .tQuery, "", .pOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The review of the local text <var>pText</var> through the seam.</p>
Method Review(pText As %String, Output pReview, pPort As %String = {..#SEAM}) As %String
{
    Kill tNone
    Quit ..Call("IMPORTFILE", "locales.xml", pText, .tNone, .pReview, pPort)
}

/// <p><b>AC3, AC4.</b> Every import refusal of the matrix is answered before any vendor call, by the review and by the write alike: both sources or neither and a local name
/// that is empty, over 255 characters or holds a slash, a backslash or a control character are 400 <code>PORT.VALIDATION</code>; text past 3,000,000 characters is 409
/// <code>LOCALE.TOOLARGE</code>; a text with a document type declaration (in either letter case), malformed text, text with no record, a locale record
/// that lacks an element the vendor requires or whose name is not a custom locale's shape, a sub-table with no type, a record that repeats a value and a kept
/// record the vendor's own class does not take (a locale whose <code>DateFormat</code> is not a number, before or after a good one; a sub-table whose type is not a
/// number) are 409 <code>LOCALE.IMPORT.SHAPE</code>; shipped records alone are <code>LOCALE.IMPORT.EMPTY</code>; a kept record that is the current locale, a table it loads or
/// a sub-table such a table names is <code>LOCALE.IMPORT.CURRENT</code>, at the review and at a write reviewed before; a target that is not the literal is 404;
/// and a server file under no allowed root, or one that is absent, is a <code>PATH.*</code> refusal. None of them reaches the vendor.</p>
/// <p>Mutation (Rule 19): the current-locale check dropped from <code>ImportReview</code> -> the <code>CURRENT</code> rows go red; the <code>&lt;!DOCTYPE</code> check
/// dropped -> the document type rows go red; the sub-table type check or the repeated-value check dropped from <code>ScanImport</code> -> its row goes red; the
/// <code>KeptRecordsValid</code> check dropped from <code>ImportReview</code> -> the three rejected-record rows go red.</p>
Method TestEveryImportRefusalIsAnsweredBeforeAnyVendorCall()
{
    Set tValid = ..Wrap(..LocaleXml(..#LOCALE))
    Kill tNone
    Do $$$AssertEquals(..Call("IMPORTFILE", "locales.xml", tValid, .tNone, .tValidReview), "200|", "a file that holds one custom locale is reviewed")
    Set tBoth("root") = "x"
    Set tBoth("path") = "y.xml"
    Do $$$AssertEquals(..Call("IMPORTFILE", "locales.xml", tValid, .tBoth), "400|PORT.VALIDATION", "a server file and a local file together are a validation fault")
    Do $$$AssertEquals(..Call("IMPORTFILE", "", "", .tNone), "400|PORT.VALIDATION", "neither is a validation fault")
    Set tLong = $Translate($Justify("", 256), " ", "n")
    For tName = "a/b.xml", "a\b.xml", "a" _ $Char(7) _ ".xml", tLong {
        Do $$$AssertEquals(..Call("IMPORTFILE", tName, tValid, .tNone), "400|PORT.VALIDATION", "a local name of " _ $Length(tName) _ " characters that is not a plain name is a validation fault")
    }
    Do $$$AssertEquals(..Call("IMPORTFILE", "", tValid, .tNone), "400|PORT.VALIDATION", "a local text with no name is a validation fault")
    Do $$$AssertEquals(..Call("IMPORTFILE", "locales.xml", $Justify("", 3000001), .tNone), "409|LOCALE.TOOLARGE", "text past 3,000,000 characters is too large")
    Set tShape = "409|LOCALE.IMPORT.SHAPE"
    For tCase = $ListBuild($Replace(tValid, "<LocalesDeepExport>", "<!DOCTYPE LocalesDeepExport><LocalesDeepExport>"), tShape), $ListBuild($Replace(tValid, "<LocalesDeepExport>", "<!doctype LocalesDeepExport><LocalesDeepExport>"), tShape), $ListBuild("<!DOCTYPE a [<!ENTITY x SYSTEM ""file:///etc/hostname"">]><a>&x;</a>", tShape), $ListBuild("<!doctype a><LocalesDeepExport/>", tShape), $ListBuild("<a><b></a>", tShape), $ListBuild("not xml", tShape), $ListBuild("<a/>", tShape), $ListBuild(..Wrap("<Locales><Name>" _ ..#LOCALE _ "</Name></Locales>"), tShape), $ListBuild(..Wrap($Replace(..LocaleXml(..#LOCALE), "<Name>" _ ..#LOCALE _ "</Name>", "<Name>yqzzw</Name>")), tShape), $ListBuild(..Wrap($Replace(..LocaleXml(..#LOCALE), "<Name>" _ ..#LOCALE _ "</Name>", "<Name></Name>")), tShape), $ListBuild(..Wrap("", "<Tables><NameFrom>yqone</NameFrom><Type>XLT</Type></Tables>"), tShape), $ListBuild(..Wrap("", "", "<SubTables><Type>0</Type></SubTables>"), tShape), $ListBuild(..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE), "<SubTables><Name>" _ ..#SUBTABLE _ "</Name></SubTables>"), tShape), $ListBuild(..Wrap($Replace(..LocaleXml(..#LOCALE), "<Name>" _ ..#LOCALE _ "</Name>", "<Name>enuw</Name><Name>" _ ..#LOCALE _ "</Name>")), tShape), $ListBuild(..Wrap(..LocaleXml(..#LOCALE) _ ..BadLocaleXml("yqyw")), tShape), $ListBuild(..Wrap(..BadLocaleXml(..#LOCALE) _ ..LocaleXml("yqyw")), tShape), $ListBuild(..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE), $Replace(..SubTableXml(..#SUBTABLE), "<Type>0</Type>", "<Type>xx</Type>")), tShape), $ListBuild(..Wrap(..LocaleXml("yqyw"), $Replace(..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE), "<Description>test</Description>", "<Description>" _ $Translate($Justify("", 129), " ", "d") _ "</Description>"), ..SubTableXml(..#SUBTABLE)), tShape), $ListBuild(..Wrap(..LocaleXml("enuw")), "409|LOCALE.IMPORT.EMPTY"), $ListBuild(..Wrap("", ..TableXml("Pattern", "Unicode", "Latin1", "Standard"), ..SubTableXml("Accent-Unicode-Unicode")), "409|LOCALE.IMPORT.EMPTY") {
        Do $$$AssertEquals(..Review($List(tCase, 1)), $List(tCase, 2), "the review of '" _ $Extract($List(tCase, 1), 1, 40) _ "' is refused " _ $List(tCase, 2))
        Set tWrite("digest") = "x"
        Set tWrite("replaces") = 0
        Do $$$AssertEquals(..Call("IMPORT", "locales.xml", $List(tCase, 1), .tWrite), $List(tCase, 2), "and so is its write")
    }
    Set tBodyless("name") = "other"
    Do $$$AssertEquals(..Call("IMPORTFILE", "locales.xml", tValid, .tBodyless), "404|LOCALE.NOTFOUND", "a target that is not the literal is not found")
    Kill tCurrentTables, tCurrentSubTables
    Set tCurrentTables("XLT", ..#TABLE, "Unicode") = ""
    Set tCurrentSubTables(..#SUBTABLE) = ""
    Do $ClassMethod(..#SEAM, "HoldCurrent", ..#LOCALE, .tCurrentTables, .tCurrentSubTables)
    Set tCurrent = "409|LOCALE.IMPORT.CURRENT"
    Do $$$AssertEquals(..Review(..Wrap(..LocaleXml(..#LOCALE))), tCurrent, "a file whose custom locale is the current locale is refused")
    Kill tReviewed
    Set tReviewed("digest") = tValidReview.%Get("Digest")
    Set tReviewed("replaces") = tValidReview.%Get("Replaces")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tValid, .tReviewed), tCurrent, "a write reviewed before its locale became current is refused at the write")
    Do $ClassMethod(..#SEAM, "HoldCurrent", "yqyw", .tCurrentTables, .tCurrentSubTables)
    Do $$$AssertEquals(..Review(..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", "Standard"))), tCurrent, "a custom table the current locale loads is refused")
    Kill tCurrentTables
    Do $ClassMethod(..#SEAM, "HoldCurrent", "yqyw", .tCurrentTables, .tCurrentSubTables)
    Do $$$AssertEquals(..Review(..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE), ..SubTableXml(..#SUBTABLE))), tCurrent, "a custom sub-table the current locale loads, named by a kept table, is refused")
    Set tWrite("digest") = "x"
    Set tWrite("replaces") = 0
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", ..Wrap(..LocaleXml(..#LOCALE)), .tWrite), "409|LOCALE.IMPORT.CHANGED", "a write whose digest is not the reviewed one is refused as changed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no import was made by any refusal of the file")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Kill tUnknown
    Set tUnknown("root") = "/no/such/allowed/root/"
    Set tUnknown("path") = "x.xml"
    Set tOutcome = ..Call("IMPORTFILE", "", "", .tUnknown)
    Do $$$AssertEquals($Piece(tOutcome, "|", 1) _ "|" _ $Extract($Piece(tOutcome, "|", 2), 1, 5), "400|PATH.", "a server file under no allowed root is a path refusal")
    Kill tAbsent
    Set tAbsent("root") = $ClassMethod(..#PROBE, "Root")
    Set tAbsent("path") = $ClassMethod(..#PROBE, "RelativeName", "absent.xml")
    Set tOutcome = ..Call("IMPORTFILE", "", "", .tAbsent)
    Do $$$AssertEquals($Piece(tOutcome, "|", 1) _ "|" _ $Extract($Piece(tOutcome, "|", 2), 1, 5), "400|PATH.", "and so is a server file that is absent")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no import was made by any refusal")
}

/// <p><b>AC1, AC2 (the port's half).</b> The review keeps only the custom records and counts them: a file holding a custom locale, a custom table, the sub-table the
/// table names, and a shipped locale, table and sub-table beside them answers one of each and three skipped, lists the locale by name and never answers the text; the write
/// hands the vendor a file holding just the custom records, answers the vendor's counts, and is refused <code>LOCALE.IMPORT.CHANGED</code> with nothing imported when the
/// digest or the replaced count is not the reviewed one or is absent. A server file reads as the same file. A vendor that imports fewer locales or tables than were
/// reviewed is a logged 500; one that answers an error is a logged 500. A shipped sub-table a custom table names is skipped and never handed to the vendor, while a
/// custom one is kept.</p>
/// <p>Mutation (Rule 19): the digest compare dropped from <code>PerformImport</code> -> the changed rows go red; <code>ScanImport</code> keeping every table -> the
/// kept-text rows go red; <code>ScanImport</code>'s parse without <code>KeepWhiteSpace</code> -> the leading-space row goes red; <code>IsCustomSubTable</code> answering 1
/// -> the shipped sub-table rows go red; the table count compare dropped from <code>PerformImport</code> -> the fewer-tables row goes red.</p>
Method TestOnlyTheCustomRecordsAreKeptCountedAndHandedToTheVendorOnce()
{
    Set tText = ..MixedText()
    Set tHeld = ..Review(tText, .tReview)
    Do $$$AssertEquals(tHeld, "200|", "the mixed file is reviewed")
    Do $$$AssertEquals(tReview.%Get("LocaleCount") _ "|" _ tReview.%Get("TableCount") _ "|" _ tReview.%Get("SubTableCount") _ "|" _ tReview.%Get("Skipped") _ "|" _ tReview.%Get("Replaces") _ "|" _ tReview.%Get("Truncated"), "1|1|1|3|0|0", "one custom locale, table and sub-table are kept, three records are skipped, none replaces and the list is not cut")
    Do $$$AssertEquals(tReview.%Get("Locales").%ToJSON() _ "|" _ tReview.%Get("fileName") _ "|" _ tReview.%Get("content") _ "|" _ (tReview.%Get("Digest") = ..Digest(tText)), "[""" _ ..#LOCALE _ """]|locales.xml||1", "the review names the locale, echoes the file's name, holds no text, and its digest is the whole text's")
    Do $$$AssertTrue($Length(tReview.%ToJSON()) < 1000, "the review's wire form is small: it never carries the file")
    Do $ClassMethod(..#SEAM, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite, .tOut) _ "|" _ tOut.%ToJSON() _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||{""Locales"":1,""Tables"":1,""SubTables"":1}|IMPORT", "the import is made once and answers the counts")
    Set tImported = $ClassMethod(..#SEAM, "Imported")
    Do $$$AssertTrue((tImported [ ("<Name>" _ ..#LOCALE _ "</Name>")) && (tImported [ ("<NameFrom>" _ ..#TABLE _ "</NameFrom>")) && (tImported [ ("<Name>" _ ..#SUBTABLE _ "</Name>")), "the vendor's file holds the custom locale, table and sub-table")
    Do $$$AssertTrue('(tImported [ "<Name>enuw</Name>") && '(tImported [ "Accent-Unicode-Unicode") && '(tImported [ "<NameTo>Latin1</NameTo>"), "and none of the shipped records")
    Do $$$AssertEquals($Extract(tImported, 1, 38), "<?xml version=""1.0"" encoding=""UTF-8""?>", "and it is an XML document")
    Do $$$AssertTrue(tImported [ "<MonthAbbr> ", "and a list of names keeps the leading space the vendor writes it with")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    For tCase = $ListBuild("digest", "0000"), $ListBuild("digest", ""), $ListBuild("replaces", 1), $ListBuild("replaces", "") {
        Kill tChanged
        Merge tChanged = tWrite
        Set tChanged($List(tCase, 1)) = $List(tCase, 2)
        Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tChanged), "409|LOCALE.IMPORT.CHANGED", "a write whose " _ $List(tCase, 1) _ " is '" _ $List(tCase, 2) _ "' is refused as changed")
    }
    Kill tChanged
    Set tChanged("replaces") = 0
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tChanged), "409|LOCALE.IMPORT.CHANGED", "a write with no reviewed digest is refused as changed")
    Kill tChanged
    Set tChanged("digest") = tReview.%Get("Digest")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tChanged), "409|LOCALE.IMPORT.CHANGED", "and so is one with no reviewed count")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText _ " ", .tWrite), "409|LOCALE.IMPORT.CHANGED", "and a file that changed by one character")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "nothing was imported by any refusal")
    Do $ClassMethod(..#PROBE, "WriteFile", "locales.xml", tText)
    Kill tServer
    Set tServer("root") = $ClassMethod(..#PROBE, "Root")
    Set tServer("path") = $ClassMethod(..#PROBE, "RelativeName", "locales.xml")
    Do $$$AssertEquals(..Call("IMPORTFILE", "", "", .tServer, .tFromFile), "200|", "a server file is reviewed")
    Do $$$AssertEquals(tFromFile.%Get("Digest") _ "|" _ tFromFile.%Get("path") _ "|" _ tFromFile.%Get("fileName") _ "|" _ tFromFile.%Get("LocaleCount"), tReview.%Get("Digest") _ "|" _ tServer("path") _ "||1", "and reads as the same file")
    Set tServer("digest") = tFromFile.%Get("Digest")
    Set tServer("replaces") = tFromFile.%Get("Replaces")
    Do $$$AssertEquals(..Call("IMPORT", "", "", .tServer) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200||IMPORT", "and is imported")
    Do $ClassMethod(..#PROBE, "WriteFile", "locales.xml", tText _ " ")
    Do $$$AssertEquals(..Call("IMPORT", "", "", .tServer) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|LOCALE.IMPORT.CHANGED|IMPORT", "a server file that changed after the review is refused as changed, with no second import")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Do $ClassMethod(..#SEAM, "FeedImportCounts", 0, 0, 0)
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor that imports fewer locales than were reviewed is a logged server error")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor error is a logged server error")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a locale that is not listed after the import is a logged server error")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(..#SEAM, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Do $ClassMethod(..#SEAM, "FeedImportCounts", 1, 0, 1)
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|INTERNAL|error", "a vendor that imports fewer tables than were reviewed is a logged server error")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Set tShipped = "XLT-Latin2-Unicode"
    Set tSuffixed = "XLT-Latin2-Unicode.0001"
    Set tSubText = ..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", tShipped) _ ..TableXml("XLT", ..#TABLE, "Latin2", tSuffixed), ..SubTableXml(tShipped) _ ..SubTableXml(tSuffixed))
    Do $$$AssertEquals(..Review(tSubText, .tSubReview), "200|", "a file whose custom tables name a shipped and a custom sub-table is reviewed")
    Do $$$AssertEquals(tSubReview.%Get("TableCount") _ "|" _ tSubReview.%Get("SubTableCount") _ "|" _ tSubReview.%Get("Skipped"), "2|1|1", "the custom sub-table is kept and the shipped one a custom table names is skipped")
    Kill tSubWrite
    Set tSubWrite("digest") = tSubReview.%Get("Digest")
    Set tSubWrite("replaces") = tSubReview.%Get("Replaces")
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tSubText, .tSubWrite), "200|", "and is imported")
    Set tSubImported = $ClassMethod(..#SEAM, "Imported")
    Do $$$AssertTrue((tSubImported [ ("<Name>" _ tSuffixed _ "</Name>")) && '(tSubImported [ ("<Name>" _ tShipped _ "</Name>")), "the vendor's file holds the custom sub-table and never the shipped one")
}

/// <p>The SHA-256 of <var>pText</var>'s UTF-8 bytes, as lower-case hex, computed here as the port's review states it.</p>
ClassMethod Digest(pText As %String) As %String
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pText, "O", "UTF8"))), "L")
}

/// <p><b>AC1, AC2 (the mint and the screen).</b> The agent's schema is closed: it names the literal target, <code>root</code> and <code>path</code>, and the agent's
/// own words, and never <code>fileName</code> or <code>content</code>, so a local file's name and text are the screen's alone; an argument that names no file is refused
/// at the mint; the mint refuses a file the port refuses, with nothing stored, and mints a card of the file, the locales, the tables and the sub-tables for one it
/// admits; the screen's values reach the port as the query keys it reads; the tool is destructive, its consequence is <code>LOCALE.IMPORT</code>, and it declares the
/// write pair, the import page and PathPort's pairs for a server file.</p>
/// <p>Mutation (Rule 19): <code>fileName</code> added to <code>LocaleImport.InputSchema</code> -> the schema row goes red; <code>PortQuery</code> dropping <code>content</code> -> the
/// screen's row goes red.</p>
Method TestTheAgentSchemaIsClosedAndTheMintRefusesWhatThePortRefuses()
{
    Set tTool = "OcuPilot.Screen.Tool.LocaleImport"
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Set tNames = ""
    Set tIterator = tSchema.%Get("properties").%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames = tNames _ tKey _ ","
    }
    Do $$$AssertEquals(tNames, "Name,rationale,expectedImpact,reverse,root,path,", "the schema holds the literal target, the server file and the agent's words, and no local file")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "and refuses any other argument")
    Do $$$AssertEquals($ClassMethod(tTool, "Destructive") _ "|" _ $Parameter(tTool, "CONSEQUENCECODE") _ "|" _ $Parameter(tTool, "CLASSICPAGES") _ "|" _ $Parameter(tTool, "WRITETYPE") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")), "1|LOCALE.IMPORT|%CSP.UI.Portal.NLSImport|IMPORT|import,import-local", "the import is destructive, performs the classic import page's operation and is reached by two screen actions")
    Do $$$AssertEquals(##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.IMPORT"), "Importing replaces any custom locale or table with the same name. This cannot be undone.", "its consequence sentence is the ruled one")
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue(tResolved && ''$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")) && ''$ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")), "it declares the screen's pairs and the write pair")
    Set tServerPairs = $ClassMethod(tTool, "ArgumentPairs", "", {"Name": "import", "root": "x", "path": "y"}, .tServerResolved)
    Do $$$AssertTrue($ListLength(tServerPairs) > 0, "and PathPort's pairs for a server file")
    Do $$$AssertEquals($ListLength($ClassMethod(tTool, "ArgumentPairs", "", {"Name": "import"}, .tNoneResolved)), 0, "and none when it names no server file")
    Do $ClassMethod(tTool, "ArgumentProblem", "import", {"Name": "import", "path": "y"}, .tProblem)
    Do $$$AssertNotEquals(tProblem, "", "an argument that names no root is refused at the mint")
    Do $ClassMethod(tTool, "ArgumentProblem", "other", {"Name": "other", "root": "x", "path": "y"}, .tProblem)
    Do $$$AssertNotEquals(tProblem, "", "and so is a target that is not the literal")
    Do $ClassMethod(tTool, "ScreenActionDelta", "import-local", {"fileName": "a.xml", "content": "<x/>"}, {"Digest": "d", "Replaces": 2}, .tArgs, .tScreenProblem)
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", tArgs, .tQuery)
    Do $$$AssertEquals(tScreenProblem _ "|" _ $Get(tQuery("fileName")) _ "|" _ $Get(tQuery("content")) _ "|" _ $Get(tQuery("digest")) _ "|" _ $Get(tQuery("replaces")) _ "|" _ $Data(tQuery("root")), "|a.xml|<x/>|d|2|0", "the screen's local file and reviewed values reach the port under its own query keys")
    Do $ClassMethod(tTool, "ScreenActionDelta", "import", {"root": "r", "path": "p.xml"}, "", .tArgs2, .tScreenProblem2)
    Kill tQuery2
    Do $ClassMethod(tTool, "PortQuery", tArgs2, .tQuery2)
    Do $$$AssertEquals($Get(tQuery2("root")) _ "|" _ $Get(tQuery2("path")) _ "|" _ $Data(tQuery2("fileName")), "r|p.xml|0", "and a server file's values do too")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Do $ClassMethod(..#PROBE, "WriteFile", "shape.xml", "<a><b></a>")
    Do $ClassMethod(..#PROBE, "WriteFile", "good.xml", ..MixedText())
    Set tSC = ##class(OcuPilot.Test.LicenseProbe).Mint(..#TOOL, "import", {"Name": "import", "root": (tRoot), "path": ($ClassMethod(..#PROBE, "RelativeName", "shape.xml"))}, .tProposal, .tHttp, .tShapeProblem)
    Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject(tProposal) && (tShapeProblem '= ""), "the mint refuses a file that is not an export, and stores nothing")
    Set tSC = ##class(OcuPilot.Test.LicenseProbe).Mint(..#TOOL, "import", {"Name": "import", "root": (tRoot), "path": ($ClassMethod(..#PROBE, "RelativeName", "good.xml"))}, .tProposal2, .tHttp2, .tProblem2)
    Do $$$AssertStatusOK(tSC, "the mint admits a file that holds custom records")
    Set tFields = ""
    If $IsObject($Get(tProposal2)) {
        Set tRows = tProposal2.%Get("changed")
        Set tRowIterator = tRows.%GetIterator()
        While tRowIterator.%GetNext(.tRowKey, .tRow) {
            Set tFields = tFields _ tRow.%Get("field") _ ","
        }
    }
    Do $$$AssertTrue(tFields [ "File,Locales,Tables,Subtables,Skipped,", "its card holds the file, the locales, the tables, the sub-tables and what is skipped, in that order: " _ tFields)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no import was made")
}

/// <p><b>AC5 (the file the port makes).</b> The file the port hands the vendor is empty and its own when the vendor is called, under the port's own temporary directory, whatever
/// the vendor's answer, and is gone afterwards: after an import that ends in a vendor error and one that raises an exception, and after an export to this browser, to a file,
/// with an error and with an exception. The vendor never receives a caller's value as its file, and the log of a vendor error holds its error number, not its text,
/// which quotes the file's values.</p>
/// <p>Mutation (Rule 19): <code>SendImport</code> not deleting the file after an error -> the error row goes red; the delete moved inside the <code>Try</code> -> the exception
/// row goes red; <code>PerformImport</code> logging the vendor's text -> the log row goes red.</p>
Method TestTheFileHandedToTheVendorIsOursAndGoneOnEveryPath()
{
    Set tPort = ..#TRANSFER
    Set tPrefix = $ClassMethod(tPort, "TransferParent") _ $Parameter(tPort, "TRANSFERDIRECTORY") _ "-"
    Do $$$AssertTrue((tPrefix '= "") && ##class(%File).DirectoryExists($ClassMethod(tPort, "TransferParent")), "the operating system's temporary directory is found")
    Set tText = ..Wrap(..LocaleXml(..#LOCALE))
    Kill tNone
    Set tHeld = ..Review(tText, .tReview, tPort)
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    For tMode = "ok", "error", "throw" {
        Do $ClassMethod(tPort, "Reset")
        Do $ClassMethod(tPort, "Mode", tMode)
        Set tOutcome = ..Call("IMPORT", "locales.xml", tText, .tWrite, , tPort)
        Do $ClassMethod(tPort, "Calls", .tCalls)
        Set tCall = $Get(tCalls(1))
        Set tFile = $Piece(tCall, "|", 2)
        Set tDirectory = $Piece(tCall, "|", 4)
        Set tDirectories(tMode) = tDirectory
        Do $$$AssertEquals($Piece(tCall, "|", 1) _ "|" _ $Piece(tCall, "|", 3) _ "|" _ ($Extract(tDirectory, 1, $Length(tPrefix)) = tPrefix) _ "|" _ ($Extract(tFile, *-3, *) = ".xml") _ "|" _ $Piece(tCall, "|", 5) _ "|" _ ##class(%File).Exists(tFile) _ "|" _ ##class(%File).DirectoryExists(tDirectory), "import|1|1|1|1|0|0", "an import with the vendor answering " _ tMode _ " hands it a file of ours in a directory made for it, and the file and the directory are gone after")
        If tMode '= "ok" Do $$$AssertEquals(tOutcome, "500|INTERNAL", "and a vendor " _ tMode _ " is a server error")
        If tMode = "error" Do $$$AssertTrue(($ClassMethod(tPort, "Logged") [ "vendor error") && '($ClassMethod(tPort, "Logged") [ "yqfilevalue"), "and the log names the vendor's error, never the file's values its text quotes")
    }
    Do $$$AssertTrue((tDirectories("ok") '= tDirectories("error")) && (tDirectories("error") '= tDirectories("throw")) && (tDirectories("ok") '= tDirectories("throw")), "three imports made three different directories")
    Do ..Review(tText, .tReview2, tPort)
    Set tQuery("name") = $ClassMethod(..#READ, "VendorGet", "", .tNoneName)
    Do $ClassMethod(tPort, "Reset")
    Set tSC = $ClassMethod(tPort, "Invoke", "Locales", "EXPORT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $ClassMethod(tPort, "Calls", .tExportCalls)
    Set tExportFile = $Piece($Get(tExportCalls(1)), "|", 2)
    Do $$$AssertEquals(tHttp _ "|" _ tResult.%Get("lines").%ToJSON() _ "|" _ ##class(%File).Exists(tExportFile), "200|[""<LocalesDeepExport/>""]|0", "an export to this browser answers the vendor's file as lines, and the file is gone")
    Set tServer("root") = $ClassMethod(..#PROBE, "Root")
    Set tServer("path") = $ClassMethod(..#PROBE, "RelativeName", "exported.xml")
    Merge tQuery = tServer
    Do $ClassMethod(..#PROBE, "WriteFile", "exported.xml", "an older file")
    Do $ClassMethod(tPort, "Reset")
    Set tSC = $ClassMethod(tPort, "Invoke", "Locales", "EXPORT", .tQuery, "", .tResult2, .tHttp2, .tFault2)
    Do $ClassMethod(tPort, "Calls", .tFileCalls)
    Set tFileTemp = $Piece($Get(tFileCalls(1)), "|", 2)
    Do $$$AssertEquals(tHttp2 _ "|" _ $ClassMethod(..#PROBE, "ReadFile", "exported.xml") _ "|" _ tResult2.%Get("path") _ "|" _ ##class(%File).Exists(tFileTemp) _ "|" _ ##class(%File).DirectoryExists($Piece($Get(tFileCalls(1)), "|", 4)), "200|<LocalesDeepExport/>|" _ tServer("path") _ "|0|0", "an export to a server file replaces the file with the vendor's, answers the file, and leaves no temporary file or directory")
    For tMode = "error", "throw" {
        Do $ClassMethod(tPort, "Reset")
        Do $ClassMethod(tPort, "Mode", tMode)
        Set tSC = $ClassMethod(tPort, "Invoke", "Locales", "EXPORT", .tQuery, "", .tResult3, .tHttp3, .tFault3)
        Do $ClassMethod(tPort, "Calls", .tModeCalls)
        Do $$$AssertEquals(tHttp3 _ "|" _ ##class(%File).Exists($Piece($Get(tModeCalls(1)), "|", 2)) _ "|" _ ##class(%File).DirectoryExists($Piece($Get(tModeCalls(1)), "|", 4)), "500|0|0", "an export with the vendor answering " _ tMode _ " is a server error and leaves no file or directory")
    }
}

/// <p><b>AC5 (the directory the port owns).</b> Each transfer's directory is made by the port, under a name no other transfer has, and a directory already at that name is
/// refused: an import and an export are a logged server error, the vendor is never called, and what was in the directory is left as it was.</p>
/// <p>Mutation (Rule 19): <code>TransferFile</code> not refusing an existing directory -> both rows go red.</p>
Method TestATransferDirectoryThatIsAlreadyThereIsRefusedAndLeftAlone()
{
    Set tPort = ..#TRANSFER
    Set tName = $Translate($System.Util.CreateGUID(), "{}", "")
    Set tDirectory = ##class(%File).NormalizeDirectory($Parameter(tPort, "TRANSFERDIRECTORY") _ "-" _ tName, $ClassMethod(tPort, "TransferParent"))
    Do $$$AssertTrue(##class(%File).CreateDirectory(tDirectory), "a directory is posed at the name the port will choose")
    Set tSentinel = ##class(%File).NormalizeFilename("sentinel.txt", tDirectory)
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Do tStream.LinkToFile(tSentinel)
    Do tStream.Write("not ours")
    Do $$$AssertStatusOK(tStream.%Save(), "and holds a file of someone else's")
    Set tStream = ""
    Set tText = ..Wrap(..LocaleXml(..#LOCALE))
    Set tHeld = ..Review(tText, .tReview, tPort)
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "FixName", tName)
    Set tOutcome = ..Call("IMPORT", "locales.xml", tText, .tWrite, , tPort)
    Do $ClassMethod(tPort, "Calls", .tCalls)
    Do $$$AssertEquals(tOutcome _ "|" _ $Data(tCalls) _ "|" _ ##class(%File).Exists(tSentinel), "500|INTERNAL|0|1", "an import into a directory that is already there is refused before the vendor, and leaves the directory's file")
    Kill tQuery
    Set tQuery("name") = $ClassMethod(..#READ, "VendorGet", "", .tNoneName)
    Set tSC = $ClassMethod(tPort, "Invoke", "Locales", "EXPORT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $ClassMethod(tPort, "Calls", .tExportCalls)
    Do $$$AssertEquals(tHttp _ "|" _ $Data(tExportCalls) _ "|" _ ##class(%File).Exists(tSentinel), "500|0|1", "and so is an export")
    Do $ClassMethod(tPort, "Reset")
    Do $$$AssertTrue(##class(%File).RemoveDirectoryTree(tDirectory), "the posed directory is removed")
}

/// <p><b>AC2 (the locks).</b> An import locks <code>import</code> and then each custom locale its file keeps, in name order and whatever order the file names them
/// in, holds all of them while the vendor is called, and releases all of them; a locale whose lock another request keeps refuses the import
/// <code>WRITE.TARGETBUSY</code> with nothing imported and every lock it took released; and a write that finds its review keeps a locale the locks did not cover is
/// <code>LOCALE.IMPORT.CHANGED</code>.</p>
/// <p>Mutation (Rule 19): <code>ImportUnderLock</code> taking only the <code>import</code> lock -> the held and busy rows go red; <code>PerformImport</code>'s covered check
/// dropped -> the changed row goes red.</p>
Method TestAnImportLocksEveryLocaleItKeepsInNameOrderAndReleasesThem()
{
    Set tSeam = ..#SEAM
    Set tText = ..Wrap(..LocaleXml(..#LOCALE) _ ..LocaleXml("yqaw"))
    Set tHeld = ..Review(tText, .tReview)
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    Do $ClassMethod(tSeam, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Do $ClassMethod(tSeam, "HoldLocale", "yqaw", "posed", 0, 1)
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(tSeam, "Calls"), "200||IMPORT", "an import of two locales is made")
    Do $$$AssertEquals($ClassMethod(tSeam, "LockedAtImport") _ "|" _ $ClassMethod(tSeam, "LockOrder") _ "|" _ $ClassMethod(tSeam, "Held"), "import,yqaw," _ ..#LOCALE _ "|import,yqaw," _ ..#LOCALE _ "|", "the vendor was called with the import and both locales locked, taken in name order, and nothing is held after")
    Do $ClassMethod(tSeam, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(tSeam, "HoldBusy", ..#LOCALE)
    Do $$$AssertEquals(..Call("IMPORT", "locales.xml", tText, .tWrite) _ "|" _ $ClassMethod(tSeam, "Calls"), "409|WRITE.TARGETBUSY|", "an import of a locale another request holds is refused as busy, with no vendor call")
    Do $$$AssertEquals($ClassMethod(tSeam, "LockOrder") _ "|" _ $ClassMethod(tSeam, "Held"), "import,yqaw|", "and the locks it took first were released")
    Do $ClassMethod(tSeam, "Reset")
    Do ##class(OcuPilot.Test.LocaleRead).HoldAll()
    Do $ClassMethod(tSeam, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Do $ClassMethod(tSeam, "HoldLocale", "yqaw", "posed", 0, 1)
    Kill tQuery
    Set tQuery("name") = "import"
    Set tQuery("fileName") = "locales.xml"
    Set tQuery("content") = tText
    Set tQuery("digest") = tReview.%Get("Digest")
    Set tQuery("replaces") = tReview.%Get("Replaces")
    Set tSC = $ClassMethod(tSeam, "ImportCovered", .tQuery, $ListBuild("yqaw"), .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(tSeam, "Calls"), "409|LOCALE.IMPORT.CHANGED|","a write whose file keeps a locale the locks did not cover is refused as changed")
    Set tSC = $ClassMethod(tSeam, "ImportCovered", .tQuery, $ListBuild("yqaw", ..#LOCALE), .tOut2, .tHttp2, .tFault2)
    Do $$$AssertEquals(tHttp2 _ "|" _ $ClassMethod(tSeam, "Calls"), "200|IMPORT", "and one whose locks cover both is imported")
}

/// <p>A file whose one kept sub-table holds more than 1,000,000 characters, named by a kept custom table.</p>
ClassMethod BigText() As %String
{
    Set tItems = ""
    For tKey = 1:1:25000 {
        Set tItems = tItems _ "<FromToItem FromToKey=""" _ tKey _ """>66</FromToItem>"
    }
    Set tSub = "<SubTables><Description>big</Description><FromTo>" _ tItems _ "</FromTo><Name>" _ ..#SUBTABLE _ "</Name><Type>0</Type></SubTables>"
    Quit ..Wrap("", ..TableXml("XLT", ..#TABLE, "Unicode", ..#SUBTABLE), tSub)
}

/// <p>The file the first lines of the import script <var>pScript</var> write, as text: every line but the namespace line and the ones from the vendor's
/// <code>ImportAll</code> on is run in this process, and the file it made is read and deleted. The vendor's call is never run.</p>
ClassMethod ScriptFile(pScript As %String) As %String [ PublicList = (tFile, tStream, tSC, tImported) ]
{
    Set tText = ""
    Set tFile = ""
    Try {
        For tI = 2:1:$Length(pScript, $Char(10)) {
            Set tLine = $Piece(pScript, $Char(10), tI)
            If tLine [ "Config.NLS.Locales).ImportAll(tFile" Quit
            Xecute tLine
        }
        Set tStream = ""
        Set tIn = ##class(%Stream.FileCharacter).%New()
        Set tIn.TranslateTable = "UTF8"
        Do tIn.LinkToFile(tFile)
        While 'tIn.AtEnd {
            Set tText = tText _ tIn.Read(32000)
        }
        Set tIn = ""
    } Catch {
        Set tText = ""
    }
    If tFile '= "" Do ##class(%File).Delete(tFile)
    Quit tText
}

/// <p><b>AD-59.</b> An import and an export each render a script of the vendor's own call and the locale as a string literal. An import of a file the query names
/// renders the records the review keeps, never the file: the script writes them line by line into a temporary file, byte for byte the file the port hands the vendor, with
/// none of the shipped records the file holds, and imports that file with the literal flags and deletes it; a script that would pass 1,000,000 characters is refused. An
/// import that names no file says the file is the one this browser sent.</p>
/// <p>Mutation (Rule 19): the flags in <code>TransferSnippet</code> changed -> the import row goes red; <code>ImportSnippet</code> rendering the import of the whole file
/// instead of the kept records, or the 1,000,000-character check dropped -> the kept-records and the cap rows go red.</p>
Method TestAnImportAndAnExportRenderTheirScript()
{
    Set tSeam = ..#SEAM
    Do $$$AssertEquals($ClassMethod(tSeam, "SnippetForm", "Locales", "IMPORT") _ "|" _ $ClassMethod(tSeam, "SnippetForm", "Locales", "EXPORT") _ "|" _ $ClassMethod(tSeam, "SnippetForm", "Locales", "IMPORTFILE"), "objectscript|objectscript|", "both writes render a script and the review renders none")
    Set tText = ..MixedText()
    Do $ClassMethod(..#PROBE, "WriteFile", "locales.xml", tText)
    Set tQuery("name") = "import"
    Set tQuery("root") = $ClassMethod(..#PROBE, "Root")
    Set tQuery("path") = $ClassMethod(..#PROBE, "RelativeName", "locales.xml")
    Set tServer = $ClassMethod(tSeam, "Snippet", "Locales", "IMPORT", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue((tServer [ "ImportAll(tFile, .tImported, 7)") && (tServer [ ("allowed directory " _ tQuery("root") _ " and the name " _ tQuery("path"))) && '(tServer [ "Set tFile = ""locales.xml"""), "an import of a server file names its directory and name and the literal flags, and imports a file the script makes")
    Do $$$AssertTrue((tServer [ "<Name>" _ ..#LOCALE _ "</Name>") && (tServer [ "<NameFrom>" _ ..#TABLE _ "</NameFrom>") && (tServer [ "<Name>" _ ..#SUBTABLE _ "</Name>"), "the script holds the custom locale, table and sub-table")
    Do $$$AssertTrue('(tServer [ "<Name>enuw</Name>") && '(tServer [ "Accent-Unicode-Unicode") && '(tServer [ "<NameTo>Latin1</NameTo>"), "and none of the shipped records the file holds")
    Kill tNone
    Do $$$AssertEquals(..Call("IMPORTFILE", "", "", .tQuery, .tReview), "200|", "the same file is reviewed")
    Do $ClassMethod(tSeam, "HoldLocale", ..#LOCALE, "posed", 0, 1)
    Kill tWrite
    Merge tWrite = tQuery
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    Do $$$AssertEquals(..Call("IMPORT", "", "", .tWrite) _ "|" _ $ClassMethod(tSeam, "Calls"), "200||IMPORT", "and imported")
    Set tScripted = ..ScriptFile(tServer)
    Do $$$AssertTrue((tScripted '= "") && (tScripted = $ClassMethod(tSeam, "Imported")), "the file the script writes is the file the port hands the vendor, byte for byte")
    Do $ClassMethod(..#PROBE, "WriteFile", "big.xml", ..BigText())
    Kill tBig
    Set tBig("name") = "import"
    Set tBig("root") = tQuery("root")
    Set tBig("path") = $ClassMethod(..#PROBE, "RelativeName", "big.xml")
    Do $$$AssertEquals(..Call("IMPORTFILE", "", "", .tBig, .tBigReview), "200|", "a file whose kept sub-table holds more than 1,000,000 characters is reviewed")
    Do $$$AssertEquals($ClassMethod(tSeam, "Snippet", "Locales", "IMPORT", .tBig).%Size(), 0, "and its script is refused whole")
    Kill tAbsent
    Set tAbsent("name") = "import"
    Set tAbsent("root") = tQuery("root")
    Set tAbsent("path") = $ClassMethod(..#PROBE, "RelativeName", "absent.xml")
    Set tAbsentSteps = $ClassMethod(tSeam, "Snippet", "Locales", "IMPORT", .tAbsent)
    Do $$$AssertEquals(tAbsentSteps.%Size() _ "|" _ tAbsentSteps.%Get(0).%Get("kind"), "1|comment", "and a file the import refuses renders its refusal as one comment")
    Kill tLocal
    Set tLocal("name") = "import"
    Set tLocalScript = $ClassMethod(tSeam, "Snippet", "Locales", "IMPORT", .tLocal).%Get(0).%Get("text")
    Do $$$AssertTrue((tLocalScript [ "ImportAll(tFile, .tImported, 7)") && (tLocalScript [ "this browser sent"), "an import of a local file says it is the file this browser sent")
    Set tLocal("fileName") = "mine.xml"
    Set tLocal("content") = tText
    Set tLocalScript = $ClassMethod(tSeam, "Snippet", "Locales", "IMPORT", .tLocal).%Get(0).%Get("text")
    Do $$$AssertTrue((tLocalScript [ "this browser sent") && '(tLocalScript [ "<Name>") && '(tLocalScript [ "mine.xml"), "and a local file's name and text are never in the script")
    Kill tExport
    Set tExport("name") = "yq""zw"
    Set tExportScript = $ClassMethod(tSeam, "Snippet", "Locales", "EXPORT", .tExport).%Get(0).%Get("text")
    Do $$$AssertTrue((tExportScript [ "ExportList(tFile, .tExported, .tLocales)") && (tExportScript [ "Set tLocales(""yq""""zw"") = """""), "an export puts the locale in a string literal, a quote doubled")
}

}
