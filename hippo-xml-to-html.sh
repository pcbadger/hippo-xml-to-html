#! /bin/bash
# Reads content.xml from hippo CMS and outputs directories containing flat HTML
# V 0.1

  # Declaring variables
LINENUM=1
NODESTAT=0
LASTNODESTAT=0
LOOKINGFORCONTENT=0
FOUNDCONTENT=0

  # Initialising array
declare -a FOLDERPATH
FOLDERPATH=(${FOLDERPATH[@]}'exported')

  # Read the content xml one line at a time
cat content.xml | while read LINE; do

  # Check to see if we've entered a folder block (excluding the 1.0 folder)
ISITAFOLDER=`echo $LINE | grep "<sv:value>hippostd:folder</sv:value>" | grep -v 1.0`

  # This counts when we enter and exit a node, so we can tell when we're in a subfolder of the previous one
  if [[ $LINE == *"<sv:node"* ]] ; then
    ((NODESTAT=NODESTAT+1))
  elif [[ $LINE == *"</sv:node"* ]] ; then
    ((NODESTAT=NODESTAT-1))
  fi

  # The name of the node is always 2 lines above the node type line
  ((NODENAMELINE=$LINENUM-2))

  # If we've entered a folder node, then do stuff
  if [[ $ISITAFOLDER =  *[!\ ]* ]] ; then

  # If the node in/out count hasn't changed since the last folder, then we're not in a subfolder
  # So remove the last folder name from the end of the folders array
    if [[ "$LASTNODESTAT" == "$NODESTAT" ]] ; then
      DELETE=(\/$SHORTFOLDERNAME)
      FOLDERPATH=( "${FOLDERPATH[@]/$DELETE}" )
    fi

  # Extracts the pertinent folder name from the other guff in that line
    SHORTFOLDERNAME=`sed -n $NODENAMELINE\p content.xml | cut -d \" -f 2`

  # Unless this is the 1.0 folder, add the newly found folder name to the end of the array and create the folder
    if [[ $SHORTFOLDERNAME != "1.0" ]] ; then
      FOLDERPATH=(${FOLDERPATH[@]}'/'$SHORTFOLDERNAME)
      mkdir -p ${FOLDERPATH[@]}
  # debugging
      echo ${FOLDERPATH[@]}
    fi

  # Increments node in/out count
    LASTNODESTAT=$NODESTAT

fi

  # If the line signifies the start of a document block, find the doc name, create the empty file and start looking for content
if [[ $LINE =~  "<sv:value>hippo:handle</sv:value>" ]] ; then
  SHORTDOCNAME=`sed -n $NODENAMELINE\p content.xml | cut -d \" -f 2`
  LOOKINGFORCONTENT=1
  touch $FOLDERPATH/$SHORTDOCNAME.html
  # debugging
  echo $FOLDERPATH/$SHORTDOCNAME.html
fi

  # If you're in content search mode, do this stuff
if [[ $LOOKINGFORCONTENT == 1 ]] ; then

  # If content block is found, switch to found content mode
  if [[ $LINE =~ "hippostd:content" ]] ; then
    FOUNDCONTENT=1
  # This means that the document is unpublished, so stop looking for content and delete the document
  elif [[ $LINE =~ "<sv:value>new</sv:value>" ]] ; then
  	LOOKINGFORCONTENT=0
  	rm $FOLDERPATH/$SHORTDOCNAME.html
  fi

  # Now we're in found content mode, so do this stuff with the next lines
  if [[ $FOUNDCONTENT = 1 ]] ; then

  # If the line shows the end of the content block, stop looking for content and exit loop
    if [[ $LINE =~ "</sv:property>" ]] ; then
      LOOKINGFORCONTENT=0
      FOUNDCONTENT=0
    else
  # If still in content block, echo out lines to document and reformat (except the content start line) 	
      if ! [[ $LINE =~ "hippostd:content" ]] ; then
        echo $LINE \
        | sed 's/<sv:value>//g' \
        | sed 's/<\/sv:value>//g' \
        | sed 's/&amp;bull;/<li>/g' \
        | sed 's/&amp;#39;/\"/g' \
        | sed 's/&gt;/>/g' \
        | sed 's/&lt;/</g' \
        > $FOLDERPATH/$SHORTDOCNAME.html
  # debugging
        echo $LINE
      fi
    fi
  fi
fi

  # Increment Linenumber, restart loop
((LINENUM=LINENUM+1))
done