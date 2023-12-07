---
Title: 【Istio⛵️】Envoyの設定を抽象化するIstioのカスタムリソース
---

# 01. はじめに

<br>

サービスメッシュを使用したマイクロサービスアーキテクチャでは、マイクロサービス間通信の不具合がよく起こります。

例えば、Istioによるマイクロサービス間通信で不具合が起こった場合には、Istioカスタムリソースを参考にトラブルシューティングします。

しかし実際は、Istioに抽象化されたEnvoyがマイクロサービス間通信を処理しています。

この時、Istioカスタムリソースについてだけではなく、Envoyの設定値との関係性を理解している必要があると感じています。

そこで今回、マイクロサービス間通信に関するEnvoyの設定値とIstioカスタムリソースの関係を整理しました。

# 02. Istioによるマイクロサービス間通信

まずは、Istioによる通信を簡単に紹介します。

Istioによる通信は、2つの種類に分類できます。



2つ目は、マイクロサービス間通信です。



![istio_envoy_istio_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_ingress.png)



![istio_envoy_istio_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_service-to-service.png)

![istio_envoy_istio_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_egress.png)


# 03. マイクロサービス間通信を制御するカスタムリソースたち

Istioを使用したマイクロサービス間通信にどのようなIstioカスタムリソースが関係しているのかを見ていきましょう。

![istio_envoy_istio_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_ingress.png)

![istio_envoy_istio_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_service-to-service.png)

![istio_envoy_istio_resource_egress_resource](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_istio_resource_egress.png)


# 04. Envoyの処理の流れ

Envoyはどのようにリクエストを処理するのでしょうか。

HTTPまたはTCPを処理する場合で、処理の流れが少しだけ異なります。

今回は、HTTPを処理する場合のみ注目します。

![istio_envoy_envoy-flow_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_ingress.png)

# 05. Envoyの設定値とIstioのカスタムリソースの関係

![istio_envoy_envoy-flow_resource_ingress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_ingress.png)

![istio_envoy_envoy-flow_resource_service-to-service](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_service-to-service.png)

![istio_envoy_envoy-flow_resource_egress](https://raw.githubusercontent.com/hiroki-it/tech-notebook-images/master/images/drawio/blog/istio/istio_envoy_envoy-flow_resource_egress.png)
