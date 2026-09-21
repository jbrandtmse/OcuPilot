/// <p>The declaration contract (AD-5): one descriptor is the source of a screen's route, its
/// navigation entry and its privilege gate, and it can express the three awkward forms the
/// mechanism has to carry -- several entity types, a sub-resource's parent, and a composite
/// id -- plus a tool identity that is not derived from either.</p>
/// <p>The production roster holds Home, the users list, the web applications list, the SSL/TLS
/// configurations list and the task schedule, so the awkward forms are
/// exercised over fixture descriptors under <code>OcuPilot.Test.Screen.</code>, enumerated by
/// <class>OcuPilot.Test.ScreenRegistry</class>. The real roster is asserted here too -- it is
/// what the shell serves -- but it cannot demonstrate forms it does not contain.</p>
Class OcuPilot.Test.Descriptor Extends %UnitTest.TestCase
{

/// <p>The one real descriptor this epic authors.</p>
Parameter HOMEDESCRIPTOR = "OcuPilot.Screen.Descriptor.Home";

/// <p>AC1 -- one declaration drives all three. The route lookup, the roster entry and the gate
/// each resolve Home, and each reads the same declaration rather than a copy of it: the
/// roster's route is the descriptor's own <method>Route</method>, and the gate's requirement is
/// the descriptor's own <method>PrivilegePairs</method>.</p>
/// <p>Mutation: change <code>"route"</code> in
/// <class>OcuPilot.Screen.Descriptor.Home</class>'s declaration -> the lookup and the roster
/// assertions go red together, which is the evidence that they are one source and not two.</p>
Method TestOneDeclarationDrivesRouteNavigationAndGate()
{
    Set tRoute = $ClassMethod(..#HOMEDESCRIPTOR, "Route")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute), ..#HOMEDESCRIPTOR, "the route table resolves the declared route to the declaring class")

    Set tSC = ##class(OcuPilot.Screen.Registry).Roster(.tRoster)
    Do $$$AssertStatusOK(tSC, "the roster builds")
    Set tHomeArea = ..AreaEntry(tRoster, "home")
    Do $$$AssertTrue($IsObject(tHomeArea), "the roster carries the home area")
    If $IsObject(tHomeArea) {
        Do $$$AssertEquals(tHomeArea.screens.%Size(), 1, "with exactly the one built screen declared for it")
        Do $$$AssertEquals(tHomeArea.screens.%Get(0).route, tRoute, "whose navigation entry names the declared route")
        Do $$$AssertEquals(tHomeArea.screens.%Get(0).descriptor, ..#HOMEDESCRIPTOR, "and the declaring class")
    }

    Set tFailed = "x"
    Do $$$AssertTrue(##class(OcuPilot.Screen.Gate).Evaluate(..#HOMEDESCRIPTOR, .tFailed), "the gate resolves the same descriptor")
    Do $$$AssertEquals(tFailed, "", "and names no failed pair, because Home declares none")
}

/// <p>The production roster is sound: every descriptor parses, names a declared area, uses
/// only kernel entity types, declares a tool identifier and holds a route no sibling
/// claims.</p>
/// <p>Mutation: point <class>OcuPilot.Screen.Descriptor.Home</class>'s <code>"area"</code> at a
/// key <class>OcuPilot.Screen.Area</class> does not declare -> this goes red naming the class
/// and the key.</p>
Method TestTheProductionRosterValidates()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "the production descriptor roster is sound")
    Do $$$AssertStatusOK(tSC, "and the refusal travels in the status too")
}

/// <p>AC7 -- the web applications list's declaration passes the read grammar on its own, and its
/// classic page names a class compiled on this instance, spelled in that class's own case: the
/// custom-resource lookup does not case-fold, so a mis-cased name would silently union no
/// resource onto the gate (AD-44).</p>
/// <p>Mutation: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> -> the classic-page and compiled-class
/// assertions go red.</p>
Method TestTheWebApplicationsListValidatesAndNamesItsClassicPageInItsOwnCase()
{
    Set tClass = "OcuPilot.Screen.Descriptor.WebAppList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("web-applications/list"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("webapp.list"), tClass, "and so does its tool identifier")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Applications.WebList", "the classic page is the vendor's web application list")
    ; The dictionary lookup is keyed on the exact name, so a mis-cased declaration opens nothing.
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>DW-1121, AD-3, AD-6 -- the confirm channel is the descriptor's declaration, and a
/// credential-named field it does not declare is refused where it is declared. Without this rule
/// <code>secretArguments</code> is a list nothing reads, which is the inversion AD-3 forbids:
/// the schema layer advisory and the name pattern the real defense.</p>
/// <p><b>Every shipped descriptor passes it</b>, and the two malformed shapes and the planted
/// credential-named criterion are refused with the sentence
/// <file>ui/tools/screen-mirror.mjs</file>'s own <code>confirmChannelProblem</code> returns for the
/// same input.</p>
/// <p>Mutation (Rule 19): restore <method>SecretArguments</method> on
/// <class>OcuPilot.Kernel.Shell.ReadTool</class> and plant a credential-named criterion on a
/// shipped descriptor -- the refusal below is what bites, and without it the declaration would be
/// overruled by an intermediate class with nothing noticing.</p>
Method TestTheConfirmChannelRefusesACredentialNamedFieldItDoesNotDeclare()
{
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.WebAppList", "DeclarationJson", .tSound)
    Do $$$AssertStatusOK(tSC, "the web applications declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tSound), "", "and its two declared lists are sound")

    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("secretArguments", "not an array")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "secretArguments is not an array of strings", "a secretArguments that is not an array is refused")

    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("fingerprintExcludes", ["NoSuchField"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "fingerprintExcludes names 'NoSuchField', which is neither a field of this screen's write tool nor one its read declares (AD-6)", "an exclusion covering nothing is refused")

    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("fingerprintExcludes", ["Timeout"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "while one naming a field of that tool is sound")

    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("fingerprintExcludes", [(tSound.%Get("read").%Get("fields").%Get(0))])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "and so is one naming a field this screen's own read declares (DW-1205)")

    ; DW-1206, the refusing direction: secretArguments is read as a whitelist by the confirm channel
    ; and by the tool's own schema, both by exact name, so an entry naming nothing left the real
    ; field advertised and the channel closed to the spelling nobody sends. Both keys are now
    ; checked against one set.
    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("secretArguments", ["Pasword"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "secretArguments names 'Pasword', which is neither a settable field of this screen's write tool nor one its read declares (AD-6)", "a secretArguments entry naming nothing is refused")
    Do tBad.%Set("secretArguments", ["Timeout"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "while one naming a settable field of that tool is sound")
    Do tBad.%Set("secretArguments", [(tSound.%Get("read").%Get("fields").%Get(0))])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "and so is one naming a field this screen's own read declares")

    ; The two spellings the one set carries, because their consumers honour different ones: the
    ; schema drops a declared secret by the []-stripped name, while an exclusion of an array reaches
    ; the fingerprint as <path>[].
    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("secretArguments", ["CorsAllowlist"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "a secret named in the spelling the tool's schema honours is sound")
    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("fingerprintExcludes", ["CorsAllowlist[]"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "and an exclusion named in the spelling the fingerprint honours is sound")

    ; The tightening half: any row of the entry was accepted before, a secret-classified subtree
    ; included. An exclusion covering a field the tool cannot set is nameable through the read half.
    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Set("fingerprintExcludes", ["MatchRoles[].MatchRole"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "fingerprintExcludes names 'MatchRoles[].MatchRole', which is neither a field of this screen's write tool nor one its read declares (AD-6)", "a row the write tool cannot set is no longer nameable through the tool half")

    Set tBad = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
    Do tBad.%Get("read").%Set("criteria", {"fields": [{"param": "apiKey", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]})
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "read.criteria names 'apiKey', whose name matches the credential pattern and which secretArguments does not declare (AD-3)", "a credential-named criterion the declaration does not hold is refused")
    Do tBad.%Set("secretArguments", ["apiKey"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tBad), "", "and declaring it is what admits it")

    ; The loosening half: a declared criterion is one of the names the read declares, so it is a
    ; nameable exclusion where it was refused before -- including a FLAG criterion, whose value is
    ; the descriptor's own and which DeclaredCriterionParams missed until DW-1206.
    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.AuditList", "DeclarationJson", .tAudit)
    Do $$$AssertStatusOK(tSC, "the audit viewer's declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tAudit), "", "and is sound as it ships")
    Set tFlags = $ClassMethod("OcuPilot.Screen.Descriptor.AuditList", "FlagCriteria")
    Do $$$AssertTrue($ListLength(tFlags) > 0, "it declares at least one flag criterion")
    Do tAudit.%Set("fingerprintExcludes", [(tAudit.%Get("read").%Get("criteria").%Get("fields").%Get(0).%Get("param"))])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tAudit), "", "a typed criterion's parameter is a nameable exclusion")
    Do tAudit.%Set("fingerprintExcludes", [(tAudit.%Get("read").%Get("criteria").%Get($List(tFlags, 1)).%Get("param"))])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tAudit), "", "and so is a flag criterion's, which the builder missed before")

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tAll)
    Do $$$AssertStatusOK(tSC, "every shipped descriptor enumerates")
    For tI = 1:1:$ListLength(tAll) {
        Set tClass = $List(tAll, tI)
        Do $ClassMethod(tClass, "DeclarationJson", .tOne)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tOne), "", tClass _ ": passes the confirm-channel rule")
    }
}

/// <p>Story 5.10's descriptor: the first <code>built: false</code> screen in this tree. It
/// validates, its route and its tool identifier resolve to it, it declares the security area's own
/// pairs, and it is absent from every surface a <b>built</b> screen appears on -- which is what lets
/// the agent's write tool ship before Story 7.4 builds the screen.</p>
/// <p>Mutation (Rule 19): flip its <code>"built"</code> key to true and recompile -- the mirror's
/// own <code>BuiltArchetypeKey</code> gate would then require an Angular page for
/// <code>form-page</code> (it has one, Story 4.2's), so what reddens here is the unbuilt
/// assertions below and <class>OcuPilot.Test.SurfaceCoverage</class>'s screen roster.</p>
Method TestTheAuditingConfigurationDescriptorIsDeclaredUnbuiltAndOwnsTheWriteTool()
{
    Set tClass = "OcuPilot.Screen.Descriptor.AuditingConfig"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    Set tKeys = ""
    Set tIterator = tDeclaration.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "route,area,labelKey,sideBarPosition,archetype,built,refreshes,refreshRates,privileges,entityType,entityLabelKey,secondaryEntityTypes,scope,parentScope,id,primaryAction,rowActions,context,emptyStateKey,commandAliases,classicPage,classicLinkExemption,toolIdentifier", "the declared keys, with no read, table, banner or criteria among them: " _ tKeys)

    Do $$$AssertEquals($ClassMethod(tClass, "IsBuilt"), 0, "it is declared unbuilt")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tDeclaration), "", "so its side-bar position says nothing yet")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "a declaration with no read is a supported shape")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tDeclaration), "", "and it declares no secret and no exclusion")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "the accessor answers no read at all")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("security/auditing"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("security.auditing"), tClass, "and so does the tool identifier its write tool's name opens with")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "auditing-configuration", "its entity type is the instance's auditing configuration")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", "scoped to the instance, which has one of them")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "it is a form page, as Story 7.4 will build it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("form-page"), "detail", "whose link-out class permits a classic link it does not declare")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and its classic-page declaration is sound")
    Do $$$AssertNotEquals(tDeclaration.%Get("classicPage"), "", "it names the classic page it replaces (AD-44)")

    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Secure"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "two declared pairs: the endpoint's own resource at USE, and read on the database the port runs it from")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", $ClassMethod(tClass, "PrivilegePairs")), "", "and the security area covers both")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it never auto-refreshes: a form whose fields moved under the cursor is what refresh must not do")
}

/// <p>Story 6.1 -- the REST API explorer and the OpenAPI document viewer pass the read, criteria and
/// classic-link rules; their routes and tool identifiers resolve to them; both read through the
/// <code>mgmnt</code> source in the route's namespace scope, over <code>rest-service</code> entities
/// keyed by one name; neither names a classic page; the explorer is the area's second side-bar entry
/// and the viewer is routable and unlisted; and the viewer declares its one criterion,
/// <code>application</code>, bounded at 256 characters.</p>
/// <p>Mutations: set the viewer's <code>sideBarPosition</code> to 3 -&gt; the unlisted assertion goes
/// red; declare the explorer's read on the <code>admin</code> port -&gt; the source assertion goes
/// red.</p>
Method TestTheRestApiExplorerAndDocumentViewerValidate()
{
    Set tExplorer = "OcuPilot.Screen.Descriptor.RestApiList"
    Set tViewer = "OcuPilot.Screen.Descriptor.OpenApiViewer"
    For tClass = tExplorer, tViewer {
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": and its criteria")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tClass _ ": and it links out to nothing")
        Do $$$AssertEquals(tDeclaration.read.source.port, "mgmnt", tClass _ ": it reads through the management API's port")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "namespace", tClass _ ": in the route's namespace")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "rest-service", tClass _ ": over REST services")
        Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "single", tClass _ ": keyed by one name")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "", tClass _ ": with no classic page")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "web-applications", tClass _ ": in the Web applications area")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("web-applications/rest-apis"), tExplorer, "the explorer's route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("webapp.restapis"), tExplorer, "and so does its tool identifier")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("web-applications/rest-apis/document"), tViewer, "the viewer's route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("webapp.openapi"), tViewer, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tExplorer, "SideBarPosition"), 2, "the explorer is the area's second side-bar entry")
    Do $$$AssertEquals($ListToString($ClassMethod(tExplorer, "CommandAliases"), "|"), "REST|REST APIs", "answering the command box's REST aliases")
    Do $$$AssertEquals($ClassMethod(tViewer, "SideBarPosition"), 0, "the viewer is routable and unlisted")
    Do $$$AssertEquals($ClassMethod(tViewer, "Archetype"), "viewer (OpenAPI)", "on its own archetype")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Read).CriteriaParams(tViewer)), "application", "and it declares one criterion, the application")
    Do $$$AssertEquals($ClassMethod(tViewer, "Read").criteria.fields.%Get(0).maxLength, 256, "bounded at 256 characters")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Read).CriteriaParams(tExplorer)), 0, "the explorer declares none")
}

