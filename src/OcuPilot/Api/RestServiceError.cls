/// <p>The spec-based REST services' codes (AD-39, Story 18.32): every <code>RESTSERVICE.*</code> code
/// <code>webapp.restapis.create</code>, <code>webapp.restapis.delete</code> and the management API port's service
/// endpoint answer, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than
/// in it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.RestServiceError Extends %RegisteredObject
{

/// <p>Envelope code: the service was refused on one or more of its fields, its <code>detail.violations</code>
/// naming each (422).</p>
Parameter VALIDATION = "RESTSERVICE.VALIDATION";

Parameter REASONVALIDATION = "The REST service was refused.";

/// <p>Violation code: a name that is not a package of at most 215 characters with no percent sign, on
/// <code>Name</code>.</p>
Parameter NAME = "RESTSERVICE.NAME";

Parameter REASONNAME = "The name is a package of at most 215 characters: letters and digits in dot-separated parts, each starting with a letter, with no percent sign.";

/// <p>Violation code: a document that is not a JSON object, whose <code>swagger</code> member is not 2.0, or that is
/// over 1,000,000 characters, on <code>Document</code>.</p>
Parameter DOCUMENT = "RESTSERVICE.DOCUMENT";

Parameter REASONDOCUMENT = "The document is an OpenAPI 2.0 document: a JSON object whose swagger member is 2.0, of at most 1,000,000 characters.";

/// <p>Violation code: a document the management API could not build a service from, on <code>Document</code>.</p>
Parameter BUILD = "RESTSERVICE.BUILD";

Parameter REASONBUILD = "The management API could not build a service from this document.";

/// <p>Violation code: a name the namespace already lists as a REST service, or whose specification or dispatch class it
/// holds, in any letter case, on <code>Name</code>. Nothing is sent.</p>
Parameter TAKEN = "RESTSERVICE.TAKEN";

Parameter REASONTAKEN = "This namespace already has a REST service of that name, or its specification or dispatch class, in some letter case.";

/// <p>Refusal (409) on a delete: a web application dispatches to the service, or the row is itself a web application.
/// Nothing is sent.</p>
Parameter DEPLOYED = "RESTSERVICE.DEPLOYED";

Parameter REASONDEPLOYED = "This row is a web application, or a web application dispatches to this service, so it is not deleted here. Web applications are deleted or repointed from the Web applications list.";

/// <p>The longest document the port sends the management API, in characters of its JSON text.</p>
Parameter DOCUMENTMAX = 1000000;

/// <p>The longest package name the port accepts: the longest class name the instance stores (220 characters) less the
/// five of the longest suffix, <code>.spec</code>.</p>
Parameter NAMEMAX = 215;

/// <p>Every <code>RESTSERVICE.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAME, ..#DOCUMENT, ..#BUILD, ..#DEPLOYED, ..#TAKEN)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAME, ..#DOCUMENT, ..#BUILD, ..#TAKEN)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#NAME) || (pCode = ..#TAKEN) Quit "Name"
    If (pCode = ..#DOCUMENT) || (pCode = ..#BUILD) Quit "Document"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAME Quit ..#REASONNAME
    If pCode = ..#DOCUMENT Quit ..#REASONDOCUMENT
    If pCode = ..#BUILD Quit ..#REASONBUILD
    If pCode = ..#DEPLOYED Quit ..#REASONDEPLOYED
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    Quit ""
}

}
