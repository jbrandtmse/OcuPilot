/// <p>AD-39's "one envelope, two renderings", for the privilege refusal (Story 5.4, AC2): the
/// <b>same missing pair</b> on the <b>same descriptor</b>, reached once as a screen read over the
/// wire and once as a tool call through the shipped dispatcher, carries the same
/// <code>AUTH.NOPRIVILEGE</code> code, the same written sentence and the same
/// <code>detail.failedPair</code>.</p>
/// <p><b>Two real refusals, not one constructor asked twice.</b> The screen half is a real HTTP
/// request by a principal the instance really refuses, evaluated by the real
/// <code>$System.Security.Check</code>; the tool half runs the shipped dispatch chain with that one
/// pair denied at its own <code>$SYSTEM.Security.CheckUserPermission</code> seam, because
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>. Neither half reads the
/// other's answer.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. The account's password is generated for
/// the run and never written to source; the account and its role are removed in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.DenialParity Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The screen both halves reach, as its <code>toolIdentifier</code>. Its declared pair set
/// carries <code>%Admin_Secure:USE</code>, which is the pair this class withholds.</p>
Parameter SCREENTOOL = "webapp.restapis";

/// <p>The pair the principal does not hold and the dispatcher is told to deny.</p>
Parameter MISSINGPAIR = "%Admin_Secure:USE";

/// <p>The principal: read on the install namespace's code database, one administrative resource so
/// the API's own instance-level gate admits it, and <b>not</b>
/// <parameter>MISSINGPAIR</parameter>.</p>
Parameter DENIEDUSER = "OcuPilotParityNoSecure";

/// <p>See <parameter>DENIEDUSER</parameter>.</p>
Parameter DENIEDROLE = "OcuPilotParityNoSecureRole";

/// <p>The shipped tool registry, which both halves resolve through.</p>
Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

/// <p>The dispatcher whose pair seam a test denies.</p>
Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The account's password for this run. Prefix deliberately not "Test".</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, rather than assumed, that the account
/// does not hold <parameter>MISSINGPAIR</parameter>.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DenialParity creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotParity" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        ; %Admin_Operate, never %Operator: %Operator carries %DB_IRISSYS:RW and is a
        ; self-escalation primitive, so a denial proved with it proves nothing.
        Set tSC = ..EnsurePrincipal(tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Operate:U")
        If $$$ISERR(tSC) Quit

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#DENIEDUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#DENIEDUSER, "%Admin_Operate", "USE") = 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal is admitted by the API's own gate and refused " _ ..#MISSINGPAIR)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#DENIEDUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#DENIEDUSER)
        If ##class(Security.Users).Exists(..#DENIEDUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#DENIEDUSER
        If ##class(Security.Roles).Exists(..#DENIEDROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#DENIEDROLE)
        If ##class(Security.Roles).Exists(..#DENIEDROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#DENIEDROLE
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.DenialParity teardown left throwaway objects on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) the throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(..#DENIEDROLE, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(..#DENIEDROLE, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(..#DENIEDROLE, "OcuPilot test: denial-parity principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(..#DENIEDUSER, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(..#DENIEDUSER)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(..#DENIEDUSER, ..#DENIEDROLE, ..PreparedPassword, "OcuPilot denial-parity test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DenialParity; deleted in OnAfterAllTests")
}

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

/// <p>The screen half: the denied principal's own read of
/// <parameter>SCREENTOOL</parameter>, as <code>&lt;status&gt;|&lt;code&gt;|&lt;failedPair&gt;</code>
/// with the written sentence in <var>pReason</var>.</p>
Method ScreenRefusal(Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ ..#SCREENTOOL _ "/read?ns=" _ $Namespace, ..#DENIEDUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit "requestfailed"
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set tAnswer = ""
    }
    If '$IsObject(tAnswer) Quit tStatus _ "|unparseable|"
    Set pReason = tAnswer.%Get("reason")
    Set tPair = ""
    If $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.detail.%Get("failedPair")
    Quit tStatus _ "|" _ tAnswer.%Get("code") _ "|" _ tPair
}

