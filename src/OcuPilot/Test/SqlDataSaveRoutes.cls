/// <p>Pins Data browser's Save over the wire, the screen action <code>save</code> of
/// <code>explorer.sqldata.save</code> (Story 19.8, AD-10, AD-22, AD-39, AD-53): a save answered with its
/// target, verb, read-back and per-row output; the order of the gates -- the screen's pairs before the
/// values, the values before the prohibited set; bad values refused <code>TOOL.ARGUMENTS</code>, the
/// column rules <code>EXPLORER.DATA.CHANGES</code> and a view or a keyless table
/// <code>EXPLORER.DATA.READONLY</code>, each with nothing written; as the suite's <code>%All</code>
/// account in the install namespace, OcuPilot's own tables, an unknown name in an OcuPilot schema and a
/// view over OcuPilot's table refused <code>PROHIBITED.OCUPILOTSQL</code>; a custom resource on the
/// classic Open Table page gating the save; the tool absent from every roster the agent sees, its key
/// shipping disabled; and no ledger row, agent marker or log line carrying a save.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and removes
/// <class>OcuPilot.Test.SqlSaveProbe</class>'s objects, data included, its principals and its resource,
/// so it runs on a throwaway only (<method>OcuPilot.Test.SqlConsoleProbe.Armed</method>); it assigns that
/// resource to the classic Open Table page and puts the page's own back after each test, reads the tail
/// of <code>messages.log</code>, and snapshots the stored governance policy before each test and puts it
/// back after it.</p>
Class OcuPilot.Test.SqlDataSaveRoutes Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlSaveProbe";

Parameter TOOLNAME = "explorer.sqldata.save";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerSqlDataSave";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlData";

Parameter ACTION = "/api/ocupilot/screens/explorer.sqldata/action";

