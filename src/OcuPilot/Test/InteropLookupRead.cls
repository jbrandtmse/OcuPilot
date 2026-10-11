/// <p>Pins Story 20.5's reads end to end against probe lookup tables and two probe business partners in <code>USER</code> (AD-29,
/// AD-35, AD-36, AD-62): the tables list, a table's entries and the partners list read through
/// <class>OcuPilot.Port.InteropPort</class>; the screen's read route, its read and its read tool answer the same rows in the
/// fields each declares; the table and entry single-object reads; an entry whose key matches the credential pattern reads an
/// empty value with <code>Secret</code> true; <code>maxRows</code> cuts each of the three lists; an unknown table is 404, a read naming no table
/// 400; a table's stamp reads in the instance's local clock time; and no read changes <code>^Ens.LookupTable</code> or the
/// partner global.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It starts no production and removes every table and the
/// partners it creates.</p>
Class OcuPilot.Test.InteropLookupRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter TABLE = "OcuProbe205Read";

Parameter OTHER = "OcuProbe205Other";

Parameter SECRETKEY = "dbpassword";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupRead writes probe lookup tables and probe business partners in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISERR(tSC) Quit tSC
    Quit ..Arrange()
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Two tables and the two probe partners: <parameter>TABLE</parameter> holds three entries and one whose key holds a credential.</p>
Method Arrange() As %Status
{
    Set tFixture = ..#FIXTURE
    Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "alpha", "first value")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "bravo", "")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, "charlie", "third" _ $Char(10) _ "line")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#TABLE, ..#SECRETKEY, "hunter2")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "Put", ..#OTHER, "only", "entry")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "PutPartner")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tFixture, "PutPartner", $Parameter(tFixture, "PARTNERB"))
    Quit tSC
}

/// <p>One port call as the test process: the rows or the row, the HTTP status in <var>pHttp</var> and the wire fault in
/// <var>pFault</var>.</p>
ClassMethod Port(pEndpoint As %String, pType As %String, ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicAbstractObject
{
    Set pQuery("namespace") = ..#NAMESPACE
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, pType, .pQuery, "", .tResult, .pHttp, .pFault)
    Quit $Get(tResult)
}

/// <p>The names of a list's <var>pField</var>, comma-separated, in the order the rows came.</p>
ClassMethod Column(pRows As %DynamicArray, pField As %String) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit tText
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tText
}

