/// <p>Story 20.14's floor-only roster (AD-8): the floor admits an account holding
/// <code>%Ens_Portal:USE</code> and nothing else, so a surface that declares no pair beyond
/// <code>%Ens_Portal:USE</code> is protected by the floor alone and opens to that account. Every
/// screen descriptor, read tool and write tool either declares a pair on some other resource, which
/// refuses the account by name, or is listed in <parameter>FLOORONLY</parameter> with its reason. An
/// unlisted floor-only surface fails naming it, and so does a roster entry that no longer exists or
/// now declares a pair. Routes are pinned by <class>OcuPilot.Test.InteropFloorRoutes</class>'s sweep.</p>
/// <p>A pair on <code>%Development</code> or an <code>%Admin_*</code> resource counts as declared: the
/// floor admits its holder, and the account this story widens it for holds neither.</p>
/// <p>It creates nothing and needs no arming.</p>
Class OcuPilot.Test.InteropFloorOwnPairs Extends %UnitTest.TestCase
{

/// <p>The floor member the widened floor adds, which declares no check beyond the floor.</p>
Parameter FLOORONLYRESOURCE = "%Ens_Portal";

/// <p>The reason a surface reads only the caller's own data.</p>
Parameter OWNERSCOPED = "owner-scoped";

/// <p>The reason a surface replaces no classic resource-guarded page.</p>
Parameter NOCLASSIC = "no classic resource";

/// <p>The closed roster of surfaces that declare no pair beyond the floor, as
/// <code>kind:name=reason</code>, comma-separated, with <code>kind</code> one of
/// <code>screen</code> (a descriptor's short name), <code>tool</code> (a tool name).</p>
Parameter FLOORONLY = "screen:AgentGuardrails=owner-scoped,screen:AgentLedger=owner-scoped,screen:AgentTranscript=owner-scoped,screen:AgentTranscripts=owner-scoped,screen:Home=no classic resource,tool:agent.transcripts.read=owner-scoped,tool:shell.instance.read=no classic resource,tool:shell.namespaces.read=no classic resource,tool:shell.privileges.read=no classic resource,tool:shell.screen.open=no classic resource";

/// <p>The package the screens are declared in.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>Whether <var>pPairs</var>, a list of <code>$ListBuild(resource, permission)</code>, declares
/// a pair on any resource other than <parameter>FLOORONLYRESOURCE</parameter>.</p>
ClassMethod DeclaresOwnPair(pPairs As %List) As %Boolean
{
    Set tOwn = 0
    If '$ListValid(pPairs) Quit tOwn
    For tI = 1:1:$ListLength(pPairs) {
        If $List($List(pPairs, tI), 1) '= ..#FLOORONLYRESOURCE Set tOwn = 1
    }
    Quit tOwn
}

/// <p>The reason <parameter>FLOORONLY</parameter> gives for <var>pKey</var> (<code>kind:name</code>),
/// or <code>""</code> when it lists none.</p>
ClassMethod ReasonOf(pKey As %String) As %String
{
    Set tReason = ""
    For tI = 1:1:$Length(..#FLOORONLY, ",") {
        Set tEntry = $Piece(..#FLOORONLY, ",", tI)
        If $Piece(tEntry, "=", 1) = pKey Set tReason = $Piece(tEntry, "=", 2)
    }
    Quit tReason
}

/// <p><b>Every surface has its own check (AC6).</b> Each screen descriptor, read tool and write tool
/// declares a pair beyond the floor, or is a <parameter>FLOORONLY</parameter> entry carrying its
/// reason; every entry names a surface that exists and declares no such pair.</p>
/// <p>Mutations: drop <class>OcuPilot.Screen.Descriptor.LogEventViewer</class>'s two
/// <code>%Ens_EventLog</code> pairs from its <code>privileges</code> -> it is unlisted and floor-only; drop
/// every pair of <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s
/// <code>PrivilegePairs</code> but <code>%Ens_Portal:USE</code> -> its tools are unlisted and
/// floor-only; either way this goes red naming the surface. Add a pair to
/// <class>OcuPilot.Screen.Descriptor.Home</class> -> its roster entry is stale and this goes red.</p>
Method TestEverySurfaceDeclaresItsOwnPairOrIsListedFloorOnly()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the descriptors list")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(($ListLength(tDescriptors) > 0) && (tTools.%Size() > 0), "there are surfaces to check: " _ $ListLength(tDescriptors) _ " screens, " _ tTools.%Size() _ " tools")

    Kill tSeen
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tClass = $List(tDescriptors, tI)
        Set tKey = "screen:" _ $Piece(tClass, ..#DESCRIPTORPACKAGE, 2)
        Set tSeen(tKey) = ""
        Set tOwn = ..DeclaresOwnPair($ClassMethod(tClass, "PrivilegePairs"))
        Do ..Judge(tKey, tOwn)
    }
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tKey = "tool:" _ tTool.name
        Set tSeen(tKey) = ""
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Do $$$AssertTrue(tResolved, tKey _ ": its required pairs resolve")
        If 'tResolved Continue
        Do ..Judge(tKey, ..DeclaresOwnPair(tPairs))
    }
    For tI = 1:1:$Length(..#FLOORONLY, ",") {
        Set tEntry = $Piece(..#FLOORONLY, ",", tI)
        Set tName = $Piece(tEntry, "=", 1)
        Do $$$AssertTrue($Data(tSeen(tName)), tName _ ": a roster entry names a surface that exists")
        Do $$$AssertTrue($ListFind($ListBuild(..#OWNERSCOPED, ..#NOCLASSIC), $Piece(tEntry, "=", 2)), tName _ ": its reason is one of the two allowed")
    }
}

/// <p>Assert that <var>pKey</var> declares an own pair exactly when <parameter>FLOORONLY</parameter>
/// does not list it.</p>
Method Judge(pKey As %String, pOwn As %Boolean)
{
    Set tReason = ..ReasonOf(pKey)
    If pOwn {
        Do $$$AssertEquals(tReason, "", pKey _ " declares its own pair, so FLOORONLY must not list it")
    } Else {
        Do $$$AssertNotEquals(tReason, "", pKey _ " declares no pair beyond the floor and is not listed in FLOORONLY")
    }
}

}
