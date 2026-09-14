/// <p>The tool registry's discovery and validation half and the read tool's view (AD-5, AD-22,
/// AD-36): which tools a registry lists and of which kind, the kind refusal, the argument
/// validator's rows, the view's cap and secret stripping, the read declaration's refusals, and
/// the absence of any dispatch method.</p>
/// <p>Tools come from <class>OcuPilot.Test.Read.ToolRegistry</class>; canned rows from
/// <class>OcuPilot.Test.EndpointFixture</class> through <class>OcuPilot.Test.PortFixture</class>;
/// the route rows the view is compared with through <class>OcuPilot.Test.Dispatch</class> with
/// <class>OcuPilot.Test.ScreenGate</class>'s declared privileges. Reads only.</p>
Class OcuPilot.Test.ReadTool Extends %UnitTest.TestCase
{

/// <p>The canned read-declaring descriptor.</p>
Parameter CANNED = "OcuPilot.Test.Read.Canned";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>AC3 -- each read-declaring descriptor yields exactly one tool
/// <code>&lt;toolIdentifier&gt;.read</code> of kind <code>read</code> with no class of its own, a
/// readless descriptor yields none, a concrete tool two levels down is found with its
/// inherited kind, and the production registry holds exactly <code>permissions.users.read</code>,
/// <code>security.ssl.read</code>, <code>tasks.schedule.read</code> and
/// <code>webapp.list.read</code>.</p>
/// <p>Mutations: name the read tool from <method>OcuPilot.Screen.Descriptor.Base.Route</method>
/// in <method>OcuPilot.Screen.Tool.Read.NameFor</method> -> the name assertions go red. Replace
/// <code>%Extends</code> with superclass equality in
/// <method>OcuPilot.Screen.Tool.Registry.ToolClasses</method> -> the <code>Leaf</code> assertions
/// go red.</p>
Method TestTheRegistryListsDescriptorReadsAndInheritedKinds()
{
    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the fixture tools list")
    Kill tByName
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tByName(tTool.name) = tTool
    }
    Do $$$AssertEquals(tTools.%Size(), 3, "two read tools and one class tool")

    For tPair = $ListBuild("webapp.canned.read", ..#CANNED), $ListBuild("webapp.probe.read", "OcuPilot.Test.Read.WebApps") {
        Set tName = $List(tPair, 1)
        Do $$$AssertTrue($Data(tByName(tName)), tName _ " is registered")
        If '$Data(tByName(tName)) Continue
        Do $$$AssertEquals(tByName(tName).kind, "read", tName _ " is of kind read")
        Do $$$AssertEquals(tByName(tName).descriptor, $List(tPair, 2), tName _ " is derived from its descriptor")
        Do $$$AssertEquals(tByName(tName).class, "OcuPilot.Test.Read.ToolFixture", tName _ " is answered by the one read tool class, not a class of its own")
    }
    Do $$$AssertEquals($Data(tByName("webapp.readless.read")), 0, "a descriptor with no read yields no tool")

    Do $$$AssertTrue($Data(tByName("test.leaf.write")), "a concrete tool below an abstract middle class is found")
    If $Data(tByName("test.leaf.write")) {
        Do $$$AssertEquals(tByName("test.leaf.write").kind, "write", "with the kind it inherits")
        Do $$$AssertEquals(tByName("test.leaf.write").class, "OcuPilot.Test.Read.Tool.Leaf", "and its own class")
    }

    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.canned.read", .tResolved)
    Do $$$AssertStatusOK(tSC, "resolution runs")
    Do $$$AssertTrue($IsObject(tResolved) && (tResolved.descriptor = ..#CANNED), "a listed name resolves to its entry")
    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.nosuch.read", .tMissing)
    Do $$$AssertEquals(tMissing, "", "an unlisted name resolves to nothing")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tProduction)
    Do $$$AssertStatusOK(tSC, "the production registry lists")
    Kill tProductionByName
    Set tIterator = tProduction.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tProductionByName(tTool.name) = tTool
    }
    Set tNames = ""
    Set tName = $Order(tProductionByName(""))
    While tName '= "" {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        Set tName = $Order(tProductionByName(tName))
    }
    Do $$$AssertEquals(tProduction.%Size(), 4, "the production registry holds four tools, fixtures excluded")
    Do $$$AssertEquals(tNames, "permissions.users.read,security.ssl.read,tasks.schedule.read,webapp.list.read", "the users, SSL/TLS, task schedule and web applications lists' read tools")
    For tPair = $ListBuild("permissions.users.read", "OcuPilot.Screen.Descriptor.UserList"), $ListBuild("security.ssl.read", "OcuPilot.Screen.Descriptor.SslConfigList"), $ListBuild("tasks.schedule.read", "OcuPilot.Screen.Descriptor.TaskScheduleList"), $ListBuild("webapp.list.read", "OcuPilot.Screen.Descriptor.WebAppList") {
        Set tName = $List(tPair, 1)
        If '$Data(tProductionByName(tName)) Continue
        Do $$$AssertEquals(tProductionByName(tName).kind, "read", tName _ " is of kind read")
        Do $$$AssertEquals(tProductionByName(tName).descriptor, $List(tPair, 2), tName _ " is derived from its descriptor")
        Do $$$AssertEquals(tProductionByName(tName).class, "OcuPilot.Screen.Tool.Read", tName _ " is answered by the one read tool class")
    }
}