/// <p>Story 2.6 -- the users list's declaration passes the read grammar, its detail call included,
/// and the classic link rule; its route and tool identifier resolve to it; and its classic page is
/// a class compiled on this instance under the declaration's own case (AD-44).</p>
/// <p>Mutation: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -> the compiled-class assertion goes red.</p>
Method TestTheUsersListValidatesAndNamesItsClassicPageInItsOwnCase()
{
    Set tClass = "OcuPilot.Screen.Descriptor.UserList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read, detail call and table are the declared grammar")
    Do $$$AssertEquals(tDeclaration.read.source.rowGet.key, "Name", "and it declares the detail call by name")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("permissions/users"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("permissions.users"), tClass, "and so does its tool identifier")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Users", "the classic page is the vendor's users list")
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>Story 2.7 -- the SSL/TLS configurations list's declaration passes the read grammar and the
/// classic link rule; its route and tool identifier resolve to it; its four read fields are the ones
/// the vendor LIST answers and none of them is key material; and its classic page is a class
/// compiled on this instance under the declaration's own case (AD-44).</p>
/// <p>Mutations: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.SslConfigList</class> -> the compiled-class assertion goes
/// red; drop <code>Type</code> from its <code>read.filter</code> -> the filter pin goes red.</p>
Method TestTheSslConfigurationsListValidatesAndNamesItsClassicPageInItsOwnCase()
{
    Set tClass = "OcuPilot.Screen.Descriptor.SslConfigList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(tDeclaration.read.source.%GetTypeOf("rowGet"), "unassigned", "it declares no detail call, so no GET is ever issued")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("security/ssl"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("security.ssl"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""Description"",""Enabled"",""Type""]", "the four declared fields are the live LIST row's key set, in the vendor's order")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON(), "[""Name"",""Description"",""Type""]", "the filter matches on every field but the boolean")
    Do $$$AssertEquals(tDeclaration.read.sort.%ToJSON(), "{""fields"":[""Name"",""Description"",""Type""],""default"":""Name"",""direction"":""asc""}", "and the list sorts by name ascending")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "and the read carries no secret to strip")
    For tForbidden = "PrivateKeyPassword", "PrivateKeyFile", "PrivateKeyType", "CertificateFile", "CAFile", "CAPath" {
        Do $$$AssertEquals((tDeclaration.%ToJSON() [ tForbidden), 0, "no part of the declaration names " _ tForbidden)
    }

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.SSLList", "the classic page is the vendor's SSL/TLS configuration list")
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>Story 2.8 -- a banner outside the grammar is refused, as values here and over a real roster,
/// and the refusal reaches <method>OcuPilot.Screen.Registry.Validate</method> naming the offending
/// class. The corpus both engines run is <class>OcuPilot.Test.BannerCorpus</class>, driven from
/// <class>OcuPilot.Test.ReadTool</class>; what this adds is the wiring -- that
/// <method>Validate</method> calls the rule at all -- and the value-driven shapes the corpus does
/// not need a descriptor for.</p>
/// <p><b>Why a declared banner is refused rather than swallowed.</b>
/// <method>OcuPilot.Screen.Read.BannerKey</method> answers <code>""</code> on every fault, so a
/// misdeclared banner would render nothing and report nothing; this is where it is loud.</p>
/// <p>Mutation: delete the <method>OcuPilot.Screen.Registry.BannerProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> -> the fixture-roster assertions go red while
/// the shipped roster stays green either way.</p>
Method TestABannerOutsideTheGrammarIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.BannerRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a banner outside the grammar is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Banner.Bad", "the refusal names the offending class: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "banner.cases entry #1 severity 'error'", "and the value it is about")

    Set tSound = {"read":{},"banner":{"source":{"port":"admin","endpoint":"Task.Manager","type":"GET"},"field":"Status","cases":[{"equals":"Suspended","messageKey":"taskManagerSuspendedBanner","severity":"warning"}]}}
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tSound), "", "a sound banner on a read-declaring screen answers no problem")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem({}), "", "an absent banner is a screen with no banner")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem({"banner":null}), "", "and so is a null one")

    Set tProdSC = ##class(OcuPilot.Screen.Registry).Validate(.tProdProblem)
    Do $$$AssertEquals(tProdProblem, "", "while every shipped descriptor's banner is the declared grammar")
    Do $$$AssertStatusOK(tProdSC, "so the shipped roster validates")
}

