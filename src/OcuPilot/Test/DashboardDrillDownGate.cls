/// <p>Pins the four Dashboard drill-downs' gate against real principals (AD-8, AD-29, Story 18.36), each reading
/// <code>GET /screens/&lt;tool&gt;/read?maxRows=10</code> of the four screens over the wire: a principal holding
/// exactly the Dashboard's two pairs reads all four; a principal missing either pair is refused 403 naming it on all
/// four; and a request with no credentials is refused 401 on all four.</p>
/// <p><b>What it needs from the environment:</b> <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>,
/// because it creates three users and roles named <code>OcuProbe1836*</code>, each also holding READ on the install
/// namespace's code database, as every caller must. The principals are removed after the last test.</p>
Class OcuPilot.Test.DashboardDrillDownGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DashboardDrillDownProbe";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's READ&gt;</code>,
/// separated by <code>;</code>: the holder of exactly the two pairs; one with <code>%Admin_Manage</code> in place of
/// <code>%Admin_Operate</code>; and one without the system database's read.</p>
Parameter PRINCIPALS = "OcuProbe1836Exact:%Admin_Operate:U,%DB_IRISSYS:R;OcuProbe1836NoOperate:%Admin_Manage:U,%DB_IRISSYS:R;OcuProbe1836NoSys:%Admin_Operate:U";

/// <p>The four screens' tool identifiers, each read as <code>/screens/&lt;tool&gt;/read?maxRows=10</code>.</p>
Parameter TOOLS = "osmgmt.globalstatistics,osmgmt.ecpstatistics,osmgmt.resourcestatistics,osmgmt.activeprocesses";

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
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DashboardDrillDownGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1836Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    If $ClassMethod(..#PROBE, "Remaining") '= (2 * $Length(..#PRINCIPALS, ";")) Quit $$$ERROR($$$GeneralError, "the probe principals and their roles were not all created")
    Quit $$$OK
}

/// <p>Remove the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $ClassMethod(..#PROBE, "Remaining") '= 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "a probe principal or role survives"))
    Quit tSC
}

/// <p>The holder of exactly the two pairs reads all four screens: the statistics screens one row of their fields,
/// and Most active processes no row whose <code>Process</code> is empty.</p>
/// <p>Mutation (Rule 19): keep the empty rows in <method>OcuPilot.Port.AdminPort.ComposedAnswer</method> -- the
/// processes leg goes red while the instance pads its busy-process list.</p>
Method TestTheExactPairsReadAllFour()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Do $$$AssertEquals(..Wire(tTool, "OcuProbe1836Exact", .tAnswer), "200 ", tTool _ ": the principal holding exactly the two pairs reads")
        If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("rows") '= "array") Continue
        If tI <= 2 Do $$$AssertEquals(tAnswer.rows.%Size(), 1, tTool _ ": one row of the screen's fields")
        If tI '= 4 Continue
        Set tIterator = tAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Do $$$AssertNotEquals(tRow.%Get("Process"), "", tTool _ ": row " _ (tIndex + 1) _ " names its process")
        }
    }
}

/// <p>A principal missing <code>%Admin_Operate:USE</code>, or <code>%DB_IRISSYS:READ</code>, is refused 403 naming
/// it on all four screens.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.DashboardResources</class>'s privileges -- its NoOperate leg goes red.</p>
Method TestEachMissingPairIsRefusedByName()
{
    For tCase = $ListBuild("OcuProbe1836NoOperate", "%Admin_Operate:USE"), $ListBuild("OcuProbe1836NoSys", "%DB_IRISSYS:READ") {
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Do $$$AssertEquals(..Wire(tTool, $List(tCase, 1), .tAnswer), "403 " _ $List(tCase, 2), tTool _ " " _ $List(tCase, 1) _ ": refused naming the pair")
        }
    }
}

/// <p>A request with no credentials is refused 401 on all four screens.</p>
Method TestARequestWithNoCredentialsIsRefused()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Do $$$AssertEquals(..Wire(tTool, "", .tAnswer), "401 ", tTool _ ": no credentials, no read")
    }
}

/// <p>The read of <var>pTool</var>'s screen at ten rows, over the wire as <var>pUser</var> (no credentials when
/// <code>""</code>), answered as <code>status failedPair</code>: the failed pair, or <code>""</code>;
/// <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Wire(pTool As %String, pUser As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ pTool _ "/read?maxRows=10", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}")) } Catch {}
    Set tDetail = $Select($IsObject(pAnswer): pAnswer.%Get("detail"), 1: "")
    Quit $Get(tStatus) _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

}
