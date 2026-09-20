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
/// web-application paths, none of which can hold a control character (inference) -- so a
/// composite id passes through a key unharmed and splits back on its own separator.</p>
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

/// <p>The one entity type whose id has a canonical spelling in Release 1
/// (<method>NormalizedId</method>).</p>
Parameter TYPEWEBAPPLICATION = "web-application";

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
/// <p><b>The rule is per entity type</b>, because the instance's own resolution is: a web
/// application's path resolves case-insensitively and with trailing slashes ignored, while a user
/// name, a role name and a task name are the instance's own strings. A type this method holds no
/// rule for is answered verbatim, so adding one is a decision about that type's identity rather
/// than a default applied to it.</p>
/// <p><b>Probed on this build, not assumed</b> (<code>ocupilot-ci</code>, 2026-09-20):
/// <code>Security.Applications</code> keeps a name's case as created
/// (<code>/csp/OcuPilotProbeCase</code> reads back verbatim) and resolves either spelling, and the
/// vendor <code>WebApp.App</code> <code>GET</code> answers the same application for
/// <code>/API/OcuPilot</code>, <code>/api/ocupilot/</code> and <code>/API/OCUPILOT///</code> but
/// nothing for <code>api/ocupilot</code>, <code>/api//ocupilot</code>,
/// <code>/api/ocupilot/.</code> or a trailing space -- so the rule goes exactly this far.
/// <method>OcuPilot.Test.ProhibitedRoute.TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt</method>
/// compares it with the port's own answers rather than with this sentence.</p>
/// <p>The canonical form is not the instance's own spelling of the object, which is why a caller
/// addressing a target by a canonical id relies on that case-insensitive resolution.</p>
ClassMethod NormalizedId(pType As %String, pId As %String) As %String
{
    If pType '= ..#TYPEWEBAPPLICATION Quit pId
    Set tId = $ZConvert(pId, "L")
    While (tId '= "") && ($Extract(tId, $Length(tId)) = "/") {
        Set tId = $Extract(tId, 1, $Length(tId) - 1)
    }
    Quit tId
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
