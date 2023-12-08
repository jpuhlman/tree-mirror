#!/bin/bash
set -e
set -x
TOPDIR=`pwd`
mkdir -p tree

pushd tree
# Init
source $TOPDIR/conf/base.conf
LOCAL_TREE=$(basename $BASE_TREE | sed s,.git,,)

checkout_tree () {
    TREE=$1
    BRANCH=$2
    REPO=$(basename $TREE | sed s,.git,,)
    if [ "$REMOVE_TREE" = "1" ] ; then
       rm $REPO -rf
    fi
    if [ ! -e "$REPO"  ] ; then
        if [ "$BRANCH" = "master" ] ; then
            git clone $TREE
        else
            git clone -b $BRANCH $TREE
        fi
    fi
}

add_remote_tree () {
    TREE=$1
    REMOTE=$2
    if [ -n "$(git config -l | grep remote.*.url | cut -d = -f 2 | grep ^$TREE$)" ] ; then
       return 0
    fi
    git remote add $REMOTE $TREE
}

push () {
    FROM_REMOTE=$1
    TO_REMOTE=$2
    BRANCH=$3
    PUSH_BRANCH=$4

    if [ -n "$(git branch | grep push-branch)" ]; then
        git checkout $BASE_BRANCH 
        git branch -D push-branch
    fi
    if [ -z "$FROM_REMOTE" -o -z "$TO_REMOTE" -o -z "$BRANCH" ] ; then
       echo "push failed to set all vars"
       echo "FROM_REMOTE=$FROM_REMOTE TO_REMOTE=$TO_REMOTE BRANCH=$BRANCH"
       exit 1
    fi
    git checkout $FROM_REMOTE/$BRANCH -b push-branch
    if [ -z "$PUSH_BRANCH" ] ; then
        git push -f $TO_REMOTE push-branch:refs/heads/$BRANCH
    else
        git push $TO_REMOTE push-branch:refs/heads/$PUSH_BRANCH
    fi
    if [ -z "$(git branch | grep $BASE_BRANCH)" ] ; then 
       git checkout $FROM_REMOTE/$BASE_BRANCH -b $BASE_BRANCH
    else
       git checkout $BASE_BRANCH
    fi
    git branch -D push-branch
}

checkout_tree $BASE_TREE $BASE_BRANCH

pushd $LOCAL_TREE
add_remote_tree $TO_TREE $TO_REMOTE
git fetch --all

if [ -n "$MASTER_TO_NEXT" ] ; then
    if [ -z "$(git branch -a | grep remotes\/origin/$MASTER_TO_NEXT)" ] ; then
        push origin $TO_REMOTE master $MASTER_TO_NEXT
    fi
fi

if [ "$AUTO_PUSH_BASE" != "0" ] ; then
    push origin $TO_REMOTE $BASE_BRANCH
fi
if [ -n "$(ls $TOPDIR/conf/trees/ 2>/dev/null)" ] ; then
    for tree in $TOPDIR/conf/trees/*; do
        TREE=""
        BRANCH=""
        REMOTE=""
        if [ -e $tree ] ; then
            source $tree
        fi
        if [ -z "$TREE" -a -z "$BRANCH" ] ; then
           echo $tree define is empty
           exit 1
        fi
        REMOTE=$(basename $TREE | sed s,\\.git,, | sed s,\\.,_,g)
        add_remote_tree $TREE $REMOTE
    done
    git fetch --all
    for tree in $TOPDIR/conf/trees/*; do
        TREE=""
        BRANCH=""
        REMOTE=""
        if [ -e $tree ] ; then
            source $tree
        fi
        if [ -z "$TREE" -a -z "$BRANCH" ] ; then
           echo $tree define is empty
           exit 1
        fi
        REMOTE=$(basename $TREE | sed s,\\.git,, | sed s,\\.,_,g)
        push $REMOTE $TO_REMOTE $BRANCH 
    done 
fi
if [ -n "$MANUAL_MERGE_BRANCHES" -o "$SYNC_ALL" = "1" ] ; then
   allBranches=$(git branch -a | grep -v HEAD | grep remotes\/origin | sed s,remotes\/origin/,,)
   mergeBranches=""
   for branch in $allBranches; do
       current=$(echo $branch | sed s,\ ,,g)
       for manual in $MANUAL_MERGE_BRANCHES; do
           if [ "$manual" = "$current" ] ; then
                current=""
           fi
       done
       if [ -n "$current" ] ; then
          mergeBranches="$mergeBranches $current"
       fi
   done
   for branch in $mergeBranches; do
       push origin github $branch
   done
fi

