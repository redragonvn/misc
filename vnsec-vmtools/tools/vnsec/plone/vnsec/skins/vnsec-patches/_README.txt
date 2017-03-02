This folder contains modifed files of other products to add feature, change
layout, view or fix bugs

- login_from: added captcha check 
- PloneSoftwareCenter: remove 'power by info'
- PloneHelpCenter: remove 'power by info'
- Quills portlets: 
   - author - change the display look
   - quills - remove power by quills 
   - recent_posts - display only recent posts inside the blog
   - blogcalendar - remove event part from calendar porlet (tal:condition="nothing|day/event")
   (TODO) display correct information
- Search form: remove unnecessary options
- qPloneComments:
  o Change comment form from qPloneComments/skins/qplonecomments/2.5/discussion_reply_form.cpt
	- add Re: subject
	- Only check for captcha for anonymous user
	- fix redirect url bug in discussion_reply.cpy
