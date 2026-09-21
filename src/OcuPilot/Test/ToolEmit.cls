/// <p>What a provider request advertises and what a tool is asked for (AD-5, AD-22, AD-24, AD-36,
/// AD-39; Conventions, Tool naming): every live tool's wire name, emitted schema, result schema and
/// description; the emission rule over a corpus of keywords; the read tools' row bounds and fault
/// pass-through over fixtures; and a sentence for every <code>TOOL.*</code> code.</p>
/// <p><b>Live-safe</b>: it runs no live tool. The row bounds run against
/// <class>OcuPilot.Test.PortFixture</class> and <class>OcuPilot.Test.ErrorReadStub</class>.</p>
Class OcuPilot.Test.ToolEmit Extends %UnitTest.TestCase
{

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

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
    Do ##class(OcuPilot.Test.ErrorReadStub).Clear()
    Do ##class(OcuPilot.Test.AdvertiseTool.Tool).SetMode("")
}

/// <p>Every live tool's canonical name holds no underscore, its wire name replaces each dot with an
/// underscore and matches the provider grammar, and no two tools share one; the three shell reads
/// are among the tools.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Registry.WireName</method> keeps the dots -> this goes
/// red.</p>
Method TestEveryLiveToolHasAReversibleWireName()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Kill tSeen
    Set tNames = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tWire = $ClassMethod(..#REGISTRY, "WireName", tTool.name)
        Set tNames = tNames _ $ListBuild(tTool.name)
        Do $$$AssertEquals(tTool.name [ "_", 0, tTool.name _ ": the canonical name holds no underscore, so the wire name is reversible")
        Do $$$AssertEquals(tWire, $Translate(tTool.name, ".", "_"), tTool.name _ ": the wire name is the name with each dot an underscore")
        Do $$$AssertTrue($Match(tWire, $Parameter(..#REGISTRY, "WIRENAMEPATTERN")), tTool.name _ ": '" _ tWire _ "' matches the provider's tool-name grammar")
        Do $$$AssertEquals($Data(tSeen(tWire)), 0, tTool.name _ ": no other tool has its wire name")
        Set tSeen(tWire) = ""
    }
    For tShell = "shell.instance.read", "shell.namespaces.read", "shell.privileges.read" {
        Do $$$AssertTrue($ListFind(tNames, tShell) > 0, tShell _ " is registered beside the per-screen read tools")
    }
}

/// <p>No two tools share a wire name -- two tool classes declaring the same canonical name refuse
/// the whole listing, naming both claimants, with nothing listed and nothing advertised; over
/// <class>OcuPilot.Test.ClashTool.Registry</class>.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Registry.Claim</method>'s duplicate-name check
/// removed -> this goes red.</p>
Method TestTwoToolsSharingANameRefuseTheWholeListing()
{
    Set tRegistry = "OcuPilot.Test.ClashTool.Registry"
    Set tSC = $ClassMethod(tRegistry, "ListTools", .tTools)
    Do $$$AssertStatusNotOK(tSC, "two tools claiming the same name refuse the listing")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText [ "OcuPilot.Test.ClashTool.First") && (tText [ "OcuPilot.Test.ClashTool.Second"), "naming both claimants: " _ tText)
    Do $$$AssertEquals(tTools, "", "and nothing is listed")
    Set tSC = $ClassMethod(tRegistry, "ProviderTools", .tAdvertised)
    Do $$$AssertStatusNotOK(tSC, "and nothing is advertised either")
    Do $$$AssertEquals(+$Get(tAdvertised), 0, "with a count of zero")
}

/// <p>Advertise -- the provider tool array holds every live tool in name order, each with its wire
/// name, a description, and a schema using only the emitted subset; a declared <code>maxLength</code>
/// is gone from the schema and stated in the property's description. A read tool's description
/// names its <code>toolIdentifier</code>.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method> leaves
/// <code>maxLength</code> in the schema -> this goes red.</p>
Method TestEveryLiveToolIsAdvertisedInTheSubset()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ProviderTools", .tAdvertised), "the tools are advertised")
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Do $$$AssertEquals(+$Get(tAdvertised), tTools.%Size(), "one advertised tool per live tool")
    Set tWithBound = 0
    For tI = 1:1:+$Get(tAdvertised) {
        Set tTool = tTools.%Get(tI - 1)
        Do $$$AssertEquals(tAdvertised(tI, "name"), $ClassMethod(..#REGISTRY, "WireName", tTool.name), "tool " _ tI _ " is " _ tTool.name _ ", in name order")
        Do $$$AssertTrue($ZStrip(tAdvertised(tI, "description"), "<>W") '= "", tTool.name _ ": a description is advertised")
        If tTool.descriptor '= "" Do $$$AssertTrue(tAdvertised(tI, "description") [ $ClassMethod(tTool.descriptor, "ToolIdentifier"), tTool.name _ ": the read tool's description names its screen")
        Set tJson = tAdvertised(tI, "inputSchema")
        Do $$$AssertEquals(tJson [ "maxLength", 0, tTool.name _ ": no maxLength keyword is advertised")
        Set tEmitted = ##class(%DynamicAbstractObject).%FromJSON(tJson)
        Do $$$AssertEquals(..SubsetProblem(tEmitted), "", tTool.name _ ": the schema uses only the emitted subset")
        Set tDeclared = $ClassMethod(..#REGISTRY, "InputSchemaOf", tTool)
        Set tIterator = tDeclared.properties.%GetIterator()
        While tIterator.%GetNext(.tKey, .tProperty) {
            If tProperty.%GetTypeOf("maxLength") '= "number" Continue
            Set tWithBound = tWithBound + 1
            Do $$$AssertTrue(tEmitted.properties.%Get(tKey).description [ ("At most " _ tProperty.maxLength _ " characters."), tTool.name _ "." _ tKey _ ": the bound is stated in the description")
        }
    }
    Do $$$AssertTrue(tWithBound > 0, "at least one live property declares a maxLength: " _ tWithBound)
}

/// <p>Every live tool declares a result schema the validator admits, closed at its top level.</p>
Method TestEveryLiveToolDeclaresAResultSchema()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tSchema = $ClassMethod(..#REGISTRY, "ResultSchemaOf", tTool)
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ValidateSchema", tSchema, .tProblem), tTool.name _ ": its result schema is admitted " _ tProblem)
        Do $$$AssertTrue($IsObject(tSchema) && (tSchema.type = "object") && (tSchema.required.%Size() > 0), tTool.name _ ": an object that requires its keys")
    }
}

/// <p>Advertise, refused -- a tool the provider could not take refuses the whole listing, with no tool
/// advertised: an input schema the validator admits and the emitted subset does not, no description,
/// or no result schema. The same tool declared well is advertised.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method> ignores
/// <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method>'s status -> the subset leg goes red.</p>
Method TestAToolTheProviderCannotTakeRefusesTheListing()
{
    Set tRegistry = "OcuPilot.Test.AdvertiseTool.Registry"
    Set tTool = "OcuPilot.Test.AdvertiseTool.Tool"
    For tCase = "subset|'description'", "nodescription|declares no description", "noresult|result schema" {
        Do $ClassMethod(tTool, "SetMode", $Piece(tCase, "|", 1))
        Set tSC = $ClassMethod(tRegistry, "ProviderTools", .tTools)
        Do $$$AssertStatusNotOK(tSC, $Piece(tCase, "|", 1) _ ": the listing is refused")
        Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ $Piece(tCase, "|", 2), $Piece(tCase, "|", 1) _ ": naming why: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals(+$Get(tTools) _ "|" _ $Data(tTools(1)), "0|0", $Piece(tCase, "|", 1) _ ": and nothing is advertised")
    }
    Do $ClassMethod(tTool, "SetMode", "")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tTools), "declared well, the tool is advertised")
    Do $$$AssertEquals(+$Get(tTools) _ "|" _ $Get(tTools(1, "name")), "1|probe_advertise_read", "under its wire name")
}

/// <p>Every live tool's privilege pairs are read, and are its screen's: a descriptor-derived read
/// tool's are its descriptor's, the application error tool's are its screen descriptor's, and a shell
/// read declares none (AD-8). The application error tool's arguments add the pairs its port requires
/// for the namespace they name, database pairs included -- this namespace's, and another namespace's
/// when a call names that one; no other live tool's arguments add any (AD-48).</p>
/// <p>Mutations: delete <method>OcuPilot.Screen.Tool.ErrorRead.PrivilegePairs</method> -> this goes
/// red. Delete <method>OcuPilot.Screen.Tool.ErrorRead.ArgumentPairs</method> -> this goes red.
/// <method>OcuPilot.Screen.Tool.ErrorRead.ArgumentPairs</method> resolves <code>$Namespace</code>
/// instead of the named namespace -> this goes red.</p>
Method TestEveryLiveToolRequiresItsScreensPairs()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tPairs = $ClassMethod(..#REGISTRY, "RequiredPairs", tTool, .tResolved)
        Do $$$AssertEquals(tResolved, 1, tTool.name _ ": its pairs are read")
        Set tArgs = {}
        If tTool.class = "OcuPilot.Screen.Tool.ErrorRead" Set tArgs = {"namespace": ($Namespace), "date": "09/16/2026"}
        Set tAdded = $ClassMethod(..#REGISTRY, "ArgumentPairs", tTool, tArgs, .tAddedResolved)
        Do $$$AssertEquals(tAddedResolved, 1, tTool.name _ ": the pairs its arguments add are read")
        Set tExpectedAdded = ""
        If tTool.descriptor '= "" {
            Set tExpected = ##class(OcuPilot.Screen.Gate).RequiredPairs(tTool.descriptor, .tExpectedResolved)
        } ElseIf tTool.class = "OcuPilot.Screen.Tool.ErrorRead" {
            Set tExpected = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tTool.class, "DESCRIPTORCLASS"), .tExpectedResolved)
            Do $$$AssertTrue($ListLength(tExpected) > 0, tTool.name _ ": its screen declares pairs")
            Set tExpectedAdded = ##class(OcuPilot.Port.LogSourcePort).PairsFor(##class(OcuPilot.Port.LogSourcePort).#ERRORSKEY, $Namespace)
            Do $$$AssertTrue(##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase($Namespace, .tResource, .tReadOnly) && $ListFind(tAdded, $ListBuild(tResource, "WRITE")), tTool.name _ ": its arguments add the named namespace's database pairs")
            Set tOther = ..OtherNamespace(tResource, .tOtherResource)
            Do $$$AssertTrue(tOther '= "", tTool.name _ ": this instance has a namespace whose globals database another resource guards")
            If tOther '= "" {
                Set tOtherAdded = $ClassMethod(..#REGISTRY, "ArgumentPairs", tTool, {"namespace": (tOther), "date": "09/16/2026"}, .tOtherResolved)
                Do $$$AssertTrue(tOtherResolved && $ListFind(tOtherAdded, $ListBuild(tOtherResource, "WRITE")) && '$ListFind(tOtherAdded, $ListBuild(tResource, "WRITE")), tTool.name _ ": a call naming " _ tOther _ " adds that namespace's database pairs, not this one's")
            }
        } ElseIf $ClassMethod(tTool.class, "%Extends", "OcuPilot.Screen.Tool.Write") {
            ; Story 5.1: a write tool is a class of its own, so its pairs are its descriptor's
            ; together with the pair the write itself names (AD-8). DW-1208: that pair is the one
            ; the vendor's own editor checks, which the screen already declares, so the set does
            ; not grow -- and the barrier a write crosses beyond a read is the confirm transition
            ; (AD-34, AD-40), never a privilege delta.
            Set tExpected = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tTool.class, "DESCRIPTORCLASS"), .tExpectedResolved)
            Do $$$AssertTrue($ListLength(tExpected) > 0, tTool.name _ ": its screen declares pairs")
            Set tOwnPair = $ListBuild($Parameter(tTool.class, "WRITERESOURCE"), $Parameter(tTool.class, "WRITEPERMISSION"))
            If '$ListFind(tExpected, tOwnPair) Set tExpected = tExpected _ $ListBuild(tOwnPair)
        } ElseIf $ClassMethod(tTool.class, "%Extends", "OcuPilot.Kernel.Shell.ReadTool") {
            Set tExpected = ""
        } ElseIf tTool.class = "OcuPilot.Screen.Tool.Navigate" {
            ; Story 4.7: no static requirement of its own -- the target screen's own pairs are
            ; what gate it, resolved per call in ArgumentPairs from the (untested-here) route
            ; argument. With no route in tArgs, DescriptorForRoute("") resolves to Home, whose
            ; own declared privileges are empty, so both sides of the comparison below are "".
            Set tExpected = ""
            Set tExpectedAdded = ##class(OcuPilot.Screen.Gate).RequiredPairs("OcuPilot.Screen.Descriptor.Home", .tExpectedAddedResolved)
            Do $$$AssertEquals(tExpectedAddedResolved, 1, tTool.name _ ": Home's own pairs resolve")
        } Else {
            Do $$$AssertTrue(0, tTool.name _ ": a live tool of a source this test does not know, " _ tTool.class)
            Continue
        }
        Do $$$AssertEquals(tPairs, tExpected, tTool.name _ ": requires exactly its screen's pairs, plus its own write permission where it has one")
        Do $$$AssertEquals(tAdded, tExpectedAdded, tTool.name _ ": and exactly the pairs its arguments add")
    }
}

/// <p>A namespace other than <code>$Namespace</code> whose globals database a resource other than
/// <var>pResource</var> guards, with that resource in <var>pOtherResource</var>, or <code>""</code>
/// when the instance has none.</p>
Method OtherNamespace(pResource As %String, Output pOtherResource As %String) As %String
{
    Set pOtherResource = ""
    If $$$ISERR(##class(OcuPilot.Kernel.Shell.Namespaces).NamespaceNames(.tNames)) Quit ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If ($Extract(tName) = "^") || (tName = $Namespace) Continue
        If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(tName, .tOtherResource, .tReadOnly) Continue
        If tOtherResource = pResource Continue
        Set pOtherResource = tOtherResource
        Quit
    }
    Quit $Select(pOtherResource '= "": tName, 1: "")
}

/// <p>The emission corpus -- each keyword outside the subset refuses a schema naming it, at the top
/// level and on a property; <code>maxLength</code> is moved into the description, on a property and
/// under <code>items</code>, and the declared schema is left unchanged.</p>
Method TestTheEmissionCorpus()
{
    For tKeyword = "pattern", "format", "default", "const", "minLength", "$ref", "oneOf", "anyOf", "allOf", "examples", "properties", "required", "additionalProperties" {
        Set tSchema = {"type": "object", "properties": {"x": {"type": "string"}}, "required": [], "additionalProperties": false}
        Do tSchema.properties.x.%Set(tKeyword, "v")
        Set tSC = $ClassMethod(..#REGISTRY, "EmitSchema", tSchema, .tEmitted, .tProblem)
        Do $$$AssertStatusNotOK(tSC, "property keyword '" _ tKeyword _ "' is refused")
        Do $$$AssertTrue(tProblem [ ("'" _ tKeyword _ "'"), "naming it: " _ tProblem)
    }
    For tKeyword = "description", "title", "$schema", "definitions" {
        Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
        Do tSchema.%Set(tKeyword, "v")
        Do $$$AssertStatusNotOK($ClassMethod(..#REGISTRY, "EmitSchema", tSchema, .tEmitted, .tProblem), "top-level keyword '" _ tKeyword _ "' is refused: " _ tProblem)
    }
    Do $$$AssertStatusNotOK($ClassMethod(..#REGISTRY, "EmitSchema", {"type": "object", "properties": {}, "required": []}, .tEmitted, .tProblem), "a top level that is not closed is refused")

    Set tSchema = {"type": "object", "properties": {"x": {"type": "string", "maxLength": 50, "description": "A name."}, "y": {"type": "string", "maxLength": 7}, "z": {"type": "array", "items": {"type": "string", "maxLength": 9}, "maxItems": 3}}, "required": ["x"], "additionalProperties": false}
    Set tBefore = tSchema.%ToJSON()
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "EmitSchema", tSchema, .tEmitted, .tProblem), "a schema declaring maxLength is emitted: " _ tProblem)
    If '$IsObject(tEmitted) Quit
    Do $$$AssertEquals(tEmitted.%ToJSON(), "{""type"":""object"",""properties"":{""x"":{""type"":""string"",""description"":""A name. At most 50 characters.""},""y"":{""type"":""string"",""description"":""At most 7 characters.""},""z"":{""type"":""array"",""items"":{""type"":""string"",""description"":""At most 9 characters.""},""maxItems"":3}},""required"":[""x""],""additionalProperties"":false}", "with every maxLength moved into its description")
    Do $$$AssertEquals(tSchema.%ToJSON(), tBefore, "and the declared schema is unchanged")
}

/// <p>Row cap (AD-36) -- the read tool asks its executor for the rows the screen reads, the smaller
/// of the model's <code>maxRows</code> and the read's own cap, so the port is asked for one row more
/// than that; the filter runs over those rows, and the result is then cut to the context cap. Over
/// eight rows under a context cap of three, a filter matching only the eighth row finds it.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Read.View</method> bounds the read by the context cap
/// -> this goes red.</p>
Method TestTheReadToolReadsTheScreensRowsThenNarrows()
{
    Set tCap = ##class(OcuPilot.Screen.Read).#DEFAULTMAXROWS
    For tCase = "500|501", "|" _ (tCap + 1), (tCap * 5) _ "|" _ (tCap + 1), "5|6" {
        Do ##class(OcuPilot.Test.EndpointFixture).Clear()
        Do ..ArmRows()
        Set tArgs = {}
        If $Piece(tCase, "|", 1) '= "" Do tArgs.%Set("maxRows", +$Piece(tCase, "|", 1), "number")
        Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, tArgs, 3, .tView, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tArgs.%ToJSON() _ ": the view runs")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("maxRows"), $Piece(tCase, "|", 2), tArgs.%ToJSON() _ ": the port is asked for " _ $Piece(tCase, "|", 2) _ " rows")
        Do $$$AssertTrue($IsObject(tView), tArgs.%ToJSON() _ ": the view answers a result")
        If $IsObject(tView) Do $$$AssertEquals(tView.rows.%Size() _ "|" _ tView.truncated, "3|1", tArgs.%ToJSON() _ ": and the result is cut to the context cap and marked")
    }
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"filter": "csp/h"}, 3, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the filtered view runs")
    Do $$$AssertTrue($IsObject(tView), "the filtered view answers a result")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.rows.%Size() _ "|" _ tView.rows.%Get(0).Name _ "|" _ tView.truncated, "1|/csp/h|0", "the filter finds the eighth row, past the context cap, and nothing was cut")
}

/// <p>Tool fault -- the read tool answers the executor's own HTTP status and fault, and a refused
/// argument is 400 <code>TOOL.ARGUMENTS</code> with the problem as detail.</p>
Method TestTheReadToolPassesItsExecutorsFault()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("notfound")
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {}, 200, .tView, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the view fails")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "404|PORT.NOTFOUND", "with the port's status and fault")
    Do $$$AssertEquals(tView, "", "and no result")

    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 0}, 200, .tView, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|TOOL.ARGUMENTS", "a refused argument is 400 TOOL.ARGUMENTS")
    Do $$$AssertTrue($IsObject(tFault) && $IsObject(tFault.detail) && (tFault.detail.problem [ "'maxRows'"), "with the problem as detail")
}

/// <p>Row cap and Tool fault (DW-298) -- the application error tool asks its port for the smaller of
/// the model's <code>maxRows</code> and the cap, and answers the port's own status and fault.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ErrorRead.View</method> passes the model's
/// <code>maxRows</code> -> this goes red.</p>
Method TestTheErrorToolClampsAndPassesItsPortsFault()
{
    Set tStub = "OcuPilot.Test.ErrorReadStub"
    For tCase = "500|200", "|200", "3|3" {
        Set tArgs = {"namespace": "USER", "date": "09/16/2026"}
        If $Piece(tCase, "|", 1) '= "" Do tArgs.%Set("maxRows", +$Piece(tCase, "|", 1), "number")
        Set tSC = $ClassMethod(tStub, "View", "", tArgs, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tArgs.%ToJSON() _ ": the view runs")
        Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "maxRows"), $Piece(tCase, "|", 2), tArgs.%ToJSON() _ ": the port is asked for " _ $Piece(tCase, "|", 2) _ " rows")
    }
    Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.truncated _ "|" _ tResult.rows.%Get(0).%IsDefined("username"), "3|1|0", "the port's rows, its truncation, and the summary fields only")

    Do $ClassMethod(tStub, "ArmFault", 403, "AUTH.NOPRIVILEGE", "{""failedPair"":""%DB_USER:READ""}")
    Set tSC = $ClassMethod(tStub, "View", "", {"namespace": "USER", "date": "09/16/2026"}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a refused port read fails the view")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.detail.failedPair, 1: ""), "403|AUTH.NOPRIVILEGE|%DB_USER:READ", "with the port's status, code and detail")
}

/// <p>Every <code>TOOL.*</code> code <class>OcuPilot.Api.Error</class> declares is in
/// <method>OcuPilot.Api.Error.ToolCodes</method> and carries a written sentence.</p>
Method TestEveryToolCodeHasASentence()
{
    Set tDeclared = ##class(OcuPilot.Api.Error).ToolCodes()
    Set tFound = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If $Extract(tName, 1, 4) '= "TOOL" Continue
        Set tFound = tFound + 1
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        Do $$$AssertTrue($ListFind(tDeclared, tCode) > 0, tName _ " is in ToolCodes()")
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForTool(tCode), "", tName _ " has a written sentence")
    }
    Do $$$AssertEquals(tFound, 5, "the vocabulary declares five tool codes")
    Do $$$AssertEquals($ListLength(tDeclared), tFound, "and ToolCodes() holds no code the class does not declare")
}

