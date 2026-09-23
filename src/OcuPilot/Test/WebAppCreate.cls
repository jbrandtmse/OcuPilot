/// <p>Pins Story 8.1's tool and its form screen (AD-54, AD-55, AD-3, AD-10): what
/// <class>OcuPilot.Screen.Tool.WebAppCreate</class> advertises, what it refuses to advertise, what
/// the server derives rather than accepting, and that the screen's Save and the agent's confirm
/// compose one payload from one field list.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, its compiled tool registry and
/// its screen registry. Every port call is <class>OcuPilot.Test.ProposalFixture</class>'s, so
/// nothing here writes to the instance and no principal or application is created.</p>
Class OcuPilot.Test.WebAppCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.WebAppCreate";

Parameter TOOLNAME = "webapp.list.create";

Parameter FORM = "OcuPilot.Screen.Descriptor.WebAppForm";

Parameter LIST = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter TYPE = "web-application";

/// <p>The name <method>TestTheScreenSaveRefusesAProhibitedCreateBeforeThePortIsTouched</method>
/// drives the refused creates against. Nothing here creates it on a sound build -- every leg is a
/// refusal -- so an application answering that name afterwards is the residue of a build where the
/// refusal did not happen, which is exactly what that method asserts the absence of.</p>
Parameter PROBEAPP = "/csp/ocupilotprobescreencreate";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    ; Only this suite's own probe name, and only when a refusal that should have happened did not.
    ; A mutation run leaves one behind, and a leftover would then redden the next run for the
    ; previous run's reason rather than its own.
    If ##class(OcuPilot.Test.WebAppWire).Exists(..#PROBEAPP) Do ##class(OcuPilot.Test.WebAppWire).Remove(..#PROBEAPP)
    Quit $$$OK
}

