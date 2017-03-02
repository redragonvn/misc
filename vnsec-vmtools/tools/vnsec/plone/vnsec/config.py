USE_EXTERNAL_STORAGE = False

EXTERNAL_STORAGE_PATH = 'vnsec-files'

PROJECTNAME      = "vnsec"
SKINS_DIR        = "skins"

GLOBALS          = globals()

DEPENDENCIES = (
                     'TextIndexNG3',
                     'PloneLanguageTool',
                     'PloneKeywordManager',
                     'CMFContentPanels',
                     'SmartPortlets',
                     'qPloneResolveUID',
                     'qPloneComments',
                     'qPloneCaptchas',
                     'GrufSpaces',
                     'Quills',
                     'AddRemoveWidget',
                     'ArchAddOn',
                     'DataGridField',
                     'intelligenttext',
                     'PloneSoftwareCenter',
                     )

# skins
BASE_SKIN        = "Plone Tableless"
SKIN_NAMES       = ("vnsec-skin1", "vnsec-skin2", "vnsec-skin3", "vnsec-skin4-tableless")
DEFAULT_SKIN     = "vnsec-skin4-tableless"

LIB_FOLDERS      = ("vnsec-common", "vnsec-patches", ) 

# tabs
TABS             = [("index_html", "Home", "string:$portal_url/")]
TABS_ORDER       = ['news', 'Members', 'projects', 'resources', 'events']


# Permission
AddWeblogPerm    = 'Quills: Add Weblog'
AddContentPanelsPerm = 'Add CMF ContentPanels Tools'
AddGroupSpacePerm = 'GrufSpaces: Add GroupSpaces'

# portal config
PORTAL_TITLE     = "VNSECURITY"
PORTAL_DESC      = "VIETNAM SECURITY TEAM"
PORTAL_DEFAULT_VIEW = "front-page"

PORTAL_CHECKMAIL = 0
PORTAL_CHARSET   = "UTF-8"
PORTAL_FIXLINK   = 1


# Portlets
#'here/portlet_archives/macros/portlet',
#'here/portlet_author/macros/portlet',
#'here/portlet_blog_navigation/macros/portlet',
#'here/portlet_blogcalendar/macros/portlet',
#'here/portlet_bloglist/macros/portlet',
#'here/portlet_calendar/macros/portlet',
#'here/portlet_events/macros/portlet',
#'here/portlet_navigation/macros/portlet',
#'here/portlet_quills/macros/portlet',
#'here/portlet_recent_comments/macros/portlet',
#'here/portlet_recent_posts/macros/portlet',
#'here/portlet_related/macros/portlet',
#'here/portlet_review/macros/portlet',
#'here/portlet_tag_cloud/macros/portlet',
#'here/portlet_tag_clouds/macros/portlet',
#'here/portlet_topics/macros/portlet',
#'here/portlet_vnsec_helpcenter/macros/portlet',
#'here/portlet_vnsec_recent_comments/macros/portlet',
#'here/portlet_vnsec_recent_posts/macros/portlet',
#'here/portlet_vnsec_releases/macros/portlet',


PORTAL_LEFTSLOTS = (
                    'here/portlet_navigation/macros/portlet',
                    'here/portlet_searchbox/macros/portlet',
                    'here/smartportlets_tool/blogs/smartportlet',
                    'here/portlet_related/macros/portlet',
                    )

PORTAL_RIGHTSLOTS = (
                    'here/portlet_review/macros/portlet',
                    'here/portlet_events/macros/portlet',
                    'here/portlet_calendar/macros/portlet',
                    'here/portlet_vnsec_releases/macros/portlet',
                    )

# portal misc properties
VISIBLE_IDS      = True
CALENDAR_START   = 2006
TYPESNOTTOLIST   = 'File' 

# member area
MEMBERS_FOLDER_ID = 'people'
MEMBERS_FOLDER_DESC = "members' home directories"

MEMBER_DEFAULT_VIEW = "vnsec_member_view"

ROOT_MEMBER_LEFTSLOTS = (
                    'here/portlet_calendar/macros/portlet',
                    'here/portlet_bloglist/macros/portlet',
                    'here/portlet_tag_clouds/macros/portlet',
                    )

ROOT_MEMBER_RIGHTSLOTS = (
                    'here/portlet_review/macros/portlet',
                    'here/portlet_vnsec_recent_comments/macros/portlet',
                    'here/portlet_vnsec_recent_posts/macros/portlet',
                    'here/portlet_quills/macros/portlet',
                    )

MEMBER_LEFTSLOTS = (
                    'here/portlet_blog_navigation/macros/portlet',
                    'here/portlet_blogcalendar/macros/portlet',
                    'here/portlet_archives/macros/portlet',
                    'here/portlet_topics/macros/portlet',
                    'here/portlet_tag_cloud/macros/portlet',
                    )

MEMBER_RIGHTSLOTS = (
                    'here/portlet_review/macros/portlet',
                    'here/portlet_author/macros/portlet',
                    'here/portlet_recent_comments/macros/portlet',
                    'here/portlet_recent_posts/macros/portlet',
                    'here/portlet_quills/macros/portlet',
                    )

MEMBER_FOLDERS = ('Files', )


# Groups to be created
USERGROUPS = ( 
                    ('staffs',['Reviewer',]),
                    ('members', ['Member',]),
             )


if USE_EXTERNAL_STORAGE:
    try:
        import Products.ExternalStorage
    except ImportError:
        LOG('PloneSoftwareCenter',
            PROBLEM, 'ExternalStorage N/A, falling back to AttributeStorage')
        USE_EXTERNAL_STORAGE = False



# Projects config
PROJECT_CATEGORIES = [
        'Security|Security related projects|Security related projects.',
        'Exploit|Vulnerability exploits|Vulnerability exploits.',
        'Misc|Miscellaneous tools|Useful miscellaneous tools.',
                     ]
PROJECT_VERSIONS = []
PROJECT_PLATFORMS= ['Linux', 'Mac OS X', 'Windows', 'BSD', 'Solaris',
                    'UNIX (other)', ]

