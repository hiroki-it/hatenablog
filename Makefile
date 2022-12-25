FILE_NAME:=

# 投稿をプルする。
.PHONY: pull
pull:
	docker-compose run -T --rm blogsync pull hiroki-hasegawa.hatenablog.jp
