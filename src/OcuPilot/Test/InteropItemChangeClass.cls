/// <p>Pins Story 20.41's item change of class end to end against a probe production in <code>USER</code> (AD-6, AD-10, AD-15, AD-22,
/// AD-35, AD-51, AD-53, AD-58, AD-59, AD-62): the agent's change minted, confirmed over HTTP, read back and ledgered; the person's dry
/// run and the action that carries its digest; the class, the settings it drops and the settings it keeps; the card's removed rows and
/// the value a credential-named setting never shows; the vendor's audit trail; the class through a recompile; a running production
/// reading update pending and nothing else; and the change's script. Its refusals are
/// <class>OcuPilot.Test.InteropItemChangeClassRefusals</class>', the Classes tab's <class>OcuPilot.Test.InteropItemClasses</class>', and
/// the principals' legs <class>OcuPilot.Test.InteropItemGate</class>'.</p>
/// <p>It uses <class>OcuPilot.Test.InteropItemControl</class>'s class methods. <b>What it needs from the environment:</b> OcuPilot
/// installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// compiles and runs a probe production in <code>USER</code>. One class per run.</p>
Class OcuPilot.Test.InteropItemChangeClass Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemChangeClass";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter SCREEN = "/screens/interop.items";

/// <p>The probe item every change here changes: an operation holding a Host setting the new class does not take, a credential-named
/// one, and one it takes.</p>
Parameter ITEM = "OcuPilotProbeChg";

Parameter OLDCLASS = "OcuPilotProbe.Interop.Op";

Parameter NEWCLASS = "OcuPilotProbe.Interop.TearOp";

/// <p>The two values no surface may show beyond the one that is not a secret: the dropped plain setting's, which the card lists, and the
/// credential-named one's, which nothing does.</p>
Parameter HANGVALUE = "4471";

Parameter SECRETVALUE = "s3cretProbeValue";

