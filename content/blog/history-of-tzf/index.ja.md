---
author: ringsaturn
authorTwitter: ringsaturn_me
cover:
  image: https://blog-assets.ringsaturn.me/pic/tzf-post-cover.webp
date: '2023-01-31'
description: tzf の進化の過程を紹介。最初の Go 実装から始まり、後に Python 拡張、現在の Rust 実装、そして PyO3 によるラッパーに至るまでの流れを説明する。
math: true
post_pdf_url: https://blog-assets.ringsaturn.me/pdf/2023-01-31-history-of-tzf.ja.pdf
summary: tzf の進化の過程を紹介。最初の Go 実装から始まり、後に Python 拡張、現在の Rust 実装、そして PyO3 によるラッパーに至るまでの流れを説明する。
tags:
- Python
- Go
- Geo
- Timezone
- Rust
- PyO3
- Geometry
- Caiyun
- tzf
- tzfpy
- tzf-rs
title: tzf の進化プロセス
toc: true
updated: '2025-04-29'
---

tzf および関連プロジェクトの基礎開発作業はほぼ安定しており、これまでの記事で開発・設計の断片的な記録が残っています：

- 2022-05-29,
  [在 Go 中将经纬度转时区](https://blog.ringsaturn.me/posts/timezone-go/)
- 2022-08-01,
  [Python 中经纬度转时区新的选择](https://blog.ringsaturn.me/posts/tzfpy/)
- 2022-08-27,
  [用 Go 编写 Python 扩展](https://blog.ringsaturn.me/posts/py-ext-go/)
- 2022-09-10,
  [tzf 预览图制作](https://blog.ringsaturn.me/posts/tzf-social-media/)
- 2022-11-24,
  [tzfpy Rust 重写](https://blog.ringsaturn.me/posts/tzfpy-tzfpy-rust/)

本記事は最終まとめとして、プロジェクトの立ち上げから最適化・進化の過程を辿ります。

---

現在使用している経緯度 → タイムゾーン変換ライブラリは [timezonefinder](https://github.com/jannikmi/timezonefinder) ですが、多角形の境界付近のクエリが遅く、以前のバージョンでは 200ms ～ 800ms を要していました。 [timezonefinder@6.1.0](https://github.com/jannikmi/timezonefinder/blob/master/CHANGELOG.rst#610-2022-08-15) で C 実装の Ray Cast アルゴリズムに切り替わったものの、依然として最速・最遅の差が大きいため、独自に経緯度 → タイムゾーン変換パッケージを開発することにしました。

以前の [行政区画データ処理][lnglat2adcode] で Point in Polygon 問題や Ray Casting アルゴリズムを学んでいたため、あとはタイムゾーンのポリゴンデータをどこから取るかが課題でした。オープンソースコミュニティのおかげで、[@evansiroky](https://github.com/evansiroky) 氏がメンテナンスする [timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder) が IANA の [Timezone Database](https://www.iana.org/time-zones) の更新に合わせて GeoJSON／ShapeFile を公開しており、ODbL ライセンスの下で利用可能です。

[lnglat2adcode]: https://blog.ringsaturn.me/posts/geo-computing-2/

GeoJSON を処理に採用しましたが、圧縮サイズ 45MB、展開後 155MB はプロジェクトには大きすぎるため、まずデータ量を削減する必要がありました。

最も簡単なアプローチは、より効率的なバイナリエンコード形式に変換することです。チームは Protocol Buffers に慣れていたため、[`tzinfo.proto`][tzpb] を作成しました。GeoJSON の [RFC 7946][rfc7946] 定義では、Polygon は外側輪郭と内側の穴を含むため、Protocol Buffers で表現するにはネストされた`repeated`が必要ですが未サポートなので、以下のように分割しています：

```proto
message Point {
  float lng = 1;
  float lat = 2;
}

message Polygon {
  repeated Point points = 1;
  repeated Polygon holes = 2;
}

message Timezone {
  repeated Polygon polygons = 1;
  string name = 2;
}

message Timezones {
  repeated Timezone timezones = 1;
}
```

[tzpb]: https://github.com/ringsaturn/tzf/blob/main/pb/tzf/v1/tzinfo.proto
[rfc7946]: https://www.rfc-editor.org/rfc/rfc7946

この変換で約 80MB 削減できましたが、完全ロードすると約 900MB を要し、まだ大きいためさらなる削減が必要です。GeoJSON の座標を見ると点間隔が細かいため、実ビジネスには不要な精度があります。まずは座標点数を減らす最適化を行いました。

多角形の点を効果的に減らすには、[Ramer–Douglas–Peucker algorithm](https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm) が一般的です：

![The effect of varying epsilon in a parametric implementation of RDP, [source](https://en.wikipedia.org/wiki/File:RDP,_varying_epsilon.gif)](https://blog-assets.ringsaturn.me/pic/RDP_varying_epsilon.gif)

このフィルタリングにより、バイナリサイズは 11MB まで縮小しました。

しかし 11MB のバイナリでも配布にはやや大きいため、座標データ圧縮方式を調査したところ、Google Maps の [Polyline] アルゴリズムが適していました。最初の点を除き各点を前点との差分で表現し、ビット演算で ASCII にエンコードします。これで最終的に 4.6MB に圧縮でき、バイナリ配布に非常に適したサイズになりました。

[polyline]: https://developers.google.com/maps/documentation/utilities/polylinealgorithm

ここまでで実用レベルのタイムゾーンライブラリが完成し、クエリ性能は timezonefinder をわずかに上回りました。しかし高並行の環境下ではさらに高速化が望まれます。Ray casting は $O(n^2)$ の計算量であるため、実行頻度を極力減らすための索引機構が必要でした。

行政区画処理の経験から RTree を検討しましたが、グローバルデータでは効果が薄く、その理由は：

1. タイムゾーン数は数百程度で、行政区画の数千に比べて少ないため、静的言語では全走査でも大きな負荷にならない。
2. 多角形サイズの差が大きく、検索範囲を狭めると大きなゾーンがヒットせず、広げると走査削減に寄与しない。

したがって RTree は不適と判断しました。

ではどのように索引を構築するか？10 月末に、地図タイル（QuadTree）を使った[気象観測所データ検索方式を応用できないかと考えました][geo-computing-1]。QuadTree では親タイルが 4 つの子タイルを完全に包含するため、小タイルの集合で形状を近似でき、隙間も発生しません。

[geo-computing-1]: https://blog.ringsaturn.me/posts/geo-computing-1/

```txt
┌───────────┬───────────┬───────────┐
│           │           │           │
│           │           │           │
│ x-1,y-1,z │ x+0,y-1,z │ x+1,y-1,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+0,z │ x+0,y+0,z │ x+1,y+0,z │
│           │           │           │
│           │           │           │
├───────────┼───────────┼───────────┤
│           │           │           │
│           │           │           │
│ x-1,y+1,z │ x+0,y+1,z │ x+1,y+1,z │
│           │           │           │
│           │           │           │
└───────────┴───────────┴───────────┘
```

驚くべきことに、形状情報を十分に表現できることが確認できました：

![](https://blog-assets.ringsaturn.me/pic/geo-computing/preindex-timezone-preview-we.webp)

---

最初は Go で実装し、MIT ライセンスで [tzf](https://github.com/ringsaturn/tzf) として公開しました。前述のデータ変換、容量削減、圧縮、索引構築はすべてコマンドラインツールとして [tzf/cmd] に置き、生成したバイナリは Go の `embed` 機能で [tzf-rel] から配布しています。

[tzf/cmd]: https://github.com/ringsaturn/tzf/tree/main/cmd
[tzf-rel]: https://github.com/ringsaturn/tzf-rel

Go 実装が安定したあと、CGO で `.so` を生成して Python から呼び出せるようにしました。 [cibuildwheel] を使って各プラットフォームの wheel をビルドし、インストール時の再コンパイルを回避しています。基本的には問題ありませんでしたが、返却オブジェクトの手動解放を怠るとメモリリークが発生する [tzf#63] ことが分かりました。Python 側で CGO の GC を呼び出すと、一部ケースで実行速度が約 2 倍に遅くなるため、よりエレガントな解決策を模索しました。

[cibuildwheel]: https://github.com/pypa/cibuildwheel
[tzf#63]: https://github.com/ringsaturn/tzf/pull/63

そこで Rust に目を向け、[PyO3] と [Maturin] という強力なツールを使えば手動解放不要な Python パッケージを生成でき、ベンチマークでも CPU 集約型で Go より高速でした。

[PyO3]: https://github.com/PyO3/pyo3
[Maturin]: https://github.com/PyO3/maturin

Rust 版ではまずデータロード、地図索引構築、多角形検索などを実装しました。 [georust/geo] が豊富なジオ演算機能を提供してくれたおかげでスムーズに進みました。

[georust/geo]: https://github.com/georust/geo

しかしタイムゾーンデータ処理では約 1,700,000ns を要し、Go 実装の約 12,000ns に比して 100 倍近く遅いことが判明。これはアルゴリズム実装の効率によると考え、Rust コンパイラの警告を受けて一晩かけて調査したところ、ポイント列を生成時に`to_owned`していたことがボトルネックだと判明しました。数百万点をコピーする代わりにポインタ参照に変更したところ、約 30,000ns まで一気に改善。Go 版では多角形内部にさらにプリインデックスを構築しているため多少遅くなるものの、許容範囲となりました。

パフォーマンス安定後、PyO3 で Python ライブラリ [tzfpy] にラップ。lazy init でグローバル Finder を初期化する方式を採用し、初回呼び出しは遅いものの以降は高速となっています。

[tzfpy]: https://github.com/ringsaturn/tzfpy

```bash
pip install tzfpy
```

```python
>>> from tzfpy import get_tz
>>> print(get_tz(116.3883, 39.9289))
```

なお現状 tzf-rs/tzfpy は Polyline 圧縮済みデータをまだ使用していませんが、今後切り替えてさらにバイナリサイズを削減する予定です。
