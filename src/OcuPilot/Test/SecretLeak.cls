/// <p><b>What it pins:</b> the AD-48 "no OcuPilot frame binds key material to a local" property on
/// the two frames of the credential-<b>store</b> path that hold a posted key --
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method>, which assigns it onto the credential row's
/// <code>Password</code>, and <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method>, which
/// assigns it onto the adapter's <property>OcuPilot.Kernel.Provider.Base.ApiKey</property>.
/// <class>OcuPilot.Test.ProviderSecret</class> covers the resolve/call path, from the
/// provider-transport frames, which never put either of these on the stack.</p>
/// <p>A canary key is driven through each frame with a probe that forces a real
/// <code>^ERRORS</code> entry from inside it -- <class>OcuPilot.Test.SecretStoreProbe</class> on
/// <method>Store</method>'s own failure branch,
/// <class>OcuPilot.Test.ProviderStubShapeLeak</class> inside the shape seam -- so the frame under
/// test is genuinely live when the entry is written. Each entry is read back through the
/// application error log's own port, the reader the Logs screen uses, and asserted to carry no part
/// of the canary anywhere in its captured variable table, its logged expressions or its stack.</p>
/// <p><b>It forces a real <code>^ERRORS</code> entry, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>).
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it, and <class>OcuPilot.Test.SecretStoreProbe</class> refuses on its own besides. An
/// application error cannot be un-logged -- the delete is Epic 5's.</p>
Class OcuPilot.Test.SecretLeak Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>The fabricated credential. Shaped like an Anthropic key so a shape gate would accept it
/// were one in play here, and carrying a word that appears nowhere else in this instance. No
/// real credential is used, and no provider is called.</p>
Parameter CANARY = "sk-ant-ocupilotstoreleakcanary00000";

/// <p>The substring the assertions actually search for.</p>
Parameter CANARYMARK = "ocupilotstoreleakcanary";

/// <p>76 characters against the credential entry's <code>SystemName</code> <code>MAXLEN</code>
/// of 50 -- named distinctly from <class>OcuPilot.Test.Secret</class>'s own so a run of both
/// classes never contends over the same never-created reference.</p>
Parameter TOOLONGNAME = "OcuPilotProbeCredentialReferenceTheCredentialStoreItselfWillNotAcceptAtAll01";

/// <p>The log port the forced entry is read back through -- the same reader the Logs screen
/// uses, so what this class searches is what a user would see.</p>
Parameter LOGPORT = "OcuPilot.Port.LogSourcePort";

