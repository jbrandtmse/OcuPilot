/// <p>The wallet key routes against the instance itself, through the real port, as real principals
/// (AD-8, AD-12, AD-27, AD-39, AD-55, Story 18.24): a principal holding only the wallet form's declared pairs
/// creates by generation, imports an RSA key and a symmetric key, reads each key's metadata and replaces
/// each key, and a principal without <code>%Admin_Wallet:USE</code> is refused on every route by that
/// pair's name with nothing created; and each of the four key tools requires the screens' pairs and no
/// other.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding the wallet
/// screens' own pairs, <code>/usr/bin/openssl</code> for run-time key material, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the legs create and delete two
/// users, two roles and secrets. <method>OnBeforeAllTests</method> refuses anywhere it does not; every
/// probe is removed by exact name.</p>
Class OcuPilot.Test.WalletKeyWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CREATEPATH = "/wallet/secret";

Parameter FORMPATH = "/wallet/secret/form";

Parameter EDITPATH = "/wallet/secret/:id";

Parameter PROBE = "OcuPilot.Test.WalletKeyProbe";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

Parameter FORM = "OcuPilot.Screen.Descriptor.WalletSecretForm";

Parameter TOOLS = "OcuPilot.Screen.Tool.WalletKeyCreateRsa,OcuPilot.Screen.Tool.WalletKeyCreateSymmetric,OcuPilot.Screen.Tool.WalletKeyReplaceRsa,OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric";

Parameter RSA = "%Wallet.RSA";

Parameter SYMMETRIC = "%Wallet.SymmetricKey";

/// <p>The secrets this class stores in the probe collection, by the part after it.</p>
Parameter PARTS = "WireRsa,WireImp,WireSym,WireCert,WireDeny";

/// <p>The principal that holds everything the wallet screens need but the wallet resource, and the one that
/// holds the form's declared pairs alone.</p>
Parameter NOWALLETUSER = "OcuPilotKeyWireNoWallet";

Parameter NOWALLETROLE = "OcuPilotKeyWireNoWalletRole";

Parameter WALLETUSER = "OcuPilotKeyWireWalletOnly";

Parameter WALLETROLE = "OcuPilotKeyWireWalletOnlyRole";

Property MaterialDirectory As %String;

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..MaterialDirectory = ""
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletKeyWire creates and deletes users, roles and wallet secrets on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    If $$$ISERR(tSC) Quit tSC
    Set ..MaterialDirectory = tDirectory
    Hang 2
    Set tSC = $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPilotKey" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipal()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletKeyWire")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOWALLETUSER, ..#WALLETUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#NOWALLETROLE, ..#WALLETROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#NOWALLETUSER) || ##class(Security.Roles).Exists(..#NOWALLETROLE) || ##class(Security.Users).Exists(..#WALLETUSER) || ##class(Security.Roles).Exists(..#WALLETROLE) {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletKeyWire left a throwaway principal on the instance"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Quit $$$OK
}

