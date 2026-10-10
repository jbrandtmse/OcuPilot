/// <p>Pins Story 20.3's four item writes end to end against a probe production in <code>USER</code> (AD-6,
/// AD-7, AD-13, AD-15, AD-51, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62): the Production items list and its
/// read; the agent's disable, enable, add and remove minted, confirmed over HTTP, read back and ledgered;
/// the person's row actions and Save writing the same way; the change in the stored configuration, in the
/// production class after a recompile and in the vendor's audit trail; a write on a running production
/// starting and stopping no job, reading as an update pending, and applied by Story 20.2's Update; and each
/// tool's script.</p>
/// <p>The class methods other than the tests are shared by <class>OcuPilot.Test.InteropItemRefusals</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over
/// HTTP as <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code>
/// namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and
/// <b>runs a probe production in <code>USER</code></b>: <class>OcuPilot.Test.ProductionProbe</class> creates
/// the classes <code>OcuPilotProbe.Interop.*</code>, starts and stops the production and removes everything it
/// made after the last test. The agent's proposals are minted for the HTTP account, so the confirm over the
/// wire is that user's own. One class per run.</p>
Class OcuPilot.Test.InteropItemControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>Story 20.2's control test, whose probe production is this class's: the production's state, last start and
/// Productions row action are read through it.</p>
Parameter PRODUCTIONS = "OcuPilot.Test.InteropControl";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "/screens/interop.items";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter ADDED = "OcuPilotProbeAdded";

Parameter OPCLASS = "OcuPilotProbe.Interop.Op";

/// <p>A comment no audit row may carry: the audit names an operation and an item, never a value.</p>
Parameter COMMENT = "OcuPilotCommentMarker";

/// <p>The probe production's items before and after every test, <code>Name:Enabled</code>.</p>
Parameter BASELINE = "OcuPilotProbeOp:1,OcuPilotProbeSvc:1";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemControl compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals; a failing status when
/// <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemControl left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Reset()
}

/// <p>The probe is stopped and its items are as they began, its proposals removed, whether the test passed or
/// failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = ..Reset()
    Do $$$AssertStatusOK(tSC, "the probe production is left stopped with its items as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Stop the probe and put its items back as its class declares them when they differ. A probe whose
/// operation was removed cannot settle until its class is written again, so the reset comes first then.</p>
ClassMethod Reset() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If ..Items() = ..#BASELINE Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Settle")
    Quit tSC
}

/// <p>One request over the wire as the test account, scoped to <parameter>NAMESPACE</parameter>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer, Output pContentType As %String) As %Status
{
    Set pAnswer = ""
    Set pContentType = ""
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 120)
    Set pContentType = $Get(tHeaders("CONTENT-TYPE"))
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>The composite id of <var>pName</var> in the probe production, as the routes take it.</p>
ClassMethod IdOf(pName As %String) As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ pName
}

