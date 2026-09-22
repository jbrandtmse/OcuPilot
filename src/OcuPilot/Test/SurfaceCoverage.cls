/// <p>The surface coverage floor (Story 13.2, AC3): every screen the registry declares, built or
/// not, and every tool the tool registry classifies <code>write</code>, has a named test method
/// that pins it -- and every coverage row names a member that still exists.</p>
/// <p><b>The roster covers unbuilt descriptors too</b> (DW-1453, Story 5.11). A descriptor that
/// declares <code>"built": false</code> is still a declaration the registry validates, still the
/// owner of its screen's privileges, entity type and write tool
/// (<class>OcuPilot.Screen.Descriptor.AuditingConfig</class> owns
/// <code>security.auditing.update</code>), and still something a later story turns on -- so
/// leaving it off the roster meant the next one sat on no roster silently.</p>
/// <p><b>Both sets are derived from the registries themselves</b>
/// (<method>OcuPilot.Screen.Registry.Descriptors</method> and
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method>), never from a list beside them. Those
/// are the surfaces the product resolves through, so a descriptor that stops compiling or a tool
/// the registry excludes is counted the way production counts it. A failed derivation is an error
/// naming what failed, never an empty set -- an empty set would read as "nothing to cover" and
/// pass.</p>
/// <p><b>What a pinning row claims, and what it does not.</b> A row names a compiled
/// <code>Test*</code> method on a <class>%UnitTest.TestCase</class> under
/// <package>OcuPilot.Test</package>, so deleting that method reddens naming the member. Where the
/// only method that names a member covers many members in one loop, the row declares
/// <code>corpus</code> and the count of such rows is reported -- so the granularity this floor
/// actually has is a number in the output rather than a silent assumption, the treatment AD-44
/// gives classic-link exemptions.</p>
/// <p>Needs a compiled instance; makes no request and writes nothing.</p>
Class OcuPilot.Test.SurfaceCoverage Extends %UnitTest.TestCase
{

/// <p>The package every screen descriptor sits in; rows name a descriptor without it.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The package every pinning test class sits in.</p>
Parameter TESTPACKAGE = "OcuPilot.Test.";

/// <p>The superclass a pinning class must extend for the runner to execute its methods.</p>
Parameter TESTCASECLASS = "%UnitTest.TestCase";

/// <p>The tool kind this floor covers (AD-22).</p>
Parameter WRITEKIND = "write";

/// <p>The coverage table. A <code>&lt;screen/&gt;</code> row names a descriptor without
/// <parameter>DESCRIPTORPACKAGE</parameter>; a <code>&lt;tool/&gt;</code> row names a tool by its
/// canonical dotted name; a <code>&lt;member/&gt;</code> row names one of AC2's named floor
/// members by the method that is it. <var>class</var> and <var>method</var> name the test that
/// pins it, and <var>corpus</var> is the reason where that method covers many members in one
/// loop.</p>
/// <p><b>Why the <code>&lt;member/&gt;</code> rows exist.</b> AC2 names three existing test
/// classes as the floor the suite must keep. What pins them is
/// <file>ui/tools/ci-runner.mjs</file>'s on-disk-versus-instance check, which compares CLASS
/// lists -- so deleting the named test METHOD from any of them left every gate green. These rows
/// put those methods under the same <method>PinProblem</method> the coverage table uses.</p>
/// <p><b>The write half has members.</b> Story 5.5 landed the first tool the registry classifies
/// <code>write</code>, <code>webapp.list.update</code>, and with it the explicit zero this block
/// used to assert -- which was written to be deleted in exactly that pass. Stories 5.9, 5.10 and
/// 5.11 landed the rest. The derived side is <method>ListTools</method>, so a further write tool
/// binds itself and reddens here until it declares its row.</p>
XData Coverage
{
<coverage>
<screen name="AgentDefinitionForm" class="OcuPilot.Test.AgentDefinitionForm" method="TestTheFormDeclaresNoReadOrTableAndOneIdAndNoClassicPage"/>
<screen name="AgentDefinitionList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="AgentSwitches" class="OcuPilot.Test.Wire" method="TestTheAgentAreaNeverGatesWhileItsScreensGateOnOcuPilotsOwnResource"/>
<screen name="AuditList" class="OcuPilot.Test.Descriptor" method="TestTheAuditListValidatesAndDeclaresItsServerCriteria"/>
<screen name="AuditingConfig" class="OcuPilot.Test.Descriptor" method="TestTheAuditingConfigurationDescriptorIsDeclaredUnbuiltAndOwnsTheWriteTool"/>
<screen name="DatabaseDetails" class="OcuPilot.Test.Descriptor" method="TestDatabaseDetailsDeclaresExactlyFifteenFieldsAndOperateAlone"/>
<screen name="DatabaseFreeSpace" class="OcuPilot.Test.Descriptor" method="TestTheFreeSpaceViewMergesInfoFiguresAndDeclaresNoMaxSize"/>
<screen name="DatabaseList" class="OcuPilot.Test.Descriptor" method="TestTheDatabasesGeneralViewDeclaresExactlyItsFiveFieldsAndFiveColumns"/>
<screen name="DatabaseVolumeList" class="OcuPilot.Test.Descriptor" method="TestDatabaseVolumesDeclaresTheVendorSixAndNoDetailCall"/>
<screen name="DeviceList" class="OcuPilot.Test.Descriptor" method="TestTheDevicesListDeclaresExactlyItsSixFieldsAndSixColumns"/>
<screen name="Home" class="OcuPilot.Test.Descriptor" method="TestARefreshingScreenDeclaresItsRatesAndHomeDeclaresNone"/>
<screen name="LdapConfigList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="LockList" class="OcuPilot.Test.Descriptor" method="TestTheLocksListDeclaresExactlyItsEightFieldsAndSevenColumns"/>
<screen name="LogAlertViewer" class="OcuPilot.Test.Descriptor" method="TestTheAlertLogViewerDeclaresTheLogSourceTailAndItsOnePair"/>
<screen name="LogErrorList" class="OcuPilot.Test.Descriptor" method="TestTheApplicationErrorLogDeclaresNoReadAndGatesOnItsNamespaceFreePairs"/>
<screen name="LogMessageViewer" class="OcuPilot.Test.Descriptor" method="TestTheConsoleLogViewerDeclaresTheLogSourceTailAndItsOnePair"/>
<screen name="OAuthClientTab" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="OAuthResourceServerTab" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="OAuthServerClientTab" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="OAuthServerDescriptionTab" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="OAuthServerTab" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="OpenApiViewer" class="OcuPilot.Test.Descriptor" method="TestTheRestApiExplorerAndDocumentViewerValidate" corpus="one test method validates both the REST API explorer and the document viewer, so neither member has a method of its own"/>
<screen name="ProcessDetails" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="ProcessList" class="OcuPilot.Test.Descriptor" method="TestTheProcessesListValidatesAndNamesTheVendorsNamespaceKey"/>
<screen name="ResourceList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="RestApiList" class="OcuPilot.Test.Descriptor" method="TestTheRestApiExplorerAndDocumentViewerValidate" corpus="one test method validates both the REST API explorer and the document viewer, so neither member has a method of its own"/>
<screen name="RoleList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="ServiceList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="SslConfigList" class="OcuPilot.Test.Descriptor" method="TestTheSslConfigurationsListValidatesAndNamesItsClassicPageInItsOwnCase"/>
<screen name="SystemUsage" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="TaskDetails" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="TaskHistoryList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="TaskOnDemandList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="TaskRunList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="TaskScheduleList" class="OcuPilot.Test.Descriptor" method="TestTheTaskScheduleListValidatesAndNamesItsClassicPageInItsOwnCase"/>
<screen name="TaskUpcomingList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="UserList" class="OcuPilot.Test.Descriptor" method="TestTheUsersListValidatesAndNamesItsClassicPageInItsOwnCase"/>
<screen name="WalletCollectionList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="WalletSecretList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<screen name="WebAppList" class="OcuPilot.Test.Descriptor" method="TestTheWebApplicationsListValidatesAndNamesItsClassicPageInItsOwnCase"/>
<screen name="X509CredentialList" class="OcuPilot.Test.ReadTool" method="TestTheRegistryListsDescriptorReadsAndInheritedKinds" corpus="named inside the production read-tool roster, which asserts every descriptor-derived read in one loop"/>
<tool name="permissions.users.update" class="OcuPilot.Test.ToolWrite" method="TestTheUserWriteToolAdvertisesEnabledAndRolesWithTheScreensOwnPairs"/>
<tool name="security.auditing.update" class="OcuPilot.Test.ToolWrite" method="TestTheAuditingWriteToolAdvertisesEnabledAloneAndDeclaresItsWriteDestructive"/>
<tool name="tasks.schedule.resume" class="OcuPilot.Test.ToolWrite" method="TestTheTaskResumeToolIsAnActionWriteOverTheScreensOwnPairs"/>
<tool name="webapp.list.update" class="OcuPilot.Test.ToolWrite" method="TestTheRegistryAdvertisesItAsAWriteToolFulfilledOnTheInstance"/>
<member name="state-protection" class="OcuPilot.Test.State" method="TestDeniedUserCannotReachAnyStateClass"/>
<member name="audit-round-trip-record" class="OcuPilot.Test.AuditRecord" method="TestACreateRecordsTheFieldsItCreatedAtTheirDefaults"/>
<member name="audit-round-trip-verbs" class="OcuPilot.Test.AuditVerbs" method="TestADeleteIsRecordedWithWhatBecameOfItsCredentialEntry"/>
</coverage>
}

/// <p>Every screen the registry declares, built or not, by descriptor name without
/// <parameter>DESCRIPTORPACKAGE</parameter>, in <var>pRows</var>. A failing status from the
/// registry, or a descriptor that cannot answer <method>IsBuilt</method>, is an error.</p>
ClassMethod DeriveScreens(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
        If $$$ISERR(tSC) Quit
        If $ListLength(tList) = 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the screen registry enumerated no descriptor at all, which is a failed derivation rather than a product with no screens")
            Quit
        }
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            ; DW-1453: every declared descriptor, built or not. IsBuilt is still called, so a
            ; descriptor that cannot answer it is the error the header promises rather than a row
            ; quietly missing from the roster.
            Do $ClassMethod(tClass, "IsBuilt")
            Set pRows($Extract(tClass, $Length(..#DESCRIPTORPACKAGE) + 1, *)) = tClass
        }
    } Catch ex {
        Kill pRows
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every tool the registry classifies <parameter>WRITEKIND</parameter>, by canonical name, in
/// <var>pRows</var>. <var>pTotal</var> is how many tools the registry listed in all, so a
/// narrowed enumeration is visible before a member is.</p>
ClassMethod DeriveWriteTools(Output pRows, Output pTotal As %Integer) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Set pTotal = 0
    Try {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTools) {
            Set tSC = $$$ERROR($$$GeneralError, "the tool registry answered no list at all, which is a failed derivation rather than a product with no tools")
            Quit
        }
        Set pTotal = tTools.%Size()
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            If tTool.kind '= ..#WRITEKIND Continue
            ; An empty name would write a "" subscript $Order never reaches, so the tool would be
            ; silently uncovered -- a failed lookup scored as a negative result.
            If tTool.name = "" {
                Kill pRows
                Set tSC = $$$ERROR($$$GeneralError, "the tool registry classified a " _ ..#WRITEKIND _ " tool with no name (class '" _ tTool.class _ "'), which this floor cannot cover")
                Quit
            }
            Set pRows(tTool.name) = tTool.class
        }
    } Catch ex {
        Kill pRows
        Set pTotal = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared coverage table, subscripted by kind (<code>screen</code>, <code>tool</code> or
/// <code>member</code>) and member name, each node
/// <code>&lt;class&gt;|&lt;method&gt;|&lt;corpus&gt;</code>.</p>
ClassMethod Stored(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Coverage", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Coverage XData block could not be opened")
            Quit
        }
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            Set tKind = ""
            If tLine [ "<screen " Set tKind = "screen"
            If tLine [ "<tool " Set tKind = "tool"
            If tLine [ "<member " Set tKind = "member"
            If tKind = "" Continue
            Set tName = ..Attribute(tLine, "name")
            ; A row whose name is absent or misspelled is an ERROR, never a row quietly dropped.
            ; A dropped <screen/> row is caught by the both-directions equality, but a dropped
            ; <member/> row is not: the member half is a one-directional roster, so a malformed
            ; row would take AC2's named floor member with it and leave every assertion green.
            If tName = "" {
                Set tSC = $$$ERROR($$$GeneralError, "a <" _ tKind _ "/> coverage row declares no name: " _ tLine)
                Quit
            }
            Set pRows(tKind, tName) = ..Attribute(tLine, "class") _ "|" _ ..Attribute(tLine, "method") _ "|" _ ..Attribute(tLine, "corpus")
        }
        Set tXData = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One double-quoted attribute value out of a coverage row.</p>
/// <p>The name is matched with the space that precedes it, so only a whole attribute name
/// matches: an unanchored search for <code>class</code> would also answer a
/// <code>subclass</code> attribute's value.</p>
ClassMethod Attribute(pLine As %String, pName As %String) As %String [ Private ]
{
    Set tNeedle = " " _ pName _ "="""
    If pLine '[ tNeedle Quit ""
    Quit $Piece($Piece(pLine, tNeedle, 2), """", 1)
}

/// <p>The drift between a derived member set and the coverage rows of kind <var>pKind</var>, in
/// both directions: a derived member with no row, and a row naming no derived member.
/// <code>""</code> when they agree. <var>pDerivedNoun</var> names the derived population in the
/// message ("a built screen"), and the two counts come back for the size assertion.</p>
ClassMethod Drift(ByRef pDerived, ByRef pRows, pKind As %String, pDerivedNoun As %String, Output pDerivedCount As %Integer, Output pDeclaredCount As %Integer) As %String
{
    Set tDrift = "", pDerivedCount = 0, pDeclaredCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pDerived(tName))
        Quit:tName=""
        Set pDerivedCount = pDerivedCount + 1
        If '$Data(pRows(pKind, tName)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tName _ " is " _ pDerivedNoun _ " with no coverage row -- add one naming the test that pins it"
        }
    }
    Set tName = ""
    For {
        Set tName = $Order(pRows(pKind, tName))
        Quit:tName=""
        Set pDeclaredCount = pDeclaredCount + 1
        If '$Data(pDerived(tName)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tName _ " has a coverage row and is not " _ pDerivedNoun _ " -- remove it"
        }
    }
    Quit tDrift
}

/// <p>AC3 -- the declared-screen set and the coverage table are equal in both directions, so a
/// descriptor with no row, and a row naming a descriptor that no longer exists, each fail naming
/// the member.</p>
/// <p>Mutation: delete one <code>&lt;screen/&gt;</code> row -> red naming the uncovered
/// descriptor; restore <method>DeriveScreens</method>' <code>built</code> filter -> the
/// <code>AuditingConfig</code> row reads as an orphan and this goes red (DW-1453).</p>
Method TestEveryDeclaredScreenHasACoverageRowAndBack()
{
    Set tSC = ..DeriveScreens(.tScreens)
    Do $$$AssertStatusOK(tSC, "the declared-screen set derives from the screen registry, built and unbuilt alike")
    Set tStoredSC = ..Stored(.tRows)
    Do $$$AssertStatusOK(tStoredSC, "the coverage table parses")

    Set tDrift = ..Drift(.tScreens, .tRows, "screen", "a declared screen", .tDerived, .tDeclared)
    Do $$$AssertEquals(tDrift, "", "the declared screens and the coverage table agree")
    Do $$$AssertTrue(tDerived > 0, "the registry enumerated screens at all; a run over none would pass having checked nothing")
    Do $$$AssertEquals(tDeclared, tDerived, "and the two are the same size (" _ tDeclared _ " row(s), " _ tDerived _ " declared screen(s))")
}

/// <p>AC3 -- the write-tool set and the coverage table are equal in both directions, through the
/// same <method>Drift</method> the screen half uses, which
/// <method>TestTheBothDirectionsComparisonNamesTheMemberInEachDirection</method> exercises.</p>
/// <p>The write half has members: Story 5.5 landed <code>webapp.list.update</code>, which tripped
/// the tripwire the assertion below replaced. Both sizes are asserted non-zero, so neither a
/// derivation nor a table that silently returned nothing can read as a pass.</p>
Method TestEveryWriteToolHasACoverageRowAndBack()
{
    Set tSC = ..DeriveWriteTools(.tTools, .tTotal)
    Do $$$AssertStatusOK(tSC, "the write-tool set derives from the tool registry")
    Set tStoredSC = ..Stored(.tRows)
    Do $$$AssertStatusOK(tStoredSC, "the coverage table parses")

    Do $$$AssertTrue(tTotal > 0, "the tool registry listed tools at all (" _ tTotal _ "), so an empty write set is a classification and not a failed enumeration")

    Set tDrift = ..Drift(.tTools, .tRows, "tool", "a write tool", .tDerived, .tDeclared)
    Do $$$AssertEquals(tDrift, "", "the write tools and the coverage table agree")
    Do $$$AssertEquals(tDeclared, tDerived, "and the two are the same size")
    Do $$$AssertTrue(tDerived > 0, "the write half is not empty -- the first write tool landed in Story 5.5, so a derivation that silently returned nothing cannot read as a pass here either (" _ tDerived _ ")")
}

/// <p>AC3 -- the both-directions comparison itself, over synthetic sets. Both halves above call
/// <method>Drift</method> against the sets the instance derives; this is where the comparison's
/// own two directions are driven, over sets a real branch cannot be put into.</p>
/// <p>Mutation: invert either <code>$Data</code> test in <method>Drift</method>, or delete either
/// loop -> red.</p>
Method TestTheBothDirectionsComparisonNamesTheMemberInEachDirection()
{
    ; Three names, none a substring of another, so each assertion below is about its own member.
    Kill tDerived, tRows
    Set tDerived("alpha") = 1
    Set tDerived("beta") = 1
    Set tRows("probe", "alpha") = "OcuPilot.Test.SurfaceCoverage|TestX|"
    Set tRows("probe", "gamma") = "OcuPilot.Test.SurfaceCoverage|TestX|"

    Set tDrift = ..Drift(.tDerived, .tRows, "probe", "a probe member", .tDerivedCount, .tDeclaredCount)
    Do $$$AssertEquals(tDerivedCount, 2, "both derived members were walked")
    Do $$$AssertEquals(tDeclaredCount, 2, "and both rows")
    Do $$$AssertTrue(tDrift [ "beta", "a derived member with no row is named (" _ tDrift _ ")")
    Do $$$AssertTrue(tDrift [ "gamma", "and a row naming no derived member is named (" _ tDrift _ ")")
    Do $$$AssertEquals(tDrift [ "alpha", 0, "and the member both sides carry is not (" _ tDrift _ ")")

    Kill tRows
    Set tRows("probe", "alpha") = ""
    Set tRows("probe", "beta") = ""
    Do $$$AssertEquals(..Drift(.tDerived, .tRows, "probe", "a probe member", .tAgreedDerived, .tAgreedDeclared), "", "two sets that agree drift not at all")
    Do $$$AssertEquals(tAgreedDerived, 2, "having walked both sides")
    Do $$$AssertEquals(tAgreedDeclared, 2, "in both directions")
}

/// <p>AC3 -- every coverage row names a method the sweep actually executes: a compiled
/// <code>Test*</code> method on a <class>%UnitTest.TestCase</class> under
/// <parameter>TESTPACKAGE</parameter>. The count of rows pinned by a whole-corpus method is
/// reported, so the granularity this floor has is visible rather than assumed.</p>
/// <p>AC2's <code>&lt;member/&gt;</code> rows are checked here too, which is what makes deleting
/// one of the three named test methods a failure rather than a change no gate reads.</p>
/// <p>Mutation: point one row's <code>method</code> at a name that does not exist -> red naming
/// the member and the missing method; delete the method it names from its class and recompile ->
/// the same.</p>
Method TestEveryCoverageRowNamesATestTheSuiteExecutes()
{
    Set tSC = ..Stored(.tRows)
    Do $$$AssertStatusOK(tSC, "the coverage table parses")

    Set tDrift = "", tChecked = 0, tCorpus = 0
    Set tKind = ""
    For {
        Set tKind = $Order(tRows(tKind))
        Quit:tKind=""
        Set tName = ""
        For {
            Set tName = $Order(tRows(tKind, tName))
            Quit:tName=""
            Set tRow = tRows(tKind, tName)
            Set tClass = $Piece(tRow, "|", 1)
            Set tMethod = $Piece(tRow, "|", 2)
            Set tChecked = tChecked + 1
            If tKind = "member" Set tMembers = $Get(tMembers, 0) + 1
            If $Piece(tRow, "|", 3) '= "" {
                Set tCorpus = tCorpus + 1
            } Else {
                ; A method named by two rows covers two members, which is what `corpus` means --
                ; so an undeclared sharing makes the reported "by a method of their own" count
                ; overstate the granularity this floor has. Counted here rather than trusted.
                Set tShared(tClass _ ":" _ tMethod) = $Get(tShared(tClass _ ":" _ tMethod)) _ $Select($Get(tShared(tClass _ ":" _ tMethod)) = "": "", 1: ", ") _ tName
            }
            Set tProblem = ..PinProblem(tClass, tMethod)
            If tProblem '= "" {
                Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tKind _ " " _ tName _ ": " _ tProblem
            }
        }
    }
    Do $$$AssertEquals(tDrift, "", "every coverage row names a test method the suite executes")
    Do $$$AssertTrue(tChecked > 0, "rows were checked at all")
    Do $$$AssertTrue($Get(tMembers, 0) > 0, "and AC2's named floor members are among them (" _ $Get(tMembers, 0) _ " member row(s))")
    ; Reported, and bounded on one side only: a row pinned by a whole-corpus method is legal, and
    ; the number of them is what says how fine-grained this floor really is (AD-44's treatment of
    ; exemptions). What is asserted is that they are not all of it.
    Do $$$AssertTrue(tCorpus < tChecked, tChecked _ " coverage row(s), of which " _ tCorpus _ " are pinned by a whole-corpus method and " _ (tChecked - tCorpus) _ " by a method of their own")

    ; And that the second number means what it says.
    Set tSharedDrift = "", tPair = ""
    For {
        Set tPair = $Order(tShared(tPair))
        Quit:tPair=""
        If tShared(tPair) [ ", " Set tSharedDrift = tSharedDrift _ $Select(tSharedDrift = "": "", 1: "; ") _ tPair _ " pins " _ tShared(tPair)
    }
    Do $$$AssertEquals(tSharedDrift, "", "no two rows claim a method of their own that is the same method; such a row declares corpus")
}

/// <p>Why <var>pClass</var>.<var>pMethod</var> is not a test the suite executes, or
/// <code>""</code> when it is.</p>
ClassMethod PinProblem(pClass As %String, pMethod As %String) As %String
{
    If $Extract(pClass, 1, $Length(..#TESTPACKAGE)) '= ..#TESTPACKAGE Quit "the pinning class " _ pClass _ " is not under " _ ..#TESTPACKAGE
    If $Extract(pMethod, 1, 4) '= "Test" Quit "the pinning method " _ pMethod _ " does not begin with Test, so the framework never discovers it"
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit "the pinning class " _ pClass _ " is not compiled on this instance"
    Set tIsCase = 0
    Try {
        Set tIsCase = $ClassMethod(pClass, "%Extends", ..#TESTCASECLASS)
    } Catch ex {
        Set tIsCase = 0
    }
    If 'tIsCase Quit "the pinning class " _ pClass _ " does not extend " _ ..#TESTCASECLASS
    If '$IsObject(##class(%Dictionary.CompiledMethod).IDKEYOpen(pClass, pMethod, , .tSC)) Quit "the pinning method " _ pClass _ ":" _ pMethod _ " does not exist"
    Quit ""
}

}
