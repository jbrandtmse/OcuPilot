/// <p>Pins the gate on Story 20.31's resend and edit-and-resend against real principals (AD-8, AD-29, AD-44, AD-62): a principal missing
/// one pair -- the Interoperability menu's <code>%Ens_Portal:USE</code>, the message viewer's <code>%Ens_MessageHeader:USE</code>, the
/// Resend page's <code>%Ens_MessageResend:USE</code>, the Contents pane's <code>%Ens_MessageContent:USE</code>, the edit page's
/// <code>%Ens_MessageEditResend:USE</code>, or READ or WRITE on <code>USER</code>'s database -- is refused 403 naming that pair through
/// the port, on each tool's pairs (which the mint and the confirm evaluate), on the Messages and Header screens' dry-run and action
/// routes and on the agent's confirm, before any vendor call, so a refused call sends nothing; a principal holding exactly the set
/// reads, resends and edits through the port, the routes and a confirm.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes
/// identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> and creates eight users and roles named <code>OcuS31*</code>. Each principal also holds READ on the install
/// namespace's code database and <code>%Development:USE</code>, as every caller of a route must. The probe, its messages and the
/// principals are removed after the last test (<class>OcuPilot.Test.InteropResendCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropResendGate Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter GATE = "OcuPilot.Test.InteropItemGate";

Parameter PRINCIPALGATE = "OcuPilot.Test.InteropTestGate";

Parameter RESENDTOOL = "OcuPilot.Screen.Tool.InteropMessageResend";

Parameter EDITTOOL = "OcuPilot.Screen.Tool.InteropMessageEditResend";

Parameter RESENDKEY = "interop.messages.resend";

Parameter EDITKEY = "interop.messageheader.editresend";

Parameter MESSAGESCREEN = "/screens/interop.messages";

Parameter HEADERSCREEN = "/screens/interop.messageheader";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the set, then each missing one. <code>NoRead</code> holds no pair on the globals database and
/// <code>NoWrite</code> READ alone.</p>
Parameter PRINCIPALS = "OcuS31Exact:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U,%DB_USER:RW;OcuS31NoPortal:%Development:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U,%DB_USER:RW;OcuS31NoHeader:%Development:U,%Ens_Portal:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U,%DB_USER:RW;OcuS31NoResend:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageEditResend:U,%DB_USER:RW;OcuS31NoContent:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U,%DB_USER:RW;OcuS31NoEdit:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%DB_USER:RW;OcuS31NoRead:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U;OcuS31NoWrite:%Development:U,%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_MessageResend:U,%Ens_MessageEditResend:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>: the resend read and write of one message, then the
/// edit read and write of another.</p>
Parameter LEGS = "Messages|RESEND,Messages|RESENDMESSAGES,Messages|EDIT,Messages|EDITRESEND";

/// <p>What each principal's four port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or empty when the leg is
/// admitted&gt;</code> per leg in <parameter>LEGS</parameter> order, separated by <code>,</code>.</p>
Parameter EXPECTED = "OcuS31Exact=,,,;OcuS31NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuS31NoHeader=%Ens_MessageHeader:USE,%Ens_MessageHeader:USE,%Ens_MessageHeader:USE,%Ens_MessageHeader:USE;OcuS31NoResend=%Ens_MessageResend:USE,%Ens_MessageResend:USE,%Ens_MessageResend:USE,%Ens_MessageResend:USE;OcuS31NoContent=,,%Ens_MessageContent:USE,%Ens_MessageContent:USE;OcuS31NoEdit=,,%Ens_MessageEditResend:USE,%Ens_MessageEditResend:USE;OcuS31NoRead=%DB_USER:READ,%DB_USER:WRITE,%DB_USER:READ,%DB_USER:WRITE;OcuS31NoWrite=,%DB_USER:WRITE,,%DB_USER:WRITE";

/// <p>How many messages each principal's legs sent, <code>&lt;user&gt;=&lt;count&gt;</code> separated by <code>;</code>; a principal
/// not listed sent none.</p>
Parameter SENDS = "OcuS31Exact=2;OcuS31NoContent=1;OcuS31NoEdit=1";

