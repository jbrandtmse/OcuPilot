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
/// <code>reason</code>, <code>label</code> and <code>href</code> (AD-44),
/// <code>refreshes</code> plus <code>refreshRates</code> and an optional <code>refreshDefault</code> (AD-43),
/// <code>read</code> (the one declared read, AD-36, or absent), <code>table</code> (the columns and
/// empty-state keys a read's rows render with, declared exactly when <code>read</code> is),
/// <code>banner</code> (a second declared port read whose value raises a strip above the table, or
/// absent), <code>tab</code> (<code>{group, position, labelKey}</code>: the route of the tab group
/// this screen is one tab of, its position in the strip and its label's string key, AD-5, or absent),
/// and <code>toolIdentifier</code>.</p>
/// <p><b><code>refreshes</code> and <code>refreshRates</code> are the whole of a screen's
/// live-data declaration</b> (AD-43). The shared framework owns the timer, the persisted
/// per-screen setting and the silent re-fetch; no screen implements refresh of its own. Rates are
/// whole seconds, ascending, and are empty unless <code>refreshes</code> --
/// <class>OcuPilot.Screen.Registry</class> refuses every other shape at install rather than at
/// render.</p>
/// <p><b><code>toolIdentifier</code> is its own field and is never derived</b> from the route
/// or the display name, so renaming a screen cannot orphan its write tools or their governance
/// keys (AD-5).</p>
/// <p><b>Every accessor reads one cached parse of the declaration</b>
/// (<method>Declaration</method>), so walking a roster costs one XData read per descriptor per
/// process, until the class is recompiled, rather than one per accessor call.</p>
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

/// <p>The declaration every accessor below reads: parsed once per process and held until the
/// class is recompiled. The cache is keyed by class name and the compiled class's hash
/// (<code>$$$cCLASShash</code>), so a recompile is read fresh on the next accessor call; a class
/// with no compiled hash is never cached. A failed read is never cached either.</p>
/// <p>The object handed back is the cached one and must not be mutated: accessors that hand a
/// nested value to a caller copy it first (<method>Field</method>). <method>DeclarationJson</method>
/// itself stays uncached, because <class>OcuPilot.Screen.Registry</class> and
/// <class>OcuPilot.Screen.Gate</class> read it as the source of truth.</p>
ClassMethod Declaration(Output pObject As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tClass = $ClassName()
        Set tHash = $$$comClassKeyGet(tClass, $$$cCLASShash)
        If (tHash '= "") && $IsObject($Get(%OcuPilotDeclarations(tClass))) && ($Get(%OcuPilotDeclarations(tClass, "hash")) = tHash) {
            Set pObject = %OcuPilotDeclarations(tClass)
            Quit
        }
        Kill %OcuPilotDeclarations(tClass)
        Set tSC = ..DeclarationJson(.tObject)
        If $$$ISERR(tSC) Quit
        Set pObject = tObject
        If tHash '= "" {
            Set %OcuPilotDeclarations(tClass) = tObject
            Set %OcuPilotDeclarations(tClass, "hash") = tHash
        }
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Drop this class's cached declaration, so the next accessor reads
/// <method>DeclarationJson</method> again.</p>
ClassMethod ForgetDeclaration()
{
    Kill %OcuPilotDeclarations($ClassName())
}

/// <p>One top-level declared value, or <code>""</code> when the declaration cannot be read or
/// does not carry <var>pName</var>. Every scalar accessor below goes through this, so a
/// descriptor whose block will not parse reads as empty everywhere rather than throwing in one
/// accessor and not another. An object or array value is a copy, so a caller cannot change the
/// cached declaration.</p>
ClassMethod Field(pName As %String) As %RawString
{
    Quit ..CopyOf(..CachedValue(pName))
}

/// <p>This screen's declared <code>read</code> (AD-36) as a copy, or <code>""</code> for a screen
/// that declares none. <method>OcuPilot.Screen.Registry.ReadProblem</method> is the grammar.</p>
ClassMethod Read() As %DynamicObject
{
    Set tRead = ..Field("read")
    If '$IsObject(tRead) Quit ""
    If 'tRead.%IsA("%Library.DynamicObject") Quit ""
    Quit tRead
}

