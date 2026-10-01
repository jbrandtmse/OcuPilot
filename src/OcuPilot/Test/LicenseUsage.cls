/// <p>License usage (Story 16.7): the four tab declarations and the group they form, and the
/// <code>source.rows</code> read shape each issues (AD-36 as amended) -- one member of the
/// <code>Monitor</code> <code>LICENSEUSAGE</code> answer projected to rows, the vendor's
/// <code>maxRows</code> sent as the cap plus one, truncation reported, an empty member read as no
/// rows, and any other answer failing the whole read.</p>
/// <p>The reads run through <class>OcuPilot.Test.Read.ReadFixture</class> over
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>, whose answer each test arms; the declarations
/// are read from the compiled descriptors. Needs a compiled instance; makes no request and writes
/// only process-private globals.</p>
Class OcuPilot.Test.LicenseUsage Extends %UnitTest.TestCase
{

/// <p>The four tabs, in position order, as <code>descriptor:route:rows:tool:emptyKey:tabLabelKey</code>.</p>
Parameter TABS = "LicenseSummaryTab:os-management/license-usage:Summary:osmgmt.licensesummary:licenseUsageSummaryEmpty:openApiColumnSummary,LicenseProcessTab:os-management/license-usage/processes:UsageByProcess:osmgmt.licenseprocesses:licenseUsageProcessesEmpty:licenseUsageByProcess,LicenseUserTab:os-management/license-usage/users:UsageByUser:osmgmt.licenseusers:licenseUsageUsersEmpty:licenseUsageByUser,LicenseDistributedTab:os-management/license-usage/distributed:ConnectionList:osmgmt.licensedistributed:licenseUsageDistributedEmpty:licenseUsageDistributed";

/// <p>The package the four descriptors sit in.</p>
Parameter PACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The group every tab declares: the first tab's own route.</p>
Parameter GROUP = "os-management/license-usage";

/// <p><code>%Api.Admin.Endpoints.Monitor</code>'s <code>LICENSEUSAGE</code> type number, which
/// <class>OcuPilot.Test.ReadSource.Endpoint</class> dispatches on.</p>
Parameter LICENSEUSAGETYPE = 16;

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
}

