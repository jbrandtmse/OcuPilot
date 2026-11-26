/// <p>Pins Story 24.17 Batch 2's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): every read and purge of the two logs is refused before any vendor call and before any value
/// is judged, naming the pair that fails: the portal's, the classic page's own resource, the purge resource a purge adds, WRITE on the namespace's database and, for a read, the SQL SELECT
/// privilege on the log's table, which a list alone is asked. The last is pinned by equality with the classic page: for each principal and each log, the list is admitted exactly when the classic page's own query prepares as
/// that principal through <class>%Library.ResultSet</class>, and is refused exactly when that answers <code>#5580</code>. A refused purge changes nothing and an admitted one deletes the old probe.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropLogPurgeCase</class> needs; it creates and removes seven principals and their SQL grants in <code>USER</code>.</p>
Class OcuPilot.Test.InteropLogPurgeGate Extends OcuPilot.Test.InteropLogPurgeCase
{

Parameter CHILD = "OcuPilot.Test.InteropLogPurgeChild";

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The pairs every principal holds unless its entry leaves one out, and the principals: all of them, without the purge resource, with READ on <code>USER</code>'s database only, without the rule
/// log's resource, without the business process resource, and (the same pairs as the first) with no SQL grant.</p>
Parameter BASE = "%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW";

Parameter PRINCIPALS = "OcuP2417gAll:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gNoPurge:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gDbRead:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:R,%DB_HSCUSTOM:RW;OcuP2417gNoRule:%Ens_Portal:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gNoJobs:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gNoSelect:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW";

/// <p>The principals of the equality legs: the same pairs and the SQL privilege through the Ensemble operator role, on the rule log's table alone, and none at all; one holding only READ on the
/// two databases; <code>_SYSTEM</code> holds <code>%All</code>.</p>
Parameter EQUALITYPRINCIPALS = "OcuP2417gOp:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gOne:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417gDb:%DB_USER:R,%DB_HSCUSTOM:R";

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
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2417g" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Do ..RevokeAll()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#EQUALITYPRINCIPALS))
    Quit tSC
}

/// <p>Take back every SQL grant the principals were given, which a deleted role would leave behind.</p>
ClassMethod RevokeAll()
{
    For tUser = "OcuP2417gAll", "OcuP2417gNoPurge", "OcuP2417gDbRead", "OcuP2417gNoRule", "OcuP2417gNoJobs" {
        Do $ClassMethod(..#FIXTURE, "RevokeSelect", tUser _ "Role")
    }
    Do $ClassMethod(..#FIXTURE, "Sql", ..#SOURCE, "REVOKE SELECT ON Ens_Rule.Log FROM OcuP2417gOneRole")
}

/// <p>Create the principals of <parameter>PRINCIPALS</parameter> and give each but the one without a grant the SQL SELECT on both tables.</p>
Method CreateGated() As %Status
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    For tUser = "OcuP2417gAll", "OcuP2417gNoPurge", "OcuP2417gDbRead", "OcuP2417gNoRule", "OcuP2417gNoJobs" {
        If '$ClassMethod(..#FIXTURE, "GrantSelect", tUser _ "Role") {
            Set tSC = $$$ERROR($$$GeneralError, "the SQL SELECT grant to " _ tUser _ "Role failed")
            Quit
        }
    }
    Quit tSC
}

/// <p>The answer a leg is expected to carry, <code>http|code|failedPair</code>: <var>pPair</var> empty is an admitted call.</p>
ClassMethod Expect(pPair As %String = "") As %String
{
    If pPair = "" Quit "200||"
    Quit "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ pPair
}

