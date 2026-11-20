/// <p>The mobile phone providers' codes (AD-39, Story 21.10): every <code>PHONEPROVIDER.*</code> code the Mobile
/// phone providers screens and <code>security.phoneproviders.create</code>, <code>.update</code> and <code>.delete</code>
/// answer, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it
/// because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35).</p>
Class OcuPilot.Api.PhoneProviderError Extends %RegisteredObject
{

/// <p>Envelope code: the provider was refused on one or more of its fields, its <code>detail.violations</code>
/// naming each (422).</p>
Parameter VALIDATION = "PHONEPROVIDER.VALIDATION";

Parameter REASONVALIDATION = "The provider was refused.";

/// <p>Violation code: a name that is empty, over 50 characters or holds a control character, on <code>Name</code>.</p>
Parameter NAME = "PHONEPROVIDER.NAME";

Parameter REASONNAME = "The provider name is 1 to 50 characters with no control character.";

/// <p>Violation code: an SMS gateway that is empty, over 50 characters or holds a control character, on
/// <code>SMSGateway</code>.</p>
Parameter GATEWAY = "PHONEPROVIDER.GATEWAY";

Parameter REASONGATEWAY = "The SMS gateway is 1 to 50 characters with no control character.";

/// <p>Violation code and refusal (409): a provider already exists under that name, on <code>Name</code>.</p>
Parameter TAKEN = "PHONEPROVIDER.TAKEN";

Parameter REASONTAKEN = "A mobile phone provider with that name already exists.";

/// <p>Refusal (404): the instance holds no provider of that name, compared exactly.</p>
Parameter NOTFOUND = "PHONEPROVIDER.NOTFOUND";

Parameter REASONNOTFOUND = "There is no mobile phone provider with that name.";

/// <p>Refusal (409): one or more users name the provider, so it is not deleted.</p>
Parameter INUSE = "PHONEPROVIDER.INUSE";

Parameter REASONINUSE = "One or more users name this provider for two-factor text messages, so it cannot be deleted. Change those users' provider first.";

/// <p>The consequence code a provider delete's proposal card carries.</p>
Parameter DELETE = "PHONEPROVIDER.DELETE";

Parameter REASONDELETE = "Deleting this provider removes it from this instance. This cannot be undone.";

/// <p>The longest provider name and SMS gateway the instance stores.</p>
Parameter NAMEMAX = 50;

Parameter GATEWAYMAX = 50;

/// <p>Every <code>PHONEPROVIDER.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAME, ..#GATEWAY, ..#TAKEN, ..#NOTFOUND, ..#INUSE, ..#DELETE)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAME, ..#GATEWAY, ..#TAKEN)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#NAME) || (pCode = ..#TAKEN) Quit "Name"
    If pCode = ..#GATEWAY Quit "SMSGateway"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAME Quit ..#REASONNAME
    If pCode = ..#GATEWAY Quit ..#REASONGATEWAY
    If pCode = ..#TAKEN Quit ..#REASONTAKEN
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#INUSE Quit ..#REASONINUSE
    If pCode = ..#DELETE Quit ..#REASONDELETE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with as a refusal: 404 or 409, and 0 for a code that is no
/// port refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#NOTFOUND Quit 404
    If (pCode = ..#TAKEN) || (pCode = ..#INUSE) Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    If ..HttpStatusFor(pCode) = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
