import os

from Products.CMFCore.DirectoryView import addDirectoryViews
from Products.CMFCore.utils import getToolByName
from Products.CMFCore.CMFCorePermissions import ManagePortal
from Products.Archetypes.public import listTypes
from Products.Archetypes.Extensions.utils import installTypes, install_subskin

from cStringIO import StringIO
import string

from Products.vnsec.config import *
from Products.vnsec import skin_globals

# custom import
from Products.CMFPlone.migrations.migration_util import safeEditProperty
#from Products.CMFPlone.migrations.migration_util import addLinesToProperty
from Products.CMFCore.permissions import AddPortalMember
from Products.CMFCore.CMFCorePermissions import ReplyToItem
from Products.CMFCore.CMFCorePermissions import ManagePortal
from types import ListType, TupleType
from Globals import package_home


def addLinesToProperty(obj, key, values):
    if obj.hasProperty(key):
        data = getattr(obj, key)
        if type(data) is TupleType:
            data = list(data)
        if type(values) is ListType:
            data.extend(values)
        else:
            if values not in data:
                data.append(values)
        obj._updateProperty(key, data)
    else:
        if type(values) is not ListType:
            values = [values]
        obj._setProperty(key, values, 'lines')

def installDepend(self, out):
    quickinstaller = getToolByName(self,'portal_quickinstaller')
    for productname in DEPENDENCIES:
        if quickinstaller.isProductInstallable(productname) \
        and not quickinstaller.isProductInstalled(productname):
            print >> out, u"Installing dependency %s:" % productname
            quickinstaller.installProduct(productname)
            get_transaction().commit(1)


def configPermissions(self, out):
    changeFolderPermissions(self, out, GROUPS_FOLDER_ID)
    self.manage_permission('List portal members',
                           roles=('Anonymous',),
                           acquire=True,
                           )
    print >> out, "Configured permissions."

def configOrder(self, out):
    # move 'news' and 'events' to top
    self.moveObjectsToTop(TABS_ORDER)
    print >> out, "Ordered top-level objects."

def updateCatalog(self):
    ct = getToolByName(self,'portal_catalog')
    ct.refreshCatalog()

def updateWorkflowPolicyByType(self, policy, ptype, wf):
    policy.setChain(portal_type=ptype, chain=(wf,))

def updateGrufWorkflow(self, out):
    placeful_wf_tool = getToolByName(self,'portal_placeful_workflow')
    #wf_policies = wf.getWorkflowPolicies()
    #type_tool = getToolByName(self,'portal_types')
    #type_list = type_tool.listTypeInfo()

   
    GRUF_WF_POLICIES = {
                'groupspacearea_public_workflow_policy':
                'groupspace_content_published_workflow', 
                'groupspacearea_shared_workflow_policy':
                'groupspace_content_shared_workflow', 
                'groupspacearea_resources_workflow_policy':
                'groupspace_content_intra_workflow', 
                'groupspacearea_test_workflow_policy':
                'groupspace_content_test_workflow', 
                'groupspacearea_box_workflow_policy':
                'groupspace_content_submit_workflow'}
    
    TYPE_LIST = ['Topic', 'Large Plone Folder', 'Document', 'Folder', 
                'Image', 'Favorite', 'Event', 'News Item', 'Link', 'File', 
                'ContentPanels', ]

    # set the right workflow policy to all content inside grufspace
    for gruf_wf_id in GRUF_WF_POLICIES.keys():
        print >> out, u"Updating workflow %s:" % gruf_wf_id

        wf_policy = getattr(placeful_wf_tool, gruf_wf_id)  
        for ptype in TYPE_LIST:
            updateWorkflowPolicyByType(self, wf_policy, ptype, 
                                        GRUF_WF_POLICIES[gruf_wf_id])

    # set the right permission for the main groupspace
    # remove all manage permission of GroupMember
    portal_wf_tool = getToolByName(self,'portal_workflow') 
    wf = getattr(portal_wf_tool, 'groupspace_open_close_workflow')

    MANAGE_PERMISSIONS = ('Copy or Move', 'Modify portal content', 'Add portal content', 'Delete objects', 'View management screens', 'GrufSpaces: Assign GroupSpace Roles', 'ATContentTypes: Add Document', 'ATContentTypes: Add Event', 'ATContentTypes: Add Favorite', 'ATContentTypes: Add File', 'ATContentTypes: Add Folder', 'ATContentTypes: Add Image', 'ATContentTypes: Add Large Plone Folder', 'ATContentTypes: Add Link', 'ATContentTypes: Add News Item', 'Add portal events', 'Add portal folders', 'Change portal events', 'Change portal topics', 'WebDAV Lock items', 'WebDAV Unlock items') 

    open_sdef = wf.states['open']
    close_sdef = wf.states['closed']

    for p in MANAGE_PERMISSIONS:
        open_perms = open_sdef.getPermissionInfo(p) 
        if 'GroupMember' in open_perms['roles']:
            open_perms['roles'].remove('GroupMember')
            open_sdef.setPermission(p, open_perms['acquired'], 
                                        open_perms['roles'])

        close_perms = close_sdef.getPermissionInfo(p) 
        if 'GroupMember' in close_perms['roles']:
            close_perms['roles'].remove('GroupMember')
            close_sdef.setPermission(p, close_perms['acquired'], 
                                        close_perms['roles'])

    # update the security settings of all workflow-aware objects
    wf.updateRoleMappings()

