/// <p>Pins <class>OcuPilot.Port.DocDbPort</class>'s gate against real principals (AD-8, AD-29, Story
/// 19.17): a principal missing one pair the port requires -- <code>%Development:USE</code>,
/// <code>%DocDB_Admin:USE</code>, <code>%Service_DocDB:USE</code>, READ on <code>USER</code>'s database,
/// or, for a create and a drop, WRITE on it -- is refused 403 naming that pair on every call, before the
/// service check, so with the service disabled no vendor audit row is written; a principal holding
/// <code>%Admin_Secure:USE</code> in place of <code>%DocDB_Admin:USE</code>, whom the vendor's own gate
/// admits, is refused naming <code>%DocDB_Admin:USE</code>; and a principal holding exactly the pairs
/// lists, creates, reads and drops a probe database in <code>USER</code>.</p>
/// <p>The calls run in a child process (<method>OcuPilot.Test.DocDbProbe.Probe</method>) that logs in as
/// the principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PRINCIPALSVARIABLE</parameter> reading
/// <code>1</code>, because it enables <code>%Service_DocDB</code>, creates and drops a probe database
/// named <code>OcuProbe1917*</code>, and creates seven users and roles named <code>OcuP1917*</code>. Each
/// principal also holds READ on the install namespace's code database, as every caller must. The
/// service is put back after every test, and the principals and probes are removed after the last.</p>
Class OcuPilot.Test.DocDbGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's service writes.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DocDbProbe";

Parameter NAMESPACE = "USER";

/// <p>The probe database every principal's calls name.</p>
Parameter PROBENAME = "OcuProbe1917G";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's
/// READ&gt;</code>, separated by <code>;</code>: exactly the port's pairs, then each missing one, then
/// <code>%Admin_Secure:USE</code> in place of <code>%DocDB_Admin:USE</code>.</p>
Parameter PRINCIPALS = "OcuP1917Exact:%Development:U,%DocDB_Admin:U,%Service_DocDB:U,%DB_USER:RW;OcuP1917NoDev:%DocDB_Admin:U,%Service_DocDB:U,%DB_USER:RW;OcuP1917NoAdmin:%Development:U,%Service_DocDB:U,%DB_USER:RW;OcuP1917NoSvc:%Development:U,%DocDB_Admin:U,%DB_USER:RW;OcuP1917NoRead:%Development:U,%DocDB_Admin:U,%Service_DocDB:U;OcuP1917NoWrite:%Development:U,%DocDB_Admin:U,%Service_DocDB:U,%DB_USER:R;OcuP1917Secure:%Admin_Secure:U,%Development:U,%Service_DocDB:U,%DB_USER:RW";

/// <p>Whether <code>%Service_DocDB</code> was enabled before the test, put back after it.</p>
Property PreparedService As %String;

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = ""
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbGate enables %Service_DocDB and creates and drops document databases on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP1917Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probes, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbGate left the principal or role of " _ tUser))
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
    Set tSC = $ClassMethod(..#PROBE, "ServiceEnabled", .tPrior)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = tPrior
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", ..PreparedService), "%Service_DocDB is put back as it was found")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe database and class is removed")
    Quit $$$OK
}

