/// <p>Pins Story 24.3's gate against real principals (AD-8, AD-29, AD-62): a principal missing one pair -- the Interoperability menu's
/// <code>%Ens_Portal:USE</code>, Productions' <code>%Ens_ProductionConfig:READ</code>, auto-start's <code>%Ens_ProductionConfig:WRITE</code>,
/// the shutdown group's <code>%Admin_Manage:USE</code>, or WRITE on <code>USER</code>'s database -- is refused 403 naming that pair, through the
/// port and on each tool's pairs, before any vendor call, so the startup settings are never changed by a refused call; and a principal
/// holding exactly the set reads and writes them. With a second interoperability namespace registered whose settings the principal cannot
/// read, a group or priority change is refused 403 <code>INTEROP.STARTUP.ALLNAMESPACES</code> by the vendor's own all-namespaces read, and
/// turning auto-start on at the priority the read answered, and off, is admitted.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles the probe productions in <code>USER</code>
/// (<class>OcuPilot.Test.ProductionProbe</class>), creates six users and roles named <code>OcuP243*</code> and, for one test, registers
/// <code>HSSYS</code> as a second interoperability namespace for the length of the test. Each principal also holds READ on the install
/// namespace's code database and <code>%Development:USE</code>, as every caller of a route must. Everything is put back after each test.</p>
Class OcuPilot.Test.InteropStartupGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The namespace registered as a second interoperability one, whose settings a principal without its database cannot read.</p>
Parameter SECONDNAMESPACE = "HSSYS";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: exactly the
/// set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP243Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%Admin_Manage:U,%DB_USER:RW;OcuP243NoPortal:%Development:U,%Ens_ProductionConfig:RW,%Admin_Manage:U,%DB_USER:RW;OcuP243NoRead:%Development:U,%Ens_Portal:U,%Admin_Manage:U,%DB_USER:RW;OcuP243NoConfigWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Admin_Manage:U,%DB_USER:RW;OcuP243NoManage:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP243NoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%Admin_Manage:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;type&gt;|&lt;body&gt;</code>, separated by <code>;</code>. A write is undone by the next, so a
/// principal admitted to all of them leaves the settings as it found them.</p>
Parameter LEGS = "STARTUP|;AUTOSTART|{""AutoStart"":""1""};AUTOSTART|{""AutoStart"":""0""};SHUTDOWNGROUP|{""ShutdownGroup"":""3""};SHUTDOWNGROUP|{""ShutdownGroup"":""2""}";

/// <p>The tools whose pairs a probe evaluates.</p>
Parameter TOOLS = "InteropProductionAutoStart,InteropProductionShutdownGroup";

