/// <p>Pins Story 19.1's declarations: the System Explorer area's row, its two lists and two viewers
/// -- each validated, read through the source code API port, gated on the measured pair, keyed to a
/// classic page the portal's own resolver answers, and carrying at least three prompts in the Code
/// group -- the two editors since Story 19.3, form pages with no read and no classic page; Search,
/// Compare and Macros since Story 19.4, two reads with no classic page and a form page keyed to the
/// classic Compare Routines page; the SQL catalog's four lists and a table's five parent-scoped tabs
/// since Story 19.5, and a table's four further tabs and a view's three and a procedure's two since
/// Story 19.14, each keyed to the classic SQL page and gated by a custom resource on it, the three SQL
/// statements reads carrying the statistics note; and the area's tools since Story 19.2: twenty-four
/// reads and the two lists' compile, delete, export, import and save, each write's baseline key, and
/// the actions the lists declare for them; and Data browser since Story 19.7, a form page keyed to the
/// classic Open Table page; and Document databases since Story 19.17, its read, create and drop.</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and the classic portal's
/// classes. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.ExplorerDescriptor Extends %UnitTest.TestCase
{

/// <p>The thirty descriptors: the five code screens listed, in side-bar order, then viewers,
/// then editors; then the four SQL catalog lists, in side-bar order, a table's nine tabs, a view's
/// three and a procedure's two; then SQL query, Data browser and Document databases.</p>
Parameter DESCRIPTORS = "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList,OcuPilot.Screen.Descriptor.ExplorerSearch,OcuPilot.Screen.Descriptor.ExplorerCompare,OcuPilot.Screen.Descriptor.ExplorerMacro,OcuPilot.Screen.Descriptor.ExplorerClassDocument,OcuPilot.Screen.Descriptor.ExplorerRoutineDocument,OcuPilot.Screen.Descriptor.ExplorerClassEditor,OcuPilot.Screen.Descriptor.ExplorerRoutineEditor,OcuPilot.Screen.Descriptor.ExplorerSqlSchemas,OcuPilot.Screen.Descriptor.ExplorerSqlTables,OcuPilot.Screen.Descriptor.ExplorerSqlViews,OcuPilot.Screen.Descriptor.ExplorerSqlProcedures,OcuPilot.Screen.Descriptor.ExplorerSqlTable,OcuPilot.Screen.Descriptor.ExplorerSqlFields,OcuPilot.Screen.Descriptor.ExplorerSqlIndices,OcuPilot.Screen.Descriptor.ExplorerSqlPartitions,OcuPilot.Screen.Descriptor.ExplorerSqlPartitionMappings,OcuPilot.Screen.Descriptor.ExplorerSqlTriggers,OcuPilot.Screen.Descriptor.ExplorerSqlConstraints,OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries,OcuPilot.Screen.Descriptor.ExplorerSqlTableStatements,OcuPilot.Screen.Descriptor.ExplorerSqlView,OcuPilot.Screen.Descriptor.ExplorerSqlViewFields,OcuPilot.Screen.Descriptor.ExplorerSqlViewStatements,OcuPilot.Screen.Descriptor.ExplorerSqlProcedure,OcuPilot.Screen.Descriptor.ExplorerSqlProcedureStatements,OcuPilot.Screen.Descriptor.ExplorerSqlQuery,OcuPilot.Screen.Descriptor.ExplorerSqlData,OcuPilot.Screen.Descriptor.ExplorerDocDbList";

/// <p>The SQL catalog's classic page, whose compiled <code>RESOURCE</code> is
/// <code>%Development</code>.</p>
Parameter SQLPAGE = "%CSP.UI.Portal.SQL.Home";

/// <p>The measured pair set every screen and the area declare.</p>
Parameter PAIRS = "[{""resource"":""%Development"",""permission"":""USE""}]";

/// <p>The area's row, as the rail declares it.</p>
Method TestTheAreaIsTheEighthRailItem()
{
    Set tArea = ##class(OcuPilot.Screen.Area).Find("system-explorer")
    Do $$$AssertTrue($IsObject(tArea), "the area is declared")
    If '$IsObject(tArea) Quit
    Do $$$AssertEquals(tArea.railPosition _ "|" _ tArea.labelKey _ "|" _ tArea.navigates _ "|" _ tArea.pinBottom, "8|navAreaSystemExplorer|0|0", "rail position 8, its own label, not navigating, not pinned")
    Do $$$AssertEquals(tArea.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE alone")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Area).Find("agent").railPosition, 11, "Agent co-pilot sits at 11")
    Set tSC = ##class(OcuPilot.Screen.Registry).ListedScreensForArea("system-explorer", .tListed)
    Do $$$AssertStatusOK(tSC, "the side bar reads")
    Do $$$AssertEquals($ListToString(tListed), "OcuPilot.Screen.Descriptor.ExplorerClassList,OcuPilot.Screen.Descriptor.ExplorerRoutineList,OcuPilot.Screen.Descriptor.ExplorerSearch,OcuPilot.Screen.Descriptor.ExplorerCompare,OcuPilot.Screen.Descriptor.ExplorerMacro,OcuPilot.Screen.Descriptor.ExplorerSqlSchemas,OcuPilot.Screen.Descriptor.ExplorerSqlTables,OcuPilot.Screen.Descriptor.ExplorerSqlViews,OcuPilot.Screen.Descriptor.ExplorerSqlProcedures,OcuPilot.Screen.Descriptor.ExplorerSqlQuery,OcuPilot.Screen.Descriptor.ExplorerSqlData,OcuPilot.Screen.Descriptor.ExplorerDocDbList", "its side bar lists Classes, Routines, Search, Compare, Macros, SQL schemas, SQL tables, SQL views, SQL procedures, SQL query, Data browser and Document databases")
}

/// <p>Each declaration that reads validates, is gated on the measured pair, reads through the
/// atelier port, and keys a classic page the portal's own resolver answers (AD-44), or, for Search
/// and Macros, none; Stories 19.5 AC6 and 19.14 AC9: each SQL catalog screen keys the classic SQL
/// page.</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Screen.Descriptor.ExplorerSqlTriggers</class>'
/// <code>classicPage</code> to <code>""</code> -- its classic page assertion goes red; the same for
/// <class>OcuPilot.Screen.Descriptor.ExplorerSqlView</class>.</p>
Method TestEachDeclarationValidatesAndIsGatedOnTheMeasuredPair()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the roster validates: " _ tProblem)
    Set tPackage = "OcuPilot.Screen.Descriptor."
    Set tExpected = $ListBuild($ListBuild("ExplorerClassList", "system-explorer/classes", 1, "list (server criteria)", "class", "Classes", "%CSP.UI.Portal.ClassList", "explorer.classes"), $ListBuild("ExplorerRoutineList", "system-explorer/routines", 2, "list (server criteria)", "routine", "Routines", "%CSP.UI.Portal.RoutineList", "explorer.routines"), $ListBuild("ExplorerClassDocument", "system-explorer/classes/document", 0, "viewer (source)", "class", "Class", "%CSP.UI.Portal.ClassList", "explorer.class"), $ListBuild("ExplorerRoutineDocument", "system-explorer/routines/document", 0, "viewer (source)", "routine", "Routine", "%CSP.UI.System.ViewCode", "explorer.routine"), $ListBuild("ExplorerSearch", "system-explorer/search", 3, "list (server criteria)", "class", "Search", "", "explorer.search"), $ListBuild("ExplorerMacro", "system-explorer/macros", 5, "list (server criteria)", "routine", "Macro", "", "explorer.macro"))
    Set tSql = ..#SQLPAGE
    Set tExpected = tExpected _ $ListBuild($ListBuild("ExplorerSqlSchemas", "system-explorer/sql-schemas", 6, "list (server criteria)", "class", "Catalog.Schemas", tSql, "explorer.sqlschemas"), $ListBuild("ExplorerSqlTables", "system-explorer/sql-tables", 7, "list (server criteria)", "class", "Catalog.Tables", tSql, "explorer.sqltables"), $ListBuild("ExplorerSqlViews", "system-explorer/sql-views", 8, "list (server criteria)", "class", "Catalog.Views", tSql, "explorer.sqlviews"), $ListBuild("ExplorerSqlProcedures", "system-explorer/sql-procedures", 9, "list (server criteria)", "class", "Catalog.Procedures", tSql, "explorer.sqlprocedures"), $ListBuild("ExplorerSqlTable", "system-explorer/sql-tables/document", 0, "detail", "class", "Catalog.Table", tSql, "explorer.sqltable"), $ListBuild("ExplorerSqlFields", "system-explorer/sql-tables/fields", 0, "detail", "class", "Catalog.Fields", tSql, "explorer.sqlfields"), $ListBuild("ExplorerSqlIndices", "system-explorer/sql-tables/indices", 0, "detail", "class", "Catalog.Indices", tSql, "explorer.sqlindices"), $ListBuild("ExplorerSqlTriggers", "system-explorer/sql-tables/triggers", 0, "detail", "class", "Catalog.Triggers", tSql, "explorer.sqltriggers"), $ListBuild("ExplorerSqlConstraints", "system-explorer/sql-tables/constraints", 0, "detail", "class", "Catalog.Constraints", tSql, "explorer.sqlconstraints"))
    Set tExpected = tExpected _ $ListBuild($ListBuild("ExplorerSqlPartitions", "system-explorer/sql-tables/partitions", 0, "detail", "class", "Catalog.Partitions", tSql, "explorer.sqlpartitions"), $ListBuild("ExplorerSqlPartitionMappings", "system-explorer/sql-tables/partition-mappings", 0, "detail", "class", "Catalog.PartitionMappings", tSql, "explorer.sqlpartitionmappings"), $ListBuild("ExplorerSqlCachedQueries", "system-explorer/sql-tables/cached-queries", 0, "detail", "class", "Catalog.CachedQueries", tSql, "explorer.sqlcachedqueries"), $ListBuild("ExplorerSqlTableStatements", "system-explorer/sql-tables/statements", 0, "detail", "class", "Catalog.TableStatements", tSql, "explorer.sqltablestatements"), $ListBuild("ExplorerSqlView", "system-explorer/sql-views/document", 0, "detail", "class", "Catalog.View", tSql, "explorer.sqlview"), $ListBuild("ExplorerSqlViewFields", "system-explorer/sql-views/fields", 0, "detail", "class", "Catalog.ViewFields", tSql, "explorer.sqlviewfields"), $ListBuild("ExplorerSqlViewStatements", "system-explorer/sql-views/statements", 0, "detail", "class", "Catalog.ViewStatements", tSql, "explorer.sqlviewstatements"), $ListBuild("ExplorerSqlProcedure", "system-explorer/sql-procedures/document", 0, "detail", "class", "Catalog.Procedure", tSql, "explorer.sqlprocedure"), $ListBuild("ExplorerSqlProcedureStatements", "system-explorer/sql-procedures/statements", 0, "detail", "class", "Catalog.ProcedureStatements", tSql, "explorer.sqlprocedurestatements"))
    For tI = 1:1:$ListLength(tExpected) {
        Set tWant = $List(tExpected, tI)
        Set tClass = tPackage _ $List(tWant, 1)
        Set tWant = $List(tWant, 2, *)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": the declaration, its read and its criteria validate")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.area, $List(tWant, 1) _ "|" _ $List(tWant, 2) _ "|" _ $List(tWant, 3) _ "|" _ $List(tWant, 4) _ "|namespace|system-explorer", tClass _ ": its route, position, archetype, type and scope")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": gated on %Development:USE")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint, "atelier|" _ $List(tWant, 5), tClass _ ": read through the atelier port")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tWant, 6), tClass _ ": its classic page")
        If $List(tWant, 6) '= "" {
            Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace($List(tWant, 6), "%", "%25") _ ".zen"), $List(tWant, 6), tClass _ ": which the portal's own resolver answers")
            Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId($List(tWant, 6)), tClass _ ": and which is a compiled class")
        }
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tWant, 7)), tClass, tClass _ ": its tool identifier resolves to it")
        Do $$$AssertEquals(tDeclaration.read.%Get("document"), "", tClass _ ": declares no document of its own")
    }
}