/// <p>Story 2.8 -- the task schedule list's declaration passes the read, banner and classic link
/// rules; its route and tool identifier resolve to it; it declares the four auto-refresh rates and
/// no detail call; <code>Suspended</code> is absent from its read, its table and its agent context,
/// because the vendor LIST coerces it to false for every task; and its classic page is a class
/// compiled on this instance under the declaration's own case (AD-44).</p>
/// <p>Mutations: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -> the compiled-class assertion goes
/// red; drop <code>Namespace</code> from its <code>read.filter</code> -> the filter pin goes red;
/// declare <code>Suspended</code> as a read field or a column -> the absence assertions go red.
/// DW-304: change one declared banner case's <code>equals</code> value to a word the vendor's
/// <code>RunGet</code> does not spell -> the vendor-source assertion goes red naming it, together
/// with the typed-copy comparison above it. The two are not independent, and the vendor pin is not
/// here to separate them: it is here for the direction no typed copy can see, a vendor that
/// renames its own status word while the declaration and its copy still agree with each other.</p>
Method TestTheTaskScheduleListValidatesAndNamesItsClassicPageInItsOwnCase()
{
    Set tClass = "OcuPilot.Screen.Descriptor.TaskScheduleList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "and so is its banner")
    Do $$$AssertEquals(tDeclaration.read.source.%GetTypeOf("rowGet"), "unassigned", "it declares no detail call, so no GET is ever issued for a row")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("tasks/schedule"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("tasks.schedule"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""Type"",""Namespace"",""Description"",""Id"",""LastFinished"",""NextScheduled""]", "the seven declared fields are the live LIST row's key set less Suspended, in the vendor's order")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON(), "[""Name"",""Namespace"",""Type"",""Description""]", "the filter matches on every text field")
    Do $$$AssertEquals(tDeclaration.read.sort.%ToJSON(), "{""fields"":[""Name"",""Namespace"",""Type"",""Description"",""LastFinished"",""NextScheduled""],""default"":""Name"",""direction"":""asc""}", "and the list sorts by name ascending")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "and the read carries no secret to strip")
    ; The vendor LIST answers "Suspended":false for every task on this build, suspended ones
    ; included, so a column over it would read "No" above a suspended task. Absence from the read,
    ; the table and the context is the claim -- the banner's own `equals` is the word "Suspended"
    ; as the Task Manager's Status reads it, which is a different value on a different endpoint.
    Do $$$AssertEquals((tDeclaration.read.%ToJSON() [ "Suspended"), 0, "the read names no Suspended field, filter or sort")
    Do $$$AssertEquals((tDeclaration.table.%ToJSON() [ "Suspended"), 0, "and the table declares no Suspended column")
    Do $$$AssertEquals((tDeclaration.context.%ToJSON() [ "Suspended"), 0, "and the agent's context carries none either")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 1, "it is one of the auto-refresh screens")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the four declared rates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem($ClassMethod(tClass, "Refreshes"), $ClassMethod(tClass, "RefreshRates")), "", "which are a sound pair")
    Set tBanner = $ClassMethod(tClass, "Banner")
    Do $$$AssertTrue($IsObject(tBanner), "the banner accessor answers the declaration")
    If $IsObject(tBanner) {
        Do $$$AssertEquals(tBanner.source.endpoint, "Task.Manager", "whose source is the Task Manager endpoint")
        Do $$$AssertEquals(tBanner.source.type, "GET", "read with a GET")
        ; DW-270: one read, two (value -> sentence) cases over one field. `Not running` is the
        ; vendor's own word for status 0, and a stopped Task Manager runs no scheduled task either
        ; -- the single-case banner left that state silent.
        Do $$$AssertEquals(tBanner.field, "Status", "over the one field the manager reports")
        Do $$$AssertEquals(tBanner.cases.%ToJSON(), "[{""equals"":""Suspended"",""messageKey"":""taskManagerSuspendedBanner"",""severity"":""warning""},{""equals"":""Not running"",""messageKey"":""taskManagerStoppedBanner"",""severity"":""warning""}]", "raising the suspended sentence at Suspended and the stopped one at Not running, both warnings")
        Do $$$AssertEquals(tBanner.cases.%Size(), 2, "and Running, the third value the vendor answers, raises none")

        ; DW-304: the comparison above is against a typed copy of the same three words, which
        ; cannot catch the vendor changing its own spelling. Read RunGet's compiled source off the
        ; class dictionary and require each declared `equals` value, and the silent third value, to
        ; appear in it verbatim. The endpoint is resolved through the port (AD-27); nothing here
        ; names the administration API.
        Set tEndpointClass = ##class(OcuPilot.Port.AdminPort).EndpointClass(tBanner.source.endpoint)
        Do $$$AssertNotEquals(tEndpointClass, "", "the banner's endpoint resolves to a compiled vendor class through the port")
        If tEndpointClass '= "" {
            Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(tEndpointClass, "RunGet", , .tOpenSC)
            Do $$$AssertTrue($IsObject(tMethod), "the vendor endpoint compiles a RunGet method")
            If $IsObject(tMethod) {
                Do tMethod.Implementation.Rewind()
                Set tSource = tMethod.Implementation.Read(32000)
                Set tVendorChecked = 0
                Set tCaseIterator = tBanner.cases.%GetIterator()
                While tCaseIterator.%GetNext(.tCaseIdx, .tCase) {
                    Do $$$AssertTrue((tSource [ ("""" _ tCase.equals _ """")), "the vendor's own RunGet still spells the word '" _ tCase.equals _ "'")
                    Set tVendorChecked = tVendorChecked + 1
                }
                Do $$$AssertEquals(tVendorChecked, 2, "both declared cases were checked against the live vendor source")
                Do $$$AssertTrue((tSource [ """Running"""), "and the vendor's third, silent value is still spelled 'Running'")
            }
        }
    }

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.TaskSchedule", "the classic page is the vendor's task schedule")
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>Story 2.9 -- the processes list's declaration passes the read and classic link rules; its
/// route and tool identifier resolve to it; it declares the four auto-refresh rates, no detail call
/// and no banner; its read names the vendor's own <code>Nspace</code> key rather than
/// <code>Namespace</code>; none of the four <code>CanBe*</code> gates or the client and identity
/// fields Story 6.8 owns reaches the read, the table or the agent's context; and its classic page is
/// a class compiled on this instance under the declaration's own case (AD-44).</p>
/// <p>Mutations: rename <code>Nspace</code> to <code>Namespace</code> in
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> -> the <code>read.fields</code> pin goes
/// red (and so does <class>OcuPilot.Test.ScreenRead</class>'s drift guard, against the live row);
/// declare <code>CanBeTerminated</code> as a read field or a column -> the absence assertions go
/// red; drop a rate -> the rate pin goes red.</p>
Method TestTheProcessesListValidatesAndNamesTheVendorsNamespaceKey()
{
    Set tClass = "OcuPilot.Screen.Descriptor.ProcessList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "it declares no banner, which the banner rule admits")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("banner"), "unassigned", "and the key is absent rather than null")
    Do $$$AssertEquals(tDeclaration.read.source.%GetTypeOf("rowGet"), "unassigned", "it declares no detail call, so no GET is ever issued for a row")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/processes"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.processes"), tClass, "and so does its tool identifier")
    ; Nspace, not Namespace: the vendor LIST row's own key. A read declaring the reader's word
    ; would project null into every row rather than fail, so the spelling is pinned here on the
    ; declaration and against the live row in OcuPilot.Test.ScreenRead.
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Pid"",""Username"",""Nspace"",""Routine"",""State"",""Commands"",""Globals""]", "the seven declared fields carry the vendor's Nspace spelling")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON(), "[""Pid"",""Username"",""Nspace"",""Routine"",""State""]", "the filter matches on the five text fields, never on the two counters")
    Do $$$AssertEquals(tDeclaration.read.sort.%ToJSON(), "{""fields"":[""Pid"",""Username"",""Nspace"",""Routine"",""State"",""Commands"",""Globals""],""default"":""Pid"",""direction"":""asc""}", "every declared field is sortable, by process id ascending to begin with")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "and the read carries no secret to strip")
    ; The four CanBe* booleans gate the controls this story does not ship (Stories 5.12, 7.8 and
    ; 16.6), and the client and identity fields are Story 6.8's process details. Absence from the
    ; read, the table and the agent's context is the claim.
    For tAbsent = "CanBe", "CanReceive", "Device", "ClientName", "EXEname", "IPAddress", "OSUserName", "Job", "ParentPid", "PrvGblBlkCnt", "CPUTime", "ElapsedTime" {
        Do $$$AssertEquals((tDeclaration.read.%ToJSON() [ tAbsent), 0, "the read names no " _ tAbsent _ " field, filter or sort")
        Do $$$AssertEquals((tDeclaration.table.%ToJSON() [ tAbsent), 0, "and the table declares no " _ tAbsent _ " column")
        Do $$$AssertEquals((tDeclaration.context.%ToJSON() [ tAbsent), 0, "and the agent's context carries none either")
    }
    ; "Namespace" is checked over the read and the context alone: the table's own column carries
    ; the reader's word through headerNamespaceLabel, which contains the string by design.
    Do $$$AssertEquals((tDeclaration.read.%ToJSON() [ "Namespace"), 0, "the read names no Namespace field, filter or sort -- only the vendor's Nspace")
    Do $$$AssertEquals((tDeclaration.context.%ToJSON() [ "Namespace"), 0, "and neither does the agent's context")
    ; Pid is the name column, which is what the row key and the code face come from, and the two
    ; counters are the first `number` columns any shipped descriptor declares.
    Do $$$AssertEquals(tDeclaration.table.columns.%ToJSON(), "[{""field"":""Pid"",""labelKey"":""processColumnPid"",""kind"":""name""},{""field"":""Username"",""labelKey"":""processColumnUser"",""kind"":""text""},{""field"":""Nspace"",""labelKey"":""headerNamespaceLabel"",""kind"":""text""},{""field"":""Routine"",""labelKey"":""processColumnRoutine"",""kind"":""identifier""},{""field"":""State"",""labelKey"":""processColumnState"",""kind"":""text""},{""field"":""Commands"",""labelKey"":""processColumnCommands"",""kind"":""number""},{""field"":""Globals"",""labelKey"":""processColumnGlobals"",""kind"":""number""}]", "seven columns, Pid the name one and the two counters numeric")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 1, "it is one of the auto-refresh screens")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the four declared rates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem($ClassMethod(tClass, "Refreshes"), $ClassMethod(tClass, "RefreshRates")), "", "which are a sound pair")
    ; Order matters: OcuPilot.Screen.Gate.EvaluatePairs names the FIRST pair a caller does not
    ; hold, and both wire fixtures pin that name.
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "the endpoint's own gate first, the CONTROLPANEL query's check second, the database read third")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", "and the os-management area covers all three")
    ; DW-275, the half that stops the decision being reversed by accident: %Admin_Manage:USE is in
    ; the area's own set, and dropping it there makes this screen fail coverage at install rather
    ; than making the narrower screens reachable.
    Set tAreaPairs = ##class(OcuPilot.Screen.Area).PrivilegePairs("os-management")
    Set tHasManage = 0
    For tI = 1:1:$ListLength(tAreaPairs) {
        If ($List($List(tAreaPairs, tI), 1) = "%Admin_Manage") && ($List($List(tAreaPairs, tI), 2) = "USE") Set tHasManage = 1
    }
    Do $$$AssertEquals(tHasManage, 1, "the os-management area declares the union, %Admin_Manage:USE included (DW-275)")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Processes", "the classic page is the vendor's processes list, not its process details")
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>Story 2.10 AC7 -- a roster whose criteria block is outside the grammar is refused by
/// <method>OcuPilot.Screen.Registry.Validate</method> naming the class and the sentence, which is
/// what pins the <b>wiring</b> of the rule rather than the rule itself: every other grammar refusal
/// in <method>Validate</method> has a fixture registry of its own for the same reason.</p>
/// <p>Mutation: delete the <code>CriteriaProblem</code> arm from
/// <method>OcuPilot.Screen.Registry.Validate</method> -> this goes red and nothing else does, since
/// every other criteria test calls <method>CriteriaProblem</method> as a value.</p>
Method TestCriteriaOutsideTheGrammarAreRefusedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Test.CriteriaRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying criteria outside the grammar is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Criteria.Bad", "the refusal names the offending class: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "kind 'choice' declares no options", "and the rule it broke")

    Set tProdSC = ##class(OcuPilot.Screen.Registry).Validate(.tProdProblem)
    Do $$$AssertEquals(tProdProblem, "", "while every shipped descriptor's criteria are the declared grammar")
    Do $$$AssertStatusOK(tProdSC, "so the shipped roster validates")
}

/// <p>Whether <var>pList</var>, a declared field-name array, names <var>pField</var>.</p>
ClassMethod NamesField(pList As %DynamicArray, pField As %String) As %Boolean
{
    If '$IsObject(pList) Quit 0
    Set tFound = 0
    Set tIterator = pList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If tName = pField Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Whether <var>pColumns</var>, a declared table-column array, renders <var>pField</var>.</p>
ClassMethod NamesColumn(pColumns As %DynamicArray, pField As %String) As %Boolean
{
    If '$IsObject(pColumns) Quit 0
    Set tFound = 0
    Set tIterator = pColumns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        If $IsObject(tColumn) && (tColumn.%Get("field") = pField) Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Story 2.10 AC1 -- the audit database viewer's declaration is the whole of what the screen is:
/// its route, its archetype, its composite id, the eight criteria it searches the server with over
/// nine parameters, the agent-marker filter that overrides one of them, the twenty-four fields the
/// vendor LIST answers and the twenty-three the model sees, its eight columns, and its three
/// privilege pairs in the order the gate reports in.</p>
/// <p>Mutations: drop the <code>beginDateTime</code> entry from
/// <code>read.criteria.fields</code> -> the criteria roster assertion goes red on the declaration.
/// Change <code>read.criteria.marker.value</code> from <code>OcuPilot</code> -> the marker
/// assertion goes red. Add <code>EventData</code> to <code>context.fields</code> -> the
/// untrusted-blob assertion goes red. Declare <code>refreshes</code> true -> the
/// <method>OcuPilot.Screen.Registry.CriteriaProblem</method> assertion goes red naming the
/// pair.</p>
Method TestTheAuditListValidatesAndDeclaresItsServerCriteria()
{
    Set tClass = "OcuPilot.Screen.Descriptor.AuditList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so are its server-search criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "it declares no banner, which the banner rule admits")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("banner"), "unassigned", "and the key is absent rather than null")
    Do $$$AssertEquals(tDeclaration.read.source.%GetTypeOf("rowGet"), "unassigned", "it declares no detail call: the endpoint's GET answers no key the LIST row lacks")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("logs/audit"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("logs.audit"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list (server criteria)", "it is the first screen of the server-criteria archetype")

    ; The eight criteria the amended FR-61 names, over nine parameters, each spelling the vendor's
    ; own (%Api.Admin.Endpoints.Security.Audit.Record.RunList's GetQueryParam block). systemIDs,
    ; ascending and jsonSearch are real parameters this screen deliberately does not declare.
    Set tParams = ""
    Set tIterator = tDeclaration.read.criteria.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tParams = tParams _ $Select(tParams = "": "", 1: ",") _ tField.%Get("param")
    }
    Do $$$AssertEquals(tParams, "beginDateTime,endDateTime,eventSources,eventTypes,events,usernames,pids,namespaces,authentication", "nine declared parameters, authentication singular as the vendor spells it")
    ; Over the roster the walk above built, never over the node's JSON: a substring of a label key
    ; or an option would answer for a parameter, which is the reading this project's own pitfalls
    ; name.
    For tAbsent = "systemIDs", "ascending", "jsonSearch" {
        Do $$$AssertEquals($ListFind($ListFromString(tParams, ","), tAbsent), 0, "the criteria roster declares no " _ tAbsent _ " parameter")
    }
    ; The one choice criterion, and why: an unrecognized authentication name converts to -1 on the
    ; instance and matches nearly every row, so the value is held to a declared enum instead.
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).CriteriaParams(tClass), $ListFromString(tParams, ","), "and the executor's allow-list is that same roster")
    Set tChoice = tDeclaration.read.criteria.fields.%Get(8)
    Do $$$AssertEquals(tChoice.%Get("param"), "authentication", "the ninth parameter is the authentication mechanism")
    Do $$$AssertEquals(tChoice.%Get("kind"), "choice", "declared as a closed choice, never free text")
    Do $$$AssertEquals(tChoice.options.%Size(), 11, "over the eleven display names this screen declares")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "which the criteria grammar admits")

    ; The marker names a criterion the form already carries, which is what makes it an override
    ; rather than a tenth parameter: both name eventSources, and the vendor matches a comma list by
    ; membership, so appending would widen the result (AD-46).
    Do $$$AssertEquals(tDeclaration.read.criteria.marker.%ToJSON(), "{""param"":""eventSources"",""value"":""OcuPilot"",""labelKey"":""auditMarkerFilterLabel""}", "the marker filter is a Source filter over OcuPilot's own audit Source")
    Do $$$AssertEquals(tDeclaration.read.criteria.marker.%Get("value"), $Parameter("OcuPilot.Kernel.State.Base", "AUDITSOURCE"), "which is the Source the installer registers and every marker carries (AD-15)")

    ; EventData is read -- the dialog renders it -- and never enters the context the model sees
    ; (AD-11, AD-24). Authentication is read and never rendered as a column: it arrives as the
    ; stored logical integer while the criterion beside it takes display names.
    Do $$$AssertEquals(tDeclaration.read.fields.%Size(), 24, "the read projects all twenty-four LIST keys")
    Do $$$AssertEquals(tDeclaration.context.fields.%Size(), 23, "and the context carries one fewer")
    ; Over the field and column lists themselves, never over the node's JSON: read.criteria's own
    ; labelKey is auditCriteriaAuthentication, so a substring test against read.%ToJSON() would
    ; answer true with Authentication gone from read.fields entirely.
    Do $$$AssertEquals(..NamesField(tDeclaration.read.fields, "EventData"), 1, "EventData is read, for the detail dialog")
    Do $$$AssertEquals(..NamesField(tDeclaration.context.fields, "EventData"), 0, "and never enters the context the model is handed (AD-11, AD-24)")
    Do $$$AssertEquals(..NamesField(tDeclaration.read.fields, "Authentication"), 1, "Authentication is read")
    Do $$$AssertEquals(..NamesColumn(tDeclaration.table.columns, "Authentication"), 0, "and is not a column, because the row carries the logical integer")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "the read carries no secret to strip: a secret never reaches the screen either")

    Do $$$AssertEquals(tDeclaration.table.columns.%ToJSON(), "[{""field"":""TimeStamp"",""labelKey"":""auditColumnTime"",""kind"":""text""},{""field"":""EventSource"",""labelKey"":""auditColumnEventSource"",""kind"":""text""},{""field"":""EventType"",""labelKey"":""auditColumnEventType"",""kind"":""text""},{""field"":""Event"",""labelKey"":""auditColumnEventName"",""kind"":""name""},{""field"":""Username"",""labelKey"":""processColumnUser"",""kind"":""text""},{""field"":""Pid"",""labelKey"":""processColumnPid"",""kind"":""identifier""},{""field"":""Namespace"",""labelKey"":""headerNamespaceLabel"",""kind"":""text""},{""field"":""Description"",""labelKey"":""tableColumnDescription"",""kind"":""text""}]", "eight columns, the event name the one that links to the detail dialog")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""composite"",""parts"":[""UTCTimeStamp"",""SystemID"",""AuditIndex""]}", "the id is the record's own IDKEY order, joined into one segment (AD-13)")

    ; EXPERIENCE.md exempts this screen from the refreshing roster by name: it renders nothing
    ; until Search, so a timer would have no rows to re-read.
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it never auto-refreshes")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RefreshRates")), 0, "and declares no rate")

    ; Order matters: OcuPilot.Screen.Gate.EvaluatePairs names the FIRST pair a caller does not
    ; hold, and AC5's denial is observed on the second.
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Secure"",""permission"":""USE""},{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "the endpoint's own gate first, the async-result poll's second, the database read third")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("logs", $ClassMethod(tClass, "PrivilegePairs")), "", "and the logs area covers all three")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Audit.View", "the classic page is the vendor's audit list, not its audit detail")
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
    Do $$$AssertTrue($IsObject(tCompiled), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>DW-279 -- every declared <code>maxLength</code> is the bound the criterion's own vendor
/// property carries on this instance, read from the class dictionary rather than typed here.</p>
/// <p><b>The vendor class is resolved through the port</b> (AD-27):
/// <method>OcuPilot.Port.AdminPort.EndpointClass</method> answers the endpoint the descriptor
/// declares, and the request's task class is that name plus the request type's own suffix.
/// Nothing here names the administration API, which is what keeps its blast radius at one file.</p>
/// <p>Without this the nine bounds are numbers a probe once read: a vendor narrowing would leave
/// the screen admitting at 1000 what the instance now refuses at 50, and the refusal the caller
/// meets would come from inside the port again, naming nothing.</p>
/// <p>Mutation: change one declared <code>maxLength</code> in
/// <class>OcuPilot.Screen.Descriptor.AuditList</class> -&gt; that criterion's assertion goes red
/// naming it, and only it. Rename a vendor property -&gt; the mapping assertion goes red and the
/// count below refuses the shortened walk, so a lookup that found nothing is not read as a pass.</p>
Method TestTheAuditCriteriaBoundsAreTheVendorPropertysOwn()
{
    Set tClass = "OcuPilot.Screen.Descriptor.AuditList"
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the audit list declares a read")
    If '$IsObject(tRead) Quit

    Set tEndpointClass = ##class(OcuPilot.Port.AdminPort).EndpointClass(tRead.source.%Get("endpoint"))
    Do $$$AssertNotEquals(tEndpointClass, "", "the declared endpoint resolves to a compiled vendor class through the port")
    If tEndpointClass = "" Quit
    Set tType = tRead.source.%Get("type")
    Set tTaskClass = tEndpointClass _ $ZConvert($Extract(tType), "U") _ $ZConvert($Extract(tType, 2, *), "L") _ "Task"
    Do $$$AssertEquals(''##class(%Dictionary.CompiledClass).%ExistsId(tTaskClass), 1, "and its request class is compiled here: " _ tTaskClass)
    If '##class(%Dictionary.CompiledClass).%ExistsId(tTaskClass) Quit

    Set tChecked = 0
    Set tIterator = tRead.criteria.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tParam = tField.%Get("param")
        ; The vendor spells the same parameter with a leading capital; nothing else differs.
        Set tProperty = $ZConvert($Extract(tParam), "U") _ $Extract(tParam, 2, *)
        Set tProp = ##class(%Dictionary.CompiledProperty).IDKEYOpen(tTaskClass, tProperty, , .tOpenSC)
        Do $$$AssertTrue($IsObject(tProp), tParam _ " maps to the vendor property " _ tProperty)
        If '$IsObject(tProp) Continue
        Do $$$AssertEquals(tField.%Get("maxLength"), tProp.Parameters.GetAt("MAXLEN"), tParam _ " declares the MAXLEN its vendor property carries")
        Set tChecked = tChecked + 1
    }
    ; A walk that found nothing is not a pass -- the count is what stops a renamed property from
    ; turning this into a loop over none.
    Do $$$AssertEquals(tChecked, 9, "all nine declared criteria were checked against the live dictionary")
}

/// <p>Story 2.12 AC1, AC4, AC6 -- the application error log's declaration is the whole of what that
/// screen is, asserted key by key rather than through <method>OcuPilot.Screen.Registry.Validate</method>
/// alone (DW-271: a misspelt top-level key installs silently, because an accessor that cannot find
/// its key answers <code>""</code> and a validator that never asks does not notice).</p>
/// <p>The four claims that are this story's own: it declares <b>no read</b>, which is what sends
/// its tool to the registry's other source; its <code>context.fields</code> carry the five summary
/// fields and no captured detail; its privilege set is the <b>two</b> pairs that do not depend on
/// a namespace -- <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, the database
/// <code>SYS.ApplicationError</code> is executed from -- while the read and write on the
/// <i>selected</i> namespace's globals database are resolved at the port per call, because no
/// static resource can express them; and its scope is <code>instance</code>, because the screen
/// enumerates namespaces itself and the route's <code>?ns=</code> does not reach it (AD-48).</p>
/// <p>Mutations: add a <code>read</code> block -&gt; the read assertion goes red and
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method> refuses the name two sources then
/// claim. Add a <code>%DB_HSCUSTOM:READ</code> pair -&gt; the privilege assertion goes red and so
/// does <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method>. Add a field to
/// <code>context.fields</code> -&gt; the summary-field assertion goes red.</p>
Method TestTheApplicationErrorLogDeclaresNoReadAndGatesOnItsNamespaceFreePairs()
{
    Set tClass = "OcuPilot.Screen.Descriptor.LogErrorList"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    ; Every top-level key the declaration carries, read off the block itself: a misspelt key is an
    ; extra name here and a missing one, which is what DW-271 makes invisible to Validate.
    Set tKeys = ""
    Set tIterator = tDeclaration.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "route,area,labelKey,sideBarPosition,archetype,built,refreshes,refreshRates,privileges,entityType,secondaryEntityTypes,scope,parentScope,id,primaryAction,rowActions,context,emptyStateKey,commandAliases,classicPage,classicLinkExemption,toolIdentifier", "the twenty-two declared keys, and no read, table, banner or criteria among them: " _ tKeys)

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "a declaration with no read is a supported shape")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and it declares no criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "and no banner")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and links out to nothing, as a list-classified archetype must")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "the accessor answers no read at all")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("logs/errors"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("logs.applicationerrors"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "drill-down", "it is the first screen of the drill-down archetype")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("drill-down"), "list", "which the vocabulary classifies as a list")

    ; The five AD-48 summary fields and nothing else: the captured variable table never enters the
    ; context a turn sends, because it is never in this list to be stripped from it.
    Do $$$AssertEquals(tDeclaration.context.%ToJSON(), "{""fields"":[""errorNumber"",""time"",""errorText"",""routine"",""line""],""secretFields"":[]}", "the five summary fields, and no captured detail among them (AD-48)")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""composite"",""parts"":[""namespace"",""date"",""errorNumber""]}", "one entry is identified by namespace, date and number together (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", "the route carries no namespace: the screen enumerates them itself (AD-48)")

    ; Two pairs, both namespace-free. The read and write this screen also needs on the SELECTED
    ; namespace's globals database are resolved at the port per call; a %DB_<ns> pair declared here
    ; would be refused by the area's own coverage besides.
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "two declared pairs: the classic portal's own key for these screens, and the database SYS.ApplicationError is executed from")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("logs", $ClassMethod(tClass, "PrivilegePairs")), "", "and the logs area covers both")

    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it never auto-refreshes: EXPERIENCE.md's roster does not name it (AD-43)")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RefreshRates")), 0, "and declares no rate")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, "and no row action: the three delete scopes are Epic 5's")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", "and no primary action")

    ; The classic page, checked through the portal's OWN resolver rather than through
    ; %Dictionary.CompiledClass. The four classic application-error pages are CSP pages compiled
    ; into %cspapp.op.*, which is not mapped into the install namespace -- %ExistsId answers 0 for
    ; them here, and the other descriptors' check would report a correct declaration as a missing
    ; class. What AD-44 actually needs is that the key an operator's custom resource is stored
    ; under resolves, and %SYS.Portal.Resources.NormalizePage is what decides that: it falls back
    ; to $system.CLS.DumpContext, which does find them from here.
    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%cspapp.op.utilsysapperrornamespaces", "the classic page is the drill's own entry point")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert(tPage, "O", "URL")), tPage, "which the portal's own resolver recognises from the install namespace, so a custom resource assigned to it is honoured (AD-44)")
    ; The same page reached the way an operator reaches it, which is what makes the value above the
    ; classic portal's own key rather than a plausible-looking class name.
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("/csp/sys/op/UtilSysAppErrorNamespaces.csp", "O", "URL")), tPage, "and which the classic URL normalises to")
}

