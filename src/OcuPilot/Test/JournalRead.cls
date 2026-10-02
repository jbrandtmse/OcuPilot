/// <p>Pins Story 18.5's journal reads and the admin port's journal file guard (AD-21's eighth case,
/// AD-36): Journals and its read tool answer the vendor's list in its order; Journal file details and
/// its databases list read one listed file's <code>GET</code>; a name the instance's journal file list
/// does not answer is refused <code>JOURNAL.FILE.UNLISTED</code> on every guarded pair, through each
/// screen's read, the integrity check's screen action and the integrity tool's mint, with no vendor
/// call for the target and no echo of the name; and the record list's omitted file reads the newest
/// listed file.</p>
/// <p>Its tests read only. Where the journal file list names no closed file,
/// <method>OnBeforeAllTests</method> first switches the journal file to close one
/// (<method>OcuPilot.Test.JournalProbe.EnsureClosedFile</method>), only when
/// <parameter>JOURNALVARIABLE</parameter> reads <code>1</code>; the file it closes is kept. It needs
/// journaling on, a caller holding <code>%All</code>, and OcuPilot serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account.</p>
Class OcuPilot.Test.JournalRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the journal switch a list without a closed file needs.</p>
Parameter JOURNALVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

Parameter LIST = "OcuPilot.Screen.Descriptor.JournalList";

Parameter DETAILS = "OcuPilot.Screen.Descriptor.JournalFileDetails";

Parameter DATABASES = "OcuPilot.Screen.Descriptor.JournalFileDatabaseList";

Parameter COUNTPORT = "OcuPilot.Test.JournalCountPort";

Parameter READFIXTURE = "OcuPilot.Test.JournalReadFixture";

Parameter INTEGRITY = "OcuPilot.Screen.Tool.JournalIntegrityCheck";

Parameter UNLISTED = "JOURNAL.FILE.UNLISTED";

/// <p>A name no journal file list answers.</p>
Parameter FOREIGNFILE = "/tmp/x.001";

Method OnBeforeAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.JournalProbe).EnsureClosedFile($System.Util.GetEnviron(..#JOURNALVARIABLE) = 1)
}

/// <p>The instance's journal file list, whole, through the admin port.</p>
ClassMethod Listed() As %DynamicArray
{
    Kill tQuery
    Set tQuery("maxRows") = 0
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Journal.File", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit []
    Quit tRows
}

/// <p>The names of <var>pRows</var>, in order, joined by spaces.</p>
ClassMethod Names(pRows As %DynamicArray, pMax As %Integer = 0) As %String
{
    Set tOut = ""
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If pMax && (tIndex >= pMax) Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tRow.%Get("Name")
    }
    Quit tOut
}

/// <p>AC1: Journals and <code>osmgmt.journals.read</code> answer the vendor's list in its order,
/// newest first, each row the five declared fields; the first row is the file journaling writes
/// now.</p>
/// <p>Mutation (Rule 19): declare Journals' read as <code>Journal.File</code> <code>GET</code> in place
/// of <code>LIST</code> -&gt; the read is refused for its missing criterion and this goes red.</p>
Method TestJournalsAndItsToolAnswerOneRead()
{
    Set tListed = ..Listed()
    Do $$$AssertTrue(tListed.%Size() >= 2, "the instance lists journal files: " _ tListed.%Size())
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Journals reads: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LIST, {}, 1000, .tView, .tViewHttp, .tViewFault)
    Do $$$AssertStatusOK(tSC, "and so does its read tool")
    If $$$ISERR(tSC) Quit
    Set tMax = $Select(tListed.%Size() > 1000: 1000, 1: tListed.%Size())
    Do $$$AssertEquals(..Names(tScreen.%Get("rows")), ..Names(tListed, tMax), "the screen's rows are the vendor's list, in its order")
    Do $$$AssertEquals(..Names(tView.%Get("rows")), ..Names(tScreen.%Get("rows")), "and the tool's are the screen's")
    Do $$$AssertEquals(tScreen.%Get("fields").%ToJSON(), "[""Name"",""Size"",""CreationTime"",""Reason"",""DataSize""]", "the five declared fields")
    Set tCurrent = ##class(%SYS.Journal.System).GetCurrentFileName()
    Do $$$AssertEquals(tScreen.%Get("rows").%Get(0).%Get("Name"), tCurrent, "the first row is the file journaling writes now")
}

