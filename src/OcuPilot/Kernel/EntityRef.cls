/// <p>The <code>(entity type, scope, id)</code> triple every reference that crosses a boundary
/// carries (AD-13, AD-14): a change event's subject, a proposal's target, a highlight target and
/// an audit marker. A task named <code>Nightly purge</code> in <code>USER</code> and one in
/// <code>HSCUSTOM</code> are different entities, so an id alone is never an identity.</p>
/// <p>The type is validated against <class>OcuPilot.Kernel.EntityType</class>, the kernel's
/// closed vocabulary; the scope is either a namespace or the literal
/// <parameter>OcuPilot.Kernel.Scope.SCOPEINSTANCE</parameter>, resolved from a descriptor's
/// declared <code>scope</code> by <method>ScopeFor</method>.</p>
/// <p><b>A reference key is not a URL segment.</b> It is built by joining the three parts with
/// <parameter>REFSEPARATOR</parameter>, never by running them through
/// <class>OcuPilot.Kernel.EntityId</class>: that codec encodes twice and decodes once because
/// the web server consumes one decoding in transit, so <code>Decode(Encode(x))</code> is
/// deliberately not the identity and a key built from the pair would have no inverse. The
/// separator is one code point above that codec's
/// <parameter>OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR</parameter>, on the same inference --
/// the composite keys Release 1 administers are IRIS identifiers, namespace names and
/// web-application paths, none of which can hold a control character (inference) -- so a composite
/// id reaches the key with its parts intact and splits back on its own separator. What the
/// separator does not protect is the parts' spelling: <method>NormalizedId</method> answers on the
/// whole id, so a composite id of a type that has a rule has every part folded by it. No caller
/// builds one today.</p>
/// <p><b>One entity, one key.</b> An id reaches a key through <method>NormalizedId</method>, which
/// is keyed by entity type because the instance's own resolution is: two spellings a web
/// application resolves alike are one target to AD-34's per-target lock, to its sibling cancel and
/// to the <property>OcuPilot.Kernel.State.Propose.TargetRef</property> the ledger and the proposal
/// panel show. <method>Canonical</method> is the same answer for a caller handed a stored key
/// rather than one it built. The rule itself lives here alone --
/// <method>OcuPilot.Kernel.Proposal.Prohibited.NormalizedPath</method> delegates here rather than
/// holding a copy -- while which entry point applies it is each one's own decision:
/// <method>Key</method> does, <method>Wire</method> deliberately does not.</p>
/// <p><b>No production consumer yet.</b> Nothing writes in Epic 1, so nothing publishes a
/// change event; the first consumers are Story 1.14's re-fetch routing and Epic 5's proposal
/// targets and audit markers. <file>ui/src/app/core/entity-ref.ts</file> is the client mirror of
/// the same grammar.</p>
Class OcuPilot.Kernel.EntityRef Extends %RegisteredObject
{

/// <p>The character joining the three parts of a reference key, as its code point. See the
/// class header for why it is one above
/// <parameter>OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR</parameter> rather than the same
/// value.</p>
Parameter REFSEPARATOR = 2;

/// <p>The web-application entity type's key, spelled once for the callers that name that type
/// directly (<method>OcuPilot.Kernel.Proposal.Prohibited.NormalizedPath</method>). Which types
/// have a canonical spelling is <parameter>IDRULES</parameter>, not this parameter.</p>
Parameter TYPEWEBAPPLICATION = "web-application";

/// <p>The per-type canonical id rules, as comma-separated <code>type:rule</code> pairs. A type
/// absent from this table canonicalizes to itself, so adding one is a decision about that type's
/// identity rather than a default applied to it.</p>
/// <p><b>It is declared as data because a generator reads it.</b>
/// <file>ui/tools/screen-mirror.mjs</file> mirrors it into
/// <file>ui/src/app/core/screens.generated.ts</file> so the client's key builder applies the same
/// rule this class does (AD-5: one source, two readers). A pair naming a type outside
/// <parameter>OcuPilot.Kernel.EntityType.TYPES</parameter>, or a rule the generator cannot
/// implement, fails <code>npm run build</code> rather than reaching the client as a silent
/// no-op. A later write-tool story adds one pair here, never a branch in two languages.</p>
Parameter IDRULES = "web-application:foldcase-striptrailingslash,user:foldcase,auditing-configuration:singleton,task:integer,process:integer,application-error:foldcase,role:foldcase";

/// <p>The closed rule vocabulary <parameter>IDRULES</parameter> selects from. A rule named there
/// and absent here is a declaration error, pinned by
/// <class>OcuPilot.Test.EntityRef</class>.</p>
Parameter IDRULENAMES = "foldcase-striptrailingslash,foldcase,singleton,integer";

/// <p>The web-application rule: fold to lower case, then strip every trailing slash.</p>
Parameter RULEFOLDCASESTRIPTRAILINGSLASH = "foldcase-striptrailingslash";

/// <p>The user rule, the application error log's and a role's. Fold to lower case, and nothing else.
/// A role name is compared case-insensitively by <class>Security.Roles</class>, so two spellings
/// are one role. An
/// account name is an IRIS identifier with no path grammar, so there is no slash to strip and a
/// trailing one is part of no name the instance resolves.</p>
/// <p>An <code>application-error</code> id is the namespace the drill reached, and
/// <code>SYS.ApplicationError</code> resolves that name case-insensitively -- measured on the
/// instance 2026-09-22, where <code>DateList</code> answered the same six rows for
/// <code>HSCUSTOM</code>, <code>hscustom</code> and <code>HsCustom</code> -- so two spellings are
/// one entity and AD-34's per-target lock has to cover both (AD-13).</p>
Parameter RULEFOLDCASE = "foldcase";

/// <p>The auditing-configuration rule: answer <parameter>RULESINGLETONID</parameter> whatever the
/// caller sent. A configuration object with exactly one instance has no name to fold -- the
/// caller-supplied id is a required schema property of every write tool
/// (<method>OcuPilot.Screen.Tool.Write.View</method> is <code>Final</code>), so without this rule
/// the target key would be whatever the model typed and two spellings would be two targets,
/// defeating AD-34's per-target lock and its sibling cancel.</p>
Parameter RULESINGLETON = "singleton";

/// <p>The task and process rule: a numeric id in its plain decimal spelling. Both vendor ids are
/// integers the model supplies as strings through
/// <method>OcuPilot.Screen.Tool.Write.View</method>, so <code>"007"</code>, <code>"+7"</code> and
/// <code>" 7 "</code> are spellings of one target and would otherwise be three keys. Measured on
/// this build against <code>Process</code>'s own <code>GET</code>, <code>"837"</code>,
/// <code>"0837"</code>, <code>"+837"</code> and <code>"837 "</code> all answer pid 837. A value
/// this rule cannot read as an integer is answered verbatim, as a type with no rule is.</p>
Parameter RULEINTEGER = "integer";

/// <p>The one id a <parameter>RULESINGLETON</parameter> type's reference carries.
/// <code>SYSTEM</code> is <class>Security.System</class>'s own row id, which
/// <code>%Api.Admin.Endpoints.Security.Audit.Enabled</code>'s <code>RunPut</code> opens, rather
/// than an invention of this class.</p>
/// <p><b>Mirrored, not copied.</b> <file>ui/tools/screen-mirror.mjs</file> reads this parameter and
/// emits it as <code>ENTITY_SINGLETON_ID</code>, and
/// <file>ui/src/app/core/entity-ref.ts</file> builds the rule from that rather than from a literal
/// of its own -- the discipline <parameter>REFSEPARATOR</parameter> already follows, because a
/// hand-copied second spelling is two key builders that agree on everything but the id.</p>
Parameter RULESINGLETONID = "SYSTEM";

/// <p>Build the reference key for <var>pType</var> / <var>pScope</var> / <var>pId</var>.
/// Refuses a type the kernel vocabulary does not hold, and an empty scope or id -- a reference
/// names something, and the scope of an object that has none is the literal
/// <code>instance</code>, never the empty string.</p>
/// <p>The id reaches the key in the spelling <method>NormalizedId</method> answers for that type,
/// so two ids the instance resolves to one entity produce one key. An id that normalizes to
/// nothing is refused as an empty id rather than building a key with none.</p>
ClassMethod Key(pType As %String, pScope As %String, pId As %String, Output pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set pKey = ""
    Try {
        Set tId = ..NormalizedId(pType, pId)
        Set tSC = ..Validate(pType, pScope, tId)
        If $$$ISERR(tSC) Quit
        Set tSeparator = $Char(..#REFSEPARATOR)
        Set pKey = pType _ tSeparator _ pScope _ tSeparator _ tId
    } Catch ex {
        Set pKey = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Split <var>pKey</var> back into its three parts. The id is everything after the second
/// separator, so a composite id carrying
/// <parameter>OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR</parameter> comes back whole.</p>
ClassMethod Parse(pKey As %String, Output pType As %String, Output pScope As %String, Output pId As %String) As %Status
{
    Set tSC = $$$OK
    Set pType = ""
    Set pScope = ""
    Set pId = ""
    Try {
        Set tSeparator = $Char(..#REFSEPARATOR)
        If $Length(pKey, tSeparator) < 3 {
            Set tSC = $$$ERROR($$$GeneralError, "a reference key carries an entity type, a scope and an id")
            Quit
        }
        Set tType = $Piece(pKey, tSeparator, 1)
        Set tScope = $Piece(pKey, tSeparator, 2)
        Set tId = $Piece(pKey, tSeparator, 3, *)
        Set tSC = ..Validate(tType, tScope, tId)
        If $$$ISERR(tSC) Quit
        Set pType = tType
        Set pScope = tScope
        Set pId = tId
    } Catch ex {
        Set pType = ""
        Set pScope = ""
        Set pId = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The triple as the object a change event, a proposal target or an audit marker puts on the
/// wire: <code>{type, scope, id}</code>. It asks of a triple what <method>Validate</method> asks,
/// which is what <method>Key</method> asks of the id it has already normalized -- so the two agree
/// except where that normalization is the difference: a web-application id of <code>/</code>
/// normalizes to nothing and <method>Key</method> refuses it, while this method answers the raw
/// triple.</p>
/// <p>It renders the id it is handed rather than normalizing it: a change event's subject is the
/// spelling its publisher read the object under, which is the spelling the screen that subscribes
/// holds too, and normalizing here would make those two disagree. A proposal's target is already
/// canonical when it reaches this method, because <class>OcuPilot.Kernel.Proposal.Mint</class>
/// hands it <method>Parse</method>'s reading of the key it stored.</p>
ClassMethod Wire(pType As %String, pScope As %String, pId As %String, Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tSC = ..Validate(pType, pScope, pId)
        If $$$ISERR(tSC) Quit
        Set pObject = {}
        Do pObject.%Set("type", pType)
        Do pObject.%Set("scope", pScope)
        Do pObject.%Set("id", pId)
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The scope half of a reference to an entity on a screen whose descriptor declares
/// <var>pDeclaredScope</var>: this request's resolved namespace for <code>namespace</code>, the
/// literal <code>instance</code> for <code>instance</code>, and <code>""</code> for anything
/// else -- a value <method>OcuPilot.Screen.Registry.Validate</method> refuses before a
/// descriptor carrying it can reach a roster.</p>
ClassMethod ScopeFor(pDeclaredScope As %String) As %String
{
    If pDeclaredScope = ##class(OcuPilot.Kernel.Scope).#SCOPENAMESPACE Quit ##class(OcuPilot.Kernel.Scope).Current()
    If pDeclaredScope = ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE Quit ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE
    Quit ""
}

/// <p><var>pId</var> in the one spelling a reference to an entity of type <var>pType</var>
/// carries. Two ids that answer alike here name one entity and so build one key.</p>
/// <p><b>The rule is per entity type and declared as data</b>, in
/// <parameter>IDRULES</parameter>, because the instance's own resolution is per type: a web
/// application's path resolves case-insensitively and with trailing slashes ignored, an account
/// name resolves case-insensitively and has no path grammar to strip, a task is addressed by the
/// vendor's own integer id, and a role name is the instance's own string. A type the table holds
/// no pair for is answered verbatim.
/// This method applies the named rule; it does not decide which types have one.</p>
/// <p><b>Probed on this build, not assumed</b> (<code>ocupilot-ci</code>, 2026-09-20):
/// <code>Security.Applications</code> keeps a name's case as created
/// (<code>/csp/OcuPilotProbeCase</code> reads back verbatim) and resolves either spelling, and the
/// vendor <code>WebApp.App</code> <code>GET</code> answers the same application for
/// <code>/API/OcuPilot</code>, <code>/api/ocupilot/</code> and <code>/API/OCUPILOT///</code> but
/// nothing for <code>api/ocupilot</code>, <code>/api//ocupilot</code>,
/// <code>/api/ocupilot/.</code> or a trailing space -- so the rule goes exactly this far.
/// <method>OcuPilot.Test.ProhibitedRoute.TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt</method>
/// compares it with the port's own answers rather than with this sentence.</p>
/// <p><b>The user rule was probed the same way</b> (<code>ocupilot-slot-a</code>, 2026-09-21): the
/// vendor <code>Security.User</code> <code>GET</code> answers the same account for
/// <code>_SYSTEM</code>, <code>_system</code> and <code>_System</code> and nothing for a trailing
/// space, so folding case is the whole of it.
/// <method>OcuPilot.Test.UserUpdate.TestTheUserRuleFoldsCaseTheWayTheInstanceResolvesIt</method>
/// compares it with the port's own answers.</p>
/// <p><b>The auditing-configuration rule is not a fold at all</b>: the type names one
/// configuration object, so every id answers <parameter>RULESINGLETONID</parameter> and an empty
/// id answers it too -- which is why <method>Key</method> can never refuse this type's id as
/// empty. Probed on <code>ocupilot-ci</code>, 2026-09-21: the vendor
/// <code>Security.Audit.Enabled</code> <code>GET</code> answers
/// <code>{"Enabled":true}</code> with <code>name=SYSTEM</code>, with no query parameter and with a
/// bogus one, so the endpoint identifies its target by nothing the caller sends and the id exists
/// to key the lock rather than to address the object.</p>
/// <p>The canonical form is not the instance's own spelling of the object, which is why a caller
/// addressing a target by a canonical id relies on that case-insensitive resolution.</p>
ClassMethod NormalizedId(pType As %String, pId As %String) As %String
{
    Set tRule = ..IdRuleFor(pType)
    If tRule = "" Quit pId
    If tRule = ..#RULESINGLETON Quit ..#RULESINGLETONID
    If tRule = ..#RULEINTEGER Quit ..PlainInteger(pId)
    If tRule = ..#RULEFOLDCASE Quit $ZConvert(pId, "L")
    If tRule '= ..#RULEFOLDCASESTRIPTRAILINGSLASH Quit pId
    Set tId = $ZConvert(pId, "L")
    While (tId '= "") && ($Extract(tId, $Length(tId)) = "/") {
        Set tId = $Extract(tId, 1, $Length(tId) - 1)
    }
    Quit tId
}

/// <p><var>pId</var>'s plain decimal spelling: surrounding whitespace dropped, a leading
/// <code>+</code> dropped, leading zeros dropped, and a negative zero answered as
/// <code>0</code>. A value that is not an optionally-signed run of digits is answered
/// verbatim.</p>
/// <p><b>It normalizes the string rather than arithmetic on it</b>, so
/// <file>ui/src/app/core/entity-ref.ts</file> can answer the same thing without depending on two
/// languages agreeing about numeric precision -- the divergence a key builder cannot afford
/// (AD-13, DW-1364).</p>
ClassMethod PlainInteger(pId As %String) As %String [ Private ]
{
    Set tId = $ZStrip(pId, "<>W")
    If '$Match(tId, "^[+-]?[0-9]+$") Quit pId
    Set tSign = ""
    If $Extract(tId) = "+" Set tId = $Extract(tId, 2, *)
    If $Extract(tId) = "-" Set tSign = "-", tId = $Extract(tId, 2, *)
    While ($Length(tId) > 1) && ($Extract(tId) = "0") {
        Set tId = $Extract(tId, 2, *)
    }
    If tId = "0" Set tSign = ""
    Quit tSign _ tId
}

/// <p>The rule <parameter>IDRULES</parameter> declares for <var>pType</var>, or <code>""</code>
/// when it declares none.</p>
ClassMethod IdRuleFor(pType As %String) As %String [ Private ]
{
    Set tFound = ""
    If pType = "" Quit tFound
    Set tRaw = ..#IDRULES
    For tI = 1:1:$Length(tRaw, ",") {
        Set tPair = $Piece(tRaw, ",", tI)
        If $Piece(tPair, ":", 1) '= pType Continue
        Set tFound = $Piece(tPair, ":", 2)
        Quit
    }
    Quit tFound
}

/// <p><var>pKey</var> with its id in the spelling <method>Key</method> would have built it in.</p>
/// <p><b>Caller contract:</b> it is for a caller handed a <b>stored</b> reference rather than one
/// it built, and a key this class cannot read comes back verbatim so such a caller behaves as it
/// did before rather than failing on a value it was given.
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> is the caller that needs
/// it: it is handed the ref a row stored, and a row written into the store directly -- or minted
/// before <method>NormalizedId</method> existed -- would otherwise take a lock of its own and
/// serialize against no other confirm of the same target.</p>
ClassMethod Canonical(pKey As %String) As %String
{
    Set tKey = pKey
    Try {
        If $$$ISERR(..Parse(pKey, .tType, .tScope, .tId)) Quit
        If $$$ISERR(..Key(tType, tScope, tId, .tBuilt)) Quit
        Set tKey = tBuilt
    } Catch ex {
        Set tKey = pKey
    }
    Quit tKey
}

/// <p>What every entry point above requires of a triple, in one place: a type the kernel
/// vocabulary holds, and a non-empty scope and id.</p>
ClassMethod Validate(pType As %String, pScope As %String, pId As %String) As %Status [ Private ]
{
    If '##class(OcuPilot.Kernel.EntityType).IsKnown(pType) {
        Quit $$$ERROR($$$GeneralError, "entity type '" _ pType _ "' is not in OcuPilot.Kernel.EntityType")
    }
    If pScope = "" {
        Quit $$$ERROR($$$GeneralError, "a reference carries a scope; an object with no namespace is scoped '" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ "'")
    }
    If pId = "" {
        Quit $$$ERROR($$$GeneralError, "a reference carries an id")
    }
    Quit $$$OK
}

}
