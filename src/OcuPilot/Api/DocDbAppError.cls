/// <p>The Doc DB applications' codes (AD-39, Story 18.30): every <code>DOCDBAPP.*</code> code the Doc DB applications
/// screens and <code>webapp.docdbapps.create</code>, <code>.update</code> and <code>.delete</code> answer, and the one
/// sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds
/// the compiler's limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.
/// <code>DOCDB.*</code> is Story 19.17's document databases and is not used here.</p>
/// <p>No sentence quotes a caller's input (AD-35).</p>
Class OcuPilot.Api.DocDbAppError Extends %RegisteredObject
{

/// <p>Envelope code: the record was refused on one or more of its fields, its <code>detail.violations</code>
/// naming each (422).</p>
Parameter VALIDATION = "DOCDBAPP.VALIDATION";

Parameter REASONVALIDATION = "The Doc DB application was refused.";

/// <p>Violation code: a name that is not a valid class name, on <code>Name</code>.</p>
Parameter NAME = "DOCDBAPP.NAME";

Parameter REASONNAME = "The name is a valid class name: letters and digits in dot-separated parts, each starting with a letter, the first optionally with a percent sign.";

/// <p>Violation code: a namespace that is empty or that this instance does not define, on
/// <code>Namespace</code>.</p>
Parameter NAMESPACE = "DOCDBAPP.NAMESPACE";

Parameter REASONNAMESPACE = "The namespace must be one this instance defines.";

/// <p>Violation code: a description over 256 characters, on <code>Description</code>.</p>
Parameter DESCRIPTION = "DOCDBAPP.DESCRIPTION";

Parameter REASONDESCRIPTION = "The description is at most 256 characters.";

/// <p>Violation code: an enabled value that is not true, false, 1 or 0, on <code>Enabled</code>.</p>
Parameter ENABLED = "DOCDBAPP.ENABLED";

Parameter REASONENABLED = "Enabled is true, false, 1 or 0.";

/// <p>Violation code: a resource that is neither empty nor a service or application resource this instance lists,
/// on <code>Resource</code>.</p>
Parameter RESOURCE = "DOCDBAPP.RESOURCE";

Parameter REASONRESOURCE = "The resource is empty, or a service or application resource this instance lists.";

/// <p>Violation code: a record already exists under that namespace and name in any case, on <code>Name</code>.</p>
Parameter TAKEN = "DOCDBAPP.TAKEN";

Parameter REASONTAKEN = "A Doc DB application with that name already exists in that namespace.";

/// <p>The longest description the instance stores.</p>
Parameter DESCRIPTIONMAX = 256;

/// <p>Every <code>DOCDBAPP.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAME, ..#NAMESPACE, ..#DESCRIPTION, ..#ENABLED, ..#RESOURCE, ..#TAKEN)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAME, ..#NAMESPACE, ..#DESCRIPTION, ..#ENABLED, ..#RESOURCE, ..#TAKEN)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#NAME) || (pCode = ..#TAKEN) Quit "Name"
    If pCode = ..#NAMESPACE Quit "Namespace"
    If pCode = ..#DESCRIPTION Quit "Description"
    If pCode = ..#ENABLED Quit "Enabled"
    If pCode = ..#RESOURCE Quit "Resource"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAME Quit ..#REASONNAME
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#DESCRIPTION Quit ..#REASONDESCRIPTION
    If pCode = ..#ENABLED Quit ..#REASONENABLED
    If pCode = ..#RESOURCE Quit ..#REASONRESOURCE
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    Quit ""
}

}
