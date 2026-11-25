# Mifjpn-PT-Clouds

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Minecraft](https://img.shields.io/badge/Minecraft-1.20%20--%2026.x-brightgreen.svg)](https://www.minecraft.net/)
[![Mod Loader](https://img.shields.io/badge/Iris%20%2B%20Sodium-Required-orange.svg)](https://irisshaders.dev/)

Clean-room, MIT-licensed screen-space path-traced shader pack for **Minecraft Java Edition (1.20 – 26.x)** running on **Iris + Sodium** — **Spherical Dual-Layer Cloud & Clear-Sky Edition**.

`Mifjpn-PT-Clouds` is an atmospheric derivative of **Mifjpn-PT**. It introduces a 100% procedural 32 km spherical dual-layer cloud and sky engine without relying on external binary noise textures, while keeping path-traced global illumination (SSPT GI) fast by evaluating lightweight low-cloud projections on indirect bounces.

---

## Atmospheric & Dual-Layer Cloud Architecture

- **Crisp Cerulean-Cobalt Spherical Sky**
  - Analytical Chapman airmass integration with reduced clear-air Mie aerosol turbidity and enriched stratospheric ozone (Chappuis-band) absorption, preserving vivid cobalt-to-cerulean zenith blues and clean pale-cyan horizons.
- **High-Altitude Ice-Crystal Veil (`2,900 m` Spherical Shell)**
  - Combines gossamer, jet-stream-sheared **Cirrostratus** filaments with fine-grained cellular **Cirrocumulus** ripples.
  - Features dual-lobe ice-crystal forward scattering and solar elevation offset so high clouds catch warm coral and amber afterglow after low cumulus decks fall into shadow.
- **Low-Altitude Convective Cumulus (`768 m` Default Base, up to `1,280 m`)**
  - **Discrete Bénard-Cell Placement**: Generates rounded, independent fair-weather cumulus puffs (*Cumulus humilis* to *congestus*) separated by wide corridors of open sky across a 32 km curved horizon.
  - **Sculpted Multi-Scattered Shading**: Perlin-Worley cauliflower crowns with curl-warped edge erosion, crisp sunlit tops, cool slate-blue shaded bellies, Rayleigh/Mie aerial perspective, and physical camera wake interaction (`CLOUD_INTERACTION`).

## Core Rendering Pipeline (from Mifjpn-PT)

- **Screen-Space Path-Traced GI & Temporal Variance Denoiser**: R2 quasirandom cosine-hemisphere sampling with branchless Pixar ONB, 1-bounce color bleeding, moment clamping, and edge-preserving spatial filtering.
- **High-Contrast Direct Lighting & Crisp Shadows**:
  - Full **Minecraft 26.x (Reversed-Z / Zero-to-One)** shadow pipeline compatibility (`shadow.culling=false`, `shadowPlayer=true`, and full-opacity shadow blocking for `entityTranslucent` player skins, 3D skin layers, and armor).
  - **10-Step Screen-Space Contact Shadows (`CONTACT_SHADOWS`)** and physical penumbra PCF filtering, plus colored translucent glass shadows and water-column absorption tags.
- **LabPBR 1.3 Material Pipeline**: Height-correlated Smith-GGX specular BRDF, conductor F0 presets, subsurface scattering (`PBR_SSS`), Parallax Occlusion Mapping (`POM`), and automatic luma-gradient normal generation for vanilla textures.
- **28-Band Ocean Optics**: Jacobian-advected wave spectrum, exact unpolarized dielectric Fresnel reflectance, Beer-Lambert spectral water absorption, and Hessian wave-focusing underwater caustics.
- **Dimension Atmospheres**: Volumetric Nether soot, glowing magma crust, and updraft embers; End domain-warped nebula, solar eclipse corona, and 3D void mist sea.
- **Filmic Color & Auto-Exposure**: Open-Toe Filmic tone mapping paired with snow-compensated auto-exposure.
- **Localization**: Complete **English (`en_us`)** and **Japanese (`ja_jp`)** shader option menus.

## Requirements & Installation

1. Install **Sodium** and **Iris Shaders** for Minecraft Java Edition `1.20` – `26.x`.
2. Download `Mifjpn-PT-Clouds.zip` from [Releases](../../releases) (or the repository root) and place it directly into `.minecraft/shaderpacks/` (do not extract).
3. In Minecraft, open **Options → Video Settings → Shader Packs** and select `Mifjpn-PT-Clouds.zip`.

## Mod Compatibility

- **Distant Horizons**: Native远景 (LOD) G-Buffer integration.
- **Physics Mod Pro**: Native **Ocean Physics (Ocean v3)** vertex/fragment hook support in water passes.
  - *Note for Minecraft 26.3*: If entity or terrain shadows disappear when using Physics Mod, set **Options → Physics Settings → Smoke** to **Off** (Ocean Physics can remain enabled).

## Key Cloud Options (`Shader Pack Settings → Clouds`)

| Option | Macro | Default | Range | Description |
| :--- | :--- | :---: | :---: | :--- |
| **Cloud Coverage** | `CLOUD_COVERAGE` | `0.44` | `0.15 – 0.85` | Horizontal coverage of low convective cumulus |
| **Cloud Altitude** | `CLOUD_ALTITUDE` | `768.0` | `192 – 1280` | Condensation base height (m) of low cumulus |
| **Cloud Thickness** | `CLOUD_THICKNESS` | `260.0` | `110 – 440` | Vertical thickness (m) of cumulus towers |
| **Low Cloud Scale** | `CLOUD_SCALE` | `1.00` | `0.60 – 2.00` | Horizontal/vertical parcel size multiplier |
| **High Cloud Toggle** | `CLOUD_CIRRUS` | `ON` | `ON / OFF` | Enables high-altitude Cirrostratus & Cirrocumulus |
| **High Cloud Coverage** | `CLOUD_HIGH_COVERAGE` | `0.58` | `0.00 – 1.00` | Sky coverage of high ice-crystal cloud sheets |
| **High Cloud Opacity** | `CLOUD_HIGH_DENSITY` | `1.00` | `0.25 – 2.00` | Optical thickness of high-altitude clouds |

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for full text.

---

# Mifjpn-PT-Clouds（日本語ガイド）

**Minecraft Java Edition (1.20 – 26.x / Iris + Sodium)** 向けにフルスクラッチで設計・実装された、MITライセンスのスクリーンスペース・パストレーシングシェーダーパック **「球殻二層クラウド ＆ 快晴大気エディション」** です。

本パックは **Mifjpn-PT** をベースに、外部バイナリ3Dテクスチャを一切使用しない100%プロシージャル実装の **32km 球殻二層クラウドエンジン（高層雲＋低層積雲）** を搭載した派生版です。パストレーシング間接光（SSPT GI）側の雲評価は軽量な低層投影のまま維持し、描画負荷を抑えながら圧倒的な空の抜けと奥行きを両立しています。

---

## 大気・二層クラウドの特徴

- **オゾン帯吸収を強化した澄んだ青空**
  - チャップマン気柱近似による球面大気散乱をベースに、晴天時のエアロゾル（Mie）白濁を抑え、成層圏オゾン（Chappuis帯）の吸収を強化。中天から天頂にかけての深いセルリアン〜コバルトブルーと、水平線へすっと抜ける淡いシアンのグラデーションを再現します。
- **高層雲：巻層雲ベール ＆ 波状巻積雲（高度 `2,900 m` 球殻）**
  - ジェット気流のシアーで伸びる繊細な繊維状の**巻層雲（Cirrostratus）**と、2Dセルラーノイズによる細粒の**うろこ雲（Cirrocumulus）**を合成。
  - 氷晶の前方散乱と太陽高度オフセットにより、日没後に低層雲が日陰に入ったあとも高層雲だけが茜色・珊瑚色に残照します。
- **低層雲：独立対流セル積雲（既定雲底 `768 m`・最大 `1,280 m`）**
  - **対流セル（Bénard Cell）配置**: 雲が一枚岩のシートにならず、丸みのある独立した綿雲（並雲）が心地よい青空の間隔を保ちながら 32km 先の水平線まで点在します。
  - **立体的な雲底陰影と遠景霞**: Perlin-Worley によるカリフラワー状の純白ドーム、引き締まったスレートブルーの雲底陰影、遠方の雲が水平線へ溶け込む大気遠近法（Aerial Perspective）、および飛行時に雲をかき分ける航跡インタラクション（`CLOUD_INTERACTION`）を備えています。

## コアレンダリング機能（Mifjpn-PT 共通）

- **スクリーンスペース・パストレーシング GI ＆ 時間軸分散デノイザー**: R2準乱数と分岐なし Pixar 直交基底による半球サンプリング、日向から日陰への1バウンス色滲み、モーメントクランプ付き時間軸蓄積を実装。
- **高精細シャドウ ＆ 接触影（Minecraft 26.x 完全対応）**:
  - MC 26.2 / 26.3 の Reversed-Z クリップ空間に対応（`shadow.culling=false`・一人称自キャラ影 `shadowPlayer=true`・プレイヤースキンや3Dスキンレイヤー／防具の完全遮光化）。
  - **10ステップ・スクリーンスペース接触影（`CONTACT_SHADOWS`）**、物理スケール連動PCFフィルタ、ステンドグラス色透過影、水中光路減衰を搭載。
- **LabPBR 1.3 物理ベースマテリアル**: 高度相関 Smith-GGX 鏡面BRDF、金属F0プリセット、表面下散乱（`PBR_SSS`）、視差オクルージョンマッピング（`POM`）、バニラテクスチャ向け自動法線生成に対応。
- **28バンド海洋波浪 ＆ 水中光学**: ヤコビアン移流による28波合成スペクトル、厳密フレネル反射、ランベルト・ベール分光吸収、ヘッセ行列式による水底コースティクス。
- **ネザー・ジ・エンド専用3D大気**: ネザーの3D煤煙・溶岩地殻・火の粉、ジ・エンドのドメインワープ星雲・皆既日食コロナ・奈落の3D雲海を収録。
- **Open-Toe Filmic トーンマップ ＆ 雪景色補正付き自動露出**: 暗部の黒潰れと高アルベド雪原の白飛びを同時に抑制。
- **日本語メニュー完備**: 日本語（`ja_jp`）・英語（`en_us`）の設定画面を標準収録。

## 導入方法

1. Minecraft Java Edition（`1.20` 〜 `26.x`）に **Sodium** と **Iris Shaders** を導入します。
2. [Releases](../../releases)（またはリポジトリ直下）から `Mifjpn-PT-Clouds.zip` をダウンロードし、解凍せずに `.minecraft/shaderpacks/` フォルダへ配置します。
3. ゲーム内の **設定 → ビデオ設定 → シェーダーパック** から `Mifjpn-PT-Clouds.zip` を選択して適用します。

## Mod 連携・注意事項

- **Distant Horizons**: 遠景 LOD の G-Buffer 統合にネイティブ対応しています。
- **Physics Mod Pro**: 水面描画パスでの **海洋物理（Ocean v3）** にネイティブ対応しています。
  - *MC 26.3 環境での補足*: Physics Mod 併用時にプレイヤーや地形の影が消える場合は、海洋設定は有効のまま **Physics Settings → Smoke（煙）** のみ **Off** に設定してください。

## 主な雲設定項目（`シェーダーパック設定 → 雲・ボリューム雲`）

| 設定項目 | マクロ名 | 初期値 | 設定範囲 | 内容 |
| :--- | :--- | :---: | :---: | :--- |
| **雲量** | `CLOUD_COVERAGE` | `0.44` | `0.15 – 0.85` | 低層ボリューム積雲の広がり具合 |
| **雲底高度** | `CLOUD_ALTITUDE` | `768.0` | `192 – 1280` | 低層雲の底面高度（m） |
| **雲層の厚み** | `CLOUD_THICKNESS` | `260.0` | `110 – 440` | 低層積雲の垂直方向の厚み（m） |
| **低層雲のスケール** | `CLOUD_SCALE` | `1.00` | `0.60 – 2.00` | 綿雲1粒あたりのサイズ倍率 |
| **高層雲 (巻雲・うろこ雲)** | `CLOUD_CIRRUS` | `ON` | `ON / OFF` | 上空の巻層雲・うろこ雲層の有効化 |
| **高層雲の広がり** | `CLOUD_HIGH_COVERAGE` | `0.58` | `0.00 – 1.00` | 高層雲ベールの被覆面積 |
| **高層雲の濃さ** | `CLOUD_HIGH_DENSITY` | `1.00` | `0.25 – 2.00` | 高層雲の光学濃度（透け感） |

## ライセンス

**MIT License** の下で公開・配布されています。詳細は [`LICENSE`](LICENSE) を参照してください。
