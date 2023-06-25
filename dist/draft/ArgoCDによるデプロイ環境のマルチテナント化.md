---
Title: 【ArgoCD🐙️】ArgoCDにおけるマルチテナント化の設計手法とその仕組み
Category:
  - ArgoCD
  - Microservices Architecture
---

<br>

[:contents]

<br>

# 01. はじめに

Argoくんへの愛ゆえに思っています。

[Argo Tシャツ](https://store.cncf.io/products/staright-fit-argo-tee) がクソだせぇえええ...😂

さて最近の業務では、全プロダクトの技術基盤開発チームに携わっており、全プロダクト共有のArgoCD🐙のテナントを設計しました。

ArgoCDの機能を使えば、プロダクト管理者が許可されていない他プロダクトをデプロイできないように、プロダクト別のテナントを作成できます。

今回、そのマルチテナント化の設計手法を記事で解説しました。

それでは、もりもり布教していきます😗

<br>

# 02. マルチテナント化の設計手法の種類

## ここで説明すること

ArgoCD上にプロダクト別のテナントを作成する時、何を単位とすればよさそうでしょうか。

前述した通り、テナントの意義は『プロダクト管理者が許可されていない他プロダクトをデプロイできないようにすること』です。

ここでは、私が検討した単位の種類は以下の通りです。

<br>

## 実Cluster単位

![argocd_tenant_physical_cluster.png](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/argocd/argocd_tenant_physical_cluster.png)

後述の仮想Clusterと対比させるために、『実Cluster』と呼ぶことにします。

この単位では、ArgoCDのためにプロダクト共有Clusterを作成するのではなく、デプロイ先ClusterごとにArgoCD用の実Clusterを作成します。

この時の実Clusterをプロダクト別テナントの単位とします。

それぞれの実Cluster上のKubernetesリソースは完全に独立しています。

そのため、ArgoCDが使用するClusterスコープなKubernetesリソース (例：ArgoCD系のCRD) を完全に分離でき、それぞれのArgoCDを好きなように運用保守できます。

しかしみなさんご存知な通り、Clusterが増えると我々の運用保守がとてもつらくなるため、不採用になりました。

<br>

## 仮想Cluster単位

![argocd_tenant_virtual_cluster.png](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/argocd/argocd_tenant_virtual_cluster.png)

この単位では、プロダクト共有Cluster上に仮想Clusterを作成し、それぞれの仮想Cluster上でArgoCDを動かします。

この時の仮想Clusterをプロダクト別テナントの単位とします。

仮想Clusterの代表的なプロビジョニングツールとして、[vcluster](https://github.com/loft-sh/vcluster) があります。

ホストClusterのKubernetesリソースは共有しますが、それぞれの仮想Cluster上のそれは完全に独立しています。

そのため、実Cluster単位テナントのメリットを享受しつつ、また実Clusterが増えなくてよいです。

しかし、仮想Cluster自体が増えてしまうことと、技術的に発展途上で運用保守の難易度が高くなってしまうため、不採用になりました。

> ↪️：[https://blog.argoproj.io/using-argo-cd-with-vclusters-5df53d1c51ce:title]

<br>

## AppProject単位

![argocd_tenant_appproject.png](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/argocd/argocd_tenant_appproject.png)

この単位では、プロダクト共有Cluster上にプロダクト別のNamespaceを作成し、Cluster全体に認可スコープを持つ単一のArgoCDを動かします。

また、それぞれのNamespaceにデプロイ先ClusterごとのAppProjectを作成します。

この時のAppProjectをプロダクト別テナントの単位とします。

そのため、実Cluster単位テナントのメリットを享受しつつ、また実Clusterが増えなくてよいです。

また、単一のArgoCDを運用保守しさせすればよいので、ハッピーになれます。

しかし私の状況では、単一のArgoCDでデプロイしなければならないプロダクトの数が非常に多く、単一のArgoCDの影響範囲がプロダクト全体に渡ってしまうため、不採用になりました。

単一のArgoCDがデプロイするべきプロダクト数が少ない状況であれば、採用する価値があります。

もし採用する場合は、ArgoCDの『Clusterスコープモード』を有効化します。

<br>

## Namespace単位

![argocd_tenant_namespace.png](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/argocd/argocd_tenant_namespace.png)

この単位では、プロダクト共有Cluster上にプロダクト別のNamespaceを作成し、それぞれのNamespace内にのみ認可スコープを持つArgoCDを動かします。

また、それぞれのNamespaceにデプロイ先ClusterごとのAppProjectを作成します。

この時のNamespaceをプロダクト別テナントの単位とします。

そのため、実Cluster単位テナントのメリットを享受しつつ、また実Clusterが増えなくてよいです。

前述の通り、私の状況ではArgoCDでデプロイしなければならないプロダクトの数が非常に多く、それぞれのArgoCDの影響範囲がプロダクトに限定できるため、**採用になりました**。

ArgoCDの『Namespacedスコープモード』を有効化します。

<br>

# 02. Namespace単位のマルチテナントの仕組み

## ここで説明すること

Namespace単位のマルチテナントを採用した場合、ArgoCD上でどのようなことが起こるのか、その仕組みとNamespacedスコープモードの設定方法を説明していきます。

なおこの仕組みを理解する上で、ArgoCDの特に "argocd-server" "application-controller" "dex-server" の責務を知る必要があります。

これらのコンポーネントついて、今回は簡単にしか説明していません😢

詳しく知りたい方は、以下の記事で全体像を紹介してますので、よろしくどうぞ🙇🏻‍♂️

[https://hiroki-hasegawa.hatenablog.jp/entry/2023/05/02/145115:embed]

<br>

## 仕組みの概要

![argocd_tenant_namespace_overview.png](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/argocd/argocd_tenant_namespace_overview.png)

ArgoCD用Clusterがあり、ここで動いているArgoCDは、dev環境とstg環境のプロダクト用Clusterにマニフェストをデプロイします。

Cluster上には、Namespace (`foo`、`bar`、`baz`) があります。

#### 【１】

各プロダクト用Clusterの管理者は、SSOでargocd-serverにログインします。

#### 【２】

argocd-serverは、各プロダクト用Clusterの管理者のApplicationの認可スコープを制御します。

なお各プロダクトのArgoCDのApplicationは、プロダクトの実行環境別のClusterに対応しています。

#### 【３】

各プロダクト用Clusterの管理者は、各Namespace上のArgoCDを介して、担当するClusterにのみマニフェストをデプロイできます。

<br>

## argocd-serverまわりの仕組み

わかりやすいように、Namespaceの`foo`のみに着目します。

まず、argocd-serverです。

Namespace単位でテナントを分割する場合、argocd-serverの『Namespacedスコープモード』を有効化します。

#### 【１】

各プロダクトCluster管理者がダッシュボード (argocd-server) にSSOを使用してログインしようとします。

#### 【２】

argocd-serverは、認証フェーズをIDプロバイダーに委譲するために、dex-serverをコールします。

#### 【３】

dex-serverは、認可リクエストを作成します。

#### 【４】

dex-serverは、前の手順で作成した認可リクエストをIDプロバイダーに送信します。

#### 【５】

IDプロバイダー側でSSOの認証フェーズを実施します。

IDプロバイダーは、コールバックURL (`<ArgoCDのドメイン名>/api/dex/callback`) を指定して、認可レスポンスを送信します。

#### 【６】

認可レスポンスは、argocd-serverを介して、dex-serverに届きます。

ConfigMap (argocd-rbac-cm) を参照し、IDプロバイダーから取得したユーザーやグループに、ArgoCD系リソースに関する認可スコープを付与します。

ここでは、developerロールにはdevというAppProjectに属するArgoCD系リソースにのみ、またmaintainerロールには全てのAppProjectの操作を許可しています。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # デフォルトのロール
  policy.default: role:readonly
  policy.csv: |
    # ロールとArgoCD系リソースの認可スコープを定義する
    p, role:foo-product, *, *, tes/*, allow
    p, role:foo-product, *, *, stg/*, allow

    # グループにロールを紐付ける
    g, developers, role:foo-product
  scopes: "[groups]"
```

<br>

## application-controllerまわりの仕組み

わかりやすいように、argocd-serverの説明と同様にNamespaceの`foo`のみに着目します。

Namespace単位でテナントを分割する場合、argocd-serverと同様にapplication-controllerの『Namespacedスコープモード』を有効化します。

<br>

# おわりに

ArgoCDにおけるマルチテナント化の設計手法とその仕組みをもりもり布教しました。

ArgoCDでマニフェストのデプロイを自動化している場合、プロダクトが多くなるにつれて、必ずと言っていいほどテナント分割は必要になってくるのでないかと思います。

ArgoCDで、どうすればテナント分割できるのかわからず困っている組織の助けになれば幸いです👍

<br>

# 謝辞

ArgoCDのマルチテナント設計にあたり、[`@toversus26`](https://twitter.com/toversus26) さんに有益なプラクティスをご教授いただきました。

この場で感謝申し上げます🙇🏻‍

<br>
