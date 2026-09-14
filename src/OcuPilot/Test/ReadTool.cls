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
/// readless descriptor yields none, and a concrete tool two levels down is found with its
/// inherited kind.</p>
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
    Do $$$AssertEquals(tProduction.%Size(), 0, "and holds no tool, fixtures excluded, since no production descriptor declares a read yet")
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
/// the route's minus the secret field, and its rows are the first three of the view rule over the
/// route's rows with the secret field removed. The filter keeps four of the route's five rows, so
/// the cap is what cuts.</p>
/// <p>Mutation: project <code>context.fields</code> instead of the read's fields in
/// <method>OcuPilot.Screen.Tool.Read.View</method> -> the field and row assertions go red.</p>
Method TestTheToolViewIsTheRouteReadNarrowed()
{
    Do ..ArmRows()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
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

    Set tExpectedFields = []
    Set tIterator = tRoute.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If tField '= "Secret" Do tExpectedFields.%Push(tField)
    }
    Do $$$AssertEquals(tView.fields.%ToJSON(), tExpectedFields.%ToJSON(), "the tool's fields are the route's minus Secret")

    Set tNarrowed = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(..#CANNED, "Read"), "CSP/B", "Name", "desc")
    Do $$$AssertEquals(tNarrowed.%Size(), 4, "the view rule leaves four of the five rows, more than the cap")
    Set tExpectedRows = []
    For tI = 0:1:2 {
        Set tRow = tNarrowed.%Get(tI)
        Do tRow.%Remove("Secret")
        Do tExpectedRows.%Push(tRow)
    }
    Do $$$AssertEquals(tView.rows.%ToJSON(), tExpectedRows.%ToJSON(), "its rows are the first three of the view rule over the route's rows, Secret removed")
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
    Do tCase.%Set("toolIdentifier", "security.ssl.detail")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "security.ssl.detail", "a three-segment tool identifier with a read is refused")

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
    Do tCase.%Set("read", "WebApp.App")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read is a string", "a read that is not an object is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "", "null")
    Do tCase.%Set("toolIdentifier", "security.ssl.detail")
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
