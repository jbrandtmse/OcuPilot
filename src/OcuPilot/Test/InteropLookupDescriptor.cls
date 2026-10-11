/// <p>Pins Story 20.5's declarations (AD-5, AD-8, AD-13, AD-22, AD-35, AD-36, AD-44, AD-51, AD-54, AD-59, AD-62): the three
/// screens (Lookup tables, a table's entries and Business partners), the four write tools, the port's pairs, serving matrix
/// and endpoint roster, the codes' sentences, the bounds of <method>OcuPilot.Port.InteropPort.LookupViolations</method>, the
/// pure write decision, the script form of every write, the prohibited set's covered types, the governance defaults and the
/// two Save classes' codes, and the argument names the entry tools redact from the ledger.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. It reads no lookup table and writes nothing.</p>
Class OcuPilot.Test.InteropLookupDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter PREFIX = "OcuPilot.Screen.Descriptor.";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.";

/// <p>The screens, <code>&lt;class&gt;|&lt;route&gt;|&lt;position&gt;|&lt;entity type&gt;|&lt;endpoint&gt;|&lt;classic page&gt;|&lt;tool identifier&gt;</code>.</p>
Parameter SCREENS = "InteropLookupTableList|interoperability/lookup-tables|8|lookup-table|LookupTables|EnsPortal.LookupSettings|interop.lookuptables;InteropLookupEntryList|interoperability/lookup-tables/entries|0|lookup-entry|LookupEntries|EnsPortal.LookupSettings|interop.lookupentries;InteropBusinessPartnerList|interoperability/business-partners|9|business-partner|BusinessPartners|EnsPortal.BusinessPartners|interop.businesspartners";

/// <p>The four tools, <code>&lt;class&gt;|&lt;tool&gt;|&lt;write type&gt;|&lt;screen actions&gt;|&lt;destructive&gt;|&lt;change action&gt;|&lt;subject&gt;|&lt;consequence&gt;|&lt;governance key value&gt;|&lt;creates&gt;</code>.</p>
Parameter TOOLS = "InteropLookupEntryAdd|interop.lookupentries.add|ADDENTRY||0|created|||1|1;InteropLookupEntrySet|interop.lookupentries.set|SETENTRY|set|0|updated|||1|0;InteropLookupEntryRemove|interop.lookupentries.remove|REMOVEENTRY|remove|1|deleted|Key,Value|INTEROP.LOOKUP.REMOVE|0|0;InteropLookupTableDelete|interop.lookuptables.delete|DELETETABLE|delete|1|deleted|Name,Entries,Modified|INTEROP.LOOKUP.DELETE|0|0";

