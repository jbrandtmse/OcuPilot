/// <p>Pins AD-10's own-mappings rule over the globals OcuPilot's code is read from (Story 18.14,
/// DW-1803): in the namespace this process runs in and in <code>%ALL</code>, a global mapping that
/// moves one of <parameter>OcuPilot.Kernel.Proposal.Prohibited.CODEGLOBALS</parameter> -- the whole
/// global, a pattern or range naming it, a subscript mapping reaching OcuPilot's names, or one whose
/// base mapping would move the global -- is refused <code>PROHIBITED.OCUPILOTMAPPING</code> on the
/// screen's Save and at the agent's confirm, and in a copy; a subscript range of one that does not
/// reach them, and an unrelated global, are permitted. It also holds the declared set equal to the
/// instance's own routine database.</p>
/// <p>Every write in the namespace this process runs in goes to
/// <class>OcuPilot.Test.MappingAcceptPort</class>, which sends none, and the <code>%ALL</code> legs ask
/// the prohibited set directly (<class>OcuPilot.Test.MappingAllTargetFixture</class>). The only
/// mappings written are in probe namespaces.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving in the namespace it
/// runs these tests in, that namespace's globals and routines on one readable database, the
/// <code>USER</code> and <code>IRISTEMP</code> databases, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the class
/// creates and deletes namespaces and mappings (<class>OcuPilot.Test.MappingProbe</class>).
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe namespace is removed by
/// exact name, with its mappings, before all, after each and after all.</p>
Class OcuPilot.Test.MappingCodeGlobals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter KERNEL = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter WRITE = "OcuPilot.Test.MappingWrite";

Parameter COPY = "OcuPilot.Test.NamespaceCopy";

Parameter ACCEPT = "OcuPilot.Test.MappingAcceptPort";

Parameter COPYTOOL = "OcuPilot.Screen.Tool.NamespaceCopyMappings";

Parameter OWNCODE = "PROHIBITED.OCUPILOTMAPPING";

Parameter TYPE = "global-mapping";

/// <p>The probe namespaces: two copy sources, a copy destination, and one whose globals database is
/// not its routines database.</p>
Parameter SOURCE = "OCUPROBE1814A";

Parameter NEARSOURCE = "OCUPROBE1814C";

Parameter DESTINATION = "OCUPROBE1814B";

Parameter SPLIT = "OCUPROBE1814S";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MappingCodeGlobals creates and deletes namespaces and mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name, with its mappings")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe object; a failing status when any survives or the configuration file no
/// longer validates or still names a probe namespace.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.MappingCodeGlobals"))
    Quit tSC
}

