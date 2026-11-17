/// <p>Pins Story 24.10's gate on the folder manager's three writes (AD-8, AD-29, AD-44, AD-65) at the person's screen actions and at the port, against <code>USER</code>: a
/// principal without the Folder Manager's own pair <code>%Development:USE</code>, and one holding the pairs but only READ on the database <code>^DeepSee.FolderItemD</code>
/// maps to, are each refused 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair on the Import and Delete actions, with the folder items as they were; an Export asks the
/// file system's resource instead, which no principal here holds; and a folder item database that is mounted read-only or not journaled is refused 409
/// <code>ANALYTICS.FOLDERITEM.READONLY</code> or <code>NOTJOURNALED</code> at the port before any vendor call, for the import, the delete and the reads composed for them,
/// while the export, which reads only, is not refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP, <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates users and roles, turns analytics on in <code>USER</code> and writes folder items there; it removes the principals, their roles, the items
/// and the probe after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsFolderItemGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter BASE = "OcuPilot.Test.AnalyticsFolderItemTransfer";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter NAMESPACE = "USER";

Parameter MARKER = "OcuProbeFI2410";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: P1 without the Folder Manager's
/// pair (it clears the floor by <code>%Admin_Operate</code>), P2 with both pairs and READ on <code>USER</code> alone, P3 with both and WRITE.</p>
Parameter PRINCIPALS = "OcuP2410NoDev:%Admin_Operate:U,%DeepSee_Portal:U,%DB_USER:RW;OcuP2410ReadOnly:%Development:U,%DeepSee_Portal:U,%DB_USER:R;OcuP2410Editor:%Development:U,%DeepSee_Portal:U,%DB_USER:RW";

Parameter P1 = "OcuP2410NoDev";

Parameter P2 = "OcuP2410ReadOnly";

Parameter P3 = "OcuP2410Editor";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemGate creates and deletes users and roles, turns analytics on in USER and writes folder items there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedPassword = "OcuP2410Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsFolderItemGate")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals, their roles, the items and the probe; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#BASE, "Sweep")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#BASE, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemGate left folder items or folders in USER: " _ $ClassMethod(..#BASE, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#BASE, "Sweep")
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#BASE, "Sweep")
    Quit $$$OK
}

/// <p>A request over the wire as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>: the HTTP status, the raw body in <var>pRaw</var>.</p>
Method Call(pPath As %String, pUser As %String, pBody As %String, Output pRaw) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody, "application/json")
    Quit +$Get(tStatus)
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>; <code>""</code> for a body that is not a refusal.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || (tBody.%Get("code") = "") Quit ""
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>The three writes as the person reaches them, each as a screen action body for the item <var>pName</var>: Export to this browser, Import of a local file that holds
/// a free item, and Delete.</p>
ClassMethod Bodies(pName As %String) As %List
{
    Set tFree = $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", ..#MARKER _ "/GateNew.dashboard"))
    Quit $ListBuild({"action": "export-browser", "id": (pName)}.%ToJSON(), {"action": "import-local", "id": "import", "values": {"fileName": "a.xml", "content": (tFree)}}.%ToJSON(), {"action": "delete", "id": (pName)}.%ToJSON())
}

