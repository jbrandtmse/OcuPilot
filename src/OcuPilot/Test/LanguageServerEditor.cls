/// <p>Pins Story 16.25's external language server editor on the instance side (AD-3, AD-4, AD-8,
/// AD-10, AD-21, AD-44, AD-51, AD-52, AD-54, AD-55): what the form and the three tools declare, the
/// rules' refusals, the update's member-by-member <code>Custom</code> merge and its running refusal,
/// the create's composed body and resource default, the delete's running refusal, the port's completed
/// read and its Python delete gate observed through <class>OcuPilot.Test.LanguageServerSeamPort</class>,
/// the prohibited set's coverage and the declared lists' agreement with the instance.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%All</code>. It reads the instance's own servers and <code>Config.Gateways</code> and changes
/// nothing: every fresh read is a fixture's, and every armed port answer goes through
/// <class>OcuPilot.Test.LanguageServerEndpoint</class>. One run at a time.</p>
Class OcuPilot.Test.LanguageServerEditor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter FORM = "OcuPilot.Screen.Descriptor.LanguageServerForm";

Parameter CREATE = "OcuPilot.Screen.Tool.LanguageServerCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.LanguageServerUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.LanguageServerDelete";

Parameter RULES = "OcuPilot.Area.OsMgmt.LanguageServerRules";

Parameter ENDPOINT = "OcuPilot.Test.LanguageServerEndpoint";

Parameter SEAM = "OcuPilot.Test.LanguageServerSeamPort";

/// <p>The pairs every write adds to the screen's two, and the classic editor.</p>
Parameter WRITEPAIRS = "%DB_IRISSYS:WRITE,%Admin_Manage:USE";

Parameter EDITOR = "%CSP.UI.Portal.ExternalLanguageServer";

/// <p>The running refusal EXPERIENCE.md publishes.</p>
Parameter RUNNING = "This server is running. Stop it before changing or deleting it.";

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

