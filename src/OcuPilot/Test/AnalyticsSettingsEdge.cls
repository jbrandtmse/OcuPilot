/// <p>Pins the edges of Story 24.13's read surface (AD-35, AD-36, AD-65) against <code>USER</code>, with analytics on and the analytics settings written through the vendor's own methods by
/// <class>OcuPilot.Test.AnalyticsProbe</class>: the agent's four read tools are cut by the caller's row cap and by their own <code>maxRows</code> and say so, and a cap equal to the count cuts
/// nothing; the same tools are refused 409 <code>ANALYTICS.NAMESPACE</code> in a namespace without analytics and answer no rows; a Google Maps key stored as empty reads no mask and one stored as
/// <code>0</code> reads the mask, on the screen and in the tool alike; and a cap anywhere inside the worklists, at a panel or at a page boundary, answers exactly that many of the rows the uncut read
/// answers first.</p>
/// <p>The matrix of the stored, unset, key, never-run and gate states is pinned by <class>OcuPilot.Test.AnalyticsSettingsRead</class>, whose port read this class calls.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the probe turns analytics on for <code>USER</code> and the class empties and rewrites <code>USER</code>'s three settings globals, which it restores from a
/// snapshot taken first. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter READ = "OcuPilot.Test.AnalyticsSettingsRead";

/// <p>The read class whose row helpers this class uses.</p>
Parameter ROWS = "OcuPilot.Test.AnalyticsQualityMeasureRead";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

/// <p>The four screens, in tab order, and the rows each reads with the markers stored.</p>
Parameter SCREENS = "analytics.settings,analytics.worklists,analytics.runtimevariables,analytics.usericons";

Parameter COUNTS = "15,16,2,1";

/// <p>The credential mask a stored key reads as.</p>
Parameter MASK = "[redacted]";

/// <p>What <code>USER</code>'s three settings globals read as before the class changed them.</p>
Property StartDigest As %String;

/// <p>Whether <property>StartDigest</property> was taken, which an empty digest, the state of a fresh instance, cannot say.</p>
Property StartTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEdge turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    If $$$ISOK(tSC) Set ..StartDigest = $ClassMethod(..#PROBE, "SettingsDigest"), ..StartTaken = 1
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, which restores USER's flags and its three settings globals; a failing status when anything of it is left or the three read otherwise than at the start.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEdge left USER's analytics settings changed")
    Quit tSC
}

/// <p>Every test starts with nothing stored, and states what it stores.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>Forget the scope, and put the three settings globals back from the snapshot, which is taken again for the next test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RestoreSettings")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    Quit tSC
}