/// <p>The lists' criteria carry the classic page's defaults; the viewers' carry the name and a form
/// defaulting to UDL. Their context never names the description or the text.</p>
Method TestTheCriteriaCarryTheClassicDefaults()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassList", "pattern=*,system=no,generated=no,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineList", "pattern=*.mac,system=no,generated=yes,mapped=yes,from=,to="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassDocument", "name=,form=udl"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineDocument", "name=,form=udl"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSearch", "text=,scope=all,case=no"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerMacro", "document=,macro="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlSchemas", "system=no"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlTables", "system=no,schema="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlViews", "system=no,schema="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlProcedures", "system=no,schema="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlTriggers", "table="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlTableStatements", "table="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlViewFields", "view="), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerSqlProcedure", "procedure=") {
        Set tSC = $ClassMethod($List(tCase, 1), "DeclarationJson", .tDeclaration)
        Set tSeen = ""
        Set tIterator = tDeclaration.read.criteria.fields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tField.param _ "=" _ tField.%Get("default")
        }
        Do $$$AssertEquals(tSeen, $List(tCase, 2), $List(tCase, 1) _ ": its criteria and defaults")
    }
    Set tSC = ##class(OcuPilot.Screen.Descriptor.ExplorerClassDocument).DeclarationJson(.tDeclaration)
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), "[""Kind"",""Name"",""Type"",""Flags""]", "screen context carries kind, name, type and flags alone")
}

