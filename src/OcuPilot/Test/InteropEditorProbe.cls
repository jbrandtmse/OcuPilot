/// <p>Story 20.16's probe documents, created in <parameter>NAMESPACE</parameter> on a throwaway container: one rule, one
/// business process written in BPL, one data transformation written in DTL and one business process written as a class
/// (<method>Make</method>), each named <code>&lt;package&gt;.Rule</code>, <code>.Process</code>, <code>.Transform</code> and
/// <code>.Coded</code> (<method>Name</method>). <method>Remove</method> deletes the package with every class compiling the
/// BPL generated and the rule's compiled cache node, and fails while anything survives.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions. Each method switches to
/// <parameter>NAMESPACE</parameter> by explicit save and restore and calls only vendor classes while switched. A package
/// never begins with <code>OcuPilot</code>, which the prohibited set refuses.</p>
Class OcuPilot.Test.InteropEditorProbe Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

/// <p>The package the server tests use; the browser spec uses <code>OcuProbe2016Ui</code>.</p>
Parameter PACKAGE = "OcuProbe2016";

/// <p>The DTL probe's one assignment line, which an edit replaces.</p>
Parameter DTLASSIGN = "<assign value='source.StringValue' property='target.StringValue' action='set'/>";

/// <p>The BPL probe's trace line, which an edit replaces.</p>
Parameter BPLTRACE = "<trace name='Trace one' value='""probe-one""' xpos='200' ypos='350' />";

/// <p>The rule probe's send element, which an edit replaces.</p>
Parameter RULESEND = "<send transform="""" target=""OcuProbeTarget""></send>";

/// <p>A code activity that does not compile, which an edit adds to a DTL or a BPL.</p>
Parameter BROKENCODE = "<code><![CDATA[ Set x = (1 ]]></code>";

/// <p>The probe of kind <var>pKind</var> (<code>rule</code>, <code>process</code>, <code>transform</code> or
/// <code>coded</code>) in package <var>pPackage</var>, as a class name.</p>
ClassMethod Name(pKind As %String, pPackage As %String = {..#PACKAGE}) As %String
{
    Quit pPackage _ "." _ $Case(pKind, "rule": "Rule", "process": "Process", "transform": "Transform", : "Coded")
}

/// <p>The text of probe <var>pName</var> of kind <var>pKind</var>, its lines ended by line feeds.</p>
ClassMethod Text(pKind As %String, pName As %String) As %String
{
    Set tNL = $Char(10)
    If pKind = "transform" {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL [ DependsOn = (Ens.StringRequest, Ens.StringResponse) ]" _ tNL _ "{" _ tNL _ tNL _
            "XData DTL [ XMLNamespace = ""http://www.intersystems.com/dtl"" ]" _ tNL _ "{" _ tNL _
            "<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='new' language='objectscript'>" _ tNL _
            ..#DTLASSIGN _ tNL _ "</transform>" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
    }
    If pKind = "process" {
        Quit "Class " _ pName _ " Extends Ens.BusinessProcessBPL" _ tNL _ "{" _ tNL _ tNL _
            "XData BPL [ XMLNamespace = ""http://www.intersystems.com/bpl"" ]" _ tNL _ "{" _ tNL _
            "<process language='objectscript' request='Ens.Request' response='Ens.Response' height='2000' width='2000' >" _ tNL _
            "<context>" _ tNL _ "<property name='Probe' type='%String' instantiate='0' />" _ tNL _ "</context>" _ tNL _
            "<sequence xend='200' yend='450' >" _ tNL _
            "<assign name='Set probe' property='context.Probe' value='""one""' action='set' xpos='200' ypos='250' />" _ tNL _
            ..#BPLTRACE _ tNL _
            "</sequence>" _ tNL _ "</process>" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
    }
    If pKind = "rule" {
        Quit "Class " _ pName _ " Extends Ens.Rule.Definition" _ tNL _ "{" _ tNL _ tNL _
            "Parameter RuleAssistClass = ""EnsLib.MsgRouter.RuleAssist"";" _ tNL _ tNL _
            "XData RuleDefinition [ XMLNamespace = ""http://www.intersystems.com/rule"" ]" _ tNL _ "{" _ tNL _
            "<ruleDefinition alias="""" context=""EnsLib.MsgRouter.RoutingEngine"" production="""">" _ tNL _
            "<ruleSet name="""" effectiveBegin="""" effectiveEnd="""">" _ tNL _
            "<rule name=""Probe"" disabled=""false"">" _ tNL _ "<when condition=""1"">" _ tNL _
            ..#RULESEND _ tNL _ "<return></return>" _ tNL _ "</when>" _ tNL _ "</rule>" _ tNL _ "</ruleSet>" _ tNL _
            "</ruleDefinition>" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
    }
    Quit "Class " _ pName _ " Extends Ens.BusinessProcess" _ tNL _ "{" _ tNL _ tNL _
        "Method OnRequest(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status" _ tNL _ "{" _ tNL _
        "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
}

/// <p>Probe <var>pName</var> of kind <var>pKind</var> with <parameter>BROKENCODE</parameter> added after its first
/// activity, so it saves and does not compile. A rule and a coded process answer their plain text.</p>
ClassMethod Broken(pName As %String, pKind As %String = "process") As %String
{
    Set tText = ..Text(pKind, pName)
    If pKind = "process" Quit $Replace(tText, ..#BPLTRACE, ..#BROKENCODE _ $Char(10) _ ..#BPLTRACE)
    If pKind = "transform" Quit $Replace(tText, ..#DTLASSIGN, ..#DTLASSIGN _ $Char(10) _ ..#BROKENCODE)
    Quit tText
}

/// <p>Delete the ledger rows of every turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method> seeded in this process. Call it
/// before <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method>, which removes those turns and their proposals and leaves the rows
/// the dispatcher recorded for them.</p>
ClassMethod ForgetLedger() As %Status
{
    Set tSC = $$$OK
    Set tKey = ""
    For {
        Set tKey = $Order(^||OcuPilotProposalFixtureTurns(tKey))
        If tKey = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Write probe <var>pKind</var> in package <var>pPackage</var> to <parameter>NAMESPACE</parameter> and compile it.</p>
ClassMethod Make(pKind As %String, pPackage As %String = {..#PACKAGE}) As %Status
{
    Set tName = ..Name(pKind, pPackage)
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tName, ..Text(pKind, tName), $Char(10))
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(tName, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete package <var>pPackage</var> from <parameter>NAMESPACE</parameter> with every class compiling it generated, kill the
/// compiled cache node of the rule probe, and answer a failing status when a class or the node survives.</p>
ClassMethod Remove(pPackage As %String = {..#PACKAGE}) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do $System.OBJ.DeletePackage(pPackage, "-d")
        Kill ^IRIS.TempEnsRule("class", pPackage _ ".Rule")
        Set tLeft = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", pPackage _ ".")
        While tRS.%Next() {
            Set tLeft = tLeft _ " " _ tRS.%GetData(1)
        }
        If $Data(^IRIS.TempEnsRule("class", pPackage _ ".Rule")) Set tLeft = tLeft _ " ^IRIS.TempEnsRule"
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "probe documents survive in " _ ..#NAMESPACE _ ":" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