/// <p>AD-5, AD-8, AD-44, AD-51, AD-54: the form is the list's unlisted <code>form-page</code> over the
/// list's own pairs; the three tools are writes through the language server port, each requiring the
/// screen's pairs with <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:WRITE</code>, the create
/// and update the classic editor's custom resource too; the delete is a destructive, bodyless row
/// action fingerprinted over the running state and the type; every key ships enabled.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Manage</code> from
/// <method>OcuPilot.Screen.Tool.LanguageServerDelete.PrivilegePairs</method> -- its pairs leg goes
/// red.</p>
Method TestTheFormAndToolsRegister()
{
    Set tSC = $ClassMethod(..#FORM, "DeclarationJson", .tForm)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tList)
    If '$IsObject($Get(tForm)) || '$IsObject($Get(tList)) Quit
    Do $$$AssertEquals(tForm.route _ " " _ tForm.sideBarPosition _ " " _ tForm.archetype _ " " _ tForm.entityType _ " " _ tForm.id.kind _ " " _ tForm.toolIdentifier, "os-management/language-servers/edit 0 form-page language-server single osmgmt.languageserverform", "the form is the list's unlisted editor")
    Do $$$AssertEquals(tForm.classicPage _ " " _ tForm.suggestedPrompts.%Size(), ..#EDITOR _ " 3", "replacing the classic editor, with three suggested prompts")
    Do $$$AssertEquals(..Pairs($ClassMethod(..#FORM, "PrivilegePairs")) _ " " _ ..Pairs($ClassMethod(..#FORM, "OwnPrivilegePairs")), ..Pairs($ClassMethod(..#LIST, "PrivilegePairs")) _ " %Admin_ExternalLanguageServerEdit:USE", "over the list's own pairs, the own pair included")
    Do $$$AssertEquals(tList.primaryAction.id _ " " _ tList.rowActions.%Get(2).id, "create delete", "the list's Create and its Delete")
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Set tScreenPairs = ..Pairs($ClassMethod(..#LIST, "PrivilegePairs"))
    For tCase = $ListBuild("osmgmt.languageservers.create", ..#CREATE, "GET PUT 1 0 created", ..#EDITOR), $ListBuild("osmgmt.languageservers.update", ..#UPDATE, "GET PUT 1 0 updated", ..#EDITOR), $ListBuild("osmgmt.languageservers.delete", ..#DELETE, "GET DELETE 0 1 deleted", "") {
        Set tName = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)) && (tTool.class = tClass) && (tTool.kind = "write"), tName _ " is registered as a write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive") _ " " _ $ClassMethod(tClass, "ChangeAction"), "OcuPilot.Port.LanguageServerPort " _ $List(tCase, 3), tName _ ": its port, request types and kind")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdParam") _ " " _ $ClassMethod(tClass, "IdArgument"), "LanguageServer name Name", tName _ ": addressing the server by its name")
        Set tWanted = tScreenPairs _ "," _ ..#WRITEPAIRS
        Do $$$AssertEquals(..Pairs($ClassMethod(tClass, "PrivilegePairs")), tWanted, tName _ ": the screen's pairs with the write's own two")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $List(tCase, 4), tName _ ": the classic page it performs beyond the list's")
        Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
        Do $$$AssertTrue($$$ISOK(tSC) && (tKeys.%GetTypeOf(tName) = "boolean") && tKeys.%Get(tName), tName _ ": its governance key ships enabled")
        Set tType = $Piece($List(tCase, 3), " ", 2)
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("LanguageServer", tType), tName _ ": the port admits LanguageServer/" _ tType)
        Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsBodyless("LanguageServer", tType), '$ClassMethod(tClass, "SendsBody"), tName _ ": bodyless exactly when the tool sends no body")
    }
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#UPDATE, "Creates"), "1 0", "the create creates its target and the update does not")
    Do $$$AssertEquals($ListToString($ClassMethod(..#CREATE, "SettableFields")), "BindToIPAddress,ConnectionTimeout,InitializationTimeout,Port,Resource,Type,UseSharedMemory,SSLConfigurationServer,SSLConfigurationClient,VerifySSLHostName,Custom", "the create sets the type, the shared settings and Custom, and no file location")
    Do $$$AssertEquals($ListToString($ClassMethod(..#UPDATE, "SettableFields")), "BindToIPAddress,ConnectionTimeout,InitializationTimeout,Port,Resource,UseSharedMemory,SSLConfigurationServer,SSLConfigurationClient,VerifySSLHostName,Custom", "the update sets the same less the type")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "InputSchema").required.%ToJSON(), "[""Name"",""Type"",""Port""]", "the create's schema requires the name, the type and the port")
    Set tUpdateSchema = $ClassMethod(..#UPDATE, "InputSchema").properties
    Do $$$AssertTrue((tUpdateSchema.%GetTypeOf("Type") = "unassigned") && (tUpdateSchema.%GetTypeOf("LogFile") = "unassigned") && (tUpdateSchema.%GetTypeOf("Custom") = "object"), "the update's schema carries Custom, and no Type or LogFile")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETE, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(..#DELETE, "FingerprintSubject")) _ " " _ $ClassMethod(..#DELETE, "PreconditionField"), "delete CurrentlyRunning,Type CurrentlyRunning", "the delete is the list's row action, fingerprinted over the running state and the type")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#DELETE), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($Parameter(..#UPDATE, "RUNNINGREASON") _ "|" _ $Parameter(..#DELETE, "RUNNINGREASON") _ "|" _ ##class(OcuPilot.Api.LanguageServerError).#REASONRUNNING, ..#RUNNING _ "|" _ ..#RUNNING _ "|" _ ..#RUNNING, "the update, the delete and the Save's envelope refuse a running server with one published sentence")
    Do $$$AssertTrue($Parameter(..#UPDATE, "DESCRIPTION") [ $Parameter(..#UPDATE, "PYTHONCONSEQUENCE"), "the update's description carries the Python consequence")
}

/// <p>AD-39, AD-55: the rules refuse each field on its own code -- the name's shape and a taken name,
/// the type, the port and the timeouts' ranges, the names' lengths, a flag that is not one, a file
/// location top-level or in <code>Custom</code>, a member the type does not take and a .NET version
/// outside the vendor's list -- and accept a create that sets every settable field. An edit keeps a
/// stored .NET version outside the list until it changes.</p>
/// <p>Mutation (Rule 19): drop the <code>CUSTOMPATH</code> arm of
/// <method>OcuPilot.Area.OsMgmt.LanguageServerRules.Validate</method> -- the path member reads as an
/// unknown one and this goes red.</p>
Method TestTheRulesRefuseEachField()
{
    Set tRules = ..#RULES
    Set tGood = {"Type": "Java", "Port": 54490, "ConnectionTimeout": 10, "InitializationTimeout": "20", "BindToIPAddress": "127.0.0.1", "Resource": "%Gateway_Object", "UseSharedMemory": true, "SSLConfigurationServer": "", "SSLConfigurationClient": "", "VerifySSLHostName": false, "Custom": {"JVMArgs": "-Xmx64m"}}
    Do $$$AssertEquals(..Violations("OcuPilotProbeELSGood", tGood, "create"), "", "a create setting every settable field passes")
    For tCase = $ListBuild("", "Name:LANGUAGESERVER.NAME.REQUIRED"), $ListBuild($Translate($Justify("", 51), " ", "X"), "Name:LANGUAGESERVER.NAME.SHAPE"), $ListBuild("OcuPilot" _ $Char(9) _ "Tab", "Name:LANGUAGESERVER.NAME.SHAPE") {
        Do $$$AssertEquals(..Violations($List(tCase, 1), tGood, "create"), $List(tCase, 2), "the name '" _ $ZStrip($List(tCase, 1), "*C") _ "' is refused on Name")
    }
    Do $$$AssertEquals(..Violations($Translate($Justify("", 50), " ", "X"), tGood, "create"), "", "a 50-character name passes")
    Set tCases = 0
    Set tCases($Increment(tCases)) = $ListBuild({"Port": 1}.%ToJSON(), "Type:LANGUAGESERVER.TYPE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "java", "Port": 1}.%ToJSON(), "Type:LANGUAGESERVER.TYPE.UNKNOWN")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java"}.%ToJSON(), "Port:LANGUAGESERVER.PORT.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": ""}.%ToJSON(), "Port:LANGUAGESERVER.PORT.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 70000}.%ToJSON(), "Port:LANGUAGESERVER.PORT.RANGE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": "abc"}.%ToJSON(), "Port:LANGUAGESERVER.PORT.RANGE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "ConnectionTimeout": 1}.%ToJSON(), "ConnectionTimeout:LANGUAGESERVER.CONNECTIONTIMEOUT.RANGE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "InitializationTimeout": 301}.%ToJSON(), "InitializationTimeout:LANGUAGESERVER.INITIALIZATIONTIMEOUT.RANGE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "Resource": ($Translate($Justify("", 65), " ", "R"))}.%ToJSON(), "Resource:LANGUAGESERVER.RESOURCE.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "SSLConfigurationClient": ($Translate($Justify("", 65), " ", "S"))}.%ToJSON(), "SSLConfigurationClient:LANGUAGESERVER.SSLCONFIGURATIONCLIENT.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "UseSharedMemory": "yes"}.%ToJSON(), "UseSharedMemory:PORT.FIELD.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "LogFile": "/tmp/x.log"}.%ToJSON(), "LogFile:LANGUAGESERVER.PATH")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "Custom": {"JavaHome": "/opt/jdk"}}.%ToJSON(), "Custom.JavaHome:LANGUAGESERVER.CUSTOM.PATH")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Python", "Port": 1, "Custom": {"PythonPath": "/usr/bin/python3"}}.%ToJSON(), "Custom.PythonPath:LANGUAGESERVER.CUSTOM.PATH")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "Custom": {"Address": "10.0.0.1"}}.%ToJSON(), "Custom.Address:LANGUAGESERVER.CUSTOM.UNKNOWN")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "ODBC", "Port": 1, "Custom": {"JVMArgs": "-X"}}.%ToJSON(), "Custom.JVMArgs:LANGUAGESERVER.CUSTOM.UNKNOWN")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": ".NET", "Port": 1, "Custom": {"DotNetVersion": "N6.0"}}.%ToJSON(), "Custom.DotNetVersion:LANGUAGESERVER.DOTNETVERSION.UNKNOWN")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": ".NET", "Port": 1, "Custom": {"Exec32": "yes"}}.%ToJSON(), "Custom.Exec32:PORT.FIELD.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild({"Type": "Java", "Port": 1, "Custom": "-Xmx64m"}.%ToJSON(), "Custom:PORT.FIELD.SHAPE")
    For tI = 1:1:tCases {
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCases(tI), 1))
        Do $$$AssertEquals(..Violations("OcuPilotProbeELSRule", tArgs, "create"), $List(tCases(tI), 2), "create " _ tArgs.%ToJSON() _ " is refused on its field")
    }
    Do $$$AssertEquals(..Violations("OcuPilotProbeELSRule", {"Type": ".NET", "Port": 1, "Custom": {"DotNetVersion": "N10.0", "Exec32": true}}, "create"), "", "a listed .NET version and a flag pass")
    Set tNet = {"Type": ".NET", "Port": 53372, "Custom": {"DotNetVersion": "N6.0", "Exec32": 0, "FilePath": ""}, "CurrentlyRunning": false}
    Do $$$AssertEquals(..Violations("%DotNet Server", {"Custom": {"DotNetVersion": "N6.0"}}, "update", tNet), "", "an edit keeps a stored .NET version outside the list")
    Do $$$AssertEquals(..Violations("%DotNet Server", {"Custom": {"DotNetVersion": "N7.0"}}, "update", tNet), "Custom.DotNetVersion:LANGUAGESERVER.DOTNETVERSION.UNKNOWN", "and refuses a change to another one")
    Do $$$AssertEquals(..Violations("%DotNet Server", {"Port": ""}, "update", tNet), "Port:LANGUAGESERVER.PORT.REQUIRED", "an edit that empties the port is refused as missing")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "LIST", .tNoQuery, "", .tVendor, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tVendor)) && (tVendor.%Size() > 0), "the vendor lists a server of its own")
    If $$$ISERR(tSC) || '$IsObject($Get(tVendor)) || (tVendor.%Size() = 0) Quit
    Set tHeld = tVendor.%Get(0).%Get("Name")
    Do $$$AssertEquals(..Violations(tHeld, {"Type": "Java", "Port": 1}, "create", "", 1), "Name:LANGUAGESERVER.NAME.TAKEN", "a name the instance holds is taken")
    Do $$$AssertEquals(..Violations($ZConvert(tHeld, "L") _ "OcuPilotNoSuch", {"Type": "Java", "Port": 1}, "create", "", 1), "", "and a name it does not hold is free")
}

