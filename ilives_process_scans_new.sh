#!/bin/sh

# This script is invoked by the Queue Server in response to a scan job processing request

# get the logging scripts

. ilives_logging.sh

# set up environment and server urls

. ilives_environment_new.sh

#############################################################################
#		Check input parameters												#
#############################################################################
export bibnum=$1
export book_pid=$2
export queueid=ilives
# Log the start of scan processing
log_starting_message $queueid "starting scan processing"

#############################################################################
#		Is Fedora server avalable?											#
#############################################################################
wget --timeout=4 --tries=2 -o /tmp/$$-wget.log -O /tmp/$$-wget.out $FEDORA_URL"search"
if [ $? != 0 ] ; then fatal_error $queueid "$FEDORA_URL not available"; exit; fi

#############################################################################
#		Are bib numbers good?												#
#############################################################################

#wget --timeout=4 --tries=2 -o /tmp/$$-wget.log -O - "$ISLANDPINES_PREFIX"$bibnum"$ISLANDPINES_SUFFIX"
#RECORD_FOUND=$?
#if [ "$RECORD_FOUND" != 0 ] ; then fatal_error $queueid "record $bibnum count = $bibnum_count"; exit; fi

#############################################################################
#		Form working directory structure									#
#############################################################################

# add appropriate number of leading zeros
logid=$bibnum"-"$jobid"-"$scanid

#storage_path="$ILIVESROOT"/"$bibnum"

# Check if book dir exists in permanent storage, exit otherwise.
if [ -d $STORAGEROOT/$bibnum ]; then
	mkdir $ILIVESROOT"/"$bibnum
else
	fatal_error $queueid "Book files do not exist in permanent storage in $STORAGEROOT"
	exit 1
fi

#############################################################################
#		Create local working directories									#
#############################################################################

bookdir=$ILIVESROOT"/"$bibnum
abbyyxmldir="$bookdir/xml"
pdfdir="$bookdir/pdf"
ocrtxtdir="$bookdir/txt"
tiffdir="$bookdir/processed"
mkdir $tiffdir
mkdir $tiffdir/figures
coverdir=$bookdir/cover
logdir=$ILIVESROOT"/logs/"`date +"%Y"`
echo $logdir
cd $bookdir

mkdir -p $logdir

logfile=$logdir"/ilives.log"

# At this point we start with a directory structure like
# $bookdir/
# $bookdir/processed   -- contains tiff files

echo -e $logid "\t" `date` "\tTransferring files to working directory" >> $logfile

