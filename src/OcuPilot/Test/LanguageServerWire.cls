/// <p>Pins Story 16.10 against a real external language server (AD-8, AD-10, AD-36, AD-39, AD-51,
/// AD-53): a principal holding exactly the screens' two pairs lists the servers, reads the Activity
/// log and starts and stops a probe Java server through
/// <code>POST /api/ocupilot/screens/:screen/action</code>, with Running observed each way, the two
/// read tools answering what the screens' reads answer, and the wrong verb refused with its published
/// sentence; the agent's confirmed start, and a stop minted
/// while running then stopped out of band, refused at Confirm; a start the instance refuses answering
/// <code>LANGUAGESERVER.START</code>; and a holder of OS management's pairs without the own pair
/// refused by name on every call while the rest of OS management stays open.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s test account, a JVM the instance's Java
/// servers find, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class
/// creates and deletes two users, two roles and two probe servers named
/// <parameter>PROBE</parameter> and <parameter>BADPROBE</parameter>, and starts and stops the first.
/// No vendor <code>%</code> server is started, stopped or deleted. Teardown stops each probe before it
/// is removed, since a deleted running server keeps listening, and removes its activity rows.</p>
/// <p>Both probes listen on ports below the instance's ephemeral port range, so no outbound
/// connection's source port can hold one when it starts; the range is read from
/// <parameter>PORTRANGEFILE</parameter> at run time, and a file that cannot be read is red.</p>
Class OcuPilot.Test.LanguageServerWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter LIST = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter START = "OcuPilot.Screen.Tool.LanguageServerStart";

Parameter STOP = "OcuPilot.Screen.Tool.LanguageServerStop";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The probe Java server this class starts and stops, and its port.</p>
Parameter PROBE = "OcuPilotProbeELSWire";

Parameter PROBEPORT = 31291;

/// <p>The probe Java server whose <code>JavaHome</code> names no JVM, and its port.</p>
Parameter BADPROBE = "OcuPilotProbeELSWireBad";

Parameter BADPROBEPORT = 31292;

/// <p>The kernel file whose first number is the low bound of the instance's ephemeral port range.</p>
Parameter PORTRANGEFILE = "/proc/sys/net/ipv4/ip_local_port_range";

Parameter BADJAVAHOME = "/nonexistent/ocupilot/jdk";

/// <p>The purpose-built principal holding the install namespace's code read and exactly the two
/// pairs the screens declare.</p>
Parameter EXACTUSER = "OcuPilotELSGateExact";

Parameter EXACTROLE = "OcuPilotELSGateExactRole";

/// <p>The purpose-built principal holding the code read and OS management's three pairs, and not
/// the own pair.</p>
Parameter AREAUSER = "OcuPilotELSGateArea";

Parameter AREAROLE = "OcuPilotELSGateAreaRole";

Parameter OWNPAIR = "%Admin_ExternalLanguageServerEdit:USE";

/// <p>The two state refusals and the refused start's sentence, as EXPERIENCE.md publishes them.</p>
Parameter RUNNING = "This server is already running.";

Parameter STOPPED = "This server is not running.";

Parameter STARTFAILED = "The server did not start. Its activity log records why.";

/// <p>The seconds an HTTP client waits for a start, which blocks until the server answers.</p>
Parameter STARTTIMEOUT = 60;

/// <p>The throwaway principals' password, generated for the run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LanguageServerWire creates users, roles and external language servers on this instance, and starts and stops one; it runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotELS" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ..EnsurePrincipals()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..CreateProbe(..#PROBE, ..#PROBEPORT, "")
    If $$$ISERR(tSC) Quit tSC
    Quit ..CreateProbe(..#BADPROBE, ..#BADPROBEPORT, ..#BADJAVAHOME)
}