/// <p>Story 6.13 -- the alerts.log viewer declares the log file's own tail as its read source, the
/// one pair the port behind it declares, a <code>none</code> id, no action and no refresh, and it
/// takes the Logs area's first side-bar position.</p>
/// <p>The screen's pair set is exactly <parameter>OcuPilot.Port.LogSourcePort.ALERTSPAIRS</parameter>,
/// so the gate a user meets is the same whichever way the screen reads.
/// <code>%Admin_Secure:USE</code> is deliberately absent: this screen reads no security endpoint,
/// and the area's set is a union rather than a per-screen requirement (DW-278).</p>
/// <p>Mutation: point the read's source at <code>{"port": "monitor"}</code> -&gt; the registry's own
/// read arm refuses the declaration and the validation assertion goes red.</p>
Method TestTheAlertLogViewerDeclaresTheLogSourceTailAndItsOnePair()
{
    Set tClass = "OcuPilot.Screen.Descriptor.LogAlertViewer"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing, as a list-classified archetype must")

    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""logsource"",""endpoint"":""alerts"",""type"":""LIST""}", "the log file's own bounded tail is the read's source (AD-36)")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Port.LogSourcePort).Sources(), tDeclaration.read.source.endpoint) > 0, "and its endpoint is a key of that port's fixed enum (AD-21)")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""time"",""severity"",""text""]", "three declared fields")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""}]", "one declared pair, and no %Admin_Secure:USE (DW-278)")
    Set tPortPairs = ##class(OcuPilot.Port.LogSourcePort).PairsFor("alerts")
    Do $$$AssertEquals($ListLength(tPortPairs), 1, "which the port behind it declares too")
    If $ListLength(tPortPairs) = 1 Do $$$AssertEquals($ListToString($List(tPortPairs, 1), ":"), "%Admin_Operate:USE", "as the same pair, so neither way in is the wider gate")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("logs", $ClassMethod(tClass, "PrivilegePairs")), "", "and the logs area covers it, so its own declaration is untouched")

    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""none"",""parts"":[]}", "a log line is not an entity the instance can be asked for again (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "log-viewer", "it is the first screen of the log-viewer archetype")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("log-viewer"), "list", "which the vocabulary classifies as a list")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("logs/alerts"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("logs.alerts"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 1, "it is the Logs area's first side-bar entry")

    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "nothing streams: it never auto-refreshes (AD-43)")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RefreshRates")), 0, "and declares no rate")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, "no row action (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", "and no primary action")
}

/// <p>Story 6.14 -- the messages.log viewer declares the console log's own tail as its read source,
/// the one pair the port behind it declares, a <code>none</code> id, no action and no refresh, and
/// it takes the Logs area's <b>second</b> side-bar position.</p>
/// <p>The position is asserted here and as an order in
/// <method>OcuPilot.Test.Navigation.TestThePayloadCarriesEveryAreaWithAVerdict</method>: this leg
/// says what the descriptor declares, that one says where the payload puts it.</p>
/// <p>The <code>messages.log</code> command alias is asserted because the shell's fault banner
/// resolves "Open messages.log" from it (AD-5, DW-148), so it is a published name and not a
/// convenience.</p>
/// <p>Mutation: change the read's <code>endpoint</code> to <code>alerts</code> -&gt; the source
/// assertion goes red naming the other file, while the alerts.log leg above stays green.</p>
Method TestTheConsoleLogViewerDeclaresTheLogSourceTailAndItsOnePair()
{
    Set tClass = "OcuPilot.Screen.Descriptor.LogMessageViewer"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing, as a list-classified archetype must")

    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""logsource"",""endpoint"":""messages"",""type"":""LIST""}", "the console log's own bounded tail is the read's source (AD-36)")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Port.LogSourcePort).Sources(), tDeclaration.read.source.endpoint) > 0, "and its endpoint is a key of that port's fixed enum (AD-21)")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""time"",""severity"",""text""]", "three declared fields")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""}]", "one declared pair, and no %Admin_Secure:USE (DW-278)")
    Set tPortPairs = ##class(OcuPilot.Port.LogSourcePort).PairsFor("messages")
    Do $$$AssertEquals($ListLength(tPortPairs), 1, "which the port behind it declares too")
    If $ListLength(tPortPairs) = 1 Do $$$AssertEquals($ListToString($List(tPortPairs, 1), ":"), "%Admin_Operate:USE", "as the same pair, so neither way in is the wider gate")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("logs", $ClassMethod(tClass, "PrivilegePairs")), "", "and the logs area covers it, so its own declaration is untouched")

    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""none"",""parts"":[]}", "a log line is not an entity the instance can be asked for again (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "log-viewer", "it renders the shared log-viewer archetype")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("logs/messages"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("logs.messages"), tClass, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 2, "it is the Logs area's second side-bar entry")
    Do $$$AssertTrue($ListFind($ClassMethod(tClass, "CommandAliases"), "messages.log") > 0, "and it publishes the messages.log alias the fault banner resolves its destination from: " _ $ListToString($ClassMethod(tClass, "CommandAliases"), ","))

    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "nothing streams: it never auto-refreshes (AD-43)")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RefreshRates")), 0, "and declares no rate")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, "no row action (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", "and no primary action")
}


/// <p>Story 2.7 AC7 (DW-266) -- a screen declaring a pair its area does not is refused by
/// <method>OcuPilot.Screen.Registry.Validate</method> naming the class, the area and the pair;
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> answers the same sentence for an
/// uncovered set and <code>""</code> for a covered one; and the production roster still validates
/// now that every area covers its screens.</p>
/// <p><b>Why the refusal matters:</b> <class>OcuPilot.Screen.Gate</class> evaluates an area's set
/// and a screen's set separately and never unions them, so an area declaring less than its screens
/// require shows the rail item allowed and refuses everything inside it.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> answer
/// <code>""</code> unconditionally -> the fixture-roster and value assertions go red. Drop
/// <code>%DB_IRISSYS:READ</code> from the <code>security</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the production-roster leg goes red.</p>
Method TestAnAreaThatDoesNotCoverItsScreensPairsIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.AreaPairRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster whose screen names a pair its area does not is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.AreaPair.Bad", "the refusal names the offending class: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "area 'logs'", "and the area")
    ; %Admin_Manage:USE since Story 2.10, because the audit database viewer made the Logs area
    ; declare the %Admin_Secure:USE this fixture used to be uncovered on. The pair a coverage
    ; fixture names has to be one its area still does not declare, or the fixture pins nothing.
    Do $$$AssertTrue(tProblem [ "%Admin_Manage:USE", "and the pair the area does not declare")

    Set tCovered = $ListBuild($ListBuild("%Admin_Secure", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", tCovered), "", "a set the area covers answers no problem")
    Set tSubset = $ListBuild($ListBuild("%Admin_Secure", "USE"))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", tSubset), "", "so does a set the area declares more than")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", ""), "", "and so does an empty set")
    Set tUncovered = $ListBuild($ListBuild("%Admin_Operate", "USE"))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", tUncovered), "area 'security' does not declare %Admin_Operate:USE, which this screen requires, so the area would read allowed while the screen is refused (AD-8)", "an uncovered pair answers the sentence Validate prefixes")
    ; The method names the FIRST uncovered pair, so a covered pair ahead of it is skipped and a
    ; second uncovered one behind it is not the one reported.
    Set tMixed = $ListBuild($ListBuild("%Admin_Secure", "USE"), $ListBuild("%Admin_Operate", "USE"), $ListBuild("%Admin_Task", "USE"))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", tMixed), "area 'security' does not declare %Admin_Operate:USE, which this screen requires, so the area would read allowed while the screen is refused (AD-8)", "and the first uncovered pair is the one named, past a covered one and ahead of a second uncovered one")

    Set tProdSC = ##class(OcuPilot.Screen.Registry).Validate(.tProdProblem)
    Do $$$AssertEquals(tProdProblem, "", "and every production area covers its own screens' pairs")
    Do $$$AssertStatusOK(tProdSC, "so the shipped roster validates")
}

/// <p>Story 3.5 -- <method>OcuPilot.Screen.Registry.SideBarPositionProblem</method> refuses a
/// built screen that does not declare <code>sideBarPosition</code> as a whole number of at least
/// 0, and admits 0 itself.</p>
/// <p><b>Why the rule needed one.</b>
/// <method>OcuPilot.Screen.Descriptor.Base.SideBarPosition</method> is <code>+..Field(...)</code>,
/// so an absent key already reads as 0. Once 0 is the sentinel for routable-but-unlisted, a
/// descriptor that merely forgot the key would go silently unlisted with nothing red anywhere --
/// which is exactly what a rule that refuses nothing would also do, so the refusals are asserted
/// as values here rather than only the admission.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Registry.SideBarPositionProblem</method> answer
/// <code>""</code> unconditionally -> every refusal assertion below goes red.</p>
Method TestAnUndeclaredSideBarPositionIsRefusedOnABuiltScreen()
{
    Set tAbsent = {"built": true}
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tAbsent) [ "not declared as a number", "an absent key is refused rather than read as 0: " _ ##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tAbsent))
    Set tString = {"built": true, "sideBarPosition": "1"}
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tString) [ "not declared as a number", "and so is a position declared as a string")
    Set tNegative = {"built": true, "sideBarPosition": -1}
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tNegative) [ "whole number of at least 0", "a negative position is refused: " _ ##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tNegative))
    Set tFraction = {"built": true, "sideBarPosition": 1.5}
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tFraction) [ "whole number of at least 0", "and so is a fractional one")

    Set tSentinel = {"built": true, "sideBarPosition": 0}
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tSentinel), "", "0 is the sentinel for routable but not listed, not a fault")
    Set tListed = {"built": true, "sideBarPosition": 4}
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tListed), "", "and an ordinary position is sound")
    ; An unbuilt screen is listed by nothing and routed by nothing, so its position says nothing
    ; yet -- which is the rule's other half and the reason it cannot simply require the key.
    Set tUnbuilt = {"built": false}
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tUnbuilt), "", "an unbuilt screen is exempt")

    Set tProdSC = ##class(OcuPilot.Screen.Registry).Validate(.tProdProblem)
    Do $$$AssertEquals(tProdProblem, "", "and every shipped descriptor declares one")
    Do $$$AssertStatusOK(tProdSC, "so the shipped roster validates")
}

