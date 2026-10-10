/// <p>Pins Story 18.30's reads: the screen's declared read and <code>webapp.docdbapps.read</code> answer the same rows
/// from one read, <code>Enabled</code> a boolean; <code>GET /docdb-application/form</code> answers a record's five
/// fields and a new record's defaults; a record the instance does not hold, or an id that is not two parts, is 404; and
/// <class>OcuPilot.Port.DocDbAppPort</class> splits the composite id for the vendor and renders its script, which a create's
/// copy-out draft shows with the record named as typed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe records
/// (<class>OcuPilot.Test.DocDbAppProbe</class>) and removes them by exact namespace and name before all, after each and
/// after all. After each test the record list reads as that test found it.</p>
Class OcuPilot.Test.DocDbAppRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "webapp.docdbapps";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.DocDbAppList";

Parameter PROBE = "OcuPilot.Test.DocDbAppProbe";

Parameter PORT = "OcuPilot.Port.DocDbAppPort";

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbAppRead creates probe Doc DB application records on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe record and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the record list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the record list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>C1: the screen and the tool answer the same rows, each carrying the five list fields with <code>Enabled</code> a
/// boolean, and the probe records are listed with the namespace the instance stores and the name as written.</p>
/// <p>The live <code>DocDB</code> <code>LIST</code> row of each probe carries every field the list declares, and the
/// screen's rows carry the description and the resource the probes hold.</p>
/// <p>Mutation (Rule 19): point the descriptor's read at <code>WebApp.App</code> -- the rows legs go red.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "first", "Enabled": false, "Resource": ""}), "a first probe record")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "ocuprobe1830b", {"Description": "second", "Enabled": true, "Resource": "OcuProbe1830Res"}), "and a second naming the resource")
    Kill tQuery
    Set tRawSC = ##class(OcuPilot.Port.AdminPort).Invoke("DocDB", "LIST", .tQuery, "", .tRaw, .tRawHttp, .tRawFault)
    Do $$$AssertStatusOK(tRawSC, "the live DocDB LIST answers")
    Set tProbeRows = 0
    Set tRawIterator = $Select($IsObject($Get(tRaw)) && tRaw.%IsA("%Library.DynamicArray"): tRaw.%GetIterator(), 1: "")
    While $IsObject(tRawIterator) && tRawIterator.%GetNext(.tRawIndex, .tRawRow) {
        If '$IsObject(tRawRow) || '$ClassMethod(..#PROBE, "IsProbe", tRawRow.%Get("Name")) Continue
        Set tProbeRows = tProbeRows + 1
        Set tFieldIterator = $ClassMethod(..#DESCRIPTOR, "Read").%Get("fields").%GetIterator()
        While tFieldIterator.%GetNext(.tFieldIndex, .tField) {
            Do $$$AssertTrue(tRawRow.%IsDefined(tField), "declared read field '" _ tField _ "' is a key of the live row of " _ tRawRow.%Get("Name"))
        }
    }
    Do $$$AssertEquals(tProbeRows, 2, "both probe records are in the live list")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 100, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "Description,Enabled,Name,Namespace,Resource", "row " _ tIndex _ " carries the five list fields and nothing else")
        Do $$$AssertEquals(tRow.%GetTypeOf("Enabled"), "boolean", "row " _ tIndex _ " reads Enabled as a boolean")
        If $ClassMethod(..#PROBE, "IsProbe", tRow.%Get("Name")) Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("Namespace") _ ":" _ tRow.%Get("Name") _ ":" _ tRow.%Get("Enabled") _ ":" _ tRow.%Get("Description") _ ":" _ tRow.%Get("Resource")
    }
    Do $$$AssertEquals(tSeen, "USER:OcuProbe1830A:0:first:,USER:ocuprobe1830b:1:second:OcuProbe1830Res", "both probes are listed in USER, named as written, with Enabled, description and resource as stored")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "webapp.docdbapps.read resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 100}, 100, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's rows")
}

