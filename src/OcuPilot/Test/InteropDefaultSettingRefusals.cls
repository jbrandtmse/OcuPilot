/// <p>Pins Story 24.15's refusals end to end against probe system default settings in <code>USER</code> and <code>HSCUSTOM</code> (AD-6,
/// AD-8, AD-35, AD-39, AD-54, AD-62): each row of the plan's refusal matrix is refused by its own code with its published sentence, and
/// nothing is written -- a key the namespace holds, a key that is not there, a setting whose name holds a credential, a key part or a value
/// the rules or the vendor refuse (422), a namespace under source control, and the comparison's namespace refusals. The gate runs as real
/// principals in a child process: a caller without WRITE, the setting <code>Enabled</code> without the item run resource, and a restricted
/// caller with and without the setting's own resource, and a caller who cannot read the other namespace. The <code>%All</code> exemption of
/// the per-setting rules is driven through <class>OcuPilot.Test.InteropDefaultSettingRoleSeam</class>, which answers whether the caller holds
/// the role, because the principals above hold exactly the pairs they name.</p>
/// <p>A secret-named setting never shows its value: the list, the screen's read, the agent's read tool, the comparison and the script form
/// render none, and the vendor's own audit rows of it read masked.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP
/// test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named
/// <code>OcuP2415*</code>. It removes every setting, principal and role it creates.</p>
Class OcuPilot.Test.InteropDefaultSettingRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropDefaultSettingControl";

Parameter GENERATOR = "OcuPilot.Test.InteropLookupGate";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter ROLESEAM = "OcuPilot.Test.InteropDefaultSettingRoleSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter PRODUCTION = "OcuProbe2415.Production";

