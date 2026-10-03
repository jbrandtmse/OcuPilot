/// <p>Pins Story 18.5's declarations: Journals and its two unlisted screens, their pairs, prompts,
/// reads and replaced classic pages; the three journal tools' kinds, ports, request types, pairs and
/// replaced pages; their baseline lines; the read grammar's single-object <code>GET</code> read
/// over one member; and how the journal port compares directories (AD-5, AD-8, AD-22, AD-36, AD-44,
/// AD-51). And Story 18.18's: Journal settings, its tool's kind, port, fields and pairs, its baseline
/// line and its script, and the directory switch's precondition code. And Story 18.19's: Journal
/// records, its criteria against the admin port's closed filter sets, and its three codes.</p>
/// <p>It reads declarations only and needs OcuPilot installed with no custom resource assigned to the
/// replaced classic pages.</p>
Class OcuPilot.Test.JournalDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.JournalList";

Parameter DETAILS = "OcuPilot.Screen.Descriptor.JournalFileDetails";

Parameter DATABASES = "OcuPilot.Screen.Descriptor.JournalFileDatabaseList";

Parameter SETTINGS = "OcuPilot.Screen.Descriptor.JournalSettings";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The groups of <var>pDeclaration</var>'s prompts, joined by commas.</p>
ClassMethod PromptGroups(pDeclaration As %DynamicObject) As %String
{
    Set tOut = ""
    Set tIterator = pDeclaration.suggestedPrompts.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPrompt) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPrompt.groupKey
    }
    Quit tOut
}

/// <p>AC1, AC11: Journals is OS management's thirteenth entry over the vendor's journal file list,
/// newest first, with three row actions, three Capacity prompts and the classic Journals page.</p>
/// <p>Mutation (Rule 19): give Journals a fourth prompt group or drop a prompt -&gt; the prompt leg
/// goes red.</p>
Method TestJournalsIsOsManagementsThirteenthEntry()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey _ ":" _ tDeclaration.archetype, "os-management:13:journalListLabel:list", "OS management's thirteenth side-bar entry, a list")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Journal.File"",""type"":""LIST""}", "read through the vendor's journal file list")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""Size"",""CreationTime"",""Reason"",""DataSize""]", "its five fields")
    Do $$$AssertEquals(tDeclaration.read.sort.default _ " " _ tDeclaration.read.sort.direction, "CreationTime desc", "newest first")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "OS management's operate pair and the system database's read")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ tDeclaration.id.%ToJSON(), "journal-file|instance|{""kind"":""composite"",""parts"":[""Name""]}", "one journal file per row, keyed by its name")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), "switchfile,switchdirectory,integrity", "Switch file, Switch directory and Check integrity")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.op.utilsysjournals", "the classic Journals page, spelled as NormalizePage answers it (AD-44)")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("%cspapp.op.utilsysjournals"), $ClassMethod(tClass, "ClassicPage"), "which NormalizePage answers unchanged")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it does not refresh (AD-43)")
    Do $$$AssertEquals(..PromptGroups(tDeclaration), "promptGroupCapacity,promptGroupCapacity,promptGroupCapacity", "three Capacity prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/journals") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.journals"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
}