/// <p>What each principal's five legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or empty when the leg is admitted&gt;</code> per leg
/// in <parameter>LEGS</parameter> order, separated by <code>,</code>; then the pair each tool's pairs fail on.</p>
Parameter EXPECTED = "OcuP243Exact=,,,,|;OcuP243NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE|%Ens_Portal:USE,%Ens_Portal:USE;OcuP243NoRead=%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ|%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP243NoConfigWrite=,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE,,|%Ens_ProductionConfig:WRITE,;OcuP243NoManage=,,,%Admin_Manage:USE,%Admin_Manage:USE|,%Admin_Manage:USE;OcuP243NoWrite=,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE|%DB_USER:WRITE,%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupGate compiles probe productions in USER, sets its startup settings and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP243Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set ..PreparedStartup = $ClassMethod(..#PROBE, "SaveStartup")
    If ..PreparedStartup = "" Quit $$$ERROR($$$GeneralError, "USER's startup settings could not be read")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe, the principals and their roles, and any registration of the second namespace; a failing status when any survives.</p>
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Each test starts with no production of <code>USER</code> starting with the instance, since its legs turn auto-start on and then off;
/// <method>OnAfterOneTest</method> puts back what the class found.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedRegistered = ''$Data(^%SYS("Ensemble", "InstalledNamespace", ..#SECONDNAMESPACE))
    Set ..AddedRegistration = 0
    Set tNow = $ClassMethod(..#PROBE, "SaveStartup")
    If tNow = "" Quit $$$ERROR($$$GeneralError, "USER's startup settings could not be read")
    Quit $ClassMethod(..#PROBE, "RestoreStartup", $ListBuild("", "", $List(tNow, 3), $List(tNow, 4)))
}

Method OnAfterOneTest() As %Status
{
    Do ..Unregister()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreStartup", ..PreparedStartup), "USER's startup settings are put back")
    Do $$$AssertEquals(''$Data(^%SYS("Ensemble", "InstalledNamespace", ..#SECONDNAMESPACE)), ..PreparedRegistered, "and the second namespace is registered as it was before the test")
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

/// <p>The expected failed pairs of <var>pUser</var>: the five legs' as comma-separated text in <var>pLegs</var>, then each tool's in
/// <var>pTools</var>, each read with <code>$Piece</code> because an admitted leg's is empty.</p>
ClassMethod ExpectedFor(pUser As %String, Output pLegs As %String, Output pTools As %String)
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Set tRest = $Piece(tEntry, "=", 2)
    Set pLegs = $Piece(tRest, "|", 1)
    Set pTools = $Piece(tRest, "|", 2)
}

/// <p>Each principal's five port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal; each tool's pairs fail on the pair it says; and the startup settings are as they were after
/// every principal's run.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePortAndTheTools()
{
    Set tBefore = $ClassMethod(..#PROBE, "SaveStartup")
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser, ..#LEGS)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Do ..ExpectedFor(tUser, .tLegs, .tTools)
        For tJ = 1:1:$Length(..#LEGS, ";") {
            Set tWanted = $Piece(tLegs, ",", tJ)
            Do $$$AssertEquals(..LegText(tProbe, tJ), $Select(tWanted = "": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted), tUser _ ": " _ $Piece($Piece(..#LEGS, ";", tJ), "|", 1) _ " leg " _ tJ)
        }
        For tJ = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tJ)
            Set tWanted = $Piece(tTools, ",", tJ)
            Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tTool), 1: "absent"), tWanted, tUser _ ": " _ tTool _ " fails on " _ $Select(tWanted = "": "nothing", 1: tWanted))
        }
        Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(tBefore), tUser _ ": the startup settings are as they were")
    }
}

/// <p>With <parameter>SECONDNAMESPACE</parameter> registered as an interoperability namespace the principal cannot read, the vendor's own
/// all-namespaces read answers an error: a group change and a priority change are refused 403 <code>INTEROP.STARTUP.ALLNAMESPACES</code> and
/// change nothing, while turning auto-start on at the priority the read answered and off is admitted. Without the registration the same
/// group change is admitted.</p>
Method TestAChangeNeedsEveryNamespacesSettingsRead()
{
    Set tLegs = "AUTOSTART|{""AutoStart"":""1""};AUTOSTART|{""AutoStart"":""1"",""StartupPriority"":""7""};SHUTDOWNGROUP|{""ShutdownGroup"":""3""};AUTOSTART|{""AutoStart"":""0""}"
    Set tBefore = $ClassMethod(..#PROBE, "SaveStartup")
    Do ..Register()
    Set tProbe = ..ProbeAs("OcuP243Exact", tLegs)
    Do ..Unregister()
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|OcuP243Exact", "the probe ran as the exact principal: " _ tProbe.%ToJSON())
    Set tAll = ##class(OcuPilot.Api.InteropError).#STARTUPALLNAMESPACES
    Do $$$AssertEquals(..LegText(tProbe, 1), "200  ", "turning auto-start on at the priority the read answered is admitted")
    Do $$$AssertEquals(..LegText(tProbe, 2), "403 " _ tAll _ " ", "a priority change is refused ALLNAMESPACES")
    Do $$$AssertEquals(..LegText(tProbe, 3), "403 " _ tAll _ " ", "a group change is refused ALLNAMESPACES")
    Do $$$AssertEquals(..LegText(tProbe, 4), "200  ", "and turning auto-start off is admitted")
    Do $$$AssertEquals(tProbe.%Get("namespace"), $NAMESPACE, "the principal's namespace is as the vendor's reads found it")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(tBefore), "and neither refused change was made")
    Set tProbe = ..ProbeAs("OcuP243Exact", "SHUTDOWNGROUP|{""ShutdownGroup"":""3""};SHUTDOWNGROUP|{""ShutdownGroup"":""2""}")
    Do $$$AssertEquals(..LegText(tProbe, 1) _ "|" _ ..LegText(tProbe, 2), "200  |200  ", "with no second namespace registered the group changes are admitted")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process for <var>pLegs</var> and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pLegs As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropStartupGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION, pLegs)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>One leg of a probe as <code>http code failedPair</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %Integer) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get("L" _ pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get("L" _ pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <var>pLegs</var> through
/// <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> naming <var>pId</var>, evaluate each of <parameter>TOOLS</parameter>' pairs
/// for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username, namespace, L&lt;n&gt;: {http, code, failedPair}, tools:
/// {&lt;tool&gt;: failed pair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pId As %String, pLegs As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(pLegs, ";") {
            Set tLeg = $Piece(pLegs, ";", tI)
            Set tType = $Piece(tLeg, "|", 1)
            Set tBodyText = $Piece(tLeg, "|", 2, *)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("id") = pId
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Productions", tType, .tQuery, $Select(tBodyText = "": "", 1: ##class(%DynamicObject).%FromJSON(tBodyText)), .tResult, .tHttp, .tFault)
            Set tOne = {}
            Do tOne.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tOne.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tOne.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set("L" _ tI, tOne)
        }
        Do tOut.%Set("namespace", $NAMESPACE)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tTools = {}
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Set tPairs = $ClassMethod("OcuPilot.Screen.Tool." _ tTool, "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tTools.%Set(tTool, tFailed)
        }
        Do tOut.%Set("tools", tTools)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
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
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the startup settings' gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot startup settings gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropStartupGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP243Exact", "%Admin_Manage", "USE", 1), $ListBuild("OcuP243NoManage", "%Admin_Manage", "USE", 0), $ListBuild("OcuP243NoConfigWrite", "%Ens_ProductionConfig", "WRITE", 0), $ListBuild("OcuP243NoRead", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP243NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP243NoWrite", "%DB_USER", "WRITE", 0) {
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
