---
Title: 【Istio⛵️】IstioによるEnvoyの抽象化に抗う
---

# この記事から得られる知識

この記事を読むと、以下を **"完全に理解"** できます✌️

- Istioの通信方向に応じたトラフィック管理の仕組み
- IstioのカスタムリソースとEnvoyの設定値の対応関係

<br>

[:contents]

<br>

# 01. はじめに

どうも、**俺 a.k.a いすてぃ男**です。

![istio-icon](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio-icon.png)

<br>

Istio⛵️のサービスメッシュの不具合を調査するとき、IstioはもちろんEnvoyについても知識が必要です。

これは、IstioがEnvoyの設定値を抽象化し、開発者に代わってEnvoyを管理してくれているためです。

![istio_envoy](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy.png)

今回は、Istioの様々なEnvoyの抽象化のうち、トラフィック管理に注目します。

KubernetesリソースやIstioリソースに基づいて、IstioがEnvoyのトラフィック管理をどのように抽象化するのかを解説します。

Istioのサービスメッシュ方式には、サイドカープロキシメッシュとアンビエントメッシュ (Nodeエージェントメッシュ) があり、今回はサイドカープロキシメッシュについて言及します。

それでは、もりもり布教していきます😗

<div class="text-box">
記事中のこのボックスは、補足情報を記載しています。
<br>
<br>
飛ばしていただいても大丈夫ですが、読んでもらえるとより理解が深まるはずです👍
</div>

<br>

# 02. 様々なリソースがEnvoy抽象化に関わる

KubernetesリソースやIstioカスタムリソースの状態がEnvoy設定値に関わります。

本章では、どのようなリソースがEnvoyのトラフィック管理を抽象化しているか、通信の方向に分けて解説していきます。

ひとまず、`istio-proxy`コンテナやEnvoyまでは言及しません。

<br>

## サービスメッシュ外からの通信

サービスメッシュ外から内にリクエストを送信する場合に関わるリソースです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_ingress.png)

1. クライアントは、リクエストをサービスメッシュ外から内に送信します。
2. Istio IngressGateway Podは、リクエストを受信します。
3. Istio IngressGateway Podは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
   1. Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (VirtualService、DestinationRule) に応じて、適切な宛先Podを選択します。
   2. 宛先Podに送信します。
   3. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
4. 最終的に、宛先PodはHTTPSリクエストを受信します。

## マイクロサービス間の通信

サービスメッシュ内のPodから別のPodにリクエストを送信する場合に関わるリソースです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_service-to-service.png)

1. 送信元Podは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
   1. Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (VirtualService、DestinationRule) に応じて、適切な宛先Podを選択します。
   2. 宛先Podに送信します。
   3. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
2. 最終的に、宛先PodはHTTPSリクエストを受信します。

<br>

## サービスメッシュ外への通信

サービスメッシュ内のPodから外のシステム (例：データベース、ドメインレイヤー委譲先の外部API) にリクエストを送信する場合に関わるリソースです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_egress.png)

1. 送信元Podは、リクエストの宛先がServiceEntryでエントリ済みか否かに応じて、リクエストの宛先を切り替えます。
   1. 宛先がエントリ済みであれば、送信元Podはリクエストの宛先にIstio EgressGateway Podを選択します。
   2. 宛先が未エントリであれば、送信元Podはリクエストの宛先に外のシステムを選択します。
2. ここでは、宛先がエントリ済であったとします。送信元Podは、HTTPSリクエストの向き先をIstio EgressGateway Podに変更します。
   1. エントリ済システム宛にリクエストを送信すると、VirtualService`X`が宛先をIstio EgressGateway Podに変えます。
   2. Kubernetesリソース (Service、Endpoints) やDestinationRule`X`に応じて、適切なIstio EgressGateway Podを選択します。
   3. 宛先Podに送信します。
   4. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
3. Istio EgressGateway Podは、HTTPSリクエストを受信します。
4. Istio EgressGateway Podは、HTTPSリクエストをエントリ済システムに`L7`ロードバランシングします。
   1. Istioカスタムリソース (VirtualService、DestinationRule) に応じて、適切なエントリ済システムを選択します。
   2. エントリ済システムに送信します。
