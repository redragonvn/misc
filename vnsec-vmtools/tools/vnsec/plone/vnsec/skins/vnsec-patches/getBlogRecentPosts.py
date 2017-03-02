## Script (Python) "getBlogRecentPosts"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=
##title=get recent weblog posts
##

weblog = context.quills_tool.getParentWeblog(context)

path = '/'.join(weblog.getPhysicalPath())

results = context.portal_catalog.searchResults(
        meta_type=['WeblogEntry',],
        path={'query':path, 'level': 0},
        review_state='published',
        sort_on = 'effective',
        sort_order = 'reverse')

return results

