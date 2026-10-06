/// <p>Test-only helper for Story 18.23's encryption startup settings suites and its Task 0:
/// <class>OcuPilot.Test.EncryptionKeyProbe</class> under its own prefix, <parameter>PREFIX</parameter>, and
/// its own directory under the manager directory, so it shares no object with Stories 18.7's and 18.22's
/// suites. It inherits the probe directory, key file and principal seeding, the encryption facts, the
/// timed port call, <method>RunAs</method>, the active probe keys and <method>Restore</method>, and adds the
/// audit facts (<method>AuditFacts</method>), which <method>Snapshot</method> carries.</p>
/// <p>It declares no password: a caller seeding a key file passes one it generated at run time.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionStartupProbe Extends OcuPilot.Test.EncryptionKeyProbe
{

Parameter PREFIX = "OCUPROBESTART";

Parameter DIRECTORYNAME = "ocuprobestart";

Parameter MARKER = "OCUPROBESTART.marker";

Parameter PRINCIPAL = "OcuProbeStartT0User";

Parameter PRINCIPALROLE = "OcuProbeStartT0Role";

Parameter ADMIN = "OcuProbeStartAdmin";

/// <p>Empty on purpose: every seeding call names the password it generated.</p>
Parameter PASSWORD;

/// <p>A password for a probe key file, generated at run time; the caller holds it in a local and
/// never writes it anywhere.</p>
ClassMethod NewPassword() As %String
{
    Quit "Ocu" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), "+/=", "xyz")
}

/// <p>The audit database's state, read in <code>%SYS</code>: its <code>directory</code>, whether it is
/// <code>encrypted</code> and with which <code>keyId</code>, its <code>IRIS.DAT</code> file's
/// <code>size</code> and <code>modified</code> time, the audit event <code>count</code>, and the newest
/// <code>%System/%Security/AuditChange</code> row as <code>UTCTimeStamp|Description</code>.</p>
ClassMethod AuditFacts() As %DynamicObject
{
    Set tOut = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ##class(%SYS.Audit).GetAuditDatabase()
        Do tOut.%Set("directory", tDirectory, "string")
        Set tDatabase = ##class(SYS.Database).%OpenId(tDirectory)
        Do tOut.%Set("encrypted", $Select($IsObject(tDatabase): tDatabase.EncryptedDB _ "", 1: "?"), "string")
        Do tOut.%Set("keyId", $Select($IsObject(tDatabase): tDatabase.EncryptionKeyID _ "", 1: "?"), "string")
        Do tOut.%Set("mounted", $Select($IsObject(tDatabase): tDatabase.Mounted _ "", 1: "?"), "string")
        Set tDatabase = ""
        Set tFile = ##class(%File).NormalizeDirectory(tDirectory) _ "IRIS.DAT"
        Do tOut.%Set("size", ##class(%File).GetFileSize(tFile), "number")
        Do tOut.%Set("modified", ##class(%File).GetFileDateModified(tFile, 1) _ "", "string")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS.Audit")
        Do tOut.%Set("count", $Select(tRS.%Next(): +tRS.%GetData(1), 1: -1), "number")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 UTCTimeStamp, Description FROM %SYS.Audit WHERE EventSource = '%System' AND EventType = '%Security' AND Event = 'AuditChange' ORDER BY UTCTimeStamp DESC")
        Do tOut.%Set("auditChange", $Select(tRS.%Next(): tRS.%GetData(1) _ "|" _ tRS.%GetData(2), 1: ""), "string")
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Quit tOut
}

/// <p>The inherited snapshot with the audit database's lasting facts added: its directory, whether it is
/// encrypted, its key and whether it is mounted. Its size, modified time, event count and newest audit
/// change row move with every audited event and are left out.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Set tOut = ##super()
    Set tFacts = ..AuditFacts()
    For tKey = "directory", "encrypted", "keyId", "mounted", "error" {
        If tFacts.%GetTypeOf(tKey) = "unassigned" Continue
        Do tOut.%Push("audit|" _ tKey _ "|" _ tFacts.%Get(tKey))
    }
    Quit tOut
}

}