5. 最終的に、エントリ済システムはHTTPSリクエストを受信します。

<br>

# 03. Istioはリソースの状態に応じて`istio-proxy`コンテナを作成する

前章では、KubernetesリソースやIstioカスタムリソースによって抽象化されたEnvoyまで言及しませんでした。

本章では、もう少し具体化します。

Istioは、各リソースに状態に応じて、Envoyをプロセスとした`istio-proxy`コンテナを作成します。

この`istio-proxy`コンテナを使用して、Istioがどのようにトラフィックを管理しているのかを解説します。

ひとまず、Envoyの具体的な設定までは言及しません。

<br>

## サービスメッシュ外からの通信

サービスメッシュ外から内にリクエストを送信する場合の`istio-proxy`コンテナです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_ingress.png)

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. クライアントは、リクエストをサービスメッシュ外から内に送信します。
3. Istio IngressGateway Pod内の`istio-proxy`コンテナは、リクエストを受信します。
4. Istio IngressGateway Pod内の`istio-proxy`コンテナは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
5. 宛先Pod内の`istio-proxy`コンテナは、リクエストを受信します。
6. 宛先Pod内の`istio-proxy`コンテナは、HTTPリクエストを宛先マイクロサービスに送信します。
7. 宛先マイクロサービスはHTTPSリクエストを受信します。

<br>

## マイクロサービス間の通信

サービスメッシュ内のPodから別のPodにリクエストを送信する場合の`istio-proxy`コンテナです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_service-to-service.png)

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元Pod内のマイクロサービスは、`istio-proxy`コンテナにHTTPリクエストを送信します。
3. 送信元Pod内の`istio-proxy`コンテナは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
4. 宛先Pod内の`istio-proxy`コンテナは、リクエストを受信します。
5. 宛先Pod内の`istio-proxy`コンテナは、HTTPリクエストを宛先マイクロサービスに送信します。
6. 最終的に、宛先マイクロサービスはHTTPSリクエストを受信します。

<br>

## サービスメッシュ外への通信

サービスメッシュ内のPodから外のシステム (例：データベース、ドメインレイヤー委譲先の外部API) にリクエストを送信する場合の`istio-proxy`コンテナです。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_egress.png)

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元Pod内のマイクロサービスは、`istio-proxy`コンテナにHTTPリクエストを送信します。
3. 送信元Pod内の`istio-proxy`コンテナは、リクエストの宛先がServiceEntryでエントリ済みか否かに応じて、リクエストの宛先を切り替えます。
   1. 宛先がエントリ済みであれば、`istio-proxy`コンテナはリクエストの宛先にIstio EgressGateway Podを選択します。
   2. 宛先が未エントリであれば、`istio-proxy`コンテナはリクエストの宛先に外のシステムを選択します。
4. ここでは、宛先がエントリ済であったとします。送信元Pod内の`istio-proxy`コンテナは、HTTPSリクエストをIstio EgressGateway Podに`L7`ロードバランシングします。
5. Istio EgressGateway Podは、HTTPSリクエストをエントリ済システムに`L7`ロードバランシングします。
6. 最終的に、エントリ済システムはHTTPSリクエストを受信します。