cp -R $STORAGEROOT/$bibnum/processed/*.tif $tiffdir
cp -R $STORAGEROOT/$bibnum/processed/figures/* $tiffdir/figures
if [[ $? != 0 ]] ; then
	fatal_error $bibnum Error copying files from storage to working directory
fi
mkdir $bookdir/cover
cp $STORAGEROOT/$bibnum/cover/*frontcover.jpg $bookdir/cover/"cover.jpg"

#rm -fr $bookdir
#mkdir -p $bookdir
mkdir -p $abbyyxmldir
mkdir -p $ocrtxtdir
mkdir -p $pdfdir
#mkdir -p 

echo -e $logid "\t" `date` "\tCreating JPEG2000 files from TIFFs" >> $logfile

cd $bookdir
for i in `find processed -name "*cover.[Tt][Ii][Ff]"`; do
  bn=`basename $i -cover.tif`
  mv $i processed/$bn".tif"
done

for i in processed/*.[Tt][Ii][Ff]; do
	bn=`basename $i .tif`
	bn=`basename $bn .TIF`
	mkdir -p $bn
	kdu_compress -i $i -o $bn/$bn.jp2 Creversible=yes -rate -,1,0.5,0.25 Clevels=6
	convert -size 400x400  $i -thumbnail 120x120   -unsharp 0x.5  $bn/${bn}_TN.jpg
	# Copy figures into subfolder inside the page it appears on.
	cp processed/figures/$bn* $bn
done

# Perform ABBYY OCR

echo -e $logid "\t" `date` "\tPerforming OCR with ABBYY." >>$logfile

pushd $ABBYYCLI
#CLI -ics $imageList -f PDF -pem ImageOnText -pfpf Automatic -pfq 85 -pfpr 150 -of "/usr/local/fedora/abbyy/${image%.*}.pdf"

imagelist=" "
for image in `find $bookdir/processed -name "*.[tT][iI][fF]" | sort`; do
	imagelist="$imagelist -if $image"; 
done

./CLI -ics $imagelist \
-f PDF -pem ImageOnText -pfpf Automatic -pfq 90 -pfpr 150  -of "$bookdir/pdf/$bibnum.pdf" \
-f XML -xaca -of "$bookdir/xml/$bibnum.xml" \
-f Text -tel -tpb -tet UTF8 -of "$bookdir/txt/$bibnum.txt"

popd

#############################################################################
#		Perform the TEI encoding.								            #
#############################################################################

pushd $GATEHOME

cp $bookdir/xml/$bibnum.xml ../../XML
./BatchProcess.sh $bibnum
cp ../../XML/$bibnum/*.[xk]ml $bookdir/xml

# Compile a list of TEI page files.
cd ../../XML/$bibnum/pages
teidir=`pwd`
pagecounter=0

for teipagefile in `find . -name "*.xml" -exec echo $teidir/{} \; |sort `
do
  teipagelist[$pagecounter]=$teipagefile
  pagecounter=$((pagecounter+1))
done


popd

pagecounter=0
#for pagedir in `find . \( -name "*-?_????" -o  -name "*-?_????-*" \) -exec echo $bookdir/{} \; |sort`; do
for pagedir in `tree -id |grep "\-.\_...."`; do
  imgpagelist[$pagecounter]=$pagedir
  cp ${teipagelist[$pagecounter]} $pagedir
  pagecounter=$((pagecounter+1))
done


# Extract JHOve data from JP2 files.

#for i in $bibnum-*; do
#  java -jar /opt/jhove/bin/JhoveApp.jar -c /opt/jhove/conf/jhove.conf -h xml $i/$i.jp2 -o $i/$i-jhove.xml
#  java org.apache.xalan.xslt.Process -IN $i/$i-jhove.xml -XSL $MNTBHOME/scripts/jhove2mix.xsl -OUT $i/$i.mix
#done

#############################################################################
#		Perform Fedora ingests												#
#############################################################################
# form pid
if [ -z "$book_pid" ]; then  
    book_pid=$PID_NAMESPACE":"$bibnum 
fi

log_processing_message $queueid "checking for book object $book_pid"

# See if we already have the book object 
#############################################################################
#		Ingest book object if not already there								#
#############################################################################
wget --timeout=4 --tries=2 -o /tmp/$$-wget.log -O /tmp/$$-wget.out $FEDORA_URL"/search?query=pid~"$book_pid"&pid=true&maxResults=10&xml=true" >>$logfile 2>&1
if [ $? != 0 ] ; then fatal_error $queueid "search of  $FEDORA_URL failed"; exit; fi
log_processing_message $queueid "Ingesting book datastreams for $book_pid"
if test `cat  /tmp/$$-wget.out | grep $book_pid | wc -l` -eq 0 ;
then
	fatal_error $queueid "Book $bookid does not exist in Fedora."	
else
	log_processing_message $queueid "Adding datastreams to $book_pid"
#	python $MNTBHOME/scripts/fix_book_TEI.py xml/$i.TEI.annotated.xml

	echo '<?xml version="1.0" encoding="utf-8"?>' >ingest_book_purge.xml
	echo '<fbm:batchModify xmlns:fbm="http://www.fedora.info/definitions/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/ http://www.fedora.info/definitions/1/0/api/batchModify.xsd">' >>ingest_book_purge.xml
	echo '  <fbm:purgeDatastream pid="'$book_pid'" dsID="TN" logMessage="BatchModify - purgeDatastream TN"/>' >>ingest_book_purge.xml
	echo '</fbm:batchModify>' >>ingest_book_purge.xml


	# Construct fedora modify object XML file.
	echo '<?xml version="1.0" encoding="utf-8"?>' >ingest_book.xml
	echo '<fbm:batchModify xmlns:fbm="http://www.fedora.info/definitions/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/ http://www.fedora.info/definitions/1/0/api/batchModify.xsd">' >>ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="PDF" dsLabel="Full_Text.pdf" dsMIME="application/pdf" dsLocation="'$DS_LOCATION$bibnum/pdf/$bibnum'.pdf" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream PDF"/>' >>ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="TN" dsLabel="MEDIUM" dsMIME="image/jpg" dsLocation="'$DS_LOCATION$bibnum'/cover/cover.jpg" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream TN"/>' >>ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="OCR" dsLabel="OCR_Text.txt" dsMIME="text/plain" dsLocation="'$DS_LOCATION$bibnum/txt/$bibnum'.txt" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream TXT"/>' >>ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="ABBYY" dsLabel="ABBYY_XML.xml" dsMIME="text/xml" dsLocation="'$DS_LOCATION$bibnum/xml/$bibnum'.xml" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream XML"/>' >>ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="TEI" dsLabel="Annotated_TEI.xml" dsMIME="text/xml" dsLocation="'$DS_LOCATION$bibnum/xml/$bibnum'.TEI.annotated.xml" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream TEI">' >>ingest_book.xml
	echo '  </fbm:addDatastream>' >> ingest_book.xml
	echo '  <fbm:addDatastream pid="'$book_pid'" dsID="KML" dsLabel="KML_Location_Data.kml" dsMIME="text/xml" dsLocation="'$DS_LOCATION$bibnum/xml/$bibnum'.kml" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream KML"/>' >>ingest_book.xml
	echo '</fbm:batchModify>' >>ingest_book.xml
	
fi
rm -f /tmp/$$-wget.log

if $FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password ingest_book_purge.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http validate-only=false | grep [1-9].*failed ; then
#	fatal_error $queueid "Batch modify of book record failed. See $ILIVESROOT/logs/book_ingest_$bibnum.log"	
#	exit 1
echo sad face
else
	log_processing_message $queueid "Successfully added book datastreams."
fi

if $FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password ingest_book.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http validate-only=false | grep [1-9].*failed ; then
#	fatal_error $queueid "Batch modify of book record failed. See $ILIVESROOT/logs/book_ingest_$bibnum.log"	
#	exit 1
echo sad face
else
	log_processing_message $queueid "Successfully added book datastreams."
fi

#############################################################################
#		Generate page foxml, dc, mods, mix, svg, and html					#
#############################################################################
# generate foxml
log_processing_message $queueid "creating page objects"

# Get the MODS and Dublin Core records from the book object

wget --timeout=4 --tries=2 -o /tmp/$$-wget.log -O ${bibnum}_MODS.xml $FEDORA_URL"get/"$book_pid"/MODS" >>$logfile 2>&1
wget --timeout=4 --tries=2 -o /tmp/$$-wget.log -O ${bibnum}_DC.xml $FEDORA_URL"get/"$book_pid"/DC" >>$logfile 2>&1

#if [[$? != 0]]; then
#	fatal_error $queueid "Failed to retrieve MODS record for $bibnum."
#	exit 1
#fi

for i in `tree -id |grep "\-.\_...."`; do
  # Construct the page MODS.
  page_pid=$book_pid-$i
  python $MNTBHOME/scripts/create_page_MODS.py ${bibnum}_MODS.xml $page_pid $i/${i}_MODS.xml
  python $MNTBHOME/scripts/create_page_DC.py ${bibnum}_DC.xml $page_pid $i/${i}_DC.xml

  # Create the RELS-EXT
  echo '<rdf:RDF xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">' > $i/${i}_RELS-EXT.xml
  echo '      <rdf:description rdf:about="info:fedora/'$page_pid'">' >> $i/${i}_RELS-EXT.xml
  echo '        <fedora:isMemberOf rdf:resource="info:fedora/'$book_pid'"></fedora:isMemberOf>' >> $i/${i}_RELS-EXT.xml
  echo '        <fedora-model:hasModel rdf:resource="info:fedora/ilives:pageCModel"></fedora-model:hasModel>' >> $i/${i}_RELS-EXT.xml
  echo '      </rdf:description>' >> $i/${i}_RELS-EXT.xml
  echo '    </rdf:RDF>' >> $i/${i}_RELS-EXT.xml
	
	# Create the batch modify script	
  echo '<?xml version="1.0" encoding="utf-8"?>' >ingest_page_$i.xml
  echo '<fbm:batchModify xmlns:fbm="http://www.fedora.info/definitions/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/ http://www.fedora.info/definitions/1/0/api/batchModify.xsd">' >>ingest_page_$i.xml
  echo '<fbm:addObject pid="'$page_pid'" label="'`head -c 255 $i/label.txt`'" contentModel="ilives:pageCModel" logMessage="BatchModify - Add page object"/>' >>ingest_page_$i.xml
# 	
  pagetei=`ls $i/*-*[0-9][0-9][0-9][0-9].xml`
  echo '  <fbm:addDatastream pid="'$page_pid'" dsID="TEI" dsLabel="TEI Page Fragment" dsMIME="text/xml" dsControlGroupType="X" dsState="A" logMessage="BatchModify - addDatastream Page TEI">' >>ingest_page_$i.xml
  echo '     <fbm:xmlData>' >> ingest_page_$i.xml
  sed -e '1d' -e 's/xmlns:gate="http:\/\/www.gate.ac.uk" xmlns:tei="http:\/\/www.tei-c.org\/ns\/1.0"//g' $pagetei >>ingest_page_$i.xml
  echo '     </fbm:xmlData>' >> ingest_page_$i.xml
  echo '  </fbm:addDatastream>' >> ingest_page_$i.xml
  echo '  <fbm:addDatastream pid="'$page_pid'" dsID="MODS" dsLabel="MODS_record.xml" dsMIME="text/xml" dsControlGroupType="X" dsState="A" logMessage="BatchModify - addDatastream Page MODS">' >>ingest_page_$i.xml
  echo '     <fbm:xmlData>' >> ingest_page_$i.xml
  sed 's/<?xml version="1.0" ?>//g' $i/${i}_MODS.xml >> ingest_page_$i.xml
  echo '     </fbm:xmlData>' >> ingest_page_$i.xml
  echo '  </fbm:addDatastream>' >> ingest_page_$i.xml
  echo '  <fbm:addDatastream pid="'$page_pid'" dsID="JP2" dsLabel="JP2.jp2" dsMIME="image/jp2" dsLocation="'$DS_LOCATION$bibnum/$i/${i}.jp2'" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream Page JP2"/>' >>ingest_page_$i.xml
  echo '  <fbm:addDatastream pid="'$page_pid'" dsID="TN" dsLabel="TN.jpg" dsMIME="image/jpg" dsLocation="'$DS_LOCATION$bibnum/$i/${i}_TN.jpg'" dsControlGroupType="M" dsState="A" logMessage="BatchModify - addDatastream Page TN"/>' >>ingest_page_$i.xml
  echo '  <fbm:addDatastream pid="'$page_pid'" dsID="RELS-EXT" dsLabel="Relationships" dsMIME="text/xml" dsControlGroupType="X" dsState="A" logMessage="BatchModify - addDatastream Page RELS-EXT">' >>ingest_page_$i.xml
  echo '     <fbm:xmlData>' >> ingest_page_$i.xml
  cat $i/${i}_RELS-EXT.xml >> ingest_page_$i.xml
  echo '     </fbm:xmlData>' >> ingest_page_$i.xml
  echo '  </fbm:addDatastream>' >> ingest_page_$i.xml
  echo '  <fbm:modifyDatastream pid="'$page_pid'" dsID="DC" dsLabel="Default Dublin Core Metadata" dsMIME="text/xml" dsControlGroupType="X" dsState="A" logMessage="BatchModify - modifyDatastream Page DC">' >>ingest_page_$i.xml
  echo '     <fbm:xmlData>' >> ingest_page_$i.xml
  sed 's/<?xml version="1.0" ?>//g' $i/${i}_DC.xml >> ingest_page_$i.xml
  echo '     </fbm:xmlData>' >> ingest_page_$i.xml
  echo '  </fbm:modifyDatastream>' >> ingest_page_$i.xml
  echo '</fbm:batchModify>' >> ingest_page_$i.xml


#echo $FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password ingest_page_$i.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http 
 # if $FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password ingest_page_$i.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http validate-only=false | grep [1-9].*failed ; then
  $FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password ingest_page_$i.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http validate-only=false
#		fatal_error $queueid "Batch modify of book record failed. See $ILIVESROOT/logs/book_ingest_$bibnum.log"	
#		exit 1
#    echo sad sad face
#  else
 #   log_processing_message $queueid "Successfully added page datastream $i."
#  fi

done

pushd $bookdir/processed/figures
mkdir $bookdir/figures
for i in `find . -name "$bibnum-*"`; do
  bn=`basename $i .jpg`
  mkdir $bookdir/figures/$bn  
  cp $i $bookdir/figures/$bn
done

popd


pushd $bookdir
# Get the DC record for the book and replace the dc:type bib-only with ingested.
sed -i 's/bib-only/ingested/g' ${bibnum}_DC.xml
echo '<?xml version="1.0" encoding="utf-8"?>' >modify_book_dc.xml
echo '<fbm:batchModify xmlns:fbm="http://www.fedora.info/definitions/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/ http://www.fedora.info/definitions/1/0/api/batchModify.xsd">' >>modify_book_dc.xml

echo '  <fbm:modifyDatastream pid="'$book_pid'" dsID="DC" dsLabel="Default Dublin Core Metadata" dsMIME="text/xml" dsControlGroupType="X" dsState="A" logMessage="BatchModify - modifyDatastream Page DC">' >>modify_book_dc.xml
echo '     <fbm:xmlData>' >> modify_book_dc.xml
sed 's/<?xml version="1.0" ?>//g' ${bibnum}_DC.xml >> modify_book_dc.xml
echo '     </fbm:xmlData>' >> modify_book_dc.xml
echo '  </fbm:modifyDatastream>' >> modify_book_dc.xml
echo '</fbm:batchModify>' >> modify_book_dc.xml
$FEDORA_HOME/client/bin/fedora-modify.sh $FEDORA_HOST fedoraAdmin $password modify_book_dc.xml $ILIVESROOT/logs/book_ingest_$bibnum.log http validate-only=false
popd

#############################################################################
#		Clean up temporary files											#
#############################################################################
#rm -fr $bookdir
#rm -fr $ocrdir
#rm -fr /tmp/$$-fedora.log
#rm -fr /tmp/$$-source.xml

#############################################################################
#		Log completion and reports pids and filenames						#
#############################################################################
log_completion_message $queueid $pids $original_pages $corrected_pages
#echo -e $queueid "\t" `date` "\tcomplete\tscan processing complete\t"$pids"\t"$original_pages"\t"$corrected_pages"#" >> $short_logfile
echo THE END
