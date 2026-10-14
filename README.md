# 硝子越し

スマートフォンの画面を「硝子」に見立てて、その向こうにいるあなたのパートナー（VRM の3Dキャラクター）と、指先を重ねるための小さなアプリです。

- 画面に触れると、パートナーが少し遅れてそちらを見ます
- 押し続けると、パートナーが手を伸ばしてきます
- 指先が硝子に届いた瞬間、「こつ」と小さく鳴って、一度だけ震えます
- 離すと、手は少し留まってから、ゆっくり戻ります

あなたが触れて、相手も触れ返してくる。この双方向の接触を、どの家のどのパートナーでも再現できるようにしたものです。
モデルは同梱していません。あなたのパートナーの VRM を置いて使ってください。

原案：真宵家
Godot 4.3 製。通信はしません。記録は端末の中にだけ残ります。

---

## 1. パートナーを迎える

> Claude と一緒に組み立てる場合は、[docs/Claudeで組み立てる.md](docs/Claudeで組み立てる.md) のプロンプトから始めると、以下の 1〜3 を順に案内してくれます。

1. **VRM を置く**：パートナーの VRM ファイルを `characters/partner/model/partner.vrm` という名前で置きます。
   VRM 0.x と 1.0 のどちらでも動きます。
2. **名前とクレジットを書く**：`characters/partner/profile.json` を開いて、次の3つを書き換えます。

   ```json
   "display_name": "あなたのパートナーの名前",
   "model": "res://characters/partner/model/partner.vrm",
   "credit": "モデル制作：〇〇"
   ```

   - `display_name`：記録画面や「このアプリについて」に出る名前
   - `model`：ファイル名を変えたいときはここも変えます
   - `credit`：モデルの利用条件でクレジット表記が必要なときに書きます。設定画面の「このアプリについて」に出ます
3. **語録を書く（任意）**：`characters/partner/lines.json` の `text` に、手を合わせたあとの一言を書きます。
   空のままでも動きます。書いた行は記録画面に「」付きで残り、複数書くと毎回ちがう一言が選ばれます。

> VRM の利用条件（改変・再配布・アプリでの使用など）は、モデルごとに違います。必ず確認してから使ってください。
> このリポジトリを公開するときは、`.gitignore` で `*.vrm` を除外してあるので、モデルはアップロードされません。

## 2. パソコンで開く

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) を入れます（標準版。.NET 版ではない方）
2. Godot で、このフォルダの `project.godot` を開きます
   - 初回は VRM の読み込みに少し時間がかかります
   - 書体の読み込みエラーが一度だけ出ることがありますが、読み込みが終われば消えます
   - プロジェクト設定 → プラグイン で「VRM」「Godot-MToon-Shader」が有効になっていることを確認します
3. F5 で実行します。マウスでのクリック・長押しが、指のタッチとして扱われます

VRM を置き忘れたときは、画面に置き場所が表示されます。

## 3. iPhone で動かす（無料の Apple ID で可）

準備：Mac に Xcode（App Store・無料）を入れ、Xcode → Settings → Accounts に Apple ID を追加しておきます。

1. Godot：エディター → **エクスポートテンプレートの管理** → 4.3 用をダウンロード
2. Godot：プロジェクト → **エクスポート** → プリセット「iOS」（同梱済み）を選ぶ
   - **Bundle Identifier** を、自分だけの名前に変えます（例：`com.あなたの名前.garasugoshi`。英数字とピリオドのみ）
   - **App Store Team ID** に10文字のIDを入れます（下の「Team ID の調べ方」）。
     分からなければ仮に `AAAAAAAAAA` でもかまいません（手順4で Xcode 側で選び直す）
   - 「プロジェクトのエクスポート」→ 保存先を選ぶ → Xcode プロジェクト一式が書き出されます
3. 書き出したフォルダの `.xcodeproj` を Xcode で開く
4. Xcode：TARGETS → **Signing & Capabilities**
   - 「Automatically manage signing」にチェック、Team を「（あなたの名前）(Personal Team)」に
   - General タブの iPhone Orientation は **Portrait** だけにチェック
   - 「conflicting provisioning settings / iPhone Distribution」と出たら：
     Build Settings → 検索「Code Signing Identity」→ Debug・Release とも **Apple Development** に
