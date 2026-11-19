/// <p>Pins Story 21.15's export and import on both callers (AC1, AC2, AC6; DW-2606; AD-6, AD-21, AD-51, AD-53, AD-58) against the real instance: a custom locale the
/// test made is exported to this browser by the screen's action and, by the agent's confirmed proposal, to a server file that already holds another text, which it
/// replaces; the locale is deleted and imported back from the browser's lines by the screen's action and, from the server file, by the agent's proposal, each listing it
/// again with a definition equal to the original's and a matching read-back; an agent's import is refused once its file has changed after the mint, with nothing imported; an
/// export of a locale past the browser's cap is <code>LOCALE.TOOLARGE</code>; the port's counts equal the file's; a file holding a record the vendor's class rejects
/// writes nothing; and no transfer directory is left.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory as an allowed root, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the class creates, exports, deletes and imports custom locales. The custom locales <parameter>COPYA</parameter> are made from the
/// current locale's definition; the current locale is never changed. Every test deletes the locales it made and the files it wrote on every path
/// (<method>Restore</method>) and puts the governance policy back.</p>
Class OcuPilot.Test.LocaleTransferWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.LocalePort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter READ = "OcuPilot.Test.LocalePropertyRead";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter LOCALESCREEN = "osmgmt.locales";

Parameter KEYS = "osmgmt.locales.import,osmgmt.locales.export";

/// <p>The custom locale every test makes.</p>
Parameter COPYA = "yqaw";

/// <p>The custom locale whose record the vendor's class rejects, which a test only tries to import.</p>
Parameter REJECTED = "yqbw";

/// <p>The custom table and the custom sub-table it names, which the tests that need them make.</p>
Parameter TABLEA = "yqtab";

Parameter SUBA = "XLT-yqtab-Unicode";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Property PreparedLocale As %String [ InitialExpression = "" ];

