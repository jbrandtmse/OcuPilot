/// <p>The database configuration codes (AD-39, Story 18.3): every <code>DATABASE.*</code> machine code
/// and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in
/// it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answers these codes through
/// <method>ReasonFor</method>, so every caller still asks the one writer.</p>
Class OcuPilot.Api.DatabaseError Extends %RegisteredObject
{

/// <p>Envelope code (AD-39, Story 18.3): a database's create or edit broke one or more of the rules
/// <class>OcuPilot.Area.OsMgmt.DatabaseRules</class> applies before the port is touched. Rendered on
/// the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>.</p>
Parameter VALIDATION = "DATABASE.VALIDATION";

Parameter REASONVALIDATION = "The database was refused.";

/// <p>Violation code: no database name was supplied.</p>
Parameter NAMEREQUIRED = "DATABASE.NAME.REQUIRED";

Parameter REASONNAMEREQUIRED = "Name the database.";

/// <p>Violation code: a name the instance does not accept for a database configuration (measured on
/// <code>ocupilot-b-ci</code>: a leading digit, a dot, a space or a leading <code>%</code> is refused
/// 42, and a 65th character 7201).</p>
Parameter NAMESHAPE = "DATABASE.NAME.SHAPE";

Parameter REASONNAMESHAPE = "A database name starts with a letter, then letters, digits, _ or -, at most 64 characters.";

/// <p>Violation code: a database configuration already carries that name, compared without regard
/// to case.</p>
Parameter NAMETAKEN = "DATABASE.NAME.TAKEN";

Parameter REASONNAMETAKEN = "This instance already has a database with that name. Choose a different one.";

/// <p>Violation code: an edit or a form read names a database configuration this instance does not
/// hold. Rendered at 404.</p>
Parameter NAMEABSENT = "DATABASE.NAME.ABSENT";

Parameter REASONNAMEABSENT = "This instance has no database with that name.";

/// <p>Violation code: the create's directory already holds a database file (DW-1791).</p>
Parameter DIRECTORYINUSE = "DATABASE.DIRECTORY.INUSE";

Parameter REASONDIRECTORYINUSE = "That directory already holds a database. Choose another directory.";

/// <p>Violation code: the create's initial size is not a whole number of megabytes, 1 or more.</p>
Parameter SIZESHAPE = "DATABASE.SIZE.SHAPE";

Parameter REASONSIZESHAPE = "Enter a whole number of megabytes, 1 or more.";

/// <p>Violation codes: a maximum size, expansion size or new volume threshold that is not a whole
/// number of megabytes, 0 or more.</p>
Parameter MAXSIZESHAPE = "DATABASE.MAXSIZE.SHAPE";

Parameter EXPANSIONSIZESHAPE = "DATABASE.EXPANSIONSIZE.SHAPE";

Parameter NEWVOLUMETHRESHOLDSHAPE = "DATABASE.NEWVOLUMETHRESHOLD.SHAPE";

Parameter REASONMEGABYTESSHAPE = "Enter a whole number of megabytes, 0 or more.";

/// <p>Violation code: a resource name that does not begin with <code>%DB_</code> (the vendor's 896,
/// mapped at the port).</p>
Parameter RESOURCESHAPE = "DATABASE.RESOURCE.SHAPE";

Parameter REASONRESOURCESHAPE = "A database's resource name starts with %DB_.";

/// <p>Violation code: a resource name no resource on this instance carries.</p>
Parameter RESOURCEABSENT = "DATABASE.RESOURCE.ABSENT";

Parameter REASONRESOURCEABSENT = "No resource on this instance has that name.";

/// <p>Envelope code (409): the vendor refused a configuration delete while a namespace uses the
/// database (its 429, measured on <code>ocupilot-b-ci</code>), and nothing was removed.</p>
Parameter INUSE = "DATABASE.INUSE";

Parameter REASONINUSE = "Namespaces still use this database. Delete them or point them at another database first.";

/// <p>Envelope code (409): a file-settings edit named a configuration whose database is on another
/// server, and nothing was sent.</p>
Parameter REMOTE = "DATABASE.REMOTE";

Parameter REASONREMOTE = "This database's file is on another server. Change its settings there.";

/// <p>Every field-level code, as a <class>%List</class>, in the order the form lists its rules.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAMEREQUIRED, ..#NAMESHAPE, ..#NAMETAKEN, ..#NAMEABSENT, ..#DIRECTORYINUSE, ..#SIZESHAPE, ..#MAXSIZESHAPE, ..#EXPANSIONSIZESHAPE, ..#NEWVOLUMETHRESHOLDSHAPE, ..#RESOURCESHAPE, ..#RESOURCEABSENT)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for a code this class does not
/// declare: the field-level codes, the two envelope codes and the validation envelope.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAMEREQUIRED Quit ..#REASONNAMEREQUIRED
    If pCode = ..#NAMESHAPE Quit ..#REASONNAMESHAPE
    If pCode = ..#NAMETAKEN Quit ..#REASONNAMETAKEN
    If pCode = ..#NAMEABSENT Quit ..#REASONNAMEABSENT
    If pCode = ..#DIRECTORYINUSE Quit ..#REASONDIRECTORYINUSE
    If pCode = ..#SIZESHAPE Quit ..#REASONSIZESHAPE
    If (pCode = ..#MAXSIZESHAPE) || (pCode = ..#EXPANSIONSIZESHAPE) || (pCode = ..#NEWVOLUMETHRESHOLDSHAPE) Quit ..#REASONMEGABYTESSHAPE
    If pCode = ..#RESOURCESHAPE Quit ..#REASONRESOURCESHAPE
    If pCode = ..#RESOURCEABSENT Quit ..#REASONRESOURCEABSENT
    If pCode = ..#INUSE Quit ..#REASONINUSE
    If pCode = ..#REMOTE Quit ..#REASONREMOTE
    Quit ""
}

}
