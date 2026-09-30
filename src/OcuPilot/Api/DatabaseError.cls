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

/// <p>Violation code (the owner's database-directory rule at AD-21's sixth case, DW-1860): a file edit
/// that leaves a new volume threshold above 0 on a database whose new volume directory is the manager
/// directory -- IRISSYS on a stock instance -- where the instance's own expansion would add volume
/// files.</p>
Parameter NEWVOLUMETHRESHOLDMANAGER = "DATABASE.NEWVOLUMETHRESHOLD.MANAGER";

Parameter REASONNEWVOLUMETHRESHOLDMANAGER = "This database's new volume directory is the manager directory, which holds the instance's own files, so its new volume threshold must be 0. Set another new volume directory first.";

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

/// <p>Envelope code (409, Story 18.4): a mount of a database that is already mounted (the vendor's
/// own 19, mapped at the port, or refused before any vendor call).</p>
Parameter MOUNTED = "DATABASE.MOUNTED";

Parameter REASONMOUNTED = "This database is already mounted.";

/// <p>Envelope code (409, Story 18.4): a dismount, truncate, compact, defragment, size grow, new
/// volume or integrity check of a database that is not mounted, refused before any vendor call.</p>
Parameter DISMOUNTED = "DATABASE.DISMOUNTED";

Parameter REASONDISMOUNTED = "This database is dismounted. Mount it first.";

/// <p>Envelope code (409, Story 18.4): a truncate, compact or defragment of a database mounted
/// read-only, refused before any vendor call.</p>
Parameter READONLY = "DATABASE.READONLY";

Parameter REASONREADONLY = "This database is mounted read-only, so its file cannot be changed.";

/// <p>Violation code (Story 18.4): a truncate's target size that is not 0 or a whole number of
/// megabytes smaller than the current size.</p>
Parameter TARGETSIZESHAPE = "DATABASE.TARGETSIZE.SHAPE";

Parameter REASONTARGETSIZESHAPE = "Enter 0, or a whole number of megabytes smaller than the current size.";

/// <p>Violation code (Story 18.4): a compact's target free space that is not a whole number of
/// megabytes from 0 to the database's free space.</p>
Parameter TARGETFREESHAPE = "DATABASE.TARGETFREE.SHAPE";

Parameter REASONTARGETFREESHAPE = "Enter a whole number of megabytes, from 0 to the database's free space.";

/// <p>Violation code (Story 18.4): a size grow that is not a whole number of megabytes larger than
/// the current size and no larger than a non-zero maximum size.</p>
Parameter GROWSIZESHAPE = "DATABASE.GROWSIZE.SHAPE";

Parameter REASONGROWSIZESHAPE = "Enter a whole number of megabytes larger than the current size and no larger than the maximum size.";

/// <p>Violation code (Story 18.4): a new volume's initial size that is not a whole number of
/// megabytes, 1 or more, and no larger than a non-zero new volume threshold.</p>
Parameter INITIALSIZESHAPE = "DATABASE.INITIALSIZE.SHAPE";

Parameter REASONINITIALSIZESHAPE = "Enter a whole number of megabytes, 1 or more, and no larger than the new volume threshold when one is set.";

/// <p>Violation code (Story 18.4): an integrity check that names no database.</p>
Parameter INTEGRITYDATABASES = "DATABASE.INTEGRITY.DATABASES";

Parameter REASONINTEGRITYDATABASES = "Choose at least one database to check.";

/// <p>Violation code (Story 18.4): a global name an integrity check does not take.</p>
Parameter GLOBALSSHAPE = "DATABASE.GLOBALS.SHAPE";

Parameter REASONGLOBALSSHAPE = "Enter global names, one per line, each starting with a letter or %.";

/// <p>Violation code (Story 18.4): global names given for an integrity check of more than one
/// database.</p>
Parameter GLOBALSONEDATABASE = "DATABASE.GLOBALS.ONEDATABASE";

