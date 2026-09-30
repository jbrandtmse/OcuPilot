/// <p>Pins Story 16.25's external language server editor against real servers over the wire (AD-4,
/// AD-6, AD-8, AD-21, AD-44, AD-51, AD-53, AD-54, AD-55): a principal holding exactly the tools' pairs
/// creates a Java, a Python, a .NET, a Remote and an ODBC probe through
/// <code>POST /language-server</code>, reads each one's form and the name check, edits a port keeping
/// <code>Custom</code>, keeps a Python server's hidden settings on an edit that sends no
/// <code>Custom</code> and resets them on one that does, and deletes through the list's row action;
/// a principal missing a pair is refused by name on every caller with nothing changed; a Python delete
/// without <code>%System_CallOut:USE</code> is refused with the server intact; a started probe is
/// refused edit and delete by both callers; a field outside its rules is refused on its field by the
/// Save and by the agent's call; and the agent's create, update and delete confirm, while a create of
/// a held name is refused at the mint, and a create whose name was taken since the mint and a delete
/// whose server started since the mint are refused at Confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP as <class>OcuPilot.Test.Http</class>'s test account, a JVM the instance's Java servers
/// find, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes three users, three roles and probe servers named <code>OcuPilotProbeELSEd*</code>, and starts
/// and stops one. No vendor <code>%</code> server is touched. Teardown stops each probe before it is
/// removed, since a deleted running server keeps listening, and removes its activity rows.</p>
Class OcuPilot.Test.LanguageServerEditorWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter LIST = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter CREATE = "OcuPilot.Screen.Tool.LanguageServerCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.LanguageServerUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.LanguageServerDelete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The Save routes, relative to the API base.</p>
Parameter CREATEPATH = "/language-server";

Parameter EDITPATH = "/language-server/:id";

Parameter FORMPATH = "/language-server/form";

Parameter NAMEPATH = "/language-server/name";

/// <p>The probe servers, each <code>&lt;name&gt;:&lt;type&gt;:&lt;port&gt;</code>.</p>
Parameter PROBES = "OcuPilotProbeELSEdJava:Java:53294,OcuPilotProbeELSEdPy:Python:53295,OcuPilotProbeELSEdNet:.NET:53296,OcuPilotProbeELSEdRemote:Remote:53297,OcuPilotProbeELSEdOdbc:ODBC:53298,OcuPilotProbeELSEdAgent:Java:53300,OcuPilotProbeELSEdTaken:Java:53301";

/// <p>The principals: the screen's two pairs; those and <code>%DB_IRISSYS:WRITE</code>; and exactly the
/// tools' four pairs.</p>
Parameter SCREENUSER = "OcuPilotELSEdScreen";

Parameter WRITEUSER = "OcuPilotELSEdWrite";

Parameter EXACTUSER = "OcuPilotELSEdExact";

/// <p>The sentences EXPERIENCE.md publishes.</p>
Parameter RUNNING = "This server is running. Stop it before changing or deleting it.";

Parameter TAKEN = "A server with this name already exists.";

/// <p>The seconds an HTTP client waits for a call that may ping a server.</p>
Parameter TIMEOUT = 60;

