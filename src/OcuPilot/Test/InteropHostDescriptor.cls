/// <p>Pins Story 20.4's declarations (AD-5, AD-8, AD-13, AD-29, AD-36, AD-43, AD-44, AD-62): the nine screens that read
/// a production's runtime state, the item tab group they form with Item settings, the port's endpoint roster and pair
/// sets, the queue each kind of item reads, and the dead-job flag of a job row.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and the interoperability classes. It starts
/// nothing, reads no production and creates no principal, so it runs on any instance.</p>
Class OcuPilot.Test.InteropHostDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter GROUP = "interoperability/productions/items/document";

Parameter ITEMS = "interoperability/productions/items";

/// <p>The nine screens, <code>&lt;class&gt;|&lt;route&gt;|&lt;side-bar position&gt;|&lt;archetype&gt;|&lt;entity type&gt;|&lt;endpoint&gt;|&lt;tool&gt;|&lt;classic page&gt;|&lt;refreshes&gt;|&lt;tab position&gt;|&lt;row actions&gt;</code>,
/// separated by <code>;</code>. The row actions are Story 20.23's: Queues, Queue messages and the Queue tab offer Abort, Jobs and the
/// Jobs tab offer Abort, Suspend and Stop.</p>
Parameter SCREENS = "InteropMonitorList|interoperability/monitor|5|list|production-item|Monitor|interop.monitor|EnsPortal.ProductionMonitor|1|0|;InteropQueueList|interoperability/queues|6|list|interop-queue|Queues|interop.queues|EnsPortal.Queues|1|0|abort;InteropQueueMessageList|interoperability/queues/messages|0|list|interop-message|QueueItems|interop.queuemessages|EnsPortal.Queues|0|0|abort;InteropJobList|interoperability/jobs|7|list|interop-job|Jobs|interop.jobs|EnsPortal.Jobs|1|0|abort,suspend,stop;InteropItemStatusTab|interoperability/productions/items/document|0|detail|production-item|ItemStatus|interop.itemstatus|EnsPortal.ProductionConfig|0|1|;InteropItemQueueTab|interoperability/productions/items/queue|0|detail|interop-message|ItemQueue|interop.itemqueue|EnsPortal.ProductionConfig|0|3|abort;InteropItemLogTab|interoperability/productions/items/log|0|detail|log-entry|ItemLog|interop.itemlog|EnsPortal.ProductionConfig|0|4|;InteropItemMessageTab|interoperability/productions/items/messages|0|detail|interop-message|ItemMessages|interop.itemmessages|EnsPortal.ProductionConfig|0|5|;InteropItemJobTab|interoperability/productions/items/jobs|0|detail|interop-job|ItemJobs|interop.itemjobs|EnsPortal.ProductionConfig|0|6|abort,suspend,stop";

/// <p>The endpoint roster the port declares (AD-62): the four Story 20.2 endpoints, Items and Settings, then the nine
/// runtime reads. Pinned as a literal, because a roster that derives both sides proves nothing.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Items,Settings,Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs";

/// <p>The pairs each runtime endpoint requires, <code>&lt;endpoint&gt;=&lt;pairs&gt;</code>, separated by <code>;</code>: its classic
/// page's resource beside the Interoperability menu's, and each item tab's beside Productions' (AD-8, AD-29).</p>
Parameter PAIRS = "Monitor=%Ens_Portal:USE,%Ens_Dashboard:USE;ItemStatus=%Ens_Portal:USE,%Ens_ProductionConfig:READ;Queues=%Ens_Portal:USE,%Ens_Queues:READ;QueueItems=%Ens_Portal:USE,%Ens_Queues:READ;ItemQueue=%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_Queues:READ;ItemLog=%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_EventLog:USE;ItemMessages=%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_MessageHeader:USE;Jobs=%Ens_Portal:USE,%Ens_Jobs:READ;ItemJobs=%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_Jobs:READ";

/// <p><var>pPairs</var> (a pair list or a JSON array of pair objects) as <code>resource:permission</code>, comma-separated.</p>
ClassMethod PairText(pPairs) As %String
{
    Set tText = ""
    If $IsObject(pPairs) {
        Set tIterator = pPairs.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPair) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tPair.resource _ ":" _ tPair.permission
        }
        Quit tText
    }
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(pPairs, tI), 1) _ ":" _ $List($List(pPairs, tI), 2)
    }
    Quit tText
}