/// <p>The first pair each principal fails the resend tool's pairs on, then the edit tool's, <code>&lt;user&gt;=&lt;resend&gt;|&lt;edit&gt;</code>.</p>
Parameter TOOLEXPECTED = "OcuS31Exact=|;OcuS31NoPortal=%Ens_Portal:USE|%Ens_Portal:USE;OcuS31NoHeader=%Ens_MessageHeader:USE|%Ens_MessageHeader:USE;OcuS31NoResend=%Ens_MessageResend:USE|%Ens_MessageResend:USE;OcuS31NoContent=|%Ens_MessageContent:USE;OcuS31NoEdit=|%Ens_MessageEditResend:USE;OcuS31NoRead=%DB_USER:WRITE|%DB_USER:WRITE;OcuS31NoWrite=%DB_USER:WRITE|%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropResendGate compiles a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Quit ##super()
}

Method OnPrepare() As %Status
{
    Set ..PreparedPassword = "OcuS31Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PRINCIPALGATE, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.InteropResendGate")
    If $$$ISERR(tSC) Quit tSC
    Set tOK = 1
    For tCase = $ListBuild("OcuS31Exact", "%Ens_MessageEditResend", "USE", 1), $ListBuild("OcuS31Exact", "%DB_USER", "WRITE", 1), $ListBuild("OcuS31NoResend", "%Ens_MessageResend", "USE", 0), $ListBuild("OcuS31NoContent", "%Ens_MessageContent", "USE", 0), $ListBuild("OcuS31NoEdit", "%Ens_MessageEditResend", "USE", 0), $ListBuild("OcuS31NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuS31NoWrite", "%DB_USER", "READ", 1), $ListBuild("OcuS31NoWrite", "%DB_USER", "WRITE", 0) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
            Set tOK = 0
            Quit
        }
    }
    Quit $Select(tOK: $$$OK, 1: $$$ERROR($$$GeneralError, "a principal's decisive grant did not read back as declared"))
}

/// <p>Delete the principals and their roles; a failing status when any survives.</p>
Method OnRelease() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropResendGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>The text after <code>=</code> of <var>pUser</var>'s entry in the table <var>pTable</var> (<code>;</code>-separated entries).</p>
ClassMethod EntryFor(pTable As %String, pUser As %String) As %String
{
    For tI = 1:1:$Length(pTable, ";") {
        Set tEntry = $Piece(pTable, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Quit $Select($Piece(tEntry, "=", 1) = pUser: $Piece(tEntry, "=", 2), 1: "")
}

/// <p>AC6: each principal's four port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal; the principals admitted to a write sent exactly the messages <parameter>SENDS</parameter>
/// says, and a refused leg sent none.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageEditResend:USE</code> from the edit branch of <method>OcuPilot.Port.InteropPort.Pairs</method>
/// -- the missing-edit principal's edit legs reach the vendor and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    Set tResend = ..Make("gate resend")
    Set tEdit = ..Make("gate edit")
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tTop = $ClassMethod(..#FIXTURE, "TopId")
        Set tProbe = ..ProbeAs(tUser, tResend, tEdit)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tExpected = $ListFromString(..EntryFor(..#EXPECTED, tUser), ",")
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted), tUser _ ": " _ tLeg)
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, +..EntryFor(..#SENDS, tUser), tUser _ ": the legs sent " _ (+..EntryFor(..#SENDS, tUser)) _ " message(s)")
    }
}

/// <p>AC6: the two tools' pairs, evaluated for each principal in the namespace the request is scoped to, fail naming the first pair the
/// principal lacks -- the screen's pairs, the Resend page's (and for the edit the Contents pane's and the edit page's), then WRITE on
/// the globals database; the exact principal holds every pair. The mint and the confirm evaluate these same lists.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageEditResend:USE</code> from <method>OcuPilot.Screen.Tool.InteropMessageEditResend.PrivilegePairs</method>
/// -- the missing-edit row goes red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheTools()
{
    Set tResend = ..Make("gate resend")
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser, tResend, tResend, "")
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        Set tWanted = ..EntryFor(..#TOOLEXPECTED, tUser)
        Set tGot = $Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get("resend") _ "|" _ tProbe.tools.%Get("edit"), 1: "absent")
        Do $$$AssertEquals(tGot, tWanted, tUser _ ": the tools fail on " _ tWanted)
    }
}