/// <p>What <method>Prepare</method> stores.</p>
Parameter STORED = "OcuPilotProbe.Interop.Op|Host.HangSeconds=4471,Host.ApiToken=s3cretProbeValue,Host.TearDownSeconds=7";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemChangeClass compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes and its proposals; a failing status when <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemChangeClass left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The probe's items are asserted as they began and put back when they are not, and its proposals are removed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    Do $$$AssertStatusOK(tSC, "the probe production is left stopped with its items and settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Store the probe item <var>pName</var>, disabled, of <parameter>OLDCLASS</parameter> with the three Host settings the changes here
/// judge: <code>HangSeconds</code> (the class declares it, the new class does not), <code>ApiToken</code> (the same, and named like a
/// credential) and <code>TearDownSeconds</code> (the new class declares it). <var>pPlainOnly</var> stores the last alone.</p>
ClassMethod Prepare(pName As %String = {..#ITEM}, pPlainOnly As %Boolean = 0) As %Status
{
    If pPlainOnly Quit $ClassMethod(..#PROBE, "AddItem", pName, ..#OLDCLASS, 1, 0, "TearDownSeconds", "7", "Host")
    Set tSC = $ClassMethod(..#PROBE, "AddItem", pName, ..#OLDCLASS, 1, 0, "HangSeconds", ..#HANGVALUE, "Host")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "PutItemSetting", pName, "Host", "ApiToken", ..#SECRETVALUE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "PutItemSetting", pName, "Host", "TearDownSeconds", "7")
    Quit tSC
}

/// <p>The stored class of the item <var>pName</var> and the settings it holds, <code>class|Target.Name=Value,...</code>, or
/// <code>absent</code>.</p>
ClassMethod Stored(pName As %String = {..#ITEM}) As %String
{
    Set tText = "absent"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
        Set tItem = tProduction.FindItemByConfigName(pName)
        If $IsObject(tItem) {
            Set tList = ""
            For tI = 1:1:tItem.Settings.Count() {
                Set tSetting = tItem.Settings.GetAt(tI)
                Set tList = tList _ $Select(tList = "": "", 1: ",") _ tSetting.Target _ "." _ tSetting.Name _ "=" _ tSetting.Value
            }
            Set tText = tItem.ClassName _ "|" _ tList
        }
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>Turn the governance key of the change on, remembering the policy in <var>pPolicy</var> for <method>KeyRestore</method>.</p>
ClassMethod KeyOn(Output pPolicy) As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.pPolicy)
    If $$$ISERR(tSC) Quit tSC
    Set tSettings($Parameter(..#TOOL, "TOOLNAME")) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Put back the policy <method>KeyOn</method> found.</p>
ClassMethod KeyRestore(ByRef pPolicy) As %Status
{
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.pPolicy)
}

/// <p>What proposal <var>pKey</var> keeps of the change in its arguments, payload and diff streams, as one text.</p>
ClassMethod StoredText(pKey As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If tRS.%Next() {
        Set tProposal = ##class(OcuPilot.Kernel.State.Propose).%OpenId(tRS.%GetData(1))
        If $IsObject(tProposal) {
            For tName = "Arguments", "Payload", "Diff" {
                Set tStream = $Property(tProposal, tName)
                Do tStream.Rewind()
                Set tText = tText _ "|" _ tStream.Read(3000000)
            }
        }
    }
    Quit tText
}

/// <p>The agent's arguments for changing the class of <var>pName</var> to <var>pClass</var>.</p>
ClassMethod ChangeArgs(pName As %String, pClass As %String) As %DynamicObject
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", pName)
    Do tArgs.%Set("NewClass", pClass, "string")
    Quit tArgs
}

/// <p>The port's <code>CHANGECLASS</code> of <var>pName</var> to <var>pClass</var> as <code>status code</code>, with the digest
/// <var>pDigest</var> when it is not empty.</p>
ClassMethod PortChange(pPort As %String, pName As %String, pClass As %String, pDigest As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tQuery("newClass") = pClass
    If pDigest '= "" Set tQuery("digest") = pDigest
    Set tSC = $ClassMethod(pPort, "Invoke", "Items", "CHANGECLASS", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The port's <code>ITEM</code> read of <var>pName</var> composed for the change to <var>pClass</var>, as the object it answers (or
/// <code>""</code>); the status and code in <var>pText</var>.</p>
ClassMethod Dry(pName As %String, pClass As %String, Output pText As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tQuery("newClass") = pClass
    Set tQuery("action") = "CHANGECLASS"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Items", "ITEM", .tQuery, "", .tResult, .tHttp, .tFault)
    Set pText = +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(tResult)): tResult, 1: "")
}

/// <p>The names of the Host and Adapter settings the Item settings read of <var>pName</var> answers a stored value for,
/// <code>Target.Name</code>, comma-separated, in the order read: a setting the item holds in its stored production configuration.</p>
ClassMethod HeldSettings(pName As %String = {..#ITEM}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("item") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If '$IsObject($Get(tRows)) Quit "unread " _ $Get(tHttp)
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.Source = "production") && (tRow.Target '= "Core") Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.Target _ "." _ tRow.Name
    }
    Quit tText
}

/// <p>AC1, AC4: the agent's change of the probe item to <parameter>NEWCLASS</parameter>, minted for the HTTP account and confirmed over
/// HTTP, sets the class, removes the settings the new class does not take and keeps the one it does, and its card lists the class
/// change and each dropped setting as a removed row, the credential-named one with no value; it is destructive, states its consequence,
/// is marked (AD-15) and ledgered once, reads back as nothing sent, survives a recompile of the production class, and is audited by
/// the vendor's event naming the item and each dropped setting and no value.</p>
/// <p>Mutation (Rule 19): drop <code>SaveToClass</code> from <method>OcuPilot.Port.InteropPort.ChangeStep</method> -- the recompile leg
/// goes red; make <method>OcuPilot.Port.InteropPort.DroppedSettings</method> keep every setting -- the removed-row and stored-settings legs go
/// red.</p>
Method TestTheAgentsChangeOfClassConfirmsOverHttp()
{
    Do $$$AssertStatusOK(..Prepare(), "the probe item and its three settings are stored")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..ChangeArgs(..#ITEM, ..#NEWCLASS), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the change mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = tProposal.changed
    Do $$$AssertEquals(tRows.%Size(), 3, "its card shows the class and the two settings that go: " _ tRows.%ToJSON())
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.field _ "|" _ tRow.before _ "|" _ tRow.after, "ClassName|" _ ..#OLDCLASS _ "|" _ ..#NEWCLASS, "the first row is the class, from the old to the new")
    Set tRow = tRows.%Get(1)
    Do $$$AssertEquals(tRow.field _ "|" _ tRow.before _ "|" _ tRow.after _ "|" _ tRow.%Get("removed"), "Host.HangSeconds|" _ ..#HANGVALUE _ "||1", "the plain dropped setting is a removed row showing its value")
    Set tRow = tRows.%Get(2)
    Do $$$AssertEquals(tRow.field _ "|" _ tRow.before _ "|" _ tRow.after _ "|" _ tRow.%Get("removed"), "Host.ApiToken|||1", "the credential-named one is a removed row with no value")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item|USER|" _ ..#PRODUCTION _ "~" _ ..#ITEM, "the target is the item, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.ITEM.CHANGECLASS|1", "it is destructive and states its consequence")
    Set tStored = ..StoredText(tProposal.proposalId)
    Do $$$AssertTrue((tStored [ ..#HANGVALUE) && (tStored '[ ..#SECRETVALUE), "the stored payload and diff carry the plain value and never the credential's")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("code"), 1: tStatus), "403 GOVERNANCE.DISABLED", "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Stored(), ..#STORED, "and the item is as it was")
    Set tSC = ..KeyOn(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the key is turned on")
    Try {
        Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the confirm raised")
    }
    Do $$$AssertStatusOK(..KeyRestore(.tPolicy), "the policy found before the test is put back")
    Do $$$AssertEquals(tStatus, 200, "the change then confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "updated and marked (AD-15), and read back as nothing sent")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, $Parameter(..#TOOL, "TOOLNAME")), 1, "the confirmed write is in the ledger once")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Arguments, Fields, Target, Route, Code FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurn)
    Set tLedger = $Select(tRS.%SQLCODE < 0: "sql " _ tRS.%Message, 1: "")
    While tRS.%Next() {
        Set tLedger = tLedger _ "|" _ tRS.%Get("Arguments") _ "|" _ tRS.%Get("Fields") _ "|" _ tRS.%Get("Target") _ "|" _ tRS.%Get("Route") _ "|" _ tRS.%Get("Code")
    }
    Do $$$AssertTrue((tLedger '= "") && (tLedger '[ ..#SECRETVALUE) && (tLedger '[ ..#HANGVALUE), "the ledger row carries no setting's value: " _ tLedger)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Stored(), ..#NEWCLASS _ "|Host.TearDownSeconds=7", "the item reads the new class, without the settings it does not take and with the one it does")
    Do $$$AssertEquals(..HeldSettings(), "Host.TearDownSeconds", "and its Item settings read holds no production value for either dropped setting (AC2): " _ ..HeldSettings())
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the production class compiles again")
    Do $$$AssertEquals(..Stored(), ..#NEWCLASS _ "|Host.TearDownSeconds=7", "and the compile keeps the change")
    Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
    Do $$$AssertTrue((tAudit [ ("item " _ ..#ITEM _ " of " _ ..#PRODUCTION)) && (tAudit [ ("item class changed by OcuPilot from " _ ..#OLDCLASS _ " to " _ ..#NEWCLASS)) && ($Length(tAudit, "item class changed") = 2), "the vendor's audit trail holds one change row naming the item and both classes: " _ tAudit)
    Do $$$AssertTrue((tAudit [ "Host.HangSeconds") && (tAudit [ "Host.ApiToken") && (tAudit '[ ..#HANGVALUE) && (tAudit '[ ..#SECRETVALUE), "naming each dropped setting and no value: " _ tAudit)
}

/// <p>AC1: the person's dry run lists the same rows and answers the digest of what it listed, and the action that carries that digest
/// changes the class, and the vendor's audit holds the one change row; the secret setting's row shows no value in the dry run either; the
/// port's composed read answers the dropped settings with <code>Secret</code> and a digest that does not depend on the credential's value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemChangeClass.ScreenActionDelta</method> leave out <code>Reviewed</code>
/// -- the stale-digest leg of <class>OcuPilot.Test.InteropItemChangeClassRefusals</class> goes red; add the credential's value to
/// <method>OcuPilot.Port.InteropPort.ChangeDigest</method> -- the digest leg goes red.</p>
Method TestThePersonsDryRunThenActionChangesTheClass()
{
    Do $$$AssertStatusOK(..Prepare(), "the probe item and its three settings are stored")
    Set tId = $ClassMethod(..#CONTROL, "IdOf", ..#ITEM)
    Set tBody = {"action": "changeclass", "values": {"NewClass": (..#NEWCLASS)}}
    Do tBody.%Set("id", tId, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/dryrun", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the dry run answers: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If '$IsObject(tAnswer) Quit
    Set tDigest = $Select($IsObject(tAnswer.%Get("review")): tAnswer.review.%Get("Digest"), 1: "")
    Do $$$AssertTrue($Match(tDigest, "^[0-9a-f]{64}$"), "it answers the digest of the review: " _ tDigest)
    Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("rows") = "array": tAnswer.rows.%Size(), 1: -1) _ "|" _ tAnswer.rows.%Get(1).field _ "|" _ tAnswer.rows.%Get(2).field _ "|" _ tAnswer.rows.%Get(2).before, "3|Host.HangSeconds|Host.ApiToken|", "its rows are the class and the two dropped settings, the credential's with no value")
    Do $$$AssertTrue($ZConvert(tAnswer.%ToJSON(), "L") '[ $ZConvert(..#SECRETVALUE, "L"), "and nothing of the credential's value")
    Set tRead = ..Dry(..#ITEM, ..#NEWCLASS, .tText)
    Do $$$AssertEquals(tText _ "|" _ tRead.Digest, "200 |" _ tDigest, "the port's composed read answers the same digest")
    Do $$$AssertEquals(tRead.Dropped.%Get(1).Secret _ "|" _ tRead.Dropped.%Get(1).Value, "1|", "and the credential-named setting is flagged Secret with an empty value")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Host", "ApiToken", "another" _ ..#SECRETVALUE), "the credential's value changes")
    Set tAgain = ..Dry(..#ITEM, ..#NEWCLASS, .tText)
    Do $$$AssertEquals(tAgain.Digest, tDigest, "which does not move the digest")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tAction = {"action": "changeclass", "values": {"NewClass": (..#NEWCLASS), "Reviewed": (tDigest)}}
    Do tAction.%Set("id", tId, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tAction, .tStatus, .tDone)
    Do $$$AssertEquals(tStatus, 200, "the action that carries the digest is applied: " _ $Select($IsObject(tDone): $Extract(tDone.%ToJSON(), 1, 300), 1: tDone))
    Do $$$AssertEquals(..Stored(), ..#NEWCLASS _ "|Host.TearDownSeconds=7", "the item reads the new class and the setting it takes")
    Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
    Do $$$AssertTrue((tAudit [ ("item class changed by OcuPilot from " _ ..#OLDCLASS _ " to " _ ..#NEWCLASS)) && ($Length(tAudit, "item class changed") = 2), "the vendor's audit holds one change row: " _ tAudit)
}

/// <p>AC1: the vendor's drop rule is applied per target and per value: a Host setting the new class declares but whose stored value it
/// does not accept, an Adapter setting (the new class has no adapter) and a setting of any other target are each a removed row, and the
/// change removes them; the setting the new class declares and accepts stays.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DroppedSettings</method> ignore the status of the Host
/// <code>IsValid</code> call -- the invalid-value row goes red; keep every setting that is not a Host setting -- the adapter and other-target
/// rows go red.</p>
Method TestTheDropRuleIsAppliedPerTargetAndPerValue()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#ITEM, ..#OLDCLASS, 1, 0, "TearDownSeconds", "not a number", "Host"), "an item holding a Host setting the new class declares with a value it rejects is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Adapter", "ProbeAdapterSetting", "1"), "an Adapter setting is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Other", "ProbeOtherSetting", "2"), "and a setting of another target")
    Set tRead = ..Dry(..#ITEM, ..#NEWCLASS, .tText)
    Do $$$AssertEquals(tText, "200 ", "the composed read is answered")
    Set tFields = ""
    Set tIterator = tRead.Dropped.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tRow.Target _ "." _ tRow.Name
    }
    Do $$$AssertEquals(tFields, "Host.TearDownSeconds,Adapter.ProbeAdapterSetting,Other.ProbeOtherSetting", "each is a dropped setting")
    Do $$$AssertEquals(..PortChange(..#PORT, ..#ITEM, ..#NEWCLASS, tRead.Digest), "200 ", "and the change reviewed at that digest is applied")
    Do $$$AssertEquals(..Stored(), ..#NEWCLASS _ "|", "the item holds none of them")
    Do $$$AssertEquals(..HeldSettings(), "", "(AC2) its Item settings tab holds no production value for the dropped setting the new class declares")
}

/// <p>AC1, AC2: between two operation classes on the same adapter (<code>EnsLib.File.OutboundAdapter</code>), an Adapter setting the
/// adapter declares and accepts is kept and one whose stored value it rejects is dropped, and the Item settings tab then holds the kept
/// one alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DroppedSettings</method> remove every Adapter setting -- the dropped list,
/// the stored settings and the tab go red.</p>
Method TestAnAdapterSettingTheSharedAdapterTakesIsKept()
{
    Set tName = "OcuPilotProbeChgFile"
    Set tNew = "EnsLib.HL7.Operation.FileOperation"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddFileItem", tName, "EnsLib.File.PassthroughOperation", "/tmp/ocupilot-probe-chg"), "a file operation holding its adapter's FilePath is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", tName, "Adapter", "Overwrite", "maybe"), "and its adapter's Overwrite at a value the adapter rejects")
    Set tRead = ..Dry(tName, tNew, .tText)
    Do $$$AssertEquals(tText, "200 ", "the composed read of the change to another class on the same adapter is answered")
    If '$IsObject(tRead) Quit
    Set tFields = ""
    Set tIterator = tRead.Dropped.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tRow.Target _ "." _ tRow.Name
    }
    Do $$$AssertEquals(tFields, "Adapter.Overwrite", "only the rejected Adapter setting is a dropped setting")
    Do $$$AssertEquals(..PortChange(..#PORT, tName, tNew, tRead.Digest), "200 ", "the change reviewed at that digest is applied")
    Do $$$AssertEquals(..Stored(tName), tNew _ "|Adapter.FilePath=/tmp/ocupilot-probe-chg", "the item keeps the Adapter setting its adapter takes")
    Do $$$AssertEquals(..HeldSettings(tName), "Adapter.FilePath", "(AC2) and its Item settings tab holds that one alone")
}

/// <p>AC1: a change that drops nothing is still a destructive card with the class row alone, and its confirm keeps every setting; an
/// item whose class is not compiled takes any of the three kinds, so its change to the operation class is applied.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemChangeClass.StateDiff</method> push no <code>ClassName</code> row --
/// the card leg goes red.</p>
Method TestAChangeThatDropsNothingAndAnItemOfAnUnknownKind()
{
    Do $$$AssertStatusOK(..Prepare(, 1), "an item holding only the setting the new class takes is stored")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..ChangeArgs(..#ITEM, ..#NEWCLASS), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the change mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).field, "1|ClassName", "its card is the class row alone")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 1, "and still draws the destructive treatment")
    Set tSC = ..KeyOn(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the key is turned on")
    Try {
        Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the confirm raised")
    }
    Do $$$AssertStatusOK(..KeyRestore(.tPolicy), "the policy found before the test is put back")
    Do $$$AssertEquals(tStatus, 200, "it confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Stored(), ..#NEWCLASS _ "|Host.TearDownSeconds=7", "the class changed and the setting stayed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeUnknown", "OcuPilotProbe.No.Such.Class", 1, 0), "an item whose class is not compiled is stored")
    Do $$$AssertEquals(..PortChange(..#PORT, "OcuPilotProbeUnknown", ..#OLDCLASS), "200 ", "its change to an operation class is applied")
    Do $$$AssertEquals($Piece(..Stored("OcuPilotProbeUnknown"), "|", 1), ..#OLDCLASS, "and it reads the operation class")
}

/// <p>AC1: the change on a running production starts and stops no job and does not start the production again, and the production reads as
/// needing an update, as after an add; a class the item's kind takes is changed on a disabled item whose production runs.</p>
/// <p>Mutation (Rule 19): call <code>Ens.Director.UpdateProduction</code> after the save in <method>OcuPilot.Port.InteropPort.ChangeStep</method>
/// -- the production-state leg goes red.</p>
Method TestAChangeOnARunningProductionChangesNoJob()
{
    Set tProductions = "OcuPilot.Test.InteropControl"
    Do $$$AssertStatusOK(..Prepare(), "the probe item is stored")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "StartProduction"), "the probe production is started")
    Set tJobs = $ClassMethod(..#CONTROL, "Jobs")
    Set tStarted = $ClassMethod(tProductions, "LastStart")
    Do $$$AssertEquals($ClassMethod(tProductions, "State"), "Running|0", "and nothing is pending")
    Do $$$AssertEquals(..PortChange(..#PORT, ..#ITEM, ..#NEWCLASS), "200 ", "the change is applied")
    Hang 2
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Jobs"), tJobs, "no job started or stopped")
    Do $$$AssertEquals($ClassMethod(tProductions, "LastStart"), tStarted, "and the production was not started again")
    For tTry = 1:1:10 {
        If $Piece($ClassMethod(tProductions, "State"), "|", 2) Quit
        Hang 0.5
    }
    Do $$$AssertEquals($ClassMethod(tProductions, "State"), "Running|1", "the production reads as needing an update")
}

/// <p>AC1: the script a person takes instead of confirming a change (AD-59) names the item, sets the new class, removes exactly the settings
/// the review listed by their target and name, saves the item and the production class, never updates the production, and drops the
/// production on its last line.</p>
/// <p>Mutation (Rule 19): remove <code>SaveToClass(tItem)</code> from the <code>CHANGECLASS</code> branch of
/// <method>OcuPilot.Port.InteropPort.ItemSnippet</method> -- the save clause goes red.</p>
Method TestTheScriptOfAChangeSetsTheClassAndRemovesTheListedSettings()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Items", "CHANGECLASS"), "objectscript", "a change of class has an ObjectScript form")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "Probe.Production" _ $Char(1) _ "Probe.Item"
    Set tQuery("newClass") = "Probe.NewClass"
    Set tContext = {"payload": {"Dropped": [{"Target": "Host", "Name": "HangSeconds", "Value": "1", "Secret": false}, {"Target": "Adapter", "Name": ("Quoted" _ $Char(34) _ "Name"), "Value": "", "Secret": true}]}}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Items", "CHANGECLASS", .tQuery, "", tContext)
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "FindItemByConfigName(""Probe.Item"")", "the item is the named one: " _ tText)
    Do $$$AssertTrue(tText [ "Set tItem.ClassName = ""Probe.NewClass""", "it takes the new class")
    Do $$$AssertTrue((tText [ """Host.HangSeconds""") && (tText [ """Adapter.Quoted""""Name"""), "it removes the listed settings by target and name, each as a string literal")
    Do $$$AssertTrue((tText [ "tItem.%Save()") && (tText [ "SaveToClass(tItem)"), "the item and the production class are saved")
    Do $$$AssertTrue((tText '[ "UpdateProduction") && (tText '[ "CleanProduction"), "and nothing updates the production")
    Do $$$AssertEquals($Piece(tText, $Char(10), *), " Kill tItem, tProduction", "the last line drops the production")
}

}