/// <p>The pairs of <var>pPairs</var> (<code>resource:permission,...</code>) less the Interoperability menu's
/// <code>%Ens_Portal:USE</code>: what a screen declares as its own.</p>
ClassMethod OwnText(pPairs As %String) As %String
{
    Set tText = ""
    For tI = 1:1:$Length(pPairs, ",") {
        Set tPair = $Piece(pPairs, ",", tI)
        If tPair = "%Ens_Portal:USE" Continue
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tPair
    }
    Quit tText
}

/// <p>The declared pair set of <var>pEndpoint</var>, from <parameter>PAIRS</parameter>.</p>
ClassMethod PairsOf(pEndpoint As %String) As %String
{
    For tI = 1:1:$Length(..#PAIRS, ";") {
        Set tEntry = $Piece(..#PAIRS, ";", tI)
        If $Piece(tEntry, "=", 1) = pEndpoint Quit
    }
    Quit $Piece(tEntry, "=", 2)
}

/// <p>Each of the nine descriptors declares what the spec names: its route, side-bar position and archetype, the
/// entity type, the endpoint of the interop source, the classic page and tool identifier, whether it refreshes (at the
/// four shared rates, default off), the pairs of its endpoint and, as its own, those less
/// <code>%Ens_Portal:USE</code>, no primary action and the row actions <parameter>SCREENS</parameter> names (none for four of
/// them), three prompts and a table with one name column; a screen with a row action draws the agent-inviting empty state and no
/// next step, and one without keeps the read-only one; and the registry accepts the roster.</p>
/// <p>Mutation (Rule 19): drop the <code>tab</code> from <class>OcuPilot.Screen.Descriptor.InteropItemQueueTab</class>
/// -- the group leg of <method>TestTheItemTabsFormOneGroupInOrder</method> and this go red.</p>
Method TestTheNineDeclarationsRegister()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tEntry, "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration reads")
        If '$IsObject($Get(tDeclaration)) Continue
        Set tEndpoint = $Piece(tEntry, "|", 6)
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope, $Piece(tEntry, "|", 2) _ "|interoperability|" _ $Piece(tEntry, "|", 3) _ "|" _ $Piece(tEntry, "|", 4) _ "|namespace", tClass _ ": route, area, side-bar position, archetype and scope")
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, $Piece(tEntry, "|", 5) _ "|" _ $Piece(tEntry, "|", 8) _ "|" _ $Piece(tEntry, "|", 7), tClass _ ": entity type, classic page and tool identifier")
        Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""interop"",""endpoint"":""" _ tEndpoint _ """,""type"":""LIST""}", tClass _ ": it reads the interop source's " _ tEndpoint _ " endpoint")
        Do $$$AssertEquals(..PairText(tDeclaration.privileges), ..PairsOf(tEndpoint), tClass _ ": its pairs are its endpoint's")
        Do $$$AssertEquals(..PairText(tDeclaration.privileges), ..PairText($ClassMethod(..#PORT, "Pairs", tEndpoint, "LIST")), tClass _ ": and the port's own")
        Do $$$AssertEquals(..PairText(tDeclaration.ownPrivileges), ..OwnText(..PairsOf(tEndpoint)), tClass _ ": its own pairs are those less the Interoperability menu's")
        Set tActions = ""
        Set tActionIterator = tDeclaration.rowActions.%GetIterator()
        While tActionIterator.%GetNext(.tActionIndex, .tAction) {
            Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
        }
        Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tActions, "|" _ $Piece(tEntry, "|", 11), tClass _ ": no primary action, and its row actions")
        Set tAgent = $Case($Piece(tEntry, "|", 1), "InteropQueueList": "interopQueuesEmptyAgent", "InteropQueueMessageList": "interopQueueMessagesEmptyAgent", "InteropItemQueueTab": "interopQueueMessagesEmptyAgent", "InteropJobList": "interopJobsEmptyAgent", "InteropItemJobTab": "interopJobsEmptyAgent", : "")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, $Select(tAgent = "": "tableReadOnlyEmptyNext|", 1: "|" _ tAgent), tClass _ ": its empty state")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": it declares three suggested prompts")
        Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ $Select(tDeclaration.refreshes: tDeclaration.refreshRates.%ToJSON(), 1: "") _ "|" _ tDeclaration.%IsDefined("refreshDefault"), $Piece(tEntry, "|", 9) _ "|" _ $Select($Piece(tEntry, "|", 9): "[5,10,30,60]", 1: "") _ "|0", tClass _ ": it refreshes at the four shared rates, default off, or not at all")
        Set tNames = 0
        Set tColumns = tDeclaration.table.columns.%GetIterator()
        While tColumns.%GetNext(.tColumn, .tDefinition) {
            If tDefinition.kind = "name" Set tNames = tNames + 1
        }
        Do $$$AssertEquals(tNames, 1, tClass _ ": its table has one name column")
        Set tTabPosition = $Select($IsObject(tDeclaration.%Get("tab")): tDeclaration.tab.position, 1: 0)
        Do $$$AssertEquals(tTabPosition, +$Piece(tEntry, "|", 10), tClass _ ": its tab position, 0 for a screen that is no tab")
    }
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertEquals($Get(tProblem), "", "the registry accepts the roster with the nine screens")
}

