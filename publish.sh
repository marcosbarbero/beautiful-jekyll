rm -rf _site/
bundle exec jekyll build

git fetch --all
# git push origin --delete master
git branch -D master

git checkout develop

cp CNAME _site/CNAME

git add --all
git commit -m "`date`"

git subtree split --prefix _site -b master

git push -f origin master:master