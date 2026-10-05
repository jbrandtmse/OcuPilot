/// <p>Pins how <code>PROHIBITED.OCUPILOTKEY</code> compares key ids (AD-10, Story 18.7):
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SameKeyId</method> and
/// <method>OcuPilot.Kernel.Proposal.Prohibited.RowNeedsKey</method>, the comparison
/// <method>OcuPilot.Kernel.Proposal.Prohibited.DependsOnKey</method> makes for each of OcuPilot's or the
/// instance's own databases. The rows are shaped as <code>Database.SysCRUD</code> <code>LIST</code>
/// answers them on this build: <code>Encrypted</code> a boolean, <code>EncryptionKeyID</code> a
/// string.</p>
/// <p>Needs nothing from the instance: it calls the pure comparison only, with no port and no vendor
/// call.</p>
Class OcuPilot.Test.EncryptionKeyMatch Extends %UnitTest.TestCase
{

/// <p>A key id as the key file lists it.</p>
Parameter KEY = "6C2B0A1F9E3D4B7A8C112F5E6D7A8B9C";

/// <p>The same id in another form: lower case, braces and hyphens.</p>
Parameter KEYFORMATTED = "{6c2b0a1f-9e3d-4b7a-8c11-2f5e6d7a8b9c}";

/// <p>Another key's id.</p>
Parameter OTHERKEY = "0D9E8F7A6B5C4D3E2F1A0B9C8D7E6F5A";

/// <p>The same key in another case, or with braces, hyphens and spaces, is the same key, so a database
/// encrypted with it needs it.</p>
/// <p>Mutation (Rule 19): compare the ids as exact strings in <method>SameKeyId</method> -- every leg
/// here goes red.</p>
Method TestTheSameKeyInAnotherFormIsRefused()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).SameKeyId(..#KEYFORMATTED, ..#KEY), "a braced, hyphenated, lower-case id names the same key as its bare upper-case form")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).SameKeyId(..#KEY, ..#KEYFORMATTED), "and the comparison reads the same either way round")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).SameKeyId("6c2b 0a1f 9e3d 4b7a 8c11 2f5e 6d7a 8b9c", ..#KEY), "spaces do not matter")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": (..#KEYFORMATTED)}, ..#KEY), "a database whose key id is the formatted form of the key needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": (..#KEY)}, ..#KEYFORMATTED), "and so does one whose key id is the bare form, when the key is named formatted")
}

/// <p>An encrypted database whose key id cannot be read might need any key, so it needs this one.</p>
/// <p>Mutation (Rule 19): make <method>RowNeedsKey</method>'s last line answer 0 -- every leg but the
/// non-object one goes red.</p>
Method TestAnEncryptedRowWhoseKeyIdCannotBeReadIsRefused()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true}, ..#KEY), "an encrypted row with no EncryptionKeyID member needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": ""}, ..#KEY), "an encrypted row with an empty EncryptionKeyID needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": null}, ..#KEY), "an encrypted row whose EncryptionKeyID is null needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": 12345}, ..#KEY), "an encrypted row whose EncryptionKeyID is a number, not a string, needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": "{-}"}, ..#KEY), "an encrypted row whose EncryptionKeyID holds no hex digit needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "EncryptionKeyID": ""}, ..#KEY), "a row that does not say whether it is encrypted, with an empty key id, needs the key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey("", ..#KEY), "a row that is not an object needs the key")
}

/// <p>A database encrypted with another key, or not encrypted, does not need this key.</p>
Method TestADifferentKeyOrAnUnencryptedRowIsAllowed()
{
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).SameKeyId(..#OTHERKEY, ..#KEY), 1, "two different ids name different keys")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": true, "EncryptionKeyID": (..#OTHERKEY)}, ..#KEY), 0, "a database encrypted with another key does not need this one")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": false, "EncryptionKeyID": ""}, ..#KEY), 0, "an unencrypted database with an empty key id, as this build lists every database, does not need the key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey({"Directory": "/x/", "Encrypted": false}, ..#KEY), 0, "nor does an unencrypted one with no key id member")
}

/// <p>A key whose id reads empty once normalized is treated as depended on, so its removal is
/// refused.</p>
Method TestAKeyThatReadsEmptyIsRefused()
{
    Set tPlain = {"Directory": "/x/", "Encrypted": false, "EncryptionKeyID": ""}
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey(tPlain, ""), "an empty key is needed even by an unencrypted database")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey(tPlain, "{-} "), "and so is a key of braces, hyphens and spaces")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).RowNeedsKey(tPlain, "xyz"), "and a key that holds no hex digit")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedKeyId("{-} "), "", "the key file's id normalizes to empty")
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).SameKeyId("{-}", "{-}"), 1, "and two ids that read empty name no key, so they are never the same")
}

}
