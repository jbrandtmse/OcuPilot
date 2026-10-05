/// <p>Pins Story 18.22's declarations (B8): the two descriptors (routes, positions, pairs, classic pages,
/// prompts, entity types, reads and actions), the four tools' pairs, constant actions, secrets, ports and
/// destructive flags, <class>OcuPilot.Api.EncryptionError</class>'s codes and sentences, the vendor codes
/// <class>OcuPilot.Port.AdminPort</class> maps for an activation and a deactivation, the four baseline keys
/// shipped disabled, <code>DATAELEMENTLIST</code> admitted as a read type, and
/// <method>OcuPilot.Port.EncryptionPort.Snippet</method>'s branches for the two writes.</p>
/// <p>Reads only: it names no file the instance holds, so every activation snippet it renders is a
/// refusal, decided before any vendor call.</p>
Class OcuPilot.Test.EncryptionKeyDescriptor Extends %UnitTest.TestCase
{

Parameter DATABASE = "OcuPilot.Screen.Descriptor.DatabaseEncryption";

Parameter DATAELEMENT = "OcuPilot.Screen.Descriptor.DataElementEncryption";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

/// <p>The two screens: route, position, classic page, tool identifier, entity type and read type, each in
/// Security and secrets with its two pairs and no own pair.</p>
Method TestTheTwoScreensAreDeclaredAsTheSpecPlacesThem()
{
    For tCase = $ListBuild(..#DATABASE, "security/database-encryption", 9, "%CSP.UI.Portal.EncryptionDatabase", "security.databaseencryption", "database-encryption-keys", "LIST"), $ListBuild(..#DATAELEMENT, "security/data-element-encryption", 10, "%CSP.UI.Portal.EncryptionManaged", "security.dataelementencryption", "data-element-encryption-keys", "DATAELEMENTLIST") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(tClass, "Route"), $List(tCase, 2), tClass _ "'s route")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "security", tClass _ " is in Security and secrets")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 3), tClass _ "'s side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", tClass _ "'s archetype")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), $List(tCase, 4), tClass _ "'s classic page")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), $List(tCase, 5), tClass _ "'s tool identifier")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), $List(tCase, 6) _ " instance", tClass _ "'s entity type and scope")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId($List(tCase, 6), "anything"), "SYSTEM", tClass _ "'s entity type is a singleton")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", tClass _ "'s pairs, in order")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", tClass _ " declares no own pair")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, tClass _ " carries three prompts")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(tClass, "RowActionIds")), "activate activate,deactivate", tClass _ "'s actions")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SecretArguments")), "AdminPassword", tClass _ "'s declared secret")
        Set tSource = $ClassMethod(tClass, "Read").%Get("source")
        Do $$$AssertEquals(tSource.%Get("port") _ " " _ tSource.%Get("endpoint") _ " " _ tSource.%Get("type"), "admin Security.Encryption.Key " _ $List(tCase, 7), tClass _ " reads the vendor's own list")
        Do $$$AssertEquals(+$ClassMethod(tClass, "Refreshes"), 0, tClass _ " does not refresh")
    }
}

/// <p>B1, AD-36: <code>DATAELEMENTLIST</code> is a read type, on an admin source only, with no detail call
/// and no parent list.</p>
/// <p>Mutation (Rule 19): drop <code>DATAELEMENTLIST</code> from
/// <parameter>OcuPilot.Screen.Registry.READSOURCETYPES</parameter> -- the first leg goes red.</p>
Method TestDataElementListIsAReadType()
{
    Set tRegistry = "OcuPilot.Screen.Registry"
    Do $$$AssertTrue($ListFind($ListFromString($Parameter(tRegistry, "READSOURCETYPES")), "DATAELEMENTLIST"), "the type is admitted")
    Do $$$AssertStatusOK($ClassMethod(..#DATAELEMENT, "DeclarationJson", .tDeclaration), "Data element encryption's declaration is read")
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tDeclaration), "", "and its read is sound")
}

/// <p>The four tools: pairs (the screen's two, the activations also <code>%Admin_FileSystemAccess:USE</code>),
/// constant actions, read types, secrets within the descriptor's, destructive flags, port and no classic
/// page beyond the descriptor's own.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.DatabaseKeyActivate.EXTRAPAIRS</parameter>
/// -- the activation's pairs leg goes red.</p>
Method TestTheFourToolsDeclareTheirPairsActionsAndSecrets()
{
    Set tTwo = "%Admin_Secure:USE,%DB_IRISSYS:READ"
    For tCase = $ListBuild("DatabaseKeyActivate", tTwo _ ",%Admin_FileSystemAccess:USE", "ActivateDB", "DATABASEKEYS", "AdminPassword", 0), $ListBuild("DatabaseKeyDeactivate", tTwo, "DeactivateDB", "DATABASEKEYS", "", 1), $ListBuild("DataElementKeyActivate", tTwo _ ",%Admin_FileSystemAccess:USE", "ActivateMK", "DATAELEMENTKEYS", "AdminPassword", 0), $ListBuild("DataElementKeyDeactivate", tTwo, "DeactivateMK", "DATAELEMENTKEYS", "", 1) {
        Set tClass = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs(tPairs), $List(tCase, 2), tClass _ "'s pairs")
        Do $$$AssertEquals($Parameter(tClass, "ACTION") _ " " _ $ClassMethod(tClass, "ReadType"), $List(tCase, 3) _ " " _ $List(tCase, 4), tClass _ "'s action and fresh read")
        Do $$$AssertEquals($Parameter(tClass, "SECRETBODY"), $List(tCase, 5), tClass _ "'s secret")
        Do $$$AssertEquals(+$Parameter(tClass, "DESTRUCTIVE"), $List(tCase, 6), tClass _ "'s destructive flag")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", tClass _ " declares no classic page beyond its descriptor's")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), ..#PORT, tClass _ " reaches its target through the encryption port")
        Kill tQuery
        Do $ClassMethod(tClass, "PortQuery", {"root": "r", "path": "p", "AdminName": "a", "KeyId": "k", "Action": "ActivateDB"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("Action")), $List(tCase, 3), tClass _ "'s action is its constant, never the payload's")
        Set tSecrets = $ClassMethod(tClass, "SecretBodyNames")
        Set tDeclared = $ClassMethod(tClass, "SecretArguments", "", .tIs)
        For tI = 1:1:$ListLength(tSecrets) {
            Do $$$AssertTrue($ListFind(tDeclared, $List(tSecrets, tI)), tClass _ "'s secret " _ $List(tSecrets, tI) _ " is its descriptor's declared secret")
        }
    }
}

