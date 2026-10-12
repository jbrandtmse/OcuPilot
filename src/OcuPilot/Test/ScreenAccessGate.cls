/// <p>Pins Story 20.15's store and its one reader in process (AD-8, AD-29, AD-64): the
/// <class>OcuPilot.Kernel.State.Access</class> row round trip with its version conflict;
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> following an adjustment, keeping the classic
/// page's custom resource, ignoring a row for a screen that cannot be adjusted and refusing when the
/// store cannot be read; a write tool's own pairs staying on top of an adjusted base; a port's constants
/// staying put; Screen permissions' own tools requiring the declared set whatever the store holds; the
/// either-of split confined to that one pair; and the port's own refusals of an own screen and of a set
/// that moved under a write.</p>
/// <p>It needs an instance whose store holds no adjustment: it writes rows and empties the store in
/// <method>OnAfterOneTest</method>. The real-principal legs are
/// <class>OcuPilot.Test.ScreenAccessWire</class>'s.</p>
Class OcuPilot.Test.ScreenAccessGate Extends %UnitTest.TestCase
{

Parameter STORE = "OcuPilot.Kernel.State.Access";

Parameter SEAM = "OcuPilot.Test.ScreenAccessGateSeam";

/// <p>A screen the store holds a row for in the round-trip leg; no descriptor carries it.</p>
Parameter PROBESCREEN = "ocupilot.accessprobe";

Parameter LOCKS = "osmgmt.locks";

Parameter LOCKDESCRIPTOR = "OcuPilot.Screen.Descriptor.LockList";

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotAccessSeam
    Kill ^||OcuPilotAccessRace
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
    Quit $ClassMethod(..#STORE, "DeleteAllGuarded")
}

/// <p>The pairs of <var>pList</var> spelled <code>resource:permission</code>, comma-separated.</p>
ClassMethod Spelled(pList As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pList) {
        Set tPair = $List(pList, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>The store creates a row at version 1, updates it only from the version it carries, refuses a stale
/// update and a stale remove with the stale-save refusal, and removes it from its version; the hot-path
/// read and the full read agree with it.</p>
/// <p>Mutation (Rule 19): drop the <code>GuardedSaveIfCurrent</code> call from
/// <method>OcuPilot.Kernel.State.Access.GuardedPut</method> -- the stale-update leg goes red.</p>
Method TestTheStoreRoundTripsAndRefusesAStaleVersion()
{
    Set tStore = ..#STORE
    Set tScreen = ..#PROBESCREEN
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedPairsFor", tScreen, .tPairs, .tFound), "an empty store reads")
    Do $$$AssertEquals(tFound, 0, "and holds no row")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedPut", tScreen, "%Admin_Secure:USE", 0, "probe"), "a create is stored")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedGet", tScreen, .tPairs, .tVersion, .tFound), "the row reads")
    Do $$$AssertEquals(tFound _ "|" _ tPairs _ "|" _ tVersion, "1|%Admin_Secure:USE|1", "at version 1")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedPairsFor", tScreen, .tHot, .tHotFound), "the hot path reads")
    Do $$$AssertEquals(tHotFound _ "|" _ tHot, "1|%Admin_Secure:USE", "the same row")
    Set tSC = $ClassMethod(tStore, "GuardedPut", tScreen, "%Admin_Manage:USE", 0, "probe")
    Do $$$AssertTrue($ClassMethod(tStore, "IsStaleSave", tSC), "a second create of the same screen is the stale refusal")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedPut", tScreen, "%Admin_Secure:USE,%Admin_Manage:USE", 1, "probe"), "an update from the version it carries is stored")
    Set tSC = $ClassMethod(tStore, "GuardedPut", tScreen, "%Admin_Operate:USE", 1, "probe")
    Do $$$AssertTrue($ClassMethod(tStore, "IsStaleSave", tSC), "an update from a version it no longer carries is the stale refusal")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedAll", .tAll), "the full read lists")
    Do $$$AssertEquals($Get(tAll(tScreen)), "%Admin_Secure:USE,%Admin_Manage:USE", "the updated row")
    Set tSC = $ClassMethod(tStore, "GuardedRemove", tScreen, 1)
    Do $$$AssertTrue($ClassMethod(tStore, "IsStaleSave", tSC), "a remove from a stale version is the stale refusal")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedRemove", tScreen, 2), "a remove from the current version is stored")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedPairsFor", tScreen, .tAfter, .tAfterFound), "and the screen reads again")
    Do $$$AssertEquals(tAfterFound, 0, "as holding no row")
}