/// <p>One call of the read tool <var>pName</var> as the agent makes it, in the scope already set: its result in <var>pResult</var>, the HTTP status and the fault.</p>
ClassMethod Tool(pName As %String, pArgs As %DynamicObject, pCap As %Integer, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Set pResult = ""
    Set pHttp = 0
    Set pFault = ""
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", pName, .tTool)
    If $$$ISERR(tSC) || '$IsObject($Get(tTool)) Quit $$$ERROR($$$GeneralError, pName _ " does not resolve")
    Quit $ClassMethod(..#REGISTRY, "InvokeTool", tTool, pArgs, pCap, .pResult, .pHttp, .pFault)
}

/// <p>The cut of one tool read, as <code>http|rows sent|truncated|rows available</code>; <code>http|unreadable</code> when no result came.</p>
ClassMethod Cut(pName As %String, pArgs As %DynamicObject, pCap As %Integer) As %String
{
    Set tSC = ..Tool(pName, pArgs, pCap, .tResult, .tHttp, .tFault)
    If '$IsObject(tResult) Quit tHttp _ "|unreadable"
    Quit tHttp _ "|" _ tResult.rows.%Size() _ "|" _ tResult.truncated _ "|" _ tResult.rowsAvailable
}

/// <p>Store the Google Maps key <var>pKey</var> alone in <code>USER</code>, as the page's save does: the node exists, with that text.</p>
ClassMethod StoreKey(pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set ^DeepSee.UserPortalSettings("GoogleMapsKey") = pKey
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The <code>Value</code> and <code>Stored</code> of the key's row on the screen's read and in the tool's rows, as <code>screen value|screen stored|tool value|tool stored</code>.</p>
ClassMethod KeyRows() As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.settings/read?maxRows=100", "", .tStatus, .tScreen)
    Set tScreenKey = $Select($IsObject(tScreen) && $IsObject(tScreen.%Get("rows")): $ClassMethod(..#ROWS, "RowNamed", tScreen.rows, "GoogleMapsKey"), 1: "")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.settings.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set tToolKey = $Select($IsObject(tLeg.%Get("rows")): $ClassMethod(..#ROWS, "RowNamed", tLeg.rows, "GoogleMapsKey"), 1: "")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If '$IsObject(tScreenKey) || '$IsObject(tToolKey) Quit "unreadable: " _ tStatus _ " " _ tLeg.%ToJSON()
    Quit tScreenKey.Value _ "|" _ tScreenKey.Stored _ "|" _ tToolKey.Value _ "|" _ tToolKey.Stored
}

/// <p>The agent's read tool for each screen is cut by the caller's row cap and by its own <code>maxRows</code>, and says so: a cap below the count answers that many rows, reports
/// the cut and the count it was cut from; a cap equal to the count, or above it, reports nothing cut. The icons screen holds one row with the markers stored, so a cap of one is exactly
/// its count.</p>
/// <p>Mutation (Rule 19): cut at one row more than <var>pContextCap</var> in <method>OcuPilot.Screen.Tool.Read.View</method> -- the cut legs go red.</p>
Method TestAToolReadIsCutByTheCallersCapAndSaysSo()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetMarkerSettings"), "the marker settings are stored through the vendor's own methods")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tI = 1:1:4 {
        Set tName = $Piece(..#SCREENS, ",", tI) _ ".read"
        Set tCount = $Piece(..#COUNTS, ",", tI)
        Set tCut = (tCount > 1)
        Do $$$AssertEquals(..Cut(tName, {}, 1), "200|1|" _ tCut _ "|" _ tCount, tName _ ": a caller's cap of one answers one row and says whether it cut")
        Do $$$AssertEquals(..Cut(tName, {"maxRows": 1}, 100), "200|1|" _ tCut _ "|1", tName _ ": the tool's own maxRows of one reads one row and says whether it cut")
        Do $$$AssertEquals(..Cut(tName, {}, tCount), "200|" _ tCount _ "|0|" _ tCount, tName _ ": a cap equal to the count answers every row and cuts nothing")
        Do $$$AssertEquals(..Cut(tName, {}, 100), "200|" _ tCount _ "|0|" _ tCount, tName _ ": a cap above the count cuts nothing")
    }
}

/// <p>The agent's four read tools in a namespace that does not report analytics are refused 409 <code>ANALYTICS.NAMESPACE</code> and answer no rows, while the same tools in <code>USER</code>
/// answer; the port's own refusal reaches the tool as it reaches the screen.</p>
/// <p>Mutation (Rule 19): skip the analytics-reporting test in <method>OcuPilot.Port.AnalyticsPort.AdmitNamespace</method> -- the refusal legs go red.</p>
Method TestTheToolsAreRefusedWhereAnalyticsIsOff()
{
    For tI = 1:1:4 {
        Set tName = $Piece(..#SCREENS, ",", tI) _ ".read"
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ..Tool(tName, {}, 100, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tName _ ": a namespace without analytics is refused")
        Do $$$AssertTrue('$IsObject(tResult), tName _ ": and no rows are answered")
        Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
        Set tSC = ..Tool(tName, {}, 100, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tName _ ": the same tool answers in " _ ..#NAMESPACE)
    }
}

/// <p>A Google Maps key stored as empty, which the page's save stores when it is given none, is a key that is stored and has no text: its row reads no value and stored, on the screen and in the
/// tool alike. A key whose text is <code>0</code> is a key: its row reads the mask. Neither reads the empty-string sentinel.</p>
/// <p>Mutation (Rule 19): answer the mask for every stored key row in <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the empty leg goes red; treat a key whose text is <code>0</code> as
/// no key there -- the <code>0</code> leg goes red.</p>
Method TestAnEmptyOrFalsyKeyIsReadAsWhatItIs()
{
    Do $$$AssertEquals(..KeyRows(), "|0||0", "with nothing stored the key row reads no value and not stored")
    Do $$$AssertStatusOK(..StoreKey(""), "a key of no text is stored")
    Do $$$AssertEquals(..KeyRows(), "|1|" _ "|1", "it reads stored with no mask, on the screen and in the tool")
    Do $$$AssertStatusOK(..StoreKey(0), "a key whose text is 0 is stored")
    Do $$$AssertEquals(..KeyRows(), ..#MASK _ "|1|" _ ..#MASK _ "|1", "it reads the mask, on the screen and in the tool")
}

/// <p>A cap anywhere inside the worklists' sixteen rows, a panel's four and a page's eight boundaries among them, answers exactly that many rows, and they are the first rows of the uncut
/// read in the same order; a cap above sixteen answers all sixteen.</p>
/// <p>Mutation (Rule 19): stop the worklists branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> only once <code>pData</code> is above <code>pMax</code> -- every capped leg goes red.</p>
Method TestACapInsideTheWorklistsAnswersThatManyOfTheFirstRows()
{
    Set tSC = $ClassMethod(..#READ, "Read", "Worklists", 100, .tAll, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount",tAll), "200|16", "the uncut read answers sixteen rows")
    If '$IsObject(tAll) Quit
    For tCap = 1:1:17 {
        Set tSC = $ClassMethod(..#READ, "Read", "Worklists", tCap, .tRows, .tHttp, .tFault)
        Set tWant = $Select(tCap > 16: 16, 1: tCap)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount",tRows), "200|" _ tWant, "a cap of " _ tCap _ " answers " _ tWant _ " rows")
        If '$IsObject(tRows) Continue
        Set tSame = 1
        For tAt = 0:1:tRows.%Size() - 1 {
            If tRows.%Get(tAt).%ToJSON() '= tAll.%Get(tAt).%ToJSON() Set tSame = 0
        }
        Do $$$AssertTrue(tSame, "a cap of " _ tCap _ " answers the first " _ tWant _ " rows of the uncut read")
    }
}

}
