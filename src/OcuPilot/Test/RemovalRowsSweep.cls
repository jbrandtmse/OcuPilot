/// <p>What pins <method>OcuPilot.Screen.Tool.Write.RemovalRows</method> as the one place a delete's removal rows
/// are built. A delete tool whose own <code>StateDiff</code> writes a <code>"removed"</code> row calls
/// <method>RemovalRows</method>, or is on <method>Others</method>, the list of tools whose rows have another
/// shape. A tool added later with its own copy of the loop in its <code>StateDiff</code> fails here, naming it.</p>
/// <p>Seven tests. One scans the shipped tool classes' own <code>StateDiff</code> source. One pins each migrated
/// tool's call: the names it reads and whether it skips an unassigned field, with <method>Sites</method> naming
/// exactly the tools whose own <code>StateDiff</code> passes <method>RemovalRows</method> a names list. One reads the roster
/// itself: every name on it is a compiled tool that writes a <code>"removed"</code> row and does not call
/// <method>RemovalRows</method>. Two drive <method>RemovalRows</method>: the rows follow the names it is given, in
/// that order, with each value as <method>OcuPilot.Kernel.Proposal.Mint.Display</method> renders it, and with
/// no names they follow <parameter>REMOVALROWS</parameter>. One pins a row's field order and value types as
/// JSON. One calls <code>StateDiff</code> of the tools whose precondition is a field present or absent in the
/// read, and holds the proposal's rows to the names and the unassigned-field flag the roster gives.</p>
/// <p>It needs nothing from the environment, creates nothing and writes nothing.</p>
Class OcuPilot.Test.RemovalRowsSweep Extends %UnitTest.TestCase
{

/// <p>The class that holds <method>RemovalRows</method>.</p>
Parameter BASE = "OcuPilot.Screen.Tool.Write";

/// <p>A tool with a <parameter>REMOVALROWS</parameter> of its own, for the leg that passes no names.</p>
Parameter DECLARING = "OcuPilot.Screen.Tool.ExplorerDocDbDelete";

/// <p>The tools whose own <code>StateDiff</code> writes a <code>"removed"</code> row in a shape
/// <method>RemovalRows</method> does not build: an array the tool reads for itself, one state row, or a raw
/// <code>%Get</code> of one value. Comma-separated class names.</p>
ClassMethod Others() As %String
{
    Quit "ErrorDelete,LockRemove,MftConnectionRevoke,UserTokenRevoke,ExplorerDelete,OAuthResourceServerDelete,OAuthAuthorizationServerDelete"
}

/// <p>The tools that build their removal rows through <method>RemovalRows</method>, each as
/// <code>class:skip:source</code>: <code>skip</code> is the unassigned-field flag the tool passes and
/// <code>source</code> the method that answers its names. Comma-separated.</p>
ClassMethod Sites() As %String
{
    Set tFingerprint = "OAuthServerDescriptionDelete,AuditUserEventDelete,TaskDelete,WebAppDelete,SslDelete,OAuthServerClientDelete,OAuthClientDelete,LdapDelete,ResourceDelete,RoleDelete,UserDelete"
    Set tSites = ""
    For tI = 1:1:$Length(tFingerprint, ",") {
        Set tSites = tSites _ $Select(tSites = "": "", 1: ",") _ $Piece(tFingerprint, ",", tI) _ ":0:FingerprintSubject"
    }
    Quit tSites _ ",SuperserverDelete:1:ReadAnswers,DocDbAppDelete:1:ReadAnswers,WalletSecretDelete:1:ReadAnswers,WebAppPctAccessDelete:1:ReadAnswers,MappingDelete:0:ReadAnswers"
}

/// <p>The compiled <package>OcuPilot.Screen.Tool</package> classes whose own <code>StateDiff</code> source names
/// <code>"removed"</code>, comma-separated in name order.</p>
ClassMethod RemovingClasses() As %String
{
    Quit ..ClassesWhoseStateDiffHas("""removed""")
}

/// <p>The compiled <package>OcuPilot.Screen.Tool</package> classes whose own <code>StateDiff</code> source contains
/// <var>pText</var>, comma-separated in name order.</p>
ClassMethod ClassesWhoseStateDiffHas(pText As %String) As %String
{
    Set tFound = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.Screen.Tool.' ORDER BY Name")
    If tRS.%SQLCODE < 0 Quit ""
    While tRS.%Next() {
        Set tClass = tRS.%GetData(1)
        If ..StateDiffSource(tClass) [ pText Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tClass
    }
    Do tRS.%Close()
    Quit tFound
}

/// <p>The tools whose own <code>StateDiff</code> calls <method>RemovalRows</method> with a third argument, a
/// names list, as full class names, comma-separated in exact collation order.</p>
ClassMethod NamesCallers() As %String
{
    Set tAll = ..ClassesWhoseStateDiffHas("RemovalRows(")
    For tI = 1:1:$Length(tAll, ",") {
        Set tClass = $Piece(tAll, ",", tI)
        If tClass = "" Continue
        If $Length($Piece($Piece(..StateDiffSource(tClass), "RemovalRows(", 2), ")", 1), ",") >= 3 Set tSorted(tClass) = ""
    }
    Quit ..Joined(.tSorted)
}

/// <p>The subscripts of <var>pSet</var>, comma-separated in collation order.</p>
ClassMethod Joined(ByRef pSet) As %String
{
    Set tJoined = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pSet(tKey))
        If tKey = "" Quit
        Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ",") _ tKey
    }
    Quit tJoined
}

