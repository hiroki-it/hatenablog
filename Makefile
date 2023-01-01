# 投稿をプルする。
.PHONY: pull
pull:
	docker-compose run -T --rm blogsync pull hiroki-hasegawa.hatenablog.jp

# 下書きを作成する。
.PHONY: create-draft
FILE_NAME=
create-draft:
	docker-compose run -T --rm blogsync post --title=${FILE_NAME} --draft hiroki-hasegawa.hatenablog.jp < ./draft/${FILE_NAME}.md

# 記事をプッシュする。
.PHONY: push
push:
	git add ./dist/entry
	git commit -m "update 記事を更新した。"
	git push
