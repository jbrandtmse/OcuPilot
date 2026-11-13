/// <p>What pins <method>OcuPilot.Screen.Tool.Write.RemovalRows</method> as the one place a delete's removal rows
/// are built. A delete tool whose own <code>StateDiff</code> writes a <code>"removed"</code> row calls
/// <method>RemovalRows</method>, or is on <method>Others</method>, the list of tools whose rows have another
/// shape. A tool added later with its own copy of the loop fails here, naming it.</p>
/// <p>Five tests. One scans the shipped tool classes' own <code>StateDiff</code> source. One pins each migrated
/// tool's call: the names it reads and whether it skips an unassigned field. One reads the roster
/// itself: every name on it is a compiled tool that writes a <code>"removed"</code> row and does not call
/// <method>RemovalRows</method>. Two drive <method>RemovalRows</method>: the rows follow the names it is given, in
/// that order, with each value as <method>OcuPilot.Kernel.Proposal.Mint.Display</method> renders it, and with
/// no names they follow <parameter>REMOVALROWS</parameter>.</p>
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
    Set tFound = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.Screen.Tool.' ORDER BY Name")
    If tRS.%SQLCODE < 0 Quit ""
    While tRS.%Next() {
        Set tClass = tRS.%GetData(1)
        If ..StateDiffSource(tClass) [ """removed""" Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tClass
    }
    Do tRS.%Close()
    Quit tFound
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
    }
    Do $$$AssertEquals($Length(tSites, ","), 16, "control: the roster holds the 16 migrated tools")
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

}