/// <p>AC4: each write, from the person's side, is refused 403 naming the failed pair for the principal without the Folder Manager's pair (<code>%Development:USE</code>) and,
/// for the import and the delete, for the one with READ alone on the folder item database (<code>%DB_USER:WRITE</code>); the export asks the file system's resource, which no
/// principal here holds. The principal holding every pair is not refused for one: its import and its delete run. The folder items are as they were after each refusal.</p>
/// <p>Mutation (Rule 19): each pair is enforced at several layers, so no single drop reddens this: remove <code>%Development:USE</code> from
/// <parameter>OcuPilot.Port.AnalyticsPort.FOLDERPAIRS</parameter> and from the Folder items descriptor's <code>privileges</code> together -- the first principal's legs go red.</p>
Method TestEachWriteIsRefusedNamingTheFailedPair()
{
    Set tName = ..#MARKER _ "/GateItem.dashboard"
    Do $ClassMethod(..#BASE, "Item", tName)
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Set tBodies = ..Bodies(tName)
    Set tPath = "/screens/analytics.folderitems/action"
    For tCase = $ListBuild(..#P1, "%Development:USE", "%Development:USE", "%Development:USE"), $ListBuild(..#P2, "%Admin_FileSystemAccess:USE", "%DB_USER:WRITE", "%DB_USER:WRITE"), $ListBuild(..#P3, "%Admin_FileSystemAccess:USE", "", "") {
        For tI = 1:1:$ListLength(tBodies) {
            Set tPair = $List(tCase, tI + 1)
            Set tStatus = ..Call(tPath, $List(tCase, 1), $List(tBodies, tI), .tRaw)
            If tPair = "" {
                Do $$$AssertTrue(tStatus < 300, $List(tCase, 1) _ ": request " _ tI _ " is not refused for a pair: " _ tStatus _ " " _ $Extract(tRaw, 1, 160))
            } Else {
                Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), "403 AUTH.NOPRIVILEGE|" _ tPair, $List(tCase, 1) _ ": request " _ tI _ " is refused naming its pair")
            }
        }
        If $List(tCase, 3) '= "" Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot"), tBefore, $List(tCase, 1) _ ": and the folder items are as they were")
        Do $ClassMethod(..#BASE, "Sweep")
        Do $ClassMethod(..#BASE, "Item", tName)
        Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    }
}

/// <p>AC4: with the folder item database mounted read-only, or not journaled, an import and a delete, and the reads composed for them, are refused 409
/// <code>ANALYTICS.FOLDERITEM.READONLY</code> or <code>NOTJOURNALED</code> before any vendor call, and the folder items are as they were; the export reads only and is not refused.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AnalyticsPort.AdmitDestination</method> in <method>OcuPilot.Port.AnalyticsPort.AdmitJournaled</method> -- the read-only legs go red;
/// skip the journal test there -- the not-journaled legs go red.</p>
Method TestAReadOnlyOrUnjournaledDatabaseIsRefusedBeforeAnyVendorCall()
{
    Set tName = ..#MARKER _ "/Dest.dashboard"
    Do $ClassMethod(..#BASE, "Item", tName)
    Set tText = $ClassMethod(..#BASE, "Wrap", $ClassMethod(..#BASE, "Doc", ..#MARKER _ "/DestNew.dashboard"))
    Set tExtra = {"fileName": "d.xml", "content": (tText)}
    Do tExtra.%Set("digest", ##class(OcuPilot.Port.AnalyticsPort).TextDigest(tText))
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    For tMode = "readonly", "nonjournaled" {
        Set tCode = $Select(tMode = "readonly": "409 ANALYTICS.FOLDERITEM.READONLY", 1: "409 ANALYTICS.FOLDERITEM.NOTJOURNALED")
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", tMode)
        Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORT", "import", tExtra, .tRes, .tFault), tCode, tMode _ ": the import is refused")
        Do $$$AssertEquals($ClassMethod(..#BASE, "T", "IMPORTFILE", "import", tExtra, .tRes, .tFault, "IMPORT"), tCode, tMode _ ": and so is its read composed for the import")
        Do $$$AssertEquals($ClassMethod(..#BASE, "T", "DELETE", tName, "", .tRes, .tFault), tCode, tMode _ ": the delete is refused")
        Do $$$AssertEquals($ClassMethod(..#BASE, "T", "FOLDERITEM", tName, "", .tRes, .tFault, "DELETE"), tCode, tMode _ ": and so is its read composed for the delete")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, tMode _ ": no vendor call was made")
        Do $$$AssertEquals($ClassMethod(..#BASE, "T", "EXPORT", tName, "", .tRes, .tFault), "200 ", tMode _ ": the export reads only and is not refused")
    }
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot"), tBefore, "and nothing was written")
}

}