def importContent(self, id, container):
    zexp_path = os.path.join(package_home(skin_globals), 'import', 
                                '%s.zexp' % id)
    container._importObjectFromFile(zexp_path, verify = 1, set_owner = 1)

    return getattr(container, id)


def setupPortalContent(self, out):
    ## smart folders, workspace, software center, import content panel

    urltool = getToolByName(self, 'portal_url')
    portal = urltool.getPortalObject()
    wftool = portal.portal_workflow

    existing = portal.objectIds()

    # grufspace workspace (resources)
    if 'Resources' not in existing:
        portal.invokeFactory('GroupSpace', id='Resources', title='Resources', 
                            description='Document Warehouse')
        resources = portal.Resources
        
        area_description = {'public':'Public content',
                            'shared':'Shared content editable by Members',
                            'resources':'Internal Published Resources',
                            'test':'Test content editable by the Owner', 
                            'box':'Box content addable and viewable by Owner',
                           }
        
        for area in area_description.keys():
            resources[area].setDescription(area_description[area])

        # limit content type can add

        # permission (members)
        resources.assignCollabRoleToGroup('GroupMember', 'members')
        resources.assignCollabRoleToGroup('GroupAdmin', 'staffs')

        # publish
        wftool.doActionFor(resources, 'open')
    
    # software center
    if 'projects' not in existing:
        portal.invokeFactory('PloneSoftwareCenter', id='projects', 
                            title='Projects', description="Member's Projects",
                            availableCategories = PROJECT_CATEGORIES, 
                            availableVersions = PROJECT_VERSIONS,
                            availablePlatforms = PROJECT_PLATFORMS,
                            
                            )
        projects = portal.projects
        
        # publish
        # wftool.doActionFor(projects, 'publish')

    # list topic
    if 'list' not in existing:
        portal.invokeFactory('Topic', id='list', title='List', 
                            description='Site Content List')
        list_topic = portal.list
        list_topic.setLayout('folder_summary_view')

        # subtopics

        # blogs
        list_topic.invokeFactory('Topic', id='blogs', title='Blogs', 
                                description="List of Member's Blogs")
        blogs_topic = list_topic.blogs
        type_crit = blogs_topic.addCriterion('Type','ATPortalTypeCriterion')
        type_crit.setValue('Weblog')
        sort_crit = blogs_topic.addCriterion('created','ATSortCriterion')
        state_crit = blogs_topic.addCriterion('review_state', 'ATSimpleStringCriterion')
        state_crit.setValue('published')
        blogs_topic.setSortCriterion('sortable_title', True)
        blogs_topic.setLayout('folder_summary_view')

        # blogentries
        list_topic.invokeFactory('Topic', id='blogentries', title='Blog Entries', 
                                description='List of Blog Entries')
        blogentries_topic = list_topic.blogentries
        type_crit = blogentries_topic.addCriterion('Type','ATPortalTypeCriterion')
        type_crit.setValue('Weblog Entry')
        sort_crit = blogentries_topic.addCriterion('created','ATSortCriterion')
        state_crit = blogentries_topic.addCriterion('review_state', 'ATSimpleStringCriterion')
        state_crit.setValue('published')
        blogentries_topic.setSortCriterion('effective', True)
        blogentries_topic.setLayout('folder_summary_view')

        # projects
        list_topic.invokeFactory('Topic', id='projects', title='Projects', 
                                description='List of Projects')
        projects_topic = list_topic.projects
        type_crit = projects_topic.addCriterion('Type','ATPortalTypeCriterion')
        type_crit.setValue('Software Project')
        sort_crit = projects_topic.addCriterion('created','ATSortCriterion')
        state_crit = projects_topic.addCriterion('review_state', 'ATSimpleStringCriterion')
        state_crit.setValue('published')
        projects_topic.setSortCriterion('effective', True)
        projects_topic.setLayout('folder_summary_view')

        # resources
        list_topic.invokeFactory('Topic', id='resources', title='Resources', 
                                description='Public Resources')
        resources_topic = list_topic.resources
        type_crit = resources_topic.addCriterion('path','ATPathCriterion')
        type_crit.setValue([resources.public.UID()])
        sort_crit = resources_topic.addCriterion('created','ATSortCriterion')
        state_crit = resources_topic.addCriterion('review_state', 'ATSimpleStringCriterion')
        state_crit.setValue('published')
        resources_topic.setSortCriterion('effective', True)
        resources_topic.setLayout('folder_summary_view')

    # create smart portlet
    smart_tool = portal.smartportlets_tool
    existing = smart_tool.objectIds()

    if 'blogs' not in existing:
        smart_tool.invokeFactory('SmartPortlet', id='blogs', title='Blogs', 
                            description="Members' Blogs", 
                            smartFolder=blogs_topic.UID(), 
                            maxItems=0)

    if 'projects' not in existing:
        smart_tool.invokeFactory('SmartPortlet', id='projects', 
                            title='Latest Project', 
                            description="Latest Projects", 
                            smartFolder=projects_topic.UID(),
                            maxItems=4)


    if 'resources' not in existing:
        smart_tool.invokeFactory('SmartPortlet', id='resources', 
                            title='Latest Resources', 
                            description="Latest Resources", 
                            smartFolder=resources_topic.UID(), 
                            maxItems=4)

    if 'blogsentries' not in existing:
        smart_tool.invokeFactory('SmartPortlet', id='blogsentries', 
                            title='Recent Blog Posts', 
                            description="Recent Blog Posts", 
                            smartFolder=blogentries_topic.UID(), 
                            maxItems=5)

    # import content panels
    existing = portal.objectIds()

    if 'front-page' not in existing:
        front_page = importContent(self, 'front-page', portal)
        front_page.reindexObject()

    # publish portal objects
    PUBLIC_ITEMS = ['news', 'events', 'Members', ]
    for item in PUBLIC_ITEMS:
        try:
            wftool.doActionFor(portal[item], 'publish')
        except:
            out.write( 'Unable to publish %s \n' % item)


