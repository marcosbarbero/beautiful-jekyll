git checkout develop
rm -rf _site/
jekyll build
git add --all
git commit -m "`date`"
# git push origin develop
git subtree push --prefix  _site/ origin gh-pages