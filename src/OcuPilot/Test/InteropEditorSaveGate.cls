/// <p>Pins Story 20.16's pair refusals against real principals (AD-8, AD-29, AD-64, AC8): an editor tool is refused by name before
/// any mint, with no proposal row added, to a principal missing <code>%Development:USE</code> (the port's pair), missing
/// <code>%Ens_Code:WRITE</code> (the vendor editors' write resource, for a save), missing <code>%Ens_Code:READ</code> (the editor
/// screen's own pair, so the refusal names the screen), or missing WRITE on the routines database (the save's argument pair); and a
/// principal holding exactly the set is minted a proposal by the save and read the text by the read.</p>
/// <p>Each call runs in a child process (<method>Probe</method>) that logs in as the principal and sends one <code>tool_use</code>
/// through the agent's dispatcher inside a completed turn seeded for that principal, so this process never changes identity. The
/// principals are created by <method>OcuPilot.Test.InteropTestGate.CreatePrincipals</method>.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates five users and roles named
/// <code>OcuP2016*</code>, and makes and removes the <code>OcuProbe2016</code> probe package. Each principal also holds READ on the
/// install namespace's code database. The principals, the probe and the proposals are removed after the last test.</p>
Class OcuPilot.Test.InteropEditorSaveGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SHARED = "OcuPilot.Test.InteropTestGate";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

Parameter NAMESPACE = "USER";

Parameter SAVE = "interop.transformeditor.save";

Parameter READ = "interop.transformeditor.source";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP2016Exact:%Development:U,%Ens_Portal:U,%Ens_Code:RW,%DB_USER:RW;OcuP2016NoDev:%Ens_Portal:U,%Ens_Code:RW,%DB_USER:RW;OcuP2016NoCodeWrite:%Development:U,%Ens_Portal:U,%Ens_Code:R,%DB_USER:RW;OcuP2016NoCodeRead:%Development:U,%Ens_Portal:U,%Ens_Code:W,%DB_USER:RW;OcuP2016NoDbWrite:%Development:U,%Ens_Portal:U,%Ens_Code:RW,%DB_USER:R";

/// <p>What each principal's save and read are answered, <code>&lt;user&gt;=&lt;the pair the save names&gt;/&lt;the pair the read names&gt;</code>, an empty
/// side meaning the call is admitted, separated by <code>;</code>. The principal without <code>%Ens_Code:WRITE</code> reads, and the
/// one without WRITE on the database reads: neither pair is the read's.</p>
Parameter EXPECTED = "OcuP2016Exact=/;OcuP2016NoDev=%Development:USE/%Development:USE;OcuP2016NoCodeWrite=%Ens_Code:WRITE/;OcuP2016NoCodeRead=%Ens_Code:READ/%Ens_Code:READ;OcuP2016NoDbWrite=%DB_USER:WRITE/";

/// <p>Which of the refusals name the editor screen, because the pair they name is one of the screen's own (AD-8, Story 20.18).</p>
Parameter SCREENNAMED = "OcuP2016NoCodeRead";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropEditorSaveGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring up a throwaway container with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2016Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Make", "transform", ..#PACKAGE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#SHARED, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.InteropEditorSaveGate")
    If $$$ISOK(tSC) Set tSC = ..ReadBack()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropEditorSaveGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.InteropEditorProbe", "ForgetLedger"), "the ledger rows of the probe turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Read the decisive grants of the principals back, a failing status naming the first that is not as declared.</p>
ClassMethod ReadBack() As %Status
{
    Set tSC = $$$OK
    For tCase = $ListBuild("OcuP2016Exact", "%Ens_Code", "WRITE", 1), $ListBuild("OcuP2016Exact", "%Ens_Code", "READ", 1), $ListBuild("OcuP2016Exact", "%DB_USER", "WRITE", 1), $ListBuild("OcuP2016NoDev", "%Development", "USE", 0), $ListBuild("OcuP2016NoCodeWrite", "%Ens_Code", "READ", 1), $ListBuild("OcuP2016NoCodeWrite", "%Ens_Code", "WRITE", 0), $ListBuild("OcuP2016NoCodeRead", "%Ens_Code", "WRITE", 1), $ListBuild("OcuP2016NoCodeRead", "%Ens_Code", "READ", 0), $ListBuild("OcuP2016NoDbWrite", "%DB_USER", "READ", 1), $ListBuild("OcuP2016NoDbWrite", "%DB_USER", "WRITE", 0) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
            Quit
        }
    }
    Quit tSC
}

/// <p>The expected failed pair of <var>pUser</var>'s save when <var>pSide</var> is 1, or its read when 2.</p>
ClassMethod ExpectedFor(pUser As %String, pSide As %Integer) As %String
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Quit $Piece($Piece(tEntry, "=", 2), "/", pSide)
}

