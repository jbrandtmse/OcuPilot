/// <p>The base every screen descriptor extends (AD-5). A subclass declares its screen once, in
/// one <code>XData Declaration</code> block of JSON, and this class reads that block through
/// typed accessors so the route table, the navigation entry, the privilege gate, the tools, the
/// change-event key and the classic link all resolve through the same declaration. Adding a
/// screen means adding a subclass; it never means editing a router or a nav list.</p>
/// <p><b>One block, two readers.</b> The server reads it through
/// <class>%Dictionary.XDataDefinition</class> (the idiom
/// <class>OcuPilot.Port.AdminPort</class> uses for the vendor's own <code>UrlMap</code>), and
/// <file>ui/tools/screen-mirror.mjs</file> reads the same block off disk to emit
/// <file>ui/src/app/core/screens.generated.ts</file>. The mirror is a checked-in generated
/// artifact, never runtime reflection and never a second hand-written source (AD-3's rule
/// applied to AD-5). The generator runs on the repository rather than in the container, which
/// has no source mount.</p>
/// <p><b>The declared fields.</b>
/// <code>route</code> (the path under the shell's base, <code>""</code> for the application
/// root), <code>area</code> (a key from <class>OcuPilot.Screen.Area</class>),
/// <code>labelKey</code> (a key in the one client string source, used for the side-bar entry
/// and the screen title), <code>sideBarPosition</code>, <code>archetype</code>,
/// <code>built</code>, <code>privileges</code> (the AD-8 pair set),
/// <code>entityType</code> plus <code>secondaryEntityTypes</code> (AD-14 keys, all of which
/// participate in change-event routing), <code>scope</code>
/// (<code>namespace</code> or the literal <code>instance</code>, AD-13),
/// <code>parentScope</code> (the route of the screen whose entity this one is a sub-resource
/// of), <code>id</code> (<code>kind</code> <code>none</code> / <code>single</code> /
/// <code>composite</code> with its <code>parts</code>), <code>context</code>
/// (<code>fields</code> and the <code>secretFields</code> that never leave the instance,
/// AD-24), <code>primaryAction</code> and <code>rowActions</code> with their
/// <code>selfProtection</code> rules, <code>emptyStateKey</code>,
/// <code>commandAliases</code>, <code>classicPage</code> (the class name of the classic page
/// this screen replaces, AD-27/AD-44), <code>classicLinkExemption</code> with its
/// <code>reason</code> (AD-44), and <code>toolIdentifier</code>.</p>
/// <p><b><code>toolIdentifier</code> is its own field and is never derived</b> from the route
/// or the display name, so renaming a screen cannot orphan its write tools or their governance
/// keys (AD-5).</p>
/// <p><b>Nothing here consumes the tool, context, action or refresh declarations yet.</b> This
/// story delivers the declaration and the three things that read it now -- route, navigation
/// entry, gate. Stories 1.10, 1.11, 1.14 and 1.15 and Epic 2 onward consume the rest.</p>
Class OcuPilot.Screen.Descriptor.Base Extends %RegisteredObject [ Abstract ]
{

/// <p>The name of the XData block a subclass declares its screen in.</p>
Parameter DECLARATIONXDATA = "Declaration";

/// <p>The declaration as a <class>%DynamicObject</class>, read from this class's own
/// <parameter>DECLARATIONXDATA</parameter> block.</p>
/// <p><b>Overridable</b> so a test fixture can supply a declaration no checked-in XData
/// carries -- an entity type outside the kernel enum, for instance, which the build gates in
/// <file>scripts/check-objectscript.py</file> would otherwise refuse to let into the tree.
/// Production descriptors never override it.</p>
ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), ..#DECLARATIONXDATA, , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "screen descriptor " _ $ClassName() _ " carries no " _ ..#DECLARATIONXDATA _ " XData block")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        If '$IsObject(pObject) {
            Set pObject = ""
            Set tSC = $$$ERROR($$$GeneralError, "screen descriptor " _ $ClassName() _ " declaration is not a JSON object")
        }
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One top-level declared value, or <code>""</code> when the declaration cannot be read or
/// does not carry <var>pName</var>. Every scalar accessor below goes through this, so a
/// descriptor whose block will not parse reads as empty everywhere rather than throwing in one
/// accessor and not another.</p>
ClassMethod Field(pName As %String) As %RawString
{
    Set tValue = ""
    Try {
        Set tSC = ..DeclarationJson(.tObject)
        If $$$ISERR(tSC) Quit
        Set tValue = tObject.%Get(pName)
    } Catch {
        Set tValue = ""
    }
    Quit tValue
}

