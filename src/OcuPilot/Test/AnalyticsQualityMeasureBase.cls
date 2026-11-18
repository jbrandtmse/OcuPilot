/// <p>What Story 24.12's quality measure write tests share (Batch 2): <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s probe, routes, mint and confirm, audit and ledger counts, gate
/// seam and own-code helper, with the measure's own fixtures, tools and screen: names under the catalog <parameter>MARKER</parameter>, classes in <parameter>CLASSMARKER</parameter>'s
/// package, a measure's model flattened to one string, the registry's state and the checks that a measure's class and every node it registered are gone.
/// <class>OcuPilot.Test.AnalyticsQualityMeasureWrite</class> and <class>OcuPilot.Test.AnalyticsQualityMeasureWriteEdge</class> extend it.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It saves, compiles and deletes classes in <code>USER</code> and removes every one after the last test.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureBase Extends OcuPilot.Test.AnalyticsListingGroupBase [ Abstract ]
{

/// <p>The catalog of every measure a test makes, the package of its classes, and the package of the classes a test saves to show a write refuse OcuPilot's own code (AD-10).</p>
Parameter MARKER = "OcuProbeQMW";

Parameter CLASSMARKER = "OcuProbeQMW.Analytics.QMW";

Parameter OWNCLASSMARKER = "OcuPilotQMW.Analytics.QMW";

/// <p>The set of every measure a test makes.</p>
Parameter SETNAME = "Probe";

Parameter MEASURESCREEN = "/screens/analytics.qualitymeasures/action";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureAdd";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureUpdate";

Parameter COPYTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureCopy";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureDelete";

Parameter WRITEENDPOINT = "QualityMeasures";

Method RemoveFixtures() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveQualityMeasures")
}

/// <p>The full name of the test measure whose id is <var>pId</var>.</p>
ClassMethod Name(pId As %String) As %String
{
    Quit ..#MARKER _ "/" _ ..#SETNAME _ "/" _ pId
}

/// <p>The class text of the measure <var>pId</var> in the class <var>pClass</var>: a class parameter the writes must keep, and a measure over the Visits cube with two groups (one element
/// disabled) and one documentation item, its expression <var>pExpression</var>. <var>pLinkedTo</var>, when given, makes it a measure linked to that master, with the expression <code>1</code> and no group;
/// <var>pNote</var>, when given, is a second class parameter, which changes the class's text and not the measure; <var>pSpare</var>, when true, adds two groups that cannot count: <code>Off</code>,
/// a disabled group, and <code>Idle</code>, whose one element is disabled.</p>
ClassMethod MeasureText(pId As %String, pClass As %String, pLinkedTo As %String = "", pExpression As %String = "[Long]/[Everyone]", pNote As %String = "", pSpare As %Boolean = 0) As %String
{
    Set tNL = $Char(13, 10)
    Set tNS = "http://www.intersystems.com/deepsee/qualityMeasure"
    Set tHead = "<qualityMeasure xmlns='" _ tNS _ "' catalog='" _ ..#MARKER _ "' set='" _ ..#SETNAME _ "' id='" _ pId _ "' caption='Original' description='Seeded' subjectArea='" _ ..#VISITS _ "' "
    If pLinkedTo '= "" {
        Set tXML = tHead _ "linkedTo='" _ pLinkedTo _ "' expression='1'/>"
    } Else {
        Set tXML = tHead _ "expression='" _ pExpression _ "' published='true' format='#.##' href='https://example.invalid/measure'>" _
            "<group name='Long' caption='Long stays' description='Visits over the limit'>" _
            "<element name='Over30' caption='Over 30 minutes' mdx='{[Minutes].&amp;[30]}'/>" _
            "<element name='Retired' caption='Retired rule' mdx='{[Minutes].&amp;[99]}' disabled='true'/>" _
            "</group>" _
            "<group name='Everyone' caption='All visits' description='Every visit'><element name='AllVisits' caption='All visits' mdx='{[Minutes].Members}'/></group>" _
            $Select('pSpare: "", 1: "<group name='Off' caption='Off group' description='Disabled' disabled='true'><element name='OffRule' caption='Off rule' mdx='{[Minutes].&amp;[30]}'/></group>" _
                "<group name='Idle' caption='Idle group' description='No enabled element'><element name='IdleRule' caption='Idle rule' mdx='{[Minutes].&amp;[30]}' disabled='true'/></group>") _
            "<meta name='Purpose' caption='Purpose' section='Overview'>Counts the long visits &amp; their share.</meta>" _
            "</qualityMeasure>"
    }
    Quit "Class " _ pClass _ " Extends %DeepSee.QualityMeasure.QualityMeasure" _ tNL _ "{" _ tNL _ tNL _ "/// A line the writes keep." _ tNL _ "Parameter KEEP = ""kept"";" _ tNL _ tNL _ $Select(pNote = "": "", 1: "Parameter NOTE = """ _ pNote _ """;" _ tNL _ tNL) _
        "XData QualityMeasure [ XMLNamespace = """ _ tNS _ """ ]" _ tNL _ "{" _ tNL _ $Translate(tXML, "'", """") _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
}

