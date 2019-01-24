setup_git() {
   git config --global user.email "travis@travis-ci.org"
   git config --global user.name "Travis CI"
   git remote add origin-pages https://${GH_TOKEN}@github.com/marcosbarbero/marcosbarbero.github.io.git > /dev/null 2>&1
}

build_site() {
	rm -rf _site/
    bundle exec jekyll build
}

fetch_n_checkout_branch() {
	git fetch --all
    # git push origin --delete master
    git branch -D master

    git checkout develop
}

commit_n_push() {
	git add --all
    git commit --message "Travis build: $TRAVIS_BUILD_NUMBER"

    git subtree split --prefix _site -b master
    git push --quiet --set-upstream -f origin-pages master
}

if [ "$TRAVIS_BRANCH" = "develop" ] && [ "$TRAVIS_PULL_REQUEST" = "false" ] && [[ "$TRAVIS_COMMIT_MESSAGE" == *"[ci deploy]"* ]]; then

	setup_git
	build_site
	fetch_n_checkout_branch   

    cp CNAME _site/CNAME

    commit_n_push

    echo "New version released"
fi 