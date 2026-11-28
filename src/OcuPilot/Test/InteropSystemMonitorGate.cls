/// <p>Pins Story 24.17 Batch 5's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): each of the four endpoints is refused before any vendor call, naming the pair that fails, for a
/// principal without <code>%Ens_Portal:USE</code>, without <code>%Ens_Dashboard:USE</code> and without <code>%DB_IRISSYS:READ</code>, and admitted for one that holds all three -- with none of the
/// roles <code>%All</code> brings. The vendor's own call, made as that principal with and without a production running, leaves its roles, user and namespace as found and answers 200.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropSystemMonitorCase</class> needs; it creates and removes four principals.</p>
Class OcuPilot.Test.InteropSystemMonitorGate Extends OcuPilot.Test.InteropSystemMonitorCase
{

Parameter CHILD = "OcuPilot.Test.InteropSystemMonitorChild";

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The principals: all three pairs, and each without one. Each holds READ on <code>HSCUSTOM</code>, which running OcuPilot's code needs.</p>
Parameter PRINCIPALS = "OcuP2417sAll:%Ens_Portal:U,%Ens_Dashboard:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R;OcuP2417sNoPortal:%Ens_Dashboard:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R;OcuP2417sNoDash:%Ens_Portal:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R;OcuP2417sNoSys:%Ens_Portal:U,%Ens_Dashboard:U,%DB_HSCUSTOM:R";

/// <p>The pair each principal lacks, <code>user=pair</code>; the first lacks none.</p>
Parameter LACKS = "OcuP2417sAll=,OcuP2417sNoPortal=%Ens_Portal:USE,OcuP2417sNoDash=%Ens_Dashboard:USE,OcuP2417sNoSys=%DB_IRISSYS:READ";

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
    Set ..PreparedPassword = "OcuP2417s" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

/// <p>AC3: each endpoint is refused before any vendor call, naming the pair that fails, and admitted for the principal that holds the three. The seam counts the vendor calls: the admitted
/// principal's four reads make four, and a refused principal's make none.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Dashboard:USE</code> from <parameter>SYSTEMMONITORPAIRS</parameter> -- the principal without it is admitted and this goes red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the four principals are created")
    If $$$ISERR(tSC) Quit
    For tI = 1:1:$Length(..#LACKS, ",") {
        Set tEntry = $Piece(..#LACKS, ",", tI)
        Set tUser = $Piece(tEntry, "=", 1)
        Set tPair = $Piece(tEntry, "=", 2)
        Kill ^IRIS.Temp.OcuProbe2417SmMode
        Set ^IRIS.Temp.OcuProbe2417SmMode = "values"
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", tUser, "legs", ..#SEAM)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        For tJ = 1:1:4 {
            Set tEndpoint = $Piece(..#ENDPOINTS, ",", tJ)
            Set tLeg = tOut.%Get(tEndpoint)
            Set tGot = $Select($IsObject(tLeg): tLeg.%Get("http") _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Set tWant = $Select(tPair = "": "200||", 1: "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ tPair)
            Do $$$AssertEquals(tGot, tWant, tUser _ ": " _ tEndpoint _ " is answered as declared")
        }
        Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417SmMode("calls")), $Select(tPair = "": 4, 1: 0), tUser _ ": " _ $Select(tPair = "": "the four reads made four vendor calls", 1: "no vendor call was made"))
    }
    Do $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS)
}

/// <p>AC4: the real call as a principal that holds none of the roles <code>%All</code> brings, idle and with the probe production running in a job with no web request: 200, the roles, user and
/// namespace as before, and the production counted while it runs.</p>
Method TestTheRealCallAsAPrincipalWithoutAllLeavesItsRolesAsFound()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the four principals are created")
    If $$$ISERR(tSC) Quit
    For tLeg = "idle", "running" {
        If tLeg = "running" Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
        If tLeg = "idle" Do ..AgeSnapshot()
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "OcuP2417sAll", "roles", ..#PORT)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tLeg _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tLeg _ ": the principal logged in")
        Do $$$AssertTrue((tOut.before '[ "%All") && (tOut.before '= ""), tLeg _ ": the principal holds roles but not %All: " _ tOut.before)
        Do $$$AssertEquals(tOut.http _ "|" _ tOut.running, "200|" _ $Select(tLeg = "running": 1, 1: 0), tLeg _ ": the read answers 200 and counts the production only while it runs")
        Do $$$AssertEquals(tOut.after, tOut.before, tLeg _ ": the roles are as before")
        Do $$$AssertEquals(tOut.sameUser _ "|" _ tOut.sameNamespace, "1|1", tLeg _ ": the user and namespace are as before")
    }
    Do $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS)
}

}
