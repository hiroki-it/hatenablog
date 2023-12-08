---
Title: 【Istio⛵️】IstioがEnvoyのトラフィック管理を抽象化する仕組み
---

# 01. はじめに

<br>

Istioは、マイクロサービスアーキテクチャ上にサービスメッシュを実装するツールです。

サービスメッシュを実装するために、IstioはEnvoyの様々な機能を抽象化し、カスタムリソースでEnvoyを設定できるようにします。

今回は、Istioのトラフィック管理機能に注目し、Envoyをどのように抽象化しているのかを解説しようと思います👍

なお、Istioのサービスメッシュ方式には、サイドカープロキシメッシュとアンビエントメッシュ (Nodeエージェントメッシュ) があり、今回はサイドカープロキシメッシュについて言及します。

<br>

# 02. Istioのトラフィック管理の種類

IstioはEnvoyを使用してトラフィックを管理します。

Istioによるトラフィック管理は、通信方向の観点で3つの種類に分類できます。

## サービスメッシュ外からの通信

サービスメッシュ外からリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. クライアントは、サービスメッシュ外から内にリクエストを送信します。
3. KubernetesCluster内に入ったリクエストは、Istio IngressGatewayのPodに到達します。
4.
5. `istio-proxy`コンテナは、マイクロサービス (例：API Gateway相当のマイクロサービス) のPodにリクエストを送信します。

![istio_envoy_istio_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_ingress.png)

## マイクロサービス間の通信

マイクロサービスのPodから別のマイクロサービスのPodにリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元マイクロサービスは、`istio-proxy`コンテナにHTTPでリクエストを送信します。
3. 送信元マイクロサービスPodの`istio-proxy`コンテナは、別のマイクロサービスのPodにHTTPSでリクエストを送信します。
4. 宛先マイクロサービスPodの`istio-proxy`コンテナは、宛先マイクロサービスにHTTPでリクエストを送信します。

![istio_envoy_istio_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_service-to-service.png)

## サービスメッシュ外への通信

マイクロサービスのPodからサービスメッシュ外にリクエストを送信する場合です。

なお、HTTPS (相互TLS) を採用している前提です。

1. Istioコントロールプレーンは、KubernetesリソースやIstioカスタムリソースの設定を各Pod内の`istio-proxy`コンテナに提供します。
2. 送信元マイクロサービスは、`istio-proxy`コンテナにHTTPでリクエストを送信します。送信元マイクロサービスはSSL証明書を持たないため、HTTPです。
3. `3`で選択した宛先にHTTPSでリクエストを送信します。

![istio_envoy_istio_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_egress.png)

# 03. トラフィック管理を宣言するためのリソース

## サービスメッシュ外からの通信

![istio_envoy_istio_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_ingress.png)

## マイクロサービス間の通信

![istio_envoy_istio_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_service-to-service.png)

## サービスメッシュ外への通信

![istio_envoy_istio_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_egress.png)

# 04. リソースとEnvoyの関係性

|                  | Kubernetes<br> Service | Kubernetes<br> Endpoints | Istio<br> Gateway | Istio<br> VirtualService | Istio<br>DestinationRule | Istio<br> ServiceEntry | Istio<br> PeerAuthentication |
| ---------------- | ---------------------- | ------------------------ | ----------------- | ------------------------ | ------------------------ | ---------------------- | ---------------------------- |
| リスナー値       | ✅                     |                          | ✅                | ✅                       |                          |                        | ✅                           |
| ルート値         | ✅                     |                          |                   | ✅<br>(HTTPの場合のみ)   |                          |                        |                              |
| クラスター値     | ✅                     |                          |                   |                          | ✅                       | ✅                     | ✅                           |
| エンドポイント値 |                        | ✅                       |                   |                          | ✅                       | ✅                     |                              |

<br>

## サービスメッシュ外からの通信

![istio_envoy_envoy-flow_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_ingress.png)

## マイクロサービス間の通信

![istio_envoy_envoy-flow_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_service-to-service.png)

## サービスメッシュ外への通信

![istio_envoy_envoy-flow_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_egress.png)

# 05. IstioによるEnvoyの抽象化に抗う

Envoyはどのようにリクエストを処理するのでしょうか。

HTTPまたはTCPを処理する場合で、処理の流れが少しだけ異なります。

今回は、HTTPを処理する場合のみ注目します。

具体的な値を見ながら解説していきます。

<br>

## サービスメッシュ外からの通信

Istio IngressGatewayのPod内の`istio-proxy`コンテナは、KubernetesリソースやIstioカスタムリソースの設定に応じて、リクエストの宛先のPodを選択します。

![istio_envoy_envoy-flow_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_ingress.png)

## マイクロサービス間の通信

送信元マイクロサービスPodの`istio-proxy`コンテナは、KubernetesリソースやIstioカスタムリソースの設定に応じて、リクエストの宛先のPodを選択します。

![istio_envoy_envoy-flow_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_service-to-service.png)

## サービスメッシュ外への通信

1. `istio-proxy`コンテナは、リクエストの宛先がエントリ済みか否かに応じて、リクエストを宛先を切り替えます。
   1. 宛先がエントリ済みであれば、`istio-proxy`コンテナはリクエストの宛先にIstio EgressGatewayのPodを選択します。
   2. 宛先が未エントリであれば、`istio-proxy`コンテナはリクエストの宛先にサービスメッシュ外 (`PassthrouCluster`) を選択します。

![istio_envoy_envoy-flow_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_egress.png)
