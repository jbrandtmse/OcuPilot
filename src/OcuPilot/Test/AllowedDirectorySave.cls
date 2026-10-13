/// <p>Story 18.42's route (AD-21's tenth case, AD-22, AD-34, AD-53, AD-55): <code>POST /allowed-directories</code> over the wire,
/// as the suite's own account and as a principal short of the screen's pair -- the pair refusal that comes before the
/// governance key, the key shipped off refusing <code>ALLOWLIST.OFF</code> with nothing changed, an add, a change and a remove
/// written to the real <code>FSAccess</code> list and read back, the screen's action route reaching no tool, a body that is
/// not the three strings, a held target answered busy, a tool the agent can reach refused by the kernel on the route, and
/// what a server-path consumer resolves after an add from an unrestricted list and after a remove has emptied it.</p>
/// <p>Each method records the allow-list and the governance policy before it runs and restores both exactly afterwards,
/// failure included, and creates and removes its probe directories under the manager directory. Changing the instance's
/// allow-list and policy is why <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms
/// it; it also creates one throwaway principal and role, deleted in <method>OnAfterAllTests</method>. Needs OcuPilot
/// installed in the namespace it runs in and a process holding <code>%All</code>.</p>
Class OcuPilot.Test.AllowedDirectorySave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>. Only
/// <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SAVEPATH = "/allowed-directories";

Parameter READPATH = "/screens/security.alloweddirectories/read?maxRows=1000";

Parameter ACTIONPATH = "/screens/security.alloweddirectories/action";

/// <p>The tool and its governance key.</p>
Parameter TOOL = "OcuPilot.Screen.Tool.AllowedDirectoryUpdate";

Parameter KEY = "security.alloweddirectories.update";

Parameter PURPOSEID = "%GUIFileSelector";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Parameter PATHPORT = "OcuPilot.Port.PathPort";

/// <p>The route run in this process with the prohibited set whose registry a test arms, and that set.</p>
Parameter ROUTE = "OcuPilot.Test.AllowedDirectorySaveFixture";

Parameter SET = "OcuPilot.Test.AllowListAgentSet";

/// <p>The principal that clears the API's floor and holds the screen's database pair but not
/// <code>%Admin_FileSystemAccess:USE</code>, and its role.</p>
Parameter NOFSAUSER = "OcuProbe1842NoFsa";

Parameter NOFSAROLE = "OcuProbe1842NoFsaRole";

Property PreparedPassword As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Property SavedExists As %Boolean [ InitialExpression = 0 ];

Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

Property SavedPaths As %List;

Property SavedOk As %Boolean [ InitialExpression = 0 ];

Property SavedPolicy As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Set ..SavedOk = 0
    Set ..SavedPolicy = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AllowedDirectorySave changes this instance's %GUIFileSelector allow-list and governance policy and creates one IRIS user and role, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1842" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tOk = $ClassMethod("OcuPilot.Kernel.Shell.Namespaces", "RoutineDatabase", $Namespace, .tCode, .tReadOnly)
    Set tSC = ##class(OcuPilot.Test.ErrorLogDenial).EnsurePrincipal(..#NOFSAROLE, ..#NOFSAUSER, tCode _ ":R,%DB_IRISSYS:R,%Admin_Operate:U", ..PreparedPassword)
    Set ..PreparedSetupOk = tOk && $$$ISOK(tSC) && ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%Admin_FileSystemAccess", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%DB_IRISSYS", "READ") = 1)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#NOFSAUSER) Do ##class(Security.Users).Delete(..#NOFSAUSER)
        If ##class(Security.Roles).Exists(..#NOFSAROLE) Do ##class(Security.Roles).Delete(..#NOFSAROLE)
        Set tLeft = ##class(Security.Users).Exists(..#NOFSAUSER) || ##class(Security.Roles).Exists(..#NOFSAROLE)
        Set $NAMESPACE = tOrigNS
        Do $$$AssertEquals(tLeft, 0, "the throwaway principal and role are removed")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(0, "the principal could not be removed: " _ ex.DisplayString())
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedPolicy = ..PolicyJson(.tRows)
    For tSuffix = "a", "b", "c" Do ##class(%File).CreateDirectoryChain(..Dir(tSuffix))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $$$OK
    If ..SavedOk {
        Set ..SavedOk = 0
        Set tSC = $ClassMethod(..#FIXTURE, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
        Do ..PolicyRows(..SavedPolicy, .tRows)
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is put back")
    }
    For tSuffix = "a", "b", "c" Do ##class(%File).RemoveDirectory(..Dir(tSuffix))
    Quit tSC
}