/// <p>AD-4 as amended: the update merges the arguments over the fresh read, sends the type and the
/// file locations as held, never sends the running state, leaves out a <code>Custom</code> no member of
/// which changes, and sends the whole <code>Custom</code> when one does; a running server is refused
/// with the published sentence unless it is <code>Remote</code>. A Python server's changed member
/// carries the consequence code the card states, and nothing else does.</p>
/// <p>Mutation (Rule 19): drop the <code>Remote</code> test from
/// <method>OcuPilot.Area.OsMgmt.LanguageServerRules.Running</method> -- the Remote leg goes red; make
/// <method>OcuPilot.Screen.Tool.LanguageServerUpdate.Consequence</method> answer <code>""</code> -- the
/// Python leg goes red.</p>
Method TestTheUpdateMergesCustomByMember()
{
    Set tFresh = ..Fresh("Java", 0, {"ClassPath": "/opt/lib/a.jar", "JavaHome": "/opt/jdk", "JVMArgs": "-Xmx32m"})
    Set tSettable = $ClassMethod(..#UPDATE, "SettableFields")
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tFresh, {"Port": "54411"}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " [" _ tProblem _ "] " _ tDiff.%ToJSON(), "1 [] [{""field"":""Port"",""before"":""54410"",""after"":""54411""}]", "a port edit is one row")
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.%ToJSON(), 1: ""), "{""BindToIPAddress"":""127.0.0.1"",""ConnectionTimeout"":5,""InitializationTimeout"":5,""LogFile"":""/opt/log/gw.log"",""Port"":54411,""Resource"":""%Gateway_Object"",""Type"":""Java"",""UseSharedMemory"":false,""SSLConfigurationServer"":"""",""SSLConfigurationClient"":"""",""VerifySSLHostName"":false}", "the body carries every field as held, the new port as a number, and no Custom or running state")
    Do $$$AssertEquals(tUnchanged, 10, "ten keys unchanged")
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tFresh, {"Custom": {"JVMArgs": "-Xmx64m"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tDiff.%ToJSON(), "[{""field"":""Custom.JVMArgs"",""before"":""-Xmx32m"",""after"":""-Xmx64m""}]", "a changed member is one Custom row")
    Do $$$AssertEquals($Select($IsObject(tPayload) && $IsObject(tPayload.Custom): tPayload.Custom.%ToJSON(), 1: ""), "{""ClassPath"":""/opt/lib/a.jar"",""JavaHome"":""/opt/jdk"",""JVMArgs"":""-Xmx64m""}", "and the whole Custom is sent, its file locations as held")
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tFresh, {"Port": 54411, "Custom": {"JVMArgs": "-Xmx32m"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.%GetTypeOf("Custom"), 1: "") _ " " _ tDiff.%Size(), "unassigned 1", "a Custom whose members are unchanged is left out of the body")
    For tCase = $ListBuild("{""Custom"":{""JavaHome"":""/tmp""}}", "'Custom.JavaHome': File locations"), $ListBuild("{""Custom"":{""PythonOptions"":""-u""}}", "'Custom.PythonOptions': This server's type has no such setting.") {
        Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tFresh, ##class(%DynamicObject).%FromJSON($List(tCase, 1)), "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        Do $$$AssertTrue($$$ISOK(tSC) && ($Extract(tProblem, 1, $Length($List(tCase, 2))) = $List(tCase, 2)) && '$IsObject(tPayload), $List(tCase, 1) _ " is refused: " _ tProblem)
    }
    Set tNet = ..Fresh(".NET", 0, {"DotNetVersion": "N8.0", "Exec32": 0, "FilePath": ""})
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tNet, {"Custom": {"Exec32": true}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($Select($IsObject(tPayload) && $IsObject(tPayload.Custom): tPayload.Custom.%ToJSON(), 1: "") _ " " _ tDiff.%ToJSON(), "{""DotNetVersion"":""N8.0"",""Exec32"":1,""FilePath"":""""} [{""field"":""Custom.Exec32"",""before"":""0"",""after"":""1""}]", "a flag member is sent as the 1 the instance answers it as")
    Set tPython = ..Fresh("Python", 0, {"PythonOptions": "-u", "PythonPath": "/usr/bin/python3"})
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tPython, {"Custom": {"PythonOptions": "-B"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "Consequence", tPayload), $Parameter(..#UPDATE, "PYTHONCUSTOMCONSEQUENCE"), "a Python server's changed member carries the consequence code to the card (AD-4)")
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tPython, {"Port": 54411}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "Consequence", tPayload) _ "|" _ $ClassMethod(..#UPDATE, "Consequence", {"Type": "Java", "Custom": {"JVMArgs": "-X"}}), "|", "and a shared field's edit, or another type's Custom, carries none")

    Set tRunning = ..Fresh("Java", 1, {"ClassPath": "", "JavaHome": "", "JVMArgs": ""})
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tRunning, {"Port": 54411}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProblem _ " " _ $IsObject(tPayload), "1 " _ ..#RUNNING _ " 0", "a running server's edit is refused with the published sentence and composes nothing")
    Do tRunning.%Remove("CurrentlyRunning")
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tRunning, {"Port": 54411}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tProblem, ..#RUNNING, "and so is one whose running state was not read")
    Set tRemote = ..Fresh("Remote", 1, {"Address": "10.0.0.5"})
    Set tSC = $ClassMethod(..#UPDATE, "MergeUpdate", tRemote, {"Port": 54411, "Custom": {"Address": "10.0.0.6"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tDiff.%Size() _ " " _ $Select($IsObject(tPayload): tPayload.%GetTypeOf("CurrentlyRunning") _ " " _ tPayload.Custom.Address, 1: ""), " 2 unassigned 10.0.0.6", "a running Remote server is editable, and its running state is still not sent")
}

/// <p>AD-54, the Resource default: a create's body is the supplied fields, the whole numbers as
/// numbers and <code>Custom</code> with only its supplied members, one row each; a create naming no
/// resource sends its type's classic default as a row of its own; a member its type does not take is
/// refused.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.LanguageServerRules.ResourceDefault</method>
/// answer <code>%Gateway_Object</code> for every type -- the JDBC, ODBC and ML legs go red.</p>
Method TestTheCreateComposesItsTypesDefaults()
{
    For tCase = "Java:%Gateway_Object", "XSLT:%Gateway_Object", "JDBC:%Gateway_SQL", "ODBC:%Gateway_SQL", "ML:%Gateway_ML", "R:%Gateway_Object", ".NET:%Gateway_Object", "Python:%Gateway_Object", "Remote:%Gateway_Object" {
        Do $$$AssertEquals($ClassMethod(..#RULES, "ResourceDefault", $Piece(tCase, ":", 1)), $Piece(tCase, ":", 2), $Piece(tCase, ":", 1) _ " defaults its resource to " _ $Piece(tCase, ":", 2))
    }
    Set tSettable = $ClassMethod(..#CREATE, "SettableFields")
    Set tSC = $ClassMethod(..#CREATE, "ComposeCreate", {"Name": "OcuPilotProbeELSC", "Type": "JDBC", "Port": "54420", "Custom": {"JVMArgs": "-Xmx32m"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " [" _ tProblem _ "] " _ $Select($IsObject(tPayload): tPayload.%ToJSON(), 1: ""), "1 [] {""Port"":54420,""Type"":""JDBC"",""Custom"":{""JVMArgs"":""-Xmx32m""},""Resource"":""%Gateway_SQL""}", "a JDBC create carries its fields, its member and its default resource, and no name")
    Do $$$AssertEquals(tDiff.%ToJSON() _ " " _ tUnchanged, "[{""field"":""Port"",""before"":"""",""after"":""54420""},{""field"":""Type"",""before"":"""",""after"":""JDBC""},{""field"":""Custom.JVMArgs"",""before"":"""",""after"":""-Xmx32m""},{""field"":""Resource"",""before"":"""",""after"":""%Gateway_SQL""}] 0", "one row each, the default resource among them")
    Set tSC = $ClassMethod(..#CREATE, "ComposeCreate", {"Type": "Java", "Port": 54421, "Resource": "%DB_USER"}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.Resource, 1: ""), "%DB_USER", "a named resource is kept")
    Set tSC = $ClassMethod(..#CREATE, "ComposeCreate", {"Type": ".NET", "Port": 54422, "Custom": {"Exec32": true, "DotNetVersion": "N8.0"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.Custom.%ToJSON(), 1: ""), "{""Exec32"":1,""DotNetVersion"":""N8.0""}", "a .NET create's flag is composed as 1")
    Set tSC = $ClassMethod(..#CREATE, "ComposeCreate", {"Type": "ODBC", "Port": 54423, "Custom": {"JVMArgs": "-X"}}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "Custom.JVMArgs") && '$IsObject(tPayload), "an ODBC create takes no Custom member: " _ tProblem)
    Set tSC = $ClassMethod(..#CREATE, "ArgumentProblem", "OcuPilotProbeELSC", {"Type": "Java", "Port": 54424, "Custom": {"ClassPath": "/opt/a.jar"}}, .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "'Custom.ClassPath': File locations are set on the classic portal"), "the agent's create naming a file location is refused: " _ tProblem)
}

/// <p>AD-51, AD-52: the delete refuses a running server with the published sentence, or one whose
/// running state was not read, and lists a stopped one's type and port as removed rows; a running
/// <code>Remote</code> server is deletable.</p>
/// <p>Mutation (Rule 19): drop the <code>Running</code> refusal from
/// <method>OcuPilot.Screen.Tool.LanguageServerDelete.StateDiff</method> -- the running leg goes red.</p>
Method TestTheDeleteRefusesARunningServer()
{
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", ..Fresh("Java", 0, {}), .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ " [" _ tProblem _ "] " _ tRows.%ToJSON(), "1 [] [{""field"":""Type"",""before"":""Java"",""after"":"""",""removed"":true},{""field"":""Port"",""before"":""54410"",""after"":"""",""removed"":true}]", "a stopped server's delete lists its type and port as removed")
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", ..Fresh("Python", 1, {}), .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tRows.%Size(), ..#RUNNING _ " 0", "a running server's delete is refused with the published sentence")
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", {"Type": "Java", "Port": 1}, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem, ..#RUNNING, "and so is one whose running state was not read")
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", ..Fresh("Remote", 1, {}), .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tRows.%Size(), " 2", "a running Remote server is deletable")
}

/// <p>AD-52: through the language server port, a <code>GET</code> that answers is completed by the same
/// server's <code>ACTIVITY</code>, sent with <code>maxRows</code> 1, whose running state is set on the
/// answer; an <code>ACTIVITY</code> that fails fails the whole read; a <code>GET</code> that answers
/// 404 is not completed.</p>
/// <p>Mutation (Rule 19): drop the <code>maxRows</code> line from
/// <method>OcuPilot.Port.LanguageServerPort.Invoke</method> -- the one-row leg goes red.</p>
Method TestThePortCompletesTheReadWithOneActivityRow()
{
    Do ..Arm("Java")
    Do $ClassMethod(..#ENDPOINT, "ArmServer", "OcuPilotProbeELSA", 1, "[{""ID"":2,""DateTime"":""2026-09-29 05:06:09"",""RecordType"":""Info"",""Job"":7,""Text"":""started""},{""ID"":1,""DateTime"":""2026-09-29 05:06:00"",""RecordType"":""Info"",""Job"":7,""Text"":""starting""}]")
    Kill tQuery
    Set tQuery("name") = "OcuPilotProbeELSA"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%GetTypeOf("CurrentlyRunning") _ " " _ tAnswer.CurrentlyRunning _ " " _ tAnswer.Type, 1: ""), "boolean 1 Java", "completed with the running state beside the definition")
    Do $$$AssertEquals($ClassMethod(..#ENDPOINT, "ActivityMaxRows"), "1", "from one ACTIVITY call sent maxRows 1")
    Do $$$AssertEquals($Get(tQuery("maxRows")), "", "leaving the caller's query as it was")
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ..Arm("Java")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " [" _ $Get(tAnswer) _ "]", "1 404 []", "an ACTIVITY that fails fails the whole read, answering nothing")
    Set tQuery("name") = "OcuPilotProbeELSNoSuch"
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ..Arm("Java")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#ENDPOINT, "ActivityMaxRows"), "404 ", "a server the GET does not find is not completed")
}

/// <p>AD-8 as amended: the port refuses a Python server's <code>DELETE</code> to a caller without
/// <code>%System_CallOut:USE</code>, 403 naming the pair, before the vendor's delete is constructed;
/// the same caller's delete of a Java server, and a holder's delete of the Python one, reach the
/// vendor; a type read that fails is answered as that read, and nothing is deleted.</p>
/// <p>Mutation (Rule 19): drop the <code>CallOutRefused</code> call from
/// <method>OcuPilot.Port.LanguageServerPort.Invoke</method> -- the refusal leg goes red; let a failed
/// type read fall through to the delete -- the unread-type leg goes red.</p>
Method TestThePortRefusesAPythonDeleteWithoutCallOut()
{
    Kill tQuery
    Set tQuery("name") = "OcuPilotProbeELSA"
    Do ..Arm("Python")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.%Get("detail").%Get("failedPair"), 1: ""), "403 AUTH.NOPRIVILEGE %System_CallOut:USE", "a Python delete without the call-out pair is refused naming it")
    Do $$$AssertEquals($ClassMethod(..#ENDPOINT, "Recorded", "type"), $Parameter(..#ENDPOINT, "TYPEGET"), "before the vendor's delete was constructed: the last call was the type read")
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ..Arm("Java")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ $ClassMethod(..#ENDPOINT, "Recorded", "type"), "1 " _ $Parameter(..#ENDPOINT, "TYPEDELETE"), "the same caller's delete of a Java server reaches the vendor")
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ..Arm("Python")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(1)
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ $ClassMethod(..#ENDPOINT, "Recorded", "type"), "1 " _ $Parameter(..#ENDPOINT, "TYPEDELETE"), "and a holder's delete of the Python one does too")
    Do $ClassMethod(..#ENDPOINT, "Clear")
    Do ..Arm("Python")
    Do $ClassMethod(..#ENDPOINT, "SetDetailFault", "OcuPilotProbeELSA", "errorstatus")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "LanguageServer", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ $ClassMethod(..#ENDPOINT, "Recorded", "type"), "1 " _ $Parameter(..#ENDPOINT, "TYPEGET"), "a type read that fails is answered as that read's failure, and the vendor's delete is never constructed")
}

/// <p>AD-10, AD-54: the prohibited set covers the editor's fields -- a create may set the type and
/// every settable field, a change every settable field less the type, and neither a file location --
/// and judges a vendor server's <code>Custom</code> change, a create and a delete by the reviewed-few
/// sweep alone.</p>
/// <p>Mutation (Rule 19): drop <code>Custom</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.LanguageServerFields</method> -- the Custom change is
/// refused and this goes red; delete the <code>Custom.&lt;member&gt;</code> block of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Changed</method> -- the top-level key leg goes red.</p>
Method TestProhibitedCoversTheEditorsFields()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    For tField = "BindToIPAddress", "ConnectionTimeout", "InitializationTimeout", "Port", "Resource", "UseSharedMemory", "SSLConfigurationServer", "SSLConfigurationClient", "VerifySSLHostName", "Custom" {
        Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "PermittedChangeFields", "language-server"), tField) && $ListFind($ClassMethod(tProhibited, "PermittedCreateFields", "language-server"), tField), tField _ " is permitted on a change and a create")
    }
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "PermittedCreateFields", "language-server"), "Type") && '$ListFind($ClassMethod(tProhibited, "PermittedChangeFields", "language-server"), "Type"), "Type is a create's field and not a change's")
    Do $$$AssertEquals($ListFind($ClassMethod(tProhibited, "PermittedCreateFields", "language-server"), "LogFile") + $ListFind($ClassMethod(tProhibited, "PermittedChangeFields", "language-server"), "LogFile"), 0, "LogFile is neither")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("language-server", "instance", "OcuPilotProbeELSAbsent", .tNewRef)
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.create", tNewRef, "{""Type"":""Java"",""Port"":54430,""Resource"":""%Gateway_Object"",""Custom"":{""JVMArgs"":""-X""}}", "[]", .tProhibits, .tCode)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProhibits _ " [" _ tCode _ "]", "1 0 []", "a create setting its fields is not prohibited")
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.create", tNewRef, "{""Type"":""Java"",""Port"":54430,""LogFile"":""/tmp/a.log""}", "[]", .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.UNCOVEREDFIELD", "and one setting a file location is refused")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "LIST", .tNoQuery, "", .tVendor, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tVendor)) || (tVendor.%Size() = 0) {
        Do $$$AssertTrue(0, "the vendor lists a server of its own to read against")
        Quit
    }
    Set tServer = tVendor.%Get(0).%Get("Name")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("language-server", "instance", tServer, .tRef)
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.update", tRef, "{""Custom"":{""OcuPilotProbe"":""changed""}}", "[{""field"":""Custom.OcuPilotProbe"",""before"":"""",""after"":""changed""}]", .tProhibits, .tCode)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProhibits _ " [" _ tCode _ "]", "1 0 []", "a Custom member change on " _ tServer _ " is permitted")
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.update", tRef, "{""Custom.OcuPilotProbe"":""changed""}", "[{""field"":""Custom.OcuPilotProbe"",""before"":"""",""after"":""changed""}]", .tProhibits, .tCode)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProhibits _ " [" _ tCode _ "]", "1 0 []", "a Custom.<member> row is read from Custom's own member, never from a top-level key spelled with its dot")
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.update", tRef, "{""LogFile"":""/tmp/changed.log""}", "[{""field"":""LogFile"",""before"":"""",""after"":""/tmp/changed.log""}]", .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.UNCOVEREDFIELD", "a LogFile change is refused")
    Set tSC = $ClassMethod(tProhibited, "Prohibits", "osmgmt.languageservers.delete", tRef, "{}", "[{""field"":""Type"",""before"":""Java"",""after"":"""",""removed"":true}]", .tProhibits, .tCode)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tProhibits _ " [" _ tCode _ "]", "1 0 []", "a delete is not prohibited")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).UncoveredWriteTools(.tTools)
    Do $$$AssertEquals($ListToString($Get(tTools)), "", "no registered write tool is uncovered")
}

/// <p>AD-3, AD-39: the rules' declared lists are the instance's own -- the types equal the
/// derivation's, the .NET versions <code>Config.Gateways</code>'s <code>VALIDNETVERSIONS</code>, and each
/// file location a derived path -- and every code the editor answers carries its sentence, while
/// <code>LANGUAGESERVER.START</code> carries none as a violation.</p>
/// <p>Mutation (Rule 19): add <code>N6.0</code> to
/// <parameter>OcuPilot.Area.OsMgmt.LanguageServerRules.DOTNETVERSIONS</parameter> -- the vendor-list leg
/// goes red.</p>
Method TestTheDeclaredListsAreTheInstancesOwn()
{
    Do $$$AssertEquals($Parameter(..#RULES, "TYPES"), ##class(OcuPilot.Test.FieldDerive).#LANGUAGESERVERTYPES, "the rules' types are the derivation's")
    Set tOrigNS = $NAMESPACE
    Set tVendor = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tVendor = $Parameter("Config.Gateways", "VALIDNETVERSIONS")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($Parameter(..#RULES, "DOTNETVERSIONS"), tVendor, "the .NET versions are Config.Gateways' VALIDNETVERSIONS")
    Set tSC = ##class(OcuPilot.Test.FieldDerive).Stored(.tLists)
    Do $$$AssertStatusOK(tSC, "the committed lists read")
    Kill tPaths
    Set tKey = ""
    For {
        Set tKey = $Order(tLists(tKey))
        Quit:tKey=""
        If $Piece(tKey, ":", 1) '= "LanguageServer" Continue
        Set tN = ""
        For {
            Set tN = $Order(tLists(tKey, tN), 1, tRow)
            Quit:tN=""
            Set tPaths($Piece($Piece(tRow, "|", 1), ".", $Length($Piece(tRow, "|", 1), "."))) = ""
        }
    }
    Set tLocations = $Parameter(..#RULES, "PATHFIELDS")
    For tI = 1:1:$Length(tLocations, ",") {
        Do $$$AssertTrue($Data(tPaths($Piece(tLocations, ",", tI))), $Piece(tLocations, ",", tI) _ " is a derived language server path")
    }
    Set tCodes = ##class(OcuPilot.Api.Error).LanguageServerViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the editor declares violation codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries its sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#LANGUAGESERVERSTART), "", "the refused start is no violation")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#NAMETAKEN), "A server with this name already exists.", "a taken name reads the published sentence")
}

/// <p>A fresh read of a server of type <var>pType</var>, running when <var>pRunning</var>, with
/// <var>pCustom</var> as its <code>Custom</code>.</p>
ClassMethod Fresh(pType As %String, pRunning As %Boolean, pCustom As %DynamicObject) As %DynamicObject
{
    Set tFresh = {"BindToIPAddress": "127.0.0.1", "ConnectionTimeout": 5, "InitializationTimeout": 5, "LogFile": "/opt/log/gw.log", "Port": 54410, "Resource": "%Gateway_Object", "Type": (pType), "UseSharedMemory": false, "SSLConfigurationServer": "", "SSLConfigurationClient": "", "VerifySSLHostName": false}
    Do tFresh.%Set("Custom", ##class(%DynamicAbstractObject).%FromJSON(pCustom.%ToJSON()))
    Do tFresh.%Set("CurrentlyRunning", ''pRunning, "boolean")
    Quit tFresh
}

/// <p>Arm the fixture endpoint: its <code>GET</code> answers a server of type <var>pType</var> named
/// <code>OcuPilotProbeELSA</code>, and the seam port resolves every endpoint to it.</p>
ClassMethod Arm(pType As %String)
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass(..#ENDPOINT)
    Do $ClassMethod(..#ENDPOINT, "SetMode", "list")
    Set tDetail = ..Fresh(pType, 0, {})
    Do tDetail.%Remove("CurrentlyRunning")
    Set tDetails = {}
    Do tDetails.%Set("OcuPilotProbeELSA", tDetail)
    Do $ClassMethod(..#ENDPOINT, "SetDetails", tDetails.%ToJSON())
}

/// <p>The rules' violations for <var>pArgs</var> in mode <var>pMode</var>, as comma-separated
/// <code>field:code</code> text; <var>pCheckTaken</var> asks the instance whether the name is taken.</p>
ClassMethod Violations(pName As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject = "", pCheckTaken As %Boolean = 0) As %String
{
    Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .tViolations, pMode, pCheckTaken, pFresh)
    If $$$ISERR(tSC) Quit "error: " _ $System.Status.GetErrorText(tSC)
    Set tText = ""
    For tI = 1:1:+$Get(tViolations) Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tViolations(tI), 1) _ ":" _ $List(tViolations(tI), 2)
    Quit tText
}

/// <p><var>pPairs</var>, a list of <code>$ListBuild(resource, permission)</code> pairs, as
/// comma-separated <code>resource:permission</code> text.</p>
ClassMethod Pairs(pPairs As %List) As %String
{
    Quit ##class(OcuPilot.Test.LanguageServer).Pairs(pPairs)
}

}