/// <p>What in <var>pSchema</var> steps outside the emitted subset, or <code>""</code>.</p>
ClassMethod SubsetProblem(pSchema As %DynamicObject) As %String
{
    Set tTop = $ListFromString($Parameter(..#REGISTRY, "EMITTEDTOPKEYWORDS"))
    Set tProblem = ""
    Set tIterator = pSchema.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tTop, tKey) Set tProblem = "top-level " _ tKey
    }
    If tProblem '= "" Quit tProblem
    Set tIterator = pSchema.properties.%GetIterator()
    While tIterator.%GetNext(.tKey, .tProperty) {
        Set tProblem = ..PropertyProblem(tProperty, tKey)
        If tProblem '= "" Quit
    }
    Quit tProblem
}

ClassMethod PropertyProblem(pProperty As %DynamicObject, pPath As %String) As %String
{
    Set tAllowed = $ListFromString($Parameter(..#REGISTRY, "EMITTEDKEYWORDS"))
    Set tProblem = ""
    Set tIterator = pProperty.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tAllowed, tKey) Set tProblem = pPath _ "." _ tKey
    }
    If (tProblem = "") && $IsObject(pProperty.%Get("items")) Set tProblem = ..PropertyProblem(pProperty.%Get("items"), pPath _ ".items")
    Quit tProblem
}

/// <p>Arm eight canned rows for <parameter>CANNED</parameter>'s read.</p>
ClassMethod ArmRows()
{
    Set tRows = []
    For tName = "/csp/a", "/csp/b", "/csp/c", "/csp/d", "/csp/e", "/csp/f", "/csp/g", "/csp/h" {
        Do tRows.%Push({"Name": (tName), "NameSpace": "USER", "Enabled": true, "Secret": "s"})
    }
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows(tRows.%ToJSON())
}

}
