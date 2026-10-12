/// <p>The container start's namespace-resolution session, executed (Story 18.13, AD-17): the
/// ObjectScript between <code>PRE_RAW=$(iris session</code> and its <code>EOF</code> in
/// <file>scripts/container-start.sh</file>, run in <code>%SYS</code> against namespaces this class
/// creates, answers <code>OK</code> for the install namespace, <code>OTHER</code> when it does not
/// hold the <code>OcuPilot*</code> mapping onto <code>OCUPILOT</code> and another namespace does,
/// <code>SYSTEM</code> and <code>MISSING</code>, and marks only the first usable. The shell
/// <code>case</code> that turns an outcome into an exit is run by
/// <file>ui/tools/container-start-outcome.test.mjs</file>.</p>
/// <p><b>It primes OcuPilot's production install in the namespace it runs in and creates a
/// namespace, database, resource and directory, so <method>OnBeforeAllTests</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1.</b> It needs the script readable at
/// <parameter>SCRIPT</parameter> (the throwaway mounts <file>scripts/</file> there) and the
/// install in <code>HSCUSTOM</code>, the namespace the default resolves to. The session's first
/// line, which reads <code>OCUPILOT_NAMESPACE</code> from the environment, is replaced by a line
/// setting the override under test; the session stops before it writes its outcome, switches
/// namespace or marks anything.</p>
Class OcuPilot.Test.ContainerStartNamespace Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

Parameter SCRIPT = "/opt/ocupilot/scripts/container-start.sh";

/// <p>The namespace the session resolves to with no override, where production is installed.</p>
Parameter HOME = "HSCUSTOM";

/// <p>The probe namespace, its globals database, the database's resource and directory name.</p>
Parameter NAMESPACE = "OCUPROBE1813S";

Parameter DATABASE = "OCUPROBE1813S";

Parameter RESOURCE = "%DB_OCUPROBE1813S";

Parameter DIRECTORY = "ocuprobe1813s";

/// <p>The session's lines up to the one that decides whether the start can use the namespace,
/// <code>$ListBuild</code> of the lines, read once by <method>OnBeforeAllTests</method>.</p>
Property PreparedLines As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedLines = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ContainerStartNamespace primes OcuPilot's PRODUCTION install and creates a namespace and a database, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed or created.")
    }
    Do ..RemoveNamespace()
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadSession()
    If $$$ISERR(tSC) Quit tSC
    Quit ..BuildNamespace()
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = ..RemoveNamespace()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ContainerStartNamespace teardown left: " _ tLeft)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..SetProbeMapping(0)
    Quit $$$OK
}

/// <p>Read the session out of the start script into <property>PreparedLines</property>: the lines
/// from the first <code>iris session iris -U %SYS</code> here-document up to and including the one
/// that sets <code>tUsable</code>. Refuses when the script is unreadable, a landmark is missing or
/// the first line is not the environment read, so a changed script fails here and not silently.</p>
Method ReadSession() As %Status
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(..#SCRIPT)
    If $$$ISERR(tSC) Quit tSC
    Set tInSession = 0
    Set tLines = ""
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        If 'tInSession {
            If (tLine [ "PRE_RAW=$(iris session iris -U %SYS") && (tLine [ "<<'EOF'") Set tInSession = 1
            Continue
        }
        If tLine = "EOF" Quit
        If tLine [ "OCUPILOT-""_""NS-START" Continue
        Set tLines = tLines _ $ListBuild(tLine)
        If $Extract(tLine, 1, 12) = "Set tUsable=" Quit
    }
    If tLines = "" Quit $$$ERROR($$$GeneralError, "no resolution session in " _ ..#SCRIPT)
    If $List(tLines, 1) '= "Set tOverride=$System.Util.GetEnviron(""OCUPILOT_NAMESPACE"")" {
        Quit $$$ERROR($$$GeneralError, "the resolution session no longer starts by reading OCUPILOT_NAMESPACE: " _ $List(tLines, 1))
    }
    If $Extract($List(tLines, *), 1, 12) '= "Set tUsable=" {
        Quit $$$ERROR($$$GeneralError, "the resolution session has no tUsable line before its end")
    }
    Set ..PreparedLines = tLines
    Quit $$$OK
}

