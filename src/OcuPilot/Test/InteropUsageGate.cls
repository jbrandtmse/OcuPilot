/// <p>Pins the three Interoperability usage tabs' gate against real principals (AD-8, AD-29, AD-64, Story 18.37), each
/// reading <code>GET /screens/&lt;tool&gt;/read?maxRows=100</code> of the three screens over the wire: a principal
/// holding exactly the monitor port's two pairs reads all three; a principal missing either pair is refused 403 naming
/// it on all three; with the three screens adjusted below the port's pairs, the port still refuses the principal the
/// screen now admits; and a request with no credentials is refused 401 on all three.</p>
/// <p><b>What it needs from the environment:</b> <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>,
/// because it creates three users and roles named <code>OcuProbe1837*</code>, each also holding READ on the install
/// namespace's code database, as every caller must, and stores an adjusted permission set for each of the three
/// screens. The principals and the adjusted sets are removed after the test that made them, and a set of
/// <parameter>ADJUSTMENTS</parameter> an interrupted earlier run left is removed before the first test.</p>
Class OcuPilot.Test.InteropUsageGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.InteropUsageProbe";

/// <p>The store that holds a screen's adjusted permission set (AD-64).</p>
Parameter ACCESSSTORE = "OcuPilot.Kernel.State.Access";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's READ&gt;</code>,
/// separated by <code>;</code>: the holder of exactly the two pairs; one with <code>%Admin_Manage</code> in place of
/// <code>%Admin_Operate</code>; and one without the system database's read.</p>
Parameter PRINCIPALS = "OcuProbe1837Exact:%Admin_Operate:U,%DB_IRISSYS:R;OcuProbe1837NoOperate:%Admin_Manage:U,%DB_IRISSYS:R;OcuProbe1837NoSys:%Admin_Operate:U";

/// <p>The three screens' tool identifiers, each read as <code>/screens/&lt;tool&gt;/read?maxRows=100</code>.</p>
Parameter TOOLS = "osmgmt.interopusage,osmgmt.interopvolume,osmgmt.interopimpact";

/// <p>The two sets <method>TestThePortRefusesWhatALoweredScreenAdmits</method> adjusts the three screens to,
/// separated by <code>;</code>.</p>
Parameter ADJUSTMENTS = "%Admin_Operate:USE;%Admin_Manage:USE";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The set the three screens are adjusted to now, <code>""</code> when this class has stored none.</p>
Property StoredAdjustment As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..StoredAdjustment = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropUsageGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1837Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    If $ClassMethod(..#PROBE, "Remaining") '= (2 * $Length(..#PRINCIPALS, ";")) Quit $$$ERROR($$$GeneralError, "the probe principals and their roles were not all created")
    For tI = 1:1:$Length(..#ADJUSTMENTS, ";") {
        Set ..StoredAdjustment = $Piece(..#ADJUSTMENTS, ";", tI)
        Set tSC = ..RemoveAdjustment()
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Remove the adjusted sets the test stored.</p>
Method OnAfterOneTest() As %Status
{
    Quit ..RemoveAdjustment()
}

/// <p>Remove the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $ClassMethod(..#PROBE, "Remaining") '= 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "a probe principal or role survives"))
    Quit tSC
}

/// <p>The holder of exactly the two pairs reads all three screens as rows of each screen's fields; the interfaces
/// screen answers its totals rows, whose namespace and protocol are empty.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Usage</method> answer no rows -- the totals leg
/// goes red.</p>
Method TestTheExactPairsReadAllThree()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Do $$$AssertEquals(..Wire(tTool, "OcuProbe1837Exact", .tAnswer), "200 ", tTool _ ": the principal holding exactly the two pairs reads")
        If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("rows") '= "array") Continue
        Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $Piece("[""Type"",""Namespace"",""Protocol"",""ActiveNow"",""Count""]|[""Namespace"",""Type"",""Volume""]|[""Database"",""DataCreated""]", "|", tI), tTool _ ": rows of the screen's fields")
        If tI '= 1 Continue
        Set tTotals = 0
        Set tIterator = tAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If (tRow.%Get("Namespace") = "") && (tRow.%Get("Protocol") = "") Set tTotals = tTotals + 1
        }
        Do $$$AssertTrue(tTotals > 0, tTool _ ": the answer holds a totals row, whose namespace and protocol are empty")
    }
}

