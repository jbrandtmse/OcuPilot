/// <p>Pins Story 18.6's declarations (AC A7): License key, License servers and the license server form --
/// their routes, side-bar positions, pairs, classic pages, prompts, entity types, id rules and secret
/// fields; the four tools' kinds, ports, fields, pairs, classic pages and advertisement;
/// <class>OcuPilot.Api.LicenseError</class>'s codes and sentences; the license port's check answer,
/// unlogged refusal and script; and the baseline's four keys, the activation and the delete
/// disabled.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and no custom resource assigned to
/// the replaced classic pages. It writes nothing.</p>
Class OcuPilot.Test.LicenseDescriptor Extends %UnitTest.TestCase
{

Parameter KEY = "OcuPilot.Screen.Descriptor.LicenseKey";

Parameter LIST = "OcuPilot.Screen.Descriptor.LicenseServerList";

Parameter FORM = "OcuPilot.Screen.Descriptor.LicenseServerForm";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>License key: OS management's fifteenth entry, a detail screen over the vendor's
/// <code>License.Key</code> <code>GET</code>, a singleton, whose read declares the authorization key
/// secret and whose one action is Activate, carrying the secret <code>Key</code>.</p>
/// <p>Mutation (Rule 19): <code>sideBarPosition</code> 0 -- the position leg goes red.</p>
Method TestLicenseKeyIsOsManagementsFifteenthEntry()
{
    Set tClass = ..#KEY
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey _ ":" _ tDeclaration.archetype, "os-management:15:licenseKeyLabel:detail", "OS management's fifteenth side-bar entry, a detail screen")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""License.Key"",""type"":""GET""}", "read through the vendor's license key GET")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "OS management's two pairs, and no own pair")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("ownPrivileges"), "unassigned", "it declares no own pair")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind") _ "|" _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("license-key", "any spelling"), "license-key|instance|single|SYSTEM", "the one license key, a singleton (AD-13)")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ContextSecretFields")) _ "|" _ $ListToString($ClassMethod(tClass, "SecretArguments")), "AuthorizationKey|Key", "the authorization key is secret, and the action's key text a secret argument")
    Do $$$AssertTrue(tDeclaration.read.fields.%ToJSON() [ """AuthorizationKey""", "the authorization key is one of the read's fields")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "activate|activate", "its action is Activate")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.License.Key", "the classic License Key page (AD-44)")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/license-key") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.licensekey"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
}

/// <p>License servers: OS management's sixteenth entry, a list over the vendor's
/// <code>License.Server</code> <code>LIST</code>, keyed by name with <code>foldcase</code>, with Create
/// and a Delete row action, its four columns and its two empty-state keys.</p>
/// <p>Mutation (Rule 19): <code>sideBarPosition</code> 0 -- the position leg goes red.</p>
Method TestLicenseServersIsOsManagementsSixteenthEntry()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey, "os-management:16:licenseServerListLabel", "OS management's sixteenth side-bar entry")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""License.Server"",""type"":""LIST""}", "read through the vendor's license server LIST")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""Address"",""Port"",""KeyDirectory""]", "its four fields")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "OS management's two pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "IdKind") _ "|" _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("license-server", "OcuProbe186A"), "license-server|single|ocuprobe186a", "one server per row, keyed by its name in any case (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "create|delete", "Create, and Delete on a row")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.LicenseServers", "the classic License Servers page (AD-44)")
    Do $$$AssertEquals(tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyAgentKey, "licenseServerListEmpty|licenseServerListEmptyAgent", "its two empty-state keys")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/license-servers") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.licenseservers"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
}

/// <p>The form: built, unlisted, under the list's route, with the list's pairs and three prompts, and
/// no read of its own.</p>
Method TestTheFormIsBuiltUnlistedWithTheListsPairs()
{
    Set tClass = ..#FORM
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, "os-management/license-servers/edit|form-page|0", "a form page under the list's route, taking no side-bar position")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the list's own pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ $ClassMethod(tClass, "PrimaryEntityType"), "%CSP.UI.Portal.LicenseServers|license-server", "the classic page, over the license server entity type")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "and no read of its own")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
}