/// <p>The input of the call to <var>pTool</var>: the probe transformation's one edit for the save, its name for the read.</p>
ClassMethod InputFor(pTool As %String) As %String
{
    Set tName = $ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE) _ ".cls"
    If pTool = ..#READ Quit {"name": (tName)}.%ToJSON()
    Quit {"Names": (tName), "Edits": [{"Old": ($Parameter(..#PROBE, "DTLASSIGN")), "New": ($Parameter(..#PROBE, "DTLASSIGN") _ " ")}]}.%ToJSON()
}

/// <p>AC8: each principal's save and read are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with
/// <code>AUTH.NOPRIVILEGE</code> and the pair as <code>detail.failedPair</code>, the editor screen named exactly where the pair is
/// one of the screen's own; a refused save adds no proposal row, and the principal holding exactly the set is minted a proposal and
/// read the class text.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropEditorSave.PrivilegePairs</method> drops <code>%Development:USE</code> --
/// the principal's save reaches the port and is refused there, not by name at the dispatcher, so the dispatcher-made leg goes red;
/// drops <code>%Ens_Code:WRITE</code> -- the vendor-write principal's save is minted and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameBeforeAnyMint()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        For tSide = 1, 2 {
            Set tTool = $Select(tSide = 1: ..#SAVE, 1: ..#READ)
            Set tWanted = ..ExpectedFor(tUser, tSide)
            Set tRows = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(tTool)
            Set tProbe = ..ProbeAs(tUser, tTool)
            Set tLabel = tUser _ " " _ tTool
            Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tLabel _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
            Set tContent = ##class(%DynamicAbstractObject).%FromJSON($Select(tProbe.%Get("content") = "": "{}", 1: tProbe.%Get("content")))
            If tWanted = "" {
                Do $$$AssertTrue('tProbe.%Get("isError"), tLabel _ ": admitted: " _ $Extract(tProbe.%Get("content"), 1, 240))
                Do $$$AssertTrue(tContent.%Get("proposalId") _ tContent.%Get("text") '= "", tLabel _ ": and answers a proposal or the text")
                Continue
            }
            Do $$$AssertTrue(tProbe.%Get("isError"), tLabel _ ": refused: " _ $Extract(tProbe.%Get("content"), 1, 240))
            Set tDetail = tContent.%Get("detail")
            Do $$$AssertEquals(tContent.%Get("code") _ "|" _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: ""), "AUTH.NOPRIVILEGE|" _ tWanted, tLabel _ ": refused naming " _ tWanted)
            Do $$$AssertEquals(tProbe.%Get("failedPair"), tWanted, tLabel _ ": and the dispatcher made the refusal, naming the pair itself, not the port inside the mint")
            Set tScreen = $Select($IsObject(tDetail): tDetail.%Get("screen"), 1: "")
            If $Find(..#SCREENNAMED, tUser) {
                Do $$$AssertTrue((tScreen '= "") && (tProbe.%Get("failedScreen") = tScreen), tLabel _ ": and names the editor screen")
            } Else {
                Do $$$AssertEquals(tScreen _ "|" _ tProbe.%Get("failedScreen"), "|", tLabel _ ": and names no screen, the pair being the tool's own")
            }
            Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(tTool), tRows, tLabel _ ": and adds no proposal")
        }
    }
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process, calling <var>pTool</var>, and answer what it signalled, or an
/// object carrying <code>error</code>. The turn the call runs in is seeded for <var>pUser</var> here.</p>
ClassMethod ProbeAs(pUser As %String, pTool As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", "the probe turn could not be seeded")
            Quit
        }
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropEditorSaveGate).Probe($Job, pUser, ..#NAMESPACE, pTool, tTurn, ..InputFor(pTool))::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, scope the request to <var>pNamespace</var>
/// and send <var>pTool</var> with the JSON input <var>pInput</var> through the agent's dispatcher inside turn <var>pTurn</var>, and
/// signal <code>{loggedIn, username, isError, content}</code> to process <var>pParent</var>, or <code>{error}</code> when
/// something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pTool As %String, pTurn As %String, pInput As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tUse = {"type": "tool_use", "id": "toolu_gate"}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
        Do tUse.%Set("input", ##class(%DynamicObject).%FromJSON(pInput))
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", "the dispatch failed: " _ $System.Status.GetErrorText(tSC))
        } Else {
            Do tOut.%Set("isError", ''tResults.%Get(0).%Get("is_error"), "boolean")
            Do tOut.%Set("content", tResults.%Get(0).%Get("content"))
            Do tOut.%Set("failedPair", tDetails.%Get(0).%Get("failedPair"), "string")
            Do tOut.%Set("failedScreen", tDetails.%Get(0).%Get("failedScreen"), "string")
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
