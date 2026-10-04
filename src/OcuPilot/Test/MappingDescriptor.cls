/// <p>Pins Story 18.14's declarations: the three mapping lists and their forms, the ten write tools'
/// fields, kinds and pairs, the replaced classic pages every registered write tool declares
/// (<parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>, AD-44, DW-1784), and the
/// Integration rows -- each <code>osmgmt.&lt;kind&gt;mappings.read</code> answers the rows its list's
/// own read answers, every row carrying its namespace (AD-36).</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and an installed instance whose
/// install namespace holds mappings the admin API lists. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.MappingDescriptor Extends %UnitTest.TestCase
{

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The registered write tools that declare replaced classic pages, each with its pages, as
/// <code>tool=page</code> entries: the namespace create, edit, delete, copy of mappings and enable of
/// interoperability, each
/// mapping kind's create and edit, Story 18.3's database create, edits and delete, Story 16.4's
/// task export and import, Story 16.10's language server start and stop, Story 16.25's language
/// server create and edit, Story 18.4's disk operations but the dismount, which the classic
/// Database details page performs itself, Story 16.12's three lock removals, Story 16.13's
/// service update, Story 16.14's LDAP create, password and update, Story 19.2's two compiles, Story
/// 18.16's remote database create, update and delete, Story 19.13's two exports and two
/// imports, Story 18.5's switch file, switch directory and integrity check, and Story 18.7's key file
/// create and administrator and key adds.</p>
Parameter CLASSICROSTER = "explorer.classes.compile=%CSP.UI.Portal.Dialog.Compile,explorer.classes.export=%CSP.UI.Portal.Dialog.Export,explorer.classes.import=%CSP.UI.Portal.Dialog.Import,explorer.routines.compile=%CSP.UI.Portal.Dialog.Compile,explorer.routines.export=%CSP.UI.Portal.Dialog.Export,explorer.routines.import=%CSP.UI.Portal.Dialog.Import,osmgmt.databasedetails.compact=%CSP.UI.Portal.Background.Dialog.DatabaseCompact,osmgmt.databasedetails.defragment=%CSP.UI.Portal.Background.Dialog.DatabaseDefragment,osmgmt.databasedetails.mount=%CSP.UI.Portal.Dialog.DBActions,osmgmt.databasedetails.truncate=%CSP.UI.Portal.Background.Dialog.DatabaseTruncate,osmgmt.databases.integrity=%CSP.UI.Portal.Dialog.Integ,%CSP.UI.Portal.Dialog.IntegOutput,osmgmt.ecpdataservers.changestatus=%CSP.UI.Portal.Dialog.ECPDataServer,osmgmt.ecpdataservers.create=%CSP.UI.Portal.Dialog.ECPDataServer,osmgmt.ecpdataservers.update=%CSP.UI.Portal.Dialog.ECPDataServer,osmgmt.globalmappings.create=%CSP.UI.Portal.Mappings.Global,osmgmt.globalmappings.update=%CSP.UI.Portal.Mappings.Global,osmgmt.journals.integrity=%cspapp.op.utilsysjournalintegrity,osmgmt.journals.switchdirectory=%cspapp.op.utilsysjournalswitchdirectory,osmgmt.journals.switchfile=%cspapp.op.utilsysjournalproperties,osmgmt.languageservers.create=%CSP.UI.Portal.ExternalLanguageServer,osmgmt.languageservers.start=%CSP.UI.Portal.ExternalLanguageServerStart,osmgmt.languageservers.stop=%CSP.UI.Portal.ExternalLanguageServerStop,%CSP.UI.Portal.Dialog.ExternalLanguageServerStopDialog,osmgmt.languageservers.update=%CSP.UI.Portal.ExternalLanguageServer,osmgmt.licensekey.activate=%CSP.UI.Portal.Dialog.LicenseActivate,osmgmt.localdatabases.create=%CSP.UI.Portal.Dialog.DatabaseWizard,osmgmt.localdatabases.delete=%CSP.UI.Portal.Dialog.DatabaseDelete,osmgmt.localdatabases.expand=%CSP.UI.Portal.DatabaseVolumes,%CSP.UI.Portal.Dialog.ExpandVolume,osmgmt.localdatabases.grow=%CSP.UI.Portal.Database,osmgmt.localdatabases.update=%CSP.UI.Portal.Database,%CSP.UI.Portal.DatabaseVolumes,osmgmt.localdatabases.updatemount=%CSP.UI.Portal.Database,osmgmt.locks.remove=%CSP.UI.Portal.Locks,osmgmt.locks.removeclient=%CSP.UI.Portal.Locks,osmgmt.locks.removeprocess=%CSP.UI.Portal.Locks,osmgmt.namespaces.copymappings=%CSP.UI.Portal.Namespace,osmgmt.namespaces.create=%CSP.UI.Portal.Namespace,osmgmt.namespaces.delete=%CSP.UI.Portal.Dialog.NamespaceDelete,osmgmt.namespaces.enableinterop=%CSP.UI.Portal.Namespace,osmgmt.namespaces.update=%CSP.UI.Portal.NamespaceEdit,osmgmt.packagemappings.create=%CSP.UI.Portal.Mappings.Package,osmgmt.packagemappings.update=%CSP.UI.Portal.Mappings.Package,osmgmt.remotedatabases.create=%CSP.UI.Portal.Dialog.RemoteDatabase,osmgmt.remotedatabases.delete=%CSP.UI.Portal.Dialog.DatabaseDelete,osmgmt.remotedatabases.update=%CSP.UI.Portal.Dialog.RemoteDatabase,osmgmt.routinemappings.create=%CSP.UI.Portal.Mappings.Routine,osmgmt.routinemappings.update=%CSP.UI.Portal.Mappings.Routine,permissions.services.update=%CSP.UI.Portal.Dialog.Service,security.encryptionkeyfile.addkey=%CSP.UI.Portal.Dialog.EncAddAdmin,security.encryptionkeyfile.create=%CSP.UI.Portal.EncryptionCreate,security.encryptionkeyfileadmins.addadministrator=%CSP.UI.Portal.Dialog.EncAddAdmin,security.ldap.create=%CSP.UI.Portal.LDAP,security.ldap.password=%CSP.UI.Portal.LDAP,security.ldap.update=%CSP.UI.Portal.LDAP,tasks.schedule.export=%cspapp.op.utilsystaskaction,tasks.schedule.import=%cspapp.op.utilsystaskaction";

/// <p>The lists: unlisted, parent-scoped to Namespaces, keyed by <code>[namespace, Name]</code>, read
/// through the vendor's own <code>LIST</code> with one namespace criterion, with Create and Delete,
/// over the one classic mappings page, re-fetched on a namespace change.</p>
Method TestTheListsAreParentScopedAndKeyedByNamespaceAndName()
{
    For tCase = $ListBuild("global", "namespace,Name,Database,LockDatabase,Collation", "Name:tableColumnName:name,Database:systemInfoDatabase:identifier,LockDatabase:mappingColumnLockDatabase:identifier,Collation:mappingColumnCollation:text"), $ListBuild("routine", "namespace,Name,Type,Database", "Name:tableColumnName:name,Type:tableColumnType:text,Database:systemInfoDatabase:identifier"), $ListBuild("package", "namespace,Name,Database", "Name:tableColumnName:name,Database:systemInfoDatabase:identifier") {
        Set tKind = $List(tCase, 1)
        Set tClass = ..Descriptor(tKind, "List")
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tKind _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tKind _ ": the declaration validates")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tKind _ ": including its read and criterion")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.parentScope, "os-management/namespaces/" _ tKind _ "-mappings|0|os-management/namespaces", tKind _ ": unlisted, under Namespaces")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, tKind _ ": the Namespaces screens' two pairs")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "SecondaryEntityTypes")) _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind") _ "|" _ $ListToString($ClassMethod(tClass, "IdParts")), tKind _ "-mapping|namespace|instance|composite|namespace,Name", tKind _ ": its own type, listening for namespaces, keyed by namespace and name")
        Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Namespace." _ $ZConvert($Extract(tKind), "U") _ $Extract(tKind, 2, *) _ "Mappings"",""type"":""LIST""}", tKind _ ": read through the vendor's list")
        Do $$$AssertEquals($ListToString(..Strings(tDeclaration.read.fields)), $List(tCase, 2), tKind _ ": the read's fields, the namespace first")
        Do $$$AssertEquals(tDeclaration.read.criteria.fields.%ToJSON(), "[{""param"":""namespace"",""labelKey"":""headerNamespaceLabel"",""kind"":""text"",""maxLength"":64}]", tKind _ ": one namespace criterion")
        Set tColumns = ""
        Set tIterator = tDeclaration.table.columns.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tColumn.field _ ":" _ tColumn.labelKey _ ":" _ tColumn.kind
        }
        Do $$$AssertEquals(tColumns, $List(tCase, 3), tKind _ ": its columns")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "create|delete", tKind _ ": Create and Delete")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Mappings", tKind _ ": the one classic mappings list (AD-44)")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt." _ tKind _ "mappings"), tClass, tKind _ ": its tool identifier resolves to it")
    }
}

