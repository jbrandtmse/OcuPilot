/// <p>The globals' codes and sentences (AD-29, AD-39, Story 21.5): every <code>GLOBAL.*</code> code
/// <class>OcuPilot.Port.GlobalPort</class> answers with, and the one sentence each carries. Each sentence is published once in
/// EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file> key. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000 parameters
/// (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method> answer
/// these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>DELETE</parameter>, <parameter>NODEDELETE</parameter> and <parameter>REPLACE</parameter> are not refusals: they are the
/// consequence codes the proposal card and the dialog of a global's delete, of a node's delete and of a replace carry.</p>
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

/// <p>422: the global's node text, or the XML of its export, is above the most one export or import reads (Story 21.17).</p>
Parameter TOOLARGE = "GLOBAL.TOOLARGE";

Parameter REASONTOOLARGE = "This global is too large for OcuPilot to export or replace: the most is 3,000,000 characters.";

/// <p>403: the global is OcuPilot's own, whose data an export never reads (Story 21.17).</p>
Parameter OWNDATA = "GLOBAL.OWNDATA";

Parameter REASONOWNDATA = "OcuPilot's own data cannot be exported.";

/// <p>The consequence code a global's delete carries.</p>
Parameter DELETE = "GLOBAL.DELETE";

Parameter REASONDELETE = "Deleting removes the global and all of its data. This cannot be undone.";

/// <p>The consequence code a node's delete carries.</p>
Parameter NODEDELETE = "GLOBAL.NODE.DELETE";

Parameter REASONNODEDELETE = "Deleting removes this node and every node below it. This cannot be undone.";

/// <p>409: no plain-text value of the global holds the text a replace looks for (Story 21.18).</p>
Parameter NOCHANGE = "GLOBAL.REPLACE.NOCHANGE";

Parameter REASONNOCHANGE = "No plain-text value in this global holds that text, so nothing would change.";

/// <p>409: the global holds more nodes than one replace walks, or a replaced value would be longer than one value may be.</p>
Parameter REPLACETOOLARGE = "GLOBAL.REPLACE.TOOLARGE";

Parameter REASONREPLACETOOLARGE = "This global is too large to replace in here: it holds more than 20,000 nodes, or a replaced value would be longer than 32,767 characters.";

/// <p>409: the nodes a replace would change are not the ones that were reviewed, so nothing was written.</p>
Parameter REVIEWCHANGED = "GLOBAL.REPLACE.REVIEWCHANGED";

Parameter REASONREVIEWCHANGED = "This global changed after the replace was reviewed, so nothing was replaced. Review the replace again.";

/// <p>409: a replace is not offered in the <code>%SYS</code> namespace.</p>
Parameter SYSNAMESPACE = "GLOBAL.REPLACE.SYSNAMESPACE";

Parameter REASONSYSNAMESPACE = "Find and replace is not available in the %SYS namespace.";

/// <p>The consequence code a global's replace carries.</p>
Parameter REPLACE = "GLOBAL.REPLACE";

Parameter REASONREPLACE = "Replacing changes every value the review counts. This cannot be undone.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NOCHANGE Quit ..#REASONNOCHANGE
    If pCode = ..#REPLACETOOLARGE Quit ..#REASONREPLACETOOLARGE
    If pCode = ..#REVIEWCHANGED Quit ..#REASONREVIEWCHANGED
    If pCode = ..#SYSNAMESPACE Quit ..#REASONSYSNAMESPACE
    If pCode = ..#REPLACE Quit ..#REASONREPLACE
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#NODENOTFOUND Quit ..#REASONNODENOTFOUND
    If pCode = ..#NODENOTEDITABLE Quit ..#REASONNODENOTEDITABLE
    If pCode = ..#VALUESHAPE Quit ..#REASONVALUESHAPE
    If pCode = ..#TOOLARGE Quit ..#REASONTOOLARGE
    If pCode = ..#OWNDATA Quit ..#REASONOWNDATA
    If pCode = ..#DELETE Quit ..#REASONDELETE
    If pCode = ..#NODEDELETE Quit ..#REASONNODEDELETE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 400, 403, 404, 409 or 422, and 0 for a code that is no refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#VALUESHAPE Quit 400
    If (pCode = ..#NOTFOUND) || (pCode = ..#NODENOTFOUND) Quit 404
    If pCode = ..#NODENOTEDITABLE Quit 409
    If pCode = ..#TOOLARGE Quit 422
    If pCode = ..#OWNDATA Quit 403
    If (pCode = ..#NOCHANGE) || (pCode = ..#REPLACETOOLARGE) || (pCode = ..#REVIEWCHANGED) || (pCode = ..#SYSNAMESPACE) Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    Set tStatus = ..HttpStatusFor(pCode)
    If tStatus = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    If tStatus = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    If tStatus = 403 Quit ##class(OcuPilot.Api.Error).#FORBIDDEN
    If tStatus = 422 Quit ##class(OcuPilot.Api.Error).#VALIDATIONFAILED
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