/// <p>How many transfer directories the port had in the temporary directory before the test, which the test leaves as it found.</p>
Property PreparedTransferFiles As %Integer [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LocaleTransferWrite creates, exports, deletes and imports custom locales on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set ..PreparedLocale = $ClassMethod(..#READ, "VendorGet", "", .tNone)
    Do ..Restore()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ..Restore()
    Set ..PreparedTransferFiles = ..TransferFiles()
    Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnableKeys()
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Do $$$AssertEquals(..VendorExists(..#COPYA) _ "|" _ ..VendorTableExists(), "0|0|0", "the custom locale, table and sub-table are gone")
    Do $$$AssertEquals($ClassMethod(..#READ, "VendorGet", "", .tNone), ..PreparedLocale, "the current locale is as the class found it")
    Do $$$AssertEquals(..TransferFiles(), ..PreparedTransferFiles, "no transfer directory of this test is left in the temporary directory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveDirectory"), "the probe directory is removed")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Delete the custom locales, table and sub-table, in <code>%SYS</code>.</p>
Method Restore()
{
    Do ..VendorDelete(..#COPYA)
    Do ..VendorDelete(..#REJECTED)
    Do ..VendorDeleteTable()
}

/// <p>Create the custom sub-table and the custom table that names it, as the test's own setup.</p>
ClassMethod VendorMakeTable() As %Boolean
{
    Set tOK = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSub("Description") = "transfer test sub-table"
        Set tSub("Type") = 0
        Set tSub("FromTo", 65) = 66
        Set tSub("FromTo", 67) = 68
        Set tTable("Description") = "transfer test table"
        Set tTable("SubTableName") = ..#SUBA
        Set tOK = $$$ISOK(##class(Config.NLS.SubTables).Create(..#SUBA, .tSub)) && $$$ISOK(##class(Config.NLS.Tables).Create("XLT", ..#TABLEA, "Unicode", .tTable))
    } Catch {
        Set tOK = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOK
}

ClassMethod VendorDeleteTable()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.NLS.Tables).Exists("XLT", ..#TABLEA, "Unicode") Do ##class(Config.NLS.Tables).Delete("XLT", ..#TABLEA, "Unicode")
        If ##class(Config.NLS.SubTables).Exists(..#SUBA) Do ##class(Config.NLS.SubTables).Delete(..#SUBA)
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>Whether the custom table and the custom sub-table exist, as <code>table|subTable</code>.</p>
ClassMethod VendorTableExists() As %String
{
    Set tOut = "0|0"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tOut = (''##class(Config.NLS.Tables).Exists("XLT", ..#TABLEA, "Unicode")) _ "|" _ (''##class(Config.NLS.SubTables).Exists(..#SUBA))
    } Catch {
        Set tOut = "0|0"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The vendor's own definitions of the custom table in <var>pTable</var> and sub-table in <var>pSub</var> (<code>Get</code> arrays), and its own serialization of
/// each in <var>pTableXml</var> and <var>pSubXml</var>.</p>
ClassMethod VendorTableRead(Output pTable, Output pSub, Output pTableXml As %String, Output pSubXml As %String)
{
    Kill pTable, pSub
    Set pTableXml = ""
    Set pSubXml = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Tables).Get("XLT", ..#TABLEA, "Unicode", .tTable)
        Merge pTable = tTable
        Set tSC = ##class(Config.NLS.SubTables).Get(..#SUBA, .tSub)
        Merge pSub = tSub
        Set tTableObject = ##class(Config.NLS.Tables).%OpenId("XLT||" _ ..#TABLEA _ "||Unicode")
        Do tTableObject.XMLExportToString(.pTableXml, "Tables")
        Set tSubObject = ##class(Config.NLS.SubTables).%OpenId(..#SUBA)
        Do tSubObject.XMLExportToString(.pSubXml, "SubTables")
    } Catch {
        Set pTableXml = ""
        Set pSubXml = ""
    }
    Set tTableObject = ""
    Set tSubObject = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>The port's answer to <var>pType</var> for the local file <var>pContent</var>, with <var>pQuery</var> added; <code>http|code</code>, the answer in
/// <var>pOut</var>.</p>
ClassMethod Port(pType As %String, pContent As %String, ByRef pQuery, Output pOut) As %String
{
    Set pQuery("name") = "import"
    Set pQuery("fileName") = "records.xml"
    Set pQuery("content") = pContent
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", pType, .pQuery, "", .pOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

Method EnableKeys() As %Status
{
    Kill tSettings
    For tI = 1:1:$Length(..#KEYS, ",") Set tSettings($Piece(..#KEYS, ",", tI)) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>How many transfer directories the port has left in the operating system's temporary directory.</p>
ClassMethod TransferFiles() As %Integer
{
    Set tCount = 0
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Set tSC = tRS.Execute($ClassMethod(..#PORT, "TransferParent"), $Parameter(..#PORT, "TRANSFERDIRECTORY") _ "-*", "", 0)
    While tRS.Next() {
        If tRS.Get("Type") = "D" Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Create the locale <var>pName</var> from the current locale's definition, as the test's own setup.</p>
ClassMethod VendorCopy(pName As %String) As %Boolean
{
    Set tOK = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tSC = ##class(Config.NLS.Locales).Get(tCurrent, .tProps)
        Set tProps("Name") = pName
        Set tProps("Description") = "transfer test copy"
        Set tOK = $$$ISOK(##class(Config.NLS.Locales).Create(pName, .tProps))
    } Catch {
        Set tOK = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOK
}

ClassMethod VendorDelete(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.NLS.Locales).Exists(pName) Do ##class(Config.NLS.Locales).Delete(pName)
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

ClassMethod VendorExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Config.NLS.Locales).Exists(pName)
    } Catch {
        Set tExists = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>The leaf nodes whose value differs between the definitions <var>pA</var> and <var>pB</var> (<code>Get</code> arrays), as <code>key;key;</code>.</p>
ClassMethod Changed(ByRef pA, ByRef pB) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pA(tKey))
        If tKey = "" Quit
        If $Data(pA(tKey)) = 1 {
            If $Get(pB(tKey), $Char(0)) '= pA(tKey) Set tOut = tOut _ tKey _ ";"
            Continue
        }
        Set tSub = ""
        For {
            Set tSub = $Order(pA(tKey, tSub))
            If tSub = "" Quit
            If $Get(pB(tKey, tSub), $Char(0)) '= pA(tKey, tSub) Set tOut = tOut _ tKey _ ":" _ tSub _ ";"
        }
    }
    Set tKey = ""
    For {
        Set tKey = $Order(pB(tKey))
        If tKey = "" Quit
        If $Data(pB(tKey)) = 1 {
            If '$Data(pA(tKey)) Set tOut = tOut _ tKey _ ";"
            Continue
        }
        Set tSub = ""
        For {
            Set tSub = $Order(pB(tKey, tSub))
            If tSub = "" Quit
            If '$Data(pA(tKey, tSub)) Set tOut = tOut _ tKey _ ":" _ tSub _ ";"
        }
    }
    Quit tOut
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> of screen <var>pScreen</var> with <var>pValues</var>; the parsed envelope in <var>pAnswer</var>, answering the
/// HTTP status.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with <var>pArgs</var> and confirm it; answers <code>http code</code> and the confirm's answer in <var>pResult</var>, or
/// <code>refused: &lt;problem&gt;</code> when the mint refused.</p>
ClassMethod Agent(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, pArgs, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", tProposal, .pResult)
}

/// <p>The lines of the screen's answer <var>pAnswer</var> as the file the browser would save: each line ended by a line feed.</p>
ClassMethod Saved(pAnswer As %DynamicObject) As %String
{
    Set tText = ""
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("output")) || (pAnswer.%Get("output").%GetTypeOf("lines") '= "array") Quit ""
    Set tIterator = pAnswer.%Get("output").%Get("lines").%GetIterator()
    While tIterator.%GetNext(.tKey, .tLine) {
        Set tText = tText _ tLine _ $Char(10)
    }
    Quit tText
}

/// <p><b>AC1, AC2.</b> A custom locale is exported to this browser by the screen's action, deleted, and imported back from the lines the browser saved by the screen's action
/// (<code>import-local</code>), the locale listed again with the definition it had and a matching read-back and the vendor's counts answered; then exported to a server file
/// by the agent, deleted, and imported from that file by the agent's confirmed proposal, with the same result; and an agent's import whose file changes after the mint is
/// refused with nothing imported. A text with a record of the locale InterSystems ships beside the custom one imports the custom one alone. No temporary file is left.</p>
/// <p>Mutation (Rule 19): <code>SendImport</code> passing flags 3 (no locales) -> the listed-again rows go red. The changed-file row pins the proposal's fingerprint
/// (<code>PROPOSAL.TARGETCHANGED</code>), which refuses before the port's own digest compare runs.</p>
Method TestAnExportIsImportedBackOnBothCallersAndAChangedFileIsRefused()
{
    Do $$$AssertTrue(..VendorCopy(..#COPYA), "the custom locale is made as the test's own setup")
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tOriginal)
    Set tStatus = ..Act(..#LOCALESCREEN, "export-browser", ..#COPYA, "", .tAnswer)
    Set tText = ..Saved(tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's export to this browser answers")
    Do $$$AssertTrue((tText [ ("<Name>" _ ..#COPYA _ "</Name>")) && (tText [ "<LocalesDeepExport>"), "its lines hold the locale's record in the vendor's export form")
    Do ..VendorDelete(..#COPYA)
    Do $$$AssertEquals(..VendorExists(..#COPYA), 0, "the locale is deleted")
    Set tStatus = ..Act(..#LOCALESCREEN, "import-local", "import", {"fileName": "yqaw.xml", "content": (tText)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..VendorExists(..#COPYA), "200||matches|1", "the screen's import of the local file lists the locale again, and reads back matching: " _ $Extract($Get(tAnswer), 1, 200))
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tAfter)
    Set tDiffers = ..Changed(.tOriginal, .tAfter)
    Do $$$AssertEquals(tDiffers, "", "its definition is the one it had (" _ tDiffers _ ")")
    Do $$$AssertEquals($Select($IsObject(tAnswer.%Get("output")): tAnswer.%Get("output").%Get("Locales"), 1: -1), 1, "and the vendor's count of imported locales is answered")
    Do ..VendorDelete(..#COPYA)
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "yqaw.xml")
    Do $ClassMethod(..#PROBE, "WriteFile", "yqaw.xml", tText)
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..VendorExists(..#COPYA), "200 |matches|1", "the agent's confirmed import of the server file lists the locale again: " _ tOutcome)
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tAgent)
    Do $$$AssertEquals(..Changed(.tOriginal, .tAgent), "", "with the definition it had")
    Do ..VendorDelete(..#COPYA)
    Set ^||OcuPilotDatabaseWritePort = $Parameter("OcuPilot.Screen.Tool.LocaleImport", "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.LocaleImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's mint of the import is a proposal: " _ $Get(tProblem))
    Do $ClassMethod(..#PROBE, "WriteFile", "yqaw.xml", tText _ " ")
    Set tChanged = $ClassMethod(..#AGENT, "Confirm", tProposal, .tChangedResult)
    Do $$$AssertEquals(tChanged _ "|" _ ..VendorExists(..#COPYA), "409 PROPOSAL.TARGETCHANGED|0", "a file that changed after the mint is refused (" _ tChanged _ "), and nothing is imported")
    Do ..VendorDelete(..#COPYA)
    Set tMixed = $Replace(tText, "</LocalesExport>", ..CurrentRecord() _ $Char(10) _ "</LocalesExport>")
    Set tStatus = ..Act(..#LOCALESCREEN, "import-local", "import", {"fileName": "mixed.xml", "content": (tMixed)}, .tMixedAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..VendorExists(..#COPYA) _ "|" _ ($ClassMethod(..#READ, "VendorGet", "", .tNone2) = ..PreparedLocale), "200|1|1", "a file with the current locale's record beside the custom one imports the custom one and leaves the current locale as it was")
}

/// <p><b>AC6.</b> With the default baseline's export key, a custom locale is exported to this browser by the screen's action and, by the agent's confirmed proposal, to a server
/// file that already holds another text; the screen's lines and the replaced file each hold the locale's record and as many tables and sub-tables as the vendor's own counts
/// answer, the locale is unchanged, a locale past the browser's cap is <code>LOCALE.TOOLARGE</code> to this browser and still exports to a file, and no temporary file is left.</p>
/// <p>Mutation (Rule 19): <code>SendExport</code> filling the vendor's list with the current locale instead of the target -> the file's record row goes red.</p>
Method TestALocaleIsExportedToThisBrowserAndToAServerFileOnBothCallers()
{
    Do $$$AssertTrue(..VendorCopy(..#COPYA), "the custom locale is made as the test's own setup")
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tBefore)
    Set tStatus = ..Act(..#LOCALESCREEN, "export-browser", ..#COPYA, "", .tAnswer)
    Set tLines = ..Saved(tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's export to this browser answers")
    Set tQuery("name") = ..#COPYA
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "EXPORT", .tQuery, "", .tCounts, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the port exports the locale")
    Do $$$AssertEquals(($Length(tLines, "<Locales>") - 1) _ "|" _ ($Length(tLines, "<Tables>") - 1) _ "|" _ ($Length(tLines, "<SubTables>") - 1), tCounts.%Get("Locales") _ "|" _ tCounts.%Get("Tables") _ "|" _ tCounts.%Get("SubTables"), "the lines hold the locale, and as many tables and sub-tables as the vendor counted")
    Do $$$AssertEquals($Length(tLines, "<Name>" _ ..#COPYA _ "</Name>") - 1, 1, "and the record of the one locale asked for")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "exported.xml")
    Do $ClassMethod(..#PROBE, "WriteFile", "exported.xml", "an older file")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.LocaleExport", ..#COPYA, {"Name": (..#COPYA), "root": (tRoot), "path": (tPath)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |nothingSent", "the agent's confirmed export to a server file answers: " _ tOutcome)
    Set tFile = $ClassMethod(..#PROBE, "ReadFile", "exported.xml")
    Do $$$AssertTrue((tFile '[ "an older file") && (tFile [ ("<Name>" _ ..#COPYA _ "</Name>")), "the file at that name is replaced by the locale's export")
    Do $$$AssertEquals(($Length(tFile, "<Locales>") - 1) _ "|" _ ($Length(tFile, "<Tables>") - 1) _ "|" _ ($Length(tFile, "<SubTables>") - 1), tCounts.%Get("Locales") _ "|" _ tCounts.%Get("Tables") _ "|" _ tCounts.%Get("SubTables"), "and holds as many tables and sub-tables as the vendor counted")
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "the locale is unchanged")
    Set tLarge = ""
    Do $$$AssertEquals(..LargestLocale(.tLarge), 1, "the instance lists a locale whose export is past the browser's cap")
    If tLarge '= "" {
        Set tStatus = ..Act(..#LOCALESCREEN, "export-browser", tLarge, "", .tLargeAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tLargeAnswer), "409|LOCALE.TOOLARGE", "an export of " _ tLarge _ " to this browser is too large")
        Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.LocaleExport", tLarge, {"Name": (tLarge), "root": (tRoot), "path": (tPath)}, .tLargeResult), "200 ", "and one to a server file is not")
        Do $$$AssertTrue(##class(%File).GetFileSize($ClassMethod(..#PROBE, "Directory") _ "exported.xml") > 3000000, "and writes the whole file")
    }
}

/// <p><b>AC2.</b> An import of a custom locale, table and sub-table the instance already holds counts all three as replaced: the review answers <code>Replaces</code> 3, the
/// agent's card holds a <code>Replaced</code> row of 3, a write whose reviewed count is not 3 is <code>LOCALE.IMPORT.CHANGED</code> with the locale as it was, and the write
/// with the reviewed count imports one of each.</p>
/// <p>Mutation (Rule 19): <code>ReplacedCount</code> always answering 0 -> the review, card and changed-count rows go red.</p>
Method TestAnImportOverExistingRecordsCountsThemAndRefusesAChangedCount()
{
    Set tImportRules = "OcuPilot.Test.LocaleImportRules"
    Do $$$AssertTrue(..VendorCopy(..#COPYA) && ..VendorMakeTable(), "the custom locale, table and sub-table are made as the test's own setup")
    Do ..VendorTableRead(.tTable, .tSub, .tTableXml, .tSubXml)
    Set tText = $ClassMethod(tImportRules, "Wrap", $ClassMethod(tImportRules, "LocaleXml", ..#COPYA), tTableXml, tSubXml)
    Kill tQuery
    Set tReviewed = ..Port("IMPORTFILE", tText, .tQuery, .tReview)
    Do $$$AssertEquals(tReviewed _ "|" _ tReview.%Get("LocaleCount") _ "|" _ tReview.%Get("TableCount") _ "|" _ tReview.%Get("SubTableCount") _ "|" _ tReview.%Get("Replaces"), "200||1|1|1|3", "the review counts the three records the instance already holds as replaced")
    Set tRoot = $ClassMethod(..#PROBE, "Root")
    Set tPath = $ClassMethod(..#PROBE, "RelativeName", "replace.xml")
    Do $ClassMethod(..#PROBE, "WriteFile", "replace.xml", tText)
    Set ^||OcuPilotDatabaseWritePort = $Parameter("OcuPilot.Screen.Tool.LocaleImport", "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.LocaleImport", "import", {"Name": "import", "root": (tRoot), "path": (tPath)}, .tProposal, .tHttp, .tProblem)
    Set tReplaced = ""
    If $IsObject($Get(tProposal)) {
        Set tIterator = tProposal.%Get("changed").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("field") = "Replaced" Set tReplaced = tRow.%Get("after")
        }
    }
    Do $$$AssertEquals(tReplaced, 3, "the agent's card holds a Replaced row of 3: " _ $Get(tProblem))
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tBefore)
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = 0
    Do $$$AssertEquals(..Port("IMPORT", tText, .tWrite, .tNone), "409|LOCALE.IMPORT.CHANGED", "a write whose reviewed count is not the present count is refused as changed")
    Do $ClassMethod(..#READ, "VendorGet", ..#COPYA, .tAfter)
    Do $$$AssertEquals(..Changed(.tBefore, .tAfter), "", "and the locale is as it was")
    Kill tWrite
    Set tWrite("digest") = tReview.%Get("Digest")
    Set tWrite("replaces") = tReview.%Get("Replaces")
    Set tWritten = ..Port("IMPORT", tText, .tWrite, .tOut)
    Do $$$AssertEquals(tWritten _ "|" _ $Select($IsObject(tOut): tOut.%Get("Locales") _ "|" _ tOut.%Get("Tables") _ "|" _ tOut.%Get("SubTables"), 1: ""), "200||1|1|1", "the write with the reviewed count imports one of each")
}

/// <p><b>AC1.</b> A custom table and its sub-table, in the vendor's own serialization, are deleted and imported back: the review counts one of each and none replaced, the
/// screen's import answers the review's counts, and the vendor's own <code>Get</code> of each is the definition it had, the table still naming its sub-table.</p>
/// <p>Mutation (Rule 19): <code>ScanImport</code> dropping a kept record's attributes -> the sub-table's definition row goes red.</p>
Method TestACustomTableAndItsSubTableAreImportedBackWithTheirDefinitions()
{
    Do $$$AssertTrue(..VendorMakeTable(), "the custom sub-table and table are made as the test's own setup")
    Do ..VendorTableRead(.tTable, .tSub, .tTableXml, .tSubXml)
    Do $$$AssertTrue((tTableXml [ ("<NameFrom>" _ ..#TABLEA _ "</NameFrom>")) && (tSubXml [ "FromToKey=""65"""), "the vendor's own serialization holds the table and the sub-table's items")
    Set tText = $ClassMethod("OcuPilot.Test.LocaleImportRules", "Wrap", "", tTableXml, tSubXml)
    Do ..VendorDeleteTable()
    Do $$$AssertEquals(..VendorTableExists(), "0|0", "both are deleted")
    Kill tQuery
    Set tReviewed = ..Port("IMPORTFILE", tText, .tQuery, .tReview)
    Do $$$AssertEquals(tReviewed _ "|" _ tReview.%Get("LocaleCount") _ "|" _ tReview.%Get("TableCount") _ "|" _ tReview.%Get("SubTableCount") _ "|" _ tReview.%Get("Replaces"), "200||0|1|1|0", "the review counts one table and one sub-table, none replaced")
    Set tStatus = ..Act(..#LOCALESCREEN, "import-local", "import", {"fileName": "tables.xml", "content": (tText)}, .tAnswer)
    Set tCounts = $Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("output")): tAnswer.%Get("output").%Get("Locales") _ "|" _ tAnswer.%Get("output").%Get("Tables") _ "|" _ tAnswer.%Get("output").%Get("SubTables"), 1: "none")
    Do $$$AssertEquals(tStatus _ "|" _ tCounts, "200|" _ tReview.%Get("LocaleCount") _ "|" _ tReview.%Get("TableCount") _ "|" _ tReview.%Get("SubTableCount"), "the screen's import answers the review's counts: " _ $Extract($Get(tAnswer), 1, 200))
    Do $$$AssertEquals(..VendorTableExists(), "1|1", "both exist again")
    Do ..VendorTableRead(.tTableAfter, .tSubAfter, .tTableXmlAfter, .tSubXmlAfter)
    Do $$$AssertEquals(..Changed(.tTable, .tTableAfter), "", "the table is the definition it had")
    Do $$$AssertEquals(..Changed(.tSub, .tSubAfter), "", "the sub-table is the definition it had, its items included")
    Do $$$AssertEquals($Get(tTableAfter("SubTableName")), ..#SUBA, "and the table still names its sub-table")
}

/// <p><b>AC1.</b> A file whose second custom locale the vendor's own class rejects (a <code>DateFormat</code> that is not a number) is refused
/// <code>LOCALE.IMPORT.SHAPE</code> at the review and at a write that carries the file's own digest, and the good locale before it is not written.</p>
/// <p>Mutation (Rule 19): <code>KeptRecordsValid</code> dropped from <code>ImportReview</code> -> the review, write and written rows go red, the write reaching the vendor,
/// which writes the first locale and fails on the second.</p>
Method TestARecordTheVendorRejectsLeavesTheLocaleBeforeItUnwritten()
{
    Set tImportRules = "OcuPilot.Test.LocaleImportRules"
    Set tText = $ClassMethod(tImportRules, "Wrap", $ClassMethod(tImportRules, "LocaleXml", ..#COPYA) _ $ClassMethod(tImportRules, "BadLocaleXml", ..#REJECTED))
    Kill tQuery
    Do $$$AssertEquals(..Port("IMPORTFILE", tText, .tQuery, .tReview), "409|LOCALE.IMPORT.SHAPE", "the review of the file is refused as not an export")
    Kill tWrite
    Set tWrite("digest") = $ClassMethod(tImportRules, "Digest", tText)
    Set tWrite("replaces") = 0
    Do $$$AssertEquals(..Port("IMPORT", tText, .tWrite, .tOut), "409|LOCALE.IMPORT.SHAPE", "and so is its write, which carries the file's own digest")
    Do $$$AssertEquals(..VendorExists(..#COPYA) _ "|" _ ..VendorExists(..#REJECTED), "0|0", "neither locale is written")
}

/// <p>The current locale's own record,<code>&lt;Locales&gt;...&lt;/Locales&gt;</code>, as the vendor serializes it.</p>
ClassMethod CurrentRecord() As %String
{
    Set tXml = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLocale = ##class(Config.NLS.Locales).%OpenId($Get(^%SYS("LOCALE", "CURRENT")))
        Do tLocale.XMLExportToString(.tXml, "Locales")
    } Catch {
        Set tXml = ""
    }
    Set tLocale = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tXml
}

/// <p>The name of a shipped locale whose export holds more characters than the browser's cap, in <var>pName</var>, answering 1 when there is one: the largest the instance
/// lists among <code>zdsw</code>, <code>zduw</code>, <code>jpnw</code>, <code>jpuw</code>, <code>jpww</code> and <code>chsw</code>.</p>
ClassMethod LargestLocale(Output pName As %String) As %Boolean
{
    Set pName = ""
    For tName = "zdsw", "zduw", "jpnw", "jpuw", "jpww", "chsw" {
        If ..VendorExists(tName) {
            Set pName = tName
            Quit
        }
    }
    Quit (pName '= "")
}

}
