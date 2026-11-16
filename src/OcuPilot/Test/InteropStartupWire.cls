/// <p>Pins Story 24.3's two startup writes over the real routes as real least-privileged principals (AD-8, AD-29, AD-53, AD-62): a principal
/// holding exactly the classic pages' pairs -- <code>%Ens_Portal:USE</code>, <code>%Ens_ProductionConfig:RW</code>,
/// <code>%Admin_Manage:USE</code> and <code>%DB_USER:RW</code> -- sets auto-start and the shutdown group of a stopped and of a running
/// production through <code>POST /screens/interop.productions/action</code> and by confirming the agent's proposals over
/// <code>POST /proposal/{id}/confirm</code>, each audited under that principal's name; a principal missing a pair is refused 403 naming
/// it from the row action and from the confirm, with the vendor's startup state unchanged; and with a second interoperability namespace
/// registered whose settings the principal cannot read, a group or priority change is refused 403 <code>INTEROP.STARTUP.ALLNAMESPACES</code>
/// from both callers while turning auto-start on at the read's priority is admitted.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP, an
/// interoperability-enabled <code>USER</code> namespace and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// compiles and starts the probe productions in <code>USER</code>, creates four users and roles named <code>OcuPQA243*</code> and, for one
/// test, registers <code>HSSYS</code> as a second interoperability namespace. Each principal also holds READ on the install namespace's
/// code database and <code>%Development:USE</code>, as every caller of a route must. Each test puts <code>USER</code>'s startup settings
/// back and the principals are removed after the last test. One class per run.</p>
Class OcuPilot.Test.InteropStartupWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter CONTROL = "OcuPilot.Test.InteropStartupControl";

Parameter ITEMCONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "/screens/interop.productions";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OTHER = "OcuPilotProbe.Interop.Other";

/// <p>The namespace registered as a second interoperability one, whose settings a principal without its database cannot read.</p>
Parameter SECONDNAMESPACE = "HSSYS";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>:
/// exactly the classic pages' set, then one missing the shutdown group's pair, one missing auto-start's and one missing WRITE on
/// <code>USER</code>'s database.</p>
Parameter PRINCIPALS = "OcuPQA243Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%Admin_Manage:U,%DB_USER:RW;OcuPQA243NoManage:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuPQA243NoConfigWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Admin_Manage:U,%DB_USER:RW;OcuPQA243NoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%Admin_Manage:U,%DB_USER:R";

Property PreparedPassword As %String;

Property PreparedStartup As %List;

/// <p>Whether <parameter>SECONDNAMESPACE</parameter> was registered when the test began, and whether this test registered it.</p>
Property PreparedRegistered As %Boolean;