Parameter SECRETMARKER = "OcuSecretMarker2415";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>.</p>
Parameter PRINCIPALS = "OcuP2415Exact:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:RW,%Ens_ConfigItemRun:U,%DB_USER:RW;OcuP2415NoWrite:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:R,%DB_USER:RW;OcuP2415NoRun:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:RW,%DB_USER:RW;OcuP2415Restricted:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:RW,%Ens_ConfigItemRun:U,%DB_USER:RW,%Ens_RestrictedUI_SystemDefaultSettings:U;OcuP2415Own:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:RW,%Ens_ConfigItemRun:U,%DB_USER:RW,%Ens_RestrictedUI_SystemDefaultSettings:U,%Ens_SystemDefaultSettings_PoolSize:U;OcuP2415NoUser:%Development:U,%Ens_Portal:U,%Ens_SystemDefaultConfig:RW";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;type&gt;|&lt;setting&gt;|&lt;namespace&gt;|&lt;target&gt;</code>. Every write names the probe
/// production, <code>*</code> for its item and host class and the held <code>PoolSize</code> setting for a set.</p>
Parameter LEGS = "add|ADDDEFAULT|ArchiveIOProbe|USER|,addEnabled|ADDDEFAULT|Enabled|USER|,addAny|ADDDEFAULT|*|USER|,setPool|SETDEFAULT|PoolSize|USER|,diffUser|LIST||HSCUSTOM|USER,diffHsc|LIST||USER|HSCUSTOM";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropDefaultSettingRefusals creates and deletes users and roles and writes probe system default settings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2415Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#ROLESEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe settings are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION) + $ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION, "HSCUSTOM"), 0, "and none survives in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The code of <var>pFault</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    Quit $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The probe production's setting <var>pSetting</var> through the port class <var>pClass</var> in <var>pNamespace</var>: the HTTP
/// status and, in <var>pFault</var>, the envelope; <var>pRow</var> is the answer. A read names the type <code>DEFAULTSETTING</code>.</p>
ClassMethod Through(pType As %String, pSetting As %String, pBody As %DynamicObject = "", Output pFault, Output pRow, pNamespace As %String = "USER", pClass As %String = {..#PORT}, pAction As %String = "") As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, "*", "*", pSetting))
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(pClass, "Invoke", "DefaultSettings", pType, .tQuery, pBody, .pRow, .tHttp, .pFault)
    Quit +$Get(tHttp)
}

/// <p>The status and code of a write as <code>status code</code>.</p>
ClassMethod Verdict(pType As %String, pSetting As %String, pBody As %DynamicObject = "", pNamespace As %String = "USER", pClass As %String = {..#PORT}) As %String
{
    Set tHttp = ..Through(pType, pSetting, pBody, .tFault, .tRow, pNamespace, pClass)
    Quit tHttp _ " " _ ..CodeOf(tFault)
}

/// <p>The agent's mint of <var>pTool</var> for the probe setting <var>pSetting</var> with <var>pSet</var> beside it: the code of its
/// refusal, <code>minted</code> when it was not refused; the sentence in <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pSetting As %String, pSet As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, $ClassMethod(..#CONTROL, "ArgsFor", pSetting, pSet), .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>AC2: an add of a key the namespace holds is <code>INTEROP.DEFAULTSETTING.TAKEN</code>, and a set or a remove of a key it does not hold
/// is 404, each with its published sentence for the add, from the person's Save, the agent's mint and the port, and the held setting is
/// untouched.</p>
/// <p>Mutation (Rule 19): drop the <code>TAKEN</code> decision from <method>OcuPilot.Port.InteropPort.DefaultSettingWriteToken</method> --
/// the add legs go red.</p>
Method TestAHeldKeyIsTakenAndAMissingOneIsNotFound()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "PoolSize", "3", "held"), "the probe setting is held")
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/default-settings", $ClassMethod(..#CONTROL, "SaveBody", "PoolSize", "5"), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "409 INTEROP.DEFAULTSETTING.TAKEN " _ ..Reason("DEFAULTSETTINGTAKEN"), "the Save is refused with the published sentence")
    Do $$$AssertEquals(..MintVerdict("InteropDefaultSettingAdd", "PoolSize", {"Value": "5"}, .tReason), "INTEROP.DEFAULTSETTING.TAKEN", "the agent's add is refused at the mint")
    Do $$$AssertEquals(tReason, ..Reason("DEFAULTSETTINGTAKEN"), "with the published sentence")
    Do $$$AssertEquals(..Verdict("ADDDEFAULT", "PoolSize", {"Value": "5"}), "409 INTEROP.DEFAULTSETTING.TAKEN", "the port refuses the add")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|held|0", "and the held setting is untouched")
    Do $$$AssertEquals(..Verdict("SETDEFAULT", "NoSuchSetting", {"Value": "5"}), "404 PORT.NOTFOUND", "a set of a key that is not held is 404")
    Do $$$AssertEquals(..Verdict("REMOVEDEFAULT", "NoSuchSetting"), "404 PORT.NOTFOUND", "and so is a remove")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "remove", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, "*", "*", "NoSuchSetting")), "", .tAnswer), "404 PORT.NOTFOUND", "the person's Remove of it is 404 too")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION), 1, "and nothing was written")
}

