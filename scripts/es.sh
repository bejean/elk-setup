#!/bin/bash
#set -x
#trap read debug

# TODO - use getopt - https://gist.github.com/bobpaul/ecd74cdf7681516703f20726431eaceb

# $ echo sortmeplease | grep -o . | sort | tr -d '\n'; echo
# aeeelmoprsst

# foo=string
# for (( i=0; i<${#foo}; i++ )); do
#   echo "${foo:$i:1}"
# done

# string='My long string'
# if [[ $string == *"My long"* ]]; then
#  echo "It's there!"
# fi

#


function usage()
{
    echo "Usage"
    echo "-----"
    echo ""
    echo "    ./es.sh -a <action> [-i <indice>] [--uid document id] [-f <json file>] [-q <query>] [-e <env>] [-u <es_url>] [--ssl] [--user username:password][-p <api_entrypoint>] [--pipeline <pipeline_name>] [--silent] [-v] [-h] [-d]"
    echo ""
    echo "    -a --action    -> action"
    echo "        indice_create       (-if) -> create indice"
    echo "        indice_delete       (-i)  -> delete indice"
    echo "        indice_set_mapping  (-if) -> set/update mapping on existing indice"
    echo "        index               (-if) -> index one json document or all json documents in directory (one document per file)"
    echo "        index_bulk          (-if) -> bulk index one json document or all json documents in directory (several documents per bulk file)"
    echo "        search              (-i)  -> search in indice"
    echo "        clear_content       (-i)  -> remove all documents in indice (for tests as delete and recreate indice instead is a better practice)"
    echo ""
    echo "        get|delete          (-p)  -> "
    echo "        post|put            (-pf) -> "
    echo ""
    echo "    -u --url       -> elasticsearch root url (default 'http://localhost:9200/')"
    echo "    -h --help      -> display usage"
    echo "    -v --verbose   -> dump action and settings "  
    echo "    -d --debug     -> dump action and settings and quit"
    echo ""
    echo "    Example :"
    echo "        ./ed.sh -a indice_create -i cea -f indice_setting.json"
    echo "        ./es.sh -a indice_delete -i cea"
    echo "        ./es.sh -a indice_set_mapping -i cea -f indice_mapping.json"
    echo ""
}

#
# Defaults
#
METHOD="GET"
FILE=""
QUERY=""
INDICE=""
POST_DATA="{}"
ES_ENV=""
VERBOSE="0"
DEBUG="0"
ERROR_MSG=""
ENTRY_POINT=""
PIPELINE=""
EXTRA_PARAM=
SSL=
SILENT=
UUID=

SCRIPT_HOME="`dirname "$0"`"
. $SCRIPT_HOME/es-env.sh

#
# Parse command line
#
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage
      exit
      ;;
    -v|--verbose)
      VERBOSE="1"
      shift
      ;;
    -d|--debug)
      VERBOSE="1"
      DEBUG="1"
      shift
      ;;
    -a|--action)
      ACTION=$2
      shift 2
      ;;
    -e|--env)
      ES_ENV=$2
      shift 2
      ;;
    -i|--indice)
      INDICE=$2
      shift 2
      ;;
    -u|--url)
      ES_URL=$2
      shift 2
      ;;
    --ssl)
      SSL="1"
      shift
      ;;
    --silent)
      SILENT="1"
      shift
      ;;
    -q|--query)
      QUERY=$2
      shift 2
      ;;
    --pipeline)
      EXTRA_PARAM="${EXTRA_PARAM}&pipeline=$2"
      shift 2
      ;;
    -p|--point)
      ENTRY_POINT=$2
      shift 2
      ;;
    --uid)
      UUID=$2
      shift 2
      ;;
    --user)
      USER=$2
      shift 2
      ;;
    -f|--file)
      FILE=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"


#
# Check action and configure curl query
#
case $ACTION in
  indice_create )
    METHOD="PUT"
    ENTRY_POINT="$INDICE"
    ;;
  indice_delete )
    METHOD="DELETE"
    ENTRY_POINT="$INDICE"
    ;;
  indice_set_mapping )
    METHOD="PUT"
    ENTRY_POINT="$INDICE/_mapping"
    ;;
  indice_list )
    METHOD=""
    ENTRY_POINT="_aliases"
    ;;
  index )
    METHOD="POST"
    ENTRY_POINT="$INDICE/_doc"
    ;;
  index_bulk )
    METHOD="POST"
    ENTRY_POINT="$INDICE/_bulk"
    ;;
  search )
    METHOD="GET"
    ENTRY_POINT="$INDICE/_search"
    ;;  
  clear_content )
    METHOD="POST"
    ENTRY_POINT="$INDICE/_delete_by_query"
    POST_DATA='{"query": {"match_all": {}}}'
    ;;  
  get )
    METHOD="GET"
    ;; 
  post )
    METHOD="POST"
    ;; 
  put )
    METHOD="PUT"
    ;; 
  delete )
    METHOD="DELETE"
    ;;   
  *)
    echo ""
    if [ "$ACTION" == "" ]; then
      echo "Action missing !"
    else
      echo "Action not valid [$ACTION] !"
    fi
    echo ""
    usage
    exit 1
esac

if [ "$SSL" == "1" ]; then
  ES_URL="${ES_URL/http:/https:}"    
fi

ES_URL=`echo "${ES_URL}" | sed 's/\(.*\)\/$/\1/'`
ENTRY_POINT=`echo "${ENTRY_POINT}" | sed 's/^\/\(.*\)/\1/'`

