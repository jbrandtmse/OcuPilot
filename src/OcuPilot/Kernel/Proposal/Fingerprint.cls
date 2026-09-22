/// <p>The digest a proposal carries and a confirm re-computes (AD-6): a canonical, key-ordered
/// serialisation of the payload the write will send, minus the paths the descriptor declares under
/// <code>fingerprintExcludes</code>, hashed with SHA-256 and hex-encoded.</p>
/// <p><b>It covers the complete property set, and the exclusions are the descriptor's.</b> A slice
/// never chooses which fields the fingerprint covers -- only which ones it does not -- so the
/// default is everything else. That is what makes "the target moved under the diff" a question the
/// instance can answer rather than one each write tool answers for itself.</p>
/// <p><b>An action-style write inverts that selection, and only that kind does</b> (AD-51 as
/// amended 2026-09-22). Such a write sends no payload, so its diff is over state the read can see
/// rather than over a property set, and the tool declares the <b>subject</b> the digest covers:
/// <var>pSubject</var>, a <class>%List</class> of top-level names. A digest over the whole of a
/// live process's read would refuse every confirm whose target executed a command in between,
/// which is not protection but a dead path. An empty <var>pSubject</var> is the merge write's own
/// behavior, exclusions and all.</p>
/// <p><b>Canonical means key insertion order cannot change the answer.</b> An object's members are
/// emitted in <code>$Order</code> collation of their names -- one fixed order, whatever order they
/// were inserted in, with canonical numbers ahead of other strings; an array's elements keep their
/// own order, because an array's order is part of the value. A string is emitted with its length,
/// so no concatenation of two members can be read as one.</p>
/// <p><b>An excluded path is a <class>OcuPilot.Screen.Tool.ToolFields</class> path</b>: dotted
/// members, with <code>[]</code> for an array's elements (<code>MatchRoles[].MatchRole</code>). It
/// is the same grammar <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> checks a
/// declaration against, so a declared exclusion and the path it excludes are spelled once.</p>
Class OcuPilot.Kernel.Proposal.Fingerprint Extends %RegisteredObject
{

/// <p>The digest algorithm, in the bit size <code>$System.Encryption.SHAHash</code> takes.</p>
Parameter SHABITS As %Integer = 256;

/// <p>The hex digest of <var>pPayload</var> minus the paths in <var>pExcludes</var>, in
/// <var>pDigest</var>. An error status leaves it <code>""</code>.</p>
/// <p><var>pPayload</var> is a <class>%DynamicObject</class>; anything else is refused rather than
/// hashed, because a digest over a value nobody can reproduce is worse than no digest.</p>
/// <p><var>pSubject</var>, where the tool declares one (AD-51), narrows the digest to those
/// top-level members of <var>pPayload</var> before the exclusions are applied. A declared name the
/// payload does not carry is refused rather than hashed as absent: the subject is the whole of
/// what the confirm compares, so a name that reached it by a spelling the endpoint does not answer
/// would make the digest stable whatever the target did.</p>
ClassMethod Of(pPayload As %DynamicObject, pExcludes As %List = "", Output pDigest As %String, pSubject As %List = "") As %Status
{
    Set pDigest = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pPayload) || 'pPayload.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "a fingerprint is taken over an object")
            Quit
        }
        Set tSubject = pPayload
        If pSubject '= "" {
            Set tSC = ..Projection(pPayload, pSubject, .tSubject)
            If $$$ISERR(tSC) Quit
        }
        Set tCanonical = ..Canonical(tSubject, "", pExcludes)
        Set pDigest = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(..#SHABITS, $ZConvert(tCanonical, "O", "UTF8"))), "L")
    } Catch ex {
        Set pDigest = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pPayload</var> narrowed to the top-level names <var>pSubject</var> declares, in
/// <var>pProjection</var>, each member keeping its own JSON type. A declared name the payload does
/// not carry is an error.</p>
ClassMethod Projection(pPayload As %DynamicObject, pSubject As %List, Output pProjection As %DynamicObject) As %Status
{
    Set pProjection = ""
    Set tSC = $$$OK
    Try {
        Set tProjection = {}
        For tI = 1:1:$ListLength(pSubject) {
            Set tName = $List(pSubject, tI)
            Set tType = pPayload.%GetTypeOf(tName)
            If tType = "unassigned" {
                Set tSC = $$$ERROR($$$GeneralError, "the fingerprint subject names '" _ tName _ "', which this read does not answer")
                Quit
            }
            Do tProjection.%Set(tName, pPayload.%Get(tName), tType)
        }
        If $$$ISERR(tSC) Quit
        Set pProjection = tProjection
    } Catch ex {
        Set pProjection = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The canonical text of <var>pValue</var> at path <var>pPath</var>, with every path in
/// <var>pExcludes</var> left out.</p>
/// <p>An object emits <code>{</code>, each surviving member as
/// <code>&lt;length&gt;:&lt;name&gt;=&lt;value&gt;</code> in <code>$Order</code> collation of the
/// name, joined by <code>,</code>, then <code>}</code>. An array emits its elements in order, or
/// <code>[]</code> when its own <code>[]</code> path is excluded -- which is how an exclusion the
/// generator spells <code>CorsAllowlist[]</code> takes that field out of the digest. A scalar emits
/// its JSON type and its text, length-prefixed, so <code>"1"</code> and <code>1</code> cannot
/// serialise alike.</p>
ClassMethod Canonical(pValue As %RawString, pPath As %String, pExcludes As %List) As %String [ Private ]
{
    If '$IsObject(pValue) Quit ..Scalar("string", pValue)
    If pValue.%IsA("%Library.DynamicArray") {
        If $ListFind(pExcludes, pPath _ "[]") Quit "[]"
        Set tOut = "["
        Set tFirst = 1
        Set tIterator = pValue.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tElement, .tType) {
            If 'tFirst Set tOut = tOut _ ","
            Set tFirst = 0
            Set tOut = tOut _ ..Member(tElement, tType, pPath _ "[]", pExcludes)
        }
        Quit tOut _ "]"
    }
    Set tNames = ""
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tKey, .tMember, .tType) {
        Set tChild = $Select(pPath = "": tKey, 1: pPath _ "." _ tKey)
        If $ListFind(pExcludes, tChild) Continue
        Set tNames(tKey) = ""
    }
    Set tOut = "{"
    Set tFirst = 1
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        If 'tFirst Set tOut = tOut _ ","
        Set tFirst = 0
        Set tChild = $Select(pPath = "": tKey, 1: pPath _ "." _ tKey)
        Set tOut = tOut _ $Length(tKey) _ ":" _ tKey _ "=" _ ..Member(pValue.%Get(tKey), pValue.%GetTypeOf(tKey), tChild, pExcludes)
    }
    Quit tOut _ "}"
}

/// <p>The canonical text of one member: the nested form for an object or an array, the scalar form
/// otherwise.</p>
ClassMethod Member(pValue As %RawString, pType As %String, pPath As %String, pExcludes As %List) As %String [ Private ]
{
    If (pType = "object") || (pType = "array") Quit ..Canonical(pValue, pPath, pExcludes)
    Quit ..Scalar(pType, pValue)
}

/// <p>One scalar as <code>&lt;type&gt;:&lt;length&gt;:&lt;text&gt;</code>. The type is the JSON
/// type the payload carried, so a boolean, a number and their string spellings do not collide; the
/// length is what stops two adjacent values reading as one.</p>
ClassMethod Scalar(pType As %String, pValue As %RawString) As %String [ Private ]
{
    Set tText = pValue
    If (pType = "null") || (pType = "unassigned") Set tText = ""
    If pType = "boolean" Set tText = $Select(''tText: "true", 1: "false")
    Quit pType _ ":" _ $Length(tText) _ ":" _ tText
}

}
