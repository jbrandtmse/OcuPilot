/// <p>Pins Story 20.3's refusals end to end against a probe production in <code>USER</code> (AD-12, AD-39,
/// AD-54, AD-55, AD-62): each state the vendor would answer as a silent success, or refuse, is refused by its
/// own 409 code with the published sentence before any vendor call, from the screen and at the agent's
/// mint; a name the production holds in any letter case is taken, and a name it holds twice is ambiguous; an
/// add the rules refuse is 422 with every violation named; an item whose class the vendor types as no business
/// host is absent to an enable and a disable; a Save in a namespace that runs no interoperability is refused by
/// the port's gate; and every refusal leaves the items as they were.</p>
/// <p>It shares <class>OcuPilot.Test.InteropItemControl</class>'s helpers and its probe. <b>What it needs
/// from the environment:</b> the same as that class, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it compiles and <b>runs a probe production in <code>USER</code></b> and writes
/// one system default setting there, which it removes. One class per run.</p>
Class OcuPilot.Test.InteropItemRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter OFF = "OcuPilotProbeOff";

Parameter ROUTER = "OcuPilotProbeRouter";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemRefusals compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals.</p>
Method OnAfterAllTests() As %Status
{
    Do ..RemoveDefault()
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..RemoveDefault()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The probe is stopped, its items as they began, its system default removed and its proposals removed,
/// whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..RemoveDefault()
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left stopped with its items as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>One row action as <code>status code</code>; the answer's <code>reason</code> in <var>pReason</var>.</p>
ClassMethod Act(pAction As %String, pName As %String, Output pReason As %String) As %String
{
    Set tText = $ClassMethod(..#CONTROL, "Act", pAction, pName, .tAnswer)
    Set pReason = $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: "")
    Quit tText
}

/// <p>The system default setting that decides the probe operation's <code>Enabled</code>, stored in
/// <code>USER</code> when <var>pValue</var> is given.</p>
ClassMethod PutDefault(pValue As %String) As %Status
{
    ; Only vendor classes resolve once the namespace is switched, so the names are read first.
    Set tProduction = $Parameter(..#CONTROL, "PRODUCTION")
    Set tItem = $Parameter(..#CONTROL, "OPNAME")
    Set tClass = $Parameter(..#CONTROL, "OPCLASS")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tDefault = ##class(Ens.Config.DefaultSettings).%New()
        Set tDefault.ProductionName = tProduction
        Set tDefault.ItemName = tItem
        Set tDefault.HostClassName = tClass
        Set tDefault.SettingName = "Enabled"
        Set tDefault.SettingValue = pValue
        Set tSC = tDefault.%Save()
        Set tDefault = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every system default setting this class stored for the probe production.</p>
ClassMethod RemoveDefault()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        &sql(DELETE FROM Ens_Config.DefaultSettings WHERE ProductionName = 'OcuPilotProbe.Interop.Production')
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>AC3: enabling an enabled item, disabling a disabled one and removing an enabled one are each refused 409
/// by their own code and sentence, an item the production does not hold is 404, and the items and the
/// vendor's audit trail are as they were.</p>
/// <p>Mutation (Rule 19): drop the <code>ENABLEDREMOVE</code> refusal from
/// <method>OcuPilot.Port.InteropPort.ItemRefusalToken</method> -- the vendor would remove an enabled item and
/// the remove rows go red.</p>
Method TestAStateTheActionDoesNotFitIsRefusedByItsCode()
{
    Set tE = ..#ERROR
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#OFF, $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "a disabled item is added to the stored configuration")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tCase = $ListBuild("enable", $Parameter(..#CONTROL, "OPNAME"), "ITEMENABLED"), $ListBuild("disable", ..#OFF, "ITEMDISABLED"), $ListBuild("remove", $Parameter(..#CONTROL, "OPNAME"), "ITEMENABLEDREMOVE") {
        Set tText = ..Act($List(tCase, 1), $List(tCase, 2), .tReason)
        Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, $List(tCase, 3)) _ "|" _ $Parameter(tE, "REASON" _ $List(tCase, 3)), $List(tCase, 1) _ " of " _ $List(tCase, 2) _ " is refused")
    }
    Do $$$AssertEquals(..Act("disable", "OcuPilotProbeNoSuch", .tReason), "404 PORT.NOTFOUND", "an item the production does not hold is not found")
    Set tBody = {"action": "disable"}
    Do tBody.%Set("id", "OcuPilotProbe.No.Such" _ $Char(1) _ "Op", "string")
    Set tSC = $ClassMethod(..#CONTROL, "Call", "POST", "/screens/interop.items/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "404 PORT.NOTFOUND", "so is a production it does not hold")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ ",OcuPilotProbeOff:0", "the items are as they were")
    Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
    Do $$$AssertEquals(tAudit, "", "and the vendor audited nothing: " _ tAudit)
}

/// <p>AC3: the agent is refused the same at the mint, with the same code and nothing stored: an enable of an
/// enabled item, a disable of a disabled one and a remove of an enabled one.</p>
Method TestTheMintRefusesWhatTheScreenRefuses()
{
    Set tE = ..#ERROR
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#OFF, $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "a disabled item is added to the stored configuration")
    For tCase = $ListBuild("InteropItemEnable", $Parameter(..#CONTROL, "OPNAME"), "ITEMENABLED"), $ListBuild("InteropItemDisable", ..#OFF, "ITEMDISABLED"), $ListBuild("InteropItemRemove", $Parameter(..#CONTROL, "OPNAME"), "ITEMENABLEDREMOVE") {
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ $List(tCase, 1), $ClassMethod(..#CONTROL, "ArgsFor", $List(tCase, 2)), tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(tE, $List(tCase, 3)), $List(tCase, 1) _ " of " _ $List(tCase, 2) _ " is refused at the mint")
        Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing is minted")
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ ",OcuPilotProbeOff:0", "the items are as they were")
}

/// <p>AC3: a system default that supplies an item's <code>Enabled</code> makes the list read it with source
/// <code>default</code> and refuses an enable and a disable by <code>DEFAULTSETTING</code>, and a remove of an
/// item the default keeps enabled by the same code; a business process
/// whose pool size is 0 cannot be disabled (<code>POOLZERO</code>) but a business service with pool size 0
/// can be, and nothing changes in any of them.</p>
/// <p>Mutation (Rule 19): drop the <code>DEFAULTSETTING</code> refusal from
/// <method>OcuPilot.Port.InteropPort.ItemRefusalToken</method> -- the default rows go red.</p>
Method TestADefaultSettingAndAPoolZeroProcessAreRefused()
{
    Set tE = ..#ERROR
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK(..PutDefault(0), "a system default sets the probe operation's Enabled to 0")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", $Parameter(..#CONTROL, "OPNAME"))
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "Items", "ITEM", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): +tRow.Enabled _ "|" _ tRow.EnabledSource, 1: "unread " _ $Get(tHttp)), "0|default", "the item reads disabled, from the default")
    Set tText = ..Act("enable", $Parameter(..#CONTROL, "OPNAME"), .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMDEFAULTSETTING") _ "|" _ $Parameter(tE, "REASONITEMDEFAULTSETTING"), "an enable is refused: the default decides")
    Set tText = ..Act("disable", $Parameter(..#CONTROL, "OPNAME"), .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMDISABLED") _ "|" _ $Parameter(tE, "REASONITEMDISABLED"), "a disable of what the default already disables is refused as disabled")
    Do ..RemoveDefault()
    Do $$$AssertStatusOK(..PutDefault(1), "a system default sets the probe operation's Enabled to 1")
    Set tText = ..Act("disable", $Parameter(..#CONTROL, "OPNAME"), .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMDEFAULTSETTING") _ "|" _ $Parameter(tE, "REASONITEMDEFAULTSETTING"), "a disable is refused: the default decides")
    Set tText = ..Act("enable", $Parameter(..#CONTROL, "OPNAME"), .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMENABLED") _ "|" _ $Parameter(tE, "REASONITEMENABLED"), "an enable of what the default already enables is refused as enabled")
    Set tText = ..Act("remove", $Parameter(..#CONTROL, "OPNAME"), .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMDEFAULTSETTING") _ "|" _ $Parameter(tE, "REASONITEMDEFAULTSETTING"), "a remove of what the default keeps enabled names the default, which a disable cannot change")
    Do ..RemoveDefault()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#ROUTER, "EnsLib.MsgRouter.RoutingEngine", 0, 1), "a business process with pool size 0 is added to the stored configuration")
    Set tText = ..Act("disable", ..#ROUTER, .tReason)
    Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMPOOLZERO") _ "|" _ $Parameter(tE, "REASONITEMPOOLZERO"), "its disable is refused")
    Set tText = ..Act("disable", "OcuPilotProbeSvc", .tReason)
    Do $$$AssertEquals(tText, "200 ", "while a business service with pool size 0 can be disabled: " _ tReason)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "StoredEnabled", ..#ROUTER) _ "|" _ $ClassMethod(..#CONTROL, "StoredEnabled", "OcuPilotProbeOp"), "1|1", "no refused write changed the process or the defaulted operation")
}

/// <p>AC3, AD-54: an add of a name the production holds, in any letter case, is 409 <code>TAKEN</code> from
/// the Save and at the agent's mint; a name it holds twice refuses an enable, a disable and a remove by
/// <code>AMBIGUOUS</code> from the screen and at the mint, and so does the item read asked for no action; both
/// rows still list.</p>
/// <p>Mutation (Rule 19): drop the <code>TAKEN</code> test from
/// <method>OcuPilot.Port.InteropPort.ReadItem</method> -- the Save and mint rows go red; drop its
/// <code>AMBIGUOUS</code> test for a read with no action -- the read row goes red.</p>
Method TestATakenNameAndADuplicatedNameAreRefused()
{
    Set tE = ..#ERROR
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tOp = $Parameter(..#CONTROL, "OPNAME")
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op"}
    For tName = tOp, $ZConvert(tOp, "L"), $ZConvert(tOp, "U") {
        Set tText = $ClassMethod(..#CONTROL, "Save", tName, tFields, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ $Parameter(tE, "ITEMTAKEN") _ "|" _ $Parameter(tE, "REASONITEMTAKEN"), "a Save of '" _ tName _ "' is taken")
    }
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", $ZConvert(tOp, "L"))
    Do tArgs.%Set("ClassName", "OcuPilotProbe.Interop.Op", "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropItemAdd", tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(tE, "ITEMTAKEN"), "the agent's add of the lower-case name is taken at the mint")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE"), "no refused add stored an item")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", tOp, $Parameter(..#CONTROL, "OPCLASS"), 1, 1), "a second item of that name is stored")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", tOp)
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "Items", "ITEM", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(tE, "ITEMAMBIGUOUS"), "the item read of the duplicated name, asked for no action, is ambiguous")
    For tAction = "enable", "disable", "remove" {
        Set tText = ..Act(tAction, tOp, .tReason)
        Do $$$AssertEquals(tText _ "|" _ tReason, "409 " _ $Parameter(tE, "ITEMAMBIGUOUS") _ "|" _ $Parameter(tE, "REASONITEMAMBIGUOUS"), tAction _ " of the duplicated name is ambiguous")
    }
    For tTool = "InteropItemEnable", "InteropItemDisable", "InteropItemRemove" {
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ tTool, $ClassMethod(..#CONTROL, "ArgsFor", tOp), tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ $Parameter(tE, "ITEMAMBIGUOUS"), tTool _ " of the duplicated name is ambiguous at the mint")
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ ",OcuPilotProbeOp:1", "both rows still list and neither changed")
}

/// <p>AC3, AD-55: an add the rules refuse is 422 carrying every violation, the first one's code and sentence
/// at the top: an illegal name, a class that is no business host or does not exist, and a value the item
/// refuses; a key the Save does not settle is 400 <code>PORT.FIELD.UNEXPECTED</code>, a production the
/// namespace does not hold is 404, and the agent's mint refuses the same rules as <code>TOOL.ARGUMENTS</code>.
/// Nothing is stored.</p>
/// <p>Mutation (Rule 19): drop the name rule from <method>OcuPilot.Port.InteropPort.NameProblem</method>
/// -- the name rows go red.</p>
Method TestAnAddTheRulesRefuseIsRefusedWithItsViolations()
{
    Set tE = ..#ERROR
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tOpClass = $Parameter(..#CONTROL, "OPCLASS")
    For tCase = $ListBuild("-bad", tOpClass, 1, "Name", "ITEMNAME"), $ListBuild("OcuPilotProbeNew", "No.Such.Class", 1, "ClassName", "ITEMCLASS"), $ListBuild("OcuPilotProbeNew", "Ens.Config.Item", 1, "ClassName", "ITEMCLASS"), $ListBuild("OcuPilotProbeNew", tOpClass, -1, "PoolSize", "ITEMVALUE") {
        Set tFields = {}
        Do tFields.%Set("ClassName", $List(tCase, 2), "string")
        Do tFields.%Set("PoolSize", $List(tCase, 3), "number")
        Set tText = $ClassMethod(..#CONTROL, "Save", $List(tCase, 1), tFields, .tAnswer)
        Set tWhat = "'" _ $List(tCase, 1) _ "' of '" _ $List(tCase, 2) _ "' at pool " _ $List(tCase, 3)
        Do $$$AssertEquals(tText, "422 " _ $Parameter(tE, $List(tCase, 5)), "a Save of " _ tWhat _ " is 422 with its code: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.detail.%Get("violations")): tAnswer.detail.violations.%Get(0).field _ "|" _ tAnswer.detail.violations.%Get(0).code, 1: ""), $List(tCase, 4) _ "|" _ $Parameter(tE, $List(tCase, 5)), "naming the field in its violations")
        Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", $List(tCase, 1))
        Do tArgs.%Set("ClassName", $List(tCase, 2), "string")
        Do tArgs.%Set("PoolSize", $List(tCase, 3), "number")
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropItemAdd", tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 TOOL.ARGUMENTS", "the agent's add of " _ tWhat _ " is refused at the mint")
    }
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op", "Unsettled": "x"}
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Save", "OcuPilotProbeNew", tFields, .tAnswer), "400 PORT.FIELD.UNEXPECTED", "a key the Save does not settle is refused")
    Set tBody = {"ClassName": "OcuPilotProbe.Interop.Op", "Production": "OcuPilotProbe.No.Such", "Name": "OcuPilotProbeNew"}
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/items", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "404 PORT.NOTFOUND", "and so is a production the namespace does not hold")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE"), "no refused add stored an item")
}

/// <p>The port's own <code>ADD</code> of <var>pName</var> with <var>pBody</var> in the probe production, with
/// nothing in front of it to judge the fields, as <code>status code field</code> -- the field of the first
/// violation, <code>""</code> when the refusal names none.</p>
ClassMethod PortAdd(pName As %String, pBody As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "Items", "ADD", .tQuery, pBody, .tResult, .tHttp, .tFault)
    Set tCode = ""
    Set tField = ""
    If $IsObject($Get(tFault)) {
        Set tCode = tFault.%Get("code")
        If $IsObject(tFault.%Get("detail")) && $IsObject(tFault.detail.%Get("violations")) Set tField = tFault.detail.violations.%Get(0).field
    }
    Quit +$Get(tHttp) _ " " _ tCode _ " " _ tField
}

/// <p>AC3: the port's own <code>ADD</code> judges an add's fields itself: a <code>PoolSize</code> of the wrong
/// JSON type is 422 <code>PORT.FIELD.SHAPE</code> naming the field, and so is an <code>Enabled</code>, a
/// <code>Category</code> or a <code>Comment</code> of the wrong type; a <code>Comment</code> or a
/// <code>Category</code> longer than the item property holds is 422 <code>INTEROP.ITEM.VALUE</code>, and an
/// illegal name is 422 <code>INTEROP.ITEM.NAME</code>; nothing is stored.</p>
/// <p>Mutation (Rule 19): delete the shape arms (the four <code>PORT.FIELD.SHAPE</code> lines for
/// <code>PoolSize</code>, <code>Category</code>, <code>Comment</code> and <code>Enabled</code>) from
/// <method>OcuPilot.Port.InteropPort.AddViolations</method> -- the four shape rows go red; delete the
/// <code>Enabled</code> line alone -- its row goes red.</p>
Method TestThePortsOwnAddJudgesTheFieldsItself()
{
    Set tE = ..#ERROR
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tClass = $Parameter(..#CONTROL, "OPCLASS")
    Set tNew = "OcuPilotProbeNew"
    Set tBody = {"PoolSize": "many"}
    Do tBody.%Set("ClassName", tClass, "string")
    Do $$$AssertEquals(..PortAdd(tNew, tBody), "422 " _ tShape _ " PoolSize", "a PoolSize that is no number is a shape violation naming it")
    For tCase = $ListBuild("Enabled", "{""Enabled"": ""yes""}"), $ListBuild("Category", "{""Category"": 5}"), $ListBuild("Comment", "{""Comment"": true}") {
        Set tBody = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do tBody.%Set("ClassName", tClass, "string")
        Do $$$AssertEquals(..PortAdd(tNew, tBody), "422 " _ tShape _ " " _ $List(tCase, 1), "an " _ $List(tCase, 1) _ " of the wrong type is a shape violation naming it")
    }
    Set tBody = {}
    Do tBody.%Set("ClassName", tClass, "string")
    Do tBody.%Set("Comment", $Translate($Justify("", 2001), " ", "x"), "string")
    Do $$$AssertEquals(..PortAdd(tNew, tBody), "422 " _ $Parameter(tE, "ITEMVALUE") _ " Comment", "a Comment over the property's 2000 characters is a value violation")
    Set tBody = {}
    Do tBody.%Set("ClassName", tClass, "string")
    Do tBody.%Set("Category", $Translate($Justify("", 2501), " ", "x"), "string")
    Do $$$AssertEquals(..PortAdd(tNew, tBody), "422 " _ $Parameter(tE, "ITEMVALUE") _ " Category", "a Category over the property's 2500 characters is a value violation")
    Set tBody = {}
    Do tBody.%Set("ClassName", tClass, "string")
    Do $$$AssertEquals(..PortAdd("-bad", tBody), "422 " _ $Parameter(tE, "ITEMNAME") _ " Name", "an illegal name reaches the port's own violation branch")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE"), "no refused add stored an item")
}

/// <p>AC3: an item whose class the vendor types as no business host (a class no longer compiled) is not found by
/// the vendor's enable and disable, so both answer 404 <code>PORT.NOTFOUND</code>, unlogged, through the row
/// action and the port, rather than the vendor's failure as a logged 500; it still lists, as <code>unknown</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.VendorCannotFind</method> answer 0 -- the port
/// row answers 500 and the action row answers 500, and both go red.</p>
Method TestAnItemTheVendorCannotTypeIsAbsentToAnEnableAndADisable()
{
    Set tGhost = "OcuP203Ghost"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", tGhost, "OcuPilotProbe.No.Such.Class", 1, 0), "an item whose class does not exist is stored, disabled")
    Do $$$AssertEquals(..Act("enable", tGhost, .tReason), "404 PORT.NOTFOUND", "its Enable is not found")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", tGhost)
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "Items", "ENABLE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 PORT.NOTFOUND", "and so is the port's enable")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ "," _ tGhost _ ":0", "nothing changed")
}

/// <p>AC3, AD-62: a Save scoped to a namespace that runs no interoperability (<code>%SYS</code>) is refused 409
/// <code>INTEROP.NAMESPACE</code> by the port's gate, and the port's own add rules there judge only what needs no
/// vendor class, so neither calls into a namespace the gate does not admit.</p>
/// <p>Mutation (Rule 19): drop the <code>Admit</code> check from
/// <method>OcuPilot.Port.InteropPort.AddViolations</method> -- the Save answers 500 and the rules row errors, and
/// both go red.</p>
Method TestASaveInANamespaceWithoutInteroperabilityIsRefusedByTheGate()
{
    Set tBody = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
    Do tBody.%Set("Production", $Parameter(..#CONTROL, "PRODUCTION"), "string")
    Do tBody.%Set("Name", "OcuP203Elsewhere", "string")
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/items?ns=%25SYS"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json", .tExtra, 120)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tCode = "" }
    Do $$$AssertEquals($Get(tStatus) _ " " _ tCode, "409 " _ $Parameter(..#ERROR, "NAMESPACE"), "the Save in %SYS is refused by the namespace: " _ $Extract($Get(tRaw), 1, 300))
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "AddViolations", "%SYS", "OcuP203Elsewhere", {"ClassName": "OcuPilotProbe.Interop.Op"}, .tViolations)
    Do $$$AssertStatusOK(tSC, "the port's add rules in %SYS raise nothing")
    Do $$$AssertEquals(+$Get(tViolations), 0, "and judge no vendor rule there")
}

}