/// <p>The read tools tell the model each declared default, since omitting a criterion reads it
/// (AD-36): the Routines pattern names <code>*.mac</code>, each include choice its own default, and
/// the viewer's form <code>udl</code>.</p>
/// <p>Mutation: drop the default clause from
/// <method>OcuPilot.Screen.Tool.Read.AddCriteria</method> -&gt; every assertion here goes red.</p>
Method TestTheReadToolsNameEachDefault()
{
    Set tRoutines = ##class(OcuPilot.Screen.Tool.Read).InputSchema("OcuPilot.Screen.Descriptor.ExplorerRoutineList").properties
    Do $$$AssertTrue(tRoutines.pattern.description [ "screen's default (*.mac)", "the Routines pattern names *.mac: " _ tRoutines.pattern.description)
    Do $$$AssertTrue(tRoutines.system.description [ "screen's default (no)", "system names no: " _ tRoutines.system.description)
    Do $$$AssertTrue(tRoutines.generated.description [ "screen's default (yes)", "generated names yes: " _ tRoutines.generated.description)
    Set tClass = ##class(OcuPilot.Screen.Tool.Read).InputSchema("OcuPilot.Screen.Descriptor.ExplorerClassDocument").properties
    Do $$$AssertTrue(tClass.form.description [ "screen's default (udl)", "the viewer's form names udl: " _ tClass.form.description)
}

/// <p>Every screen of the area declares at least three suggested prompts in the Code group.</p>
Method TestEveryScreenDeclaresThreePromptsInTheCodeGroup()
{
    For tI = 1:1:$Length(..#DESCRIPTORS, ",") {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Set tCount = 0
        Set tGroups = ""
        Set tIterator = tDeclaration.suggestedPrompts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPrompt) {
            Set tCount = tCount + 1
            If tPrompt.groupKey '= "webAppPromptGroupCode" Set tGroups = tGroups _ " " _ tPrompt.groupKey
        }
        Do $$$AssertTrue(tCount >= 3, tClass _ ": declares at least three prompts")
        Do $$$AssertEquals(tGroups, "", tClass _ ": all in the Code group")
    }
}

/// <p>Stories 19.2 AC9, 19.13 AC7, 19.4 AC6, 19.5 AC5, 19.14 AC7, 19.11, 19.17 and 20.21: the area's advertised
/// tools are its twenty-eight reads (Story 20.19 adds the two source reads, one per viewer) and fifteen writes
/// (the lists' compile, create, delete, export, import and save, Story 20.21 adding the two saves and Story 20.20
/// the two creates), each over the source
/// code API port with its own request type, fingerprint subject and precondition -- a delete covers each
/// document's modified time, an import its reviewed documents and a save the text, version and compile choice;
/// the compile, export, save and document database create keys are enabled and the delete, import, SQL run,
/// data browser save and document database drop keys disabled at the baseline; the SQL query's run over the SQL
/// port; and the two lists declare the seven row actions, compile, delete and export acting on the checked rows,
/// at most one hundred, while the viewers and editors declare none. The two saves are
/// <method>TestTheTwoSavesAreAdvertisedDestructiveWrites</method>'s.</p>
/// <p>Mutation (Rule 19): enable a delete key in the baseline -- the baseline leg goes red.</p>
Method TestTheAreaAdvertisesItsReadsAndWrites()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists")
    If $$$ISERR(tSC) Quit
    Set tExplorer = ""
    Set tWriters = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If '##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tTool) Continue
        If $Extract(tTool.name, 1, 9) = "explorer." Set tExplorer = tExplorer _ $Select(tExplorer = "": "", 1: ",") _ tTool.name _ ":" _ tTool.kind
        If (tTool.kind '= "write") || (tTool.class = "") || ($Extract($Parameter(tTool.class, "DESCRIPTORCLASS"), 1, 35) '= "OcuPilot.Screen.Descriptor.Explorer") Continue
        Set tClass = tTool.class
        Set tWriters = tWriters _ $Select(tWriters = "": "", 1: ",") _ tTool.name _ ":" _ $Piece($Parameter(tClass, "DESCRIPTORCLASS"), ".", *) _ "/" _ $ClassMethod(tClass, "PortClass") _ "/" _ $ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "Destructive") _ "/" _ $ListToString($ClassMethod(tClass, "FingerprintSubject"), "+") _ "/" _ $ClassMethod(tClass, "PreconditionField")
    }
    Do $$$AssertEquals(tExplorer, "explorer.class.read:read,explorer.class.source:read,explorer.classes.compile:write,explorer.classes.create:write,explorer.classes.delete:write,explorer.classes.export:write,explorer.classes.import:write,explorer.classes.read:read,explorer.classes.save:write,explorer.docdb.create:write,explorer.docdb.delete:write,explorer.docdb.read:read,explorer.macro.read:read,explorer.routine.read:read,explorer.routine.source:read,explorer.routines.compile:write,explorer.routines.create:write,explorer.routines.delete:write,explorer.routines.export:write,explorer.routines.import:write,explorer.routines.read:read,explorer.routines.save:write,explorer.search.read:read,explorer.sqlcachedqueries.read:read,explorer.sqlconstraints.read:read,explorer.sqlfields.read:read,explorer.sqlindices.read:read,explorer.sqlpartitionmappings.read:read,explorer.sqlpartitions.read:read,explorer.sqlprocedure.read:read,explorer.sqlprocedures.read:read,explorer.sqlprocedurestatements.read:read,explorer.sqlquery.read:read,explorer.sqlquery.run:write,explorer.sqlschemas.read:read,explorer.sqltable.read:read,explorer.sqltables.read:read,explorer.sqltablestatements.read:read,explorer.sqltriggers.read:read,explorer.sqlview.read:read,explorer.sqlviewfields.read:read,explorer.sqlviews.read:read,explorer.sqlviewstatements.read:read", "the area's advertised tools are twenty-eight reads and fifteen writes, and Compare has none")
    Do $$$AssertEquals(tWriters, "explorer.classes.compile:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/COMPILE/0/Present+Absent+Namespace+KeepSource+CompileDependents+SkipUpToDate/Present,explorer.classes.create:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/CREATE/0/Present+Namespace/Present,explorer.classes.delete:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/DELETE/1/Modified+Absent+Namespace/Modified,explorer.classes.export:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/EXPORT/0/Present+Absent+Namespace+root+path/Present,explorer.classes.import:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/IMPORT/1/Namespace+root+path+fileName+content+documents+Compile/documents,explorer.classes.save:ExplorerClassList/OcuPilot.Port.AtelierPort/Classes/SAVE/1/Modified+Absent+Namespace+content+version+Compile/Modified,explorer.docdb.create:ExplorerDocDbList/OcuPilot.Port.DocDbPort/Databases/CREATE/0//,explorer.docdb.delete:ExplorerDocDbList/OcuPilot.Port.DocDbPort/Databases/DROP/1/Name+Class+Namespace/Class,explorer.routines.compile:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/COMPILE/0/Present+Absent+Namespace+KeepSource+CompileDependents+SkipUpToDate/Present,explorer.routines.create:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/CREATE/0/Present+Namespace/Present,explorer.routines.delete:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/DELETE/1/Modified+Absent+Namespace/Modified,explorer.routines.export:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/EXPORT/0/Present+Absent+Namespace+root+path/Present,explorer.routines.import:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/IMPORT/1/Namespace+root+path+fileName+content+documents+Compile/documents,explorer.routines.save:ExplorerRoutineList/OcuPilot.Port.AtelierPort/Routines/SAVE/1/Modified+Absent+Namespace+content+version+Compile/Modified,explorer.sqlquery.run:ExplorerSqlQuery/OcuPilot.Port.SqlPort/Sql/RUN/1/Namespace+Kind+StatementType+Tables+statement+parameters+maxRows/Kind", "each write names its list, its port (the source code API's, or the DocDB port for Document databases), its endpoint and type, its fingerprint subject and precondition, and the deletes, imports, the drop and the SQL run are destructive")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
    Do $$$AssertStatusOK(tSC, "the baseline reads")
    If $$$ISERR(tSC) Quit
    Set tBaselined = ""
    Set tIterator = tKeys.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $Extract(tKey, 1, 9) = "explorer." Set tBaselined = tBaselined _ $Select(tBaselined = "": "", 1: ",") _ tKey _ "=" _ $Select(tValue: "true", 1: "false")
    }
    Do $$$AssertEquals(tBaselined, "explorer.classes.compile=true,explorer.classes.delete=false,explorer.routines.compile=true,explorer.routines.delete=false,explorer.classes.export=true,explorer.routines.export=true,explorer.classes.import=false,explorer.classes.save=true,explorer.routines.save=true,explorer.classes.create=true,explorer.routines.create=true,explorer.sqlquery.run=false,explorer.routines.import=false,explorer.sqldata.save=false,explorer.docdb.create=true,explorer.docdb.delete=false", "the compile, export, save and document database create keys ship enabled and the delete, import, SQL run, data browser save and document database drop keys disabled")
    For tI = 1:1:$Length(..#DESCRIPTORS, ",") {
        Set tClass = $Piece(..#DESCRIPTORS, ",", tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Set tMulti = $Select($$$ISOK(tSC) && (tDeclaration.%GetTypeOf("multiSelect") = "object"): tDeclaration.multiSelect.%ToJSON(), 1: "")
        Set tWant = $Select(tI <= 2: "|compile,delete,export,export-browser,import,import-local,save|{""action"":""compile"",""max"":100,""extraActions"":[""delete"",""export""]}", tClass = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery": "|run|", tClass = "OcuPilot.Screen.Descriptor.ExplorerSqlData": "|save|", tClass = "OcuPilot.Screen.Descriptor.ExplorerDocDbList": "create|delete|", 1: "||")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")) _ "|" _ tMulti, tWant, tClass _ ": its actions")
    }
}