/// <p>The <var>pIndex</var>th piece <var>pPiece</var> of <parameter>TABS</parameter>.</p>
ClassMethod Tab(pIndex As %Integer, pPiece As %Integer) As %String
{
    Quit $Piece($Piece(..#TABS, ",", pIndex), ":", pPiece)
}

/// <p><var>pPairs</var>, a <class>%List</class> of <code>$ListBuild(resource, permission)</code>, as
/// <code>resource:permission</code> text, comma-separated in order.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>A whole <code>LICENSEUSAGE</code> answer, shaped as the vendor answers it, with one row in
/// each member.</p>
ClassMethod Answer() As %DynamicObject
{
    Quit {
        "UsageByProcess": [{"PID": 1626, "Process": "System", "LID": "", "Type": "", "Con": 0, "MaxCon": 0, "CSPCon": 0, "LU": 0, "Active": 0, "Grace": 0}],
        "UsageByUser": [{"UserId": "UnknownUser", "Type": "User", "Connects": 1, "MaxCon": 1, "CSPCon": 0, "LU": 1, "Active": 12, "Grace": 0}],
        "Summary": [{"LicenseUnitUse": "Current License Units Used ", "Local": "1", "Distributed": "Not connected to license server"}],
        "ConnectionList": [{"UserId": "UnknownUser", "LicenseUnits": "1", "Connections": "1", "ServerIP": "127.0.0.1", "Instance": "IRIS"}]
    }
}

/// <p>Arm the stand-in endpoint's <code>LICENSEUSAGE</code> answer with <var>pAnswer</var>.</p>
ClassMethod Arm(pAnswer As %DynamicAbstractObject)
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", pAnswer.%ToJSON(), ..#LICENSEUSAGETYPE)
}

/// <p>The four declarations pass the read and tab grammar and form one group: Summary is the side
/// bar's seventh OS management entry at the group's route, the other three unlisted at positions 2
/// to 4. Each is a <code>detail</code> screen over <code>{admin, Monitor, LICENSEUSAGE}</code> naming
/// its own member, with the two OS management pairs and no own pair, no entity type, instance scope,
/// no id, no action, no refresh, <code>%CSP.UI.Portal.LicenseUsage</code> as its classic page with no
/// exemption, a context carrying exactly the read's fields, the name column's field as the default
/// ascending sort, its own tool identifier, empty text and tab label, and the same three Capacity
/// prompts.</p>
/// <p>Mutation: name <code>UsageByUser</code> as the By process tab's <code>rows</code> -&gt; its row
/// goes red.</p>
Method TestTheFourTabsDeclareTheirReadsAndFormOneGroup()
{
    Set tValidateSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tValidateSC, "the registry validates with the four tabs in it: " _ $Get(tProblem))
    For tI = 1:1:4 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tWhere _ "the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tWhere _ "its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tDeclaration), "", tWhere _ "its tab is the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tWhere _ "and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute(..Tab(tI, 2)), tClass, tWhere _ "its route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..Tab(tI, 4)), tClass, tWhere _ "and so does its tool identifier")

        Set tTab = tDeclaration.tab
        Do $$$AssertEquals(tTab.group _ "|" _ tTab.position _ "|" _ tTab.labelKey, ..#GROUP _ "|" _ tI _ "|" _ ..Tab(tI, 6), tWhere _ "the group, its position and its tab label")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $Select(tI = 1: 8, 1: 0), tWhere _ "Summary is the eighth entry and the others are unlisted")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "os-management", tWhere _ "in OS management")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", tWhere _ "on the detail archetype")
        Do $$$AssertEquals($ClassMethod(tClass, "IsBuilt"), 1, tWhere _ "built")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tWhere _ "and not refreshing")
        Do $$$AssertEquals(..PairsText($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Operate:USE,%DB_IRISSYS:READ", tWhere _ "the two pairs, in order")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "OwnPrivilegePairs")), 0, tWhere _ "none of them its own")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", tWhere _ "which the area covers")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "|instance|none", tWhere _ "no entity type, instance scope, no id")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tWhere _ "no action")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.LicenseUsage", tWhere _ "the classic page it replaces")
        Do $$$AssertEquals($ClassMethod(tClass, "EmptyStateKey"), ..Tab(tI, 5), tWhere _ "its own empty text")

        Set tSource = tDeclaration.read.source
        Do $$$AssertEquals(tSource.port _ "|" _ tSource.endpoint _ "|" _ tSource.type _ "|" _ tSource.rows, "admin|Monitor|LICENSEUSAGE|" _ ..Tab(tI, 3), tWhere _ "one member of the LICENSEUSAGE answer")
        Do $$$AssertEquals(tDeclaration.read.paging, "cap", tWhere _ "bounded by the cap")
        Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), tWhere _ "the context carries exactly the read's fields")
        Do $$$AssertEquals(tDeclaration.read.sort.default _ "|" _ tDeclaration.read.sort.direction, tDeclaration.read.fields.%Get(0) _ "|asc", tWhere _ "sorted by its name column, ascending")
        Do $$$AssertEquals(tDeclaration.table.columns.%Get(0).field _ "|" _ tDeclaration.table.columns.%Get(0).kind, tDeclaration.read.fields.%Get(0) _ "|name", tWhere _ "whose first column is the name column")
        Set tPrompts = ""
        Set tPromptIterator = tDeclaration.suggestedPrompts.%GetIterator()
        While tPromptIterator.%GetNext(.tIndex, .tPrompt) {
            Set tPrompts = tPrompts _ $Select(tPrompts = "": "", 1: ",") _ tPrompt.groupKey _ ":" _ tPrompt.textKey
        }
        Do $$$AssertEquals(tPrompts, "promptGroupCapacity:licenseUsagePrompt1,promptGroupCapacity:licenseUsagePrompt2,promptGroupCapacity:licenseUsagePrompt3", tWhere _ "the three shared Capacity prompts")
    }
}

