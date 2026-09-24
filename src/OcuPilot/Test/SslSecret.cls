/// <p>Pins Story 9.5's private key password (AC2, AD-3, AD-6, AD-35, AD-41): on a probe server
/// configuration whose key file is encrypted under a password made for this run, the screen's Save
/// stores the right password and refuses a wrong one on its field; an empty optional password on
/// either caller leaves the stored one set; and no form read, proposal, diff,
/// answer, ledger row, <code>messages.log</code> line or audit row holds the password, whether it was
/// entered in the form or on the agent's confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the image's OpenSSL
/// through <code>$ZF(-100)</code> (<class>OcuPilot.Test.X509Material</class>), and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes an
/// SSL/TLS configuration by exact name. <method>OnBeforeAllTests</method> refuses anywhere it does
/// not. The key material lives in a directory made for the run and deleted after it.</p>
Class OcuPilot.Test.SslSecret Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

/// <p>The probe server configuration, and the description that marks it as this class's own.</p>
Parameter PROBE = "OcuPilotProbeSslSecret";

Parameter PROBEMARKER = "OcuPilot SSL secret probe";

Parameter FORMPATH = "/ssl/form";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIST = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter TOOL = "OcuPilot.Screen.Tool.SslUpdate";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The directory the key material was made in.</p>
Property MaterialDirectory As %String;

/// <p>The password the probe's key file is encrypted under, made for this run.</p>
Property Sentinel As %String;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslSecret creates and deletes an SSL/TLS configuration on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..Sentinel = "OcuPilotSslSentinel" _ $Job _ $Random(1000000)
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    Set ..MaterialDirectory = $Get(tDirectory)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#MATERIAL, "Run", tDirectory, "pkcs8", "-topk8", "-in", tDirectory _ "key.pem", "-out", tDirectory _ "ssl-key.pem", "-v2", "aes-256-cbc", "-passout", "pass:" _ ..Sentinel)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..RemoveProbe()
    Set tDiscardSC = $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory)
    Quit $$$ADDSC(tSC, tDiscardSC)
}