if [ "$VERBOSE" == "1" ]; then
  echo ""
  echo "ACTION         : ${ACTION}"
  echo "ES_URL         : ${ES_URL} (${METHOD})"
  echo "ES_ENTRY_POINT : ${ENTRY_POINT}"
  echo "FILE           : ${FILE}"
  echo "EXTRA_PARAM    : ${EXTRA_PARAM}"
  echo "USER           : ${USER}"
  echo ""
  echo ""
  read -p "Continue (y/N) ? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
  fi
fi

#
# Check parameters
#
case $ACTION in
  indice_create )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    #if [ -z $FILE ]; then
    #  ERROR_MSG="Indice setting file not specified (-f)"
    #fi
    ;;
  indice_delete )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    ;;
  indice_set_mapping )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    if [ -z $FILE ]; then
      ERROR_MSG="Mapping definition file not specified (-f)"
    fi
    ;;
  index | index_bulk )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    if [ -z $FILE ]; then
      ERROR_MSG="File or directory not specified (-f)"
    fi
    ;;
  post )
    if [ -z $ENTRY_POINT ]; then
      ERROR_MSG="Entry point not specified (-p)"
    fi
    if [ -z $FILE ]; then
      ERROR_MSG="File or directory not specified (-f)"
    fi
    ;;
  put )
    if [ -z $ENTRY_POINT ]; then
      ERROR_MSG="Entry point not specified (-p)"
    fi
    if [ -z $FILE ]; then
      ERROR_MSG="File or directory not specified (-f)"
    fi
    ;;
  delete )
    if [ -z $ENTRY_POINT ]; then
      ERROR_MSG="Entry point not specified (-p)"
    fi
    ;;
  get )
    if [ -z $ENTRY_POINT ]; then
      ERROR_MSG="Entry point not specified (-p)"
    fi
    ;;
  search )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    #if [ -z $QUERY ]; then
    #  ERROR_MSG="Query not specified (-q)"
    #fi
    ;;
  clear_content )
    if [ -z $INDICE ]; then
      ERROR_MSG="Indice not specified (-i)"
    fi
    ;;  
esac

if [ ! "x$UUID" == "x" ]; then
  if ! command -v jq &> /dev/null
  then
      echo "jq command requiered with uid parameter could not be found !"
      exit
  fi
fi

if [ -z "$ERROR_MSG" ]; then
  ERROR_MSG=""
else
  echo ""
  echo "$ERROR_MSG"
  echo ""
  usage
  exit 
fi

#
# Execute action
#
cmd="curl --silent -k" 

if [ ! -z "$USER" ]
then
  cmd="$cmd --user $USER"
fi


if [ "$METHOD" == "" ]; then
    cmd="$cmd '${ES_URL}/$ENTRY_POINT?pretty${EXTRA_PARAM}'"
    #curl --silent "${ES_URL}/$ENTRY_POINT?pretty${EXTRA_PARAM}"
else
  if [ "$METHOD" == "GET" ] || [ "$METHOD" == "DELETE" ]; then
    cmd="$cmd -X $METHOD '${ES_URL}/$ENTRY_POINT?pretty${EXTRA_PARAM}'"
    if [ ! -z "$QUERY" ]; then
      cmd="$cmd&$QUERY"
    fi
  else
    if [ "$POST_DATA" == "{}" ]; then
      if [ "$FILE" == "" ]; then
        cmd="$cmd '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD"
      else
        if [ ! -f "$FILE" ] && [ ! -d "$FILE" ]; then
          echo "$FILE not found !"
          exit 1
        fi
        if [ -f "$FILE" ]; then
          if [ "$ACTION" == "index_bulk" ]; then
            cmd="$cmd '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD -H 'Content-Type: application/x-ndjson' --data-binary @$FILE"
          else
            if [ "$ACTION" == "index" ] && [ ! "x$UUID" == "x" ]; then
              uid=$( jq -r ".$UUID" $FILE )
              ENTRY_POINT="${ENTRY_POINT}/${uid}"
            fi
            cmd="$cmd '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD -H 'Content-Type: application/json' -H 'kbn-xsrf: true' -d @$FILE"
          fi
        fi
        if [ -d "$FILE" ]; then
          cmdsave=$cmd
          entrypointsave=${ENTRY_POINT}
          find $FILE -type f -name '*.json' -print | while read filename
          do
            echo $filename 
            if [ "$ACTION" == "index_bulk" ]; then
              cmd="$cmdsave '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD -H 'Content-Type: application/x-ndjson' --data-binary @$filename"
            else
              if [ "$ACTION" == "index" ] && [ ! "x$UUID" == "x" ]; then
                uid=$( jq -r ".$UUID" $filename )
                ENTRY_POINT="$entrypointsave/${uid}"
              fi
              cmd="$cmdsave '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD -H 'Content-Type: application/json' -d @$filename"
            fi
            if [ "$VERBOSE" == "1" ]; then
              echo $cmd
            fi
            if [ "$DEBUG" != "1" ]; then
              if [ "$SILENT" == "1" ]; then
                cmd="$cmd > /dev/null"
              fi
              eval $cmd
            fi
          done
          exit 0
        fi
      fi
    else
      cmd="$cmd '${ES_URL}/${ENTRY_POINT}?pretty${EXTRA_PARAM}' -X $METHOD -H 'Content-Type: application/json' -d '$POST_DATA'"
    fi
  fi
fi


if [ "$VERBOSE" == "1" ]; then
  echo $cmd
  if [ "$DEBUG" == "1" ]; then
    exit 0
  fi
fi
if [ "$SILENT" == "1" ]; then
  cmd="$cmd > /dev/null"
fi
eval $cmd


#?pipeline=parse_sirene_csv