/// <p>Each tab lists its own member of one answer: the Summary, By process, By user and
/// Distributed rows come back projected to exactly each tab's declared fields, one row each, with
/// the vendor's values, and each read issues <code>LICENSEUSAGE</code> once.</p>
/// <p>Mutation: return the whole answer rather than its member from
/// <method>OcuPilot.Screen.Read.RowsMember</method> -&gt; every read fails as not a list and each
/// row goes red.</p>
Method TestEachMemberIsProjectedToRows()
{
    For tI = 1:1:4 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tMember = ..Tab(tI, 3)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
        Do ..Arm(..Answer())
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tWhere _ "the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tWhere _ "at 200")
        If '$IsObject(tResult) Continue
        Do $$$AssertEquals(tResult.fields.%ToJSON(), $ClassMethod(tClass, "Read").fields.%ToJSON(), tWhere _ "the declared fields")
        Do $$$AssertEquals(tResult.rows.%Size(), 1, tWhere _ "one row, the member's own")
        Do $$$AssertEquals(tResult.truncated, 0, tWhere _ "not truncated")
        If tResult.rows.%Size() '= 1 Continue
        Set tExpected = ..Answer().%Get(tMember).%Get(0)
        Set tRow = tResult.rows.%Get(0)
        Set tFieldIterator = tResult.fields.%GetIterator()
        While tFieldIterator.%GetNext(.tIndex, .tField) {
            Do $$$AssertTrue(tExpected.%IsDefined(tField), tWhere _ tField _ " is a key the vendor's row carries")
            Do $$$AssertEquals(tRow.%Get(tField), tExpected.%Get(tField), tWhere _ tField _ " is the vendor's value")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorTypes"), ..#LICENSEUSAGETYPE, tWhere _ "issued as LICENSEUSAGE, once")
    }
}

/// <p>The read sends the vendor's <code>maxRows</code> as the cap plus one, keeps at most the cap's
/// rows and reports truncation when the member holds more; a member holding exactly the cap is not
/// truncated.</p>
/// <p>Mutation: send <code>maxRows</code> as the cap rather than the cap plus one in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the recorded query goes red.</p>
Method TestTheCapPlusOneIsSentAndTruncationIsReported()
{
    Set tAnswer = ..Answer()
    Set tProcesses = []
    For tPid = 101:1:104 {
        Do tProcesses.%Push({"PID": (tPid), "Process": "System", "LID": "", "Type": "", "Con": 0, "MaxCon": 0, "CSPCon": 0, "LU": 0, "Active": 0, "Grace": 0})
    }
    Do tAnswer.%Set("UsageByProcess", tProcesses)
    Do ..Arm(tAnswer)
    Set tClass = ..#PACKAGE _ "LicenseProcessTab"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the capped read succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorQuery"), "maxRows=3", "the vendor is asked for the cap plus one")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 2, "the cap's rows are kept")
    Do $$$AssertEquals(tResult.truncated, 1, "and truncation is reported")
    Do $$$AssertEquals(tResult.rows.%Get(0).PID _ "," _ tResult.rows.%Get(1).PID, "101,102", "the first rows the vendor answered")

    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, 4, .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "a cap the member fits succeeds")
    If '$IsObject(tResult2) Quit
    Do $$$AssertEquals(tResult2.rows.%Size(), 4, "every row is kept")
    Do $$$AssertEquals(tResult2.truncated, 0, "and nothing is reported truncated")
}

/// <p>Any other answer fails the whole read as the generic internal fault with no result: an answer
/// that is not an object, a member that is absent, a member that is not an array, and an array
/// holding anything but objects.</p>
/// <p>Mutation: return the member without checking its elements in
/// <method>OcuPilot.Screen.Read.RowsMember</method> -&gt; the array-of-strings case reads 200 and
/// goes red.</p>
Method TestAMalformedAnswerFailsTheWholeRead()
{
    Set tClass = ..#PACKAGE _ "LicenseUserTab"
    Set tCases = $ListBuild($ListBuild("an array answer", "[]"), $ListBuild("an absent member", "{""Summary"": []}"), $ListBuild("a member that is an object", "{""UsageByUser"": {}}"), $ListBuild("a member that is a string", "{""UsageByUser"": ""none""}"), $ListBuild("an array of strings", "{""UsageByUser"": [""UnknownUser""]}"), $ListBuild("an array holding one object and one number", "{""UsageByUser"": [{""UserId"": ""a""}, 1]}"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tWhere = $List(tCase, 1) _ ": "
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", $List(tCase, 2), ..#LICENSEUSAGETYPE)
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ "the read fails")
        Do $$$AssertEquals(tHttp, 500, tWhere _ "at 500")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tWhere _ "as the generic internal fault")
        Do $$$AssertEquals(tResult, "", tWhere _ "with no partial result")
    }
}

/// <p>An empty member reads as no rows, not truncated, at 200 -- the By user tab's answer on an
/// instance serving only REST traffic.</p>
Method TestAnEmptyMemberReadsAsNoRows()
{
    Set tAnswer = ..Answer()
    Do tAnswer.%Set("UsageByUser", [])
    Do ..Arm(tAnswer)
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#PACKAGE _ "LicenseUserTab", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 0, "with no rows")
    Do $$$AssertEquals(tResult.truncated, 0, "and nothing truncated")
}

}
