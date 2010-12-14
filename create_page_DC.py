import os, sys, xml.dom.minidom, re
from xml.dom.minidom import parse, parseString
from unicode_support import safe_unicode, safe_str, write_unicode_to_file

def replace_node( a_dom, tag, new_text ):
    new_node = a_dom.createTextNode( new_text )
    try:
        element = a_dom.getElementsByTagName( tag )[0]
    except:
        return new_node
    old_node = element.childNodes[0]
    element.replaceChild( new_node, old_node )
    return new_node

book_dc = sys.argv[1]
pid = sys.argv[2]
page_dc = sys.argv[3]

bookpid = pid.split('-')[0]

pageType = re.findall(r'\-.\_', pid)[0][1] # f front matter p page z back matter

pageNumber = re.findall(r'\-.\_....', pid)[0][3:7]

pageTypes = {'f':'Front Matter',
             'p':'Page',
             'z':'Back Matter'}

dcdom = parse(book_dc)

replace_node( dcdom, 'dc:type', 'text' )

dc_title = dcdom.getElementsByTagName('dc:title')
old_title = dc_title[0].childNodes[0]
new_title = pageTypes[pageType] + ' ' + str(int(pageNumber[0:3])) + ' - ' + old_title.toxml()
write_unicode_to_file(os.path.dirname(page_dc) + '/label.txt', new_title)

extra_type_nodes = dcdom.getElementsByTagName('dc:type')
if len(extra_type_nodes) > 0:
    extra_type_nodes.pop(0) # Keep first element that we just changed.
for x in extra_type_nodes:
	x.parentNode.removeChild(x)

replace_node( dcdom, 'dc:title',  new_title)
replace_node( dcdom, 'dc:identifier', pid )
replace_node( dcdom, 'dc:format', 'electronic' )

extra_format_nodes = dcdom.getElementsByTagName( 'dc:format' )
if len(extra_format_nodes) > 0:
    extra_format_nodes.pop(0) # Keep first element that we just changed.
for x in extra_format_nodes:
    x.parentNode.removeChild(x)

extra_text_nodes = dcdom.getElementsByTagName( 'dc:type' )
if len(extra_text_nodes) > 0:
    extra_text_nodes.pop(0) # Keep first element that we just changed.
for x in extra_text_nodes:
    x.parentNode.removeChild(x)


#dcdom.writexml(open(page_dc, 'w'))
write_unicode_to_file(page_dc, dcdom.toxml())
