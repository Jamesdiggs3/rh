" post blog entry to Drupal site
" Use :e blog/nodeID_which_are_digits to open an existing entry for editing;
"     For example :e blog/12
" Use :e blog/anything_other_than_digits to open a new entry for editing
"     For example :e blog/blah
" Use :w or :PublishPost to post it. 
" Use :SavePost to save your post to drupal without promoting it to the front page.
" Use :w blog/anything to post a file as a new blog entry
"
" Use :ListPosts <n> to obtain a simple browser of the n most recent posts (default: 10)

python << EOF

strUserName = 'username'
strPassword = 'password'
strDrupal = 'http://your.drupalsite.com'
useinlinetags = True

import vim
import xmlrpclib
import re
import os.path
import base64
import urllib
import string

def normal(str):
  vim.command("normal "+str)

def DeleteBlog(strID):
  strID = str(strID)
  oDrupal = xmlrpclib.ServerProxy( strDrupal + '/xmlrpc.php', )
  bSuccess = oDrupal.blogger.deletePost( 'test', strID, strUserName, strPassword, True )
  GetPosts(10)
  print "Deleted entry %s" % strID

def PostBlog(publish):

  #
  # If first line contains a blog entry ID then edit existing post,
  # otherwise write a new one.
  #
  vim.command( 'set modifiable')
  vim.command('map e e')
  vim.command('map n n')
  vim.command('map D D')

  nFirstLine = 0
  strID = vim.current.buffer[0]
  if not re.match( '^\d+$', strID):
    strID = ''
  else:
    nFirstLine = 1

  strTitle = vim.current.buffer[nFirstLine]
  # this is kinda hacky - but necessitated by the fact that drupal won't tell us if a post
  # is published
  if publish:
    if strTitle.endswith("[draft]"):
      strTitle = strTitle[0:-7] #x
  else:
    if not strTitle.endswith("[draft]"):
      if strTitle.endswith(" "):
        strTitle += '[draft]'
      else:
        strTitle += ' [draft]'

  strText = "\n".join( vim.current.buffer[nFirstLine+1:])

  oDrupal = xmlrpclib.ServerProxy( strDrupal + '/xmlrpc.php')

  oPost = { 'title': strTitle, 'description': strText}

  if strID == '':
    strID = oDrupal.metaWeblog.newPost( 'blog', strUserName, strPassword, oPost, publish)
  else:
    bSuccess = oDrupal.metaWeblog.editPost( strID, strUserName, strPassword, oPost, publish)
  # if (strVid != 0) and strTags:
    # bSuccess1 = oDrupal.drupalapi.freeTag( strID, strUserName, strPassword, strTags, strVid )

  GetPosts(10)
  if publish:
    print "Posted entry %s" % strID
  else:
    print "Saved draft %s" % strID

  #
  # Don't intend to write posts to disk so unmodify the buffer and
  # allow easy quit from VIM.
  #
  vim.command( 'set nomodified')

def ReadBlog( strID ):
  
  #
  # So html plugin is automatically enabled for editing the post 
  # with auto-completion and syntax highlighting
  #
  vim.command( 'set modifiable')
  vim.command('setfiletype html')
  vim.command('map e e')
  vim.command('map n n')
  vim.command('map D D')

  if not strID.isdigit():
    print "New blog entry"
    vim.current.buffer[:] = None
    if useinlinetags:
    vim.current.buffer.append( '[tags][/tags]' )
    return

  oDrupal = xmlrpclib.ServerProxy( strDrupal + '/xmlrpc.php')

  oBlog = oDrupal.metaWeblog.getPost( strID, strUserName, strPassword )

  if useinlinetags:
    oPostTags = oDrupal.mt.getPostCategories( strID, strUserName, strPassword )
    tags = '[tags]'
    # print repr(oPostTags)
    for tag in oPostTags:
      tags += tag['categoryName'] + ','
    tags += '[/tags]'

  #print repr(oBlog)
  #print repr(oTerms)
  #print repr(oPostTags)
  if oBlog['title'].endswith("[draft]"):
    oBlog['title'] = oBlog['title'][0:-7] #x

  vim.current.buffer[:] = []
  vim.current.buffer[0] = strID
  vim.current.buffer.append( oBlog['title'])

  if useinlinetags:
    vim.current.buffer.append( tags )

  for strLine in oBlog['description'].split('\n'):
    # vim chokes on unicode strings
    vim.current.buffer.append( strLine.encode('latin-1', 'replace') )

