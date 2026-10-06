/// <p>Pins that a credential literal in a statement's text reaches no screen answer and no tool result
/// (AD-35, AD-36, AD-60): <method>OcuPilot.Port.SqlPort.MaskCredentials</method> over each form of
/// <code>IDENTIFY BY</code>, <code>IDENTIFIED BY</code> and <code>PASSWORD</code>; a statement the instance
/// recorded without running it, read through the agent's SQL read over
/// <code>INFORMATION_SCHEMA.STATEMENTS</code>, through the SQL catalog's statements and cached-query tabs,
/// and through SQL activity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It prepares one
/// <code>CREATE USER</code> statement, which the instance records in the current namespace's statement
/// index with its literal, and removes that index row in <method>OnAfterOneTest</method>, then reads it
/// back gone. It starts one SQL activity probe job and stops it.</p>
Class OcuPilot.Test.SqlCredentialMask Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlRead";

Parameter SEAM = "OcuPilot.Test.SqlActivitySeam";

Parameter PROBE = "OcuPilot.Test.SqlActivityProbe";

Parameter MASK = "[redacted]";

/// <p>The planted statement's user name, upper case as the index stores it.</p>
Property PlantedName As %String;

/// <p>The planted statement's literal, in the case it was typed.</p>
Property PlantedLiteral As %String;

/// <p>The planted statement's text as the instance holds it.</p>
Property PlantedText As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PlantedName = ""
    Set ..PlantedLiteral = ""
    Set ..PlantedText = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.SqlActivitySeam).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.SqlActivitySeam).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "every probe job is stopped")
    If ..PlantedName '= "" {
        Do ..RemovePlanted()
        Do $$$AssertEquals(..PlantedRows(), 0, "the planted statement's index row is gone")
        Set ..PlantedName = ""
    }
    Quit $$$OK
}