/// <p>The screens declare what the plan names: their routes, positions, entity types, ids, pairs (the endpoint's, the classic
/// page's resource as their own), actions, the entries list's one criterion and its parent, the tables list's secondary entity
/// type, three prompts each, the read source and the classic page; the partner list is read-only and says what to do next; and
/// each passes the registry.</p>
/// <p>Mutation (Rule 19): remove <code>parentScope</code> from the entries list, or <code>secondaryEntityTypes</code> from the
/// tables list -- this goes red.</p>
Method TestTheThreeDeclarationsRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the registry enumerates the descriptors")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PREFIX _ $Piece(tEntry, "|", 1)
        Do $$$AssertTrue($ListFind(tList, tClass) > 0, tClass _ " is among the registry's descriptors")
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ " declares JSON")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, $Piece(tEntry, "|", 2) _ "|" _ $Piece(tEntry, "|", 3) _ "|" _ $Piece(tEntry, "|", 4) _ "|" _ $Piece(tEntry, "|", 5) _ "|" _ $Piece(tEntry, "|", 6) _ "|" _ $Piece(tEntry, "|", 7), tClass _ ": route, position, entity, endpoint, classic page and tool identifier")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.type _ "|" _ tDeclaration.built _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.refreshes, "interop|LIST|1|namespace|0", tClass _ ": an interop LIST, built, namespace-scoped, never refreshing")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        ; The pairs are the port's own endpoint pairs, the classic page's resource as the screen's own.
        Set tPairs = ##class(OcuPilot.Test.InteropHostDescriptor).PairText(tDeclaration.privileges)
        Set tEndpointPairs = ##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", tDeclaration.read.source.endpoint, "LIST"))
        Do $$$AssertEquals(tPairs, tEndpointPairs, tClass _ ": its pairs are the port's endpoint pairs")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText(tDeclaration.ownPrivileges), ##class(OcuPilot.Test.InteropHostDescriptor).OwnText(tPairs), tClass _ ": its own pairs are those less the Interoperability menu's")
    }
    Set tTables = ..Declaration("InteropLookupTableList")
    Set tEntries = ..Declaration("InteropLookupEntryList")
    Set tPartners = ..Declaration("InteropBusinessPartnerList")
    Do $$$AssertEquals(tTables.primaryAction.id _ "|" _ tTables.rowActions.%Get(0).id _ "|" _ tTables.rowActions.%Size() _ "|" _ tTables.secondaryEntityTypes.%Get(0) _ "|" _ tTables.id.kind, "add|delete|5|lookup-entry|single", "the tables list adds a table, deletes one, exports, imports from the server and from this computer, and re-reads on an entry change")
    Do $$$AssertEquals(tEntries.primaryAction.id _ "|" _ tEntries.rowActions.%Get(0).id _ "," _ tEntries.rowActions.%Get(1).id _ "|" _ tEntries.parentScope _ "|" _ tEntries.id.kind _ "|" _ tEntries.id.parts.%Get(0) _ "," _ tEntries.id.parts.%Get(1), "add|set,remove|interoperability/lookup-tables|composite|Table,Key", "the entries list adds, sets and removes, under the tables list, by the composite [Table, Key]")
    Do $$$AssertEquals(tEntries.read.criteria.fields.%Size() _ "|" _ tEntries.read.criteria.fields.%Get(0).param _ "|" _ tEntries.read.criteria.fields.%Get(0).maxLength, "1|table|255", "its one criterion is the table")
    Do $$$AssertTrue(tEntries.read.criteria.fields.%Get(0).hint [ "interop.lookuptables.read", "whose hint names the tables read tool")
    Do $$$AssertEquals(tPartners.primaryAction.id _ "|" _ tPartners.rowActions.%Size() _ "|" _ (tPartners.table.emptyNextKey '= "") _ "|" _ (tPartners.table.emptyAgentKey = ""), "|0|1|1", "the partners list offers no action and says what to do next")
    Do $$$AssertEquals(tPartners.read.fields.%Size(), 14, "and reads the partner's name, description and both contacts' six fields")
}

/// <p>The four write tools declare what the plan names, resolve through the tool registry as writes, carry the lookup write
/// pair and the globals database beyond their screen's pairs, declare no classic page (the operation is the screen's own),
/// and the governance baseline ships the two destructive ones disabled.</p>
/// <p>Mutation (Rule 19): change the remove's <code>DESTRUCTIVE</code> to 0, or drop <code>%Ens_LookupTables</code> from
/// <method>OcuPilot.Screen.Tool.InteropLookupEntryAction</method>'s write resource -- this goes red.</p>
Method TestTheFourWriteToolsAreDeclaredAsThePlanPlacesThem()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    Kill tByName
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tByName(tTool.name) = tTool
    }
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tEntry = $Piece(..#TOOLS, ";", tI)
        Set tClass = ..#TOOLPREFIX _ $Piece(tEntry, "|", 1)
        Set tName = $Piece(tEntry, "|", 2)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), tName, tClass _ " is " _ tName)
        Do $$$AssertTrue($Data(tByName(tName)) > 0, tName _ " is in the tool registry")
        If $Data(tByName(tName)) Do $$$AssertEquals(tByName(tName).kind, "write", tName _ " is a write tool")
        Do $$$AssertEquals($Parameter(tClass, "WRITETYPE"), $Piece(tEntry, "|", 3), tName _ ": its write type")
        Do $$$AssertEquals($Parameter(tClass, "SCREENACTIONS"), $Piece(tEntry, "|", 4), tName _ ": its screen actions")
        Do $$$AssertEquals(+$ClassMethod(tClass, "Destructive"), +$Piece(tEntry, "|", 5), tName _ ": destructive or not")
        Do $$$AssertEquals($ClassMethod(tClass, "ChangeAction"), $Piece(tEntry, "|", 6), tName _ ": its change action")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), $Piece(tEntry, "|", 7), tName _ ": its fingerprint subject")
        Do $$$AssertEquals($Parameter(tClass, "CONSEQUENCECODE"), $Piece(tEntry, "|", 8), tName _ ": its consequence code")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", tName _ " declares no classic page: the operation is the screen's own (AD-44)")
        Do $$$AssertEquals(+$ClassMethod(tClass, "Creates"), +$Piece(tEntry, "|", 10), tName _ ": creates its target or not")
        Do $$$AssertEquals(+##class(OcuPilot.Kernel.Governance.Baseline).Seed(tName, .tListed) _ "|" _ tListed, $Piece(tEntry, "|", 9) _ "|1", tName _ ": the baseline ships it " _ $Select($Piece(tEntry, "|", 9): "enabled", 1: "disabled"))
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved, tName _ ": its pairs resolve in this namespace")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Ens_LookupTables", "WRITE")) > 0, tName _ " requires %Ens_LookupTables:WRITE")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Ens_LookupTables", "READ")) > 0, tName _ " and the screen's own read pair")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.InteropLookupEntryMint).%GetParameter("NAMESPACEARGUMENT") _ "|" _ $ClassMethod(..#TOOLPREFIX _ "InteropLookupEntrySet", "IdArgument"), "Table|Key", "the entry tools' mint names the table, and the key is the id argument")
    Do $$$AssertEquals($ClassMethod(..#TOOLPREFIX _ "InteropLookupEntryAdd", "ReadBackTool"), ..#TOOLPREFIX _ "InteropLookupEntrySet", "the add's read-back reads the created entry through the set")
}

/// <p>The two transfer tools declare what the plan names: the export writes a file and only reads the table (READ on the lookup resource and
/// the globals database and the file system's pair, the baseline ships it enabled, it is not destructive and it performs no classic page of its own), and the import replaces
/// a table (WRITE on both, the baseline ships it disabled, destructive, the classic Import dialog's operation, and its text only in its screen
/// values); both resolve through the tool registry as writes.</p>
/// <p>Mutation (Rule 19): change the import's <code>DESTRUCTIVE</code> to 0, or its governance key's baseline to enabled -- this goes
/// red.</p>
Method TestTheTwoTransferToolsAreDeclaredAsThePlanPlacesThem()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    Kill tByName
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tByName(tTool.name) = tTool
    }
    ; <class>|<tool>|<write type>|<screen actions>|<destructive>|<change action>|<subject>|<baseline enabled>|<WRITE pair held>|<classic page>
    Set tRoster = "InteropLookupTableExport|interop.lookuptables.export|EXPORT|export,export-browser|0|updated|Name,Entries,Modified,Namespace,root,path|1|0|;InteropLookupTableImport|interop.lookuptables.import|IMPORT|import,import-local|1|updated|Namespace,root,path,fileName,content,Table,FileEntries,Digest,Present,Entries,Modified|0|1|EnsPortal.Dialog.Import"
    For tI = 1:1:$Length(tRoster, ";") {
        Set tEntry = $Piece(tRoster, ";", tI)
        Set tClass = ..#TOOLPREFIX _ $Piece(tEntry, "|", 1)
        Set tName = $Piece(tEntry, "|", 2)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), tName, tClass _ " is " _ tName)
        Do $$$AssertTrue($Data(tByName(tName)) > 0, tName _ " is in the tool registry")
        If $Data(tByName(tName)) Do $$$AssertEquals(tByName(tName).kind, "write", tName _ " is a write tool")
        Do $$$AssertEquals($Parameter(tClass, "WRITETYPE") _ "|" _ $Parameter(tClass, "SCREENACTIONS") _ "|" _ +$ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "ChangeAction"), $Piece(tEntry, "|", 3) _ "|" _ $Piece(tEntry, "|", 4) _ "|" _ $Piece(tEntry, "|", 5) _ "|" _ $Piece(tEntry, "|", 6), tName _ ": write type, screen actions, destructive and change action")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), $Piece(tEntry, "|", 7), tName _ ": its fingerprint subject")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $Piece(tEntry, "|", 10), tName _ ": its classic page")
        Do $$$AssertEquals(+##class(OcuPilot.Kernel.Governance.Baseline).Seed(tName, .tListed) _ "|" _ tListed, $Piece(tEntry, "|", 8) _ "|1", tName _ ": the baseline ships it " _ $Select($Piece(tEntry, "|", 8): "enabled", 1: "disabled"))
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved, tName _ ": its pairs resolve in this namespace")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Ens_LookupTables", "READ")) > 0, tName _ " requires %Ens_LookupTables:READ")
        Do $$$AssertEquals($ListFind(tPairs, $ListBuild("%Ens_LookupTables", "WRITE")) > 0, +$Piece(tEntry, "|", 9), tName _ ": holds the lookup write pair or not")
        Do $$$AssertEquals($ListFind(tPairs, $ListBuild("%Admin_FileSystemAccess", "USE")) > 0, 1 - $Piece(tEntry, "|", 9), tName _ ": only the export writes a file of its own, so only it requires the file system's pair")
    }
}

