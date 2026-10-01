/// <p>Pins Story 16.10's External language servers list, its Activity log and the start and stop
/// tools (AD-5, AD-8, AD-10, AD-36, AD-39, AD-51, AD-53): what the two descriptors declare, the
/// list's Running values over the instance's own servers, the <code>ACTIVITY</code> detail call's
/// <code>maxRows</code> 1, the Activity log's rows and fields and its refusal of a missing name, the
/// tools' registration, <method>OcuPilot.Screen.Tool.LanguageServerStart.StateDiff</method>'s two
/// refusals and its rows, the port's published answer to a refused start, and the prohibited set's
/// coverage of the new type.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%All</code>. It reads the instance's own language servers and changes none: every armed
/// answer goes through <class>OcuPilot.Test.LanguageServerEndpoint</class>. One run at a time.</p>
Class OcuPilot.Test.LanguageServer Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter ACTIVITY = "OcuPilot.Screen.Descriptor.LanguageServerActivity";

Parameter START = "OcuPilot.Screen.Tool.LanguageServerStart";

Parameter STOP = "OcuPilot.Screen.Tool.LanguageServerStop";

Parameter ENDPOINT = "OcuPilot.Test.LanguageServerEndpoint";

Parameter READER = "OcuPilot.Test.Read.ReadFixture";

/// <p>The own pair both screens declare beside the area's database read.</p>
Parameter OWNPAIR = "%Admin_ExternalLanguageServerEdit:USE";

/// <p>The three sentences EXPERIENCE.md's Fixed strings publish.</p>
Parameter RUNNING = "This server is already running.";

Parameter STOPPED = "This server is not running.";