/// <p>This screen's declared <code>banner</code> as a copy, or <code>""</code> for a screen that
/// declares none. <method>OcuPilot.Screen.Registry.BannerProblem</method> is the grammar and
/// <method>OcuPilot.Screen.Read.Execute</method> is what evaluates it.</p>
/// <p>A banner is a second declared port read whose value raises a warning strip above the table.
/// It is screen chrome rather than rows, so it rides in the read's own response and never reaches
/// the read tool's payload (AD-36).</p>
ClassMethod Banner() As %DynamicObject
{
    Set tBanner = ..Field("banner")
    If '$IsObject(tBanner) Quit ""
    If 'tBanner.%IsA("%Library.DynamicObject") Quit ""
    Quit tBanner
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

/// <p>This screen's position in its area's side bar, ascending -- and <b>0 for a screen that is
/// routable but takes no side-bar position</b>: it is reached from its own list, and the side bar,
/// the command box, Home's tile caption, the locator bar's area target and the rail's landing all
/// skip it while the route table still carries it.</p>
/// <p><code>+</code> answers 0 for an absent key as well, which is why the key is not optional:
/// <method>OcuPilot.Screen.Registry.SideBarPositionProblem</method> refuses a built screen that
/// does not declare it, so the sentinel is a declaration rather than an omission.</p>
ClassMethod SideBarPosition() As %Integer
{
    Quit +..Field("sideBarPosition")
}

/// <p>The state-matrix archetype this screen is, which fixes the states it must show and,
/// through <class>OcuPilot.Screen.Archetype</class>'s link-out class, whether it may declare a
/// <code>classicLinkExemption</code> (AD-44). A value outside that vocabulary is refused.</p>
ClassMethod Archetype() As %String
{
    Quit ..Field("archetype")
}

/// <p>Whether this screen exists yet. An unbuilt screen is declared, routed by nothing and
/// listed by no side bar -- "a screen that is not yet built does not appear in the side-bar"
/// (<file>EXPERIENCE.md</file> "Entries in daily-use order.").</p>
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
        Set tPairs = ##class(OcuPilot.Screen.Area).PairsFrom(..CachedValue("privileges"))
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

/// <p>This screen's declared <code>context.maxLength</code> map, as <var>pLengths</var>
/// subscripted by field name -> the declared whole number (AD-24). A field this screen's
/// <code>context.fields</code> names but <code>maxLength</code> does not is simply absent; a
/// caller falls back to <parameter>OcuPilot.Kernel.Agent.Limits.FIELDMAXLENGTH</parameter> for
/// it.</p>
ClassMethod ContextMaxLengths(Output pLengths)
{
    Kill pLengths
    Try {
        Set tMap = ..NestedField("context", "maxLength")
        If '$IsObject(tMap) || 'tMap.%IsA("%Library.DynamicObject") Quit
        Set tIterator = tMap.%GetIterator()
        While tIterator.%GetNext(.tField, .tValue) {
            If tField '= "" Set pLengths(tField) = +tValue
        }
    } Catch {
        Kill pLengths
    }
}

/// <p>This screen's declared <code>rowTarget</code> as a copy, or <code>""</code> for a screen
/// that declares none (AD-5, Story 6.10). A row target is a list's single cross-screen row link,
/// resolved ahead of the paired-surface chain in <file>ui/src/app/shell/data-table.ts</file> and
/// validated by <method>OcuPilot.Screen.Registry.RowTargetProblem</method> and
/// <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method>.</p>
ClassMethod RowTarget() As %DynamicObject
{
    Set tTarget = ..Field("rowTarget")
    If '$IsObject(tTarget) Quit ""
    If 'tTarget.%IsA("%Library.DynamicObject") Quit ""
    Quit tTarget
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
        Set tActions = ..CachedValue("rowActions")
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

/// <p>Where the exemption's link goes: a root-relative, same-origin path on this instance
/// (AD-47), and <code>""</code> for a screen that declares no exemption.</p>
/// <p><b>Declared, never derived.</b> <method>ClassicPage</method> is the AD-8 privilege-union
/// key and is a class name; no code path turns one into a URL, because none exists to turn it
/// into. <class>%SYS.Portal.Resources</class>' <code>NormalizePage</code> runs URL to class
/// only, the vendor publishes no inverse, and the <code>/csp/sys/{exp,mgr,op,sec}</code>
/// sub-application a portal class is served under is not a function of its class name. So a
/// descriptor that wants a link declares where it goes, here, inside the same
/// <code>classicLinkExemption</code> object as the flag and the reason.</p>
ClassMethod ClassicLinkHref() As %String
{
    Quit ..NestedField("classicLinkExemption", "href")
}

/// <p>The classic page's own name, which is what the card's action is labelled with. It is
/// descriptor data naming an external page, like <method>ClassicPage</method> itself -- not
/// shell copy the Fixed-strings table governs -- and it is <code>""</code> for a screen that
/// declares no exemption.</p>
ClassMethod ClassicLinkLabel() As %String
{
    Quit ..NestedField("classicLinkExemption", "label")
}

/// <p>Whether this screen is one the shared auto-refresh framework binds (AD-43). A screen that
/// declares it must also register the read the tick calls; binding one that has not is refused.</p>
ClassMethod Refreshes() As %Boolean
{
    Quit ''..Field("refreshes")
}

/// <p>The rates, in whole seconds, the command-bar chip may set on this screen, ascending. Empty
/// for a screen that does not refresh.</p>
/// <p><b>Every declared element is carried, including an empty or malformed one</b>, which is why
/// this does not go through <method>ArrayToList</method>: that helper drops empties, and a
/// dropped element is a malformed declaration <method>OcuPilot.Screen.Registry.Validate</method>
/// would never see.</p>
/// <p><b>Only a JSON array is read.</b> <method>%GetIterator</method> over a
/// <class>%Library.DynamicObject</class> yields that object's <i>values</i>, so
/// <code>"refreshRates": {"a": 10}</code> would otherwise be read as the sound rate list
/// <code>10</code> and install as a refreshing screen the declaration never described.</p>
ClassMethod RefreshRates() As %List
{
    Set tRates = ""
    Try {
        Set tArray = ..CachedValue("refreshRates")
        If '$IsObject(tArray) Quit
        If 'tArray.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tArray.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tValue) {
            Set tRates = tRates _ $ListBuild(tValue)
        }
    } Catch {
        Set tRates = ""
    }
    Quit tRates
}

/// <p>The rate, in whole seconds, the shared framework starts this screen at when the person has
/// remembered none, or <code>""</code> when the screen declares none; <code>""</code> and
/// <code>0</code> are off, the published default (AD-43). Declared only by a refreshing screen, as one of its
/// <method>RefreshRates</method>; <method>OcuPilot.Screen.Registry.RefreshProblem</method> refuses
/// any other value. An object or array reads as <code>"?"</code>, so the registry refuses it rather
/// than reading it as absent.</p>
ClassMethod RefreshDefault() As %String
{
    Set tValue = ..CachedValue("refreshDefault")
    If $IsObject(tValue) Quit "?"
    Quit tValue
}

/// <p>The stable identifier this screen's tools are named from (AD-5). Declared, never derived
/// from the route or the display name.</p>
ClassMethod ToolIdentifier() As %String
{
    Quit ..Field("toolIdentifier")
}

/// <p>The client string key holding the <b>singular</b> noun for this screen's primary entity type
/// (AD-5, AD-14), or <code>""</code> for a screen that publishes none yet.</p>
/// <p>A proposal card's title is the entity noun and the target's own name, and neither the wire's
/// entity-type slug nor <method>LabelKey</method>'s plural screen label is that noun -- so it is
/// declared here, once, beside the entity type it belongs to.
/// <method>OcuPilot.Screen.Registry.EntityLabelProblem</method> is the grammar.</p>
ClassMethod EntityLabelKey() As %String
{
    Quit ..Field("entityLabelKey")
}

/// <p>The top-level argument names this screen's write tools take as secret (AD-3, AD-6). Declared
/// here rather than on a tool class because the confirm channel is the descriptor's: the only keys
/// a client may supply at confirm are the fields declared secret for that tool, and a tool's input
/// schema never admits one at all.</p>
/// <p>An absent key is an empty list, which is the answer for every screen that has no secret
/// field -- and is a declaration, not silence: <method>OcuPilot.Screen.Registry.Validate</method>
/// refuses a descriptor whose declared criteria carry a credential-pattern name this list does not
/// hold, so an unlisted secret is a refusal rather than a default.</p>
ClassMethod SecretArguments() As %List
{
    Quit ..StringList("secretArguments")
}

/// <p>The payload paths a proposal's fingerprint leaves out (AD-6): the fields the endpoint itself
/// moves as a side effect -- a next-scheduled time, a last-modified stamp -- which would otherwise
/// make every confirm read a target that had changed under it.</p>
/// <p>An absent key is an empty list, and the default is "everything else": a slice never chooses
/// which fields the fingerprint covers, only which ones it does not.</p>
ClassMethod FingerprintExcludes() As %List
{
    Quit ..StringList("fingerprintExcludes")
}

/// <p>One value nested one level under <var>pParent</var>, or <code>""</code>. An object or array
/// value is a copy.</p>
ClassMethod NestedField(pParent As %String, pName As %String) As %RawString [ Private ]
{
    Quit ..CopyOf(..NestedCachedValue(pParent, pName))
}

/// <p>One top-level value of the cached declaration, uncopied, or <code>""</code>. Only readers
/// that do not hand the value on may use it.</p>
ClassMethod CachedValue(pName As %String) As %RawString [ Private ]
{
    Set tValue = ""
    Try {
        Set tSC = ..Declaration(.tObject)
        If $$$ISERR(tSC) Quit
        Set tValue = tObject.%Get(pName)
    } Catch {
        Set tValue = ""
    }
    Quit tValue
}

/// <p>One value nested one level under <var>pParent</var> in the cached declaration, uncopied, or
/// <code>""</code>.</p>
ClassMethod NestedCachedValue(pParent As %String, pName As %String) As %RawString [ Private ]
{
    Set tValue = ""
    Try {
        Set tParent = ..CachedValue(pParent)
        If '$IsObject(tParent) Quit
        Set tValue = tParent.%Get(pName)
    } Catch {
        Set tValue = ""
    }
    Quit tValue
}

/// <p><var>pValue</var> unchanged when it is not a dynamic object or array, and a deep copy when
/// it is.</p>
ClassMethod CopyOf(pValue As %RawString) As %RawString [ Private ]
{
    If '$IsObject(pValue) Quit pValue
    Quit ##class(%DynamicAbstractObject).%FromJSON(pValue.%ToJSON())
}

/// <p>The names of the <b>flag</b> criteria this screen's declared read carries: a criterion whose
/// value is the descriptor's own, not a caller's, and which is therefore nameable by an agent
/// navigation (AD-21, Story 5.8). The audit database viewer's <code>marker</code> is the one such
/// criterion in Release 1.</p>
/// <p>A flag is well-formed only when it declares both the query parameter it sends and the value
/// it sends under it; a half-declared one is not a flag and is not named here, so a caller can
/// never reach a criterion whose value nobody declared. The <code>fields</code> half of
/// <code>criteria</code> is deliberately absent: those take the value a person typed, and naming
/// one would be a caller value reaching a read.</p>
ClassMethod FlagCriteria() As %List
{
    Set tNames = ""
    Try {
        Set tRead = ..Read()
        If '$IsObject(tRead) Quit
        Set tCriteria = tRead.%Get("criteria")
        If '$IsObject(tCriteria) || 'tCriteria.%IsA("%Library.DynamicObject") Quit
        Set tIterator = tCriteria.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            If tName = "fields" Continue
            If '$IsObject(tValue) || 'tValue.%IsA("%Library.DynamicObject") Continue
            If tValue.%Get("param") = "" Continue
            If tValue.%GetTypeOf("value") = "unassigned" Continue
            Set tNames = tNames _ $ListBuild(tName)
        }
    } Catch {
        Set tNames = ""
    }
    Quit tNames
}

/// <p>A declared array of strings as a <class>%List</class>, with empties dropped.</p>
ClassMethod StringList(pName As %String) As %List [ Private ]
{
    Quit ..ArrayToList(..CachedValue(pName))
}

/// <p>A declared array of strings nested one level under <var>pParent</var>.</p>
ClassMethod NestedStringList(pParent As %String, pName As %String) As %List [ Private ]
{
    Quit ..ArrayToList(..NestedCachedValue(pParent, pName))
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
