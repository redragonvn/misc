#
# makeAccounts.py
#
# simple script to be invoked via
#
#  cd $INSTANCEHOME
#  bin/zopectl run <path/to/>makeAccounts.py [site_id, [source_file_path]]
#
#  reads account data from a csv-like file
#  expects three values per line (user_id, fullname, email) like
#
#      joe, Joe User, joe@user.com
#
#  (sample in ResearchCommunitySite/lib/data/sample_account_data.txt)
#  generates random passwords 
#  creates member area for each new user
#  does nothing if a user with the given user_id already exists
#

##### config the following to fit your needs if not passing command line args

# Set SITE_ID to the Plone site's id you want to add the users to.
# This will be overwritten if a first command line argument is provided.

SITE_ID = 'plone'

# Change DATA_SOURCE_FILE to point to your data source file.
# This will be overwritten if a second command line argument is provided.

DATA_SOURCE_FILE = '/path/to/data/file'

##### end of config

from AccessControl.SecurityManagement import newSecurityManager
import sys
try:
    site_id = sys.argv[1]
except IndexError:
    site_id = SITE_ID
try:
    input_path = sys.argv[2]
except IndexError:
    input_path = DATA_SOURCE_FILE

# ugly hack to satisfy the translation service
from Testing.ZopeTestCase.utils import makerequest
app = makerequest(app)


data = open(input_path, 'r')
site = app[site_id]
registration_tool = site.portal_registration
membership_tool = site.portal_membership

print "Adding members from '%s'." % input_path
for line in data.readlines():
    # ignore empty lines and comments
    if not line.strip() or line.startswith('#'):
        continue
    try:
        id, fullname, email = line.split(',')
    except ValueError, message:
        print "Cannot parse line '%s'; ignoring it." % line.strip()
        print message
        continue
    id = id.strip()
    fullname = fullname.strip()
    email = email.strip()
    properties = {'username':id,
                  'email':email,
                  'fullname':fullname,
                  }
    pw = registration_tool.generatePassword()
    try:
        registration_tool.addMember(id, pw, properties=properties)
    except ValueError, message:
        print "Adding %s (%s) failed." % (id, fullname)
        print message
        continue
    user = site.acl_users.getUserById(id)
    user = user.__of__(site.acl_users)
    newSecurityManager(None, user)
    membership_tool.createMemberarea()
    print "Added %s (%s)." % (id, fullname)

data.close()
import transaction
transaction.commit()
print "Done."