/// <p>The throwaway principals' password, generated for the run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LanguageServerEditorWire creates users, roles and external language servers on this instance, and starts and stops one; it runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotELSEd" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ..RemoveProbes()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Stop and remove every probe server and its activity rows, then the principals and their roles;
/// a failing status when anything survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..RemoveProbes()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#SCREENUSER, ..#WRITEUSER, ..#EXACTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.LanguageServerEditorWire left the principal " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Remove every probe the test made and the proposals it minted.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(..RemoveProbes(), "every probe server is stopped and removed by exact name")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC1, AC9: the exact-pairs principal creates one probe of each shape over <code>POST
/// /language-server</code>, 201 <code>{name, readBack}</code> as JSON; the instance holds each with the
/// port, the members sent and its type's default resource; the list's read shows the rows; each form
/// read answers the server with its type's settable and path members as the derived lists name them;
/// and the name check answers taken and free. A path member and a taken name are refused 422 on their
/// fields with nothing created.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.LanguageServerCreate.ComposeCreate</method>
/// skip the resource default -- the ODBC probe reads <code>%Gateway_Object</code> and this goes red.</p>
Method TestTheExactPairsPrincipalCreatesEachTypeAndReadsItsForm()
{
    Set tUser = ..#EXACTUSER
    For tCase = $ListBuild("OcuPilotProbeELSEdJava", "{""Custom"":{""JVMArgs"":""-Xmx48m""}}", "%Gateway_Object"), $ListBuild("OcuPilotProbeELSEdPy", "{""Custom"":{""PythonOptions"":""-u""}}", "%Gateway_Object"), $ListBuild("OcuPilotProbeELSEdNet", "{""Custom"":{""DotNetVersion"":""N8.0"",""Exec32"":true}}", "%Gateway_Object"), $ListBuild("OcuPilotProbeELSEdRemote", "{""Custom"":{""Address"":""127.0.0.1""}}", "%Gateway_Object"), $ListBuild("OcuPilotProbeELSEdOdbc", "{""ConnectionTimeout"":7}", "%Gateway_SQL") {
        Set tName = $List(tCase, 1)
        Set tBody = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do tBody.%Set("Name", tName, "string")
        Do tBody.%Set("Type", ..ProbeType(tName), "string")
        Do tBody.%Set("Port", ..ProbePort(tName), "number")
        Set tSC = ..Call("POST", ..#CREATEPATH, tUser, tBody, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus, 201, tName _ ": the create answers 201: " _ ..Shown(tAnswer))
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", tName _ ": as JSON")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%GetTypeOf("readBack"), 1: ""), tName _ "|object", tName _ ": naming the server and its read-back")
        Do $$$AssertEquals(..Stored(tName, "Port") _ " " _ ..Stored(tName, "Resource"), ..ProbePort(tName) _ " " _ $List(tCase, 3), tName _ ": the instance holds its port and its type's resource")
    }
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdJava", "JVMArgs") _ "|" _ ..Stored("OcuPilotProbeELSEdNet", "DotNetVersion") _ "|" _ ..Stored("OcuPilotProbeELSEdNet", "Exec32") _ "|" _ ..Stored("OcuPilotProbeELSEdOdbc", "ConnectionTimeout"), "-Xmx48m|N8.0|1|7", "and the members and settings sent")
    Set tSC = ..Call("GET", "/screens/osmgmt.languageservers/read?maxRows=1000", tUser, "", .tStatus, .tRead, .tHeaders)
    Set tListed = ""
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) {
        Set tIterator = tRead.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $Extract(tRow.%Get("Name"), 1, 16) = "OcuPilotProbeELS" Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tRow.%Get("Name")
        }
    }
    Do $$$AssertEquals(tListed, "OcuPilotProbeELSEdJava,OcuPilotProbeELSEdNet,OcuPilotProbeELSEdOdbc,OcuPilotProbeELSEdPy,OcuPilotProbeELSEdRemote", "the list's read shows the rows the Saves created (AC9)")

    For tCase = "OcuPilotProbeELSEdJava:JVMArgs:ClassPath,JavaHome", "OcuPilotProbeELSEdPy:PythonOptions:PythonPath", "OcuPilotProbeELSEdNet:DotNetVersion,Exec32:FilePath", "OcuPilotProbeELSEdRemote:Address:", "OcuPilotProbeELSEdOdbc::" {
        Set tName = $Piece(tCase, ":", 1)
        Set tSC = ..Call("GET", ..#FORMPATH _ "?name=" _ ##class(%CSP.Page).EscapeURL(tName), tUser, "", .tStatus, .tForm, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tName _ ": its form reads")
        If '$IsObject(tForm) Continue
        Set tType = ..ProbeType(tName)
        Do $$$AssertEquals(tForm.server.Type _ " " _ tForm.server.Name _ " " _ tForm.running, tType _ " " _ tName _ " 0", tName _ ": the form answers the server, not running")
        Set tFields = tForm.typeFields.%Get(tType)
        Do $$$AssertEquals(..Joined(tFields.settable) _ ":" _ ..Joined(tFields.paths), $Piece(tCase, ":", 2, 3), tName _ ": its type's settable and path members, as the derived list names them (AC9)")
    }
    Do $$$AssertEquals($Select($IsObject($Get(tForm)): ..Joined(tForm.dotNetVersions) _ "|" _ ..Joined(tForm.requiredFields), 1: ""), "N8.0,N9.0,N10.0|Name,Type,Port", "the form read offers the .NET versions and names the create's required fields")
    Set tRule = ""
    If $IsObject($Get(tForm)) && $IsObject(tForm.rules) {
        Set tIterator = tForm.rules.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.code = ##class(OcuPilot.Api.LanguageServerError).#PORTREQUIRED Set tRule = tRow.field _ "|" _ tRow.reason
        }
    }
    Do $$$AssertEquals(tRule, "Port|" _ ##class(OcuPilot.Api.LanguageServerError).#REASONPORTREQUIRED, "and carries each rule on its field with its published sentence, the port's required one among them")
    Set tSC = ..Call("GET", ..#NAMEPATH _ "?name=OcuPilotProbeELSEdJava", tUser, "", .tStatus, .tTaken, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tTaken): tTaken.taken _ " " _ tTaken.reason, 1: ""), "200 1 " _ ..#TAKEN, "the name check answers a held name taken")
    Set tSC = ..Call("GET", ..#NAMEPATH _ "?name=ocupilotprobeelsedjava", tUser, "", .tStatus, .tTaken, .tHeaders)
    Do $$$AssertEquals($Select($IsObject(tTaken): tTaken.taken, 1: ""), 0, "and the same name in another case free, as the instance compares names")

    Set tSC = ..Call("POST", ..#CREATEPATH, tUser, {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": 53300, "Custom": {"JavaHome": "/opt/jdk"}}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 Custom.JavaHome:LANGUAGESERVER.CUSTOM.PATH", "a file location is refused on its field")
    Set tSC = ..Call("POST", ..#CREATEPATH, tUser, {"Name": "OcuPilotProbeELSEdJava", "Type": "Java", "Port": 53300}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 Name:LANGUAGESERVER.NAME.TAKEN", "a taken name is refused on Name")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdAgent", "Port") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "Port"), "|53294", "and neither refusal created or changed a server")
}

/// <p>AC2, AD-4's named exception: an edit of the port keeps every <code>Custom</code> member; a
/// <code>Custom</code> edit keeps the other members and the file locations; on a Python server an edit
/// that sends no <code>Custom</code> keeps the virtual-environment flag and PYTHONPATH, which the read
/// never answers, and a <code>Custom</code> edit resets them as the consequence line says; the type and
/// a file location are refused.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.LanguageServerUpdate.MergeUpdate</method>
/// keep an unchanged <code>Custom</code> in the body -- the Python server's hidden settings reset on the
/// timeout edit and this goes red.</p>
Method TestAnEditKeepsCustomAndAPythonCustomEditResetsItsHiddenSettings()
{
    Set tUser = ..#EXACTUSER
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdJava", "JVMArgs=-Xmx32m,ClassPath=/opt/lib/probe.jar"), "a Java probe with a class path is created")
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdPy", "PythonOptions=-u"), "a Python probe is created")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), tUser, {"Port": 53299}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the port edit answers 200: " _ ..Shown(tAnswer))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and reads back as sent")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdJava", "Port") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "JVMArgs") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "ClassPath"), "53299|-Xmx32m|/opt/lib/probe.jar", "the instance holds the new port and every Custom member as it was")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), tUser, {"Custom": {"JVMArgs": "-Xmx64m"}}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Stored("OcuPilotProbeELSEdJava", "JVMArgs") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "ClassPath") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "Port"), "200 -Xmx64m|/opt/lib/probe.jar|53299", "a Custom edit changes that member and keeps the class path and the port")

    Do $$$AssertStatusOK(..SeedHidden("OcuPilotProbeELSEdPy", "/opt/ocupilot/probe"), "the Python probe's classic-only settings are seeded")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdPy", "PythonCreateVirtualEnvironment") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonPathVar"), "0|/opt/ocupilot/probe", "the virtual environment is off and PYTHONPATH set")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdPy"), tUser, {"ConnectionTimeout": 9}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Stored("OcuPilotProbeELSEdPy", "ConnectionTimeout") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonCreateVirtualEnvironment") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonPathVar"), "200 9|0|/opt/ocupilot/probe", "an edit that sends no Custom keeps both")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdPy"), tUser, {"Custom": {"PythonOptions": "-B"}}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Stored("OcuPilotProbeELSEdPy", "PythonOptions") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonCreateVirtualEnvironment") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonPathVar"), "200 -B|1|", "a Custom edit turns the virtual environment back on and clears PYTHONPATH, as the consequence line says")

    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), tUser, {"Type": "Python"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer), "400 PORT.FIELD.UNEXPECTED", "the type is refused as not settable")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), tUser, {"LogFile": "/tmp/probe.log"}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 LogFile:LANGUAGESERVER.PATH", "a file location is refused on its field")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdJava", "Type") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "LogFile"), "Java|", "and neither changed the server")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdAbsent"), tUser, {"Port": 53302}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..Stored("OcuPilotProbeELSEdAbsent", "Port"), "404 LANGUAGESERVER.NAME.ABSENT ", "an edit of a server the instance does not define is 404 and creates nothing")
}