/// <p>AC2, AC11: Journal file details and Journal file databases are built, unlisted children of
/// Journals with its pairs, each with three Troubleshooting prompts over the classic summary page;
/// details read the file's <code>GET</code> by its route criterion, and the databases list reads that
/// <code>GET</code>'s <code>Databases</code> member.</p>
/// <p>Mutation (Rule 19): drop <code>"rows"</code> from the databases read -&gt; it reads the
/// <code>GET</code> as one row and the read leg goes red.</p>
Method TestDetailsAndDatabasesAreUnlistedChildrenOfJournals()
{
    For tCase = $ListBuild(..#DETAILS, "os-management/journals/details", "detail", "journal-file", "{""port"":""admin"",""endpoint"":""Journal.File"",""type"":""GET""}", "osmgmt.journalfile"), $ListBuild(..#DATABASES, "os-management/journals/databases", "list", "journal-file-database", "{""port"":""admin"",""endpoint"":""Journal.File"",""type"":""GET"",""rows"":""Databases""}", "osmgmt.journalfiledatabases") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ " parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ " validates")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ "'s read validates")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.parentScope, $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|0|os-management/journals", tClass _ " is built, unlisted, under Journals")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), $List(tCase, 4), tClass _ "'s entity type")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, tClass _ " carries Journals' pairs")
        Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), $List(tCase, 5), tClass _ "'s read")
        Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Get(0).param _ "|" _ tDeclaration.read.criteria.fields.%Size(), "file|1", tClass _ " takes the file as its one criterion")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.op.utilsysjournalsummary", tClass _ " replaces the classic summary page (AD-44)")
        Do $$$AssertEquals(..PromptGroups(tDeclaration), "promptGroupTroubleshooting,promptGroupTroubleshooting,promptGroupTroubleshooting", tClass _ " has three Troubleshooting prompts")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 6)), tClass, tClass _ "'s tool identifier resolves to it")
    }
}

/// <p>AC9, AD-8, AD-44: each journal tool is a write on Journals through
/// <class>OcuPilot.Port.JournalPort</class>, with its own read and request types, no body, nothing
/// destructive; it requires Journals' pairs, the directory switch also the system database's write and
/// <code>%Admin_Manage:USE</code>; and each names its replaced classic page, spelled as
/// <code>NormalizePage</code> answers it.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <parameter>OcuPilot.Screen.Tool.JournalSwitchDirectory.EXTRAPAIRS</parameter> -&gt; that tool's pair
/// leg goes red.</p>
Method TestTheToolsDeclareTheirKindsPortsAndPairs()
{
    Set tScreen = "%Admin_Operate:USE,%DB_IRISSYS:READ"
    Set tCases = $ListBuild($ListBuild("osmgmt.journals.switchfile", "Journal.Settings|STATE|SWITCHFILE|id", tScreen, "%cspapp.op.utilsysjournalproperties", "switchfile"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.journals.switchdirectory", "Journal.Settings|DIRSTATE|SWITCHDIR|id", tScreen _ ",%DB_IRISSYS:WRITE,%Admin_Manage:USE", "%cspapp.op.utilsysjournalswitchdirectory", "switchdirectory"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.journals.integrity", "Journal.File|GET|INTEGRITYCHECK|file", tScreen, "%cspapp.op.utilsysjournalintegrity", "integrity"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass"), "write|" _ ..#LIST _ "|OcuPilot.Port.JournalPort", tName _ " is a write on Journals through the journal port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "IdParam"), $List(tCase, 2), tName _ ": endpoint, read type, request type and id parameter")
        Do $$$AssertEquals($ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction"), "0|0|0|updated", tName _ " sends no body, removes nothing and updates")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
        }
        Do $$$AssertEquals(tResolved _ " " _ tText, "1 " _ $List(tCase, 3), tName _ " requires exactly its pairs (AD-8)")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $List(tCase, 4), tName _ " names its replaced classic page (AD-44)")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($List(tCase, 4)), $List(tCase, 4), tName _ "'s page is spelled as NormalizePage answers it")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), $List(tCase, 5), tName _ " carries its screen action")
    }
}

/// <p>AC10, AD-22: the three journal keys are in the baseline, enabled.</p>
/// <p>Mutation (Rule 19): drop one from <class>OcuPilot.Kernel.Governance.Baseline</class> -&gt; this
/// and <class>OcuPilot.Test.GovernanceBaseline</class> go red.</p>
Method TestTheBaselineEnablesTheThreeKeys()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Kernel.Governance.Baseline", "Keys")
    Do $$$AssertTrue($IsObject(tXData), "the baseline's keys are read")
    If '$IsObject(tXData) Quit
    Set tKeys = ##class(%DynamicObject).%FromJSON(tXData.Data)
    For tKey = "osmgmt.journals.switchfile", "osmgmt.journals.switchdirectory", "osmgmt.journals.integrity" {
        Do $$$AssertEquals(tKeys.%GetTypeOf(tKey) _ " " _ tKeys.%Get(tKey), "boolean 1", tKey _ " is enabled in the baseline")
    }
}