/// <p>A principal missing <code>%Admin_Operate:USE</code>, or <code>%DB_IRISSYS:READ</code>, is refused 403 naming
/// it on all three screens.</p>
/// <p>The screens' own gate refuses the same principals before the port is reached, so skipping the port's
/// gate alone leaves this green; <method>TestThePortRefusesWhatALoweredScreenAdmits</method> pins that gate on
/// the wire and <class>OcuPilot.Test.InteropUsagePort</class> in process.</p>
/// <p>Mutation (Rule 19): declare <code>%Admin_Operate:USE</code> alone on the three descriptors, relax the
/// Registry's system-database arm for <code>monitor</code> sources and make
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> skip its gate for the usage endpoints -- the NoSys leg
/// goes red on all three screens.</p>
Method TestEachMissingPairIsRefusedByName()
{
    For tCase = $ListBuild("OcuProbe1837NoOperate", "%Admin_Operate:USE"), $ListBuild("OcuProbe1837NoSys", "%DB_IRISSYS:READ") {
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Do $$$AssertEquals(..Wire(tTool, $List(tCase, 1), .tAnswer), "403 " _ $List(tCase, 2), tTool _ " " _ $List(tCase, 1) _ ": refused naming the pair")
        }
    }
}

/// <p>With the three screens adjusted below the port's pairs (AD-64), the screen admits a principal the port still
/// refuses, naming the pair it lacks: the principal without <code>%DB_IRISSYS:READ</code> under a set of
/// <code>%Admin_Operate:USE</code> alone, and the principal without <code>%Admin_Operate:USE</code> under a set of
/// <code>%Admin_Manage:USE</code> alone. The refusal carries no screen, which tells the port's from the screen's,
/// and under the first set the holder of exactly the two pairs still reads.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Invoke</method> skip its gate for the usage
/// endpoints -- the refusal legs go red on all three screens.</p>
Method TestThePortRefusesWhatALoweredScreenAdmits()
{
    For tCase = $ListBuild("OcuProbe1837NoSys", $Piece(..#ADJUSTMENTS, ";", 1), "%DB_IRISSYS:READ"), $ListBuild("OcuProbe1837NoOperate", $Piece(..#ADJUSTMENTS, ";", 2), "%Admin_Operate:USE") {
        Set tUser = $List(tCase, 1)
        Do $$$AssertStatusOK(..Adjust($List(tCase, 2)), "the three screens are adjusted to " _ $List(tCase, 2))
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Do $$$AssertEquals(..Wire(tTool, tUser, .tAnswer), "403 " _ $List(tCase, 3), tTool _ " " _ tUser _ ": the lowered screen admits it and the port refuses, naming the pair")
            Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("screen"), 1: "no detail"), "", tTool _ " " _ tUser _ ": and the refusal names no screen")
            If tUser '= "OcuProbe1837NoSys" Continue
            Do $$$AssertEquals(..Wire(tTool, "OcuProbe1837Exact", .tAnswer), "200 ", tTool _ ": the holder of exactly the two pairs still reads")
        }
    }
}

/// <p>Store <var>pPairs</var> as the adjusted set of each of the three screens, replacing the set this class stored
/// before; a failing status when a screen already holds a set of its own.</p>
Method Adjust(pPairs As %String) As %Status
{
    Set tSC = ..RemoveAdjustment()
    If $$$ISERR(tSC) Quit tSC
    Set ..StoredAdjustment = pPairs
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tSC = $ClassMethod(..#ACCESSSTORE, "GuardedPut", $Piece(..#TOOLS, ",", tI), pPairs, 0, ..#PROBE)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Remove the set <property>StoredAdjustment</property> names from each of the three screens that holds it; a set
/// of any other pairs is not this class's and stays.</p>
Method RemoveAdjustment() As %Status
{
    Set tSC = $$$OK
    If ..StoredAdjustment = "" Quit tSC
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Set tGetSC = $ClassMethod(..#ACCESSSTORE, "GuardedGet", tTool, .tPairs, .tVersion, .tFound)
        If $$$ISERR(tGetSC) {
            Set tSC = $$$ADDSC(tSC, tGetSC)
            Continue
        }
        If tFound && (tPairs = ..StoredAdjustment) Set tSC = $$$ADDSC(tSC, $ClassMethod(..#ACCESSSTORE, "GuardedRemove", tTool, tVersion))
    }
    If $$$ISOK(tSC) Set ..StoredAdjustment = ""
    Quit tSC
}

/// <p>A request with no credentials is refused 401 on all three screens.</p>
Method TestARequestWithNoCredentialsIsRefused()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Do $$$AssertEquals(..Wire(tTool, "", .tAnswer), "401 ", tTool _ ": no credentials, no read")
    }
}

/// <p>The read of <var>pTool</var>'s screen at one hundred rows, over the wire as <var>pUser</var> (no credentials when
/// <code>""</code>), answered as <code>status failedPair</code>: the failed pair, or <code>""</code>;
/// <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Wire(pTool As %String, pUser As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ pTool _ "/read?maxRows=100", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}")) } Catch {}
    Set tDetail = $Select($IsObject(pAnswer): pAnswer.%Get("detail"), 1: "")
    Quit $Get(tStatus) _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

}
