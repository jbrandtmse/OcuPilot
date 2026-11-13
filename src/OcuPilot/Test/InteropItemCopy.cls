/// <p>Pins Story 20.40's item copy end to end against a probe production in <code>USER</code> (AD-6, AD-15, AD-54, AD-55, AD-58, AD-59,
/// AD-62): the agent's copy minted, confirmed over HTTP, read back and ledgered; the person's Save at
/// <code>POST /interop/items/copy</code>; the copy's class, settings, disabled state and pool size; the vendor's audit trail; the
/// copy's Item settings read; and each refusal of the matrix by its code with nothing written.</p>
/// <p>It uses <class>OcuPilot.Test.InteropItemControl</class>'s class methods. The principals' legs of the copy are
/// <class>OcuPilot.Test.InteropItemGate</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and runs a probe production in
/// <code>USER</code>. One class per run.</p>
Class OcuPilot.Test.InteropItemCopy Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemCopy";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The probe operation every copy here copies, and the name the copies take.</p>
Parameter SOURCE = "OcuPilotProbeOp";

Parameter COPY = "OcuPilotProbeCopy";

/// <p>The <code>CopyFrom</code> a Save sends as a JSON number.</p>
Parameter NUMBERFROM = "#number";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemCopy compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes and its proposals; a failing status when <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemCopy left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The seam and the fake gate are cleared, the probe's items are asserted as they began and put back when they are not.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    Do $$$AssertStatusOK(tSC, "the probe production is left stopped with its items and settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The person's copy as <code>status code</code>, the answer in <var>pAnswer</var>: <code>POST /interop/items/copy</code> for
/// <var>pName</var> in <var>pProduction</var>, and <var>pFrom</var> as <code>CopyFrom</code> unless it is <code>$Char(0)</code>, or as the
/// number 5 when it is <parameter>NUMBERFROM</parameter>.</p>
ClassMethod SaveCopy(pName As %String, pFrom As %String, Output pAnswer, pProduction As %String = {..#PRODUCTION}, Output pContentType As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("Production", pProduction, "string")
    Do tBody.%Set("Name", pName, "string")
    If pFrom = ..#NUMBERFROM {
        Do tBody.%Set("CopyFrom", 5, "number")
    } ElseIf pFrom '= $Char(0) {
        Do tBody.%Set("CopyFrom", pFrom, "string")
    }
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/items/copy", tBody, .tStatus, .pAnswer, .pContentType)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The arguments of the agent's copy of <var>pFrom</var> as <var>pName</var>.</p>
ClassMethod CopyArgs(pName As %String, pFrom As %String) As %DynamicObject
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", pName)
    Do tArgs.%Set("CopyFrom", pFrom, "string")
    Quit tArgs
}

/// <p>The stored <code>PoolSize</code> of every item named <var>pName</var> in the probe production, comma-separated.</p>
ClassMethod StoredColumn(pColumn As %String, pName As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT " _ pColumn _ " FROM Ens_Config.Item WHERE Production = ? AND %EXACT(Name) = ?", ..#PRODUCTION, pName)
        While tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>How many rows <code>Ens_Config.Production</code> holds in <code>USER</code>.</p>
ClassMethod ProductionRows() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens_Config.Production")
        If tRS.%Next() Set tCount = tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The value of the Host setting <var>pSetting</var> and its source, <code>value|source</code>, that the Item settings read answers
/// for the item <var>pName</var>, or <code>unread</code>.</p>
ClassMethod SettingOf(pName As %String, pSetting As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("item") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If '$IsObject($Get(tRows)) Quit "unread " _ $Get(tHttp)
    Set tText = "absent"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.Target = "Host") && (tRow.Name = pSetting) Set tText = tRow.Value _ "|" _ tRow.Source
    }
    Quit tText
}

/// <p>The port's <code>COPY</code> of <var>pName</var> from <var>pFrom</var> through <var>pPort</var> as <code>status code</code>.</p>
ClassMethod PortCopy(pPort As %String, pName As %String, pFrom As %String, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tSC = $ClassMethod(pPort, "Invoke", "Items", "COPY", .tQuery, {"CopyFrom": (pFrom), "Enabled": false}, .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "")
}

