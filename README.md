# Amazon Elastic Container Service (ECS) を terraform で素振り

ECS+Fargate を terraform で素振り。

- defaultvpc/
    - デフォルトVPC・サブネット・セキィリティグループを用いてサービスを実行
- service/
    - terraform で VPC からフルセットで作成してサービスを実行
- schedule/
    - タスクを定期的に実行（タスクのスケジューリング）
