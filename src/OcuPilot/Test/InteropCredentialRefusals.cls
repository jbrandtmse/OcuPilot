/// <p>Pins Story 24.15's credential refusals end to end against probe credentials in <code>USER</code> (AD-6, AD-8, AD-35, AD-39, AD-54, AD-62): each
/// refusal row of the plan's matrix is refused by its own code with its published sentence, from the person's Save, the agent's mint and the port, and
/// nothing is written -- a name the namespace holds in any letter case, a credential that is not there, a name the vendor cannot store, a business
/// partner the namespace does not hold and a user name the rules refuse. The gate runs as real principals in a child process: a caller without
/// <code>%Ens_Credentials:WRITE</code>, one without the read pair and one who cannot write the database. <b>No refusal carries a password.</b></p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named <code>OcuP2415C*</code>. It
/// removes every credential, password node, principal and role it creates.</p>
Class OcuPilot.Test.InteropCredentialRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropCredentialControl";

Parameter GENERATOR = "OcuPilot.Test.InteropLookupGate";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter NAME = "OcuProbe2415A";

/// <p>The password every refused write carries, so a leak into a refusal is a substring test.</p>
Parameter PASSWORD = "OcuPwRefusal2415x";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>.</p>
Parameter PRINCIPALS = "OcuP2415CExact:%Development:U,%Ens_Portal:U,%Ens_Credentials:RW,%DB_USER:RW;OcuP2415CNoWrite:%Development:U,%Ens_Portal:U,%Ens_Credentials:R,%DB_USER:RW;OcuP2415CNoRead:%Development:U,%Ens_Portal:U,%DB_USER:RW;OcuP2415CNoUser:%Development:U,%Ens_Portal:U,%Ens_Credentials:RW";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;type&gt;|&lt;credential&gt;</code>. The held credential is the one the set, the password and the remove
/// name.</p>
Parameter LEGS = "list|LIST|,add|ADDCREDENTIAL|OcuProbe2415G,set|SETCREDENTIAL|OcuProbe2415H,password|PASSWORDCREDENTIAL|OcuProbe2415H,remove|REMOVECREDENTIAL|OcuProbe2415H";

Property PreparedPassword As %String;

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropCredentialRefusals creates and deletes users and roles and writes probe credentials on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2415Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe credentials are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415") + $ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415", "HSCUSTOM"), 0, "and none survives, with its password node, in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The code of <var>pFault</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    Quit $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port's call of the type <var>pType</var> on <var>pName</var> in <var>pNamespace</var> as <code>status code</code>, the envelope in
/// <var>pFault</var> and the answer in <var>pRow</var>.</p>
ClassMethod Verdict(pType As %String, pName As %String, pBody As %DynamicObject = "", Output pFault, Output pRow, pNamespace As %String = "USER") As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Credentials", pType, .tQuery, pBody, .pRow, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ ..CodeOf(.pFault)
}

