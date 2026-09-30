/// <p>Test-only <class>OcuPilot.Test.DatabaseAcceptPort</class> that sends no write and answers a
/// database file's <code>GET</code> with the new volume directory a test armed with <method>Arm</method>
/// in place of the instance's, so a disk operation's <code>STATE</code> read names a new volume
/// directory no probe can be given: none, which the instance never stores, or the manager directory,
/// which a probe must never be given (Story 18.4, the owner's database-directory rule). Every other
/// answer is the instance's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseVolumePort Extends OcuPilot.Test.DatabaseAcceptPort
{

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && (pEndpoint = "Database.SysCRUD") && (pType = "GET") && ($Data(^||OcuPilotDatabaseVolumeDirectory) # 2) && $IsObject($Get(pResult)) {
        Do pResult.%Set("NewVolumeDirectory", ^||OcuPilotDatabaseVolumeDirectory, "string")
    }
    Quit tSC
}

/// <p>Answer every database file's <code>NewVolumeDirectory</code> as <var>pDirectory</var>, which may
/// be <code>""</code>.</p>
ClassMethod Arm(pDirectory As %String)
{
    Set ^||OcuPilotDatabaseVolumeDirectory = pDirectory
}

/// <p>The recording port's own clearing, and the armed directory forgotten.</p>
ClassMethod Clear()
{
    Do ##super()
    Kill ^||OcuPilotDatabaseVolumeDirectory
}

}
