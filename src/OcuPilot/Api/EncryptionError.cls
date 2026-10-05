/// <p>The encryption screens' codes (AD-39, Stories 18.7 and 18.22): every <code>ENCRYPTION.*</code> code
/// Encryption key files, its form, Database encryption and Data element encryption answer, and the one
/// sentence each carries, with the state refusals their tools answer as <code>TOOL.ARGUMENTS</code>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit
/// of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
Class OcuPilot.Api.EncryptionError Extends %RegisteredObject
{

/// <p>Envelope code: a key file request refused on one or more of its fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter KEYFILEVALIDATION = "ENCRYPTION.KEYFILE.VALIDATION";

Parameter REASONKEYFILEVALIDATION = "The key file request was refused.";

/// <p>Violation code: a new key file's folder does not exist, on <code>path</code>; the vendor would
/// create it.</p>
Parameter KEYFILEDIRECTORY = "ENCRYPTION.KEYFILE.DIRECTORY";

Parameter REASONKEYFILEDIRECTORY = "Choose a folder that already exists for the key file.";

/// <p>Violation code: a key length other than 128, 192 or 256 bits, on <code>KeyLen</code>.</p>
Parameter KEYFILEKEYLEN = "ENCRYPTION.KEYFILE.KEYLEN";

Parameter REASONKEYFILEKEYLEN = "Choose 128, 192 or 256 bits.";

/// <p>Violation code: an empty administrator name, one longer than
/// <parameter>OcuPilot.Area.Security.EncryptionRules.NAMEMAXLENGTH</parameter>, or one holding a
/// character the vendor refuses, on <code>AdminName</code>, <code>OldAdminName</code> or
/// <code>NewAdminName</code>.</p>
Parameter KEYFILEADMINNAME = "ENCRYPTION.KEYFILE.ADMINNAME";

Parameter REASONKEYFILEADMINNAME = "Enter an administrator name of up to 50 characters.";

/// <p>Violation code: a password shorter than
/// <parameter>OcuPilot.Area.Security.EncryptionRules.PASSWORDMINLENGTH</parameter> (the vendor's own
/// minimum, measured), or holding a character the vendor refuses, on each password field.</p>
Parameter KEYFILEPASSWORD = "ENCRYPTION.KEYFILE.PASSWORD";

Parameter REASONKEYFILEPASSWORD = "Enter a password of at least 3 characters.";

/// <p>Violation code: the administrator name and password do not open the key file, on
/// <code>AdminPassword</code> or <code>OldAdminPassword</code>, or on the name when it is not listed.</p>
Parameter KEYFILECREDENTIALS = "ENCRYPTION.KEYFILE.CREDENTIALS";

Parameter REASONKEYFILECREDENTIALS = "That administrator name and password do not open this key file.";

/// <p>Violation code: the chosen file is not an encryption key file, on <code>path</code>.</p>
Parameter KEYFILEUNREADABLE = "ENCRYPTION.KEYFILE.UNREADABLE";

Parameter REASONKEYFILEUNREADABLE = "This file is not an encryption key file.";

/// <p>Consequence code: a create or an added key makes a new key.</p>
Parameter KEYFILENEWKEY = "ENCRYPTION.KEYFILE.NEWKEY";

Parameter REASONKEYFILENEWKEY = "The new key is unique: no existing encrypted database or file can use it. If every key file containing it is lost, all data encrypted with it is permanently inaccessible. Make a backup copy of the key file.";

/// <p>Consequence code: a key is removed from a key file.</p>
Parameter KEYFILEREMOVEKEY = "ENCRYPTION.KEYFILE.REMOVEKEY";

Parameter REASONKEYFILEREMOVEKEY = "If this is the only key file containing this key, all data encrypted with this key will be permanently inaccessible.";

/// <p>State refusals, answered as 400 <code>TOOL.ARGUMENTS</code> with <code>detail.problem</code>.</p>
Parameter REASONADMINTAKEN = "This key file already has an administrator of that name.";

Parameter REASONADMINLAST = "A key file keeps at least one administrator.";

Parameter REASONADMINABSENT = "This administrator is not in this key file.";

Parameter REASONKEYABSENT = "This key is not in this key file.";

/// <p>Refusal code: a mounted encrypted database, or a journal file the instance still needs, uses the
/// key a deactivation names (409, Story 18.22).</p>
Parameter KEYINUSE = "ENCRYPTION.KEY.INUSE";

Parameter REASONKEYINUSE = "A mounted encrypted database, or a journal file the instance still needs, uses this key, so it stays active.";

/// <p>Refusal code: the key a deactivation names is the default key or the journal key while another
/// key is active (409, Story 18.22).</p>
Parameter KEYROLE = "ENCRYPTION.KEY.ROLE";

Parameter REASONKEYROLE = "This key is the default key for new encrypted databases or the key for encrypted journal files. Make another active key the default and the journal key first.";

/// <p>Consequence codes of Story 18.22's four tools.</p>
Parameter KEYACTIVATE = "ENCRYPTION.KEY.ACTIVATE";

Parameter REASONKEYACTIVATE = "The keys in this key file become active until they are deactivated or the instance restarts. If no database key was active, the first one also becomes the default key for new encrypted databases and the key for encrypted journal files, and key activation at startup is set to Interactive. Each later start then asks for a key file on the console and, when nobody answers, starts without the key and leaves encrypted databases unmounted, until the startup settings change it.";

Parameter KEYDEACTIVATE = "ENCRYPTION.KEY.DEACTIVATE";

Parameter REASONKEYDEACTIVATE = "An encrypted database that needs this key cannot be mounted until the key is activated again from a key file.";

Parameter KEYACTIVATEDATAELEMENT = "ENCRYPTION.KEY.ACTIVATEDATAELEMENT";

Parameter REASONKEYACTIVATEDATAELEMENT = "The keys in this key file become available to applications that encrypt data elements, until they are deactivated or the instance restarts.";

Parameter KEYDEACTIVATEDATAELEMENT = "ENCRYPTION.KEY.DEACTIVATEDATAELEMENT";

Parameter REASONKEYDEACTIVATEDATAELEMENT = "Data encrypted with this key cannot be read or written until the key is activated again from a key file.";

/// <p>Story 18.22's state refusals, answered as 400 <code>TOOL.ARGUMENTS</code> with
/// <code>detail.problem</code>.</p>
Parameter REASONKEYINACTIVE = "This key is not active.";

Parameter REASONKEYSALLACTIVE = "Every key in this key file is already active.";

Parameter REASONKEYDEFAULT = "This is the default key for new encrypted databases while another key is active. Make another active key the default first.";

/// <p>Every <code>ENCRYPTION.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#KEYFILEVALIDATION, ..#KEYFILEDIRECTORY, ..#KEYFILEKEYLEN, ..#KEYFILEADMINNAME, ..#KEYFILEPASSWORD, ..#KEYFILECREDENTIALS, ..#KEYFILEUNREADABLE, ..#KEYFILENEWKEY, ..#KEYFILEREMOVEKEY, ..#KEYINUSE, ..#KEYROLE, ..#KEYACTIVATE, ..#KEYDEACTIVATE, ..#KEYACTIVATEDATAELEMENT, ..#KEYDEACTIVATEDATAELEMENT)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its first field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#KEYFILEDIRECTORY, ..#KEYFILEKEYLEN, ..#KEYFILEADMINNAME, ..#KEYFILEPASSWORD, ..#KEYFILECREDENTIALS, ..#KEYFILEUNREADABLE)
}