/// <p>AD-36 as amended: a single-object <code>GET</code> may be read over one member, and nothing else
/// changes about the rule -- a detail call beside it is still refused, and the mirror's
/// <code>rowsProblem</code> answers each case alike (<class>OcuPilot.Test.ReadSourceCorpus</class>).</p>
/// <p>Mutation (Rule 19): drop the <code>GET</code> admission from
/// <method>OcuPilot.Screen.Registry.RowsProblem</method> -&gt; the sound leg goes red.</p>
Method TestAGetMayBeReadOverOneMember()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RowsProblem({"port": "admin", "endpoint": "Journal.File", "type": "GET", "rows": "Databases"}), "", "a GET over one member is sound")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RowsProblem({"port": "admin", "endpoint": "Journal.File", "type": "GET", "rows": "Databases", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}]}), "read.source.parts is declared with read.source.rows, and a list over one member issues one call and projects its rows (AD-36)", "beside parts it is refused")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RowsProblem({"port": "admin", "endpoint": "Journal.File", "type": "LIST", "rows": "Databases"}), "read.source.type 'LIST' is not an upper-case bare admin type, and read.source.rows reads one member of a bare type's one-object answer (AD-36)", "and a LIST over one member is still refused")
}

/// <p>AD-59, AD-21's eighth case: the integrity check's script reads the journal file list first, as
/// the guard does, then sends the body the port builds from the flag; a switch's script sends its
/// call alone.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.AdminPort.JournalListStep</method> push from
/// <method>OcuPilot.Port.AdminPort.Snippet</method> -&gt; the first-step leg goes red; have
/// <method>OcuPilot.Port.JournalPort.Snippet</method> pass the caller body -&gt; the body leg goes red.</p>
Method TestTheIntegrityScriptReadsTheListFirstAndSendsTheBuiltBody()
{
    Set tContext = {"origin": "http://host:1", "user": "u"}
    Kill tQuery
    Set tQuery("file") = "/j/20261002.001"
    Set tQuery("CheckDetails") = "true"
    Set tSteps = ##class(OcuPilot.Port.JournalPort).Snippet("Journal.File", "INTEGRITYCHECK", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size(), 2, "two steps: " _ tSteps.%ToJSON())
    If tSteps.%Size() '= 2 Quit
    Do $$$AssertEquals(tSteps.%Get(0).%Get("text"), "curl -u 'u' -X GET 'http://host:1/api/admin/v2/journal/files?maxRows=0'", "the guard's read of the journal file list comes first")
    Do $$$AssertTrue(tSteps.%Get(1).%Get("text") [ "/journal/file/integrity-check?file=/j/20261002.001", "then the check of the named file")
    Do $$$AssertTrue(tSteps.%Get(1).%Get("text") [ "-d '{""CheckDetails"":true}'", "sending the body the port builds from the flag: " _ tSteps.%Get(1).%Get("text"))
    Kill tQuery
    Set tQuery("id") = "current"
    Set tSteps = ##class(OcuPilot.Port.JournalPort).Snippet("Journal.Settings", "SWITCHFILE", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size(), 1, "a switch's script is its one call: " _ tSteps.%ToJSON())
}

/// <p>AD-39: every <code>JOURNAL.*</code> code reads its own sentence through the one writer, on a
/// refused tool call and on a field violation alike, never the generic unavailable sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>JOURNAL.</code> line from
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> -&gt; this goes red.</p>
Method TestEveryJournalCodeReadsItsOwnSentence()
{
    Set tCodes = ##class(OcuPilot.Api.JournalError).Codes()
    Do $$$AssertEquals($ListLength(tCodes), 12, "Stories 18.5, 18.18 and 18.19 declare twelve codes")
    Do $$$AssertEquals(##class(OcuPilot.Api.JournalError).ReasonFor("JOURNAL.FILTER.SHAPE"), "Choose a column and a comparison from the lists, and a value to compare.", "Story 18.19's filter refusal")
    Do $$$AssertEquals(##class(OcuPilot.Api.JournalError).ReasonFor("JOURNAL.OFFSET.SHAPE"), "Enter a record offset as a whole number.", "its offset refusal")
    Do $$$AssertEquals(##class(OcuPilot.Api.JournalError).ReasonFor("JOURNAL.RECORD.UNREADABLE"), "That record is not in this file, or its database is one you cannot read.", "and its unreadable record")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.JournalError).ReasonFor(tCode)
        Do $$$AssertTrue(tReason '= "", tCode _ " has a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " reads it on a refused tool call")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " and on a violation")
    }
}

/// <p>Story 18.18 AC1, AC9: Journal settings is OS management's fourteenth entry, a form page over the
/// vendor's settings <code>GET</code> and its thirteen fields, gated on the classic page's own two
/// resources -- <code>%Admin_Journal:USE</code> its own pair -- and the system database's read, with
/// three Capacity prompts, no row action, no refresh and the classic Journal Settings page.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Journal:USE</code> from the descriptor's pairs -&gt; the
/// pair leg goes red, and the registry refuses its own pair.</p>
Method TestJournalSettingsIsOsManagementsFourteenthEntry()
{
    Set tClass = ..#SETTINGS
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey _ ":" _ tDeclaration.archetype, "os-management:14:journalSettingsLabel:form-page", "OS management's fourteenth side-bar entry, a form page")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Journal.Settings"",""type"":""GET""}", "read through the vendor's settings GET")
    Do $$$AssertEquals(tDeclaration.read.fields.%Size() _ " " _ tDeclaration.context.fields.%Size() _ " " _ tDeclaration.context.secretFields.%Size(), "13 13 0", "its thirteen fields, each in context, none secret")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%Admin_Journal"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "the classic page's two resources and the system database's read")
    Do $$$AssertEquals($Select($IsObject(tDeclaration.ownPrivileges): tDeclaration.ownPrivileges.%ToJSON(), 1: ""), "[{""resource"":""%Admin_Journal"",""permission"":""USE""}]", "%Admin_Journal:USE its own pair (AD-8)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ tDeclaration.id.%ToJSON(), "journal-settings|instance|{""kind"":""single"",""parts"":[]}", "the instance's one set of settings")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("journal-settings", "anything"), "SYSTEM", "every id reads as the singleton (AD-13)")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, "no row action")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Journal", "the classic Journal Settings page (AD-44)")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("%CSP.UI.Portal.Journal"), $ClassMethod(tClass, "ClassicPage"), "which NormalizePage answers unchanged")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes") _ " " _ tDeclaration.classicLinkExemption.exempt, "0 0", "it does not refresh (AD-43) and links out nowhere")
    Do $$$AssertEquals(..PromptGroups(tDeclaration), "promptGroupCapacity,promptGroupCapacity,promptGroupCapacity", "three Capacity prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/journal-settings") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.journalsettings"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
}

/// <p>Story 18.18 AC2, AC5, AC8, AD-4, AD-8, AD-44: the settings update is a merge write on Journal
/// settings through <class>OcuPilot.Port.JournalPort</class>, admitting the eight settable fields and
/// the four directory arguments and never a directory, the archive target or the write image
/// journal; it requires the screen's pairs, the system database's write and
/// <code>%Admin_Operate:USE</code>, and the path port's pair when a root is sent; it names no classic
/// page; its key is in the baseline, enabled; and the directory switch names its precondition
/// code.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from
/// <parameter>OcuPilot.Screen.Tool.JournalSettingsUpdate.EXTRAPAIRS</parameter> -&gt; the pair leg goes
/// red; drop the directory arguments from its <code>InputSchema</code>, or make its
/// <code>PortQuery</code> set nothing -&gt; the schema or the port-query leg goes red.</p>
Method TestTheSettingsToolDeclaresItsFieldsKindAndPairs()
{
    Set tName = "osmgmt.journalsettings.update"
    Kill tTool
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tClass = tTool.class
    Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass"), "write|" _ ..#SETTINGS _ "|OcuPilot.Port.JournalPort", "a write on Journal settings through the journal port")
    Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType"), "Journal.Settings|GET|PUT", "a merge over the settings GET, sent as a PUT")
    Do $$$AssertEquals($ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction"), "1|0|0|updated", "it sends a body, removes nothing and updates")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), "BackupsBeforePurge,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived,CompressFiles,primaryRoot,primaryPath,alternateRoot,alternatePath", "the eight settable fields and the four directory arguments")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ExcludedFields")), "CurrentDirectory,AlternateDirectory,ArchiveName,wijdir,targwijsz", "never a directory, the archive target or the write image journal")
    Set tSchema = $ClassMethod(tClass, "InputSchema")
    Do $$$AssertTrue((tSchema.properties.%GetTypeOf("CurrentDirectory") = "unassigned") && (tSchema.properties.%GetTypeOf("wijdir") = "unassigned") && (tSchema.properties.%GetTypeOf("ArchiveName") = "unassigned"), "the agent's schema carries none of them")
    Do $$$AssertTrue(tSchema.properties.Name.description [ "'SYSTEM'", "and names the singleton by its literal id")
    Set tArgTypes = ""
    For tArg = "primaryRoot", "primaryPath", "alternateRoot", "alternatePath" {
        Set tArgTypes = tArgTypes _ $Select(tArgTypes = "": "", 1: ",") _ tArg _ ":" _ $Select(tSchema.properties.%GetTypeOf(tArg) = "object": tSchema.properties.%Get(tArg).%Get("type"), 1: "")
    }
    Do $$$AssertEquals(tArgTypes, "primaryRoot:string,primaryPath:string,alternateRoot:string,alternatePath:string", "the agent's closed schema admits each directory's root and relative name")
    Kill tQuery
    Do $ClassMethod(tClass, "PortQuery", {"Name": "SYSTEM", "FileSizeLimit": 1000, "alternateRoot": "/r/", "alternatePath": "k", "primaryRoot": ""}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("alternateRoot")) _ "|" _ $Get(tQuery("alternatePath")) _ "|" _ $Data(tQuery("primaryRoot")) _ "|" _ $Data(tQuery("FileSizeLimit")), "/r/|k|0|0", "the port query carries a sent directory's two arguments and nothing else, so the port resolves it again at the write")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved _ " " _ ..PairsText(tPairs), "1 %Admin_Manage:USE,%Admin_Journal:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE,%Admin_Operate:USE", "the screen's pairs, the system database's write and %Admin_Operate:USE (AD-8)")
    Do $$$AssertEquals(..PairsText($ClassMethod(tClass, "ArgumentPairs", "", {"alternateRoot": "/durable/iris/mgr/", "alternatePath": "x"}, .tResolved)), "%Admin_FileSystemAccess:USE", "the path port's pair when a root is sent")
    Do $$$AssertEquals(..PairsText($ClassMethod(tClass, "ArgumentPairs", "", {"FileSizeLimit": 1000}, .tResolved)), "", "and none otherwise")
    Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", "the descriptor's own classic page performs it (AD-44)")
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Kernel.Governance.Baseline", "Keys")
    Set tKeys = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Do $$$AssertEquals(tKeys.%GetTypeOf(tName) _ " " _ tKeys.%Get(tName), "boolean 1", tName _ " is enabled in the baseline (AD-22)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.JournalSwitchDirectory).PreconditionCodes()), "JOURNAL.SWITCHDIR.NOOTHER", "the directory switch names its precondition code (DW-1950)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.JournalSwitchFile).PreconditionCodes()), "", "and a tool that names none has none")
}