/// <p>An adjustment replaces the declared set in <method>OcuPilot.Screen.Gate.RequiredPairs</method> on the
/// very next call, and removing it restores the declared set: nothing is cached.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.BaseSet</method> ignore the adjusted set -- this
/// goes red.</p>
Method TestRequiredPairsFollowsAnAdjustment()
{
    Set tDeclared = ..Spelled($ClassMethod(..#LOCKDESCRIPTOR, "PrivilegePairs"))
    Set tBefore = ..Spelled(##class(OcuPilot.Screen.Gate).RequiredPairs(..#LOCKDESCRIPTOR, .tResolved))
    Do $$$AssertEquals(tResolved _ "|" _ tBefore, "1|" _ tDeclared, "with no row the declared set applies")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", ..#LOCKS, "%Admin_Secure:USE", 0, "probe"), "Locks is adjusted")
    Set tAdjusted = ..Spelled(##class(OcuPilot.Screen.Gate).RequiredPairs(..#LOCKDESCRIPTOR, .tResolved))
    Do $$$AssertEquals(tResolved _ "|" _ tAdjusted, "1|%Admin_Secure:USE", "the adjusted set replaces the declared one at the next call")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Gate).BasePairs(..#LOCKS, .tDescriptor, .tBaseResolved), ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LOCKDESCRIPTOR), "BasePairs answers the same set when no classic page adds one")
    Do $$$AssertEquals(tDescriptor, ..#LOCKDESCRIPTOR, "and names the descriptor")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedAll", .tAll), "the store lists")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "DeleteAllGuarded"), "the adjustment is cleared")
    Set tAfter = ..Spelled(##class(OcuPilot.Screen.Gate).RequiredPairs(..#LOCKDESCRIPTOR, .tResolved))
    Do $$$AssertEquals(tResolved _ "|" _ tAfter, "1|" _ tDeclared, "and the declared set applies again")
}

/// <p>The classic page's custom resource is unioned on an adjusted set, as it is on a declared one
/// (AD-44), and a store that cannot be read leaves the screen unresolved, which
/// <method>OcuPilot.Screen.Gate.Evaluate</method> refuses without naming a pair.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.AdjustedPairs</method> answer resolved when a
/// stored row does not parse -- the third leg goes red; drop the classic union from
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> -- the first does.</p>
Method TestTheClassicResourceStaysAndAnUnreadableStoreRefuses()
{
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", ..#LOCKS, "%Admin_Secure:USE", 0, "probe"), "Locks is adjusted")
    Set ^||OcuPilotAccessSeam("classic") = "OcuPilotProbeClassic"
    Set tUnion = ..Spelled($ClassMethod(..#SEAM, "RequiredPairs", ..#LOCKDESCRIPTOR, .tResolved))
    Do $$$AssertEquals(tResolved _ "|" _ tUnion, "1|%Admin_Secure:USE,OcuPilotProbeClassic:USE", "the effective set is the adjusted set and the custom resource")
    Kill ^||OcuPilotAccessSeam("classic")
    Set ^||OcuPilotAccessSeam("mode") = "fail"
    Set tPairs = $ClassMethod(..#SEAM, "RequiredPairs", ..#LOCKDESCRIPTOR, .tResolved)
    Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tPairs), "0|0", "an unreadable store leaves the requirement unresolved")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Evaluate", ..#LOCKDESCRIPTOR, .tFailed) _ "|" _ tFailed, "0|", "so the screen is refused, naming no pair")
    Kill ^||OcuPilotAccessSeam("mode")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", ..#LOCKS, "nocolon", 1, "probe"), "a row that will not parse is stored")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LOCKDESCRIPTOR, .tResolved)
    Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tPairs), "0|0", "the real gate leaves a row that will not parse unresolved")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Gate).Evaluate(..#LOCKDESCRIPTOR, .tFailed) _ "|" _ tFailed, "0|", "and refuses the screen, naming no pair")
}

/// <p>A row stored for a screen that cannot be adjusted is ignored by the one reader, and Screen
/// permissions' own screen and tools require the either-of <code>%Development:USE</code> or <code>%Admin_Secure:USE</code> whatever the store
/// holds (AD-64 rule 3).</p>
/// <p>Mutation (Rule 19): drop the <code>Adjustable</code> test from
/// <method>OcuPilot.Screen.Gate.BaseSet</method> -- the stray-row legs go red; route a Screen permissions
/// tool's <code>PrivilegePairs</code> through <method>OcuPilot.Screen.Gate.RequiredPairs</method> -- the
/// tool leg goes red only while the descriptor is adjustable, which is why the descriptor leg is here
/// too.</p>
Method TestAStrayRowForANonAdjustableScreenIsIgnored()
{
    Set tHome = "OcuPilot.Screen.Descriptor.Home"
    Set tOwn = "OcuPilot.Screen.Descriptor.AgentScreenPermissions"
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", "shell.home", "%Admin_Secure:USE", 0, "probe"), "a stray row for Home is stored")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", "agent.screenpermissions", "%Admin_Secure:USE", 0, "probe"), "and one for Screen permissions")
    Set tHomePairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tHome, .tHomeResolved)
    Do $$$AssertEquals(tHomeResolved _ "|" _ $ListLength(tHomePairs), "1|0", "Home still requires nothing")
    Set tOwnPairs = ..Spelled(##class(OcuPilot.Screen.Gate).RequiredPairs(tOwn, .tOwnResolved))
    Do $$$AssertEquals(tOwnResolved _ "|" _ tOwnPairs, "1|%Development|%Admin_Secure:USE", "Screen permissions still requires its either-of pair")
    For tTool = "OcuPilot.Screen.Tool.ScreenAccessAddPair", "OcuPilot.Screen.Tool.ScreenAccessRemovePair", "OcuPilot.Screen.Tool.ScreenAccessReset" {
        Do $$$AssertEquals(..Spelled($ClassMethod(tTool, "PrivilegePairs")), "%Development|%Admin_Secure:USE", tTool _ ": requires the either-of pair")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Gate).Adjustable(tHome) _ "|" _ ##class(OcuPilot.Screen.Gate).Adjustable(tOwn) _ "|" _ ##class(OcuPilot.Screen.Gate).Adjustable(..#LOCKDESCRIPTOR), "0|0|1", "only Locks of the three can be adjusted")
}

/// <p>The dispatcher's pair check accepts either arm of the either-of pair and, when neither is held, names
/// both. The seam holds every pair except the ones a test denies.</p>
/// <p>Mutation (Rule 19): revert <method>OcuPilot.Kernel.Agent.Dispatch.MissingPair</method> to test the pair's
/// resource without splitting its alternatives -- this goes red.</p>
Method TestDispatchAcceptsEitherArmOfTheEitherOfPair()
{
    Set tPairs = $ClassMethod("OcuPilot.Screen.Tool.ScreenAccessAddPair", "PrivilegePairs")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", tPairs), "", "both arms held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Development", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", tPairs), "", "only %Admin_Secure held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Admin_Secure", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", tPairs), "", "only %Development held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Development", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", tPairs), "%Development:USE or %Admin_Secure:USE", "neither held names both")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
}

