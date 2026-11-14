/// <p>Pins Story 20.41's Classes tab and its read, the <code>ItemClasses</code> endpoint of
/// <class>OcuPilot.Port.InteropPort</class> (AD-5, AD-8, AD-29, AD-36, AD-44, AD-62), against a probe production in <code>USER</code>:
/// its rows equal the lists <code>Ens.ContextSearch</code> gives the classic Change Class dialog for each kind of item, as sets; an item
/// whose class reads as no business host lists all three kinds; the item's own class is the one row flagged <code>Current</code>; an item
/// or a production the namespace does not hold is 404, a name held twice is <code>INTEROP.ITEM.AMBIGUOUS</code>, a missing item
/// criterion and a bad row cap are 400; a caller missing the dialog's own pair, <code>%Ens_ProductionConfig:WRITE</code>, is refused
/// naming it; and the tab is declared as the spec places it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles a probe production in <code>USER</code>
/// (<class>OcuPilot.Test.ProductionProbe</class>) and removes it after the last test. One class per run.</p>
Class OcuPilot.Test.InteropItemClasses Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter TAB = "OcuPilot.Screen.Descriptor.InteropItemClassTab";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The probe items: a business process, an item whose class is not compiled, and two items of one name.</p>
Parameter PROCESS = "OcuPilotProbeProc";

Parameter UNKNOWN = "OcuPilotProbeUnknown";

