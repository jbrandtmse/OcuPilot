/// <p>Pins Story 18.21's pairs with least-privileged principals (AC C1, C6; AD-8, AD-29): a holder of OS
/// management's two pairs sees ECP settings listed unavailable naming <code>%Admin_Secure:USE</code> and is
/// refused its read, its form route and its Save naming it, while ECP application servers opens; a holder
/// of the screen's three pairs reads the settings and the form; a principal without
/// <code>%DB_IRISSYS:WRITE</code> is refused the Save, the three SSL/TLS actions and the agent's confirm
/// of a settings change and of an SSL/TLS delete naming it, and one without <code>%Admin_Manage:USE</code>
/// every call naming it, each with zero port calls; and principals holding exactly each tool's declared
/// pairs write on both callers.</p>
/// <p>The write legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.EcpWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.EcpSeamPort</class> was asked; the reads and both routes run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, no <code>%ECPServer</code>
/// SSL/TLS configuration, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>ECPVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe
/// users, roles and SSL/TLS names (<class>OcuPilot.Test.EcpProbe</class>), changes the ECP settings and
/// restores them, and sets the governance policy. Every probe object is removed by exact name; after each
/// test the settings read as that test found them, no ECP process runs and the license reads as
/// found.</p>
Class OcuPilot.Test.EcpSettingsGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the ECP writes, set there alone too.</p>
Parameter ECPVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint helper, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SETTINGSTOOL = "OcuPilot.Screen.Tool.EcpSettingsUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.EcpSslConnectionDelete";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// reader holds OS management's two pairs; the secure reader those with <code>%Admin_Secure:USE</code>,
/// ECP settings' three; the writer those with the system database's <code>WRITE</code>, the settings
/// update's set; the SSL/TLS writer OS management's two with that <code>WRITE</code> and no
/// <code>%Admin_Secure:USE</code>, the SSL/TLS actions' set; the outsider the system database's
/// <code>READ</code> and <code>%Admin_Operate:USE</code>, which admits it to the API and is not the
/// screens'.</p>
Parameter PRINCIPALS = "OCUPROBEECPHREADER:OCUPROBEECPHREADERROLE:%Admin_Manage:U;%DB_IRISSYS:R,OCUPROBEECPHSECURE:OCUPROBEECPHSECUREROLE:%Admin_Manage:U;%Admin_Secure:U;%DB_IRISSYS:R,OCUPROBEECPHWRITER:OCUPROBEECPHWRITERROLE:%Admin_Manage:U;%Admin_Secure:U;%DB_IRISSYS:RW,OCUPROBEECPHSSL:OCUPROBEECPHSSLROLE:%Admin_Manage:U;%DB_IRISSYS:RW,OCUPROBEECPHNONE:OCUPROBEECPHNONEROLE:%DB_IRISSYS:R;%Admin_Operate:U";

/// <p>The two routes, relative to the API base.</p>
Parameter FORMPATH = "/ecp-settings/form";

Parameter SAVEPATH = "/ecp-settings";

/// <p>The probe SSL/TLS names the write legs seed.</p>
Parameter NAMEA = "CN=OCUPROBEECPHA";

Parameter NAMEB = "CN=OCUPROBEECPHB";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The ECP settings and the license's facts before each test, which the test must leave as
/// found.</p>
Property PreparedSettings As %String(MAXLEN = "");

Property PreparedFacts As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSettings = ""
    Set ..PreparedFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#ECPVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpSettingsGate creates and deletes users, roles and ECP SSL/TLS names and changes the ECP settings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#ECPVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbeEcpSettings" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs with the principals, and with the agent's settings and SSL/TLS delete keys
/// enabled.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Set ..PreparedSettings = $ClassMethod(..#PROBE, "Settings").%ToJSON()
    Kill tSettings
    Set tSettings("osmgmt.ecpsettings.update") = "enabled"
    Set tSettings("osmgmt.ecpsslconnections.delete") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, *), ";", ","), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreSettings", ##class(%DynamicObject).%FromJSON(..PreparedSettings)), "the ECP settings are restored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), ..PreparedSettings, "and read as before the test")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, "no ECP process runs after the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON(), ..PreparedFacts, "the license reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>C1: a holder of OS management's two pairs sees ECP settings listed unavailable naming