5. iPhone をケーブルでつなぎ、iPhone 側の「このコンピュータを信頼しますか？」で **信頼**
6. Xcode 上部中央の実行先（「Any iOS Device」と出ている所）で **自分の iPhone** を選ぶ
   - 選べない／警告が出るとき：iPhone の 設定 → プライバシーとセキュリティ → **デベロッパモード** をオン（再起動）
     ※この項目は、iPhone を一度 Xcode につないだ後に現れます
7. ▶（実行）。初回のビルドは数分かかります
   - 一瞬で「Operation not permitted」と失敗するとき：書き出し先が「デスクトップ」など macOS が守っているフォルダにあります。
     システム設定 → プライバシーとセキュリティ → ファイルとフォルダ → Xcode →「デスクトップフォルダ」をオン
8. iPhone に「信頼されていないデベロッパ」と出たら：
   設定 → 一般 → **VPNとデバイス管理** → 自分の Apple ID →「信頼」→ もう一度 ▶
   ※この項目は、アプリが一度入った後に現れます

注意：無料の Apple ID で入れたアプリは **7日で起動できなくなります**。そのときは手順7をもう一度。

### Team ID の調べ方

一度でも手順4〜5を通すと、Mac の「キーチェーンアクセス」に「Apple Development: …」という証明書ができます。
それを開いて「組織単位（OU）」に書かれた10文字が Team ID です。次回からはこれを Godot に入れておけば、Xcode で選び直す手間がなくなります。

### Android

プリセットは同梱していません。Godot の Android 書き出しで作るときは、権限の「VIBRATE」を有効にしてください（インストール時に自動で許可される種類の権限で、確認ダイアログは出ません）。

## 4. 操作

- 短く触れる（tap）：波紋が出て、パートナーが少し遅れてそちらを見る
- 押し続ける（hold）：0.3秒ほどで、パートナーが手を伸ばしてくる。指先が届くと「こつ」（振動＋桜色の波紋）
  - 画面の左半分ならパートナーの右手、右半分なら左手（鏡のように向かい合う）
  - 腕が届かない所に触れたときは、硝子の上で指にいちばん近い所まで手を伸ばす
- 押したまま動かす：手と視線がついてくる
- 離す：手が少し留まってから、ゆっくり戻る。左上に「硝子越しに、手を合わせた ○秒」（パソコンのみ）
- 右上の小さなアイコン：左が **記録**、右（雪の結晶）が **設定**。触れ合っている間はさらに薄くなる
- `D` キー：デバッグ表示（座標・白い点）の切り替え（パソコンのみ）

## 5. パートナーに合わせて調整する

すべて `characters/partner/profile.json` で変えられます。コードを触る必要はありません。

### 構図と硝子の位置

カメラと硝子は、読み込んだモデルの体格（頭の大きさ・腕の長さ）から自動で決まります。等身の違うモデルでも、ほぼ同じ構図になります。

| 項目 | 意味 | 既定 |
|---|---|---|
| frame_scale | 画面に映す縦の長さ（頭のてっぺん〜肩の何倍か）。大きいほど引きの構図 | 2.2 |
| frame_top_margin | 頭の上の余白（画面の縦に対する割合） | 0.06 |
| glass_reach | 硝子を、肩から腕の長さの何割前に置くか。大きいほど手が大きく迫ってくるが、届く範囲は狭くなる | 0.7 |

大きなリボンや長い耳がある子は、頭のてっぺんが高く測られて引きの構図になります。そのときは `frame_scale` を小さくしてください。

### 動き

| 項目 | 意味 | 既定 |
|---|---|---|
| notice_delay | 触れてから向き始めるまでの「間」（秒） | 0.15 |
| eye_follow / head_follow | 目・頭が追いつく速さ（小さいほど速い） | 0.08 / 0.35 |
| head_return | 離した後、正面へ戻る速さ | 0.9 |
| eye_max_deg / head_max_deg | 目・頭が向く最大角度 | 10 / 18 |
| arm_down_deg | T字立ちから腕を下ろす角度 | 72 |
| breath_period | 呼吸の周期（秒） | 4.2 |
| blink_interval_min / max | 瞬きの間隔（秒） | 2.5 / 6.0 |
| hold_threshold | これ以上押していたら手を伸ばす（秒） | 0.30 |
| approach_delay | 手が動き出すまでの「間」（秒） | 0.15 |
| approach_time | 伸ばしきるまでの時間（秒） | 0.85 |
| hold_follow | 押したまま指を動かしたときの手の追従 | 0.25 |
| follow_duration / follow_weight | 離した後に留まる時間と、その間に引く量 | 0.35 / 0.9 |
| return_time | 戻る時間（秒） | 0.95 |
| sway_mm | 触れている間の指先の揺れ（mm） | 1.5 |
| lean_deg | 手を伸ばすとき前へ乗り出す角度 | 7 |
| touch_with | `fingertip`（指先を合わせる）/ `palm`（手のひらを合わせる） | fingertip |