/// <p>The classic Open Table page the screen replaces (AD-44).</p>
Parameter PAGE = "%cspapp.exp.utilsqlopen";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The custom resource the classic page carried before the class ran.</p>
Property PreparedPage As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedPage = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlDataSaveRoutes creates IRIS users, roles and a resource and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPage = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(..#PAGE, "O", "URL"))
    Set ..PreparedPassword = "OcuProbe198" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..RestorePage()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Fill")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(..RestorePage(), "the classic page reads its recorded custom resource again")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Put the classic Open Table page's recorded custom resource back; an error when it does not read
/// it afterwards.</p>
Method RestorePage() As %Status
{
    Set tEncoded = $ZConvert(..#PAGE, "O", "URL")
    If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) = ..PreparedPage Quit $$$OK
    Set tSC = ##class(%CSP.Portal.Utils).%SetCustomResource(tEncoded, ..PreparedPage)
    If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= ..PreparedPage Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, ..#PAGE _ " does not read its recorded custom resource"))
    Quit tSC
}

/// <p>One Save of <var>pChanges</var> (a <class>%DynamicArray</class>, or the text sent as it is) to
/// <var>pTable</var> (<code>Schema.Name</code>) in <var>pNamespace</var> as <var>pUser</var> (the
/// suite's own account when <code>""</code>): the HTTP status and the parsed answer. <var>pValues</var>,
/// where given, is sent as the body's <code>values</code> instead.</p>
Method Save(pTable As %String, pChanges, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = "USER", pUser As %String = "", pValues As %DynamicObject = "")
{
    Set tRequest = {"action": "save", "id": "sql"}
    If $IsObject(pValues) {
        Do tRequest.%Set("values", pValues)
    } Else {
        Set tValues = {}
        Do tValues.%Set("schema", $Piece(pTable, "."), "string")
        Do tValues.%Set("table", $Piece(pTable, ".", 2, *), "string")
        Do tValues.%Set("changes", $Select($IsObject(pChanges): pChanges.%ToJSON(), 1: pChanges), "string")
        Do tRequest.%Set("values", tValues)
    }
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#ACTION _ "?ns=" _ pNamespace, tUser, tPassword, .pStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

/// <p>An answer's status and the code it was refused with, with the pair a denial names.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) Quit $Get(pStatus) _ " " _ $Get(pAnswer)
    Quit pStatus _ " " _ pAnswer.%Get("code") _ $Select((pAnswer.%GetTypeOf("detail") = "object") && (pAnswer.detail.%Get("failedPair") '= ""): " " _ pAnswer.detail.%Get("failedPair"), 1: "")
}

/// <p>AC4, AC5: a confirmed Save answers the change event's triple, its verb, the read-back of an
/// action-style write and each row's outcome as output, and changes exactly its rows.</p>
Method TestASaveAnswersItsTargetVerbAndOutput()
{
    Do ..Save("OcuProbe198.Edit", [{"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "abd"}}, {"op": "update", "key": {"Code": "b"}, "original": {"Name": "stale"}, "values": {"Name": "no"}}, {"op": "delete", "key": {"Code": "f"}}], .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("target")): tStatus _ " " _ tAnswer.action _ " " _ tAnswer.target.%ToJSON() _ " " _ tAnswer.readBack.verdict, 1: ..Code(tStatus, .tAnswer)), "200 updated {""type"":""class"",""scope"":""USER"",""id"":""sql""} nothingSent", "the save answers its target, its verb and an action's read-back")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tAnswer.output.%ToJSON(), 1: ""), "{""outcome"":""saved"",""results"":[{""index"":0,""outcome"":""saved"",""rowCount"":1},{""index"":1,""outcome"":""changed"",""rowCount"":0},{""index"":2,""outcome"":""saved"",""rowCount"":1}],""saved"":2,""failed"":1}", "and each row's outcome as output")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "b", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "f"), "Name=abd Name=bee absent", "a changed, b left as it was, f removed")
}

/// <p>The order of the gates: a caller without the screen's pair is refused 403 naming it although the
/// values are bad, and a save whose values are bad is refused 400 <code>TOOL.ARGUMENTS</code> although
/// it names OcuPilot's own table, which the prohibited set would refuse.</p>
/// <p>Mutation (Rule 19): ignore <method>OcuPilot.Port.SqlPort.SaveChanges</method>'s refusal in
/// <method>OcuPilot.Screen.Tool.ExplorerSqlDataSave.ScreenActionDelta</method> -- the second leg answers
/// 403 and goes red.</p>
Method TestThePairsComeBeforeTheValuesAndTheValuesBeforeTheSet()
{
    Do ..Save("OcuProbe198.Edit", "{", .tStatus, .tAnswer, "USER", $Parameter(..#PROBE, "NODEVUSER"))
    Do $$$AssertEquals(..Code(tStatus, .tAnswer), "403 AUTH.NOPRIVILEGE %Development:USE", "the pairs before the values")
    Do ..Save("OcuPilot_Kernel_State.Proposal", "[]", .tStatus, .tAnswer, $NAMESPACE)
    Do $$$AssertEquals(..Code(tStatus, .tAnswer), "400 TOOL.ARGUMENTS", "the values before the prohibited set")
}

/// <p>Matrix rows Bad shape, Bad changes and Not writable over the wire: an unknown operation, no
/// change, 101 changes, a value of 32,768 characters, changes past 1,000,000 characters or not JSON, and
/// a value name the action does not declare are 400 <code>TOOL.ARGUMENTS</code>; a key, identity,
/// generated or stream column among the values, or a key member missing, is 400
/// <code>EXPLORER.DATA.CHANGES</code>; a view and a keyless table are 409
/// <code>EXPLORER.DATA.READONLY</code>, each with its published sentence and nothing written.</p>
Method TestBadSavesAreRefusedBeforeAnyWrite()
{
    Set tMany = []
    For tI = 1:1:101 Do tMany.%Push({"op": "delete", "key": {"Code": "f"}})
    Set tWide = []
    For tI = 1:1:31 Do tWide.%Push({"op": "update", "key": {"Code": "f"}, "original": {"Name": "eff"}, "values": {"Name": ($Translate($Justify("", 32767), " ", "w"))}})
    For tCase = $ListBuild("[{""op"":""merge"",""values"":{""Name"":""n""}}]", "an unknown op"), $ListBuild("[]", "no change"), $ListBuild(tMany.%ToJSON(), "101 changes"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""f""},""original"":{""Name"":""eff""},""values"":{""Name"":""" _ $Translate($Justify("", 32768), " ", "v") _ """}}]", "a value of 32,768 characters"), $ListBuild(tWide.%ToJSON(), "changes past 1,000,000 characters"), $ListBuild("{", "changes that are not JSON") {
        Do ..Save("OcuProbe198.Edit", $List(tCase, 1), .tStatus, .tAnswer)
        Do $$$AssertEquals(..Code(tStatus, .tAnswer), "400 TOOL.ARGUMENTS", $List(tCase, 2))
    }
    Do ..Save("", "", .tStatus, .tAnswer, "USER", "", {"schema": "OcuProbe198", "table": "Edit", "changes": "[{\"op\":\"delete\",\"key\":{\"Code\":\"f\"}}]", "extra": "x"})
    Do $$$AssertEquals(..Code(tStatus, .tAnswer), "400 TOOL.ARGUMENTS", "a value name the action does not declare")
    For tCase = $ListBuild("OcuProbe198.Edit", "[{""op"":""update"",""key"":{""Code"":""f""},""original"":{""Code"":""f""},""values"":{""Code"":""k""}}]", "a key column"), $ListBuild("OcuProbe198.Ident", "[{""op"":""insert"",""values"":{""Id2"":""9"",""Name"":""n""}}]", "an identity column"), $ListBuild("OcuProbe198.Edit", "[{""op"":""update"",""key"":{""Code"":""f""},""original"":{""Shout"":""EFF""},""values"":{""Shout"":""X""}}]", "a computed column"), $ListBuild("OcuProbe198.Edit", "[{""op"":""update"",""key"":{""Code"":""f""},""original"":{""Memo"":null},""values"":{""Memo"":""m""}}]", "a stream column"), $ListBuild("OcuProbe198.Edit", "[{""op"":""delete"",""key"":{""Name"":""eff""}}]", "a key member missing") {
        Do ..Save($List(tCase, 1), $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertEquals(..Code(tStatus, .tAnswer), "400 EXPLORER.DATA.CHANGES", $List(tCase, 3))
    }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONDATACHANGES, "with the published sentence")
    For tCase = $ListBuild("OcuProbe198.EditView", "[{""op"":""update"",""key"":{""Code"":""f""},""original"":{""Name"":""eff""},""values"":{""Name"":""v""}}]", "a view"), $ListBuild("OcuProbe198.Comp", "[{""op"":""delete"",""key"":{""N"":""1""}}]", "a keyless table") {
        Do ..Save($List(tCase, 1), $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertEquals(..Code(tStatus, .tAnswer), "409 EXPLORER.DATA.READONLY", $List(tCase, 3))
    }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONDATAREADONLY, "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "f", "Code,Name") _ " " _ $ClassMethod(..#PROBE, "Value", "SELECT COUNT(*) FROM OcuProbe198.Comp"), "Code=f|Name=eff 1", "and nothing was written")
}

/// <p>AC9: as the suite's <code>%All</code> account in the install namespace, a save to a table in an
/// OcuPilot schema, to a name that schema does not hold, and to a view over OcuPilot's proposal table is
/// each refused 403 <code>PROHIBITED.OCUPILOTSQL</code> with its published sentence -- the unknown name
/// by its text alone, before any statement, rather than 404.</p>
/// <p>Mutation (Rule 19): leave <code>statement</code> out of
/// <method>OcuPilot.Screen.Tool.ExplorerSqlDataSave.ScreenActionDelta</method>'s arguments -- the unknown
/// name answers 404 and goes red.</p>
Method TestOcuPilotsOwnTablesAreRefused()
{
    Set tDelete = [{"op": "delete", "key": {"ID": "0"}}]
    For tTable = "OcuPilot_Kernel_State.Proposal", "OcuPilot_Kernel_State.OcuProbe198NoSuchTable", $Parameter(..#PROBE, "OWNVIEW") {
        Do ..Save(tTable, tDelete, .tStatus, .tAnswer, $NAMESPACE)
        Do $$$AssertEquals(..Code(tStatus, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "403 PROHIBITED.OCUPILOTSQL " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSQLREASON, tTable)
    }
}

/// <p>AD-44: a custom resource on the classic Open Table page gates the save -- a principal holding
/// every other pair and the table's grants is refused 403 naming it, and saves once the page's own is
/// back.</p>
Method TestACustomResourceOnTheOpenTablePageGatesTheSave()
{
    Set tResource = $Parameter(..#PROBE, "PAGERESOURCE")
    Do $$$AssertStatusOK(##class(%CSP.Portal.Utils).%SetCustomResource($ZConvert(..#PAGE, "O", "URL"), tResource), "the probe resource is assigned to the page")
    Set tChanges = [{"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "up"}}]
    Do ..Save("OcuProbe198.Edit", tChanges, .tStatus, .tAnswer, "USER", $Parameter(..#PROBE, "UPUSER"))
    Do $$$AssertEquals(..Code(tStatus, .tAnswer), "403 AUTH.NOPRIVILEGE " _ tResource _ ":USE", "a principal lacking it is refused, named")
    Do $$$AssertStatusOK(..RestorePage(), "the page's own resource is back")
    Do ..Save("OcuProbe198.Edit", tChanges, .tStatus, .tAnswer, "USER", $Parameter(..#PROBE, "UPUSER"))
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tStatus _ " " _ tAnswer.output.saved, 1: ..Code(tStatus, .tAnswer)), "200 1", "and saves once it is gone")
}

/// <p>AC4, AD-53: the save is in no roster the agent sees -- the provider tool list, the dispatch
/// lookup, a proposal-path resolve, the screen context's <code>tools</code> -- while the screen's route
/// reaches it.</p>
Method TestTheSaveIsAbsentFromEveryRosterTheAgentSees()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertEquals($ClassMethod(..#TOOLCLASS, "Advertised"), 0, "declared unadvertised")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tWire = $ClassMethod(tRegistry, "WireName", ..#TOOLNAME)
    Set tProviderNames = ""
    For tI = 1:1:+$Get(tProvider) Set tProviderNames = tProviderNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertTrue('$ListFind(tProviderNames, tWire), "the provider tool list leaves it out")
    Kill tByWire, tByName, tForRoute
    Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
    Do $$$AssertTrue('$IsObject($Get(tByWire)), "the dispatch lookup does not find it")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOLNAME, .tByName)
    Do $$$AssertTrue('$IsObject($Get(tByName)), "nor does a proposal-path resolve")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOLNAME, .tForRoute, 1)
    Do $$$AssertTrue($IsObject($Get(tForRoute)), "while the screen's route reaches it")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tTools), "the screen's context tools build")
    Set tJson = $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson '[ tWire) && (tJson '[ ..#TOOLNAME), "and carry no save: " _ tJson)
}

/// <p>AC10, AD-22, AD-39: the key ships disabled and reads disabled while a person's save writes; and a
/// save's values, SQLCODE and message reach no ledger row, no agent marker and no log line.</p>
Method TestTheKeyShipsDisabledAndASaveLeavesNoTrace()
{
    Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(..#TOOLNAME, .tListed)
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(..#TOOLNAME, "write", .tEnabled, .tSource)
    Do $$$AssertEquals(tListed _ " " _ tValue _ " " _ ''$Get(tEnabled), "1 0 0", "listed, disabled, and read disabled")
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set tMark = "OcuProbe198Trace" _ $Translate($ZTimeStamp, ",.", "")
    Set tChanges = []
    Do tChanges.%Push({"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": (tMark)}})
    Do tChanges.%Push({"op": "insert", "values": {"Code": "b", "Name": (tMark)}})
    Do ..Save("OcuProbe198.Edit", tChanges, .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")): tStatus _ " " _ tAnswer.output.saved _ " " _ tAnswer.output.results.%Get(1).outcome, 1: ..Code(tStatus, .tAnswer)), "200 1 error", "a person's save writes, answering its refused row")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = ?", ..#TOOLNAME)
    Do $$$AssertEquals($Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1), 0, "no ledger row names the save")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Test.AuditMarker).MarkerName(), ..#TOOLNAME, .tData), 0, "no agent marker carries it")
    Set tFound = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If $ZConvert(tLine, "U") [ $ZConvert(tMark, "U") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertEquals(tFound, "", "and no log line carries its values or the instance's answer")
}

}
