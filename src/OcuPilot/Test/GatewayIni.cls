/// <p><b>DW-51</b> (rework iteration 5): pins the Web Gateway configuration-file fallback
/// behind <method>OcuPilot.Install.Installer.GatewayResponseTimeout</method> -- the path it
/// reads (<method>OcuPilot.Install.Installer.GatewayConfigFilePath</method>, which used to
/// name a file that does not exist) and the key match it makes
/// (<method>OcuPilot.Install.Installer.GatewayTimeoutFromIni</method>, which used to be an
/// unanchored substring search). The two are one fix: anchoring a match on an unreachable
/// file could never be demonstrated red (Rule 19).</p>
/// <p>A separate class from <class>OcuPilot.Test.Version</class> only to keep each test
/// class near the ~500-line bound (<file>.claude/rules/objectscript-testing.md</file>).
/// Read-only: nothing here installs, writes or changes the Gateway.</p>
Class OcuPilot.Test.GatewayIni Extends %UnitTest.TestCase
{

/// <p><b>DW-51, the anchoring.</b> Drives the pure
/// <method>OcuPilot.Install.Installer.GatewayTimeoutFromIni</method> with crafted
/// <code>CSP.ini</code> text in the real file's own format. The shipped code matched
/// <code>Server_Response_Timeout</code> as an unanchored substring and took everything
/// after the first <code>=</code>, so the <b>first</b> line merely containing the name
/// won -- here a comment carrying <code>999</code>. Each decoy targets one way that went
/// wrong: comment lines of both styles, a longer key that contains the name, the same key
/// in another section, and a <code>Password=</code> line of the kind the real
/// <code>[SYSTEM]</code> section carries.</p>
Method TestGatewayIniParserIsKeyAndSectionAnchored()
{
    Set tNL = $Char(10)
    Set tText = "[SYSTEM]" _ tNL _ "; Server_Response_Timeout=999" _ tNL _ "# Server_Response_Timeout=998" _ tNL _ "Server_Response_Timeout_Override=997" _ tNL _ "Password=]]]pbkdf2-hash-with=equals" _ tNL _ "Server_Response_Timeout=60" _ tNL _ "Queued_Request_Timeout=60" _ tNL _ "[LOCAL]" _ tNL _ "Server_Response_Timeout=996" _ tNL
    Do $$$AssertTrue(##class(OcuPilot.Install.Installer).GatewayTimeoutFromIni(tText, .tT1), "the real [SYSTEM] key is found past every decoy")
    Do $$$AssertEquals(tT1, "60", "the value comes from the exact key in [SYSTEM], not the first line that merely contains the name")

    Set tOther = "[LOCAL]" _ tNL _ "Server_Response_Timeout=996" _ tNL _ "[SYSTEM]" _ tNL _ "Queued_Request_Timeout=60" _ tNL
    Do $$$AssertTrue('##class(OcuPilot.Install.Installer).GatewayTimeoutFromIni(tOther, .tT2), "the key under a different section is not the Gateway's own timeout")
    Do $$$AssertEquals(tT2, "", "and nothing is reported from it")

    Set tCommentOnly = "[SYSTEM]" _ tNL _ ";Server_Response_Timeout=999" _ tNL _ "Server_Response_Timeout_Override=997" _ tNL
    Do $$$AssertTrue('##class(OcuPilot.Install.Installer).GatewayTimeoutFromIni(tCommentOnly, .tT3), "a comment or a longer key is never read as the timeout")

    Set tCrLf = "[SYSTEM]" _ $Char(13, 10) _ "Server_Response_Timeout=45" _ $Char(13, 10)
    Do $$$AssertTrue(##class(OcuPilot.Install.Installer).GatewayTimeoutFromIni(tCrLf, .tT4), "CRLF line endings are tolerated")
    Do $$$AssertEquals(tT4, "45", "and the carriage return is not carried into the value")
}

/// <p><b>DW-51, the path.</b> The configuration-file fallback used to probe
/// <code>&lt;installdir&gt;CSP.ini</code>, which does not exist on this instance (verified
/// live), so the whole branch was unreachable. Drives the real file read directly -- not
/// through the registry-first <method>GatewayResponseTimeout</method>, which answers from
/// the live registry on this instance and would never reach the file -- and checks it
/// against an independent read: the live Gateway registry, a different source. Also
/// asserts the extracted value is a bare number, never a whole line, since the real
/// <code>[SYSTEM]</code> section carries a <code>Password=</code> hash.</p>
Method TestGatewayTimeoutReadsTheRealConfigFile()
{
    Set tPath = ##class(OcuPilot.Install.Installer).GatewayConfigFilePath()
    Do $$$AssertTrue(##class(%File).Exists(tPath), "the resolved Gateway configuration path names a file that exists on this instance: " _ tPath)

    Set tSC = ##class(OcuPilot.Install.Installer).GatewayTimeoutFromConfigFile(.tTimeout, .tSource)
    Do $$$AssertStatusOK(tSC, "reading the real configuration file succeeds")
    Do $$$AssertTrue(tTimeout '= "", "the real configuration file yields a timeout")
    Do $$$AssertTrue((tTimeout '= "") && (tTimeout = +tTimeout), "the extracted value is a bare number, never a whole line: " _ tTimeout)
    Do $$$AssertTrue(tSource [ tPath, "the report's source names the file it was read from")

    Set tRegSC = ##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tRegTimeout, .tRegSource)
    Do $$$AssertStatusOK(tRegSC, "the registry-first read succeeds")
    If tRegSource = "live Gateway registry" {
        Do $$$AssertEquals(tTimeout, tRegTimeout, "the configuration file agrees with the live Gateway registry, an independent source")
    } Else {
        Do $$$AssertTrue(1, "SKIPPED: the live Gateway registry does not answer on this instance, so there is no independent source to compare the file against")
    }
}

}