/// <p>The four tools: their descriptor, port, fields, request types, body, kind, advertisement and
/// pairs; the activation's secret body and classic dialog; the server writes'
/// <code>%DB_IRISSYS:WRITE</code> (AD-8, measured at Task 0).</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.LicenseServerUpdate.PrivilegePairs</method> -- the pairs leg goes red.</p>
Method TestTheToolsDeclareTheirKindsPortsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = tScreen _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))
    ; name, descriptor, port, settable, endpoint|write type|body|destructive|creates|change action|advertised, pairs
    Set tCases = $ListBuild($ListBuild("osmgmt.licensekey.activate", ..#KEY, "OcuPilot.Port.LicensePort", "", "License.Key|PUT|0|1|0|updated|0", tScreen))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.licenseservers.create", ..#LIST, "OcuPilot.Port.AdminPort", "Address,Port", "License.Server|PUT|1|0|1|created|1", tWrite))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.licenseservers.update", ..#LIST, "OcuPilot.Port.AdminPort", "Address,Port", "License.Server|PUT|1|0|0|updated|1", tWrite))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.licenseservers.delete", ..#LIST, "OcuPilot.Port.AdminPort", "", "License.Server|DELETE|0|1|0|deleted|1", tWrite))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass"), "write|" _ $List(tCase, 2) _ "|" _ $List(tCase, 3), tName _ ": a write on its screen, through its port")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 4), tName _ " admits exactly its fields")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Advertised"), $List(tCase, 5), tName _ ": endpoint, request type, body, destructive, creates, change action and advertisement")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(tResolved _ " " _ ..PairsText(tPairs), "1 " _ ..PairsText($List(tCase, 6)), tName _ " requires its pairs")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.LicenseKeyActivate", "SECRETBODY") _ "|" _ $Parameter("OcuPilot.Screen.Tool.LicenseKeyActivate", "SCREENVALUES") _ "|" _ $Parameter("OcuPilot.Screen.Tool.LicenseKeyActivate", "CLASSICPAGES"), "Key|activate=Key|%CSP.UI.Portal.Dialog.LicenseActivate", "the activation sends the secret key alone, from the screen's activate, and names the classic dialog (AD-44, AD-56)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.LicenseKeyActivate).ChannelSecretNames(..#KEY, .tDeclared)), "Key", "and Key is its one channel secret")
    For tName = "LicenseServerCreate", "LicenseServerUpdate", "LicenseServerDelete" {
        Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool." _ tName, "CLASSICPAGES"), "", tName _ " names no classic page beyond its descriptor's own (AD-44)")
    }
    For tPage = "%CSP.UI.Portal.License.Key", "%CSP.UI.Portal.Dialog.LicenseActivate", "%CSP.UI.Portal.LicenseServers" {
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(tPage), tPage _ " is a compiled classic page")
    }
}

