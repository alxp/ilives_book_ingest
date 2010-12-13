import os, sys, xml.dom.minidom
from xml.dom.minidom import parse, parseString
from unicode_support import safe_unicode, safe_str, write_unicode_to_file

def replace_node( a_dom, tag, new_text ):
    new_node = a_dom.createTextNode( new_text )
    element = a_dom.getElementsByTagName( tag )[0]
    old_node = element.childNodes[0]
    element.replaceChild( new_node, old_node )
    return new_node

book_dc = sys.argv[1]
pid = sys.argv[2]
img_dc = sys.argv[3]

bookpid = pid.split('-')[0]

pageType = pid.split('-')[1][0] # f front matter p page z back matter

pageNumber = pid.split('_')[1]

pageTypes = {'f':'Front Matter',
             'p':'Page',
             'z':'Back Matter'}

figureNum = pid.split('-')[2][3]
figureType = pid.split('-')[2][4]

figureTypes = {'p':'Photograph',
               'i':'Illustration',
               'm':'Map',
               'd':'Document',
               'n':'Newspaper Item',
               'f':'Family Tree',
               'a':'Advertisement'}

typeOfResource = {'p':'still image',
                  'i':'still image',
                  'm':'cartographic',
                  'd':'text',
                  'n':'text',
                  'f':'text',
                  'a':'still image'}


dcdom = parse(book_dc)

replace_node( dcdom, 'dc:type', 'image' )

dc_title = dcdom.getElementsByTagName('dc:title')
old_title = dc_title[0].childNodes[0]

new_title = figureTypes[figureType] + ' ' + figureNum + ' - ' + pageTypes[pageType] + ' ' + str(int(pageNumber[0:3])) + ' - ' + old_title.toxml()
write_unicode_to_file( os.path.dirname(img_dc) + '/label.txt', new_title)
replace_node( dcdom, 'dc:title',  new_title)
replace_node( dcdom, 'dc:identifier', pid )
replace_node( dcdom, 'dc:format', 'electronic' )

extra_format_nodes = dcdom.getElementsByTagName( 'dc:format' )
extra_format_nodes.pop(0) # Keep first element that we just changed.
for x in extra_format_nodes:
    x.parentNode.removeChild(x)

#dcdom.writexml(open(img_dc, 'w'))
write_unicode_to_file(img_dc, dcdom.toxml())
