/// <p>Pins Story 20.3's declarations (AD-5, AD-8, AD-13, AD-22, AD-36, AD-44, AD-51, AD-54, AD-59, AD-62):
/// the Production items descriptor and the four item tools; the registry's criteria rule on synthetic
/// sources (a parent-scoped interop read takes its parent's route id and no other read takes criteria);
/// the tools' pairs, shapes, governance keys and script forms; <method>OcuPilot.Port.InteropPort.ItemRefusal</method>
/// over the state matrix; the item name rule; the screen's read and the read tool answering the same rows
/// through the port; and every item code resolving to its sentence.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries, an interoperability-enabled
/// <code>USER</code> namespace and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// read leg compiles the probe classes of <class>OcuPilot.Test.ProductionProbe</class> in <code>USER</code>.
/// It starts no production.</p>
Class OcuPilot.Test.InteropItemDescriptor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.InteropItemList";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The four tools, <code>&lt;class&gt;|&lt;tool&gt;|&lt;write type&gt;|&lt;screen actions&gt;|&lt;destructive&gt;|&lt;change
/// action&gt;|&lt;subject&gt;|&lt;consequence&gt;|&lt;governance key value&gt;</code>.</p>
Parameter TOOLS = "InteropItemEnable|interop.items.enable|ENABLE|enable|0|updated|Enabled,EnabledSource,Namespace|INTEROP.ITEM.PENDING|1;InteropItemDisable|interop.items.disable|DISABLE|disable|0|updated|Enabled,EnabledSource,Namespace|INTEROP.ITEM.PENDING|1;InteropItemRemove|interop.items.remove|REMOVE|remove|1|deleted|Enabled,ClassName,Namespace|INTEROP.ITEM.REMOVE|0;InteropItemAdd|interop.items.add|ADD||0|created||INTEROP.ITEM.PENDING|1";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemDescriptor compiles the probe classes in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe classes.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The descriptor declares what the spec names: a built, unlisted list under the Productions list, its
/// composite id, the Productions list's pairs with the classic page's resource as its own, the add as its
/// primary action and enable, disable and remove as its row actions, three prompts, and the interop
/// source's Items endpoint with the production as its one criterion; and it passes the registry.</p>
/// <p>Mutation (Rule 19): change <code>parentScope</code> to <code>interoperability/processes</code> -- this
/// goes red.</p>
Method TestTheDescriptorDeclaresTheProductionItemsList()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.parentScope, "interoperability/productions/items|interoperability|0|list|namespace|interoperability/productions", "route, area, no side-bar position, archetype, scope and parent")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON(), "production-item|composite|[""Production"",""Name""]", "the entity type and the composite [Production, Name]")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ "|" _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""}]|[{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""}]", "the Productions list's two pairs, the second its own")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.primaryAction.id, "EnsPortal.ProductionConfig|interop.items|add", "its classic page, tool identifier and primary action")
    Set tActions = ""
    Set tIterator = tDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions _ "|" _ tDeclaration.context.fields.%ToJSON(), "enable,disable,remove|[""Name"",""ClassName"",""Type"",""Enabled"",""PoolSize""]", "its three row actions and its context fields")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three suggested prompts")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "interop|Items|LIST", "read through the interop port's Items endpoint")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Size() _ "|" _ tDeclaration.read.criteria.fields.%Get(0).param _ "|" _ (tDeclaration.read.criteria.fields.%Get(0).hint '= ""), "1|production|1", "one criterion, the production, with a hint")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so do its criteria")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("production-item"), "production-item is in the kernel's vocabulary")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), "production-item") > 0, "and in the prohibited set's covered types")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("production-item")), "Name,ClassName,PoolSize,Enabled,Category,Comment", "an add may set the six fields")
}

/// <p>The criteria rule on synthetic sources (AD-36 as amended): an interop read takes criteria only as
/// its parent's route id on a parent-scoped list, and a read of any other port that is refused criteria
/// still is.</p>
/// <p>Mutation (Rule 19): drop the <code>'tParented</code> arm from
/// <method>OcuPilot.Screen.Registry.CriteriaProblem</method> -- the non-parented leg goes red.</p>
Method TestAnInteropReadTakesCriteriaOnlyAsItsParentsRouteId()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tBase)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tBase)) Quit
    Set tRefusal = "read.criteria is declared on a 'interop' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"
    Set tParentRefusal = "parentScope 'interoperability/productions' is declared with a read, and a parent-scoped read declares exactly one read.criteria field, which its route id fills (AD-5)"
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(tBase.%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "a parent-scoped interop read with its one criterion is sound")
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(tBase.%ToJSON())
    Do tDeclaration.%Set("parentScope", "")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), tRefusal, "the same criteria on a list with no parent are refused")
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(tBase.%ToJSON())
    Do tDeclaration.read.criteria.fields.%Push({"param": "second", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64})
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), tParentRefusal, "a parent-scoped list with two criteria is refused the parent-criteria sentence")
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(tBase.%ToJSON())
    Do tDeclaration.read.%Remove("criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), tParentRefusal, "a parent-scoped list with none is refused too")
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(tBase.%ToJSON())
    Do tDeclaration.read.source.%Set("port", "monitor")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "read.criteria is declared on a 'monitor' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)", "a parent-scoped monitor read is refused as before")
}

