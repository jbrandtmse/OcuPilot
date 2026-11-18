/// <p>What Story 24.11's listing group write tests share (Batch 2): the probe's analytics in <code>USER</code>, classes and groups named with the probe's write marker, the
/// person's routes and the agent's mint and confirm over HTTP, the vendor's model of a group, a class's text and what lies outside its <code>Listings</code> XData, the
/// registry's state, the audit and ledger counts, and a probe principal without the SQL pair that mints in a child process. <class>OcuPilot.Test.AnalyticsListingGroupWrite</class>, <class>OcuPilot.Test.AnalyticsListingWrite</class>,
/// <class>OcuPilot.Test.AnalyticsListingGroupWriteEdge</class> and <class>OcuPilot.Test.AnalyticsListingGroupDatabase</class> extend it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in <code>USER</code> and saves, compiles and deletes classes there. It removes
/// everything after the last test of each class.</p>
Class OcuPilot.Test.AnalyticsListingGroupBase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter NAMESPACE = "USER";

/// <p>The prefix every group this class makes starts with, and the prefix of their classes.</p>
Parameter MARKER = "OcuPilotProbeLGW";

Parameter CLASSMARKER = "OcuPilotProbe.Analytics.LGW";

Parameter GROUPSCREEN = "/screens/analytics.listinggroups/action";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupAdd";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupUpdate";

Parameter COPYTOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupCopy";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupDelete";

/// <p>The cubes the tests target, and the cube class the first depends on.</p>
Parameter VISITS = "OcuPilotProbeVisits";

Parameter CATEGORIES = "OcuPilotProbeCategories";

Parameter VISITSCLASS = "OcuPilotProbe.Analytics.VisitsCube";

Parameter CATEGORIESCLASS = "OcuPilotProbe.Analytics.CategoriesCube";

Parameter GATE = "OcuPilot.Test.ScreenGate";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

/// <p>The principal the mint-time SQL rule is judged for: the pairs the listing tools declare, and not <code>%DeepSee_ListingGroupSQL:USE</code>.</p>
Parameter NOSQLUSER = "OcuP2411LgwNoSql";