/// <p>The source of the <code>StateDiff</code> method <var>pClass</var> declares itself, or <code>""</code> when it
/// declares none.</p>
ClassMethod StateDiffSource(pClass As %String) As %String
{
    Set tSource = ""
    Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(pClass _ "||StateDiff")
    If '$IsObject(tMethod) Quit ""
    Do tMethod.Implementation.Rewind()
    While 'tMethod.Implementation.AtEnd {
        Set tSource = tSource _ tMethod.Implementation.Read(32000)
    }
    Quit tSource
}

/// <p>Every tool that writes its own <code>"removed"</code> row in <code>StateDiff</code> calls
/// <method>RemovalRows</method> or is named by <method>Others</method>.</p>
/// <p>Mutation (Rule 19): put one delete's own loop back in place of its <method>RemovalRows</method> call -- this
/// goes red naming it.</p>
Method TestEveryRemovalRowComesFromTheOneBuilder()
{
    Set tClasses = ..RemovingClasses()
    Set tOthers = ..Others()
    Set tChecked = 0
    Set tStray = ""
    For tI = 1:1:$Length(tClasses, ",") {
        Set tClass = $Piece(tClasses, ",", tI)
        If tClass = "" Continue
        Set tChecked = tChecked + 1
        Set tShort = $Piece(tClass, ".", $Length(tClass, "."))
        If ..StateDiffSource(tClass) '[ "RemovalRows(" && '$ListFind($ListFromString(tOthers, ","), tShort) Set tStray = tStray _ " " _ tClass
    }
    Do $$$AssertTrue(tChecked >= $Length(tOthers, ","), "control: the scan reaches every tool on the list of other shapes (" _ tChecked _ ")")
    Do $$$AssertEquals(tStray, "", "every tool that writes a removed row builds it through RemovalRows or is on the list of other shapes:" _ tStray)
}

/// <p>Each tool on <method>Sites</method> has its own <code>StateDiff</code> set its rows from
/// <method>RemovalRows</method> with the unassigned-field flag and names source the roster gives.</p>
/// <p>Mutation (Rule 19): change one tool's flag or names source in its own <code>StateDiff</code> -- this goes red
/// naming it.</p>
Method TestEachToolPassesItsOwnNamesAndSkip()
{
    Set tSites = ..Sites()
    Set tMiscalled = ""
    For tI = 1:1:$Length(tSites, ",") {
        Set tSite = $Piece(tSites, ",", tI)
        Set tClass = "OcuPilot.Screen.Tool." _ $Piece(tSite, ":", 1)
        Set tCall = "Set pRows = ..RemovalRows(pFresh, " _ $Piece(tSite, ":", 2) _ ", .." _ $Piece(tSite, ":", 3) _ "())"
        If ..StateDiffSource(tClass) '[ tCall Set tMiscalled = tMiscalled _ " " _ tClass
        Set tRoster(tClass) = ""
    }
    Do $$$AssertEquals(..Joined(.tRoster), ..NamesCallers(), "control: the roster names exactly the tools whose own StateDiff passes RemovalRows a names list")
    Do $$$AssertEquals(tMiscalled, "", "every tool passes the flag and names source the roster gives:" _ tMiscalled)
}