/// <p>AD-3 and AD-10 over a create: the tool advertises exactly the fields the set has reviewed
/// for a create of this type, and <code>MatchRoles</code> reaches neither the schema nor the
/// settable list nor the excluded-by-classification path.</p>
/// <p>Mutations: drop a name from
/// <parameter>OcuPilot.Screen.Tool.WebAppCreate.PERMITTEDFIELDS</parameter>, or add one to
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> alone -> the
/// set-equality goes red in that direction. Remove <code>MatchRoles</code> from
/// <method>OcuPilot.Screen.Tool.WebAppCreate.ExcludedFields</method> -> it is still absent, because
/// the reviewed classification leaves that subtree unnamed and the generator emits it secret, and
/// the assertion below says so rather than resting on the exclusion alone.</p>
Method TestTheToolAdvertisesTheReviewedCreateFieldsAndExcludesMatchRoles()
{
    Do $$$AssertEquals(''$ClassMethod(..#TOOL, "Creates"), 1, "the tool declares that its write creates its target")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ChangeAction"), "created", "and the change event it publishes is a create")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Endpoint"), "WebApp.App", "at the endpoint the list already reads")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType"), "GET", "with the same read type as every other write on this entity")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "PUT", "and the vendor's own upsert as its write type")

    Set tSettable = $ClassMethod(..#TOOL, "SettableFields")
    Set tPermitted = $ClassMethod(..#SET, "PermittedCreateFields", ..#TYPE)
    Do $$$AssertTrue($ListLength(tSettable) > 0, "the tool admits at least one field")
    Do $$$AssertEquals($ListLength(tSettable), $ListLength(tPermitted), "and admits exactly as many as the set reviewed for a create -- '" _ $ListToString(tSettable) _ "' against '" _ $ListToString(tPermitted) _ "'")
    For tI = 1:1:$ListLength(tSettable) {
        Do $$$AssertTrue($ListFind(tPermitted, $List(tSettable, tI)) > 0, "the tool admits '" _ $List(tSettable, tI) _ "', which the set reviewed for a create")
    }
    For tI = 1:1:$ListLength(tPermitted) {
        Do $$$AssertTrue($ListFind(tSettable, $List(tPermitted, tI)) > 0, "the set reviewed '" _ $List(tPermitted, tI) _ "', which the tool advertises")
    }

    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf("MatchRoles"), "unassigned", "MatchRoles reaches no schema of this tool")
    Do $$$AssertEquals($ListFind(tSettable, "MatchRoles"), 0, "and no settable list")
    Do $$$AssertEquals($ListFind($ClassMethod(..#TOOL, "SecretArguments", "", .tDeclared), "MatchRoles"), 0, "and is not smuggled in as a declared secret")
    Do $$$AssertEquals(tDeclared, 1, "whose declaration the descriptor answers")
    Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf("Type"), "unassigned", "Type reaches no schema either: the endpoint hard-codes it and refuses it in the body")
    Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf("Path"), "unassigned", "and neither does Path, which the server derives")
    Do $$$AssertEquals($ListFind(tSettable, "Path"), 0, "and which no caller may set")

    ; AD-54's one asymmetry, asserted on this tool rather than only on the kernel's two lists.
    Do $$$AssertTrue($ListFind(tSettable, "DispatchClass") > 0, "a create may name the class that answers at the address")
    Do $$$AssertEquals($ListFind($ClassMethod("OcuPilot.Screen.Tool.WebAppUpdate", "SettableFields"), "DispatchClass"), 0, "while a change may not repoint a serving application at another one")
}

/// <p>AD-55: the screen's Save and the agent's confirm resolve one tool class, so the same
/// arguments compose the same payload whichever caller supplied them -- and the one field the
/// server derives is derived by the tool, for both.</p>
/// <p>Mutations: give <class>OcuPilot.Area.WebApp.Create</class> a field list of its own instead of
/// <method>OcuPilot.Screen.Tool.WebAppCreate.SettableFields</method> -> the two payloads diverge.
/// Make <method>OcuPilot.Screen.Tool.WebAppCreate.DerivedFields</method> a no-op -> the derived
/// path assertion goes red.</p>
Method TestTheScreenRouteAndTheToolComposeOnePayloadAndOneDerivedPath()
{
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Create).ToolClass(), ..#TOOL, "the screen route resolves the same tool class the agent path does")

    Set tArgs = ..Args()
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tArgs, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), .tAgent, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent path composes its payload")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    If $$$ISERR(tSC) Quit

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(..Args(), "Name", $ClassMethod(##class(OcuPilot.Area.WebApp.Create).ToolClass(), "SettableFields"), .tScreen, .tScreenDiff, .tScreenUnchanged, .tScreenProblem)
    Do $$$AssertStatusOK(tSC, "and the screen path composes its own from the same list")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tScreen.%ToJSON(), tAgent.%ToJSON(), "and the two bodies are the same")
    Do $$$AssertEquals(tUnchanged, 0, "a create sends no property the caller did not name")
    Do $$$AssertEquals(tScreenUnchanged, 0, "on either path")

    ; The derivation is the tool's, so both callers get it by calling one method.
    Do $$$AssertEquals(tAgent.%GetTypeOf("Path"), "unassigned", "the composed body carries no path")
    Do $ClassMethod(..#TOOL, "DerivedFields", tAgent)
    Do $$$AssertEquals(tAgent.%Get("Path"), tArgs.%Get("WSGIAppLocation"), "and the tool derives it from the WSGI application's own directory")

    ; A body with no WSGI directory derives nothing, so a CSP or REST create leaves the vendor to
    ; create the directory it defaults to.
    Set tPlain = {}
    Do tPlain.%Set("NameSpace", $Namespace, "string")
    Do $ClassMethod(..#TOOL, "DerivedFields", tPlain)
    Do $$$AssertEquals(tPlain.%GetTypeOf("Path"), "unassigned", "a create that names no directory derives no path")
}

/// <p>The rules the create applies before the port is touched, and the one it does not invent: a
/// create with no authentication method is refused on the field that names it, because
/// <property>Security.Applications.AutheEnabled</property> carries
/// <code>InitialExpression = 64</code> and an omitted value would create an application anybody
/// can reach without signing in.</p>
/// <p>Mutation: drop the <code>AutheEnabled</code> leg from
/// <method>OcuPilot.Area.WebApp.Create.Validate</method> -> the refusal goes and this reddens on
/// the first assertion.</p>
Method TestACreateWithNoAuthenticationMethodAndNoNamespaceIsRefusedOnTheFieldsThatNameThem()
{
    ; The name look-up these rules make reads the LIVE instance: FormRules.Taken resolves the
    ; tool's own port, which the fixture arming below does not reach. The probe names are ones no
    ; instance holds, so "already taken" is not what refuses these; the arming is here because the
    ; sound-create leg shares this method's setup.
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tArgs = {}
    Do tArgs.%Set("Name", "/csp/ocupilotprobecreaterules", "string")
    Set tSC = ..Validate(tArgs, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rules run")
    Do $$$AssertTrue(..Names(.tViolations) [ "NameSpace", "a create with no namespace is refused on the namespace field")
    Do $$$AssertTrue(..Names(.tViolations) [ "AutheEnabled", "and a create with no authentication method on the field that names them")
    Do $$$AssertEquals(..CodeFor(.tViolations, "AutheEnabled"), ##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED, "with the published required-method code")
    Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED), "", "and a sentence authored on the server")

    ; A name that is not a path this instance can address is refused before the read is made.
    Set tArgs = ..Args()
    Do tArgs.%Set("Name", "csp/no-leading-slash", "string")
    Set tSC = ..Validate(tArgs, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rules run over a malformed name")
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#WEBAPPNAMESHAPE, "which is refused on its own field")

    ; And a sound one earns no violation at all, which is the floor under the three above.
    Set tArgs = ..Args()
    Do tArgs.%Set("Name", "/csp/ocupilotprobecreaterules", "string")
    Set tSC = ..Validate(tArgs, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rules run over a sound create")
    Do $$$AssertEquals($Get(tViolations), 0, "which breaks none of them: " _ ..Names(.tViolations))
}

/// <p>AD-10 and AD-55 over the screen's own Save: a prohibited create is refused before the port
/// is touched, on the prohibition rather than on whichever field rule happened to run first, and
/// nothing is written.</p>
/// <p><b>The set is asked about the caller's own fields, not the composed body.</b>
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> keeps only what the tool admits, so a
/// body carrying <code>MatchRoles</code> would otherwise reach the vendor with that key silently
/// dropped -- a 201 for a request AD-10 says is refused. The agent cannot author such a key at all
/// (its schema is closed), so this leg is the screen path's own half of "refused whatever the
/// caller".</p>
/// <p>Mutation: pass the composed payload to <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// instead of <method>OcuPilot.Area.WebApp.Create.CallerFields</method>'s answer -> the role leg
/// goes red, because the key is gone by the time the set is asked.</p>
Method TestTheScreenSaveRefusesAProhibitedCreateBeforeThePortIsTouched()
{
    Set tName = ..#PROBEAPP
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).Exists(tName), 0, "the probe name is free before the first refusal is driven")

    ; A role grant through a path, which AD-10 forbids on a create exactly as on a change.
    Set tArgs = ..Args()
    Do tArgs.%Set("MatchRoles", ##class(%DynamicAbstractObject).%FromJSON("[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]"))
    Set tSC = ##class(OcuPilot.Area.WebApp.Create).Perform(tName, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "a create carrying application roles is refused")
    Do $$$AssertEquals($Get(tViolations), 0, "not as a field rule")
    Do $$$AssertEquals(tHttp, 403, "but at 403")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $Parameter(..#SET, "PRIVILEGEGRANT"), "on the privilege-grant predicate")
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.FormRules).Taken(tName, .tTaken), $$$OK, "the name is read back")
    Do $$$AssertEquals(tTaken, 0, "and nothing was created")

    ; A field this release has not reviewed for a create.
    Set tArgs = ..Args()
    Do tArgs.%Set("EventClass", "Some.Event.Class", "string")
    Set tSC = ##class(OcuPilot.Area.WebApp.Create).Perform(tName, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "a create carrying an unreviewed field is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $Parameter(..#SET, "UNCOVEREDFIELD"), "as a field nobody has reviewed for a create")

    ; And creating at the address that serves OcuPilot, which is refused on the serving-path
    ; predicate rather than on the name being taken -- the set is asked first for exactly this.
    Set tSC = ##class(OcuPilot.Area.WebApp.Create).Perform(..OcuPilotPath(), ..Args(), .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "a create at OcuPilot's own path is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $Parameter(..#SET, "SERVINGPATH"), "on the serving-path predicate")
}

/// <p>OcuPilot's own API application path, read from the install roster rather than typed here --
/// the same declaration <method>OcuPilot.Kernel.Proposal.Prohibited.ServesOcuPilot</method> reads,
/// so a roster whose paths move moves this test with it.</p>
ClassMethod OcuPilotPath() As %String
{
    Set tSC = ##class(OcuPilot.Install.Roster).Application("api", .tApplication)
    If $$$ISERR(tSC) || '$IsObject(tApplication) Quit ""
    Quit tApplication.%Get("path")
}

/// <p>Every field-level code this story publishes carries a sentence, and every sentence is
/// reachable through the one method that owns them (AD-39).</p>
/// <p>Mutation: add a code to
/// <method>OcuPilot.Api.Error.WebAppViolationCodes</method> with no row in
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -> this goes red naming it.</p>
Method TestEveryPublishedFieldCodeCarriesItsOwnSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).WebAppViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes field-level codes at all")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "", tCode _ " carries a written sentence")
    }
    ; And the form's own bootstrap read serves those sentences rather than a copy of them, which is
    ; what makes an inline blur refusal and a failed Save one wording (DW-376).
    Set tRules = ##class(OcuPilot.Area.WebApp.FormRules).Rules()
    Do $$$AssertTrue(tRules.%Size() > 0, "the form's bootstrap read publishes rules")
    Set tIterator = tRules.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRule) {
        Do $$$AssertEquals(tRule.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(tRule.%Get("code")), "the rule on " _ tRule.%Get("field") _ " carries the server's own sentence for " _ tRule.%Get("code"))
    }
}

/// <p>The form screen is built, unlisted and gated by the list's own pairs, and it is the editor
/// the list's Create resolves by convention (AD-5, AD-8).</p>
/// <p>Mutation: give the form a non-zero <code>sideBarPosition</code> -> the unlisted assertion
/// goes red. Drop <code>%DB_IRISSYS:READ</code> from its declared privileges -> the pair-set
/// equality goes red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt"), 1, "it is built")
    Do $$$AssertEquals(+$ClassMethod(..#FORM, "SideBarPosition"), 0, "and unlisted, so it is reachable and never advertised")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype"), "form-page", "it is a form page")
    Do $$$AssertEquals($ClassMethod(..#FORM, "PrimaryEntityType"), ..#TYPE, "over the same entity type the list reads")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ToolIdentifier"), "webapp.form", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(..#FORM, "Read")), 0, "and no declared read, because a form is one entity rather than a list of rows")

    Set tFormPairs = $ClassMethod(..#FORM, "PrivilegePairs")
    Set tListPairs = $ClassMethod(..#LIST, "PrivilegePairs")
    Do $$$AssertEquals($ListToString(tFormPairs), $ListToString(tListPairs), "the form requires exactly what the list requires")

    ; AD-55: the write route's own gate is that same set, so the screen and the route cannot
    ; require different things.
    Do $$$AssertEquals($Parameter("OcuPilot.Area.WebApp.Create", "DESCRIPTORCLASS"), ..#FORM, "and the create route gates on the form's declaration")

    ; The list is write-capable now, which is what puts Create on its command bar and swaps its
    ; empty state for the agent invitation (Conventions, screen archetype).
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertNotEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "", "and invites the agent instead")
}

/// <p>The authentication methods the form offers are the instance's own, never a constant: every
/// bit it publishes is one <property>Security.System.AutheEnabled</property> reports, and each
/// carries the label the classic editor draws it with.</p>
/// <p>Mutation: drop the intersection from
/// <method>OcuPilot.Area.WebApp.FormRules.Methods</method> and return every declared pair -> this
/// goes red on the first bit the instance has turned off.</p>
Method TestTheFormOffersOnlyTheAuthenticationMethodsTheInstanceEnables()
{
    Set tEnabled = ..SystemAutheEnabled()
    Do $$$AssertTrue(tEnabled > 0, "the instance reports an authentication mask at all")
    Set tMethods = ##class(OcuPilot.Area.WebApp.FormRules).Methods()
    Do $$$AssertTrue(tMethods.%Size() > 0, "and the form offers at least one method")
    Set tIterator = tMethods.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tBit = +tRow.%Get("bit")
        Do $$$AssertTrue(tBit > 0, "every offered method names a bit")
        Do $$$AssertTrue(((tEnabled \ tBit) # 2), "and bit " _ tBit _ " is one this instance has enabled")
        Do $$$AssertNotEquals(tRow.%Get("label"), "", "and carries the instance's own label for it")
    }
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.FormRules).Mask(), ..Sum(tMethods), "and the mask the rules judge against is exactly those bits")
}

/// <p>AD-39 at the port boundary: a vendor refusal that names a body field crosses as one
/// <code>detail.violations[]</code> row carrying the field the vendor named, OcuPilot's stable
/// code for that kind of refusal and OcuPilot's own sentence -- never the vendor's text, which is
/// written for a portal developer.</p>
/// <p>It is the half of the matrix's <code>NameSpace</code> row that OcuPilot's own rule normally
/// pre-empts: the create refuses a missing namespace before the port is touched, so the vendor's
/// <code>MissingRequestBodyField</code> is reachable only for a field this release does not state
/// a rule of its own for. The mapping is still what makes such a refusal land on a field, so it is
/// driven directly over a real vendor status rather than left to a path that no longer reaches
/// it.</p>
/// <p>Mutation: drop <code>param 1</code> in
/// <method>OcuPilot.Api.Error.ViolationsFromVendor</method> -- take the last dotted segment, or
/// <code>""</code> -- and the field assertions go red. Remove a row from
/// <parameter>OcuPilot.Api.Error.VENDORFIELDCODES</parameter> and that code's row disappears.</p>
Method TestAVendorRefusalNamingAFieldCrossesAsOneViolationOnThatField()
{
    ; The vendor's own codes, built the way %Api.Admin.Util.RequestValidator builds them:
    ; $$$ERROR(<code>, <field path>), where the path carries dots and [0] for an array element.
    Set tMissing = $System.Status.Error(40301, "NameSpace")
    Set tRows = ##class(OcuPilot.Api.Error).ViolationsFromVendor(tMissing)
    Do $$$AssertEquals(tRows.%Size(), 1, "a missing-field refusal crosses as exactly one violation")
    If tRows.%Size() '= 1 Quit
    Do $$$AssertEquals(tRows.%Get(0).%Get("field"), "NameSpace", "on the field the vendor named")
    Do $$$AssertEquals(tRows.%Get(0).%Get("code"), ##class(OcuPilot.Api.Error).#PORTFIELDREQUIRED, "with OcuPilot's own code for that kind of refusal")
    Do $$$AssertEquals(tRows.%Get(0).%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDREQUIRED), "and OcuPilot's own sentence, never the vendor's text")
    Do $$$AssertEquals(tRows.%Get(0).%Get("reason") [ "40301", 0, "which carries no vendor code")

    ; A nested path is taken verbatim, dots and subscript included, so a refusal about a member of
    ; an array names that member rather than its last segment.
    Set tNested = $System.Status.Error(40307, "MatchRoles[0].MatchRole")
    Set tRows = ##class(OcuPilot.Api.Error).ViolationsFromVendor(tNested)
    Do $$$AssertEquals(tRows.%Size(), 1, "an unexpected-field refusal crosses as one violation")
    If tRows.%Size() '= 1 Quit
    Do $$$AssertEquals(tRows.%Get(0).%Get("field"), "MatchRoles[0].MatchRole", "naming the whole path the vendor gave")
    Do $$$AssertEquals(tRows.%Get(0).%Get("code"), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "as an unexpected field")

    ; A status that names no body field carries no rows, which is what keeps an ordinary failure
    ; from rendering an empty violation the screen would have nowhere to put.
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ViolationsFromVendor($$$OK).%Size(), 0, "a success carries no violations")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ViolationsFromVendor($$$ERROR($$$GeneralError, "something else went wrong")).%Size(), 0, "and neither does a refusal that names no field")
}

/// <p>The arguments a WSGI create carries: a namespace, an authentication mask and the three WSGI
/// fields, so the derived path has something to derive from.</p>
ClassMethod Args() As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("NameSpace", $Namespace, "string")
    Do tArgs.%Set("AutheEnabled", 32, "number")
    Do tArgs.%Set("WSGIAppName", "probe.py", "string")
    Do tArgs.%Set("WSGICallable", "app", "string")
    Do tArgs.%Set("WSGIAppLocation", "/tmp/ocupilot-probe-wsgi", "string")
    Do tArgs.%Set("WSGIType", "WSGI", "string")
    Quit tArgs
}

/// <p>Run the create's own rules over <var>pArgs</var>, taking the name from the body the way the
/// route does.</p>
ClassMethod Validate(pArgs As %DynamicObject, Output pViolations) As %Status
{
    Set tName = ""
    If pArgs.%GetTypeOf("Name") = "string" Set tName = pArgs.%Get("Name")
    Quit ##class(OcuPilot.Area.WebApp.Create).Validate(tName, pArgs, .pViolations)
}

/// <p>The fields <var>pViolations</var> names, comma-separated.</p>
ClassMethod Names(ByRef pViolations) As %String
{
    Set tNames = ""
    For tI = 1:1:+$Get(pViolations) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ $List(pViolations(tI), 1)
    }
    Quit tNames
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p>The instance's own system authentication mask, read in <code>%SYS</code> by AD-16's explicit
/// save and restore.</p>
ClassMethod SystemAutheEnabled() As %Integer
{
    Set tEnabled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set tEnabled = +tSystem.AutheEnabled
        Set tSystem = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tEnabled = 0
    }
    Quit tEnabled
}

/// <p>The sum of every <code>bit</code> in <var>pRows</var>.</p>
ClassMethod Sum(pRows As %DynamicArray) As %Integer
{
    Set tSum = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSum = tSum + +tRow.%Get("bit")
    }
    Quit tSum
}

}
