/// <p>Story 18.46's screen half (AD-22, AD-53): <code>GET /allowed-directories</code> over the wire, which answers the verdict on
/// the write's governance key the Allowed directories screen draws Add, Change and Remove off with, as the suite's own account
/// and as a principal short of the screen's pair; and the descriptor's three actions, their self-protection rule and the
/// tools the screen's context lists. <class>OcuPilot.Test.AllowedDirectorySave</class> pins the route they go through.</p>
/// <p>Each method records the allow-list and the governance policy before it runs and restores both exactly afterwards,
/// failure included, and creates and removes its probe directory under the manager directory. Changing the instance's
/// policy is why <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms it; it also
/// creates one throwaway principal and role, deleted in <method>OnAfterAllTests</method>. Needs OcuPilot installed in the
/// namespace it runs in and a process holding <code>%All</code>.</p>
Class OcuPilot.Test.AllowedDirectoryScreen Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>. Only
/// <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter STATEPATH = "/allowed-directories";

/// <p>The sibling whose helpers this class reuses: the probe directory, the governance key's two settings, the roots now and
/// the policy snapshot.</p>
Parameter SIBLING = "OcuPilot.Test.AllowedDirectorySave";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AllowedDirectoryList";

Parameter TOOLNAME = "security.alloweddirectories.update";

Parameter RULE = "allowed-directory-fallback";

/// <p>The principal that clears the API's floor and holds the screen's database pair but not
/// <code>%Admin_FileSystemAccess:USE</code>, and its role.</p>
Parameter NOFSAUSER = "OcuProbe1846NoFsa";

Parameter NOFSAROLE = "OcuProbe1846NoFsaRole";

Property PreparedPassword As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Property SavedExists As %Boolean [ InitialExpression = 0 ];

Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

Property SavedPaths As %List;

Property SavedOk As %Boolean [ InitialExpression = 0 ];

