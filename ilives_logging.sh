#!/bin/sh

# These are logging routines used by the IslandLives book scripts
# The first argument is the queue_id and the 2nd is the message to accompany the log statement.
#
. ilives_environment.sh
mkdir -p $ILIVESROOT/logs
short_logfile=$ILIVESROOT/logs/jobs.log
short_logfile_lock=$short_logfile".lock";


#############################################################################
#   logging routines                          #
#############################################################################
fatal_error()
{
  lockfile -r -1 $short_logfile_lock
  echo -e  $1 "\t" `date` "\tcancelled\t"$2"#" >> $short_logfile
  rm -f $short_logfile_lock
#  [ "$bookdir" != "" ] && rm -fr $bookdir;
#  [ "$ocrdir" != "" ] && rm -fr $ocrdir;
#  [ -f /tmp/$$-fedora.log ] && rm -f /tmp/$$-fedora.log
#  [ -f /tmp/$$-source.log ] && rm -f /tmp/$$-source.log
#  [ -f /tmp/$$-wget.log ] && rm -f /tmp/$$-wget.log
  return 0;
}

log_processing_message()
{
  lockfile -r -1 $short_logfile_lock
  echo -e  $1 "\t" `date` "\tprocessing\t"$2"#" >> $short_logfile
  rm -f $short_logfile_lock
  return 0;
}

log_completion_message()
{
  if [ "$3" = "" ] ;
  then
  	lockfile -r -1 $short_logfile_lock
  	echo -e $1 "\t" `date` "\tcomplete\tscan processing complete\t"$2"\t"$4"#" >> $short_logfile
  	rm -f $short_logfile_lock
  else
  	lockfile -r -1 $short_logfile_lock
  	echo -e $1 "\t" `date` "\tcomplete\tscan processing complete\t"$2"\t"$3"\t"$4"#" >> $short_logfile
  	rm -f $short_logfile_lock
  fi
  return 0;
}

log_starting_message()
{
  lockfile -r -1 $short_logfile_lock
  echo -e  $1 "\t" `date` "\tstarting\t"$2"#" >> $short_logfile
  rm -f $short_logfile_lock
  return 0;
}