/// <p>The declared set is the instance's: walking every global of the routine database of the
/// namespace this process runs in, the ones holding a subscript that begins with one of OcuPilot's
/// stems in any case, at the first or second level, are exactly
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.CODEGLOBALS</parameter>, and the ones holding it at
/// the second under a first subscript that does not begin with a stem are exactly
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.NESTEDCODEGLOBALS</parameter>. A global whose own
/// name begins with a stem is the stem rule's and is not counted.</p>
Method TestTheCodeGlobalsAreTheOnesHoldingOcuPilotsNames()
{
    Set tStems = $ClassMethod(..#KERNEL, "OwnNameStems")
    Set tDest = ##class(%SYS.Namespace).GetRoutineDest($NAMESPACE)
    Do $$$AssertTrue($Extract(tDest) = "^", "the routine database of " _ $NAMESPACE _ " is local: " _ tDest)
    Set tDir = "^" _ tDest
    Set tWalked = 0
    Set tGlobal = ""
    For {
        Set tGlobal = $Order(^$|tDir|GLOBAL(tGlobal))
        If tGlobal = "" Quit
        Set tName = $Translate(tGlobal, "^")
        Set tWalked = tWalked + 1
        If ..BeginsWithStem(tName, tStems) Continue
        If ..Holds("^|""" _ tDir _ """|" _ tName, tStems, .tBelow) Set tHolders(tName) = ""
        If tBelow Set tNested(tName) = ""
    }
    Do $$$AssertTrue(tWalked > 0, "the walk read " _ tWalked _ " globals of " _ tDest)
    Do $$$AssertEquals(..Joined(.tHolders), ..Sorted($Parameter(..#KERNEL, "CODEGLOBALS")), "the globals holding OcuPilot's names are the kernel's code globals")
    Do $$$AssertEquals(..Joined(.tNested), ..Sorted($Parameter(..#KERNEL, "NESTEDCODEGLOBALS")), "and the ones holding them under a first subscript that is not one are its nested ones")
}

/// <p>Each code global mapped whole, and a pattern or range naming one with case (<code>odd*</code>,
/// <code>r*</code>, <code>Q:S</code>, which names <code>ROUTINE</code> alone), is refused on both
/// callers in the namespace this process runs in with no write reaching the port, and by the set in
/// <code>%ALL</code>; the same names in another case (<code>rObj</code>, <code>ODD*</code>) reach the
/// port, since the instance compares global names with case.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Kernel.Proposal.Prohibited.CODEGLOBALS</parameter> set
/// to <code>""</code> -> the member floor fails, the member-pattern legs reach the port, and this
/// goes red.</p>
Method TestAWholeCodeGlobalMappingIsRefused()
{
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    Set tMembers = $ListFromString($Parameter(..#KERNEL, "CODEGLOBALS"))
    Do $$$AssertTrue($ListLength(tMembers) > 0, "the kernel declares code globals")
    For tI = 1:1:$ListLength(tMembers) {
        Do ..AssertRefused($List(tMembers, tI))
        Do $$$AssertEquals(..AllProhibits($List(tMembers, tI)), "1 " _ ..#OWNCODE, "%ALL " _ $List(tMembers, tI) _ ": refused")
    }
    For tName = "odd*", "r*", "Q:S" {
        Do ..AssertRefused(tName)
    }
    For tName = "rObj", "ODD*" {
        Do ..AssertPermitted(tName)
    }
}

/// <p>A subscript mapping of each code global whose first-subscript range reaches OcuPilot's names,
/// a single OcuPilot subscript, and ranges open at either end the instance accepts
/// (<code>BEGIN</code>, <code>END</code>) are refused on both callers; so is any subscript mapping of
/// a nested code global (<code>oddDEP(0)</code>, <code>rINDEXSQL("TABLE")</code>,
/// <code>rINDEXEXT("C")</code>), which holds OcuPilot names under such a first subscript (measured).
/// In <code>%ALL</code> the set refuses the same.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.CoversCodeGlobal</method> answers
/// 0 for a subscripted name of a member that is not nested -> the range, single and open-end legs
/// reach the port and this goes red; <parameter>OcuPilot.Kernel.Proposal.Prohibited.NESTEDCODEGLOBALS</parameter>
/// set to <code>""</code> -> the nested legs reach the port.</p>
Method TestASubscriptMappingReachingOcuPilotsNamesIsRefused()
{
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    Set tMembers = $ListFromString($Parameter(..#KERNEL, "CODEGLOBALS"))
    For tI = 1:1:$ListLength(tMembers) {
        Set tName = $List(tMembers, tI) _ "(""OcuPilot""):(""OcuPilotz"")"
        Do ..AssertRefused(tName)
        Do $$$AssertEquals(..AllProhibits(tName), "1 " _ ..#OWNCODE, "%ALL " _ tName _ ": refused")
    }
    For tName = "ROUTINE(""OcuPilot.Api.Account.1"")", "rOBJ(""O""):(END)", "oddDEF(BEGIN):(END)", "rINDEXCLASS(""O""):(""P"")", "oddDEP(0)", "rINDEXSQL(""TABLE"")", "rINDEXEXT(""C"")" {
        Do ..AssertRefused(tName)
    }
    Do $$$AssertEquals(..AllProhibits("rOBJ(""O""):(END)"), "1 " _ ..#OWNCODE, "%ALL rOBJ(""O""):(END): refused")
}

/// <p>A subscript mapping of a code global that does not reach OcuPilot's names -- a range below them,
/// a range ending before them at an open start (<code>BEGIN</code>), a subscript that is only a leading
/// part of the stem -- and a global the kernel does not hold reach the port on both callers, and the
/// set permits the first in <code>%ALL</code>. Here the namespace keeps its globals and routines on
/// one database, so the base mapping the instance creates with each moves nothing. A routine or
/// package mapping named like a code global moves no global.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.CoversCodeGlobal</method> answers
/// 1 for every subscripted name of a member -> each member leg is refused and this goes red.</p>
Method TestASubscriptMappingThatDoesNotReachOcuPilotIsPermitted()
{
    Do $$$AssertEquals($ClassMethod(..#KERNEL, "BaseMappingMoves", $NAMESPACE, "rOBJ"), 0, "this namespace's base mapping of a code global lands where it is read now")
    Do $$$AssertEquals($ClassMethod(..#KERNEL, "CoversOwnName", "r*", "routine-mapping", $NAMESPACE) _ $ClassMethod(..#KERNEL, "CoversOwnName", "oddDEF", "package-mapping", $NAMESPACE), "00", "a routine or package mapping named like a code global covers nothing of OcuPilot's")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    For tName = "rOBJ(""A""):(""B"")", "oddDEF(BEGIN):(""O"")", "rOBJ(""Ocu"")", "OcuProbe1814Code(""OcuPilot"")" {
        Do ..AssertPermitted(tName)
    }
    Do $$$AssertEquals(..AllProhibits("rOBJ(""A""):(""B"")"), "0 ", "%ALL rOBJ(""A""):(""B""): permitted")
}

/// <p>A change and a delete of a <code>%ALL</code> code-global mapping that moves OcuPilot's code --
/// the whole <code>rOBJ</code>, and a range of <code>oddDEF</code> reaching OcuPilot's names -- are
/// refused by the set, as a create is; the same writes to a range that does not reach them are
/// permitted.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.Mapping</method> passes
/// <code>""</code> as the mapping type -> each change and delete leg of a code global is permitted and
/// this goes red.</p>
Method TestAChangeOrDeleteOfACodeGlobalMappingIsRefused()
{
    For tCase = $ListBuild("Update", "rOBJ", 1), $ListBuild("Delete", "rOBJ", 1), $ListBuild("Update", "oddDEF(""OcuPilot""):(""OcuPilotz"")", 1), $ListBuild("Delete", "oddDEF(""OcuPilot""):(""OcuPilotz"")", 1), $ListBuild("Update", "rOBJ(""A""):(""B"")", 0), $ListBuild("Delete", "rOBJ(""A""):(""B"")", 0) {
        Set tTool = $ClassMethod(..#WRITE, "Tool", "global", $List(tCase, 1))
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(..#TYPE, "instance", $ClassMethod(..#PROBE, "Id", "%ALL", $List(tCase, 2)), .tRef)
        Do $$$AssertStatusOK(tSC, $ListToString(tCase, " ") _ ": the reference is built")
        Set tPayload = $Select($List(tCase, 1) = "Delete": {"Database": "USER", "LockDatabase": "", "Collation": 5}, 1: {"Database": "IRISTEMP"})
        Set tDiff = $Select($List(tCase, 1) = "Delete": [], 1: [{"field": "Database", "before": "USER", "after": "IRISTEMP"}])
        Set tSC = ##class(OcuPilot.Test.MappingAllTargetFixture).Prohibits($Parameter(tTool, "TOOLNAME"), tRef, tPayload.%ToJSON(), tDiff.%ToJSON(), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, $ListToString(tCase, " ") _ ": the set answers")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 3): "1 " _ ..#OWNCODE, 1: "0 "), $ListToString(tCase, " ") _ ": " _ $Select($List(tCase, 3): "refused", 1: "permitted"))
    }
}

/// <p>Where a namespace's globals database is not its routines database, the base mapping the instance
/// creates with a subscript mapping of a code global moves the whole global there, so even a range
/// that does not reach OcuPilot's names moves its class definitions: measured in a probe namespace
/// over <code>IRISTEMP</code> and <code>USER</code>, and foreseen by the predicate, which refuses the
/// range for that namespace and permits it for this one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.BaseMappingMoves</method>
/// answers 0 -> the split namespace's range is permitted and this goes red.</p>
Method TestABaseMappingThatWouldMoveACodeGlobalIsRefused()
{
    Set tName = "oddDEF(""A""):(""B"")"
    Set tOwn = """" _ $ClassName() _ """"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", ..#SPLIT, "IRISTEMP"), "a probe namespace with its globals on IRISTEMP and its routines on USER is created")
    Do $$$AssertEquals($ClassMethod(..#KERNEL, "BaseMappingMoves", ..#SPLIT, "oddDEF"), 1, "the predicate foresees that its base mapping moves the class definitions")
    Do $$$AssertEquals($ClassMethod(..#KERNEL, "CoversOwnName", tName, ..#TYPE, ..#SPLIT) _ $ClassMethod(..#KERNEL, "CoversOwnName", tName, ..#TYPE, $NAMESPACE), "10", "and refuses the range there, while permitting it here")
    Set tBefore = ##class(%SYS.Namespace).GetGlobalDest(..#SPLIT, "oddDEF", tOwn)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#SPLIT, tName, "USER"), "the range is mapped in the probe namespace")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#SPLIT), "oddDEF," _ tName, "the instance created the base mapping with it")
    Set tAfter = ##class(%SYS.Namespace).GetGlobalDest(..#SPLIT, "oddDEF", tOwn)
    Do $$$AssertEquals(tBefore '= tAfter, 1, "which moved this class's definition from " _ tBefore _ " to " _ tAfter)
    Do $$$AssertEquals(tAfter, ##class(%SYS.Namespace).GetGlobalDest(..#SPLIT), "onto the namespace's globals database")
}

/// <p>A copy into the namespace this process runs in is refused on both callers from a source holding
/// a subscript mapping of a code global that reaches OcuPilot's names, and from one holding a range
/// that does not, because the instance created the base mapping with it and the copy brings it; into
/// a probe namespace the same sources reach the port.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Kernel.Proposal.Prohibited.CODEGLOBALS</parameter> set
/// to <code>""</code> -> each refused copy reaches the port and this goes red.</p>
Method TestACopyOfACodeGlobalMappingIsRefused()
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    For tNs = ..#SOURCE, ..#NEARSOURCE, ..#DESTINATION {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tNs), tNs _ " is created")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#SOURCE, "oddDEF(""OcuPilot""):(""OcuPilotz"")", "USER"), "a source maps a range of class definitions reaching OcuPilot's")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NEARSOURCE, "oddDEF(""A""):(""B"")", "USER"), "another maps a range that does not")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    For tSource = ..#SOURCE, ..#NEARSOURCE {
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", $ClassMethod(..#COPY, "Body", tOwnNs, tSource), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#COPY, "Code", tAnswer), "403 " _ ..#OWNCODE, tSource _ ": the screen's copy is refused")
        Set tSC = $ClassMethod(..#WRITE, "Mint", ..#COPYTOOL, {"Name": (tOwnNs), "SourceNamespace": (tSource)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tSource _ ": the agent's copy is minted " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "403 " _ ..#OWNCODE, tSource _ ": and its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tSource _ ": no copy reached the port")
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.namespaces", $ClassMethod(..#COPY, "Body", ..#DESTINATION, tSource), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "200 MAPPINGS", tSource _ ": into a probe namespace the copy reaches the port")
    }
}

/// <p>Asserts that a global mapping create of <var>pName</var> in the namespace this process runs in
/// is refused on the screen's Save and at the agent's confirm, with no write reaching the port.</p>
Method AssertRefused(pName As %String)
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "create", tOwnNs, pName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, pName _ ": the screen's create is refused")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..Tool(), {"Namespace": (tOwnNs), "Name": (pName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, pName _ ": the agent's create is minted " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "403 " _ ..#OWNCODE, pName _ ": and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", pName _ ": no write reached the port")
}

/// <p>Asserts that a global mapping create of <var>pName</var> in the namespace this process runs in
/// reaches the port on the screen's Save and at the agent's confirm.</p>
Method AssertPermitted(pName As %String)
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "create", tOwnNs, pName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "201  PUT", pName _ ": the screen's create is permitted and reaches the port")
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..Tool(), {"Namespace": (tOwnNs), "Name": (pName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal) _ $ClassMethod(..#ACCEPT, "Writes"), "200 PUT", pName _ ": so is the agent's " _ tProblem)
}

/// <p>The prohibited set's answer, <code>prohibits code</code>, for a create of the <code>%ALL</code>
/// global mapping <var>pName</var>.</p>
ClassMethod AllProhibits(pName As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(..#TYPE, "instance", $ClassMethod(..#PROBE, "Id", "%ALL", pName), .tRef)
    If $$$ISERR(tSC) Quit "no reference"
    Set tSC = ##class(OcuPilot.Test.MappingAllTargetFixture).Prohibits($Parameter(..Tool(), "TOOLNAME"), tRef, {"Database": "USER"}.%ToJSON(), "[]", .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit "no answer: " _ $System.Status.GetErrorText(tSC)
    Quit tProhibits _ " " _ tCode
}

/// <p>The global mapping create tool class.</p>
ClassMethod Tool() As %String
{
    Quit $ClassMethod(..#WRITE, "Tool", "global", "Create")
}

/// <p>Whether global name <var>pName</var> begins with one of <var>pStems</var>, ignoring case.</p>
ClassMethod BeginsWithStem(pName As %String, pStems As %List) As %Boolean
{
    Set tBegins = 0
    For tI = 1:1:$ListLength(pStems) {
        If $ZConvert($Extract(pName, 1, $Length($List(pStems, tI))), "L") = $List(pStems, tI) Set tBegins = 1
    }
    Quit tBegins
}

/// <p>Whether global <var>pRef</var> holds a subscript beginning with one of <var>pStems</var> in any
/// case, at its first level or at its second; <var>pBelow</var> whether it holds one at the second
/// under a first subscript that does not begin with a stem.</p>
ClassMethod Holds(pRef As %String, pStems As %List, Output pBelow As %Boolean) As %Boolean
{
    Set pBelow = 0
    Set tFirst = ""
    For {
        Set tFirst = $Order(@pRef@(tFirst))
        If tFirst = "" Quit
        If ..BeginsWithStem(tFirst, pStems) Continue
        If ..HoldsStem(pRef, tFirst, pStems) {
            Set pBelow = 1
            Quit
        }
    }
    Quit pBelow || ..HoldsStem(pRef, "", pStems)
}

/// <p>Whether global <var>pRef</var> holds, directly under <var>pFirst</var> or at its first level when
/// <var>pFirst</var> is <code>""</code>, a subscript beginning with one of <var>pStems</var> in any
/// case. Only the subscripts whose first letter is the stem's, in either case, are read.</p>
ClassMethod HoldsStem(pRef As %String, pFirst As %String, pStems As %List) As %Boolean
{
    Set tHolds = 0
    For tI = 1:1:$ListLength(pStems) {
        Set tStem = $List(pStems, tI)
        For tLetter = $ZConvert($Extract(tStem), "U"), $ZConvert($Extract(tStem), "L") {
            Set tSub = tLetter
            For {
                Set tSub = $Select(pFirst = "": $Order(@pRef@(tSub)), 1: $Order(@pRef@(pFirst, tSub)))
                If (tSub = "") || ($Extract(tSub) '= tLetter) Quit
                If $ZConvert($Extract(tSub, 1, $Length(tStem)), "L") = tStem {
                    Set tHolds = 1
                    Quit
                }
            }
            If tHolds Quit
        }
        If tHolds Quit
    }
    Quit tHolds
}

/// <p>The subscripts of <var>pArray</var>, comma-separated in collation order.</p>
ClassMethod Joined(ByRef pArray) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pArray(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>The comma-separated list <var>pList</var>, in collation order.</p>
ClassMethod Sorted(pList As %String) As %String
{
    Kill tArray
    For tI = 1:1:$Length(pList, ",") {
        If $Piece(pList, ",", tI) '= "" Set tArray($Piece(pList, ",", tI)) = ""
    }
    Quit ..Joined(.tArray)
}

}