/// <p>The forms: built, unlisted, under their list's route, with the list's pairs and composite id,
/// no read, each over its kind's classic dialog.</p>
Method TestTheFormsAreUnlistedOverTheirKindsDialog()
{
    For tKind = "global", "routine", "package" {
        Set tClass = ..Descriptor(tKind, "Form")
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tKind _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tKind _ ": the declaration validates")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.parentScope, "os-management/namespaces/" _ tKind _ "-mappings/edit|form-page|0|", tKind _ ": a form page under its list's route, unlisted")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, tKind _ ": the list's own pairs")
        Do $$$AssertEquals($ClassMethod(tClass, "IdKind") _ "|" _ $ListToString($ClassMethod(tClass, "IdParts")) _ "|" _ $IsObject($ClassMethod(tClass, "Read")), "composite|namespace,Name|0", tKind _ ": the same composite id and no read")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Mappings." _ $ZConvert($Extract(tKind), "U") _ $Extract(tKind, 2, *), tKind _ ": its kind's classic dialog (AD-44)")
        Do $$$AssertEquals(tDeclaration.toolIdentifier, "osmgmt." _ tKind _ "mappingform", tKind _ ": its tool identifier")
    }
}

/// <p>The ten tools: each mapping create and edit admits exactly its kind's template, the create
/// requiring the database; each delete admits none, is destructive and bodyless and carries the
/// list's Delete; the copy of mappings admits its source alone, is destructive, bodyless, queued
/// through <class>OcuPilot.Port.NamespacePort</class> and carries the Namespaces list's
/// <code>copy-mappings</code>. Every mapping write declares <code>%DB_IRISSYS:WRITE</code> beyond the
/// list's pairs, and the copy <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:WRITE</code>
/// (AD-8).</p>
Method TestTheToolsDeclareTheirFieldsKindsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = $ListBuild("%DB_IRISSYS", "WRITE")
    For tKind = "global", "routine", "package" {
        Set tFields = $Select(tKind = "global": "Database,LockDatabase,Collation", 1: "Database")
        For tCase = $ListBuild("create", tFields, "PUT", 1, 0), $ListBuild("update", tFields, "PUT", 1, 0), $ListBuild("delete", "", "DELETE", 0, 1) {
            Set tName = "osmgmt." _ tKind _ "mappings." _ $List(tCase, 1)
            Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
            Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
            If '$IsObject($Get(tTool)) Continue
            Set tClass = tTool.class
            Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS"), "write|" _ ..Descriptor(tKind, "List"), tName _ " is a write on its list")
            Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 2), tName _ " admits exactly its fields")
            Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "PortClass") _ "|" _ $ClassMethod(tClass, "MintClass"), $List(tCase, 3) _ "|" _ $List(tCase, 4) _ "|" _ $List(tCase, 5) _ "|OcuPilot.Port.NamespacePort|OcuPilot.Screen.Tool.MappingMint", tName _ ": request type, body, destructive, port and mint")
            Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
            Do $$$AssertTrue(tResolved && (tPairs = (tScreen _ $ListBuild(tWrite))), tName _ ": the list's pairs, then the write pair")
            Set tRequired = $ClassMethod(tClass, "InputSchema").required.%ToJSON()
            Do $$$AssertEquals(tRequired, $Select($List(tCase, 1) = "create": "[""Name"",""Namespace"",""Database""]", 1: "[""Name"",""Namespace""]"), tName _ ": requires the name and the namespace" _ $Select($List(tCase, 1) = "create": ", and the database", 1: ""))
        }
        Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields(tKind _ "-mapping")) _ "|" _ $ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields(tKind _ "-mapping")), tFields _ "|" _ tFields, tKind _ ": the prohibited set reviews the same fields for a create and a change")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.namespaces.copymappings", .tTool, 1)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the copy of mappings is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tClass = tTool.class
    Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS"), "write|OcuPilot.Screen.Descriptor.NamespaceList", "a write on the Namespaces list")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")) _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "PortClass"), "SourceNamespace|MAPPINGS|0|1|OcuPilot.Port.NamespacePort", "its source alone, bodyless, destructive, through the namespace port")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "copy-mappings")), "copy-mappings|SourceNamespace", "carrying the list's copy-mappings, its one value the source")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Globals,Routines,TempGlobals,SourceNamespace", "fingerprinting the destination's databases and the source (AD-51)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard accepts")
    Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
    Do $$$AssertTrue(tResolved && (tPairs = (tScreen _ $ListBuild($ListBuild("%Admin_Operate", "USE"), tWrite))), "the list's pairs, then the poll's and the write's")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter("OcuPilot.Port.AdminPort", "QUEUEDWRITES")), "Namespace.Namespace/MAPPINGS"), "and its write is one the port lets the vendor queue (AD-26)")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("global-mapping", "OCUPROBE1814X" _ $Char(1) _ "OcuProbe1814Case"), "ocuprobe1814x" _ $Char(1) _ "OcuProbe1814Case", "a mapping's id folds its namespace part alone (AD-13)")
}

