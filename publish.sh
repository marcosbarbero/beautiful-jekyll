setup_git() {
   git config --global user.email "travis@travis-ci.org"
   git config --global user.name "Travis CI"
   git remote add origin https://$GH_TOKEN@github.com/marcosbarbero/marcosbarbero.github.io.git
}

build_site() {
	rm -rf _site/
	bundle install
    bundle exec jekyll build
    ls -lah _site/
}

fetch_n_checkout_branch() {
	git fetch --all
    git push origin --delete master
    git branch -D master

    git checkout develop
}

commit_n_push() {
	git add --all
    git commit --message "Travis build: $TRAVIS_BUILD_NUMBER"

    git subtree split --prefix _site -b master
    # git push --quiet --set-upstream -f origin-pages master
    git push -f origin master
}

if [ "$TRAVIS_BRANCH" = "develop" ] && [ "$TRAVIS_PULL_REQUEST" = "false" ] && [[ "$TRAVIS_COMMIT_MESSAGE" == *"[ci deploy]"* ]]; then

	echo "***************************************************"
	echo "BUILD STARTED"
	echo "***************************************************"

	build_site
	setup_git
	fetch_n_checkout_branch   

    cp CNAME _site/CNAME

    commit_n_push

	echo "***************************************************"
    echo "BLOG RELEASED"
    echo "***************************************************"
fi 