/// <p>Stop and remove both probe servers and their activity rows, then both principals and their
/// roles; a failing status when anything survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    For tProbe = ..#PROBE, ..#BADPROBE {
        Set tRemoveSC = ..RemoveProbe(tProbe)
        If $$$ISERR(tRemoveSC) Set tSC = tRemoveSC
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#EXACTUSER, ..#AREAUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#EXACTROLE, ..#AREAROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#EXACTUSER) || ##class(Security.Users).Exists(..#AREAUSER) || ##class(Security.Roles).Exists(..#EXACTROLE) || ##class(Security.Roles).Exists(..#AREAROLE) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.LanguageServerWire left a throwaway principal on the instance")
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
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Leave the probe stopped, whatever the test did, and remove the proposals it minted.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ..StopOutOfBand(..#PROBE)
    Do $$$AssertEquals(..Running(..#PROBE), 0, "the probe is left stopped")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC1, AC2, AC3, AC5: a principal holding exactly the screens' two pairs reads the probe on the
/// list as not running; its Start answers 200 with the updated event for the server and the list then
/// reads it running; a second Start is refused 400 with the published sentence and sends nothing; the
/// Activity log reads the server's newest rows; its Stop answers 200 and the list reads it stopped;
/// and a second Stop is refused with its own sentence.</p>
/// <p>First, both probe ports read below the instance's ephemeral port range.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.LanguageServerStart.PrivilegePairs</method>
/// add <code>%Admin_Manage:USE</code> -- the exact-pairs principal's Start is refused 403 and this goes
/// red. Set <parameter>PROBEPORT</parameter> to 53291 -- the port assertion goes red, naming the port and
/// the range's low bound.</p>
Method TestTheExactPairsPrincipalStartsAndStopsTheProbe()
{
    Set tLow = ..EphemeralLow()
    Do $$$AssertTrue(tLow '= "", "the instance's ephemeral port range is read from " _ ..#PORTRANGEFILE)
    If tLow '= "" {
        For tPort = ..#PROBEPORT, ..#BADPROBEPORT {
            Do $$$AssertTrue(tPort < tLow, "probe port " _ tPort _ " is below the instance's ephemeral port range, which starts at " _ tLow)
        }
    }
    Set tUser = ..#EXACTUSER
    Do $$$AssertEquals(..ListedRunning(..#PROBE, tUser), "false", "the principal reads the probe on the list, not running")
    Set tSC = ..Act("start", ..#PROBE, tUser, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its Start answers 200: " _ ..Shown(tBody))
    If $IsObject(tBody) && $IsObject(tBody.%Get("target")) Do $$$AssertEquals(tBody.%Get("action") _ " " _ tBody.%Get("target").%ToJSON(), "updated {""type"":""language-server"",""scope"":""instance"",""id"":""" _ ..#PROBE _ """}", "publishing the updated event for the server")
    Do $$$AssertEquals(..ListedRunning(..#PROBE, tUser), "true", "and the list then reads it running")
    Do $$$AssertEquals(..ToolRunning(..#PROBE), "true", "as osmgmt.languageservers.read reports it (AC7)")
    Set tSC = ..Act("start", ..#PROBE, tUser, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#RUNNING, "a second Start is refused with the published sentence")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.languageserveractivity/read?maxRows=5&name=" _ ##class(%CSP.Page).EscapeURL(..#PROBE), tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the principal reads the probe's Activity log")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%Get("rows").%Size() > 0) && (tRead.%Get("rows").%Size() <= 5), "within the cap, holding rows: " _ $Get(tRaw))
    If $IsObject(tRead) && (tRead.%Get("rows").%Size() > 0) {
        Set tNewest = tRead.%Get("rows").%Get(0)
        Do $$$AssertTrue((tNewest.%GetTypeOf("ID") = "number") && (tNewest.%Get("DateTime") ? 4N1"-"2N1"-"2N1" "2N1":"2N1":"2N) && (tNewest.%Get("RecordType") '= ""), "the newest row carries its id, its local time and its record type: " _ tNewest.%ToJSON())
        Do $$$AssertTrue(tRead.%Get("rows").%Get(tRead.%Get("rows").%Size() - 1).%Get("ID") <= tNewest.%Get("ID"), "newest first")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View("OcuPilot.Screen.Descriptor.LanguageServerActivity", {"name": (..#PROBE), "maxRows": 5}, 200, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "osmgmt.languageserveractivity.read reads the probe's Activity log")
    Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.%Get("rows").%ToJSON(), 1: ""), $Select($IsObject(tRead): tRead.%Get("rows").%ToJSON(), 1: "-"), "and returns the rows the screen's read answers, in its order (AC7)")

    Set tSC = ..Act("stop", ..#PROBE, tUser, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its Stop answers 200: " _ ..Shown(tBody))
    Do $$$AssertEquals(..ListedRunning(..#PROBE, tUser), "false", "and the list then reads it stopped")
    Set tSC = ..Act("stop", ..#PROBE, tUser, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#STOPPED, "a second Stop is refused with its published sentence")
}

/// <p>AC4, AD-51, AD-6: the agent's start of the stopped probe mints one state row, and its confirm
/// starts it; a stop minted while it runs, after an out-of-band stop, is refused at Confirm because
/// the fingerprint moved.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.LanguageServerStart.FINGERPRINTSUBJECT</parameter>
/// -- the registration guard refuses both tools and the mint legs go red.</p>
Method TestTheAgentsStartConfirmsAndAMovedStopIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#START, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the start mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tRows = tProposal.%Get("changed")
    Set tRow = $Select($IsObject(tRows) && (tRows.%Size() = 1): tRows.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("before") _ " " _ tRow.%Get("after"), 1: ""), "CurrentlyRunning No Yes", "one Running row, No to Yes: " _ ..Shown(tRows))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm starts it: " _ $Get(tCode))
    Do $$$AssertEquals(..Running(..#PROBE), 1, "and the probe runs")

    Set tSC = ..Mint(..#STOP, tTurn, .tStop)
    Do $$$AssertStatusOK(tSC, "a stop mints while it runs: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do ..StopOutOfBand(..#PROBE)
    Do $$$AssertEquals(..Running(..#PROBE), 0, "the probe is stopped out of band")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tStop.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the stop's confirm is refused as a moved target")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC2, AD-39: a start the instance refuses -- the probe's <code>JavaHome</code> names no JVM --
/// answers 500 <code>LANGUAGESERVER.START</code> with the published sentence; the server stays
/// stopped, and its Activity log records the refusal as an <code>Error</code> row.</p>
Method TestARefusedStartAnswersItsPublishedCode()
{
    Set tSC = ..Act("start", ..#BADPROBE, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ $Select($IsObject(tBody): tBody.%Get("reason"), 1: ""), "500 LANGUAGESERVER.START " _ ..#STARTFAILED, "the refused start answers its code and sentence")
    Do $$$AssertEquals(..Running(..#BADPROBE), 0, "the server stays stopped")
    Kill tQuery
    Set tQuery("name") = ..#BADPROBE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "ACTIVITY", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Set tError = 0
    If $$$ISOK(tSC) && $IsObject(tAnswer) {
        Set tIterator = tAnswer.%Get("Activity").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("RecordType") = "Error" Set tError = 1
        }
    }
    Do $$$AssertTrue(tError, "and its activity log records an Error row")
}

/// <p>AC5, AD-8 as amended: a holder of OS management's three pairs without the own pair keeps the
/// area and every other listed OS management screen, while External language servers alone reads
/// refused on <code>%Admin_ExternalLanguageServerEdit:USE</code>, beside Journal settings on its own
/// <code>%Admin_Journal:USE</code> (Story 18.18); both screens' reads and both
/// actions answer 403 naming that pair, and the probe is not started.</p>
/// <p>Mutation (Rule 19): drop the own pair from the list's <code>ownPrivileges</code> -- the area
/// reads refused and the navigation leg goes red.</p>
Method TestAnAreaHolderKeepsOsManagementAndIsRefusedTheServers()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#AREAUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Set tArea = ""
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("areas").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.%Get("key") = "os-management" Set tArea = tEntry
        }
    } Catch {}
    Do $$$AssertTrue($IsObject(tArea), "and carries OS management")
    If '$IsObject(tArea) Quit
    Do $$$AssertEquals(tArea.%Get("allowed"), 1, "which is open")
    Set tRefused = ""
    Set tOpen = 0
    Set tIterator = tArea.%Get("screens").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tScreen) {
        If tScreen.%Get("sideBarPosition") = 0 Continue
        If tScreen.%Get("allowed") {
            Set tOpen = tOpen + 1
        } Else {
            Set tRefused = tRefused _ $ListBuild(tScreen.%Get("route") _ "=" _ tScreen.%Get("failedPair"))
        }
    }
    ; Story 18.18's Journal settings declares its own pair too, which this principal does not hold.
    Set tJournal = $ListFind(tRefused, "os-management/journal-settings=%Admin_Journal:USE")
    Do $$$AssertTrue(tJournal > 0, "Journal settings is refused on its own pair, %Admin_Journal:USE: " _ $ListToString(tRefused, " "))
    If tJournal Set tRefused = $List(tRefused, 1, tJournal - 1) _ $List(tRefused, tJournal + 1, *)
    ; Story 18.21's ECP settings declares its own pair too, %Admin_Secure:USE, which this principal does
    ; not hold.
    Set tEcpSettings = $ListFind(tRefused, "os-management/ecp-settings=%Admin_Secure:USE")
    Do $$$AssertTrue(tEcpSettings > 0, "ECP settings is refused on its own pair, %Admin_Secure:USE: " _ $ListToString(tRefused, " "))
    If tEcpSettings Set tRefused = $List(tRefused, 1, tEcpSettings - 1) _ $List(tRefused, tEcpSettings + 1, *)
    Do $$$AssertEquals($ListToString(tRefused, " "), "os-management/language-servers=" _ ..#OWNPAIR, "only External language servers is refused, on its own pair")
    Do $$$AssertTrue(tOpen > 0, "and every other listed OS management screen is open")
    For tRead = "osmgmt.languageservers/read?maxRows=5", "osmgmt.languageserveractivity/read?maxRows=5&name=" _ ##class(%CSP.Page).EscapeURL(..#PROBE) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ tRead, ..#AREAUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ ..#OWNPAIR, "the read " _ $Piece(tRead, "?") _ " is refused naming the own pair")
    }
    For tAction = "start", "stop" {
        Set tSC = ..Act(tAction, ..#PROBE, ..#AREAUSER, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ ..#OWNPAIR, "its " _ tAction _ " is refused naming the own pair")
    }
    Do $$$AssertEquals(..Running(..#PROBE), 0, "and the probe was not started")
}

/// <p>Mint <var>pToolClass</var>'s proposal for the probe as the caller, in turn <var>pTurn</var>.</p>
Method Mint(pToolClass As %String, pTurn As %String, Output pProposal As %DynamicObject) As %Status
{
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#PROBE, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurn, tArgs, ..#LIMITS, .pProposal, .tHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), ..#PROBE, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>One row action over the route as <var>pUser</var>, or as the test account when
/// <var>pUser</var> is empty, answering the HTTP status and the parsed envelope.</p>
Method Act(pAction As %String, pName As %String, pUser As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tPassword = ..PreparedPassword
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pName, "string")
    Kill tExtra
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.languageservers/action", pUser, tPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json", .tExtra, ..#STARTTIMEOUT)
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The probe's <code>CurrentlyRunning</code> as the list's read answers it to <var>pUser</var>,
/// as text, or <code>""</code> when the list does not carry it.</p>
Method ListedRunning(pName As %String, pUser As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.languageservers/read?maxRows=1000", pUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tFound = ""
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("Name") = pName Set tFound = $Select(tRow.%GetTypeOf("CurrentlyRunning") = "boolean": $Select(tRow.%Get("CurrentlyRunning"): "true", 1: "false"), 1: "?")
        }
    } Catch {}
    Quit tFound
}

/// <p>Whether the instance reports server <var>pName</var> running, read through the port as the
/// caller: 1 or 0, or -1 when the read fails, so a failed read never passes for a stopped server.</p>
Method Running(pName As %String) As %Integer
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tQuery("maxRows") = 1
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "ACTIVITY", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tAnswer)) || (tAnswer.%GetTypeOf("CurrentlyRunning") '= "boolean") Quit -1
    Quit ''tAnswer.%Get("CurrentlyRunning")
}

/// <p>The probe's <code>CurrentlyRunning</code> as <code>osmgmt.languageservers.read</code> answers it
/// to the caller, as text, or <code>""</code> when its view does not carry it.</p>
Method ToolRunning(pName As %String) As %String
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LIST, {"maxRows": 1000}, 1000, .tView, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tView)) Quit ""
    Set tFound = ""
    Set tIterator = tView.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Set tFound = $Select(tRow.%GetTypeOf("CurrentlyRunning") = "boolean": $Select(tRow.%Get("CurrentlyRunning"): "true", 1: "false"), 1: "?")
    }
    Quit tFound
}

/// <p>Stop server <var>pName</var> through the port as the caller, not through OcuPilot's write
/// path.</p>
Method StopOutOfBand(pName As %String)
{
    Kill tQuery
    Set tQuery("name") = pName
    Do ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "STOP", .tQuery, "", .tAnswer, .tHttp, .tFault)
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The problem sentence an envelope <var>pBody</var>'s detail carries, or <code>""</code>.</p>
ClassMethod Problem(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("problem")
}

/// <p>The failed pair an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

/// <p>The low bound of the instance's ephemeral port range, the first number in
/// <parameter>PORTRANGEFILE</parameter>, or <code>""</code> when that file cannot be read. The file is
/// read through its device rather than a file stream, because the kernel reports its size as 0.</p>
ClassMethod EphemeralLow() As %String
{
    Set tLow = ""
    Set tIO = $IO
    Set tFile = ..#PORTRANGEFILE
    Try {
        Open tFile:("RS"):2
        If '$Test Quit
        Use tFile
        Read tLine:2
        Use tIO
        Close tFile
        Set tFirst = $Piece($ZStrip($Translate(tLine, $Char(9), " "), "<=>W"), " ", 1)
        If tFirst ? 1.N Set tLow = +tFirst
    } Catch {
        Use tIO
        Close tFile
        Set tLow = ""
    }
    Quit tLow
}

/// <p>Create probe Java server <var>pName</var> on <var>pPort</var> through
/// <class>Config.Gateways</class>, with <var>pJavaHome</var> where it is not empty, replacing a probe
/// an earlier run left.</p>
Method CreateProbe(pName As %String, pPort As %Integer, pJavaHome As %String) As %Status
{
    Set tSC = ..RemoveProbe(pName)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Type") = "Java"
        Set tProperties("Port") = pPort
        If pJavaHome '= "" Set tProperties("JavaHome") = pJavaHome
        Set tSC = ##class(Config.Gateways).Create(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Stop probe server <var>pName</var>, delete it and remove its activity rows; OK when it is
/// absent, and an error, deleting nothing, when it still reads running after the stop, because a
/// deleted running server keeps listening.</p>
Method RemoveProbe(pName As %String) As %Status
{
    Set tSC = $$$OK
    If $Extract(pName, 1, 16) '= "OcuPilotProbeELS" Quit $$$ERROR($$$GeneralError, "only a probe server is removed")
    Do ..StopOutOfBand(pName)
    If ..Running(pName) = 1 Quit $$$ERROR($$$GeneralError, "the probe server " _ pName _ " still reads running after its stop, so it was not deleted")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Gateways).Exists(pName) Set tSC = ##class(Config.Gateways).Delete(pName)
        If $$$ISOK(tSC) {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %Net_Remote.ActivityLog WHERE %EXACT(GatewayName) = ?", pName)
            If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the probe's activity rows were not removed: SQLCODE " _ tResult.%SQLCODE)
        }
        If $$$ISOK(tSC) && ##class(Config.Gateways).Exists(pName) Set tSC = $$$ERROR($$$GeneralError, "the probe server " _ pName _ " is still defined")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
        For tCase = $ListBuild(..#EXACTUSER, ..#EXACTROLE, tCode _ ",%DB_IRISSYS:R,%Admin_ExternalLanguageServerEdit:U"), $ListBuild(..#AREAUSER, ..#AREAROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Operate:U,%Admin_Manage:U") {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the language server gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot language server test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LanguageServerWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_ExternalLanguageServerEdit", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_Manage", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_Operate", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%DB_IRISSYS", "WRITE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the exact-pairs principal's grants did not read back as declared")
            Quit
        }
        If ($SYSTEM.Security.CheckUserPermission(..#AREAUSER, "%Admin_ExternalLanguageServerEdit", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#AREAUSER, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#AREAUSER, "%Admin_Operate", "USE") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the area principal's grants did not read back as declared")
            Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