/// <p>Each tool declares what the spec names: the port, the <code>ITEM</code> read, its own write type and
/// screen action, its fingerprint subject, no body except the add's, the destructive flag only on the
/// remove, its change action and consequence; each passes the subject's adequacy rule, is advertised, and
/// is listed in the governance baseline, enabled except the remove.</p>
/// <p>Mutation (Rule 19): set <code>interop.items.remove</code> <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- this goes red.</p>
Method TestTheToolShapes()
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Set tAdd = ($Piece(tRow, "|", 3) = "ADD")
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|ITEM|OcuPilot.Port.InteropPort|Items", tTool _ ": name, request types and port")
        Do $$$AssertEquals($ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "Creates") _ "|" _ $ClassMethod(tTool, "IdArgument") _ "|" _ $ClassMethod(tTool, "IdParam"), tAdd _ "|" _ $Piece(tRow, "|", 5) _ "|" _ $Piece(tRow, "|", 6) _ "|" _ $Piece(tRow, "|", 4) _ "|" _ tAdd _ "|Name|id", tTool _ ": body, destructive flag, change action, screen action, create flag and id")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")) _ "|" _ $ClassMethod(tTool, "Consequence", {}, 0, ""), $Piece(tRow, "|", 7) _ "|" _ $Piece(tRow, "|", 8), tTool _ ": its subject and its consequence code")
        Do $$$AssertEquals($ClassMethod(tTool, "MintClass"), "OcuPilot.Screen.Tool.InteropItemMint", tTool _ ": it mints the composite id")
        Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") = 1, tTool _ " is advertised")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", tTool _ " passes the subject's adequacy rule")
        Set tCodes = $ClassMethod(tTool, "PreconditionCodes")
        Do $$$AssertTrue($ListFind(tCodes, ##class(OcuPilot.Api.InteropError).#NAMESPACE) && $ListFind(tCodes, ##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL), tTool _ ": its precondition codes name the namespace and source control")
        For tJ = 1:1:$ListLength(tCodes) {
            Do $$$AssertTrue(($ListFind(##class(OcuPilot.Api.InteropError).ItemPreconditionCodes(), $List(tCodes, tJ)) > 0) || ($List(tCodes, tJ) = ##class(OcuPilot.Api.InteropError).#NAMESPACE), tTool _ ": " _ $List(tCodes, tJ) _ " is a declared item refusal")
        }
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"Name": "N"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")), $Piece(tRow, "|", 3), tTool _ ": the read made from the call's arguments is composed for its action")
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"Enabled": false, "Namespace": "USER"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("namespace")), $Select(tAdd: "ADD", 1: "") _ "|USER", tTool _ ": the read made from the stored payload names the payload's namespace" _ $Select(tAdd: " and still asks for the add", 1: " and no action"))
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertTrue(tSchema.required.%Get(0) = "Name" && $Select(tAdd: tSchema.required.%ToJSON() = "[""Name"",""Production"",""ClassName""]", 1: tSchema.required.%ToJSON() = "[""Name"",""Production""]"), tTool _ " requires " _ tSchema.required.%ToJSON())
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed($Piece(tRow, "|", 2), .tListed) _ "|" _ tListed, $Piece(tRow, "|", 9) _ "|1", tTool _ ": listed in the governance baseline with its declared value")
    }
}

