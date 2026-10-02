/// <p>System Explorer's write codes and sentences (AD-39, Story 19.2): every <code>EXPLORER.*</code>
/// code the source code API port answers a write with, the sentence each carries, and the port-owned
/// reason a delete's refused document carries in its per-document result. Each sentence is published
/// once in EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file>
/// key by <file>ui/tools/self-protection.test.mjs</file>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit
/// of 1,000 parameters (ERROR #5290).</p>
Class OcuPilot.Api.AtelierError Extends %RegisteredObject
{

/// <p>Envelope code: a document the write names is absent at the fresh read, so nothing was sent.
/// Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, its
/// <code>detail.documents</code> naming each absent document.</p>
Parameter DOCUMENTABSENT = "EXPLORER.DOCUMENT.ABSENT";

/// <p>The sentence <parameter>DOCUMENTABSENT</parameter> carries.</p>
Parameter REASONDOCUMENTABSENT = "This namespace no longer holds a document this change names.";

/// <p>Envelope code: an import's file holds no document the instance can read (Story 19.13).</p>
Parameter IMPORTUNREADABLE = "EXPLORER.IMPORT.UNREADABLE";

/// <p>The sentence <parameter>IMPORTUNREADABLE</parameter> carries.</p>
Parameter REASONIMPORTUNREADABLE = "The file holds no document this instance can read.";

/// <p>Envelope code: an import's file no longer holds the documents its proposal was minted with
/// (Story 19.13).</p>
Parameter IMPORTCHANGED = "EXPLORER.IMPORT.CHANGED";

/// <p>The sentence <parameter>IMPORTCHANGED</parameter> carries.</p>
Parameter REASONIMPORTCHANGED = "The file no longer holds the documents this import was proposed with.";

/// <p>Envelope code: a local file sent for import is longer than an import reads (Story 19.13).</p>
Parameter IMPORTTOOLARGE = "EXPLORER.IMPORT.TOOLARGE";

/// <p>The sentence <parameter>IMPORTTOOLARGE</parameter> carries.</p>
Parameter REASONIMPORTTOOLARGE = "The file is longer than 3,000,000 characters, the most one import reads.";

/// <p>A deleted document's per-document reason when the vendor refused it for want of a privilege
/// (#5838, #5883, #302) or a <code>&lt;PROTECT&gt;</code>.</p>
Parameter DELETEACCESS = "This account cannot change the database that holds this document.";

/// <p>A deleted document's per-document reason when another process holds it (#5864).</p>
Parameter DELETELOCKED = "Another process is editing this document.";

/// <p>A deleted document's per-document reason when the vendor no longer found it.</p>
Parameter DELETEABSENT = "This namespace no longer holds this document.";

/// <p>A deleted document's per-document reason for any other refusal.</p>
Parameter DELETEFAILED = "The source code API could not delete this document.";

/// <p>Every <code>EXPLORER.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#DOCUMENTABSENT, ..#IMPORTUNREADABLE, ..#IMPORTCHANGED, ..#IMPORTTOOLARGE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#DOCUMENTABSENT Quit ..#REASONDOCUMENTABSENT
    If pCode = ..#IMPORTUNREADABLE Quit ..#REASONIMPORTUNREADABLE
    If pCode = ..#IMPORTCHANGED Quit ..#REASONIMPORTCHANGED
    If pCode = ..#IMPORTTOOLARGE Quit ..#REASONIMPORTTOOLARGE
    Quit ""
}

}
