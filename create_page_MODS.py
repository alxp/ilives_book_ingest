from xml.dom.minidom import parse, parseString
import sys, re
from unicode_support import safe_unicode, safe_str, write_unicode_to_file 

book_mods = sys.argv[1]
pid = sys.argv[2]
outputFile = sys.argv[3]

dom1 = parse(book_mods)

bookpid = pid.split('-')[0]

#pageType = pid.split('-')[1][0] # f front matter p page z back matter
pageType = re.findall(r'\-.\_', pid)[0][1]

pageNumber = re.findall(r'\-.\_....', pid)[0][3:7]
part = dom1.createElement('part')
detail = dom1.createElement('detail')
part.appendChild(detail)
detail.setAttribute('type', 'page')

pageTypes = {'f':'Front Matter',
             'p':'Page',
             'z':'Back Matter'}

caption = dom1.createElement('caption')
detail.appendChild(caption)

captionText = dom1.createTextNode(pageTypes[pageType] + ' ' + str(int(pageNumber[0:3])))

caption.appendChild(captionText)
number = dom1.createElement('number')
detail.appendChild(number)

numberText = dom1.createTextNode(pageNumber)
number.appendChild(numberText)
dom1.childNodes[0].appendChild(part)

phys = dom1.getElementsByTagName('physicalDescription')
for x in phys:
    try:
        dom1.childNodes[0].removeChild(x)
    except:
        print "No physical description"


physicalDescriptionXML = '''<physicalDescription><form authority="marcform">electronic</form><form authority="marcform">print</form><internetMediaType>image/jp2</internetMediaType><internetMediaType>text/xml</internetMediaType><extent>1 p.</extent><digitalOrigin>reformatted digital</digitalOrigin></physicalDescription>'''

physicalDescription = parseString(physicalDescriptionXML)
physicalDescriptionNode = dom1.importNode(physicalDescription.childNodes[0],True)
dom1.childNodes[0].appendChild(physicalDescriptionNode)

identifier = dom1.createElement('identifier')
identifierText = dom1.createTextNode(pid)
identifier.appendChild(identifierText)
identifier.setAttribute('type', 'fedora')
dom1.childNodes[0].appendChild(identifier)

locationXML = '''    <location>
        <physicalLocation>University of Prince Edward Island, Robertson Library (Charlottetown,PE)
        </physicalLocation>
    </location>'''

location = parseString(locationXML)
locationNode = dom1.importNode(location.childNodes[0],True)
dom1.childNodes[0].appendChild(locationNode)


accessXML = '''    <accessCondition type="useAndReproduction"> Use of this resource is governed by the Canadian
        Copyright Act. Unless otherwise noted you must contact the right&apos;s holder(s) for permission
        to publish or reproduce this resource.
    </accessCondition>'''
access = parseString(accessXML)
accessNode = dom1.importNode(access.childNodes[0],True)
dom1.childNodes[0].appendChild(accessNode)
#dom1.writexml(open(outputFile, 'w'),encoding="iso9660-1")
#outfile = open( outputFile, 'w')
#outfile.write(str(dom1.toxml()))
write_unicode_to_file(outputFile, dom1.toxml())

