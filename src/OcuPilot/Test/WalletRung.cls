/// <p>Pins the wallet credential rung's ladder arm (AD-8, AD-42; Story 18.41's C1, C3, C4 and C6) with least-privileged
/// principals: a holder of the probe collection's use resource, an outsider and an administrator holding
/// <code>%Admin_Wallet:USE</code>, each with read on the install database alone beyond that. Each resolves in a child
/// process logged in as the principal (<class>OcuPilot.Test.WalletRungProbe</class>), which signals whether the
/// resolution equals the expected text and never the value.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes users, roles, a resource and a wallet collection, and sets the
/// vendor audit event <code>WalletSecretUse</code>. Every probe object is removed by exact name after each test, and the
/// event is restored to the state it was read in.</p>
Class OcuPilot.Test.WalletRung Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.WalletRungProbe";

/// <p>The stored value of the probe secrets: key-shaped, fabricated, and unmistakable in a search.</p>
Parameter CANARY = "sk-ant-ocupilotwalletrungcanary18410000";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>Whether the vendor audit event <code>WalletSecretUse</code> was enabled before the test, or <code>-1</code>.</p>
Property PreparedUseEvent As %Integer;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedUseEvent = -1
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletRung creates and deletes users, roles, a resource and a wallet collection on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " must read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1841Rung" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs over a freshly created collection, resource, secrets and principals.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedUseEvent = $ClassMethod(..#PROBE, "UseEventEnabled")
    Quit $ClassMethod(..#PROBE, "SeedAll", ..#CANARY, ..PreparedPassword)
}

Method OnAfterOneTest() As %Status
{
    If ..PreparedUseEvent '= -1 Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetUseEvent", ..PreparedUseEvent), "the WalletSecretUse event is restored to the state it was read in")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every <code>WALLETRUNG.*</code> code carries a sentence through each resolver that answers it, the use refusal's
/// sentence names the pair it is given, and the statuses are the matrix's: the use refusal 403, the usage refusal 503,
/// a name and a key store 422 -- the same through the provider base.</p>
/// <p>Mutation (Rule 19): drop the <code>WALLETRUNG.</code> arm from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- the violation resolver answers <code>""</code> and this
/// goes red.</p>
Method TestEveryCodeHasASentenceAndAStatus()
{
    Set tCodes = ##class(OcuPilot.Api.WalletRungError).Codes()
    Do $$$AssertEquals($ListLength(tCodes), 4, "the rung declares four codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tSentence = ##class(OcuPilot.Api.WalletRungError).ReasonFor(tCode)
        Do $$$AssertNotEquals(tSentence, "", tCode _ " has a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tSentence, tCode _ " is the same sentence as a violation")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tSentence, tCode _ " is the same sentence as a tool result")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForTurnError(tCode), tSentence, tCode _ " is the same sentence on a turn")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tCode), tSentence, tCode _ " is the same sentence on a provider fault")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).IsValidCode(tCode), 1, tCode _ " is a well-formed code")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.WalletRungError).ReasonFor("WALLETRUNG.OTHER"), "", "a code the class does not declare has none")
    Set tPair = "OcuPilotProbe1841Use:USE"
    Do $$$AssertTrue(##class(OcuPilot.Api.WalletRungError).ReasonFor(##class(OcuPilot.Api.WalletRungError).#USE, tPair) [ tPair, "the use refusal's sentence names the pair it is given")
    Do $$$AssertTrue(##class(OcuPilot.Api.WalletRungError).ReasonFor(##class(OcuPilot.Api.WalletRungError).#USAGE, "%Admin_Wallet:USE") [ "%Admin_Wallet:USE", "and the usage refusal's names %Admin_Wallet:USE")
    For tCase = $ListBuild("WALLETRUNG.USE", 403), $ListBuild("WALLETRUNG.USAGE", 503), $ListBuild("WALLETRUNG.NAME", 422), $ListBuild("WALLETRUNG.KEYSTORE", 422) {
        Do $$$AssertEquals(##class(OcuPilot.Api.WalletRungError).HttpFor($List(tCase, 1)), $List(tCase, 2), $List(tCase, 1) _ " answers " _ $List(tCase, 2))
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Base).HttpFor($List(tCase, 1)), $List(tCase, 2), $List(tCase, 1) _ " answers " _ $List(tCase, 2) _ " through the provider base")
    }
}

/// <p>C1: a holder of the collection's use resource resolves the key-value secret to its stored value, and so does a
/// holder of <code>%Admin_Wallet:USE</code> that holds no use resource.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> answer <code>""</code> -- every leg
/// here reads a mismatch and this goes red.</p>
Method TestACallerHoldingThePairResolvesTheStoredValue()
{
    Set tHolder = ..Run(1, [{"kind": "resolve", "name": (..Secret("DEFAULTSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..Ran(tHolder, 1), ..User(1) _ " 1", "the child process ran as the holder of the use resource")
    Do $$$AssertEquals(..LegText(tHolder, 1), "matches=1 transient=0 refusal=", "the use resource's holder resolves the stored value (" _ ..LegText(tHolder, 1) _ ")")
    Set tAdmin = ..Run(3, [{"kind": "resolve", "name": (..Secret("DEFAULTSECRET")), "expected": (..#CANARY)}, {"kind": "resolve", "name": (..Secret("HTTPONLYSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..Ran(tAdmin, 3), ..User(3) _ " 1", "the child process ran as the administrator")
    Do $$$AssertEquals(..LegText(tAdmin, 1), "matches=1 transient=0 refusal=", "the holder of %Admin_Wallet:USE resolves it with no use resource (" _ ..LegText(tAdmin, 1) _ ")")
    Do $$$AssertEquals(..LegText(tAdmin, 2), "matches=1 transient=0 refusal=", "and the secret that allows no custom use (" _ ..LegText(tAdmin, 2) _ ")")
}

/// <p>C3: a caller holding neither pair is refused <code>WALLETRUNG.USE</code> naming the collection's use resource, a
/// holder of the use resource is refused <code>WALLETRUNG.USAGE</code> naming <code>%Admin_Wallet:USE</code> when the
/// secret's uses exclude custom, neither refusal is transient, and the refused resolutions write no
/// <code>AccessDenied</code> row: the one row since the mark is the outsider's direct vendor call, which is the positive
/// control that the audit reads rows at all.</p>
/// <p>Mutation (Rule 19): drop the use-resource check from <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> -- the
/// outsider's leg reads no refusal and this goes red.</p>
Method TestACallerWithoutThePairIsRefusedBeforeAnyRead()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Hang 1
    Set tOutsider = ..Run(2, [{"kind": "resolve", "name": (..Secret("DEFAULTSECRET")), "expected": (..#CANARY)}, {"kind": "resolve", "name": (..Secret("HTTPONLYSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..Ran(tOutsider, 2), ..User(2) _ " 1", "the child process ran as the outsider")
    Do $$$AssertEquals(..LegText(tOutsider, 1), "matches=0 transient=0 refusal=WALLETRUNG.USE|OcuPilotProbe1841Use:USE", "the outsider is refused naming the use resource (" _ ..LegText(tOutsider, 1) _ ")")
    Do $$$AssertEquals(..LegText(tOutsider, 2), "matches=0 transient=0 refusal=WALLETRUNG.USE|OcuPilotProbe1841Use:USE", "whatever the secret's uses (" _ ..LegText(tOutsider, 2) _ ")")
    Set tHolder = ..Run(1, [{"kind": "resolve", "name": (..Secret("HTTPONLYSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..LegText(tHolder, 1), "matches=0 transient=0 refusal=WALLETRUNG.USAGE|%Admin_Wallet:USE", "the use resource's holder is refused a secret that allows no custom use, naming %Admin_Wallet:USE (" _ ..LegText(tHolder, 1) _ ")")
    Do $$$AssertEquals(..DeniedRows(tSince), 0, "the refused resolutions wrote no AccessDenied row")
    Set tControl = ..Run(2, [{"kind": "exists", "name": (..Secret("DEFAULTSECRET"))}])
    Do $$$AssertEquals(tControl.steps.%Get(0).opened, 0, "the outsider's direct vendor call is refused")
    Do $$$AssertEquals(..DeniedRows(tSince, 1), 1, "and writes the one AccessDenied row, so the count above counted something")
}

/// <p>C4: a name the wallet lists no key-value secret under -- an absent secret, an absent collection, a symmetric key,
/// a name of the wrong case and one that is no name -- resolves to <code>""</code> as an absence: not transient, not a
/// refusal, whoever asks.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> answer an absent secret as
/// transient -- every leg reads <code>transient=1</code> and this goes red.</p>
Method TestAnAbsentOrNonKeyValueSecretIsAnAbsentReference()
{
    Set tPlan = []
    For tName = "OcuPilotProbe1841.nope", "OcuPilotNoSuchCollection1841.kv", ..Secret("SYMMETRICSECRET"), $ZConvert(..Secret("DEFAULTSECRET"), "U"), "not a secret name", "OcuPilotProbe1841.*" {
        Do tPlan.%Push({"kind": "resolve", "name": (tName), "expected": ""})
    }
    For tUser = 1, 2, 3 {
        Set tRun = ..Run(tUser, tPlan)
        Do $$$AssertEquals(..Ran(tRun, tUser), ..User(tUser) _ " 1", "the child process ran as " _ ..User(tUser))
        For tLeg = 1:1:6 {
            Do $$$AssertEquals(..LegText(tRun, tLeg), "matches=1 transient=0 refusal=", ..User(tUser) _ ": name " _ tLeg _ " resolves to nothing, as an absence (" _ ..LegText(tRun, tLeg) _ ")")
        }
    }
}

/// <p>C6: with the vendor audit event <code>WalletSecretUse</code> off, a resolution writes no row; with it on, it
/// writes one row that names the secret and carries none of its value. The event is turned on first, so the off leg that
/// follows reads no row only because the event is off.</p>
/// <p>Mutation (Rule 19): read the secret twice in <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> -- the on leg
/// counts two rows and this goes red. Make <method>OcuPilot.Test.WalletRungProbe.SetUseEvent</method> ignore a request to
/// turn the event off -- the off leg reads the resolution's row and this goes red.</p>
Method TestTheUseRowIsWrittenOnlyWhileTheEventIsOn()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetUseEvent", 1), "the WalletSecretUse event is turned on")
    Set tOnSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Hang 1
    Set tOn = ..Run(1, [{"kind": "resolve", "name": (..Secret("DEFAULTSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..LegText(tOn, 1), "matches=1 transient=0 refusal=", "the resolution succeeds with the event on")
    Set tRows = ..UseRows(tOnSince, 1)
    Do $$$AssertEquals(tRows, 1, "and writes one row naming the secret")
    Do $$$AssertEquals(..UseRowCarries(tOnSince, ..#CANARY), 0, "that carries none of the value")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetUseEvent", 0), "the WalletSecretUse event is turned off")
    Set tOffSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Hang 1
    Set tOff = ..Run(1, [{"kind": "resolve", "name": (..Secret("DEFAULTSECRET")), "expected": (..#CANARY)}])
    Do $$$AssertEquals(..LegText(tOff, 1), "matches=1 transient=0 refusal=", "the resolution succeeds with the event off")
    ; A refused direct vendor call writes a row of another event after the resolution above. Once that row is readable,
    ; every row the resolution wrote is readable too, so the zero below is read after the audit store has caught up.
    Set tControl = ..Run(2, [{"kind": "exists", "name": (..Secret("DEFAULTSECRET"))}])
    Do $$$AssertEquals(tControl.steps.%Get(0).opened, 0, "the outsider's direct vendor call is refused")
    Do $$$AssertEquals(..DeniedRows(tOffSince, 1), 1, "and its AccessDenied row is readable")
    Do $$$AssertEquals(..UseRows(tOffSince), 0, "so the audit store has caught up, and the resolution wrote no WalletSecretUse row")
}

/// <p>The name of the probe secret <parameter>pParameter</parameter> of <parameter>PROBE</parameter> names.</p>
ClassMethod Secret(pParameter As %String) As %String
{
    Quit $Parameter(..#PROBE, pParameter)
}

/// <p>The principal of entry <var>pIndex</var> of the probe's principals.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $ClassMethod(..#PROBE, "User", pIndex)
}

/// <p>Run <var>pPlan</var> in a child process logged in as principal <var>pUserIndex</var>, and answer what it signalled,
/// or an object carrying <code>error</code>.</p>
Method Run(pUserIndex As %Integer, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Set tUser = ..User(pUserIndex)
        Job ##class(OcuPilot.Test.WalletRungProbe).Run($Job, tUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 300)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 300 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error. <var>pUserIndex</var> is the principal the
/// run was started as, named so a failure says who.</p>
ClassMethod Ran(pRun As %DynamicObject, pUserIndex As %Integer) As %String
{
    If '$IsObject(pRun) Quit "no answer"
    If pRun.%IsDefined("error") Quit pRun.%Get("error")
    Quit pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")
}

/// <p>Step <var>pIndex</var> (from 1) as <code>matches=m transient=t refusal=code|pair</code>, or its error.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit "absent"
    Set tLeg = pRun.%Get("steps").%Get(pIndex - 1)
    If '$IsObject(tLeg) Quit "absent"
    If tLeg.%IsDefined("error") Quit tLeg.%Get("error")
    Quit "matches=" _ tLeg.%Get("matches") _ " transient=" _ tLeg.%Get("transient") _ " refusal=" _ tLeg.%Get("refusal")
}

/// <p>How many <code>WalletSecretUse</code> rows naming the default probe secret the audit database holds since
/// <var>pSince</var>. With <var>pWait</var>, a zero is asked again for up to five seconds: the first row can take a
/// moment to be readable.</p>
ClassMethod UseRows(pSince As %String, pWait As %Boolean = 0) As %Integer
{
    Set tRows = ..AuditRows(pSince, $Parameter(..#PROBE, "USEEVENT"), ..Secret("DEFAULTSECRET"))
    If pWait && (tRows < 1) {
        For tTry = 1:1:50 {
            Hang 0.1
            Set tRows = ..AuditRows(pSince, $Parameter(..#PROBE, "USEEVENT"), ..Secret("DEFAULTSECRET"))
            If tRows > 0 Quit
        }
    }
    Quit tRows
}

/// <p>How many of the <code>WalletSecretUse</code> rows since <var>pSince</var> carry <var>pText</var>.</p>
ClassMethod UseRowCarries(pSince As %String, pText As %String) As %Integer
{
    Quit ..AuditRows(pSince, $Parameter(..#PROBE, "USEEVENT"), pText)
}

/// <p>How many <code>AccessDenied</code> rows the audit database holds since <var>pSince</var>. With <var>pWait</var>,
/// a zero is asked again for up to five seconds.</p>
ClassMethod DeniedRows(pSince As %String, pWait As %Boolean = 0) As %Integer
{
    Set tRows = ..AuditRows(pSince, $Parameter(..#PROBE, "DENIEDEVENT"), "")
    If pWait && (tRows < 1) {
        For tTry = 1:1:50 {
            Hang 0.1
            Set tRows = ..AuditRows(pSince, $Parameter(..#PROBE, "DENIEDEVENT"), "")
            If tRows > 0 Quit
        }
    }
    Quit tRows
}

/// <p>How many <code>%System/%Security/</code><var>pEvent</var> rows since <var>pSince</var> carry <var>pText</var>, read
/// by <method>OcuPilot.Test.AuditingUpdate.VendorRows</method>.</p>
ClassMethod AuditRows(pSince As %String, pEvent As %String, pText As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditingUpdate).VendorRows(pSince, pEvent, pText, .tStamp)
}

}