/// <p>The abstract base lives in the descriptor package and is not a screen. A registry that
/// enumerated it would try to read a declaration it does not carry and refuse a sound
/// roster.</p>
Method TestTheBaseClassIsNotEnumerated()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the descriptor list builds")
    Do $$$AssertEquals($ListFind(tList, "OcuPilot.Screen.Descriptor.Base"), 0, "the abstract base is not a descriptor")
    Do $$$AssertTrue($ListFind(tList, ..#HOMEDESCRIPTOR) > 0, "while a real descriptor is")
}

/// <p>A class that sits in the descriptor package without extending the base is not a
/// descriptor and is not enumerated. The package prefix says where a class lives, not what it
/// is, and a misplaced class that reached the roster would raise
/// <code>&lt;METHOD DOES NOT EXIST&gt;</code> on the first accessor -- taking down
/// <method>OcuPilot.Screen.Registry.Roster</method> and with it
/// <code>GET /api/ocupilot/navigation</code>, which leaves the client with no map and every
/// area reading ungated.</p>
/// <p>Mutation: drop the <code>%Extends</code> filter from
/// <method>OcuPilot.Screen.Registry.Descriptors</method> -> the membership assertion goes red
/// and both the roster and the validation assertions below it go red with it, because
/// <class>OcuPilot.Test.Screen.Stray</class> answers no accessor.</p>
Method TestAClassInThePackageThatIsNotADescriptorIsNotEnumerated()
{
    Set tSC = ##class(OcuPilot.Test.ScreenRegistry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the fixture descriptor list builds")
    Do $$$AssertEquals($ListFind(tList, "OcuPilot.Test.Screen.Stray"), 0, "a class in the package that does not extend the base is not a descriptor")
    Do $$$AssertTrue($ListFind(tList, "OcuPilot.Test.Screen.Multi") > 0, "while one that does extend it still is")

    Set tRosterSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 0, .tAll)
    Do $$$AssertStatusOK(tRosterSC, "and the roster walk does not throw on it")

    Set tValidateSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "nor does validation refuse a sound roster because of it")
    Do $$$AssertStatusOK(tValidateSC, "and the refusal travels in the status too")
}

/// <p>AC3, the multi-entity form -- a screen administering several entity types declares a
/// primary plus secondaries, and all of them participate in change-event routing.</p>
/// <p>Mutation: move <code>"oauth2-server-definition"</code> out of
/// <class>OcuPilot.Test.Screen.Multi</class>'s secondaries -> the count and the membership
/// assertions go red, while the primary stays green.</p>
Method TestAMultiEntityDescriptorDeclaresPrimaryAndSecondaryTypes()
{
    Set tClass = "OcuPilot.Test.Screen.Multi"
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "oauth2-client-configuration", "the primary type drives the route and the change-event key")
    Set tSecondary = $ClassMethod(tClass, "SecondaryEntityTypes")
    Do $$$AssertEquals($ListLength(tSecondary), 2, "two secondary types are declared")
    Do $$$AssertTrue($ListFind(tSecondary, "oauth2-server-definition") > 0, "the server definition is one of them")
    Do $$$AssertTrue($ListFind(tSecondary, "oauth2-resource-server") > 0, "and the resource server is the other")

    Set tAll = $ClassMethod(tClass, "EntityTypes")
    Do $$$AssertEquals($ListLength(tAll), 3, "all three participate in change-event routing")
    Do $$$AssertEquals($List(tAll, 1), "oauth2-client-configuration", "with the primary first")

    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExempt"), "and the exemption flag is readable")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExemptionReason") '= "", "with the reason AD-44 requires alongside it")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkLabel") '= "", "the classic page's own name, which labels the card's action")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkHref"), "/csp/sys/OcuPilotTestClassicPageMulti.csp", "and the declared target, which is never derived from classicPage")
}

/// <p>AD-44's vocabulary half -- <code>archetype</code> is a closed vocabulary with a link-out
/// class per key, which is what gives "only a detail view may declare a classic link-out" a
/// predicate to evaluate. While it was free text, a typo answered "not a detail view" and
/// passed.</p>
/// <p>Mutation: change <code>form-page</code>'s <code>linkOut</code> in
/// <class>OcuPilot.Screen.Archetype</class> to <code>none</code> -> the
/// <method>MayLinkOut</method> assertion goes red, and so does
/// <method>TestEveryClassicLinkCorpusCaseGetsItsSentence</method>'s <code>form-page</code> case.</p>
Method TestTheArchetypeVocabularyIsClosedAndClassified()
{
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).Exists("list"), "a declared key is known")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).Exists("form-page (tabs)"), "including one whose spelling carries a space and parentheses")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).Exists("lst"), "a near miss is not")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).Exists(""), "and neither is the empty string")
    ; Pinned to a literal. Comparing Count() with the size of List() restates Count()'s own
    ; definition and cannot fail, so a key dropped from the block would go unnoticed.
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).Count(), 16, "sixteen keys: EXPERIENCE.md's twelve state-matrix rows, the form row holding three, plus shell and external")

    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("list"), "list", "a list archetype is classified list")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("log-viewer"), "list", "and so is a viewer of rows under another name")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("form-page"), "detail", "a reduced form is a form-page, which is a detail view")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("home"), "none", "and Home is neither")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Archetype).LinkOutClass("lst"), "", "an undeclared key has no classification")

    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut("detail"), "only a detail view may link out")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut("wizard"), "which the wizard archetype is")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("list"), "a list archetype never does")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("drill-down"), "nor one classified list under another name")
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("meters"), "nor one classified neither")
    ; The default is refusal, so a mis-classification refuses a link rather than permitting one.
    Do $$$AssertTrue('##class(OcuPilot.Screen.Archetype).MayLinkOut("lst"), "and an archetype outside the vocabulary fails closed")
}

/// <p>AD-44 and DW-186 -- every case in <class>OcuPilot.Test.ClassicLinkCorpus</class> gets its exact
/// sentence, or none, from <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method>, the same
/// corpus <file>ui/tools/classic-links.test.mjs</file> runs through <code>classicLinkProblem</code>;
/// every archetype key the vocabulary declares has its exemption case there; and a roster carrying a
/// forbidden exemption is refused by <method>OcuPilot.Screen.Registry.Validate</method>.</p>
/// <p>Mutation: drop the exempt-type check from
/// <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method> -> the <code>exempt 1</code> case
/// goes red.</p>
Method TestEveryClassicLinkCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.ClassicLinkCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Kill tExemptKey, tPlainKey
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tCase.declaration), tExpected, tCase.name)
        Set tExemption = tCase.declaration.%Get("classicLinkExemption")
        If '$IsObject(tExemption) || (tExemption.%GetTypeOf("exempt") '= "boolean") Continue
        If tExemption.exempt && (tExemption.reason '= "") && (tExemption.label '= "") && (tExemption.href = "/csp/sys/OcuPilotTestClassicPage.csp") && (tCase.declaration.classicPage '= "") Set tExemptKey(tCase.declaration.archetype) = ""
        If 'tExemption.exempt && (tExemption.label = "") && (tExemption.href = "") && (tCase.%GetTypeOf("expected") = "null") Set tPlainKey(tCase.declaration.archetype) = ""
    }

    Set tSC = ##class(OcuPilot.Screen.Archetype).List(.tArchetypes)
    Do $$$AssertStatusOK(tSC, "the vocabulary reads")
    Set tIterator = tArchetypes.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArchetype) {
        Do $$$AssertTrue($Data(tExemptKey(tArchetype.key)), "the corpus holds a complete exemption for archetype " _ tArchetype.key)
        Do $$$AssertTrue($Data(tPlainKey(tArchetype.key)), "and a sound declaration with no exemption for archetype " _ tArchetype.key)
    }

    Set tSC = ##class(OcuPilot.Test.ClassicLinkRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a list archetype that declares an exemption is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.ClassicLink.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.ClassicLink.Bad).#BADARCHETYPE, "and the offending archetype")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster whose one exemption is a detail view is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>Story 6.4 (AD-5) -- every case in <class>OcuPilot.Test.TabCorpus</class> gets its exact sentence,
/// or none, from <method>OcuPilot.Screen.Registry.TabProblem</method>, and every roster there from
/// <method>OcuPilot.Screen.Registry.TabGroupProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>tabProblem</code> and
/// <code>tabGroupProblem</code>.</p>
/// <p>Mutation: drop the side-bar arm from <method>OcuPilot.Screen.Registry.TabProblem</method> -&gt;
/// the two later-tab side-bar cases go red. Disable the position check in
/// <method>OcuPilot.Screen.Registry.TabGroupProblem</method> -&gt; the gap, repeated-position and
/// two-group rosters go red.</p>
Method TestEveryTabCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.TabCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Do $$$AssertTrue(tCorpus.rosters.%Size() > 0, "and rosters: " _ tCorpus.rosters.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tCase.declaration), tExpected, tCase.name)
    }
    Set tIterator = tCorpus.rosters.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRoster) {
        Set tExpected = $Select(tRoster.%GetTypeOf("expected") = "null": "", 1: tRoster.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabGroupProblem(tRoster.screens), tExpected, tRoster.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)
}

/// <p>Story 6.4 (AD-5) -- <method>OcuPilot.Screen.Registry.Validate</method> refuses a roster whose
/// descriptor declares a tab outside the grammar (<class>OcuPilot.Test.TabRegistry</class>) and a
/// roster whose tab group leaves a gap in its positions
/// (<class>OcuPilot.Test.TabGroupRegistry</class>), each naming the offending class: the wiring the
/// corpus test, which calls the rules directly, does not reach.</p>
/// <p>Mutation: delete the <method>OcuPilot.Screen.Registry.TabProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> -&gt; the tab roster's assertions go red; delete
/// the <method>OcuPilot.Screen.Registry.TabGroupProblem</method> call -&gt; the group roster's go
/// red.</p>
Method TestATabOutsideTheGrammarIsRefusedByTheRoster()
{
    Set tSC = ##class(OcuPilot.Test.TabRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a tab outside the grammar is refused")
    Do $$$AssertEquals(tProblem, "OcuPilot.Test.Tab.Bad: tab.position 2 is a tab under its group's first, and such a tab declares sideBarPosition 0 (AD-5)", "naming the class and the rule")

    Set tSC = ##class(OcuPilot.Test.TabGroupRegistry).Validate(.tGroupProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster whose tab group leaves a gap is refused")
    Do $$$AssertEquals(tGroupProblem, "OcuPilot.Test.TabGroup.First: tab.group 'security/tab-group' declares positions 1,3, and a tab group's positions run 1 to 2 with no gap or repeat (AD-5)", "naming the group's first tab and the positions")
}

/// <p>AD-44's honored path, on the archetype the rule names literally: a
/// <code>detail</code> descriptor declaring a complete exemption validates, and every part the
/// card renders is readable from the declaration.</p>
/// <p><b>The target is declared, never derived.</b> The falsifiable form is that the href shares
/// no spelling with <method>ClassicPage</method>: the classic portal keys custom page resources
/// by normalized class name and publishes no inverse, so a descriptor that wanted a link had to
/// say where it goes.</p>
Method TestADetailDescriptorDeclaresAnHonoredExemption()
{
    Set tClass = "OcuPilot.Test.Screen.Detail"
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", "the archetype AD-44's rule names literally")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Archetype).MayLinkOut($ClassMethod(tClass, "Archetype")), "which may link out")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExempt"), "and declares that it does")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkExemptionReason") '= "", "with its reason")
    Do $$$AssertTrue($ClassMethod(tClass, "ClassicLinkLabel") '= "", "the page name its card's action carries")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkHref"), "/csp/sys/OcuPilotTestClassicPageDetail.csp", "and the declared target")

    Set tHref = $ClassMethod(tClass, "ClassicLinkHref")
    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertNotEquals(tHref, tPage, "the target is not the class name")
    Do $$$AssertNotEquals(tHref, "/" _ tPage, "nor the class name under a root")
    Do $$$AssertNotEquals(tHref, "/csp/sys/" _ tPage, "nor the class name under a guessed sub-application")

    Do $$$AssertTrue('$ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkExempt"), "Home links out to nothing")
    Do $$$AssertEquals($ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkHref"), "", "so it declares no target")
    Do $$$AssertEquals($ClassMethod(..#HOMEDESCRIPTOR, "ClassicLinkLabel"), "", "and no label")
}

/// <p>AC3, the sub-resource form -- task history is not a task, so it declares its own entity
/// type and names the route of the screen whose entity it hangs from.</p>
Method TestASubResourceDescriptorNamesItsParentScope()
{
    Set tClass = "OcuPilot.Test.Screen.Sub"
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "task-history-entry", "its rows are not the entity its route identifies")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "tasks/schedule", "and it names the route it hangs from")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "namespace", "its data scope is the namespace, not the instance")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Screen.Multi", "ParentScope"), "", "a screen that is nobody's sub-resource declares no parent")
}

