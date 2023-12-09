---
Title: 【Istio⛵️】IstioがEnvoyのトラフィック管理を抽象化する仕組み
---

# 01. はじめに

<br>

Istioは、マイクロサービスアーキテクチャ上にサービスメッシュを実装するツールです。

サービスメッシュを実装するために、IstioはEnvoyの様々な機能を抽象化し、KubernetesリソースやIstioカスタムリソースでEnvoyを設定できるようにします。

今回は、Istioのトラフィック管理機能に注目し、Envoyをどのように抽象化しているのかを解説しようと思います👍

なお、Istioのサービスメッシュ方式には、サイドカープロキシメッシュとアンビエントメッシュ (Nodeエージェントメッシュ) があり、今回はサイドカープロキシメッシュについて言及します。

<br>

# 02. Istioのトラフィック管理の種類

IstioはEnvoyを使用してトラフィックを管理します。

Istioによるトラフィック管理は、通信方向の観点で3つの種類に分類できます。

<br>

## サービスメッシュ外からの通信

サービスメッシュ外からリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. クライアントは、リクエストをサービスメッシュ外から内に送信します。
3. Istio IngressGateway Podの`istio-proxy`コンテナは、リクエストを受信します。
4. Istio IngressGateway Podの`istio-proxy`コンテナは、HTTPSでリクエストを宛先マイクロサービス Pod (例：API Gateway相当のマイクロサービス) に送信します。
5. マイクロサービスPodの`istio-proxy`コンテナは、リクエストを受信します。
6. マイクロサービスPodの`istio-proxy`コンテナは、HTTPでリクエストを宛先マイクロサービスに送信します。

![istio_envoy_istio_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_ingress.png)

<br>

## マイクロサービス間の通信

マイクロサービスPodから別のマイクロサービスPodにリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元マイクロサービスは、`istio-proxy`コンテナにHTTPでリクエストを送信します。
3. 送信元マイクロサービスPodの`istio-proxy`コンテナは、HTTPSでリクエストを宛先マイクロサービスPodに送信します。
4. 宛先マイクロサービスPodの`istio-proxy`コンテナは、リクエストを受信します。
5. 宛先マイクロサービスPodの`istio-proxy`コンテナは、HTTPでリクエストを宛先マイクロサービスに送信します。

![istio_envoy_istio_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_service-to-service.png)

<br>

## サービスメッシュ外への通信

マイクロサービスPodからサービスメッシュ外にリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元マイクロサービスは、`istio-proxy`コンテナにHTTPでリクエストを送信します。送信元マイクロサービスはSSL証明書を持たないため、HTTPです。
3. 送信元マイクロサービスPodの`istio-proxy`コンテナは、リクエストの宛先がエントリ済みか否かに応じて、リクエストの宛先を切り替えます。
   1. 宛先がエントリ済みであれば、`istio-proxy`コンテナはリクエストの宛先にIstio EgressGateway Podを選択します。
   2. 宛先が未エントリであれば、`istio-proxy`コンテナはリクエストの宛先にサービスメッシュ外を選択します。
4. 選択した宛先にHTTPSでリクエストを送信します。

![istio_envoy_istio_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_egress.png)

<br>

# 03. トラフィック管理を宣言するためのリソース

## サービスメッシュ外からの通信

サービスメッシュ外からリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. クライアントは、リクエストをサービスメッシュ外から内に送信します。
3. Istio IngressGateway Podの`istio-proxy`コンテナは、リクエストを受信します。
4. Istio IngressGateway Podの`istio-proxy`コンテナは、HTTPSでリクエストを宛先マイクロサービス Pod (例：API Gateway相当のマイクロサービス) に送信します。
5. マイクロサービスPodの`istio-proxy`コンテナは、リクエストを受信します。
6. マイクロサービスPodの`istio-proxy`コンテナは、HTTPでリクエストを宛先マイクロサービスに送信します。

![istio_envoy_istio_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_ingress.png)

## マイクロサービス間の通信