/// <p>The agent's mint of <var>pTool</var> for the credential <var>pName</var> with <var>pSet</var> beside it: the code of its refusal,
/// <code>minted</code> when it was not refused; the sentence in <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pName As %String, pSet As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, $ClassMethod(..#CONTROL, "ArgsFor", pName, pSet), .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>AC2: an add of a name the namespace holds, exactly or in another letter case, is <code>INTEROP.CREDENTIAL.TAKEN</code> from the person's Save,
/// the agent's mint and the port, and an edit, a password set or a remove of a name it does not hold exactly is 404; the held credential is untouched
/// and no refusal carries the password.</p>
/// <p>Mutation (Rule 19): make the add's case-folded taken test in <method>OcuPilot.Port.InteropPort.CredentialWriteToken</method> compare exactly
/// -- the other-case legs go red.</p>
Method TestAHeldNameIsTakenInAnyCaseAndAMissingOneIsNotFound()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#NAME, "held", "", "OcuPwHeld2415"), "the probe credential is held")
    For tName = ..#NAME, $ZConvert(..#NAME, "L") {
        Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/credentials", $ClassMethod(..#CONTROL, "SaveBody", tName, "x", "", ..#PASSWORD), .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "409 INTEROP.CREDENTIAL.TAKEN " _ ..Reason("CREDENTIALTAKEN"), "the Save of '" _ tName _ "' is refused with the published sentence")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ ..#PASSWORD), "which carries no password")
        Do $$$AssertEquals(..MintVerdict("InteropCredentialAdd", tName, {"Username": "x"}, .tReason), "INTEROP.CREDENTIAL.TAKEN", "the agent's add of '" _ tName _ "' is refused at the mint")
        Do $$$AssertEquals(tReason, ..Reason("CREDENTIALTAKEN"), "with the published sentence")
        Do $$$AssertEquals(..Verdict("ADDCREDENTIAL", tName, {"Username": "x", "Password": (..#PASSWORD)}, .tFault), "409 INTEROP.CREDENTIAL.TAKEN", "the port refuses the add of '" _ tName _ "'")
        Do $$$AssertTrue(tFault.%ToJSON() '[ ..#PASSWORD, "without the password in the envelope")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialText", ..#NAME), "held||1", "the held credential and its password are untouched")
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialCount", "OcuProbe2415"), 2, "and nothing else was written")
    Set tMissing = "OcuProbe2415Missing"
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", tMissing, {"Username": "x"}), "404 PORT.NOTFOUND", "a set of a name that is not held is 404")
    Do $$$AssertEquals(..Verdict("PASSWORDCREDENTIAL", tMissing, {"Password": (..#PASSWORD)}, .tFault), "404 PORT.NOTFOUND", "so is a password set")
    Do $$$AssertEquals(..Verdict("REMOVECREDENTIAL", tMissing), "404 PORT.NOTFOUND", "and a remove")
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", $ZConvert(..#NAME, "L"), {"Username": "x"}), "404 PORT.NOTFOUND", "a set by the name in another letter case is 404, since the vendor opens a name exactly")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "remove", tMissing, "", .tAnswer), "404 PORT.NOTFOUND", "the person's Remove of a missing name is 404 too")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "password", tMissing, {"Password": (..#PASSWORD)}, .tAnswer), "404 PORT.NOTFOUND", "and so is the person's Set password")
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialCount", "OcuProbe2415"), 2, "and nothing was written")
}

/// <p>AC2: a name that is empty, over fifty characters or holds a control character is <code>INTEROP.CREDENTIAL.NAME</code> (422) from the Save, the
/// mint and the port, with the published sentence, and nothing is written; a user name over the vendor's limit is
/// <code>INTEROP.CREDENTIAL.VALUE</code>.</p>
/// <p>Mutation (Rule 19): drop the control character test from <method>OcuPilot.Port.InteropPort.CredentialNameOK</method> -- the control character
/// row goes red.</p>
Method TestANameTheVendorCannotStoreIsRefusedBeforeAnythingIsStored()
{
    Set tLong = ..#NAME _ $Translate($Justify("", 38), " ", "z")
    Do $$$AssertEquals($Length(tLong), 51, "the long name is one past the limit")
    For tCase = $ListBuild("long", tLong), $ListBuild("control", ..#NAME _ $Char(9) _ "x"), $ListBuild("bell", ..#NAME _ $Char(7)) {
        Set tName = $List(tCase, 2)
        Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/credentials", $ClassMethod(..#CONTROL, "SaveBody", tName, "x", "", ..#PASSWORD), .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "422 INTEROP.CREDENTIAL.NAME", $List(tCase, 1) _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("CREDENTIALNAME")), $List(tCase, 1) _ ": with the published sentence")
        Do $$$AssertEquals(..Verdict("ADDCREDENTIAL", tName, {"Username": "x", "Password": (..#PASSWORD)}, .tFault), "422 INTEROP.CREDENTIAL.NAME", $List(tCase, 1) _ ": the port refuses the add")
        Do $$$AssertTrue(tFault.%ToJSON() '[ ..#PASSWORD, $List(tCase, 1) _ ": without the password in the envelope")
        Do $$$AssertEquals(..MintVerdict("InteropCredentialAdd", tName, {"Username": "x"}, .tReason), "TOOL.ARGUMENTS", $List(tCase, 1) _ ": the agent's add is refused at the mint")
        Do $$$AssertTrue(tReason [ ..Reason("CREDENTIALNAME"), $List(tCase, 1) _ ": naming the published sentence: " _ tReason)
    }
    Do $$$AssertEquals(..Verdict("REMOVECREDENTIAL", tLong), "404 PORT.NOTFOUND", "a remove of a name the vendor cannot store finds none")
    Do $$$AssertEquals(..Verdict("ADDCREDENTIAL", ..#NAME, {"Username": ($Justify("", 3640874))}), "422 INTEROP.CREDENTIAL.VALUE", "a user name over the vendor's limit is a value the instance does not accept")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415"), 0, "and nothing was written")
}

/// <p>AC2: a business partner that is not empty and not one of the namespace's is <code>INTEROP.CREDENTIAL.PARTNER</code> (422) from the Save, the
/// mint and the port, on an add and on an edit, and an empty partner and a held one are accepted; nothing is written. An edit of the user name of a
/// credential whose partner the namespace does not hold proceeds and keeps the partner, from the port and the person's Edit.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.CredentialPartnerHeld</method> answer 1 -- the unknown-partner legs go red. Make
/// <method>OcuPilot.Port.InteropPort.CredentialMoves</method> answer the body whole -- the kept-partner legs go red.</p>
Method TestAPartnerTheNamespaceDoesNotHoldIsRefused()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner"), "a probe partner is arranged")
    Set tHeld = $Parameter(tFixture, "PARTNER")
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/credentials", $ClassMethod(..#CONTROL, "SaveBody", ..#NAME, "x", "NoSuchPartner2415", ..#PASSWORD), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "422 INTEROP.CREDENTIAL.PARTNER", "the Save of an unknown partner is refused")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("CREDENTIALPARTNER")) && (tAnswer.%ToJSON() '[ ..#PASSWORD), "with the published sentence and no password")
    Do $$$AssertEquals(..Verdict("ADDCREDENTIAL", ..#NAME, {"Username": "x", "BusinessPartner": "NoSuchPartner2415"}), "422 INTEROP.CREDENTIAL.PARTNER", "the port refuses the add")
    Do $$$AssertEquals(..MintVerdict("InteropCredentialAdd", ..#NAME, {"BusinessPartner": "NoSuchPartner2415"}, .tReason), "TOOL.ARGUMENTS", "the agent's add is refused at the mint")
    Do $$$AssertTrue(tReason [ ..Reason("CREDENTIALPARTNER"), "naming the published sentence: " _ tReason)
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialCount", "OcuProbe2415"), 0, "and nothing was written")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#NAME, "held"), "a credential is arranged")
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", ..#NAME, {"BusinessPartner": "NoSuchPartner2415"}), "422 INTEROP.CREDENTIAL.PARTNER", "the port refuses an edit to an unknown partner")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", ..#NAME, {"BusinessPartner": "NoSuchPartner2415"}, .tAnswer), "422 INTEROP.CREDENTIAL.PARTNER", "so does the person's Edit")
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialText", ..#NAME), "held||0", "and the credential is as it was")
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", ..#NAME, {"BusinessPartner": (tHeld)}), "200 ", "a held partner is accepted")
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", ..#NAME, {"BusinessPartner": ""}), "200 ", "and so is an empty one")
    ; A partner the credential already holds is not judged again, so an edit of its user name alone proceeds.
    Set tStale = ..#NAME _ "S"
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", tStale, "held", "NoSuchPartner2415"), "a credential naming a partner the namespace does not hold is arranged")
    Do $$$AssertEquals(..Verdict("SETCREDENTIAL", tStale, {"Username": "moved", "BusinessPartner": "NoSuchPartner2415"}), "200 ", "the port edits its user name beside the partner it holds")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", tStale, {"Username": "again"}, .tAnswer), "200 ", "and so does the person's Edit")
    Do $$$AssertEquals($ClassMethod(tFixture, "CredentialText", tStale), "again|NoSuchPartner2415|0", "and the partner is kept")
}

/// <p>AC2: the gate, as real principals in a child process, refuses before any vendor call and writes nothing: a caller without
/// <code>%Ens_Credentials:WRITE</code> is refused 403 naming that pair on each write and reads the list; one without the read pair is refused every
/// leg naming it; one who cannot write the database is refused each write naming it and one who cannot read it the list.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.CREDENTIALWRITEPAIR</parameter> from the write pairs -- the
/// <code>OcuP2415CNoWrite</code> caller's write legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "the credential gate")
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tOk = "200||"
    Set tWrite = "403|" _ tDeny _ "|%Ens_Credentials:WRITE"
    Set tRead = "403|" _ tDeny _ "|%Ens_Credentials:READ"
    Set tUserWrite = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tUserRead = "403|" _ tDeny _ "|%DB_USER:READ"
    Set tExpected("OcuP2415CExact") = $ListBuild(tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2415CNoWrite") = $ListBuild(tOk, tWrite, tWrite, tWrite, tWrite)
    Set tExpected("OcuP2415CNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuP2415CNoUser") = $ListBuild(tUserRead, tUserWrite, tUserWrite, tUserWrite, tUserWrite)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), tUser _ ": the probe credentials are cleared")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", "OcuProbe2415H", "held", "", "OcuPwHeld2415"), tUser _ ": the held credential is arranged")
        Set tOut = ..ProbeAs(tUser)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tHeldGone = 0
        Set tAdded = 0
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If (tLegName = "add") && (tGot = tOk) Set tAdded = 1
            If (tLegName = "remove") && (tGot = tOk) Set tHeldGone = 1
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", "OcuProbe2415G") _ "|" _ $ClassMethod(..#FIXTURE, "PasswordNode", "OcuProbe2415G"), $Select(tAdded: "added||1|1", 1: "<absent>|0"), tUser _ ": only an admitted add was stored")
        If 'tHeldGone Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", "OcuProbe2415H"), $Select(tOut.%Get("set").http = 200: "set", 1: "held") _ "||1", tUser _ ": a refused remove left the held credential, its password node included")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "PasswordNode", "OcuProbe2415H"), 'tHeldGone, tUser _ ": and its password node follows it")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropCredentialRefusals).Probe($Job, pUser)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter> through
/// <class>OcuPilot.Port.InteropPort</class>, and signal <code>{loggedIn, username, "&lt;leg&gt;": {http, code, failedPair}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tSpec = $Piece(..#LEGS, ",", tI)
            Set tName = $Piece(tSpec, "|", 1)
            Set tType = $Piece(tSpec, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = "USER"
            Set tBody = ""
            If tType '= "LIST" {
                Set tQuery("id") = $Piece(tSpec, "|", 3)
                Set tBody = $Case(tType, "ADDCREDENTIAL": {"Username": "added", "Password": "OcuPwProbe2415"}, "SETCREDENTIAL": {"Username": "set"}, "PASSWORDCREDENTIAL": {"Password": "OcuPwProbe2415"}, : "")
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Credentials", tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tName, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