/// <p>Refuse to run at all unless this instance is armed for an application-error write.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SecretLeak forces an application error into this instance's own ^ERRORS and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Leave no switch set, and no credential entry, for the next class.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SecretStoreProbe).Clear()
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#TOOLONGNAME)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#TOOLONGNAME), 0, "no credential entry this class created survives it")
    ; The entry is only half of where a refused store puts a key. The vendor's PasswordSet writes
    ; the value into ^Ens.SecondaryData.Password before %Save is attempted, and undoes it from
    ; %OnClose -- a step that needs a production-enabled namespace, which the rung predicate does
    ; not. Read directly, because the vendor's own accessor resolves through a row that is gone.
    Do $$$AssertEquals($Get(^Ens.SecondaryData.Password(..#TOOLONGNAME)), "", "and the canary is not left in the vendor's own secondary password store either")
    Quit $$$OK
}

/// <p>Drive the vendor's own refusal through <class>OcuPilot.Test.SecretStoreProbe</class>,
/// forcing a real application-error entry from inside <method>Store</method>'s own frame while
/// it is live, and assert that entry -- every local at every stack level, every logged
/// expression and the stack itself -- carries no part of the canary.</p>
/// <p>Mutation: bind the credential value to a local in
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> (<code>Set tLeak = pBody.%Get(pField)</code>
/// ahead of assigning it onto <code>Password</code>) -- <method>Store</method>'s own frame is
/// exactly what <method>AssertEntriesAreClean</method> reads back, so the added local reaches
/// the captured variable table and the assertion goes red.</p>
Method TestNoCredentialMaterialReachesTheLogFromAStoreFailure()
{
    Set tDate = $ZDate($Horolog, 1)
    Set tBefore = ..ErrorCount(tDate)

    Do ##class(OcuPilot.Test.SecretStoreProbe).Clear()
    Do ##class(OcuPilot.Test.SecretStoreProbe).Arm(.tArmed)
    Do $$$AssertTrue(tArmed, "the probe is armed to force a real application-error entry")
    If 'tArmed Quit

    Set tBody = ##class(OcuPilot.Test.CredentialFixture).Payload(..#CANARY)
    Set tSC = ##class(OcuPilot.Test.SecretStoreProbe).Store(..#TOOLONGNAME, tBody, "apiKey")
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses the write, which is what reaches OcuPilot.Kernel.Secret.Ladder.LogCodes")
    Do $$$AssertEquals($System.Status.GetErrorText(tSC) [ ..#CANARYMARK, 0, "and the refusal OcuPilot itself composes carries no part of the canary")

    Set tForced = ##class(OcuPilot.Test.SecretStoreProbe).EntryCount()
    Do $$$AssertTrue(tForced > 0, "the refusal forced at least one real application-error entry, so the assertion below reads a row rather than nothing: " _ tForced)

    Set tAfter = ..ErrorCount(tDate)
    Do $$$AssertTrue(tAfter > tBefore, "the application error log grew, from " _ tBefore _ " to " _ tAfter)

    Set tChecked = ..AssertEntriesAreClean()
    Do $$$AssertTrue(tChecked > 0, "and every entry the run forced was read back in full: " _ tChecked)
}

/// <p>The same property on the <b>other</b> frame that holds a posted key:
/// <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method>, which moves the body member onto the
/// adapter's <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> and asks the argument-free
/// seam about it.</p>
/// <p>The canary is driven through the real
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method> against a catalog row whose adapter
/// forces a real <code>^ERRORS</code> entry from inside
/// <method>IsApiKeyShapeValid</method> -- so the entry is written with the shipped
/// <method>KeyShapeAccepted</method> frame, and the handler's own refusal chain above it, live on
/// the stack. Nothing is stored: the shape gate writes nothing wherever it answers.</p>
/// <p>Mutation: bind the key to a local in
/// <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method>
/// (<code>Set tKey = pBody.%Get(..#KEYFIELD)</code> ahead of the property assignment) -- the
/// captured variable table carries it and the assertion goes red.</p>
Method TestNoCredentialMaterialReachesTheLogFromTheShapeCheck()
{
    Set tDate = $ZDate($Horolog, 1)
    Set tBefore = ..ErrorCount(tDate)

    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Do ##class(OcuPilot.Test.ProviderStub).ArmErrorLog(.tArmed)
    Do $$$AssertTrue(tArmed, "the shape-gate adapter is armed to force a real application-error entry")
    If 'tArmed Quit

    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.CredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPECREDS
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#SHAPELEAKKEY
    Set tBody = ##class(OcuPilot.Test.CredentialFixture).Payload(..#CANARY)
    Set tCode = ##class(OcuPilot.Test.DefinitionsProbe).CredentialRefusal(tRow, tBody)
    Set tRow = ""
    Do $$$AssertEquals(tCode, "", "the canary has the shape this row's prefix requires, so the gate reached the adapter and accepted it: '" _ tCode _ "'")

    Set tForced = ##class(OcuPilot.Test.ProviderStub).ErrorLogCount()
    Do $$$AssertTrue(tForced > 0, "the shape gate forced at least one real application-error entry, so the assertions below read a row rather than nothing: " _ tForced)
    Set tAfter = ..ErrorCount(tDate)
    Do $$$AssertTrue(tAfter > tBefore, "the application error log grew, from " _ tBefore _ " to " _ tAfter)

    Set tChecked = ..AssertStubEntriesAreClean()
    Do $$$AssertTrue(tChecked > 0, "and every entry the shape gate forced was read back in full: " _ tChecked)
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
}

/// <p>Read every entry <class>OcuPilot.Test.ProviderStub</class> forced, in full, and assert none
/// of it carries the canary. Answers how many entries were actually read, so an assertion over
/// nothing is visible as such.</p>
Method AssertStubEntriesAreClean() As %Integer
{
    Set tChecked = 0
    For tI = 1:1:##class(OcuPilot.Test.ProviderStub).ErrorLogCount() {
        Set tEntry = ##class(OcuPilot.Test.ProviderStub).ErrorLogEntry(tI)
        If '$ListValid(tEntry) || ($ListLength(tEntry) < 2) Continue
        Set tSC = $ClassMethod(..#LOGPORT, "Errors", "detail", $Namespace, $ZDate($List(tEntry, 1), 1), $List(tEntry, 2), "", .tResult, .tStatus, .tFault)
        Do $$$AssertEquals(tStatus, 200, "entry #" _ $List(tEntry, 2) _ " reads back at the detail level")
        If tStatus '= 200 Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(tResult.variables.%Size() > 0, "entry #" _ $List(tEntry, 2) _ " captured a variable table to search: " _ tResult.variables.%Size() _ " row(s)")
        Do $$$AssertEquals(tResult.variables.%ToJSON() [ ..#CANARYMARK, 0, "and no local at any stack level in entry #" _ $List(tEntry, 2) _ " carries credential material")
        Do $$$AssertEquals(tResult.expressions.%ToJSON() [ ..#CANARYMARK, 0, "nor any logged expression in entry #" _ $List(tEntry, 2))
        Do $$$AssertEquals(tResult.stack.%ToJSON() [ ..#CANARYMARK, 0, "nor any stack frame in entry #" _ $List(tEntry, 2))
    }
    Quit tChecked
}

/// <p>How many application errors this namespace holds for <var>pDate</var>, or <code>0</code>
/// when the level cannot be read.</p>
ClassMethod ErrorCount(pDate As %String) As %Integer
{
    Set tSC = $ClassMethod(..#LOGPORT, "Errors", "list", $Namespace, pDate, "", "", .tResult, .tStatus, .tFault)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit 0
    Quit tResult.rows.%Size()
}

/// <p>Read every entry <class>OcuPilot.Test.SecretStoreProbe</class> forced, in full, and assert
/// none of it carries the canary. Answers how many entries were actually read, so an assertion
/// over nothing is visible as such.</p>
Method AssertEntriesAreClean() As %Integer
{
    Set tChecked = 0
    For tI = 1:1:##class(OcuPilot.Test.SecretStoreProbe).EntryCount() {
        Set tEntry = ##class(OcuPilot.Test.SecretStoreProbe).Entry(tI)
        If '$ListValid(tEntry) || ($ListLength(tEntry) < 2) Continue
        Set tSC = $ClassMethod(..#LOGPORT, "Errors", "detail", $Namespace, $ZDate($List(tEntry, 1), 1), $List(tEntry, 2), "", .tResult, .tStatus, .tFault)
        Do $$$AssertEquals(tStatus, 200, "entry #" _ $List(tEntry, 2) _ " reads back at the detail level")
        If tStatus '= 200 Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(tResult.variables.%Size() > 0, "entry #" _ $List(tEntry, 2) _ " captured a variable table to search: " _ tResult.variables.%Size() _ " row(s)")
        Do $$$AssertEquals(tResult.variables.%ToJSON() [ ..#CANARYMARK, 0, "and no local at any stack level in entry #" _ $List(tEntry, 2) _ " carries credential material")
        Do $$$AssertEquals(tResult.expressions.%ToJSON() [ ..#CANARYMARK, 0, "nor any logged expression in entry #" _ $List(tEntry, 2))
        Do $$$AssertEquals(tResult.stack.%ToJSON() [ ..#CANARYMARK, 0, "nor any stack frame in entry #" _ $List(tEntry, 2))
    }
    Quit tChecked
}

}