Parameter TWIN = "OcuPilotProbeTwin";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemClasses compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production and its classes.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The seam and the fake gate are cleared and the probe's items put back.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The Classes tab's read of the item <var>pName</var> through <var>pPort</var> as <code>status code</code>, the rows in
/// <var>pRows</var>; <var>pItem</var> is sent as the criterion when it is not <code>$Char(0)</code>.</p>
ClassMethod Read(pPort As %String, pName As %String, Output pRows, Output pFault, pMaxRows As %String = 1000, pItem As %String = {$Char(0)}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = pMaxRows
    If pItem '= $Char(0) {
        If pItem '= "" Set tQuery("item") = pItem
    } ElseIf pName '= "" {
        Set tQuery("item") = ..#PRODUCTION _ "||" _ pName
    }
    Set tSC = $ClassMethod(pPort, "Invoke", "ItemClasses", "LIST", .tQuery, "", .pRows, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>What <code>Ens.ContextSearch</code> lists for <var>pKind</var> (<code>service</code>, <code>process</code>, <code>operation</code>
/// or <code>all</code>) in <code>USER</code>, as the subscripts of <var>pSet</var>.</p>
ClassMethod ContextSet(pKind As %String, Output pSet)
{
    Kill pSet
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tMethod = $Case(pKind, "service": "BusinessServices", "process": "BusinessProcesses", "operation": "BusinessOperations", : "AllBusinessHosts")
        Set tSC = $ClassMethod("Ens.ContextSearch", tMethod, .tCaption, .tTop, .tResults, .tParms)
        For tI = 1:1:+$Get(tResults) {
            Set pSet($Get(tResults(tI))) = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Whether the rows <var>pRows</var> name exactly the classes <var>pSet</var> holds, with each row's kind among
/// <var>pKinds</var> (comma-separated) and every row's production and item as given; the difference is answered as text,
/// <code>""</code> for none. <var>pCurrent</var> receives the rows flagged <code>Current</code>, comma-separated.</p>
ClassMethod Difference(pRows, ByRef pSet, pKinds As %String, pItem As %String, Output pCurrent As %String) As %String
{
    Set pCurrent = ""
    Set tText = ""
    If '$IsObject(pRows) Quit "no rows"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen(tRow.ClassName) = ""
        If '$Data(pSet(tRow.ClassName)) Set tText = tText _ " extra:" _ tRow.ClassName
        If '$ListFind($ListFromString(pKinds), tRow.Type) Set tText = tText _ " kind:" _ tRow.ClassName _ "=" _ tRow.Type
        If (tRow.Production '= ..#PRODUCTION) || (tRow.Item '= pItem) Set tText = tText _ " item:" _ tRow.ClassName
        If tRow.Current Set pCurrent = pCurrent _ $Select(pCurrent = "": "", 1: ",") _ tRow.ClassName
    }
    Set tName = ""
    For {
        Set tName = $Order(pSet(tName))
        If tName = "" Quit
        If '$Data(tSeen(tName)) Set tText = tText _ " missing:" _ tName
    }
    Quit tText
}

/// <p>AC2: for an operation, a business process, a business service and an item whose class reads as no business host, the rows are
/// exactly the classes <code>Ens.ContextSearch</code> gives the classic dialog for that kind (the three lists together for the unknown
/// one), each row carries its kind, and the item's own class is the one row flagged <code>Current</code> (none for the unknown one).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.CandidateClasses</method> admit an abstract class -- the operation row
/// goes red naming the extra class.</p>
Method TestTheRowsAreTheClassesTheClassicDialogOffersForEachKind()
{
    Set tOp = $Parameter(..#CONTROL, "OPCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#PROCESS, "EnsLib.MsgRouter.RoutingEngine", 0, 0), "a business process is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#UNKNOWN, "OcuPilotProbe.No.Such.Class", 1, 0), "an item whose class is not compiled is stored")
    For tCase = $ListBuild("service", "OcuPilotProbeSvc", "OcuPilotProbe.Interop.Svc", "service"), $ListBuild("process", ..#PROCESS, "EnsLib.MsgRouter.RoutingEngine", "process"), $ListBuild("operation", "OcuPilotProbeOp", tOp, "operation"), $ListBuild("all", ..#UNKNOWN, "", "service,process,operation") {
        Do ..ContextSet($List(tCase, 1), .tSet)
        Set tCount = 0
        Set tName = ""
        For {
            Set tName = $Order(tSet(tName))
            If tName = "" Quit
            Set tCount = tCount + 1
        }
        Do $$$AssertTrue(tCount > 0, $List(tCase, 1) _ ": the classic lists name classes to compare with")
        Set tText = ..Read(..#PORT, $List(tCase, 2), .tRows, .tFault)
        Do $$$AssertEquals(tText, "200 ", $List(tCase, 1) _ ": the Classes read is answered")
        Set tDifference = ..Difference(tRows, .tSet, $List(tCase, 4), $List(tCase, 2), .tCurrent)
        Do $$$AssertEquals(tDifference, "", $List(tCase, 1) _ ": the rows are the classic dialog's as sets")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1), tCount, $List(tCase, 1) _ ": one row for each class, " _ tCount)
        Do $$$AssertEquals(tCurrent, $List(tCase, 3), $List(tCase, 1) _ ": the item's own class is the one flagged Current")
    }
}

/// <p>AC2: the screen's read, which the Change class dialog reads, answers the same rows as the port, and the row cap cuts them.</p>
/// <p>Mutation (Rule 19): drop the <code>maxRows</code> cut from <method>OcuPilot.Port.InteropPort.ListItemClasses</method> -- the cap leg
/// goes red.</p>
Method TestTheScreenReadAnswersTheSameRowsAndTheCapCutsThem()
{
    Set tText = ..Read(..#PORT, "OcuPilotProbeOp", .tRows, .tFault)
    Set tAll = $Select($IsObject(tRows): tRows.%Size(), 1: -1)
    Do $$$AssertTrue(tAll > 3, "the operation's classes are listed: " _ tAll)
    Set tText = ..Read(..#PORT, "OcuPilotProbeOp", .tCut, .tFault, 3)
    Do $$$AssertEquals($Select($IsObject(tCut): tCut.%Size(), 1: -1), 3, "a row cap of three cuts the rows to three")
    Set tPath = "/screens/interop.itemclasses/read?maxRows=1000&item=" _ $ZConvert(..#PRODUCTION _ "||OcuPilotProbeOp", "O", "URL")
    Do $ClassMethod(..#CONTROL, "Call", "GET", tPath, "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen read answers: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: tAnswer))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("rows") = "array": tAnswer.rows.%Size(), 1: -1), tAll, "with the rows the port lists")
    Set tFirst = $Select(tAnswer.%GetTypeOf("rows") = "array": tAnswer.rows.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tFirst): tFirst.%Get("Production") _ "|" _ tFirst.%Get("Item") _ "|" _ (tFirst.%GetTypeOf("Current") = "boolean"), 1: ""), ..#PRODUCTION _ "|OcuPilotProbeOp|1", "each row names its production and item and flags Current as a boolean")
}

/// <p>AC3: an item the production does not hold, and a production the namespace does not hold, are 404; a name held twice is 409
/// <code>INTEROP.ITEM.AMBIGUOUS</code>; a read with no item criterion or a malformed one, and a bad row cap, are 400
/// <code>PORT.VALIDATION</code>; a namespace without interoperability is 409 <code>INTEROP.NAMESPACE</code>; each before any class is
/// read.</p>
/// <p>Mutation (Rule 19): drop the held-twice refusal from <method>OcuPilot.Port.InteropPort.ListItemClasses</method> -- the ambiguous leg
/// goes red.</p>
Method TestAnAbsentOrAmbiguousItemAndABadCriterionAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#TWIN, $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "an item named Twin is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#TWIN, $Parameter(..#CONTROL, "OPCLASS"), 1, 0), "and a second item of its name")
    Do $$$AssertEquals(..Read(..#PORT, "OcuPilotProbeNone", .tRows, .tFault), "404 PORT.NOTFOUND", "an item the production does not hold is not found")
    Do $$$AssertEquals(..Read(..#PORT, "", .tRows, .tFault, 1000, "OcuPilotProbe.No.Such||OcuPilotProbeOp"), "404 PORT.NOTFOUND", "a production the namespace does not hold is not found")
    Do $$$AssertEquals(..Read(..#PORT, ..#TWIN, .tRows, .tFault), "409 INTEROP.ITEM.AMBIGUOUS", "a name held twice is ambiguous")
    Do $$$AssertEquals(..Read(..#PORT, ..#TWIN, .tRows, .tFault, 1000, ..#PRODUCTION _ "||" _ $ZConvert(..#TWIN, "U")), "409 INTEROP.ITEM.AMBIGUOUS", "in any letter case")
    Do $$$AssertEquals(..Read(..#PORT, "", .tRows, .tFault, 1000, ""), "400 PORT.VALIDATION", "a read with no item is refused")
    Do $$$AssertEquals(..Read(..#PORT, "", .tRows, .tFault, 1000, "NoSeparator"), "400 PORT.VALIDATION", "and so is an item that names no production")
    Do $$$AssertEquals(..Read(..#PORT, "OcuPilotProbeOp", .tRows, .tFault, "0"), "400 PORT.VALIDATION", "a row cap of zero is refused")
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tQuery("item") = ..#PRODUCTION _ "||OcuPilotProbeOp"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemClasses", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 INTEROP.NAMESPACE", "a namespace without interoperability is refused for it")
}

/// <p>AC5: the Classes read takes the Interoperability menu's pair, Production items' read pair and the classic dialog's own
/// <code>%Ens_ProductionConfig:WRITE</code>, and READ on the namespace's database, each refused by name before any class is read; a caller
/// holding exactly them reads the rows, and the read needs no routines database.</p>
/// <p>Mutation (Rule 19): drop <code>ITEMWRITEPAIRS</code> from the <code>ItemClasses</code> branch of
/// <method>OcuPilot.Port.InteropPort.Pairs</method> -- the missing-write leg goes red.</p>
Method TestACallerMissingAPairIsRefusedNamingIt()
{
    Set tSeam = ..#SEAM
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Set tText = ..Read(tSeam, "OcuPilotProbeOp", .tRows, .tFault)
    Do $$$AssertEquals(tText _ " " _ $ClassMethod("OcuPilot.Test.InteropItemGate", "FaultText", tFault), "403 AUTH.NOPRIVILEGE AUTH.NOPRIVILEGE %Ens_ProductionConfig:WRITE", "without the dialog's own pair the read is refused naming it")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "WRITE")
    Set tText = ..Read(tSeam, "OcuPilotProbeOp", .tRows, .tFault)
    Do $$$AssertEquals(tText, "200 ", "holding it, the read is answered, and asks for no routines database")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    For tCase = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%DB_USER", "READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        For tHeld = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ") {
            If tHeld '= tCase Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tHeld, 1), $List(tHeld, 2))
        }
        Set tText = ..Read(tSeam, "OcuPilotProbeOp", .tRows, .tFault)
        Do $$$AssertTrue($Extract(tText, 1, 3) = "403", $List(tCase, 1) _ ":" _ $List(tCase, 2) _ " missing: the read is refused: " _ tText)
        Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropItemGate", "FaultText", tFault), "AUTH.NOPRIVILEGE " _ $List(tCase, 1) _ ":" _ $List(tCase, 2), "naming the pair")
    }
}

/// <p>The tab is declared as the spec places it: a built detail screen under Production items with the item's route id as its one
/// criterion, <code>%Ens_Portal:USE</code>, <code>%Ens_ProductionConfig:READ</code> and <code>%Ens_ProductionConfig:WRITE</code> as its pairs, the last two its own, no action,
/// no refresh, three columns and three prompts over the port's <code>ItemClasses</code> list; it is the item strip's eighth tab,
/// labeled as the class list is; and it passes the registry.</p>
/// <p>Mutation (Rule 19): change the tab's <code>position</code> to 7 -- the strip leg goes red.</p>
Method TestTheTabIsDeclaredAsTheSpecPlacesIt()
{
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.built _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.parentScope, "interoperability/productions/items/classes|interoperability|detail|1|namespace|interoperability/productions/items", "a built detail screen under Production items")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON(), "production-item|composite|[""Item"",""ClassName""]", "its entity type and the composite its rows name")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ "|" _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""},{""resource"":""%Ens_ProductionConfig"",""permission"":""WRITE""}]|[{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""},{""resource"":""%Ens_ProductionConfig"",""permission"":""WRITE""}]", "the configuration page's and the classic dialog's pairs, and its own the two the menu does not hold")
    Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ tDeclaration.refreshRates.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size(), "0|0||0", "it does not refresh and offers no action")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, "EnsPortal.ProductionConfig|interop.itemclasses", "its classic page and tool identifier")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "interop|ItemClasses|LIST", "read through the interop port's ItemClasses endpoint")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Size() _ "|" _ tDeclaration.read.criteria.fields.%Get(0).param, "1|item", "one criterion, the item")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Production"",""Item"",""ClassName"",""Type"",""Current""]", "its rows carry the five fields")
    Do $$$AssertEquals(tDeclaration.table.columns.%Size() _ "|" _ tDeclaration.suggestedPrompts.%Size() _ "|" _ tDeclaration.context.fields.%ToJSON(), "3|3|[""ClassName"",""Type"",""Current""]", "three columns, three prompts and its context fields")
    Do $$$AssertEquals(tDeclaration.tab.group _ "|" _ tDeclaration.tab.position _ "|" _ tDeclaration.tab.labelKey, "interoperability/productions/items/document|8|explorerClassListLabel", "it is the item strip's eighth tab")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so do its criteria")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tDeclaration.entityType), "its entity type is in the kernel's vocabulary")
}

}