/// <p>The port's pairs, serving matrix and endpoint roster: both lookup endpoints take the classic Lookup Tables page's pairs,
/// the partners the Productions endpoint's, every lookup write adds <code>%Ens_LookupTables:WRITE</code>, and each endpoint
/// serves exactly the types the plan lists.</p>
/// <p>Mutation (Rule 19): drop <code>DELETETABLE</code> from <method>OcuPilot.Port.InteropPort.Serves</method> -- this goes red.</p>
Method TestThePortDeclaresItsPairsAndServesWhatThePlanSays()
{
    Set tText = ##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupTables", "LIST"))
    Do $$$AssertEquals(tText, "%Ens_Portal:USE,%Ens_LookupTables:READ", "the Lookup tables endpoint's pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupEntries", "LIST")), tText, "and the entries endpoint's")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "BusinessPartners", "LIST")), "%Ens_Portal:USE,%Ens_ProductionConfig:READ", "the partners endpoint takes the Productions endpoint's")
    For tType = "ADDENTRY", "SETENTRY", "REMOVEENTRY" {
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupEntries", tType)), tText _ ",%Ens_LookupTables:WRITE", tType _ " adds the lookup write pair")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupTables", "DELETETABLE")), tText _ ",%Ens_LookupTables:WRITE", "so does the table delete")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupTables", "IMPORT")), tText _ ",%Ens_LookupTables:WRITE", "and the import")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupTables", "EXPORT")) _ "|" _ ##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupTables", "IMPORTTABLE")), tText _ "|" _ tText, "while the export, which only reads the table, and the import's read add none")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "LookupEntries", "LOOKUPENTRY")), tText, "and a read adds none")
    Set tServed = ""
    For tEndpoint = "LookupTables", "LookupEntries", "BusinessPartners" {
        For tType = "LIST", "LOOKUPTABLE", "LOOKUPENTRY", "ADDENTRY", "SETENTRY", "REMOVEENTRY", "DELETETABLE", "IMPORTTABLE", "IMPORT", "EXPORT", "STATE", "ITEM" {
            If $ClassMethod(..#PORT, "Serves", tEndpoint, tType) Set tServed = tServed _ $Select(tServed = "": "", 1: ";") _ tEndpoint _ "=" _ tType
        }
    }
    Do $$$AssertEquals(tServed, "LookupTables=LIST;LookupTables=LOOKUPTABLE;LookupTables=DELETETABLE;LookupTables=IMPORTTABLE;LookupTables=IMPORT;LookupTables=EXPORT;LookupEntries=LIST;LookupEntries=LOOKUPENTRY;LookupEntries=ADDENTRY;LookupEntries=SETENTRY;LookupEntries=REMOVEENTRY;BusinessPartners=LIST", "each endpoint serves exactly its types")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "Endpoints"), "LookupTables") && $ListFind($ClassMethod(..#PORT, "Endpoints"), "BusinessPartners"), "and the endpoint roster carries the three")
    For tType = "ADDENTRY", "SETENTRY", "REMOVEENTRY", "DELETETABLE", "IMPORT" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "IsLookupWrite", tType), tType _ " is a lookup write")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "IsLookupWrite", "LOOKUPENTRY") && '$ClassMethod(..#PORT, "IsLookupWrite", "ENABLE") && '$ClassMethod(..#PORT, "IsLookupWrite", "EXPORT") && '$ClassMethod(..#PORT, "IsLookupWrite", "IMPORTTABLE"), "and a read, an export or an item write is not")
}

