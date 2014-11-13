#! /bin/bash

# Reads content.xml from hippo CMS and outputs directories containing flat HTML
# V 0.3

  # Declaring variables
LINENUM=1
NODESTAT=0
  # Setting flags
LOOKINGFORCONTENT=0
FOUNDCONTENT=0

  # Initialising array
declare -a FOLDERPATH
FOLDERPATH=(${FOLDERPATH[@]}'exported')

  # Function time!

function CHECK_IF_DOCUMENT_UNPUBLISHED {
  # This means that the document is unpublished, so stop looking for content and delete the document
  if [[ $LINE =~ "<sv:value>new</sv:value>" ]] ; then
    LOOKINGFORCONTENT=0
    echo "Document: $FULLFOLDERPATH/$SHORTDOCNAME.html is unpublished, rejecting" # Cosmetic verbosity
    rm $FULLFOLDERPATH/$SHORTDOCNAME.html
  fi
}

function OUTPUT_CONTENT_TO_FILE {
          echo $LINE \
        | sed 's/<sv:value>//g' \
        | sed 's/<\/sv:value>//g' \
        | sed 's/&amp;bull;/<li>/g' \
        | sed 's/&amp;#39;/\"/g' \
        | sed 's/&gt;/>/g' \
        | sed 's/&lt;/</g' \
        > $FULLFOLDERPATH/$SHORTDOCNAME.html
}

  # Read the content xml one line at a time
cat content.xml | while read LINE; do

  # The name of the node is always 2 lines above the node type line
  ((NODENAMELINE=$LINENUM-2))

# This counts when we enter and exit a node, so we can tell when we're in a subfolder of the previous one
if [[ $LINE == *"<sv:node"* ]] ; then
  ((NODESTAT=NODESTAT+1))
elif [[ $LINE == *"</sv:node"* ]] ; then
  ((NODESTAT=NODESTAT-1))

# If we've entered a folder node, then do stuff
elif [[ $LINE =~ "<sv:value>hippostd:folder</sv:value>" ]] ; then

# Extracts the pertinent folder name from the other guff in that line
  SHORTFOLDERNAME=`sed -n $NODENAMELINE\p content.xml | cut -d \" -f 2`

# Unless this is the 1.0 folder, add the newly found folder name to the end of the array
# Excluding helpbook stuff as there's a different method for that
  if [[ $SHORTFOLDERNAME != "1.0" ]] && [[ $SHORTFOLDERNAME != "helpbook" ]] ; then
    FOLDERPATH[((NODESTAT-1))]='/'$SHORTFOLDERNAME
    LEN=${#FOLDERPATH[*]}
# Making sure any extraneous guff is removed from the end of the path
    for i in `seq $NODESTAT $LEN`; do 
      unset "FOLDERPATH[$i]"
    done
    FULLFOLDERPATH=`echo ${FOLDERPATH[@]} | sed 's/ //g'`
# Create the directory
    mkdir -p $FULLFOLDERPATH
    echo "Creating Folder: $FULLFOLDERPATH" # Cosmetic verbosity
  fi

  # If the line signifies the start of a document block, find the doc name, create the empty file and start looking for content
  # Excluding helpbook stuff as there's a different method for that
elif [[ $LINE =~  "<sv:value>hippo:handle</sv:value>" ]] && [[ $SHORTFOLDERNAME != "helpbook" ]]  ; then

  SHORTDOCNAME=`sed -n $NODENAMELINE\p content.xml | cut -d \" -f 2`
  LOOKINGFORCONTENT=1
  touch $FULLFOLDERPATH/$SHORTDOCNAME.html
  echo "Creating Empty Document: $FULLFOLDERPATH/$SHORTDOCNAME.html" # Cosmetic verbosity

  # If you're in content search mode, do this stuff
elif [[ $LOOKINGFORCONTENT == 1 ]] ; then

  CHECK_IF_DOCUMENT_UNPUBLISHED # Function call

  # This means that the document is a link document with a custom format
  if [[ $LINE =~ "<sv:value>mycms:linkdocument</sv:value>" ]] ; then
    LOOKINGFORLINK=1
    echo "Document: $FULLFOLDERPATH/$SHORTDOCNAME.html is a linkdocument" # Cosmetic verbosity

  elif [[ $LOOKINGFORLINK = 1 ]] ; then

  # Find the link, stick it in the file and exit the loop
    if [[ $LINE =~ "<sv:value>http" ]] ; then
      echo "Adding link to $FULLFOLDERPATH/$SHORTDOCNAME.html" # Cosmetic verbosity
      OUTPUT_CONTENT_TO_FILE  # Function call
      LOOKINGFORCONTENT=0
      LOOKINGFORLINK=0
    fi

  # If content block is found, switch to found content mode
  elif [[ $LINE =~ "hippostd:content" ]] ; then
    FOUNDCONTENT=1
    echo "Adding content to $FULLFOLDERPATH/$SHORTDOCNAME.html" # Cosmetic verbosity

  # Now we're in found content mode, so do this stuff with the next lines
  elif [[ $FOUNDCONTENT = 1 ]] ; then
  # If the line shows the end of the content block, stop looking for content and exit loop
    if [[ $LINE =~ "</sv:property>" ]] ; then
      LOOKINGFORCONTENT=0
      FOUNDCONTENT=0
  # If still in content block, echo out lines to document and reformat (except the content start line)
    elif ! [[ $LINE =~ "hippostd:content" ]] ; then
        OUTPUT_CONTENT_TO_FILE  # Function call
    fi
  fi
fi

  # Increment Linenumber, restart loop
((LINENUM=LINENUM+1))
done

  # Now move on and pull down the helpbook stuff

FOLDERPATH="exported/site/helpbook/"
SOURCE_URL="http://myhippo.com:8080"
SOURCE_PATH="site/helpbook"

echo "Creating Helpbook Directory" # Cosmetic verbosity

mkdir -p $FOLDERPATH

  #  Get the welcome page and look for page titles

curl -s $SOURCE_URL/$SOURCE_PATH | while read LINE; do

  if [[ $LINE =~ "<li><a href=\"/site/helpbook/" ]] ; then
    PAGETITLE=`echo $LINE | cut -d \/ -f 4 | cut -d \" -f 1`

    echo "Creating Empty Helpbook $PAGETITLE" # Cosmetic verbosity
  # Create the empty pages and then fill them with content
    touch $FOLDERPATH/$PAGETITLE.html
    echo "Populating Helpbook $PAGETITLE from $SOURCE_URL/$SOURCE_PATH/$PAGETITLE" # Cosmetic verbosity
    curl -s $SOURCE_URL/$SOURCE_PATH/$PAGETITLE > $FOLDERPATH/$PAGETITLE.html
  fi

done

