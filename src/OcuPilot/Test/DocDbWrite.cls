/// <p>Pins Story 19.17's two writes end to end in <code>USER</code>, on both callers (AD-6, AD-10, AD-22,
/// AD-53, AD-54, AD-55, AD-58, AD-59): the screen's create over <code>POST /explorer/docdb</code> -- 201
/// with a read-back that matches, the name rules, a taken name and class, a mapped package and an
/// undeclared field refused with nothing created -- and its Drop through the list's action; the service
/// refusal on the read, the Save, the Drop and the agent's mint; the agent's create minted and confirmed,
/// and refused at the confirm once its name was taken in another case; the agent's drop refused by
/// governance at the baseline and confirmed once its key is enabled; OcuPilot's own code refused on both
/// callers; and the copy-out draft of a create.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP as <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it enables
/// <code>%Service_DocDB</code> and creates and drops probe databases named <code>OcuProbe1917*</code>. The
/// service and the stored governance policy are put back after every test, and every probe is removed
/// and read back gone.</p>
Class OcuPilot.Test.DocDbWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DocDbProbe";

Parameter NAMESPACE = "USER";

/// <p>The scope a confirm is sent from to pin that it writes where the proposal read.</p>
Parameter OTHERSCOPE = "HSCUSTOM";

Parameter CREATE = "OcuPilot.Screen.Tool.ExplorerDocDbCreate";

Parameter DELETE = "OcuPilot.Screen.Tool.ExplorerDocDbDelete";

/// <p>The Save route, relative to the API base.</p>
Parameter SAVEPATH = "/explorer/docdb";

/// <p>The drop's governance key, which the baseline disables.</p>
Parameter DELETEKEY = "explorer.docdb.delete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Whether <code>%Service_DocDB</code> was enabled before the test, put back after it.</p>
Property PreparedService As %String;

/// <p>The governance policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbWrite enables %Service_DocDB and creates and drops document databases on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "ServiceEnabled", .tPrior)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = tPrior
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

/// <p>The service, the policy and the probes are put back and read back, whether the test passed or
/// failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", ..PreparedService), "%Service_DocDB is put back as it was found")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe database and class is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#OTHERSCOPE), "and none is left in " _ ..#OTHERSCOPE)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One request over the wire as the test account, scoped to <parameter>NAMESPACE</parameter>:
/// the HTTP status, the parsed envelope and the headers.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Kill pHeaders
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .pHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 60)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>The Save of <var>pBody</var>, as <code>status code</code>, with <code>:field</code> for a
/// violation.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do ..Call("POST", ..#SAVEPATH, pBody, .tStatus, .pAnswer, .tHeaders)
    Set tText = tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
    If $IsObject(pAnswer) && $IsObject(pAnswer.%Get("detail")) && $IsObject(pAnswer.detail.%Get("violations")) && (pAnswer.detail.violations.%Size() > 0) Set tText = tText _ " " _ pAnswer.detail.violations.%Get(0).field
    Quit tText
}