/// <p>Story 20.21 AC1: the two lists' saves are advertised, destructive, action-style writes over the source
/// code API port's <code>SAVEDOCS</code> and <code>SAVE</code>, fingerprinting the document's version, the
/// namespace and the three values the list's <code>save</code> action declares -- the text, the version and
/// the compile choice; their closed schema names the document, the agent's replacements and its own words; and
/// they declare no classic page.</p>
Method TestTheTwoSavesAreAdvertisedDestructiveWrites()
{
    For tCase = $ListBuild("OcuPilot.Screen.Tool.ExplorerClassSave", "explorer.classes.save", "ExplorerClassList", "Classes"), $ListBuild("OcuPilot.Screen.Tool.ExplorerRoutineSave", "explorer.routines.save", "ExplorerRoutineList", "Routines") {
        Set tClass = $List(tCase, 1)
        Do ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 2), .tEntry, 1)
        Do $$$AssertTrue($IsObject($Get(tEntry)) && (tEntry.class = tClass) && (tEntry.kind = "write") && (tEntry.advertised = 1), $List(tCase, 2) _ ": a registered, advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "Advertised") _ "/" _ $Piece($Parameter(tClass, "DESCRIPTORCLASS"), ".", *) _ "/" _ $ClassMethod(tClass, "PortClass") _ "/" _ $ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "ReadType") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "SendsBody") _ "/" _ $ClassMethod(tClass, "Destructive") _ "/" _ $ClassMethod(tClass, "ChangeAction") _ "/" _ $ListToString($ClassMethod(tClass, "FingerprintSubject"), "+") _ "/" _ $ClassMethod(tClass, "PreconditionField") _ "/" _ $Parameter(tClass, "CLASSICPAGES"), "1/" _ $List(tCase, 3) _ "/OcuPilot.Port.AtelierPort/" _ $List(tCase, 4) _ "/SAVEDOCS/SAVE/0/1/updated/Modified+Absent+Namespace+content+version+Compile/Modified/", $List(tCase, 2) _ ": its declarations")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", $List(tCase, 2) _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "save")) _ " " _ $ListToString($ClassMethod(tClass, "SettableFields")), "save content,version,Compile content,version,Compile", $List(tCase, 2) _ ": carrying the list's save and its three values")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Set tNames = ""
        Set tIterator = tSchema.properties.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) { Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName }
        Do $$$AssertEquals(tNames _ " " _ tSchema.required.%ToJSON() _ " " _ tSchema.additionalProperties, "Names,Edits,rationale,expectedImpact,reverse [""Names"",""Edits""] 0", $List(tCase, 2) _ ": a closed schema naming the document and the replacements")
        Set tOne = $Select($List(tCase, 4) = "Classes": "A.cls", 1: "A.mac")
        Do $$$AssertEquals($ClassMethod(tClass, "SetProblem", tOne) _ "|" _ ($ClassMethod(tClass, "SetProblem", tOne _ "," _ $Replace(tOne, "A.", "B.")) '= ""), "|1", $List(tCase, 2) _ ": exactly one document")
    }
}