/// <p>The list of other shapes names nothing stale: each name is a compiled tool whose own <code>StateDiff</code>
/// writes a <code>"removed"</code> row and does not call <method>RemovalRows</method>.</p>
/// <p>Mutation (Rule 19): add a name to <method>Others</method> that is not such a tool -- this goes red naming
/// it.</p>
Method TestTheListOfOtherShapesNamesNothingStale()
{
    Set tOthers = ..Others()
    Set tStale = ""
    For tI = 1:1:$Length(tOthers, ",") {
        Set tShort = $Piece(tOthers, ",", tI)
        Set tSource = ..StateDiffSource("OcuPilot.Screen.Tool." _ tShort)
        If (tSource '[ """removed""") || (tSource [ "RemovalRows(") Set tStale = tStale _ " " _ tShort
    }
    Do $$$AssertEquals(tStale, "", "each name on the list is a tool with its own removed row:" _ tStale)
}

/// <p>With names, the rows follow them in that order, each <code>before</code> the value as
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> renders it; with the skip, a name the read did not
/// assign gets no row; a read that is not an object still gets every row.</p>
/// <p>Mutation (Rule 19): ignore <var>pNames</var> in <method>RemovalRows</method> -- this goes red.</p>
Method TestRowsFollowTheNamesInOrder()
{
    Set tFresh = {"Alpha": "one", "Beta": 2, "Gamma": true}
    Set tNames = $ListBuild("Gamma", "Alpha", "Missing", "Beta")
    Set tRows = $ClassMethod(..#BASE, "RemovalRows", tFresh, 0, tNames)
    Do $$$AssertEquals(tRows.%Size(), 4, "without the skip every name has a row")
    Set tOrder = ""
    Set tOK = 1
    For tI = 0:1:tRows.%Size() - 1 {
        Set tRow = tRows.%Get(tI)
        Set tOrder = tOrder _ $Select(tOrder = "": "", 1: ",") _ tRow.field
        If (tRow.after '= "") || (tRow.removed '= 1) Set tOK = 0
        If (tRow.field '= "Missing") && (tRow.before '= ##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get(tRow.field), tFresh.%GetTypeOf(tRow.field))) Set tOK = 0
    }
    Do $$$AssertEquals(tOrder, "Gamma,Alpha,Missing,Beta", "the rows follow the names given")
    Do $$$AssertTrue(tOK, "each row is empty after, removed, and carries Mint.Display of the read value")
    Set tSkipped = $ClassMethod(..#BASE, "RemovalRows", tFresh, 1, tNames)
    Set tOrder = ""
    For tI = 0:1:tSkipped.%Size() - 1 {
        Set tOrder = tOrder _ $Select(tOrder = "": "", 1: ",") _ tSkipped.%Get(tI).field
    }
    Do $$$AssertEquals(tOrder, "Gamma,Alpha,Beta", "with the skip an unassigned name has no row")
    Set tNone = $ClassMethod(..#BASE, "RemovalRows", "", 1, tNames)
    Do $$$AssertEquals(tNone.%Size(), 4, "a read that is not an object still gets every row")
    Do $$$AssertEquals(tNone.%Get(0).before, "", "and each reads empty")
}

/// <p>With no names, the rows follow the class's <parameter>REMOVALROWS</parameter>.</p>
/// <p>Mutation (Rule 19): read the names from <var>pNames</var> only -- this goes red.</p>
Method TestNoNamesReadsTheDeclaredRows()
{
    Set tFresh = {"Name": "ProbeDocDb", "Class": "ProbeClass"}
    Set tRows = $ClassMethod(..#DECLARING, "RemovalRows", tFresh)
    Set tDeclared = $Parameter(..#DECLARING, "REMOVALROWS")
    Do $$$AssertEquals(tDeclared, "Name,Class", "control: the tool declares the rows this leg reads")
    Do $$$AssertEquals(tRows.%Size(), 2, "one row per declared name")
    Do $$$AssertEquals(tRows.%Get(0).field _ "," _ tRows.%Get(1).field, tDeclared, "in the declared order")
    Do $$$AssertEquals(tRows.%Get(0).before, "ProbeDocDb", "carrying the read value")
}

/// <p>The entries of <method>Sites</method> whose <code>StateDiff</code> precondition only needs its field
/// assigned: every site but <code>RoleDelete</code> (an array), <code>AuditUserEventDelete</code> (a boolean) and
/// <code>TaskDelete</code> (two fields), with the abstract <code>MappingDelete</code> driven through
/// <code>GlobalMappingDelete</code>. Comma-separated, as <method>Sites</method> writes them.</p>
ClassMethod Driven() As %String
{
    Set tSites = ..Sites()
    Set tDriven = ""
    For tI = 1:1:$Length(tSites, ",") {
        Set tSite = $Piece(tSites, ",", tI)
        If $ListFind($ListBuild("RoleDelete", "AuditUserEventDelete", "TaskDelete"), $Piece(tSite, ":", 1)) Continue
        If $Piece(tSite, ":", 1) = "MappingDelete" Set $Piece(tSite, ":", 1) = "GlobalMappingDelete"
        Set tDriven = tDriven _ $Select(tDriven = "": "", 1: ",") _ tSite
    }
    Quit tDriven
}

/// <p>The rows <var>pNames</var> make for <var>pFresh</var> as JSON, each carrying the read value
/// <code>v-</code> plus the name, or <code>""</code> for a name <var>pSkip</var> leaves out or the read did not
/// assign.</p>
ClassMethod ExpectedRows(pFresh As %DynamicObject, pNames As %List, pSkip As %Boolean) As %String
{
    Set tJSON = ""
    For tI = 1:1:$ListLength(pNames) {
        Set tName = $List(pNames, tI)
        Set tAssigned = (pFresh.%GetTypeOf(tName) '= "unassigned")
        If pSkip && 'tAssigned Continue
        Set tJSON = tJSON _ $Select(tJSON = "": "", 1: ",") _ "{""field"":""" _ tName _ """,""before"":""" _ $Select(tAssigned: "v-" _ tName, 1: "") _ """,""after"":"""",""removed"":true}"
    }
    Quit "[" _ tJSON _ "]"
}

/// <p>A row is <code>field</code>, <code>before</code>, <code>after</code>, <code>removed</code>, in that
/// order, the first three strings and the last a JSON boolean.</p>
/// <p>Mutation (Rule 19): set <code>after</code> before <code>before</code> in <method>RemovalRows</method> --
/// this goes red.</p>
Method TestARowKeepsItsFieldOrderAndTypes()
{
    Set tRows = $ClassMethod(..#BASE, "RemovalRows", {"Alpha": "one"}, 0, $ListBuild("Alpha"))
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""Alpha"",""before"":""one"",""after"":"""",""removed"":true}]", "the row's keys, order and value types")
}

/// <p>Each tool on <method>Driven</method>, given a read that assigns every name it reads or fingerprints, answers
/// <code>StateDiff</code> rows that are exactly those names in order, each with the value read; given a read
/// that leaves one name unassigned, a tool with the skip omits that row and a tool without it keeps the row
/// empty. A tool that migrated to <method>RemovalRows</method> with another names source or flag is seen here
/// by its rows, not by its source.</p>
/// <p>Mutation (Rule 19): pass skip <code>0</code> in <code>SuperserverDelete</code> -- this goes red naming
/// it.</p>
Method TestEachDrivenToolAnswersTheRowsItsRosterNames()
{
    Set tSites = ..Driven()
    Set tWrong = ""
    Set tRowsChecked = 0
    Set tOmitted = 0
    For tI = 1:1:$Length(tSites, ",") {
        Set tSite = $Piece(tSites, ",", tI)
        Set tShort = $Piece(tSite, ":", 1)
        Set tClass = "OcuPilot.Screen.Tool." _ tShort
        Set tSkip = $Piece(tSite, ":", 2)
        Set tNames = $ClassMethod(tClass, $Piece(tSite, ":", 3))
        Set tPre = $ClassMethod(tClass, "PreconditionField")
        Set tFresh = {}
        For tJ = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tJ)
            Do tFresh.%Set(tName, "v-" _ tName, "string")
        }
        If tPre '= "" Do tFresh.%Set(tPre, "v-" _ tPre, "string")
        Set tRows = ""
        Set tProblem = ""
        Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
        Set tExpected = ..ExpectedRows(tFresh, tNames, tSkip)
        If $$$ISERR(tSC) || (tProblem '= "") || (tRows.%ToJSON() '= tExpected) Set tWrong = tWrong _ " " _ tShort _ "(full)"
        Set tRowsChecked = tRowsChecked + tRows.%Size()
        ; leave out the last name that is not the precondition's field
        Set tOmit = ""
        For tJ = $ListLength(tNames):-1:1 {
            If $List(tNames, tJ) '= tPre Set tOmit = $List(tNames, tJ) Quit
        }
        If tOmit '= "" Set tOmitted = tOmitted + 1
        Do tFresh.%Remove(tOmit)
        Set tRows = ""
        Set tProblem = ""
        Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
        Set tExpected = ..ExpectedRows(tFresh, tNames, tSkip)
        If $$$ISERR(tSC) || (tProblem '= "") || (tRows.%ToJSON() '= tExpected) Set tWrong = tWrong _ " " _ tShort _ "(one unassigned)"
        Set tRowsChecked = tRowsChecked + tRows.%Size()
    }
    Do $$$AssertEquals(tOmitted, $Length(tSites, ","), "control: each tool's second leg left one name unassigned")
    Do $$$AssertTrue(tRowsChecked > $Length(tSites, ","), "control: the legs produced rows (" _ tRowsChecked _ ")")
    Do $$$AssertEquals(tWrong, "", "each tool's rows are its names in order, with its skip:" _ tWrong)
}

}
