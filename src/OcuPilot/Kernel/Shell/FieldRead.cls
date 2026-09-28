/// <p>The shell-chrome field read: a set of named members, each read in the calling process behind
/// its own <code>Try</code>, so a refused or broken source degrades that one member to
/// <code>""</code> and reaches the log while the others still answer (AD-8, AD-36's shell-chrome
/// exception).</p>
/// <p>A subclass names its members in <method>Members</method>, reads each in
/// <method>ReadSource</method>, and sets <parameter>LOGSUBSYSTEM</parameter> and
/// <parameter>LOGMESSAGE</parameter>. <var>pContext</var> carries whatever a subclass prepared once
/// for several members; the base never reads it.</p>
Class OcuPilot.Kernel.Shell.FieldRead Extends %RegisteredObject
{

/// <p>The subsystem a failed source is logged under.</p>
Parameter LOGSUBSYSTEM As %String;

/// <p>The log line's message for a failed source.</p>
Parameter LOGMESSAGE As %String;

/// <p>The members <method>Fields</method> reads, in order. A member's name is also its
/// <method>ReadSource</method> field name.</p>
ClassMethod Members() As %List
{
    Quit ""
}

/// <p>Every member of <method>Members</method> as a string member of a new <var>pObject</var>,
/// each through <method>Field</method>. The status reports whether the object could be built,
/// never whether a member answered.</p>
ClassMethod Fields(Output pObject As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set pObject = {}
        Set tMembers = ..Members()
        For tI = 1:1:$ListLength(tMembers) {
            Set tMember = $List(tMembers, tI)
            Do pObject.%Set(tMember, ..Field(tMember, .pContext), "string")
        }
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One raw read, behind its own <code>Try</code>: <method>ReadSource</method>'s answer, or
/// <code>""</code> after a raise, which reaches the log through
/// <method>LogSourceFailure</method>.</p>
ClassMethod Field(pField As %String, ByRef pContext) As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource(pField, .pContext)
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure(pField, ex)
    }
    Quit tValue
}

/// <p>The raw read of <var>pField</var>; an unknown field reads <code>""</code>. A subclass
/// overrides it, and a test fixture overrides the subclass to make one source fail.</p>
ClassMethod ReadSource(pField As %String, ByRef pContext) As %String
{
    Quit ""
}

/// <p>Log one failed source under <parameter>LOGSUBSYSTEM</parameter>, naming
/// <var>pField</var>. It swallows its own failure, because it is called from inside
/// <method>Field</method>'s <code>Catch</code>. Overridable for capture in a test.</p>
ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, ..#LOGMESSAGE, {"field": (pField), "detail": (pException.DisplayString())})
    } Catch {
    }
}

}