/// <p>Each tool's pairs are the screen's two, then <code>%Ens_ProductionConfig:WRITE</code>, then WRITE on the
/// request namespace's globals database, then the routines database's where it is another resource, then
/// the custom resource of each classic page the tool declares, each pair once; in <code>USER</code>,
/// <code>%DB_USER:WRITE</code>. No tool names <code>%Ens_ProductionRun:USE</code>. The add declares the three
/// classic add-host dialogs and the others declare none.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.InteropItemAction.PrivilegePairs</method> -- this goes red.</p>
Method TestTheToolPairsAddTheConfigurationWriteAndTheDatabaseWrites()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tGlobals, .tReadOnly)
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase("USER", .tRoutines, .tReadOnly)
    Set tExpected = "%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:WRITE," _ tGlobals _ ":WRITE" _ $Select(tRoutines = tGlobals: "", 1: "," _ tRoutines _ ":WRITE")
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Do $$$AssertEquals(tResolved _ "|" _ tText, "1|" _ tExpected, $Parameter(tTool, "TOOLNAME") _ "'s pairs")
        Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), $Select($Piece(tRow, "|", 3) = "ADD": "EnsPortal.Dialog.ProductionAddService,EnsPortal.Dialog.ProductionAddProcess,EnsPortal.Dialog.ProductionAddOperation", 1: ""), $Parameter(tTool, "TOOLNAME") _ " declares the classic pages it performs")
    }
    For tClass = "EnsPortal.Dialog.ProductionAddService", "EnsPortal.Dialog.ProductionAddProcess", "EnsPortal.Dialog.ProductionAddOperation" {
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage(tClass), tClass, tClass _ " is spelled as NormalizePage answers it (AD-44)")
    }
}

/// <p><method>OcuPilot.Port.InteropPort.ItemRefusal</method> over the state matrix: the vendor stores a
/// duplicate name, answers a no-op as a success or an error text, or changes a system default instead of the
/// production, and the port names each by its own code before any vendor call (AD-62). A remove of an item a
/// system default keeps enabled names the default, since a disable of it is refused too.</p>
/// <p>Mutation (Rule 19): drop the <code>DEFAULTSETTING</code> refusal from
/// <method>OcuPilot.Port.InteropPort.ItemRefusalToken</method> -- the default rows go red; drop the remove's
/// alone -- the remove's default row goes red.</p>
Method TestTheItemRefusalMatrix()
{
    Set tP = "INTEROP.ITEM."
    ; type, count, enabled, source, business type, pool size, expected
    For tCase = $ListBuild("ADD", 0, 0, "", 0, "", ""), $ListBuild("ADD", 1, 1, "production", 3, 1, tP _ "TAKEN"), $ListBuild("ADD", 2, 1, "production", 3, 1, tP _ "TAKEN"),
        $ListBuild("ENABLE", 1, 0, "production", 3, 1, ""), $ListBuild("ENABLE", 1, 1, "production", 3, 1, tP _ "ENABLED"), $ListBuild("ENABLE", 1, 0, "default", 3, 1, tP _ "DEFAULTSETTING"), $ListBuild("ENABLE", 1, 1, "default", 3, 1, tP _ "ENABLED"), $ListBuild("ENABLE", 2, 0, "production", 3, 1, tP _ "AMBIGUOUS"),
        $ListBuild("DISABLE", 1, 1, "production", 3, 1, ""), $ListBuild("DISABLE", 1, 0, "production", 3, 1, tP _ "DISABLED"), $ListBuild("DISABLE", 1, 1, "default", 3, 1, tP _ "DEFAULTSETTING"), $ListBuild("DISABLE", 1, 1, "production", 2, 0, tP _ "POOLZERO"), $ListBuild("DISABLE", 1, 1, "production", 2, 1, ""), $ListBuild("DISABLE", 1, 1, "production", 3, 0, ""), $ListBuild("DISABLE", 3, 1, "production", 3, 1, tP _ "AMBIGUOUS"), $ListBuild("DISABLE", 1, 0, "production", 2, 0, tP _ "DISABLED"),
        $ListBuild("REMOVE", 1, 0, "production", 3, 1, ""), $ListBuild("REMOVE", 1, 1, "production", 3, 1, tP _ "ENABLEDREMOVE"), $ListBuild("REMOVE", 1, 1, "default", 3, 1, tP _ "DEFAULTSETTING"), $ListBuild("REMOVE", 1, 0, "default", 3, 1, ""), $ListBuild("REMOVE", 2, 0, "production", 3, 1, tP _ "AMBIGUOUS"), $ListBuild("RESTART", 1, 1, "production", 3, 1, "") {
        Set tCode = $ClassMethod(..#PORT, "ItemRefusal", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), $List(tCase, 5), $List(tCase, 6))
        Do $$$AssertEquals(tCode, $List(tCase, 7), $List(tCase, 1) _ " of " _ $List(tCase, 2) _ " item(s), enabled " _ $List(tCase, 3) _ " from " _ $List(tCase, 4) _ ", host type " _ $List(tCase, 5) _ ", pool " _ $List(tCase, 6))
    }
}

/// <p>The item name rule (Story 20.3): 1 to 128 characters with no control character and no space at either
/// end, none of the characters <code>| ; , [</code>, not beginning with <code>-</code> or <code>_</code>, not
/// ending with <code>-</code>, <code>!</code> or <code>$</code>, and not <code>*</code>.</p>
/// <p>Mutation (Rule 19): drop the trailing-character test from
/// <method>OcuPilot.Port.InteropPort.NameProblem</method> -- the ending rows go red.</p>
Method TestTheItemNameRule()
{
    Set tName = ##class(OcuPilot.Api.InteropError).#ITEMNAME
    For tCase = "A", "My Item", "my.item-1", "a_b", $Translate($Justify("", 128), " ", "x"), $Char(220), "x-y", "x*" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "NameProblem", tCase), "", "'" _ $Extract(tCase, 1, 20) _ "' is a legal name")
    }
    For tCase = "", $Translate($Justify("", 129), " ", "x"), " lead", "trail ", "a|b", "a;b", "a,b", "a[b", "-lead", "_lead", "end-", "end!", "end$", "*", "a" _ $Char(9) _ "b", "a" _ $Char(0) _ "b" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "NameProblem", tCase), tName, $ZConvert($Extract(tCase, 1, 20), "O", "JSON") _ " is an illegal name")
    }
}