/// <p>The path this screen is routed at, under the shell's own base. <code>""</code> means the
/// application root, which is Home's.</p>
ClassMethod Route() As %String
{
    Quit ..Field("route")
}

/// <p>The key of the area whose rail item and side bar this screen belongs to.</p>
ClassMethod AreaKey() As %String
{
    Quit ..Field("area")
}

/// <p>The client string key for this screen's side-bar entry and title.</p>
ClassMethod LabelKey() As %String
{
    Quit ..Field("labelKey")
}

/// <p>This screen's position in its area's side bar, ascending.</p>
ClassMethod SideBarPosition() As %Integer
{
    Quit +..Field("sideBarPosition")
}

/// <p>The state-matrix archetype this screen is, which fixes the states it must show.</p>
ClassMethod Archetype() As %String
{
    Quit ..Field("archetype")
}

/// <p>Whether this screen exists yet. An unbuilt screen is declared, routed by nothing and
/// listed by no side bar -- "a screen that is not yet built does not appear in the side-bar"
/// (<file>EXPERIENCE.md</file> `:157`).</p>
ClassMethod IsBuilt() As %Boolean
{
    Quit ''..Field("built")
}

/// <p>The declared privilege pair set as a <class>%List</class> of
/// <code>$ListBuild(resource, permission)</code>, <b>all</b> of which the gate requires
/// (AD-8). Empty means the screen itself never gates; the classic page's custom resource is
/// unioned on by <class>OcuPilot.Screen.Gate</class>, not here.</p>
ClassMethod PrivilegePairs() As %List
{
    Set tPairs = ""
    Try {
        Set tSC = ..DeclarationJson(.tObject)
        If $$$ISERR(tSC) Quit
        Set tPairs = ##class(OcuPilot.Screen.Area).PairsFrom(tObject.%Get("privileges"))
    } Catch {
        Set tPairs = ""
    }
    Quit tPairs
}

/// <p>The primary entity type (AD-14), which drives the route and the change-event key.
/// <code>""</code> for a screen that administers no entity.</p>
ClassMethod PrimaryEntityType() As %String
{
    Quit ..Field("entityType")
}

/// <p>The secondary entity types, as a <class>%List</class>. They are declared and participate
/// in change-event routing; only the primary drives the route.</p>
ClassMethod SecondaryEntityTypes() As %List
{
    Quit ..StringList("secondaryEntityTypes")
}

/// <p>Every entity type this descriptor names, primary first, with empties dropped. This is
/// the list <class>OcuPilot.Screen.Registry</class> validates against
/// <class>OcuPilot.Kernel.EntityType</class>.</p>
ClassMethod EntityTypes() As %List
{
    Set tTypes = ""
    Set tPrimary = ..PrimaryEntityType()
    If tPrimary '= "" Set tTypes = $ListBuild(tPrimary)
    Quit tTypes _ ..SecondaryEntityTypes()
}

/// <p>The data scope every read and write on this screen executes against: <code>namespace</code>
/// for a namespace-scoped object, the literal <code>instance</code> for a configuration object
/// that has none (AD-13).</p>
ClassMethod Scope() As %String
{
    Quit ..Field("scope")
}

/// <p>The route of the screen whose entity this one is a sub-resource of, or <code>""</code>.
/// Task history is not a task, and its rows are not the entity its route identifies.</p>
ClassMethod ParentScope() As %String
{
    Quit ..Field("parentScope")
}

/// <p>How this screen's rows are identified: <code>none</code>, <code>single</code>, or
/// <code>composite</code> -- whose parts <method>IdParts</method> names and the one shared
/// codec joins (AD-13). A slice never invents a second composite grammar.</p>
ClassMethod IdKind() As %String
{
    Quit ..NestedField("id", "kind")
}

/// <p>The named parts of a composite id, in the order the shared encoder joins them. Empty for
/// every other kind.</p>
ClassMethod IdParts() As %List
{
    Quit ..NestedStringList("id", "parts")
}

/// <p>The fields this screen's context serializer emits (AD-24).</p>
ClassMethod ContextFields() As %List
{
    Quit ..NestedStringList("context", "fields")
}