/// <p>Story 6.6 (DW-1020) -- <method>OcuPilot.Screen.Registry.Validate</method> refuses a roster
/// whose built descriptor's <code>parentScope</code> names no built descriptor with that route
/// and an id, over the four ways that can happen: the route is not declared at all
/// (<class>OcuPilot.Test.ParentScopeNotFoundRegistry</class>), it is declared but not built
/// (<class>OcuPilot.Test.ParentScopeNotBuiltRegistry</class>), it is declared and built but
/// carries <code>id.kind</code> <code>none</code>
/// (<class>OcuPilot.Test.ParentScopeNoIdRegistry</class>), and it names the checked descriptor's
/// own route (<class>OcuPilot.Test.ParentScopeSelfRegistry</class>) -- the entry being checked is
/// excluded from its own candidate search, so it cannot resolve against itself. A fifth roster of
/// only sound declarations (<class>OcuPilot.Test.ParentScopeSoundRegistry</class>) validates
/// clean; the production roster's own sound path is
/// <method>TestTheProductionRosterValidates</method>'s.</p>
/// <p>Mutation: delete the <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method>
/// call from <method>OcuPilot.Screen.Registry.Validate</method> -&gt; the four refusing rosters'
/// assertions go red.</p>
Method TestAParentScopeThatDoesNotResolveIsRefusedByTheRoster()
{
    Set tSC = ##class(OcuPilot.Test.ParentScopeNotFoundRegistry).Validate(.tNotFoundProblem)
    Do $$$AssertStatusNotOK(tSC, "a parentScope naming a route nothing declares is refused")
    Do $$$AssertEquals(tNotFoundProblem, "OcuPilot.Test.ParentScope.NotFound.Child: parentScope 'parent-scope/not-found/nonexistent' names no built descriptor with that route and an id (DW-1020)", "naming the child and the unresolved route")

    Set tSC = ##class(OcuPilot.Test.ParentScopeNotBuiltRegistry).Validate(.tNotBuiltProblem)
    Do $$$AssertStatusNotOK(tSC, "a parentScope naming a route that is declared but not built is refused")
    Do $$$AssertEquals(tNotBuiltProblem, "OcuPilot.Test.ParentScope.NotBuilt.Child: parentScope 'parent-scope/not-built/parent' names no built descriptor with that route and an id (DW-1020)", "naming the child and the unbuilt parent's route")

    Set tSC = ##class(OcuPilot.Test.ParentScopeNoIdRegistry).Validate(.tNoIdProblem)
    Do $$$AssertStatusNotOK(tSC, "a parentScope naming a built route with id.kind none is refused")
    Do $$$AssertEquals(tNoIdProblem, "OcuPilot.Test.ParentScope.NoId.Child: parentScope 'parent-scope/no-id/parent' names no built descriptor with that route and an id (DW-1020)", "naming the child and the id-less parent's route")

    Set tSC = ##class(OcuPilot.Test.ParentScopeSelfRegistry).Validate(.tSelfProblem)
    Do $$$AssertStatusNotOK(tSC, "a parentScope naming its own route cannot resolve against itself")
    Do $$$AssertEquals(tSelfProblem, "OcuPilot.Test.ParentScope.Self.Child: parentScope 'parent-scope/self/child' names no built descriptor with that route and an id (DW-1020)", "the entry being checked is excluded from its own candidate search")

    Set tSC = ##class(OcuPilot.Test.ParentScopeSoundRegistry).Validate(.tSoundProblem)
    Do $$$AssertStatusOK(tSC, "a roster of resolving and empty parentScope declarations validates")
    Do $$$AssertEquals(tSoundProblem, "", "with no problem reported")
}

/// <p>AC3, the composite-id form -- the descriptor names the parts and the <b>one</b> shared
/// codec joins them, and the result is still a single path segment that survives the wire trip
/// byte for byte (AD-13). A slice never invents a second composite grammar, which is why the
/// join and the split live on <class>OcuPilot.Kernel.EntityId</class> and not here.</p>
/// <p>Mutation: join the parts with a literal <code>"/"</code> instead of
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method> -> the single-segment assertion goes
/// red, because the value stops being one segment.</p>
Method TestACompositeIdRoundTripsThroughTheOneSharedCodec()
{
    Set tClass = "OcuPilot.Test.Screen.Composite"
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "the id accessor declares itself composite")
    Set tParts = $ClassMethod(tClass, "IdParts")
    Do $$$AssertEquals($ListLength(tParts), 2, "and names its parts")
    Do $$$AssertEquals($List(tParts, 1), "namespace", "in order")
    Do $$$AssertEquals($List(tParts, 2), "name", "in order")

    Set tValues = $ListBuild("HSCUSTOM", "/csp/myapp")
    Set tJoined = ##class(OcuPilot.Kernel.EntityId).JoinComposite(tValues)
    Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode(tJoined)
    Do $$$AssertTrue((tEncoded '[ "/"), "a composite id still occupies exactly one path segment")
    Set tDelivered = ##class(OcuPilot.Test.EntityId).ServerDecode(tEncoded)
    Set tSplit = ##class(OcuPilot.Kernel.EntityId).SplitComposite(##class(OcuPilot.Kernel.EntityId).Decode(tDelivered))
    Do $$$AssertEquals($ListLength(tSplit), 2, "and comes back as its parts")
    Do $$$AssertEquals($List(tSplit, 1), "HSCUSTOM", "byte for byte")
    Do $$$AssertEquals($List(tSplit, 2), "/csp/myapp", "including the part that holds a slash")

    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Screen.Sub", "IdKind"), "single", "a single-id screen says so")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.Home", "IdKind"), "none", "and a screen with no entity declares no accessor")
}

/// <p>AC3, tool identity -- the tool name comes from its own declared field, so renaming a
/// screen cannot silently orphan its write tools or their governance keys.</p>
/// <p>The falsifiable form of "renaming the screen does not change it" is that the identifier
/// is <b>not derivable</b> from the route or the label: the fixture's route and its tool
/// identifier share no spelling, and neither of the two obvious derivations produces it.</p>
Method TestAToolIdentifierIsDeclaredAndNotDerived()
{
    Set tClass = "OcuPilot.Test.Screen.Composite"
    Set tTool = $ClassMethod(tClass, "ToolIdentifier")
    Set tRoute = $ClassMethod(tClass, "Route")
    Do $$$AssertEquals(tTool, "webapp.list", "the tool identifier is the declared value")
    Do $$$AssertNotEquals(tTool, tRoute, "it is not the route")
    Do $$$AssertNotEquals(tTool, $Translate(tRoute, "/", "."), "nor the route with its separator swapped")
    Do $$$AssertNotEquals(tTool, $ClassMethod(tClass, "LabelKey"), "nor the display name's key")
}

/// <p>AC4, the instance half -- a descriptor naming an entity type outside the kernel enum is
/// refused by the registry, naming the class and the value. The same value is refused by
/// <file>scripts/check-objectscript.py</file> in the tree and by
/// <file>ui/tools/screen-mirror.mjs</file> before the mirror is emitted, which is why the
/// fixture supplies its declaration through the overridable seam rather than an XData
/// block.</p>
/// <p>Mutation: add <code>not-an-entity-type</code> to
/// <parameter>OcuPilot.Kernel.EntityType.TYPES</parameter> -> this goes red, because the
/// vocabulary is what the refusal reads.</p>
Method TestAnUnknownEntityTypeIsRefusedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Test.BadRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster naming an unknown entity type is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Bad.Unknown", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.Bad.Unknown).#BADTYPE, "and the offending value")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that uses declared values is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>AC4's scope half -- a descriptor declaring a <code>scope</code> that is neither
/// <code>namespace</code> nor <code>instance</code> is refused by the registry, naming the class
/// and the value. The two are what <method>OcuPilot.Kernel.EntityRef.ScopeFor</method> resolves,
/// and it answers <code>""</code> for anything else, so without this refusal a third spelling
/// would build references with no scope rather than fail anywhere a reader could see.</p>
/// <p>Mutation: add <code>cluster</code> to the pair
/// <method>OcuPilot.Screen.Registry.Validate</method> accepts -> this goes red, because the two
/// declared values are what the refusal reads.</p>
Method TestADeclaredScopeOutsideTheTwoIsRefusedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Test.ScopeRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster declaring a third scope is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Scope.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Test.Scope.Bad).#BADSCOPE, "and the offending value")

    ; The same declaration, read the way a reference reads it, resolves to no scope at all --
    ; the silent outcome the refusal above exists to prevent.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor(##class(OcuPilot.Test.Scope.Bad).#BADSCOPE), "", "and it would have produced a reference with no scope")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that declares the two values is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>The vocabulary is closed and kernel-owned: a declared value is known, an undeclared one
/// is not, and the empty string is not -- a screen with no entity type declares <code>""</code>
/// and the registry exempts it rather than <method>IsKnown</method> admitting it.</p>
Method TestTheEntityTypeVocabularyIsClosed()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("web-application"), "a declared value is known")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("agent-switch"), "including the last one declared")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown("webapplication"), "a near miss is not")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown(""), "and neither is the empty string")
    ; Pinned to a literal. Comparing Count() with $ListLength(List()) restates Count()'s own
    ; definition and cannot fail, so a value dropped from TYPES would go unnoticed.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).Count(), 29, "the closed vocabulary holds twenty-nine values; adding one is a deliberate edit here and in Kernel.EntityType")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.Home", "PrimaryEntityType"), "", "Home administers nothing and says so")
    Do $$$AssertEquals($ListLength($ClassMethod("OcuPilot.Screen.Descriptor.Home", "EntityTypes")), 0, "so it contributes no key to validate")
}

/// <p>AD-43's declaration half -- a screen says in its descriptor whether it refreshes and at
/// what rates, and that is the only place either is said. The rates are whole seconds, so the
/// value read here is what the framework multiplies into the delay it hands its timer seam.</p>
/// <p>Mutation: drop <code>"refreshRates"</code> from
/// <class>OcuPilot.Test.Screen.Refreshing</class>'s declaration -> the rate assertions go red,
/// and <method>TestTheProductionRosterValidates</method>'s fixture sibling below goes red with
/// them, because a refreshing screen with no rates is refused.</p>
Method TestARefreshingScreenDeclaresItsRatesAndHomeDeclaresNone()
{
    Set tClass = "OcuPilot.Test.Screen.Refreshing"
    Do $$$AssertTrue($ClassMethod(tClass, "Refreshes"), "a refreshing screen says so in its descriptor")
    Set tRates = $ClassMethod(tClass, "RefreshRates")
    Do $$$AssertEquals($ListLength(tRates), 1, "and declares the rates its chip may set")
    Do $$$AssertEquals($List(tRates, 1), 10, "in whole seconds")

    Do $$$AssertTrue('$ClassMethod(..#HOMEDESCRIPTOR, "Refreshes"), "Home is not one of the auto-refresh screens")
    Do $$$AssertEquals($ListLength($ClassMethod(..#HOMEDESCRIPTOR, "RefreshRates")), 0, "so it permits no rate")

    ; A descriptor written before the pair existed declares neither, and reads as the screen it
    ; is: one the framework binds nothing for. The registry accepts that pair, so an older
    ; fixture is not retroactively malformed.
    Do $$$AssertTrue('$ClassMethod("OcuPilot.Test.Screen.Multi", "Refreshes"), "an omitted declaration reads as not refreshing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(0, ""), "", "and that pair is sound")
}

/// <p>AD-43's refusal half -- every refresh declaration outside the permitted shapes is refused,
/// as values here and over a real roster below. <method>Validate</method> reports only the first
/// problem in a roster, so six malformed shapes would otherwise be six fixture packages.</p>
/// <p>Mutation: drop the ascending comparison from
/// <method>OcuPilot.Screen.Registry.RefreshProblem</method> -> the repeat and the descent both
/// stop being refused and two assertions go red, while a chip cycling through
/// <code>10, 10</code> would spend one step of its cycle changing nothing.</p>
Method TestARefreshDeclarationOutsideThePermittedShapesIsRefused()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(10)), "", "one positive rate on a refreshing screen is sound")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(5, 10, 30, 60)), "", "and so is an ascending list of them")

    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(0, $ListBuild(10)), "", "a rate on a screen that does not refresh is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, ""), "", "a refreshing screen with no rate is refused: its chip could never turn on")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(0)), "", "zero is spelled by turning the chip off, never by declaring it")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(-10)), "", "a negative rate is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(1.5)), "", "a fraction of a second is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild("ten")), "", "and so is a rate that is not a number")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(10, 10)), "", "a repeat would make one step of the chip's cycle a no-op")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(1, $ListBuild(30, 10)), "", "and a descent would advance the chip backwards")

    Set tSC = ##class(OcuPilot.Test.RefreshRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a malformed refresh declaration is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Refresh.Bad", "the refusal names the offending class")
    Do $$$AssertTrue(tProblem [ "refreshRates", "and the field it is about")

    Set tGoodSC = ##class(OcuPilot.Test.ScreenRegistry).Validate(.tGoodProblem)
    Do $$$AssertEquals(tGoodProblem, "", "while the fixture roster that declares a sound pair is sound")
    Do $$$AssertStatusOK(tGoodSC, "and passes")
}

/// <p>A side bar lists only screens that exist (<file>EXPERIENCE.md</file> "Entries in daily-use order."). The
/// unbuilt fixture shares an area with a built one, so an implementation that dropped the
/// filter would list two where one is correct rather than turning an empty list into an empty
/// list.</p>
/// <p>Mutation: default <method>OcuPilot.Screen.Registry.ScreensForArea</method>'s
/// <var>pBuiltOnly</var> to 0 -> the first assertion goes red with two entries.</p>
Method TestOnlyBuiltScreensReachASideBar()
{
    Set tSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 1, .tBuilt)
    Do $$$AssertStatusOK(tSC, "the built list builds")
    Do $$$AssertEquals($ListLength(tBuilt), 1, "only the built screen is listed")
    Do $$$AssertEquals($List(tBuilt, 1), "OcuPilot.Test.Screen.Composite", "and it is the one declared built")

    Set tAllSC = ##class(OcuPilot.Test.ScreenRegistry).ScreensForArea("web-applications", 0, .tAll)
    Do $$$AssertStatusOK(tAllSC, "the unfiltered list builds")
    Do $$$AssertEquals($ListLength(tAll), 2, "while both are declared")
    Do $$$AssertTrue('$ClassMethod("OcuPilot.Test.Screen.Unbuilt", "IsBuilt"), "and the excluded one is the unbuilt one")
}

