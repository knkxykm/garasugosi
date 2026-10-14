# 共有について

このリポジトリは Private のまま運用してください。

GitHub の Private リポジトリは「URLを知っているだけ」では閲覧できません。閲覧させたい相手の GitHub アカウントを collaborator として招待してください。

- VRM 本体は共有しません（`*.vrm` を `.gitignore` で除外）
- `tools/setup_dependencies.py` と `tools/setup_font.py` の通信はセットアップ時だけです
- アプリ本体には外部通信処理を持たせません