/// <p>Run the session in <code>%SYS</code> with <var>pOverride</var> as the environment's
/// <code>OCUPILOT_NAMESPACE</code> and answer <code>outcome|usable</code>.</p>
Method Resolve(pOverride As %String) As %String [ PublicList = (tOverride, tHasHSCUSTOM, tHasUSER, tDefault, tNS, tExists, tRefusedList, tUpper, tIsSystem, tSelfHolds, tSelfMap, tOther, tOtherRS, tOtherMap, tNsOutcome, tUsable) ]
{
    ; The session's variables are public so the executed lines and this method share them;
    ; New restores the caller's on the way out.
    New tOverride, tHasHSCUSTOM, tHasUSER, tDefault, tNS, tExists, tRefusedList, tUpper, tIsSystem, tSelfHolds, tSelfMap, tOther, tOtherRS, tOtherMap, tNsOutcome, tUsable
    Set tAnswer = "(session failed)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tIndex = 1:1:$ListLength(..PreparedLines) {
            Set tLine = $List(..PreparedLines, tIndex)
            If tIndex = 1 Set tLine = "Set tOverride=""" _ pOverride _ """"
            Xecute tLine
        }
        Set tAnswer = $Get(tNsOutcome) _ "|" _ $Get(tUsable)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tAnswer = "(session failed: " _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The production profile's globals pattern and database, as the state class declares them and
/// the start hook spells them.</p>
ClassMethod ProductionPattern() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN
}

ClassMethod ProductionDatabase() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#DATABASENAME
}

/// <p>Create the probe namespace over a database of its own and the home namespace's routines.</p>
Method BuildNamespace() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeNamespace).Build(..#NAMESPACE, ..#DATABASE, ..#RESOURCE, ..#DIRECTORY, ..#HOME)
}

/// <p>Remove what <method>BuildNamespace</method> creates, and answer what is still there.</p>
Method RemoveNamespace() As %String
{
    Quit ##class(OcuPilot.Test.ProbeNamespace).Remove(..#NAMESPACE, ..#DATABASE, ..#RESOURCE, ..#DIRECTORY, ..ProductionPattern())
}

/// <p>Map the production pattern in the probe namespace onto <var>pDatabase</var> (the probe's own
/// database by default), or remove that mapping when <var>pOn</var> is 0.</p>
Method SetProbeMapping(pOn As %Boolean, pDatabase As %String = "") As %Status
{
    Quit ##class(OcuPilot.Test.ProbeNamespace).SetMapping(..#NAMESPACE, ..ProductionPattern(), $Select('pOn: "", pDatabase = "": ..#DATABASE, 1: pDatabase))
}

/// <p>Assert the session answers <var>pExpected</var> (<code>outcome|usable</code>) for
/// <var>pOverride</var>, saying what it answered.</p>
Method AssertResolves(pOverride As %String, pExpected As %String, pWhat As %String)
{
    Set tGot = ..Resolve(pOverride)
    Do $$$AssertEquals(tGot, pExpected, pWhat _ " (answered " _ tGot _ ")")
}

/// <p><b>The default and the install namespace itself are usable.</b> With no override the session
/// resolves to the namespace production runs in, and naming that namespace answers the same: the
/// namespace the start resolved never counts as another holder of its own mapping, so a restart of
/// an installed container is not refused.</p>
Method TestTheInstallNamespaceItselfIsUsable()
{
    Do ..AssertResolves("", "OK:" _ ..#HOME _ "|1", "no override resolves to the install namespace and marks it usable")
    Do ..AssertResolves(..#HOME, "OK:" _ ..#HOME _ "|1", "naming the install namespace answers the same, not OTHER")
}

/// <p><b>A second namespace is OTHER and not usable.</b> The namespace holding the mapping is
/// named first, then the one this start resolved; the mapping in the probe namespace itself, when
/// there is one, changes nothing.</p>
Method TestASecondNamespaceIsOtherAndNotUsable()
{
    Do ..AssertResolves(..#NAMESPACE, "OTHER:" _ ..#HOME _ ":" _ ..#NAMESPACE _ "|0", "a namespace without the mapping is refused naming the holder and itself")
    Do $$$AssertStatusOK(..SetProbeMapping(1), "the probe namespace is given a mapping onto its own database")
    Do ..AssertResolves(..#NAMESPACE, "OTHER:" _ ..#HOME _ ":" _ ..#NAMESPACE _ "|0", "and is refused the same way when it has one of its own, since the holder is the one onto OCUPILOT")
}

/// <p><b>Only a mapping onto the profile's database holds the install.</b> The probe namespace
/// maps the same pattern onto its own database; resolving the install namespace still answers
/// OK, so a namespace holding something else under that name does not refuse the start.</p>
Method TestAMappingOntoAnotherDatabaseDoesNotHoldTheInstall()
{
    Do $$$AssertStatusOK(..SetProbeMapping(1), "the probe namespace is given a mapping onto its own database")
    Do ..AssertResolves(..#HOME, "OK:" _ ..#HOME _ "|1", "the install namespace resolves OK beside it")
}

/// <p><b>A namespace that holds the mapping itself is usable beside another holder.</b> With the
/// probe namespace's own pattern mapped onto the profile's database too, as an earlier release could
/// leave an instance, each of the two resolves as the install namespace rather than OTHER, so a
/// start against either goes on to install, and the operator can uninstall from either.</p>
Method TestANamespaceHoldingTheMappingItselfIsUsableBesideAnother()
{
    Do $$$AssertStatusOK(..SetProbeMapping(1, ..ProductionDatabase()), "the probe namespace is given the production mapping too")
    Do ..AssertResolves(..#NAMESPACE, "OK:" _ ..#NAMESPACE _ "|1", "a second holder resolves as the install namespace")
    Do ..AssertResolves(..#HOME, "OK:" _ ..#HOME _ "|1", "and so does the first, beside it")
}

/// <p><b>A system namespace and a missing one are refused, and neither is usable.</b></p>
Method TestASystemOrMissingNamespaceIsRefused()
{
    Do ..AssertResolves("%SYS", "SYSTEM:%SYS|0", "an override naming %SYS is a system namespace")
    Do ..AssertResolves("OCUPROBE1813NOSUCH", "MISSING:OCUPROBE1813NOSUCH|0", "an override naming no namespace is missing")
}

}