/// <p>Every <code>ENCRYPTION.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; the tools' state refusals are the error class's; and
/// the admin port maps the vendor's measured credentials, in-use and role codes.</p>
/// <p>Mutation (Rule 19): drop the <code>Security.Encryption.Key:1214</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -- the mapping leg goes red.</p>
Method TestTheErrorCodesAnswerTheirSentences()
{
    Set tClass = "OcuPilot.Api.EncryptionError"
    Set tCodes = $ClassMethod(tClass, "Codes")
    For tCode = "ENCRYPTION.KEY.INUSE", "ENCRYPTION.KEY.ROLE", "ENCRYPTION.KEY.ACTIVATE", "ENCRYPTION.KEY.DEACTIVATE", "ENCRYPTION.KEY.ACTIVATEDATAELEMENT", "ENCRYPTION.KEY.DEACTIVATEDATAELEMENT" {
        Do $$$AssertTrue($ListFind(tCodes, tCode), tCode _ " is one of the class's codes")
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " and through the tool dispatch")
    }
    Do $$$AssertTrue($ClassMethod(tClass, "ReasonFor", "ENCRYPTION.KEY.ACTIVATE") [ "key activation at startup is set to Interactive", "the activation's consequence states the startup effect measured at Task 0")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EncryptionKeyWrite", "REASONKEYINACTIVE"), $Parameter(tClass, "REASONKEYINACTIVE"), "the inactive key's sentence is one sentence")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.DatabaseKeyDeactivate", "REASONKEYDEFAULT"), $Parameter(tClass, "REASONKEYDEFAULT"), "the default key's")
    Set tFaults = $ListFromString($Parameter("OcuPilot.Port.AdminPort", "PROPERTYFAULTS"))
    For tEntry = "Security.Encryption.File:1219:@AdminPassword=ENCRYPTION.KEYFILE.CREDENTIALS", "Security.Encryption.Key:1208:@=ENCRYPTION.KEY.INUSE", "Security.Encryption.Key:1215:@=ENCRYPTION.KEY.INUSE", "Security.Encryption.Key:1214:@=ENCRYPTION.KEY.ROLE" {
        Do $$$AssertTrue($ListFind(tFaults, tEntry), "the admin port maps " _ tEntry)
    }
}