/// <p>The replaced classic pages (AD-44, DW-1784): exactly the fifty-one tools of
/// <parameter>CLASSICROSTER</parameter> declare <parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>,
/// each its page, and no other registered tool declares one; every declared page is spelled exactly as
/// the instance names it, because the custom-resource store does not fold case: a compiled class, or,
/// for a CSP page compiled into <code>%cspapp.</code>, which is not mapped here, the key the portal's
/// own resolver answers for it.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.NamespaceDelete.CLASSICPAGES</parameter>
/// -> the roster differs and this goes red.</p>
Method TestTheClassicPagesRosterIsTheDeclaringTools()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    If $$$ISERR(tSC) Quit
    Kill tDeclared
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || (tEntry.%Get("kind") '= "write") Continue
        Set tPages = $Parameter(tEntry.%Get("class"), "CLASSICPAGES")
        If tPages '= "" Set tDeclared(tEntry.%Get("name")) = tPages
    }
    Set tRoster = ""
    Set tName = ""
    For {
        Set tName = $Order(tDeclared(tName), 1, tPages)
        If tName = "" Quit
        Set tRoster = tRoster _ $Select(tRoster = "": "", 1: ",") _ tName _ "=" _ tPages
        For tI = 1:1:$Length(tPages, ",") {
            Set tPage = $Piece(tPages, ",", tI)
            If $Extract(tPage, 1, 8) = "%cspapp." {
                Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert(tPage, "O", "URL")), tPage, tName _ ": " _ tPage _ " is the key the portal's own resolver answers")
                Continue
            }
            Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
            Do $$$AssertTrue($IsObject(tCompiled) && (tCompiled.Name = tPage), tName _ ": " _ tPage _ " is a compiled class spelled exactly")
            Set tCompiled = ""
        }
    }
    Do $$$AssertEquals(tRoster, ..#CLASSICROSTER, "the declaring tools and their pages")
}