Property AddedRegistration As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedStartup = ""
    Set ..PreparedRegistered = 0
    Set ..AddedRegistration = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupWire compiles and starts probe productions in USER, sets its startup settings and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPQA243" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set ..PreparedStartup = $ClassMethod(..#PROBE, "SaveStartup")
    If ..PreparedStartup = "" Quit $$$ERROR($$$GeneralError, "USER's startup settings could not be read")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe, the principals and their roles, and any registration this class added; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Unregister()
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "USER's startup settings read as they did before the class ran")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Gone"), "and the probe holds nothing")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupWire left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set ..PreparedRegistered = ''$Data(^%SYS("Ensemble", "InstalledNamespace", ..#SECONDNAMESPACE))
    Set ..AddedRegistration = 0
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do ..Unregister()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreStartup", ..PreparedStartup), "USER's startup settings are put back")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "and read as they did before the test")
    Do $$$AssertEquals(''$Data(^%SYS("Ensemble", "InstalledNamespace", ..#SECONDNAMESPACE)), ..PreparedRegistered, "and the second namespace is registered as it was before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Register <parameter>SECONDNAMESPACE</parameter> as an interoperability namespace unless it already is, and note that this test
/// added it (<method>OcuPilot.Test.ProductionProbe.RegisterNamespace</method>).</p>
Method Register()
{
    If $ClassMethod(..#PROBE, "RegisterNamespace", ..#SECONDNAMESPACE) Set ..AddedRegistration = 1
}

/// <p>Remove the registration only when <method>Register</method> added it.</p>
Method Unregister()
{
    Do $ClassMethod(..#PROBE, "UnregisterNamespace", ..#SECONDNAMESPACE, ..AddedRegistration)
    Set ..AddedRegistration = 0
}

/// <p>One request over the wire as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>: the status in <var>pStatus</var> and the
/// parsed answer, or the raw text when it is not one JSON document, in <var>pAnswer</var>.</p>
Method As(pUser As %String, pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set pAnswer = ""
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, 120)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>The row action <var>pAction</var> on the probe production with <var>pValues</var>, as <var>pUser</var>: <code>status code failedPair</code>,
/// the answer in <var>pAnswer</var>.</p>
Method Act(pUser As %String, pAction As %String, pValues As %DynamicObject, Output pAnswer) As %String
{
    Do ..As(pUser, "POST", ..#SCREEN _ "/action", {"action": (pAction), "id": (..#PRODUCTION), "values": (pValues)}, .tStatus, .pAnswer)
    Quit tStatus _ " " _ ..CodeOf(pAnswer)
}

/// <p>The code and, when it names one, the failed pair of an answer: <code>&lt;code&gt; &lt;failedPair&gt;</code>.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    If '$IsObject(pAnswer) Quit ""
    Set tPair = ""
    If $IsObject(pAnswer.%Get("detail")) Set tPair = pAnswer.detail.%Get("failedPair")
    Quit pAnswer.%Get("code") _ $Select(tPair '= "": " " _ tPair, 1: "")
}

/// <p>Mint the agent's call of <var>pTool</var> for <var>pUser</var> and confirm it over the wire as <var>pConfirmer</var>:
/// <code>status code failedPair</code>, the answer in <var>pAnswer</var>, the proposal's turn in <var>pTurn</var>. <code>unminted</code> when it
/// did not mint.</p>
Method Agent(pTool As %String, pArgs As %DynamicObject, pUser As %String, pConfirmer As %String, Output pAnswer, Output pTurn) As %String
{
    Set tSC = $ClassMethod(..#ITEMCONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, pArgs, pUser, .tProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, pTool _ " mints for " _ pUser _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit "unminted"
    Do ..As(pConfirmer, "POST", "/proposal/" _ tProposal.proposalId _ "/confirm", "", .tStatus, .pAnswer)
    Quit tStatus _ " " _ ..CodeOf(pAnswer)
}

/// <p>How many <code>ConfigChange</code> rows since <var>pSince</var> record a <code>set</code> of the probe production, the last row's
/// <code>actor</code> in <var>pUser</var> and its data in <var>pData</var>.</p>
ClassMethod Audited(pSince As %String, Output pUser As %String, Output pData As %String) As %Integer
{
    Set pUser = ""
    Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """id"":""" _ ..#PRODUCTION _ """", .pData, """verb"":""set""")
    Try {
        Set pUser = ##class(%DynamicObject).%FromJSON(pData).%Get("actor")
    } Catch {
        Set pUser = "unread"
    }
    Quit tRows
}

/// <p>The vendor's startup state of the probe (<method>OcuPilot.Test.InteropStartupControl.Vendor</method>).</p>
ClassMethod Vendor() As %String
{
    Quit $ClassMethod(..#CONTROL, "Vendor")
}

/// <p>The row of <var>pName</var> in the Productions list as <var>pUser</var> reads it, <code>AutoStart|StartupPriority|ShutdownGroup</code>, or
/// <code>unlisted</code>; the read's status is asserted.</p>
Method ListedAs(pUser As %String, pName As %String) As %String
{
    Do ..As(pUser, "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, pUser _ ": the Productions list reads")
    Set tRow = $ClassMethod(..#CONTROL, "RowIn", $Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: ""), pName)
    If '$IsObject(tRow) Quit "unlisted"
    Quit tRow.AutoStart _ "|" _ tRow.StartupPriority _ "|" _ tRow.ShutdownGroup
}

/// <p>A principal holding exactly the classic pages' pairs sets auto-start and the shutdown group of the probe production, stopped and then
/// running, through the person's row actions: each answers 200 and a matching read-back, the vendor's own state reads each change (the
/// running production's running-namespace value too), the list the principal reads shows it, and each write's <code>ConfigChange</code> row
/// is recorded under the principal's own name.</p>
Method TestAPrincipalWithTheClassicPairsSetsBothOverTheRowActions()
{
    Set tUser = "OcuPQA243Exact"
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Seed", ..#OTHER, 5), "the other production starts with the instance at priority 5")
    Do $$$AssertEquals(..ListedAs(tUser, ..#OTHER) _ ";" _ ..ListedAs(tUser, ..#PRODUCTION), "Yes|5|2;No||2", "the principal reads the list's three fields")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act(tUser, "autostart", {"AutoStart": "1", "StartupPriority": "4"}, .tAnswer)
    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.readBack.verdict, 1: ""), "200 |" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "Start with the instance answers 200 and a matching read-back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Vendor(), ..#PRODUCTION _ "|4|2|2|0", "the vendor's state reads the production at priority 4 in place of the other")
    Do $$$AssertEquals(..ListedAs(tUser, ..#PRODUCTION) _ ";" _ ..ListedAs(tUser, ..#OTHER), "Yes|4|2;No||2", "and the list shows it")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.InteropControl", "StartIt"), "the probe production is started")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AwaitRunning"), "and reads running")
    For tGroup = 3, 2 {
        Set tText = ..Act(tUser, "shutdowngroup", {"ShutdownGroup": (tGroup _ "")}, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.readBack.verdict, 1: ""), "200 |" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "group " _ tGroup _ " of the running production answers 200 and a matching read-back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals($Piece(..Vendor(), "|", 3, 5), tGroup _ "|2|" _ (tGroup '= 2), "group " _ tGroup _ ": the vendor's group reads it")
        Do $$$AssertEquals($Get(^%SYS("Ensemble", "RunningNamespace", ..#NAMESPACE, "SystemShutdownGroup")), tGroup, "group " _ tGroup _ ": and so does the vendor's running-namespace value, written as this principal")
    }
    Do $$$AssertEquals(..Act(tUser, "autostart", {"AutoStart": "0"}, .tAnswer), "200 ", "turning auto-start off answers 200")
    Do $$$AssertEquals(..Vendor(), "||2|2|0", "and no production of USER starts with the instance")
    Do $$$AssertEquals(..Audited(tSince, .tAuditUser, .tData), 4, "four ConfigChange rows of OcuPilot's own, one per write")
    Do $$$AssertEquals(tAuditUser, tUser, "recorded under the principal's own name")
}

/// <p>The agent's proposals, confirmed over the wire by a principal holding exactly the classic pages' pairs, write both settings: each
/// answers 200, marked (AD-15), updated and read back as sent; the vendor reads each change; the proposal is ledgered once; and the
/// <code>ConfigChange</code> row is recorded under the principal's name.</p>
Method TestAnAgentsProposalsConfirmedByAPrincipalWithTheClassicPairsWriteBoth()
{
    Set tUser = "OcuPQA243Exact"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Agent("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "1", "StartupPriority": "6"}, tUser, tUser, .tAnswer, .tTurn)
    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.auditMarked _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "200 |1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "the auto-start proposal confirms 200, marked, updated and read back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(..#ITEMCONTROL, "LedgerCount", tTurn, "interop.productions.autostart"), 1, "ledgered once")
    Do $$$AssertEquals(..Vendor(), ..#PRODUCTION _ "|6|2|2|0", "the vendor's state reads the production at priority 6")
    Set tText = ..Agent("InteropProductionShutdownGroup", {"Name": (..#PRODUCTION), "ShutdownGroup": "3"}, tUser, tUser, .tAnswer, .tTurn)
    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.auditMarked _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "200 |1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "the shutdown-group proposal confirms 200, marked, updated and read back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(..#ITEMCONTROL, "LedgerCount", tTurn, "interop.productions.shutdowngroup"), 1, "ledgered once")
    Do $$$AssertEquals($Piece(..Vendor(), "|", 1, 3), ..#PRODUCTION _ "|6|3", "the vendor reads group 3, the auto-start unchanged")
    Do $$$AssertEquals(..Audited(tSince, .tAuditUser, .tData), 2, "two ConfigChange rows")
    Do $$$AssertEquals(tAuditUser, tUser, "recorded under the principal's own name")
    Do $$$AssertTrue(tData [ "interop.productions.shutdowngroup", "the last names its tool: " _ tData)
}

/// <p>A principal missing a pair is refused 403 <code>AUTH.NOPRIVILEGE</code> naming it: the person's row action answers it for the
/// shutdown group without <code>%Admin_Manage:USE</code>, for auto-start without <code>%Ens_ProductionConfig:WRITE</code> and for both
/// without WRITE on <code>USER</code>'s database, and the confirm of a proposal that principal minted is refused the same way.
/// The vendor's startup state is as it was after every attempt.</p>
Method TestAPrincipalMissingAPairIsRefusedByNameFromBothCallersAndNothingChanges()
{
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Seed", ..#PRODUCTION, 5, 3), "the probe production starts with the instance at priority 5 and is in group 3")
    Set tBefore = ..Vendor()
    Set tAuto = {"AutoStart": "1", "StartupPriority": "6"}
    Set tGroup = {"ShutdownGroup": "2"}
    Do $$$AssertEquals(..Act("OcuPQA243NoManage", "shutdowngroup", tGroup, .tAnswer), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE", "no %Admin_Manage:USE: the shutdown group is refused naming it")
    Do $$$AssertEquals(..Act("OcuPQA243NoConfigWrite", "autostart", tAuto, .tAnswer), "403 AUTH.NOPRIVILEGE %Ens_ProductionConfig:WRITE", "no %Ens_ProductionConfig:WRITE: auto-start is refused naming it")
    Do $$$AssertEquals(..Act("OcuPQA243NoWrite", "autostart", tAuto, .tAnswer), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "no WRITE on USER's database: auto-start is refused naming it")
    Do $$$AssertEquals(..Act("OcuPQA243NoWrite", "shutdowngroup", tGroup, .tAnswer), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "and so is the shutdown group")
    Do $$$AssertEquals(..Vendor(), tBefore, "the vendor's startup state is as it was")
    Set tText = ..Agent("InteropProductionShutdownGroup", {"Name": (..#PRODUCTION), "ShutdownGroup": "2"}, "OcuPQA243NoManage", "OcuPQA243NoManage", .tAnswer, .tTurn)
    Do $$$AssertEquals(tText, "403 AUTH.NOPRIVILEGE %Admin_Manage:USE", "the confirm of a shutdown-group proposal is refused naming the pair: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Set tText = ..Agent("InteropProductionAutoStart", {"Name": (..#PRODUCTION), "AutoStart": "0"}, "OcuPQA243NoConfigWrite", "OcuPQA243NoConfigWrite", .tAnswer, .tTurn)
    Do $$$AssertEquals(tText, "403 AUTH.NOPRIVILEGE %Ens_ProductionConfig:WRITE", "and the confirm of an auto-start proposal is refused naming its pair: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Vendor(), tBefore, "and the vendor's startup state is still as it was")
}

/// <p>With <parameter>SECONDNAMESPACE</parameter> registered as an interoperability namespace the principal cannot read, a shutdown-group
/// change and a priority change from the person's row action, and the confirm of the agent's group proposal, are refused 403
/// <code>INTEROP.STARTUP.ALLNAMESPACES</code> and change nothing, while turning auto-start on at the priority the read answered, and off,
/// is admitted.</p>
Method TestAChangeNeedsEveryNamespacesSettingsOverTheRowActionsAndTheConfirm()
{
    Set tUser = "OcuPQA243Exact"
    Set tAll = ##class(OcuPilot.Api.InteropError).#STARTUPALLNAMESPACES
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Seed", ..#PRODUCTION, 4, 2), "the probe production starts with the instance at priority 4")
    Set tBefore = ..Vendor()
    Do ..Register()
    Do $$$AssertEquals(..Act(tUser, "shutdowngroup", {"ShutdownGroup": "3"}, .tAnswer), "403 " _ tAll, "the shutdown group is refused ALLNAMESPACES: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.InteropError).ReasonFor(tAll), "with the published sentence")
    Do $$$AssertEquals(..Act(tUser, "autostart", {"AutoStart": "1", "StartupPriority": "7"}, .tAnswer), "403 " _ tAll, "a priority change is refused ALLNAMESPACES")
    Set tText = ..Agent("InteropProductionShutdownGroup", {"Name": (..#PRODUCTION), "ShutdownGroup": "3"}, tUser, tUser, .tAnswer, .tTurn)
    Do $$$AssertEquals(tText, "403 " _ tAll, "the confirm of the agent's group proposal is refused ALLNAMESPACES: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Vendor(), tBefore, "and neither refused change was made")
    Do $$$AssertEquals(..Act(tUser, "autostart", {"AutoStart": "0"}, .tAnswer), "200 ", "turning auto-start off is admitted")
    Do $$$AssertEquals(..Act(tUser, "autostart", {"AutoStart": "1", "StartupPriority": "0"}, .tAnswer), "200 ", "and turning it on at the priority the read answered is admitted")
    Do ..Unregister()
    Do $$$AssertEquals(..Act(tUser, "shutdowngroup", {"ShutdownGroup": "3"}, .tAnswer), "200 ", "with the second namespace gone the same group change is admitted")
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ on the install namespace's code
/// database, then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tEntry = $Piece(..#PRINCIPALS, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the startup settings' routes (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot startup settings routes test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropStartupWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuPQA243Exact", "%Admin_Manage", "USE", 1), $ListBuild("OcuPQA243NoManage", "%Admin_Manage", "USE", 0), $ListBuild("OcuPQA243NoConfigWrite", "%Ens_ProductionConfig", "WRITE", 0), $ListBuild("OcuPQA243NoWrite", "%DB_USER", "WRITE", 0) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