/// <p>AC3: with the service disabled, each principal missing one of the port's pairs is refused every
/// call 403 naming that pair, and the principal holding READ and not WRITE is refused the create and
/// the drop naming the write pair; of its twenty-four calls only that principal's two reads reach the
/// service check, so exactly two vendor access-denied rows are written.</p>
/// <p>Mutation (Rule 19): drop <code>%DocDB_Admin:USE</code> from
/// <parameter>OcuPilot.Port.DocDbPort.PAIRS</parameter> -- the missing-admin principal reaches the
/// service check and this goes red. Moving the service check ahead of the pairs writes a row per call
/// and the audit leg goes red.</p>
Method TestEachMissingPairIsRefusedByNameBeforeTheService()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "%Service_DocDB is disabled for this test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tBefore), "the access-denied rows are counted")
    For tCase = $ListBuild("OcuP1917NoDev", "%Development:USE"), $ListBuild("OcuP1917NoAdmin", "%DocDB_Admin:USE"), $ListBuild("OcuP1917NoSvc", "%Service_DocDB:USE"), $ListBuild("OcuP1917NoRead", "%DB_USER:READ"), $ListBuild("OcuP1917Secure", "%DocDB_Admin:USE") {
        Set tUser = $List(tCase, 1)
        Set tWanted = "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        For tType = "LIST", "CREATE", "DATABASE", "DROP" {
            Do $$$AssertEquals(..LegText(tProbe, tType), tWanted, tUser _ ": " _ tType _ " is refused naming the pair")
        }
    }
    Set tProbe = ..ProbeAs("OcuP1917NoWrite")
    Do $$$AssertEquals(..LegText(tProbe, "CREATE") _ "|" _ ..LegText(tProbe, "DROP"), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE|403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "OcuP1917NoWrite: the create and the drop are refused naming the write pair before the service")
    Do $$$AssertEquals(..LegText(tProbe, "LIST") _ "|" _ ..LegText(tProbe, "DATABASE"), "409 DOCDB.SERVICE.DISABLED |409 DOCDB.SERVICE.DISABLED ", "OcuP1917NoWrite: its reads reach the disabled service")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tAfter), "the rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 2, "only the two reads reached the vendor's service check, each writing one audit row; no pair refusal wrote one")
}

/// <p>AC3: with the service enabled, a principal holding READ on <code>USER</code>'s database and not
/// WRITE lists and reads, and is refused the create and the drop naming <code>%DB_USER:WRITE</code>; a
/// principal holding exactly the port's pairs lists, creates, reads and drops.</p>
Method TestTheExactPairsListCreateAndDrop()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "%Service_DocDB is enabled")
    Set tProbe = ..ProbeAs("OcuP1917NoWrite")
    Do $$$AssertEquals(..LegText(tProbe, "LIST") _ "|" _ ..LegText(tProbe, "DATABASE"), "200  |404 PORT.NOTFOUND ", "the read-only principal lists, and reads the absent probe as not found")
    Do $$$AssertEquals(..LegText(tProbe, "CREATE") _ "|" _ ..LegText(tProbe, "DROP"), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE|403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "and is refused the create and the drop naming the write pair")
    Set tProbe = ..ProbeAs("OcuP1917Exact")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|OcuP1917Exact", "the probe ran as the exact principal: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(..LegText(tProbe, "LIST") _ "|" _ ..LegText(tProbe, "CREATE") _ "|" _ ..LegText(tProbe, "DATABASE") _ "|" _ ..LegText(tProbe, "DROP"), "200  |201  |200  |200  ", "the exact principal lists, creates, reads and drops")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, ..#PROBENAME), "and the probe is gone")
}

/// <p>Run <method>OcuPilot.Test.DocDbProbe.Probe</method> as <var>pUser</var> in a child process and
/// answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.DocDbProbe).Probe($Job, pUser, ..#NAMESPACE, ..#PROBENAME)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
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
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get(pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get(pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ
/// on the install namespace's code database, then read the decisive grants back.</p>
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
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the DocDB port's gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot DocDB gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DocDbGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP1917Exact", "%DocDB_Admin", "USE", 1), $ListBuild("OcuP1917NoAdmin", "%DocDB_Admin", "USE", 0), $ListBuild("OcuP1917NoSvc", "%Service_DocDB", "USE", 0), $ListBuild("OcuP1917NoDev", "%Development", "USE", 0), $ListBuild("OcuP1917NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP1917NoWrite", "%DB_USER", "WRITE", 0), $ListBuild("OcuP1917Secure", "%DocDB_Admin", "USE", 0), $ListBuild("OcuP1917Secure", "%Admin_Secure", "USE", 1) {
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