/// <p>The agent's call of <var>pTool</var> for <var>pName</var>, scoped to
/// <parameter>NAMESPACE</parameter> and minted on a seeded turn.</p>
Method MintFor(pTool As %String, pName As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {"rationale": "probe", "expectedImpact": "probe"}
    Do tArgs.%Set("Name", pName, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = $ClassMethod(pTool, "View", "", tArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p>Confirm <var>pProposal</var> in process as the running account, scoped to
/// <var>pScope</var>.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String, pScope As %String = {..#NAMESPACE}) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pScope)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>AC4: the screen's create answers 201 as JSON naming the database, with a read-back that matches;
/// the instance holds the database and its class, and the list's read shows the row. A case variant is
/// a taken name and the class's own name a taken class (409); an invalid name, a name over the length
/// and a mapped package are refused on <code>Name</code> (422); a field other than the name is refused
/// (400); none of them creates anything.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.ExplorerDocDbCreate.READBACKFIELDS</parameter>
/// -- the read-back reads unchecked and this goes red.</p>
Method TestTheSaveCreatesAndRefusesEachRow()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Do ..Call("POST", ..#SAVEPATH, {"Name": "OcuProbe1917A"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.readBack.verdict, 1: ""), "OcuProbe1917A|matches", "naming the database, with a read-back that matches")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A") && $ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "ISC.DM.OcuProbe1917A"), "the instance holds the database and its class")
    Do ..Call("GET", "/screens/explorer.docdb/read?maxRows=1000", "", .tStatus, .tRead, .tHeaders)
    Set tListed = ""
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) {
        Set tIterator = tRead.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.Name = "OcuProbe1917A" Set tListed = tRow.Name _ "|" _ tRow.Class
        }
    }
    Do $$$AssertEquals(tStatus _ " " _ tListed, "200 OcuProbe1917A|ISC.DM.OcuProbe1917A", "the list's read shows the row")

    Do $$$AssertEquals(..Save({"Name": "ocuprobe1917a"}), "409 " _ ##class(OcuPilot.Api.DocDbError).#NAMETAKEN, "a case variant is a taken name")
    Do $$$AssertEquals(..Save({"Name": "ISC.DM.OcuProbe1917A"}), "409 " _ ##class(OcuPilot.Api.DocDbError).#CLASSTAKEN, "the class's own name is a taken class")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1917_B"}, .tAnswer), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEINVALID _ " Name", "an invalid name is refused on Name")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.detail.violations.%Get(0).reason, 1: ""), ##class(OcuPilot.Api.DocDbError).#REASONNAMEINVALID, "with the published sentence")
    Do $$$AssertEquals(..Save({"Name": ("OcuProbe1917" _ $Translate($Justify("", 202), " ", "b"))}), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEINVALID _ " Name", "a 214-character unqualified name is refused on Name")
    Do $$$AssertEquals(..Save({"Name": "Ens.OcuProbe1917"}), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED _ " Name", "a mapped package is refused on Name")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1917B", "Resource": "%DB_USER"}), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " Resource", "a resource is not a field the create takes")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917B") && '$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "Ens.OcuProbe1917") && '$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "ISC.DM.OcuProbe1917A"), "no refusal created a database")
}