/// <p>Story 2.6 AC5 -- every case in <class>OcuPilot.Test.RowGetCorpus</class> gets its exact
/// sentence, or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>; and the users
/// list's own detail call passes.</p>
/// <p>Mutation: accept any <code>rule</code> in
/// <method>OcuPilot.Screen.Registry.RowGetProblem</method> -> the <code>afterToday</code> case goes
/// red.</p>
Method TestEveryRowGetCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.RowGetCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Set tDeclaration = ##class(OcuPilot.Test.RowGetCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Set tSC = ##class(OcuPilot.Screen.Descriptor.UserList).DeclarationJson(.tUsers)
    Do $$$AssertStatusOK(tSC, "the users list's declaration reads")
    If $$$ISOK(tSC) Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tUsers), "", "and its detail call passes")
}

/// <p>Story 2.7 AC5 (DW-264) -- every case in <class>OcuPilot.Test.AdminPairCorpus</class> gets its
/// exact sentence, or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same
/// corpus <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>; and
/// the three shipped admin-port lists pass.</p>
/// <p>Mutation: make the admin-port arm of <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// unreachable -> every refusing case goes red, while the shipped roster stays green either way.</p>
Method TestEveryAdminPairCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.AdminPairCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.AdminPairCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    For tClass = "OcuPilot.Screen.Descriptor.SslConfigList", "OcuPilot.Screen.Descriptor.TaskScheduleList", "OcuPilot.Screen.Descriptor.UserList", "OcuPilot.Screen.Descriptor.WebAppList" {
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tShipped), "", tClass _ ": its read declares the system database read")
    }
}

/// <p>Story 2.8 -- every case in <class>OcuPilot.Test.BannerCorpus</class> gets its exact sentence,
/// or none, from <method>OcuPilot.Screen.Registry.BannerProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>bannerProblem</code>; and every
/// shipped descriptor's banner, the one that declares a banner included, passes.</p>
/// <p>Mutation: admit any <code>severity</code> in
/// <method>OcuPilot.Screen.Registry.BannerProblem</method> -> the two severity cases go red.</p>
Method TestEveryBannerCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.BannerCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.BannerCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tShippedList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tWithBanner = 0
    For tI = 1:1:$ListLength(tShippedList) {
        Set tClass = $List(tShippedList, tI)
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tShipped), "", tClass _ ": its banner is the declared grammar")
        If $IsObject($ClassMethod(tClass, "Banner")) Set tWithBanner = tWithBanner + 1
    }
    Do $$$AssertEquals(tWithBanner, 1, "exactly one shipped descriptor declares a banner, and it is the task schedule's")
}