/// <p>C1: over the wire the form read answers 200 as JSON for a probe record: <code>Name</code>, <code>Namespace</code>
/// and its three settings; the same record named in another case answers the same record; an absent record and an id
/// that is not two parts are 404; a new record's form carries its defaults.</p>
/// <p>Mutation (Rule 19): drop <code>DocDB</code> from the port's <parameter>OcuPilot.Port.DocDbAppPort.MAPPINGENDPOINTS</parameter>
/// -- the form read answers 404 for a record that exists and this leg goes red.</p>
Method TestTheFormReadAnswersTheFiveFields()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "form", "Enabled": false, "Resource": ""}), "a probe record")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tId = $ClassMethod(..#PROBE, "QueryId", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A"))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form?id=" _ tId, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /docdb-application/form answers: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm), "row", "the form answers one member")
    Set tRow = tForm.%Get("row")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "Description,Enabled,Name,Namespace,Resource", "the row carries the name, the namespace and the three settings")
    Do $$$AssertEquals(tRow.%Get("Name") _ "|" _ tRow.%Get("Namespace") _ "|" _ tRow.%Get("Description") _ "|" _ tRow.%Get("Enabled") _ "|" _ tRow.%GetTypeOf("Enabled") _ "|" _ tRow.%Get("Resource"), "OcuProbe1830A|USER|form|0|boolean|", "as the instance stores them, Enabled a boolean")
    Set tLower = $ClassMethod(..#PROBE, "QueryId", $ClassMethod(..#PROBE, "Id", "user", "ocuprobe1830a"))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form?id=" _ tLower, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("row").%Get("Description"), "200 form", "the same record named in another case is the same record")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830R", {"Description": "held", "Enabled": true, "Resource": "OcuProbe1830Res"}), "a record naming it")
    Set tHeld = $ClassMethod(..#PROBE, "QueryId", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830R"))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form?id=" _ tHeld, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("row").%Get("Resource"), "200 OcuProbe1830Res", "a record's resource is the one the form reads")
    Set tAbsent = $ClassMethod(..#PROBE, "QueryId", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830Z"))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form?id=" _ tAbsent, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 PORT.NOTFOUND", "a record the instance does not hold is 404 PORT.NOTFOUND")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form?id=OcuProbe1830A", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 PORT.NOTFOUND", "an id that is not two parts is 404 PORT.NOTFOUND")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/docdb-application/form", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tNew = ##class(%DynamicObject).%FromJSON(tRaw).%Get("row")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tNew) _ " " _ tNew.%Get("Name") _ tNew.%Get("Namespace") _ tNew.%Get("Description") _ tNew.%Get("Resource") _ " " _ tNew.%Get("Enabled") _ tNew.%GetTypeOf("Enabled"), "200 Description,Enabled,Name,Namespace,Resource  1boolean", "a new record's form carries the same members, enabled and otherwise empty")
}

/// <p>AD-52: the port splits the composite id into the vendor's queries, the namespace upper-cased and the name as
/// typed, so a lookup in any case finds the record; an id that is not two non-empty parts is 404 with no vendor call;
/// a query that already names a namespace passes through.</p>
/// <p>Mutation (Rule 19): drop <code>DocDB</code> from the port's <parameter>OcuPilot.Port.DocDbAppPort.MAPPINGENDPOINTS</parameter>
/// -- the split legs go red.</p>
Method TestThePortSplitsTheCompositeId()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "split", "Enabled": true, "Resource": ""}), "a probe record")
    For tId = $ClassMethod(..#PROBE, "Id", "user", "ocuprobe1830a"), $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A") {
        Kill tQuery
        Set tQuery("name") = tId
        Set tSC = $ClassMethod(..#PORT, "Invoke", "DocDB", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ $Select($IsObject($Get(tRead)): tRead.%Get("Description"), 1: ""), "1 200 split", $Translate(tId, $Char(1), "|") _ " finds the record")
    }
    Kill tQuery
    Set tQuery("name") = "OcuProbe1830A"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DocDB", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a one-part id names no record")
    Kill tQuery
    Set tQuery("name") = $ClassMethod(..#PROBE, "Id", "USER", "")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DocDB", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "and so does an empty name")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("name") = "OcuProbe1830A"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DocDB", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a query that names its namespace passes through")
}

/// <p>AD-59: the copy-out script of a create or a change is the one vendor call with the split queries and the body;
/// a delete is the one call with no body; an id the port cannot split renders no step.</p>
/// <p>Mutation (Rule 19): drop <code>DocDB</code> from the port's <parameter>OcuPilot.Port.DocDbAppPort.MAPPINGENDPOINTS</parameter>
/// -- the query legs go red.</p>
Method TestTheScriptRendersTheSplitCall()
{
    Kill tQuery
    Set tQuery("name") = $ClassMethod(..#PROBE, "Id", "user", "OcuProbe1830A")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "DocDB", "PUT", .tQuery, {"Description": "x"}, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "a PUT is one step")
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue((tText [ "namespace=USER") && (tText [ "name=OcuProbe1830A") && (tText [ """Description"":""x"""), "naming the namespace upper-cased, the name as typed and carrying the body: " _ tText)
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "DocDB", "DELETE", .tQuery, "", "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "a DELETE is one step")
    Do $$$AssertTrue((tSteps.%Get(0).%Get("text") [ "-X DELETE") && (tSteps.%Get(0).%Get("text") [ "namespace=USER"), "a DELETE call: " _ tSteps.%Get(0).%Get("text"))
    Kill tQuery
    Set tQuery("name") = "OcuProbe1830A"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "DocDB", "PUT", .tQuery, {"Description": "x"}, "").%Size(), 0, "a one-part id renders no step")
}

/// <p>AD-54, AD-59: the copy-out draft of a create names the record as the caller typed it, the namespace upper-cased
/// and the name as written, through <method>OcuPilot.Screen.Tool.DocDbAppCreate.TypedId</method>.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Kernel.Proposal.Draft</class> read the id argument alone in place of
/// <method>OcuPilot.Screen.Tool.Write.TypedId</method> -- the script names the folded name and this test goes red.</p>
Method TestTheDraftOfACreateNamesTheRecordAsTyped()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("docdb-application", "instance", $ClassMethod(..#PROBE, "Id", "user", "ocuprobe1830mixed"), .tTargetRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    If $$$ISERR(tSC) Quit
    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = "webapp.docdbapps.create"
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = {"Namespace": "user", "Name": "OcuProbe1830Mixed", "Description": "draft"}.%ToJSON()
    Set tValues("payload") = {"Description": "draft", "Enabled": true, "Resource": ""}.%ToJSON()
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ tKey _ "/draft", tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tText, 1, 300))
    Set tScript = ##class(OcuPilot.Test.DraftRoute).Text(##class(%DynamicObject).%FromJSON(tText))
    Do $$$AssertTrue((tScript [ "name=OcuProbe1830Mixed") && (tScript [ "namespace=USER"), "the script names the record as typed in the upper-cased namespace: " _ tScript)
}

}
