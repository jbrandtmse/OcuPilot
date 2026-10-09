/// <p>The percent-class access codes (AD-39, Story 18.10): the seven <code>PCTACCESS.*</code> codes a
/// class access entry answers and the one <code>PRIVROUTINE.TYPE</code> code the privileged routine
/// endpoint answers, each with the sentence it carries. They live beside
/// <class>OcuPilot.Api.Error</class> because that class holds the compiler's limit of 1,000 parameters
/// (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.PctAccessError Extends %RegisteredObject
{

/// <p>Violation code, on <code>allowType</code>: only <code>AllowClass</code> and <code>AllowPrefix</code> are
/// an access type the instance accepts.</p>
Parameter ALLOWTYPE = "PCTACCESS.ALLOWTYPE";

Parameter REASONALLOWTYPE = "Choose Allow access to a class or to a package of classes.";

/// <p>Answer (404) to a read of an entry the application does not hold; the read is absent rather than refused.</p>
Parameter NOTFOUND = "PCTACCESS.NOTFOUND";

Parameter REASONNOTFOUND = "The application holds no entry for that allow type and class.";

/// <p>Violation code, on <code>name</code>: the id is not the three parts an entry is named by.</p>
Parameter BADID = "PCTACCESS.ID";

Parameter REASONBADID = "Name an entry by its application, its allow type and its class.";

/// <p>Violation code, on <code>class</code>: a class or package name that begins with a percent sign and holds
/// letters, digits and dots.</p>
Parameter CLASS = "PCTACCESS.CLASS";

Parameter REASONCLASS = "Name a class or package that begins with a percent sign, such as %Utility.Example.";

/// <p>Violation code, on <code>application</code>: the application is absent, or the name is not a whole
/// application name.</p>
Parameter APPLICATION = "PCTACCESS.APPLICATION";

Parameter REASONAPPLICATION = "Name a web application this instance holds, or all applications.";

/// <p>Refusal (409) on a create: the instance already holds an entry with the same application, allow type and class,
/// and a create does not overwrite it.</p>
Parameter EXISTS = "PCTACCESS.EXISTS";

Parameter REASONEXISTS = "This application already has an entry for that allow type and class, so it is not added again.";

/// <p>Refusal (409): the entry belongs to the instance and goes only with its application, so it is not
/// deleted on its own. Nothing is sent.</p>
Parameter SYSTEM = "PCTACCESS.SYSTEM";

Parameter REASONSYSTEM = "This entry belongs to the instance and goes only with its application, so it cannot be deleted on its own.";

/// <p>Refusal (409) on <code>Security.PrivilegedRoutine</code>: the named application is not a privileged
/// routine application, so the endpoint does not change it.</p>
Parameter PRIVROUTINETYPE = "PRIVROUTINE.TYPE";

Parameter REASONPRIVROUTINETYPE = "This application is not a privileged routine application, so this endpoint does not read or change it.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#ALLOWTYPE Quit ..#REASONALLOWTYPE
    If pCode = ..#BADID Quit ..#REASONBADID
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#CLASS Quit ..#REASONCLASS
    If pCode = ..#APPLICATION Quit ..#REASONAPPLICATION
    If pCode = ..#SYSTEM Quit ..#REASONSYSTEM
    If pCode = ..#EXISTS Quit ..#REASONEXISTS
    If pCode = ..#PRIVROUTINETYPE Quit ..#REASONPRIVROUTINETYPE
    Quit ""
}

}
