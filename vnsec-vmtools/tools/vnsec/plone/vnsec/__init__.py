from Globals import package_home
from Products.Archetypes.public import process_types, listTypes
from Products.CMFCore import utils
from Products.CMFCore import CMFCorePermissions
from Products.CMFCore.CMFCorePermissions import AddPortalContent
from Products.CMFCore.DirectoryView import registerDirectory
import os, os.path

from config import SKINS_DIR, GLOBALS, PROJECTNAME

skin_globals=globals()
registerDirectory(SKINS_DIR, skin_globals)

def initialize(context):

    content_types, constructors, ftis = process_types(
                                 listTypes(PROJECTNAME), PROJECTNAME)

    utils.ContentInit(
         PROJECTNAME + ' Content',
         content_types = content_types,
         permission         = AddPortalContent,
         extra_constructors = constructors,
         fti = ftis,
         ).initialize(context)

