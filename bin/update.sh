#!/bin/bash
set -e

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
    if [ -z "$FROM_REMOTE" -o -z "$TO_REMOTE" -o -z "$BRANCH" ] ; then
       echo "push failed to set all vars"
       echo "FROM_REMOTE=$FROM_REMOTE TO_REMOTE=$TO_REMOTE BRANCH=$BRANCH"
       exit 1
    fi
    git checkout $FROM_REMOTE/$BRANCH -b push-branch
    git push $TO_REMOTE push-branch:$BRANCH
    git checkout master
    git branch -D push-branch
}

checkout_tree $BASE_TREE $BASE_BRANCH

pushd $LOCAL_TREE
add_remote_tree $TO_TREE $TO_REMOTE
git fetch --all
push origin $TO_REMOTE $BASE_BRANCH
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