/// <p>AC2, AC3: a write of a setting whose name holds a credential is <code>INTEROP.DEFAULTSETTING.SECRET</code> from every caller, before
/// any vendor call; the value of a stored one is shown by no read, no comparison and no script, and the setting is left as it was.</p>
/// <p>Mutation (Rule 19): drop the <code>IsCredentialName</code> test from <method>OcuPilot.Port.InteropPort.DefaultSettingWriteRefusal</method>
/// -- the write rows go red.</p>
Method TestASecretNamedSettingIsRefusedAndNeverShown()
{
    Set tFixture = ..#FIXTURE
    Set tMarker = ..#SECRETMARKER
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-here", "stored"), "a stored secret-named setting is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-there", "stored", 0, "HSCUSTOM"), "and another in HSCUSTOM")
    For tCase = $ListBuild("ADDDEFAULT", "ApiPassword"), $ListBuild("SETDEFAULT", "SSLPassword"), $ListBuild("REMOVEDEFAULT", "SSLPassword") {
        Do $$$AssertEquals(..Verdict($List(tCase, 1), $List(tCase, 2), {"Value": "changed"}), "409 INTEROP.DEFAULTSETTING.SECRET", $List(tCase, 1) _ " of " _ $List(tCase, 2) _ " is refused for the credential")
    }
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/default-settings", $ClassMethod(..#CONTROL, "SaveBody", "ApiPassword", "x"), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "409 INTEROP.DEFAULTSETTING.SECRET " _ ..Reason("DEFAULTSETTINGSECRET"), "the Save is refused with the published sentence")
    Set tVerdict = ..MintVerdict("InteropDefaultSettingUpdate", "SSLPassword", {"Value": "changed"}, .tReason)
    Do $$$AssertEquals(tVerdict, "INTEROP.DEFAULTSETTING.SECRET", "the agent's update is refused at the mint: " _ tReason)
    Do $$$AssertEquals(tReason, ..Reason("DEFAULTSETTINGSECRET"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "SSLPassword"), tMarker _ "-here|stored|0", "the stored value is untouched")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION), 1, "and no credential-named setting was added")
    ; No read carries the value.
    Set tHttp = ..Through("LIST", "", "", .tFault, .tRows)
    Set tRow = ..RowFor(tRows, "SSLPassword")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRow): tRow.Value _ "|" _ tRow.Secret, 1: "unlisted"), "200||1", "the list shows the setting with an empty value and Secret true")
    Do $$$AssertTrue(tRows.%ToJSON() '[ tMarker, "and no part of the answer carries the value")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("target") = "HSCUSTOM"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tDiff, .tHttp, .tFault)
    Set tDiffRow = ..RowFor(tDiff, "SSLPassword")
    Do $$$AssertEquals($Select($IsObject(tDiffRow): tDiffRow.Change _ "|" _ tDiffRow.Value _ "|" _ tDiffRow.OtherValue _ "|" _ tDiffRow.Secret, 1: "unlisted"), "differs|||1", "the comparison lists it as differing and shows neither value")
    Do $$$AssertTrue(tDiff.%ToJSON() '[ tMarker, "and no part of its answer carries a value")
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "GET", "/screens/interop.defaultsettings/read?maxRows=1000", "", .tScreenStatus, .tScreen)
    Do $$$AssertTrue($IsObject(tScreen) && (tScreen.%ToJSON() '[ tMarker) && (tScreen.%ToJSON() [ "SSLPassword"), "the screen's read lists it without the value")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.defaultsettings.read", .tTool)
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertTrue((+$Get(tToolHttp) = 200) && (tResult.%ToJSON() '[ tMarker) && (tResult.%ToJSON() [ "SSLPassword"), "the agent's read tool lists it without the value")
    ; The script form carries a placeholder, never the value.
    Kill tScript
    Set tScript("namespace") = "USER"
    Set tScript("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, "*", "*", "SSLPassword"))
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "DefaultSettings", "ADDDEFAULT", .tScript, {"Value": (tMarker _ "-sent")})
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue((tText [ "<Value>") && (tText '[ tMarker), "the script form renders a placeholder for the value: " _ tText)
}

/// <p>The row of <var>pRows</var> whose <code>Setting</code> is <var>pSetting</var>, or <code>""</code>.</p>
ClassMethod RowFor(pRows As %DynamicArray, pSetting As %String) As %DynamicObject
{
    Set tHit = ""
    If '$IsObject($Get(pRows)) Quit tHit
    For tI = 0:1:pRows.%Size() - 1 {
        If pRows.%Get(tI).Setting = pSetting Set tHit = pRows.%Get(tI)
    }
    Quit tHit
}

/// <p>AC3: the vendor's own audit rows of a secret-named setting, read from the audit database, read masked once
/// <method>OcuPilot.Port.AuditPort.MaskVendorSecrets</method> is applied to them, and a row of an ordinary setting, and a bulk delete, are
/// read as written. The test calls the mask directly; it does not drive the Logs audit screen's read or the agent's read tool. The mask
/// names no value of its own: it reads the row's <code>SettingName</code> line.</p>
/// <p>Mutation (Rule 19): drop the <code>DefaultSettingSecret</code> branch from <method>OcuPilot.Port.AuditPort.MaskVendorSecrets</method> --
/// the masked legs go red.</p>
Method TestTheVendorAuditRowsOfASecretNamedSettingAreMasked()
{
    Set tFixture = ..#FIXTURE
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tMarker = ..#SECRETMARKER
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-one", "stored"), "the vendor's insert of a secret-named setting is recorded")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-two", "stored"), "and its update")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "PlainSetting", tMarker _ "-plain", "stored"), "and an ordinary setting's insert")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "DropDefaults", ..#PRODUCTION), "and the delete of each")
    Set tRows = []
    For tWords = "Create System Default Setting", "Modify System Default Setting", "Delete System Default Setting" {
        Set tCount = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ModifyDefaultSetting", tWords, .tData, "SettingName: SSLPassword", "%Ensemble", "%Production")
        Do $$$AssertEquals(tCount, 1, tWords _ ": the vendor recorded one row of the secret-named setting")
        Do tRows.%Push({"EventSource": "%Ensemble", "EventType": "%Production", "Event": "ModifyDefaultSetting", "Description": (tWords), "EventData": (tData)})
    }
    Set tCount = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ModifyDefaultSetting", "Create System Default Setting", .tPlain, "SettingName: PlainSetting", "%Ensemble", "%Production")
    Do tRows.%Push({"EventSource": "%Ensemble", "EventType": "%Production", "Event": "ModifyDefaultSetting", "Description": "Create System Default Setting:", "EventData": (tPlain)})
    Do tRows.%Push({"EventSource": "%Ensemble", "EventType": "%Production", "Event": "ModifyDefaultSetting", "Description": "Bulk Delete System Default Settings", "EventData": "Delete all System Default Settings for Production: OcuProbe2415.Production"})
    Do $$$AssertTrue((tRows.%Get(0).EventData [ (tMarker _ "-one")) && (tRows.%Get(1).EventData [ (tMarker _ "-two")), "the rows as the audit database holds them carry the values")
    Do ##class(OcuPilot.Port.AuditPort).MaskVendorSecrets(tRows)
    For tI = 0:1:2 {
        Do $$$AssertTrue((tRows.%Get(tI).EventData '[ tMarker) && (tRows.%Get(tI).EventData [ "*****") && (tRows.%Get(tI).EventData [ "SettingName: SSLPassword"), "row " _ tI _ " reads masked and still names the setting")
    }
    Do $$$AssertTrue(tRows.%Get(3).EventData [ (tMarker _ "-plain"), "an ordinary setting's row is read as written")
    Do $$$AssertEquals(tRows.%Get(4).EventData, "Delete all System Default Settings for Production: OcuProbe2415.Production", "and a bulk delete's row is unchanged")
}

/// <p>AC2: a key part that is empty, past 255 characters or holds two vertical bars or a control character is
/// <code>INTEROP.DEFAULTSETTING.KEY</code>, and a value or
/// description past 2,000 characters, or a value the vendor refuses for the setting (<code>PoolSize</code> 0, a non-number for an integer
/// setting), is <code>INTEROP.DEFAULTSETTING.VALUE</code>: 422 from the Save and the port, each with its published sentence, before anything
/// is stored, and the agent's mint refuses the same rules.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DefaultSettingAccepts</method> answer 1 -- the vendor legs go red; drop the
/// control character test from <method>OcuPilot.Port.InteropPort.DefaultSettingPartOK</method> -- the control character row goes red; drop
/// its edge bar tests -- the two vertical bar rows at a part's edge go red.</p>
Method TestAKeyPartOrAValueTheRulesRefuseIsRefusedBeforeAnythingIsStored()
{
    Set tFixture = ..#FIXTURE
    Set tLong = $Translate($Justify("", 256), " ", "x")
    Set tFields = ..KeyCase(tLong)
    For tI = 1:1:$ListLength(tFields) {
        Set tCase = $List(tFields, tI)
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($List(tCase, 1))
        Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettings", "ADDDEFAULT", .tQuery, {"Value": "1"}, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "422 INTEROP.DEFAULTSETTING.KEY", $List(tCase, 2) _ " is refused as a key")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("DEFAULTSETTINGKEY"), $List(tCase, 2) _ ": with the published sentence")
    }
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/default-settings", {"Production": "OcuProbe2415.Production", "Item": "*", "HostClass": "*", "Setting": "Pool||Size", "Value": "1"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "422 INTEROP.DEFAULTSETTING.KEY", "the Save refuses a part with two vertical bars")
    For tCase = $ListBuild("PoolSize", "0", "PoolSize 0"), $ListBuild("PoolSize", "abc", "PoolSize abc"), $ListBuild("ArchiveIO", $Translate($Justify("", 2001), " ", "x"), "a value of 2,001 characters") {
        Do $$$AssertEquals(..Verdict("ADDDEFAULT", $List(tCase, 1), {"Value": ($List(tCase, 2))}), "422 INTEROP.DEFAULTSETTING.VALUE", $List(tCase, 3) _ " is refused as a value")
        Do $$$AssertEquals(..MintVerdict("InteropDefaultSettingAdd", $List(tCase, 1), {"Value": ($List(tCase, 2))}), "TOOL.ARGUMENTS", $List(tCase, 3) _ ": the agent's mint refuses it too")
    }
    Do $$$AssertEquals(..Verdict("ADDDEFAULT", "ArchiveIO", {"Description": ($Translate($Justify("", 2001), " ", "x"))}), "422 INTEROP.DEFAULTSETTING.VALUE", "a description of 2,001 characters is refused")
    Do $$$AssertEquals(..Verdict("ADDDEFAULT", "ArchiveIO", {"Value": 7}), "422 PORT.FIELD.SHAPE", "and a value that is not a string is refused by its shape")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION), 0, "and nothing was stored")
    ; A held setting is refused the same value on a set, from the person's Edit, the port and the agent's update.
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "PoolSize", "3", "held"), "the probe setting is held")
    Do $$$AssertEquals(..Verdict("SETDEFAULT", "PoolSize", {"Value": "0"}), "422 INTEROP.DEFAULTSETTING.VALUE", "the port refuses a set of PoolSize 0")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", $ClassMethod(..#CONTROL, "IdFor", "PoolSize"), {"Value": "0"}, .tAnswer), "422 INTEROP.DEFAULTSETTING.VALUE", "and so does the person's Edit")
    Do $$$AssertEquals(..MintVerdict("InteropDefaultSettingUpdate", "PoolSize", {"Value": "0"}), "TOOL.ARGUMENTS", "and the agent's update is refused at the mint")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|held|0", "and the stored value is unchanged")
}

/// <p>The key parts, as <code>$ListBuild(production, item, host class, setting)</code> with a label, each wrong in one part.</p>
ClassMethod KeyCase(pLong As %String) As %List
{
    Quit $ListBuild($ListBuild($ListBuild("", "*", "*", "ArchiveIO"), "an empty production"), $ListBuild($ListBuild(..#PRODUCTION, "", "*", "ArchiveIO"), "an empty item"), $ListBuild($ListBuild(..#PRODUCTION, "*", pLong, "ArchiveIO"), "a host class of 256 characters"), $ListBuild($ListBuild(..#PRODUCTION, "*", "*", pLong), "a setting of 256 characters"), $ListBuild($ListBuild(..#PRODUCTION, "a||b", "*", "ArchiveIO"), "an item with two vertical bars"), $ListBuild($ListBuild(..#PRODUCTION, "a|", "*", "ArchiveIO"), "an item ending in a vertical bar"), $ListBuild($ListBuild(..#PRODUCTION, "*", "|b", "ArchiveIO"), "a host class beginning with a vertical bar"), $ListBuild($ListBuild(..#PRODUCTION, "*", "*", "Arch" _ $Char(2) _ "ive"), "a setting with a control character"))
}

/// <p>AC2: a namespace under source control refuses every default setting write by <code>SOURCECONTROL</code> before the vendor is called,
/// the composed reads of a write included, while the list stays readable. Driven through the port both callers reach, through a seam that
/// answers the namespace's source control state.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from
/// <method>OcuPilot.Port.InteropPort.DefaultSettingWriteRefusal</method> -- the write rows go red.</p>
Method TestASourceControlledNamespaceRefusesEveryWrite()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "PoolSize", "3", "held"), "the probe setting is held")
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_SystemDefaultConfig", "READ"), $ListBuild("%Ens_SystemDefaultConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Kill tList
    Set tList("namespace") = "USER"
    Set tSC = $ClassMethod(tSeam, "Invoke", "DefaultSettings", "LIST", .tList, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list is readable under source control")
    For tWrite = $ListBuild("ADDDEFAULT", "Fresh", {"Value": "v"}), $ListBuild("SETDEFAULT", "PoolSize", {"Value": "4"}), $ListBuild("REMOVEDEFAULT", "PoolSize", "") {
        Set tHttp = ..Through($List(tWrite, 1), $List(tWrite, 2), $List(tWrite, 3), .tFault, .tRow, "USER", tSeam)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.DEFAULTSETTING.SOURCECONTROL", $List(tWrite, 1) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("DEFAULTSETTINGSOURCECONTROL"), "with the published sentence")
    }
    For tAction = "ADDDEFAULT", "SETDEFAULT", "REMOVEDEFAULT" {
        Set tHttp = ..Through("DEFAULTSETTING", "PoolSize", "", .tFault, .tRow, "USER", tSeam, tAction)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.DEFAULTSETTING.SOURCECONTROL", "the read composed for " _ tAction _ " is refused too")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|held|0", "nothing was written")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
    Do $ClassMethod(tSeam, "Disarm")
}

/// <p>AC2: a caller who holds the restricted-UI resource and not the <code>%All</code> role is refused <code>RESTRICTED</code> for the
/// setting <code>*</code> and for a setting they hold no resource for, and a caller who also holds <code>%All</code> writes both. Driven
/// through a seam that answers whether the caller holds the role (<class>OcuPilot.Test.InteropDefaultSettingRoleSeam</class>).</p>
/// <p>Mutation (Rule 19): drop the <code>HoldsAllRole</code> exemption from <method>OcuPilot.Port.InteropPort.DefaultSettingRestricted</method>
/// -- the <code>%All</code> legs go red.</p>
Method TestACallerHoldingTheAllRoleWritesWhereARestrictedOneIsRefused()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#ROLESEAM
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_SystemDefaultConfig", "READ"), $ListBuild("%Ens_SystemDefaultConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE"), $ListBuild("%Ens_RestrictedUI_SystemDefaultSettings", "USE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do $ClassMethod(tSeam, "Arm", 0)
    For tSetting = "*", "ArchiveIOProbe" {
        Do $$$AssertEquals(..Verdict("ADDDEFAULT", tSetting, {"Value": "4"}, "USER", tSeam), "403 INTEROP.DEFAULTSETTING.RESTRICTED", "a restricted caller without the role is refused the setting " _ tSetting)
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION), 0, "and nothing was written")
    Do $ClassMethod(tSeam, "Arm", 1)
    For tSetting = "*", "ArchiveIOProbe" {
        Do $$$AssertEquals(..Verdict("ADDDEFAULT", tSetting, {"Value": "4"}, "USER", tSeam), "200 ", "the same caller holding the role writes the setting " _ tSetting)
        Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", tSetting), "4||0", "and it is stored: " _ tSetting)
    }
}

/// <p>AC2: the gate, as real principals in a child process, refuses before any vendor call and writes nothing: a caller without
/// <code>%Ens_SystemDefaultConfig:WRITE</code> is refused 403 naming that pair; the setting <code>Enabled</code> without
/// <code>%Ens_ConfigItemRun:USE</code>, and a restricted caller's write of a setting they hold no resource for or of <code>*</code>, are
/// refused 403 <code>INTEROP.DEFAULTSETTING.RESTRICTED</code>, while a restricted caller writes the setting whose resource they hold; a caller
/// who cannot read the other namespace is refused the comparison naming the database pair.</p>
/// <p>Mutation (Rule 19): drop the <code>Enabled</code> rule from <method>OcuPilot.Port.InteropPort.DefaultSettingRestricted</method> -- the
/// <code>OcuP2415NoRun</code> caller's <code>addEnabled</code> leg goes red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "the default setting gate")
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tRestricted = "403|INTEROP.DEFAULTSETTING.RESTRICTED|"
    Set tWrite = "403|" _ tDeny _ "|%Ens_SystemDefaultConfig:WRITE"
    Set tOk = "200||"
    Set tUserWrite = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tUserRead = "403|" _ tDeny _ "|%DB_USER:READ"
    Set tExpected("OcuP2415Exact") = $ListBuild(tOk, tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2415NoWrite") = $ListBuild(tWrite, tWrite, tWrite, tWrite, tOk, tOk)
    Set tExpected("OcuP2415NoRun") = $ListBuild(tOk, tRestricted, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2415Restricted") = $ListBuild(tRestricted, tRestricted, tRestricted, tRestricted, tOk, tOk)
    Set tExpected("OcuP2415Own") = $ListBuild(tRestricted, tRestricted, tRestricted, tOk, tOk, tOk)
    Set tExpected("OcuP2415NoUser") = $ListBuild(tUserWrite, tUserWrite, tUserWrite, tUserWrite, tUserRead, tUserRead)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), tUser _ ": the probe settings are cleared")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutDefault", ..#PRODUCTION, "*", "*", "PoolSize", "3", "held"), tUser _ ": the held setting is arranged")
        Set tOut = ..ProbeAs(tUser)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tAdded = 0
        Set tSetGot = ""
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If (tI <= 3) && (tGot = tOk) Set tAdded = tAdded + 1
            If tLegName = "setPool" Set tSetGot = tGot
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION), 1 + tAdded, tUser _ ": only the admitted adds were stored")
        If tSetGot '= tOk Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|held|0", tUser _ ": the refused set left the held setting as arranged")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropDefaultSettingRefusals).Probe($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter> through
/// <class>OcuPilot.Port.InteropPort</class>, and signal <code>{loggedIn, username, "&lt;leg&gt;": {http, code, failedPair}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tSpec = $Piece(..#LEGS, ",", tI)
            Set tName = $Piece(tSpec, "|", 1)
            Set tType = $Piece(tSpec, "|", 2)
            Set tSetting = $Piece(tSpec, "|", 3)
            Kill tQuery
            Set tQuery("namespace") = $Piece(tSpec, "|", 4)
            Set tBody = ""
            If tType = "LIST" {
                Set tEndpoint = "DefaultSettingsDiff"
                Set tQuery("target") = $Piece(tSpec, "|", 5)
            } Else {
                Set tEndpoint = "DefaultSettings"
                Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, "*", "*", tSetting))
                Set tBody = {"Value": "4"}
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke(tEndpoint, tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tName, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>AC4: the comparison refuses its target before any read: the route's own namespace, a namespace that runs no interoperability
/// (<code>%SYS</code>, naming it) and one the instance does not know are refused, and nothing is read or written.</p>
/// <p>Mutation (Rule 19): drop the same-namespace test from <method>OcuPilot.Port.InteropPort.ListDefaultSettingDiff</method> -- the same-namespace
/// leg goes red.</p>
Method TestTheComparisonRefusesItsTargetBeforeAnyRead()
{
    For tCase = $ListBuild("USER", "400 PORT.VALIDATION"), $ListBuild("user", "400 PORT.VALIDATION"), $ListBuild("", "400 PORT.VALIDATION"), $ListBuild("%SYS", "409 INTEROP.NAMESPACE"), $ListBuild("NOSUCHNS", "409 INTEROP.NAMESPACE") {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("target") = $List(tCase, 1)
        Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettingsDiff", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), $List(tCase, 2), "the target '" _ $List(tCase, 1) _ "' is refused")
        If $List(tCase, 1) = "%SYS" Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("namespace"), 1: ""), "%SYS", "naming the namespace refused")
    }
}

}