/// <code>%Admin_Secure:USE</code> and ECP application servers open; the settings' read, its form route
/// and its Save are refused naming that pair, the Save with zero port calls; both application server tabs
/// read.</p>
/// <p>Mutation (Rule 19): drop <code>ownPrivileges</code> and <code>%Admin_Secure:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.EcpSettings</class> -- the entry opens and this goes red.</p>
Method TestEcpSettingsIsUnavailableWithoutItsOwnPair()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the reader")
    Set tSettings = ""
    Set tServers = ""
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("areas").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            If tArea.%Get("key") '= "os-management" Continue
            Set tScreens = tArea.%Get("screens").%GetIterator()
            While tScreens.%GetNext(.tScreenIndex, .tScreen) {
                If tScreen.%Get("route") = "os-management/ecp-settings" Set tSettings = tScreen.%Get("allowed") _ " " _ tScreen.%Get("failedPair")
                If tScreen.%Get("route") = "os-management/ecp-application-servers" Set tServers = tScreen.%Get("allowed") _ " " _ tScreen.%Get("failedPair")
            }
        }
    } Catch {}
    Do $$$AssertEquals(tSettings, "0 %Admin_Secure:USE", "ECP settings is listed unavailable, naming its own pair")
    Do $$$AssertEquals(tServers, "1 ", "and ECP application servers is open")
    For tPath = "/screens/osmgmt.ecpsettings/read?maxRows=5", ..#FORMPATH {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ tPath, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Denial(tRaw), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "GET " _ tPath _ " is refused naming the own pair: " _ $Extract(tRaw, 1, 200))
    }
    For tRead = "osmgmt.ecpappservers", "osmgmt.ecpsslconnections" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ tRead _ "/read?maxRows=5", tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tRead _ "'s read answers the reader: " _ $Extract(tRaw, 1, 200))
    }
    Set tRun = ..RunAs(tUser, [{"kind": "settings", "body": {"AppServerSettings": {"ClientReconnectInterval": 6}}}])
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals(..LegText(tRun, 1), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "the Save is refused naming the own pair before any port call")
}

/// <p>C1: a holder of ECP settings' three pairs reads the settings over the wire, and the form route
/// answers it as JSON with whether the license enables ECP and the <code>%ECPServer</code> state; the Save
/// route answers a value out of range 422 as JSON on its field.</p>
Method TestTheScreensPairsReadTheSettingsAndTheRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(2)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.ecpsettings/read?maxRows=5", tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "ECP settings' read answers the secure reader: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue(tRaw [ """DataServerSettings.SSLECPServer"":", "with the six members")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET " _ ..#FORMPATH _ " answers: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ..Parsed(tRaw)
    Do $$$AssertEquals($Select($IsObject(tForm): tForm.%GetTypeOf("licensed") _ " " _ tForm.%Get("serverSsl"), 1: ""), "boolean absent", "carrying the license's answer and that %ECPServer is absent")
    Set tUser = ..User(3)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..#SAVEPATH, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders, {"AppServerSettings": {"ClientReconnectInterval": 61}}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "PUT " _ ..#SAVEPATH _ " answers: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tRaw), "AppServerSettings.ClientReconnectInterval:" _ ##class(OcuPilot.Api.EcpError).#SETTINGSINTERVAL, "a time between reconnections of 61 is refused on its member")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), ..PreparedSettings, "and nothing was written")
}