/// <p>One item row action on the Production items screen as <code>status code</code>, the answer in
/// <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pName As %String, Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", ..IdOf(pName), "string")
    Do ..Call("POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Save of an add as <code>status code</code>, the answer in <var>pAnswer</var>.
/// <var>pFields</var> carries the fields beside the production and the name.</p>
ClassMethod Save(pName As %String, pFields As %DynamicObject, Output pAnswer, Output pContentType As %String) As %String
{
    Set tBody = ##class(%DynamicObject).%FromJSON(pFields.%ToJSON())
    Do tBody.%Set("Production", ..#PRODUCTION, "string")
    Do tBody.%Set("Name", pName, "string")
    Do ..Call("POST", "/interop/items", tBody, .tStatus, .pAnswer, .pContentType)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The probe production's items as <code>Name:Enabled</code>, comma-separated in the production's order,
/// read through the port as the running account.</p>
ClassMethod Items() As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("production") = ..#PRODUCTION
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Items", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If '$IsObject($Get(tRows)) Quit "unread " _ $Get(tHttp)
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.Name _ ":" _ +tRow.Enabled
    }
    Quit tText
}

/// <p>The stored configuration's <code>Enabled</code> of every item named <var>pName</var> in the probe
/// production, comma-separated, <code>""</code> when none.</p>
ClassMethod StoredEnabled(pName As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Enabled FROM Ens_Config.Item WHERE Production = ? AND %EXACT(Name) = ?", ..#PRODUCTION, pName)
        While tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ +tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The <code>Enabled</code> attribute the production class's <code>ProductionDefinition</code> XData carries
/// for the item <var>pName</var>, <code>"absent"</code> when it names no such item.</p>
ClassMethod ClassEnabled(pName As %String) As %String
{
    Set tResult = "absent"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tDef = ##class(%Dictionary.XDataDefinition).%OpenId(..#PRODUCTION _ "||ProductionDefinition")
        Set tText = ""
        If $IsObject(tDef) Set tText = tDef.Data.Read(1000000)
        Set tPos = $Find(tText, "<Item Name=""" _ pName _ """")
        If tPos {
            Set tTag = $Extract(tText, tPos, $Find(tText, ">", tPos) - 1)
            Set tResult = $Piece($Piece(tTag, "Enabled=""", 2), """", 1)
        }
        Set tDef = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tResult = "unread " _ ex.DisplayString()
    }
    Quit tResult
}

/// <p>Compile the probe production's class again, which reloads the stored configuration from its XData.</p>
ClassMethod Recompile() As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(..#PRODUCTION, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe items' running jobs, the configuration names comma-separated and sorted.</p>
ClassMethod Jobs() As %String
{
    Kill tNames
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%ResultSet).%New("Ens.Job:Enumerate")
        Set tSC = tRS.Execute()
        While tRS.Next() {
            Set tName = tRS.Get("ConfigName")
            If $Extract(tName, 1, 13) = "OcuPilotProbe" Set tNames(tName) = ""
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Quit
    }
    Set tText = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tName
    }
    Quit tText
}

/// <p>The vendor's <code>ModifyConfiguration</code> audit rows since <var>pSince</var> that name the probe
/// production, each as <code>Description: EventData</code>, joined by <code>;</code>.</p>
ClassMethod Audited(pSince As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble' AND %NOINDEX EventType = '%Production' AND %NOINDEX Event = 'ModifyConfiguration' ORDER BY UTCTimeStamp", pSince)
        While tRS.%Next() {
            If tRS.%Get("Description") [ "OcuPilotProbe.Interop.Production" Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRS.%Get("Description") _ ": " _ tRS.%Get("EventData")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The agent's call of <var>pTool</var> (a class name) with <var>pArgs</var> -- the production, the name and
/// whatever fields the tool settles -- minted for <var>pUser</var> on a seeded turn.</p>
ClassMethod MintAs(pTool As %String, pArgs As %DynamicObject, pUser As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault, Output pTurn As %String) As %Status
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Do pArgs.%Set("rationale", "probe", "string")
    Do pArgs.%Set("expectedImpact", "probe", "string")
    Set tIdArgument = $ClassMethod(pTool, "IdArgument")
    Quit $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), pUser, "", pTurn, pArgs, $ClassMethod(pTool, "LimitsClass"), .pProposal, .pHttp, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pArgs.%Get(tIdArgument), tIdArgument, $ClassMethod(pTool, "SettableFields"), $ClassMethod(pTool, "ToolClass"))
}

/// <p>The arguments of a call naming the probe production and <var>pName</var>.</p>
ClassMethod ArgsFor(pName As %String) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Production", ..#PRODUCTION, "string")
    Do tArgs.%Set("Name", pName, "string")
    Quit tArgs
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as the HTTP test account, scoped to
/// <parameter>NAMESPACE</parameter>: the status, the raw body and the parsed answer (<code>""</code> when
/// the body is not one JSON document).</p>
ClassMethod ConfirmHttp(pProposalId As %String, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ pProposalId _ "/confirm?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, "", "application/json", .tExtra, 180)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(pRaw) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Name) = ?", pTurn, pTool)
    Quit $Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1)
}

/// <p>Mint <var>pTool</var> for <var>pArgs</var> as the HTTP account and confirm it over HTTP: the card's one
/// <code>Enabled</code> row (<var>pBefore</var> to <var>pAfter</var>), the consequence code, the single envelope
/// the confirm answers, its ledger row, and the vendor's audit row since the mint. Answers the audit text
/// in <var>pAudit</var>.</p>
Method Through(pTool As %String, pArgs As %DynamicObject, pBefore As %String, pAfter As %String, pConsequence As %String, Output pAudit As %String)
{
    Set tName = $Parameter(pTool, "TOOLNAME")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..MintAs(pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""Enabled"",""before"":""" _ pBefore _ """,""after"":""" _ pAfter _ """}]", tName _ ": its card shows one Enabled row, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item|USER|" _ ..#PRODUCTION _ "~" _ pArgs.Name, tName _ ": the target is the item, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), pConsequence, tName _ ": its consequence code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, tName _ ": it is not destructive")
    Set tSC = ..ConfirmHttp(tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", tName _ ": updated and marked (AD-15)")
    Do $$$AssertEquals(..LedgerCount(tTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set pAudit = ..Audited(tSince)
}

/// <p>AC1: the Production items screen lists the probe production's two items with the fields the matrix
/// names, an unknown production is 404 <code>PORT.NOTFOUND</code>, and a read with no production is 400
/// <code>READ.CRITERION</code>.</p>
/// <p>Mutation (Rule 19): drop <code>SeedCriteria</code> from the <code>interop</code> branch of
/// <method>OcuPilot.Screen.Read.Execute</method> -- the list leg goes red.</p>
Method TestTheListAnswersTheProbesItems()
{
    Do ..Call("GET", ..#SCREEN _ "/read?production=" _ ..#PRODUCTION _ "&maxRows=100", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the list answers")
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("rows")) Quit
    Set tText = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Name _ "=" _ tRow.Type _ "|" _ +tRow.Enabled _ "|" _ tRow.EnabledSource _ "|" _ tRow.PoolSize _ "|" _ tRow.ClassName
    }
    Do $$$AssertEquals(tText, "OcuPilotProbeOp=operation|1|production|1|OcuPilotProbe.Interop.Op;OcuPilotProbeSvc=service|1|production|0|OcuPilotProbe.Interop.Svc", "its two items, with their type, enabled flag and source, pool size and class")
    Do ..Call("GET", ..#SCREEN _ "/read?production=OcuPilotProbe.No.Such&maxRows=100", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "404 PORT.NOTFOUND", "an unknown production is not found")
    Do ..Call("GET", ..#SCREEN _ "/read?maxRows=100", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 READ.CRITERION", "and a read naming none is refused for it")
}

/// <p>AC2: the agent's disable and enable of the probe's operation, each minted for the HTTP account and
/// confirmed over HTTP, store the change, carry it into the production class (surviving a recompile), answer
/// one envelope, are ledgered once and are audited by name; the cards say the change waits for an
/// update.</p>
/// <p>Mutation (Rule 19): pass <code>1</code> as <code>EnableConfigItem</code>'s third argument in
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the update would be applied by the vendor,
/// and the running-production test goes red.</p>
Method TestTheAgentsDisableAndEnableConfirmOverHttp()
{
    Do ..Through("OcuPilot.Screen.Tool.InteropItemDisable", ..ArgsFor(..#OPNAME), "true", "false", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..StoredEnabled(..#OPNAME), "0", "the stored item reads disabled")
    Do $$$AssertEquals(..ClassEnabled(..#OPNAME), "false", "the production class carries it")
    Do $$$AssertStatusOK(..Recompile(), "the class compiles again")
    Do $$$AssertEquals(..Items(), "OcuPilotProbeOp:0,OcuPilotProbeSvc:1", "and the compile does not revert it")
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeOp of OcuPilotProbe.Interop.Production") && (tAudit [ "disabled"), "the vendor's audit trail names the item: " _ tAudit)
    Do ..Through("OcuPilot.Screen.Tool.InteropItemEnable", ..ArgsFor(..#OPNAME), "false", "true", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeOp of OcuPilotProbe.Interop.Production") && (tAudit [ "enabled"), "the vendor's audit trail names the item for the enable: " _ tAudit)
    Do $$$AssertEquals(..StoredEnabled(..#OPNAME) _ "|" _ ..ClassEnabled(..#OPNAME), "1|true", "the enable is stored and carried into the class")
    Do $$$AssertEquals(..Items(), ..#BASELINE, "and the items are as they began")
}

/// <p>AC2: the agent's add of a disabled item and its remove (a destructive write, off in the governance
/// baseline) are minted and confirmed over HTTP: the add is stored, carried into the class and audited by
/// name with no field value; the remove is refused while its governance key is off, and with the key on
/// deletes the item from the configuration and the class, audited by name with no field value. Both
/// confirms are marked (AD-15).</p>
/// <p>Mutation (Rule 19): drop <code>SaveToClass</code> from the add branch of
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the class leg of the add goes red; drop the
/// <code>AuditModifyProductionConfig</code> call from its remove branch -- the remove's marker and audit
/// legs go red.</p>
Method TestTheAgentsAddAndRemoveConfirmOverHttp()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tArgs = ..ArgsFor(..#ADDED)
    Do tArgs.%Set("ClassName", ..#OPCLASS, "string")
    Do tArgs.%Set("PoolSize", 2, "number")
    Do tArgs.%Set("Enabled", 0, "boolean")
    Do tArgs.%Set("Category", "Probe", "string")
    Do tArgs.%Set("Comment", ..#COMMENT, "string")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..MintAs("OcuPilot.Screen.Tool.InteropItemAdd", tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "INTEROP.ITEM.PENDING", "its consequence says a running production needs an update")
    Set tSC = ..ConfirmHttp(tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Items(), ..#BASELINE _ ",OcuPilotProbeAdded:0", "the item is added, disabled")
    Do $$$AssertEquals(..StoredEnabled(..#ADDED) _ "|" _ ..ClassEnabled(..#ADDED), "0|false", "stored, and carried into the class")
    Do $$$AssertStatusOK(..Recompile(), "the class compiles again")
    Do $$$AssertEquals(..Items(), ..#BASELINE _ ",OcuPilotProbeAdded:0", "and the compile keeps it")
    Set tAudit = ..Audited(tSince)
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeAdded of OcuPilotProbe.Interop.Production") && (tAudit '[ ..#COMMENT), "the vendor's audit trail names the item and carries no field value: " _ tAudit)
    ; The remove: its key is off in the baseline.
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Set tSC = ..MintAs("OcuPilot.Screen.Tool.InteropItemRemove", ..ArgsFor(..#ADDED), tUser, .tRemove, .tHttp, .tFault, .tRemoveTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tRemove)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.ITEM.REMOVE|1", "its consequence says the item and its settings go, and it is destructive")
        Set tSC = ..ConfirmHttp(tRemove.proposalId, .tStatus, .tRaw, .tAnswer)
        Do $$$AssertNotEquals(tStatus, 200, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..Items(), ..#BASELINE _ ",OcuPilotProbeAdded:0", "and the item is still there")
        Kill tSettings
        Set tSettings("interop.items.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Set tRemoveSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tSC = ..ConfirmHttp(tRemove.proposalId, .tStatus, .tRaw, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the remove's confirm answers exactly one envelope")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, 1: ""), "1|deleted", "as a deletion, marked (AD-15)")
        Set tRemoveAudit = ..Audited(tRemoveSince)
        Do $$$AssertTrue((tRemoveAudit [ "item OcuPilotProbeAdded of OcuPilotProbe.Interop.Production") && (tRemoveAudit [ "removed") && (tRemoveAudit '[ ..#COMMENT), "the vendor's audit trail names the removed item and carries no field value: " _ tRemoveAudit)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRemoveTurn))
    Do $$$AssertEquals(..Items(), ..#BASELINE, "the item is gone from the configuration")
    Do $$$AssertEquals(..StoredEnabled(..#ADDED) _ "|" _ ..ClassEnabled(..#ADDED), "|absent", "and from the class")
}

/// <p>AC2: the person's row actions and Save write the same way: Disable and Enable answer 200 with the
/// <code>updated</code> event for the item, a Save answers 201 with the item's id and read-back, and Remove
/// answers 200 with <code>deleted</code>; each lands in the stored configuration and the class, and the
/// add and the remove are audited by name with no field value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.Create</method> skip the port's
/// add -- the Save leg goes red; drop the <code>AuditModifyProductionConfig</code> call from the remove
/// branch of <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the audit leg goes red.</p>
Method TestThePersonsRowActionsAndSaveWriteTheSameWay()
{
    Set tText = ..Act("disable", ..#OPNAME, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Disable answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ $Translate(tAnswer.target.id, $Char(1), "~"), 1: ""), "updated|production-item|" _ ..#PRODUCTION _ "~" _ ..#OPNAME, "publishing the updated event for the item")
    Do $$$AssertEquals(..StoredEnabled(..#OPNAME) _ "|" _ ..ClassEnabled(..#OPNAME), "0|false", "stored and carried into the class")
    Do $$$AssertEquals(..Act("enable", ..#OPNAME, .tAnswer), "200 ", "Enable answers 200")
    Do $$$AssertEquals(..StoredEnabled(..#OPNAME) _ "|" _ ..ClassEnabled(..#OPNAME), "1|true", "and stores the enable")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
    Do tFields.%Set("Comment", ..#COMMENT, "string")
    Set tText = ..Save(..#ADDED, tFields, .tAnswer, .tContentType)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue(tContentType [ "application/json", "as application/json: " _ tContentType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): $Translate(tAnswer.id, $Char(1), "~") _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#PRODUCTION _ "~" _ ..#ADDED _ "|production-item|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the item's id and a read-back that matches: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..StoredEnabled(..#ADDED) _ "|" _ ..ClassEnabled(..#ADDED), "0|false", "the added item is stored and carried into the class")
    Do $$$AssertEquals(..Act("remove", ..#ADDED, .tAnswer), "200 ", "Remove answers 200")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action, 1: ""), "deleted", "as a deletion")
    Do $$$AssertEquals(..StoredEnabled(..#ADDED) _ "|" _ ..ClassEnabled(..#ADDED), "|absent", "and the item is gone from the configuration and the class")
    Set tAudit = ..Audited(tSince)
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeAdded of OcuPilotProbe.Interop.Production") && (tAudit [ "added") && (tAudit [ "removed") && (tAudit '[ ..#COMMENT), "the vendor's audit trail names the added and the removed item and carries no field value: " _ tAudit)
    Do $$$AssertEquals(..Items(), ..#BASELINE, "leaving the items as they began")
}

/// <p>AC5: on a running production a disable and an enabled add start and stop no job and read as an update
/// pending, and Story 20.2's Update then stops the disabled item's job, starts the added one's and leaves the
/// production up to date.</p>
/// <p>Mutation (Rule 19): pass <code>1</code> as <code>EnableConfigItem</code>'s third argument in
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the job leg goes red.</p>
Method TestAWriteOnARunningProductionChangesNoJobAndTheUpdateAppliesIt()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the probe is started")
    Hang 3
    Do $$$AssertEquals(..Jobs(), "OcuPilotProbeOp", "the operation has its job")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "and nothing is pending")
    Set tStarted = $ClassMethod(..#PRODUCTIONS, "LastStart")
    Do $$$AssertEquals(..Act("disable", ..#OPNAME, .tAnswer), "200 ", "Disable answers 200")
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": true}
    Do $$$AssertEquals(..Save(..#ADDED, tFields, .tAnswer), "201 ", "an enabled add is saved")
    Hang 2
    Do $$$AssertEquals(..Jobs(), "OcuPilotProbeOp", "no job started or stopped")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "LastStart"), tStarted, "and the production was not started again")
    For tTry = 1:1:10 {
        If $Piece($ClassMethod(..#PRODUCTIONS, "State"), "|", 2) Quit
        Hang 0.5
    }
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "the production reads as needing an update")
    Do $$$AssertEquals(..Items(), "OcuPilotProbeOp:0,OcuPilotProbeSvc:1,OcuPilotProbeAdded:1", "while the configuration already holds both changes")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(##class(OcuPilot.Test.Http).GetTestUsername(), "completed", .tTurn)
    Set tText = $ClassMethod(..#PRODUCTIONS, "Act", "update", ..#PRODUCTION)
    Do $$$AssertEquals(tText, "200 ", "the Productions screen's Update answers 200")
    Do $$$AssertEquals(..Jobs(), "OcuPilotProbeAdded", "the disabled item's job stopped and the added item's started")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "and the production reads up to date")
}

/// <p>AD-59: each tool's copy-out draft renders one ObjectScript step that switches to the namespace the
/// proposal read, calls the vendor for its action, saves the production class, closes the proposal as a draft
/// and changes nothing, and none names <code>CleanProduction</code> or <code>UpdateProduction</code>.</p>
Method TestEachToolsDraftRendersItsScript()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeDraft", ..#OPCLASS, 1, 0), "a disabled item is added to the stored configuration for the enable and the remove")
    Set tAdd = ..ArgsFor(..#ADDED)
    Do tAdd.%Set("ClassName", ..#OPCLASS, "string")
    For tCase = $ListBuild("InteropItemDisable", ..#OPNAME, "EnableConfigItem(", ", 0, 0)"), $ListBuild("InteropItemEnable", "OcuPilotProbeDraft", "EnableConfigItem(", ", 1, 0)"), $ListBuild("InteropItemAdd", ..#ADDED, "Ens.Config.Item", "Items.Insert(tItem)"), $ListBuild("InteropItemRemove", "OcuPilotProbeDraft", "RemoveItem(", "FindItemByConfigName(") {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Set tArgs = $Select($List(tCase, 1) = "InteropItemAdd": tAdd, 1: ..ArgsFor($List(tCase, 2)))
        Set tSC = ..MintAs(tTool, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, tUser, "https://draft.example:52773", .tDraft, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tDraft)) Continue
        Set tText = tDraft.draft.steps.%Get(0).text
        Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", $Parameter(tTool, "TOOLNAME") _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 3)) && (tText [ $List(tCase, 4)) && (tText [ "SaveToClass(") && (tText '[ "CleanProduction") && (tText '[ "UpdateProduction"), $Parameter(tTool, "TOOLNAME") _ ": " _ tText)
    }
    Do $$$AssertEquals(..Items(), "OcuPilotProbeOp:1,OcuPilotProbeSvc:1,OcuPilotProbeDraft:0", "no draft changed an item")
}

}