/// <p>AD-59: the settings write's script sends the body the port composes -- the resolved
/// directories under their vendor keys, neither the shown-only keys nor the directory arguments, and
/// the purge rule's counts -- to the vendor's settings route.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Port.JournalPort.Snippet</method> pass the payload
/// through -&gt; the body leg goes red.</p>
Method TestTheSettingsScriptSendsTheComposedBody()
{
    Kill tQuery
    Set tBody = {"CurrentDirectory": "/j/", "AlternateDirectory": "/k/", "FileSizeLimit": 1000, "PurgeArchived": true, "DaysBeforePurge": 2, "BackupsBeforePurge": 2, "ArchiveName": "", "wijdir": "", "targwijsz": 0, "alternateRoot": "/r/", "alternatePath": "k"}
    Set tSteps = ##class(OcuPilot.Port.JournalPort).Snippet("Journal.Settings", "PUT", .tQuery, tBody, {"origin": "http://host:1", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "one call: " _ tSteps.%ToJSON())
    If tSteps.%Size() '= 1 Quit
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "-X PUT 'http://host:1/api/admin/v2/journal/settings'", "to the vendor's settings route")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "-d '{""CurrentDirectory"":""/j/"",""AlternateDirectory"":""/k/"",""FileSizeLimit"":1000,""PurgeArchived"":true,""DaysBeforePurge"":0,""BackupsBeforePurge"":0}'", "with the composed body: " _ tSteps.%Get(0).%Get("text"))
}

