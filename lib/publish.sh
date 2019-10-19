#
set -e

symb=site
key=$(ipfs key list -l | grep -w $symb | cut -d' ' -f1)
gitid=$(git rev-parse --short HEAD)
echo updating $gitid ...

find . -name "*.org" -o -name \*~ -delete

if [ "x$SITE" != 'x' ]; then
echo sending files: ...
rsync -v -r -aub $SITE/ ~/GITrepo/michel47/Gradual/site/
echo receiving files: ...
rsync -v -r -Caub ~/GITrepo/michel47/Gradual/site/ $SITE/
fi
 
tic=$(date +%s)
# ----------------------------------------------------------------------------------------------------------------
ver=$($HOME/bin/version README.md| xyml scheduled)
qm=$(ipfs add -Q -w -r *.pm README.* --cid-version=1 --cid-base=base58btc)

ipfs files rm -r /root/site/lib
ipfs files cp /ipfs/$qm /root/site/lib
echo -n "site: "
site=$(ipfs files stat /root/site --hash)
if [ "x$site" != 'x' ]; then
site32=$(ipfs cid base32 $site)
echo http://$site32.ipfs.dweb.link/lib
echo url: https://gateway.ipfs.io/ipfs/$site/lib

echo "info: /ipfs/$site/lib"
echo ipns: http://127.0.0.1:8080/ipns/$key
ipfs name publish --allow-offline --key=$symb /ipfs/$site/lib &


echo -n "rootkey: "
rootkey=$(ipfs files stat /root --hash)
echo https://gateway.ipfs.io/ipfs/$rootkey/site/lib
echo cf: https://$site32.cf-ipfs.com/lib
echo cdn: https://cdn.jsdelivr.net/gh/michel47/site@latest/lib
cat README.txt | sed -e "s/\$ver/$ver/g" -e "s/\$gitid/$gitid/g" \
    -e "s/\$qm/$qm/g" -e "s/\$rootkey/$rootkey/" -e "s/\$site/$site/" > README.md

cat RELEASE_NOTES.txt | sed -e "s/\$ver/$ver/g" -e "s/\$gitid/$gitid/g" \
    -e "s/\$qm/$qm/g" -e "s/\$rootkey/$rootkey/" -e "s/\$site/$site/" > RELEASE_NOTES.md
fi

git add README.txt
git add README.md *.pm
git diff origin/master | tee site.patch
git add site.patch RELEASE_*.md
date=$(date +%D)
time=$(date +%T)
if git commit -m "publishing on $date for $ver at $time"; then
gitid=$(git rev-parse HEAD)
git tag -f -a $ver -m "tagging $gitid on $(date +%D)"
echo "gitid: $gitid ($ver)"
echo "$tic: $gitid ($ver)" >> revs.log
fi

if git ls-remote --tags | grep "$ver"; then
  git push --delete origin $ver
fi
echo "# git pushing : "
git push --tags
echo url: https://github.com/michel47/site/releases/
echo url: https://cdn.jsdelivr.net/gh/michel47/site@latest/