/// <p>The decision a lookup write is refused with, over the state matrix, and the violations' bounds at 255/256 characters of
/// a table and a key and 32,000/32,001 of a value, a control character in a name, and an empty one.</p>
/// <p>Mutation (Rule 19): drop the <code>SAME</code> test from <method>OcuPilot.Port.InteropPort.LookupWriteToken</method>,
/// raise <code>VALUEMAX</code> to 32001, or lower <code>KEYMAX</code> to 100 -- this goes red.</p>
Method TestTheWriteDecisionAndTheBoundsAreTheVendors()
{
    Set tPort = ..#PORT
    ; pType, exists, match, keyExists, held, value
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "ADDENTRY", 1, "", 1, "a", "b"), "TAKEN", "an add of a held key is taken")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "ADDENTRY", 0, "ocu", 0, "", "b"), "TABLECASE", "an add into a table held in another case is refused for it")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "ADDENTRY", 0, "", 0, "", "b"), "", "an add into an absent table creates it")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "ADDENTRY", 1, "", 0, "", "b"), "", "an add of a new key to a held table goes ahead")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "SETENTRY", 1, "", 1, "a", "a"), "SAME", "a set of the value held is the same")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "SETENTRY", 1, "", 1, "a", ""), "", "a set to an empty value goes ahead")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "SETENTRY", 1, "", 0, "", "a"), "ABSENT", "a set of an absent key is absent")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "SETENTRY", 1, "", 1, "1.0", "1"), "", "values are compared as text, so 1.0 and 1 differ")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "REMOVEENTRY", 0, "", 0, "", ""), "ABSENT", "a remove from an absent table is absent")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "REMOVEENTRY", 1, "", 1, "a", ""), "", "a remove of a held entry goes ahead")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "DELETETABLE", 0, "", 0, "", ""), "ABSENT", "a delete of an absent table is absent")
    Do $$$AssertEquals($ClassMethod(tPort, "LookupWriteToken", "DELETETABLE", 1, "", 0, "", ""), "", "a delete of a held table goes ahead")
    Set tE = ..#ERROR
    Set tAt = $Parameter(tE, "LOOKUPTABLENAME") _ "|" _ $Parameter(tE, "LOOKUPKEY") _ "|" _ $Parameter(tE, "LOOKUPVALUE")
    Do $$$AssertEquals(tAt, "INTEROP.LOOKUP.TABLENAME|INTEROP.LOOKUP.KEY|INTEROP.LOOKUP.VALUE", "the three violation codes")
    Do $ClassMethod(tPort, "LookupViolations", $Justify("", 255), $Justify("", 255), $Justify("", 32000), .tViolations)
    Do $$$AssertEquals(tViolations, 0, "255 characters of table and key and 32,000 of value are within the bounds")
    Do $ClassMethod(tPort, "LookupViolations", $Justify("", 256), $Justify("", 256), $Justify("", 32001), .tViolations)
    Do $$$AssertEquals($ListToString($ListBuild($List(tViolations(1), 1), $List(tViolations(2), 1), $List(tViolations(3), 1))) _ "|" _ tViolations, "Table,Key,Value|3", "256 characters of table and key and 32,001 of value each break their bound")
    Do $$$AssertEquals($List(tViolations(1), 2) _ "|" _ $List(tViolations(2), 2) _ "|" _ $List(tViolations(3), 2), tAt, "with the codes in that order")
    Do $ClassMethod(tPort, "LookupViolations", "", "", "", .tViolations)
    Do $$$AssertEquals(tViolations, 2, "an empty table and an empty key are violations, an empty value is not")
    Do $ClassMethod(tPort, "LookupViolations", "a" _ $Char(10) _ "b", "k" _ $Char(9), "v" _ $Char(10), .tViolations)
    Do $$$AssertEquals(tViolations, 2, "a control character in a table or a key is a violation and one in a value is not")
}

