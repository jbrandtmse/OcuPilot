/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the business partner endpoint and the three partner write tools' pairs
/// against real principals (AD-8, AD-29, AD-44, AD-62, Story 20.26): a principal missing one pair -- the Interoperability menu's
/// <code>%Ens_Portal:USE</code>, the classic partners page's <code>%Ens_ProductionConfig:READ</code> or the write's
/// <code>%Ens_ProductionConfig:WRITE</code>, READ on <code>USER</code>'s database or, for a write, WRITE on it -- is refused 403 naming
/// that pair through the port, on the screen routes, on the Save route and on each tool's pairs, before any vendor call, so a refused
/// call changes no partner; a principal holding exactly the set reads and writes through the port and the screen, and a holder of only
/// <code>%Ens_ProductionConfig:READ</code>, which the classic page admits to its own saves, is refused every write.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes
/// identity. The principals are made and deleted by <class>OcuPilot.Test.InteropLookupGate</class>'s generator.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named
/// <code>OcuP226*</code> and writes probe partners in <code>USER</code>. Each principal also holds READ on the install namespace's
/// code database and <code>%Development:USE</code>, as every caller of a route must. The principals and the partners are removed after
/// the last test.</p>
Class OcuPilot.Test.InteropPartnerGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter GENERATOR = "OcuPilot.Test.InteropLookupGate";

Parameter NAMESPACE = "USER";

Parameter PARTNER = "OcuProbe226Gate";

Parameter ADDED = "OcuProbe226GateAdded";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the partner write set, the classic page's own set (READ only), then each missing one.</p>
Parameter PRINCIPALS = "OcuP226Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP226ReadOnly:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%DB_USER:RW;OcuP226NoPortal:%Development:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP226NoCfg:%Development:U,%Ens_Portal:U,%DB_USER:RW;OcuP226DbReadOnly:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:R;OcuP226NoRead:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>. The add comes before the set and the remove,
/// and the set and the remove take the probe partner the fixture keeps, so a principal admitted to all leaves only the partner its
/// add made.</p>
Parameter LEGS = "BusinessPartners|LIST,BusinessPartners|PARTNER,BusinessPartners|ADDPARTNER,BusinessPartners|SETPARTNER,BusinessPartners|REMOVEPARTNER";

/// <p>The legs of <parameter>LEGS</parameter> that write a partner, delimited by commas.</p>
Parameter WRITELEGS = ",BusinessPartners|ADDPARTNER,BusinessPartners|SETPARTNER,BusinessPartners|REMOVEPARTNER,";

/// <p>The tools whose pairs the probe evaluates.</p>
Parameter TOOLS = "InteropPartnerAdd,InteropPartnerUpdate,InteropPartnerRemove";

/// <p>The pair a refused leg of each principal names, one per leg of <parameter>LEGS</parameter>, <code>,</code>-separated (empty
/// for an admitted leg), after <code>=</code>; and the first pair each principal fails on for each of <parameter>TOOLS</parameter>,
/// <code>,</code>-separated, after the <code>/</code>.</p>
Parameter EXPECTED = "OcuP226Exact=,,,,/,,;OcuP226ReadOnly=,,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE/%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE;OcuP226NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE/%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP226NoCfg=%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ/%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP226DbReadOnly=,,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE/%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE;OcuP226NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE/%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE";

/// <p>The principals' password for this run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPartnerGate creates and deletes users and roles and writes probe business partners on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP226Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "the partner endpoint's gate")
    If $$$ISOK(tSC) Set tSC = ..ReadBack()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals and their roles and the probe partners; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

/// <p>The decisive grants of the principals, read back from the instance: the write pair of the exact principal and not of the one
/// the classic page admits, and the pairs the others lack.</p>
ClassMethod ReadBack() As %Status
{
    For tCase = $ListBuild("OcuP226Exact", "%Ens_ProductionConfig", "WRITE", 1), $ListBuild("OcuP226ReadOnly", "%Ens_ProductionConfig", "READ", 1), $ListBuild("OcuP226ReadOnly", "%Ens_ProductionConfig", "WRITE", 0), $ListBuild("OcuP226NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP226NoCfg", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP226DbReadOnly", "%DB_USER", "WRITE", 0), $ListBuild("OcuP226DbReadOnly", "%DB_USER", "READ", 1), $ListBuild("OcuP226NoRead", "%DB_USER", "READ", 0) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) Quit $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
    }
    Quit $$$OK
}