/// <p>The Integration rows (AD-36): each <code>osmgmt.&lt;kind&gt;mappings.read</code> answers exactly
/// the rows its list's own read answers for the install namespace, field for field, every row
/// carrying that namespace; OcuPilot's own global mapping is among the global rows; and a read with
/// no namespace is refused 400 <code>READ.CRITERION</code> on both.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Read.SeedRows</method> sets nothing -> no row
/// carries its namespace and this goes red.</p>
Method TestEachReadToolAnswersItsListsRowsWithTheNamespace()
{
    Set tNamespace = $ZConvert($NAMESPACE, "U")
    For tKind = "global", "routine", "package" {
        Kill tCriteria
        Set tCriteria("namespace") = tNamespace
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..Descriptor(tKind, "List"), "", .tResult, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tSC, tKind _ ": the list's read answers")
        If $$$ISERR(tSC) Continue
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt." _ tKind _ "mappings.read", .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tKind _ ": the read tool is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {"namespace": (tNamespace)}, 1000, .tView, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tKind _ ": and the tool answers")
        If '$IsObject($Get(tView)) Continue
        Do $$$AssertEquals(tView.fields.%ToJSON(), tResult.fields.%ToJSON(), tKind _ ": the tool's fields are the list's")
        Do $$$AssertTrue(tResult.rows.%Size() > 0, tKind _ ": the install namespace has mappings of this kind")
        Do $$$AssertEquals(..Rows(tView.rows), ..Rows(tResult.rows), tKind _ ": the tool answers the list's rows, field for field")
        Do $$$AssertEquals(..Rows(tResult.rows, "namespace"), tNamespace, tKind _ ": every row carries the namespace")
        If tKind = "global" Do $$$AssertTrue(("," _ ..Rows(tResult.rows, "Name") _ ",") [ ",OcuPilot*,", "OcuPilot's own global mapping is among them")
        Kill tNone
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..Descriptor(tKind, "List"), "", .tResult, .tHttp, .tFault, .tNone)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 READ.CRITERION", tKind _ ": the list's read with no namespace is refused")
        Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 READ.CRITERION", tKind _ ": and so is the tool's")
    }
}

