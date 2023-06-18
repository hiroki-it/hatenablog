# hatenablog

## 概要

[はてなブログ](https://hiroki-hasegawa.hatenablog.jp/)の記事をバージョン管理しています。

デプロイには、[push-to-hatenablog](https://github.com/mm0202/push-to-hatenablog)を使用しています。

## セットアップ

1. プラグインのURLを確認する。

```bash
$ asdf plugin list all | grep <.tool-versionsファイルに記載のプラグイン名>
```

2. 確認したURLを使用して、プラグインを登録する。

```bash
$ asdf plugin add <プラグイン名> <URL>
```

3. プラグインをインストールする。

```bash
$ asdf install
```

<br>

## マークダウンの静的解析

### インストール

```bash
$ yarn
```

### 整形

フォーマッターを実行する。

```bash
$ yarn prettier -w --no-bracket-spacing **/*.md
```

### 校閲

```bash
$ yarn textlint *
```