/// <p>The area vocabulary is closed and ordered: eight entries in the rail order
/// <file>EXPERIENCE.md</file> "**The rail, top to bottom (daily-use order):**" fixes, each at its declared rail
/// position and carrying its
/// own declared privilege pair set, Home the only one that navigates and Agent co-pilot the
/// only one pinned to the bottom. Home and Agent co-pilot declare no pair at all, which is how
/// "the rail item itself never gates" is expressed.</p>
/// <p>Mutation: change an area's pair set, <code>navigates</code> or <code>pinBottom</code> in
/// <class>OcuPilot.Screen.Area</class> -> that area's own assertion goes red. Each of the four
/// fields is asserted per area, so no area's value rests on another's.</p>
Method TestTheAreaVocabularyIsClosedOrderedAndUngatedAtBothEnds()
{
    Set tSC = ##class(OcuPilot.Screen.Area).List(.tAreas)
    Do $$$AssertStatusOK(tSC, "the area list reads")
    Do $$$AssertEquals(tAreas.%Size(), 8, "eight rail entries")

    ; key, pair set, navigates, pinBottom
    Set tExpected = ""
    Set tExpected = tExpected _ $ListBuild($ListBuild("home", "", 1, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("logs", "%Admin_Operate:USE, %Admin_Secure:USE, %DB_IRISSYS:READ", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("os-management", "%Admin_Operate:USE, %Admin_Manage:USE, %DB_IRISSYS:READ", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("tasks", "%Admin_Task:USE, %DB_IRISSYS:READ", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("permissions", "%Admin_Secure:USE, %DB_IRISSYS:READ", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("web-applications", "%Admin_Secure:USE, %DB_IRISSYS:READ", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("security", "%Admin_Secure:USE, %DB_IRISSYS:READ, %Admin_Wallet:USE, %Admin_OAuth2_Client:USE, %Admin_OAuth2_Server:USE, %Admin_OAuth2_Registration:USE", 0, 0))
    Set tExpected = tExpected _ $ListBuild($ListBuild("agent", "", 0, 1))
    Do $$$AssertEquals($ListLength(tExpected), 8, "the expectation names all eight areas")

    For tI = 1:1:$ListLength(tExpected) {
        Set tRow = $List(tExpected, tI)
        Set tKey = $List(tRow, 1)
        Set tPairs = $List(tRow, 2)
        Set tArea = tAreas.%Get(tI - 1)
        Do $$$AssertEquals(tArea.key, tKey, "rail position " _ tI _ " is the declared area")
        Do $$$AssertEquals(+tArea.railPosition, tI, "and declares that position")
        Set tWhat = $Select(tPairs = "": " never gates", 1: " declares exactly its pair set")
        Do $$$AssertEquals(..PairText(tKey), tPairs, tKey _ tWhat)
        Do $$$AssertEquals(''tArea.navigates, $List(tRow, 3), tKey _ " declares whether its rail item navigates")
        Do $$$AssertEquals(''tArea.pinBottom, $List(tRow, 4), tKey _ " declares whether it is pinned to the bottom")
    }

    Do $$$AssertTrue('##class(OcuPilot.Screen.Area).Exists("no-such-area"), "and the vocabulary is closed")
}

/// <p>DW-275 -- the os-management area's union, and what it costs a narrower screen.</p>
/// <p><class>OcuPilot.Test.NarrowArea</class> is the screen Stories 6.8 and 6.10 will add: one
/// needing <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and not
/// <code>%Admin_Manage:USE</code>. It validates, and the area covers it -- coverage is
/// containment, so an area declaring more than a screen requires is sound. The cost, recorded at
/// <class>OcuPilot.Screen.Area</class> and accepted, is a false denial for an operator holding
/// only those two pairs. <method>OcuPilot.Test.WireSecurityRead.TestTheProcessesListsPairSetIsEnforcedForARealPrincipal</method>
/// observes the area denial itself with a real principal; that the denial turns false once a
/// screen like this one is built is an <b>(inference)</b>, since this fixture is not a built
/// screen and no real principal can be denied it.</p>
/// <p>Mutation: drop <code>%Admin_Manage:USE</code> from the <code>os-management</code> area ->
/// the processes list's own coverage assertion goes red (the decision cannot be reversed by
/// accident), while the narrow fixture's assertions here stay green -- which is what says these
/// two halves are independent. Relax
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> to per-screen coverage -> the
/// same assertion goes red.</p>
Method TestANarrowOsManagementScreenIsSoundInsideTheUnion()
{
    Set tClass = "OcuPilot.Test.NarrowArea"
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the narrow fixture's declaration reads")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "its top-level keys are the declared vocabulary")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "it declares the two pairs a narrower os-management read needs, and not %Admin_Manage:USE")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "os-management", "inside the same area as the processes list")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", "and the area's union covers it, because coverage is containment")

    ; The area is still gated on the union, so this screen's own operator is denied the rail entry
    ; -- the accepted false denial, stated as the count it costs rather than left implicit.
    Do $$$AssertEquals(..PairText("os-management"), "%Admin_Operate:USE, %Admin_Manage:USE, %DB_IRISSYS:READ", "the area declares the union of its screens' pairs")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "PrivilegePairs")), 2, "while this screen needs two of them, which is the accepted false denial")

    ; And it is a fixture, not a screen: the production roster never lists it.
    Set tListSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tRoster)
    Do $$$AssertStatusOK(tListSC, "the production descriptor roster reads")
    If $$$ISOK(tListSC) Do $$$AssertEquals($ListFind(tRoster, tClass), 0, "and it is outside it, because it sits under OcuPilot.Test.")
}

/// <p>AC5, AC6 -- every case in <class>OcuPilot.Test.RowTargetCorpus</class>'s <code>Cases</code>
/// half gets its exact sentence, or none, from
/// <method>OcuPilot.Screen.Registry.RowTargetProblem</method>, and every roster in its
/// <code>Rosters</code> half from <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method>
/// -- the same corpus <file>ui/tools/screen-mirror.test.mjs</file> runs through
/// <code>rowTargetProblem</code> and <code>rowTargetResolutionProblem</code>.</p>
/// <p>Mutation: drop one word from <method>RowTargetProblem</method>'s "this screen's own route"
/// sentence -> the self-route case goes red. Make
/// <method>RowTargetResolutionProblem</method> return <code>""</code> for an unbuilt target ->
/// the roster case goes red in both engines.</p>
Method TestEveryRowTargetCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.RowTargetCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the Cases corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tDeclaration = ##class(OcuPilot.Test.RowTargetCorpus).DeclarationFor(tCorpus, tCase)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RowTargetProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the Cases corpus carries at least one refusing case: " _ tRefusals)

    ; The corpus's own sound rowTarget carries exactly the declared nested vocabulary, so
    ; ROWTARGETKEYS cannot gain, lose or rename a key on one side of the two engines without a
    ; case going red -- the same tie ui/tools/screen-mirror.test.mjs holds for DECLARATION_KEYS.
    Set tTargetKeys = ""
    Set tSoundTarget = tCorpus.declaration.%Get("rowTarget")
    If $IsObject(tSoundTarget) {
        Set tKeyIterator = tSoundTarget.%GetIterator()
        While tKeyIterator.%GetNext(.tTargetKey, .tTargetValue) { Set tTargetKeys = tTargetKeys _ $ListBuild(tTargetKey) }
    }
    Do $$$AssertEquals($ListToString(tTargetKeys, ","), ##class(OcuPilot.Screen.Registry).#ROWTARGETKEYS, "the corpus's sound rowTarget carries exactly the declared rowTarget vocabulary")

    Set tSC = ##class(OcuPilot.Test.RowTargetCorpus).RostersBlock(.tRosters)
    Do $$$AssertStatusOK(tSC, "the Rosters block reads")
    If '$IsObject(tRosters) Quit
    Do $$$AssertTrue(tRosters.rosters.%Size() > 0, "and rosters: " _ tRosters.rosters.%Size())
    Set tRosterRefusals = 0
    Set tIterator = tRosters.rosters.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRoster) {
        Set tExpected = $Select(tRoster.%GetTypeOf("expected") = "null": "", 1: tRoster.expected)
        If tExpected '= "" Set tRosterRefusals = tRosterRefusals + 1
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RowTargetResolutionProblem(tRoster.screens), tExpected, tRoster.name)
    }
    Do $$$AssertTrue(tRosterRefusals > 0, "the Rosters block carries at least one refusing roster: " _ tRosterRefusals)
}

/// <p>AD-5, AD-14: the entity-label rule's instance-side engine, over the same four shapes
/// <file>ui/tools/screen-mirror.test.mjs</file> holds <code>entityLabelProblem</code> to, and the
/// same four sentences -- a reword on one side only goes red on the other.</p>
/// <p>Mutation: return <code>""</code> for a noun declared with no entity type -> the fourth
/// assertion goes red in both engines. Delete the
/// <method>OcuPilot.Screen.Registry.EntityLabelProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> -> the fixture-roster assertions go red while
/// the shipped roster stays green either way, which is what tells the rule from its wiring.</p>
Method TestTheEntityLabelRuleAnswersTheSameSentencesAsTheMirror()
{
    Set tRosterSC = ##class(OcuPilot.Test.EntityLabelRegistry).Validate(.tRosterProblem)
    Do $$$AssertStatusNotOK(tRosterSC, "a roster declaring a noun for no entity type is refused")
    Do $$$AssertTrue(tRosterProblem [ "OcuPilot.Test.EntityLabel.Bad", "the refusal names the offending class: " _ tRosterProblem)
    Do $$$AssertTrue(tRosterProblem [ "entityLabelKey names the singular noun", "and the rule it is about")

    Set tSC = ##class(OcuPilot.Screen.Descriptor.WebAppList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the web applications list's declaration reads")
    If '$IsObject(tDeclaration) Quit
    Do $$$AssertEquals(tDeclaration.%Get("entityLabelKey"), "proposalEntityWebApplication", "it declares the singular noun's key")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tDeclaration), "", "and passes the rule")

    Do tDeclaration.%Remove("entityLabelKey")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tDeclaration), "", "an absent key is sound: the screen publishes no noun")

    Do tDeclaration.%Set("entityLabelKey", "", "string")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tDeclaration), "", "and so is an empty one")

    Do tDeclaration.%Set("entityLabelKey", 7, "number")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tDeclaration), "entityLabelKey is not a string key", "a non-string key is refused")

    Do tDeclaration.%Set("entityLabelKey", "proposalEntityWebApplication", "string")
    Do tDeclaration.%Set("entityType", "", "string")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tDeclaration), "entityLabelKey names the singular noun for this screen's entity type, and none is declared", "a noun declared for no entity type is refused")

    ; Every shipped descriptor passes, so the closed rule refuses nothing that ships.
    Set tListSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tRoster)
    Do $$$AssertStatusOK(tListSC, "the shipped roster reads")
    If $$$ISERR(tListSC) Quit
    For tI = 1:1:$ListLength(tRoster) {
        Set tClass = $List(tRoster, tI)
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).EntityLabelProblem(tShipped), "", tClass _ ": its entity label passes")
    }
}

/// <p>AC9 -- the Locks descriptor's read and table are exactly the eight fields and seven columns
/// Boundaries names: no transaction column, no <code>Removable</code>, <code>CanBeExamined</code>
/// or <code>RemoteOwner</code> field, no derived field, and no <code>$zu(67,19</code> anywhere in
/// this descriptor's own source -- the class this test reads, not the whole read path.</p>
/// <p>Mutation: add an eighth column to <code>table.columns</code> in
/// <class>OcuPilot.Screen.Descriptor.LockList</class> -> the column-set assertion goes red.</p>
Method TestTheLocksListDeclaresExactlyItsEightFieldsAndSevenColumns()
{
    Set tClass = "OcuPilot.Screen.Descriptor.LockList"
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the Locks list declares a read")
    If '$IsObject(tRead) Quit
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFields, ","), "Pid,OSUserName,RoutineInfo,ModeCount,Reference,Directory,System,DeleteID", "exactly the eight declared fields, no transaction column and no Removable, CanBeExamined or RemoteOwner")

    Set tTable = $ClassMethod(tClass, "Field", "table")
    Do $$$AssertTrue($IsObject(tTable), "the Locks list declares a table")
    If '$IsObject(tTable) Quit
    Set tColumns = ""
    Set tIterator = tTable.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) { Set tColumns = tColumns _ $ListBuild(tColumn.%Get("field")) }
    Do $$$AssertEquals($ListToString(tColumns, ","), "Pid,OSUserName,RoutineInfo,ModeCount,Reference,Directory,System", "exactly the seven declared columns")

    Set tSourceSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, tClass, .tSource)
    Do $$$AssertStatusOK(tSourceSC, "the class source reads")
    If $$$ISOK(tSourceSC) Do $$$AssertTrue('(tSource [ "$zu(67,19"), "no $zu(67,19 transaction check anywhere in this descriptor's own source (DW-1073)")

    ; The server-side accessor both arms of OcuPilot.Screen.Descriptor.Base.RowTarget answer
    ; through: the declared object here, and the empty string for a screen that declares none.
    Set tRowTarget = ##class(OcuPilot.Screen.Descriptor.LockList).RowTarget()
    Do $$$AssertTrue($IsObject(tRowTarget), "the RowTarget accessor answers the declared object")
    If $IsObject(tRowTarget) {
        Do $$$AssertEquals(tRowTarget.%Get("route"), "os-management/processes/details", "at Process details' route")
        Do $$$AssertEquals(tRowTarget.%Get("field"), "Pid", "keyed by Pid, not by this row's own DeleteID")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Descriptor.ProcessList).RowTarget(), "", "and a screen that declares no row target answers the empty string")
}