/// <p>AC1: the tables list holds both probe tables with a stamp in the instance's local clock time, the entries list holds the
/// table's four entries in the vendor's order with the credential key's value empty and <code>Secret</code> true, the table and
/// entry single-object reads answer the same facts, and the cut, the unknown table and the missing criterion are answered by
/// their codes.</p>
/// <p>Mutation (Rule 19): make the entries read ignore the <code>table</code> criterion (list another table's entries), or
/// answer the credential key's value in <method>OcuPilot.Port.InteropPort.LookupEntryRow</method> -- the entries leg or the
/// secret leg goes red.</p>
Method TestTheTablesAndEntriesReadThroughThePort()
{
    Kill tQuery
    Set tTables = ..Port("LookupTables", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the tables list answers")
    Set tNames = ..Column(tTables, "Name")
    Do $$$AssertTrue((("," _ tNames _ ",") [ ("," _ ..#TABLE _ ",")) && (("," _ tNames _ ",") [ ("," _ ..#OTHER _ ",")), "both probe tables are listed: " _ tNames)
    Set tIterator = tTables.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name '= ..#TABLE Continue
        Set tStamp = $ClassMethod(..#FIXTURE, "Stamp", ..#TABLE)
        Do $$$AssertEquals(tRow.Modified, ##class(OcuPilot.Port.LogSourcePort).LocalFromUtc($ZDateTime(tStamp, 3, , 3)), "its Modified is the vendor's stamp in the instance's local clock time")
        Do $$$AssertTrue($Match(tRow.Modified, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$"), "in the log readers' form: " _ tRow.Modified)
    }
    Kill tQuery
    Set tQuery("table") = ..#TABLE
    Set tEntries = ..Port("LookupEntries", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the entries list answers")
    Do $$$AssertEquals(..Column(tEntries, "Key"), "alpha,bravo,charlie," _ ..#SECRETKEY, "its four entries in the vendor's subscript order")
    Do $$$AssertEquals(..Column(tEntries, "Table"), ..#TABLE _ "," _ ..#TABLE _ "," _ ..#TABLE _ "," _ ..#TABLE, "each row carries its table")
    Do $$$AssertEquals(..Column(tEntries, "Value"), "first value,,third" _ $Char(10) _ "line,", "the values are as stored, an empty one empty and the credential key's empty too")
    Do $$$AssertEquals(..Column(tEntries, "Secret"), "0,0,0,1", "and only that key reads Secret true")
    Kill tQuery
    Set tQuery("table") = ..#TABLE
    Set tQuery("maxRows") = 2
    Set tCut = ..Port("LookupEntries", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(..Column(tCut, "Key"), "alpha,bravo", "maxRows cuts the list")
    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tCutTables = ..Port("LookupTables", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tCutTables.%Size(), "200 1", "and cuts the tables list to one row, though both probe tables are listed")
    Kill tQuery
    Set tQuery("table") = "OcuProbe205NoSuch"
    Do ..Port("LookupEntries", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "404 PORT.NOTFOUND", "an unknown table is not found")
    Kill tQuery
    Set tQuery("table") = $ZConvert(..#TABLE, "U")
    Do ..Port("LookupEntries", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "and so is a table named in another letter case: table names are exact")
    Kill tQuery
    Do ..Port("LookupEntries", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "400 PORT.VALIDATION", "a read naming no table is refused")
    Kill tQuery
    Set tQuery("maxRows") = "x"
    Do ..Port("LookupTables", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a maxRows that is no whole number is refused")
    ; The single-object reads.
    Kill tQuery
    Set tQuery("id") = ..#TABLE
    Set tTable = ..Port("LookupTables", "LOOKUPTABLE", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tTable.Name _ " " _ tTable.Entries _ " " _ tTable.Namespace, "200 " _ ..#TABLE _ " 4 " _ ..#NAMESPACE, "the table read answers its name, its entry count and its namespace")
    Do $$$AssertEquals(tTable.Modified, ##class(OcuPilot.Port.LogSourcePort).LocalFromUtc($ZDateTime($ClassMethod(..#FIXTURE, "Stamp", ..#TABLE), 3, , 3)), "with the same stamp")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#TABLE, "alpha"))
    Set tEntry = ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tEntry.Key _ "=" _ tEntry.Value _ " " _ tEntry.Secret _ " " _ tEntry.Namespace, "200 alpha=first value 0 " _ ..#NAMESPACE, "the entry read answers its key, value and namespace")
    Do $$$AssertEquals(tEntry.%IsDefined("Entries") + tEntry.%IsDefined("Modified"), 0, "and carries no count and no stamp, so another entry's change never moves a fingerprint")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#TABLE, ..#SECRETKEY))
    Set tSecret = ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tSecret.Value _ "|" _ tSecret.Secret, "200||1", "a credential key's entry reads an empty value and Secret true")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#TABLE, "nosuch"))
    Do ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "an entry the table does not hold is not found")
    Kill tQuery
    Set tQuery("id") = "not a composite"
    Do ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "400 PORT.VALIDATION", "an entry id that is not a table and a key is refused")
}

/// <p>AC6: the partners list holds the probe partner with its description and both contacts' six fields, and the screen's read
/// and the read tool answer the same.</p>
/// <p>Mutation (Rule 19): drop the contact fields from <method>OcuPilot.Port.InteropPort.ListPartners</method> -- this goes red.</p>
Method TestThePartnersListHoldsBothContacts()
{
    Kill tQuery
    Set tRows = ..Port("BusinessPartners", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the partners list answers")
    Set tProbe = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = $Parameter(..#FIXTURE, "PARTNER") Set tProbe = tRow
    }
    Do $$$AssertTrue($IsObject(tProbe), "the probe partner is listed")
    If '$IsObject(tProbe) Quit
    Do $$$AssertEquals(tProbe.Description, "Probe partner description", "with its description")
    Do $$$AssertEquals(tProbe.PrimaryContact _ "|" _ tProbe.PrimaryTitle _ "|" _ tProbe.PrimaryEmail _ "|" _ tProbe.PrimaryPhone _ "|" _ tProbe.PrimaryMobile _ "|" _ tProbe.PrimaryNotes, "Pat Primary|Analyst|pat@example.test|555-0101|555-0102|Primary notes", "its primary contact's six fields")
    Do $$$AssertEquals(tProbe.AlternativeContact _ "|" _ tProbe.AlternativeTitle _ "|" _ tProbe.AlternativeEmail _ "|" _ tProbe.AlternativePhone _ "|" _ tProbe.AlternativeMobile _ "|" _ tProbe.AlternativeNotes, "Alex Alternative|Lead|alex@example.test|555-0201|555-0202|Alternative notes", "and its alternative contact's")
    Do $$$AssertTrue(("," _ ..Column(tRows, "Name") _ ",") [ ("," _ $Parameter(..#FIXTURE, "PARTNERB") _ ","), "the second probe partner is listed too")
    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tCut = ..Port("BusinessPartners", "LIST", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tCut.%Size(), "200 1", "maxRows cuts the partners to one row, though two are held")
    Kill tQuery
    Do ..Port("BusinessPartners", "ADDENTRY", .tQuery, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 501, "the partners endpoint serves no write: a partner's save and remove are a later story")
}

/// <p>AC1, AC6: the screen's read and the read tool of each of the three screens answer the same rows as the port, in the
/// fields the screen declares.</p>
/// <p>Mutation (Rule 19): change the entries screen's declared <code>read.fields</code> -- the rows differ and this goes
/// red.</p>
Method TestEachScreenAndToolAnswerTheSameRowsAsThePort()
{
    For tI = 1:1:3 {
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Case(tI, 1: "InteropLookupTableList", 2: "InteropLookupEntryList", : "InteropBusinessPartnerList")
        Set tEndpoint = $Case(tI, 1: "LookupTables", 2: "LookupEntries", : "BusinessPartners")
        Kill tQuery, tCriteria
        Set tArgs = {}
        If tI = 2 {
            Set tQuery("table") = ..#TABLE
            Set tCriteria("table") = ..#TABLE
            Do tArgs.%Set("table", ..#TABLE, "string")
        }
        Set tPortRows = ..Port(tEndpoint, "LIST", .tQuery, .tPortHttp, .tPortFault)
        Do $$$AssertEquals(tPortHttp, 200, tEndpoint _ ": the port answers")
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
        Do $$$AssertEquals(+$Get(tScreenHttp), 200, tEndpoint _ ": the screen's read answers")
        Set tToolName = $ClassMethod(tClass, "ToolIdentifier") _ ".read"
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
        Kill tResult
        Set tToolHttp = 0
        If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(+$Get(tToolHttp), 200, tToolName _ ": the read tool answers")
        If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) || '$IsObject(tPortRows) Continue
        Do $$$AssertTrue(tPortRows.%Size() > 0, tEndpoint _ ": the port answers rows")
        Set tPortDigest = ##class(OcuPilot.Test.InteropHostRead).Digest(##class(OcuPilot.Test.InteropHostRead).Projected(tPortRows, tClass))
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostRead).Digest(tAnswer.rows), tPortDigest, tEndpoint _ ": the screen's rows are the port's, in the fields it declares")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostRead).Digest(tResult.rows), tPortDigest, tEndpoint _ ": and so are the tool's")
    }
}

/// <p>AC1: the screens' read routes answer over the wire as the test account: the entries of the probe table, an unknown table
/// 404, a read naming no table 400 <code>READ.CRITERION</code>, and the credential key's value does not reach the wire.</p>
Method TestTheReadRoutesAnswerOverTheWire()
{
    Set tControl = ..#CONTROL
    Do $ClassMethod(tControl, "Call", "GET", "/screens/interop.lookupentries/read?table=" _ ..#TABLE _ "&maxRows=100", "", .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus, 200, "the entries route answers")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")), "with a rows array")
    Do $$$AssertEquals(..Column($Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: ""), "Key"), "alpha,bravo,charlie," _ ..#SECRETKEY, "its four entries")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ "hunter2"), "and the credential key's value is nowhere in the answer")
    Do $ClassMethod(tControl, "Call", "GET", "/screens/interop.lookupentries/read?table=OcuProbe205NoSuch&maxRows=100", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "404 PORT.NOTFOUND", "an unknown table is not found")
    Do $ClassMethod(tControl, "Call", "GET", "/screens/interop.lookupentries/read?maxRows=100", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 READ.CRITERION", "a read naming no table is refused for it")
    Do $ClassMethod(tControl, "Call", "GET", "/screens/interop.lookuptables/read?maxRows=1000", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the tables route answers")
    Do $ClassMethod(tControl, "Call", "GET", "/screens/interop.businesspartners/read?maxRows=1000", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "and so does the partners route")
}

/// <p>AC7: <code>^Ens.LookupTable</code>, stamps included, and the partner global are the same after every read -- the three
/// endpoints and the two single-object reads through the port, the three screens' reads and the three read tools -- as they
/// were before, and the snapshot is not empty.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LookupFactsHere</method> remove and re-add the table's first
/// entry (<code>%RemoveValue</code>, then <code>%UpdateValue</code>) -- the stamp moves and this goes red.</p>
Method TestNoReadChangesWhatTheVendorKeeps()
{
    Set tBefore = $ClassMethod(..#FIXTURE, "Snapshot")
    Do $$$AssertTrue($Piece(tBefore, ":", 2) > 100, "the snapshot holds the probe tables and the partner: " _ tBefore)
    Kill tQuery
    Do ..Port("LookupTables", "LIST", .tQuery, .tHttp)
    Do ..Port("BusinessPartners", "LIST", .tQuery, .tHttp)
    Kill tQuery
    Set tQuery("table") = ..#TABLE
    Do ..Port("LookupEntries", "LIST", .tQuery, .tHttp)
    Kill tQuery
    Set tQuery("id") = ..#TABLE
    Do ..Port("LookupTables", "LOOKUPTABLE", .tQuery, .tHttp)
    Set tQuery("action") = "DELETETABLE"
    Do ..Port("LookupTables", "LOOKUPTABLE", .tQuery, .tHttp)
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#TABLE, "alpha"))
    Do ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp)
    For tAction = "ADDENTRY", "SETENTRY", "REMOVEENTRY" {
        Set tQuery("action") = tAction
        Do ..Port("LookupEntries", "LOOKUPENTRY", .tQuery, .tHttp)
    }
    For tClass = "InteropLookupTableList", "InteropLookupEntryList", "InteropBusinessPartnerList" {
        Kill tCriteria
        If tClass = "InteropLookupEntryList" Set tCriteria("table") = ..#TABLE
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ tClass, 1000, .tAnswer, .tScreenHttp, .tFault, .tCriteria)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod("OcuPilot.Screen.Descriptor." _ tClass, "ToolIdentifier") _ ".read", .tTool)
        Set tArgs = {}
        If tClass = "InteropLookupEntryList" Do tArgs.%Set("table", ..#TABLE, "string")
        If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Snapshot"), tBefore, "the lookup global, its stamps and the partner global are as they were")
}

}