/// <p>The wire name of <parameter>SCREENTOOL</parameter>'s read tool, resolved from the shipped
/// registry rather than spelled, so a renamed tool fails here rather than quietly testing
/// nothing.</p>
ClassMethod ReadToolWire() As %String
{
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(..#SCREENTOOL)
    If tDescriptor = "" Quit ""
    Set tSC = $ClassMethod(..#REGISTRY, "ListTools", .tTools)
    If $$$ISERR(tSC) || '$IsObject(tTools) Quit ""
    Set tWire = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If tTool.%Get("descriptor") '= tDescriptor Continue
        If tTool.%Get("kind") '= "read" Continue
        Set tWire = $ClassMethod(..#REGISTRY, "WireName", tTool.%Get("name"))
        Quit
    }
    Quit tWire
}

/// <p>The tool half: one call to <var>pWire</var> through the shipped dispatch chain with
/// <parameter>MISSINGPAIR</parameter> denied, as
/// <code>&lt;isError&gt;|&lt;code&gt;|&lt;failedPair&gt;</code> with the step's written sentence in
/// <var>pReason</var>.</p>
Method ToolRefusal(pWire As %String, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tUses = []
    Set tUse = {"type": "tool_use", "id": "toolu_parity"}
    Do tUse.%Set("name", pWire, "string")
    Do tUse.%Set("input", {"ns": ($Namespace)})
    Do tUses.%Push(tUse)
    Set tSC = $ClassMethod(..#PROBE, "Answer", "parity", $Username, "", tUses, ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    If $$$ISERR(tSC) Quit "dispatchfailed"
    If '$IsObject($Get(tResults)) || (tResults.%Size() '= 1) Quit "noresult"
    Set tResult = tResults.%Get(0)
    Set tContent = ##class(%DynamicObject).%FromJSON(tResult.%Get("content"))
    Set tPair = ""
    If $IsObject(tContent.%Get("detail")) Set tPair = tContent.detail.%Get("failedPair")
    If $IsObject($Get(tDetails)) && (tDetails.%Size() = 1) Set pReason = tDetails.%Get(0).%Get("reason")
    Quit tResult.%Get("is_error") _ "|" _ tContent.%Get("code") _ "|" _ tPair
}

/// <p><b>AC2</b> -- the screen and the tool refuse identically: same code, same written sentence,
/// same failed pair.</p>
/// <p>Mutation (Rule 19): restore
/// <method>OcuPilot.Api.ScreenRead.Handle</method>'s own literal reason sentence in place of
/// <method>OcuPilot.Kernel.Denial.Envelope</method> -> this goes red.</p>
Method TestTheScreenAndTheToolRefuseIdentically()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal is refused " _ ..#MISSINGPAIR)

    Set tWire = ..ReadToolWire()
    Do $$$AssertNotEquals(tWire, "", ..#SCREENTOOL _ " has a read tool in the shipped registry")
    If tWire = "" Quit

    Set tScreen = ..ScreenRefusal(.tScreenReason)
    Do $$$AssertEquals(tScreen, "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ ..#MISSINGPAIR, "the screen read is refused 403 AUTH.NOPRIVILEGE naming the pair")

    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Do $ClassMethod(..#PROBE, "DenyPair", $Piece(..#MISSINGPAIR, ":", 1), $Piece(..#MISSINGPAIR, ":", 2))
    Set tTool = ..ToolRefusal(tWire, .tToolReason)
    Do $$$AssertEquals(tTool, "1|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ ..#MISSINGPAIR, "the tool call is refused with the same code, naming the same pair")

    Do $$$AssertEquals(tToolReason, tScreenReason, "and both carry the same written sentence: screen '" _ tScreenReason _ "', tool '" _ tToolReason _ "'")
    Do $$$AssertEquals(tScreenReason, ##class(OcuPilot.Kernel.Denial).Reason(), "which is the one sentence OcuPilot.Kernel.Denial owns")
}

/// <p><b>AC2</b> -- the refusal names the failed pair, and OcuPilot issues no second call: the same
/// refused call refuses identically and the tool body never runs.</p>
/// <p>Mutation (Rule 19): drop <code>detail.failedPair</code> from
/// <method>OcuPilot.Kernel.Denial.Detail</method> (which is what
/// <method>OcuPilot.Kernel.Agent.Dispatch.ErrorContent</method> renders) -> this goes red.</p>
Method TestTheRefusalNamesTheFailedPair()
{
    Set tWire = ..ReadToolWire()
    Do $$$AssertNotEquals(tWire, "", ..#SCREENTOOL _ " has a read tool in the shipped registry")
    If tWire = "" Quit

    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Do $ClassMethod(..#PROBE, "DenyPair", $Piece(..#MISSINGPAIR, ":", 1), $Piece(..#MISSINGPAIR, ":", 2))

    Set tFirst = ..ToolRefusal(tWire, .tFirstReason)
    Set tSecond = ..ToolRefusal(tWire, .tSecondReason)
    Do $$$AssertEquals(tFirst, "1|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ ..#MISSINGPAIR, "the refusal names the pair that failed")
    Do $$$AssertEquals(tSecond, tFirst, "and a second call refuses identically -- reported, never retried by another path")
    Do $$$AssertEquals(tSecondReason, tFirstReason, "with the same sentence")

    ; The refusal is an ordinary tool result (AD-39), never an exception: ToolRefusal answers
    ; "dispatchfailed" when Answer returns an error status, and it did not. The pair seam was
    ; asked on both attempts, which is what "checked at call time, never cached" means (AD-8).
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Count", "pair") >= 2, "the pair was checked on each attempt, never cached: " _ $ClassMethod(..#PROBE, "Count", "pair"))
}

}