/// <p>The first field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#KEYFILEDIRECTORY) || (pCode = ..#KEYFILEUNREADABLE) Quit "path"
    If pCode = ..#KEYFILEKEYLEN Quit "KeyLen"
    If pCode = ..#KEYFILEADMINNAME Quit "AdminName"
    If (pCode = ..#KEYFILEPASSWORD) || (pCode = ..#KEYFILECREDENTIALS) Quit "AdminPassword"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#KEYFILEVALIDATION Quit ..#REASONKEYFILEVALIDATION
    If pCode = ..#KEYFILEDIRECTORY Quit ..#REASONKEYFILEDIRECTORY
    If pCode = ..#KEYFILEKEYLEN Quit ..#REASONKEYFILEKEYLEN
    If pCode = ..#KEYFILEADMINNAME Quit ..#REASONKEYFILEADMINNAME
    If pCode = ..#KEYFILEPASSWORD Quit ..#REASONKEYFILEPASSWORD
    If pCode = ..#KEYFILECREDENTIALS Quit ..#REASONKEYFILECREDENTIALS
    If pCode = ..#KEYFILEUNREADABLE Quit ..#REASONKEYFILEUNREADABLE
    If pCode = ..#KEYFILENEWKEY Quit ..#REASONKEYFILENEWKEY
    If pCode = ..#KEYFILEREMOVEKEY Quit ..#REASONKEYFILEREMOVEKEY
    If pCode = ..#KEYINUSE Quit ..#REASONKEYINUSE
    If pCode = ..#KEYROLE Quit ..#REASONKEYROLE
    If pCode = ..#KEYACTIVATE Quit ..#REASONKEYACTIVATE
    If pCode = ..#KEYDEACTIVATE Quit ..#REASONKEYDEACTIVATE
    If pCode = ..#KEYACTIVATEDATAELEMENT Quit ..#REASONKEYACTIVATEDATAELEMENT
    If pCode = ..#KEYDEACTIVATEDATAELEMENT Quit ..#REASONKEYDEACTIVATEDATAELEMENT
    Quit ""
}

}