/// <p>Each <code>MAPPING.*</code> violation code carries a sentence and names its own field, and each
/// kind's form read publishes one rule per code its fields can break: all ten for a global, and for a
/// routine and a package the seven left without the lock database, the collation and the subscript
/// rule.</p>
/// <p>Mutation (Rule 19): drop the <code>MAPPINGDATABASEREQUIRED</code> arm of
/// <method>OcuPilot.Api.Error.ReasonForMapping</method> -> that code carries no sentence and each
/// kind's rule count falls by one, and this goes red.</p>
Method TestEachViolationCodeCarriesASentenceAndItsField()
{
    Set tCodes = ##class(OcuPilot.Api.Error).MappingViolationCodes()
    Set tFields = ""
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a sentence")
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ ##class(OcuPilot.Area.OsMgmt.MappingRules).FieldOf($List(tCodes, tI))
    }
    Do $$$AssertEquals(tFields, "Name,Name,Name,Name,Name,Namespace,Database,Database,LockDatabase,Collation", "each code names its own field")
    For tCase = $ListBuild("global", 10), $ListBuild("routine", 7), $ListBuild("package", 7) {
        Do $$$AssertEquals(##class(OcuPilot.Area.OsMgmt.MappingRules).Rules($List(tCase, 1)).%Size(), $List(tCase, 2), $List(tCase, 1) _ ": the form read publishes one rule per code its fields can break")
    }
}

/// <p>The kind's <var>pWhich</var> (<code>List</code> or <code>Form</code>) descriptor class.</p>
ClassMethod Descriptor(pKind As %String, pWhich As %String) As %String
{
    Quit "OcuPilot.Screen.Descriptor." _ $ZConvert($Extract(pKind), "U") _ $Extract(pKind, 2, *) _ "Mapping" _ pWhich
}

/// <p><var>pArray</var>'s strings as a <class>%List</class>.</p>
ClassMethod Strings(pArray As %DynamicArray) As %List
{
    Set tList = ""
    If '$IsObject(pArray) Quit tList
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) { Set tList = tList _ $ListBuild(tValue) }
    Quit tList
}

/// <p><var>pRows</var> as one sorted comparable string, each row its JSON, or with
/// <var>pField</var> that field's distinct values alone, an absent value reading
/// <code>(absent)</code>.</p>
ClassMethod Rows(pRows As %DynamicArray, pField As %String = "") As %String
{
    Kill tSorted
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tValue = $Select(pField '= "": tRow.%Get(pField), 1: tRow.%ToJSON())
        Set tSorted($Select(tValue = "": "(absent)", 1: tValue)) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