/// <p>Save and compile the measure <var>pId</var> as the class <var>pClass</var> with the text <method>MeasureText</method> gives it. An expression that names a missing group saves the class and
/// answers the compiler's refusal, which leaves the measure registered and not compiled.</p>
ClassMethod SaveMeasure(pId As %String, pClass As %String, pLinkedTo As %String = "", pExpression As %String = "[Long]/[Everyone]", pNote As %String = "", pSpare As %Boolean = 0) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pClass, ..MeasureText(pId, pClass, pLinkedTo, pExpression, pNote, pSpare))
    If $$$ISOK(tSC) {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(pClass, "ck-d")
        Set $NAMESPACE = tOrigNS
    }
    Quit tSC
}

/// <p>The model the vendor reads from the measure <var>pName</var> without its link, as one string: <code>name|caption|description|subjectArea|expression|linkedTo|published|format|href</code>,
/// then each group as <code>~G:name|caption|description|disabled</code> with each of its elements as <code>;E:name|caption|mdx|disabled</code>, then each documentation item as
/// <code>~M:name|caption|section|disabled|content</code>; <code>"absent"</code> for a name that holds no measure.</p>
ClassMethod QModel(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = "absent"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tModel = ##class(%DeepSee.QualityMeasure.Utils).%GetModel(pName, , 0)
        If $IsObject(tModel) && (tModel.name '= "") {
            Set tOut = tModel.name _ "|" _ tModel.caption _ "|" _ tModel.description _ "|" _ tModel.subjectArea _ "|" _ tModel.expression _ "|" _ tModel.linkedTo _ "|" _ ''tModel.published _ "|" _ tModel.format _ "|" _ tModel.href
            For tAt = 1:1:tModel.groups.Count() {
                Set tGroup = tModel.groups.GetAt(tAt)
                Set tOut = tOut _ "~G:" _ tGroup.name _ "|" _ tGroup.caption _ "|" _ tGroup.description _ "|" _ ''tGroup.disabled
                For tElementAt = 1:1:tGroup.elements.Count() {
                    Set tElement = tGroup.elements.GetAt(tElementAt)
                    Set tOut = tOut _ ";E:" _ tElement.name _ "|" _ tElement.caption _ "|" _ tElement.mdx _ "|" _ ''tElement.disabled
                }
            }
            For tAt = 1:1:tModel.metas.Count() {
                Set tMeta = tModel.metas.GetAt(tAt)
                Set tOut = tOut _ "~M:" _ tMeta.name _ "|" _ tMeta.caption _ "|" _ tMeta.section _ "|" _ ''tMeta.disabled _ "|" _ tMeta.content
            }
        }
    } Catch {
        Set tOut = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The value of <var>pField</var> in the Quality measures screen's row named <var>pName</var>: <code>"absent"</code> when no row has that name, <code>"unreadable"</code> and the
/// HTTP status when the read is not answered.</p>
ClassMethod ScreenField(pName As %String, pField As %String) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasures/read?ns=" _ ..#NAMESPACE, "", .tHttp, .tRead)
    If (tHttp '= 200) || '$IsObject(tRead) || '$IsObject(tRead.%Get("rows")) Quit "unreadable " _ tHttp
    Set tOut = "absent"
    For tAt = 0:1:tRead.rows.%Size() - 1 {
        Set tRow = tRead.rows.%Get(tAt)
        If tRow.%Get("Name") = pName Set tOut = tRow.%Get(pField)
    }
    Quit tOut
}

/// <p>The value of <var>pField</var> in the row named <var>pName</var> of the agent's read tool <code>analytics.qualitymeasures.read</code>: <code>"absent"</code> when no row has that
/// name, <code>"unreadable"</code> when the tool is not answered.</p>
ClassMethod ToolField(pName As %String, pField As %String) As %String
{
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasures.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    If (tLeg.%Get("http") '= 200) || '$IsObject(tLeg.%Get("rows")) Quit "unreadable"
    Set tOut = "absent"
    For tAt = 0:1:tLeg.rows.%Size() - 1 {
        Set tRow = tLeg.rows.%Get(tAt)
        If tRow.Name = pName Set tOut = tRow.%Get(pField)
    }
    Quit tOut
}

/// <p>The groups, elements and documentation of <var>pModel</var> (a <method>QModel</method> answer): everything after its header.</p>
ClassMethod Members(pModel As %String) As %String
{
    Quit $Piece(pModel, "~", 2, *)
}

/// <p>1 when the vendor's registry holds the measure <var>pName</var> for the class <var>pClass</var> and the class is compiled.</p>
ClassMethod QRegistered(pName As %String, pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeld = (##class(%DeepSee.QualityMeasure.Utils).%GetQualityMeasureClass(pName) = pClass) && $System.OBJ.IsUpToDate(pClass)
    } Catch {
        Set tHeld = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit ''tHeld
}

/// <p>What the instance holds of the write tests' measures: every class under the two class markers with the length and a SHA-1 checksum of its text, and every node of
/// <code>^DeepSee.QMsrs</code> whose subscripts name the catalog or either class package (the name, class and subject area nodes), as one string, so two calls compare equal when nothing
/// was written between them.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tPrefix = ..#MARKER _ ".", $Piece(..#OWNCLASSMARKER, ".", 1) _ "." {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ? ORDER BY Name", $ZConvert(tPrefix, "U"))
            While tRS.%Next() {
                Set tText = ..TextOf(tRS.%GetData(1))
                Set tOut = tOut _ tRS.%GetData(1) _ "=" _ $Length(tText) _ ":" _ $System.Encryption.Base64Encode($System.Encryption.SHA1Hash($ZConvert(tText, "O", "UTF8"))) _ ";"
            }
        }
        Set tMarks = $ListBuild($ZConvert(..#MARKER, "U"), $ZConvert($Piece(..#OWNCLASSMARKER, ".", 1), "U"))
        Set tNode = "^DeepSee.QMsrs"
        For {
            Set tNode = $Query(@tNode)
            If tNode = "" Quit
            Set tUpper = $ZConvert(tNode, "U")
            If ($Find(tUpper, $List(tMarks, 1)) = 0) && ($Find(tUpper, $List(tMarks, 2)) = 0) Continue
            Set tOut = tOut _ "node " _ tNode _ "=" _ @tNode _ ";"
        }
    } Catch {
        Set tOut = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>1 when the class <var>pClass</var> is not defined and the measure <var>pName</var> has no node in the registry, under any subject area.</p>
ClassMethod QGone(pName As %String, pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tGone = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGone = '##class(%Dictionary.ClassDefinition).%ExistsId(pClass) && '$Data(^DeepSee.QMsrs("qmsrNames", $ZConvert(pName, "U"))) && '$Data(^DeepSee.QMsrs("qmsrClasses", pClass))
        Set tArea = ""
        For {
            Set tArea = $Order(^DeepSee.QMsrs("cubes", tArea))
            If tArea = "" Quit
            If $Data(^DeepSee.QMsrs("cubes", tArea, $ZConvert(pName, "U"))) Set tGone = 0
        }
    } Catch {
        Set tGone = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit ''tGone
}

/// <p>The quality measure screen's pairs, which its writes need beside the source code API's.</p>
ClassMethod HeldPairSpec() As %String
{
    Quit $Parameter(..#PORT, "QUALITYMEASUREPAIRS")
}

/// <p>1 when the <code>ConfigChange</code> row of the verb <var>pVerb</var> on the measure <var>pId</var> since <var>pSince</var> records the outcome <var>pOutcome</var>.</p>
ClassMethod Recorded(pSince As %String, pId As %String, pVerb As %String, pOutcome As %String) As %Boolean
{
    Do $ClassMethod(..#QUEUES, "AuditRows", pSince, "quality-measure", pId, pVerb, .tData)
    Quit ''(tData [ ("""outcome"":""" _ pOutcome _ """"))
}

}