/// <p>The entry of <parameter>EXPECTED</parameter> for <var>pUser</var>: the legs' pairs in <var>pLegs</var> and the tools' first
/// failed pairs in <var>pTools</var>, each a <code>%List</code>.</p>
ClassMethod ExpectedFor(pUser As %String, Output pLegs As %List, Output pTools As %List)
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Set tBody = $Piece(tEntry, "=", 2)
    Set pLegs = $ListFromString($Piece(tBody, "/", 1), ",")
    Set pTools = $ListFromString($Piece(tBody, "/", 2), ",")
}

/// <p>The probe partner, held with its fields, as every probe starts.</p>
ClassMethod Arrange() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "PutPartner", ..#PARTNER)
}

/// <p>The probe partners held, as <code>name=description|primary phone;...</code> in name order.</p>
ClassMethod Held() As %String
{
    Set tText = ""
    Set tPrefix = $Parameter(..#FIXTURE, "PARTNERPREFIX")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tName = ""
        For {
            Set tName = $Order(^Ens.Config.BusinessPartnerD(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(tPrefix)), "U") '= $ZConvert(tPrefix, "U") Continue
            Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(tName)
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tName _ "=" _ tPartner.Description _ "|" _ $Select($IsObject(tPartner.PrimaryContact): tPartner.PrimaryContact.PhoneNumber, 1: "")
            Set tPartner = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>The code a refusal naming <var>pPair</var> carries.</p>
ClassMethod CodeFor(pPair As %String) As %String
{
    Quit "AUTH.NOPRIVILEGE"
}

/// <p>AC5: each principal's five port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal, before any vendor call: a refused leg changes no partner, and the exact principal's add,
/// set and remove leave only the partner its add made.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from <parameter>OcuPilot.Port.InteropPort.PARTNERWRITEPAIR</parameter>
/// by making <method>OcuPilot.Port.InteropPort.Pairs</method> skip it -- the read-only principal's write legs reach the vendor and this
/// goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the probe partner is arranged")
        Set tBefore = ..Held()
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Do ..ExpectedFor(tUser, .tExpected)
        Set tWrites = 0
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals(##class(OcuPilot.Test.InteropItemGate).LegText(tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 " _ ..CodeFor(tWanted) _ " " _ tWanted), tUser _ ": " _ tLeg)
            If (tWanted = "") && (..#WRITELEGS [ ("," _ tLeg _ ",")) Set tWrites = 1
        }
        If 'tWrites Do $$$AssertEquals(..Held(), tBefore, tUser _ ": a refused leg changed no partner")
        Do $ClassMethod(..#FIXTURE, "Clear")
    }
}

/// <p>AC5: each of the three tools' pairs, evaluated for each principal in the namespace the request is scoped to, fail naming the
/// first pair the principal lacks, in the order screen pairs, the tool's own resource (<code>%Ens_ProductionConfig:WRITE</code>),
/// database permission; the exact principal holds every pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method> by naming READ in <parameter>WRITEPERMISSION</parameter> of
/// <class>OcuPilot.Screen.Tool.InteropPartnerAction</class> -- the read-only principal's rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnEachTool()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do ..ExpectedFor(tUser, .tExpected, .tWanted)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        For tJ = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tJ)
            Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tTool), 1: "absent"), $List(tWanted, tJ), tUser _ ": " _ tTool _ " fails on " _ $Select($List(tWanted, tJ) = "": "nothing", 1: $List(tWanted, tJ)))
        }
        Do $ClassMethod(..#FIXTURE, "Clear")
    }
}