/// <p>Story 19.3 AC2: the two editors validate as unlisted form pages at their list's route plus
/// <code>/editor</code>, gated on the measured pair, declaring no read, no table, no action and no
/// context field, the viewer's own prompts, and no classic page and no exemption, so they carry no
/// classic link: new capability, not parity. Their screen context names no tool.</p>
/// <p>Mutation (Rule 19): set <code>classicPage</code> on
/// <class>OcuPilot.Screen.Descriptor.ExplorerClassEditor</class> -- this goes red.</p>
Method TestTheEditorsAreFormPagesWithNoClassicPage()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.ExplorerClassEditor", "system-explorer/classes/editor", "class", "explorer.classeditor", "OcuPilot.Screen.Descriptor.ExplorerClassDocument"), $ListBuild("OcuPilot.Screen.Descriptor.ExplorerRoutineEditor", "system-explorer/routines/editor", "routine", "explorer.routineeditor", "OcuPilot.Screen.Descriptor.ExplorerRoutineDocument") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.area _ "|" _ tDeclaration.id.kind, $List(tCase, 2) _ "|0|form-page|" _ $List(tCase, 3) _ "|namespace|system-explorer|single", tClass _ ": an unlisted form page keyed by one document")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, tClass _ ": gated on %Development:USE")
        Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "unassigned|unassigned|0||{""fields"":[],""secretFields"":[]}", tClass _ ": no read, no table, no action and no context field")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicPage _ "|" _ tDeclaration.classicLinkExemption.exempt, "||0", tClass _ ": no classic page and no exemption")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 4)), tClass, tClass _ ": its tool identifier resolves to it")
        Set tSC = $ClassMethod($List(tCase, 5), "DeclarationJson", .tViewer)
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%ToJSON(), $Select($$$ISOK(tSC): tViewer.suggestedPrompts.%ToJSON(), 1: ""), tClass _ ": the viewer's own prompts")
        Kill tTools
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), tClass _ ": its context tools build")
        Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[]", tClass _ ": and name none")
    }
}

