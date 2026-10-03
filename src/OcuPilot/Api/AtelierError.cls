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

/// <p>Envelope code: an import's file, or a document it would replace, differs at the write from the
/// documents its import was reviewed with (Story 19.13).</p>
Parameter IMPORTCHANGED = "EXPLORER.IMPORT.CHANGED";

/// <p>The sentence <parameter>IMPORTCHANGED</parameter> carries.</p>
Parameter REASONIMPORTCHANGED = "The file, or a document it would replace, has changed since this import was proposed.";

/// <p>Envelope code: an export's file name names a directory that does not exist under its allowed
/// directory (Story 19.13). Rendered as a 400 violation on <code>path</code>.</p>
Parameter EXPORTDIRECTORY = "EXPLORER.EXPORT.DIRECTORY";

/// <p>The sentence <parameter>EXPORTDIRECTORY</parameter> carries.</p>
Parameter REASONEXPORTDIRECTORY = "There is no such directory under that allowed directory.";

/// <p>Envelope code: a file sent or named for import is longer than an import reads (Story 19.13).</p>
Parameter IMPORTTOOLARGE = "EXPLORER.IMPORT.TOOLARGE";

/// <p>The sentence <parameter>IMPORTTOOLARGE</parameter> carries.</p>
Parameter REASONIMPORTTOOLARGE = "The file is longer than 3,000,000 characters, the most one import reads.";

/// <p>Envelope code: the document a save names changed on the instance after the editor read it, so
/// the text was not saved (Story 19.3). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug with 409, and never logged: it is an answer, not a fault.</p>
Parameter DOCUMENTCONFLICT = "EXPLORER.DOCUMENT.CONFLICT";

/// <p>The sentence <parameter>DOCUMENTCONFLICT</parameter> carries.</p>
Parameter REASONDOCUMENTCONFLICT = "Someone else changed this document after you opened it, so it was not saved. Copy your changes, then reopen the document to see the current text.";

/// <p>Envelope code: another process holds the document a save or an import names (#5864), so
/// nothing was written (Story 19.3). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug with 409, and never logged as a fault; the vendor's message, which names a user and a process,
/// is logged at information severity and never sent (AD-61 rule 6).</p>
Parameter DOCUMENTLOCKED = "EXPLORER.DOCUMENT.LOCKED";

/// <p>The sentence <parameter>DOCUMENTLOCKED</parameter> carries, the one
/// <parameter>DELETELOCKED</parameter> carries.</p>
Parameter REASONDOCUMENTLOCKED = "Another process is editing this document.";

/// <p>Envelope code: the first line of a save's text does not name the document saved, by name and
/// kind, so nothing was sent (Story 19.3). Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter SAVEHEADER = "EXPLORER.SAVE.HEADER";

/// <p>The sentence <parameter>SAVEHEADER</parameter> carries.</p>
Parameter REASONSAVEHEADER = "The first line no longer names this document, so the text was not saved.";

/// <p>Envelope code: a save's text is longer than one save sends, so nothing was sent (Story 19.3).
/// Rendered on the <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400.</p>
Parameter SAVETOOLARGE = "EXPLORER.SAVE.TOOLARGE";

/// <p>The sentence <parameter>SAVETOOLARGE</parameter> carries.</p>
Parameter REASONSAVETOOLARGE = "The text is longer than 3,000,000 characters, the most one save sends.";

/// <p>Envelope code: the instance refused a save's text with an error of its own, a source-control
/// refusal or text it cannot store among them, and kept the document as it was (Story 19.3). Rendered
/// on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422; the vendor's text
/// is logged and never sent.</p>
Parameter SAVEREFUSED = "EXPLORER.SAVE.REFUSED";

/// <p>The sentence <parameter>SAVEREFUSED</parameter> carries.</p>
Parameter REASONSAVEREFUSED = "The instance refused this text, so nothing was saved.";

/// <p>A deleted document's per-document reason when the vendor refused it for want of a privilege
/// (#5838, #5883, #302) or a <code>&lt;PROTECT&gt;</code>.</p>
Parameter DELETEACCESS = "This account cannot change the database that holds this document.";

/// <p>A deleted document's per-document reason when another process holds it (#5864).</p>
Parameter DELETELOCKED = "Another process is editing this document.";

/// <p>A deleted document's per-document reason when the vendor no longer found it.</p>
Parameter DELETEABSENT = "This namespace no longer holds this document.";

/// <p>A deleted document's per-document reason for any other refusal.</p>
Parameter DELETEFAILED = "The source code API could not delete this document.";

}