/// <p>The monitor's and the jobs list's cross-screen links: a monitor row opens the Status tab by the item's
/// <code>Production||Name</code>, a job row opens Process details by its pid unless it reads dead; Queue messages is
/// reached from a queue and takes the queue as its one criterion.</p>
/// <p>Mutation (Rule 19): drop <code>unless</code> from the Jobs list's <code>rowTarget</code> -- the second leg goes
/// red.</p>
Method TestTheLinksBetweenTheScreensAreDeclared()
{
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.InteropMonitorList", "DeclarationJson", .tMonitor)
    Do $$$AssertEquals($IsObject(tMonitor) && (tMonitor.rowTarget.%ToJSON() = ("{""route"":""" _ ..#GROUP _ """,""field"":""Item""}")), 1, "a monitor row opens the Status tab by the item's Production||Name")
    Do $$$AssertEquals(tMonitor.id.kind _ "|" _ tMonitor.id.parts.%ToJSON(), "composite|[""Production"",""Name""]", "and its id is the item's composite")
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.InteropJobList", "DeclarationJson", .tJobs)
    Do $$$AssertEquals($IsObject(tJobs) && (tJobs.rowTarget.%ToJSON() = "{""route"":""os-management/processes/details"",""field"":""Job"",""unless"":""Dead""}"), 1, "a job row opens Process details by its pid, unless the job is dead")
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.InteropQueueMessageList", "DeclarationJson", .tMessages)
    Do $$$AssertEquals(tMessages.parentScope _ "|" _ tMessages.read.criteria.fields.%Size() _ "|" _ tMessages.read.criteria.fields.%Get(0).param _ "|" _ tMessages.read.criteria.fields.%Get(0).kind _ "|" _ tMessages.read.criteria.fields.%Get(0).maxLength, "interoperability/queues|1|queue|text|256", "Queue messages is the Queues list's sub-resource, keyed by one queue criterion")
}

/// <p>The item's six tabs form one parent-scoped group whose head is <code>interoperability/productions/items/document</code>:
/// Status, Settings, Queue, Log, Messages and Jobs in that order, each a <code>detail</code> with side-bar position 0 under
/// Production items and the same one <code>item</code> criterion; Item settings keeps its route, tool and archetype
/// change.</p>
/// <p>Mutation (Rule 19): give Item settings the position 4 -- the order leg goes red; change the head's criterion
/// length -- the shared-criterion leg goes red.</p>
Method TestTheItemTabsFormOneGroupInOrder()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tClasses)
    Do $$$AssertStatusOK(tSC, "the descriptor roster reads")
    Kill tByPosition
    For tI = 1:1:$ListLength(tClasses) {
        Set tSC = $ClassMethod($List(tClasses, tI), "DeclarationJson", .tDeclaration)
        If $$$ISERR(tSC) || '$IsObject($Get(tDeclaration)) Continue
        If '$IsObject(tDeclaration.%Get("tab")) || (tDeclaration.tab.group '= ..#GROUP) Continue
        Set tByPosition(tDeclaration.tab.position) = tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.parentScope _ "|" _ tDeclaration.read.criteria.fields.%Get(0).param _ ":" _ tDeclaration.read.criteria.fields.%Get(0).kind _ ":" _ tDeclaration.read.criteria.fields.%Get(0).maxLength _ ":" _ tDeclaration.read.criteria.fields.%Get(0).labelKey
    }
    Set tHead = ..#GROUP _ "|detail|0|" _ ..#ITEMS _ "|item:text:352:interopItemSettingsCriterionItem"
    Do $$$AssertEquals($Get(tByPosition(1)), tHead, "position 1 is the head, Status")
    Do $$$AssertEquals($Get(tByPosition(2)), $Replace(tHead, ..#GROUP, ..#ITEMS _ "/settings", , 1), "position 2 is Item settings, at its own route")
    Do $$$AssertEquals($Get(tByPosition(3)), $Replace(tHead, ..#GROUP, ..#ITEMS _ "/queue", , 1), "position 3 is Queue")
    Do $$$AssertEquals($Get(tByPosition(4)), $Replace(tHead, ..#GROUP, ..#ITEMS _ "/log", , 1), "position 4 is Log")
    Do $$$AssertEquals($Get(tByPosition(5)), $Replace(tHead, ..#GROUP, ..#ITEMS _ "/messages", , 1), "position 5 is Messages")
    Do $$$AssertEquals($Get(tByPosition(6)), $Replace(tHead, ..#GROUP, ..#ITEMS _ "/jobs", , 1), "position 6 is Jobs")
    Do $$$AssertEquals($Order(tByPosition(""), -1), 6, "and the group has six members")
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.InteropItemSettingList", "DeclarationJson", .tSettings)
    Do $$$AssertEquals(tSettings.toolIdentifier _ "|" _ tSettings.tab.labelKey _ "|" _ tSettings.rowActions.%Size(), "interop.itemsettings|interopItemTabSettings|2", "Item settings keeps its tool and its two row actions, and labels its tab Settings")
}

/// <p>The port's endpoint roster is the one the spec names, every runtime endpoint serves <code>LIST</code> and none of the production,
/// item or setting types (Queues, QueueItems and Jobs also serve Story 20.23's, which <class>OcuPilot.Test.InteropRuntimeDescriptor</class>
/// pins), and its <code>Pairs</code> are the declared sets; an endpoint the port does not serve has none.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Queues:READ</code> from the <code>ItemQueue</code> branch of
/// <method>OcuPilot.Port.InteropPort.Pairs</method> -- the pair leg goes red.</p>
Method TestThePortServesTheNineEndpointsAndTheirPairs()
{
    Do $$$AssertEquals($Parameter(..#PORT, "ENDPOINTS"), ..#ENDPOINTS, "the port's endpoint roster")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PORT, "RuntimeEndpoints")), "Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs", "the runtime endpoints are the nine")
    For tI = 1:1:$Length(..#PAIRS, ";") {
        Set tEndpoint = $Piece($Piece(..#PAIRS, ";", tI), "=", 1)
        Do $$$AssertEquals(..PairText($ClassMethod(..#PORT, "Pairs", tEndpoint, "LIST")), ..PairsOf(tEndpoint), tEndpoint _ ": its pairs")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", tEndpoint, "LIST"), tEndpoint _ " serves LIST")
        For tType = "STATE", "ITEM", "START", "ENABLE", "SET" {
            Do $$$AssertEquals($ClassMethod(..#PORT, "Serves", tEndpoint, tType), 0, tEndpoint _ " serves no " _ tType)
        }
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", tEndpoint, "LIST"), "", tEndpoint _ " has no script form")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "Pairs", "Nothing", "LIST"), "", "an endpoint the port does not serve has no pairs")
}

/// <p>The queue an item reads: a business process of pool size 0 shares <code>Ens.Actor</code> with the others and is
/// told apart by its name as the target; a business process with a pool of its own and an operation read the queue of
/// their own name. Built from in-memory items, so no production is needed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ItemQueueName</method> ignore the pool size -- the
/// pool-size-0 leg goes red.</p>
Method TestAnItemsQueueFollowsItsKindAndPoolSize()
{
    Set tProcess = ##class(Ens.Config.Item).%New("EnsLib.MsgRouter.RoutingEngine")
    Set tProcess.Name = "OcuPilotProbeProc"
    Set tProcess.PoolSize = 0
    Do $$$AssertEquals($ClassMethod(..#PORT, "ItemQueueName", tProcess, .tTarget) _ "|" _ tTarget, "Ens.Actor|OcuPilotProbeProc", "a business process of pool size 0 reads the shared actor queue, for its own name as the target")
    Set tProcess.PoolSize = 2
    Do $$$AssertEquals($ClassMethod(..#PORT, "ItemQueueName", tProcess, .tTarget) _ "|" _ tTarget, "OcuPilotProbeProc|", "a business process with a pool of its own reads the queue of its name")
    Set tOperation = ##class(Ens.Config.Item).%New("EnsLib.File.PassthroughOperation")
    Set tOperation.Name = "OcuPilotProbeOut"
    Set tOperation.PoolSize = 0
    Do $$$AssertEquals($ClassMethod(..#PORT, "ItemQueueName", tOperation, .tTarget) _ "|" _ tTarget, "OcuPilotProbeOut|", "an operation reads the queue of its name whatever its pool size")
}

/// <p>A job row is <code>Dead</code> when no process holds the job: a pid nothing holds, and the vendor's ghost id of a
/// job it marked dead; the process running this test is alive. A live row carries the production and the item only when
/// asked.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.JobRow</method> answer <code>Dead</code> false -- the
/// first two legs go red.</p>
Method TestAJobNoProcessHoldsReadsDead()
{
    Set tLine = $ListBuild("OcuPilotProbeOp", 2147483000, "OK", "Connected", "2026-10-10 22:12:30.750", "", "Hang", 3, "41")
    Set tRow = $ClassMethod(..#PORT, "JobRow", tLine)
    Do $$$AssertEquals(tRow.Dead, 1, "a pid no process holds reads dead")
    Do $$$AssertEquals(tRow.Job _ "|" _ tRow.Host _ "|" _ tRow.Status _ "|" _ tRow.AdapterState _ "|" _ tRow.Retry _ "|" _ tRow.ActiveMessage _ "|" _ tRow.LastActivity, "2147483000|OcuPilotProbeOp|OK|Connected|3|41|2026-10-10T22:12:30.750", "and carries the job's fields, the time as the log readers write it")
    Do $$$AssertEquals(tRow.%IsDefined("Production") + tRow.%IsDefined("Item"), 0, "and no parent unless one is given")
    Set tGhost = $ClassMethod(..#PORT, "JobRow", $ListBuild("OcuPilotProbeOp", "Z27603_960", "Dead", "", "", "", "Hang", "", ""))
    Do $$$AssertEquals(tGhost.Dead, 1, "the vendor's ghost id of a job it marked dead reads dead")
    Set tLive = $ClassMethod(..#PORT, "JobRow", $ListBuild("OcuPilotProbeOp", $Job, "OK", "", "", "", "", "", ""), "P")
    Do $$$AssertEquals(tLive.Dead _ "|" _ tLive.Production _ "|" _ tLive.Item, "0|P|P||OcuPilotProbeOp", "the process running this test is alive, and a row asked for its parent carries it")
}

/// <p>Every read tool is registered with the kind <code>read</code> and answered by the shared read tool class from its
/// descriptor. That none of the nine declares an action is <method>TestTheNineDeclarationsRegister</method>'s leg.</p>
Method TestEachReadToolIsRegistered()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        Set tName = $Piece(tEntry, "|", 7) _ ".read"
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertStatusOK(tSC, tName _ " resolves")
        If '$IsObject($Get(tTool)) {
            Do $$$AssertTrue(0, tName _ " is registered")
            Continue
        }
        Do $$$AssertEquals(tTool.kind _ "|" _ tTool.descriptor, "read|OcuPilot.Screen.Descriptor." _ $Piece(tEntry, "|", 1), tName _ " is a read tool derived from its descriptor")
    }
}

/// <p>The three entity types Story 20.4 adds are in the closed vocabulary, each with no spelling rule of its own.</p>
Method TestTheNewEntityTypesAreKnownAndKeptExactly()
{
    For tType = "interop-queue", "interop-message", "interop-job" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tType), tType _ " is a declared entity type")
        Do $$$AssertEquals(("," _ $Parameter("OcuPilot.Kernel.EntityRef", "IDRULES")) [ ("," _ tType _ ":"), 0, tType _ " has no id rule, so its id is kept exactly")
    }
}

}
