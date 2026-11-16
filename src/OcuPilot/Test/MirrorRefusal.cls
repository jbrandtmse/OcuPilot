/// <p>Pins the edges of Story 21.12's refusal (AD-10): a write on a <code>mirror</code> target is judged by its stored payload alone, and
/// a payload that does not set <code>DeleteDB</code> or <code>DeleteDBs</code> true -- whatever else it holds, empty, missing, mistyped,
/// unparseable or not an object -- is refused <code>PROHIBITED.UNCOVERED</code>, never allowed. <class>OcuPilot.Test.Prohibited</class>
/// holds the central cases; this class holds the shapes around them.</p>
/// <p><b>Live-safe:</b> it asks the predicate and writes nothing. <b>What it needs from the environment:</b> OcuPilot installed.</p>
Class OcuPilot.Test.MirrorRefusal Extends %UnitTest.TestCase
{

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter FIXTURE = "OcuPilot.Test.ProhibitedFixture";

/// <p>Ask the set about <var>pPayload</var> on a <code>mirror</code> target named <var>pId</var>, answered <code>prohibits|code</code>.</p>
ClassMethod Verdict(pPayload As %String, pDiff As %String = "[]", pId As %String = "MIRRORSET") As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "Ask", "", pPayload, pDiff, pId, "mirror", .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit "error: " _ $System.Status.GetErrorText(tSC)
    Quit tProhibits _ "|" _ tCode
}

/// <p><b>AC4.</b> A flag counts as set when it is the boolean true, a nonzero number, or the text <code>1</code> or <code>true</code> in any
/// letter case, on either field and whatever the other holds; every other spelling is refused <code>UNCOVERED</code>.</p>
/// <p>Mutation (Rule 19): the arm's text comparison drops its case folding -> the capitalised legs go red.</p>
Method TestEachSpellingOfASetFlagIsRefusedWithItsCodeAndNoOtherIs()
{
    Set tDatabases = $Parameter(..#SET, "MIRRORDATABASES")
    Set tUncovered = $Parameter(..#SET, "UNCOVERED")
    For tCase = $ListBuild("{""DeleteDB"":""TRUE""}", tDatabases), $ListBuild("{""DeleteDBs"":""True""}", tDatabases), $ListBuild("{""DeleteDB"":""1""}", tDatabases), $ListBuild("{""DeleteDB"":-1}", tDatabases), $ListBuild("{""DeleteDBs"":2.5}", tDatabases), $ListBuild("{""DeleteDB"":false,""DeleteDBs"":""true"",""Name"":""M""}", tDatabases), $ListBuild("{""Name"":""M"",""DeleteDB"":true}", tDatabases), $ListBuild("{""DeleteDB"":""0""}", tUncovered), $ListBuild("{""DeleteDB"":0.0}", tUncovered), $ListBuild("{""DeleteDBs"":""false""}", tUncovered), $ListBuild("{""DeleteDB"":""yes""}", tUncovered), $ListBuild("{""DeleteDB"":"" true""}", tUncovered), $ListBuild("{""DeleteDB"":""""}", tUncovered), $ListBuild("{""deletedb"":true}", tUncovered), $ListBuild("{""Mirror"":{""DeleteDB"":true}}", tUncovered) {
        Do $$$AssertEquals(..Verdict($List(tCase, 1)), "1|" _ $List(tCase, 2), "the payload '" _ $List(tCase, 1) _ "' is refused with " _ $List(tCase, 2))
    }
}

/// <p><b>AC4.</b> A flag that is null, an array (empty or not) or an object is not set, since both vendor flags are booleans: the write is
/// refused <code>UNCOVERED</code>, and one that sets the other flag alongside is still refused <code>MIRRORDATABASES</code>.</p>
Method TestANullOrMistypedFlagIsRefusedAndNeverAllowed()
{
    Set tDatabases = $Parameter(..#SET, "MIRRORDATABASES")
    Set tUncovered = $Parameter(..#SET, "UNCOVERED")
    For tCase = $ListBuild("{""DeleteDB"":null}", tUncovered), $ListBuild("{""DeleteDBs"":[]}", tUncovered), $ListBuild("{""DeleteDBs"":[""DB1""]}", tUncovered), $ListBuild("{""DeleteDB"":{}}", tUncovered), $ListBuild("{""DeleteDB"":null,""DeleteDBs"":true}", tDatabases), $ListBuild("{""DeleteDBs"":[],""DeleteDB"":true}", tDatabases) {
        Do $$$AssertEquals(..Verdict($List(tCase, 1)), "1|" _ $List(tCase, 2), "the payload '" _ $List(tCase, 1) _ "' is refused with " _ $List(tCase, 2))
    }
}

/// <p><b>AC4.</b> A payload that is no object -- an array, <code>null</code>, a bare string, number or boolean, or only whitespace -- reads as an
/// empty one and is refused <code>UNCOVERED</code>, never allowed and never an error.</p>
Method TestAPayloadThatIsNoObjectIsRefusedAsUncovered()
{
    Set tUncovered = $Parameter(..#SET, "UNCOVERED")
    For tPayload = "[]", "[true]", "[{""DeleteDB"":true}]", "null", """DeleteDB""", "true", "1", " ", "{""DeleteDB"":true", "not json" {
        Do $$$AssertEquals(..Verdict(tPayload), "1|" _ tUncovered, "the payload '" _ tPayload _ "' is refused with " _ tUncovered)
    }
}

/// <p><b>AC4.</b> The verdict does not depend on the diff or the target's name: a flag set is refused <code>MIRRORDATABASES</code> whatever
/// diff the proposal stored and whatever the mirror is called, and a flag unset is refused <code>UNCOVERED</code> under the same.</p>
Method TestTheVerdictIgnoresTheStoredDiffAndTheMirrorsName()
{
    Set tDatabases = $Parameter(..#SET, "MIRRORDATABASES")
    Set tUncovered = $Parameter(..#SET, "UNCOVERED")
    For tDiff = "[]", "", "{}", "[{""field"":""Name"",""before"":""a"",""after"":""b""}]" {
        Do $$$AssertEquals(..Verdict("{""DeleteDBs"":true}", tDiff), "1|" _ tDatabases, "a set flag under the diff '" _ tDiff _ "' is refused with " _ tDatabases)
        Do $$$AssertEquals(..Verdict("{}", tDiff), "1|" _ tUncovered, "no flag under the diff '" _ tDiff _ "' is refused with " _ tUncovered)
    }
    For tId = "MIRRORSET", "mirror-with-dashes", "Mirror Set 1", "x" {
        Do $$$AssertEquals(..Verdict("{""DeleteDB"":true}", "[]", tId), "1|" _ tDatabases, "a set flag on the mirror '" _ tId _ "' is refused with " _ tDatabases)
    }
}

}