/// <p>Story 19.4 AC7: Compare is a listed form page with no read, no table, no action, no context
/// field and no tool, keyed to the classic Compare Routines page, which the portal's own resolver
/// answers and whose compiled <code>RESOURCE</code> is <code>%Development:USE</code>, the pair it
/// declares; Search and Macros declare no classic page.</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Screen.Descriptor.ExplorerCompare</class>'s
/// <code>classicPage</code> to <code>""</code> -- this goes red.</p>
Method TestCompareKeysTheClassicCompareRoutinesPage()
{
    Set tClass = "OcuPilot.Screen.Descriptor.ExplorerCompare"
    Set tPage = "%CSP.UI.Portal.RoutineCompare"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.secondaryEntityTypes.%ToJSON() _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind, "system-explorer/compare|4|form-page|class|[""routine""]|namespace|none", "a listed form page over classes and routines, keyed by nothing")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "unassigned|unassigned|0||{""fields"":[],""secretFields"":[]}", "no read, no table, no action and no context field")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicLinkExemption.exempt, tPage _ "|0", "keyed to the classic Compare Routines page, with no exemption")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace(tPage, "%", "%25") _ ".zen"), tPage, "which the portal's own resolver answers")
    Set tResource = ##class(%Dictionary.CompiledParameter).%OpenId(tPage _ "||RESOURCE")
    Do $$$AssertEquals($Select($IsObject(tResource): tResource.Default, 1: ""), "%Development:USE", "and whose compiled RESOURCE is the pair it declares")
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.compare.read", .tEntry, 1)
    Do $$$AssertTrue('$IsObject($Get(tEntry)), "it has no read tool")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), "its context tools build")
    Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[]", "and name none")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("explorer.compare"), tClass, "its tool identifier resolves to it")
    For tOther = "OcuPilot.Screen.Descriptor.ExplorerSearch", "OcuPilot.Screen.Descriptor.ExplorerMacro" {
        Do $$$AssertEquals($ClassMethod(tOther, "ClassicPage"), "", tOther _ " declares no classic page")
    }
}

/// <p>Story 19.6 AC8: SQL query is a listed form page at side-bar position 10 with no read, no table
/// and no context field, its one row action <code>run</code>, keyed by nothing, gated on
/// <code>%Development:USE</code> and keyed to the classic SQL page, which the portal's own resolver
/// answers; a custom resource an operator assigns to that page gates it; its tool identifier resolves
/// to it and its context names the agent's query and its confirmed run (Story 19.11).</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Screen.Descriptor.ExplorerSqlQuery</class>'s
/// <code>classicPage</code> to <code>""</code> -- this goes red.</p>
Method TestSqlQueryKeysTheClassicSqlPage()
{
    Set tClass = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind, "system-explorer/sql-query|10|form-page|class|namespace|none", "a listed form page over classes, keyed by nothing")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%ToJSON() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON(), "unassigned|unassigned|[{""id"":""run"",""selfProtection"":""""}]||{""fields"":[],""secretFields"":[]}", "no read, no table, its run and no context field")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicLinkExemption.exempt, ..#SQLPAGE _ "|0", "keyed to the classic SQL page, with no exemption")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/" _ $Replace(..#SQLPAGE, "%", "%25") _ ".zen"), ..#SQLPAGE, "which the portal's own resolver answers")
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Development", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", tClass, .tFailed), "the measured pair alone opens it while the page carries no custom resource")
    Do $ClassMethod(tGate, "AssignClassic", ..#SQLPAGE, "OcuPilotTestCustomResource")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", tClass, .tFailed) && (tFailed = "OcuPilotTestCustomResource:USE"), "and a custom resource on the page refuses it, named: " _ tFailed)
    Do $ClassMethod(tGate, "Reset")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("explorer.sqlquery"), tClass, "its tool identifier resolves to it")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), "its context tools build")
    Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[""explorer_sqlquery_read"",""explorer_sqlquery_run""]", "and name the agent's query and its confirmed run (Story 19.11)")
}

/// <p>Story 19.7 AC9: Data browser is a listed form page at side-bar position 11 with no read, no
/// table and no context field, whose one action is Story 19.8's save, keyed by nothing, gated on <code>%Development:USE</code> and
/// keyed to the classic Open Table page, which the portal's own resolver answers for
/// <code>/csp/sys/exp/UtilSqlOpen.csp</code>; a custom resource an operator assigns to that page gates
/// it; its tool identifier resolves to it and its context names no tool.</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Screen.Descriptor.ExplorerSqlData</class>'s
/// <code>classicPage</code> to <code>""</code> -- this goes red.</p>
Method TestDataBrowserKeysTheClassicOpenTablePage()
{
    Set tClass = "OcuPilot.Screen.Descriptor.ExplorerSqlData"
    Set tPage = "%cspapp.exp.utilsqlopen"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.labelKey, "system-explorer/sql-data|11|form-page|class|namespace|none|explorerSqlDataLabel", "a listed form page over classes, keyed by nothing")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table") _ "|" _ tDeclaration.rowActions.%ToJSON() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.%ToJSON() _ "|" _ tDeclaration.refreshes, "unassigned|unassigned|[{""id"":""save"",""selfProtection"":""""}]||{""fields"":[],""secretFields"":[]}|0", "no read, no table, the save as its one action, no context field and no refresh")
    Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), "[""data browser"",""open table"",""browse table"",""table rows""]", "its four aliases")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#PAIRS, "gated on %Development:USE")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.classicLinkExemption.exempt, tPage _ "|0", "keyed to the classic Open Table page, with no exemption")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/exp/UtilSqlOpen.csp"), tPage, "which the portal's own resolver answers")
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Development", "USE")
    Set tFailed = "unset"
    Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", tClass, .tFailed), "the measured pair alone opens it while the page carries no custom resource")
    Do $ClassMethod(tGate, "AssignClassic", tPage, "OcuPilotTestCustomResource")
    Set tFailed = "unset"
    Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", tClass, .tFailed) && (tFailed = "OcuPilotTestCustomResource:USE"), "and a custom resource on the page refuses it, named: " _ tFailed)
    Do $ClassMethod(tGate, "Reset")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("explorer.sqldata"), tClass, "its tool identifier resolves to it")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), "its context tools build")
    Do $$$AssertEquals($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""), "[]", "and name none")
}