/// <p>AC4's instance half -- <method>OcuPilot.Screen.Tool.Registry.KindProblem</method> admits
/// <code>read</code> and <code>write</code> and refuses everything else, the empty kind a class
/// declaring neither inherits from <class>OcuPilot.Screen.Tool.Base</class> included.</p>
Method TestAKindThatIsNeitherReadNorWriteIsRefused()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", "read"), "", "read is a kind")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", "write"), "", "and so is write")
    For tBad = "", "Read", "reads", "read,write" {
        Set tProblem = ##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", tBad)
        Do $$$AssertTrue(tProblem [ "X.Tool", "kind '" _ tBad _ "' is refused naming the class")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.Base", "KIND"), "", "the base declares no kind")
    Do $$$AssertEquals($Parameter("OcuPilot.Test.Read.Tool.Leaf", "KIND"), "write", "and a subclass reads the nearest declared one")
}

/// <p>AC6 -- every tool-argument matrix row is refused naming the argument and the rule, and a
/// schema outside the subset is refused before any argument is read.</p>
/// <p>Mutation: drop the <code>additionalProperties</code> refusal from
/// <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method>'s object check -> the
/// <code>extra</code> row goes red.</p>
Method TestTheValidatorRefusesEveryArgumentRow()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(..#CANNED)
    Do $$$AssertTrue($IsObject(tSchema), "the canned read has a schema")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"maxRows": 5, "sort": "NameSpace", "direction": "desc", "filter": "csp"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "sound arguments pass")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {}, .tProblem)
    Do $$$AssertStatusOK(tSC, "no arguments pass, since none is required")

    Set tRows = $ListBuild(
        $ListBuild("{""maxRows"": ""5""}", "maxRows", "(type)"),
        $ListBuild("{""sort"": ""Enabled""}", "sort", "(enum)"),
        $ListBuild("{""direction"": ""up""}", "direction", "(enum)"),
        $ListBuild("{""extra"": 1}", "extra", "(additionalProperties: false)"),
        $ListBuild("{""maxRows"": 0}", "maxRows", "(minimum)"),
        $ListBuild("{""maxRows"": 2.5}", "maxRows", "(type)"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tRow, 1))
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tArgs, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tRow, 1) _ " is refused")
        Do $$$AssertTrue((tProblem [ ("'" _ $List(tRow, 2) _ "'")) && (tProblem [ $List(tRow, 3)), $List(tRow, 1) _ " names the argument and the rule: " _ tProblem)
    }

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"x": {"type": "string", "pattern": "^a"}}, "additionalProperties": false}, {"x": "a"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a schema using a keyword outside the subset is refused")
    Do $$$AssertTrue(tProblem [ "pattern", "naming the keyword")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {}}, {}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a top level not closed by additionalProperties: false is refused")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"n": {"type": "array", "items": {"type": "integer", "maximum": 3}, "minItems": 1, "maxItems": 2}}, "required": ["n"], "additionalProperties": false}, {"n": [1, 4]}, .tProblem)
    Do $$$AssertTrue(tProblem [ "(maximum)", "items are validated against their own schema: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"n": {"type": "array", "maxItems": 1}}, "required": ["n"], "additionalProperties": false}, {}, .tProblem)
    Do $$$AssertTrue(tProblem [ "(required)", "a required argument that is absent is refused: " _ tProblem)

    Set tSchema = {"type": "object", "properties": {"s": {"type": "string"}, "n": {"type": "number"}, "b": {"type": "boolean"}, "a": {"type": "array", "minItems": 1, "maxItems": 2}, "o": {"type": "object", "properties": {"x": {"type": "integer"}}, "additionalProperties": false}}, "additionalProperties": false}
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"s": "t", "n": 0.5, "b": false, "a": [1], "o": {"x": 2}}, .tProblem)
    Do $$$AssertStatusOK(tSC, "a value of every admitted type passes: " _ tProblem)
    Set tRows = $ListBuild(
        $ListBuild("{""s"": 1}", "s", "(type)"),
        $ListBuild("{""n"": ""1""}", "n", "(type)"),
        $ListBuild("{""b"": 0}", "b", "(type)"),
        $ListBuild("{""a"": {}}", "a", "(type)"),
        $ListBuild("{""o"": []}", "o", "(type)"),
        $ListBuild("{""a"": []}", "a", "(minItems)"),
        $ListBuild("{""a"": [1, 2, 3]}", "a", "(maxItems)"),
        $ListBuild("{""o"": {""x"": ""2""}}", "o.x", "(type)"),
        $ListBuild("{""o"": {""y"": 1}}", "o.y", "(additionalProperties: false)"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, ##class(%DynamicObject).%FromJSON($List(tRow, 1)), .tProblem)
        Do $$$AssertTrue((tProblem [ ("'" _ $List(tRow, 2) _ "'")) && (tProblem [ $List(tRow, 3)), $List(tRow, 1) _ " names the argument and the rule: " _ tProblem)
    }
}

/// <p>AC6 -- neither the tool base nor the registry compiles a method that dispatches.</p>
Method TestNothingHereDispatches()
{
    For tClass = "OcuPilot.Screen.Tool.Base", "OcuPilot.Screen.Tool.Read", "OcuPilot.Screen.Tool.Registry" {
        For tMethod = "Dispatch", "Invoke" {
            Do $$$AssertEquals(##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||" _ tMethod), 0, tClass _ " compiles no " _ tMethod)
        }
    }
}

/// <p>AC1 -- at <code>maxRows</code> 5, the tool's view is the route's read narrowed: its fields are
/// the route's, and its rows are the first three of the view rule over the route's rows. Neither
/// carries the secret field, which the one executor strips. The filter keeps four of the route's
/// five rows, so the cap is what cuts.</p>
/// <p>Mutation: keep the first <var>pContextCap</var> of the fetched rows rather than of the view in
/// <method>OcuPilot.Screen.Tool.Read.View</method> -> the row assertion goes red.</p>
Method TestTheToolViewIsTheRouteReadNarrowed()
{
    Do ..ArmRows()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", {"maxRows": "5"}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the route dispatches")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tRoute = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRoute.rows.%Size(), 5, "the route answers five rows")

    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.canned.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool resolves")
    Set tArgs = {"maxRows": 5, "filter": "CSP/B", "sort": "Name", "direction": "desc"}
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, tArgs, 3, .tView)
    Do $$$AssertStatusOK(tSC, "the tool view runs")

    Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), "the tool's fields are the route's")
    Do $$$AssertEquals(tView.fields.%ToJSON(), "[""Name"",""NameSpace"",""Enabled""]", "and neither carries Secret")

    Set tNarrowed = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(..#CANNED, "Read"), "CSP/B", "Name", "desc")
    Do $$$AssertEquals(tNarrowed.%Size(), 4, "the view rule leaves four of the five rows, more than the cap")
    Set tExpectedRows = []
    For tI = 0:1:2 {
        Do tExpectedRows.%Push(tNarrowed.%Get(tI))
    }
    Do $$$AssertEquals(tView.rows.%ToJSON(), tExpectedRows.%ToJSON(), "its rows are the first three of the view rule over the route's rows")
    Do $$$AssertEquals(tView.truncated, 1, "and truncation is reported")
    Do $$$AssertEquals((tView.%ToJSON() [ "secret"), 0, "no secret value reaches the tool")
}

/// <p>Every tool-argument matrix row, run through the view, is refused naming the argument and
/// reaches no port.</p>
Method TestARefusedArgumentReachesNoPort()
{
    Set tRows = $ListBuild(
        $ListBuild("{""maxRows"": ""5""}", "maxRows"),
        $ListBuild("{""sort"": ""Enabled""}", "sort"),
        $ListBuild("{""direction"": ""up""}", "direction"),
        $ListBuild("{""extra"": 1}", "extra"),
        $ListBuild("{""maxRows"": 0}", "maxRows"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Do ##class(OcuPilot.Test.EndpointFixture).Clear()
        Do ..ArmRows()
        Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, ##class(%DynamicObject).%FromJSON($List(tRow, 1)), 3, .tView)
        Do $$$AssertStatusNotOK(tSC, $List(tRow, 1) _ ": the view is refused")
        Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ ("'" _ $List(tRow, 2) _ "'"), $List(tRow, 1) _ ": naming the argument")
        Do $$$AssertEquals(tView, "", $List(tRow, 1) _ ": with no result")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", $List(tRow, 1) _ ": and the port was not called")
    }
}

/// <p>A read truncated by its own cap is truncated in the tool's view even when the context cap
/// cuts nothing.</p>
Method TestAFetchTruncationSurvivesTheView()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 2}, 50, .tView)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(tView.rows.%Size(), 2, "two rows")
    Do $$$AssertEquals(tView.truncated, 1, "reported truncated because the read was")
}