/// <p>Each test starts from the probe created afresh, with no password stored.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ..EnsureProbe()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The Key password row, screen caller: over a real request, a right password is stored -- read
/// in <code>%SYS</code> as set or unset, never as a value -- and a wrong one is 422
/// <code>SSL.PRIVATEKEYPASSWORD.WRONG</code> on its field; the form read never carries it; and
/// neither answer, <code>messages.log</code> nor the audit rows written meanwhile hold it.</p>
/// <p>Mutation (Rule 19): drop the <code>732</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -- the wrong password answers 500
/// and the field leg goes red.</p>
Method TestTheScreenStoresTheRightPasswordRefusesAWrongOneAndLeaksNeither()
{
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Set tMark = ##class(OcuPilot.Test.SslSinks).AuditMark()
    Do $$$AssertEquals(..PasswordSet(), 0, "the probe starts with no password stored")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(), .tStatus, .tBody, ..PasswordBody(..Sentinel), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the right password is saved")
    Do $$$AssertEquals(..PasswordSet(), 1, "and stored")
    Do $$$AssertEquals(..Carries($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")), 0, "the answer does not carry it")

    Set tWrong = ..Sentinel _ "Wrong"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(), .tStatus, .tBody, ..PasswordBody(tWrong), "application/json")
    Set tRow = $Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("detail") = "object"): tBody.detail.violations.%Get(0), 1: "")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRow): tRow.field _ " " _ tRow.code, 1: ""), "422 PrivateKeyPassword " _ ##class(OcuPilot.Api.Error).#SSLPRIVATEKEYPASSWORDWRONG, "a wrong password is refused on its field")
    Do $$$AssertEquals(..Carries($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")), 0, "the refusal does not carry it")
    Do $$$AssertTrue('($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ ..MaterialDirectory), "nor the key file's location")
    Do $$$AssertEquals(..PasswordSet(), 1, "and the right one stays stored")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..#PROBE, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read of the probe answers")
    Set tConfiguration = $Select($IsObject($Get(tBody)): tBody.%Get("configuration"), 1: "")
    Do $$$AssertEquals($IsObject(tConfiguration) && (tConfiguration.%GetTypeOf("PrivateKeyPassword") = "unassigned"), 1, "and names no password")
    Do $$$AssertEquals(..Carries($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")), 0, "nor carries one")

    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written up to a line logged after the Saves")
    Set tLog = ##class(OcuPilot.Test.SslSinks).LogSince(tOffset)
    Do $$$AssertTrue(tLog [ "#732", "the scan covers the refused Save: it holds the vendor's wrong-password line")
    Do $$$AssertEquals(..Carries(tLog), 0, "no messages.log line written meanwhile holds either password")
    Do $$$AssertTrue('(tLog [ tWrong), "the wrong one included")
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).AuditSince(tMark)), 0, "and no audit row does")
}

/// <p>AC2, the agent's confirm: a change proposed over the probe offers one masked, optional
/// password row; confirmed with the password on the card, the write carries it while the stored
/// proposal, the minted and confirmed answers, the ledger, <code>messages.log</code> and the audit
/// rows do not, and the ledger names no password field. The write goes to
/// <class>OcuPilot.Test.ProposalFixture</class>, so nothing is changed.</p>
/// <p>Mutation (Rule 19): drop <code>PrivateKeyPassword</code> from the descriptor's
/// <code>secretArguments</code> -- the confirm refuses the key, and the carried-password leg goes
/// red.</p>
Method TestTheAgentsConfirmCarriesThePasswordToTheWriteAndNowhereElse()
{
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Set tMark = ##class(OcuPilot.Test.SslSinks).AuditMark()
    Set tSC = ..Fresh(.tFresh)
    Do $$$AssertStatusOK(tSC, "the probe reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tArgs = {"Name": (..#PROBE), "Description": (..#PROBEMARKER _ " proposed")}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ..#PROBE, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the change is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Kill tRows
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows(tRow.%Get("field")) = tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%Get("optional")
    }
    Do $$$AssertEquals($Get(tRows("PrivateKeyPassword")), "||1", "the card offers one empty, optional password row")

    Set tKey = tProposal.%Get("proposalId")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSecrets = {}
    Do tSecrets.%Set("PrivateKeyPassword", ..Sentinel, "string")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed with the password: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody() [ ..Sentinel, 1, "the write carries it")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the stored proposal is read back")
    Do $$$AssertEquals(..Carries($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))), 0, "the stored proposal does not")
    Do $$$AssertEquals(..Carries(tProposal.%ToJSON()), 0, "nor the minted answer")
    Do $$$AssertEquals(..Carries($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")), 0, "nor the confirm's answer")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertTrue('($ListFind($ListFromString($Get(tLedger("Fields"))), "PrivateKeyPassword")), "naming no password field: " _ $Get(tLedger("Fields")))
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).LedgerText(tTurnKey)), 0, "nor holding the password")
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written up to a line logged after the confirm")
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).LogSince(tOffset)), 0, "no messages.log line written meanwhile holds it")
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).AuditSince(tMark)), 0, "and no audit row does")
}

/// <p>An empty optional password is not a change: with the right password stored, the agent's
/// confirm of a Description-only change with the card's password row supplied as <code>""</code>,
/// and the screen's Save of <code>{Description, PrivateKeyPassword: ""}</code>, each change the
/// description through the real port and leave the password stored.</p>
/// <p>Mutation (Rule 19): drop the <code>%Remove</code> from
/// <method>OcuPilot.Screen.Tool.SslUpdate.DerivedFields</method> -> the agent's leg goes red; send the
/// password whenever the body carries it in <method>OcuPilot.Area.Security.SslSave.Update</method>
/// -> the screen's leg goes red.</p>
Method TestAnEmptyOptionalPasswordLeavesTheStoredOneSet()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(), .tStatus, .tBody, ..PasswordBody(..Sentinel), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..PasswordSet(), "200 1", "the right password is saved and stored")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tAgent = ..#PROBEMARKER _ " agent"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, {"Name": (..#PROBE), "Description": (tAgent)}, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ..#PROBE, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the agent's Description change is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSecrets = {}
    Do tSecrets.%Set("PrivateKeyPassword", "", "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed with the password row empty: " _ $Get(tCode))
    Set tSC = ..Fresh(.tFresh)
    Do $$$AssertEquals($Select($IsObject($Get(tFresh)): tFresh.%Get("Description"), 1: ""), tAgent, "the confirm reached the instance")
    Do $$$AssertEquals(..PasswordSet(), 1, "and the password stays stored")

    Set tScreen = ..#PROBEMARKER _ " screen"
    Set tRequest = {"Description": (tScreen)}
    Do tRequest.%Set("PrivateKeyPassword", "", "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(), .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the screen's Save with the password field empty is accepted")
    Set tSC = ..Fresh(.tFresh)
    Do $$$AssertEquals($Select($IsObject($Get(tFresh)): tFresh.%Get("Description"), 1: ""), tScreen, "the Save reached the instance")
    Do $$$AssertEquals(..PasswordSet(), 1, "and the password stays stored")
}

