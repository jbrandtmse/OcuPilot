/// <p>Pins Story 16.2 against live web sessions (AD-2, AD-8, AD-26, AD-53, AD-58): the declared
/// read fields held to a live row, <class>OcuPilot.Port.AdminPort</class>'s wait for the daemon, the
/// screen's End session and the agent's confirm each ending a real session, a principal without
/// <code>%DB_IRISSYS:WRITE</code> refused by name, and a holder of the area's pairs alone keeping
/// Web applications while Web sessions is refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, <code>/api/atelier/</code> answering that
/// account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class
/// creates and deletes two users and two roles. Each test seeds its own <code>/api/atelier/</code>
/// session and ends every one it seeded.</p>
Class OcuPilot.Test.WebSessionsLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebSessionList";

Parameter TOOL = "OcuPilot.Screen.Tool.WebSessionEnd";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The application whose request leaves a session behind.</p>
Parameter SEEDPATH = "/api/atelier/";

/// <p>A session id no session carries.</p>
Parameter ABSENT = "OcuNoSessn";

/// <p>The purpose-built principal holding the install namespace's code read and the Web sessions
/// screen's two pairs, and not the write pair.</p>
Parameter OPERATORUSER = "OcuPilotSessionGateOperator";

Parameter OPERATORROLE = "OcuPilotSessionGateOperatorRole";

/// <p>The purpose-built principal holding the code read and the Web applications area's two pairs,
/// and not <code>%Admin_Operate</code>.</p>
Parameter AREAUSER = "OcuPilotSessionGateArea";

Parameter AREAROLE = "OcuPilotSessionGateAreaRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The session ids this test seeded, which its teardown ends.</p>
Property PreparedSeeded As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSeeded = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebSessionsLive creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotSess" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals()
}

/// <p>Remove both principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#OPERATORUSER, ..#AREAUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#OPERATORROLE, ..#AREAROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#OPERATORUSER) || ##class(Security.Users).Exists(..#AREAUSER) || ##class(Security.Roles).Exists(..#OPERATORROLE) || ##class(Security.Roles).Exists(..#AREAROLE) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.WebSessionsLive left a throwaway principal on the instance")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedSeeded = ""
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>End every session this test seeded that is still listed, and assert none is.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$ListLength(..PreparedSeeded) {
        Set tId = $List(..PreparedSeeded, tI)
        If '..Listed(tId) Continue
        Kill tQuery
        Set tQuery("id") = tId
        Do ##class(OcuPilot.Port.AdminPort).Invoke("WebSession", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Listed(tId), 0, "a seeded session is ended in teardown")
    }
    Set ..PreparedSeeded = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The Web sessions list's fields are the live row's keys, and the seeded session reads back
/// through the screen's read as its user, its application, no process and an expiry later than now
/// in UTC -- the column the screen heads "Expires (UTC)".</p>
/// <p>Mutation (Rule 19): declare <code>Expires</code> in place of <code>Timeout</code> in the
/// descriptor's read -- the key leg goes red.</p>
Method TestTheDeclaredFieldsAreTheLiveRowsKeys()
{
    Set tSC = ..Seed(.tId)
    Do $$$AssertStatusOK(tSC, "a session is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tRow = ..LiveRow(tId)
    Do $$$AssertTrue($IsObject(tRow), "the vendor's list carries it")
    If '$IsObject(tRow) Quit
    Set tFields = $ClassMethod(..#SCREEN, "Read").%Get("fields")
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Do $$$AssertTrue(tRow.%IsDefined(tField), "declared read field '" _ tField _ "' is a key of the live row")
    }
    Set tContext = $ClassMethod(..#SCREEN, "ContextFields")
    For tI = 1:1:$ListLength(tContext) {
        Do $$$AssertTrue(tRow.%IsDefined($List(tContext, tI)), "context field '" _ $List(tContext, tI) _ "' is a key of the live row")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/webapp.sessions/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Set tFound = ""
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) {
        Set tIterator = tRead.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.%Get("ID") = tId Set tFound = tEntry
        }
    }
    Do $$$AssertTrue($IsObject(tFound), "and lists the seeded session")
    If '$IsObject(tFound) Quit
    Do $$$AssertEquals(tFound.%Get("Username") _ " " _ tFound.%Get("Application") _ " [" _ tFound.%Get("SesProcessId") _ "]", ##class(OcuPilot.Test.Http).GetTestUsername() _ " " _ ..#SEEDPATH _ " []", "as its user, its application and no process of its own")
    Do $$$AssertTrue(tFound.%Get("Timeout") ]] $ZDateTime($ZTimeStamp, 3, 1), "expiring later than now in UTC: " _ tFound.%Get("Timeout"))
}

