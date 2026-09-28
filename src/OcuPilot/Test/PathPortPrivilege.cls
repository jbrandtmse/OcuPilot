/// <p>The Allowed directories screen's pair set over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, AD-29): a principal holding exactly
/// <code>%Admin_FileSystemAccess:USE</code> and <code>%DB_IRISSYS:READ</code>, plus read on the install
/// namespace's code database, reads the screen with a 200 whether the allow-list is absent or
/// restricted, and one lacking either pair is refused 403 naming it. The restricted leg is what shows
/// the vendor's allow-list reads demand no further pair.</p>
/// <p><b>Three purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>: <parameter>ALLOWUSER</parameter> with the two pairs,
/// <parameter>NOFSAUSER</parameter> with <code>%DB_IRISSYS:R</code> and <code>%Admin_Operate:U</code>
/// (so the API's administrative floor admits it), and <parameter>NOSYSUSER</parameter> with
/// <code>%Admin_FileSystemAccess:U</code> alone. It creates security principals and changes the
/// instance's allow-list, so <method>OnBeforeAllTests</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> arms it. Each method restores the allow-list it found through
/// <class>OcuPilot.Test.PathPortFixture</class>.</p>
Class OcuPilot.Test.PathPortPrivilege Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The screen read every leg issues.</p>
Parameter READPATH = "/api/ocupilot/screens/security.alloweddirectories/read?maxRows=1000";

/// <p>The allow-list helpers.</p>
Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

/// <p>A directory every Linux instance has.</p>
Parameter TMPROOT = "/tmp/";

/// <p>The principal holding exactly the screen's two pairs.</p>
Parameter ALLOWUSER = "OcuPilotPathAllow";

/// <p>See <parameter>ALLOWUSER</parameter>.</p>
Parameter ALLOWROLE = "OcuPilotPathAllowRole";

/// <p>The principal lacking <code>%Admin_FileSystemAccess:USE</code>.</p>
Parameter NOFSAUSER = "OcuPilotPathNoFsa";

/// <p>See <parameter>NOFSAUSER</parameter>.</p>
Parameter NOFSAROLE = "OcuPilotPathNoFsaRole";

/// <p>The principal lacking <code>%DB_IRISSYS:READ</code>.</p>
Parameter NOSYSUSER = "OcuPilotPathNoSys";

/// <p>See <parameter>NOSYSUSER</parameter>.</p>
Parameter NOSYSROLE = "OcuPilotPathNoSysRole";

/// <p>The three accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back that each account holds exactly the pairs
/// it is meant to.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The allow-list <method>OnBeforeOneTest</method> recorded.</p>
Property SavedExists As %Boolean [ InitialExpression = 0 ];

/// <p>See <property>SavedExists</property>.</p>
Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

/// <p>See <property>SavedExists</property>.</p>
Property SavedPaths As %List;

