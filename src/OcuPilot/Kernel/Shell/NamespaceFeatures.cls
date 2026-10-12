/// <p>Whether a namespace reports a feature that a rail area depends on (AD-44). The vocabulary is
/// closed: <parameter>FEATURES</parameter> is what <class>OcuPilot.Screen.Area</class> may declare
/// as <code>appliesWhen</code>, and <file>ui/tools/screen-mirror.mjs</file> reads the same list.</p>
/// <p><b>Applicability is not a privilege gate.</b> A category that applies and that the caller
/// cannot open is still drawn, unavailable, naming its pair (AD-8).</p>
/// <p>Each read passes the namespace as an argument, so it switches no namespace and escalates
/// nothing (AD-9, AD-16). A check that throws, a feature outside the vocabulary, an empty
/// namespace and an implied (<code>^</code>) namespace all answer 0 -- fail closed. A throw or an
/// unknown feature is logged once per check, at WARN.</p>
Class OcuPilot.Kernel.Shell.NamespaceFeatures Extends %RegisteredObject
{

/// <p>The closed feature vocabulary, comma separated.</p>
Parameter FEATURES = "interoperability,analytics";

/// <p>Whether <var>pNamespace</var> reports <var>pFeature</var>. The namespace is upper-cased
/// first, because the vendor's <code>%SYS</code> guards compare the raw argument.</p>
ClassMethod Reports(pFeature As %String, pNamespace As %String) As %Boolean
{
    Set tReports = 0
    Try {
        Set tNamespace = $ZConvert($Get(pNamespace), "U")
        If (tNamespace = "") || ($Extract(tNamespace) = "^") Quit
        If pFeature = "interoperability" {
            Set tReports = ''##class(%Library.EnsembleMgr).IsEnsembleNamespace(tNamespace)
        } ElseIf pFeature = "analytics" {
            If tNamespace '= "%SYS" Set tReports = ''##class(%DeepSee.Utils).%IsDeepSeeEnabled(tNamespace)
        } Else {
            Do ##class(OcuPilot.Kernel.Audit.Log).Warn("shell", "namespace feature outside the vocabulary", {"feature": ($Get(pFeature))})
        }
    } Catch ex {
        Set tReports = 0
        Do ##class(OcuPilot.Kernel.Audit.Log).Warn("shell", "namespace feature check failed", {"feature": ($Get(pFeature))})
    }
    Quit tReports
}

/// <p>1 when <var>pFeature</var> is empty (the area declares no dependency), otherwise
/// <method>Reports</method>.</p>
ClassMethod Applies(pFeature As %String, pNamespace As %String) As %Boolean
{
    If $Get(pFeature) = "" Quit 1
    Quit ..Reports(pFeature, pNamespace)
}

}
