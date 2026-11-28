/// <p>Pins the 403 of a checked catalog read against a real principal (AD-8, AD-29, AD-39): a principal holding <code>%Development:USE</code> and the
/// namespace's database pairs, but no SQL SELECT privilege on the tables <class>OcuPilot.Port.SqlPort</class> reads, is refused each of the four fixed
/// reads (runtime statistics count, index analysis count, the advice's class read and index read) <code>403 SQL.SELECT.PRIVILEGE</code> with the ruled
/// sentence naming the read's own tables, through the port, through the agent's <code>explorer.sqladvice.read</code> (whose model-facing content carries the
/// same sentence) and over HTTP; and once the privilege is granted the same four reads answer.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes a user and
/// a role named <code>OcuP2127*</code>, grants and revokes SQL privileges in <code>USER</code> and creates and drops
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s advice table there. It runs on a throwaway container only. The principal, its grants and the table are
/// removed after the last test.</p>
Class OcuPilot.Test.SqlSelectPrivilege Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter NAMESPACE = "USER";

Parameter USER = "OcuP2127Reader";

/// <p>The principal: <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, the gate's pairs for <code>USER</code> and
/// nothing else.</p>
Parameter PRINCIPAL = "OcuP2127Reader:%Development:U,%DB_USER:RW,%DB_ENSLIB:R,%DB_IRISLIB:R";

/// <p>The tables the four reads select from, each granted to the principal for the second test and revoked after each test.</p>
Parameter READTABLES = "%SYS_PTools.StatsSQL,%SYS_PTools.UtilSQLStatements,%SYS_PTools.UtilSQLAnalysisDB,%Dictionary.CompiledClass,%Dictionary.CompiledIndex";

Parameter ADVISE = "SELECT B FROM OcuProbe227Advice.T WHERE B = 'x'";