/// <p>Only <method>OcuPilot.Screen.Gate.AdjusterPairs</method>' pair is an either-of (AD-64 item 4, AD-8): any
/// other resource carrying the separator is one resource, and a pair naming no resource is never held.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.Alternatives</method> split every resource on the
/// separator -- the composite and empty-resource legs go red.</p>
Method TestOnlyTheAdjusterPairIsAnEitherOf()
{
    Set tGate = "OcuPilot.Screen.Gate"
    Set tAdjuster = $List($List(##class(OcuPilot.Screen.Gate).AdjusterPairs(), 1), 1)
    Do $$$AssertEquals($ListLength($ClassMethod(tGate, "Alternatives", tAdjuster)), 2, "the adjuster pair offers its two resources")
    Do $$$AssertEquals($ListToString($ClassMethod(tGate, "Alternatives", "%Admin_Operate|%Admin_Manage")), "%Admin_Operate|%Admin_Manage", "any other resource carrying the separator is one resource")
    Do $$$AssertEquals($ClassMethod(tGate, "SpellPair", "%Admin_Operate|%Admin_Manage", "USE"), "%Admin_Operate|%Admin_Manage:USE", "and is spelled as one pair")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Admin_Operate|%Admin_Manage", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", $ListBuild($ListBuild("%Admin_Operate|%Admin_Manage", "USE"))), "%Admin_Operate|%Admin_Manage:USE", "the dispatcher does not admit it on either half")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ToolDispatchProbe).Missing("u", $ListBuild($ListBuild("", "USE"))), ":USE", "a pair naming no resource is never held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
}

