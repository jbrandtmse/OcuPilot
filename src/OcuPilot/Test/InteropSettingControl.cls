/// <p>Pins Story 20.22's two setting writes end to end against a probe production in <code>USER</code> (AD-4, AD-6,
/// AD-7, AD-13, AD-15, AD-51, AD-53, AD-55, AD-56, AD-58, AD-59, AD-62): the Item settings list and its read tool; the
/// agent's set and reset minted, confirmed over HTTP, read back and ledgered; the person's Set value and Reset to
/// default writing the same way, an empty value included; the change in the stored configuration, in the production
/// class after a recompile and in the vendor's audit trail, which names the setting and never a value; a server path
/// named a location on the server; a write on a running production starting and stopping no job, reading as an
/// update pending, and applied by Story 20.2's Update; and each tool's script.</p>
/// <p>The class methods other than the tests are shared by <class>OcuPilot.Test.InteropSettingRefusals</class>,
/// <class>OcuPilot.Test.InteropSettingSecrets</class> and <class>OcuPilot.Test.InteropSettingPaths</class>; the
/// confirm, mint and audit helpers are <class>OcuPilot.Test.InteropItemControl</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe production in
/// <code>USER</code></b>. The agent's proposals are minted for the HTTP account, so the confirm over the wire is that
/// user's own. One class per run.</p>
Class OcuPilot.Test.InteropSettingControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>Story 20.3's control test: the mint, the confirm over HTTP, the audit and the job helpers.</p>
Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

/// <p>Story 20.2's control test: the production's state and its Update.</p>
Parameter PRODUCTIONS = "OcuPilot.Test.InteropControl";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "/screens/interop.itemsettings";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.InteropItemSettingList";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

/// <p>A value no audit row may carry: the audit names a setting, never a value.</p>
Parameter MARKER = "OcuPilotSettingMarker";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingControl compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals; a failing status when
/// <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingControl left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Reset()
}