/// <p>AC3: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, naming the pair: a principal holding every pair and the SQL SELECT reads and
/// purges both logs and deletes the old probes; one without <code>%Ens_Purge:USE</code> reads and is refused each purge naming it; one who can only read <code>USER</code>'s database reads and is refused each
/// purge naming <code>%DB_USER:WRITE</code>; one without the rule log's resource is refused each rule log call naming it, and one without the business process resource each business process call;
/// and one with every pair and no SQL SELECT is refused each list naming the table and <code>SELECT</code> while its state reads and purges, which the classic pages ask no SQL privilege of, run
/// and answer the log's count. A refused purge changed nothing.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.LOGPURGEPAIR</parameter> from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the <code>OcuP2417gNoPurge</code> legs go red; drop
/// <method>OcuPilot.Port.InteropPort.LogSelectGate</method> from <method>OcuPilot.Port.InteropPort.ListLog</method> -- the <code>OcuP2417gNoSelect</code> list legs go red; call it at the head of <method>OcuPilot.Port.InteropPort.ReadLogState</method> -- the <code>OcuP2417gNoSelect</code> state and purge legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = ..CreateGated()
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tOk = ..Expect()
    Set tPurge = ..Expect("%Ens_Purge:USE")
    Set tDb = ..Expect("%DB_USER:WRITE")
    Set tRule = ..Expect("%Ens_RuleLog:USE")
    Set tJobs = ..Expect("%Ens_Jobs:READ")
    Set tSelectRule = ..Expect("Ens_Rule.Log:SELECT")
    Set tSelectProcess = ..Expect("Ens.BusinessProcess:SELECT")
    Set tExpected("OcuP2417gAll") = $ListBuild(tOk, tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2417gNoPurge") = $ListBuild(tOk, tOk, tOk, tOk, tPurge, tPurge)
    Set tExpected("OcuP2417gDbRead") = $ListBuild(tOk, tOk, tOk, tOk, tDb, tDb)
    Set tExpected("OcuP2417gNoRule") = $ListBuild(tRule, tOk, tRule, tOk, tRule, tOk)
    Set tExpected("OcuP2417gNoJobs") = $ListBuild(tOk, tJobs, tOk, tJobs, tOk, tJobs)
    Set tExpected("OcuP2417gNoSelect") = $ListBuild(tSelectRule, tSelectProcess, tOk, tOk, tOk, tOk)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Set tRuleProbe = ..Probe("rule", ..#SOURCE, 7300, 1)
        Set tProcessProbe = ..Probe("process", ..#SOURCE, 7300, 1)
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", tUser, "legs")
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tRuleDone = 0
        Set tProcessDone = 0
        For tI = 1:1:$Length($Parameter(..#CHILD, "LEGS"), ",") {
            Set tLegName = $Piece($Piece($Parameter(..#CHILD, "LEGS"), ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If $IsObject(tLeg) && (tGot = tOk) && (tLegName '= "list") && (tLegName '= "plist") Do $$$AssertTrue(tLeg.%Get("count") '= "", tUser _ ": the " _ tLegName _ " answer carries the log's count, which is the purge's fresh read")
            If (tLegName = "rpurge") && (tGot = tOk) Set tRuleDone = 1
            If (tLegName = "ppurge") && (tGot = tOk) Set tProcessDone = 1
        }
        Do $$$AssertEquals(..Exists("rule", ..#SOURCE, tRuleProbe), 'tRuleDone, tUser _ ": an admitted rule log purge deleted the old entry and a refused one changed nothing")
        Do $$$AssertEquals(..Exists("process", ..#SOURCE, tProcessProbe), 'tProcessDone, tUser _ ": and so for the business process")
    }
    Do $ClassMethod(..#FIXTURE, "DropProbes")
}

/// <p>AC3: the SQL SELECT check is the classic page's own: for each principal and each log, in <code>USER</code> and in <code>HSCUSTOM</code>, the list is admitted exactly when the classic page's own
/// query prepares there as that principal through <class>%Library.ResultSet</class>, and refused exactly when that answers <code>#5580</code> -- a principal with a direct grant, one with the grant
/// through the Ensemble operator role, one with the grant on the rule log's table alone, one with none, one holding only READ on the databases, and <code>_SYSTEM</code> (<code>%All</code>). The grants
/// are made in <code>USER</code>, so <code>HSCUSTOM</code> admits only <code>%All</code>. The grant is read the vendor's way, in the namespace the list names, so roles and <code>%All</code> resolve as
/// the classic page resolves them.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LogSelectGate</method> check the other log's table -- the rule-table-only principal's legs go red; make it ask in <code>USER</code>
/// whatever the namespace -- the <code>HSCUSTOM</code> legs go red.</p>
Method TestTheSqlSelectCheckIsTheClassicPagesOwn()
{
    Set tSC = ..CreateGated()
    Do $$$AssertStatusOK(tSC, "the gated principals are created")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#EQUALITYPRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the equality principals are created")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "AddRole", "OcuP2417gOp", "%EnsRole_Operator"), "one holds the Ensemble operator role, which carries the grant")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Sql", ..#SOURCE, "GRANT SELECT ON Ens_Rule.Log TO OcuP2417gOneRole"), "one is granted the rule log's table alone")
    ; USER's two verdicts, then HSCUSTOM's: the grants are made in USER alone, so only %All is admitted in HSCUSTOM.
    Set tExpected("OcuP2417gNoSelect") = "00|00"
    Set tExpected("OcuP2417gAll") = "11|00"
    Set tExpected("OcuP2417gOp") = "11|00"
    Set tExpected("OcuP2417gOne") = "10|00"
    Set tExpected("OcuP2417gDb") = "00|00"
    Set tExpected("_SYSTEM") = "11|11"
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", tUser, "equality")
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tHeld = ""
        For tNamespace = "USER", "HSCUSTOM" {
            Set tHeld = tHeld _ $Select(tNamespace = "USER": "", 1: "|")
            For tKind = "rule", "process" {
                Set tLabel = tUser _ ", " _ tNamespace _ ", " _ tKind
                Set tEntry = tOut.%Get(tNamespace _ "|" _ tKind)
                Set tListed = $Select($IsObject(tEntry): (tEntry.http = 200), 1: -1)
                Do $$$AssertTrue($IsObject(tEntry) && (tEntry.prepared = tListed), tLabel _ ": the list is admitted exactly when the classic page's query prepares: " _ $Select($IsObject(tEntry): tEntry.%ToJSON(), 1: tEntry))
                Do $$$AssertTrue($IsObject(tEntry) && (tEntry.refused5580 = 'tEntry.prepared), tLabel _ ": and it is refused exactly when the classic page's answers #5580")
                If $IsObject(tEntry) && 'tListed Do $$$AssertEquals(tEntry.failedPair, $Select(tUser = "OcuP2417gDb": "%Ens_Portal:USE", tKind = "rule": "Ens_Rule.Log:SELECT", 1: "Ens.BusinessProcess:SELECT"), tLabel _ ": a refusal names the table and SELECT, or the portal's pair the database-only principal lacks")
                Set tHeld = tHeld _ $Select(tListed = 1: 1, 1: 0)
            }
        }
        Do $$$AssertEquals(tHeld, tExpected(tUser), tUser _ ": the verdicts, rule log then business process, in USER then HSCUSTOM: 1 admitted, 0 refused")
    }
    Do ..RevokeAll()
}

}