/// <p>Stories 19.5 and 19.14 AC1, AD-5: a table's nine tabs form one parent-scoped group at the SQL
/// tables list's route plus <code>/document</code> -- Table info, Fields, Maps/Indices, Partitions,
/// Partition mappings, Triggers, Constraints, Cached queries and SQL statements at positions 1 to 9, the
/// classic SQL page's order, each unlisted, each naming that list as its parent and reading its one
/// criterion <code>table</code>, at most 257 characters; the classic SQL page's compiled
/// <code>RESOURCE</code> is <code>%Development</code>, the pair every catalog screen declares.</p>
Method TestTheTableTabsFormOneParentScopedGroup()
{
    Set tGroup = "system-explorer/sql-tables/document"
    Set tSeen = ""
    For tName = "ExplorerSqlTable", "ExplorerSqlFields", "ExplorerSqlIndices", "ExplorerSqlPartitions", "ExplorerSqlPartitionMappings", "ExplorerSqlTriggers", "ExplorerSqlConstraints", "ExplorerSqlCachedQueries", "ExplorerSqlTableStatements" {
        Set tClass = "OcuPilot.Screen.Descriptor." _ tName
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tDeclaration), "", tClass _ ": its tab validates")
        Set tCriteria = tDeclaration.read.criteria.fields
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ";") _ tDeclaration.tab.position _ " " _ tDeclaration.tab.labelKey _ " " _ tDeclaration.parentScope _ " " _ tDeclaration.sideBarPosition _ " " _ tDeclaration.id.kind _ " " _ tCriteria.%Size() _ " " _ tCriteria.%Get(0).param _ "/" _ tCriteria.%Get(0).kind _ "/" _ tCriteria.%Get(0).maxLength
        Do $$$AssertEquals(tDeclaration.tab.group, tGroup, tClass _ ": in the one group")
    }
    Do $$$AssertEquals(tSeen, "1 explorerSqlTabInfo system-explorer/sql-tables 0 single 1 table/text/257;2 explorerSqlTabFields system-explorer/sql-tables 0 single 1 table/text/257;3 explorerSqlTabIndices system-explorer/sql-tables 0 single 1 table/text/257;4 explorerSqlTabPartitions system-explorer/sql-tables 0 single 1 table/text/257;5 explorerSqlTabPartitionMappings system-explorer/sql-tables 0 single 1 table/text/257;6 explorerSqlTabTriggers system-explorer/sql-tables 0 single 1 table/text/257;7 explorerSqlTabConstraints system-explorer/sql-tables 0 single 1 table/text/257;8 explorerSqlTabCachedQueries system-explorer/sql-tables 0 single 1 table/text/257;9 explorerSqlTabStatements system-explorer/sql-tables 0 single 1 table/text/257", "positions 1 to 9, each unlisted under the SQL tables list, reading table")
    Set tResource = ##class(%Dictionary.CompiledParameter).%OpenId(..#SQLPAGE _ "||RESOURCE")
    Do $$$AssertEquals($Select($IsObject(tResource): tResource.Default, 1: ""), "%Development", "the classic SQL page's compiled RESOURCE is %Development")
}

