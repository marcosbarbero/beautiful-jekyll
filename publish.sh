rm -rf _site/
jekyll build

cp CNAME _site/CNAME

git branch -D master
git checkout develop

git subtree split --prefix _site -b master
git push -f origin master:master

git branch -D master