/// <p>AC2, AD-35: a private key password longer than the vendor stores, typed on the agent's
/// confirm, is refused, is not stored, and reaches no answer, ledger row, <code>messages.log</code>
/// line or audit row. The confirm path runs no form rule on a secret, and the vendor's length
/// refusal (errors 7201 and 5802) quotes the value it was sent.</p>
/// <p>Mutation (Rule 19): log <var>pVendorSC</var> unscreened in
/// <method>OcuPilot.Port.AdminPort.Fail</method> -- the <code>messages.log</code> leg goes red.</p>
Method TestAnOverlongPasswordOnTheConfirmReachesNoSink()
{
    Set tLong = ..Sentinel _ "Overlong"
    Set tLong = tLong _ $Translate($Justify("", 300 - $Length(tLong)), " ", "x")
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Set tMark = ##class(OcuPilot.Test.SslSinks).AuditMark()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, {"Name": (..#PROBE), "Description": (..#PROBEMARKER _ " overlong")}, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ..#PROBE, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the agent's Description change is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSecrets = {}
    Do tSecrets.%Set("PrivateKeyPassword", tLong, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertTrue($$$ISERR(tSC), "the confirm with a " _ $Length(tLong) _ "-character password is refused: " _ $Get(tHttp) _ " " _ $Get(tCode))
    Do $$$AssertEquals(..PasswordSet(), 0, "nothing is stored")
    Do $$$AssertEquals(..Carries($System.Status.GetErrorText(tSC) _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") _ $Select($IsObject($Get(tDetail)): tDetail.%ToJSON(), 1: "")), 0, "the refusal does not carry it")
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).LedgerText(tTurnKey)), 0, "no ledger row holds it")
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written up to a line logged after the confirm")
    Set tLog = ##class(OcuPilot.Test.SslSinks).LogSince(tOffset)
    Do $$$AssertTrue(tLog [ "Security.SSLConfig failed", "the scan covers the refused write: it holds the port's failure line")
    Do $$$AssertEquals(..Carries(tLog), 0, "no messages.log line written meanwhile holds it")
    Do $$$AssertEquals(..Carries(##class(OcuPilot.Test.SslSinks).AuditSince(tMark)), 0, "and no audit row does")
}

/// <p>Whether <var>pText</var> carries this run's password.</p>
Method Carries(pText As %String) As %Boolean
{
    Quit (pText [ ..Sentinel)
}

/// <p>The edit route for the probe, one encoded segment (AD-13).</p>
ClassMethod Path() As %String
{
    Quit "/ssl/" _ ##class(OcuPilot.Kernel.EntityId).Encode(..#PROBE)
}

/// <p>A Save body carrying <var>pPassword</var> alone.</p>
ClassMethod PasswordBody(pPassword As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("PrivateKeyPassword", pPassword, "string")
    Quit tBody.%ToJSON()
}

/// <p>The probe as the vendor's own <code>GET</code> answers it now.</p>
ClassMethod Fresh(Output pFresh As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = ..#PROBE
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.SSLConfig", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
}

/// <p>Whether the probe stores a private key password, read in <code>%SYS</code> as set or unset;
/// the value is dropped in the same statement.</p>
ClassMethod PasswordSet() As %Boolean
{
    Set tSet = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(..#PROBE, .tConfig) Set tSet = (tConfig.PrivateKeyPassword '= "")
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tSet
}

/// <p>Create the probe server configuration afresh over this run's certificate and encrypted key,
/// with no password stored: removed first when it is this class's own, refused when a
/// configuration of that name is anybody else's.</p>
Method EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Type") = 1
        Set tProps("VerifyPeer") = 0
        Set tProps("Enabled") = 1
        Set tProps("Description") = ..#PROBEMARKER
        Set tProps("CertificateFile") = ..MaterialDirectory _ "cert.pem"
        Set tProps("PrivateKeyFile") = ..MaterialDirectory _ "ssl-key.pem"
        Set tSC = ##class(Security.SSLConfigs).Create(..#PROBE, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe when its description says it is this class's own; a configuration of that
/// name that is anybody else's is an error and is left alone.</p>
Method RemoveProbe() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(..#PROBE, .tConfig) {
            If $Extract(tConfig.Description, 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ ..#PROBE _ " is not this class's own, so it was left alone")
            } Else {
                Set tConfig = ""
                Set tSC = ##class(Security.SSLConfigs).Delete(..#PROBE)
            }
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