/// <p>Every lookup code resolves to its sentence, the sentences name no caller, the two consequences are in the consequence
/// list and the rest in the code list, and the two Save classes' literal codes equal their sources.</p>
/// <p>Mutation (Rule 19): change <code>TAKENCODE</code> in <class>OcuPilot.Area.Interop.LookupEntrySave</class> -- this goes
/// red.</p>
Method TestTheCodesResolveAndTheSaveClassesHoldTheirSources()
{
    Set tE = ..#ERROR
    Set tCodes = $ClassMethod(tE, "LookupCodes")
    Do $$$AssertEquals($ListLength(tCodes), 12, "twelve lookup refusals and violations")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertTrue($ClassMethod(tE, "ReasonFor", tCode) '= "", tCode _ " has a sentence")
        Do $$$AssertTrue($ListFind($ClassMethod(tE, "Codes"), tCode) > 0, tCode _ " is among the refusals the port answers with")
        Do $$$AssertTrue($Extract(tCode, 1, 15) = "INTEROP.LOOKUP.", tCode _ " is a lookup code")
        Do $$$AssertTrue(($ClassMethod(tE, "ReasonFor", tCode) '[ "agent") && ($ClassMethod(tE, "ReasonFor", tCode) '[ "Agent"), tCode _ " names no caller")
    }
    For tCode = "INTEROP.LOOKUP.REMOVE", "INTEROP.LOOKUP.DELETE", "INTEROP.LOOKUP.IMPORT" {
        Do $$$AssertTrue($ListFind($ClassMethod(tE, "ConsequenceCodes"), tCode) > 0, tCode _ " is a consequence code")
        Do $$$AssertTrue($ClassMethod(tE, "ReasonFor", tCode) '= "", tCode _ " has a sentence")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(tE, "LookupPreconditionCodes")), "INTEROP.LOOKUP.TAKEN,INTEROP.LOOKUP.TABLECASE,INTEROP.LOOKUP.SECRET,INTEROP.LOOKUP.SOURCECONTROL", "the precondition codes are those an entry's fresh read answers")
    Set tItemSave = "OcuPilot.Area.Interop.ItemSave"
    Set tEntrySave = "OcuPilot.Area.Interop.LookupEntrySave"
    Do $$$AssertEquals($Parameter(tItemSave, "TAKENCODE") _ "|" _ $Parameter(tItemSave, "TAKENREASON") _ "|" _ $Parameter(tItemSave, "NAMEEMPTYCODE") _ "|" _ $Parameter(tItemSave, "PARENTEMPTYCODE"), $Parameter(tE, "ITEMTAKEN") _ "|" _ $Parameter(tE, "REASONITEMTAKEN") _ "|" _ $Parameter(tE, "ITEMNAME") _ "|" _ ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "the item Save's codes are its sources'")
    Do $$$AssertEquals($Parameter(tEntrySave, "TAKENCODE") _ "|" _ $Parameter(tEntrySave, "TAKENREASON") _ "|" _ $Parameter(tEntrySave, "NAMEEMPTYCODE") _ "|" _ $Parameter(tEntrySave, "PARENTEMPTYCODE"), $Parameter(tE, "LOOKUPTAKEN") _ "|" _ $Parameter(tE, "REASONLOOKUPTAKEN") _ "|" _ $Parameter(tE, "LOOKUPKEY") _ "|" _ $Parameter(tE, "LOOKUPTABLENAME"), "and the entry Save's")
    Do $$$AssertEquals($Parameter(tEntrySave, "PRODUCTIONMEMBER") _ "|" _ $Parameter(tEntrySave, "NAMEMEMBER") _ "|" _ $Parameter(tEntrySave, "CREATETOOL"), "Table|Key|OcuPilot.Screen.Tool.InteropLookupEntryAdd", "whose members are the table and the key, through the add tool")
    Do $$$AssertEquals($ClassMethod(tEntrySave, "ParentHeld", "USER", "AnyTableAtAll") _ "|" _ $ClassMethod(tItemSave, "ParentHeld", "USER", "OcuProbe.No.Such.Production"), "1|0", "a table is never held before its first entry, and an absent production is")
}

/// <p>AD-3, AD-41, AD-35: the entry tools answer the argument names their ledger row and step redact for one call
/// (<method>OcuPilot.Screen.Tool.InteropLookupEntryAction.CallSecretNames</method>): <code>Value</code> when the call names a key
/// the credential pattern matches, and none for an ordinary key, a call with no key or one that is not an object. The add and the
/// set carry a value; the remove shares the entry base class's answer, so a value sent beside its key is redacted too. The table
/// delete, the two transfers and every read tool answer none, and the registry answers each tool's names.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropLookupEntryAction.CallSecretNames</method> quit <code>""</code>
/// -- the credential-key rows go red.</p>
Method TestTheCallSecretNamesAreTheEntryToolsAlone()
{
    For tTool = "InteropLookupEntryAdd", "InteropLookupEntrySet", "InteropLookupEntryRemove" {
        Set tClass = ..#TOOLPREFIX _ tTool
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CallSecretNames", {"Table": "T", "Key": "dbpassword", "Value": "x"})), "Value", tTool _ ": a credential-named key redacts the value")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CallSecretNames", {"Table": "T", "Key": "client_secret"})), "Value", tTool _ ": so does a compound name")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Table": "T", "Key": "timeout", "Value": "7"})), 0, tTool _ ": an ordinary key redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Table": "T", "Value": "7"})), 0, tTool _ ": a call with no key redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Table": "T", "Key": 5, "Value": "7"})), 0, tTool _ ": a key that is not a string redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", "")), 0, tTool _ ": and a call that is not an object redacts nothing")
    }
    For tTool = "InteropLookupTableDelete", "InteropLookupTableExport", "InteropLookupTableImport" {
        Set tClass = ..#TOOLPREFIX _ tTool
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Name": "dbpassword", "Key": "dbpassword", "Value": "x"})), 0, tTool _ ": a table tool names no secret, whatever the call carries")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.lookupentries.add", .tAdd)
    Do $$$AssertStatusOK(tSC, "the add resolves")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.Registry).CallSecretNames(tAdd, {"Table": "T", "Key": "dbpassword", "Value": "x"})), "Value", "the registry answers the add tool's names")
    For tRead = "interop.lookupentries.read", "interop.lookuptables.read", "interop.businesspartners.read" {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tRead, .tTool)
        Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Tool.Registry).CallSecretNames(tTool, {"Table": "T", "Key": "dbpassword"})), 0, "and none for " _ tRead)
    }
}

