/// <p>What pins <class>OcuPilot.Kernel.Proposal.Mint</class>'s one readable-id pass over every shipped
/// mint that builds a composite target id (AD-13). Each is driven, through
/// <class>OcuPilot.Test.CompositeMintProbe</class>'s port, to a refusal that names the id, and the
/// <code>detail.problem</code> it answers joins the id's parts with a breadcrumb, <code>$Char(8250)</code>,
/// with no composite separator, <code>$Char(1)</code>, anywhere in the fault.</p>
/// <p>Five tests. Three drive the roster, once for each way a mint's read ends in a refusal naming the id: the
/// target absent, a create of a target already there, and the port's own refusal. One derives the composite-id
/// mints from the compiled classes -- those whose own <code>Mint</code>, or an ancestor's, names the composite id's
/// builder -- and requires the roster to name exactly them, so such a mint added later with no row here fails. One
/// reads every shipped mint's own <code>Mint</code>: it reaches the superclass through <code>##super</code>, and
/// none replaces the pass.</p>
/// <p>It needs nothing from the environment, creates nothing and writes nothing: the probe's port answers
/// before any instance state is read, and no mint here reaches the proposal store.</p>
Class OcuPilot.Test.CompositeMintSweep Extends %UnitTest.TestCase
{

/// <p>The tool class and the port every mint is handed.</p>
Parameter PROBE = "OcuPilot.Test.CompositeMintProbe";

/// <p>The class every mint extends and the one that holds the pass.</p>
Parameter BASE = "OcuPilot.Kernel.Proposal.Mint";

/// <p>Any descriptor: the mint reads its secret declaration and builds the target reference from it.</p>
Parameter SCREEN = "OcuPilot.Screen.Descriptor.BackgroundTaskList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter TOOLNAME = "probe.composite.mint";

/// <p>The source tokens that mark a mint's own <code>Mint</code> as one that builds a composite id.</p>
Parameter COMPOSITETOKENS = "JoinComposite,COMPOSITESEPARATOR";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

/// <p>One row per shipped composite-id mint: the mint class, the arguments the agent sends, the id value
/// the tool hands the mint, and the parts the mint joins into the id, in order.</p>
ClassMethod Roster() As %DynamicArray
{
    Set tRoster = []
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.MappingMint", "args": {"Namespace": "USER", "Name": "ProbeMapping"}, "idValue": "ProbeMapping", "parts": ["USER", "ProbeMapping"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.DocDbAppMint", "args": {"Namespace": "USER", "Name": "ProbeRecord"}, "idValue": "ProbeRecord", "parts": ["USER", "ProbeRecord"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.InteropItemMint", "args": {"Production": "Probe.Production", "Name": "ProbeItem"}, "idValue": "ProbeItem", "parts": ["Probe.Production", "ProbeItem"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.InteropLookupEntryMint", "args": {"Table": "ProbeTable", "Key": "ProbeKey"}, "idValue": "ProbeKey", "parts": ["ProbeTable", "ProbeKey"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.InteropSettingMint", "args": {"Production": "Probe.Production", "Item": "ProbeItem", "Target": "Host", "Name": "ProbeSetting"}, "idValue": "ProbeSetting", "parts": ["Probe.Production", "ProbeItem", "Host", "ProbeSetting"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.SuperserverMint", "args": {"Port": "51999", "BindAddress": "127.0.0.1"}, "idValue": "51999", "parts": ["51999", "127.0.0.1"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.ErrorDeleteMint", "args": {"namespace": "USER", "date": "2026-10-01", "errorNumber": "3"}, "idValue": "USER", "parts": ["USER", "2026-10-01", "3"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.WebAppPctAccessMint", "args": {"Name": "/csp/probe", "AllowType": "Allow", "Class": "%ProbeClass"}, "idValue": "/csp/probe", "parts": ["/csp/probe", "Allow", "%ProbeClass"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.BackgroundTaskMint", "args": {"source": "Management Portal", "id": "999999999"}, "idValue": "999999999", "parts": ["Management Portal", "999999999"]})
    Do tRoster.%Push({"mint": "OcuPilot.Screen.Tool.EncryptionKeyFileMint", "args": {"root": "/probe/root", "path": "probe.key"}, "idValue": "probe.key", "parts": ["/probe/root", "probe.key"]})
    Quit tRoster
}

/// <p>Each rostered mint, handed an id whose target the probe's port reports absent, refuses 400
/// <code>TOOL.ARGUMENTS</code> with the problem <code>'&lt;part&gt; &#8250; &lt;part&gt;...' is not present on this
/// instance</code>, after exactly one read, and nothing in its fault holds <code>$Char(1)</code>.</p>
/// <p>Mutations (Rule 19): remove the readable-id pass from <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>
/// -- every row goes red; make one mint put the separator back after its <code>##super</code> returns -- that
/// mint's row alone goes red.</p>
Method TestEveryCompositeMintNamesAnAbsentTargetReadably()
{
    Do ..Drive(##class(OcuPilot.Test.CompositeMintProbe).#ABSENT, 400, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "'{id}' is not present on this instance")
}

/// <p>The same roster, for a tool that creates a target the port reports present: the refusal is 400
/// <code>TOOL.ARGUMENTS</code> with <code>'&lt;part&gt; &#8250; &lt;part&gt;...' is already present on this
/// instance</code>.</p>
/// <p>Mutation (Rule 19): move the pass out of <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>'s exit into its
/// absence branch alone -- every row of this test goes red.</p>
Method TestEveryCompositeMintNamesAnAlreadyPresentTargetReadably()
{
    Do ..Drive(##class(OcuPilot.Test.CompositeMintProbe).#PRESENT, 400, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "'{id}' is already present on this instance")
}

/// <p>The same roster, for a port that refuses the read itself and names the id in its refusal: the port's own
/// status and code stand, and its problem reads the id with the breadcrumb. The pass is at the mint's exit, not in
/// the mint's own refusal, so it covers this answer too.</p>
/// <p>Mutation (Rule 19): move the pass out of <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>'s exit into
/// <method>OcuPilot.Kernel.Proposal.Mint.Refuse</method> -- every row of this test goes red.</p>
Method TestEveryCompositeMintNamesAPortRefusalsTargetReadably()
{
    Do ..Drive(##class(OcuPilot.Test.CompositeMintProbe).#REFUSED, 409, ##class(OcuPilot.Api.Error).#PORTCONFLICT, "the probe port refused '{id}'")
}

/// <p>Drive every row of <method>Roster</method> with the probe in <var>pMode</var>, and assert the HTTP status
/// <var>pHttp</var>, the fault code <var>pCode</var> and the problem <var>pSentence</var>, whose
/// <code>{id}</code> is the row's parts joined by the breadcrumb.</p>
Method Drive(pMode As %String, pHttp As %Integer, pCode As %String, pSentence As %String)
{
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    Set tBreadcrumb = " " _ $Char(8250) _ " "
    Set tRoster = ..Roster()
    Do $$$AssertTrue(tRoster.%Size() > 0, "the roster names mints")
    Set tIterator = tRoster.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tMint = tRow.%Get("mint")
        Do $ClassMethod(..#PROBE, "Reset")
        Do $ClassMethod(..#PROBE, "SetMode", pMode)
        Kill tProposal, tHttp, tFault
        Set tSC = $ClassMethod(tMint, "Mint", ..#SCREEN, ..#TOOLNAME, $Username, "", "", tRow.%Get("args"), ..#LIMITS, .tProposal, .tHttp, .tFault, "Probe.Endpoint", "id", tRow.%Get("idValue"), "id", "", ..#PROBE)
        Do $$$AssertStatusNotOK(tSC, tMint _ " does not mint (" _ pMode _ ")")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Calls"), 1, tMint _ " reached the target through the probe's port exactly once")
        Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "")
        Do $$$AssertEquals($Get(tHttp) _ " " _ tCode, pHttp _ " " _ pCode, tMint _ " answers the " _ pMode _ " status and code")
        Set tParts = ""
        Set tPartIterator = tRow.%Get("parts").%GetIterator()
        While tPartIterator.%GetNext(.tPartIndex, .tPart) {
            Set tParts = tParts _ $Select(tParts = "": "", 1: tBreadcrumb) _ tPart
        }
        Do $$$AssertEquals(tProblem, $Replace(pSentence, "{id}", tParts), tMint _ " names the target by its parts and the breadcrumb: " _ tProblem)
        Do $$$AssertTrue(tProblem '[ tSeparator, tMint _ "'s problem holds no U+0001")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() '[ "\u0001"), tMint _ "'s whole fault holds no U+0001")
    }
    Do $ClassMethod(..#PROBE, "Reset")
}

/// <p>The roster is every composite-id mint the compiled tree holds: the shipped classes that extend
/// <parameter>BASE</parameter> and whose own <code>Mint</code>, or an ancestor's, names the composite id's
/// builder. Both directions are asserted, so a mint with no row and a row that names no mint each fail.</p>
/// <p>Mutation (Rule 19): add a shipped class that extends a composite-id mint and has no row here -- this
/// goes red naming it.</p>
Method TestTheRosterIsEveryCompositeIdMint()
{
    Set tListed = ""
    Set tRoster = ..Roster()
    Set tIterator = tRoster.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tRow.%Get("mint")
    }
    Set tShipped = ..ShippedMints()
    Do $$$AssertTrue($Length(tShipped, ",") > 20, "control: the scan finds the shipped mints (" _ $Length(tShipped, ",") _ ")")
    Do $$$AssertTrue(("," _ tShipped _ ",") [ ",OcuPilot.Screen.Tool.JournalMint,", "control: and finds one whose id is a single value")
    Set tAncestors = ""
    For tI = 1:1:$Length(tShipped, ",") {
        Set tClass = $Piece(tShipped, ",", tI)
        If ..OwnMintNamesTheId(tClass) Set tAncestors = tAncestors _ $Select(tAncestors = "": "", 1: ",") _ tClass
    }
    Set tComposite = ""
    For tI = 1:1:$Length(tShipped, ",") {
        Set tClass = $Piece(tShipped, ",", tI)
        For tJ = 1:1:$Length(tAncestors, ",") {
            If $ClassMethod(tClass, "%IsA", $Piece(tAncestors, ",", tJ)) {
                Set tComposite = tComposite _ $Select(tComposite = "": "", 1: ",") _ tClass
                Quit
            }
        }
    }
    Set tDerived = $ListFromString(tComposite, ",")
    Do $$$AssertTrue($ListFind(tDerived, "OcuPilot.Screen.Tool.SuperserverMint"), "control: the derivation finds a mint that joins its own parts: " _ tComposite)
    Do $$$AssertTrue($ListFind(tDerived, "OcuPilot.Screen.Tool.InteropSettingMint"), "control: and one that inherits the join")
    Do $$$AssertTrue('$ListFind(tDerived, "OcuPilot.Screen.Tool.JournalMint"), "control: and leaves out the one whose id is a single value")
    Set tRostered = $ListFromString(tListed, ",")
    Set tMissing = ""
    For tI = 1:1:$ListLength(tDerived) {
        If '$ListFind(tRostered, $List(tDerived, tI)) Set tMissing = tMissing _ " " _ $List(tDerived, tI)
    }
    Do $$$AssertEquals(tMissing, "", "every composite-id mint has a row:" _ tMissing)
    Set tExtra = ""
    For tI = 1:1:$ListLength(tRostered) {
        If '$ListFind(tDerived, $List(tRostered, tI)) Set tExtra = tExtra _ " " _ $List(tRostered, tI)
    }
    Do $$$AssertEquals(tExtra, "", "and every row names a composite-id mint:" _ tExtra)
}

/// <p>No shipped mint replaces the pass: a <code>Mint</code> a class declares itself calls
/// <code>##super(</code>, so what the superclass answers it leaves through the superclass's exit, and none
/// declares its own <code>ReadableId</code>. A refusal a subclass makes before that call is not read here.</p>
/// <p>Mutation (Rule 19): add a shipped class that extends <parameter>BASE</parameter>, declares its own
/// <code>Mint</code> and does not call <code>##super</code> -- this goes red naming it.</p>
Method TestNoShippedMintBypassesTheBasePass()
{
    Set tShipped = ..ShippedMints()
    Set tBypass = ""
    Set tChecked = 0
    For tI = 1:1:$Length(tShipped, ",") {
        Set tClass = $Piece(tShipped, ",", tI)
        Set tSource = ..OwnMintSource(tClass)
        If tSource '= "" {
            Set tChecked = tChecked + 1
            If tSource '[ "##super(" Set tBypass = tBypass _ " " _ tClass
        }
        Set tReadable = ##class(%Dictionary.CompiledMethod).%OpenId(tClass _ "||ReadableId")
        If '$IsObject(tReadable) || (tReadable.Origin '= ..#BASE) Set tBypass = tBypass _ " " _ tClass _ "(ReadableId)"
    }
    Do $$$AssertTrue(tChecked > 20, "control: the scan reads the mints' own Mint methods (" _ tChecked _ ")")
    Do $$$AssertEquals(tBypass, "", "every declared Mint reaches the superclass and none replaces ReadableId:" _ tBypass)
}

/// <p>The shipped classes (outside <package>OcuPilot.Test</package>) that extend <parameter>BASE</parameter>
/// at any depth, comma-separated in name order, not counting <parameter>BASE</parameter> itself. Read from
/// the compiled classes' own <code>Super</code> lists, so a class with no superclass of its own is never asked a
/// question it cannot answer.</p>
ClassMethod ShippedMints() As %String
{
    Kill tSupers, tIn
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, Super FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.' AND NOT (Name %STARTSWITH 'OcuPilot.Test')")
    If tRS.%SQLCODE < 0 Quit ""
    While tRS.%Next() {
        Set tSupers(tRS.%GetData(1)) = $ListFromString(tRS.%GetData(2), ",")
    }
    Do tRS.%Close()
    Set tIn(..#BASE) = 1
    Set tGrew = 1
    While tGrew {
        Set tGrew = 0
        Set tName = ""
        For {
            Set tName = $Order(tSupers(tName))
            If tName = "" Quit
            If $Data(tIn(tName)) Continue
            For tI = 1:1:$ListLength(tSupers(tName)) {
                If $Data(tIn($List(tSupers(tName), tI))) {
                    Set tIn(tName) = 1
                    Set tGrew = 1
                    Quit
                }
            }
        }
    }
    Kill tIn(..#BASE)
    Set tFound = ""
    Set tName = ""
    For {
        Set tName = $Order(tIn(tName))
        If tName = "" Quit
        Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName
    }
    Quit tFound
}

/// <p>The source of the <code>Mint</code> method <var>pClass</var> declares itself, or <code>""</code> when it
/// declares none.</p>
ClassMethod OwnMintSource(pClass As %String) As %String
{
    Set tSource = ""
    Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(pClass _ "||Mint")
    If '$IsObject(tMethod) Quit ""
    Do tMethod.Implementation.Rewind()
    While 'tMethod.Implementation.AtEnd {
        Set tSource = tSource _ tMethod.Implementation.Read(32000)
    }
    Quit tSource
}

/// <p>Whether <var>pClass</var> declares its own <code>Mint</code> and that method names one of
/// <parameter>COMPOSITETOKENS</parameter>.</p>
ClassMethod OwnMintNamesTheId(pClass As %String) As %Boolean
{
    Set tSource = ..OwnMintSource(pClass)
    Set tNames = 0
    For tI = 1:1:$Length(..#COMPOSITETOKENS, ",") {
        If (tSource '= "") && (tSource [ $Piece(..#COMPOSITETOKENS, ",", tI)) Set tNames = 1
    }
    Quit tNames
}

}
