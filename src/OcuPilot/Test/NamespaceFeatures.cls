/// <p>Pins <class>OcuPilot.Kernel.Shell.NamespaceFeatures</class> against the vendor checks it
/// wraps, <method>OcuPilot.Screen.Registry.AreaProblem</method>, and the <code>applies</code> field
/// <method>OcuPilot.Kernel.Shell.Navigation.Payload</method> carries (Story 20.1, AD-44).</p>
/// <p>It changes no configuration and arms nothing; each unknown-feature leg writes one WARN line to
/// the console log. The payload legs assume the instance's namespaces report what a stock throwaway
/// reports: HSCUSTOM interoperability only, and <code>%SYS</code> neither.</p>
Class OcuPilot.Test.NamespaceFeatures Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The namespaces <code>Config.Namespaces:List</code> returns, <code>,</code>-separated.</p>
ClassMethod Namespaces() As %String
{
    Set tNames = ""
    Set tOrig = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Namespaces:List")
        Do tRS.Execute()
        While tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.Get("Namespace")
        }
    } Catch {
        Set $NAMESPACE = tOrig
    }
    Set $NAMESPACE = tOrig
    Quit tNames
}

/// <p>For every namespace the instance lists, <method>OcuPilot.Kernel.Shell.NamespaceFeatures.Reports</method>
/// equals the vendor's own answer for that namespace upper-cased, and at least one namespace reports
/// each feature and at least one does not.</p>
/// <p>Mutation (Rule 19): make <code>Reports</code> answer 1 always -&gt; the <code>%SYS</code> and
/// vendor-equality legs go red.</p>
Method TestReportsEqualsTheVendorForEveryNamespace()
{
    Set tNames = ..Namespaces()
    Do $$$AssertTrue(tNames '= "", "the namespace list reads")
    Kill tSeen
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        Set tUpper = $ZConvert(tName, "U")
        Set tWantInterop = ''##class(%Library.EnsembleMgr).IsEnsembleNamespace(tUpper)
        Set tWantAnalytics = ''##class(%DeepSee.Utils).%IsDeepSeeEnabled(tUpper)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("interoperability", tName), tWantInterop, tName _ ": interoperability is the vendor's answer")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("analytics", tName), tWantAnalytics, tName _ ": analytics is the vendor's answer")
        Set tSeen("interoperability", tWantInterop) = 1
        Set tSeen("analytics", tWantAnalytics) = 1
    }
    For tFeature = "interoperability", "analytics" {
        Do $$$AssertTrue($Get(tSeen(tFeature, 1)), "at least one namespace reports " _ tFeature)
        Do $$$AssertTrue($Get(tSeen(tFeature, 0)), "and at least one does not")
    }
}

/// <p><code>%SYS</code> applies to neither feature, in either case; an implied namespace, an empty
/// one and a feature outside the vocabulary answer 0; an area that declares no feature applies.</p>
Method TestTheEdgesFailClosed()
{
    Set tClass = "OcuPilot.Kernel.Shell.NamespaceFeatures"
    For tFeature = "interoperability", "analytics" {
        Do $$$AssertEquals($ClassMethod(tClass, "Reports", tFeature, "%SYS"), 0, "%SYS does not report " _ tFeature)
        Do $$$AssertEquals($ClassMethod(tClass, "Reports", tFeature, "%sys"), 0, "nor %sys, which the vendor's own guard would answer 1 for analytics")
        Do $$$AssertEquals($ClassMethod(tClass, "Reports", tFeature, "^^/some/dir"), 0, "nor an implied namespace")
        Do $$$AssertEquals($ClassMethod(tClass, "Reports", tFeature, ""), 0, "nor an empty one")
    }
    Do $$$AssertEquals($ClassMethod(tClass, "Reports", "bogus", "HSCUSTOM"), 0, "a feature outside the vocabulary answers 0")
    Do $$$AssertEquals($ClassMethod(tClass, "Applies", "", "%SYS"), 1, "an empty feature applies everywhere")
    Do $$$AssertEquals($ClassMethod(tClass, "Applies", "bogus", "HSCUSTOM"), 0, "and an unknown one applies nowhere")
}