<div class="text-box">
Istio EgressGatewayを使用しなくとも、サービスメッシュ外の登録済システムと通信できます。
<br>
<br>
しかし、Istio EgressGatewayを使わないと、サイドカーを経由せずにマイクロサービスから外部システムに直接リクエストを送信できるようになってしまい、システムの安全性が低くなります。
<blockquote>
<ul><li>[https:https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/#security-note]</li></ul>
</blockquote>
</div>

<br>

# 04. Istioはリソースの状態をEnvoy設定値に翻訳する

前章では、`istio-proxy`コンテナ内のEnvoy設定値まで、言及しませんでした。

本章では、もっと具体化します。

Istioが各リソースをいずれのEnvoy設定値に翻訳しているのかを解説します。

<br>

## Istioコントロールプレーン

### アーキテクチャ

Envoyを抽象化する責務を持つのは、Istioコントロールプレーンです。

ここでは、Istioコントロールプレーンは異なる責務を担う複数のレイヤーから構成されています。

![istio_envoy_istio-proxy_resource_control-plane](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_control-plane.png)

1. Istioコントロールプレーンは、リソース取得レイヤーにて、kube-apiserverからKubernetesリソースやIstioカスタムリソースの状態を取得します。
2. Envoy翻訳レイヤーにて、取得したリソースの状態をEnvoy設定値に変換します。
3. `istio-proxy`配布レイヤーにて、`istio-proxy`コンテナをPodに配布します。反対に、Podが`istio-proxy`配布レイヤーから`istio-proxy`コンテナを取得しにいくこともあります。

### 各リソースとEnvoy設定値の関係一覧

Envoyの処理の流れです。

![istio_envoy_envoy-flow](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow.png)

Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの状態をEnvoy設定値に翻訳し、処理の流れに適用します。

以下の通り、各リソースがいずれのEnvoy設定値の抽象化に関わるのかを整理しました。

- ルートに関しては、HTTPを処理する場合にのみ使用し、TCPの場合はフィルターからクラスターに至ります。
- フィルターを抽象化するリソースはEnvoyフィルターですが、フィルターのデフォルト値でも問題なく使えるので、EnvoyFilterは省略します。

<table>
<thead>
    <tr>
      <th></th>
      <th colspan="2" style="text-align: center;">Kubernetesリソース</th>
      <th colspan="5" style="text-align: center;">Istioカスタムリソース</th>
    </tr>
</thead>
<tbody>
    <tr>
      <th style="text-align: center;"><nobr>Envoy設定値</nobr></th>
      <th style="text-align: center;">Service</th>
      <th style="text-align: center;">Endpoints</th>
      <th style="text-align: center;">Gateway</th>
      <th style="text-align: center;">Virtual<br>Service</th>
      <th style="text-align: center;">Destination<br>Rule</th>
      <th style="text-align: center;">Service<br>Entry</th>
      <th style="text-align: center;">Peer<br>Authentication</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>リスナー</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>ルート</nobr><br><nobr>(HTTPのみ)</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>クラスター</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>エンドポイント</nobr></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
    </tr>
</tbody>
</table>

<br>

## サービスメッシュ外からの通信

### 抽象化に関わるリソース一覧

サービスメッシュ内のPodから外のシステム (例：データベース、ドメインレイヤー委譲先の外部API) にリクエストを送信する場合、以下のリソースが抽象化に関わります。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

<table>
<thead>
    <tr>
      <th></th>
      <th colspan="2" style="text-align: center;">Kubernetesリソース</th>
      <th colspan="5" style="text-align: center;">Istioカスタムリソース</th>
    </tr>
</thead>
<tbody>
    <tr>
      <th style="text-align: center;"><nobr>Envoy設定値</nobr></th>
      <th style="text-align: center;">Service</th>
      <th style="text-align: center;">Endpoints</th>
      <th style="text-align: center;">Gateway<br><nobr>(IngressGatewayとして)</nobr></th>
      <th style="text-align: center;">Virtual<br>Service</th>
      <th style="text-align: center;">Destination<br>Rule</th>
      <th style="text-align: center;">Service<br>Entry</th>
      <th style="text-align: center;">Peer<br>Authentication</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>リスナー</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>ルート</nobr><br><nobr>(HTTPのみ)</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>クラスター</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>エンドポイント</nobr></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
    </tr>
</tbody>
</table>

<br>

### 通信への適用

前述の表を参考に、各リソースとEnvoy設定値の関係を実際の処理の流れに適用します。

![istio_envoy_envoy-flow_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_ingress.png)

Istioは、Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (Gateway、VirtualService、DestinationRule、PeerAuthentication) を翻訳します。

以下の通り、翻訳結果をIstio IngressGateway Podやこれの宛先Podの`istio-proxy`コンテナに適用します。

- Gatewayの翻訳結果をIstio IngressGateway Podのみで使用します。
- Gateway以外のリソースの翻訳結果を、Istio IngressGateway Podと宛先Podの両方で共有します。Pod間で、関わるリソースは同じ順番です。

<br>

リソースがEnvoy設定値間で重複していてわかりにくいので、少し簡略化します。

重複を排除すると、各リソースは以下の抽象化に関わります。

![istio_envoy_istio-proxy_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_ingress.png)

<br>

## マイクロサービス間の通信

### 抽象化に関わるリソース一覧

サービスメッシュ内のPodから別のPodにリクエストを送信する場合、以下のリソースが抽象化に関わります。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

<table>
<thead>
    <tr>
      <th></th>
      <th colspan="2" style="text-align: center;">Kubernetesリソース</th>
      <th colspan="5" style="text-align: center;">Istioカスタムリソース</th>
    </tr>
</thead>
<tbody>
    <tr>
      <th style="text-align: center;"><nobr>Envoy設定値</nobr></th>
      <th style="text-align: center;">Service</th>
      <th style="text-align: center;">Endpoints</th>
      <th style="text-align: center;">Gateway</th>
      <th style="text-align: center;">Virtual<br>Service</th>
      <th style="text-align: center;">Destination<br>Rule</th>
      <th style="text-align: center;">Service<br>Entry</th>
      <th style="text-align: center;">Peer<br>Authentication</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>リスナー</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>ルート</nobr><br><nobr>(HTTPのみ)</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>クラスター</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>エンドポイント</nobr></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">×</th>
      <th style="text-align: center;"></th>
    </tr>
</tbody>
</table>

<br>

### 通信への適用

前述の表を参考に、各リソースとEnvoy設定値の関係を実際の処理の流れに適用します。

![istio_envoy_envoy-flow_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_service-to-service.png)

Istioは、Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (VirtualService、DestinationRule、PeerAuthentication) を翻訳します。

以下の通り、翻訳結果を送信元Podや宛先Podの`istio-proxy`コンテナに適用します。

- 全てのリソースの翻訳結果を、送信元Podと宛先Podの両方で共有します。Pod間で、関わるリソースは同じ順番です。

<br>

リソースがEnvoy設定値間で重複していてわかりにくいので、少し簡略化します。

重複を排除すると、各リソースは以下の抽象化に関わります。

![istio_envoy_istio-proxy_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_service-to-service.png)

<br>

## サービスメッシュ外への通信

### 抽象化に関わるリソース

サービスメッシュ内のPodから外のシステム (例：データベース、ドメインレイヤー委譲先の外部API) にリクエストを送信する場合、以下のリソースが抽象化に関わります。

なお、Pod間通信にHTTPS (相互TLS) を採用している前提です。

<table>
<thead>
    <tr>
      <th></th>
      <th colspan="2" style="text-align: center;">Kubernetesリソース</th>
      <th colspan="5" style="text-align: center;">Istioカスタムリソース</th>
    </tr>
</thead>
<tbody>
    <tr>
      <th style="text-align: center;"><nobr>Envoy設定値</nobr></th>
      <th style="text-align: center;">Service</th>
      <th style="text-align: center;">Endpoints</th>
      <th style="text-align: center;">Gateway<br><nobr>(EgressGatewayとして)</nobr></th>
      <th style="text-align: center;">Virtual<br>Service</th>
      <th style="text-align: center;">Destination<br>Rule</th>
      <th style="text-align: center;">Service<br>Entry</th>
      <th style="text-align: center;">Peer<br>Authentication</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>リスナー</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>ルート</nobr><br><nobr>(HTTPのみ)</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>クラスター</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
    </tr>
    <tr>
      <th style="text-align: center;"><nobr>エンドポイント</nobr></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
    </tr>
</tbody>
</table>

### 通信への適用

前述の表を参考に、各リソースとEnvoy設定値の関係を実際の処理の流れに適用します。

![istio_envoy_envoy-flow_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_egress.png)

Istioは、Istioカスタムリソース (Gateway、VirtualService、DestinationRule、ServiceEntry) を翻訳します。

以下の通り、翻訳結果を送信元PodやIstio EgressGateway Podの`istio-proxy`コンテナに適用します。

- Gateway、エントリ済システムの宛先リソース (VirtualService `Y`、DestinationRule` Y`、ServiceEntry) の翻訳結果をIstio EgressGateway Podのみで使用します。
- Gateway以外のリソースの翻訳結果を、Istio IngressGateway Podと宛先Podの両方で共有します。Pod間で、関わるリソースは同じ順番です。

<br>

リソースがEnvoy設定値間で重複していてわかりにくいので、少し簡略化します。

重複を排除すると、各リソースは以下の抽象化に関わります。

![istio_envoy_istio-proxy_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_egress.png)

<div class="text-box">
Istio EgressGatewayを使用しなくとも、ServiceEntryだけでサービスメッシュ外の登録済みシステムと通信できます。
<br>
<br>
しかし、前の章の注意書き同様に、Istio EgressGatewayを使わないと、サイドカーを経由せずにマイクロサービスから外部システムに直接リクエストを送信できるようになってしまい、システムの安全性が低くなります。
<blockquote>
<ul><li>[https:https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/#security-note]</li></ul>
</blockquote>
</div>

<br>

# 05. IstioによるEnvoyの抽象化に抗う

この辺になってくると、ほとんどの人にとってはどうでもよくて、自己満です!!

前章では、Envoy設定値に関わる各リソースの状態まで、言及しませんでした。

本章では、さらに具体化します。

各リソースの状態の翻訳によって、Envoyの設定値がどのようになっているのかを解説します。

なお、以下のコマンドを実行すると、`istio-proxy`コンテナのEnvoy設定値を確認できます👍

```bash
# リスナー値
$ kubectl exec \
    -it foo-pod \
    -n foo-namespace \
    -c istio-proxy \
    -- bash -c "curl http://localhost:15000/config_dump?resource={dynamic_listeners}" | yq -P
```

```bash
# ルート値
$ kubectl exec \
    -it foo-pod \
    -n foo-namespace \
    -c istio-proxy \
    -- bash -c "curl http://localhost:15000/config_dump?resource={dynamic_route_configs}" | yq -P
```

```bash
# クラスター値
$ kubectl exec \
    -it foo-pod \
    -n foo-namespace \
    -c istio-proxy \
    -- bash -c "curl http://localhost:15000/config_dump?resource={dynamic_active_clusters}" | yq -P
```

```bash
# エンドポイント値
$ kubectl exec \
    -it foo-pod \
    -n foo-namespace \
    -c istio-proxy \
    -- bash -c "curl http://localhost:15000/config_dump?include_eds" | yq -P
```

<br>

## サービスメッシュ外からの通信

![istio_envoy_envoy-flow_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_ingress.png)

書こうとすると説明が長すぎてしまうので省略します。

抽象化された後の処理の流れと見比べると、雰囲気をつかめます👍

> 1. クライアントは、リクエストをサービスメッシュ外から内に送信します。
> 2. Istio IngressGateway Podは、リクエストを受信します。
> 3. Istio IngressGateway Podは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
>    1. Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (VirtualService、DestinationRule) に応じて、適切な宛先Podを選択します。
>    2. 宛先Podに送信します。
>    3. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
> 4. 最終的に、宛先PodはHTTPSリクエストを受信します。

<br>

## マイクロサービス間の通信

![istio_envoy_envoy-flow_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_service-to-service.png)

書こうとすると説明が長すぎてしまうので省略します。

抽象化された後の処理の流れと見比べると、雰囲気をつかめます👍

> 1. 送信元Podは、HTTPSリクエストを宛先Podに`L7`ロードバランシングします。
>    1. Kubernetesリソース (Service、Endpoints) やIstioカスタムリソース (VirtualService、DestinationRule) に応じて、適切な宛先Podを選択します。
>    2. 宛先Podに送信します。
>    3. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
> 2. 最終的に、宛先PodはHTTPSリクエストを受信します。

<br>

## サービスメッシュ外への通信

![istio_envoy_envoy-flow_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_egress.png)

書こうとすると説明が長すぎてしまうので省略します。

抽象化された後の処理の流れと見比べると、雰囲気をつかめます👍

> 1. 送信元Podは、リクエストの宛先がServiceEntryでエントリ済みか否かに応じて、リクエストの宛先を切り替えます。
>    1. 宛先がエントリ済みであれば、送信元Podはリクエストの宛先にIstio EgressGateway Podを選択します。
>    2. 宛先が未エントリであれば、送信元Podはリクエストの宛先に外のシステムを選択します。
> 2. ここでは、宛先がエントリ済であったとします。送信元Podは、HTTPSリクエストの向き先をIstio EgressGateway Podに変更します。
>    1. エントリ済システム宛にリクエストを送信すると、VirtualService`X`が宛先をIstio EgressGateway Podに変えます。
>    2. Kubernetesリソース (Service、Endpoints) やDestinationRule`X`に応じて、適切なIstio EgressGateway Podを選択します。
>    3. 宛先Podに送信します。
>    4. PeerAuthenticationにより、宛先Podへの通信が相互TLSになります。
> 3. Istio EgressGateway Podは、HTTPSリクエストを受信します。
> 4. Istio EgressGateway Podは、HTTPSリクエストをエントリ済システムに`L7`ロードバランシングします。
>    1. Istioカスタムリソース (VirtualService、DestinationRule) に応じて、適切なエントリ済システムを選択します。
>    2. エントリ済システムに送信します。
> 5. 最終的に、エントリ済システムはHTTPSリクエストを受信します。

<br>

# 06. おわりに

Istioが、各リソースを使用してEnvoyをどのように抽象化してトラフィック管理を実装しているのか、を解説していきました。

今回もIstioで優勝しちゃいました😭

ただ、IstioがEnvoyをいい感じに抽象化してくれるので、開発者はEnvoyの設定を深く理解する必要はないです。

にしても、やっぱ Istio ムズいっす!!

<br>

# 参考

- Istioのトラフィック管理における通信方向の種類
  - https://www.envoyproxy.io/docs/envoy/latest/intro/deployment_types/deployment_types
- Istioコントロールプレーンのアーキテクチャとレイヤー責務
  - https://docs.google.com/document/d/1S5ygkxR1alNI8cWGG4O4iV8zp8dA6Oc23zQCvFxr83U/edit#heading=h.a1bsj2j5pan1
  - https://github.com/istio/istio/blob/master/architecture/networking/pilot.md
- IstioとEnvoyの設定値の関係
  - https://youtu.be/XAKY24b7XjQ?si=pnfA7Fnr72KY-kd-
  - https://www.slideshare.net/AspenMesh/debugging-your-debugging-tools-what-to-do-when-your-service-mesh-goes-down#19
- Envoyのエンドポイントから取得できるJSON (情報ちょっと古いかもしれないけど)
  - https://github.com/zhaohuabing/bookinfo-bookinfo-config-dump/blob/master/reviews-config-dump
- Envoyプロセスのリクエスト処理の流れ
  - www.amazon.co.jp/dp/B09XN9RDY1
  - https://www.zhaohuabing.com/post/2018-09-25-istio-traffic-management-impl-intro/
- HTTPの処理に関係するネットワークフィルターやHTTPフィルター
  - https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/http_connection_management
  - https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter
- Istio IngressGatewayの仕組み
  - https://software.danielwatrous.com/istio-ingress-vs-kubernetes-ingress/
- Istio EgressGatewayの仕組み
  - https://reitsma.io/blog/using-istio-to-mitm-our-users-traffic
  - https://discuss.istio.io/t/ingress-egress-serviceentry-data-flow-issues-for-istio-api-gateway/14202
  - https://discuss.istio.io/t/fail-to-apply-virtualservice-and-gateway-to-egress-gateway-on-port-80/3161
- Istioの相互TLSについて
  - https://jimmysong.io/en/blog/understanding-the-tls-encryption-in-istio/
  - https://jimmysong.io/en/blog/istio-certificates-management/
- IstioのSSL証明書の配布について
  - https://www.zhaohuabing.com/post/2020-05-25-istio-certificate/

<br>