/// <p>AC5: on the screen routes each principal is refused naming the pair its read or action needs, before the partner is read or
/// written: the partners list's read, the Edit and Remove row actions and the Save, the last also for a body the rules after the gate
/// would refuse, so the refusal is the Save's own gate and not a later one; and the exact principal reads and writes through the
/// screen.</p>
/// <p>Mutation (Rule 19): delete the <code>..Gate</code> call from <method>OcuPilot.Area.Interop.ItemSave.HandleCreate</method> -- the
/// illegal-name Save rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Do $$$AssertStatusOK(..Arrange(), "the probe partner is arranged")
    For tCase = $ListBuild("OcuP226NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP226NoCfg", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP226NoRead", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/interop.businesspartners/read?ns=" _ ..#NAMESPACE _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the partners read is refused naming the pair: " _ $Get(tRaw))
    }
    Set tBefore = ..Held()
    For tCase = $ListBuild("OcuP226NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP226NoCfg", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP226ReadOnly", "%Ens_ProductionConfig:WRITE"), $ListBuild("OcuP226DbReadOnly", "%DB_USER:WRITE"), $ListBuild("OcuP226NoRead", "%DB_USER:READ") {
        Set tRequest = {"action": "edit", "values": (##class(OcuPilot.Test.InteropPartnerControl).Values({"Description": "gate"}))}
        Do tRequest.%Set("id", ..#PARTNER, "string")
        Set tStatus = ..Post("/screens/interop.businesspartners/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Edit row action is refused naming the pair: " _ $Get(tRaw))
        Set tRequest = {"action": "remove"}
        Do tRequest.%Set("id", ..#PARTNER, "string")
        Set tStatus = ..Post("/screens/interop.businesspartners/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Remove row action is refused naming the pair: " _ $Get(tRaw))
        Set tStatus = ..Post("/interop/business-partners", {"Name": (..#ADDED)}, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Save is refused naming the pair: " _ $Get(tRaw))
        Set tStatus = ..Post("/interop/business-partners", {"Name": ""}, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": a Save of an empty name is refused naming the pair, not the name: " _ $Get(tRaw))
    }
    Do $$$AssertEquals(..Held(), tBefore, "no refused request changed a partner")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/interop.businesspartners/read?ns=" _ ..#NAMESPACE _ "&maxRows=50", "OcuP226ReadOnly", ..PreparedPassword, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "a principal holding only the READ pair reads the partners: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertTrue($Get(tRaw) [ ..#PARTNER, "and sees the probe partner")
    Set tRequest = {"action": "edit", "values": (##class(OcuPilot.Test.InteropPartnerControl).Values({"Description": "gate"}))}
    Do tRequest.%Set("id", ..#PARTNER, "string")
    Do $$$AssertEquals(..Post("/screens/interop.businesspartners/action", tRequest, "OcuP226Exact", .tRaw), 200, "the exact principal's Edit is admitted: " _ $Get(tRaw))
    Do $$$AssertEquals(..Post("/interop/business-partners", {"Name": (..#ADDED), "Description": "v"}, "OcuP226Exact", .tRaw), 201, "and its Save: " _ $Get(tRaw))
    Set tRequest = {"action": "remove"}
    Do tRequest.%Set("id", ..#PARTNER, "string")
    Do $$$AssertEquals(..Post("/screens/interop.businesspartners/action", tRequest, "OcuP226Exact", .tRaw), 200, "and its Remove: " _ $Get(tRaw))
    Set tHeld = ..Held()
    Do $$$AssertEquals(tHeld, ..#ADDED _ "=v|", "which wrote what they sent: " _ tHeld)
}

/// <p>The person's POST to <var>pPath</var> as <var>pUser</var>: the HTTP status; the raw body in <var>pRaw</var>.</p>
Method Post(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropPartnerGate).Probe($Job, pUser, ..#NAMESPACE)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter>
/// through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the probe partner, evaluate each of
/// <parameter>TOOLS</parameter>' pairs for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username,
/// "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}, tools: {&lt;tool&gt;: failed pair}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String)
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
            Set tLegName = $Piece(..#LEGS, ",", tI)
            Set tEndpoint = $Piece(tLegName, "|", 1)
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tBody = ""
            If tType = "LIST" {
                Set tQuery("maxRows") = 5
            } Else {
                Set tQuery("id") = $Select(tType = "ADDPARTNER": ..#ADDED, 1: ..#PARTNER)
                If tType = "ADDPARTNER" Set tBody = {"Description": "gate"}
                If tType = "SETPARTNER" Set tBody = {"Description": "gate2"}
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
            Do tOut.%Set(tLegName, tLeg)
        }
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

}