/// <p>The port's own checks, below the prohibited set (AD-10, AD-34, AD-51): a write to a screen that cannot be
/// adjusted is refused <code>PROHIBITED.OCUPILOTSCREEN</code> with nothing stored, a composed read naming an
/// empty pair is refused <code>ACCESS.PAIR.MALFORMED</code>, and a stored set that moves
/// under a change, whether it is created or updated meanwhile, is refused 409 <code>STATE.CONFLICT</code> and
/// the other writer's set stands.</p>
/// <p>Mutation (Rule 19): drop the <code>'tAdjustable</code> refusal from
/// <method>OcuPilot.Port.ScreenAccessPort.Invoke</method> -- the own-screen legs go red; test the change keys'
/// values rather than their presence there -- the empty-pair leg does; make
/// <method>OcuPilot.Port.ScreenAccessPort.Stored</method> answer every failed write 500 -- the conflict legs
/// do.</p>
Method TestThePortRefusesAnOwnScreenAndASetThatMoved()
{
    For tType = "PUT", "DELETE" {
        Kill tQuery
        Set tQuery("Screen") = "shell.home"
        If tType = "PUT" Set tQuery("addpair") = "%Admin_Secure:USE"
        Set tSC = ##class(OcuPilot.Port.ScreenAccessPort).Invoke("Screen", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403|PROHIBITED.OCUPILOTSCREEN", tType _ ": the port refuses OcuPilot's own screen itself")
    }
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedAll", .tAll), "the store reads")
    Do $$$AssertEquals($Data(tAll), 0, "and nothing was stored")
    Kill tQuery
    Set tQuery("Screen") = ..#LOCKS
    Set tQuery("addpair") = ""
    Set tSC = ##class(OcuPilot.Port.ScreenAccessPort).Invoke("Screen", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "422|ACCESS.PAIR.MALFORMED", "a composed read naming an empty pair is refused, not answered as no change")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    For tCase = $ListBuild("created meanwhile", "", "%Admin_Task:USE"), $ListBuild("updated meanwhile", "%Admin_Secure:USE", "%Admin_Secure:USE,%Admin_Task:USE") {
        Set tName = $List(tCase, 1)
        Do $$$AssertStatusOK($ClassMethod(..#STORE, "DeleteAllGuarded"), tName _ ": the store is emptied")
        If $List(tCase, 2) '= "" Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", ..#LOCKS, $List(tCase, 2), 0, "probe"), tName _ ": Locks is adjusted first")
        Kill ^||OcuPilotAccessRace
        Set ^||OcuPilotAccessRace("screen") = ..#LOCKS
        Set ^||OcuPilotAccessRace("pair") = "%Admin_Task:USE"
        Kill tQuery
        Set tQuery("Screen") = ..#LOCKS
        Set tQuery("addpair") = "%Admin_Manage:USE"
        Set tSC = ##class(OcuPilot.Test.ScreenAccessPortGateSeam).Invoke("Screen", "PUT", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(^||OcuPilotAccessRace("stored")), 1, tName _ ": the other writer's change was stored during the write")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409|STATE.CONFLICT", tName _ ": the moved set is a conflict")
        Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedGet", ..#LOCKS, .tStored, .tVersion, .tFound), tName _ ": Locks reads")
        Do $$$AssertEquals(tStored, $List(tCase, 3), tName _ ": and the other writer's set stands")
    }
    Kill ^||OcuPilotAccessRace
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p>The proposal card's privilege line carries the either-of pair as the adjuster spec a mint records:
/// <code>requires</code> spells both arms, and <code>missing</code> is empty while either arm is held and names
/// both when neither is.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Disclosure.Privilege</method> spell
/// <code>resource:permission</code> without <method>OcuPilot.Screen.Gate.SpellPair</method> -- the first leg goes red.</p>
Method TestTheProposalCardNamesBothArmsOfTheEitherOfPair()
{
    Set tSpec = ##class(OcuPilot.Screen.Gate).AdjusterSpec()
    Set tBoth = "%Development:USE or %Admin_Secure:USE"
    Set tProbe = "OcuPilot.Test.ToolDispatchProbe"
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
    Set tCard = ##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege(tSpec, "u", tProbe)
    Do $$$AssertTrue($IsObject(tCard), "the adjuster spec parses to a privilege line")
    If '$IsObject(tCard) Quit
    Do $$$AssertEquals(tCard.%Get("requires").%Size() _ "|" _ tCard.%Get("requires").%Get(0), "1|" _ tBoth, "requires spells both arms as one entry")
    Do $$$AssertEquals(tCard.%Get("missing"), "", "both held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Development", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege(tSpec, "u", tProbe).%Get("missing"), "", "only %Admin_Secure held")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).DenyPair("%Admin_Secure", "USE")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege(tSpec, "u", tProbe).%Get("missing"), tBoth, "neither held names both")
    Do ##class(OcuPilot.Test.ToolDispatchProbe).Reset()
}