def init_portal(self, out):
    urltool = getToolByName(self, 'portal_url')
    portal = urltool.getPortalObject()

### CONFIG root properties ###
    portal.title = PORTAL_TITLE
    portal.description = PORTAL_DESC
    portal.validate_email = PORTAL_CHECKMAIL
    portal.default_charset = PORTAL_CHARSET
    portal.enable_permalink = PORTAL_FIXLINK

    safeEditProperty(portal, 'default_page', PORTAL_DEFAULT_VIEW, 'string')

    ## left_slots
    # TODO save & restore old slots
    # old_left_slots = list(portal.left_slots)
    left_slots = PORTAL_LEFTSLOTS
    portal._updateProperty('left_slots', left_slots)

    ## right_slots
    # TODO save & restore old slots
    # old_right_slots = list(portal.right_slots)
    right_slots = PORTAL_RIGHTSLOTS
    portal._updateProperty('right_slots', right_slots)


### PORTAL PROPERTIES ###
    props = portal.portal_properties.site_properties

    #  visible_ids boolean true (short name)
    safeEditProperty(props, 'visible_ids', VISIBLE_IDS, 'boolean')

    # calendar_starting_year (2006)
    safeEditProperty(props, 'calendar_starting_year', CALENDAR_START, 'int')

    # allowRolesToAddKeywords lines Member
    addLinesToProperty(props, 'allowRolesToAddKeywords', 'Member')

    ## portal_properties/navtree_properties
    navprops = portal.portal_properties.navtree_properties
    navprops.manage_changeProperties(
            enable_wf_state_filtering=True,
            wf_states_to_show=['published', 'open'],
            topLevel=1,
            bottomLevel=4)
    addLinesToProperty(navprops, 'metaTypesNotToList', TYPESNOTTOLIST)


### PORTAL MEMBERSHIP ###
    membership = portal.portal_membership
    membership.setMemberAreaType('Weblog')

    type_tool = portal.portal_types
    member_folder = membership.getMembersFolder()
    mtype = member_folder.getPortalTypeName()
    cur_id = member_folder.getId()

    if cur_id != MEMBERS_FOLDER_ID:
        # hack to rename
        type_tool[mtype].global_allow = True
        #member_folder.manage_renameObjects(MEMBERS_FOLDER_ID, id=MEMBERS_FOLDER_ID, text=MEMBERS_FOLDER_DESC)
#        portal.manage_renameObjects([cur_id], [MEMBERS_FOLDER_ID])
        type_tool[mtype].global_allow = False
    
    member_folder.setTitle(MEMBERS_FOLDER_ID)
    member_folder.setDescription(MEMBERS_FOLDER_DESC)

