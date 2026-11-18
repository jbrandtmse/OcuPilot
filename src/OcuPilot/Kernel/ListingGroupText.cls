/// <p>The text of a listing group's class (Story 24.11): a class extending <code>%DeepSee.ListingGroupDefinition</code> whose <code>Listings</code>
/// XData holds the group, in the form the source code API keeps it (UDL, a line feed between lines and one after the last). The analytics port
/// composes a group's XML from the model with the vendor's own writer and puts it here: a new group is <method>ClassText</method>, a changed one
/// is <method>Splice</method> over the class's current text, which replaces the XData body (<parameter>XDATANAME</parameter>) and, when
/// <parameter>DEPENDSON</parameter> is 1, the <code>DependsOn</code> keyword, and keeps every other line as it is. Every method is pure and names no vendor
/// class beyond the superclass's name. A subclass names another superclass, XML namespace and XData (<class>OcuPilot.Kernel.QualityMeasureText</class>).</p>
Class OcuPilot.Kernel.ListingGroupText Extends %RegisteredObject
{

/// <p>The class every listing group's class extends.</p>
Parameter SUPERCLASS = "%DeepSee.ListingGroupDefinition";

/// <p>The XML namespace of the XData.</p>
Parameter XMLNAMESPACE = "http://www.intersystems.com/deepsee/listinggroup";

/// <p>The name of the XData that holds the definition.</p>
Parameter XDATANAME = "Listings";

/// <p>1 when the class declares the cube classes it depends on in its header, 0 when it carries no <code>DependsOn</code>.</p>
Parameter DEPENDSON = 1;

/// <p>The <code>DependsOn</code> keyword's value for the comma-separated class names <var>pClasses</var>: the one name, or the names in
/// parentheses; <code>""</code> for none.</p>
ClassMethod DependsOnValue(pClasses As %String) As %String
{
    If $Length(pClasses, ",") > 1 Quit "(" _ $Replace(pClasses, ",", ", ") _ ")"
    Quit pClasses
}

/// <p>The text of a new class <var>pClass</var> that depends on the cube classes <var>pClasses</var> (comma-separated, may be
/// empty; ignored when <parameter>DEPENDSON</parameter> is 0) and holds the XML <var>pXml</var>.</p>
ClassMethod ClassText(pClass As %String, pClasses As %String, pXml As %String) As %String
{
    Set tNL = $Char(10)
    Set tHeader = "Class " _ pClass _ " Extends " _ ..#SUPERCLASS
    If ..#DEPENDSON && (pClasses '= "") Set tHeader = tHeader _ " [ DependsOn = " _ ..DependsOnValue(pClasses) _ " ]"
    Quit tHeader _ tNL _ "{" _ tNL _ tNL _ "XData " _ ..#XDATANAME _ " [ XMLNamespace = """ _ ..#XMLNAMESPACE _ """ ]" _ tNL _ "{" _ tNL _ ..Body(pXml) _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
}

/// <p>The XML <var>pXml</var> as the lines of an XData body: no carriage return and no trailing line feed.</p>
ClassMethod Body(pXml As %String) As %String
{
    Set tBody = $Translate(pXml, $Char(13))
    While $Extract(tBody, *) = $Char(10) {
        Set tBody = $Extract(tBody, 1, *-1)
    }
    Quit tBody
}

/// <p>The class text <var>pText</var> with its XData body replaced by <var>pXml</var> and, when <parameter>DEPENDSON</parameter> is 1, its <code>DependsOn</code>
/// made the cube classes <var>pClasses</var>, in <var>pSpliced</var>; every other character is kept, and the class header is rewritten only when
/// its <code>DependsOn</code> names other classes. 0 when the text has no class header or no such XData.</p>
ClassMethod Splice(pText As %String, pClasses As %String, pXml As %String, Output pSpliced As %String) As %Boolean
{
    Set pSpliced = ""
    Set tNL = $Char(10)
    Set tCount = $Length(pText, tNL)
    Kill tLine
    For tAt = 1:1:tCount {
        Set tLine(tAt) = $Piece(pText, tNL, tAt)
    }
    Set tHeader = 0
    Set tXData = 0
    For tAt = 1:1:tCount {
        Set tHead = $ZConvert($ZStrip(tLine(tAt), "<W"), "U")
        If 'tHeader && ($Extract(tHead, 1, 6) = "CLASS ") Set tHeader = tAt
        If tHeader && ($Extract(tHead, 1, 6 + $Length(..#XDATANAME)) = ("XDATA " _ $ZConvert(..#XDATANAME, "U"))) {
            Set tXData = tAt
            Quit
        }
    }
    If 'tHeader || 'tXData Quit 0
    Set tOpen = 0
    Set tClose = 0
    For tAt = tXData + 1:1:tCount {
        If 'tOpen {
            If $ZStrip(tLine(tAt), "<>W") = "{" Set tOpen = tAt
            Continue
        }
        If tLine(tAt) = "}" {
            Set tClose = tAt
            Quit
        }
    }
    If 'tOpen || 'tClose Quit 0
    If ..#DEPENDSON Set tLine(tHeader) = ..HeaderWith(tLine(tHeader), pClasses)
    Set tSpliced = ""
    For tAt = 1:1:tOpen {
        Set tSpliced = tSpliced _ tLine(tAt) _ tNL
    }
    Set tSpliced = tSpliced _ ..Body(pXml) _ tNL
    For tAt = tClose:1:tCount {
        Set tSpliced = tSpliced _ tLine(tAt) _ $Select(tAt < tCount: tNL, 1: "")
    }
    Set pSpliced = tSpliced
    Quit 1
}

/// <p>The class header line <var>pHeader</var> whose <code>DependsOn</code> keyword names the cube classes <var>pClasses</var>: the line itself when
/// the keyword already names exactly those classes in that order; else the keyword replaced, added or, for no classes, removed, with the line's other
/// keywords kept in order.</p>
ClassMethod HeaderWith(pHeader As %String, pClasses As %String) As %String
{
    Set tOpen = $Find(pHeader, "[")
    Set tClosing = $Length(pHeader)
    While (tClosing > 0) && ($Extract(pHeader, tClosing) '= "]") {
        Set tClosing = tClosing - 1
    }
    Set tPrefix = $Select(tOpen: $ZStrip($Extract(pHeader, 1, tOpen - 2), ">W"), 1: pHeader)
    Set tKeywords = $Select(tOpen && (tClosing >= tOpen): $ZStrip($Extract(pHeader, tOpen, tClosing - 1), "<>W"), 1: "")
    Set tTokens = ..Tokens(tKeywords)
    Set tFound = 0
    Set tChanged = 0
    Set tKept = ""
    For tAt = 1:1:$ListLength(tTokens) {
        Set tToken = $List(tTokens, tAt)
        If $ZConvert($ZStrip($Piece(tToken, "=", 1), "<>W"), "U") '= "DEPENDSON" {
            Set tKept = tKept _ $ListBuild(tToken)
            Continue
        }
        Set tFound = 1
        If ..ClassesOf($ZStrip($Piece(tToken, "=", 2, *), "<>W")) = pClasses {
            Set tKept = tKept _ $ListBuild(tToken)
        } Else {
            Set tChanged = 1
            If pClasses '= "" Set tKept = tKept _ $ListBuild("DependsOn = " _ ..DependsOnValue(pClasses))
        }
    }
    If 'tFound {
        If pClasses = "" Quit pHeader
        Set tChanged = 1
        Set tKept = tKept _ $ListBuild("DependsOn = " _ ..DependsOnValue(pClasses))
    }
    If 'tChanged Quit pHeader
    If tKept = "" Quit tPrefix
    Quit tPrefix _ " [ " _ $ListToString(tKept, ", ") _ " ]"
}

