## Script (Python) "getTopicsList"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=
##title=get list of smart folders
##

uid_catalog = context.uid_catalog
url_tool = context.portal_url
portal_base = url_tool.getPortalPath()
prefix_length = len(portal_base)+1

def get_uid(brain):
    '''Get information from a brain'''
    id = brain.getId

    # Path for the uid catalog doesn't have the leading '/'
    path = brain.getPath()
    UID = None
    if path and uid_catalog:
        try:
            metadata = uid_catalog.getMetadataForUID(path[prefix_length:])
        except KeyError:
            metadata = None
        if metadata:
            UID = metadata.get('UID', None)

    return UID


catalog = context.portal_catalog
rootpath = '/'.join(context.getPhysicalPath())

listTypes = ('Topic', )
listStates = ('published','visible')

query = {}

if listTypes:
    query['portal_type'] = listTypes
if listStates:
    query['review_state']=listStates

rawresults = catalog(**query)
results = []

for item in rawresults:
    results.append([get_uid(item), item.Title])

return results