Property SavedPolicy As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Set ..SavedOk = 0
    Set ..SavedPolicy = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AllowedDirectoryScreen changes this instance's governance policy and its %GUIFileSelector allow-list and creates one IRIS user and role, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1846" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tOk = $ClassMethod("OcuPilot.Kernel.Shell.Namespaces", "RoutineDatabase", $Namespace, .tCode, .tReadOnly)
    Set tSC = ##class(OcuPilot.Test.ErrorLogDenial).EnsurePrincipal(..#NOFSAROLE, ..#NOFSAUSER, tCode _ ":R,%DB_IRISSYS:R,%Admin_Operate:U", ..PreparedPassword)
    Set ..PreparedSetupOk = tOk && $$$ISOK(tSC) && ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%Admin_FileSystemAccess", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%DB_IRISSYS", "READ") = 1)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#NOFSAUSER) Do ##class(Security.Users).Delete(..#NOFSAUSER)
        If ##class(Security.Roles).Exists(..#NOFSAROLE) Do ##class(Security.Roles).Delete(..#NOFSAROLE)
        Set tLeft = ##class(Security.Users).Exists(..#NOFSAUSER) || ##class(Security.Roles).Exists(..#NOFSAROLE)
        Set $NAMESPACE = tOrigNS
        Do $$$AssertEquals(tLeft, 0, "the throwaway principal and role are removed")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(0, "the principal could not be removed: " _ ex.DisplayString())
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tFixture = $Parameter(..#SIBLING, "FIXTURE")
    Do $ClassMethod(tFixture, "Reset")
    Set tSC = $ClassMethod(tFixture, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedPolicy = $ClassMethod(..#SIBLING, "PolicyJson", .tRows)
    Do ##class(%File).CreateDirectoryChain($ClassMethod(..#SIBLING, "Dir", "a"))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tFixture = $Parameter(..#SIBLING, "FIXTURE")
    Do $ClassMethod(tFixture, "Reset")
    Set tSC = $$$OK
    If ..SavedOk {
        Set ..SavedOk = 0
        Set tSC = $ClassMethod(tFixture, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
        Do $ClassMethod(..#SIBLING, "PolicyRows", ..SavedPolicy, .tRows)
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is put back")
    }
    Do ##class(%File).RemoveDirectory($ClassMethod(..#SIBLING, "Dir", "a"))
    Quit tSC
}

/// <p><code>GET /allowed-directories</code> as the suite's own account, the answer's status and body.</p>
ClassMethod State(Output pStatus As %Integer, Output pBody As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#STATEPATH, .pStatus, .pBody)
}

/// <p>With the key shipped off the verdict is 200 <code>enabled</code> false, the code <code>ALLOWLIST.OFF</code> and
/// <class>OcuPilot.Api.AllowListError</class>'s sentence, which is what the screen draws its three actions off with; and the
/// read changes nothing.</p>
/// <p>Mutation (Rule 19): ignore the <code>Gate.Decide</code> verdict in
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleState</method> -- the verdict reads enabled and this goes red.</p>
Method TestTheKeyShippedOffAnswersItsVerdictAndChangesNothing()
{
    Set tFixture = $Parameter(..#SIBLING, "FIXTURE")
    Do $ClassMethod(..#SIBLING, "NoSettings")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "SetUp", 1, $ListBuild($ClassMethod(..#SIBLING, "Dir", "a"))), "the list is restricted to one probe directory")
    Set tSC = ..State(.tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the verdict is answered")
    Do $$$AssertTrue($IsObject(tBody), "with a JSON body")
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.enabled, 0, "the key is disabled")
        Do $$$AssertEquals(tBody.code, ##class(OcuPilot.Api.AllowListError).#OFF, "with its code")
        Do $$$AssertEquals(tBody.reason, ##class(OcuPilot.Api.AllowListError).#REASONOFF, "and its published sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#SIBLING, "RootsNow"), $ClassMethod(..#SIBLING, "Dir", "a"), "and the list is as it was")
}

/// <p>With the key enabled the verdict is 200 <code>enabled</code> true and carries no code and no sentence; switching it off
/// again is read at once, because the verdict is asked of the stored policy on every call.</p>
/// <p>Mutation (Rule 19): answer <code>enabled</code> true always in
/// <method>OcuPilot.Area.Security.AllowedDirectorySave.HandleState</method> -- the switched-off leg goes red.</p>
Method TestTheKeyEnabledAnswersEnabledAndFollowsTheStoredPolicy()
{
    Do $ClassMethod(..#SIBLING, "EnableKey")
    Set tSC = ..State(.tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the verdict is answered")
    Do $$$AssertTrue($IsObject(tBody), "with a JSON body")
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.enabled, 1, "the key is enabled")
        Do $$$AssertEquals(tBody.%IsDefined("code") + tBody.%IsDefined("reason"), 0, "and the verdict carries no code and no sentence")
    }
    Do $ClassMethod(..#SIBLING, "NoSettings")
    Set tSC = ..State(.tStatus2, .tBody2)
    Do $$$AssertEquals(tStatus2 _ "|" _ $Select($IsObject(tBody2): tBody2.enabled, 1: ""), "200|0", "and switching it off is read on the next call")
}

/// <p>A caller short of the screen's <code>%Admin_FileSystemAccess:USE</code> is refused 403 naming that pair, with the key
/// off or on: the pair answers before the verdict.</p>
/// <p>Mutation (Rule 19): ignore the pairs refusal in <method>OcuPilot.Area.Security.AllowedDirectorySave.Admit</method> --
/// the verdict answers 200 and this goes red.</p>
Method TestACallerWithoutTheScreensPairIsRefusedByName()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's pairs")
    For tKey = "off", "on" {
        If tKey = "on" Do $ClassMethod(..#SIBLING, "EnableKey")
        If tKey = "off" Do $ClassMethod(..#SIBLING, "NoSettings")
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot" _ ..#STATEPATH, ..#NOFSAUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes with the key " _ tKey)
        Set tAnswer = $Select(tBody '= "": ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8")), 1: "")
        Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#SIBLING, "CodeOf", tAnswer), "403|AUTH.NOPRIVILEGE", "refused as lacking a privilege with the key " _ tKey)
        Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogDenial).FailedPairOf(tBody), "%Admin_FileSystemAccess:USE", "naming the pair it lacks")
    }
}

/// <p>The descriptor declares Add as its primary action and Change and Remove as its row actions, both explained by the
/// fallback rule, which <class>OcuPilot.Screen.Registry</class> declares; its empty state and agent hint are the ones that
/// say an emptied list allows nothing; and the screen's context lists no write tool, because the update tool is unadvertised
/// and declares no screen action.</p>
/// <p>Mutation (Rule 19): drop <code>allowed-directory-fallback</code> from
/// <parameter>OcuPilot.Screen.Registry.SELFPROTECTIONRULES</parameter> -- the declaration no longer validates and this goes
/// red; advertise <class>OcuPilot.Screen.Tool.AllowedDirectoryUpdate</class> and give it <code>SCREENACTIONS</code>
/// <code>change</code> -- the tool leg goes red.</p>
Method TestTheDescriptorDeclaresTheActionsAndTheContextListsNoWriteTool()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals($ClassMethod(..#DESCRIPTOR, "PrimaryActionId"), "add", "Add is the primary action")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DESCRIPTOR, "RowActionIds")), "change,remove", "Change and Remove are the row actions")
    Do $$$AssertEquals(tDeclaration.primaryAction.selfProtection, "", "Add is protected by no rule")
    Set tIterator = tDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Do $$$AssertEquals(tAction.selfProtection, ..#RULE, tAction.id _ " is explained by the fallback rule")
    }
    Do $$$AssertTrue($ListFind($ListFromString($Parameter("OcuPilot.Screen.Registry", "SELFPROTECTIONRULES")), ..#RULE) > 0, "which the registry's vocabulary declares")
    Do $$$AssertEquals(tDeclaration.emptyStateKey, "allowedDirectoriesEmptyNone", "the empty state says an emptied list allows nothing")
    Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "|allowedDirectoriesAgentHint", "and a write-capable screen invites the agent")

    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tTools)
    Do $$$AssertStatusOK(tSC, "the screen's tools are listed")
    Set tUpdate = ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOLNAME)
    Set tRead = ##class(OcuPilot.Screen.Tool.Registry).WireName($ClassMethod(..#DESCRIPTOR, "ToolIdentifier") _ ".read")
    Set tListed = 0
    Set tReadListed = 0
    Set tToolIterator = tTools.%GetIterator()
    While tToolIterator.%GetNext(.tToolIndex, .tName) {
        If tName = tUpdate Set tListed = 1
        If tName = tRead Set tReadListed = 1
    }
    Do $$$AssertEquals(tListed, 0, "the update tool is not among them")
    Do $$$AssertEquals(tReadListed, 1, "while the screen's read tool is, so the list is not simply empty")
}

}