/// <p>AD-26: the vendor only marks a session, so the port's <code>DELETE</code> returns once the
/// list no longer carries it; an id no session carries answers 404, and the vendor's refusal, which
/// quotes that id, is logged without it.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AdminPort.AwaitGone</method> in
/// <method>OcuPilot.Port.AdminPort.InvokeLocated</method> -- the list still carries the id when the
/// call returns and this goes red; empty <parameter>OcuPilot.Port.AdminPort.UNLOGGEDQUERY</parameter>
/// -- the logged line carries the id and the log leg goes red.</p>
Method TestThePortReturnsOnceTheSessionIsGone()
{
    Set tSC = ..Seed(.tId)
    Do $$$AssertStatusOK(tSC, "a session is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("id") = tId
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebSession", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port ends it: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp \ 100, 2, "with a 2xx")
    Do $$$AssertEquals(..Listed(tId), 0, "and when the call returns the list no longer carries it")

    ; Through the shipped port with its log recorded rather than written, since the vendor's 404
    ; quotes the id it was sent.
    Kill tQuery
    Set tQuery("id") = ..#ABSENT
    Do ##class(OcuPilot.Test.X509LogPort).Taken()
    Set tSC = ##class(OcuPilot.Test.X509LogPort).Invoke("WebSession", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "an id no session carries answers 404")
    Set tLogged = ##class(OcuPilot.Test.X509LogPort).Taken()
    Do $$$AssertTrue((tLogged [ "HTTP 404") && '(tLogged [ ..#ABSENT), "and the vendor's refusal is logged without the id it quotes: " _ tLogged)
}

/// <p>AC2, AD-53, AD-58: the screen's End session ends a seeded session -- 200, the deleted change
/// event's triple, a read-back that finds it gone -- and its case twin is not found.</p>
Method TestTheScreenActionEndsASeededSession()
{
    Set tSC = ..Seed(.tId)
    Do $$$AssertStatusOK(tSC, "a session is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tTwin = $Translate(tId, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    If (tTwin '= tId) && '..Listed(tTwin) {
        Set tSC = ..Act(tTwin, "", "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the id's case twin is not found")
        Do $$$AssertEquals(..Listed(tId), 1, "and the session is still listed")
    }
    Set tSC = ..Act(tId, "", "", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the route answers")
    Do $$$AssertEquals(tStatus, 200, "the screen's End session answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("action") _ " " _ tBody.%Get("target").%ToJSON(), "deleted {""type"":""web-session"",""scope"":""instance"",""id"":""" _ tId _ """}", "publishing the deleted event for the session")
    Do $$$AssertEquals(tBody.%Get("readBack").%Get("verdict"), "notFound", "whose read-back finds it gone")
    Do $$$AssertEquals(..Listed(tId), 0, "and the list no longer carries it")
}

/// <p>AC2, AD-15: the agent's proposal lists the session as removed, and its confirm ends it and
/// lands the agent marker.</p>
Method TestTheAgentsConfirmEndsASeededSession()
{
    Set tSC = ..Seed(.tId)
    Do $$$AssertStatusOK(tSC, "a session is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {}
    Do tArgs.%Set("ID", tId, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), tId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the end mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("removed") Set tFields = tFields _ $ListBuild(tRow.%Get("field"))
    }
    Do $$$AssertEquals($ListToString(tFields), "Username,Application,SesProcessId,Timeout", "the card lists the user, application, process and expiry as removed")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm ends it: " _ $Get(tCode))
    Do $$$AssertEquals(..Listed(tId), 0, "and the list no longer carries it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurn, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC4, AD-8: a principal holding the screen's pairs and not <code>%DB_IRISSYS:WRITE</code>
/// reads the list, and its End session is refused 403 naming that pair, with the session still
/// listed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.WebSessionEnd.PrivilegePairs</method>
/// answer the list's pairs alone -- the vendor refuses inside the port instead and the named-pair
/// leg goes red.</p>
Method TestAPrincipalWithoutTheWritePairIsRefusedByName()
{
    Set tSC = ..Seed(.tId)
    Do $$$AssertStatusOK(tSC, "a session is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/webapp.sessions/read?maxRows=5", ..#OPERATORUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the principal reads the list")
    Set tSC = ..Act(tId, ..#OPERATORUSER, ..PreparedPassword, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE", "its End session is refused naming the write pair")
    Do $$$AssertEquals(..Listed(tId), 1, "and the session is still listed")
}

/// <p>AD-8's own-pair case: a holder of the Web applications area's two pairs alone keeps the area,
/// its list and the REST API explorer, while Web sessions is shown and refused on
/// <code>%Admin_Operate:USE</code>.</p>
/// <p>Mutation (Rule 19): move <code>%Admin_Operate:USE</code> from the descriptor's
/// <code>ownPrivileges</code> into the area's pairs -- the area reads denied and this goes red.</p>
Method TestAnAreaHolderKeepsTheAreaAndIsRefusedWebSessions()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#AREAUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Set tArea = ""
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("areas").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.%Get("key") = "web-applications" Set tArea = tEntry
        }
    } Catch {}
    Do $$$AssertTrue($IsObject(tArea), "and carries the Web applications area")
    If '$IsObject(tArea) Quit
    Do $$$AssertEquals(tArea.%Get("allowed"), 1, "which is open")
    Set tVerdicts = ""
    Set tIterator = tArea.%Get("screens").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tScreen) {
        If tScreen.%Get("sideBarPosition") = 0 Continue
        Set tVerdicts = tVerdicts _ $ListBuild(tScreen.%Get("route") _ "=" _ $Select(tScreen.%Get("allowed"): "open", 1: tScreen.%Get("failedPair")))
    }
    Do $$$AssertEquals($ListToString(tVerdicts, " "), "web-applications/list=open web-applications/rest-apis=open web-applications/sessions=%Admin_Operate:USE", "its list and the REST API explorer are open, and Web sessions is refused on its own pair")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/webapp.sessions/read?maxRows=5", ..#AREAUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE", "and its read is refused naming that pair")
}

/// <p>Seed one <parameter>SEEDPATH</parameter> session as the test account, answering its id: the
/// one row with that user and application the list did not carry before the request.</p>
Method Seed(Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..Ids(.tBefore)
    If $$$ISERR(tSC) Quit tSC
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#SEEDPATH, tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    If tStatus '= 200 Quit $$$ERROR($$$GeneralError, ..#SEEDPATH _ " answered " _ tStatus)
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebSession", "LIST", .tNoQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tNew = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ListFind(tBefore, tRow.%Get("ID")) Continue
        If (tRow.%Get("Application") '= ..#SEEDPATH) || (tRow.%Get("Username") '= tUser) Continue
        Set tNew = tNew _ $ListBuild(tRow.%Get("ID"))
    }
    Set ..PreparedSeeded = ..PreparedSeeded _ tNew
    If $ListLength(tNew) '= 1 Quit $$$ERROR($$$GeneralError, "the request left " _ $ListLength(tNew) _ " new sessions, not one")
    Set pId = $List(tNew, 1)
    Quit $$$OK
}

/// <p>The ids the vendor's list carries now.</p>
Method Ids(Output pIds As %List) As %Status
{
    Set pIds = ""
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebSession", "LIST", .tNoQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pIds = pIds _ $ListBuild(tRow.%Get("ID"))
    }
    Quit $$$OK
}

/// <p>The vendor's list row whose ID is <var>pId</var> exactly, or <code>""</code>.</p>
Method LiveRow(pId As %String) As %DynamicObject
{
    Set tFound = ""
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebSession", "LIST", .tNoQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("ID") = pId Set tFound = tRow
    }
    Quit tFound
}

/// <p>Whether the vendor's list carries <var>pId</var> exactly.</p>
Method Listed(pId As %String) As %Boolean
{
    Quit $IsObject(..LiveRow(pId))
}

/// <p>One End session over the route as <var>pUser</var>, or as the test account when
/// <var>pUser</var> is empty, answering the HTTP status and the parsed envelope.</p>
Method Act(pId As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set pPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {"action": "end"}
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/webapp.sessions/action", pUser, pPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The failed pair an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tCase = $ListBuild(..#OPERATORUSER, ..#OPERATORROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Operate:U", "%Admin_Operate"), $ListBuild(..#AREAUSER, ..#AREAROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Secure:U", "%Admin_Secure") {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the web session gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot web session test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WebSessionsLive; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            Set tHeld = $List(tCase, 4)
            Set tOther = $Select(tHeld = "%Admin_Operate": "%Admin_Secure", 1: "%Admin_Operate")
            If ($SYSTEM.Security.CheckUserPermission(tUser, tHeld, "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") = 1) || ($SYSTEM.Security.CheckUserPermission(tUser, tOther, "USE") = 1) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