/// <p>Story 19.14 AD-5, AC2, AC3: a view's three tabs form one parent-scoped group at the SQL views
/// list's route plus <code>/document</code>, View info, Fields and SQL statements, each reading its one
/// criterion <code>view</code>; and a procedure's two at the SQL procedures list's, Stored procedure
/// info and SQL statements, each reading <code>procedure</code>; every tab unlisted and at most 257
/// characters, and the groups validate on the roster.</p>
Method TestTheViewAndProcedureTabsFormTheirGroups()
{
    For tCase = $ListBuild("views", "view", "ExplorerSqlView,ExplorerSqlViewFields,ExplorerSqlViewStatements", "explorerSqlTabViewInfo,explorerSqlTabFields,explorerSqlTabStatements"), $ListBuild("procedures", "procedure", "ExplorerSqlProcedure,ExplorerSqlProcedureStatements", "explorerSqlTabProcedureInfo,explorerSqlTabStatements") {
        Set tParent = "system-explorer/sql-" _ $List(tCase, 1)
        Set tSeen = ""
        Set tWant = ""
        For tI = 1:1:$Length($List(tCase, 3), ",") {
            Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece($List(tCase, 3), ",", tI)
            Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
            Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
            If $$$ISERR(tSC) Continue
            Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tDeclaration), "", tClass _ ": its tab validates")
            Set tCriteria = tDeclaration.read.criteria.fields
            Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ";") _ tDeclaration.tab.group _ " " _ tDeclaration.tab.position _ " " _ tDeclaration.tab.labelKey _ " " _ tDeclaration.parentScope _ " " _ tDeclaration.sideBarPosition _ " " _ tCriteria.%Size() _ " " _ tCriteria.%Get(0).param _ "/" _ tCriteria.%Get(0).kind _ "/" _ tCriteria.%Get(0).maxLength
            Set tWant = tWant _ $Select(tWant = "": "", 1: ";") _ tParent _ "/document " _ tI _ " " _ $Piece($List(tCase, 4), ",", tI) _ " " _ tParent _ " 0 1 " _ $List(tCase, 2) _ "/text/257"
        }
        Do $$$AssertEquals(tSeen, tWant, "the " _ $List(tCase, 1) _ "' group, in order, each reading " _ $List(tCase, 2))
    }
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the roster, its tab groups among it, validates: " _ $Get(tProblem))
}

/// <p>Story 19.14 (DW-1977): the three SQL statements reads declare the statistics note, and the
/// description each read tool is registered with is the read tools' sentence naming its screen, then
/// the note's text; Table info's read declares none, and its tool's description is that sentence
/// alone.</p>
/// <p>Mutation (Rule 19): drop the note from
/// <class>OcuPilot.Screen.Descriptor.ExplorerSqlViewStatements</class> -- its two legs go red; drop the
/// append from <method>OcuPilot.Screen.Tool.Read.Description</method>, or replace the sentence with the
/// note instead of appending it -- the three description legs go red.</p>
Method TestTheStatementsToolsEndWithTheStatisticsNote()
{
    Set tText = "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."
    Set tWant = {"key": "explorerSqlStatementsNote", "text": (tText)}.%ToJSON()
    For tCase = $ListBuild("ExplorerSqlTableStatements", "explorer.sqltablestatements.read"), $ListBuild("ExplorerSqlViewStatements", "explorer.sqlviewstatements.read"), $ListBuild("ExplorerSqlProcedureStatements", "explorer.sqlprocedurestatements.read") {
        Set tClass = "OcuPilot.Screen.Descriptor." _ $List(tCase, 1)
        Set tRead = $ClassMethod(tClass, "Read")
        Do $$$AssertEquals($Select($IsObject(tRead) && (tRead.%GetTypeOf("note") = "object"): tRead.note.%ToJSON(), 1: ""), tWant, tClass _ ": its read declares the note")
        Kill tEntry
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 2), .tEntry, 1)
        Do $$$AssertStatusOK(tSC, $List(tCase, 2) _ " resolves")
        Set tDescription = $Select($IsObject($Get(tEntry)): ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tEntry), 1: "")
        Do $$$AssertEquals(tDescription, "Read the rows the " _ $Piece($List(tCase, 2), ".", 1, 2) _ " screen lists, bounded and with secret fields removed. " _ tText, $List(tCase, 2) _ ": its description is the read sentence, then the note")
    }
    Set tRead = ##class(OcuPilot.Screen.Descriptor.ExplorerSqlTable).Read()
    Do $$$AssertEquals(tRead.%GetTypeOf("note"), "unassigned", "Table info's read declares no note")
    Kill tEntry
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.sqltable.read", .tEntry, 1)
    Do $$$AssertStatusOK(tSC, "explorer.sqltable.read resolves")
    Set tDescription = $Select($IsObject($Get(tEntry)): ##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tEntry), 1: "")
    Do $$$AssertEquals(tDescription, "Read the rows the explorer.sqltable screen lists, bounded and with secret fields removed.", "explorer.sqltable.read's description is the read sentence alone")
}

/// <p>Stories 19.5 AC6 and 19.14 AC9: a custom resource an operator assigns to the classic SQL page
/// gates all eighteen SQL catalog screens. The gate's classic-page store is
/// <class>OcuPilot.Test.ScreenGate</class>'s, so nothing is written to the instance.</p>
/// <p>Mutation (Rule 19): drop the classic-page union from
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> -> every refused row goes red.</p>
Method TestACustomResourceOnTheSqlPageGatesAllEighteen()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Do $ClassMethod(tGate, "Reset")
    Do $ClassMethod(tGate, "Hold", "%Development", "USE")
    Set tSql = $List($ListFromString(..#DESCRIPTORS), 10, 27)
    Do $$$AssertEquals($ListLength(tSql), 18, "the eighteen SQL catalog screens")
    For tI = 1:1:$ListLength(tSql) {
        Set tFailed = "unset"
        Do $$$AssertTrue($ClassMethod(tGate, "Evaluate", $List(tSql, tI), .tFailed), $List(tSql, tI) _ ": the measured pair alone opens it while the page carries no custom resource")
    }
    Do $ClassMethod(tGate, "AssignClassic", ..#SQLPAGE, "OcuPilotTestCustomResource")
    For tI = 1:1:$ListLength(tSql) {
        Set tFailed = "unset"
        Do $$$AssertTrue('$ClassMethod(tGate, "Evaluate", $List(tSql, tI), .tFailed), $List(tSql, tI) _ ": refused once the page carries one")
        Do $$$AssertEquals(tFailed, "OcuPilotTestCustomResource:USE", $List(tSql, tI) _ ": naming the operator's resource")
    }
    Do $ClassMethod(tGate, "Reset")
}

}