/// <p>A pair list as <code>resource:permission</code> entries joined by commas.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    }
    Quit tText
}

/// <p>AD-51 as amended by Story 18.5: <class>OcuPilot.Port.JournalPort</class> compares two
/// normalized directories as the vendor's <code>GetTheOtherDirectory</code> does -- trailing
/// separators aside, letter case included -- so a primary and an alternate that differ only in case
/// are two directories, and an empty one names none.</p>
/// <p>Mutation (Rule 19): fold case in <method>OcuPilot.Port.JournalPort.SameDirectory</method> -&gt;
/// the case leg goes red.</p>
Method TestDirectoriesCompareAsTheVendorComparesThem()
{
    Set tPort = "OcuPilot.Port.JournalPort"
    Do $$$AssertTrue($ClassMethod(tPort, "SameDirectory", "/durable/iris/mgr/journal/", "/durable/iris/mgr/journal"), "a trailing separator changes nothing")
    Do $$$AssertTrue('$ClassMethod(tPort, "SameDirectory", "/durable/iris/mgr/Journal/", "/durable/iris/mgr/journal/"), "directories differing in case are two directories")
    Do $$$AssertTrue('$ClassMethod(tPort, "SameDirectory", "", ""), "an empty directory names none")
}

/// <p>Story 18.19 AC1, AC7: Journal records is a built, unlisted server-criteria list at
/// <code>os-management/journal-records</code>, not under Journals, with Journals' pairs, no parent
/// scope, no action and no refresh, one <code>journal-record</code> per row keyed by its address, its
/// eight fields, three Troubleshooting prompts and the classic record browser.</p>
/// <p>Mutation (Rule 19): drop one prompt -&gt; the prompt leg goes red.</p>
Method TestJournalRecordsIsAnUnlistedServerCriteriaList()
{
    Set tClass = "OcuPilot.Screen.Descriptor.JournalRecordList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and its criteria")
    Do $$$AssertEquals(tDeclaration.route _ ":" _ $ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.archetype, "os-management/journal-records:os-management:0:list (server criteria)", "an unlisted server-criteria list in OS management, not under journals/")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "Journals' pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")) _ "|" _ tDeclaration.primaryAction.id _ "|" _ ''$ClassMethod(tClass, "Refreshes"), "|||0", "no parent scope, no action and no refresh")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ tDeclaration.id.%ToJSON(), "journal-record|instance|{""kind"":""composite"",""parts"":[""Address""]}", "one journal record per row, keyed by its address")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("journal-record"), "an entity type the kernel knows")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Journal.Record"",""type"":""LIST""}", "read through the vendor's record list")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Address"",""TimeStamp"",""ProcessID"",""TypeName"",""ExtTypeName"",""InTransaction"",""GlobalNode"",""DatabaseName""]", "its eight fields")
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "and context carries the same eight")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "none of them secret")
    Do $$$AssertEquals(..PromptGroups(tDeclaration), "promptGroupTroubleshooting,promptGroupTroubleshooting,promptGroupTroubleshooting", "three Troubleshooting prompts")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.op.utilsysjournal", "the classic record browser, spelled as NormalizePage answers it (AD-44)")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("%cspapp.op.utilsysjournal"), $ClassMethod(tClass, "ClassicPage"), "which NormalizePage answers unchanged")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/journal-records") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.journalrecords"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
}