/// <p>Whether there is a recorded allow-list to restore.</p>
Property SavedOk As %Boolean [ InitialExpression = 0 ];

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
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortPrivilege creates and deletes three IRIS users and three roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotPath" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tCode = tSysDb.ResourceName _ ":R"
        Set tSC = ..EnsurePrincipal(..#ALLOWROLE, ..#ALLOWUSER, tCode _ ",%Admin_FileSystemAccess:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        ; %Admin_Operate, never %Operator: %Operator carries %DB_IRISSYS:RW.
        Set tSC = ..EnsurePrincipal(..#NOFSAROLE, ..#NOFSAUSER, tCode _ ",%DB_IRISSYS:R,%Admin_Operate:U")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOSYSROLE, ..#NOSYSUSER, tCode _ ",%Admin_FileSystemAccess:U")
        If $$$ISERR(tSC) Quit

        Set tAllow = ($SYSTEM.Security.CheckUserPermission(..#ALLOWUSER, "%Admin_FileSystemAccess", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#ALLOWUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#ALLOWUSER, "%Admin_Operate", "USE") '= 1)
        Set tNoFsa = ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%Admin_FileSystemAccess", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOFSAUSER, "%DB_IRISSYS", "READ") = 1)
        Set tNoSys = ($SYSTEM.Security.CheckUserPermission(..#NOSYSUSER, "%Admin_FileSystemAccess", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NOSYSUSER, "%DB_IRISSYS", "READ") '= 1)
        Set ..PreparedSetupOk = tAllow && tNoFsa && tNoSys
        If '..PreparedSetupOk Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the three principals' pairs: allow " _ tAllow _ ", no file-system access " _ tNoFsa _ ", no system read " _ tNoSys)
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
        For tPair = $ListBuild(..#ALLOWUSER, ..#ALLOWROLE), $ListBuild(..#NOFSAUSER, ..#NOFSAROLE), $ListBuild(..#NOSYSUSER, ..#NOSYSROLE) {
            Set tUser = $List(tPair, 1)
            Set tRole = $List(tPair, 2)
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.PathPortPrivilege teardown left throwaway objects on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) throwaway role <var>pRole</var> holding <var>pResources</var> and the
/// account <var>pUser</var> that holds it. <b>Caller contract:</b> <code>$NAMESPACE</code> must
/// already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: allowed-directories principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, ..PreparedPassword, "OcuPilot allowed-directories test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.PathPortPrivilege; deleted in OnAfterAllTests")
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    If '..SavedOk Quit $$$OK
    Set ..SavedOk = 0
    Quit $ClassMethod(..#FIXTURE, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
}

/// <p><var>pUser</var>'s read of the screen: the HTTP status in <var>pStatus</var> and the parsed
/// body in <var>pAnswer</var>, or <code>""</code>.</p>
Method Read(pUser As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ "&ns=" _ $Namespace, pUser, ..PreparedPassword, .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>AC2 -- the principal holding exactly the declared pairs reads the screen with a 200 and the
/// port's rows, with the allow-list absent and restricted to two roots.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_FileSystemAccess:U</code> from
/// <parameter>ALLOWUSER</parameter>'s role -&gt; setup and this leg go red.</p>
Method TestTheDeclaredPairsReadTheScreen()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the three principals' pairs")
    Set tInstall = $System.Util.InstallDirectory()
    For tState = "absent", "restricted" {
        If tState = "absent" Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), tState _ ": the purpose is absent")
        If tState = "restricted" Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..#TMPROOT, tInstall)), tState _ ": the purpose is restricted to two roots")
        Set tSC = ##class(OcuPilot.Port.PathPort).Rows("roots", 1001, .tPortRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tState _ ": the port answers the test process")
        If $$$ISERR(tSC) Continue
        Set tSC = ..Read(..#ALLOWUSER, .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tState _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tState _ ": the principal holding the two pairs reads the screen")
        If (tStatus '= 200) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.rows.%ToJSON(), tPortRows.%ToJSON(), tState _ ": with the port's rows")
        Do $$$AssertTrue(tAnswer.rows.%Size() > 0, tState _ ": which are not empty: " _ tAnswer.rows.%Size())
    }
}

/// <p>AC2 -- a principal lacking either pair is refused 403 <code>AUTH.NOPRIVILEGE</code> naming the
/// pair it lacks, and no row reaches it.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_FileSystemAccess:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.AllowedDirectoryList</class>'s pairs -&gt; the first principal
/// passes the screen gate and the port refuses it on its own code, so the code assertion goes
/// red.</p>
Method TestEitherPairMissingIsRefusedNamingIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the three principals' pairs")
    For tCase = $ListBuild(..#NOFSAUSER, "%Admin_FileSystemAccess:USE"), $ListBuild(..#NOSYSUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tPair = $List(tCase, 2)
        Set tSC = ..Read(tUser, .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tUser _ ": the read is refused")
        If '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Denial).Code(), tUser _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), tPair, tUser _ ": naming " _ tPair)
        Do $$$AssertEquals(tAnswer.%GetTypeOf("rows"), "unassigned", tUser _ ": and no rows")
    }
}

}