/// <p>AC2: a listed file's details read its <code>GET</code>, the route criterion seeded as
/// <code>Name</code> and the previous file projected from its object; the databases list is that
/// <code>GET</code>'s <code>Databases</code>, cut to the cap and reported truncated; a file the
/// vendor cannot open reads as no rows through neither, since the guard refuses it first.</p>
/// <p>Mutation (Rule 19): drop the <code>GET</code> admission from
/// <method>OcuPilot.Screen.Registry.RowsProblem</method> -&gt; the databases descriptor is refused at
/// registration and this goes red.</p>
Method TestDetailsAndDatabasesReadOneListedFile()
{
    Set tListed = ..Listed()
    If tListed.%Size() < 2 {
        Do $$$AssertTrue(0, "the instance lists at least two journal files")
        Quit
    }
    ; A closed file holding records for more than the cap's two databases, else for at least one,
    ; so the row legs below always have a row to compare.
    Set tFile = ""
    Set tGet = ""
    For tI = 1:1:tListed.%Size() - 1 {
        Kill tQuery
        Set tQuery("file") = tListed.%Get(tI).%Get("Name")
        Set tCandidate = ""
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Journal.File", "GET", .tQuery, "", .tCandidate, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject(tCandidate) || (tCandidate.%GetTypeOf("Databases") '= "array") Continue
        Set tCount = tCandidate.%Get("Databases").%Size()
        If (tCount > 0) && ((tFile = "") || (tCount > 2)) {
            Set tFile = tListed.%Get(tI).%Get("Name")
            Set tGet = tCandidate
        }
        If (tCount > 2) || (tI >= 20) Quit
    }
    Do $$$AssertTrue(tFile '= "", "a closed listed file's GET names at least one database")
    If tFile = "" Quit
    Kill tCriteria
    Set tCriteria("file") = tFile
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DETAILS, "", .tDetails, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the details read")
    If $$$ISERR(tSC) Quit
    Set tRow = tDetails.%Get("rows").%Get(0)
    Do $$$AssertEquals(tRow.%Get("Name"), tFile, "the route criterion is seeded as Name")
    Do $$$AssertEquals(tRow.%Get("FileGUID"), tGet.%Get("FileGUID"), "the summary is the file's GET")
    Do $$$AssertEquals(tRow.%Get("PrevFile.File"), tGet.%Get("PrevFile").%Get("File"), "the previous file is projected from its object")
    Do $$$AssertEquals(tRow.%Get("NextFile.File"), tGet.%Get("NextFile").%Get("File"), "and so is the next")
    Set tDatabases = tGet.%Get("Databases")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DATABASES, 2, .tList, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the databases read")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tList.%Get("rows").%Size(), $Select(tDatabases.%Size() > 2: 2, 1: tDatabases.%Size()), "cut to the cap")
    Do $$$AssertEquals(''tList.%Get("truncated"), (tDatabases.%Size() > 2), "and reported truncated when the file holds more")
    Do $$$AssertEquals(tList.%Get("rows").%Get(0).%ToJSON(), "{""SFN"":" _ tDatabases.%Get(0).%Get("SFN") _ ",""DatabasePathOrAlias"":""" _ tDatabases.%Get(0).%Get("DatabasePathOrAlias") _ """}", "each row is one database of the GET's own list")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DATABASES, 2, .tList, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 READ.CRITERION", "a databases read naming no file is refused before the port is asked")
}

/// <p>AD-36 as amended: a file whose <code>GET</code> the port answers absent -- purged after the list
/// named it -- reads as no databases rather than a failed read.</p>
/// <p>Mutation (Rule 19): take the <code>tObjectGone</code> branch out of
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the read fails and this goes red.</p>
Method TestAnAbsentFileReadsAsNoDatabases()
{
    Set tListed = ..Listed()
    If tListed.%Size() < 1 {
        Do $$$AssertTrue(0, "the instance lists a journal file")
        Quit
    }
    Do $ClassMethod(..#COUNTPORT, "Reset")
    Do $ClassMethod(..#COUNTPORT, "AnswerAbsent")
    Kill tCriteria
    Set tCriteria("file") = tListed.%Get(0).%Get("Name")
    Set tList = ""
    Set tSC = $ClassMethod(..#READFIXTURE, "Execute", ..#DATABASES, 2, .tList, .tHttp, .tFault, .tCriteria)
    Do $ClassMethod(..#COUNTPORT, "Reset")
    Do $$$AssertStatusOK(tSC, "the databases read of an absent file succeeds: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue($IsObject(tList) && (tList.%Get("rows").%Size() = 0) && 'tList.%Get("truncated"), "with no rows, not truncated: " _ $Select($IsObject(tList): tList.%ToJSON(), 1: ""))
}

/// <p>AC2: every guarded pair refuses a name the instance's journal file list does not answer -- a
/// foreign path and a listed name with the <code>z</code> a closed file carries on disk -- 404
/// <code>JOURNAL.FILE.UNLISTED</code>, after the one list read and with no vendor call for the
/// target; no refusal names the file; the details and databases reads refuse it on the same code
/// with the same count; and the integrity check's mint and screen action refuse it on that code.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.JournalGuard</method> answer OK for an
/// unlisted file -&gt; the target call is made and every leg here goes red on its count or its
/// code.</p>
Method TestAnUnlistedFileIsRefusedBeforeTheVendorIsCalledForIt()
{
    Set tListed = ..Listed()
    If tListed.%Size() < 2 {
        Do $$$AssertTrue(0, "the instance lists at least two journal files")
        Quit
    }
    Set tPort = ..#COUNTPORT
    Do $ClassMethod(tPort, "Reset")
    Kill tQuery
    Set tQuery("maxRows") = 0
    Set tSC = $ClassMethod(tPort, "Invoke", "Journal.File", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tBase = $ClassMethod(tPort, "Calls")
    Do $$$AssertTrue(tBase > 0, "a list read is counted: " _ tBase)
    Set tClosed = tListed.%Get(1).%Get("Name")
    For tName = ..#FOREIGNFILE, tClosed _ "z" {
        For tPair = "Journal.File/GET", "Journal.File/INTEGRITYCHECK", "Journal.Record/LIST", "Journal.Record/GET" {
            Do $ClassMethod(tPort, "Reset")
            Kill tQuery
            Set tQuery("file") = tName
            If tPair = "Journal.Record/GET" Set tQuery("address") = 131088
            Set tBody = $Select(tPair = "Journal.File/INTEGRITYCHECK": {"CheckDetails": false}, 1: "")
            Set tSC = $ClassMethod(tPort, "Invoke", $Piece(tPair, "/", 1), $Piece(tPair, "/", 2), .tQuery, tBody, .tResult, .tHttp, .tFault)
            Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
            Do $$$AssertEquals(tHttp _ " " _ tCode, "404 " _ ..#UNLISTED, tPair _ " refuses '" _ tName _ "'")
            Do $$$AssertEquals($ClassMethod(tPort, "Calls"), tBase, tPair _ " made the list read alone, and no call for '" _ tName _ "'")
            Do $$$AssertTrue($IsObject($Get(tFault)) && '(tFault.%ToJSON() [ tName), "and its refusal does not name the file")
        }
        Kill tCriteria
        Set tCriteria("file") = tName
        For tScreen = ..#DETAILS, ..#DATABASES {
            Do $ClassMethod(tPort, "Reset")
            Set tSC = $ClassMethod(..#READFIXTURE, "Execute", tScreen, "", .tRead, .tHttp, .tFault, .tCriteria)
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 " _ ..#UNLISTED, tScreen _ "'s read refuses '" _ tName _ "' rather than reading it as no rows")
            Do $$$AssertEquals($ClassMethod(tPort, "Calls"), tBase, tScreen _ "'s read made the list read alone")
        }
        Set tArgs = {}
        Do tArgs.%Set("Name", tName, "string")
        Set tSC = ##class(OcuPilot.Screen.Tool.JournalMint).Mint(..#LIST, $Parameter(..#INTEGRITY, "TOOLNAME"), $Username, "", "", tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(..#INTEGRITY, "Endpoint"), $ClassMethod(..#INTEGRITY, "IdParam"), tName, "Name", $ClassMethod(..#INTEGRITY, "SettableFields"), ..#INTEGRITY)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 " _ ..#UNLISTED, "the integrity check's mint refuses '" _ tName _ "' on the guard's own code")
        Set tSC = ##class(OcuPilot.Test.JournalWrite).Act("integrity", tName, "", .tStatus, .tBody, {"CheckDetails": "false"})
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.JournalWrite).Code(tBody), "404 " _ ..#UNLISTED, "the integrity check's screen action refuses '" _ tName _ "' on the guard's own code")
    }
    Do $ClassMethod(tPort, "Reset")
    Kill tQuery
    Set tQuery("file") = tClosed
    Set tSC = $ClassMethod(tPort, "Invoke", "Journal.File", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a listed file's GET answers")
    Do $$$AssertEquals($ClassMethod(tPort, "Calls"), tBase + 1, "after the list read and the one call for the file")
}

/// <p>The record list's omitted or empty file reads the newest listed file, while every other
/// guarded pair refuses an empty name; the guard reads the list whole at each call.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.JOURNALNEWESTTYPES</parameter>
/// -&gt; the record list's omitted file is refused and this goes red.</p>
Method TestTheRecordListsOmittedFileReadsTheNewest()
{
    Set tPort = ..#COUNTPORT
    Set tNewest = ..Listed().%Get(0).%Get("Name")
    For tGiven = "omitted", "" {
        Kill tQuery
        If tGiven '= "omitted" Set tQuery("file") = tGiven
        Set tSC = $ClassMethod(tPort, "Guard", "Journal.Record", "LIST", .tQuery, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the record list's " _ $Select(tGiven = "": "empty", 1: tGiven) _ " file is admitted")
        Do $$$AssertEquals($Get(tQuery("file")), tNewest, "and reads the newest listed file")
    }
    For tPair = "Journal.File/GET", "Journal.File/INTEGRITYCHECK", "Journal.Record/GET" {
        Kill tQuery
        Set tSC = $ClassMethod(tPort, "Guard", $Piece(tPair, "/", 1), $Piece(tPair, "/", 2), .tQuery, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 " _ ..#UNLISTED, tPair _ " refuses an omitted file")
    }
    Kill tQuery
    Set tQuery("file") = tNewest
    Set tSC = $ClassMethod(tPort, "Guard", "Journal.File", "GET", .tQuery, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the newest file itself is admitted")
}

}
