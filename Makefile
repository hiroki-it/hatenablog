FILE_NAME:=

# 投稿をプルする。
.PHONY: pull
pull:
	docker-compose run -T --rm blogsync pull hiroki-hasegawa.hatenablog.jp

# 下書きをプッシュする。
.PHONY: push-draft
push-draft:
	docker-compose run -T --rm blogsync post --title=draft --draft hiroki-hasegawa.hatenablog.jp < ./draft/${FILE_NAME}.md