/// <p>A feature outside the vocabulary applies nowhere and writes exactly one WARN line to the
/// console log, under the shell subsystem, naming the feature.</p>
/// <p>Mutation (Rule 19): drop the <code>Log.Warn</code> from <code>Reports</code>' unknown-feature
/// branch -&gt; the line count goes red.</p>
Method TestAnUnknownFeatureIsLoggedOnce()
{
    Set tPath = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tPath)
    Do $$$AssertTrue(tFrom > 0, "the console log is readable before the call: " _ tPath)
    Set tFeature = "probe" _ $Job _ $Translate($ZHorolog, ".")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Applies(tFeature, "HSCUSTOM"), 0, "an unknown feature applies nowhere")
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If tStream.LinkToFile(tPath) && tStream.MoveTo(tFrom + 1) Set tText = tStream.Read(1000000)
    } Catch ex {
        Set tText = ""
    }
    Set tCount = 0
    Set tLine = ""
    For tI = 1:1:$Length(tText, $Char(10)) {
        If $Piece(tText, $Char(10), tI) [ tFeature {
            Set tCount = tCount + 1
            Set tLine = $Piece(tText, $Char(10), tI)
        }
    }
    Do $$$AssertEquals(tCount, 1, "exactly one appended console line names the feature")
    If tLine = "" Quit
    Set tEntry = ##class(%DynamicObject).%FromJSON($Piece(tLine, "[OcuPilot] ", 2, *))
    Do $$$AssertEquals(tEntry.level, "warn", "at WARN")
    Do $$$AssertEquals(tEntry.subsystem, "shell", "under the shell subsystem")
    Do $$$AssertEquals(tEntry.msg, "namespace feature outside the vocabulary", "saying why")
    Do $$$AssertEquals(tEntry.data.feature, tFeature, "and naming the feature")
}

/// <p><method>OcuPilot.Screen.Registry.AreaProblem</method> refuses an <code>appliesWhen</code>
/// outside the vocabulary, naming the area, and admits the shipped declaration.</p>
/// <p>Mutation (Rule 19): drop the vocabulary test from <code>AreaProblem</code> -&gt; the refusal
/// leg goes red.</p>
Method TestAnAreaWithAnUnknownFeatureIsRefused()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Area).List(.tAreas), "the shipped areas read")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaProblem(tAreas), "", "the shipped declaration is sound")
    Set tBad = [{"key": "synthetic", "appliesWhen": "bogus"}]
    Set tProblem = ##class(OcuPilot.Screen.Registry).AreaProblem(tBad)
    Do $$$AssertTrue(tProblem [ "synthetic", "the refusal names the area: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "bogus", "and the value: " _ tProblem)
}

/// <p>The navigation map carries <code>applies</code> on every area, equal to what the scope's
/// namespace reports: <code>%SYS</code> applies to neither new area, HSCUSTOM to Interoperability
/// only, and every area that declares no feature applies.</p>
/// <p>Mutation (Rule 19): omit <code>applies</code> from one area in
/// <method>OcuPilot.Kernel.Shell.Navigation.Payload</method> -&gt; this goes red, and
/// <class>OcuPilot.Test.ToolShell</class> through the closed schema.</p>
Method TestThePayloadCarriesApplies()
{
    For tCase = "%SYS|0|0", "HSCUSTOM|1|0" {
        Set tNamespace = $Piece(tCase, "|", 1)
        Do ##class(OcuPilot.Kernel.Scope).Set(tNamespace)
        Set tSC = ##class(OcuPilot.Kernel.Shell.Navigation).Payload(.tObject)
        Do $$$AssertStatusOK(tSC, tNamespace _ ": the payload builds")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tObject.areas.%Size(), 11, tNamespace _ ": every area is emitted, none omitted for not applying")
        Set tIterator = tObject.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            Do $$$AssertTrue(tArea.%IsDefined("applies"), tNamespace _ ": " _ tArea.key _ " carries applies")
            Set tWant = 1
            If tArea.key = "interoperability" Set tWant = $Piece(tCase, "|", 2)
            If tArea.key = "analytics" Set tWant = $Piece(tCase, "|", 3)
            Do $$$AssertEquals(tArea.%Get("applies"), tWant, tNamespace _ ": " _ tArea.key _ " applies")
            Do $$$AssertEquals(tArea.%GetTypeOf("applies"), "boolean", tNamespace _ ": " _ tArea.key _ " applies is a boolean")
        }
    }
}

}
