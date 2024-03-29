#!/usr/bin/env zsh
version=$(ruby -e "$(head -n 1 Camera.podspec); puts(version.strip);")

git commit -a --allow-empty -m "v$version"

if [ -z "$(git status --porcelain)" ]; then 
  git tag "v$version"
  git push origin master
  git push origin master --tags
  pod repo push --swift-version=5 private-pod-specs Camera.podspec --allow-warnings
else 
  echo "Error: Git has uncommitted changes."
  exit 1
fi