/// <p>AC5, AC6 -- both new rules reach the roster through
/// <method>OcuPilot.Screen.Registry.Validate</method>, each naming the offending class. The corpus
/// test above calls the two rules directly, so deleting either call from <code>Validate</code>
/// reddens nothing there; these are the fixture registries those two call sites' own wiring
/// needed, the same way <class>OcuPilot.Test.DeclarationRegistry</class> closes it for
/// <method>DeclarationProblem</method> (DW-306).</p>
/// <p>Mutation: delete the <method>OcuPilot.Screen.Registry.RowTargetProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> -> the shape assertions go red; delete the
/// <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method> call -> the roster
/// assertions go red; either way
/// <method>TestEveryRowTargetCorpusCaseGetsItsSentence</method> and the shipped roster stay
/// green.</p>
Method TestARowTargetOutsideTheGrammarIsRefusedByTheRoster()
{
    Set tSC = ##class(OcuPilot.Test.RowTargetShapeRegistry).Validate(.tShapeProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying a rowTarget outside the grammar is refused")
    Do $$$AssertTrue(tShapeProblem [ "OcuPilot.Test.RowTargetShape.Bad", "the refusal names the offending class: " _ tShapeProblem)
    Do $$$AssertTrue(tShapeProblem [ "rowTarget.field 'Bogus' is not one of read.fields", "and the sentence RowTargetProblem returns: " _ tShapeProblem)

    Set tSC = ##class(OcuPilot.Test.RowTargetRosterRegistry).Validate(.tRosterProblem)
    Do $$$AssertStatusNotOK(tSC, "and a roster whose rowTarget.route resolves to nothing is refused")
    Do $$$AssertTrue(tRosterProblem [ "OcuPilot.Test.RowTargetRoster.A", "naming that class: " _ tRosterProblem)
    Do $$$AssertTrue(tRosterProblem [ "rowTarget.route 'security/row-target-nowhere' names no declared screen (AD-5)", "and the sentence RowTargetResolutionProblem returns: " _ tRosterProblem)

    Set tProdSC = ##class(OcuPilot.Screen.Registry).Validate(.tProdProblem)
    Do $$$AssertStatusOK(tProdSC, "while the shipped roster still validates: " _ tProdProblem)
}

/// <p>AC1, AC8, AC9, Story 6.11 -- the Databases General view declares exactly its five fields and
/// five columns, is the fourth OS-management side-bar entry, and declares
/// <code>%Admin_Manage:USE</code> alone (not Operate) as its first pair.</p>
/// <p>Mutation: add a sixth column to <code>table.columns</code> in
/// <class>OcuPilot.Screen.Descriptor.DatabaseList</class> -> the column-set assertion goes red.</p>
Method TestTheDatabasesGeneralViewDeclaresExactlyItsFiveFieldsAndFiveColumns()
{
    Set tClass = "OcuPilot.Screen.Descriptor.DatabaseList"
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 4, "the fourth OS-management side-bar entry")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list (two views)", "the two-view archetype")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the Databases list declares a read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.source.endpoint, "Database.SysCRUD", "reading the vendor's Database.SysCRUD endpoint")
    Do $$$AssertEquals(tRead.source.type, "LIST", "the General view's LIST")
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFields, ","), "Directory,Size,MaxSize,Status,Resource", "exactly the five declared fields")
    Set tTable = $ClassMethod(tClass, "Field", "table")
    Set tColumns = ""
    Set tIterator = tTable.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) { Set tColumns = tColumns _ $ListBuild(tColumn.%Get("field")) }
    Do $$$AssertEquals($ListToString(tColumns, ","), "Directory,Size,MaxSize,Status,Resource", "exactly the five declared columns")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tPairs), 2, "two declared pairs")
    Do $$$AssertEquals($List($List(tPairs, 1), 1), "%Admin_Manage", "Manage alone is the first, not Operate")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.OpDatabases", "the OpDatabases classic key, not Databases")
}

/// <p>AC2, AC3, Story 6.11 -- the Free-space view merges its <code>rowGet</code>'s
/// <code>INFO</code> figures into the General view's <code>LIST</code> row, declares
/// <code>MaxSize</code> nowhere, and declares three pairs with <code>%Admin_Operate:USE</code>
/// second, the <code>AsyncResult</code> poll's own pair.</p>
/// <p>Mutation: remove <code>%Admin_Operate:USE</code> from <code>DatabaseFreeSpace</code>'s
/// <code>privileges</code> -> the pair-count assertion goes red.</p>
Method TestTheFreeSpaceViewMergesInfoFiguresAndDeclaresNoMaxSize()
{
    Set tClass = "OcuPilot.Screen.Descriptor.DatabaseFreeSpace"
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 0, "unlisted, reached only through the View control")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the Free-space view declares a read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.source.type, "LIST", "still a LIST, merged by rowGet")
    Do $$$AssertEquals(tRead.source.rowGet.type, "INFO", "the async INFO detail call")
    Do $$$AssertEquals(tRead.source.rowGet.key, "Directory", "keyed by Directory")
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFields, ","), "Directory,Size,AvailableSpace,DiskFree,Mounted", "exactly the five declared fields")
    Do $$$AssertTrue('$ListFind(tFields, "MaxSize"), "MaxSize is declared nowhere on this view")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tPairs), 3, "three declared pairs")
    Do $$$AssertEquals($List($List(tPairs, 1), 1), "%Admin_Manage", "Manage first, the LIST's own gate")
    Do $$$AssertEquals($List($List(tPairs, 2), 1), "%Admin_Operate", "Operate second, the AsyncResult poll's own gate")
    Do $$$AssertEquals($ClassMethod(tClass, "EmptyStateKey"), "databaseListEmpty", "reusing the General view's empty state")
}

/// <p>AC7, AC8, Story 6.11 -- Database details declares Operate alone (not Manage), a composite id
/// keyed by <code>Directory</code>, a <code>dir</code> criterion filled from the route id, and
/// exactly fifteen fields: <code>Directory</code>, <code>GET</code>'s ten, and the
/// <code>rowGet</code>'s four.</p>
/// <p>Mutation: add <code>"ReadOnlyReason"</code> to <code>DatabaseDetails</code>'s
/// <code>read.fields</code> without adding it to <code>rowGet.fields</code> -> the fifteen-field
/// count assertion goes red (and <class>OcuPilot.Test.ScreenRead</class>'s live-row assertion
/// separately catches the missing key).</p>
Method TestDatabaseDetailsDeclaresExactlyFifteenFieldsAndOperateAlone()
{
    Set tClass = "OcuPilot.Screen.Descriptor.DatabaseDetails"
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", "a detail screen")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "os-management/databases", "a sub-resource of Databases")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "a composite id")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "IdParts"), ","), "Directory", "keyed by Directory")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tPairs), 2, "two declared pairs")
    Do $$$AssertEquals($List($List(tPairs, 1), 1), "%Admin_Operate", "Operate alone, not Manage")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "Database details declares a read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.source.type, "GET", "a single-object GET")
    Do $$$AssertEquals(tRead.source.rowGet.type, "INFO", "an INFO detail call, never parts")
    Do $$$AssertTrue('$IsObject(tRead.source.%Get("parts")), "and never source.parts")
    Do $$$AssertEquals(tRead.criteria.fields.%Get(0).param, "dir", "the one route-id criterion")
    Do $$$AssertEquals(tRead.source.rowGet.key, "dir", "keyed by that same criterion's param")
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListLength(tFields), 15, "fifteen fields: Directory, GET's ten, and the rowGet's four")
    Do $$$AssertEquals($ListToString(tFields, ","), "Directory,MaxSize,ExpansionSize,NewVolumeThreshold,NewVolumeDirectory,ResourceName,NewGlobalIsKeep,NewGlobalCollation,ClusterMountMode,ReadOnly,GlobalJournalState,Size,AvailableSpace,DiskFree,Mounted", "in that exact order")
}

/// <p>AC9, Story 6.11 -- Database volumes declares the six vendor fields, a
/// <code>VOLUMELIST</code> source with neither <code>rowGet</code> nor <code>forEach</code>, a
/// <code>dir</code> criterion filled from the parent route id, and no entity type of its own.</p>
/// <p>Mutation: change the source type to <code>LIST</code> -> the source-type assertion goes red,
/// and <class>OcuPilot.Test.ScreenRead</class>'s volume-row assertion separately catches the
/// endpoint answering the database list instead.</p>
Method TestDatabaseVolumesDeclaresTheVendorSixAndNoDetailCall()
{
    Set tClass = "OcuPilot.Screen.Descriptor.DatabaseVolumeList"
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "os-management/databases", "a sub-resource of Databases")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "", "no entity type of its own")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($List($List(tPairs, 1), 1), "%Admin_Manage", "Manage alone, TYPEVOLUMELIST's own arm")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "Database volumes declares a read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.source.type, "VOLUMELIST", "the new source type")
    Do $$$AssertTrue('$IsObject(tRead.source.%Get("rowGet")), "no rowGet")
    Do $$$AssertTrue('$IsObject(tRead.source.%Get("forEach")), "no forEach")
    Do $$$AssertEquals(tRead.criteria.fields.%Get(0).param, "dir", "the one route-id criterion, the vendor's own param name")
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFields, ","), "VolumeNumber,VolumeDirectory,File,Size,VolumeDirectoryTotalSize,DiskFree", "the vendor's six members")
}

/// <p>AC1, AC4, AC5, AC6, Story 6.12 -- the Devices list declares exactly its six fields and six
/// columns, in order and by kind; sorts by <code>Name</code> ascending; declares
/// <code>%Admin_Manage:USE</code> then <code>%DB_IRISSYS:READ</code> and no third pair; names its
/// own empty state and its own classic key; is OS management's fifth side-bar entry; and offers no
/// primary action, no row action and no outbound classic link: it is the list only, the device
/// editor is Story 8.8's.</p>
/// <p>Mutation: add a <code>rowActions</code> entry with no handler in
/// <class>OcuPilot.Screen.Descriptor.DeviceList</class> -> the row-action assertion goes red; set
/// <code>classicLinkExemption.exempt</code> true -> the exemption assertion goes red, and
/// <file>ui/tools/classic-links.mjs</file> separately refuses a <code>list</code> archetype
/// declaring one (AD-44).</p>
Method TestTheDevicesListDeclaresExactlyItsSixFieldsAndSixColumns()
{
    Set tClass = "OcuPilot.Screen.Descriptor.DeviceList"
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 5, "OS management's fifth side-bar entry")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertTrue($IsObject(tRead), "the Devices list declares a read")
    If '$IsObject(tRead) Quit
    Set tFields = ""
    Set tIterator = tRead.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFields = tFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFields, ","), "Name,PhysicalDevice,Type,SubType,Description,Alias", "exactly the six declared fields, no Prompt, OpenParameters or AlternateDevice")

    ; QA (independent falsification pass): filter and sort.fields are the read's own field set,
    ; not just a same-length list -- a field dropped from filter while staying in fields/columns
    ; reddens nothing else in this class or in ScreenRead's live-value method.
    Set tFilter = ""
    Set tIterator = tRead.%Get("filter").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tFilter = tFilter _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tFilter, ","), "Name,PhysicalDevice,Type,SubType,Description,Alias", "filter is exactly the same six fields as read.fields")
    Set tSortFields = ""
    Set tIterator = tRead.%Get("sort").%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) { Set tSortFields = tSortFields _ $ListBuild(tField) }
    Do $$$AssertEquals($ListToString(tSortFields, ","), "Name,PhysicalDevice,Type,SubType,Description,Alias", "sort.fields is exactly the same six fields as read.fields")
    ; The two keys that decide what order rows arrive in. Registry.ReadProblem only requires
    ; default to be one of sort.fields and direction to be asc or desc, so either can change to
    ; another valid value without a refusal, and no other assertion in any suite reads them.
    Do $$$AssertEquals(tRead.%Get("sort").%Get("default"), "Name", "sorted by Name by default, the row key's own column")
    Do $$$AssertEquals(tRead.%Get("sort").%Get("direction"), "asc", "ascending")

    Set tTable = $ClassMethod(tClass, "Field", "table")
    Do $$$AssertTrue($IsObject(tTable), "the Devices list declares a table")
    If '$IsObject(tTable) Quit
    Set tColumns = ""
    Set tKinds = ""
    Set tIterator = tTable.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tColumns = tColumns _ $ListBuild(tColumn.%Get("field"))
        Set tKinds = tKinds _ $ListBuild(tColumn.%Get("kind"))
    }
    Do $$$AssertEquals($ListToString(tColumns, ","), "Name,PhysicalDevice,Type,SubType,Description,Alias", "exactly the six declared columns, in declared order, one name column")
    ; QA (independent falsification pass): the field-name pin above passes even when a column's
    ; kind is wrong (e.g. Alias declared "text" instead of "number") -- nothing else in this
    ; class, in ScreenRead's live-value method or in the browser spec's header assertion checks
    ; kind, only the field/label/order.
    Do $$$AssertEquals($ListToString(tKinds, ","), "name,identifier,text,text,text,number", "each column's declared kind: the row key, an opaque identifier, three plain text columns, then Alias as a number (an integer alternate id, as VolumeNumber is)")

    Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tPairs), 2, "two declared pairs, no third")
    Do $$$AssertEquals($List($List(tPairs, 1), 1) _ ":" _ $List($List(tPairs, 1), 2), "%Admin_Manage:USE", "the endpoint's own ResourcesOR() pair first, which is the pair the gate names to a principal holding neither")
    Do $$$AssertEquals($List($List(tPairs, 2), 1) _ ":" _ $List($List(tPairs, 2), 2), "%DB_IRISSYS:READ", "then the port's namespace-switch pair, which Registry.ReadProblem requires of every admin-port read")

    ; The sentence an empty instance reads. screen-mirror.mjs checks only that the key exists in
    ; strings.ts and Registry only that a read-only list names emptyNextKey and not emptyAgentKey,
    ; so another screen's key would validate, mirror and ship.
    Do $$$AssertEquals($ClassMethod(tClass, "EmptyStateKey"), "deviceListEmpty", "its own empty state, not another list's")

    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, "no row action: the device editor is Story 8.8's")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", "and no primary action")
    Do $$$AssertEquals(''$ClassMethod(tClass, "ClassicLinkExempt"), 0, "and no outbound classic link: a list archetype never links out (AD-44)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Descriptor.DeviceList).RowTarget(), "", "and no rowTarget: no other screen names this entity type")

    ; The classic key carries the AD-44 union: Gate.ClassicResource resolves it through
    ; %SYS.Portal.Resources, where a name that opens nothing adds no pair and reports no error.
    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.Config.Devices", "the Config.Devices classic key -- %CSP.UI.Portal.Devices does not exist on this build")
    Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), "which is a compiled class on this instance, found under the declaration's own case")
}

/// <p>Area <var>pKey</var>'s declared privilege pairs as <code>resource:permission</code> joined
/// by <code>, </code> in declared order, empty when the area never gates. An assertion over this
/// pins the set by content: a length alone passes a set that swapped one pair for another.</p>
ClassMethod PairText(pKey As %String) As %String
{
    Set tText = ""
    Set tPairs = ##class(OcuPilot.Screen.Area).PrivilegePairs(pKey)
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Set tText = tText _ $Select(tI = 1: "", 1: ", ") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>The roster entry for <var>pKey</var>, or an empty string.</p>
ClassMethod AreaEntry(pRoster As %DynamicArray, pKey As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRoster.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = pKey {
            Set tFound = tArea
            Quit
        }
    }
    Quit tFound
}

}