/// <p>The keywords of <var>pKeywords</var> as a <class>%List</class>: split at each comma outside parentheses and quotes, each trimmed.</p>
ClassMethod Tokens(pKeywords As %String) As %List
{
    Set tTokens = ""
    Set tDepth = 0
    Set tQuoted = 0
    Set tCurrent = ""
    For tAt = 1:1:$Length(pKeywords) {
        Set tChar = $Extract(pKeywords, tAt)
        If tChar = """" Set tQuoted = 'tQuoted
        If 'tQuoted {
            If tChar = "(" Set tDepth = tDepth + 1
            If tChar = ")" Set tDepth = tDepth - 1
            If (tChar = ",") && (tDepth = 0) {
                Set tTokens = tTokens _ $ListBuild($ZStrip(tCurrent, "<>W"))
                Set tCurrent = ""
                Continue
            }
        }
        Set tCurrent = tCurrent _ tChar
    }
    If $ZStrip(tCurrent, "<>W") '= "" Set tTokens = tTokens _ $ListBuild($ZStrip(tCurrent, "<>W"))
    Quit tTokens
}

/// <p>The class names <var>pValue</var> lists, comma-separated and without spaces: a keyword value as the class text spells it, with or without
/// parentheses.</p>
ClassMethod ClassesOf(pValue As %String) As %String
{
    Set tValue = pValue
    If ($Extract(tValue) = "(") && ($Extract(tValue, *) = ")") Set tValue = $Extract(tValue, 2, *-1)
    Set tNames = ""
    For tAt = 1:1:$Length(tValue, ",") {
        Set tName = $ZStrip($Piece(tValue, ",", tAt), "<>W")
        If tName '= "" Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
    }
    Quit tNames
}

}
