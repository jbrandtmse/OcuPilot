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
    Do $$$AssertTrue(tProblem [ "banner.severity 'error'", "and the value it is about")

    Set tSound = {"read":{},"banner":{"source":{"port":"admin","endpoint":"Task.Manager","type":"GET"},"field":"Status","equals":"Suspended","messageKey":"taskManagerSuspendedBanner","severity":"warning"}}
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
/// declare <code>Suspended</code> as a read field or a column -> the absence assertions go red.</p>
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
        Do $$$AssertEquals(tBanner.field _ "=" _ tBanner.equals, "Status=Suspended", "raised when Status reads Suspended")
        Do $$$AssertEquals(tBanner.messageKey, "taskManagerSuspendedBanner", "naming the suspended sentence's key")
        Do $$$AssertEquals(tBanner.severity, "warning", "as a warning strip")
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
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("log-entry"), "including the last one declared")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown("webapplication"), "a near miss is not")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown(""), "and neither is the empty string")
    ; Pinned to a literal. Comparing Count() with $ListLength(List()) restates Count()'s own
    ; definition and cannot fail, so a value dropped from TYPES would go unnoticed.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).Count(), 26, "the closed vocabulary holds twenty-six values; adding one is a deliberate edit here and in Kernel.EntityType")
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

/// <p>A side bar lists only screens that exist (<file>EXPERIENCE.md</file> `:157`). The
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
/// <file>EXPERIENCE.md</file> `:64` fixes, each at its declared rail position and carrying its
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
    Set tExpected = tExpected _ $ListBuild($ListBuild("security", "%Admin_Secure:USE, %DB_IRISSYS:READ", 0, 0))
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
