#!/bin/bash
set -e

REPO_URL="${REPO_URL:-https://github.com/mohammed-ali-1/hello-world-chart-repo.git}"
echo "----> Deploying to $REPO_URL"

helm_response=`curl -X GET $HELMQA_URL'/livecheck?repo='$REPO_URL`
helm_code=`echo $helm_response | jq .code`

if [ $helm_code == 404 ]; then
	echo "-------> HelmQA error: $helm_response"; exit 1;
fi

GIT_REPO="$(git config remote.origin.url)"

tmp="$(mktemp -d)"
echo "----> Working in $tmp"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup 0 1 2 3 6 15

charts=$(find ./* -maxdepth 1 -name Chart.yaml -exec dirname "{}" \;)
for chart in $charts; do
  echo "----> Packaging ${chart}"
  helm package \
    --destination="$tmp" \
    --save=false \
    "$chart"
done

echo "----> Check out gh-pages branch"
git clone --depth=1 "$GIT_REPO" --branch=gh-pages "$OUT_DIR"

echo "----> Moving new charts into repo"
mv -nv "${tmp}"/*.tgz "${OUT_DIR}/"

pushd "$OUT_DIR"
new_charts="$(git status --short | grep '^??' --count ||:)"
if [ "$new_charts" -eq 0 ]; then
  echo '----> No new charts, exiting'
  exit 0
fi

echo '----> Reindexing Helm repository'
helm repo index --url="$REPO_URL" .