/// <p>AC6: a principal holding the screen's two pairs is refused its Save, its edit, its delete and
/// the agent's proposal, each 403 naming <code>%DB_IRISSYS:WRITE</code>; one holding that pair too is
/// refused each naming <code>%Admin_Manage:USE</code>; the instance is unchanged.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Manage:USE</code> from
/// <method>OcuPilot.Screen.Tool.LanguageServerCreate.PrivilegePairs</method> -- the write-pair
/// principal's create is admitted and this goes red.</p>
Method TestEachMissingPairIsRefusedByName()
{
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdJava", ""), "a Java probe is created")
    For tCase = $ListBuild(..#SCREENUSER, "%DB_IRISSYS:WRITE"), $ListBuild(..#WRITEUSER, "%Admin_Manage:USE") {
        Set tUser = $List(tCase, 1)
        Set tWanted = "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2)
        Set tSC = ..Call("POST", ..#CREATEPATH, tUser, {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": 53300}, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..FailedPair(tAnswer), tWanted, tUser _ ": the create is refused naming the pair")
        Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), tUser, {"Port": 53299}, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..FailedPair(tAnswer), tWanted, tUser _ ": the edit is refused naming the pair")
        Set tSC = ..Act("delete", "OcuPilotProbeELSEdJava", tUser, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..FailedPair(tAnswer), tWanted, tUser _ ": the delete is refused naming the pair")
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "running", .tTurn)
        Do $$$AssertStatusOK(tSC, tUser _ ": a running turn is seeded")
        Set tPlan = []
        Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurn), "tool": "osmgmt.languageservers.create", "input": {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": "53300"}})
        Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurn), "tool": "osmgmt.languageservers.update", "input": {"Name": "OcuPilotProbeELSEdJava", "Port": "53299"}})
        Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurn), "tool": "osmgmt.languageservers.delete", "input": {"Name": "OcuPilotProbeELSEdJava"}})
        Set tRun = ##class(OcuPilot.Test.MappingWriteGate).RunAs(tUser, tPlan)
        For tI = 1:1:3 {
            Set tLeg = ##class(OcuPilot.Test.MappingWriteGate).Leg(tRun, tI)
            Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair"), 1: "absent"), tWanted, tUser _ ": the agent's " _ tPlan.%Get(tI - 1).%Get("tool") _ " is refused naming the pair")
        }
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdJava", "Port") _ "|" _ ..Stored("OcuPilotProbeELSEdAgent", "Port"), "53294|", "the instance is unchanged: the probe keeps its port and nothing was created")
}