/// <p>A write tool's base follows its screen's adjustment while its own extra pairs stay on top: Remove
/// locks requires the adjusted set and <code>%DB_IRISSYS:WRITE</code>. A port's own pair constants are not
/// touched by an adjustment of the screen that reaches it.</p>
/// <p>Mutation (Rule 19): make the Remove locks tool read its descriptor's <code>PrivilegePairs</code>
/// rather than <method>OcuPilot.Screen.Gate.RequiredPairs</method> -- the first leg goes red.</p>
Method TestAWriteToolFollowsTheAdjustmentAndAPortKeepsItsConstants()
{
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", ..#LOCKS, "%Admin_Secure:USE", 0, "probe"), "Locks is adjusted")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedPut", "interop.productions", "%Admin_Secure:USE", 0, "probe"), "so is Productions")
    Kill tTool
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.locks.remove", .tTool, 1)
    Do $$$AssertTrue($IsObject($Get(tTool)), "the Remove locks tool resolves")
    If $IsObject($Get(tTool)) {
        Set tPairs = ..Spelled(##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved))
        Do $$$AssertEquals(tResolved _ "|" _ tPairs, "1|%Admin_Secure:USE,%DB_IRISSYS:WRITE", "the adjusted set and the tool's own write pair")
    }
    Set tPort = ..Spelled(##class(OcuPilot.Port.InteropPort).Pairs("Productions"))
    Do $$$AssertEquals(tPort, "%Ens_Portal:USE,%Ens_ProductionConfig:READ", "the interoperability port's own pairs are the constants it declares")
}

}
