/// <p>The document database codes and sentences (AD-29, AD-39, Story 19.17): every <code>DOCDB.*</code>
/// code <class>OcuPilot.Port.DocDbPort</class> answers with and the sentence each carries. Each sentence
/// is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/self-protection.test.mjs</file>. They
/// live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290).</p>
Class OcuPilot.Api.DocDbError Extends %RegisteredObject
{

/// <p>Envelope code: the vendor's DocDB service check refused the call after the caller's own pairs
/// passed, so no document database was listed, created or dropped. Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409.</p>
Parameter SERVICEDISABLED = "DOCDB.SERVICE.DISABLED";

/// <p>The sentence <parameter>SERVICEDISABLED</parameter> carries.</p>
Parameter REASONSERVICEDISABLED = "The DocDB service (%Service_DocDB) is disabled on this instance, so document databases cannot be listed, created or dropped. An administrator can enable it on the Services screen in Permissions.";

/// <p>Violation code on <code>Name</code>: the name is not a class name of at most 220 characters
/// once <code>ISC.DM.</code> is added to an unqualified one. Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter NAMEINVALID = "DOCDB.NAME.INVALID";

/// <p>The sentence <parameter>NAMEINVALID</parameter> carries.</p>
Parameter REASONNAMEINVALID = "A document database name is a class name: letters and digits in parts separated by dots, each part starting with a letter, and at most 213 characters without a package.";

/// <p>Violation code on <code>Name</code>: the namespace keeps the class's package in a database other
/// than its own routines database. Rendered with 422.</p>
Parameter NAMEMAPPED = "DOCDB.NAME.MAPPED";

/// <p>The sentence <parameter>NAMEMAPPED</parameter> carries.</p>
Parameter REASONNAMEMAPPED = "This namespace keeps that package's classes in another database, where OcuPilot does not create or drop document databases.";

/// <p>Envelope code: the namespace already holds a document database of that name in some letter case
/// (#25051). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409.</p>
Parameter NAMETAKEN = "DOCDB.NAME.TAKEN";

/// <p>The sentence <parameter>NAMETAKEN</parameter> carries.</p>
Parameter REASONNAMETAKEN = "This namespace already holds a document database of that name, in any letter case.";

/// <p>Envelope code: a class of the database's class name already exists (#25070, or found before the
/// vendor call). Rendered with 409.</p>
Parameter CLASSTAKEN = "DOCDB.CLASS.TAKEN";

/// <p>The sentence <parameter>CLASSTAKEN</parameter> carries.</p>
Parameter REASONCLASSTAKEN = "A class of that name already exists in this namespace, so the database was not created.";

/// <p>The codes refused on <code>Name</code> as a 422 violation.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAMEINVALID, ..#NAMEMAPPED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#SERVICEDISABLED Quit ..#REASONSERVICEDISABLED
    If pCode = ..#NAMEINVALID Quit ..#REASONNAMEINVALID
    If pCode = ..#NAMEMAPPED Quit ..#REASONNAMEMAPPED
    If pCode = ..#NAMETAKEN Quit ..#REASONNAMETAKEN
    If pCode = ..#CLASSTAKEN Quit ..#REASONCLASSTAKEN
    Quit ""
}

}