Parameter STARTFAILED = "The server did not start. Its activity log records why.";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>AD-5, AD-8: the list is OS management's ninth entry over <code>LanguageServer</code>
/// <code>LIST</code> with an <code>ACTIVITY</code> detail call; the Activity log is its unlisted,
/// parent-scoped log viewer reading <code>ACTIVITY</code> over <code>Activity</code>; both declare
/// <code>%Admin_ExternalLanguageServerEdit:USE</code> as their own pair beside the database read,
/// and both read tools are registered.</p>
/// <p>Mutation (Rule 19): drop <code>ownPrivileges</code> from the list's descriptor -- the registry
/// refuses the area coverage and the own-pair legs go red.</p>
Method TestTheDescriptorsRegister()
{
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tList)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    Set tSC = $ClassMethod(..#ACTIVITY, "DeclarationJson", .tLog)
    Do $$$AssertStatusOK(tSC, "the Activity log's declaration parses")
    If '$IsObject($Get(tList)) || '$IsObject($Get(tLog)) Quit
    Do $$$AssertEquals(tList.route _ " " _ tList.area _ " " _ tList.sideBarPosition _ " " _ tList.archetype _ " " _ tList.toolIdentifier, "os-management/language-servers os-management 10 list osmgmt.languageservers", "the tenth OS management entry, a list read as osmgmt.languageservers")
    Do $$$AssertEquals(tList.entityType _ " " _ tList.scope _ " " _ tList.id.kind _ " " _ tList.refreshes, "language-server instance single 0", "an instance-scoped language server keyed by its name, with no auto-refresh")
    Do $$$AssertEquals(tList.rowActions.%ToJSON(), "[{""id"":""start"",""selfProtection"":""""},{""id"":""stop"",""selfProtection"":""""},{""id"":""delete"",""selfProtection"":""""}]", "three row actions, Story 16.25's delete last, none self-protected")
    Do $$$AssertEquals(tList.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""LanguageServer"",""type"":""LIST"",""rowGet"":{""key"":""Name"",""param"":""name"",""type"":""ACTIVITY"",""fields"":[""CurrentlyRunning""],""derived"":[]}}", "the vendor's list, with an ACTIVITY detail call merging CurrentlyRunning")
    Do $$$AssertEquals(tList.read.fields.%ToJSON() _ " " _ tList.context.fields.%ToJSON(), "[""Name"",""Type"",""Port"",""CurrentlyRunning""] [""Name"",""Type"",""Port"",""CurrentlyRunning""]", "four fields, all of them context")
    Do $$$AssertEquals(tList.table.columns.%Get(3).field _ " " _ tList.table.columns.%Get(3).labelKey _ " " _ tList.table.columns.%Get(3).kind, "CurrentlyRunning languageServerColumnRunning status", "Running is a status column")
    Do $$$AssertEquals(tLog.route _ " " _ tLog.sideBarPosition _ " " _ tLog.archetype _ " " _ tLog.parentScope _ " " _ tLog.toolIdentifier, "os-management/language-servers/activity 0 log-viewer os-management/language-servers osmgmt.languageserveractivity", "the Activity log is the list's unlisted, parent-scoped log viewer")
    Do $$$AssertEquals(tLog.read.source.%ToJSON() _ " " _ tLog.read.criteria.%ToJSON(), "{""port"":""admin"",""endpoint"":""LanguageServer"",""type"":""ACTIVITY"",""rows"":""Activity""} {""fields"":[{""param"":""name"",""labelKey"":""tableColumnName"",""kind"":""text"",""maxLength"":50}]}", "reading ACTIVITY over its Activity member for the one name criterion")
    Do $$$AssertEquals(tLog.read.fields.%ToJSON() _ " " _ tLog.read.sort.%ToJSON(), "[""ID"",""DateTime"",""RecordType"",""Job"",""Text""] {""fields"":[""ID""],""default"":""ID"",""direction"":""desc""}", "five fields, newest first")
    Do $$$AssertEquals(tLog.context.fields.%ToJSON(), tLog.read.fields.%ToJSON(), "all of them context")
    For tScreen = ..#LIST, ..#ACTIVITY {
        Do $$$AssertEquals(##class(OcuPilot.Test.LanguageServer).Pairs($ClassMethod(tScreen, "PrivilegePairs")), ..#OWNPAIR _ ",%DB_IRISSYS:READ", tScreen _ " requires the own pair and the database read")
        Do $$$AssertEquals(##class(OcuPilot.Test.LanguageServer).Pairs($ClassMethod(tScreen, "OwnPrivilegePairs")), ..#OWNPAIR, tScreen _ ": the first is its own")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tScreen, "PrivilegePairs"), $ClassMethod(tScreen, "OwnPrivilegePairs")), "", tScreen _ ": the area covers every pair but its own")
        Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tScreen, "PrivilegePairs")), "", tScreen _ ": and the own pair is not the area's")
    }
    Do $$$AssertEquals(tList.suggestedPrompts.%Size() _ " " _ tLog.suggestedPrompts.%Size(), "3 3", "each screen carries three suggested prompts")
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    For tName = "osmgmt.languageservers.read", "osmgmt.languageserveractivity.read" {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tRead)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tRead) && (tRead.kind = "read"), tName _ " is registered")
    }
}

/// <p>AC1, AD-36: the list over this instance's own servers answers every server the vendor lists,
/// each with a boolean <code>CurrentlyRunning</code> from its <code>ACTIVITY</code> call, the vendor's own
/// <code>%</code> servers among them.</p>
Method TestTheListReadsEachServersRunningState()
{
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "LIST", .tNoQuery, "", .tVendor, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor lists the instance's servers")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tVendor.%Size() > 0, "this instance defines servers of its own")
    Do $$$AssertEquals(tResult.rows.%Size(), tVendor.%Size(), "every server the vendor lists is a row")
    Set tIterator = tResult.rows.%GetIterator()
    Set tVendorRows = 0
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(tRow.%GetTypeOf("CurrentlyRunning"), "boolean", tRow.%Get("Name") _ " reads its running state as a boolean")
        Do $$$AssertEquals(tRow.%GetTypeOf("Port"), "number", tRow.%Get("Name") _ " reads its port as a number")
        If $Extract(tRow.%Get("Name")) = "%" Set tVendorRows = tVendorRows + 1
    }
    Do $$$AssertTrue(tVendorRows > 0, "the vendor's own servers are among the rows")
}

/// <p>AC1, AD-36 as amended: each row's <code>ACTIVITY</code> detail call sends the vendor's
/// <code>maxRows</code> 1 and merges <code>CurrentlyRunning</code> alone, after the list's own call
/// sent the cap plus one.</p>
/// <p>Mutation (Rule 19): drop the <code>ACTIVITY</code> line from
/// <method>OcuPilot.Screen.Read.DetailRow</method> -- the detail calls go unseeded and the maxRows leg
/// goes red.</p>
Method TestTheActivityDetailCallSendsOneRow()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
    Do $ClassMethod(..#ENDPOINT, "SetMode", "list")
    Do $ClassMethod(..#ENDPOINT, "SetRows", "[{""Name"":""OcuPilotProbeA"",""Port"":53901,""Type"":""Java""},{""Name"":""OcuPilotProbeB"",""Port"":53902,""Type"":"".NET""}]")
    Do $ClassMethod(..#ENDPOINT, "ArmServer", "OcuPilotProbeA", 1, "[{""ID"":2,""DateTime"":""2026-09-29 05:06:09"",""RecordType"":""Info"",""Job"":7,""Text"":""started""},{""ID"":1,""DateTime"":""2026-09-29 05:06:00"",""RecordType"":""Info"",""Job"":7,""Text"":""starting""}]")
    Do $ClassMethod(..#ENDPOINT, "ArmServer", "OcuPilotProbeB", 0)
    Set tSC = $ClassMethod(..#READER, "Execute", ..#LIST, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""Name"":""OcuPilotProbeA"",""Type"":""Java"",""Port"":53901,""CurrentlyRunning"":true},{""Name"":""OcuPilotProbeB"",""Type"":"".NET"",""Port"":53902,""CurrentlyRunning"":false}]", "each row merges its server's CurrentlyRunning and nothing of its activity")
    Do $$$AssertEquals($ClassMethod(..#ENDPOINT, "ActivityMaxRows"), "1,1", "each detail call sent maxRows 1")
}

/// <p>AC3, AD-36 as amended: the Activity log reads one server's rows as the vendor answers them,
/// newest first, bounded by the cap plus one and reporting truncation, and projects the five declared
/// fields; a read with no <code>name</code> is refused 400 <code>READ.CRITERION</code> before the port
/// is called, and a name the instance does not define answers the port's 404. Against the instance, a
/// vendor server's own activity reads the same way.</p>
Method TestTheActivityReadListsOneServersRows()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
    Do $ClassMethod(..#ENDPOINT, "ArmServer", "OcuPilotProbeA", 0, "[{""ID"":3,""DateTime"":""2026-09-29 05:06:47"",""RecordType"":""Error"",""Job"":7,""Text"":""no JVM""},{""ID"":2,""DateTime"":""2026-09-29 05:06:21"",""RecordType"":""Info"",""Job"":7,""Text"":""stopped""},{""ID"":1,""DateTime"":""2026-09-29 05:06:09"",""RecordType"":""Warning"",""Job"":7,""Text"":""slow""}]")
    Set tCriteria("name") = "OcuPilotProbeA"
    Set tSC = $ClassMethod(..#READER, "Execute", ..#ACTIVITY, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the Activity log reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""ID"",""DateTime"",""RecordType"",""Job"",""Text""]", "the five declared fields")
    Do $$$AssertEquals(tResult.rows.%ToJSON(), "[{""ID"":3,""DateTime"":""2026-09-29 05:06:47"",""RecordType"":""Error"",""Job"":7,""Text"":""no JVM""},{""ID"":2,""DateTime"":""2026-09-29 05:06:21"",""RecordType"":""Info"",""Job"":7,""Text"":""stopped""}]", "the newest two, as the vendor answers them")
    Do $$$AssertEquals(tResult.truncated _ " " _ $ClassMethod(..#ENDPOINT, "ActivityMaxRows"), "1 3", "truncated, the vendor asked for the cap plus one")

    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
    Kill tNone
    Set tSC = $ClassMethod(..#READER, "Execute", ..#ACTIVITY, 2, .tResult, .tHttp, .tFault, .tNone)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "400 READ.CRITERION name is required", "a read with no name is refused")
    Do $$$AssertEquals($ClassMethod(..#ENDPOINT, "Recorded", "constructed"), "", "before the port is called")
    Kill tCriteria
    Set tCriteria("name") = "NoSuch"
    Set tSC = $ClassMethod(..#READER, "Execute", ..#ACTIVITY, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a name the instance does not define is the port's 404, not an empty log")

    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "LIST", .tNoQuery, "", .tVendor, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tVendor)) && (tVendor.%Size() > 0), "the vendor lists a server of its own to read against")
    If $$$ISERR(tSC) || '$IsObject($Get(tVendor)) || (tVendor.%Size() = 0) Quit
    Kill tCriteria
    Set tCriteria("name") = tVendor.%Get(0).%Get("Name")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#ACTIVITY, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a vendor server's own activity reads")
    Do $$$AssertTrue($$$ISOK(tSC) && (tResult.rows.%Size() <= 5) && (tResult.fields.%Size() = 5), "within the cap, over the five fields")
    Set tCriteria("name") = "OcuPilotProbeELSNoSuch"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#ACTIVITY, 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "and a name the instance does not define is the vendor's own 404")
}

/// <p>AD-51, AD-52, AD-8, AD-22: each tool is a bodyless, non-destructive action write through the
/// admin port, read through <code>ACTIVITY</code> and fingerprinted over <code>CurrentlyRunning</code>,
/// which the registration guard holds adequate; it requires the screen's own pairs and nothing more,
/// carries its row action, names its server by <code>Name</code>, and is governed by a key that ships
/// enabled. The port admits each pair bodyless and <code>ACTIVITY</code> as a read.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.LanguageServerStart.FINGERPRINTSUBJECT</parameter>
/// -- the registration guard refuses it and the adequacy leg goes red.</p>
Method TestTheToolsAreActionWritesOverTheScreensOwnPairs()
{
    For tCase = $ListBuild("osmgmt.languageservers.start", ..#START, "START"), $ListBuild("osmgmt.languageservers.stop", ..#STOP, "STOP") {
        Set tName = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tType = $List(tCase, 3)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tTool) && (tTool.class = tClass) && (tTool.kind = "write"), tName _ " is registered as a write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive") _ " " _ $ClassMethod(tClass, "ChangeAction"), "OcuPilot.Port.AdminPort ACTIVITY " _ tType _ " 0 0 updated", tName _ ": a bodyless, non-destructive " _ tType _ " read through ACTIVITY")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdParam") _ " " _ $ClassMethod(tClass, "IdArgument"), "LanguageServer name Name", tName _ ": addressing the server by its name")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField") _ " " _ $ClassMethod(tClass, "StateField"), "CurrentlyRunning CurrentlyRunning CurrentlyRunning", tName _ ": fingerprinted over the running state its precondition reads")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, tName _ ": admitting no settable field")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), $ZConvert(tType, "L"), tName _ ": carrying its row action")
        Do $$$AssertEquals(..Pairs($ClassMethod(tClass, "PrivilegePairs")), ..Pairs($ClassMethod(..#LIST, "PrivilegePairs")), tName _ ": requiring the screen's own pairs and nothing more")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Name""]", tName _ ": the schema requires the name")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("LanguageServer", tType) && ##class(OcuPilot.Port.AdminPort).IsBodyless("LanguageServer", tType), tName _ ": the port admits the pair as a bodyless write")
        Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tKeys) && (tKeys.%GetTypeOf(tName) = "boolean") && tKeys.%Get(tName), tName _ ": its governance key ships enabled")
    }
    Do $$$AssertTrue($ListFind($ListFromString(##class(OcuPilot.Port.AdminPort).#TYPESUFFIXES), "ACTIVITY") > 0, "the port admits ACTIVITY as a read")
}

/// <p>AC2, AD-51: <method>OcuPilot.Screen.Tool.LanguageServerStart.StateDiff</method> answers one
/// <code>CurrentlyRunning</code> row, No to Yes for a start and Yes to No for a stop; it refuses a start
/// of a running server and a stop of a stopped one with the published sentences, and a read carrying no
/// boolean state for both.</p>
/// <p>Mutation (Rule 19): let a start through for a running server -- the running-refusal leg goes
/// red.</p>
Method TestTheStateDiffRefusesTheWrongVerb()
{
    Set tStopped = {"CurrentlyRunning": false}
    Set tRunning = {"CurrentlyRunning": true}
    Set tSC = $ClassMethod(..#START, "StateDiff", tStopped, .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " [" _ tProblem _ "] " _ tRows.%ToJSON(), "1 [] [{""field"":""CurrentlyRunning"",""before"":""No"",""after"":""Yes""}]", "a start of a stopped server moves Running from No to Yes")
    Set tSC = $ClassMethod(..#START, "StateDiff", tRunning, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tRows.%Size(), ..#RUNNING _ " 0", "a start of a running server is refused with the published sentence")
    Set tSC = $ClassMethod(..#STOP, "StateDiff", tRunning, .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " [" _ tProblem _ "] " _ tRows.%ToJSON(), "1 [] [{""field"":""CurrentlyRunning"",""before"":""Yes"",""after"":""No""}]", "a stop of a running server moves Running from Yes to No")
    Set tSC = $ClassMethod(..#STOP, "StateDiff", tStopped, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tRows.%Size(), ..#STOPPED _ " 0", "a stop of a stopped server is refused with the published sentence")
    For tClass = ..#START, ..#STOP {
        Set tSC = $ClassMethod(tClass, "StateDiff", {"CurrentlyRunning": "true"}, .tRows, .tProblem)
        Do $$$AssertTrue((tProblem '= "") && (tProblem '= ..#RUNNING) && (tProblem '= ..#STOPPED) && (tRows.%Size() = 0), tClass _ " refuses a state that is not a boolean")
    }
    Do $$$AssertEquals($Parameter(..#START, "RUNNINGREASON") _ "|" _ $Parameter(..#START, "STOPPEDREASON"), ..#RUNNING _ "|" _ ..#STOPPED, "the tool's refusals are the published sentences")
}

/// <p>AC2, AD-39: a start the vendor refuses answers 500 <code>LANGUAGESERVER.START</code> with the
/// published sentence and nothing of the vendor's text, which goes to the log; a refused stop keeps the
/// generic internal answer.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.TYPEFAULTS</parameter> -- the start
/// answers the generic internal fault and this goes red.</p>
Method TestARefusedStartAnswersItsPublishedCode()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
    Do $ClassMethod(..#ENDPOINT, "SetMode", "errorstatus")
    Kill tQuery
    Set tQuery("name") = "OcuPilotProbeA"
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("LanguageServer", "START", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "1 500 LANGUAGESERVER.START " _ ..#STARTFAILED, "a refused start answers its own code and the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).#REASONLANGUAGESERVERSTART, ..#STARTFAILED, "which is the kernel's reason for that code")
    Do $$$AssertTrue($IsObject($Get(tFault)) && '(tFault.%ToJSON() [ $Parameter(..#ENDPOINT, "FAULTTEXT")), "carrying none of the vendor's text")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ $Parameter(..#ENDPOINT, "FAULTTEXT"), "which reaches the log")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("LanguageServer", "STOP", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a refused stop keeps the generic internal answer")
}

/// <p>AD-10, AD-13: the prohibited set covers <code>language-server</code>, no registered write tool
/// is uncovered, and a start or stop of one of the instance's own servers is judged by the reviewed-few
/// sweep alone, which its state row passes.</p>
/// <p>Mutation (Rule 19): drop <code>language-server</code> from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- both tools are uncovered
/// and this goes red.</p>
Method TestProhibitedCoversTheType()
{
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), "language-server") > 0, "language-server is a covered type")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("language-server"), "and a known entity type")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).UncoveredWriteTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry reads")
    Do $$$AssertEquals($ListToString($Get(tTools)), "", "no registered write tool is uncovered")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "LIST", .tNoQuery, "", .tVendor, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tVendor)) && (tVendor.%Size() > 0), "the vendor lists a server of its own to read against")
    If $$$ISERR(tSC) || '$IsObject($Get(tVendor)) || (tVendor.%Size() = 0) Quit
    Set tServer = tVendor.%Get(0).%Get("Name")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("language-server", "instance", tServer, .tRef)
    Do $$$AssertStatusOK(tSC, "the server has a reference")
    For tTool = "osmgmt.languageservers.start", "osmgmt.languageservers.stop" {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, "{""CurrentlyRunning"":false}", "[{""field"":""CurrentlyRunning"",""before"":""No"",""after"":""Yes""}]", .tProhibits, .tCode)
        Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProhibits _ " [" _ tCode _ "]", "1 0 []", tTool _ " on " _ tServer _ " is not prohibited")
    }
}

/// <p><var>pPairs</var>, a list of <code>$ListBuild(resource, permission)</code> pairs, as
/// comma-separated <code>resource:permission</code> text.</p>
ClassMethod Pairs(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

}
