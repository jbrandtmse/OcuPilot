/// <p>Pins the router's prefix arms (AD-12, AD-39): every arm of
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> that hands a code prefix to a family's own
/// <code>ReasonFor</code> answers each of that family's codes the sentence the family does. The arms are read
/// from the router's stored implementation, and a family's codes are the parameters of its class whose value
/// begins with the arm's prefix, so no family is named here and a later arm of that form is covered when it is
/// written. It reaches each such family whether or not the family lists its codes; an arm that hands its prefix
/// to one of the router class's own methods is not of that form, and is not read here.</p>
/// <p><b>What it needs from the environment:</b> the shipped classes compiled on the instance. It writes
/// nothing.</p>
Class OcuPilot.Test.ViolationPrefixArms Extends %UnitTest.TestCase
{

/// <p>The fewest prefix arms the sweep must read: the population it was written against. A sweep that found
/// fewer would be asserting over a roster it failed to read.</p>
Parameter MINARMS = 21;

/// <p>Every prefix arm of the router: <var>pArms</var> is subscripted <code>1..n</code>, each node a
/// <code>$ListBuild(prefix, class, length)</code>, where <code>length</code> is the character count the arm
/// compares. Answers <code>n</code>, or <code>0</code> when the router's method cannot be opened.</p>
ClassMethod Arms(Output pArms) As %Integer
{
    Kill pArms
    Set tCount = ##class(OcuPilot.Test.ViolationSentenceCoverage).RouterMatches("^\s*If \$Extract\(pCode, 1, [0-9]+\) = ""[A-Z0-9]+\."" Quit ##class\([A-Za-z0-9.]+\)\.ReasonFor\(pCode\)", .tMatches)
    For tI = 1:1:tCount {
        Set tMatch = tMatches(tI)
        Set pArms(tI) = $ListBuild($Piece(tMatch, """", 2), $Piece($Piece(tMatch, "##class(", 2), ")", 1), +$Piece($Piece(tMatch, "1, ", 2), ")", 1))
    }
    Quit tCount
}

/// <p>The codes of <var>pClass</var>: its parameters whose value begins with <var>pPrefix</var>, as a
/// <code>%List</code>. Answers <code>""</code> when the query fails.</p>
ClassMethod CodesOf(pClass As %String, pPrefix As %String) As %List
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT _Default AS Value FROM %Dictionary.CompiledParameter WHERE parent = ? AND _Default %STARTSWITH ? ORDER BY Name", pClass, pPrefix)
    If tRS.%SQLCODE < 0 Quit ""
    Set tCodes = ""
    While tRS.%Next() {
        Set tCodes = tCodes _ $ListBuild(tRS.%Get("Value"))
    }
    Quit tCodes
}

/// <p>Each prefix arm compares as many characters as its prefix has, and answers every code of its family the
/// family's own sentence, and the family answers at least one of them a sentence.</p>
/// <p>Mutation (Rule 19): put <code>If $Extract(pCode, 1, 8) = "JOURNAL." Quit ""</code> ahead of the
/// <code>JOURNAL.</code> arm of <method>OcuPilot.Api.Error.ReasonForViolation</method> -- the family lists no
/// codes, so <class>OcuPilot.Test.ViolationSentenceCoverage</class> stays green, and this goes red on each
/// <code>JOURNAL.*</code> code. Deleting the arm goes red on the arm floor alone, because the sweep reads its
/// roster from the arms.</p>
Method TestEveryPrefixArmAnswersItsFamilysSentences()
{
    Set tArms = ..Arms(.tArm)
    Do $$$AssertTrue(tArms >= ..#MINARMS, "the sweep read the router's prefix arms rather than an empty roster (found " _ tArms _ ")")
    For tI = 1:1:tArms {
        Set tPrefix = $List(tArm(tI), 1)
        Set tClass = $List(tArm(tI), 2)
        Do $$$AssertEquals($List(tArm(tI), 3), $Length(tPrefix), "the arm for " _ tPrefix _ " compares as many characters as the prefix has")
        Set tCodes = ..CodesOf(tClass, tPrefix)
        Do $$$AssertTrue($ListValid(tCodes) && ($ListLength(tCodes) > 0), tClass _ " declares codes that begin " _ tPrefix)
        If '$ListValid(tCodes) Continue
        Set tAnswered = 0
        For tJ = 1:1:$ListLength(tCodes) {
            Set tCode = $List(tCodes, tJ)
            Set tFamily = $ClassMethod(tClass, "ReasonFor", tCode)
            Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tFamily, "the router answers " _ tCode _ " what " _ tClass _ " does")
            If tFamily '= "" Set tAnswered = tAnswered + 1
        }
        Do $$$AssertTrue(tAnswered > 0, tClass _ " answers at least one of its " _ $ListLength(tCodes) _ " codes a sentence")
    }
}

}