/// <p>AC4, AC6, AD-8 as amended: the exact-pairs principal's delete of a Python server is refused 403
/// naming <code>%System_CallOut:USE</code> with the server and its settings intact, while its deletes
/// of a Java and a Remote server through the list's row action remove each from the instance and from
/// the list.</p>
/// <p>Mutation (Rule 19): drop the call-out gate from
/// <method>OcuPilot.Port.LanguageServerPort.Invoke</method> -- the Python delete reaches the vendor and
/// this goes red. Add a pair to <method>OcuPilot.Screen.Tool.LanguageServerDelete.PrivilegePairs</method>
/// -- the Java and Remote deletes are refused and this goes red.</p>
Method TestAPythonDeleteNeedsCallOutAndAStoppedServerIsDeleted()
{
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdPy", "PythonOptions=-u"), "a Python probe is created")
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdRemote", "Address=127.0.0.1"), "a Remote probe is created")
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdJava", "JVMArgs=-Xmx32m"), "a Java probe is created")
    Set tSC = ..Act("delete", "OcuPilotProbeELSEdPy", ..#EXACTUSER, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..FailedPair(tAnswer), "403 AUTH.NOPRIVILEGE %System_CallOut:USE", "the Python delete is refused naming the call-out pair")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdPy", "Type") _ "|" _ ..Stored("OcuPilotProbeELSEdPy", "PythonOptions"), "Python|-u", "and the server is intact")
    For tName = "OcuPilotProbeELSEdJava", "OcuPilotProbeELSEdRemote" {
        Set tSC = ..Act("delete", tName, ..#EXACTUSER, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tName _ ": the delete answers 200: " _ ..Shown(tAnswer))
        If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("target")) Do $$$AssertEquals(tAnswer.%Get("action") _ " " _ tAnswer.%Get("target").%Get("id"), "deleted " _ tName, tName _ ": publishing the deleted event for the server")
        Do $$$AssertEquals(..Stored(tName, "Type"), "", tName _ ": the server is gone from the instance")
    }
    Set tSC = ..Call("GET", "/screens/osmgmt.languageservers/read?maxRows=1000", ..#EXACTUSER, "", .tStatus, .tRead, .tHeaders)
    Do $$$AssertTrue($IsObject(tRead) && '(tRead.%ToJSON() [ "OcuPilotProbeELSEdRemote") && '(tRead.%ToJSON() [ "OcuPilotProbeELSEdJava"), "and both are gone from the list")
}

/// <p>AC3: a started Java probe's form reads running; its edit is refused 409 with the published
/// sentence and its delete 400 with the same sentence, the port unchanged and the server defined; the
/// agent's edit and delete minted while it runs are each refused at the mint with that sentence; and a
/// delete minted while it was stopped is refused at Confirm once it has started.</p>
/// <p>Mutation (Rule 19): drop the running refusal from
/// <method>OcuPilot.Screen.Tool.LanguageServerUpdate.MergeUpdate</method> -- the edit reaches the vendor
/// and this goes red. Let <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> store a proposal whose
/// state diff refused -- the agent's delete is minted and this goes red.</p>
Method TestAStartedServerIsRefusedEditAndDelete()
{
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdJava", ""), "a Java probe is created")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Set tSC = ..Mint(..#DELETE, "OcuPilotProbeELSEdJava", {"Name": "OcuPilotProbeELSEdJava"}, tTurn, .tStopped)
    Do $$$AssertStatusOK(tSC, "a delete is minted while the server is stopped: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertStatusOK(..Start("OcuPilotProbeELSEdJava"), "the probe is started")
    Do $$$AssertEquals(..Running("OcuPilotProbeELSEdJava"), 1, "and runs")
    Set tSC = ..Call("GET", ..#FORMPATH _ "?name=OcuPilotProbeELSEdJava", ..#EXACTUSER, "", .tStatus, .tForm, .tHeaders)
    Do $$$AssertEquals($Select($IsObject(tForm): tForm.running, 1: ""), 1, "its form reads it running, so the editor opens read-only")
    Set tSC = ..Call("PUT", ..Edit("OcuPilotProbeELSEdJava"), ..#EXACTUSER, {"Port": 53299}, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "409 LANGUAGESERVER.RUNNING " _ ..#RUNNING, "its edit is refused with the published sentence")
    Set tSC = ..Act("delete", "OcuPilotProbeELSEdJava", ..#EXACTUSER, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ..Problem(tAnswer), "400 TOOL.ARGUMENTS " _ ..#RUNNING, "its delete is refused with the same sentence")
    Set tSC = ..Mint(..#UPDATE, "OcuPilotProbeELSEdJava", {"Name": "OcuPilotProbeELSEdJava", "Port": "53299"}, tTurn, .tProposal, .tHttp)
    Do $$$AssertTrue($$$ISERR(tSC) && ($System.Status.GetErrorText(tSC) [ ..#RUNNING) && (tHttp = 400), "the agent's edit is refused 400 at the mint: " _ tHttp _ " " _ $System.Status.GetErrorText(tSC))
    Set tSC = ..Mint(..#DELETE, "OcuPilotProbeELSEdJava", {"Name": "OcuPilotProbeELSEdJava"}, tTurn, .tProposal, .tHttp)
    Do $$$AssertTrue($$$ISERR(tSC) && ($System.Status.GetErrorText(tSC) [ ..#RUNNING) && (tHttp = 400) && '$IsObject(tProposal), "the agent's delete is refused 400 at the mint: " _ tHttp _ " " _ $System.Status.GetErrorText(tSC))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tStopped)): tStopped.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the delete minted while stopped is refused at Confirm")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdJava", "Port"), 53294, "and the server keeps its port and its definition")
    Do ..StopOutOfBand("OcuPilotProbeELSEdJava")
    Do $$$AssertEquals(..Running("OcuPilotProbeELSEdJava"), 0, "the probe is stopped")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5, AD-54: the agent's create, update and delete are minted and confirmed as the screen's own
/// operations; a create whose name was taken since the mint is refused at Confirm, the other server
/// unchanged; and a create of a name the instance already holds is refused 400 at the mint.</p>
/// <p>Mutation (Rule 19): empty the create's absence fingerprint in
/// <method>OcuPilot.Kernel.Proposal.Mint.AbsenceState</method> -- the taken name's confirm upserts the
/// other server and this goes red. Skip the present-target refusal of a create in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -- the taken name is minted and this goes
/// red.</p>
Method TestTheAgentsWritesConfirmAndATakenNameIsRefusedAtConfirm()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tSC = ..Mint(..#CREATE, "OcuPilotProbeELSEdAgent", {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": "53300", "Custom": {"JVMArgs": "-Xmx40m"}}, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's create mints: " _ $System.Status.GetErrorText(tSC))
    If $IsObject($Get(tProposal)) Do $$$AssertTrue(tProposal.%Get("changed").%ToJSON() [ """field"":""Resource"",""before"":"""",""after"":""%Gateway_Object""", "its card shows the default resource as a row")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirms: " _ $Get(tCode))
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdAgent", "Port") _ "|" _ ..Stored("OcuPilotProbeELSEdAgent", "JVMArgs"), "53300|-Xmx40m", "the server exists with what was proposed")
    Set tSC = ..Mint(..#UPDATE, "OcuPilotProbeELSEdAgent", {"Name": "OcuPilotProbeELSEdAgent", "Port": "53302"}, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's edit mints")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdAgent", "Port") _ "|" _ ..Stored("OcuPilotProbeELSEdAgent", "JVMArgs"), "53302|-Xmx40m", "its confirm moves the port and keeps Custom")
    Set tSC = ..Mint(..#DELETE, "OcuPilotProbeELSEdAgent", {"Name": "OcuPilotProbeELSEdAgent"}, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's delete mints")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdAgent", "Type"), "", "its confirm deletes the server")

    Set tSC = ..Mint(..#CREATE, "OcuPilotProbeELSEdTaken", {"Name": "OcuPilotProbeELSEdTaken", "Type": "Java", "Port": "53301"}, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "a create is minted for a free name")
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdTaken", "Port=53303"), "which is then taken out of band")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the create's confirm is refused as a moved target")
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdTaken", "Port"), 53303, "and the other server is unchanged")
    Set tSC = ..Mint(..#CREATE, "OcuPilotProbeELSEdTaken", {"Name": "OcuPilotProbeELSEdTaken", "Type": "Java", "Port": "53301"}, tTurn, .tProposal, .tHttp)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($System.Status.GetErrorText(tSC) [ "'OcuPilotProbeELSEdTaken' is already present on this instance") && '$IsObject(tProposal), "a create of the name the instance now holds is refused 400 at the mint: " _ tHttp _ " " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdTaken", "Port"), 53303, "and that server is still unchanged")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5, the I/O matrix's out-of-range, path and type rows: a create with no port, a port of 70000 or
/// an initialization timeout of 301, an edit with a connection timeout of 301, an edit naming a file
/// location in <code>Custom</code> or at the top level, and an edit naming <code>Type</code> are each
/// refused on its field -- the person's Save 422 with the published sentence, the agent's call
/// <code>TOOL.ARGUMENTS</code> naming the field and that sentence, the agent's mint 400 -- and none
/// reaches the instance.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.LanguageServerRules.Whole</method> accept every
/// value -- the port and timeout legs of both callers go red.</p>
Method TestAFieldOutsideItsRulesIsRefusedOnItsField()
{
    Do $$$AssertStatusOK(..CreateProbe("OcuPilotProbeELSEdJava", "JVMArgs=-Xmx32m,ConnectionTimeout=5"), "a Java probe is created")
    Set tRange = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#PORTRANGE)
    Set tTimeout = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#INITIALIZATIONTIMEOUTRANGE)
    Set tPath = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#CUSTOMPATH)

    ; The person's Save: one 422 violation on the field, carrying the published sentence.
    Set tCases = 0
    Set tCases($Increment(tCases)) = $ListBuild("POST", ..#CREATEPATH, {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java"}.%ToJSON(), "Port:" _ ##class(OcuPilot.Api.LanguageServerError).#PORTREQUIRED, ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#PORTREQUIRED))
    Set tCases($Increment(tCases)) = $ListBuild("POST", ..#CREATEPATH, {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": 70000}.%ToJSON(), "Port:" _ ##class(OcuPilot.Api.LanguageServerError).#PORTRANGE, tRange)
    Set tCases($Increment(tCases)) = $ListBuild("POST", ..#CREATEPATH, {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": 53300, "InitializationTimeout": 301}.%ToJSON(), "InitializationTimeout:" _ ##class(OcuPilot.Api.LanguageServerError).#INITIALIZATIONTIMEOUTRANGE, tTimeout)
    Set tCases($Increment(tCases)) = $ListBuild("PUT", ..Edit("OcuPilotProbeELSEdJava"), {"ConnectionTimeout": 301}.%ToJSON(), "ConnectionTimeout:" _ ##class(OcuPilot.Api.LanguageServerError).#CONNECTIONTIMEOUTRANGE, tTimeout)
    For tI = 1:1:tCases {
        Set tCase = tCases(tI)
        Set tSC = ..Call($List(tCase, 1), $List(tCase, 2), ..#EXACTUSER, ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer) _ " " _ ..ViolationReason(tAnswer), "422 " _ $List(tCase, 4) _ " " _ $List(tCase, 5), "the Save of " _ $List(tCase, 3) _ " is refused on its field")
    }

    ; The agent's call, through the dispatcher a turn uses: TOOL.ARGUMENTS, naming the field.
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tCases = 0
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.create", {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java"}.%ToJSON(), "Port")
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.create", {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": "70000"}.%ToJSON(), "'Port': " _ tRange)
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.create", {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": "53300", "InitializationTimeout": "301"}.%ToJSON(), "'InitializationTimeout': " _ tTimeout)
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.update", {"Name": "OcuPilotProbeELSEdJava", "ConnectionTimeout": "301"}.%ToJSON(), "'ConnectionTimeout': " _ tTimeout)
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.update", {"Name": "OcuPilotProbeELSEdJava", "Custom": {"JavaHome": "/opt/jdk"}}.%ToJSON(), "'Custom.JavaHome': " _ tPath)
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.update", {"Name": "OcuPilotProbeELSEdJava", "LogFile": "/tmp/probe.log"}.%ToJSON(), "LogFile")
    Set tCases($Increment(tCases)) = $ListBuild("osmgmt.languageservers.update", {"Name": "OcuPilotProbeELSEdJava", "Type": "Python"}.%ToJSON(), "Type")
    For tI = 1:1:tCases {
        Set tCase = tCases(tI)
        Set tContent = ..Dispatched(tTurn, $List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)))
        Set tProblem = $Select($IsObject(tContent) && $IsObject(tContent.%Get("detail")): tContent.%Get("detail").%Get("problem"), 1: "")
        Do $$$AssertTrue($IsObject(tContent) && (tContent.%Get("code") = ##class(OcuPilot.Api.Error).#TOOLARGUMENTS) && (tProblem [ $List(tCase, 3)), "the agent's " _ $List(tCase, 1) _ " of " _ $List(tCase, 2) _ " is refused on " _ $List(tCase, 3) _ ": " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: ""))
    }
    Set tSC = ..Mint(..#CREATE, "OcuPilotProbeELSEdAgent", {"Name": "OcuPilotProbeELSEdAgent", "Type": "Java", "Port": "70000"}, tTurn, .tProposal, .tHttp)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($System.Status.GetErrorText(tSC) [ ("'Port': " _ tRange)) && '$IsObject(tProposal), "the agent's mint of a port of 70000 is refused 400 naming the field: " _ tHttp _ " " _ $System.Status.GetErrorText(tSC))

    Do $$$AssertEquals(..Stored("OcuPilotProbeELSEdAgent", "Type") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "Type") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "ConnectionTimeout") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "LogFile") _ "|" _ ..Stored("OcuPilotProbeELSEdJava", "JavaHome"), "|Java|5||", "none reached the instance: nothing was created and the probe is unchanged")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Send one tool call through <class>OcuPilot.Kernel.Agent.Dispatch</class> as the caller, over turn
/// <var>pTurn</var>, and answer the refusal's parsed content, or <code>""</code> when the call was
/// answered.</p>
Method Dispatched(pTurn As %String, pTool As %String, pInput As %DynamicObject) As %DynamicObject
{
    Set tUse = {"type": "tool_use", "id": "toolu_languageserver"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) || '$IsObject($Get(tResults)) || (tResults.%Size() '= 1) Quit ""
    If 'tResults.%Get(0).%Get("is_error") Quit ""
    Set tContent = ""
    Try { Set tContent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")) } Catch { Set tContent = "" }
    Quit tContent
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> with <var>pArgs</var> as the caller, in
/// turn <var>pTurn</var>; <var>pHttp</var> is the mint's HTTP status.</p>
Method Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, pTurn As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurn, pArgs, ..#LIMITS, .pProposal, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>One request over the wire as <var>pUser</var>, answering the HTTP status, the parsed envelope and
/// the headers.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody, Output pStatus As %Integer, Output pAnswer, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Kill pHeaders
    Kill tExtra
    Set tJson = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, pUser, ..PreparedPassword, .pStatus, .tRaw, .pHeaders, tJson, $Select(tJson = "": "", 1: "application/json"), .tExtra, ..#TIMEOUT)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>One row action on the list as <var>pUser</var>.</p>
Method Act(pAction As %String, pName As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pName, "string")
    Quit ..Call("POST", "/screens/osmgmt.languageservers/action", pUser, tBody, .pStatus, .pAnswer, .tHeaders)
}

/// <p>The edit route for server <var>pName</var>, its id encoded once as one segment (AD-13).</p>
ClassMethod Edit(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p>A probe's type and port, as <parameter>PROBES</parameter> declares them.</p>
ClassMethod ProbeType(pName As %String) As %String
{
    Quit $Piece(..ProbeEntry(pName), ":", 2)
}

ClassMethod ProbePort(pName As %String) As %Integer
{
    Quit +$Piece(..ProbeEntry(pName), ":", 3)
}

ClassMethod ProbeEntry(pName As %String) As %String
{
    For tI = 1:1:$Length(..#PROBES, ",") {
        If $Piece($Piece(..#PROBES, ",", tI), ":", 1) = pName Quit
    }
    Quit $Piece(..#PROBES, ",", tI)
}

/// <p>Server <var>pName</var>'s <var>pProperty</var> as <code>Config.Gateways</code> holds it, or
/// <code>""</code> for a server the instance does not define.</p>
ClassMethod Stored(pName As %String, pProperty As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        If ##class(Config.Gateways).Exists(pName) {
            Do ##class(Config.Gateways).Get(pName, .tProperties)
            Set tValue = $Get(tProperties(pProperty))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>Create probe <var>pName</var> of its declared type and port through <code>Config.Gateways</code>,
/// with the comma-separated <code>property=value</code> settings <var>pSettings</var>, replacing a probe
/// an earlier run left.</p>
Method CreateProbe(pName As %String, pSettings As %String) As %Status
{
    Set tSC = ..RemoveProbe(pName)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Type") = ..ProbeType(pName)
        Set tProperties("Port") = ..ProbePort(pName)
        For tI = 1:1:$Length(pSettings, ",") {
            Set tSetting = $Piece(pSettings, ",", tI)
            If tSetting '= "" Set tProperties($Piece(tSetting, "=", 1)) = $Piece(tSetting, "=", 2, *)
        }
        Set tSC = ##class(Config.Gateways).Create(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Seed Python probe <var>pName</var>'s classic-only settings through <code>Config.Gateways</code>:
/// the virtual environment off and PYTHONPATH <var>pPath</var>.</p>
Method SeedHidden(pName As %String, pPath As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("PythonCreateVirtualEnvironment") = 0
        Set tProperties("PythonPathVar") = pPath
        Set tSC = ##class(Config.Gateways).Modify(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Start server <var>pName</var> through the port as the caller, not through OcuPilot's write
/// path.</p>
Method Start(pName As %String) As %Status
{
    Kill tQuery
    Set tQuery("name") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "START", .tQuery, "", .tAnswer, .tHttp, .tFault)
}

/// <p>Stop server <var>pName</var> through the port as the caller.</p>
Method StopOutOfBand(pName As %String)
{
    Kill tQuery
    Set tQuery("name") = pName
    Do ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "STOP", .tQuery, "", .tAnswer, .tHttp, .tFault)
}

/// <p>Whether the instance reports server <var>pName</var> running: 1 or 0, or -1 when the read
/// fails.</p>
Method Running(pName As %String) As %Integer
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tQuery("maxRows") = 1
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("LanguageServer", "ACTIVITY", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tAnswer)) || (tAnswer.%GetTypeOf("CurrentlyRunning") '= "boolean") Quit -1
    Quit ''tAnswer.%Get("CurrentlyRunning")
}

/// <p>Stop, delete and remove the activity rows of every probe in <parameter>PROBES</parameter>; an
/// error when one still runs or survives.</p>
Method RemoveProbes() As %Status
{
    Set tSC = $$$OK
    For tI = 1:1:$Length(..#PROBES, ",") {
        Set tSC = $$$ADDSC(tSC, ..RemoveProbe($Piece($Piece(..#PROBES, ",", tI), ":", 1)))
    }
    Quit tSC
}

/// <p>Stop probe server <var>pName</var>, delete it and remove its activity rows; OK when it is absent,
/// and an error, deleting nothing, when it still reads running after the stop, because a deleted
/// running server keeps listening.</p>
Method RemoveProbe(pName As %String) As %Status
{
    Set tSC = $$$OK
    If $Extract(pName, 1, 16) '= "OcuPilotProbeELS" Quit $$$ERROR($$$GeneralError, "only a probe server is removed")
    If ..Stored(pName, "Type") = "" Quit ..RemoveActivity(pName)
    Do ..StopOutOfBand(pName)
    If ..Running(pName) = 1 Quit $$$ERROR($$$GeneralError, "the probe server " _ pName _ " still reads running after its stop, so it was not deleted")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Gateways).Exists(pName) Set tSC = ##class(Config.Gateways).Delete(pName)
        If $$$ISOK(tSC) && ##class(Config.Gateways).Exists(pName) Set tSC = $$$ERROR($$$GeneralError, "the probe server " _ pName _ " is still defined")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ..RemoveActivity(pName)
}

/// <p>Remove probe <var>pName</var>'s activity rows.</p>
Method RemoveActivity(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %Net_Remote.ActivityLog WHERE %EXACT(GatewayName) = ?", pName)
        If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the probe's activity rows were not removed: SQLCODE " _ tResult.%SQLCODE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tScreen = tCode _ ",%Admin_ExternalLanguageServerEdit:U,%DB_IRISSYS:R"
        For tCase = $ListBuild(..#SCREENUSER, tScreen), $ListBuild(..#WRITEUSER, tCode _ ",%Admin_ExternalLanguageServerEdit:U,%DB_IRISSYS:RW"), $ListBuild(..#EXACTUSER, tCode _ ",%Admin_ExternalLanguageServerEdit:U,%DB_IRISSYS:RW,%Admin_Manage:U") {
            Set tUser = $List(tCase, 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the language server editor (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot language server editor test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LanguageServerEditorWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild(..#SCREENUSER, 0, 0), $ListBuild(..#WRITEUSER, 0, 1), $ListBuild(..#EXACTUSER, 1, 1) {
            Set tUser = $List(tCase, 1)
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_ExternalLanguageServerEdit", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Manage", "USE") '= $List(tCase, 2)) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") '= $List(tCase, 3)) || ($SYSTEM.Security.CheckUserPermission(tUser, "%System_CallOut", "USE") = 1) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p><var>pArray</var>'s strings, comma-joined.</p>
ClassMethod Joined(pArray) As %String
{
    If '$IsObject(pArray) Quit ""
    Set tText = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tValue
    }
    Quit tText
}

/// <p>The first violation an envelope <var>pBody</var> carries, as <code>field:code</code>.</p>
ClassMethod Violation(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) || '$IsObject(pBody.%Get("detail").%Get("violations")) Quit ""
    Set tRow = pBody.%Get("detail").%Get("violations").%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.%Get("field") _ ":" _ tRow.%Get("code")
}

/// <p>The sentence the first violation an envelope <var>pBody</var> carries.</p>
ClassMethod ViolationReason(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) || '$IsObject(pBody.%Get("detail").%Get("violations")) Quit ""
    Set tRow = pBody.%Get("detail").%Get("violations").%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.%Get("reason")
}

ClassMethod Code(pBody) As %String
{
    Quit ##class(OcuPilot.Test.LanguageServerWire).Code(pBody)
}

ClassMethod Problem(pBody) As %String
{
    Quit ##class(OcuPilot.Test.LanguageServerWire).Problem(pBody)
}

ClassMethod FailedPair(pBody) As %String
{
    Quit ##class(OcuPilot.Test.LanguageServerWire).FailedPair(pBody)
}

ClassMethod Shown(pBody) As %String
{
    Quit ##class(OcuPilot.Test.LanguageServerWire).Shown(pBody)
}

}