/// <p>Every lookup write has a script form (AD-59) the person can run in a terminal, with the vendor's lock around the vendor's
/// call, every value a string literal, and a quote or a control character in a name or a value cannot end the literal; a read has
/// none.</p>
/// <p>Mutation (Rule 19): render the value unquoted in <method>OcuPilot.Port.InteropPort.LookupSnippet</method> -- this goes
/// red.</p>
Method TestEveryLookupWriteRendersItsScript()
{
    Set tPort = ..#PORT
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("T""x", "k" _ $Char(10)))
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = tId
    Set tBody = {"Value": ("v""al" _ $Char(9) _ "ue")}
    For tPair = $ListBuild("LookupEntries", "ADDENTRY", "%UpdateValue", ", 1)"), $ListBuild("LookupEntries", "SETENTRY", "%UpdateValue", ", 0)"), $ListBuild("LookupEntries", "REMOVEENTRY", "%RemoveValue", "") {
        Set tEndpoint = $List(tPair, 1)
        Set tType = $List(tPair, 2)
        Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", tEndpoint, tType), "objectscript", tType _ " has a script form")
        Set tSteps = $ClassMethod(tPort, "Snippet", tEndpoint, tType, .tQuery, tBody)
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "Lock +^Ens.LookupTable(""T""""x""):3") && (tText [ ("##class(Ens.Util.LookupTable)." _ $List(tPair, 3))) && (tText [ "Lock -^Ens.LookupTable(""T""""x"")"), tType _ ": it switches, takes the lock, makes the vendor's call and releases the lock")
        Do $$$AssertTrue(tText [ """k""_$Char(10)_""", tType _ ": a control character in the key is spelled as a $Char")
        If tType '= "REMOVEENTRY" Do $$$AssertTrue(tText [ """v""""al""_$Char(9)_""ue""", tType _ ": and the value is one string literal")
        Do $$$AssertTrue(tText [ $List(tPair, 4), tType _ ": with its create flag")
        Do $$$AssertEquals($Length(tText, $Char(10)) > 3, 1, tType _ ": a script of several lines")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "TableName"
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "LookupTables", "DELETETABLE"), "objectscript", "the table delete has a script form")
    Set tSteps = $ClassMethod(tPort, "Snippet", "LookupTables", "DELETETABLE", .tQuery, "")
    Do $$$AssertTrue($Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "") [ "%ClearTable(""TableName"")", "which clears the table")
    ; The two transfers: a table name or a path holding a quote or a control character stays inside its string literal.
    Set tTable = """T""""x""_$Char(9)_""y"""
    Set tDocument = """T""""x""_$Char(9)_""y.LUT"""
    Set tFileLiteral = """a""""b""_$Char(10)_""c.xml"""
    For tCase = $ListBuild("IMPORT", 1, 5, "$System.OBJ.Load("), $ListBuild("EXPORT", 1, 3, "$System.OBJ.Export("), $ListBuild("EXPORT", 0, 3, "$System.OBJ.ExportToStream(") {
        Set tType = $List(tCase, 1)
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = "T""x" _ $Char(9) _ "y"
        If $List(tCase, 2) {
            Set tQuery("root") = "/allowed/dir/"
            Set tQuery("path") = "a""b" _ $Char(10) _ "c.xml"
        }
        Set tLabel = tType _ $Select($List(tCase, 2): " to a server file", 1: " to the browser")
        Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "LookupTables", tType), "objectscript", tLabel _ " has a script form")
        Set tSteps = $ClassMethod(tPort, "Snippet", "LookupTables", tType, .tQuery, "")
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 4)), tLabel _ ": it switches namespace and makes the vendor's " _ $List(tCase, 4) _ " call")
        Do $$$AssertTrue(tText [ tDocument, tLabel _ ": it names the table's one .LUT document, the name spelled as a literal")
        Do $$$AssertTrue($Select($List(tCase, 2): tText [ tFileLiteral, 1: tText '[ "root"), tLabel _ ": a server file's name is one literal, and the browser names none")
        Do $$$AssertTrue(tText '[ $Char(9), tLabel _ ": a control character in the table name is spelled as a $Char, never written raw")
        Do $$$AssertEquals($Length(tText, $Char(10)), $List(tCase, 3), tLabel _ ": a line break in the path starts no line of its own")
        Set tLocked = (tText [ ("Lock +^Ens.LookupTable(" _ tTable _ "):3")) && (tText [ ("Lock -^Ens.LookupTable(" _ tTable _ ")"))
        Do $$$AssertEquals(tLocked, +(tType = "IMPORT"), tLabel _ ": only the import takes the vendor's table lock, and releases it")
    }
    For tType = "LOOKUPTABLE", "LIST", "IMPORTTABLE" {
        Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "LookupTables", tType), "", tType _ " has no script form")
        Set tSteps = $ClassMethod(tPort, "Snippet", "LookupTables", tType, .tQuery)
        Do $$$AssertEquals(tSteps.%Size(), 0, tType _ " renders no step")
    }
}

/// <p>The prohibited set covers the two writable types, reviews an entry's <code>Value</code> for a change and its key and
/// value for a create, and the baseline defaults are those the plan names; the entity vocabulary carries the three types.</p>
/// <p>Mutation (Rule 19): drop <code>lookup-entry</code> from <code>COVEREDTYPES</code> -- this goes red.</p>
Method TestTheKernelCoversTheLookupTypes()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "CoveredTypes"), "lookup-table") && $ListFind($ClassMethod(tProhibited, "CoveredTypes"), "lookup-entry"), "the two writable types are covered")
    Do $$$AssertEquals($ListToString($ClassMethod(tProhibited, "PermittedChangeFields", "lookup-entry")) _ "|" _ $ListToString($ClassMethod(tProhibited, "PermittedCreateFields", "lookup-entry")), "Value|Key,Value", "an entry's change reviews its value and its create its key and value")
    Do $$$AssertEquals($ListLength($ClassMethod(tProhibited, "PermittedChangeFields", "lookup-table")), 0, "a table has no field to change")
    For tType = "lookup-table", "lookup-entry", "business-partner" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tType), tType _ " is an entity type")
    }
    Do $$$AssertTrue('$ListFind($ClassMethod(tProhibited, "CoveredTypes"), "business-partner"), "a business partner has no write, so it is not a covered type")
}

/// <p>The declaration <var>pClass</var> (a descriptor class name without its package) as an object.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Set tSC = $ClassMethod(..#PREFIX _ pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

}