/// <p>The probe is stopped and its settings are as they began, its proposals removed, whether the test passed or
/// failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = ..Reset()
    Do $$$AssertStatusOK(tSC, "the probe production is left stopped with its settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Stop the probe, remove the system defaults it holds and write its class again, which reloads the stored
/// configuration from its XData: every setting an earlier test stored is as the class declares it.</p>
ClassMethod Reset() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Do $ClassMethod(..#PROBE, "RemoveDefaults")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Settle")
    Quit tSC
}

/// <p>The composite id of the setting <var>pTarget</var>/<var>pName</var> of the item <var>pItem</var> in the probe
/// production, as the routes take it.</p>
ClassMethod IdOf(pTarget As %String, pName As %String, pItem As %String = {..#OPNAME}) As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ pItem _ $Char(1) _ pTarget _ $Char(1) _ pName
}

/// <p>The item criterion of the probe operation, as the screen's route carries it.</p>
ClassMethod ItemId(pItem As %String = {..#OPNAME}) As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ pItem
}

/// <p>One call of the port's Settings endpoint in <code>USER</code>, as the running account: <var>pType</var> over
/// <var>pId</var>, with <var>pBody</var> and, for a <code>SETTING</code> read, <var>pAction</var>. The status is the
/// port's.</p>
ClassMethod Invoke(pType As %String, pId As %String, pBody = "", pAction As %String = "", Output pResult, Output pHttp As %Integer, Output pFault, pPort As %String = {..#PORT}) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Quit $ClassMethod(pPort, "Invoke", "Settings", pType, .tQuery, pBody, .pResult, .pHttp, .pFault)
}

/// <p>The code a port refusal carries, <code>""</code> when it is none.</p>
ClassMethod CodeOf(pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    Quit pFault.%Get("code")
}

/// <p>The port's <code>SETTING</code> row of <var>pTarget</var>/<var>pName</var>, <code>""</code> when it answers none.</p>
ClassMethod Row(pTarget As %String, pName As %String) As %DynamicObject
{
    Set tSC = ..Invoke("SETTING", ..IdOf(pTarget, pName), "", "", .tRow, .tHttp, .tFault)
    If +$Get(tHttp) '= 200 Quit ""
    Quit tRow
}

/// <p>The probe operation's stored value of the setting <var>pTarget</var>/<var>pName</var> (an item's own property
/// for <code>Core</code>), <code>&lt;none&gt;</code> when it holds no element.</p>
ClassMethod Stored(pTarget As %String, pName As %String) As %String
{
    Set tText = "<none>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
        Set tItem = tProduction.FindItemByConfigName(..#OPNAME)
        If pTarget = "Core" {
            Set tText = $Property(tItem, pName)
        } Else {
            Set tSetting = tItem.FindSettingByName(pName, pTarget)
            If $IsObject(tSetting) Set tText = tSetting.Value
        }
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The production class's <code>ProductionDefinition</code> XData.</p>
ClassMethod ClassText() As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tDef = ##class(%Dictionary.XDataDefinition).%OpenId(..#PRODUCTION _ "||ProductionDefinition")
        If $IsObject(tDef) Set tText = tDef.Data.Read(1000000)
        Set tDef = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>What the class's XData carries for the probe operation's setting <var>pTarget</var>/<var>pName</var>: the
/// element's text for a Host or Adapter setting, the item's attribute for a <code>Core</code> one;
/// <code>&lt;none&gt;</code> when the XData carries none.</p>
ClassMethod InClass(pTarget As %String, pName As %String) As %String
{
    Set tText = ..ClassText()
    If pTarget = "Core" {
        Set tPos = $Find(tText, "<Item Name=""" _ ..#OPNAME _ """")
        If 'tPos Quit "<none>"
        Set tTag = $Extract(tText, tPos, $Find(tText, ">", tPos) - 1)
        Quit $Piece($Piece(tTag, " " _ pName _ "=""", 2), """", 1)
    }
    Set tOpen = "<Setting Target=""" _ pTarget _ """ Name=""" _ pName _ """>"
    Set tPos = $Find(tText, tOpen)
    If 'tPos Quit "<none>"
    Quit $Piece($Extract(tText, tPos, *), "</Setting>", 1)
}

/// <p>The probe operation's stored settings and its class's XData as one text, which a refusal must leave as it was.</p>
ClassMethod Snapshot() As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
        Set tItem = tProduction.FindItemByConfigName(..#OPNAME)
        For tI = 1:1:tItem.Settings.Count() {
            Set tText = tText _ tItem.Settings.GetAt(tI).Target _ "/" _ tItem.Settings.GetAt(tI).Name _ "=" _ tItem.Settings.GetAt(tI).Value _ ";"
        }
        Set tText = tText _ "|" _ tItem.Comment _ "|" _ tItem.PoolSize _ "|" _ tItem.Category _ "|" _ tItem.Schedule _ "|" _ tItem.LogTraceEvents _ "|" _ tItem.Foreground _ "|" _ tItem.Enabled
        Set tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText _ "|" _ $System.Encryption.Base64Encode($System.Encryption.SHAHash(256, ..ClassText()))
}

/// <p>The vendor's audit rows since <var>pSince</var> that record a setting write, as
/// <method>OcuPilot.Test.InteropItemControl.Audited</method> gives them: the compile of the production class that the
/// probe's own reset makes is a configuration event too, and not this story's.</p>
ClassMethod SettingAudited(pSince As %String) As %String
{
    Set tAll = $ClassMethod(..#ITEMS, "Audited", pSince)
    Set tText = ""
    For tI = 1:1:$Length(tAll, ";") {
        Set tRow = $Piece(tAll, ";", tI)
        If tRow [ "setting " Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow
    }
    Quit tText
}

/// <p>The arguments of an agent call naming the probe operation's setting <var>pTarget</var>/<var>pName</var>, with
/// <var>pValue</var> when it is not <code>$c(0)</code>.</p>
ClassMethod ArgsFor(pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, pItem As %String = {..#OPNAME}) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Production", ..#PRODUCTION, "string")
    Do tArgs.%Set("Item", pItem, "string")
    Do tArgs.%Set("Target", pTarget, "string")
    Do tArgs.%Set("Name", pName, "string")
    If pValue '= $Char(0) Do tArgs.%Set("Value", pValue, "string")
    Quit tArgs
}

/// <p>One row action on the Item settings screen as <code>status code</code>, the answer in <var>pAnswer</var>.
/// <var>pValue</var> is the dialog's value for <code>set</code>; <code>$c(0)</code> sends none.</p>
ClassMethod Act(pAction As %String, pTarget As %String, pName As %String, pValue As %String = {$Char(0)}, Output pAnswer, pItem As %String = {..#OPNAME}) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", ..IdOf(pTarget, pName, pItem), "string")
    If pValue '= $Char(0) Do tBody.%Set("values", {"Value": (pValue)})
    Do $ClassMethod(..#ITEMS, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pArgs</var> as the HTTP account and confirm it over HTTP: the card's one
/// <code>Value</code> row (<var>pBefore</var> to <var>pAfter</var>), the consequence code, the single envelope the
/// confirm answers, its ledger row, and the vendor's audit rows since the mint, in <var>pAudit</var>.</p>
Method Through(pTool As %String, pArgs As %DynamicObject, pBefore As %String, pAfter As %String, pConsequence As %String, Output pAudit As %String)
{
    Set tName = $Parameter(pTool, "TOOLNAME")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#ITEMS, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = {}
    Do tRow.%Set("field", "Value", "string")
    Do tRow.%Set("before", pBefore, "string")
    Do tRow.%Set("after", pAfter, "string")
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[" _ tRow.%ToJSON() _ "]", tName _ ": its card shows one Value row, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item-setting|USER|" _ $Translate(..IdOf(pArgs.Target, pArgs.Name), $Char(1), "~"), tName _ ": the target is the setting, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), pConsequence, tName _ ": its consequence code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, tName _ ": it is not destructive")
    Set tSC = $ClassMethod(..#ITEMS, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", tName _ ": updated and marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(..#ITEMS, "LedgerCount", tTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set pAudit = $ClassMethod(..#ITEMS, "Audited", tSince)
}

/// <p>AC1: the Item settings list of the probe operation answers its settable Core settings and its Host settings with
/// their value, source and default through the port, in both spellings of the item, never the item's read-only rows or
/// <code>Enabled</code>; a server path and a credential-named setting are flagged; the screen's read and the read tool
/// answer the same rows; an unknown item is 404 and a read naming none is 400 <code>READ.CRITERION</code>.</p>
/// <p>Mutation (Rule 19): skip <code>GetStaticSettings</code> in
/// <method>OcuPilot.Port.InteropPort.GatherSettings</method> -- the Core legs go red.</p>
Method TestTheListAnswersTheItemsSettings()
{
    Set tSC = $ClassMethod(..#PROBE, "SetSetting", "InitSeconds", 7)
    Do $$$AssertStatusOK(tSC, "InitSeconds is stored at 7")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("item") = ..ItemId()
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the port lists the operation's settings")
    If '$IsObject($Get(tRows)) Quit
    Kill tByKey
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tByKey(tRow.Target _ "/" _ tRow.Name) = tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default _ "|" _ tRow.DefaultSource _ "|" _ tRow.Location _ "|" _ tRow.Secret
    }
    Do $$$AssertEquals($Get(tByKey("Host/InitSeconds")), "7|production|0|classDefault|0|0", "InitSeconds holds the production's 7 over the class default 0")
    Do $$$AssertEquals($Get(tByKey("Host/HangSeconds")), "0|production|0|classDefault|0|0", "HangSeconds is the production's own 0, which the XData declares")
    Do $$$AssertEquals($Get(tByKey("Host/RetryInterval")), "5|classDefault|5|classDefault|0|0", "a setting the production does not hold reads its class default")
    Do $$$AssertEquals($Get(tByKey("Core/PoolSize")), "1|production||classDefault|0|0", "a Core setting reads the item's property")
    Do $$$AssertEquals($Get(tByKey("Host/ProbeDirectory")), "|classDefault||classDefault|1|0", "a directory setting is a location")
    Do $$$AssertEquals($Get(tByKey("Host/ProbeFile")), "|classDefault||classDefault|1|0", "and so is a file setting")
    Do $$$AssertEquals($Get(tByKey("Host/ApiToken")), "|classDefault||classDefault|0|1", "a credential-named setting reads empty and secret")
    Do $$$AssertEquals($Data(tByKey("Core/Enabled")) + $Data(tByKey("Core/Classname")) + $Data(tByKey("Core/Description")) + $Data(tByKey("Core/AdapterClassname")), 0, "Enabled and the item's read-only rows are not listed")
    Set tOther = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ($ListFind($ListBuild("Core", "Host", "Adapter"), tRow.Target) = 0) || (tRow.Production '= ..#PRODUCTION) || (tRow.Item '= ..#OPNAME) Set tOther = tOther _ tRow.Name _ ";"
    }
    Do $$$AssertEquals(tOther, "", "every row names the production, the item and one of the three groups")
    Set tQuery("item") = ..#PRODUCTION _ "||" _ ..#OPNAME
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Settings", "LIST", .tQuery, "", .tVendorRows, .tVendorHttp, .tVendorFault)
    Do $$$AssertEquals(+$Get(tVendorHttp) _ "|" _ (tVendorRows.%ToJSON() = tRows.%ToJSON()), "200|1", "the vendor's config name lists the same rows")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Kill tCriteria
    Set tCriteria("item") = ..ItemId()
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tScreenHttp), 200, "the screen's read answers")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.itemsettings.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "interop.itemsettings.read resolves")
    Kill tResult
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"item": (..ItemId()), "maxRows": 1000}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(+$Get(tToolHttp), 200, "the read tool answers")
    If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tAnswer.rows.%ToJSON(), tRows.%ToJSON(), "the screen's rows are the port's")
    Do $$$AssertEquals(..Digest(tResult.rows), ..Digest(tRows), "and so are the tool's, which it sorts by name")
    Do $$$AssertEquals(tAnswer.criteria.item, ..ItemId(), "the screen reports the criterion it applied")
    Kill tNone
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tNoneAnswer, .tNoneHttp, .tNoneFault, .tNone)
    Do $$$AssertEquals(+$Get(tNoneHttp) _ "|" _ ..CodeOf(tNoneFault), "400|" _ ##class(OcuPilot.Api.Error).#READCRITERION, "a read with no item is refused for it")
    Set tCriteria("item") = ..#PRODUCTION _ $Char(1) _ "OcuPilotProbeNoSuch"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tGoneAnswer, .tGoneHttp, .tGoneFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tGoneHttp) _ "|" _ ..CodeOf(tGoneFault), "404|" _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "and an item the production does not hold is not found")
    Set tCriteria("item") = "OcuPilotProbe.No.Such" _ $Char(1) _ ..#OPNAME
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tGoneAnswer, .tGoneHttp, .tGoneFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tGoneHttp) _ "|" _ ..CodeOf(tGoneFault), "404|" _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "so is a production it does not hold")
}

/// <p>The rows of <var>pRows</var> as <code>Target/Name=Value|Source|Default|Location|Secret</code>, sorted by
/// <code>Target/Name</code> and joined by <code>;</code>.</p>
ClassMethod Digest(pRows As %DynamicArray) As %String
{
    Kill tByKey
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tByKey(tRow.Target _ "/" _ tRow.Name) = tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default _ "|" _ tRow.Location _ "|" _ tRow.Secret
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tByKey(tKey))
        If tKey = "" Quit
        Set tText = tText _ tKey _ "=" _ tByKey(tKey) _ ";"
    }
    Quit tText
}

/// <p>AC2: the agent's set of a Host setting and its reset, each minted for the HTTP account and confirmed over HTTP,
/// store the change, carry it into the production class (surviving a recompile), answer one envelope, are ledgered
/// once and are audited by the setting's name with no value; the cards say the change waits for an update; and the
/// read-back says what was sent.</p>
/// <p>Mutation (Rule 19): drop <code>SaveToClass</code> from <method>OcuPilot.Port.InteropPort.SettingStep</method> --
/// the class leg of the set goes red; leave the element in the reset -- the reset's stored leg goes red.</p>
Method TestTheAgentsSetAndResetOfAHostSettingConfirmOverHttp()
{
    Do $$$AssertEquals(..Stored("Host", "InitSeconds") _ "|" _ ..InClass("Host", "InitSeconds"), "<none>|<none>", "InitSeconds begins with no element of its own")
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingSet", ..ArgsFor("Host", "InitSeconds", "7"), "0", "7", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..Stored("Host", "InitSeconds") _ "|" _ ..InClass("Host", "InitSeconds"), "7|7", "the element is stored and the production class carries it")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the class compiles again")
    Do $$$AssertEquals(..Stored("Host", "InitSeconds"), "7", "and the compile does not revert it")
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeOp of OcuPilotProbe.Interop.Production") && (tAudit [ "setting set by OcuPilot, Host:InitSeconds"), "the vendor's audit trail names the setting: " _ tAudit)
    Set tRow = ..Row("Host", "InitSeconds")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source _ "|" _ tRow.Default, "7|production|0", "the setting reads the production's value over its default")
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingReset", ..ArgsFor("Host", "InitSeconds"), "7", "0", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..Stored("Host", "InitSeconds") _ "|" _ ..InClass("Host", "InitSeconds"), "<none>|<none>", "the reset removes the element from the configuration and the class")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the class compiles again")
    Do $$$AssertEquals(..Stored("Host", "InitSeconds"), "<none>", "and the compile keeps it removed")
    Do $$$AssertTrue(tAudit [ "setting reset by OcuPilot, Host:InitSeconds", "the audit trail names the reset: " _ tAudit)
    Set tRow = ..Row("Host", "InitSeconds")
    Do $$$AssertEquals(tRow.Value _ "|" _ tRow.Source, "0|classDefault", "and the default applies again")
}

/// <p>AC2: the agent's set of an item's own property and of an empty value: <code>Comment</code> is stored as the
/// item's property and carried into the class, the audit names it and not the value, and the same setting is then
/// cleared with an empty string, which the card shows as a move to nothing.</p>
/// <p>Mutation (Rule 19): refuse an empty <code>Value</code> in <method>OcuPilot.Port.InteropPort.SettingViolations</method>
/// -- the clearing leg goes red.</p>
Method TestTheAgentsSetOfACoreSettingAndOfAnEmptyValueConfirm()
{
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingSet", ..ArgsFor("Core", "Comment", ..#MARKER), "", ..#MARKER, "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..Stored("Core", "Comment") _ "|" _ ..InClass("Core", "Comment"), ..#MARKER _ "|" _ ..#MARKER, "the item's property is stored and carried into the class")
    Do $$$AssertTrue((tAudit [ "setting set by OcuPilot, Core:Comment") && (tAudit '[ ..#MARKER), "the vendor's audit trail names the setting and carries no value: " _ tAudit)
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingSet", ..ArgsFor("Core", "Comment", ""), ..#MARKER, "", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..Stored("Core", "Comment") _ "|" _ ..InClass("Core", "Comment"), "|", "an empty string clears it in the configuration and in the class")
    Set tSC = $ClassMethod(..#ITEMS, "MintAs", "OcuPilot.Screen.Tool.InteropSettingReset", ..ArgsFor("Core", "Comment"), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ "|" _ ..CodeOf(tFault), "409|INTEROP.SETTING.CORE", "a Core setting has no default to return to")
}

/// <p>AC2: the person's Set value and Reset to default write the same way: each answers 200 with the
/// <code>updated</code> event for the setting, an empty value is accepted for the set, a request without the value is
/// refused, and each lands in the stored configuration and the class and is audited by name with no value.</p>
/// <p>Mutation (Rule 19): drop the <code>ScreenActionEmptyNames</code> test from
/// <method>OcuPilot.Api.ScreenAction.Values</method> -- the empty-value leg goes red.</p>
Method TestThePersonsSetAndResetWriteTheSameWay()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("set", "Host", "InitSeconds", "7", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Set value answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ $Translate(tAnswer.target.id, $Char(1), "~") _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|production-item-setting|" _ $Translate(..IdOf("Host", "InitSeconds"), $Char(1), "~") _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the setting, whose read-back matches")
    Do $$$AssertEquals(..Stored("Host", "InitSeconds") _ "|" _ ..InClass("Host", "InitSeconds"), "7|7", "stored and carried into the class")
    Do $$$AssertEquals(..Act("set", "Host", "InitSeconds", $Char(0), .tAnswer), "400 TOOL.ARGUMENTS", "a set that sends no value is refused")
    Do $$$AssertEquals(..Act("reset", "Host", "InitSeconds", "7", .tAnswer), "400 TOOL.ARGUMENTS", "and a reset that sends one is")
    Do $$$AssertEquals(..Act("reset", "Host", "InitSeconds", $Char(0), .tAnswer), "200 ", "Reset to default answers 200")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "as an update that sent nothing")
    Do $$$AssertEquals(..Stored("Host", "InitSeconds") _ "|" _ ..InClass("Host", "InitSeconds"), "<none>|<none>", "and removes the element from the configuration and the class")
    Do $$$AssertEquals(..Act("set", "Core", "Comment", ..#MARKER, .tAnswer), "200 ", "Set value of a Core setting answers 200")
    Do $$$AssertEquals(..Act("set", "Core", "Comment", "", .tAnswer), "200 ", "and an empty value is accepted")
    Do $$$AssertEquals(..Stored("Core", "Comment") _ "|" _ ..InClass("Core", "Comment"), "|", "which clears it in the configuration and the class")
    Set tAudit = $ClassMethod(..#ITEMS, "Audited", tSince)
    Do $$$AssertTrue((tAudit [ "setting set by OcuPilot, Host:InitSeconds") && (tAudit [ "setting reset by OcuPilot, Host:InitSeconds") && (tAudit [ "setting set by OcuPilot, Core:Comment") && (tAudit '[ ..#MARKER), "the vendor's audit trail names each setting and carries no value: " _ tAudit)
}

/// <p>AC5: a server path is stored as its class validates it and named a location on the server: the row says so, the
/// agent's proposal for a directory and for a file carries <code>INTEROP.SETTING.LOCATION</code>, and the person's
/// Set value stores the same; a reset of the production's path is an ordinary reset.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LocationKind</method> answer <code>""</code> -- the
/// row and consequence legs go red.</p>
Method TestAServerPathIsNamedALocationOnTheServer()
{
    Set tDirectory = "/tmp/ocupilot-probe-dir"
    Set tFile = "/tmp/ocupilot-probe-dir/probe.key"
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingSet", ..ArgsFor("Host", "ProbeDirectory", tDirectory), "", tDirectory, "INTEROP.SETTING.LOCATION", .tAudit)
    Do $$$AssertEquals(..Stored("Host", "ProbeDirectory") _ "|" _ ..InClass("Host", "ProbeDirectory"), tDirectory _ "|" _ tDirectory, "the directory is stored as given and carried into the class")
    Do $$$AssertTrue(tAudit '[ tDirectory, "the audit trail carries no path: " _ tAudit)
    Set tRow = ..Row("Host", "ProbeDirectory")
    Do $$$AssertEquals(tRow.Location _ "|" _ tRow.Value, "1|" _ tDirectory, "the row says it is a location")
    Do $$$AssertEquals(..Act("set", "Host", "ProbeFile", tFile, .tAnswer), "200 ", "the person's Set value of a file stores it too")
    Do $$$AssertEquals(..Stored("Host", "ProbeFile"), tFile, "as given")
    Do ..Through("OcuPilot.Screen.Tool.InteropSettingReset", ..ArgsFor("Host", "ProbeDirectory"), tDirectory, "", "INTEROP.ITEM.PENDING", .tAudit)
    Do $$$AssertEquals(..Stored("Host", "ProbeDirectory"), "<none>", "a reset of the path is an ordinary reset")
}

/// <p>AC2: on a running production a set and a reset start and stop no job and read as an update pending, and Story
/// 20.2's Update then applies each and leaves the production up to date.</p>
/// <p>Mutation (Rule 19): call <code>UpdateProduction</code> after the save in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> -- the pending legs go red.</p>
Method TestAWriteOnARunningProductionChangesNoJobAndTheUpdateAppliesIt()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the probe is started")
    Hang 3
    Do $$$AssertEquals($ClassMethod(..#ITEMS, "Jobs"), ..#OPNAME, "the operation has its job")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "and nothing is pending")
    Set tStarted = $ClassMethod(..#PRODUCTIONS, "LastStart")
    Do $$$AssertEquals(..Act("set", "Host", "HangSeconds", "2", .tAnswer), "200 ", "Set value of HangSeconds answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Hang 2
    Do $$$AssertEquals($ClassMethod(..#ITEMS, "Jobs"), ..#OPNAME, "no job started or stopped")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "LastStart"), tStarted, "and the production was not started again")
    For tTry = 1:1:10 {
        If $Piece($ClassMethod(..#PRODUCTIONS, "State"), "|", 2) Quit
        Hang 0.5
    }
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "the production reads as needing an update")
    Do $$$AssertEquals(..Stored("Host", "HangSeconds"), "2", "while the configuration already holds the change")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "Act", "update", ..#PRODUCTION), "200 ", "the Productions screen's Update answers 200")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "and the production reads up to date")
    Do $$$AssertEquals(..Act("reset", "Host", "HangSeconds", $Char(0), .tAnswer), "200 ", "Reset to default answers 200")
    For tTry = 1:1:10 {
        If $Piece($ClassMethod(..#PRODUCTIONS, "State"), "|", 2) Quit
        Hang 0.5
    }
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "the reset reads as an update pending too")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "Act", "update", ..#PRODUCTION), "200 ", "and the Update applies it")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "leaving the production up to date")
}

/// <p>AD-59: each tool's copy-out draft renders one ObjectScript step that switches to the namespace the proposal read,
/// opens the production, stores or removes the setting, saves the item and the production class, closes the proposal
/// as a draft and changes nothing, and none names <code>CleanProduction</code> or <code>UpdateProduction</code>.</p>
Method TestEachToolsDraftRendersItsScript()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#OPNAME, "Host", "InitSeconds", 9), "InitSeconds is stored at 9 for the reset")
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild("InteropSettingSet", "7", "FindSettingByName(", "tSetting.Value = "), $ListBuild("InteropSettingReset", $Char(0), "Settings.RemoveAt(tI)", "tItem.%Save()") {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Set tArgs = ..ArgsFor("Host", "InitSeconds", $List(tCase, 2))
        Set tSC = $ClassMethod(..#ITEMS, "MintAs", tTool, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, tUser, "https://draft.example:52773", .tDraft, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tDraft)) Continue
        Set tText = tDraft.draft.steps.%Get(0).text
        Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", $Parameter(tTool, "TOOLNAME") _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 3)) && (tText [ $List(tCase, 4)) && (tText [ "SaveToClass(") && (tText '[ "CleanProduction") && (tText '[ "UpdateProduction"), $Parameter(tTool, "TOOLNAME") _ ": " _ tText)
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no draft changed a setting")
}

}
