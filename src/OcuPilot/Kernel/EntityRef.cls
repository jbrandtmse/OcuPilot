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

/// <p>Build the reference key for <var>pType</var> / <var>pScope</var> / <var>pId</var>.
/// Refuses a type the kernel vocabulary does not hold, and an empty scope or id -- a reference
/// names something, and the scope of an object that has none is the literal
/// <code>instance</code>, never the empty string.</p>
ClassMethod Key(pType As %String, pScope As %String, pId As %String, Output pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set pKey = ""
    Try {
        Set tSC = ..Validate(pType, pScope, pId)
        If $$$ISERR(tSC) Quit
        Set tSeparator = $Char(..#REFSEPARATOR)
        Set pKey = pType _ tSeparator _ pScope _ tSeparator _ pId
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
/// wire: <code>{type, scope, id}</code>. It refuses exactly what <method>Key</method> refuses,
/// so a reference cannot reach a consumer in one form and be rejected in the other.</p>
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
