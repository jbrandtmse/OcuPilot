/// <p>Pins the edges of Story 20.5 that its sibling classes leave open (AD-6, AD-13, AD-35, AD-53, AD-62), against probe lookup tables
/// and a probe business partner in <code>USER</code>: a partner with no contacts; the largest table and key the vendor stores together;
/// names full of the characters a URL, a JSON body and an XML file treat specially; keys that differ only in case; the removal of an
/// entry under a credential-named key; an export over a file that stands there; the import's read and the export leaving
/// <code>^Ens.LookupTable</code> as it was; an agent's add or set that meets a key someone took or a held vendor lock; and the table
/// delete's read under source control.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account, the
/// manager directory as an allowed root and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes what it makes.</p>
Class OcuPilot.Test.InteropLookupEdges Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropLookupControl";

Parameter ITEMCONTROL = "OcuPilot.Test.InteropItemControl";

Parameter TRANSFER = "OcuPilot.Test.InteropLookupTransfer";

Parameter REFUSALS = "OcuPilot.Test.InteropLookupRefusals";

Parameter PROBE = "OcuPilot.Test.ExplorerTransferProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter LEDGER = "OcuPilot.Test.Ledger";

/// <p>The value an entry holds under a credential-named key, which no card, answer, ledger row or audit row may carry.</p>
Parameter SECRETVALUE = "ocu-hunter2-205";

Parameter TABLE = "OcuProbe205Edge";

Parameter BAREPARTNER = "OcuProbe205Bare";

Parameter ENTRYSCREEN = "/screens/interop.lookupentries";

Parameter TABLESCREEN = "/screens/interop.lookuptables";

Parameter PARTNERSCREEN = "/screens/interop.businesspartners";

/// <p>The characters a query string, a JSON body, an XML file and a quoted literal each treat specially.</p>
Parameter SPECIAL = " &=+%#?/\""'<>";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupEdges writes probe lookup tables and a probe business partner in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..Reset()
}

Method OnAfterAllTests() As %Status
{
    Quit ..Reset()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Reset()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK(..Reset(), "the probe tables, the bare partner and the probe directory are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Remove every probe table and partner, the bare partner and the probe directory, and make the directory again.</p>
ClassMethod Reset() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISOK(tSC) Set tSC = ..BarePartner(0)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "MakeDirectory")
    Quit tSC
}

/// <p>Save the bare partner, a business partner that holds only its name, when <var>pPut</var> is true; else remove it when it is there.</p>
ClassMethod BarePartner(pPut As %Boolean) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "USER"
        If pPut {
            Set tPartner = ##class(Ens.Config.BusinessPartner).%New()
            Set tPartner.PartnerName = ..#BAREPARTNER
            Set tSC = tPartner.%Save()
            Set tPartner = ""
        } ElseIf ##class(Ens.Config.BusinessPartner).%ExistsId(..#BAREPARTNER) {
            Set tSC = ##class(Ens.Config.BusinessPartner).%DeleteId(..#BAREPARTNER)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the bare partner is there.</p>
ClassMethod BarePartnerExists() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "USER"
        Set tExists = ##class(Ens.Config.BusinessPartner).%ExistsId(..#BAREPARTNER)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ''tExists
}

/// <p>One request as a browser sends it (a UTF-8 JSON body, a percent-encoded query): the HTTP status and the parsed answer.</p>
ClassMethod Send(pMethod As %String, pPath As %String, pBody As %DynamicObject = "", Output pStatus As %Integer, Output pAnswer)
{
    Set tBytes = ""
    If $IsObject(pBody) {
        Set tBytes = ##class(%Stream.GlobalBinary).%New()
        Do tBytes.Write($ZConvert(pBody.%ToJSON(), "O", "UTF8"))
    }
    Do ##class(OcuPilot.Test.Http).MakeRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=USER", .pStatus, .pAnswer, "", "", tBytes)
}

/// <p><var>pText</var> as a query-string value: its UTF-8 bytes, every reserved character percent-encoded.</p>
ClassMethod Encoded(pText As %String) As %String
{
    Quit $Replace($ZConvert($ZConvert(pText, "O", "UTF8"), "O", "URL"), "/", "%2F")
}

