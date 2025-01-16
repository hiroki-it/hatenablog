# 投稿をプルする。
.PHONY: pull
pull:
	docker-compose run -T --rm blogsync pull hiroki-hasegawa.hatenablog.jp

# 下書きを作成する。
.PHONY: create-draft
FILE_NAME=
create-draft:
	docker-compose run -T --rm blogsync post --title=${FILE_NAME} --draft hiroki-hasegawa.hatenablog.jp < ./draft/${FILE_NAME}.md
	rm ./draft/${FILE_NAME}.md

# フォーマットを整形する。
.PHONY: format
format:
	yarn textlint *
	find ./src/entry/* -name "*.md" -type f | xargs sed -i '' -e 's/）/) /g'  -e 's/（/ (/g'
	yarn prettier -w --no-bracket-spacing **/*.md

# 記事をプッシュする。
.PHONY: push-post
push-post: format
	git checkout release/entry
	git pull
	git add ./src
	git commit -m "update 記事を更新した。"
	git push
	git checkout main
	git pull
	git push
	git merge release/entry
	git checkout release/entry
