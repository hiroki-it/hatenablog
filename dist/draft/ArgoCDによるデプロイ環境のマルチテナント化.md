---
Title: 【ArgoCD🐙️】ArgoCDにおけるマルチテナント化の設計プラクティス
Category:
- ArgoCD
- Microservices Architecture
---

<br>

[:contents]

<br>

# 01. はじめに

Argoくんへの愛ゆえに思っています。

[ArgoTシャツ](https://store.cncf.io/products/staright-fit-argo-tee) がクソだせぇえええ...😂

さて最近の業務では、全プロダクト共通基盤のArgoCDを使用してデプロイのリリースフローを整備しています。

ArgoCDの機能を使えば、プロダクト管理者が許可されていない他プロダクトをデプロイできないように、プロダクト別のテナントを作成できます。

今回、そのマルチテナント化の設計プラクティスを記事で解説しました🚀

なお、マルチテナントを設計する上で、ArgoCDの特に "argocd-server" と "application-controller" の責務を知る必要があり、こちらについては以下の記事で解説しております。

[https://hiroki-hasegawa.hatenablog.jp/entry/2023/05/02/145115:embed]

それでは、もりもり布教していきます😗

<br>

# 02. マルチテナントの種類

ArgoCD上にプロダクト別のテナントを作成する時、何を単位とすればよさそうでしょうか。

ここでは、私が検討した単位の種類は以下の通りです。

<br>

# 謝辞

ArgoCDのマルチテナント設計にあたり、[`@toversus26`](https://twitter.com/toversus26) さんに有益なプラクティスをご教授いただきました。

この場で感謝申し上げます🙇🏻‍
