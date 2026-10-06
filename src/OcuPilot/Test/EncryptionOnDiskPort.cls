/// <p>Test-only <class>OcuPilot.Port.EncryptionPort</class> subclass for the port's own on-disk encryption
/// read (Story 18.23, AD-27's named case): <method>OcuPilot.Port.EncryptionPort.EncryptedOnDisk</method> runs
/// as shipped, and each database is read as the port reads it, then reported encrypted when its configured
/// directory is one <method>ArmDirectories</method> armed. No database is encrypted, and nothing on the
/// instance changes.</p>
/// <p>The armed directories live under <class>OcuPilot.Test.EncryptionSeamPort</class>'s process-private
/// global, so its <method>OcuPilot.Test.EncryptionSeamPort.Clear</method> forgets them.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionOnDiskPort Extends OcuPilot.Port.EncryptionPort
{

/// <p>Arm the directories reported as encrypted on disk, as a <code>$ListBuild</code> list.</p>
ClassMethod ArmDirectories(pDirectories As %List)
{
    Set ^||OcuPilotEncryptionSeam("ondiskdirectories") = pDirectories
}

/// <p>The port's own read of <var>pName</var>, reporting it encrypted when its directory is armed.</p>
ClassMethod DatabaseEncryption(pName As %String, Output pDirectory As %String, Output pEncrypted As %Boolean) As %Status [ Private ]
{
    Set tSC = ##super(pName, .pDirectory, .pEncrypted)
    If $$$ISERR(tSC) Quit tSC
    If (pDirectory '= "") && $ListFind($Get(^||OcuPilotEncryptionSeam("ondiskdirectories")), pDirectory) Set pEncrypted = 1
    Quit tSC
}

}
