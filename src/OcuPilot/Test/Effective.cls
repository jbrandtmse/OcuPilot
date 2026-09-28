/// <p>Pins <class>OcuPilot.Kernel.Shell.Effective</class>'s composition (AD-8, Stories 16.19 and
/// 16.3) over literal role rows: the union across roles, <code>GrantedRoles</code> followed at every
/// depth, <code>%All</code> anywhere in the closure, public permissions, the order and spelling of a
/// lost pair, a cycle among granted roles, the closure and granting-role members, and
/// <method>OcuPilot.Kernel.Shell.Effective.Holds</method>. It reads nothing from the instance and
/// needs nothing from the environment.</p>
Class OcuPilot.Test.Effective Extends %UnitTest.TestCase
{

Parameter EFFECTIVE = "OcuPilot.Kernel.Shell.Effective";

/// <p><var>pRoles</var>'s loss when <var>pRemoved</var> is taken away, as a comma-joined string.</p>
Method LossOf(pRoles As %DynamicArray, pRemoved As %String, pRows As %DynamicObject, pPublic As %DynamicObject = "") As %String
{
    If '$IsObject(pPublic) Set pPublic = {}
    Set tAfter = []
    Set tIterator = pRoles.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        If $ZConvert(tRole, "U") '= $ZConvert(pRemoved, "U") Do tAfter.%Push(tRole)
    }
    Set tBefore = $ClassMethod(..#EFFECTIVE, "Compose", pRoles, pRows, pPublic)
    Set tAfterSet = $ClassMethod(..#EFFECTIVE, "Compose", tAfter, pRows, pPublic)
    Quit ..Joined($ClassMethod(..#EFFECTIVE, "Loss", tBefore, tAfterSet, pPublic))
}

Method Joined(pArray As %DynamicArray) As %String
{
    Set tOut = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tOne
    }
    Quit tOut
}

/// <p>Permissions union across roles: A grants X:R and B X:W, so both are held, and removing B
/// loses only X:W.</p>
Method TestPermissionsUnionAcrossRoles()
{
    Set tRows = {"A": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "R"}]}, "B": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "W"}]}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["A", "B"], tRows, {})
    Do $$$AssertEquals(tHeld.%Get("resources").%Get("X").%Get("R"), "A", "X:R is held through A")
    Do $$$AssertEquals(tHeld.%Get("resources").%Get("X").%Get("W"), "B", "and X:W through B")
    Do $$$AssertEquals(..LossOf(["A", "B"], "B", tRows), "X:W", "removing B loses X:W alone")
}

/// <p><code>GrantedRoles</code> are followed at every depth: G1 grants G2, which grants G3, so
/// removing G3 directly loses nothing, and a role held only through the chain is held.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Kernel.Shell.Effective.Compose</method> queueing a
/// granted role -- this goes red.</p>
Method TestAGrantedRoleIsFollowedAtEveryDepth()
{
    Set tRows = {"G1": {"GrantedRoles": ["G2"], "Resources": []}, "G2": {"GrantedRoles": ["G3"], "Resources": []}, "G3": {"GrantedRoles": [], "Resources": [{"Name": "Y", "Permissions": "RW"}]}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["G1"], tRows, {})
    Do $$$AssertEquals(tHeld.%Get("resources").%Get("Y").%Get("W"), "G1", "Y:W is held through G1's chain")
    Do $$$AssertEquals(..LossOf(["G1", "G3"], "G3", tRows), "", "removing G3 loses nothing G1 still grants")
}

/// <p><code>%All</code> anywhere in the closure holds everything: a user holding A and AllVia,
/// which grants <code>%All</code>, loses nothing when A goes.</p>
Method TestAllInTheClosureKeepsEverything()
{
    Set tRows = {"A": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "RWU"}]}, "AllVia": {"GrantedRoles": ["%All"], "Resources": []}, "%All": {"GrantedRoles": [], "Resources": []}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["A", "AllVia"], tRows, {})
    Do $$$AssertTrue(tHeld.%Get("all"), "%All is held")
    Do $$$AssertEquals(tHeld.%Get("allVia"), "AllVia", "through AllVia")
    Do $$$AssertEquals(..LossOf(["A", "AllVia"], "A", tRows), "", "removing A loses nothing")
}

/// <p>Losing <code>%All</code> names it first, then each pair the remaining roles do not grant.</p>
Method TestLosingAllNamesItFirst()
{
    Set tRows = {"AllVia": {"GrantedRoles": ["%All"], "Resources": [{"Name": "Z", "Permissions": "R"}, {"Name": "X", "Permissions": "W"}]}, "P": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "RW"}]}}
    Do $$$AssertEquals(..LossOf(["AllVia", "P"], "AllVia", tRows), "%All,Z:R", "%All, then Z:R, and not X:W, which P grants")
}

/// <p>A resource's public permission is held by every user: removing the role that grants X:R
/// loses nothing when X is public R, and still loses the W it does not cover.</p>
Method TestAPublicPermissionIsNeverLost()
{
    Set tRows = {"R1": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "RW"}]}}
    Do $$$AssertEquals(..LossOf(["R1"], "R1", tRows, {"X": "R"}), "X:W", "public R stays held, W is lost")
    Do $$$AssertEquals(..LossOf(["R1"], "R1", tRows, {}), "X:RW", "with no public permission both letters are lost")
}