/// <p>Prepare a <code>CREATE USER</code> statement carrying a fresh literal, without running it, and
/// read its stored text back into <property>PlantedText</property>. The instance records the text in the
/// current namespace's statement index with the literal (measured).</p>
Method Plant() As %Boolean
{
    Set tSuffix = 10000000 + $Random(90000000)
    Set ..PlantedName = "OCUP2096" _ tSuffix
    Set ..PlantedLiteral = "OcuLit2096" _ tSuffix
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("CREATE USER " _ ..PlantedName _ " IDENTIFY BY '" _ ..PlantedLiteral _ "'")
    Do $$$AssertStatusOK(tSC, "the CREATE USER statement is prepared, not run")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Statement FROM INFORMATION_SCHEMA.STATEMENTS WHERE Statement [ ?", ..PlantedName)
    Set ..PlantedText = ""
    If tRS.%Next() Set ..PlantedText = tRS.%GetData(1)
    Do $$$AssertTrue(..PlantedText [ ..PlantedLiteral, "the instance recorded the statement with its literal: " _ ..PlantedText)
    Quit (..PlantedText [ ..PlantedLiteral)
}

/// <p>Remove the planted statement's index row.</p>
Method RemovePlanted()
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Hash FROM INFORMATION_SCHEMA.STATEMENTS WHERE Statement [ ?", ..PlantedName)
    While tRS.%Next() {
        Set tHash = tRS.%GetData(1)
        Kill ^rINDEXSQL("sqlidx", 1, tHash)
    }
}

/// <p>How many rows the statement index holds for the planted statement.</p>
Method PlantedRows() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATEMENTS WHERE Statement [ ?", ..PlantedName)
    If tRS.%Next() Quit +tRS.%GetData(1)
    Quit -1
}

/// <p>The masked form of <var>pText</var>.</p>
ClassMethod Masked(pText As %String) As %String
{
    Quit $ClassMethod(..#PORT, "MaskCredentials", pText)
}

/// <p>Each form of credential is masked, a text with none comes back byte for byte, and the rest of the
/// text is unchanged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPort.MaskCredentials</method> answer its input
/// -> every masked leg goes red.</p>
Method TestMaskCredentialsOverEachForm()
{
    Set tMask = ..#MASK
    Do $$$AssertEquals(..Masked("CREATE USER u IDENTIFIED BY 'pw1'"), "CREATE USER u IDENTIFIED BY " _ tMask, "a single-quoted literal")
    Do $$$AssertEquals(..Masked("CREATE USER u IDENTIFY BY 'it''s ok' ROLE r"), "CREATE USER u IDENTIFY BY " _ tMask _ " ROLE r", "a doubled quote stays inside the literal")
    Do $$$AssertEquals(..Masked("ALTER USER u IDENTIFY BY ""pw2"" ROLE r"), "ALTER USER u IDENTIFY BY " _ tMask _ " ROLE r", "a double-quoted identifier")
    Do $$$AssertEquals(..Masked("ALTER USER u IDENTIFIED BY pw3 ROLE r"), "ALTER USER u IDENTIFIED BY " _ tMask _ " ROLE r", "a bare token")
    Do $$$AssertEquals(..Masked("alter user u with password 'pw4'"), "alter user u with password " _ tMask, "a PASSWORD clause, in any case")
    Do $$$AssertEquals(..Masked("CREATE USER u PASSWORD 'pw5'; ALTER USER v IDENTIFIED BY 'pw6'"), "CREATE USER u PASSWORD " _ tMask _ "; ALTER USER v IDENTIFIED BY " _ tMask, "two in one text")
    Do $$$AssertEquals(..Masked("CREATE USER u IDENTIFY BY 'unterminated"), "CREATE USER u IDENTIFY BY " _ tMask, "a literal a cut left unterminated runs to the end")
    Do $$$AssertEquals(..Masked("CREATE USER u IDENTIFIED BY ?"), "CREATE USER u IDENTIFIED BY ?", "a bound value is left")
    Set tPlain = "SELECT Name FROM Sample.Person WHERE Name = 'Smith' /* a  b */"
    Do $$$AssertEquals(..Masked(tPlain), tPlain, "a text the pattern does not match comes back unchanged")
    Do $$$AssertEquals(..Masked(""), "", "an empty text comes back empty")
}

/// <p>The agent's SQL read over the statement index answers the planted statement with its value
/// masked and its literal in no cell.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPort.MaskCredentials</method> answer its input,
/// or drop the text-cell branch from <method>OcuPilot.Screen.Tool.ExplorerSqlRead.MaskedRows</method>
/// -> this goes red.</p>
Method TestAPlantedStatementIsMaskedInTheAgentsSqlRead()
{
    If '..Plant() Quit
    Set tArgs = {"statement": "SELECT Statement FROM INFORMATION_SCHEMA.STATEMENTS WHERE Statement [ ?", "parameters": [(..PlantedName)]}
    Set tSC = $ClassMethod(..#TOOL, "View", "", tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    If '$IsObject($Get(tResult)) Quit
    Set tJson = tResult.%ToJSON()
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "one row names the planted statement: " _ tJson)
    Do $$$AssertTrue(tJson '[ ..PlantedLiteral, "the literal is in no cell")
    Do $$$AssertTrue(tJson [ ("IDENTIFY BY " _ ..#MASK), "the statement is there with its value masked: " _ tJson)
}

/// <p>The SQL catalog's statements tabs and its cached-query tab answer the planted statement's text with
/// its value masked, through the port both screen and tool read.</p>
/// <p>Mutation (Rule 19): drop the <code>sqltext</code> branch from
/// <method>OcuPilot.Port.AtelierPort.CatalogRow</method> -> this goes red.</p>
Method TestAPlantedStatementIsMaskedInTheCatalogTabs()
{
    If '..Plant() Quit
    For tEndpoint = "Catalog.TableStatements", "Catalog.CachedQueries" {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ##class(OcuPilot.Test.AtelierPortCatalog).ArmCatalog()
        Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ##class(OcuPilot.Test.AtelierPortCatalog).Envelope(##class(OcuPilot.Test.AtelierPortCatalogTabs).ResolvedRow("table", "OcuProbe", "Thing")))
        Set tRow = {}
        Do tRow.%Set($Select(tEndpoint = "Catalog.CachedQueries": "Query", 1: "STATEMENT"), ..PlantedText, "string")
        Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ##class(OcuPilot.Test.AtelierPortCatalog).Envelope(tRow.%ToJSON()))
        Kill tQuery
        Set tQuery("table") = "OcuProbe.Thing"
        Set tSC = ##class(OcuPilot.Test.AtelierPortCatalog).Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": the tab answers")
        If '$IsObject($Get(tRows)) Continue
        Set tJson = tRows.%ToJSON()
        Do $$$AssertTrue(tJson '[ ..PlantedLiteral, tEndpoint _ ": the literal is in no cell")
        Do $$$AssertTrue(tJson [ ("IDENTIFY BY " _ ..#MASK), tEndpoint _ ": the text is there with its value masked: " _ tJson)
    }
}

/// <p>SQL activity answers a running statement's text with its value masked.</p>
/// <p>Mutation (Rule 19): drop the <code>MaskCredentials</code> call from
/// <method>OcuPilot.Port.SqlActivityPort.StatementText</method> -> this goes red.</p>
Method TestAPlantedStatementIsMaskedInSqlActivity()
{
    If '..Plant() Quit
    Set tSC = $ClassMethod(..#PROBE, "Start", "USER", "OcuMask2096" _ $Random(90000000), "OcuMaskValue2096", .tPid)
    Do $$$AssertStatusOK(tSC, "a probe statement runs")
    If $$$ISERR(tSC) Quit
    Do $ClassMethod(..#SEAM, "Arm", "text", ..PlantedText)
    Kill tQuery
    Set tQuery("maxRows") = 100
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "CurrentStatements", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the port answers the rows")
    If '$IsObject($Get(tRows)) Quit
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("ProcessID") = tPid Set tText = tRow.%Get("Statement")
    }
    Do $$$AssertTrue(tText '= "", "the probe's row carries a statement text")
    Do $$$AssertTrue(tText '[ ..PlantedLiteral, "the literal is in no statement text")
    Do $$$AssertTrue(tText [ ("IDENTIFY BY " _ ..#MASK), "the text is there with its value masked: " _ tText)
}

}