/// <p>The port's script forms (AD-59): <code>objectscript</code> for each of the four item writes, none for
/// the reads; each script switches to the namespace, opens the production and calls the vendor with the
/// production and the item as string literals, saves the production class, opens no block it does not close on
/// its line, and ends by dropping the production, whose exclusive lock a terminal would otherwise keep; no
/// script names <code>CleanProduction</code> or <code>UpdateProduction</code>.</p>
/// <p>Mutation (Rule 19): drop the last line of <method>OcuPilot.Port.InteropPort.ItemSnippet</method> -- the
/// last-line row goes red for each write.</p>
Method TestTheScriptForms()
{
    For tType = "ENABLE", "DISABLE", "ADD", "REMOVE" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Items", tType), "objectscript", tType _ " has an ObjectScript form")
    }
    For tType = "LIST", "ITEM" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Items", tType), "", tType _ " has no script form")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "Probe.""Quoted" _ $Char(1) _ "Item ""Q"""
    Set tBody = {"ClassName": "Probe.Op", "PoolSize": 2, "Enabled": true, "Category": "c"}
    Do tBody.%Set("Comment", "hi ""there""")
    For tCase = $ListBuild("ENABLE", "EnableConfigItem(""Probe.""""Quoted||Item """"Q"""""", 1, 0)"), $ListBuild("DISABLE", "EnableConfigItem(""Probe.""""Quoted||Item """"Q"""""", 0, 0)"), $ListBuild("ADD", "##class(Ens.Config.Item).%New(""Probe.Op"")"), $ListBuild("REMOVE", "RemoveItem(") {
        Set tSteps = $ClassMethod(..#PORT, "Snippet", "Items", $List(tCase, 1), .tQuery, tBody)
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 2)) && (tText [ "SaveToClass(") && (tText '[ "CleanProduction") && (tText '[ "UpdateProduction"), $List(tCase, 1) _ ": " _ tText)
        Set tOpens = 0
        For tLine = 1:1:$Length(tText, $Char(10)) {
            If $Extract($ZStrip($Piece(tText, $Char(10), tLine), "<>W"), *) = "{" Set tOpens = tOpens + 1
        }
        Do $$$AssertEquals(tOpens, 0, $List(tCase, 1) _ ": no line opens a block it does not close")
        Do $$$AssertEquals($Piece(tText, $Char(10), *), " Kill tItem, tProduction", $List(tCase, 1) _ ": the last line drops the production")
    }
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Items", "ADD", .tQuery, tBody)
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue((tText [ "tItem.Enabled = 1") && (tText [ "tItem.PoolSize = ""2""") && (tText [ "tItem.Comment = ""hi """"there"""""""), "an add's script carries the fields it sends, quoted: " _ tText)
}

/// <p>The screen's declared read and the read tool answer the port's rows for the probe production's items,
/// and the criterion is required (AD-36, Story 20.3): the same rows by name, class, type and enabled flag; a
/// read with no production is 400 <code>READ.CRITERION</code>, and a production the namespace does not hold is
/// 404 <code>PORT.NOTFOUND</code>.</p>
/// <p>Mutation (Rule 19): drop <code>SeedCriteria</code> from the <code>interop</code> branch of
/// <method>OcuPilot.Screen.Read.Execute</method> -- the rows leg goes red.</p>
Method TestTheScreenAndItsReadToolReadTheSameRows()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("production") = ..#PRODUCTION
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Items", "LIST", .tQuery, "", .tPortRows, .tPortHttp, .tPortFault)
    Do $$$AssertEquals(+$Get(tPortHttp), 200, "the port lists the probe production's items")
    Kill tCriteria
    Set tCriteria("production") = ..#PRODUCTION
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tAnswer, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the screen's read answers")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.items.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "interop.items.read resolves")
    Kill tResult
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"production": (..#PRODUCTION), "maxRows": 1000}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(+$Get(tToolHttp), 200, "the read tool answers")
    If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) || '$IsObject($Get(tPortRows)) Quit
    Set tExpected = ..Names(tPortRows)
    Do $$$AssertTrue($Length(tExpected, ",") >= 2, "the probe production holds at least its operation and its service: " _ tExpected)
    Do $$$AssertEquals(..Names(tAnswer.rows), tExpected, "the screen's rows are the port's, by name, class, type and enabled flag")
    Do $$$AssertEquals(..Names(tResult.rows), tExpected, "and so are the tool's")
    Do $$$AssertEquals(tAnswer.criteria.production, ..#PRODUCTION, "the screen reports the criterion it applied")
    Kill tNone
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tNoneAnswer, .tNoneHttp, .tNoneFault, .tNone)
    Do $$$AssertEquals(+$Get(tNoneHttp) _ "|" _ $Select($IsObject($Get(tNoneFault)): tNoneFault.code, 1: ""), "400|" _ ##class(OcuPilot.Api.Error).#READCRITERION, "a read with no production is refused for it")
    Set tCriteria("production") = "OcuPilotProbe.No.Such.Production"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tGoneAnswer, .tGoneHttp, .tGoneFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tGoneHttp) _ "|" _ $Select($IsObject($Get(tGoneFault)): tGoneFault.code, 1: ""), "404|" _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "and a production the namespace does not hold is not found")
}

/// <p>The rows of <var>pRows</var> as <code>Name|ClassName|Type|Enabled</code>, comma-separated, sorted by
/// name.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    Kill tByName
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tByName(tRow.Name) = tRow.Name _ "|" _ tRow.ClassName _ "|" _ tRow.Type _ "|" _ tRow.Enabled
    }
    Set tText = ""
    Set tName = ""
    For {
        Set tName = $Order(tByName(tName))
        If tName = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tByName(tName)
    }
    Quit tText
}

/// <p>Every item code and consequence code resolves to its sentence through <class>OcuPilot.Api.InteropError</class>,
/// a refused tool call and a violation; the item refusals the tools may name are all declared, the field
/// violations are not among them, and the two consequence codes are declared as consequences.</p>
Method TestEveryItemCodeResolves()
{
    Set tError = "OcuPilot.Api.InteropError"
    Set tCodes = ##class(OcuPilot.Api.InteropError).ItemCodes() _ $ListBuild(##class(OcuPilot.Api.InteropError).#ITEMPENDING, ##class(OcuPilot.Api.InteropError).#ITEMREMOVE)
    Do $$$AssertEquals($ListLength(tCodes), 13, "eleven item codes and two consequences")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tError, "ReasonFor", tCode)
        Do $$$AssertTrue((tCode [ "INTEROP.ITEM.") && (tReason '= ""), tCode _ ": a code and a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": a refused tool call carries it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": and a violation")
    }
    For tCode = ##class(OcuPilot.Api.InteropError).#ITEMCLASS, ##class(OcuPilot.Api.InteropError).#ITEMNAME, ##class(OcuPilot.Api.InteropError).#ITEMVALUE {
        Do $$$AssertTrue('$ListFind(##class(OcuPilot.Api.InteropError).ItemPreconditionCodes(), tCode), tCode _ " is an add's violation, not an item refusal")
    }
    For tCode = ##class(OcuPilot.Api.InteropError).#ITEMPENDING, ##class(OcuPilot.Api.InteropError).#ITEMREMOVE {
        Do $$$AssertTrue($ListFind(##class(OcuPilot.Api.InteropError).ConsequenceCodes(), tCode) > 0, tCode _ " is a consequence code")
    }
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Api.InteropError).Codes(), ##class(OcuPilot.Api.InteropError).#SUSPENDED) && $ListFind(##class(OcuPilot.Api.InteropError).Codes(), ##class(OcuPilot.Api.InteropError).#PARTSTOPPED), "the stop outcomes are refusal codes")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.InteropProductionStop", "SUSPENDEDCODE"), ##class(OcuPilot.Api.InteropError).#SUSPENDED, "the stop tool answers the published code")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.InteropError).#SUSPENDED), ##class(OcuPilot.Api.InteropError).#REASONSUSPENDED, "and a refused tool call carries its sentence")
}

}