/// <p>Names are compared without regard to case, a lost pair keeps the spelling first met, and
/// the pairs come by resource name with their letters in R, W, U order.</p>
Method TestNamesFoldCaseAndPairsSortByName()
{
    Set tRows = {"a": {"GrantedRoles": [], "Resources": [{"Name": "Zed", "Permissions": "UR"}, {"Name": "alpha", "Permissions": "W"}]}, "B": {"GrantedRoles": [], "Resources": [{"Name": "ZED", "Permissions": "u"}]}}
    Do $$$AssertEquals(..LossOf(["A", "b"], "A", tRows), "alpha:W,Zed:R", "only Zed's R and alpha's W are lost, by name")
}

/// <p>A cycle among granted roles terminates, each role visited once.</p>
Method TestACycleAmongGrantedRolesTerminates()
{
    Set tRows = {"C1": {"GrantedRoles": ["C2"], "Resources": [{"Name": "X", "Permissions": "R"}]}, "C2": {"GrantedRoles": ["c1"], "Resources": [{"Name": "Y", "Permissions": "R"}]}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["C1"], tRows, {})
    Do $$$AssertEquals(tHeld.%Get("resources").%Size(), 2, "both resources are held once")
    Do $$$AssertEquals(..LossOf(["C1"], "C1", tRows), "X:R,Y:R", "and removing the root loses both")
}

/// <p>Story 16.3 -- <code>roles</code> is the closure in the order it is reached, a granted role
/// naming the root it was reached through; <code>sources</code> names the role whose own grant a
/// letter is, while <code>resources</code> keeps naming the root. A chain A grants B, B holds X:R:
/// X:R is reached through A and granted by B. A public letter records <code>""</code> in both.</p>
/// <p>Mutation (Rule 19): record the root in <code>sources</code> in
/// <method>OcuPilot.Kernel.Shell.Effective.Compose</method> -- this goes red.</p>
Method TestTheClosureAndTheGrantingRoleAreNamed()
{
    Set tRows = {"A": {"GrantedRoles": ["B"], "Resources": []}, "B": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "R"}]}, "E": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "W"}]}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["A"], tRows, {"P": "U"})
    Do $$$AssertEquals(tHeld.%Get("roles").%ToJSON(), "[{""name"":""A"",""through"":""""},{""name"":""B"",""through"":""A""}]", "the closure, B reached through A, and no role the account was not given")
    Do $$$AssertEquals(tHeld.%Get("resources").%Get("X").%Get("R"), "A", "X:R is reached through the root A")
    Do $$$AssertEquals(tHeld.%Get("sources").%Get("X").%Get("R"), "B", "and granted by B")
    Do $$$AssertEquals(tHeld.%Get("sources").%Get("X").%GetTypeOf("W"), "unassigned", "E's X:W is not held")
    Do $$$AssertEquals(tHeld.%Get("resources").%Get("P").%Get("U") _ "|" _ tHeld.%Get("sources").%Get("P").%GetTypeOf("U") _ "|" _ tHeld.%Get("sources").%Get("P").%Get("U"), "|string|", "a public letter names no role in either map")
    Set tTwo = $ClassMethod(..#EFFECTIVE, "Compose", ["A", "B"], tRows, {})
    Do $$$AssertEquals(tTwo.%Get("roles").%ToJSON(), "[{""name"":""A"",""through"":""""},{""name"":""B"",""through"":""""}]", "a role the account holds directly is a root, whatever else grants it")
}

/// <p>Story 16.3 -- <method>OcuPilot.Kernel.Shell.Effective.Holds</method> answers each case: a
/// chained grant names its granting role and root, a public letter says so, a letter nothing grants
/// is not held, and names match without regard to case.</p>
Method TestHoldsAnswersAGrantAPublicLetterAndNone()
{
    Set tRows = {"A": {"GrantedRoles": ["B"], "Resources": []}, "B": {"GrantedRoles": [], "Resources": [{"Name": "X", "Permissions": "R"}]}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["A"], tRows, {"P": "U"})
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "X", "R").%ToJSON(), "{""held"":true,""all"":false,""public"":false,""grantedBy"":""B"",""root"":""A""}", "X:R, granted by B, reached through A")
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "x", "r").%ToJSON(), "{""held"":true,""all"":false,""public"":false,""grantedBy"":""B"",""root"":""A""}", "matched without regard to case")
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "P", "U").%ToJSON(), "{""held"":true,""all"":false,""public"":true,""grantedBy"":"""",""root"":""""}", "P:U, public")
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "X", "W").%ToJSON(), "{""held"":false,""all"":false,""public"":false,""grantedBy"":"""",""root"":""""}", "X:W, not held")
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "Y", "R").%Get("held"), 0, "and a resource nothing records, not held")
}

/// <p>Story 16.3 -- <code>%All</code> in the closure holds every letter of every name, granted by
/// <code>%All</code> and reached through the role that grants it, before any per-resource
/// lookup.</p>
/// <p>Mutation (Rule 19): remove the <code>all</code> branch from
/// <method>OcuPilot.Kernel.Shell.Effective.Holds</method> -- this goes red.</p>
Method TestHoldsAnswersAllBeforeAnyResource()
{
    Set tRows = {"R": {"GrantedRoles": ["%All"], "Resources": []}, "%All": {"GrantedRoles": [], "Resources": []}}
    Set tHeld = $ClassMethod(..#EFFECTIVE, "Compose", ["R"], tRows, {})
    Do $$$AssertEquals($ClassMethod(..#EFFECTIVE, "Holds", tHeld, "AnyResourceAtAll", "W").%ToJSON(), "{""held"":true,""all"":true,""public"":false,""grantedBy"":""%All"",""root"":""R""}", "held through R, granted by %All")
    Do $$$AssertEquals(tHeld.%Get("roles").%ToJSON(), "[{""name"":""R"",""through"":""""},{""name"":""%All"",""through"":""R""}]", "and the closure names %All through R")
}

}