/// <p>The secret-typed subset of <method>ContextFields</method>, which never leaves the
/// instance whatever the cap (AD-24, AD-3).</p>
ClassMethod ContextSecretFields() As %List
{
    Quit ..NestedStringList("context", "secretFields")
}

/// <p>The primary action's identifier (Create, Import, or <code>""</code> for none).</p>
ClassMethod PrimaryActionId() As %String
{
    Quit ..NestedField("primaryAction", "id")
}

/// <p>The primary action's self-protection rule, or <code>""</code>.</p>
ClassMethod PrimaryActionSelfProtection() As %String
{
    Quit ..NestedField("primaryAction", "selfProtection")
}

/// <p>The row actions' identifiers, in command-bar order, destructive last.</p>
ClassMethod RowActionIds() As %List
{
    Set tIds = ""
    Try {
        Set tSC = ..DeclarationJson(.tObject)
        If $$$ISERR(tSC) Quit
        Set tActions = tObject.%Get("rowActions")
        If '$IsObject(tActions) Quit
        Set tIterator = tActions.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAction) {
            If '$IsObject(tAction) Continue
            Set tId = tAction.%Get("id")
            If tId '= "" Set tIds = tIds _ $ListBuild(tId)
        }
    } Catch {
        Set tIds = ""
    }
    Quit tIds
}

/// <p>The client string key for this screen's empty-state sentence, or <code>""</code>.</p>
ClassMethod EmptyStateKey() As %String
{
    Quit ..Field("emptyStateKey")
}

/// <p>The command-box aliases this screen answers to, drawn from the contest wording.</p>
ClassMethod CommandAliases() As %List
{
    Quit ..StringList("commandAliases")
}

/// <p>The class name of the classic portal page this screen replaces (AD-27, AD-44), or
/// <code>""</code> for a screen with no classic equivalent -- which says so by declaring the
/// empty string rather than by omitting the field.</p>
/// <p><b>Spell it in the class's own case.</b> The lookup
/// <class>OcuPilot.Screen.Gate</class> performs normalizes a link to a class name without
/// case-folding it, so a mis-cased name silently resolves to no custom resource.</p>
ClassMethod ClassicPage() As %String
{
    Quit ..Field("classicPage")
}

/// <p>Whether this screen carries an outbound link to its classic page. A list archetype never
/// does; a detail view may, and only where this is declared true with a reason (AD-44).</p>
ClassMethod ClassicLinkExempt() As %Boolean
{
    Quit ''..NestedField("classicLinkExemption", "exempt")
}

/// <p>Why the exemption above was granted. The automated check reports every exemption it
/// honours, so the count is visible rather than silent.</p>
ClassMethod ClassicLinkExemptionReason() As %String
{
    Quit ..NestedField("classicLinkExemption", "reason")
}

/// <p>The stable identifier this screen's tools are named from (AD-5). Declared, never derived
/// from the route or the display name.</p>
ClassMethod ToolIdentifier() As %String
{
    Quit ..Field("toolIdentifier")
}

/// <p>One value nested one level under <var>pParent</var>, or <code>""</code>.</p>
ClassMethod NestedField(pParent As %String, pName As %String) As %RawString [ Private ]
{
    Set tValue = ""
    Try {
        Set tParent = ..Field(pParent)
        If '$IsObject(tParent) Quit
        Set tValue = tParent.%Get(pName)
    } Catch {
        Set tValue = ""
    }
    Quit tValue
}

/// <p>A declared array of strings as a <class>%List</class>, with empties dropped.</p>
ClassMethod StringList(pName As %String) As %List [ Private ]
{
    Quit ..ArrayToList(..Field(pName))
}

/// <p>A declared array of strings nested one level under <var>pParent</var>.</p>
ClassMethod NestedStringList(pParent As %String, pName As %String) As %List [ Private ]
{
    Quit ..ArrayToList(..NestedField(pParent, pName))
}

/// <p><var>pArray</var>'s string elements as a <class>%List</class>, empties dropped.</p>
ClassMethod ArrayToList(pArray As %DynamicArray) As %List [ Private ]
{
    Set tList = ""
    If '$IsObject(pArray) Quit tList
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        If tValue '= "" Set tList = tList _ $ListBuild(tValue)
    }
    Quit tList
}

}