/// <p>The principal's password for this run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSelectPrivilege creates and deletes a user and a role and grants SQL privileges in " _ ..#NAMESPACE _ ", and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedPassword = "OcuP2127Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "MakeAdvice", ..#NAMESPACE)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPAL, ..PreparedPassword, "OcuPilot.Test.SqlSelectPrivilege")
    If $$$ISOK(tSC) Set tSC = ..InNamespace("GRANT SELECT ON " _ $Parameter(..#PROBE, "ADVICETABLE") _ " TO " _ ..#USER)
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principal, its role, its grants and the probe table; a failing status when any survives, each grant read back before the principal goes.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..Revoke()
    For tI = 1:1:$Length(..#READTABLES, ",") {
        Set tTable = $Piece(..#READTABLES, ",", tI)
        If $SYSTEM.SQL.Security.CheckPrivilege(..#USER, 1, tTable, "s", ..#NAMESPACE) = 1 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSelectPrivilege left " _ ..#USER _ " holding SELECT on " _ tTable))
    }
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAdvice", ..#NAMESPACE))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#USER) Do ##class(Security.Users).Delete(..#USER)
        If ##class(Security.Roles).Exists(..#USER _ "Role") Do ##class(Security.Roles).Delete(..#USER _ "Role")
        If ##class(Security.Users).Exists(..#USER) || ##class(Security.Roles).Exists(..#USER _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSelectPrivilege left the principal " _ ..#USER _ " or its role behind"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "AdviceState", ..#NAMESPACE) '= "0|") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSelectPrivilege left the advice table in " _ ..#NAMESPACE)
    Quit tSC
}

/// <p>Each test starts and ends with the principal holding none of <parameter>READTABLES</parameter>.</p>
Method OnBeforeOneTest() As %Status
{
    Quit ..Revoke()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..Revoke()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals($Get(tRemaining), 0, "no seeded turn is left behind")
    Quit tSC
}

/// <p>Run the statement <var>pText</var> in <parameter>NAMESPACE</parameter>.</p>
ClassMethod InNamespace(pText As %String) As %Status
{
    Quit $ClassMethod(..#PROBE, "RunIn", ..#NAMESPACE, pText)
}

/// <p>Grant the principal SELECT on each of <parameter>READTABLES</parameter>.</p>
ClassMethod Grant() As %Status
{
    Set tSC = $$$OK
    For tI = 1:1:$Length(..#READTABLES, ",") {
        Set tSC = ..InNamespace("GRANT SELECT ON " _ $Piece(..#READTABLES, ",", tI) _ " TO " _ ..#USER)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>The two procedures Alternate plans' reads call (Story 21.28), on each of which the principal is granted EXECUTE by the test that needs it.</p>
Parameter PROCEDURES = "%SYS_PTools.PT_possiblePlans,%SYS_PTools.PT_possiblePlansStats";

/// <p>Revoke the principal's SELECT on each of <parameter>READTABLES</parameter> and its EXECUTE on each of <parameter>PROCEDURES</parameter>; a revoke of a
/// privilege it does not hold is not an error.</p>
ClassMethod Revoke() As %Status
{
    For tI = 1:1:$Length(..#READTABLES, ",") {
        Do ..InNamespace("REVOKE SELECT ON " _ $Piece(..#READTABLES, ",", tI) _ " FROM " _ ..#USER)
    }
    For tI = 1:1:$Length(..#PROCEDURES, ",") {
        Do ..InNamespace("REVOKE EXECUTE ON " _ $Piece(..#PROCEDURES, ",", tI) _ " FROM " _ ..#USER)
    }
    Quit $$$OK
}

/// <p>A request over the wire as the principal, scoped to <parameter>NAMESPACE</parameter>: the HTTP status, the parsed body in <var>pBody</var>.</p>
Method Call(pMethod As %String, pPath As %String, pRequestBody As %String, Output pBody As %DynamicObject) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tUrl, ..#USER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders, pRequestBody, "application/json")
    Set pBody = {}
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as the principal in a child process, over a completed turn seeded for the principal, and answer what it signalled, or an
/// object carrying <code>error</code>. <method>OnAfterOneTest</method> removes the seeded turn.</p>
ClassMethod ProbeAs() As %DynamicObject
{
    Set tOut = {}
    Try {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#USER, "completed", .tTurnKey)
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", "the turn could not be seeded")
            Quit
        }
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.SqlSelectPrivilege).Probe($Job, ..#USER, ..#NAMESPACE, tTurnKey)::10
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

/// <p>A leg's outcome as <code>&lt;http&gt;|&lt;code&gt;|&lt;detail.reason&gt;</code> for a fault, or <code>&lt;http&gt;</code> alone.</p>
ClassMethod Leg(pHttp As %Integer, pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit +pHttp
    Quit +pHttp _ "|" _ pFault.%Get("code") _ "|" _ $Select(pFault.%GetTypeOf("detail") = "object": pFault.detail.%Get("reason"), 1: "")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, then read through the port the runtime statistics count
/// (<code>stats</code>), the index analysis count (<code>analysis</code>) and the plan with advice of <parameter>ADVISE</parameter>
/// (<code>advice</code>), through the agent's <code>explorer.sqladvice.read</code> (<code>tool</code>, with <code>content</code> the error content the
/// dispatcher gives the model), and the agent's proposal of a report run, whose fresh read is the index analysis count (<code>mint</code>, minted over the
/// seeded turn <var>pTurnKey</var>, with <code>mintContent</code>). It signals <code>{loggedIn, username, stats, analysis, advice, tool, content, mint,
/// mintContent}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pTurnKey As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Kill tQuery
        Set tQuery("namespace") = pNamespace
        Set tQuery("id") = "*"
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Invoke", "RuntimeStats", "STATS", .tQuery, "", .tResult, .tHttp, .tFault)
        Do tOut.%Set("stats", ..Leg(tHttp, tFault))
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Invoke", "IndexAnalysis", "ANALYSIS", .tQuery, "", .tResult, .tHttp, .tFault)
        Do tOut.%Set("analysis", ..Leg(tHttp, tFault))
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Plan", pNamespace, ..#ADVISE, .tAnswer, .tHttp, .tFault, 0, 1)
        Do tOut.%Set("advice", ..Leg($Select($IsObject(tFault): tHttp, 1: 200), tFault) _$Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("advice")): "|findings=" _ (tAnswer.advice.findings.%Size() > 0), 1: ""))
        Set tAnswer = ""
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Plan", pNamespace, ..#ADVISE, .tAnswer, .tHttp, .tFault, 0, 0, 1)
        Do tOut.%Set("alternates", ..Leg($Select($IsObject(tFault): tHttp, 1: 200), tFault) _ $Select($IsObject($Get(tAnswer)) && (tAnswer.%Get("outcome") = "plans"): "|plans=" _ (tAnswer.plans.%Size() > 0), 1: ""))
        Set tAnswer = ""
        Set tFault = ""
        Set tSC = $ClassMethod(..#PORT, "Plan", pNamespace, ..#ADVISE, .tAnswer, .tHttp, .tFault, 0, 0, 1, "", [1])
        Do tOut.%Set("compare", ..Leg($Select($IsObject(tFault): tHttp, 1: 200), tFault))
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.sqladvice.read", .tTool)
        If $$$ISERR(tSC) || '$IsObject($Get(tTool)) {
            Do tOut.%Set("error", "explorer.sqladvice.read does not resolve")
            Quit
        }
        Set tFault = ""
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"statement": (..#ADVISE)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"), .tToolResult, .tHttp, .tFault)
        Do tOut.%Set("tool", ..Leg(tHttp, tFault))
        If $IsObject(tFault) Do tOut.%Set("content", ##class(OcuPilot.Kernel.Agent.Dispatch).ErrorContent(tFault.%Get("code"), $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail"), 1: "")))
        Set tClass = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun"
        Set tArgs = {"Target": "*", "Report": "TS", "SkipSystem": "true", "SkipInserts": "true", "SkipIdKeys": "true"}
        Set tFault = ""
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tClass, "DESCRIPTORCLASS"), $Parameter(tClass, "TOOLNAME"), pUsername, "", pTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tMinted, .tHttp, .tFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), "*", $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), tClass)
        Do tOut.%Set("mint", ..Leg(tHttp, tFault))
        If $IsObject(tFault) Do tOut.%Set("mintContent", ##class(OcuPilot.Kernel.Agent.Dispatch).ErrorContent(tFault.%Get("code"), $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail"), 1: "")))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>The ruled sentence naming <var>pTables</var>, typed here apart from the error class so the two are compared rather than read twice.</p>
ClassMethod Sentence(pTables As %String) As %String
{
    Quit "Reading this needs the SQL SELECT privilege on " _ pTables _ "."
}

/// <p>A principal without the SQL SELECT privilege on the tables the four reads name is refused each of them 403 <code>SQL.SELECT.PRIVILEGE</code> with
/// the ruled sentence naming the read's own tables, through the port and through the agent's advice read, whose model-facing content carries the same
/// sentence in <code>detail.reason</code>; the advice read's class read refuses first, so it names the class table.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.CheckedRow</method> and <method>CheckedRows</method> leave a refused prepare to the internal fault
/// -> every leg goes red answering 500.</p>
Method TestAPrincipalWithoutSelectIsRefusedEachCheckedReadNamingItsTables()
{
    Set tProbe = ..ProbeAs()
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#USER, "the probe ran as the principal: " _ tProbe.%ToJSON())
    Set tCode = ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE
    Do $$$AssertEquals(tProbe.%Get("stats"), "403|" _ tCode _ "|" _ ..Sentence("%SYS_PTools.StatsSQL"), "the runtime statistics count is refused naming its table")
    Do $$$AssertEquals(tProbe.%Get("analysis"), "403|" _ tCode _ "|" _ ..Sentence("%SYS_PTools.UtilSQLStatements and %SYS_PTools.UtilSQLAnalysisDB"), "the index analysis count is refused naming both its tables")
    Set tAdvice = "403|" _ tCode _ "|" _ ..Sentence("%Dictionary.CompiledClass")
    Do $$$AssertEquals(tProbe.%Get("advice"), tAdvice, "the plan with advice is refused naming the class table")
    Do $$$AssertEquals(tProbe.%Get("tool"), tAdvice, "so is the agent's advice read")
    Do $$$AssertEquals(tProbe.%Get("alternates") _ "~" _ tProbe.%Get("compare"), tAdvice _ "~" _ tAdvice, "and the list and the compare of Alternate plans, which read a view's text from the class table first")
    Set tContent = ""
    Try { Set tContent = ##class(%DynamicObject).%FromJSON(tProbe.%Get("content")) } Catch {}
    Do $$$AssertTrue($IsObject(tContent) && (tContent.%Get("code") = tCode) && $IsObject(tContent.%Get("detail")) && (tContent.detail.%Get("reason") = ..Sentence("%Dictionary.CompiledClass")), "the model's tool result carries the code and the same sentence: " _ tProbe.%Get("content"))
    Set tBoth = ..Sentence("%SYS_PTools.UtilSQLStatements and %SYS_PTools.UtilSQLAnalysisDB")
    Do $$$AssertEquals(tProbe.%Get("mint"), "403|" _ tCode _ "|" _ tBoth, "the agent's proposal of a report run is refused naming the analysis tables")
    Set tContent = ""
    Try { Set tContent = ##class(%DynamicObject).%FromJSON(tProbe.%Get("mintContent")) } Catch {}
    Do $$$AssertTrue($IsObject(tContent) && (tContent.%Get("code") = tCode) && $IsObject(tContent.%Get("detail")) && (tContent.detail.%Get("reason") = tBoth), "and the model's result for it carries the same sentence: " _ tProbe.%Get("mintContent"))
}

/// <p>With SELECT granted on the five tables, the same four reads answer: both counts 200, and the plan with advice 200 with findings for the unindexed
/// condition, through the port and through the agent's read.</p>
/// <p>Mutation (Rule 19): drop <code>%Dictionary.CompiledIndex</code> from <parameter>READTABLES</parameter> -> the advice legs go red answering 403 naming the
/// index table.</p>
Method TestTheSameReadsAnswerOnceTheSelectPrivilegeIsGranted()
{
    Do $$$AssertStatusOK(..Grant(), "SELECT is granted on the five tables")
    Set tProbe = ..ProbeAs()
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#USER, "the probe ran as the principal: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("stats"), 200, "the runtime statistics count answers")
    Do $$$AssertEquals(tProbe.%Get("analysis"), 200, "the index analysis count answers")
    Do $$$AssertEquals(tProbe.%Get("advice"), "200|findings=1", "the plan with advice answers with findings: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("tool"), 200, "the agent's advice read answers")
    Do $$$AssertTrue(tProbe.%Get("mint") '[ ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE, "and the agent's proposal of a report run is no longer refused for want of the privilege: " _ tProbe.%Get("mint"))
}

/// <p>Alternate plans (Story 21.28): a principal holding SELECT but not EXECUTE on the procedure behind the possible plans is refused the list and the
/// compare 403 <code>SQL.EXECUTE.PRIVILEGE</code> naming that procedure; granted EXECUTE on it alone, it is answered the list and refused the compare naming the
/// statistics procedure, which nothing ran for.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.PlansRead</code> answers the error outcome for SQLCODE -99 -> the refusal legs go red.</p>
Method TestAPrincipalWithoutExecuteIsRefusedAlternatePlansNamingTheProcedure()
{
    Set tCode = ##class(OcuPilot.Api.AtelierError).#SQLEXECUTEPRIVILEGE
    Set tList = "403|" _ tCode _ "|Reading this needs the SQL EXECUTE privilege on %SYS_PTools.PT_possiblePlans."
    Set tStats = "403|" _ tCode _ "|Reading this needs the SQL EXECUTE privilege on %SYS_PTools.PT_possiblePlansStats."
    Do $$$AssertStatusOK(..Grant(), "SELECT is granted on the five tables")
    Set tProbe = ..ProbeAs()
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#USER, "the probe ran as the principal: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("alternates") _ "~" _ tProbe.%Get("compare"), tList _ "~" _ tList, "with no EXECUTE the list and the compare are refused naming the list's procedure")
    Do $$$AssertStatusOK(..InNamespace("GRANT EXECUTE ON %SYS_PTools.PT_possiblePlans TO " _ ..#USER), "EXECUTE is granted on the list's procedure")
    Set tProbe = ..ProbeAs()
    Do $$$AssertEquals(tProbe.%Get("alternates") _ "~" _ tProbe.%Get("compare"), "200|plans=1~" _ tStats, "the list answers and the compare is refused naming the statistics procedure: " _ tProbe.%ToJSON())
}

/// <p>A principal granted SELECT on the dictionary's class table but not its index table is refused the advice's second read, and the sentence names the
/// index table, through the port and through the agent's advice read.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.Indexed</method> passes <parameter>ADVICECLASSTABLES</parameter> to its index read -> both legs go red
/// naming the class table.</p>
Method TestTheIndexReadIsRefusedNamingTheIndexTable()
{
    Do $$$AssertStatusOK(..InNamespace("GRANT SELECT ON %Dictionary.CompiledClass TO " _ ..#USER), "SELECT is granted on the class table only")
    Set tProbe = ..ProbeAs()
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#USER, "the probe ran as the principal: " _ tProbe.%ToJSON())
    Set tAdvice = "403|" _ ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE _ "|" _ ..Sentence("%Dictionary.CompiledIndex")
    Do $$$AssertEquals(tProbe.%Get("advice"), tAdvice, "the plan with advice is refused naming the index table")
    Do $$$AssertEquals(tProbe.%Get("tool"), tAdvice, "so is the agent's advice read")
}

/// <p>Over HTTP the principal's plan with advice is 403 with the ruled sentence as the envelope's reason, and a report run, whose state read is the
/// analysis count, is 403 with the sentence naming that read's two tables, so the person sees what to ask for.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.SelectRefusal</method> composes the refusal with the generic internal fault -> both legs go red
/// answering 500.</p>
Method TestTheRoutesAnswerTheSentence()
{
    Set tStatus = ..Call("POST", "/explorer/sql/plan", {"statement": (..#ADVISE), "advise": true}.%ToJSON(), .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ tBody.%Get("code") _ "|" _ tBody.%Get("reason"), "403|" _ ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE _ "|" _ ..Sentence("%Dictionary.CompiledClass"), "the plan route's envelope carries the sentence: " _ tBody.%ToJSON())
    Set tStatus = ..Call("POST", "/screens/explorer.sqlindexanalysis/action", {"action": "run", "id": "*", "values": {"Report": "TS", "SkipSystem": "true", "SkipInserts": "true", "SkipIdKeys": "true"}}.%ToJSON(), .tBody)
    Do $$$AssertEquals(tStatus _ "|" _ tBody.%Get("code") _ "|" _ tBody.%Get("reason"), "403|" _ ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE _ "|" _ ..Sentence("%SYS_PTools.UtilSQLStatements and %SYS_PTools.UtilSQLAnalysisDB"), "the report run's envelope carries the sentence naming both tables: " _ tBody.%ToJSON())
}

}