def GetPosts(intNUM = 10):

  vim.command( 'map <silent> e :call EditPost()<CR>' )
  vim.command( 'map <silent> D :call DeletePost()<CR>' )
  vim.command( 'map <silent> n :e blog/new<CR>' )
  vim.command( 'set modifiable')
  vim.command( 'set syntax=netrw')

  #print(repr(intNUM))

  oDrupal = xmlrpclib.ServerProxy( strDrupal + '/xmlrpc.php')

  oBlog = oDrupal.metaWeblog.getRecentPosts( 'blog', strUserName, strPassword, intNUM )

  title = 'Displaying the ' + str(intNUM) + ' most recent posts:'

  vim.current.buffer[:] = []
  vim.current.buffer[0] = '"==========================================================================='
  vim.current.buffer.append( '" ' + title )
  vim.current.buffer.append( '" press "e" to edit the post under the cursor' )
  vim.current.buffer.append( '" press "D" to (permanently!) delete the post under the cursor' )
  vim.current.buffer.append( '" press "n" to create a new post' )
  vim.current.buffer.append( '"===========================================================================' )
  vim.current.buffer.append( '' )

  #print repr(oBlog)
  for post in oBlog:
    vim.current.buffer.append( post['postid'] + ': ' + post['title'] )

  vim.command('set modifiable!')
  vim.command('8')
  vim.command( 'set nomodified')

def UploadFile(strFileName, strType):
  
  if os.path.isfile(strFileName):
    import base64
    FileSize = os.path.getsize(strFileName)
    File = open(strFileName,'r')
    EncodedFile = base64.encodestring(File.read())
    Filedict = {'name': strFileName, 'bits': EncodedFile}
    #print repr(Filedict)
    #infoString = '"Uploaded file ' + strFileName + ' (' + str(FileSize) + ' bytes)..."'
    oDrupal = xmlrpclib.ServerProxy( strDrupal + '/xmlrpc.php')
    oFile = oDrupal.metaWeblog.newMediaObject( 'blog', strUserName, strPassword, Filedict)
    if (strType == 'file'):
      insertStr = 'a<a href="' + string.replace(oFile['url'], '"', '%22') + '"></a>4h'
      oFile = oDrupal.metaWeblog.newMediaObject( 'blog', strUserName, strPassword, Filedict)
    if (strType == 'img'):
      insertStr = 'a<img src="' + string.replace(oFile['url'], '"', '%22') + '"></img>6h>'
      oFile = oDrupal.metaWeblog.newMediaObject( 'image', strUserName, strPassword, Filedict)
    #print repr(oFile['url'])
    #print repr(insertStr)
    #vim.current.range.append(insertStr)
    normal(insertStr)
    if oFile:
      print 'Upload of ' + strFileName + ' succeeded!'
      return 0
    else:
      print 'Upload of ' + strFileName + ' failed!'
      return 1
    #print repr(oFile)
  else:
    print strFileName
    print "invalid file name!"

EOF

" Edit Post under cursor
function! EditPost()
  let str=getline(".")
  if strlen(str)==0 || line(".") < 3
    echo "Cannot edit this post!"
    return ""
  else
    let tokens = split( str, ':' )
    execute 'e ' . 'blog/' . tokens[0]
  endif
endfunction

" Delete Post under cursor
function! DeletePost()
  let str=getline(".")
  if strlen(str)==0 || line(".") < 3
    echo "Cannot delete this post!"
    return ""
  else
    let tokens = split( str, ':' )
    execute 'py DeleteBlog(' . tokens[0] . ')'
  endif
endfunction

" Upload regular file
function! UploadFile(uploadfile)
  if filereadable(a:uploadfile)
    let fsize=getfsize(a:uploadfile)
    echomsg 'Attempting to upload file:' a:uploadfile '(' fsize 'bytes )'
  else
    echo 'Could not read' a:uploadfile '!'
  endif
endfunction


:au BufWriteCmd blog/* py PostBlog(True) 
:au BufReadCmd blog/* py ReadBlog(vim.eval("expand('<afile>:t')"))
:command -nargs=0 PublishPost :py PostBlog(True)
:command -nargs=0 SavePost :py PostBlog(False)
:command -nargs=? ListPosts :py GetPosts(<args>)
:command -nargs=1 -complete=file UploadFile :call UploadFile(<f-args>) | :py UploadFile(<f-args>, 'file')
:command -nargs=1 -complete=file UploadImage :py UploadFile(<f-args>, 'img')
