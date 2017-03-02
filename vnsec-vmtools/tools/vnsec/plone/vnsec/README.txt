About

  vnsec is a VNSECURITY's product and skins for the Plone content management 
  system. It is designed from the ground up to work well and provide specialized 
  features for vnsecurity website, which is a community website with multi-blog, 
  software center, document center, multi user environment.

  * vnsec includes multiple skins under skins/vnsec-skin* directories.

  * Common library files for all skins located at skins/vnsec-common

  * This product also includes several hardned security patches for Zope/Plone
 
  Check config.py for configuration
  
  --rd
 
TODO

  * External Storage config

  * Customize Help Center view

  * https autentication

  * FlickerAlbum 

  * Fix PloneLogin History

  * PloneDocumentCenter based on PloneHelpCenter

  * Add qSimpleBlog features to Quills
  
  * Patch Search form & Script to disable site wide search
	CMFPlone/skins/plone_forms/search.pt
	search_form.pt

Notes

  * Many portal's settings and features will be changed after you install 
    vnsec product. So make sure to backup your data before install it. 
    vnsec should only be installed after all required components (see 
    below) are installed!!! Due to various permission changes and hardened
    patches, You can not reverse back to original Plone after installing 
    this product

  * Email functions of PloneHelpCenter discussion_notify or reset password
    wont work if Mail settings are not configured properly. 
    PloneHelpCenter discussion_notify + Quills discussion reply would crash
    zope as well. Be carefull.
    Temporary solution: remove discussion_notify feature of PloneHelpCenter

  * PloneSoftwareCenter & Quills have "getCategories" confliction. Should
    patch either PloneSoftwareCenter or Quills to fix. Tested on:
         - 2.0 svn/unreleased 
	 - 1.5.0.a3-dev10

  * GroupUserFolder (plone 2.5.1) & GrufSpaces (<1.0) doesnt work together
    (couldn't change group properties)
    Upgrade Grufspace to svn version 1.0.0 CVS/SVN (UNRELEASED) solved the
    problem

  * PloneLoginHistory doesn't work with SessionCrumbler

  * FCKeditor 2.3.3 (SVN UNRELEASED) doesn't work with firefox 1.5

  * EasyBlog 1.0.1-beta-2 add Add Portal Content privilege to Anonymous (bad)

  * Friendly Album
    Should modify the simplejson/decoder.py import line (line 6) to
         import from scanner import Scanner, pattern

  * LinguaPlone uses alot of CPU

  * CHIM won't work with kupu

  * eaycomment is not completed yet. It's broken & has security problem 
    (anonymous can delete comments) 

  * Some products still use toPortalTime which is no longer avaiable in Plone 
    2.5. Change toPortalTime to toLocalizedTime will fix the problem

  * qPloneComments: if you want user to be able to
    - delete comments on his posts (add "Moderate Discussion" permission to
      owner)
    - moderate comments (system wide): add user to Discussion Manager group

  * VERIFY PLS: some product (ex: calendar portlets) uses getBeginAndEndTimes 
    on event day (copy from portlet_calendar). It won't work anymore since 
    getBeginAndEndTimes has been removed. 
    Fix: readd getBeginAndEndTimes? or remove that from blogcalendar

  * FIXME: when uninstall, all created contents during installation will be
    deleted .. shoudl find a way to avoid this 

  * GrufSpaces: in order to limit anonymous to access shared data inside 
    group space, follow README of GrufSpace to:
    	- change Anonymous permission on Private State (also visible?)
	- change workflows other contents in groupspace to the 
	  correct groupspace workflows (see portal_placeful_workflow)

  * GrufSpaces: either open or close state, group member can new, delete and
    change content of the root group folder. This should be corrected
    GrufSpaces/Extensions/groupspace_open_close_workflow.py)

  * ContentPanels lack of defined permissions. TODO: add


Requires

  * Zope 2.8.7+ or 2.9.3+

  * Plone 2.5+


Required Components
  
  * PloneKeywordManager

  * CMFContentPanels

  * SessionCrumbler

  * GrufSpaces

  * SmartPortlets

  * qPloneComments

  * qPloneCaptcha

  * AddRemoveWidget (for PloneSoftwareCenter)

  * ArchAddOn (for PloneSoftwareCenter)

  * DataGridField (for PloneSoftwareCenter)

  * ExternalStorage (for PloneSoftwareCenter)

  * contentmigration (for PloneSoftwareCenter)
  
  * intelligenttext (for PloneSoftwareCenter)

  * PloneSoftwareCenter

  * plonetrackback (for Quills)

  * basesyndicationa (for Quills)

  * fatsyndication (for Quills)

  * RPCAuth ((for Quills)

  * Quills 

  * PloneArticle

  * adsenseproduct

Recommended Components

  * PloneAzax 

  * qSEOptimizer 

  * PloneHelpCenter

  * FriendlyAlbum

  * FlickrAlbum

  * PloneLanguageTool 

  * LinguaPlone 

  * PromoEngine

  * intelligenttext 

  * TextIndexNG3

Recommended Components (for development)

  * DocFinderTab

  * Clouseau


Contact

  Email : rd@vnsecurity.net          