/// <p>AC1, AC4: the agent's copy of the probe operation, minted for the HTTP account and confirmed over HTTP, adds the copy disabled
/// with the source's class, comment and setting; its card shows the source; it is not destructive, states its consequence, is
/// marked (AD-15) and ledgered once, survives a recompile of the production class, and is audited by name with no field value;
/// the source is unchanged.</p>
/// <p>Mutation (Rule 19): make the <code>COPY</code> branch of <method>OcuPilot.Port.InteropPort.PerformItem</method> keep the
/// source's <code>Enabled</code> -- the disabled legs go red; drop its <code>SaveToClass</code> -- the class and recompile legs go red.</p>
Method TestTheAgentsCopyConfirmsOverHttp()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetSetting", "InitSeconds", 7), "InitSeconds is stored at 7 on the source")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tRows = ..ProductionRows()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..CopyArgs(..#COPY, ..#SOURCE), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the copy mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""CopyFrom"",""before"":"""",""after"":""" _ ..#SOURCE _ """}]", "its card shows the source: " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item|USER|" _ ..#PRODUCTION _ "~" _ ..#COPY, "the target is the new item, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.ITEM.COPY|0", "its consequence says the copy is added disabled, and it is not destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the copy confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, $Parameter(..#TOOL, "TOOLNAME")), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tBaseline = $Parameter(..#CONTROL, "BASELINE")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ "," _ ..#COPY _ ":0", "the copy is added, disabled, and the source is still enabled")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "StoredEnabled", ..#COPY) _ "|" _ $ClassMethod(..#CONTROL, "ClassEnabled", ..#COPY), "0|false", "stored disabled and carried into the production class")
    Do $$$AssertEquals(..StoredColumn("ClassName", ..#COPY) _ "|" _ ..StoredColumn("ClassName", ..#SOURCE), $Parameter(..#CONTROL, "OPCLASS") _ "|" _ $Parameter(..#CONTROL, "OPCLASS"), "the copy takes the source's class")
    Do $$$AssertEquals(..SettingOf(..#COPY, "InitSeconds") _ "|" _ ..SettingOf(..#SOURCE, "InitSeconds"), "7|production|7|production", "the copy holds the source's setting and the source still holds it")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the class compiles again")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ "," _ ..#COPY _ ":0", "and the compile keeps the copy")
    Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
    Do $$$AssertTrue((tAudit [ ("item " _ ..#COPY _ " of " _ ..#PRODUCTION)) && (tAudit [ ("as a copy of " _ ..#SOURCE)) && ($Length(tAudit, "as a copy of") = 2), "the vendor's audit trail holds one copy row, naming the new item and the source: " _ tAudit)
    Do $$$AssertEquals(..ProductionRows(), tRows, "the copy added no production row")
}

/// <p>A copy on a running production starts and stops no job and does not start the production again, and the production reads as needing an
/// update, as after an add.</p>
/// <p>Mutation (Rule 19): call <code>Ens.Director.UpdateProduction</code> after the save in the <code>COPY</code> branch of
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the production-state leg goes red.</p>
Method TestACopyOnARunningProductionChangesNoJob()
{
    Set tProductions = "OcuPilot.Test.InteropControl"
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "StartProduction"), "the probe production is started")
    Set tJobs = $ClassMethod(..#CONTROL, "Jobs")
    Set tStarted = $ClassMethod(tProductions, "LastStart")
    Do $$$AssertEquals($ClassMethod(tProductions, "State"), "Running|0", "and nothing is pending")
    Set tText = ..SaveCopy(..#COPY, ..#SOURCE, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the copy is saved: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Hang 2
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Jobs"), tJobs, "no job started or stopped")
    Do $$$AssertEquals($ClassMethod(tProductions, "LastStart"), tStarted, "and the production was not started again")
    For tTry = 1:1:10 {
        If $Piece($ClassMethod(tProductions, "State"), "|", 2) Quit
        Hang 0.5
    }
    Do $$$AssertEquals($ClassMethod(tProductions, "State"), "Running|1", "the production reads as needing an update")
}

/// <p>AC1, AC2: the person's Save copies the item, answers 201 with the new item's id and a read-back that matches, adds it disabled,
/// and the copy's Item settings read lists the source's value for a setting the source holds; a copy of a business process whose pool size
/// is 0 reads a pool size of 1 and leaves the source at 0, and a source with a comment gives the copy the comment.</p>
/// <p>Mutation (Rule 19): build the clone in <method>OcuPilot.Port.InteropPort.PerformItem</method> with
/// <code>Ens.Config.Item.%New(ClassName)</code> in place of <code>%ConstructClone(1)</code> -- the settings leg goes red.</p>
Method TestThePersonsSaveCopiesTheItemAndItsSettings()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetSetting", "InitSeconds", 7), "InitSeconds is stored at 7 on the source")
    Set tText = ..SaveCopy(..#COPY, ..#SOURCE, .tAnswer, , .tContentType)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue(tContentType [ "application/json", "as application/json: " _ tContentType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): $Translate(tAnswer.id, $Char(1), "~") _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#PRODUCTION _ "~" _ ..#COPY _ "|production-item|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the new item's id and a read-back that matches")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "StoredEnabled", ..#COPY) _ "|" _ $ClassMethod(..#CONTROL, "ClassEnabled", ..#COPY), "0|false", "the copy is stored disabled and carried into the class")
    Do $$$AssertEquals(..SettingOf(..#COPY, "InitSeconds"), "7|production", "the copy's Item settings list the source's value (AC2)")
    Do $$$AssertEquals(..StoredColumn("Comment", ..#COPY), ..StoredColumn("Comment", ..#SOURCE), "the copy takes the source's comment")
    ; A business process whose pool size is 0.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeProc", "EnsLib.MsgRouter.RoutingEngine", 0, 0), "a business process with a pool size of 0 is stored")
    Set tText = ..SaveCopy("OcuPilotProbeProcCopy", "OcuPilotProbeProc", .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "its copy is saved: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..StoredColumn("PoolSize", "OcuPilotProbeProcCopy") _ "|" _ ..StoredColumn("PoolSize", "OcuPilotProbeProc"), "1|0", "the copy reads a pool size of 1 and the source stays at 0")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "StoredEnabled", "OcuPilotProbeProcCopy"), "0", "and is disabled")
    ; A source named in another letter case is found as it is stored.
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..SaveCopy("OcuPilotProbeLowerCopy", $ZConvert(..#SOURCE, "L"), .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "a copy from the source named in lower case is saved: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..SettingOf("OcuPilotProbeLowerCopy", "InitSeconds"), "7|production", "and carries the stored source's setting")
    Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
    Do $$$AssertTrue(tAudit [ ("as a copy of " _ ..#SOURCE), "the audit names the source as it is stored: " _ tAudit)
}

/// <p>AC1: the script a person takes instead of confirming a copy (AD-59) clones the named source, names the clone, stores it disabled, applies the
/// pool-size rule, saves the production and its class, and drops the production on its last line.</p>
/// <p>Mutation (Rule 19): remove <code>Set tItem.Enabled = 0</code> from the <code>COPY</code> branch of
/// <method>OcuPilot.Port.InteropPort.ItemSnippet</method> -- the disabled clause goes red.</p>
Method TestTheScriptOfACopyClonesTheSourceDisabledAndSavesTheClass()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Items", "COPY"), "objectscript", "a copy has an ObjectScript form")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "Probe.Production" _ $Char(1) _ "Probe.Copy"
    Set tBody = {"CopyFrom": "Probe.Source", "Enabled": false}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Items", "COPY", .tQuery, tBody)
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue((tText [ "FindItemByConfigName(""Probe.Source"").%ConstructClone(1)"), "the clone is the named source's: " _ tText)
    Do $$$AssertTrue((tText [ "Set tItem.Name = ""Probe.Copy"""), "it takes the new name")
    Do $$$AssertTrue((tText [ "Set tItem.Enabled = 0"), "it is stored disabled")
    Do $$$AssertTrue((tText [ "tItem.PoolSize = 0) Set tItem.PoolSize = 1"), "a business process of pool size 0 takes 1")
    Do $$$AssertTrue((tText [ "tProduction.%Save()") && (tText [ "SaveToClass(tItem)"), "the production and its class are saved")
    Do $$$AssertTrue((tText '[ "UpdateProduction") && (tText '[ "CleanProduction"), "and nothing updates the production")
    Do $$$AssertEquals($Piece(tText, $Char(10), *), " Kill tItem, tProduction", "the last line drops the production")
}

/// <p>AC3: each refusal of the matrix is refused by its code before anything is written, at the person's Save and, where the mint judges it,
/// at the agent's mint: a name held in any letter case, or held twice (409 <code>TAKEN</code>), an illegal name (422 <code>NAME</code>), a source that is empty
/// or absent (422 <code>COPYSOURCE</code>), of the wrong JSON type (422 <code>PORT.FIELD.SHAPE</code>) or held twice (422
/// <code>AMBIGUOUS</code>), a production the namespace does not hold (404) and a namespace without interoperability (409
/// <code>INTEROP.NAMESPACE</code>).</p>
/// <p>Mutation (Rule 19): drop the source count from <method>OcuPilot.Port.InteropPort.CopyViolations</method> -- the absent-source and
/// held-twice rows go red; make <method>OcuPilot.Port.InteropPort.ReadItem</method> stop inverting for <code>COPY</code> -- the taken rows go red.</p>
Method TestEachRefusalIsRefusedByItsCodeAndWritesNothing()
{
    Set tE = ..#ERROR
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBaseline = $Parameter(..#CONTROL, "BASELINE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "a twin item is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "and a second item of its name")
    Set tItems = tBaseline _ ",OcuPilotProbeTwin:0,OcuPilotProbeTwin:0"
    For tCase = $ListBuild("OcuPilotProbeOp", ..#SOURCE, "409 " _ $Parameter(tE, "ITEMTAKEN")), $ListBuild($ZConvert(..#SOURCE, "L"), ..#SOURCE, "409 " _ $Parameter(tE, "ITEMTAKEN")), $ListBuild("OcuPilotProbeTwin", ..#SOURCE, "409 " _ $Parameter(tE, "ITEMTAKEN")), $ListBuild("-OcuPilotBad", ..#SOURCE, "422 " _ $Parameter(tE, "ITEMNAME")), $ListBuild(..#COPY, "", "422 " _ $Parameter(tE, "ITEMCOPYSOURCE")), $ListBuild(..#COPY, "OcuPilotProbeNone", "422 " _ $Parameter(tE, "ITEMCOPYSOURCE")), $ListBuild(..#COPY, "OcuPilotProbeTwin", "422 " _ $Parameter(tE, "ITEMAMBIGUOUS")), $ListBuild(..#COPY, $Char(0), "422 " _ $Parameter(tE, "ITEMCOPYSOURCE")), $ListBuild(..#COPY, ..#NUMBERFROM, "422 PORT.FIELD.SHAPE") {
        Set tText = ..SaveCopy($List(tCase, 1), $List(tCase, 2), .tAnswer)
        Set tFromText = $Select($List(tCase, 2) = ..#NUMBERFROM: "a number", $List(tCase, 2) = $Char(0): "none", 1: "'" _ $List(tCase, 2) _ "'")
        Do $$$AssertEquals(tText, $List(tCase, 3), "a Save of '" _ $List(tCase, 1) _ "' from " _ tFromText _ " is refused: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tItems, "and writes nothing")
    }
    Set tText = ..SaveCopy(..#COPY, ..#SOURCE, .tAnswer, "OcuPilotProbe.No.Such")
    Do $$$AssertEquals(tText, "404 PORT.NOTFOUND", "a Save in a production the namespace does not hold is not found")
    ; The agent's mint judges the same rules.
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..CopyArgs("ocupilotprobeop", ..#SOURCE), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(tE, "ITEMTAKEN"), "the mint of a name held in another letter case is taken")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..CopyArgs(..#COPY, "OcuPilotProbeNone"), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 TOOL.ARGUMENTS", "and the mint of an absent source is refused as an argument")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() [ $Parameter(tE, "REASONITEMCOPYSOURCE")), "carrying the source sentence: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..CopyArgs(..#COPY, "OcuPilotProbeTwin"), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 TOOL.ARGUMENTS", "and the mint of a source held twice is refused as an argument")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() [ $Parameter(tE, "REASONITEMAMBIGUOUS")), "carrying the held-twice sentence: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tItems, "no mint wrote anything")
    ; A namespace that does not report interoperability: the Save over the wire, and the port.
    Set tBody = {"CopyFrom": (..#SOURCE)}
    Do tBody.%Set("Production", ..#PRODUCTION, "string")
    Do tBody.%Set("Name", ..#COPY, "string")
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/items/copy?ns=%25SYS"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json", .tExtra, 120)
    Set tWireCode = ""
    Try { Set tWireCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tWireCode = "" }
    Do $$$AssertEquals($Get(tStatus) _ " " _ tWireCode, "409 " _ $Parameter(tE, "NAMESPACE"), "the Save in %SYS is refused by the namespace: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tText = ..PortCopy(..#PORT, ..#COPY, ..#SOURCE, "%SYS")
    Do $$$AssertEquals(tText, "409 " _ $Parameter(tE, "NAMESPACE"), "the port refuses a namespace without interoperability")
}

/// <p>AC3: a name taken since the mint closes the proposal target-changed; and at the write itself, under the production's lock, the port
/// refuses a name held (<code>TAKEN</code>), a source the production no longer holds (<code>COPYSOURCE</code>) and a source it holds twice
/// (<code>AMBIGUOUS</code>) with 409 and stores nothing. The rules that run before the lock are set aside through the test seam for the
/// write-time rows.</p>
/// <p>Mutation (Rule 19): drop the <code>COPYSOURCE</code> refusal under the lock in
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the write-time source row goes red.</p>
Method TestAChangeSinceTheMintAndTheWritesOwnRefusalsStoreNothing()
{
    Set tE = ..#ERROR
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBaseline = $Parameter(..#CONTROL, "BASELINE")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..CopyArgs(..#COPY, ..#SOURCE), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the copy mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#COPY, $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "another item takes the name after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("code"), 1: tStatus), "409 PROPOSAL.TARGETCHANGED", "the confirm closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ "," _ ..#COPY _ ":0", "and only the other item is there")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the probe production is put back")
    Do $ClassMethod(..#SEAM, "SkipCopyRules")
    Set tGate = $ListBuild($ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE"))
    For tI = 1:1:$ListLength(tGate) {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tGate, tI), 1), $List($List(tGate, tI), 2))
    }
    Set tText = ..PortCopy(..#SEAM, "ocupilotprobeop", ..#SOURCE)
    Do $$$AssertEquals(tText, "409 " _ $Parameter(tE, "ITEMTAKEN"), "at the write a name held in any case is taken")
    Set tText = ..PortCopy(..#SEAM, ..#COPY, "OcuPilotProbeNone")
    Do $$$AssertEquals(tText, "409 " _ $Parameter(tE, "ITEMCOPYSOURCE"), "at the write a source the production does not hold is refused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "a twin item is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "and a second item of its name")
    Set tText = ..PortCopy(..#SEAM, ..#COPY, "OcuPilotProbeTwin")
    Do $$$AssertEquals(tText, "409 " _ $Parameter(tE, "ITEMAMBIGUOUS"), "at the write a source held twice is ambiguous")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ ",OcuPilotProbeTwin:0,OcuPilotProbeTwin:0", "none of them stored an item")
}

/// <p>AC3: a namespace under source control refuses a copy by <code>INTEROP.ITEM.SOURCECONTROL</code>, before anything is read, and the
/// port's copy needs WRITE on the routines database as every item write does.</p>
/// <p>Mutation (Rule 19): drop <code>COPY</code> from <method>OcuPilot.Port.InteropPort.IsItemWrite</method> -- the routines row goes red;
/// set <parameter>OcuPilot.Screen.Tool.InteropItemCopy.ROUTINESDATABASE</parameter> to 0 -- the tool-declaration row goes red.</p>
Method TestACopyNeedsTheRoutinesDatabaseAndIsRefusedUnderSourceControl()
{
    Set tE = ..#ERROR
    Set tSeam = ..#SEAM
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
    Do $ClassMethod(tSeam, "Arm", "%DB_OCUP2040ROUTINES")
    Set tText = ..PortCopy(tSeam, ..#COPY, ..#SOURCE)
    Do $$$AssertEquals(tText, "403 AUTH.NOPRIVILEGE", "a copy without the routines database's WRITE is refused for it")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_OCUP2040ROUTINES", "WRITE")
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Set tText = ..PortCopy(tSeam, ..#COPY, ..#SOURCE)
    Do $$$AssertEquals(tText, "409 " _ $Parameter(tE, "ITEMSOURCECONTROL"), "a copy in a namespace under source control is refused for it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE"), "and nothing was stored")
    ; The tool declares the same pairs as the add.
    Do $$$AssertEquals($Parameter(..#TOOL, "ROUTINESDATABASE") _ "|" _ $Parameter(..#TOOL, "DESTRUCTIVE") _ "|" _ $Parameter(..#TOOL, "WRITETYPE"), "1|0|COPY", "the copy tool writes the routines database too, is not destructive and is a COPY")
    Set tCopyPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tCopyResolved)
    Set tAddPairs = $ClassMethod("OcuPilot.Screen.Tool.InteropItemAdd", "PrivilegePairs", "", .tAddResolved)
    Do $$$AssertTrue(tCopyResolved && tAddResolved, "both tools' pairs resolve")
    Set tMissing = 0
    For tI = 1:1:$ListLength(tAddPairs) {
        If '$ListFind(tCopyPairs, $List(tAddPairs, tI)) Set tMissing = tMissing + 1
    }
    Do $$$AssertEquals(tMissing, 0, "and the copy declares every pair the add does")
}


/// <p>AD-10: the prohibited set admits a copy's own fields alone -- the source, and <code>Enabled</code> false -- and admits the source
/// name for no other write: a copy naming a class, or enabled, is refused <code>UNCOVEREDFIELD</code>, and so is an add naming a
/// source.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ItemCopied</method> admit every field -- the copy's
/// extra-field rows go red.</p>
Method TestTheProhibitedSetAdmitsOnlyTheCopysOwnFields()
{
    Set tDescriptor = "OcuPilot.Screen.Descriptor.InteropItemList"
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), $ClassMethod(..#CONTROL, "IdOf", ..#COPY), .tRef)
    Do $$$AssertStatusOK(tSC, "the new item's reference is built")
    Set tUncovered = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNCOVEREDFIELD")
    For tCase = $ListBuild("interop.items.copy", "{""CopyFrom"":""x"",""Enabled"":false,""Namespace"":""USER""}", ""), $ListBuild("interop.items.copy", "{""CopyFrom"":""x"",""Enabled"":false,""ClassName"":""OcuPilotProbe.Interop.Op"",""Namespace"":""USER""}", tUncovered), $ListBuild("interop.items.copy", "{""CopyFrom"":""x"",""Enabled"":true,""Namespace"":""USER""}", tUncovered), $ListBuild("interop.items.copy", "{""CopyFrom"":""x"",""Enabled"":false,""PoolSize"":3,""Namespace"":""USER""}", tUncovered), $ListBuild("interop.items.add", "{""ClassName"":""OcuPilotProbe.Interop.Op"",""CopyFrom"":""x"",""Enabled"":false,""Namespace"":""USER""}", tUncovered), $ListBuild("interop.items.add", "{""ClassName"":""OcuPilotProbe.Interop.Op"",""Enabled"":false,""Namespace"":""USER""}", "") {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($List(tCase, 1), tRef, $List(tCase, 2), "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the set is asked")
        Do $$$AssertEquals($Select(tProhibits: tCode, 1: ""), $List(tCase, 3), $List(tCase, 1) _ " carrying " _ $List(tCase, 2))
    }
}

}
