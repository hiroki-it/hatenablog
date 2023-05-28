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

Argoファンのみなさん、本当にごめんなさい。

[Argo Tシャツ](https://store.cncf.io/products/staright-fit-argo-tee) がダサいです。

前回の記事では、ArgoCDで採用したアーキテクチャを紹介しました。

[https://hiroki-hasegawa.hatenablog.jp/entry/2023/05/02/145115:embed]

最近の業務では、全プロダクト共通基盤のArgoCDを使用してデプロイのリリースフローを整備しています。

この時、共通基盤にプロダクトごとにテナントを作成することにより、プロダクト管理者が許可されていない他のプロダクトを操作できないようにする必要がありました。

今回、そのマルチテナント化の設計プラクティスを記事で解説しました🚀

プラクティスだけでなく、個々のマニフェストの実装にもちょっとだけ言及します。

それでは、もりもり布教していきます😗
