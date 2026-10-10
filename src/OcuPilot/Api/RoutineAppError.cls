/// <p>The privileged routine applications' codes (AD-39, Story 18.31): every <code>PRIVROUTINE.*</code> code the
/// privileged routine applications screens, <code>webapp.routineapps.create</code>, <code>.update</code> and
/// <code>.delete</code>, the privileged routine endpoint and a web application write naming a routine application
/// answer, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it
/// because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.RoutineAppError Extends %RegisteredObject
{

/// <p>Envelope code: the application was refused on one or more of its fields, its <code>detail.violations</code>
/// naming each (422).</p>
Parameter VALIDATION = "PRIVROUTINE.VALIDATION";

Parameter REASONVALIDATION = "The privileged routine application was refused.";

/// <p>Violation code: a name that is empty or longer than 64 characters, on <code>Name</code>.</p>
Parameter NAME = "PRIVROUTINE.NAME";

Parameter REASONNAME = "The name is required and at most 64 characters.";

/// <p>Violation code: a description over 256 characters, on <code>Description</code>.</p>
Parameter DESCRIPTION = "PRIVROUTINE.DESCRIPTION";

Parameter REASONDESCRIPTION = "The description is at most 256 characters.";

/// <p>Violation code: an enabled value that is not true, false, 1 or 0, on <code>Enabled</code>.</p>
Parameter ENABLED = "PRIVROUTINE.ENABLED";

Parameter REASONENABLED = "Enabled is true, false, 1 or 0.";

/// <p>Violation code: a resource that is neither empty nor a service, system or application resource this instance
/// lists, on <code>Resource</code>.</p>
Parameter RESOURCE = "PRIVROUTINE.RESOURCE";

Parameter REASONRESOURCE = "The resource is empty, or a service, system or application resource this instance lists.";

/// <p>Violation code: an application of any kind already holds that name, on <code>Name</code>.</p>
Parameter TAKEN = "PRIVROUTINE.TAKEN";

Parameter REASONTAKEN = "An application with that name already exists on this instance.";

/// <p>Refusal (409) on <code>WebApp.App</code>: the named application is a privileged routine application, which a web
/// application write neither changes nor deletes. Nothing is sent.</p>
Parameter WEBAPP = "PRIVROUTINE.WEBAPP";

Parameter REASONWEBAPP = "This is a privileged routine application, so a web application change or delete does not reach it.";

/// <p>Refusal on <code>Security.PrivilegedRoutine</code>: the named application is not a privileged routine
/// application, so the endpoint does not read or change it (404 for a read, 409 for a write).</p>
Parameter TYPE = "PRIVROUTINE.TYPE";

Parameter REASONTYPE = "This application is not a privileged routine application, so this endpoint does not read or change it.";

/// <p>The longest description the instance stores.</p>
Parameter DESCRIPTIONMAX = 256;

/// <p>The longest name the instance stores.</p>
Parameter NAMEMAX = 64;

/// <p>Every <code>PRIVROUTINE.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAME, ..#DESCRIPTION, ..#ENABLED, ..#RESOURCE, ..#TAKEN, ..#WEBAPP, ..#TYPE)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAME, ..#DESCRIPTION, ..#ENABLED, ..#RESOURCE, ..#TAKEN)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#NAME) || (pCode = ..#TAKEN) Quit "Name"
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
    If pCode = ..#DESCRIPTION Quit ..#REASONDESCRIPTION
    If pCode = ..#ENABLED Quit ..#REASONENABLED
    If pCode = ..#RESOURCE Quit ..#REASONRESOURCE
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    If pCode = ..#WEBAPP Quit ..#REASONWEBAPP
    If pCode = ..#TYPE Quit ..#REASONTYPE
    Quit ""
}

}
