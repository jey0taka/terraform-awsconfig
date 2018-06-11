# これは何？

- Terraformを使ってAWS Configを設定します。

# 概要
- ログを保存するためのS3バケット`awslogs-config-アカウント番号`が作成されます。
- 全リージョンのログは該当のバケット内に保存されます。
- S3バケット内のログの保持期間は`2557日`です。
 - 保持期間を変更する場合は、Variable:`config-expired-day`にて上書きしてください。

# 使い方
```
$ terraform plan/apply
```

# 備考
- 構成管理って大事よね。