/// <p>Probe directory <var>pSuffix</var>, normalized, under the manager directory.</p>
ClassMethod Dir(pSuffix As %String) As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()) _ "ocuprobe1842s" _ pSuffix _ "/"
}

ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>Enable the tool's governance key, the one setting that lets the route reach the port.</p>
ClassMethod EnableKey()
{
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Do ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Drop every stored policy row, so the key reads the baseline's shipped <code>false</code>.</p>
ClassMethod NoSettings()
{
    Kill tNone
    Do ##class(OcuPilot.Test.GovernanceFixture).Restore(.tNone)
}

/// <p><code>POST /allowed-directories</code> as the suite's own account, the answer's status and body.</p>
ClassMethod Post(pBodyJson As %String, Output pStatus As %Integer, Output pBody As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#SAVEPATH, .pStatus, .pBody, pBodyJson, "application/json")
}

/// <p>The change as a request body.</p>
ClassMethod Change(pAction As %String, pDirectory As %String, pNew As %String = "") As %String
{
    Set tBody = {"Action": (pAction), "Directory": (pDirectory)}
    If pNew '= "" Do tBody.%Set("NewDirectory", pNew, "string")
    Quit tBody.%ToJSON()
}

/// <p>The roots the real port answers now, as a <code>|</code>-joined string.</p>
ClassMethod RootsNow() As %String
{
    Set tSC = $ClassMethod(..#PATHPORT, "Roots", 1000, .tRows, .tHttp, .tFault)
    Set tText = ""
    If $$$ISERR(tSC) Quit "(" _ tHttp _ ")"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tRow.%Get("Directory")
    }
    Quit tText
}

/// <p>What resolving a file under <var>pRoot</var> answers: <code>&lt;status&gt;|&lt;code or path&gt;</code>.</p>
ClassMethod ResolveUnder(pRoot As %String) As %String
{
    Set tSC = $ClassMethod(..#PATHPORT, "Resolve", pRoot, "x.txt", "file", "root", "path", .tResolved, .tHttp, .tFault, 0, 0)
    Quit tHttp _ "|" _ $Select($$$ISOK(tSC): tResolved, $IsObject($Get(tFault)): tFault.code, 1: "")
}

/// <p>The code of answer <var>pBody</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pBody) As %String
{
    Quit $Select($IsObject($Get(pBody)): pBody.%Get("code"), 1: "")
}

/// <p>The key shipped off refuses <code>ALLOWLIST.OFF</code> with its published sentence, before the list is read, and the
/// list is exactly as it was.</p>
/// <p>Mutation (Rule 19): ignore the <code>Gate.Decide</code> verdict in
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleSave</method> -- the add is written and this goes red.</p>
Method TestTheKeyShippedOffRefusesAndChangesNothing()
{
    Do ..NoSettings()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSC = ..Post(..Change("add", ..Dir("b")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody), "403|ALLOWLIST.OFF", "the add is refused as switched off")
    If $IsObject(tBody) Do $$$AssertEquals(tBody.reason, ##class(OcuPilot.Api.AllowListError).#REASONOFF, "with the published sentence")
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and the list is as it was")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot" _ ..#SAVEPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tRawStatus, .tRaw, .tHeaders, ..Change("add", ..Dir("b")), "application/json")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "the refusal is served as JSON")
    Set tSC = ..Post(..Change("remove", ..Dir("a")), .tStatus2, .tBody2)
    Do $$$AssertEquals(tStatus2 _ "|" _ ..CodeOf(tBody2) _ "|" _ ..RootsNow(), "403|ALLOWLIST.OFF|" _ ..Dir("a"), "and so is a remove, which removes nothing")
    Set tSC = ..Post(..Change("add", "relative/dir"), .tStatus3, .tBody3)
    Set tSC = ..Post(..Change("add", ..Dir("a")), .tStatus4, .tBody4)
    Do $$$AssertEquals(tStatus3 _ "|" _ ..CodeOf(tBody3) _ " " _ tStatus4 _ "|" _ ..CodeOf(tBody4), "403|ALLOWLIST.OFF 403|ALLOWLIST.OFF", "and a change the port would refuse for its path or for being listed is refused as switched off first")
}

/// <p>The stored policy rows <var>pRows</var> as one JSON object.</p>
ClassMethod PolicyJson(ByRef pRows) As %String
{
    Set tObject = {}
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName), 1, tValue)
        If tName = "" Quit
        Do tObject.%Set(tName, tValue, "string")
    }
    Quit tObject.%ToJSON()
}