/// <p>AC2: with the service disabled, the screen's read, its Save, its Drop and the agent's create each
/// answer 409 <code>DOCDB.SERVICE.DISABLED</code> and cost one vendor access-denied row; nothing is
/// created or dropped, and the service stays disabled.</p>
Method TestADisabledServiceIsReportedOnEveryCaller()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "%Service_DocDB is disabled for this test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "a probe database is made directly")
    Set tCode = ##class(OcuPilot.Api.DocDbError).#SERVICEDISABLED
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tBefore), "the access-denied rows are counted")
    Do ..Call("GET", "/screens/explorer.docdb/read", "", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ "|" _ tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ ##class(OcuPilot.Api.DocDbError).#REASONSERVICEDISABLED, "the read is refused with the sentence")
    Do $$$AssertEquals(..Save({"Name": "OcuProbe1917B"}), "409 " _ tCode, "the Save is refused")
    Do ..Call("POST", "/screens/explorer.docdb/action", {"action": "delete", "id": "OcuProbe1917A"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "409 " _ tCode, "the Drop is refused")
    Set tSC = ..MintFor(..#CREATE, "OcuProbe1917C", .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ tCode, "the agent's create is refused at its fresh read")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tAfter), "the rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 4, "each of the four refusals wrote one vendor access-denied row")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917B") && '$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917C"), "nothing was created")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A"), "nothing was dropped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ServiceEnabled", .tEnabled), "the service reads")
    Do $$$AssertEquals(tEnabled, 0, "and stays disabled")
}

/// <p>The agent's create of an invalid name is refused at its fresh read 422
/// <code>DOCDB.NAME.INVALID</code> with the rule's sentence, and of a name whose package this namespace
/// keeps in another database 422 <code>DOCDB.NAME.MAPPED</code>; with the service disabled, neither
/// reaches the vendor's service check, so neither writes an audit row, and nothing is minted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Invoke</method> skip its name rules and
/// its package check -- both names reach the service check, answer 409 and this goes red.</p>
Method TestTheAgentsMintRefusesAnInvalidOrMappedName()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "%Service_DocDB is disabled for this test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tBefore), "the access-denied rows are counted")
    Set tSC = ..MintFor(..#CREATE, "OcuProbe1917_a", .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEINVALID _ "|" _ ##class(OcuPilot.Api.DocDbError).#REASONNAMEINVALID, "an invalid name is refused at the fresh read with the rule's sentence")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted for it")
    Set tSC = ..MintFor(..#CREATE, "Ens.OcuProbe1917", .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, "a mapped package is refused by the fresh read's 422")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted for it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tAfter), "the rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 0, "neither name reached the vendor's service check")
}

/// <p>AC5: the list's Drop removes the database, its class and its row, and reads back gone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Drop</method> skip the vendor call -- the
/// database survives and this goes red.</p>
Method TestTheScreensDropRemovesTheDatabase()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "a probe database is made")
    Do ..Call("POST", "/screens/explorer.docdb/action", {"action": "delete", "id": "OcuProbe1917A"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the Drop answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "deleted|docdb-database|ocuprobe1917a|notFound", "naming the dropped database, read back gone")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A") && '$ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "ISC.DM.OcuProbe1917A"), "its database and class are gone")
}

/// <p>AC6: the agent's create mints a card naming the database, and its confirm, sent from another
/// namespace's scope, creates it in the namespace the proposal read and reads back matching; a create
/// minted for a free name is refused at the confirm once another session has taken that name in another
/// case, and a create of a name the namespace holds is refused at the mint.</p>
/// <p>Mutation (Rule 19): let the confirm skip the absence fingerprint -- the taken name reaches the
/// vendor and answers its own refusal, and this goes red; empty
/// <method>OcuPilot.Screen.Tool.ExplorerDocDbWrite.PortQuery</method> -- the confirm creates the database
/// in <parameter>OTHERSCOPE</parameter> and this goes red.</p>
Method TestTheAgentsCreateConfirmsAndATakenNameIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Set tSC = ..MintFor(..#CREATE, "OcuProbe1917C", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create mints")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON() _ "|" _ tProposal.target.type _ "|" _ tProposal.target.id, "[{""field"":""Name"",""before"":"""",""after"":""OcuProbe1917C""}]|docdb-database|ocuprobe1917c", "its card shows the name")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertStatusOK(tSC, "and confirms from " _ ..#OTHERSCOPE _ "'s scope: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ "|" _ tResult.action _ "|" _ tResult.readBack.verdict, 1: ""), "1|created|matches", "creating it, marked (AD-15) and read back matching")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917C") && '$ClassMethod(..#PROBE, "Exists", ..#OTHERSCOPE, "OcuProbe1917C"), "the database exists in the namespace the proposal read, and not in the confirm's scope")

    Set tSC = ..MintFor(..#CREATE, "OcuProbe1917D", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create is minted for a free name")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OCUPROBE1917D"), "which another session then takes in another case")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target")
    Set tSC = ..MintFor(..#CREATE, "ocuprobe1917c", .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (+$Get(tHttp) = 400) && ($System.Status.GetErrorText(tSC) [ "already present"), "a create of a name the namespace holds in another case is refused at the mint: " _ $Get(tHttp))
}

/// <p>AC6: at the baseline the agent's drop is refused by governance at dispatch, with nothing minted;
/// once its key is enabled, its card names the database and its class as removed, and the confirmed drop
/// removes it and reads back gone.</p>
/// <p>Mutation (Rule 19): set <code>explorer.docdb.delete</code> <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the dispatch mints and this goes red.</p>
Method TestTheAgentsDropIsGovernedThenConfirmed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "a probe database is made")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    Set tWire = ##class(OcuPilot.Screen.Tool.Registry).WireName(..#DELETEKEY)
    Set tUse = {"type": "tool_use", "id": "toolu_docdb_drop", "input": {"Name": "OcuProbe1917A", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Set("name", tWire, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tAnswer = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
    Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", "the agent's drop is refused by governance at the baseline")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A"), "with nothing dropped")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)

    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled through its stored setting")
    Set tSC = ..MintFor(..#DELETE, "ocuprobe1917a", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the drop is minted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""Name"",""before"":""OcuProbe1917A"",""after"":"""",""removed"":true},{""field"":""Class"",""before"":""ISC.DM.OcuProbe1917A"",""after"":"""",""removed"":true}]", "its card names the database and its class, removed")
    Set tSC = ..ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "and its confirm drops it: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ "|" _ tResult.action _ "|" _ tResult.readBack.verdict, 1: ""), "1|deleted|notFound", "marked (AD-15) and read back gone")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A"), "the database is gone")
}

/// <p>AC7: a create naming <code>OcuPilot.OcuProbe1917X</code> on the screen, and the agent's confirmed
/// create of <code>ocupilot.ocuprobe1917y</code>, are refused 403 <code>PROHIBITED.OCUPILOTCODE</code>
/// with nothing created; a drop whose database's class begins with <code>OcuPilot</code> in any case is
/// refused by the same arm, and a probe's drop is not. Both create names carry the probe prefix, so a
/// create that wrongly succeeds is removed by <method>OcuPilot.Test.DocDbProbe.RemoveAll</method>.</p>
/// <p>Mutation (Rule 19): remove the <code>docdb-database</code> arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- each leg goes red.</p>
Method TestOcuPilotsOwnCodeIsRefusedOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Set tOwn = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE
    Do ..Call("POST", ..#SAVEPATH, {"Name": "OcuPilot.OcuProbe1917X"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ "|" _ tAnswer.reason, 1: ""), "403 " _ tOwn _ "|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tOwn), "the screen's create of OcuPilot.OcuProbe1917X is refused with the published sentence")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuPilot.OcuProbe1917X") && '$ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "OcuPilot.OcuProbe1917X"), "and nothing is created")
    Set tSC = ..MintFor(..#CREATE, "ocupilot.ocuprobe1917y", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create of ocupilot.ocuprobe1917y mints")
    Set tSC = ..ConfirmIn($Get(tProposal), .tResult, .tConfirmHttp, .tCode)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "403 " _ tOwn, "and its confirm is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "ocupilot.ocuprobe1917y") && '$ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "ocupilot.ocuprobe1917y"), "with nothing created")
    For tCase = $ListBuild("ocupilot.z", 1), $ListBuild("OCUPILOTDB.Z", 1), $ListBuild("OcuProbe1917A", 0) {
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("docdb-database", ..#NAMESPACE, $List(tCase, 1), .tRef)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("explorer.docdb.delete", tRef, "{}", "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for " _ $List(tCase, 1))
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 2): "1 " _ tOwn, 1: "0 "), "a drop of " _ $List(tCase, 1) _ $Select($List(tCase, 2): " is refused", 1: " is not"))
    }
}

/// <p>AD-59: the copy-out draft of the agent's create renders the create of the one name in the
/// namespace the proposal read, closes the proposal as a draft, and creates nothing.</p>
Method TestTheCopyOutDraftNamesTheCreate()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Set tSC = ..MintFor(..#CREATE, "OcuProbe1917E", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create mints")
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, $Username, "https://draft.example:52773", .tAnswer, .tDraftHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the draft is taken: " _ $Get(tCode))
    If '$IsObject($Get(tAnswer)) Quit
    Set tText = tAnswer.draft.steps.%Get(0).text
    Do $$$AssertEquals(tAnswer.state _ "|" _ tAnswer.closedReason _ "|" _ tAnswer.draft.steps.%Get(0).kind, "canceled|draft|objectscript", "an ObjectScript draft that closes the proposal")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "CreateDatabase(""OcuProbe1917E"")"), "creating the one name in USER: " _ tText)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917E"), "and nothing is created")
}

}