/// <p>C6: without <code>%DB_IRISSYS:WRITE</code>, ECP settings' Save, the three SSL/TLS actions and the
/// agent's confirm of a settings change and of an SSL/TLS delete are refused 403 naming it, each with zero
/// port calls and nothing changed.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.EcpSettingsUpdate.PrivilegePairs</method> -- the Save leg reaches the port
/// and this goes red.</p>
Method TestTheMissingToolPairsAreRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe SSL/TLS name is authorized")
    Set tUser = ..User(2)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SETTINGSTOOL, "SYSTEM", {"Name": "SYSTEM", "AppServerSettings": {"ClientReconnectInterval": (..Other())}}, .tSettingsProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a settings change is minted for the secure reader (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "settings", "body": {"AppServerSettings": {"ClientReconnectInterval": (..Other())}}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tSettingsProposal): tSettingsProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:2 Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 writes=", "settings leg " _ tI _ " is refused naming %DB_IRISSYS:WRITE before any port call")
    Set tUser = ..User(1)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, ..#NAMEA, {"SSLComputerName": (..#NAMEA)}, .tDeleteProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "an SSL/TLS delete is minted for the reader (" _ tProblem _ ")")
    Set tPlan = []
    For tKind = "sslauthorize", "sslreject", "ssldelete" Do tPlan.%Push({"kind": (tKind), "name": (..#NAMEA)})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tDeleteProposal): tDeleteProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:4 Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 writes=", "SSL/TLS leg " _ tI _ " is refused naming %DB_IRISSYS:WRITE before any port call")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), ..PreparedSettings, "the settings are unchanged")
    Do $$$AssertTrue(("," _ $ListToString($ClassMethod(..#PROBE, "AuthorizedNames")) _ ",") [ ("," _ ..#NAMEA _ ","), "and the name is still authorized")
}

/// <p>C6: without <code>%Admin_Manage:USE</code>, the Save, the three SSL/TLS actions and the form route
/// over the wire are refused 403 naming it, with zero port calls and nothing changed.</p>
/// <p>Mutation (Rule 19): drop the gate from <method>OcuPilot.Area.OsMgmt.EcpSettingsRules.HandleForm</method>
/// -- the outsider's form read reaches the port and this goes red.</p>
Method TestEveryCallNeedsTheScreensPairs()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe SSL/TLS name is authorized")
    Set tUser = ..User(5)
    Set tPlan = [{"kind": "settings", "body": {"AppServerSettings": {"ClientReconnectInterval": 6}}}]
    For tKind = "sslauthorize", "sslreject", "ssldelete" Do tPlan.%Push({"kind": (tKind), "name": (..#NAMEA)})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:4 Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE calls=0 writes=", "leg " _ tI _ " is refused naming the screen's pair before any port call")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Denial(tRaw), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE", "GET " _ ..#FORMPATH _ " is refused naming the screen's pair: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), ..PreparedSettings, "the settings are unchanged")
    Do $$$AssertTrue(("," _ $ListToString($ClassMethod(..#PROBE, "AuthorizedNames")) _ ",") [ ("," _ ..#NAMEA _ ","), "and the name is still authorized")
}

/// <p>C6: a principal holding exactly the settings update's declared pairs writes through the Save and the
/// agent's confirm; one holding exactly the SSL/TLS delete's pairs, without
/// <code>%Admin_Secure:USE</code>, deletes through the tab and the agent's confirm. With the refusal legs,
/// the floor under their zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Set tUser = ..User(3)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SETTINGSTOOL, "SYSTEM", {"Name": "SYSTEM", "AppServerSettings": {"ClientReconnectDuration": (..OtherDuration())}}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a settings change is minted for the writer (" _ tProblem _ ")")
    ; The confirm runs first: its fingerprint covers both objects as minted, so a Save before it would
    ; close the proposal as a changed target.
    Set tPlan = []
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "settings", "body": {"AppServerSettings": {"ClientReconnectInterval": (..Other())}}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "the agent's confirm"), $ListBuild(2, "the Save") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 ECP.Settings/PUT", $List(tCase, 2) _ " writes (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Set tStored = $ClassMethod(..#PROBE, "Settings")
    Do $$$AssertEquals(tStored.ClientReconnectInterval _ " " _ tStored.ClientReconnectDuration, ..Other() _ " " _ ..OtherDuration(), "both changes are on the instance")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe SSL/TLS name for the tab's delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEB), "and one for the agent's")
    Set tUser = ..User(4)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, ..#NAMEB, {"SSLComputerName": (..#NAMEB)}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "an SSL/TLS delete is minted for the SSL/TLS writer (" _ tProblem _ ")")
    Set tPlan = [{"kind": "ssldelete", "name": (..#NAMEA)}]
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "settings", "body": {"AppServerSettings": {"ClientReconnectInterval": 6}}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "the tab's delete"), $ListBuild(2, "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 ECP.AppServerSSLConnection/DELETE", $List(tCase, 2) _ " deletes (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals(..LegText(tRun, 3), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "and the same principal's settings Save is refused on ECP settings' own pair")
    Set tNames = "," _ $ListToString($ClassMethod(..#PROBE, "AuthorizedNames")) _ ","
    Do $$$AssertTrue('(tNames [ ("," _ ..#NAMEA _ ",")) && '(tNames [ ("," _ ..#NAMEB _ ",")), "both names are deleted: " _ tNames)
}

/// <p>A time between reconnections other than the one the test started from, in range.</p>
Method Other() As %Integer
{
    Set tNow = ##class(%DynamicObject).%FromJSON(..PreparedSettings).ClientReconnectInterval
    Quit $Select(tNow < 60: tNow + 1, 1: tNow - 1)
}

/// <p>A time to wait for recovery other than the one the test started from, in range.</p>
Method OtherDuration() As %Integer
{
    Set tNow = ##class(%DynamicObject).%FromJSON(..PreparedSettings).ClientReconnectDuration
    Quit $Select(tNow < 65535: tNow + 1, 1: tNow - 1)
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>An envelope's <code>code failedPair</code>, from its JSON text.</p>
ClassMethod Denial(pJson As %String) As %String
{
    Set tAnswer = ..Parsed(pJson)
    If '$IsObject(tAnswer) Quit ""
    Quit tAnswer.%Get("code") _ " " _ $Select($IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("failedPair"), 1: "")
}

/// <p>Run <class>OcuPilot.Test.EcpWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var>:
/// <method>OcuPilot.Test.EcpWriteGate.RunAs</method>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.EcpWriteGate).RunAs(pUser, pPlan)
}

/// <p><method>OcuPilot.Test.EcpWriteGate.Ran</method>.</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.EcpWriteGate).Ran(pRun)
}

/// <p><method>OcuPilot.Test.EcpWriteGate.Leg</method>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.EcpWriteGate).Leg(pRun, pIndex)
}

/// <p><method>OcuPilot.Test.EcpWriteGate.LegText</method>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Quit ##class(OcuPilot.Test.EcpWriteGate).LegText(pRun, pIndex)
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
