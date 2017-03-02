## Script (Python) "getObjByUid"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=uid
##title=get list of smart folders
##

ref_tool = context.reference_catalog
obj = ref_tool.lookupObject(uid);

return obj
