/// <p>The task output read's codes (AD-12, AD-21, Story 21.36): every <code>LOG.TASKOUTPUT.*</code> code
/// <method>OcuPilot.Port.LogSourcePort.TaskOutputRows</method> refuses with, and the one sentence each
/// carries. Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather
/// than in it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> answers these codes through
/// <method>ReasonFor</method>. No refusal carries the stored location.</p>
Class OcuPilot.Api.TaskError Extends %RegisteredObject
{

/// <p>409: the task writes no output file -- its <code>OpenOutputFile</code> is off or its
/// <code>OutputFilename</code> is empty. Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug before any file is touched.</p>
Parameter NONE = "LOG.TASKOUTPUT.NONE";

Parameter REASONNONE = "This task does not write its output to a file.";

/// <p>409: the task's stored output location is not one file directly in the manager directory, so
/// OcuPilot never reads it. Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug
/// before any file is touched.</p>
Parameter ELSEWHERE = "LOG.TASKOUTPUT.ELSEWHERE";

Parameter REASONELSEWHERE = "OcuPilot reads output files only in the manager directory. Open this one on the server.";

/// <p>404: the task names an output file in the manager directory and the file is not there yet.
/// Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug.</p>
Parameter ABSENT = "LOG.TASKOUTPUT.ABSENT";

Parameter REASONABSENT = "This task has not written its output file yet. It writes one each time it runs.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NONE Quit ..#REASONNONE
    If pCode = ..#ELSEWHERE Quit ..#REASONELSEWHERE
    If pCode = ..#ABSENT Quit ..#REASONABSENT
    Quit ""
}

}
