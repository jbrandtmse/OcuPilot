/// <p><code>GET /api/ocupilot/ui/guardrails</code> over HTTP (Story 16.22), against the instance's own
/// state and the <b>real</b> <code>$System.Security.Check</code> (AD-8, AD-10):</p>
/// <ul>
/// <li>a principal holding nothing of OcuPilot's own gets 200 and the full answer;</li>
/// <li>the sentence <code>GET /ui/findings</code> gives for <code>_SYSTEM</code>'s refused
/// <code>%All</code> removal is the Guardrails row for the same code.</li>
/// </ul>
/// <p><b>It creates a role and an account, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Everything it creates is removed in
/// <method>OnAfterAllTests</method>, which fails if anything survives.</p>
Class OcuPilot.Test.GuardrailsWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter GUARDRAILSPATH As %String = "/api/ocupilot/ui/guardrails";

Parameter FINDINGSPATH As %String = "/api/ocupilot/ui/findings";

/// <p>The least-privileged principal, and its role: the install namespace's code and one
/// administrative resource, which the API requires of every caller, and nothing of OcuPilot's.</p>
Parameter LOWUSER = "OcuGuardrailsLow";

Parameter LOWROLE = "OcuGuardrailsLowRole";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the principal's pairs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run unless armed, then create the least-privileged principal and read its pairs
/// back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GuardrailsWire creates and deletes a role and a user on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuGuardrails" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDbObj.Directory).ResourceName _ ":R"
        If ##class(Security.Roles).Exists(..#LOWROLE) {
            Set tProps("Resources") = tCodeRead _ ",%Admin_Manage:U"
            Set tProps("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#LOWROLE, .tProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#LOWROLE, "OcuPilot guardrails probe role (throwaway)", tCodeRead _ ",%Admin_Manage:U", "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#LOWUSER) {
            Set tSC = ##class(Security.Users).Delete(..#LOWUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#LOWUSER, ..#LOWROLE, ..PreparedPassword, "OcuPilot guardrails test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.GuardrailsWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#LOWUSER, "OcuPilotAdmin", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#LOWUSER, "%Admin_Manage", "USE") = 1)
        If '..PreparedSetupOk Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the account and its role, and fail if either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#LOWUSER) Do ##class(Security.Users).Delete(..#LOWUSER)
        If ##class(Security.Roles).Exists(..#LOWROLE) Do ##class(Security.Roles).Delete(..#LOWROLE)
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#LOWUSER) Set tLeft = tLeft _ " user " _ ..#LOWUSER
        If ##class(Security.Roles).Exists(..#LOWROLE) Set tLeft = tLeft _ " role " _ ..#LOWROLE
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.GuardrailsWire teardown left:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>One <code>GET</code> of <var>pPath</var>, its body parsed, or <code>""</code>.</p>
ClassMethod Get(pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pHeaders) As %DynamicObject
{
    Set pStatus = 0
    Set tAnswer = ""
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, pUser, pPassword, .pStatus, .tRaw, .pHeaders)
    Try {
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tRaw, "I", "UTF8"))
    } Catch {
        Set tAnswer = ""
    }
    Quit tAnswer
}

/// <p>(a) A principal holding nothing of OcuPilot's own reads the whole answer.</p>
/// <p>Mutation: declare a gate on <code>OcuPilotAdmin:USE</code> in
/// <class>OcuPilot.Api.UiGuardrails</class> -&gt; this goes red.</p>
Method TestALeastPrivilegedPrincipalReadsTheWholeAnswer()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal's pairs")
    Set tAnswer = ..Get(..#GUARDRAILSPATH, ..#LOWUSER, ..PreparedPassword, .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the guardrails are read")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer), "carrying a body")
    If '$IsObject(tAnswer) Quit
    For tMember = "prohibited", "confirmTools", "secrets" {
        Do $$$AssertEquals(tAnswer.%GetTypeOf(tMember), "array", tMember _ " is an array")
    }
    For tMember = "switches", "limits" {
        Do $$$AssertEquals(tAnswer.%GetTypeOf(tMember), "object", tMember _ " is an object")
    }
    If tAnswer.%GetTypeOf("prohibited") = "array" Do $$$AssertEquals(tAnswer.%Get("prohibited").%Size(), $ListLength(##class(OcuPilot.Kernel.Proposal.Prohibited).Codes()), "every prohibited code is a row")
    If tAnswer.%GetTypeOf("confirmTools") = "array" Do $$$AssertTrue(tAnswer.%Get("confirmTools").%Size() > 0, "the write tools are listed")
    If tAnswer.%GetTypeOf("switches") = "object" {
        Set tSwitches = tAnswer.%Get("switches")
        Do $$$AssertEquals(tSwitches.%GetTypeOf("killSwitch") _ " " _ tSwitches.%GetTypeOf("killSwitchAudience") _ " " _ tSwitches.%GetTypeOf("enforcedReadOnly"), "boolean string boolean", "the switches carry their three members")
    }
    If tAnswer.%GetTypeOf("limits") = "object" {
        Set tLimits = tAnswer.%Get("limits")
        Do $$$AssertTrue(tLimits.%Get("contextRowCap") >= 1, "the row cap is read")
        Do $$$AssertEquals(tLimits.%Get("totalMaxLength") _ " " _ tLimits.%Get("fieldMaxLength"), ##class(OcuPilot.Kernel.Agent.Limits).#TOOLRESULTMAXLENGTH _ " " _ ##class(OcuPilot.Kernel.Agent.Limits).#FIELDMAXLENGTH, "and the character caps")
    }
}

/// <p>(b) The sentence Home's Findings panel gives for <code>_SYSTEM</code>'s refused
/// <code>%All</code> removal is the Guardrails row for the same code (AD-10, AD-53).</p>
/// <p>Mutation: answer <code>""</code> for one code's reason in
/// <method>OcuPilot.Kernel.Shell.Guardrails.Read</method> -&gt; this goes red.</p>
Method TestTheFindingsRefusalIsTheGuardrailsRow()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tFindings = ..Get(..#FINDINGSPATH, tUser, tPassword, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the findings are read")
    Set tRefused = ""
    If $IsObject(tFindings) && (tFindings.%GetTypeOf("findings") = "array") {
        Set tIterator = tFindings.%Get("findings").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tFinding) {
            If (tFinding.%Get("check") = "all-holder") && (tFinding.%Get("name") = "_SYSTEM") Set tRefused = tFinding.%Get("refused") Quit
        }
    }
    Do $$$AssertTrue($IsObject(tRefused), "_SYSTEM's %All removal is refused on the Findings panel")
    If '$IsObject(tRefused) Quit

    Set tGuardrails = ..Get(..#GUARDRAILSPATH, tUser, tPassword, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the guardrails are read")
    Set tRow = ""
    If $IsObject(tGuardrails) && (tGuardrails.%GetTypeOf("prohibited") = "array") {
        Set tIterator = tGuardrails.%Get("prohibited").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tCandidate) {
            If tCandidate.%Get("code") = tRefused.%Get("code") Set tRow = tCandidate Quit
        }
    }
    Do $$$AssertTrue($IsObject(tRow), "the Guardrails page lists the refusal's code " _ tRefused.%Get("code"))
    If '$IsObject(tRow) Quit
    Do $$$AssertNotEquals(tRow.%Get("reason"), "", "with a sentence")
    Do $$$AssertEquals(tRow.%Get("reason"), tRefused.%Get("reason"), "and it is the Findings panel's sentence")
}

}
