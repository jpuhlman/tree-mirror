#!/bin/bash
set -e
if [ -z "$1" ] ; then
   echo need tree
   exit 1
fi
repo=$(basename $1)
git checkout meta-freescale
git branch $repo || true
git checkout $repo


echo "BASE_TREE=$1" > conf/base.conf.new
echo "TO_TREE=git@github.com:MontaVista-OpenSourceTechnology/$repo" >> conf/base.conf.new
cat conf/base.conf | sed -e '/BASE_TREE/d' -e '/TO_TREE/d' >> conf/base.conf.new
mv conf/base.conf.new conf/base.conf
git add conf/base.conf
git commit -m "Add $repo"
git push origin $repo