/// <p>The rows of the screen read <var>pScreen</var> asked for <var>pQuery</var> (already encoded), and the HTTP status.</p>
ClassMethod ReadRows(pScreen As %String, pQuery As %String, Output pStatus As %Integer) As %DynamicArray
{
    Do $ClassMethod(..#ITEMCONTROL, "Call", "GET", pScreen _ "/read?maxRows=1000" _ $Select(pQuery = "": "", 1: "&" _ pQuery), "", .pStatus, .tAnswer)
    Quit $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")): tAnswer.%Get("rows"), 1: "")
}

/// <p>AC6: a partner that holds only its name lists with every contact field empty, through the port and the screen's read; and a remove
/// sent to the partners screen is refused and the partner stays. That last assertion is temporary (the stated partial): it is deleted in
/// the pass that lands Story 20.26's partner remove, with the tool that performs it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListPartners</method> skip a partner whose primary contact has no name --
/// the bare partner is not listed and this goes red.</p>
Method TestAPartnerWithNoContactsListsWithEmptyContactFields()
{
    Do $$$AssertStatusOK(..BarePartner(1), "a partner holding only its name is saved")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "BusinessPartners", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the partners list answers with the bare partner held: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Set tBare = ..RowNamed($Get(tRows), ..#BAREPARTNER)
    Do $$$AssertTrue($IsObject(tBare), "the bare partner is listed")
    If $IsObject(tBare) {
        Set tFilled = ""
        Set tIterator = tBare.%GetIterator()
        While tIterator.%GetNext(.tField, .tValue) {
            If (tField '= "Name") && (tValue '= "") Set tFilled = tFilled _ tField _ " "
        }
        Do $$$AssertEquals(tFilled, "", "and every field beyond its name is empty: " _ tBare.%ToJSON())
    }
    Set tRows = ..ReadRows(..#PARTNERSCREEN, "", .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers too")
    Do $$$AssertTrue($IsObject(..RowNamed(tRows, ..#BAREPARTNER)), "and lists the bare partner")
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", ..#BAREPARTNER, "string")
    Do ..Send("POST", ..#PARTNERSCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertTrue((tStatus >= 400) && (tStatus < 500), "a remove sent to the partners screen is refused: " _ tStatus)
    Do $$$AssertEquals(..BarePartnerExists(), 1, "and the partner is still there")
}

/// <p>The row of the list <var>pRows</var> whose <code>Name</code> is <var>pName</var>, or <code>""</code>.</p>
ClassMethod RowNamed(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>AC2, AC4: the largest pair of table and key the vendor stores together -- 255 characters and 238, in either order, with a value
/// of 32,000 -- is added by the Save, read back by both lists, changed by Set value, removed by Remove and the table deleted by Delete.
/// The pair is one global reference, which a longer pair overflows, so the per-field bounds alone pin nothing end to end.</p>
/// <p>Mutation (Rule 19): lower <code>TABLEMAX</code> or <code>KEYMAX</code> in <class>OcuPilot.Port.InteropPort</class> to 254 -- the
/// Save of that shape is refused 422 and this goes red.</p>
Method TestTheLargestPairTheVendorStoresIsAddedChangedReadAndRemovedThroughTheRoutes()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Set tValue = $Translate($Justify("", 32000), " ", "v")
    For tShape = $ListBuild(255, 238), $ListBuild(238, 255) {
        Set tTable = $Translate($Justify("", $List(tShape, 1)), " ", "t")
        Set tKey = $Translate($Justify("", $List(tShape, 2)), " ", "k")
        Set tLabel = $List(tShape, 1) _ "-character table, " _ $List(tShape, 2) _ "-character key"
        Set tText = $ClassMethod(tControl, "Save", tTable, tKey, tValue, .tAnswer)
        Do $$$AssertEquals(tText, "201 ", tLabel _ ": the Save answers 201: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer), 1, 300))
        Set tStored = $ClassMethod(tFixture, "Entries", tTable)
        Do $$$AssertEquals(tStored = (tKey _ "=" _ tValue), 1, tLabel _ ": the entry is stored whole, " _ $Length(tStored) _ " characters")
        Set tRows = ..ReadRows(..#ENTRYSCREEN, "table=" _ ..Encoded(tTable), .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200 1", tLabel _ ": the entries list answers one row")
        If $IsObject(tRows) && (tRows.%Size() = 1) {
            Set tRow = tRows.%Get(0)
            Do $$$AssertEquals((tRow.Table = tTable) && (tRow.Key = tKey) && (tRow.Value = tValue), 1, tLabel _ ": the row carries the table, the key and the whole value")
        }
        Set tRows = ..ReadRows(..#TABLESCREEN, "", .tStatus)
        Do $$$AssertEquals($IsObject(..RowNamed(tRows, tTable)), 1, tLabel _ ": the tables list holds the table")
        Set tId = $ClassMethod(tControl, "Id", tTable, tKey)
        Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", tId, "changed", .tAnswer), "200 ", tLabel _ ": Set value answers 200")
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tTable), tKey _ "=changed", tLabel _ ": the value is changed")
        Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "remove", tId, $Char(0), .tAnswer), "200 ", tLabel _ ": Remove answers 200")
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tTable), 0, tLabel _ ": the last entry took the table with it")
        Do $$$AssertEquals($ClassMethod(tControl, "Save", tTable, tKey, "again", .tAnswer), "201 ", tLabel _ ": the table is created again")
        Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#TABLESCREEN, "delete", tTable, $Char(0), .tAnswer), "200 ", tLabel _ ": Delete answers 200")
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tTable), 0, tLabel _ ": and the table is gone")
    }
}

/// <p>AC1, AC2, AC3: a table, key and value full of the characters a query string, a JSON body, an XML file and a quoted literal each treat
/// specially (a space, <code>&amp;=+%#?/\"'&lt;&gt;</code>, a letter above 127 and one above 255, a line break in the value) are added by the
/// Save, read back under a percent-encoded <code>table</code> criterion, changed, added by the agent through mint and confirm, removed and
/// deleted, each stored exactly as sent.</p>
/// <p>Mutation (Rule 19): decode the <code>table</code> criterion a second time in <method>OcuPilot.Port.InteropPort.InvokeLookup</method>
/// -- the name's <code>+</code> reads as a space, the entries list finds no table and this goes red.</p>
Method TestNamesAndValuesFullOfSpecialCharactersRoundTripThroughEveryRoute()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Set tSpecial = ..#SPECIAL _ $Char(233) _ $Char(26085)
    Set tTable = "OcuProbe205 T" _ tSpecial
    Set tKey = "k" _ tSpecial
    Set tValue = "v" _ tSpecial _ $Char(10) _ "second line"
    Set tBody = {}
    Do tBody.%Set("Table", tTable, "string")
    Do tBody.%Set("Key", tKey, "string")
    Do tBody.%Set("Value", tValue, "string")
    Do ..Send("POST", "/interop/lookup-entries", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tTable), tKey _ "=" _ tValue, "the entry is stored exactly as sent")
    Set tRows = ..ReadRows(..#TABLESCREEN, "", .tStatus)
    Do $$$AssertEquals($IsObject(..RowNamed(tRows, tTable)), 1, "the tables list holds the table under its exact name")
    Set tRows = ..ReadRows(..#ENTRYSCREEN, "table=" _ ..Encoded(tTable), .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200 1", "the entries list answers one row under the encoded criterion")
    If $IsObject(tRows) && (tRows.%Size() = 1) {
        Set tRow = tRows.%Get(0)
        Do $$$AssertEquals((tRow.Table = tTable) && (tRow.Key = tKey) && (tRow.Value = tValue), 1, "whose table, key and value are the ones sent: " _ tRow.%ToJSON())
    }
    Set tId = $ClassMethod(tControl, "Id", tTable, tKey)
    Set tBody = {"action": "set", "values": {"Value": ("w" _ tSpecial)}}
    Do tBody.%Set("id", tId, "string")
    Do ..Send("POST", ..#ENTRYSCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Set value answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tTable), tKey _ "=w" _ tSpecial, "and stores the new value exactly")
    Set tArgs = $ClassMethod(tControl, "ArgsFor", tTable, "agent" _ tSpecial, "a" _ tSpecial)
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntryAdd", tArgs, .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals($ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw), 200, "and confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tTable), "agent" _ tSpecial _ "=a" _ tSpecial _ ";" _ tKey _ "=w" _ tSpecial, "and stores the agent's entry exactly, beside the other")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tBody = {"action": "remove"}
    Do tBody.%Set("id", tId, "string")
    Do ..Send("POST", ..#ENTRYSCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Remove answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", tTable), "agent" _ tSpecial _ "=a" _ tSpecial, "and only that entry goes")
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", tTable, "string")
    Do ..Send("POST", ..#TABLESCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Delete answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", tTable), 0, "and the table is gone")
}

/// <p>AC8: an export to a server file where a file already stands replaces it, over a file that is no export and over the table's own
/// earlier export: the file is the table's export each time. The replacement is a constant no export to a fresh name exercises.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Port.InteropPort.EXPORTOVERWRITES</parameter> 0 -- PathPort refuses the existing file
/// and this goes red.</p>
Method TestAnExportOverAFileThatStandsThereReplacesIt()
{
    Set tFixture = ..#FIXTURE
    Set tProbe = ..#PROBE
    Set tTransfer = ..#TRANSFER
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "first")
    Do $ClassMethod(tProbe, "WriteFile", "table.xml", "old text that is no export")
    Do $$$AssertEquals($ClassMethod(tProbe, "FileExists", "table.xml"), 1, "a file already stands at the name")
    Do $ClassMethod(tTransfer, "Act", "export", ..#TABLE, $ClassMethod(tTransfer, "FileValues", "table.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "200 ", "the export over it answers 200: " _ $ClassMethod(tTransfer, "Json", tBody))
    Set tFile = $ClassMethod(tProbe, "ReadFile", "table.xml")
    Do $$$AssertEquals((tFile [ "key=""alpha""") && (tFile '[ "old text"), 1, "and the file is the table's export with nothing of the old text left")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "beta", "second")
    Do $ClassMethod(tTransfer, "Act", "export", ..#TABLE, $ClassMethod(tTransfer, "FileValues", "table.xml"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "an export over the earlier export answers 200 too: " _ $ClassMethod(tTransfer, "Json", tBody))
    Set tFile = $ClassMethod(tProbe, "ReadFile", "table.xml")
    Do $$$AssertEquals((tFile [ "key=""alpha""") && (tFile [ "key=""beta"""), 1, "and the file now holds both entries")
}

/// <p>AC7: the import's read, with and without the action it is composed for, from a local file and from a server file, and the export,
/// to the browser and to a server file, leave <code>^Ens.LookupTable</code>, stamps included, as they were: the table keeps an entry the
/// file lacks, which a load would have removed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ImportShape</method> load the file in place of listing it (its list-only
/// argument 0) -- the entry the file lacks goes and this goes red.</p>
Method TestNoImportReadOrExportChangesWhatTheVendorKeeps()
{
    Set tFixture = ..#FIXTURE
    Set tProbe = ..#PROBE
    Set tPort = ..#PORT
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "first")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "beta", "second")
    Set tText = $ClassMethod(..#TRANSFER, "ExportText", ..#TABLE _ ".LUT")
    Do $$$AssertTrue(tText [ "key=""beta""", "the file is the table's export")
    Do $ClassMethod(tProbe, "WriteFile", "imp.xml", tText)
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "extra", "not in the file")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    For tCase = $ListBuild("a local file", ""), $ListBuild("a local file, composed for the import", "IMPORT"), $ListBuild("a server file", ""), $ListBuild("a server file, composed for the import", "IMPORT") {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = "import"
        If $List(tCase, 1) [ "local" {
            Set tQuery("fileName") = "imp.xml"
            Set tQuery("content") = tText
        } Else {
            Set tQuery("root") = $ClassMethod(tProbe, "Root")
            Set tQuery("path") = $ClassMethod(tProbe, "RelativeName", "imp.xml")
        }
        If $List(tCase, 2) '= "" Set tQuery("action") = $List(tCase, 2)
        Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "IMPORTTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRow)): tRow.Table _ "|" _ tRow.Entries, 1: ""), "200 " _ ..#TABLE _ "|3", "the import's read of " _ $List(tCase, 1) _ " answers the table as it stands: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    }
    For tToFile = 0, 1 {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = ..#TABLE
        If tToFile {
            Set tQuery("root") = $ClassMethod(tProbe, "Root")
            Set tQuery("path") = $ClassMethod(tProbe, "RelativeName", "out.xml")
        }
        Set tSC = $ClassMethod(tPort, "Invoke", "LookupTables", "EXPORT", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, "the export " _ $Select(tToFile: "to a server file", 1: "to the browser") _ " answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "the lookup global, its stamps and the partner global are as they were")
    Do $$$AssertTrue($ClassMethod(tFixture, "Entries", ..#TABLE) [ "extra=", "and the table still holds the entry the file lacks")
}

/// <p>AC2, AC4: an agent's add minted while the key was free is refused at the confirm once someone else has taken it.</p>
/// <p>Mutation (Rule 19): drop the <code>TAKEN</code> test from <method>OcuPilot.Port.InteropPort.LookupWriteToken</method> -- the add
/// then goes through <code>%UpdateValue</code> over the other entry and this goes red.</p>
Method TestAnAddMintedBeforeSomeoneTakesTheKeyIsRefusedAtTheConfirm()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "other", "x")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "k1", "mine"), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints while the key is free: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "k1", "theirs")
    Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 PROPOSAL.TARGETCHANGED", "the confirm closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "k1=theirs;other=x", "and the other entry stands")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC4: an agent's set confirmed while the table's vendor lock is held is refused <code>LOCKED</code> with nothing written; this process
/// holds the lock, so the confirm, which runs in another, waits the three seconds out.</p>
/// <p>Mutation (Rule 19): skip <code>LockTable</code> in <method>OcuPilot.Port.InteropPort.PerformLookup</method> -- the set goes ahead
/// and this goes red.</p>
Method TestAnAgentsSetConfirmedWhileTheVendorLockIsHeldIsRefusedLocked()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntrySet", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "held", "changed"), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the set mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = "USER"
        Lock +^Ens.LookupTable(..#TABLE):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the table's vendor lock")
        If tLocked {
            Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
            Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.LOOKUP.LOCKED", "the confirm is refused while the lock is held: " _ $Extract($Get(tRaw), 1, 300))
            Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "held=value", "and nothing was written")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    Set $NAMESPACE = "USER"
    Lock -^Ens.LookupTable(..#TABLE)
    Set $NAMESPACE = tOrigNS
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC4: under source control the table read composed for a table's delete is refused <code>SOURCECONTROL</code>, so the agent's mint
/// makes no card, while the same read with no action stays readable.</p>
/// <p>Mutation (Rule 19): delete the <code>SourceControlled</code> test from <method>OcuPilot.Port.InteropPort.ReadLookupTable</method>
/// -- the composed read answers the table and this goes red.</p>
Method TestTheReadComposedForATableDeleteIsRefusedUnderSourceControl()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do $ClassMethod(..#REFUSALS, "HoldLookupPairs")
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = ..#TABLE
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "LOOKUPTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRow)): tRow.Name _ "|" _ tRow.Entries, 1: ""), "200 " _ ..#TABLE _ "|1", "the table read with no action is readable under source control")
    Set tQuery("action") = "DELETETABLE"
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "LOOKUPTABLE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 INTEROP.LOOKUP.SOURCECONTROL|" _ $Parameter("OcuPilot.Api.InteropError", "REASONLOOKUPSOURCECONTROL"), "the read composed for the delete is refused for source control, with the published sentence")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "and nothing was written")
}

/// <p>AC2, AC4: an entry whose key matches the credential pattern is removed by the row action and by the agent's remove through mint and
/// confirm (a remove sends no value, so the key's secret rule is not asked of it), and no card, answer, ledger row or audit row carries the
/// value the entry held (AD-35). The add and the set of such a key are refused, which the refusals class pins.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Screen.Tool.InteropLookupEntryRemove.REFUSESSECRET</parameter> 1 -- both removes are
/// refused <code>SECRET</code> and this goes red.</p>
Method TestAnEntryWhoseKeyHoldsACredentialIsRemovedFromBothCallersWithoutShowingItsValue()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Set tSecret = ..#SECRETVALUE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "dbpassword", tSecret)
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "keep", "k")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = $ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "remove", $ClassMethod(tControl, "Id", ..#TABLE, "dbpassword"), $Char(0), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the row action Remove of a credential-named key answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "keep=k", "and removes the entry")
    Do $$$AssertEquals($ClassMethod(tControl, "Audited", tSince, "remove", ..#TABLE, .tData), 1, "with one audit row of OcuPilot's own")
    Do $$$AssertTrue((tData '[ tSecret) && ($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer) '[ tSecret), "and neither that row nor the answer carries the value: " _ tData)
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "dbpassword", tSecret)
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Kill tSettings
        Set tSettings("interop.lookupentries.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove's key is turned on")
        Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntryRemove", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "dbpassword"), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the agent's remove of a credential-named key mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Set tCard = tProposal.changed.%ToJSON()
        Do $$$AssertTrue((tCard [ "dbpassword") && (tCard '[ tSecret), "its card names the key and shows no value: " _ tCard)
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "keep=k", "removing the entry")
        Do $$$AssertEquals($ClassMethod(tControl, "Audited", tSince, "remove", ..#TABLE, .tData), 1, "with one audit row of OcuPilot's own")
        Do $$$AssertTrue((tData '[ tSecret) && ($Get(tRaw) '[ tSecret) && ($ClassMethod(..#LEDGER, "RowText", tTurn) '[ tSecret), "and no audit row, answer or ledger row carries the value")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent's leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2, AC4 (AD-13, each part of an id kept exactly): keys that differ only in letter case are separate entries: each is added without
/// being taken for another, Set value and Remove touch only the entry named, the entries list answers each key as stored, and the
/// agent's add of a spelling that is free mints while an exact repeat is refused <code>TAKEN</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LookupFactsHere</method> look a key up in lower case -- the second
/// Save is taken for the first and this goes red.</p>
Method TestKeysThatDifferOnlyInLetterCaseAreSeparateEntries()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $$$AssertEquals($ClassMethod(tControl, "Save", ..#TABLE, "alpha", "1", .tAnswer), "201 ", "the first spelling is added")
    Do $$$AssertEquals($ClassMethod(tControl, "Save", ..#TABLE, "Alpha", "2", .tAnswer), "201 ", "so is a second that differs in case: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tControl, "Save", ..#TABLE, "ALPHA", "3", .tAnswer), "201 ", "and a third")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "ALPHA=3;Alpha=2;alpha=1", "three entries stand")
    Do $$$AssertEquals($ClassMethod(tControl, "Save", ..#TABLE, "alpha", "x", .tAnswer), "409 INTEROP.LOOKUP.TAKEN", "an exact repeat is taken")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", $ClassMethod(tControl, "Id", ..#TABLE, "Alpha"), "two", .tAnswer), "200 ", "Set value on one spelling answers 200")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "ALPHA=3;Alpha=two;alpha=1", "and changes that entry alone")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "remove", $ClassMethod(tControl, "Id", ..#TABLE, "Alpha"), $Char(0), .tAnswer), "200 ", "Remove on one spelling answers 200")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "ALPHA=3;alpha=1", "and removes that entry alone")
    Set tRows = ..ReadRows(..#ENTRYSCREEN, "table=" _ ..Encoded(..#TABLE), .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropLookupRead).Column(tRows, "Key"), "200 ALPHA,alpha", "the entries list answers each key as stored")
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "Alpha", "again"), .tProposal, .tFault, .tTurn)
    Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's add of the spelling that is free mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tSC = $ClassMethod(tControl, "Mint", "InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "alpha", "again"), .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "minted"), "INTEROP.LOOKUP.TAKEN", "and an exact repeat is refused at the mint")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