/// <p>Story 18.19 AC3: the six criteria in order, each sent under the vendor's own name; the column's
/// and the comparison's options are exactly the admin port's closed sets; the defaults; and every
/// criterion's hint, which the read tool publishes as its description.</p>
/// <p>Mutation (Rule 19): add <code>NewValue</code> to the column's options -&gt; the options leg goes
/// red; drop the default sentence from a hinted choice's description -&gt; the description leg goes
/// red.</p>
Method TestJournalRecordsCriteriaAreThePortsClosedSets()
{
    Set tClass = "OcuPilot.Screen.Descriptor.JournalRecordList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Set tFields = tDeclaration.read.criteria.fields
    Set tShape = ""
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tShape = tShape _ $Select(tShape = "": "", 1: ",") _ tField.param _ ">" _ $Select(tField.%IsDefined("vendorParam"): tField.vendorParam, 1: tField.param) _ ":" _ tField.kind _ ":" _ $Select(tField.%IsDefined("default"): tField.default, 1: "")
        Do $$$AssertTrue(($Length(tField.%Get("hint")) > 0) && ($Length(tField.%Get("hint")) <= 300), tField.param _ " declares a hint")
    }
    Do $$$AssertEquals(tShape, "file>file:text:,offset>initialOffset:text:,order>reverse:choice:0,column>matchColumnName:choice:GlobalNode,operator>matchOperator:choice:[,value>matchValue:text:", "the six criteria, their vendor names, kinds and defaults")
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Do $$$AssertEquals(..Joined(tFields.%Get(3).options), $Parameter(tAdmin, "JOURNALMATCHCOLUMNS"), "the column's options are the port's eight columns")
    Do $$$AssertEquals(..Joined(tFields.%Get(4).options), $Parameter(tAdmin, "JOURNALMATCHOPERATORS"), "and the comparison's its six operators")
    Do $$$AssertEquals($Parameter(tAdmin, "JOURNALMATCHPARAMS"), tFields.%Get(3).vendorParam _ "," _ tFields.%Get(4).vendorParam _ "," _ tFields.%Get(5).vendorParam, "sent under the port's three filter keys")
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(tClass)
    Do $$$AssertTrue($Extract(tSchema.properties.%Get("offset").description, 1, $Length(tFields.%Get(1).hint)) = tFields.%Get(1).hint, "the read tool publishes the hint as the description")
    Do $$$AssertEquals(tSchema.properties.%Get("operator").enum.%ToJSON(), tFields.%Get(4).options.%ToJSON(), "and a choice keeps its enum")
    Do $$$AssertEquals(tSchema.properties.%Get("order").description, tFields.%Get(2).hint _ " One of the listed values, spelled exactly; any other value is refused before the search runs. Omit it to use the screen's default (0); an empty string leaves it unset.", "a hinted choice keeps its listed-values sentence and its default's")
    Do $$$AssertEquals(tSchema.properties.%Get("file").description, tFields.%Get(0).hint, "and a hinted text criterion with no default reads its hint alone")
}

/// <p><var>pArray</var>'s members joined by commas.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tOut = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tValue
    }
    Quit tOut
}

}
