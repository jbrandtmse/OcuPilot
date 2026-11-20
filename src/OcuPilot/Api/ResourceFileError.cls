/// <p>The Resources list's export and import codes and sentences (AD-29, AD-39): every <code>RESOURCEFILE.*</code> code
/// <class>OcuPilot.Port.ResourceTransferPort</class> answers with, and the one sentence each carries. Each sentence is published once
/// in EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file> key. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000 parameters (ERROR
/// #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method> answer
/// these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>IMPORT</parameter> is not a refusal: it is the consequence code an import's proposal card and dialog carry.</p>
Class OcuPilot.Api.ResourceFileError Extends %RegisteredObject
{

/// <p>409: an import file is not a resource export: it holds a document type declaration, is not well-formed, has another root, holds no
/// resource, or holds a resource with no usable name.</p>
Parameter SHAPE = "RESOURCEFILE.SHAPE";

Parameter REASONSHAPE = "This file is not a resource export, or it holds no resource.";

/// <p>409: the file, or the resources it would replace, changed after the import was reviewed.</p>
Parameter CHANGED = "RESOURCEFILE.CHANGED";

Parameter REASONCHANGED = "The file's resources changed after the import was reviewed, so nothing was imported. Review the import again.";

/// <p>409: an import file holds more characters, or more resources, than an import reviews.</p>
Parameter TOOLARGE = "RESOURCEFILE.TOOLARGE";

Parameter REASONTOOLARGE = "A resource file holds at most 2,000 resources, and this one is larger.";

/// <p>The consequence code an import's proposal card and dialog carry.</p>
Parameter IMPORT = "RESOURCEFILE.IMPORT";

Parameter REASONIMPORT = "It overwrites any existing resource with the same name. This cannot be undone.";

/// <p>Every <code>RESOURCEFILE.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#SHAPE, ..#CHANGED, ..#TOOLARGE, ..#IMPORT)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#SHAPE Quit ..#REASONSHAPE
    If pCode = ..#CHANGED Quit ..#REASONCHANGED
    If pCode = ..#TOOLARGE Quit ..#REASONTOOLARGE
    If pCode = ..#IMPORT Quit ..#REASONIMPORT
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 409 for a refusal, and 0 for a code that is no refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If (pCode = ..#SHAPE) || (pCode = ..#CHANGED) || (pCode = ..#TOOLARGE) Quit 409
    Quit 0
}

}
