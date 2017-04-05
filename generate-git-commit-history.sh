#!/bin/bash
### file header ###############################################################
#: NAME:          generate-git-commit-history.sh
#: SYNOPSIS:      generate-git-commit-history.sh command [arguments]
#: DESCRIPTION:   generates common usecases of git commit history
#:                and visualize them with your git repository browser
#: RETURN CODES:  0-SUCCESS, 1-FAILURE
#: RUN AS:        common user
#: AUTHOR:        anjel- <andrei.jeleznov@gmail.com>
#: VERSION:       1.0-SNAPSHOT
#: URL:           https://github.com/anjel-/learn-git-by-exercising.git
#: CHANGELOG:
#: DATE:          AUTHOR:          CHANGES:
#: 05-04-2017     anjel-           initial commit for the project
### external parameters #######################################################
set +x
declare GIT_URL="${GIT_URL:none}"  # GIT URL
declare WORKSPACE="./work"
declare -a files=(first.txt second.txt third.txt)
declare -a branches=(master feature-A feature-B )
declare -i commit_number=20
### internal parameters #######################################################
readonly SUCCESS=0 FAILURE=1
readonly FALSE=0  TRUE=1
exitcode=$SUCCESS
### service parameters ########################################################
set +x
_TRACE="${_TRACE:-0}"       # 0-FALSE, 1-print traces
_DEBUG="${_DEBUG:-1}"       # 0-FALSE, 1-print debug messages
_FAILFAST="${_FAILFAST:-1}" # 0-run to the end, 1-stop at the first failure
_DRYRUN="${_DRYRUN:-0}"     # 0-FALSE, 1-send no changes to remote systems
_UNSET="${_UNSET:-0}"       # 0-FALSE, 1-treat unset parameters as an error
TIMEFORMAT='[TIME] %R sec %P%% util'
(( _DEBUG )) && echo "[DEBUG] _TRACE=\"$_TRACE\" _DEBUG=\"$_DEBUG\" _FAILFAST=\"$_FAILFAST\""
# set shellopts ###############################################################
(( _TRACE )) && set -x || set +x
(( _FAILFAST )) && { set -o pipefail; } || true
(( _UNSET )) && set -u || set +u
### functions #################################################################
###
function die { #@ print ERR message and exit
	(( _FAILFAST )) && printf "[ERR] %s\n" "$@" >&2 || printf "[WARN] %s\n" "$@" >&2
	(( _FAILFAST )) && exit $FAILURE || { exitcode=$FAILURE; true; }
} #die
###
function print { #@ print qualified message
  local level="INFO"
  (( _DEBUG )) && level="DEBUG"
  (( _DRYRUN )) && level="DRYRUN+$level"||true
  printf "[$level] %s\n" "$@"
} #print
###
function usage { #@ USAGE:
  echo "
[INFO] generates common usecases of git commit history :
[INFO] LINEAR-LOG         - create a linear commit history
[INFO] DETACHED-HEAD      - bring the working tree into detached head state
[INFO] NOT-DIVERGED-BRANCH- create and develop on a new branch only
[INFO] DIVERGED-BRANCH    - create a new branch and develop on both branches
[INFO] FF-MERGE           - make fast-forward merge
[INFO] 3W-MERGE           - make 3-way merge
[INFO] Usage: $_SCRIPT_NAME LINEAR-LOG|DETACHED-HEAD|NOT-DIVERGED-BRANCH|DIVERGED-BRANCH|FF-MERGE|3W-MERGE
  "
} #usage
###
function initialize { #@ initialization of the script
  (( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
	(( _DEBUG )) && print "Initializing the variables"
  ostype="$(uname -o)"
  case $ostype in
  	"Cygwin")
  		_SCRIPT_DIR="${0%\\*}"
  		_SCRIPT_NAME="${0##*\\}"
      VIEWER="${VIEWER:-/cygdrive/c/Data/Programme/TortoiseGit/bin/TortoiseGitProc}"
  	;;
  	*)
  	local tempvar="$(readlink -e "${BASH_SOURCE[0]}")"
  	_SCRIPT_DIR="${tempvar%/*}"
  	_SCRIPT_NAME="${tempvar##/*/}"
    VIEWER="${VIEWER:-gitk}"
  	;;
  esac
} #initialize
###
function checkPreconditions { #@ prerequisites for the whole script
  (( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
	(( _DEBUG )) && print "Checking the preconditions for the whole script"
  print "_SCRIPT_DIR=\"$_SCRIPT_DIR\" _SCRIPT_NAME=\"$_SCRIPT_NAME\" "
} #checkPreconditions
###
function create_linear_log { #@ create a linear commit history
  (( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
  (( _DEBUG )) && print "Creating a linear commit history"
  local option step
  if (( $# > 0 ));then
     option="$1";shift
     step="$1";shift
  fi
  [[ -d ./$WORKSPACE ]] && rm -rf ./$WORKSPACE||true
  mkdir ./$WORKSPACE && pushd ./$WORKSPACE>/dev/null
  print "Creating the local git repo"
  git init
  local i count
  for (( i=1; i <=${commit_number}; i++));do
    for f in "${files[@]}";do
      (( count=10*i ))
      echo "$count line of text" >> ./$f
      git add ./$f
    done
    git commit -m "$i commit"
  done
  case "$option" in
  detached)
  git checkout HEAD~$step
  esac
  case "$ostype" in
  "Cygwin") $VIEWER "/command:log" "/path:."
  ;;
  *) $VIEWER 
  ;;
  esac
  echo "Done"
} #create_linear-log
###
function create-branch { #@ creat a new branch
	(( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
  (( _DEBUG )) && print "Creating a new branch"
  local option step
  (( $# < 1 ))&& die "$FUNCNAME needs at least an one parameter"||true
  option="$1";shift
  case "$option" in
  not-diverged)
    step_to_branch="$1";shift
  ;;
  diverged)
    step_to_branch="$1";shift
    step_to_return="$1";shift
    (( step_to_branch >= step_to_return ))&& die "step_to_branch should be < step_to_return"
  ;;
  esac

  [[ -d ./$WORKSPACE ]] && rm -rf ./$WORKSPACE||true
  mkdir ./$WORKSPACE && pushd ./$WORKSPACE>/dev/null
  print "Creating the local git repo"
  git init
  local branch="${branches[1]}"
  local i count
  for (( i=1; i <=${commit_number}; i++));do
    (( i == step_to_branch ))&& git checkout -b $branch||true
    if [[ $option == diverged ]];then
      (( i == step_to_return ))&& git checkout master||true
    fi
    for f in "${files[@]}";do
      (( count=10*i ))
      echo "$count line of text" >> ./$f
      git add ./$f
    done
    git commit -m "$i commit"
  done
  case "$ostype" in
  "Cygwin") $VIEWER "/command:log" "/path:."
  ;;
  *) $VIEWER
  ;;
  esac
  print "Done"
} #create-branch
###
function make-merge { #@ create a new branch and make a merge
	(( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
  (( _DEBUG )) && print "Creating a new branch and making the merge"
  local option step
  (( $# < 1 ))&& die "$FUNCNAME needs at least an one parameter"||true
  option="$1";shift
  case "$option" in
  ff)
    step_to_branch="$1";shift
  ;;
  3w)
    step_to_branch="$1";shift
    step_to_return="$1";shift
    (( step_to_branch >= step_to_return ))&& die "step_to_branch should be < step_to_return"
  ;;
  *)
    die "$FUNCNAME unknown option- $option"
  ;;
  esac
  [[ -d ./$WORKSPACE ]] && rm -rf ./$WORKSPACE||true
  mkdir ./$WORKSPACE && pushd ./$WORKSPACE>/dev/null
  print "Creating the local git repo"
  git init
  local branch="${branches[1]}"
  local i count
  for (( i=1; i <=${commit_number}; i++));do
    (( i == step_to_branch ))&& git checkout -b $branch||true
    if [[ $option == 3w ]];then
      (( i == step_to_return ))&& git checkout master||true
    fi
    for f in "${files[@]}";do
      (( count=10*i ))
      echo "$count line of text" >> ./$f
      git add ./$f
    done
    git commit -m "$i commit"
  done
  print "Returning to the master"
  git checkout master
  print "Showing the state before merge"
  case "$ostype" in
  "Cygwin") $VIEWER "/command:log" "/path:."
  ;;
  *) $VIEWER
  ;;
  esac
  print "Making the merge"
  git merge --strategy=ours -m "$(( i++ )) merge comit" $branch
  test -z "$(git diff-index --name-only HEAD)"||git commit -m "$(( i++ )) merge comit"
  case "$ostype" in
  "Cygwin") $VIEWER "/command:log" "/path:."
  ;;
  *) $VIEWER
  ;;
  esac
  print "Done"
} #make-merge
### function main #############################################################
function main {
  (( _DEBUG )) && echo "[DEBUG] enter $FUNCNAME"
  initialize
  checkPreconditions "$CMD"
  case $CMD in
  LINEAR-LOG|linear-log)
  create_linear_log
  ;;
  DETACHED-HEAD|detached-head)
  create_linear_log "detached" 10
  ;;
  NOT-DIVERGED-BRANCH|not-diverged-branch)
  create-branch "not-diverged" 5
  ;;
  DIVERGED-BRANCH|diverged-branch)
  create-branch "diverged" 5 15
  ;;
  FF-MERGE|ff-merge)
  make-merge "ff" 10
  ;;
  3W-MERGE|3w-merge)
  make-merge "3w" 5 15
  ;;
  HELP|help)
  usage
  ;;
  *) die "unknown command \"$CMD\" "
  ;;
  esac
} #main
### call main #################################################################
(( $# < 1 )) && die "$(basename $0) needs at least an one parameter"
declare CMD="$1" ;shift
set -- "$@"
declare VAR
main "$@"
exit $exitcode
