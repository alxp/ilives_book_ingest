from xml.dom.minidom import parse, parseString
import sys
from unicode_support import safe_unicode, safe_str, write_unicode_to_file

book_mods = sys.argv[1]
pid = sys.argv[2]
outputFile = sys.argv[3]

bookpid = pid.split('-')[0]

pageType = pid.split('-')[1][0]

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

modsdom = parse(book_mods)

part = modsdom.createElement('part')

detail = modsdom.createElement('detail')
detail.setAttribute('type', typeOfResource[figureType])
part.appendChild(detail)

caption = modsdom.createElement('caption')
captionText = modsdom.createTextNode(figureTypes[figureType])
caption.appendChild(captionText)

modsdom.childNodes[0].appendChild(part)

# Remove book's physical description elements.
phys = modsdom.getElementsByTagName('physicalDescription')
for x in phys:
    modsdom.childNodes[0].removeChild(x)

physicalDescriptionXML =    ''' <physicalDescription>
        <internetMediaType>image/jpg</internetMediaType>
        <digitalOrigin>reformatted digital</digitalOrigin>
    </physicalDescription>'''

physicalDescription = parseString(physicalDescriptionXML)
physicalDescriptionNode = modsdom.importNode(physicalDescription.childNodes[0], True)
modsdom.childNodes[0].appendChild(physicalDescriptionNode)

identifier = modsdom.createElement('identifier')
identifierText = modsdom.createTextNode(pid)
identifier.appendChild(identifierText)
identifier.setAttribute('type', 'fedora')

modsdom.childNodes[0].appendChild(identifier)


locationXML = '''    <location>
        <physicalLocation>University of Prince Edward Island, Robertson Library (Charlottetown,PE)
        </physicalLocation>
    </location>'''

location = parseString(locationXML)
locationNode = modsdom.importNode(location.childNodes[0],True)
modsdom.childNodes[0].appendChild(locationNode)


accessXML = '''    <accessCondition type="useAndReproduction"> Use of this resource is governed by the Canadian
        Copyright Act. Unless otherwise noted you must contact the right&apos;s holder(s) for permission
        to publish or reproduce this resource.
    </accessCondition>'''
access = parseString(accessXML)
accessNode = modsdom.importNode(access.childNodes[0],True)
modsdom.childNodes[0].appendChild(accessNode)
#dom1.writexml(open(outputFile, 'w'),encoding="iso9660-1")
write_unicode_to_file(outputFile, modsdom.toxml())