#    membership.setMembersFolderById(MEMBERS_FOLDER_ID)

    # delete default index_html
    if 'index_html' in member_folder.objectIds():
        member_folder.manage_delObjects('index_html')
    member_folder.reindexObject()

    # change default view
    safeEditProperty(member_folder, 'default_page', MEMBER_DEFAULT_VIEW, 'string')

    # Set member Manage Portal permission on user home
    member_folder.manage_permission(ManagePortal, ['Manager', 'Owner'], acquire=False)
    member_folder.manage_permission(AddWeblogPerm, ['Manager'], acquire=False)
    #member_folder.manage_permission(AddContentPanelsPerm, ['Manager'], acquire=False)
    member_folder.manage_permission(AddGroupSpacePerm, ['Manager'], acquire=False)


    # set member folder slots
    safeEditProperty(member_folder, 'left_slots', ROOT_MEMBER_LEFTSLOTS, 'lines')
    safeEditProperty(member_folder, 'right_slots', ROOT_MEMBER_RIGHTSLOTS, 'lines')
    

### ADD USER GROUPS
    gtool = portal.portal_groups
    existing = gtool.listGroupIds()

    for grp in USERGROUPS:
        if  grp[0] not in existing:
            gtool.addGroup(grp[0],roles=grp[1])
            out.write("Added %s group to portal_groups with %s role.\n" % (grp[0], grp[1]))


### MISC settings
    # GrufSpaces - enable use_groupspace_areas
    portal.portal_properties.grufspaces_properties.use_groupspace_areas=1

    # close site - Disable Add portal member
    portal.manage_permission(AddPortalMember, ['Manager'], acquire=False)

    # Enable Reply to Item
    portal.manage_permission(ReplyToItem, ['Anonymous','Authenticated'], acquire=True)

    # KUPU enable linkbyuid
    kupuTool = getToolByName(self, 'kupu_library_tool')
    kupuTool.linkbyuid = True


def setupSkin (self, out):
    
    skinsTool = getToolByName(self, 'portal_skins')

    # Add directory views
    try:
        addDirectoryViews(skinsTool, 'skins', GLOBALS)
        #install_subskin(self, out, GLOBALS)
        out.write( "Added directory views to portal_skins.\n" )
    except:
        out.write( '*** Unable to add directory views to portal_skins.\n')

    for skin_name in SKIN_NAMES:
        path = skinsTool.getSkinPath(BASE_SKIN)
        path = map(string.strip, string.split(path,','))

        # add lib folder
        for lib_folder in LIB_FOLDERS:
            if lib_folder not in path:
                try:
                    path.insert(path.index('custom')+1, lib_folder)
                except:
                    path.append(lib_folder)

        # add skin folders to this path, under 'custom'
        try:
            path.insert(path.index('custom')+1, skin_name)
            path = string.join(path, ', ')
            skinsTool.addSkinSelection(skin_name, path)
        except:
            out.write('adding skin %s failed' % skin_name)
       
    # change default skin
    try:
        skinsTool.manage_properties(default_skin=DEFAULT_SKIN)
        out.write('switched default skin to %s \n' % DEFAULT_SKIN)
    except:
        out.write('failed to set default_skin to %s \n' % DEFAULT_SKIN)

def removeSkin (self, out):

    skinsTool = getToolByName(self, 'portal_skins')

    try:
        skinsTool.manage_properties(default_skin=BASE_SKIN)
        skinsTool.manage_skinLayers (del_skin = 1, chosen = SKIN_NAMES)
        out.write('removed %s skins \n' % ', '.join(SKIN_NAMES))
    except:
        out.write('removing skins %s failed \n' % ', '.join(SKIN_NAMES))

    out.write('Uninstalled succesfully\n')
       
def install (self):
    out = StringIO ()

    setupSkin (self, out)

    installDepend(self, out)
    
    # initilize portal config
    init_portal(self, out)

    # create custom contents
    # smart folders, workspace, software center, import content panel
    setupPortalContent(self, out)
    # create_tabs(self)

    # portal post configuration 
    configOrder(self, out)
    updateGrufWorkflow(self, out)
    updateCatalog(self)

    out.write ('Installation completed.')
    return out.getvalue()

def uninstall (self):
    out = StringIO ()

    removeSkin (self, out)
    out.write ('Uninstallation completed.')
    return out.getvalue()

def create_tabs(self):
    pa = getToolByName(self,'portal_actions')

    for action in TABS:
        pa.addAction(action[0], action[1], action[2], '', 'View', 'portal_tabs', 1)

#def afterInstall(self, reinstall, product):
#    out = StringIO ()
#
#    init_portal(self, out)
#    configOrder(self, out)
#    updateCatalog(self)
#
#    out.write ('Custom AfterInstall completed.')
#
#    return out