/// <p>A read its own cap does not cut is truncated in the tool's view when the context cap cuts it.</p>
/// <p>Mutation: drop the context-cap half of <code>truncated</code> in
/// <method>OcuPilot.Screen.Tool.Read.View</method> -> the truncation assertion goes red.</p>
Method TestAContextCapCutAloneIsTruncated()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 50}, 3, .tView)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(tView.rows.%Size(), 3, "the context cap keeps three of the eight rows")
    Do $$$AssertEquals(tView.truncated, 1, "reported truncated although the read was not")
}

/// <p>A view that neither the read's cap nor the context cap cuts is not truncated.</p>
Method TestAViewNothingCutsIsNotTruncated()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 50}, 50, .tView)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(tView.rows.%Size(), 8, "every row")
    Do $$$AssertEquals(tView.%GetTypeOf("truncated"), "boolean", "truncated is a boolean")
    Do $$$AssertEquals(tView.truncated, 0, "and it is false")
}

/// <p>Story 2.8 -- the read tool's payload is <code>{fields, rows, truncated}</code> and carries no
/// <code>banner</code>. A banner is screen chrome rather than rows, so it rides in the screen read's
/// own response and never reaches the tool's view (AD-36) -- the claim
/// <class>OcuPilot.Screen.Descriptor.Base</class>, <class>OcuPilot.Screen.Read</class> and
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> each state in prose.</p>
/// <p>It holds because <method>OcuPilot.Screen.Tool.Read.View</method> builds its answer key by key
/// rather than returning the read's, so this is the assertion that keeps the prose true: the
/// descriptor under test is the one shipped descriptor that declares a banner, and its screen read
/// does carry the key.</p>
/// <p>Mutation: carry the read's <code>banner</code> into the payload
/// <method>OcuPilot.Screen.Tool.Read.View</method> builds -> the absence assertion goes red.</p>
Method TestTheToolPayloadCarriesNoBanner()
{
    Set tClass = "OcuPilot.Screen.Descriptor.TaskScheduleList"
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, {"maxRows": 5}, 5, .tView)
    Do $$$AssertStatusOK(tSC, "the task schedule's tool view runs")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.%GetTypeOf("banner"), "unassigned", "the tool payload carries no banner key")
    Do $$$AssertTrue(tView.rows.%Size() > 0, "while it does carry rows: " _ tView.rows.%Size())

    ; The same descriptor's screen read does carry it, so the absence above is the tool's rule and
    ; not an accident of a descriptor that declares no banner.
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 5, .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and its screen read runs")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.%GetTypeOf("banner"), "string", "carrying the banner key the tool drops")
}

