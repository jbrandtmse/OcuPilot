/// <p>Pins that every field-level violation code OcuPilot lists carries a published sentence, and
/// that every code the router answers is listed (AD-12, AD-39). The lists are every class method
/// under <code>OcuPilot.Api.</code> whose name ends <code>ViolationCodes</code>, read from the
/// class dictionary, so no family is named here: a later family is covered by adding its list.
/// The router is <method>OcuPilot.Api.Error.ReasonForViolation</method>, read from its stored
/// implementation: every arm that compares the code with a declared parameter must name a listed
/// code, so such a code cannot escape the first check by being left out of every list. Arms that
/// hand a whole code prefix to a family's own class are reached through that family's list.</p>
/// <p><b>What it needs from the environment:</b> the shipped classes compiled on the instance. It
/// writes nothing.</p>
Class OcuPilot.Test.ViolationSentenceCoverage Extends %UnitTest.TestCase
{

/// <p>The package whose classes hold the lists.</p>
Parameter PACKAGE = "OcuPilot.Api.";

/// <p>The method-name suffix that marks a list.</p>
Parameter SUFFIX = "ViolationCodes";

/// <p>The class that holds the router, and the router's method.</p>
Parameter ROUTER = "OcuPilot.Api.Error";

Parameter ROUTERMETHOD = "ReasonForViolation";

/// <p>The fewest lists the sweep must find: the population it was written against. A sweep that
/// found fewer would be asserting over a roster it failed to read.</p>
Parameter MINLISTS = 41;

/// <p>The fewest router arms the sweep must read, for the same reason.</p>
Parameter MINARMS = 100;

/// <p>Every list method: <var>pLists</var> is subscripted <code>1..n</code>, each node a
/// <code>$ListBuild(class, method)</code>. Answers <code>n</code>, or <code>-1</code> when the
/// query failed.</p>
ClassMethod Lists(Output pLists) As %Integer
{
    Kill pLists
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent AS Class, Name AS Method FROM %Dictionary.CompiledMethod WHERE parent LIKE ? AND Name LIKE ? AND ClassMethod = 1 ORDER BY parent, Name", ..#PACKAGE _ "%", "%" _ ..#SUFFIX)
    If tRS.%SQLCODE < 0 Quit -1
    Set tCount = 0
    While tRS.%Next() {
        Set tCount = tCount + 1
        Set pLists(tCount) = $ListBuild(tRS.%Get("Class"), tRS.%Get("Method"))
    }
    Quit tCount
}

/// <p>The parameter names the router compares its argument to, one per arm, read from the
/// router's stored implementation: <var>pNames</var> is subscripted <code>1..n</code>. Answers
/// <code>n</code>, or <code>0</code> when the router's method cannot be opened.</p>
ClassMethod RouterArms(Output pNames) As %Integer
{
    Kill pNames
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(..#ROUTER _ "||" _ ..#ROUTERMETHOD)
    If '$IsObject(tMethod) Quit 0
    Set tStream = tMethod.Implementation
    Do tStream.Rewind()
    Set tCount = 0
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        If '$Locate(tLine, "pCode = \.\.#([A-Z0-9]+)", 1, , tMatch) Continue
        Set tCount = tCount + 1
        Set pNames(tCount) = $Piece(tMatch, "..#", 2)
    }
    Quit tCount
}

/// <p>Every code in every list is answered a sentence by the router, other than the code itself,
/// and every list holds at least one code.</p>
/// <p>Mutation (Rule 19): delete the <code>DOCDB.</code> arm from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- this goes red on
/// <code>DOCDB.NAME.INVALID</code> and <code>DOCDB.NAME.MAPPED</code>.</p>
Method TestEveryListedCodeHasASentence()
{
    Set tCount = ..Lists(.tLists)
    Do $$$AssertTrue(tCount >= ..#MINLISTS, "the sweep read the lists rather than an empty roster (found " _ tCount _ ")")
    For tI = 1:1:tCount {
        Set tName = $List(tLists(tI), 1) _ "." _ $List(tLists(tI), 2)
        Set tList = $ClassMethod($List(tLists(tI), 1), $List(tLists(tI), 2))
        Do $$$AssertTrue($ListValid(tList) && ($ListLength(tList) > 0), tName _ " holds at least one code")
        If '$ListValid(tList) Continue
        For tJ = 1:1:$ListLength(tList) {
            Set tCode = $List(tList, tJ)
            Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
            Do $$$AssertTrue((tReason '= "") && (tReason '= tCode), tName _ " lists " _ tCode _ ", which carries a sentence: '" _ tReason _ "'")
        }
    }
}

/// <p>The router answers the document-database field codes with that family's own sentences,
/// not merely some sentence: it hands <code>DOCDB.*</code> to
/// <method>OcuPilot.Api.DocDbError.ReasonFor</method>.</p>
/// <p>Mutation (Rule 19): make the <code>DOCDB.</code> arm answer
/// <code>DocDbError.ReasonFor("DOCDB.NAME.INVALID")</code> for every code -- this goes red on
/// <code>DOCDB.NAME.MAPPED</code>, while <method>TestEveryListedCodeHasASentence</method> stays
/// green.</p>
Method TestTheRouterAnswersTheDocDbFamilysOwnSentences()
{
    Set tCodes = ##class(OcuPilot.Api.DocDbError).ViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the document-database family lists its field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tExpected = ##class(OcuPilot.Api.DocDbError).ReasonFor(tCode)
        Do $$$AssertTrue(tExpected '= "", tCode _ " has a sentence of its own to be answered")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tExpected, tCode _ " is answered the family's own sentence")
    }
}

/// <p>Every code an arm of the router names is in some list, so a sentence cannot be published
/// for a code the first test never reaches.</p>
/// <p>Mutation (Rule 19): remove <code>HELPROUTE</code> from
/// <method>OcuPilot.Api.Error.HelpViolationCodes</method> -- this goes red on
/// <code>HELP.ROUTE</code>.</p>
Method TestEveryCodeTheRouterNamesIsListed()
{
    Set tCount = ..Lists(.tLists)
    For tI = 1:1:tCount {
        Set tList = $ClassMethod($List(tLists(tI), 1), $List(tLists(tI), 2))
        If '$ListValid(tList) Continue
        For tJ = 1:1:$ListLength(tList) {
            If $List(tList, tJ) '= "" Set tListed($List(tList, tJ)) = ""
        }
    }
    Set tArms = ..RouterArms(.tNames)
    Do $$$AssertTrue(tArms >= ..#MINARMS, "the sweep read the router's arms rather than an empty roster (found " _ tArms _ ")")
    For tI = 1:1:tArms {
        Set tCode = $Parameter(..#ROUTER, tNames(tI))
        Do $$$AssertTrue(tCode '= "", "the router's arm " _ tNames(tI) _ " names a declared code")
        If tCode = "" Continue
        Do $$$AssertTrue($Data(tListed(tCode)) > 0, "the router's arm " _ tNames(tI) _ " (" _ tCode _ ") is in a violation-code list")
    }
}

}