/// <p>AC6: on the routes each principal is refused naming the pair the screen's action needs, on the dry run and on the action, before
/// any message is read or sent; the person's route for the list's resend and the Header tab's edit are each asked, and a principal
/// without READ on the namespace's database is refused naming it.</p>
/// <p>Mutation (Rule 19): drop the pair gate from <method>OcuPilot.Api.ScreenAction.Run</method> -- the dry-run rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tResend = ..Make("gate resend")
    Set tEdit = ..Make("gate edit")
    Do ..EnableKey(..#RESENDKEY)
    Do ..EnableKey(..#EDITKEY)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    For tCase = $ListBuild("OcuS31NoPortal", "%Ens_Portal:USE", "%Ens_Portal:USE"), $ListBuild("OcuS31NoHeader", "%Ens_MessageHeader:USE", "%Ens_MessageHeader:USE"), $ListBuild("OcuS31NoResend", "%Ens_MessageResend:USE", "%Ens_MessageResend:USE"), $ListBuild("OcuS31NoContent", "", "%Ens_MessageContent:USE"), $ListBuild("OcuS31NoEdit", "", "%Ens_MessageEditResend:USE"), $ListBuild("OcuS31NoWrite", "%DB_USER:WRITE", "%DB_USER:WRITE"), $ListBuild("OcuS31NoRead", "%DB_USER:READ", "%DB_USER:READ") {
        Set tUser = $List(tCase, 1)
        Set tResendRoutes = ..Through(..#MESSAGESCREEN, "resend", tResend, "", tUser)
        Set tEditRoutes = ..Through(..#HEADERSCREEN, "editresend", tEdit, "{""StringValue"":""x""}", tUser)
        Do $$$AssertEquals($Piece(tResendRoutes, "~", 1) _ "|" _ $Piece(tResendRoutes, "~", 2), $Select($List(tCase, 2) = "": "200 |200 ", 1: "403 " _ $List(tCase, 2) _ "|403 " _ $List(tCase, 2)), tUser _ ": the resend's dry run and action: " _ tResendRoutes)
        Do $$$AssertEquals($Piece(tEditRoutes, "~", 1) _ "|" _ $Piece(tEditRoutes, "~", 2), "403 " _ $List(tCase, 3) _ "|403 " _ $List(tCase, 3), tUser _ ": the edit's dry run and action: " _ tEditRoutes)
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 2, "only the two principals admitted to the resend sent, one message each")
}

/// <p>The dry run and then the action of <var>pAction</var> on <var>pScreen</var> for <var>pId</var> as <var>pUser</var>, as
/// <code>dryrun~action</code> each <code>status failedPair</code>; the action carries the dry run's digest, or a digest of zeros when the
/// review was refused, so a refusal of the action is the gate's and not the value's.</p>
Method Through(pScreen As %String, pAction As %String, pId As %String, pFields As %String, pUser As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If pFields '= "" Do tBody.%Set("values", {}.%Set("fields", pFields, "string"))
    Set tStatus = ..PostAs(pScreen _ "/dryrun", tBody, pUser, .tRaw)
    Set tDry = tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw)
    Set tDigest = ""
    Try { Set tDigest = ##class(%DynamicObject).%FromJSON(tRaw).review.Digest } Catch {}
    If tDigest = "" Set tDigest = $Translate($Justify("", 64), " ", "0")
    If tBody.%GetTypeOf("values") '= "object" Do tBody.%Set("values", {})
    Do tBody.values.%Set("Reviewed", tDigest, "string")
    Set tStatus = ..PostAs(pScreen _ "/action", tBody, pUser, .tRaw)
    Quit tDry _ "~" _ tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw)
}

/// <p><var>pBody</var> posted to <var>pPath</var> as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>; the status, and the
/// raw answer in <var>pRaw</var>.</p>
Method PostAs(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as <var>pUser</var>: the status, and the raw answer in <var>pRaw</var>.</p>
Method ConfirmAs(pProposalId As %String, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ pProposalId _ "/confirm?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, "", "application/json", .tExtra, 180)
    Quit +$Get(tStatus)
}

/// <p>AC6: a principal holding exactly the pairs completes both writes: through the port (the first test), through the routes -- the
/// review and the action of the resend and of the edit -- and through the agent's confirm of a proposal minted for it, while the
/// principals missing the resend page's pair and the edit page's pair are each refused that confirm, naming the pair, with nothing
/// sent.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Port.InteropPort.PerformEditResend</method> set a node of <code>^%SYS</code>, a
/// database the pairs do not grant -- the exact principal's edit is answered 500 and this goes red.</p>
Method TestAPrincipalHoldingExactlyThePairsCompletesResendAndEdit()
{
    Set tResend = ..Make("gate resend")
    Set tEdit = ..Make("gate edit")
    Do ..EnableKey(..#RESENDKEY)
    Do ..EnableKey(..#EDITKEY)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tRoutes = ..Through(..#MESSAGESCREEN, "resend", tResend, "", "OcuS31Exact")
    Do $$$AssertEquals(tRoutes, "200 ~200 ", "the exact principal reviews and sends the resend through the routes: " _ tRoutes)
    Set tRoutes = ..Through(..#HEADERSCREEN, "editresend", tEdit, "{""StringValue"":""edited""}", "OcuS31Exact")
    Do $$$AssertEquals(tRoutes, "200 ~200 ", "and the edit: " _ tRoutes)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 2, "two messages were sent")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    For tI = 1:1:4 {
        Set tTool = $Select(tI '= 2 && (tI '= 4): ..#RESENDTOOL, 1: ..#EDITTOOL)
        Set tArgs = $Select(tI = 1 || (tI = 3): {"Messages": (tResend)}, 1: {"Message": (tEdit), "Fields": {"StringValue": "agent"}})
        Set tUser = $Case(tI, 1: "OcuS31Exact", 2: "OcuS31Exact", 3: "OcuS31NoResend", : "OcuS31NoEdit")
        Set tWanted = $Case(tI, 3: "403 %Ens_MessageResend:USE", 4: "403 %Ens_MessageEditResend:USE", : "200 ")
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", tTool, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, tUser _ ": " _ $Parameter(tTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tStatus = ..ConfirmAs(tProposal.proposalId, tUser, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw), tWanted, tUser _ ": the confirm of " _ $Parameter(tTool, "TOOLNAME") _ ": " _ $Extract(tRaw, 1, 200))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 2, "the exact principal's two confirms sent, and the refused two did not")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pResendId As %String, pEditId As %String, pLegs As %String = {..#LEGS}) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropResendGate).Probe($Job, pUser, ..#NAMESPACE, pResendId, pEditId, pLegs)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <var>pLegs</var>
/// through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the message <var>pResendId</var> (the resend legs)
/// and <var>pEditId</var> (the edit legs, changing <code>StringValue</code>), evaluate each tool's pairs for a request scoped to
/// <var>pNamespace</var>, and signal <code>{loggedIn, username, "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}, tools: {resend,
/// edit}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pResendId As %String, pEditId As %String, pLegs As %String = {..#LEGS})
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(pLegs, ",") {
            Set tLegName = $Piece(pLegs, ",", tI)
            If tLegName = "" Continue
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("id") = $Select(tType [ "EDIT": pEditId, 1: pResendId)
            If tType = "EDITRESEND" Set tQuery("fields") = "{""StringValue"":""probe""}"
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), tType, .tQuery, "", .tResult, .tHttp, .tFault)
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
        For tCase = $ListBuild("resend", ..#RESENDTOOL), $ListBuild("edit", ..#EDITTOOL) {
            Set tPairs = $ClassMethod($List(tCase, 2), "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tTools.%Set($List(tCase, 1), tFailed)
        }
        Do tOut.%Set("tools", tTools)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
