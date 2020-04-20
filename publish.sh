#

tic=$(date +%s)
qm=$(ipfs add -Q -r .)
echo "$tic: $qm" >> qm.log
gitid=$(git rev-parse --short HEAD)
ver=$(version $0 | xyml scheduled)

eval $(perl -S fullname.pl -a $qm | eyml)
git config user.email $user@qtools.gq
echo "gituser: $(git config user.name) <$(git config user.email)>"
tag=$(echo -n "$user@gradual.gq" | ipfs add -Q --raw-leaves --hash id --cid-base=base58btc)

IFS='' read -d '' msg <<EOT
$ver $time: ${1:-publish} on $date ~ $firstname $lni.
gitid: $gitid
qm: $qm
tag: $tag
EOT

echo "msg: $msg"  | sed -e '2,$s/^/  /'
if git commit -a -m "$msg"; then
commitid=$(git rev-parse HEAD)
git tag -f -a $ver -m "tagging $commitid on $date"
echo commitid: $gitid | cut -b 1-14
if test -e revs.log; then
echo $tic: $gitid >> revs.log
fi

# test if tag $ver exist ...
if git ls-remote --tags | grep "$ver"; then
git push --delete origin "$ver"
fi
fi
echo "git push : "
git push --follow-tags
echo .