/// <p>The rows a <method>PolicyJson</method> text holds, in <var>pRows</var>.</p>
ClassMethod PolicyRows(pJson As %String, Output pRows)
{
    Kill pRows
    If pJson = "" Quit
    Set tIterator = ##class(%DynamicAbstractObject).%FromJSON(pJson).%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set pRows(tName) = tValue
    }
}

/// <p>The probe directories <var>pList</var>, in the order the vendor answers them, joined with <code>|</code>.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Quit $ListToString(##class(OcuPilot.Port.AllowListPort).Ordered(pList), "|")
}

/// <p>With the key on, an add, a change and a remove are written to the real list and read back: the answer is the
/// <code>updated</code> action on the <code>allowed-directory</code> target with the read-back saying nothing was sent, the
/// real roots hold each change at once, a second add of the same directory is refused
/// <code>ALLOWLIST.LISTED</code>, and a remove of one the list does not hold is refused <code>ALLOWLIST.NOTLISTED</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>Apply</code> call from
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleSave</method> -- the roots never change and this goes red.</p>
Method TestAnAddAChangeAndARemoveAreWrittenAndReadBack()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSC = ..Post(..Change("add", ..Dir("b")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the add is accepted: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.action _ "|" _ tBody.target.type _ "|" _ tBody.target.scope _ "|" _ tBody.target.id, "updated|allowed-directory|instance|%GUIFileSelector", "it names the change event's triple")
        Do $$$AssertEquals(tBody.readBack.verdict, "nothingSent", "and the read-back says the action sent no value")
    }
    Do $$$AssertEquals(..RootsNow(), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "the real roots hold both at once")
    Set tSC = ..Post(..Change("add", ..Dir("b")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody), "409|ALLOWLIST.LISTED", "a second add of it is refused as listed, the port's refusal passed through")
    Set tSC = ..Post(..Change("change", ..Dir("b"), ..Dir("c")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the change is accepted: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertEquals(..RootsNow(), ..Sorted($ListBuild(..Dir("a"), ..Dir("c"))), "and the real roots hold the new directory and not the old")
    Set tSC = ..Post(..Change("remove", ..Dir("c")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the remove is accepted: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and the real roots lose it at once")
    Set tSC = ..Post(..Change("remove", ..Dir("b")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody) _ "|" _ ..RootsNow(), "409|ALLOWLIST.NOTLISTED|" _ ..Dir("a"), "a remove of one it does not hold is refused as not listed, changing nothing")
    Set tSC = ..Post(..Change("add", "relative/dir"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody), "400|ALLOWLIST.PATH", "a relative directory is refused as a bad path, the port's refusal passed through")
    Set tSC = ..Post(..Change("add", ..Manager() _ "ocuprobe1842smissing/"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody) _ "|" _ ..RootsNow(), "422|ALLOWLIST.NODIRECTORY|" _ ..Dir("a"), "and a directory the server does not have is refused 422, changing nothing")
}

/// <p>A caller short of the screen's <code>%Admin_FileSystemAccess:USE</code> is refused 403 naming that pair, and the pair
/// answers before the governance key: the key is off, and the refusal is still the pair's, not
/// <code>ALLOWLIST.OFF</code>.</p>
/// <p>Mutation (Rule 19): ignore the pairs gate's refusal in
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleSave</method> -- the key's refusal answers instead and this
/// goes red on the code.</p>
Method TestACallerWithoutTheScreensPairIsRefusedByNameBeforeTheKey()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's pairs")
    Do ..NoSettings()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot" _ ..#SAVEPATH, ..#NOFSAUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, ..Change("add", ..Dir("b")), "application/json")
    Do $$$AssertStatusOK(tSC, "the request completes")
    Set tAnswer = $Select(tBody '= "": ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8")), 1: "")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "403|AUTH.NOPRIVILEGE", "refused as lacking a privilege")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogDenial).FailedPairOf(tBody), "%Admin_FileSystemAccess:USE", "naming the pair it lacks")
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and nothing changed")
}

/// <p>The screen's own action route reaches no tool for the allow-list, with the key on: <code>add</code> is 404, as an action
/// the descriptor never declared, and the list is as it was; and the tool itself carries out no screen action, so a row
/// action a descriptor later declares still reaches nothing.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Screen.Tool.AllowedDirectoryUpdate</method> a
/// <code>SCREENACTIONS</code> of <code>add</code> -- the tool leg goes red.</p>
Method TestTheScreensActionRouteReachesNoTool()
{
    Do ..EnableKey()
    Do $$$AssertEquals($ListLength($ClassMethod(..#TOOL, "ScreenActionIds")), 0, "the tool carries out no screen action")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tBody = {"action": "add", "id": "%GUIFileSelector", "values": {"Action": "add", "Directory": (..Dir("b"))}}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 404, "the action is not found: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and the list is as it was")
}

/// <p>The directories and flags the screen's read lists, as <code>directory=flag</code> pairs joined with <code>|</code>.</p>
ClassMethod ScreenRows(Output pStatus As %Integer) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#READPATH, .pStatus, .tRead)
    Set tListed = ""
    If '$IsObject(tRead) || ('$IsObject(tRead.rows)) Quit tListed
    Set tIterator = tRead.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tListed = tListed _ $Select(tListed = "": "", 1: "|") _ tRow.Directory _ "=" _ tRow.Restricted
    }
    Quit tListed
}

/// <p>From an unrestricted list the add leaves the screen's read listing the manager directory and the new one (C2), and the
/// resolver every server-path consumer calls resolves a file under the new directory (Integration); after the remove it
/// answers <code>PATH.ROOT</code> for it, and the manager directory stays a root.</p>
/// <p>Mutation (Rule 19): drop the <code>Purpose</code> <code>PUT</code> step from
/// <method>OcuPilot.Port.AllowListPort.Plan</method>'s unrestricted add -- the list stays unrestricted and this goes red.</p>
Method TestAnAddFromAnUnrestrictedListReachesTheScreenAndTheResolver()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent")
    Set tSC = ..Post(..Change("remove", ..Manager()), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody), "409|ALLOWLIST.FALLBACK", "the unrestricted list's one row, the manager directory, cannot be removed")
    Set tSC = ..Post(..Change("add", ..Dir("a")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the add is accepted: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Set tExpected = ""
    Set tOrdered = ##class(OcuPilot.Port.AllowListPort).Ordered($ListBuild(..Manager(), ..Dir("a")))
    For tI = 1:1:$ListLength(tOrdered) Set tExpected = tExpected _ $Select(tExpected = "": "", 1: "|") _ $List(tOrdered, tI) _ "=1"
    Do $$$AssertEquals(..ScreenRows(.tReadStatus), tExpected, "the screen lists the manager directory and the new one")
    Do $$$AssertEquals(..ResolveUnder(..Dir("a")), "200|" _ ..Dir("a") _ "x.txt", "a file under the new directory resolves")
    Set tSC = ..Post(..Change("remove", ..Dir("a")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the remove is accepted")
    Do $$$AssertEquals(..ResolveUnder(..Dir("a")), "400|PATH.ROOT", "and the same file is refused PATH.ROOT")
    Do $$$AssertEquals(..RootsNow(), ..Manager(), "the manager directory stays a root")
}

/// <p>A remove that empties the list leaves a restricted list with no root (C2b): the screen's read lists nothing, the
/// resolver refuses a path under the removed directory and under the manager directory <code>PATH.ROOT</code>, and the
/// vendor's own check allows no directory -- an emptied list allows nothing, never everything.</p>
/// <p>Mutation (Rule 19): send <code>Purpose</code> <code>PUT {Restricted: false}</code> after a remove's <code>DELETE</code>
/// in <method>OcuPilot.Port.AllowListPort.Execute</method> -- the list answers the manager directory again and this goes
/// red.</p>
Method TestAnEmptiedListAllowsNothing()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSC = ..Post(..Change("remove", ..Dir("a")), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the last remove is accepted: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertEquals(..ScreenRows(.tReadStatus), "", "the screen lists no directory")
    Do $$$AssertEquals(..ResolveUnder(..Dir("a")) _ " " _ ..ResolveUnder(..Manager()), "400|PATH.ROOT 400|PATH.ROOT", "and a path under the removed directory or the manager directory is refused PATH.ROOT")
    Do $$$AssertEquals($ClassMethod("%CSP.Portal.Utils", "IsDirectoryAllowed", ..Dir("a")), 0, "the vendor's own check allows no directory")
}

/// <p>A body that is not a JSON object is 400 <code>AGENT.BADBODY</code>, a key beyond the three is 400
/// <code>PORT.FIELD.UNEXPECTED</code> naming it, and a value that is not a string is 400 <code>TOOL.ARGUMENTS</code>; none
/// changes the list.</p>
Method TestABodyThatIsNotTheThreeStringsIsRefused()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tCases = $ListBuild($ListBuild("[1]", "AGENT.BADBODY", ""), $ListBuild("not json", "AGENT.BADBODY", ""), $ListBuild({"Action": "add", "Directory": (..Dir("b")), "Purpose": "Other"}.%ToJSON(), "PORT.FIELD.UNEXPECTED", "Purpose"), $ListBuild({"Action": "add", "Directory": 5}.%ToJSON(), "TOOL.ARGUMENTS", ""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..Post($List(tCase, 1), .tStatus, .tBody)
        Set tField = ""
        If $IsObject(tBody) && ($IsObject(tBody.detail)) && ($IsObject(tBody.detail.violations)) Set tField = tBody.detail.violations.%Get(0).field
        Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody) _ "|" _ tField, "400|" _ $List(tCase, 2) _ "|" _ $List(tCase, 3), "case " _ tI)
    }
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and the list is as it was")
}

/// <p>The route asks the prohibited set after its fresh read: when the set's registry lists the allow-list tool as one the
/// agent can reach, the add is refused 403 <code>PROHIBITED.ALLOWLISTAGENT</code> and nothing is written; with the shipped
/// registry, which leaves the tool out, the same add goes through (C3).</p>
/// <p>Mutation (Rule 19): hand the second <code>Operation.Gate</code> call in
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleSave</method> an empty prohibited class -- the refusal leg goes
/// red.</p>
Method TestARouteWhoseToolTheAgentCanReachIsRefusedByTheKernel()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tBody = {"Action": "add", "Directory": (..Dir("b"))}
    Do $ClassMethod(..#SET, "Arm", $Parameter(..#TOOL, "TOOLNAME"))
    Set tSC = $ClassMethod(..#ROUTE, "Handle", tBody, .tAnswer, .tStatus)
    Do $ClassMethod(..#SET, "Disarm")
    Do $$$AssertStatusOK(tSC, "the route runs")
    Set tAnswer = $Select(tAnswer '= "": ##class(%DynamicObject).%FromJSON(tAnswer), 1: "")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "403|PROHIBITED.ALLOWLISTAGENT", "a tool the agent can reach is refused by the kernel")
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and nothing was written")
    Set tSC = $ClassMethod(..#ROUTE, "Handle", tBody, .tAnswer2, .tStatus2)
    Do $$$AssertEquals(tStatus2, 200, "while the shipped registry, which leaves the tool out, lets the same add through")
    Do $$$AssertEquals(..RootsNow(), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "and the real roots hold both")
}

/// <p>Another write holding the allow-list target keeps the route waiting for the hold, and it is then refused 409
/// <code>WRITE.TARGETBUSY</code> with nothing written (AD-34).</p>
/// <p>Mutation (Rule 19): drop the <code>HoldTool</code> call from
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleSave</method> -- the add is written and this goes red.</p>
Method TestAHeldTargetIsAnsweredBusyAndNothingIsWritten()
{
    Do ..EnableKey()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).TargetRefOf($Parameter(..#TOOL, "DESCRIPTORCLASS"), ..#PURPOSEID, .tRef)
    Do $$$AssertStatusOK(tSC, "the target's reference is built")
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey($Get(tRef))
    Do $$$AssertNotEquals(tLockKey, "", "the target names a lock")
    If tLockKey = "" Quit
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "this process holds it, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBody = ""
    Try {
        Set tSC = ..Post(..Change("add", ..Dir("b")), .tStatus, .tBody)
    } Catch {
        Set tStatus = 0
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tBody), "409|WRITE.TARGETBUSY", "the add on the held target is refused busy")
    Do $$$AssertEquals(..RootsNow(), ..Dir("a"), "and nothing was written")
}

}