Parameter REASONGLOBALSONEDATABASE = "Globals can be chosen only when one database is checked.";

/// <p>Envelope code (409, the owner's database-directory rule at AD-21's sixth case): Add a volume, or
/// a size grow or defragment of a database with a new volume threshold, of a database that names no new
/// volume directory, refused before any vendor call so the vendor never chooses where a volume
/// goes.</p>
Parameter VOLUMEDIRECTORYNONE = "DATABASE.VOLUMEDIRECTORY.NONE";

Parameter REASONVOLUMEDIRECTORYNONE = "This database names no new volume directory, so the instance would choose where the new volume goes. Set its new volume directory first.";

/// <p>Envelope code (409, the owner's database-directory rule at AD-21's sixth case): the same
/// operations of a database whose new volume directory is the manager directory, refused before any
/// vendor call.</p>
Parameter VOLUMEDIRECTORYMANAGER = "DATABASE.VOLUMEDIRECTORY.MANAGER";

Parameter REASONVOLUMEDIRECTORYMANAGER = "This database's new volume directory is the manager directory, which holds the instance's own files, so no volume can be added there. Set another new volume directory first.";

/// <p>Every field-level code, as a <class>%List</class>, in the order the form lists its rules.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAMEREQUIRED, ..#NAMESHAPE, ..#NAMETAKEN, ..#NAMEABSENT, ..#DIRECTORYINUSE, ..#SIZESHAPE, ..#MAXSIZESHAPE, ..#EXPANSIONSIZESHAPE, ..#NEWVOLUMETHRESHOLDSHAPE, ..#NEWVOLUMETHRESHOLDMANAGER, ..#RESOURCESHAPE, ..#RESOURCEABSENT, ..#TARGETSIZESHAPE, ..#TARGETFREESHAPE, ..#GROWSIZESHAPE, ..#INITIALSIZESHAPE, ..#INTEGRITYDATABASES, ..#GLOBALSSHAPE, ..#GLOBALSONEDATABASE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for a code this class does not
/// declare: the field-level codes, the envelope codes and the validation envelope.</p>
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
    If pCode = ..#NEWVOLUMETHRESHOLDMANAGER Quit ..#REASONNEWVOLUMETHRESHOLDMANAGER
    If pCode = ..#RESOURCESHAPE Quit ..#REASONRESOURCESHAPE
    If pCode = ..#RESOURCEABSENT Quit ..#REASONRESOURCEABSENT
    If pCode = ..#INUSE Quit ..#REASONINUSE
    If pCode = ..#REMOTE Quit ..#REASONREMOTE
    If pCode = ..#MOUNTED Quit ..#REASONMOUNTED
    If pCode = ..#DISMOUNTED Quit ..#REASONDISMOUNTED
    If pCode = ..#READONLY Quit ..#REASONREADONLY
    If pCode = ..#TARGETSIZESHAPE Quit ..#REASONTARGETSIZESHAPE
    If pCode = ..#TARGETFREESHAPE Quit ..#REASONTARGETFREESHAPE
    If pCode = ..#GROWSIZESHAPE Quit ..#REASONGROWSIZESHAPE
    If pCode = ..#INITIALSIZESHAPE Quit ..#REASONINITIALSIZESHAPE
    If pCode = ..#INTEGRITYDATABASES Quit ..#REASONINTEGRITYDATABASES
    If pCode = ..#GLOBALSSHAPE Quit ..#REASONGLOBALSSHAPE
    If pCode = ..#GLOBALSONEDATABASE Quit ..#REASONGLOBALSONEDATABASE
    If pCode = ..#VOLUMEDIRECTORYNONE Quit ..#REASONVOLUMEDIRECTORYNONE
    If pCode = ..#VOLUMEDIRECTORYMANAGER Quit ..#REASONVOLUMEDIRECTORYMANAGER
    Quit ""
}

}