Parameter NOSQLPRINCIPAL = "OcuP2411LgwNoSql:%Development:U,%DeepSee_Portal:U,%DeepSee_ListingGroup:U,%DeepSee_ListingGroupEdit:U,%DB_USER:RW,%DB_ENSLIB:R,%DB_IRISLIB:R";

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupBase turns analytics on in USER and saves, compiles and deletes classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $USERNAME)
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe and every group and class this class made; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, $CLASSNAME() _ " left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit $$$ADDSC(tSC, ..RemoveNoSqlPrincipal())
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#GATE, "Reset")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveListingGroups")
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#GATE, "Reset")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveListingGroups"), "the test's groups and classes are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The class text of a listing group named <var>pName</var> in the class <var>pClass</var>, saved and compiled in <code>USER</code>: its header depends on the Visits cube's
/// class, a parameter the writes must keep, and one listing, <var>pListing</var>, with SQL, over the Visits cube; <var>pCubes</var> is its target cubes and <var>pResource</var>,
/// when given, the resource that guards the group.</p>
ClassMethod GroupText(pName As %String, pClass As %String, pListing As %String, pCubes As %String = {..#VISITS}, pResource As %String = "") As %String
{
    Set tNL = $Char(13, 10)
    Quit "Class " _ pClass _ " Extends %DeepSee.ListingGroupDefinition [ DependsOn = " _ ..#VISITSCLASS _ " ]" _ tNL _ "{" _ tNL _ tNL _ "/// A line the writes keep." _ tNL _ "Parameter KEEP = ""kept"";" _ tNL _ tNL _
        "XData Listings [ XMLNamespace = ""http://www.intersystems.com/deepsee/listinggroup"" ]" _ tNL _ "{" _ tNL _
        "<listingGroup xmlns=""http://www.intersystems.com/deepsee/listinggroup"" name=""" _ pName _ """ displayName=""Original"" targetCubes=""" _ pCubes _ """" _ $Select(pResource = "": "", 1: " resource=""" _ pResource _ """") _ "><listing name=""" _ pListing _ """ fieldList=""Amount"" sql=""SELECT ID FROM OcuPilotProbe_Analytics.Visit"" selectMode=""1""/></listingGroup>" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
}

/// <p>Save and compile the group <var>pName</var> with the text <method>GroupText</method> gives it, as the class <var>pClass</var>.</p>
ClassMethod SaveGroup(pName As %String, pClass As %String, pListing As %String, pCubes As %String = {..#VISITS}, pResource As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pClass, ..GroupText(pName, pClass, pListing, pCubes, pResource))
    If $$$ISOK(tSC) {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(pClass, "ck-d")
        Set $NAMESPACE = tOrigNS
    }
    Quit tSC
}

/// <p>The class <var>pClass</var>'s text as the instance keeps it.</p>
ClassMethod TextOf(pClass As %String) As %String
{
    Set tText = ""
    Do ##class(%Compiler.UDL.TextServices).GetTextAsString(..#NAMESPACE, pClass, .tText)
    Quit $Translate(tText, $Char(13))
}

/// <p><var>pText</var> without its class header line and without the lines of its <code>Listings</code> XData body: what a write must leave as it was.</p>
ClassMethod Outside(pText As %String) As %String
{
    Set tKept = ""
    Set tBody = 0
    Set tOpen = 0
    For tAt = 1:1:$Length(pText, $Char(10)) {
        Set tLine = $Piece(pText, $Char(10), tAt)
        If $Extract(tLine, 1, 6) = "Class " Continue
        If tBody {
            If tLine = "}" {
                Set tBody = 0
                Set tOpen = 0
            } Else {
                Continue
            }
        }
        If (tOpen = 0) && ($Extract(tLine, 1, 5) = "XData") {
            Set tOpen = 1
        } ElseIf (tOpen = 1) && (tLine = "{") {
            Set tBody = 1
        }
        Set tKept = tKept _ tLine _ $Char(10)
    }
    Quit tKept
}

/// <p>The model the vendor reads from the class <var>pClass</var>, as <code>{name, caption, description, cubes, resource, defaultResource, disabled, listings}</code>, each
/// listing <code>{name, displayName, fields, sql, selectMode, disabled}</code>; <code>"absent"</code> for a class that holds no group.</p>
ClassMethod Model(pClass As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = "absent"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(pClass)
        If $IsObject(tModel) && (tModel.name '= "") {
            Set tOut = tModel.name _ "|" _ tModel.displayName _ "|" _ tModel.description _ "|" _ tModel.targetCubes _ "|" _ tModel.resource _ "|" _ tModel.defaultResource _ "|" _ ''tModel.disabled
            For tAt = 1:1:tModel.listings.Count() {
                Set tListing = tModel.listings.GetAt(tAt)
                Set tOut = tOut _ "#" _ tListing.name _ "|" _ tListing.displayName _ "|" _ tListing.fieldList _ "|" _ tListing.sql _ "|" _ tListing.selectMode _ "|" _ ''tListing.disabled
            }
        }
    } Catch {
        Set tOut = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>Whether the vendor's compiled list names the group <var>pName</var> with the class <var>pClass</var>.</p>
ClassMethod Registered(pName As %String, pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%DeepSee.ListingGroup).%GetListingGroups(.tCompiled, 1)
        Set tHeld = $Data(tCompiled($ZConvert(pName, "U"), 1)) && ($List(tCompiled($ZConvert(pName, "U"), 1), 5) = pClass)
    } Catch {
        Set tHeld = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit ''tHeld
}

/// <p>What the instance holds of this class's groups: every class of the write marker with the length and a SHA-1 checksum of its text, and every group node, as one string, so two calls
/// compare equal when nothing was written between them.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ? ORDER BY Name", ..#CLASSMARKER)
        While tRS.%Next() {
            Set tText = ..TextOf(tRS.%GetData(1))
            Set tOut = tOut _ tRS.%GetData(1) _ "=" _ $Length(tText) _ ":" _ $System.Encryption.Base64Encode($System.Encryption.SHA1Hash($ZConvert(tText, "O", "UTF8"))) _ ";"
        }
        Set tName = $Order(^DeepSee.ListingGroups("groups", $ZConvert(..#MARKER, "U")), -1)
        For {
            Set tName = $Order(^DeepSee.ListingGroups("groups", tName))
            If $Extract(tName, 1, $Length(..#MARKER)) '= $ZConvert(..#MARKER, "U") Quit
            Set tOut = tOut _ "node " _ tName _ ";"
        }
    } Catch {
        Set tOut = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>A person's route <var>pPath</var> with <var>pBody</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %Integer
{
    Do $ClassMethod(..#CONTROL, "CallWide", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The person's screen action <var>pAction</var> of the screen path <var>pScreen</var> on <var>pId</var> with the values <var>pValues</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Quit ..Post(pScreen, tBody, .pAnswer)
}

/// <p>Confirm <var>pProposal</var> over HTTP: the answer in <var>pAnswer</var>, the status returned.</p>
ClassMethod Confirm(pProposal, Output pAnswer, Output pRaw) As %Integer
{
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>The count of <code>ConfigChange</code> rows of the type <var>pType</var> and id <var>pId</var> with the verb <var>pVerb</var> since <var>pSince</var>.</p>
ClassMethod Rows(pSince As %String, pType As %String, pId As %String, pVerb As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "AuditRows", pSince, pType, $Replace(pId, $Char(1), "\u0001"), pVerb, .tData)
}

/// <p>The write port's direct call: <var>pType</var> on <var>pEndpoint</var> with the query members of <var>pExtra</var>, the id <var>pId</var> and the body <var>pBody</var>; the HTTP
/// status and the fault's code in one string, <code>"200 "</code> for an answer; the answer in <var>pResult</var>.</p>
ClassMethod Port(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject, pExtra As %DynamicObject, Output pResult) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set pResult = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, pType, .tQuery, pBody, .pResult, .tHttp, .tFault)
    Quit tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>The mint of <var>pTool</var> with <var>pArgs</var> is refused with no proposal, naming <var>pCode</var> at the start of the fault's code.</p>
Method MintRefused(pTool As %String, pArgs As %DynamicObject, pCode As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusNotOK(tSC, $Parameter(pTool, "TOOLNAME") _ " is refused at the mint")
    Do $$$AssertTrue(('$IsObject($Get(tProposal))) && (+$Get(tHttp) >= 400), "with no proposal and a refusal status: " _ $Get(tHttp))
    Do $$$AssertTrue($IsObject($Get(tFault)) && ($Extract(tFault.%Get("code"), 1, $Length(pCode)) = pCode), "naming " _ pCode _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>The confirm of <var>pProposal</var> of the tool <var>pTool</var> on the target <var>pId</var> of the type <var>pType</var> in the turn <var>pTurn</var> left one
/// <code>ConfigChange</code> row naming the tool since <var>pSince</var>, one agent marker carrying the proposal id and one ledger row (AD-15).</p>
Method AssertAgentRecords(pSince As %String, pProposal, pTool As %String, pTurn As %String, pType As %String, pId As %String)
{
    Set tVerb = $Parameter(pTool, "TOOLNAME")
    Do $$$AssertEquals(..Rows(pSince, pType, pId, tVerb), 1, tVerb _ ": one audit row names the write")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "AgentWrite", pProposal.proposalId, .tMarker, tVerb), 1, tVerb _ ": the agent marker carries the proposal id")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", pTurn, tVerb), 1, tVerb _ ": one ledger row")
}

/// <p>The rows of the screen <var>pScreen</var>'s read (<code>analytics.listinggroups</code> or <code>analytics.listinggrouplistings</code>), with the group <var>pGroup</var> for the
/// Listings screen, as <code>Name:Compiled</code> pairs joined by <code>,</code> for the rows whose name starts with the write marker; <code>"unreadable"</code> when it is not
/// answered.</p>
ClassMethod ScreenRows(pScreen As %String, pGroup As %String = "") As %String
{
    Set tPath = "/screens/" _ pScreen _ "/read?ns=" _ ..#NAMESPACE _ $Select(pGroup '= "": "&listinggroup=" _ $ZConvert(pGroup, "O", "URL"), 1: "")
    Do $ClassMethod(..#CONTROL, "Call", "GET", tPath, "", .tHttp, .tRead)
    If (tHttp '= 200) || '$IsObject(tRead) || '$IsObject(tRead.%Get("rows")) Quit "unreadable " _ tHttp
    Set tOut = ""
    For tAt = 0:1:tRead.rows.%Size() - 1 {
        Set tRow = tRead.rows.%Get(tAt)
        If $Extract(tRow.%Get("Name"), 1, 3) '= "LGW" && ($Extract(tRow.%Get("Name"), 1, $Length(..#MARKER)) '= ..#MARKER) Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ $Select(tRow.%GetTypeOf("Compiled") = "boolean": tRow.%Get("Compiled"), 1: "-")
    }
    Quit tOut
}

/// <p>The agent's read tool <var>pTool</var> answers a row whose <code>Name</code> is <var>pName</var>.</p>
ClassMethod ToolHas(pTool As %String, pArgs As %DynamicObject, pName As %String) As %Boolean
{
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(pTool, pArgs, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set tFound = 0
    If $IsObject(tLeg.%Get("rows")) {
        For tAt = 0:1:tLeg.rows.%Size() - 1 {
            If tLeg.rows.%Get(tAt).Name = pName Set tFound = 1
        }
    }
    Quit ''(tFound && (tLeg.%Get("http") = 200))
}

/// <p>1 when the class <var>pClass</var> is not defined and the group <var>pName</var> and the listing <var>pListing</var> have no node in the registry.</p>
ClassMethod Gone(pName As %String, pClass As %String, pListing As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tGone = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGone = '##class(%Dictionary.ClassDefinition).%ExistsId(pClass) && '$Data(^DeepSee.ListingGroups("groups", $ZConvert(pName, "U"))) && '$Data(^DeepSee.ListingGroups("classes", pClass))
        For tCube = ..#VISITS, ..#CATEGORIES {
            If $Data(^DeepSee.ListingGroups("cubes", $ZConvert(tCube, "U"), "listing", pListing)) Set tGone = 0
        }
    } Catch {
        Set tGone = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit ''tGone
}

/// <p>The composite id of the listing <var>pListing</var> of the group <var>pGroup</var>.</p>
ClassMethod IdOf(pGroup As %String, pListing As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pGroup, pListing))
}

/// <p>The listing named <var>pListing</var> of the model <var>pModel</var> (a <method>OcuPilot.Test.AnalyticsListingGroupBase.Model</method> answer), as its part, else <code>""</code>.</p>
ClassMethod ListingIn(pModel As %String, pListing As %String) As %String
{
    Set tFound = ""
    For tAt = 2:1:$Length(pModel, "#") {
        If $Piece($Piece(pModel, "#", tAt), "|", 1) = pListing Set tFound = $Piece(pModel, "#", tAt)
    }
    Quit tFound
}

/// <p>The write port seam <var>pType</var> of <var>pEndpoint</var> on <var>pId</var> with <var>pBody</var>, under the held pairs: the HTTP status, a space and the fault's code, then, for a
/// privilege refusal, <code>|</code> and the failed pair. <var>pExtra</var> carries the write's query members, as <method>Port</method>'s does.</p>
ClassMethod Seamed(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject, Output pResult, pExtra As %DynamicObject = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set pResult = ""
    Set tSC = $ClassMethod(..#SEAM, "Invoke", pEndpoint, pType, .tQuery, pBody, .pResult, .tHttp, .tFault)
    Set tOut = tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("failedPair") '= "") Set tOut = tOut _ "|" _ tFault.detail.%Get("failedPair")
    Quit tOut
}

/// <p>Hold every pair the listing group writes need in process, but <var>pExcept</var> (a <code>resource:permission</code>, <code>""</code> for none).</p>
ClassMethod HoldEverythingBut(pExcept As %String)
{
    Do $ClassMethod(..#GATE, "Reset")
    Set tPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec($Parameter(..#PORT, "LISTINGGROUPPAIRS") _ "," _ $Parameter(..#PORT, "LISTINGGROUPEDITPAIRS") _ "," _ $Parameter(..#PORT, "LISTINGGROUPSQLPAIRS"))
    Set tPairs = tPairs _ ##class(OcuPilot.Port.AtelierPort).Pairs() _ ##class(OcuPilot.Port.AtelierPort).WritePairs(..#NAMESPACE) _ $ListBuild($ListBuild("%DB_USER", "WRITE"), $ListBuild("%DB_USER", "READ"))
    For tAt = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tAt)
        If $List(tPair, 1) _ ":" _ $List(tPair, 2) = pExcept Continue
        Do $ClassMethod(..#GATE, "Hold", $List(tPair, 1), $List(tPair, 2))
    }
}

/// <p>Mint <var>pTool</var> with <var>pArgs</var> as the principal without the SQL pair, in a child process that logs in as it, with the turn <var>pTurn</var> seeded for it: what the child
/// signalled, <code>{loggedIn, username, minted, http, code, problem}</code>, or <code>{error}</code>.</p>
ClassMethod MintAsNoSql(pTool As %String, pArgs As %DynamicObject, pTurn As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsListingGroupBase).MintProbe($Job, ..#NOSQLUSER, pTool, pArgs.%ToJSON(), pTurn, ..#NAMESPACE)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>MintAsNoSql</method> starts: log in as <var>pUsername</var>, mint <var>pTool</var> with the arguments <var>pArgsJson</var> in the turn <var>pTurn</var> scoped to
/// <var>pNamespace</var>, as <method>OcuPilot.Test.InteropItemControl.MintAs</method> does for the HTTP account, and signal the outcome to process <var>pParent</var>.</p>
ClassMethod MintProbe(pParent As %Integer, pUsername As %String, pTool As %String, pArgsJson As %String, pTurn As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tArgs = ##class(%DynamicObject).%FromJSON(pArgsJson)
        Do tArgs.%Set("rationale", "probe", "string")
        Do tArgs.%Set("expectedImpact", "probe", "string")
        Set tIdArgument = $ClassMethod(pTool, "IdArgument")
        Set tSC = $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), pUsername, "", pTurn, tArgs, $ClassMethod(pTool, "LimitsClass"), .tProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), tArgs.%Get(tIdArgument), tIdArgument, $ClassMethod(pTool, "SettableFields"), $ClassMethod(pTool, "ToolClass"))
        Do tOut.%Set("minted", ''$IsObject($Get(tProposal)), "boolean")
        Do tOut.%Set("http", +$Get(tHttp))
        If $IsObject($Get(tFault)) {
            Do tOut.%Set("code", tFault.%Get("code"))
            If $IsObject(tFault.%Get("detail")) Do tOut.%Set("problem", tFault.detail.%Get("problem"))
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Delete the principal <parameter>NOSQLUSER</parameter> and its role; a failing status when either survives.</p>
ClassMethod RemoveNoSqlPrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#NOSQLUSER) Do ##class(Security.Users).Delete(..#NOSQLUSER)
        If ##class(Security.Roles).Exists(..#NOSQLUSER _ "Role") Do ##class(Security.Roles).Delete(..#NOSQLUSER _ "Role")
        If ##class(Security.Users).Exists(..#NOSQLUSER) || ##class(Security.Roles).Exists(..#NOSQLUSER _ "Role") Set tSC = $$$ERROR($$$GeneralError, $CLASSNAME() _ " left the principal or role of " _ ..#NOSQLUSER)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