マイクロサービスPodから別のマイクロサービスPodにリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_service-to-service.png)

## サービスメッシュ外への通信

マイクロサービスPodからサービスメッシュ外にリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_egress.png)

# 04. リソースとEnvoyの関係性

<br>

## Istioコントロールプレーン

### 仕組み

Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースを取得して、Envoyの設定値に翻訳します。

仕組みを簡単に解説します。

1. Istioコントロールプレーンは、リソース取得レイヤーにて、kube-apiserverからKubernetesリソースやIstioカスタムリソースの状態を取得します。
2. Envoy翻訳レイヤーにて、取得したリソースの状態をEnvoyの設定値に変換します。
3. `istio-proxy`配布レイヤーにて、`istio-proxy`コンテナをマイクロサービスPodに配布します。反対に、マイクロサービスPodが`istio-proxy`配布レイヤーから`istio-proxy`コンテナを取得しにいくこともあります。

![istio_envoy_istio-proxy_resource_control-plane](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_control-plane.png)

### リソースとEnvoyの翻訳関係

Istioコントロールプレーンは、Envoy翻訳レイヤーにて、KubernetesリソースやIstioカスタムリソースをEnvoyの設定値に翻訳します。

以下は、翻訳の対応関係です。

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
      <th style="text-align: center;"><nobr>Envoyの設定値</nobr></th>
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
      <th style="text-align: center;"><nobr>ルート</nobr></th>
      <th style="text-align: center;">✅</th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;"></th>
      <th style="text-align: center;">✅ <br />(HTTPの場合のみ) </th>
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

### 概要

マイクロサービスPodからサービスメッシュ外にリクエストを送信する場合です。

送信側と宛先側の`istio-proxy`コンテナで、いずれのリソースが関係するのかを整理しました。

Gatewayのみ送信側`istio-proxy`コンテナに関係します。

送信側と宛先側の`istio-proxy`コンテナの間で、Gateway以外は同じリソースが関係します。

![istio_envoy_istio-proxy_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_ingress.png)

### 詳細

![istio_envoy_envoy-flow_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_ingress.png)

<br>

## マイクロサービス間の通信

### 概要

マイクロサービスPodからサービスメッシュ外にリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio-proxy_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_service-to-service.png)

### 詳細

![istio_envoy_envoy-flow_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_service-to-service.png)

<br>

## サービスメッシュ外への通信

### 概要

マイクロサービスPodからサービスメッシュ外にリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

![istio_envoy_istio-proxy_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio-proxy_resource_egress.png)

### 詳細

![istio_envoy_envoy-flow_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_egress.png)

# 05. IstioによるEnvoyの抽象化に抗う

Envoyはどのようにリクエストを処理するのでしょうか。

HTTPまたはTCPを処理する場合で、処理の流れが少しだけ異なります。

今回は、HTTPを処理する場合のみ注目します。

具体的な値を見ながら解説していきます。

<br>

## サービスメッシュ外からの通信

Istio IngressGateway Pod内の`istio-proxy`コンテナは、KubernetesリソースやIstioカスタムリソースの設定に応じて、リクエストの宛先Podを選択します。

![istio_envoy_envoy-flow_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_ingress.png)

## マイクロサービス間の通信

送信元マイクロサービスPodの`istio-proxy`コンテナは、KubernetesリソースやIstioカスタムリソースの設定に応じて、リクエストの宛先Podを選択します。

![istio_envoy_envoy-flow_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_service-to-service.png)

## サービスメッシュ外への通信

1. `istio-proxy`コンテナは、リクエストの宛先がエントリ済みか否かに応じて、リクエストを宛先を切り替えます。
   1. 宛先がエントリ済みであれば、`istio-proxy`コンテナはリクエストの宛先にIstio EgressGateway Podを選択します。
   2. 宛先が未エントリであれば、`istio-proxy`コンテナはリクエストの宛先にサービスメッシュ外 (`PassthrouCluster`) を選択します。

![istio_envoy_envoy-flow_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_egress.png)