/// <p>Every <code>LICENSE.*</code> code carries its one published sentence through both of
/// <class>OcuPilot.Api.Error</class>'s resolvers, and each field-level code names its field.</p>
/// <p>Mutation (Rule 19): drop the <code>LICENSE.</code> dispatch line from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- every sentence leg goes red.</p>
Method TestTheLicenseCodesCarryTheirSentences()
{
    Set tCodes = ##class(OcuPilot.Api.LicenseError).Codes()
    Do $$$AssertEquals($ListLength(tCodes), 7, "seven codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.LicenseError).ReasonFor(tCode)
        Do $$$AssertTrue(tReason '= "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": the violation resolver answers it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": and so does the tool-result resolver")
    }
    Set tFields = ""
    Set tViolations = ##class(OcuPilot.Api.LicenseError).ViolationCodes()
    For tI = 1:1:$ListLength(tViolations) Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ ##class(OcuPilot.Api.LicenseError).FieldOf($List(tViolations, tI))
    Do $$$AssertEquals(tFields, "Key,Key,Name,Name,Address,Port", "each violation code names its field")
    Do $$$AssertEquals(##class(OcuPilot.Api.LicenseError).#REASONKEYINVALID, "This is not a valid license key for this instance.", "the invalid key's sentence")
    Do $$$AssertEquals(##class(OcuPilot.Api.LicenseError).#REASONSERVERPORT, "Enter a port from 1 to 65535.", "and the port's")
}

/// <p>The license server delete's consequence names a multi-server key: the delete reads this
/// instance's own key server type through the license port, as <code>$SYSTEM.License.KeyServer()</code>
/// answers it; on that key the consequence is the code exactly when it reads <code>Multi</code>; and
/// through the seam's key server type, the code for <code>Multi</code> and nothing for
/// <code>Single</code>.</p>
/// <p>Mutation (Rule 19): invert the comparison in
/// <method>OcuPilot.Screen.Tool.LicenseServerDelete.Consequence</method> -- every leg goes red; make
/// <method>OcuPilot.Screen.Tool.LicenseServerDelete.KeyServer</method> read a member the read does not
/// answer -- the key server leg goes red.</p>
Method TestTheDeleteNamesAMultiServerKeyAsItsConsequence()
{
    Set tCode = $Parameter("OcuPilot.Screen.Tool.LicenseServerDelete", "CONSEQUENCEMULTIKEY")
    Set tServer = $SYSTEM.License.KeyServer()
    Do $$$AssertTrue((tServer = "Single") || (tServer = "Multi"), "the instance's key names its key server type: " _ tServer)
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.LicenseServerDelete).KeyServer(), tServer, "the delete reads that key server type through the license port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.LicenseServerDelete).Consequence({}), $Select(tServer = "Multi": tCode, 1: ""), "the delete's consequence follows this instance's own key")
    Kill ^||OcuPilotLicenseSeam
    Set ^||OcuPilotLicenseSeam("keyServer") = "Multi"
    Do $$$AssertEquals(##class(OcuPilot.Test.SeamLicenseServerDelete).Consequence({}), tCode, "a multi-server key is named")
    Set ^||OcuPilotLicenseSeam("keyServer") = "Single"
    Do $$$AssertEquals(##class(OcuPilot.Test.SeamLicenseServerDelete).Consequence({}), "", "and a single-server key is not")
    Kill ^||OcuPilotLicenseSeam
}

/// <p>The license port: a valid check's answer carries each of the five reduction kinds the vendor
/// names, in the classic dialog's order, and the features, as text; a refused activation's 400 is the
/// one license answer the admin port leaves unlogged (AD-2); and the activation's script is the check
/// and then the <code>PUT</code>, each carrying the key's placeholder alone (AD-59).</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.LicensePort.REDUCTIONKINDS</parameter>
/// <code>Cores</code> alone -- the reductions leg goes red.</p>
Method TestTheLicensePortAnswersEveryReductionAndScriptsBothSteps()
{
    Set tChecked = {"IsValid": true, "RequiresRestart": false, "Reductions": {"Product": {"From": "Enterprise", "To": "Standard"}, "LicenseType": {"From": "Concurrent User", "To": "Named User"}, "Server": {"From": "Multi", "To": "Single"}, "Users": {"From": 25, "To": 5}, "Cores": {"From": 20, "To": 8}, "Features": ["Sharding", "Vector Search"]}}
    Set tAnswer = ##class(OcuPilot.Port.LicensePort).Answer(tChecked)
    Do $$$AssertEquals(tAnswer.%ToJSON(), "{""valid"":true,""requiresRestart"":false,""reductions"":[{""kind"":""Cores"",""from"":""20"",""to"":""8""},{""kind"":""Users"",""from"":""25"",""to"":""5""},{""kind"":""Server"",""from"":""Multi"",""to"":""Single""},{""kind"":""LicenseType"",""from"":""Concurrent User"",""to"":""Named User""},{""kind"":""Product"",""from"":""Enterprise"",""to"":""Standard""}],""features"":[""Sharding"",""Vector Search""]}", "every reduction kind, in the classic dialog's order, and the features, as text")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("License.Key", "PUT", 400) && '##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("License.Key", "PUT", 500) && '##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("License.Key", "VALIDATE", 400), "a refused activation's 400 alone goes unlogged (AD-2)")
    Kill tQuery
    Set tSteps = ##class(OcuPilot.Port.LicensePort).Snippet("License.Key", "PUT", .tQuery, {"Key": "<Key>"}, {"origin": "https://instance.example", "user": "<User>"})
    Set tTexts = ""
    If $IsObject(tSteps) {
        For tI = 0:1:tSteps.%Size() - 1 Set tTexts = tTexts _ $ListBuild(tSteps.%Get(tI).%Get("text"))
    }
    Do $$$AssertEquals($ListLength(tTexts), 2, "the activation's script is two steps")
    Do $$$AssertTrue(($ListGet(tTexts, 1) [ "-X POST") && ($ListGet(tTexts, 1) [ "/license/key/validate") && ($ListGet(tTexts, 2) [ "-X PUT") && ($ListGet(tTexts, 2) '[ "/validate"), "the check, then the PUT: " _ $ListToString(tTexts, " | "))
    Do $$$AssertTrue(($ListGet(tTexts, 1) [ """Key"":""<Key>""") && ($ListGet(tTexts, 2) [ """Key"":""<Key>"""), "each carrying the key's placeholder alone")
}

/// <p>The baseline lists the four keys, the activation and the delete disabled (AD-22).</p>
/// <p>Mutation (Rule 19): drop <code>osmgmt.licensekey.activate</code> from the baseline -- this goes
/// red.</p>
Method TestTheBaselineListsTheFourKeys()
{
    For tCase = $ListBuild("osmgmt.licensekey.activate", 0), $ListBuild("osmgmt.licenseservers.create", 1), $ListBuild("osmgmt.licenseservers.update", 1), $ListBuild("osmgmt.licenseservers.delete", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed " _ $Select($List(tCase, 2): "enabled", 1: "disabled"))
    }
}

/// <p><var>pPairs</var>, a list of <code>$ListBuild(resource, permission)</code>, as text.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    Quit tOut
}

}
