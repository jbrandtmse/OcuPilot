/// <p>Task Manager email's Set value (Story 21.19, AD-6, AD-51, AD-53, AD-58): set one of the Task Manager's email settings, through
/// <code>%SYS.Task.Config.EmailSet</code>. The agent reaches it through a proposal the user confirms; Task Manager email reaches it through its
/// <code>set</code> row action, which names the setting and the value. Its rules, pairs and consequence are
/// <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s; the mail password is no setting of this tool and no argument names it (AD-35).</p>
Class OcuPilot.Screen.Tool.TaskMailSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "tasks.mail.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskMailSettingList";

Parameter DESCRIPTION = "Propose setting one of the Task Manager's email settings on this instance: the mail server, port, sender, reply-to, time zone, sign-in name, SSL configuration, STARTTLS switch, and the subject and message sent for a task that succeeds and for one that fails. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the Task Manager email list reports it, and give the new value as text in the form the list's Accepts column states; the STARTTLS switch takes 1 or 0 and the port a whole number from 1 to 65535 or nothing. A subject or message may use only the fields the refusal names between #( and )#. The mail password is not set here and is never shown. A name the list does not report and a value the setting does not accept are refused.";

Parameter ENDPOINTNAME = "TaskMail";

Parameter CLASSICPAGES = "%cspapp.mgr.utilsystaskmail";

}