/// <p>C7: a principal holding only the form's pairs creates an RSA key by generation, imports an RSA
/// certificate and a symmetric key, reads each key's metadata through the form read, and replaces each,
/// every route answering its status and the instance holding the result.</p>
/// <p>Mutation (Rule 19): add <code>%Admin_Secure:USE</code> to
/// <class>OcuPilot.Screen.Descriptor.WalletSecretForm</class>'s privileges -> the principal is refused
/// and this goes red.</p>
Method TestTheDeclaredPairsAloneCreateImportReplaceAndRead()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tRsa = ..Name("WireRsa")
    Set tSC = ..As(..#WALLETUSER, "POST", ..#CREATEPATH, {"Name": (tRsa), "Type": (..#RSA), "Length": 2048}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "the principal's generated RSA create answers 201: " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""))
    Do $$$AssertEquals($Select($IsObject($Get(tBody)) && $IsObject(tBody.%Get("readBack")): tBody.%Get("readBack").%Get("verdict"), 1: ""), "matches", "with a matching read-back")

    Set tImp = ..Name("WireImp")
    Set tSC = ..As(..#WALLETUSER, "POST", ..#CREATEPATH, {"Name": (tImp), "Type": (..#SYMMETRIC), "Secret64": ($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(32)))}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "its symmetric import answers 201: " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""))

    Set tCert = ..Name("WireCert")
    Set tSC = ..As(..#WALLETUSER, "POST", ..#CREATEPATH, {"Name": (tCert), "Type": (..#RSA), "Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "its certificate import answers 201: " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""))

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH _ "?name=" _ tRsa, ..#WALLETUSER, ..PreparedPassword, .tStatus, .tFormBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers the principal")
    Set tSecret = ""
    Try { Set tSecret = ##class(%DynamicObject).%FromJSON(tFormBody).%Get("secret") } Catch {}
    Do $$$AssertEquals($Select($IsObject(tSecret): tSecret.%Get("Length") _ " " _ tSecret.%Get("HasPrivateKey") _ " " _ tSecret.%Get("editable"), 1: ""), "2048 1 1", "with the generated key's metadata, editable")

    Set tSC = ..As(..#WALLETUSER, "PUT", ..EditPath(tRsa), {"Length": 3072}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its RSA replace answers 200: " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Metadata", tRsa).%Get("Length"), 3072, "and the instance holds the new pair")
    Set tBefore = $ClassMethod(..#PROBE, "Metadata", tImp)
    Set tSC = ..As(..#WALLETUSER, "PUT", ..EditPath(tImp), {"Secret64": ($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(16)))}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "its symmetric replace answers 200: " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""))
    Set tAfter = $ClassMethod(..#PROBE, "Metadata", tImp)
    Do $$$AssertEquals(tAfter.%Get("KeyId") _ " " _ tAfter.%Get("Length"), tBefore.%Get("KeyId") _ " 16", "keeping the key id and reading the new length")
}

/// <p>C7: a principal without <code>%Admin_Wallet:USE</code> is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// naming that pair on each key route -- a generated create, an import, a replace and a read -- and nothing is
/// created or changed.</p>
Method TestACallerWithoutTheWalletResourceIsRefusedOnEachKeyRoute()
{
    Set tName = ..Name("WireDeny")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tName, 2048), "an RSA key is stored")
    Set tCases = $ListBuild($ListBuild("POST", ..#CREATEPATH, {"Name": (..Name("WireImp")), "Type": (..#RSA), "Length": 2048}), $ListBuild("POST", ..#CREATEPATH, {"Name": (..Name("WireImp")), "Type": (..#SYMMETRIC), "Secret64": "AAAAAAAAAAAAAAAAAAAAAA=="}), $ListBuild("PUT", ..EditPath(tName), {"Length": 3072}), $ListBuild("GET", ..#FORMPATH _ "?name=" _ tName, ""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..As(..#NOWALLETUSER, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tStatus, .tBody)
        Do $$$AssertEquals(tStatus, 403, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": is refused")
        Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("code") _ " " _ tBody.%Get("detail").%Get("failedPair"), 1: ""), "AUTH.NOPRIVILEGE %Admin_Wallet:USE", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": on the pair's name")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("WireImp")), 0, "nothing was created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Metadata", tName).%Get("Length"), 2048, "and the key was not replaced")
}

/// <p>AD-8: each of the four key tools requires the wallet screens' pairs and <code>%Admin_Wallet:USE</code>,
/// which the form already declares, and no other pair.</p>
/// <p>Mutation (Rule 19): a create tool declares an extra pair in
/// <method>OcuPilot.Screen.Tool.WalletKeyCreate.PrivilegePairs</method> -> its leg goes red.</p>
Method TestEachToolRequiresTheFormsPairsAlone()
{
    Set tForm = $ListToString($ClassMethod(..#FORM, "PrivilegePairs"), ";")
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = $Piece(..#TOOLS, ",", tI)
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved, tTool _ ": its pairs resolve")
        Set tNames = ""
        For tJ = 1:1:$ListLength(tPairs) Set tNames = tNames _ $ListBuild($List($List(tPairs, tJ), 1) _ ":" _ $List($List(tPairs, tJ), 2))
        Do $$$AssertEquals($ListToString(tNames, ","), "%Admin_Wallet:USE,%DB_IRISSYS:READ", tTool _ ": %Admin_Wallet:USE and %DB_IRISSYS:READ, as the form")
    }
}

/// <p>A request as <var>pUser</var> over HTTP: <var>pBody</var> as JSON for any method but <code>GET</code>.</p>
Method As(pUser As %String, pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pPath, pUser, ..PreparedPassword, .pStatus, .tBody, .tHeaders, tText, $Select(pMethod = "GET": "", 1: "application/json"))
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Name", pPart)
}

/// <p><parameter>EDITPATH</parameter> for <var>pName</var>, its segment encoded by the one shared
/// encoder (AD-13).</p>
ClassMethod EditPath(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back: one without
/// the wallet resource and one holding the code read and the form's two declared pairs alone.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tSysDb = ##class(SYS.Database).%OpenId(tDatabase.Directory)
        If ##class(Security.Roles).Exists(..#NOWALLETROLE) Do ##class(Security.Roles).Delete(..#NOWALLETROLE)
        Set tSC = ##class(Security.Roles).Create(..#NOWALLETROLE, "OcuPilot test: no wallet resource (throwaway)", tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Secure:U", "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#NOWALLETUSER) Do ##class(Security.Users).Delete(..#NOWALLETUSER)
        Set tSC = ##class(Security.Users).Create(..#NOWALLETUSER, ..#NOWALLETROLE, ..PreparedPassword, "OcuPilot wallet key test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WalletKeyWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If $SYSTEM.Security.CheckUserPermission(..#NOWALLETUSER, "%Admin_Wallet", "USE") = 1 {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as the system read without the wallet resource")
            Quit
        }
        If ##class(Security.Roles).Exists(..#WALLETROLE) Do ##class(Security.Roles).Delete(..#WALLETROLE)
        Set tSC = ##class(Security.Roles).Create(..#WALLETROLE, "OcuPilot test: the wallet form's pairs alone (throwaway)", tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Wallet:U", "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#WALLETUSER) Do ##class(Security.Users).Delete(..#WALLETUSER)
        Set tSC = ##class(Security.Users).Create(..#WALLETUSER, ..#WALLETROLE, ..PreparedPassword, "OcuPilot wallet key test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WalletKeyWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#WALLETUSER, "%Admin_Wallet", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#WALLETUSER, "%Admin_Secure", "USE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the wallet-only principal's grants did not read back as the wallet pairs alone")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
