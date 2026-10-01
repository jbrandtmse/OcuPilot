/// <p>The service editor's address codes (AD-39, Story 16.13): every <code>SERVICE.ADDRESS.*</code>
/// code an added or changed allowed connection is refused with, and the one sentence each carries.
/// They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290), as <class>OcuPilot.Api.LockError</class>
/// does; <method>OcuPilot.Api.Error.ReasonForService</method> answers these codes through
/// <method>ReasonFor</method> and <method>OcuPilot.Api.Error.ServiceViolationCodes</method> lists
/// them, so every caller still asks the one writer.</p>
Class OcuPilot.Api.ServiceError Extends %RegisteredObject
{

/// <p>Violation code: an added or changed entry's address is one
/// <code>Security.Services.ValidateClientSystemsIP</code> answers 1, 2 or 3 for -- an address or
/// range it cannot read, or a host name it cannot parse -- which the vendor's <code>Modify</code>
/// would store as sent (measured).</p>
Parameter ADDRESSINVALID = "SERVICE.ADDRESS.INVALID";

Parameter REASONADDRESSINVALID = "Use an IP address, a range such as 10.0.0.1-20, a wildcard such as 10.0.0.*, or a host name.";

/// <p>Violation code: an added or changed entry on a service whose <code>Capabilities</code> lacks
/// the client-system bit, which stores the address and never checks it (measured).</p>
Parameter ADDRESSUNSUPPORTED = "SERVICE.ADDRESS.UNSUPPORTED";

Parameter REASONADDRESSUNSUPPORTED = "This service does not check the address a connection comes from, so it takes no allowed address.";

/// <p>Violation code: an added or changed entry carrying roles on a service whose
/// <code>Capabilities</code> lacks the client-system-roles bit, which stores the roles and never
/// grants them (measured).</p>
Parameter ADDRESSROLEUNSUPPORTED = "SERVICE.ADDRESS.ROLEUNSUPPORTED";

Parameter REASONADDRESSROLEUNSUPPORTED = "This service gives a connection no roles by its address, so an address here takes no roles.";

/// <p>Every code this class declares, as a <class>%List</class>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#ADDRESSINVALID, ..#ADDRESSUNSUPPORTED, ..#ADDRESSROLEUNSUPPORTED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#ADDRESSINVALID Quit ..#REASONADDRESSINVALID
    If pCode = ..#ADDRESSUNSUPPORTED Quit ..#REASONADDRESSUNSUPPORTED
    If pCode = ..#ADDRESSROLEUNSUPPORTED Quit ..#REASONADDRESSROLEUNSUPPORTED
    Quit ""
}

}
