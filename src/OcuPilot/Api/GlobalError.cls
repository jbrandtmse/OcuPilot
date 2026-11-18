/// <p>The globals' codes and sentences (AD-29, AD-39, Story 21.5): every <code>GLOBAL.*</code> code
/// <class>OcuPilot.Port.GlobalPort</class> answers with, and the one sentence each carries. Each sentence is published once in
/// EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file> key. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000 parameters
/// (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method> answer
/// these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>DELETE</parameter> and <parameter>NODEDELETE</parameter> are not refusals: they are the consequence codes the proposal card
/// and the dialog of a global's delete and of a node's delete carry.</p>
Class OcuPilot.Api.GlobalError Extends %RegisteredObject
{

/// <p>404: the namespace holds no global of that name.</p>
Parameter NOTFOUND = "GLOBAL.NOTFOUND";

Parameter REASONNOTFOUND = "There is no global with that name in this namespace.";

/// <p>404: the node holds no value and has no node below it.</p>
Parameter NODENOTFOUND = "GLOBAL.NODE.NOTFOUND";

Parameter REASONNODENOTFOUND = "This node no longer holds a value or nodes below it.";

/// <p>409: the node's value is not plain text of 1,000 characters at most.</p>
Parameter NODENOTEDITABLE = "GLOBAL.NODE.NOTEDITABLE";

Parameter REASONNODENOTEDITABLE = "Only a value of plain text, 1,000 characters at most, can be edited here.";

/// <p>400: the new value is not plain text of 1,000 characters at most.</p>
Parameter VALUESHAPE = "GLOBAL.VALUE.SHAPE";

Parameter REASONVALUESHAPE = "Enter plain text of 1,000 characters at most.";

/// <p>The consequence code a global's delete carries.</p>
Parameter DELETE = "GLOBAL.DELETE";

Parameter REASONDELETE = "Deleting removes the global and all of its data. This cannot be undone.";

/// <p>The consequence code a node's delete carries.</p>
Parameter NODEDELETE = "GLOBAL.NODE.DELETE";

Parameter REASONNODEDELETE = "Deleting removes this node and every node below it. This cannot be undone.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#NODENOTFOUND Quit ..#REASONNODENOTFOUND
    If pCode = ..#NODENOTEDITABLE Quit ..#REASONNODENOTEDITABLE
    If pCode = ..#VALUESHAPE Quit ..#REASONVALUESHAPE
    If pCode = ..#DELETE Quit ..#REASONDELETE
    If pCode = ..#NODEDELETE Quit ..#REASONNODEDELETE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 400, 404 or 409, and 0 for a code that is no refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#VALUESHAPE Quit 400
    If (pCode = ..#NOTFOUND) || (pCode = ..#NODENOTFOUND) Quit 404
    If pCode = ..#NODENOTEDITABLE Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    Set tStatus = ..HttpStatusFor(pCode)
    If tStatus = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    If tStatus = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