/// <p>AD-22: the four keys ship disabled in the baseline.</p>
/// <p>Mutation (Rule 19): drop <code>security.databaseencryption.deactivate</code> from
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- this goes red.</p>
Method TestTheFourKeysShipDisabled()
{
    For tKey = "security.databaseencryption.activate", "security.databaseencryption.deactivate", "security.dataelementencryption.activate", "security.dataelementencryption.deactivate" {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 0", tKey _ " is listed and disabled")
    }
}

/// <p>AD-59: a deactivation renders one <code>rest</code> step to <code>Key</code> <code>DEACTIVATE</code>'s
/// route naming the key, with both composed names as placeholders; an activation or a deactivation the port
/// would refuse renders one <code>comment</code> carrying the refusal: an action outside the write's own, no
/// key, an administrator name the rules refuse, and a root that is not an allowed directory.</p>
Method TestTheScriptRendersBothWritesAndTheirRefusals()
{
    Kill tQuery
    Set tQuery("Action") = "DeactivateDB"
    Set tQuery("KeyId") = "OCUPROBEACT-K1"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Key", "DEACTIVATE", .tQuery, "", {})
    Set tText = $Select($IsObject(tSteps): tSteps.%ToJSON(), 1: "")
    Do $$$AssertEquals(tSteps.%Size() _ " " _ $Select(tSteps.%Size() > 0: tSteps.%Get(0).%Get("kind"), 1: ""), "1 rest", "a deactivation is one rest step: " _ $Extract(tText, 1, 300))
    Do $$$AssertTrue((tText [ "/security/encryption/key/deactivate") && (tText [ "OCUPROBEACT-K1") && (tText [ "DeactivateDB") && (tText [ "<AdminPassword>"), "to the vendor's route, naming the key, its action and the password placeholder")
    Kill tQuery
    Set tQuery("Action") = "DeactivateMK"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Key", "DEACTIVATE", .tQuery, "", {})
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, "a deactivation naming no key")
    Kill tQuery
    Set tQuery("Action") = "ActivateMK"
    Set tQuery("KeyId") = "OCUPROBEACT-K1"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Key", "DEACTIVATE", .tQuery, "", {})
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, "a deactivation carrying an activation's action")
    Kill tQuery
    Set tQuery("Action") = "ActivateDB"
    Set tQuery("root") = $System.Util.ManagerDirectory()
    Set tQuery("path") = "ocuprobeact-absent/act.key"
    Set tQuery("AdminName") = ""
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.File", "ACTIVATE", .tQuery, {"AdminPassword": "<AdminPassword>"}, {})
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Step(tSteps), "comment Enter an administrator name of up to 50 characters.", "an administrator name the rules refuse")
    Set tQuery("AdminName") = "OcuProbeActAdmin"
    Set tQuery("root") = "/ocuprobeact-not-allowed/"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.File", "ACTIVATE", .tQuery, {"AdminPassword": "<AdminPassword>"}, {})
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONPATHROOT, "a root that is not allowed")
    Set tQuery("Action") = "Activate"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.File", "ACTIVATE", .tQuery, {"AdminPassword": "<AdminPassword>"}, {})
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, "an action outside the two activations")
}

}
