/// <p>Pins Story 23.12 (AD-5, AD-11, AD-35, AD-36): what the model is told when it chooses a list. Every
/// read tool in the production listing names its screen's title, what one row is and the fields the read
/// answers; each tool of a confusable group carries its declared label, and a label names only tools the
/// listing advertises; <code>shell.tools.find</code> answers the same description the registry composes;
/// and the built-in prompt carries the three rules for answering that no list holds something.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>. It reads the
/// production registry, descriptors and prompt, runs one discovery search and two reads of this instance
/// (the license key and the users list, each of which always has rows), writes nothing and needs no
/// arming.</p>
Class OcuPilot.Test.ReadDescriptions Extends %UnitTest.TestCase
{

/// <p>The class tool that reads the application error log, the one read outside the descriptors.</p>
Parameter ERRORTOOL = "logs.applicationerrors.read";

Parameter ERRORCLASS = "OcuPilot.Screen.Tool.ErrorRead";

Parameter RULEONE = "When more than one list could hold the answer, read each likely one before you answer that there is none.";

Parameter RULETWO = "Never say that a list lacks a field or a status until you have read it; each read tool's description names the fields it returns.";

Parameter RULETHREE = "When you find nothing, name the lists you checked, by their screen titles.";

/// <p>The sentence the rules follow, and the one that follows them.</p>
Parameter PRECEDING = "say so rather than describe a capability you lack.";

Parameter FOLLOWING = "When the user asks you to explain this screen";

/// <p>The confusable groups: the read tools, by tool identifier, whose lists a model can mistake for one
/// another, so that reading the wrong one answers "none". Each carries a declared label.</p>
XData Groups
{
{
  "Tasks": ["tasks.schedule", "tasks.ondemand", "tasks.upcoming", "tasks.history", "tasks.taskhistory", "tasks.background", "logs.taskerrors"],
  "Databases": ["osmgmt.databases", "osmgmt.localdatabases", "osmgmt.remotedatabases", "osmgmt.databasefreespace", "osmgmt.ecpdataservers", "explorer.docdb"],
  "Logs": ["logs.messages", "logs.applicationerrors", "logs.alerts", "logs.systemmonitor", "logs.xdbc", "logs.sqldiagnostics", "logs.eventlog", "logs.analytics", "logs.hub", "logs.audit", "osmgmt.integritylog", "interop.messages"],
  "Processes": ["osmgmt.processes", "osmgmt.activeprocesses", "interop.processes", "interop.jobs"],
  "Audit": ["security.auditsystemevents", "security.audituserevents", "security.auditing"],
  "SQL statements": ["osmgmt.sqlactivity", "explorer.sqltablestatements", "explorer.sqlviewstatements", "explorer.sqlprocedurestatements"],
  "SQL schema objects": ["explorer.sqlschematables", "explorer.sqlschemaviews", "explorer.sqlschemaprocedures"]
}
}

/// <p>The confusable groups as <var>pRoster</var>, subscripted by tool identifier, each node holding its
/// group's name.</p>
ClassMethod Roster(Output pRoster) As %Status
{
    Set tSC = $$$OK
    Kill pRoster
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Groups", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Groups XData block is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set tGroups = ##class(%DynamicObject).%FromJSON(tXData.Data)
        Set tGroupIterator = tGroups.%GetIterator()
        While tGroupIterator.%GetNext(.tGroup, .tTools) {
            Set tToolIterator = tTools.%GetIterator()
            While tToolIterator.%GetNext(.tIndex, .tId) {
                Set pRoster(tId) = tGroup
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every read tool the production registry lists, into <var>pReads</var>:
/// <code>pReads(name)</code> = <code>$ListBuild(descriptorClass, description)</code>. A tool the read
/// tool class derives from a descriptor qualifies, and so does the application error log's class tool.</p>
ClassMethod Reads(Output pReads) As %Status
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Kill pReads
    If $$$ISERR(tSC) Quit tSC
    Set tReadClass = ##class(OcuPilot.Screen.Tool.Registry).ReadToolClass()
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tDerived = (tTool.%Get("class") = tReadClass) && (tTool.%Get("descriptor") '= "")
        If 'tDerived && (tTool.%Get("name") '= ..#ERRORTOOL) Continue
        Set pReads(tTool.%Get("name")) = $ListBuild(tTool.%Get("descriptor"), ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tTool))
    }
    Quit tSC
}

/// <p>The descriptors that declare a read, into <var>pLabels</var> subscripted by tool identifier, each
/// node holding the descriptor's declared <code>label</code> or <code>""</code>; and the application error
/// log's own <code>LABEL</code> under its identifier. <var>pClasses</var> is the same subscripts mapped
/// to the descriptor class.</p>
ClassMethod Declared(Output pLabels, Output pClasses) As %Status
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Kill pLabels, pClasses
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tClass = $List(tDescriptors, tI)
        Set tRead = $ClassMethod(tClass, "Read")
        If '$IsObject(tRead) Continue
        Set tId = $ClassMethod(tClass, "ToolIdentifier")
        Set pClasses(tId) = tClass
        Set pLabels(tId) = $Select(tRead.%GetTypeOf("label") = "string": tRead.%Get("label"), 1: "")
    }
    Set tErrorId = $Piece(..#ERRORTOOL, ".", 1, 2)
    Set pClasses(tErrorId) = $Parameter(..#ERRORCLASS, "DESCRIPTORCLASS")
    Set pLabels(tErrorId) = $Parameter(..#ERRORCLASS, "LABEL")
    Quit tSC
}

/// <p>The names in <var>pAnswered</var> joined by a comma and a space, as a description lists them.</p>
ClassMethod FieldsText(pAnswered As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pAnswered.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tField
    }
    Quit tText
}

/// <p>The generated <code>Titles</code> XData as a <class>%DynamicObject</class>, read from the compiled class
/// directly, so that the title a screen is expected to carry does not pass through the code under test.
/// <code>""</code> when the XData cannot be read.</p>
ClassMethod GeneratedTitles() As %DynamicAbstractObject
{
    Set tTitles = ""
    Set tXData = ##class(%Dictionary.CompiledXData).%OpenId("OcuPilot.Screen.Titles||Titles")
    If $IsObject(tXData) {
        Do tXData.Data.Rewind()
        Set tTitles = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    }
    Quit tTitles
}

/// <p>The description the tool <var>pId</var> is expected to carry, restated from its declarations
/// without <method>OcuPilot.Screen.Tool.Read.Compose</method>: the title <var>pTitles</var> holds for the
/// screen's <code>labelKey</code>, ", one &lt;row&gt; per row" when a row is declared, ", bounded and with
/// secret fields removed.", the label, "Fields:" and the answered fields, and the note last. The application
/// error log's tool takes its parts from <parameter>ERRORCLASS</parameter>. <var>pClass</var> is the
/// descriptor class from <method>Declared</method>.</p>
ClassMethod ExpectedText(pId As %String, pClass As %String, pTitles As %DynamicAbstractObject) As %String
{
    If pId = $Piece(..#ERRORTOOL, ".", 1, 2) {
        Set tRow = $Parameter(..#ERRORCLASS, "ROW")
        Set tLabel = $Parameter(..#ERRORCLASS, "LABEL")
        Set tFields = $Replace($Parameter(..#ERRORCLASS, "SUMMARYFIELDS"), ",", ", ")
        Set tNote = $Parameter(..#ERRORCLASS, "DESCRIPTION")
    } Else {
        Set tRead = $ClassMethod(pClass, "Read")
        Set tRow = $Select(tRead.%GetTypeOf("row") = "string": tRead.%Get("row"), 1: "")
        Set tLabel = $Select(tRead.%GetTypeOf("label") = "string": tRead.%Get("label"), 1: "")
        Set tFields = ..FieldsText(##class(OcuPilot.Screen.Read).AnsweredFields(pClass))
        Set tNote = $Select(tRead.%GetTypeOf("note") = "object": tRead.%Get("note").%Get("text"), 1: "")
    }
    Set tText = "Read the rows of the " _ pTitles.%Get($ClassMethod(pClass, "LabelKey")) _ " screen (" _ pId _ ")"
    If tRow '= "" Set tText = tText _ ", one " _ tRow _ " per row"
    Set tText = tText _ ", bounded and with secret fields removed."
    If tLabel '= "" Set tText = tText _ " " _ tLabel
    If tFields '= "" Set tText = tText _ " Fields: " _ tFields _ "."
    If tNote '= "" Set tText = tText _ " " _ tNote
    Quit tText
}

/// <p>AC1 and AC6: every read tool's description holds its screen's title, "one &lt;row&gt; per row", the
/// fields its read answers with no secret field among them, and its note last. The title is the string the
/// generated <code>Titles</code> XData holds for the descriptor's <code>labelKey</code>, and never the key.
/// The roster is equal to the descriptors that declare a read, plus the application error log's tool, so a
/// descriptor with no tool and a tool with no descriptor are both named.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.Read.Compose</method> omits the "Fields:" clause for
/// <code>tasks.schedule</code> -- this goes red naming it; <method>OcuPilot.Screen.Read.AnsweredFields</method>
/// keeps secret fields -- this goes red at <code>osmgmt.licensekey</code>;
/// <method>OcuPilot.Screen.Tool.Read.Title</method> answers the label key -- this goes red on every tool;
/// <method>OcuPilot.Screen.Tool.Read.Compose</method> omits the row clause -- this goes red on every tool.</p>
Method TestEveryReadToolNamesItsTitleRowAndFields()
{
    Set tSC = ..Reads(.tReads)
    Do $$$AssertStatusOK(tSC, "the production listing is read")
    Set tDeclaredSC = ..Declared(.tLabels, .tClasses)
    Do $$$AssertStatusOK(tDeclaredSC, "the descriptors are read")
    Set tTitles = ..GeneratedTitles()
    Do $$$AssertTrue($IsObject(tTitles), "the generated Titles XData is read")
    If $$$ISERR(tSC) || $$$ISERR(tDeclaredSC) || '$IsObject(tTitles) Quit
    Set tListed = 0
    Set tName = ""
    For {
        Set tName = $Order(tReads(tName))
        If tName = "" Quit
        Set tListed = tListed + 1
    }
    Set tId = ""
    Set tChecked = 0
    Set tSecrets = 0
    Set tNoted = 0
    For {
        Set tId = $Order(tClasses(tId))
        If tId = "" Quit
        Set tClass = tClasses(tId)
        Set tName = tId _ ".read"
        If '$Data(tReads(tName)) {
            Do $$$AssertTrue(0, tName _ " is in the production listing")
            Continue
        }
        Set tChecked = tChecked + 1
        Set tDescription = $List(tReads(tName), 2)
        Set tTitle = ##class(OcuPilot.Screen.Tool.Read).Title(tClass)
        Set tKey = $ClassMethod(tClass, "LabelKey")
        Set tGenerated = tTitles.%Get(tKey)
        Do $$$AssertTrue((tGenerated '= "") && (tGenerated '= tKey), tName _ ": the generated Titles XData holds a string for " _ tKey _ " that is not the key")
        Do $$$AssertEquals(tTitle, tGenerated, tName _ ": its title is the generated string for " _ tKey)
        Do $$$AssertEquals($Extract(tDescription, 1, $Length("Read the rows of the " _ tTitle _ " screen (" _ tId _ ")")), "Read the rows of the " _ tTitle _ " screen (" _ tId _ ")", tName _ ": it opens with the screen's title and the tool identifier")
        If tId = $Piece(..#ERRORTOOL, ".", 1, 2) {
            Set tRow = $Parameter(..#ERRORCLASS, "ROW")
            Set tFields = $Replace($Parameter(..#ERRORCLASS, "SUMMARYFIELDS"), ",", ", ")
            Set tNote = $Parameter(..#ERRORCLASS, "DESCRIPTION")
            Set tSecretFields = ""
        } Else {
            Set tRead = $ClassMethod(tClass, "Read")
            Set tRow = $Select(tRead.%GetTypeOf("row") = "string": tRead.%Get("row"), 1: "")
            Set tFields = ..FieldsText(##class(OcuPilot.Screen.Read).AnsweredFields(tClass))
            Set tNote = $Select(tRead.%GetTypeOf("note") = "object": tRead.%Get("note").%Get("text"), 1: "")
            Set tSecretFields = $ClassMethod(tClass, "ContextSecretFields")
        }
        Do $$$AssertTrue(tRow '= "", tName _ ": it declares what one row is")
        Do $$$AssertTrue(tDescription [ (", one " _ tRow _ " per row, bounded and with secret fields removed."), tName _ ": it says one " _ tRow _ " per row")
        Do $$$AssertTrue(tFields '= "", tName _ ": it answers fields")
        Do $$$AssertTrue(tDescription [ (" Fields: " _ tFields _ "."), tName _ ": it lists the fields its read answers: " _ tFields)
        Set tAnswered = $ListFromString(tFields, ", ")
        For tK = 1:1:$ListLength(tSecretFields) {
            Set tSecrets = tSecrets + 1
            Do $$$AssertEquals($ListFind(tAnswered, $List(tSecretFields, tK)), 0, tName _ ": the secret field " _ $List(tSecretFields, tK) _ " is not listed")
        }
        If tNote '= "" {
            Set tNoted = tNoted + 1
            Do $$$AssertEquals($Extract(tDescription, *-$Length(tNote)+1, *), tNote, tName _ ": its note is last")
        }
    }
    Do $$$AssertEquals(tChecked, tListed, "the listing holds exactly the read tools of the declared reads and the error log: " _ tChecked _ " of " _ tListed)
    Do $$$AssertTrue(tChecked > 100, "the roster is not empty: " _ tChecked)
    Do $$$AssertTrue(tSecrets > 0, "at least one read declares a secret field that is withheld: " _ tSecrets)
    Do $$$AssertTrue(tNoted > 0, "at least one read declares a note that ends its description: " _ tNoted)
    Do $$$AssertTrue($ListFind($ListFromString(..FieldsText(##class(OcuPilot.Screen.Read).AnsweredFields("OcuPilot.Screen.Descriptor.LicenseKey")), ", "), "AuthorizationKey") = 0, "the license key's authorization key is withheld (AD-35)")
}

/// <p>AC2: every tool of a confusable group carries its declared label, no tool outside the groups
/// declares one, and each tool identifier a label names is a read tool the listing holds. Any token of
/// lower-case words joined by dots, apart from a <code>.log</code> file name, must be exactly
/// <code>&lt;area&gt;.&lt;screen&gt;</code> and name a listed read tool. The application error log's
/// <code>ROW</code> and <code>LABEL</code> meet the lengths the read grammar sets a descriptor's.</p>
/// <p>Mutation (Rule 19): remove <code>read.label</code> from
/// <class>OcuPilot.Screen.Descriptor.BackgroundTaskList</class> -- this goes red naming
/// <code>tasks.background</code>; point a label at <code>tasks.nosuch</code>, or at
/// <code>tasks.schedule.read</code> -- this goes red naming it.</p>
Method TestEveryConfusableToolCarriesItsLabel()
{
    Set tRosterSC = ..Roster(.tRoster)
    Do $$$AssertStatusOK(tRosterSC, "the roster is read")
    Set tReadsSC = ..Reads(.tReads)
    Do $$$AssertStatusOK(tReadsSC, "the production listing is read")
    Set tDeclaredSC = ..Declared(.tLabels, .tClasses)
    Do $$$AssertStatusOK(tDeclaredSC, "the descriptors are read")
    If $$$ISERR(tRosterSC) || $$$ISERR(tReadsSC) || $$$ISERR(tDeclaredSC) Quit
    Set tCount = 0
    Set tId = ""
    For {
        Set tId = $Order(tRoster(tId))
        If tId = "" Quit
        Set tCount = tCount + 1
        Set tName = tId _ ".read"
        Do $$$AssertTrue($Data(tReads(tName)) > 0, tName _ " is a read tool in the production listing (" _ tRoster(tId) _ ")")
        Set tLabel = $Get(tLabels(tId))
        Do $$$AssertTrue(tLabel '= "", tName _ " declares its label")
        If $Data(tReads(tName)) && (tLabel '= "") Do $$$AssertTrue($List(tReads(tName), 2) [ tLabel, tName _ ": its description carries its label")
    }
    Do $$$AssertEquals(tCount, 39, "seven groups name 39 distinct read tools")
    Set tId = ""
    Set tNamed = 0
    For {
        Set tId = $Order(tLabels(tId))
        If tId = "" Quit
        If tLabels(tId) = "" Continue
        Do $$$AssertTrue($Data(tRoster(tId)) > 0, tId _ " declares a label and is in a confusable group")
        Set tTokens = $ListFromString(tLabels(tId), " ")
        For tK = 1:1:$ListLength(tTokens) {
            Set tToken = $ZStrip($List(tTokens, tK), "<>P")
            If '$Match(tToken, "^[a-z][a-z0-9]*(\.[a-z0-9]+)+$") || ($Piece(tToken, ".", $Length(tToken, ".")) = "log") Continue
            Set tNamed = tNamed + 1
            Do $$$AssertTrue(($Length(tToken, ".") = 2) && ($Data(tReads(tToken _ ".read")) > 0), tId _ "'s label names " _ tToken _ ", which is a read tool identifier (<area>.<screen>) in the listing")
        }
    }
    Do $$$AssertTrue(tNamed > 30, "the labels name neighbouring tools: " _ tNamed)
    Set tErrorRow = $Parameter(..#ERRORCLASS, "ROW")
    Set tErrorLabel = $Parameter(..#ERRORCLASS, "LABEL")
    Do $$$AssertTrue(($Length(tErrorRow) > 0) && ($Length(tErrorRow) <= $Parameter("OcuPilot.Screen.Registry", "READROWMAXLENGTH")), ..#ERRORTOOL _ ": its ROW meets the read.row bound: " _ $Length(tErrorRow))
    Do $$$AssertTrue(($Length(tErrorLabel) > 0) && ($Length(tErrorLabel) <= $Parameter("OcuPilot.Screen.Registry", "READLABELMAXLENGTH")), ..#ERRORTOOL _ ": its LABEL meets the read.label bound: " _ $Length(tErrorLabel))
}

/// <p>AC7: <code>shell.tools.find</code> asked for "suspended tasks", with a limit of 20, answers a row
/// <code>tasks_schedule_read</code> whose description is the registry's composed description, names
/// <code>Suspended</code>, and is short enough that the discovery row is not cut at AD-24's field
/// bound.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ToolsFind.View</method> answers the old fixed
/// sentence for a read tool -- this goes red.</p>
Method TestTheDiscoveryAnswerCarriesTheDescription()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.ToolsFind).View("", {"query": "suspended tasks", "limit": 20}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the discovery tool answers")
    Do $$$AssertEquals(tHttp, 200, "and answers 200")
    If '$IsObject($Get(tResult)) Quit
    Set tFound = ""
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.name = "tasks_schedule_read" Set tFound = tRow.description
    }
    Do $$$AssertTrue(tFound '= "", "a row names tasks_schedule_read among " _ tResult.rows.%Size())
    Set tResolveSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("tasks.schedule.read", .tTool)
    Do $$$AssertStatusOK(tResolveSC, "tasks.schedule.read resolves")
    If '$IsObject($Get(tTool)) Quit
    Do $$$AssertEquals(tFound, ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tTool), "the row carries the registry's composed description")
    Do $$$AssertTrue(tFound [ "Suspended", "and it names Suspended")
    Do $$$AssertTrue($Length(tFound) <= ##class(OcuPilot.Kernel.Agent.Limits).#FIELDMAXLENGTH, "and fits the field bound a discovery row is cut at: " _ $Length(tFound))
}

/// <p>AC3: the built-in prompt carries the three rules verbatim, once each, directly after the sentence
/// about searching and before the one about explaining a screen, as printable ASCII. A definition's
/// override is sent whole without them (<class>OcuPilot.Test.TurnLoop</class> pins that on a turn).</p>
/// <p>Mutation (Rule 19): remove the second rule from <parameter>OcuPilot.Kernel.Agent.Prompt.BUILTIN</parameter>
/// -- this goes red.</p>
Method TestThePromptCarriesTheListRules()
{
    Set tPrompt = ##class(OcuPilot.Kernel.Agent.Prompt).Builtin()
    For tRule = ..#RULEONE, ..#RULETWO, ..#RULETHREE {
        Do $$$AssertEquals($Length(tPrompt, tRule) - 1, 1, "the prompt carries once: " _ $Extract(tRule, 1, 50))
    }
    Do $$$AssertTrue(tPrompt [ (..#PRECEDING _ " " _ ..#RULEONE _ " " _ ..#RULETWO _ " " _ ..#RULETHREE _ " " _ ..#FOLLOWING), "in order, after the search sentence and before the explain sentence")
    Do $$$AssertTrue($Match(tPrompt, "^[ -~]*$") > 0, "the prompt is printable ASCII")
}

/// <p>A read with no generated title or no row phrase still composes, and never raises: the head names
/// the identifier alone, the row clause is absent, and the fields close the sentence. A descriptor that
/// has no title or no <code>LabelKey</code> reads as <code>""</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.Read.Compose</method> always writes the row clause
/// -- this goes red.</p>
Method TestAReadWithoutATitleOrARowStillComposes()
{
    Set tFields = ["Name", "Id"]
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Compose("", "probe.list", "", tFields, "", ""), "Read the rows of the probe.list screen, bounded and with secret fields removed. Fields: Name, Id.", "no title and no row")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Compose("Probe list", "probe.list", "probe", tFields, "It holds probes.", "A note."), "Read the rows of the Probe list screen (probe.list), one probe per row, bounded and with secret fields removed. It holds probes. Fields: Name, Id. A note.", "every part, the note last")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Compose("Probe list", "probe.list", "probe", "", "", ""), "Read the rows of the Probe list screen (probe.list), one probe per row, bounded and with secret fields removed.", "no fields")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Title("OcuPilot.Test.NoSuchDescriptor"), "", "a class that is no descriptor has no title and raises nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Title(""), "", "and neither does no class")
}

/// <p>AC1 and AC2: every read tool's description is exactly its parts in their documented order and with
/// nothing else: the head with the title and identifier, the row clause, "bounded and with secret fields
/// removed.", the label, the field list and the note last (<method>ExpectedText</method> restates the
/// template from the declarations). The label therefore sits before the field list, and the text before the
/// field list is shorter than the bound a discovery row is cut at, so that cut trims fields only.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.Read.Compose</method> writes the label after the
/// field list -- this goes red on every labelled tool.</p>
Method TestEveryReadDescriptionIsExactlyItsDeclaredParts()
{
    Set tSC = ..Reads(.tReads)
    Do $$$AssertStatusOK(tSC, "the production listing is read")
    Set tDeclaredSC = ..Declared(.tLabels, .tClasses)
    Do $$$AssertStatusOK(tDeclaredSC, "the descriptors are read")
    Set tRosterSC = ..Roster(.tRoster)
    Do $$$AssertStatusOK(tRosterSC, "the roster is read")
    Set tTitles = ..GeneratedTitles()
    Do $$$AssertTrue($IsObject(tTitles), "the generated Titles XData is read")
    If $$$ISERR(tSC) || $$$ISERR(tDeclaredSC) || $$$ISERR(tRosterSC) || '$IsObject(tTitles) Quit
    Set tBound = ##class(OcuPilot.Kernel.Agent.Limits).#FIELDMAXLENGTH
    Set tChecked = 0
    Set tLabelled = 0
    Set tId = ""
    For {
        Set tId = $Order(tClasses(tId))
        If tId = "" Quit
        Set tName = tId _ ".read"
        If '$Data(tReads(tName)) Continue
        Set tChecked = tChecked + 1
        If tLabels(tId) '= "" Set tLabelled = tLabelled + 1
        Set tActual = $List(tReads(tName), 2)
        Do $$$AssertEquals(tActual, ..ExpectedText(tId, tClasses(tId), tTitles), tName _ ": its description is its title, row, label, fields and note, in that order")
        Set tFieldsAt = $Find(tActual, " Fields: ")
        If tFieldsAt Do $$$AssertTrue((tFieldsAt - $Length(" Fields: ") - 1) < tBound, tName _ ": the text before its field list is within the bound a discovery row is cut at")
    }
    Do $$$AssertTrue(tChecked > 100, "the roster is not empty: " _ tChecked)
    Set tGrouped = 0
    Set tId = ""
    For {
        Set tId = $Order(tRoster(tId))
        If tId = "" Quit
        Set tGrouped = tGrouped + 1
    }
    Do $$$AssertEquals(tLabelled, tGrouped, "the labelled tools are the tools of the confusable groups: " _ tLabelled)
}

/// <p>The matrix examples, each with the condition that makes it that example: the schedule names
/// <code>Suspended</code> among its fields; the license key declares a secret field and neither the
/// description nor the executed read carries it; the statements read ends head, label, fields, note; a read
/// outside every group declares no label and no note, so its description is the head, the row clause and the
/// fields alone; and the application error log's class tool composes through the same
/// <method>OcuPilot.Screen.Tool.Read.Compose</method>, its note last.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.UserList</class> declares a label -- the
/// outside-every-group leg goes red.</p>
Method TestTheMatrixExamplesCarryTheirDocumentedParts()
{
    Set tSC = ..Reads(.tReads)
    Do $$$AssertStatusOK(tSC, "the production listing is read")
    Set tDeclaredSC = ..Declared(.tLabels, .tClasses)
    Do $$$AssertStatusOK(tDeclaredSC, "the descriptors are read")
    Set tTitles = ..GeneratedTitles()
    Do $$$AssertTrue($IsObject(tTitles), "the generated Titles XData is read")
    If $$$ISERR(tSC) || $$$ISERR(tDeclaredSC) || '$IsObject(tTitles) Quit
    Set tSchedule = $List($Get(tReads("tasks.schedule.read")), 2)
    Do $$$AssertTrue(tSchedule [ " Suspended", "tasks.schedule.read answers Suspended")
    Do $$$AssertTrue(($Find(tSchedule, tLabels("tasks.schedule")) > 0) && ($Find(tSchedule, tLabels("tasks.schedule")) < $Find(tSchedule, " Fields: ")), "and carries its label before its fields")

    Set tLicense = $List($Get(tReads("osmgmt.licensekey.read")), 2)
    Set tSecrets = $ClassMethod(tClasses("osmgmt.licensekey"), "ContextSecretFields")
    Do $$$AssertTrue($ListLength(tSecrets) > 0, "the license key declares a secret field")
    For tK = 1:1:$ListLength(tSecrets) {
        Do $$$AssertEquals($Find(tLicense, $List(tSecrets, tK)), 0, "osmgmt.licensekey.read does not name " _ $List(tSecrets, tK))
    }

    Set tStatements = $List($Get(tReads("explorer.sqltablestatements.read")), 2)
    Set tStatementsRead = $ClassMethod(tClasses("explorer.sqltablestatements"), "Read")
    Set tNote = tStatementsRead.%Get("note").%Get("text")
    Do $$$AssertTrue(tNote '= "", "explorer.sqltablestatements declares a note")
    Do $$$AssertTrue(($Find(tStatements, "removed. " _ tLabels("explorer.sqltablestatements") _ " Fields: ") > 0) && ($Find(tStatements, " Fields: ") < $Find(tStatements, tNote)) && ($Extract(tStatements, *-$Length(tNote)+1, *) = tNote), "explorer.sqltablestatements.read is head, label, fields, then the note last")

    Set tUsers = $List($Get(tReads("permissions.users.read")), 2)
    Set tUsersRead = $ClassMethod(tClasses("permissions.users"), "Read")
    Do $$$AssertEquals(tLabels("permissions.users"), "", "permissions.users declares no label")
    Do $$$AssertEquals(tUsersRead.%GetTypeOf("note"), "unassigned", "and no note")
    Do $$$AssertTrue($Find(tUsers, "secret fields removed. Fields: ") > 0, "so permissions.users.read goes from its head straight to its fields")
    Do $$$AssertEquals($Extract(tUsers, *), ".", "and ends with its field list")

    Set tErrors = $List($Get(tReads(..#ERRORTOOL)), 2)
    Set tErrorId = $Piece(..#ERRORTOOL, ".", 1, 2)
    Set tErrorTitle = tTitles.%Get($ClassMethod(tClasses(tErrorId), "LabelKey"))
    Do $$$AssertTrue(tErrorTitle '= "", "the application error log has a generated title")
    Do $$$AssertEquals($Extract(tErrors, 1, $Length("Read the rows of the " _ tErrorTitle _ " screen (" _ tErrorId _ "), one " _ $Parameter(..#ERRORCLASS, "ROW") _ " per row")), "Read the rows of the " _ tErrorTitle _ " screen (" _ tErrorId _ "), one " _ $Parameter(..#ERRORCLASS, "ROW") _ " per row", "logs.applicationerrors.read opens with its title and row phrase")
    Do $$$AssertTrue(tErrors [ ("removed. " _ $Parameter(..#ERRORCLASS, "LABEL") _ " Fields: " _ $Replace($Parameter(..#ERRORCLASS, "SUMMARYFIELDS"), ",", ", ") _ ". "), "then its label and its summary fields")
    Do $$$AssertEquals($Extract(tErrors, *-$Length($Parameter(..#ERRORCLASS, "DESCRIPTION"))+1, *), $Parameter(..#ERRORCLASS, "DESCRIPTION"), "and its closing sentence last")
}

/// <p>A descriptor whose <code>labelKey</code> has no generated title and whose read declares no
/// <code>row</code> composes from its identifier alone, with no row clause and no secret field, and raises
/// nothing; a descriptor with a title and no row keeps the title and drops only the row clause.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.Read.Description</method> passes the label key as the
/// title when none is generated -- this goes red.</p>
Method TestAFixtureDescriptorWithoutATitleOrARowComposesFromItsIdentifier()
{
    Set tProbe = "OcuPilot.Test.ReadDescriptionsProbe"
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Read).Title(tProbe), "", "the fixture's label key has no generated title")
    Set tDescription = ##class(OcuPilot.Screen.Tool.Read).Description(tProbe)
    Do $$$AssertEquals(tDescription, "Read the rows of the probe.readdescriptions screen, bounded and with secret fields removed. Fields: Name, Id.", "its description names the identifier alone, has no row clause and withholds its secret field")
    Set tTitles = ..GeneratedTitles()
    Do $$$AssertTrue($IsObject(tTitles), "the generated Titles XData is read")
    If '$IsObject(tTitles) Quit
    Set tNoRow = "OcuPilot.Test.ProposalScreen"
    Set tTitle = tTitles.%Get($ClassMethod(tNoRow, "LabelKey"))
    Do $$$AssertTrue(tTitle '= "", "the second fixture's label key has a generated title")
    Set tDescription = ##class(OcuPilot.Screen.Tool.Read).Description(tNoRow)
    Do $$$AssertEquals($Extract(tDescription, 1, $Length("Read the rows of the " _ tTitle _ " screen (probe.proposal), bounded and with secret fields removed. Fields: ")), "Read the rows of the " _ tTitle _ " screen (probe.proposal), bounded and with secret fields removed. Fields: ", "a titled read with no row keeps its title and has no row clause")
}

/// <p>AC1 on a real read: the fields a read tool's description lists are the fields the executed read
/// returns, and every key of every row it returns is one of them, with the screen's secret field in neither.
/// The two screens are the matrix's own examples, the license key (a declared secret field) and the users
/// list (outside every group). Both read this instance and change nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Read.Execute</method> projects each row onto the read's
/// declared fields without removing the secret ones -- this goes red at the license key.</p>
Method TestTheDescribedFieldsAreTheFieldsTheReadReturns()
{
    Set tSC = ..Reads(.tReads)
    Do $$$AssertStatusOK(tSC, "the production listing is read")
    If $$$ISERR(tSC) Quit
    For tClass = "OcuPilot.Screen.Descriptor.LicenseKey", "OcuPilot.Screen.Descriptor.UserList" {
        Set tName = $ClassMethod(tClass, "ToolIdentifier") _ ".read"
        Set tViewSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, {}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tViewSC, tName _ " runs against this instance")
        Do $$$AssertEquals(tHttp, 200, tName _ " answers 200")
        If '$IsObject($Get(tResult)) Continue
        Set tReturned = ..FieldsText(tResult.fields)
        Do $$$AssertTrue(tReturned '= "", tName _ " returns fields")
        Do $$$AssertTrue($List($Get(tReads(tName)), 2) [ (" Fields: " _ tReturned _ "."), tName _ ": its description lists exactly the fields the read returned")
        Do $$$AssertTrue(tResult.rows.%Size() > 0, tName _ " returned rows: " _ tResult.rows.%Size())
        Set tReturnedList = $ListFromString(tReturned, ", ")
        Set tOutside = 0
        Set tRowIterator = tResult.rows.%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            Set tKeyIterator = tRow.%GetIterator()
            While tKeyIterator.%GetNext(.tKey, .tValue) {
                If '$ListFind(tReturnedList, tKey) Set tOutside = tOutside + 1
            }
        }
        Do $$$AssertEquals(tOutside, 0, tName _ ": no row carries a key outside the fields it returned")
        Set tSecrets = $ClassMethod(tClass, "ContextSecretFields")
        For tK = 1:1:$ListLength(tSecrets) {
            Do $$$AssertEquals($ListFind(tReturnedList, $List(tSecrets, tK)), 0, tName _ ": the secret field " _ $List(tSecrets, tK) _ " is not among the returned fields")
        }
    }
}

}