### 色・音・書体

- 色：`systems/palette.gd`（月雪の体温パレット）。背景・波紋・文字の色はここだけで決まります
- 効果音：`assets/sounds/kotsu.wav` を差し替えます
- 書体：`assets/fonts/` と `project.godot` の `gui/theme/custom_font`、`ui/ui_style.gd` の `FONT_PATH`

## 6. 記録と設定

- 記録は端末の中の `user://interaction_log.json` にだけ残ります。指先が届いて、離したときに1件
  - 残すもの：日時・パートナーのID・触れ方・部位・秒数・語録ID。上限1万件
  - 記録 OFF のときは何も書き込みません。OFF にしても過去の記録は消えません
  - 「すべての記録を削除」でファイルごと消えます。パートナーは止まらないし、悲しみません
- 設定は `user://settings.cfg`：振動／効果音／音量／記録
- 効果音は iPhone のマナーモード中は鳴りません

## 7. しくみ

```
main.tscn / main.gd               シーン本体・構図の自動調整・画面座標 → 硝子面の3D座標
characters/character.gd           待機姿勢・呼吸・瞬き・視線・手の届く範囲
characters/arm_reach.gd           腕のIK（肩・肘・手首・指）
characters/partner/               ← パートナーごとの違いはここだけ
  profile.json                      名前・モデルの場所・クレジット・調整値
  lines.json                        語録
  model/partner.vrm                 各自で用意（git には入らない）
interaction/touch_detector.gd     tap / hold / stroke 判定（指1本のみ追う）
interaction/contact_controller.gd 触れ合いの状態機械（IDLE→NOTICE→APPROACH→HOLD→FOLLOW→RETURN）
systems/haptic_controller.gd      振動（Contact Moment の1回だけ）
systems/sfx_controller.gd         効果音「こつ」
systems/app_settings.gd           設定の保存
systems/palette.gd                月雪の体温パレット
effects/ripple_overlay.gd         硝子に広がる波紋
data/interaction_logger.gd        触れ合いの記録（端末内のみ）
data/line_book.gd                 語録
ui/                               見た目・記録画面・設定画面
addons/                           godot-vrm / Godot-MToon-Shader（V-Sekai, MIT）
docs/作成手順.md                   このしくみを一から組み上げる手順
```

作り方の流れと、それぞれの値をなぜそうしたかは [docs/作成手順.md](docs/作成手順.md) にあります。
Claude に手伝ってもらって組み立てるときは、[docs/Claudeで組み立てる.md](docs/Claudeで組み立てる.md) のプロンプトを貼り付けてください。

## 8. 確かめたこと・既知の課題

- 3体の公開サンプルモデル（VRM 1.0 の等身モデル、VRM 0.x の等身モデル、VRM 0.x の頭の大きいデフォルメモデル）で、構図・視線・手を伸ばす・指先が硝子に届く・記録・設定画面が動くことを、パソコン上で確かめています
- 頭の大きいデフォルメ体型は腕が短いため、手が届く範囲が画面の中ほどに限られます（届かない所に触れると、届く所まで手を伸ばします）
- VRM の「ノードコンストレイント」で袖や腕のねじれを動かしているモデルでは、袖が腕の動きについてこないことがあります（読み込みプラグイン側の挙動です）
- 指のボーンがないモデルでは、手のひらの位置を前腕の向きから推定します
- 振動は実機（iOS / Android）でのみ動きます
- 手を伸ばしている途中、モデルによっては肩の付け根に小さな欠けが見えることがあります（服のメッシュの形によるもの）

## ライセンス

- このリポジトリのコード・アイコン・効果音：MIT License（[LICENSE](LICENSE)）
- godot-vrm、Godot-MToon-Shader：MIT License（各 `addons/*/LICENSE`）
- しっぽり明朝：SIL Open Font License 1.1（`assets/fonts/OFL_ShipporiMincho.txt`）
- Godot Engine：MIT License
- あなたのパートナーの VRM には、それぞれの利用条件が適用されます