/// <p>Matrix row "Declaration" -- a filter field outside the fields, a secret field in the sort
/// fields, cursor paging, and a three-segment tool identifier are each refused; and a roster
/// carrying one is refused naming the class, as is a roster in which two descriptors declare one
/// tool identifier.</p>
Method TestAReadDeclarationOutsideTheGrammarIsRefused()
{
    Set tSC = $ClassMethod(..#CANNED, "DeclarationJson", .tSound)
    Do $$$AssertStatusOK(tSC, "the canned declaration reads")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tSound), "", "the canned read is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.filter.%Push("Missing")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "Missing", "a filter field outside fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.fields.%Push("Secret")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "secret field 'Secret'", "a secret field in sort.fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("paging", "cursor")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "cursor", "cursor paging is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("toolIdentifier", "security.nosuch.detail")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "security.nosuch.detail", "a three-segment tool identifier with a read is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("default", "Enabled")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a sort default outside sort.fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.fields.%Push("Name")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a repeated field is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("port", "monitor")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a port other than admin is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.filter.%Push("Secret")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.filter names the secret field 'Secret'", "a secret field in filter is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("direction", "up")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "direction 'up'", "a sort direction other than asc or desc is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("type", "GET")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "type 'GET'", "a source type other than LIST is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("fields", [])
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.fields is empty", "empty fields are refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.secretFields.%Push("Other")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context.secretFields names 'Other'", "a secret field outside fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.%Set("secretfields", tCase.context.secretFields)
    Do tCase.context.%Remove("secretFields")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context declares the unknown key 'secretfields'", "a misspelt secretFields is refused, not read as no secret field")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.%Remove("secretFields")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context.secretFields is not an array", "an undeclared secretFields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Remove("context")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context is not an object", "a read with no context is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("secretFields", ["Secret"])
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read declares the unknown key 'secretFields'", "an unknown key in read is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("maxRows", 5)
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.source declares the unknown key 'maxRows'", "an unknown key in read.source is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("dir", "asc")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.sort declares the unknown key 'dir'", "an unknown key in read.sort is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "WebApp.App")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read is a string", "a read that is not an object is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "", "null")
    Do tCase.%Set("table", "", "null")
    Do tCase.%Set("toolIdentifier", "security.nosuch.detail")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a null read is a screen with no read, whatever its identifier")

    Set tSC = ##class(OcuPilot.Test.ReadBadRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying cursor paging is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.ReadBad.Cursor", "naming the class")
    Set tSC = ##class(OcuPilot.Test.Read.Registry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "while the read fixtures' roster is sound")

    Set tSC = ##class(OcuPilot.Test.ReadTwinRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster in which two descriptors declare one tool identifier is refused")
    Do $$$AssertTrue((tProblem [ "OcuPilot.Test.ReadTwin.One") && (tProblem [ "OcuPilot.Test.ReadTwin.Two") && (tProblem [ "webapp.twin"), "naming both classes and the identifier: " _ tProblem)
    Set tSC = ##class(OcuPilot.Test.ReadTwinToolRegistry).ListTools(.tTools)
    Do $$$AssertStatusNotOK(tSC, "the tool registry refuses the read tool name the two claim")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "webapp.twin.read", "naming the tool")
    Do $$$AssertEquals(tTools, "", "and lists nothing")
}

/// <p>Matrix row "Grammar" -- a read with no table, a column field outside the read's fields, two
/// name columns, an unknown kind, an <code>emptyNextKey</code> on a write-capable descriptor and a
/// composite id part outside the fields are each refused, as are a table with no read, an unknown
/// table key and an empty <code>emptyStateKey</code>; the agent key on a write-capable descriptor
/// is sound.</p>
/// <p>Mutation: drop the exactly-one-name check from
/// <method>OcuPilot.Screen.Registry.TableProblem</method> -> the two-name-columns assertion goes
/// red.</p>
Method TestATableOutsideTheGrammarIsRefused()
{
    Set tSC = $ClassMethod(..#CANNED, "DeclarationJson", .tSound)
    Do $$$AssertStatusOK(tSC, "the canned declaration reads")
    Set tRegistry = "OcuPilot.Screen.Registry"
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tSound), "", "the canned table is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Remove("table")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table is not an object", "a read with no table is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("field", "Missing")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "field 'Missing' is not one of read.fields", "a column field outside the read's fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(1).%Set("kind", "name")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "2 name column(s)", "two name columns are refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("kind", "identifier")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "0 name column(s)", "no name column is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(2).%Set("kind", "boolean")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "kind 'boolean'", "an unknown kind is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Push({"field": "Name", "labelKey": "fieldUserName", "kind": "text"})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "names the field 'Name' twice", "a field shown twice is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Push({"field": "Secret", "labelKey": "fieldUserName", "kind": "text"})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "field 'Secret' is a secret field", "a column over a secret field is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("rowActions", [{"id": "disable", "selfProtection": ""}])
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyNextKey is declared on a write-capable descriptor", "emptyNextKey on a write-capable descriptor is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("primaryAction", {"id": "create", "selfProtection": ""})
    Do tCase.table.%Set("emptyNextKey", "")
    Do tCase.table.%Set("emptyAgentKey", "classicLinkCardCaption")
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tCase), "", "the agent key on a write-capable descriptor is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("emptyAgentKey", "classicLinkCardCaption")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyAgentKey is declared on a descriptor with no primary or row action", "emptyAgentKey on a read-only descriptor is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("primaryAction", {"id": "create", "selfProtection": ""})
    Do tCase.table.%Set("emptyNextKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyAgentKey is empty on a write-capable descriptor", "a write-capable descriptor with no agent key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("emptyNextKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyNextKey is empty", "a read-only descriptor with no next-step key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("labelKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "labelKey is empty", "an empty column label key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("columns", [])
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.columns is empty", "a table with no column is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("width", 3)
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "declares the unknown key 'width'", "an unknown column key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("id", {"kind": "composite", "parts": ["NameSpace", "Path"]})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "id.parts names 'Path'", "a composite part outside the read's fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("id", {"kind": "composite", "parts": ["NameSpace", "Name"]})
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tCase), "", "a composite id over declared fields is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("emptyStateKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "emptyStateKey is empty", "an empty emptyStateKey is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("sort", "Name")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table declares the unknown key 'sort'", "an unknown table key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "", "null")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table is declared while read is not", "a table with no read is refused")
}

/// <p>A copy of <var>pDeclaration</var> to mutate.</p>
ClassMethod Mutated(pDeclaration As %DynamicObject) As %DynamicObject
{
    Quit ##class(%DynamicObject).%FromJSON(pDeclaration.%ToJSON())
}

/// <p>Arm eight canned rows whose names sort and filter distinctly, each with a secret value.</p>
ClassMethod ArmRows()
{
    Set tRows = []
    For tName = "/csp/b1", "/csp/a1", "/csp/b3", "/CSP/b2", "/csp/B5", "/csp/c1", "/csp/b4", "/other/b6" {
        Do tRows.%Push({"Name": (tName), "NameSpace": "USER", "Enabled": true, "Secret": ("secret-" _ tName)})
    }
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows(tRows.%ToJSON())
}

}
